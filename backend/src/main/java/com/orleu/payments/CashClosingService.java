package com.orleu.payments;

import com.orleu.audit.AuditService;
import com.orleu.auth.CurrentUser;
import com.orleu.common.ApiException;
import com.orleu.common.Money;
import com.orleu.tenancy.Permission;
import com.orleu.tenancy.TenantAccess;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.sql.Timestamp;
import java.time.*;
import java.util.List;
import java.util.UUID;

/**
 * Cash register closing. The expected figures are derived from the ledger for [previous closing end, now): CASH is what should be in the drawer,
 * BANK_TRANSFER and CARD_MANUAL are shown for the accountant but are not counted physically. Closings are append-only and serialised per business.
 * Known limit: a payment whose transaction started before the closing but commits after it is picked up by the NEXT period (milliseconds window).
 */
@Service
public class CashClosingService {
    public record Method(BigDecimal payments, BigDecimal refunds, BigDecimal net) {}
    public record Preview(Instant periodStart, Instant periodEnd, String currency, Method cash, Method bank, Method card, boolean firstClosing, Closing lastClosing) {}
    public record Closing(UUID id, Instant periodStart, Instant periodEnd, String currency, BigDecimal expectedCash, BigDecimal expectedBank, BigDecimal expectedCard,
                          BigDecimal countedCash, BigDecimal difference, String note, UUID closedBy, String closedByName, Instant createdAt) {}

    private final TenantAccess access;
    private final JdbcClient jdbc;
    private final AuditService audit;

    public CashClosingService(TenantAccess access, JdbcClient jdbc, AuditService audit) { this.access = access; this.jdbc = jdbc; this.audit = audit; }

    private record Period(Instant start, Instant end, boolean first) {}

    private Period period(UUID businessId, Instant end, LocalDate since) {
        Instant last = jdbc.sql("select period_end from cash_closings where business_id = :b order by period_end desc limit 1").param("b", businessId)
                .query(Timestamp.class).optional().map(Timestamp::toInstant).orElse(null);
        if (last != null) {
            if (since != null) throw ApiException.badRequest("SINCE_NOT_ALLOWED", "'since' is only allowed for the first closing");
            return new Period(last, end, false);
        }
        ZoneId zone = ZoneId.of(jdbc.sql("select timezone from businesses where id = :b").param("b", businessId).query(String.class).single());
        LocalDate from = since != null ? since : end.atZone(zone).toLocalDate();
        if (from.isAfter(end.atZone(zone).toLocalDate())) throw ApiException.badRequest("INVALID_SINCE", "'since' cannot be in the future");
        return new Period(from.atStartOfDay(zone).toInstant(), end, true);
    }

    private Method sum(UUID businessId, Period p, String method) {
        BigDecimal pay = jdbc.sql("select coalesce(sum(amount), 0) from ledger_entries where business_id = :b and method = :m and entry_type = 'PAYMENT' and created_at >= :s and created_at < :e")
                .param("b", businessId).param("m", method).param("s", Timestamp.from(p.start())).param("e", Timestamp.from(p.end())).query(BigDecimal.class).single();
        BigDecimal ref = jdbc.sql("select coalesce(sum(amount), 0) from ledger_entries where business_id = :b and method = :m and entry_type = 'REFUND' and created_at >= :s and created_at < :e")
                .param("b", businessId).param("m", method).param("s", Timestamp.from(p.start())).param("e", Timestamp.from(p.end())).query(BigDecimal.class).single();
        return new Method(Money.scale(pay), Money.scale(ref), Money.scale(pay.subtract(ref)));
    }

    private String currency(UUID businessId) {
        return jdbc.sql("select currency from businesses where id = :b").param("b", businessId).query(String.class).single();
    }

    public Preview preview(UUID businessId, LocalDate since) {
        access.require(businessId, Permission.FINANCE_VIEW);
        Period p = period(businessId, Instant.now(), since);
        return new Preview(p.start(), p.end(), currency(businessId), sum(businessId, p, "CASH"), sum(businessId, p, "BANK_TRANSFER"), sum(businessId, p, "CARD_MANUAL"), p.first(), list(businessId, 1).stream().findFirst().orElse(null));
    }

    /**
     * Closes the period. {@code expectedCash} is what the user saw in the preview: if the ledger moved since (a payment arrived),
     * the close is refused with 409 so nobody signs off on numbers they have not seen.
     */
    @Transactional
    public Closing close(UUID businessId, BigDecimal expectedCash, BigDecimal countedCash, String note, LocalDate since) {
        access.require(businessId, Permission.FINANCE_MANAGE);
        if (countedCash == null || countedCash.signum() < 0) throw ApiException.badRequest("INVALID_AMOUNT", "The counted cash cannot be negative");
        String n = note == null || note.isBlank() ? null : note.trim();
        if (n != null && n.length() > 500) throw ApiException.badRequest("NOTE_TOO_LONG", "The note is limited to 500 characters");
        // serialise closings of one business so two people cannot close the same period twice
        jdbc.sql("select id from businesses where id = :b for update").param("b", businessId).query(UUID.class).optional().orElseThrow(() -> ApiException.notFound("Business"));
        Instant end = Instant.now().truncatedTo(java.time.temporal.ChronoUnit.MICROS);
        Period p = period(businessId, end, since);
        if (!p.end().isAfter(p.start())) throw ApiException.conflict("PERIOD_EMPTY", "Nothing to close yet");
        Method cash = sum(businessId, p, "CASH"), bank = sum(businessId, p, "BANK_TRANSFER"), card = sum(businessId, p, "CARD_MANUAL");
        if (expectedCash == null || Money.scale(expectedCash).compareTo(cash.net()) != 0) {
            throw ApiException.conflict("EXPECTED_CHANGED", "Payments changed since you opened the closing. Review the new expected cash: " + cash.net());
        }
        BigDecimal counted = Money.scale(countedCash);
        UUID id = jdbc.sql("""
            insert into cash_closings (business_id, period_start, period_end, currency, expected_cash, expected_bank, expected_card, counted_cash, difference, note, closed_by)
            values (:b, :s, :e, :c, :ec, :eb, :ecd, :cc, :d, :n, :u) returning id
            """).param("b", businessId).param("s", Timestamp.from(p.start())).param("e", Timestamp.from(p.end())).param("c", currency(businessId))
                .param("ec", cash.net()).param("eb", bank.net()).param("ecd", card.net()).param("cc", counted).param("d", counted.subtract(cash.net()))
                .param("n", n, java.sql.Types.VARCHAR).param("u", CurrentUser.id()).query(UUID.class).single();
        audit.log(businessId, CurrentUser.id(), "CASH_CLOSED", "BUSINESS", businessId, "{\"closing\":\"" + id + "\",\"difference\":\"" + counted.subtract(cash.net()) + "\"}");
        return list(businessId, 50).stream().filter(c -> c.id().equals(id)).findFirst().orElseThrow();
    }

    public List<Closing> history(UUID businessId) {
        access.require(businessId, Permission.FINANCE_VIEW);
        return list(businessId, 50);
    }

    private List<Closing> list(UUID businessId, int limit) {
        return jdbc.sql("""
            select c.id, c.period_start, c.period_end, c.currency, c.expected_cash, c.expected_bank, c.expected_card, c.counted_cash, c.difference, c.note, c.closed_by, u.full_name, c.created_at
            from cash_closings c left join users u on u.id = c.closed_by where c.business_id = :b order by c.period_end desc limit :l
            """).param("b", businessId).param("l", limit)
                .query((rs, i) -> new Closing(rs.getObject(1, UUID.class), rs.getTimestamp(2).toInstant(), rs.getTimestamp(3).toInstant(), rs.getString(4), rs.getBigDecimal(5), rs.getBigDecimal(6),
                        rs.getBigDecimal(7), rs.getBigDecimal(8), rs.getBigDecimal(9), rs.getString(10), rs.getObject(11, UUID.class), rs.getString(12), rs.getTimestamp(13).toInstant())).list();
    }
}
