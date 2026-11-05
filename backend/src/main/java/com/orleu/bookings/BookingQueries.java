package com.orleu.bookings;

import com.orleu.bookings.BookingDtos.*;
import com.orleu.common.Money;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/** Read model: bookings joined with names and ledger-derived financials. Always tenant-scoped. */
@Component
public class BookingQueries {
    private static final String BASE = """
        select b.id, b.branch_id, b.service_id, s.name as service_name, b.employee_id, e.display_name as employee_name,
               b.customer_id, c.full_name as customer_name, c.phone as customer_phone, b.starts_at, b.ends_at, b.status,
               b.currency, b.notes, b.hold_expires_at, b.price, b.deposit_amount,
               coalesce((select sum(l.amount) from ledger_entries l where l.booking_id = b.id and l.entry_type = 'PAYMENT'), 0) as paid,
               coalesce((select sum(l.amount) from ledger_entries l where l.booking_id = b.id and l.entry_type = 'REFUND'), 0) as refunded
        from bookings b
        join services s on s.id = b.service_id and s.business_id = b.business_id
        join employees e on e.id = b.employee_id and e.business_id = b.business_id
        join customers c on c.id = b.customer_id and c.business_id = b.business_id
        where b.business_id = :biz
        """;

    private final JdbcClient jdbc;

    public BookingQueries(JdbcClient jdbc) { this.jdbc = jdbc; }

    public Optional<BookingView> find(UUID businessId, UUID bookingId) {
        return jdbc.sql(BASE + " and b.id = :id").param("biz", businessId).param("id", bookingId)
                .query((rs, i) -> map(rs)).optional();
    }

    public List<BookingView> list(UUID businessId, Instant from, Instant to, UUID employeeId, BookingStatus status) {
        return jdbc.sql(BASE + """
                 and b.starts_at >= :from and b.starts_at < :to
                 and (cast(:emp as uuid) is null or b.employee_id = :emp)
                 and (cast(:st as varchar) is null or b.status = :st)
                 order by b.starts_at limit 1000
                """).param("biz", businessId).param("from", Timestamp.from(from)).param("to", Timestamp.from(to))
                .param("emp", employeeId, java.sql.Types.OTHER).param("st", status == null ? null : status.name(), java.sql.Types.VARCHAR)
                .query((rs, i) -> map(rs)).list();
    }

    private BookingView map(java.sql.ResultSet rs) throws java.sql.SQLException {
        BigDecimal price = rs.getBigDecimal("price");
        BigDecimal deposit = rs.getBigDecimal("deposit_amount");
        BigDecimal paid = rs.getBigDecimal("paid");
        BigDecimal refunded = rs.getBigDecimal("refunded");
        return new BookingView(rs.getObject("id", UUID.class), rs.getObject("branch_id", UUID.class),
                rs.getObject("service_id", UUID.class), rs.getString("service_name"),
                rs.getObject("employee_id", UUID.class), rs.getString("employee_name"),
                rs.getObject("customer_id", UUID.class), rs.getString("customer_name"), rs.getString("customer_phone"),
                rs.getTimestamp("starts_at").toInstant(), rs.getTimestamp("ends_at").toInstant(),
                BookingStatus.valueOf(rs.getString("status")), rs.getString("currency"), rs.getString("notes"),
                rs.getTimestamp("hold_expires_at") == null ? null : rs.getTimestamp("hold_expires_at").toInstant(),
                financials(price, deposit, paid, refunded));
    }

    public static Financials financials(BigDecimal price, BigDecimal deposit, BigDecimal paid, BigDecimal refunded) {
        BigDecimal net = Money.scale(paid.subtract(refunded));
        BigDecimal remaining = Money.scale(price.subtract(net).max(BigDecimal.ZERO));
        String status;
        if (paid.signum() == 0) status = "UNPAID";
        else if (net.signum() == 0 && refunded.signum() > 0) status = "REFUNDED";
        else if (net.compareTo(price) >= 0) status = "PAID";
        else if (net.compareTo(deposit) >= 0 && deposit.signum() > 0) status = "DEPOSIT_PAID";
        else status = "PARTIALLY_PAID";
        return new Financials(price, deposit, Money.scale(paid), Money.scale(refunded), net, remaining, status);
    }
}
