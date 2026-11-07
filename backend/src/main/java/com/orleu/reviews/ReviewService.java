package com.orleu.reviews;

import com.orleu.admin.PlatformAccess;
import com.orleu.admin.PlatformRole;
import com.orleu.audit.AuditService;
import com.orleu.auth.CurrentUser;
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
    public record ReviewRow(UUID id, int rating, String comment, String customerName, String serviceName, Instant createdAt,
                            String reply, Instant repliedAt, boolean hidden, String hiddenReason) {}
    /** Platform moderation view: includes the business, never the customer's phone or e-mail. */
    public record AdminReviewRow(UUID id, UUID businessId, String businessName, int rating, String comment, String customerName, Instant createdAt,
                                 boolean hidden, String hiddenReason, String reply) {}
    public record Summary(int count, Double average, int[] distribution) {}

    private final JdbcClient jdbc;
    private final TenantAccess access;
    private final PlatformAccess platform;
    private final AuditService audit;

    public ReviewService(JdbcClient jdbc, TenantAccess access, PlatformAccess platform, AuditService audit) {
        this.jdbc = jdbc; this.access = access; this.platform = platform; this.audit = audit;
    }

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
            select r.id, r.rating, r.comment, c.full_name, s.name, r.created_at, r.reply, r.replied_at, r.hidden, r.hidden_reason
            from reviews r join bookings b on b.id = r.booking_id and b.business_id = r.business_id
            join customers c on c.id = b.customer_id and c.business_id = b.business_id
            join services s on s.id = b.service_id and s.business_id = b.business_id
            where r.business_id = :b order by r.created_at desc limit 100
            """).param("b", businessId)
            .query((rs, i) -> new ReviewRow(rs.getObject(1, UUID.class), rs.getInt(2), rs.getString(3), rs.getString(4), rs.getString(5), rs.getTimestamp(6).toInstant(),
                    rs.getString(7), rs.getTimestamp(8) == null ? null : rs.getTimestamp(8).toInstant(), rs.getBoolean(9), rs.getString(10))).list();
    }

    @Transactional(readOnly = true)
    public Summary summary(UUID businessId) {
        access.require(businessId, Permission.CUSTOMERS_VIEW);
        return summaryUnchecked(businessId);
    }

    /** Public figure shown on the booking page; no access check because it only aggregates already-public data of a published business. */
    public Summary summaryUnchecked(UUID businessId) {
        int[] dist = new int[5];
        jdbc.sql("select rating, count(*) from reviews where business_id = :b and not hidden group by rating").param("b", businessId)
                .query((rs, i) -> { dist[rs.getInt(1) - 1] = rs.getInt(2); return 0; }).list();
        int n = 0, sum = 0;
        for (int i = 0; i < 5; i++) { n += dist[i]; sum += dist[i] * (i + 1); }
        return new Summary(n, n == 0 ? null : Math.round(sum * 10.0 / n) / 10.0, dist);
    }

    // ---------- business reply ----------

    /** Sets or replaces the business's public reply (BUSINESS_MANAGE). The guest sees it on their booking link. */
    @Transactional
    public ReviewRow reply(UUID businessId, UUID reviewId, String text) {
        access.require(businessId, Permission.BUSINESS_MANAGE);
        String t = text == null ? "" : text.strip();
        if (t.isEmpty()) throw ApiException.badRequest("INVALID_REPLY", "The reply cannot be empty");
        if (t.length() > 1000) throw ApiException.badRequest("INVALID_REPLY", "The reply is too long");
        Boolean hidden = jdbc.sql("select hidden from reviews where id = :id and business_id = :b for update").param("id", reviewId).param("b", businessId).query(Boolean.class).optional()
                .orElseThrow(() -> ApiException.notFound("Review"));
        if (hidden) throw ApiException.conflict("REVIEW_HIDDEN", "This review was hidden by the platform");
        jdbc.sql("update reviews set reply = :t, replied_at = now(), replied_by = :u where id = :id and business_id = :b").param("t", t).param("u", CurrentUser.id()).param("id", reviewId).param("b", businessId).update();
        audit.log(businessId, CurrentUser.id(), "REVIEW_REPLIED", "REVIEW", reviewId, null);
        return one(businessId, reviewId);
    }

    @Transactional
    public ReviewRow deleteReply(UUID businessId, UUID reviewId) {
        access.require(businessId, Permission.BUSINESS_MANAGE);
        int n = jdbc.sql("update reviews set reply = null, replied_at = null, replied_by = null where id = :id and business_id = :b").param("id", reviewId).param("b", businessId).update();
        if (n == 0) throw ApiException.notFound("Review");
        audit.log(businessId, CurrentUser.id(), "REVIEW_REPLY_REMOVED", "REVIEW", reviewId, null);
        return one(businessId, reviewId);
    }

    private ReviewRow one(UUID businessId, UUID reviewId) {
        return list(businessId).stream().filter(r -> r.id().equals(reviewId)).findFirst().orElseThrow(() -> ApiException.notFound("Review"));
    }

    // ---------- platform moderation ----------

    private UUID moderator() { return platform.require(PlatformRole.SUPER_ADMIN, PlatformRole.PLATFORM_SUPPORT); }

    @Transactional(readOnly = true)
    public List<AdminReviewRow> adminList(boolean onlyHidden, int page, int size) {
        moderator();
        int s = Math.min(Math.max(size, 1), 100), p = Math.max(page, 0);
        return jdbc.sql("""
            select r.id, r.business_id, bz.name, r.rating, r.comment, c.full_name, r.created_at, r.hidden, r.hidden_reason, r.reply
            from reviews r join businesses bz on bz.id = r.business_id
            join bookings b on b.id = r.booking_id and b.business_id = r.business_id
            join customers c on c.id = b.customer_id and c.business_id = b.business_id
            where (not :oh or r.hidden) order by r.created_at desc limit :s offset :o
            """).param("oh", onlyHidden).param("s", s).param("o", p * s)
            .query((rs, i) -> new AdminReviewRow(rs.getObject(1, UUID.class), rs.getObject(2, UUID.class), rs.getString(3), rs.getInt(4), rs.getString(5), rs.getString(6),
                    rs.getTimestamp(7).toInstant(), rs.getBoolean(8), rs.getString(9), rs.getString(10))).list();
    }

    /** Hides an abusive or fraudulent review from the average and from the guest page. A reason is mandatory and the action is audited; reversible. */
    @Transactional
    public void hide(UUID reviewId, String reason) {
        UUID admin = moderator();
        String r = reason == null ? "" : reason.strip();
        if (r.length() < 5 || r.length() > 300) throw ApiException.badRequest("INVALID_REASON", "Give a reason of 5-300 characters");
        UUID biz = jdbc.sql("select business_id from reviews where id = :id for update").param("id", reviewId).query(UUID.class).optional().orElseThrow(() -> ApiException.notFound("Review"));
        jdbc.sql("update reviews set hidden = true, hidden_reason = :r, hidden_by = :u, hidden_at = now() where id = :id").param("r", r).param("u", admin).param("id", reviewId).update();
        audit.log(biz, admin, "REVIEW_HIDDEN", "REVIEW", reviewId, null);
    }

    @Transactional
    public void unhide(UUID reviewId) {
        UUID admin = moderator();
        UUID biz = jdbc.sql("select business_id from reviews where id = :id for update").param("id", reviewId).query(UUID.class).optional().orElseThrow(() -> ApiException.notFound("Review"));
        jdbc.sql("update reviews set hidden = false, hidden_reason = null, hidden_by = null, hidden_at = null where id = :id").param("id", reviewId).update();
        audit.log(biz, admin, "REVIEW_UNHIDDEN", "REVIEW", reviewId, null);
    }
}
