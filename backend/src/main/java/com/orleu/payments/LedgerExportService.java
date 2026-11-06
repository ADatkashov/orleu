package com.orleu.payments;

import com.orleu.audit.AuditService;
import com.orleu.auth.CurrentUser;
import com.orleu.common.ApiException;
import com.orleu.tenancy.Permission;
import com.orleu.tenancy.TenantAccess;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.UUID;

/**
 * Accounting export of the immutable ledger as CSV: one row per payment/refund, refunds negative, in business time.
 * Requires FINANCE_EXPORT (owner, admin, accountant): a whole-period dump is a wider disclosure than viewing single payments,
 * so receptionists and managers do not get it. Every export is audited.
 * Customer names and phone numbers are deliberately NOT included: the accountant role has no CUSTOMERS_VIEW and an export must not
 * be a way around that. This is a data export, NOT a statutory fiscal document: no tax numbers, no fiscal receipts.
 * Text cells are neutralised against spreadsheet formula injection (a service named "=HYPERLINK(...)" must not run in Excel).
 */
@Service
public class LedgerExportService {
    static final int MAX_ROWS = 50_000;
    private static final DateTimeFormatter LOCAL = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");

    public record Export(String fileName, byte[] bytes, int rows) {}

    private final TenantAccess access;
    private final JdbcClient jdbc;
    private final AuditService audit;

    public LedgerExportService(TenantAccess access, JdbcClient jdbc, AuditService audit) { this.access = access; this.jdbc = jdbc; this.audit = audit; }

    @Transactional
    public Export export(UUID businessId, Instant from, Instant to, boolean semicolon) {
        access.require(businessId, Permission.FINANCE_EXPORT);
        if (!to.isAfter(from) || Duration.between(from, to).toDays() > 366) throw ApiException.badRequest("INVALID_RANGE", "range must be positive and at most 366 days");
        var biz = jdbc.sql("select slug, timezone from businesses where id = :b").param("b", businessId)
                .query((rs, i) -> new String[]{rs.getString(1), rs.getString(2)}).single();
        ZoneId zone = ZoneId.of(biz[1]);
        String sep = semicolon ? ";" : ",";
        StringBuilder sb = new StringBuilder("﻿");
        sb.append(String.join(sep, "recorded_at_local", "recorded_at_utc", "entry_id", "type", "amount_signed", "currency", "method", "booking_id",
                "booking_start_local", "service", "provider_ref")).append("\r\n");
        int[] n = {0};
        jdbc.sql("""
            select l.created_at, l.id, l.entry_type, l.amount, l.currency, l.method, l.booking_id, b.starts_at, s.name, l.provider_ref
            from ledger_entries l
            join bookings b on b.id = l.booking_id and b.business_id = l.business_id
            join services s on s.id = b.service_id and s.business_id = b.business_id
            where l.business_id = :b and l.created_at >= :from and l.created_at < :to
            order by l.created_at, l.id limit :lim
            """).param("b", businessId).param("from", java.sql.Timestamp.from(from)).param("to", java.sql.Timestamp.from(to)).param("lim", MAX_ROWS + 1)
            .query(rs -> {
                if (++n[0] > MAX_ROWS) return;
                Instant at = rs.getTimestamp(1).toInstant();
                BigDecimal amount = rs.getBigDecimal(4);
                if ("REFUND".equals(rs.getString(3))) amount = amount.negate();
                sb.append(String.join(sep,
                        LOCAL.format(at.atZone(zone)), at.toString(), rs.getString(2), rs.getString(3), amount.setScale(2).toPlainString(), rs.getString(5),
                        rs.getString(6), rs.getString(7), LOCAL.format(rs.getTimestamp(8).toInstant().atZone(zone)),
                        text(rs.getString(9), semicolon), text(rs.getString(10), semicolon))).append("\r\n");
            });
        if (n[0] > MAX_ROWS) throw ApiException.badRequest("EXPORT_TOO_LARGE", "More than " + MAX_ROWS + " entries: choose a shorter period");
        audit.log(businessId, CurrentUser.id(), "FINANCE_EXPORTED", "LEDGER", null, "{\"rows\":" + n[0] + ",\"from\":\"" + from + "\",\"to\":\"" + to + "\"}");
        String name = "orleu-ledger-" + biz[0] + "-" + from.atZone(zone).toLocalDate() + "_" + to.atZone(zone).toLocalDate() + ".csv";
        return new Export(name, sb.toString().getBytes(StandardCharsets.UTF_8), n[0]);
    }

    /** RFC-4180 quoting plus formula-injection protection: cells starting with = + - @ tab or CR are prefixed with an apostrophe. */
    static String text(String v, boolean semicolon) {
        if (v == null) return "";
        String s = v;
        if (!s.isEmpty() && "=+-@\t\r".indexOf(s.charAt(0)) >= 0) s = "'" + s;
        if (s.contains(",") || s.contains(";") || s.contains("\"") || s.contains("\n") || s.contains("\r")) s = "\"" + s.replace("\"", "\"\"") + "\"";
        return s;
    }
}
