package com.orleu.reviews;

import com.orleu.bookings.BookingService;
import com.orleu.common.ApiException;
import com.orleu.tenancy.Permission;
import com.orleu.tenancy.TenantAccess;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

/**
 * Reviews come only from real, COMPLETED bookings (the guest proves it with the booking's secret manage token), one per
 * booking. Nothing is invented or editable by the business; ratings are measured averages, never estimates.
 */
@Service
public class ReviewService {
    public record ReviewRow(UUID id, int rating, String comment, String customerName, String serviceName, Instant createdAt) {}
    public record Summary(int count, Double average, int[] distribution) {}

    private final JdbcClient jdbc;
    private final TenantAccess access;

    public ReviewService(JdbcClient jdbc, TenantAccess access) { this.jdbc = jdbc; this.access = access; }

    @Transactional
    public void submit(String rawToken, int rating, String comment) {
        if (rating < 1 || rating > 5) throw ApiException.badRequest("INVALID_RATING", "rating must be 1-5");
        if (comment != null && comment.length() > 1000) throw ApiException.badRequest("INVALID_COMMENT", "comment is too long");
        if (rawToken == null || rawToken.length() < 20 || rawToken.length() > 100) throw ApiException.notFound("Booking");
        var row = jdbc.sql("select id, business_id, status from bookings where manage_token_hash = :h")
                .param("h", BookingService.hashToken(rawToken))
                .query((rs, i) -> new Object[]{rs.getObject(1, UUID.class), rs.getObject(2, UUID.class), rs.getString(3)}).optional()
                .orElseThrow(() -> ApiException.notFound("Booking"));
        if (!"COMPLETED".equals(row[2])) throw ApiException.conflict("REVIEW_NOT_ALLOWED", "Only completed visits can be reviewed");
        String text = comment == null || comment.isBlank() ? null : comment.strip();
        try {
            jdbc.sql("insert into reviews (business_id, booking_id, rating, comment) values (:b, :bk, :r, :c)")
                    .param("b", row[1]).param("bk", row[0]).param("r", rating).param("c", text, java.sql.Types.VARCHAR).update();
        } catch (DuplicateKeyException e) {
            throw ApiException.conflict("ALREADY_REVIEWED", "This visit was already reviewed");
        }
    }

    @Transactional(readOnly = true)
    public List<ReviewRow> list(UUID businessId) {
        access.require(businessId, Permission.CUSTOMERS_VIEW);
        return jdbc.sql("""
            select r.id, r.rating, r.comment, c.full_name, s.name, r.created_at
            from reviews r join bookings b on b.id = r.booking_id and b.business_id = r.business_id
            join customers c on c.id = b.customer_id and c.business_id = b.business_id
            join services s on s.id = b.service_id and s.business_id = b.business_id
            where r.business_id = :b order by r.created_at desc limit 100
            """).param("b", businessId)
            .query((rs, i) -> new ReviewRow(rs.getObject(1, UUID.class), rs.getInt(2), rs.getString(3), rs.getString(4), rs.getString(5), rs.getTimestamp(6).toInstant())).list();
    }

    @Transactional(readOnly = true)
    public Summary summary(UUID businessId) {
        access.require(businessId, Permission.CUSTOMERS_VIEW);
        return summaryUnchecked(businessId);
    }

    /** Public figure shown on the booking page; no access check because it only aggregates already-public data of a published business. */
    public Summary summaryUnchecked(UUID businessId) {
        int[] dist = new int[5];
        jdbc.sql("select rating, count(*) from reviews where business_id = :b group by rating").param("b", businessId)
                .query((rs, i) -> { dist[rs.getInt(1) - 1] = rs.getInt(2); return 0; }).list();
        int n = 0, sum = 0;
        for (int i = 0; i < 5; i++) { n += dist[i]; sum += dist[i] * (i + 1); }
        return new Summary(n, n == 0 ? null : Math.round(sum * 10.0 / n) / 10.0, dist);
    }
}
