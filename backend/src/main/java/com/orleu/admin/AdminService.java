package com.orleu.admin;

import com.orleu.audit.AuditService;
import com.orleu.common.ApiException;
import com.orleu.subscriptions.EntitlementService;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Service
public class AdminService {
    public record BusinessRow(UUID id, String slug, String name, String businessType, String planCode, String status,
                              boolean published, Instant planExpiresAt, Instant createdAt) {}
    public record BusinessDetail(BusinessRow business, EntitlementService.Usage usage, String suspendedReason, List<SubscriptionEvent> history) {}
    public record SubscriptionEvent(String fromPlan, String toPlan, String reason, Instant expiresAt, UUID actorUserId, Instant createdAt) {}
    public record Plan(String code, String name, int maxBranches, int maxEmployees, java.math.BigDecimal priceMonthly, String currency, boolean active) {}
    public record AuditRow(UUID id, UUID businessId, UUID actorUserId, String action, String entityType, UUID entityId, Instant createdAt) {}
    public record Page<T>(List<T> items, int page, int size) {}
    public record UserRow(UUID id, String email, String fullName, String status, String platformRole, int businesses, Instant createdAt) {}

    private final PlatformAccess access;
    private final JdbcClient jdbc;
    private final EntitlementService entitlements;
    private final AuditService audit;

    public AdminService(PlatformAccess access, JdbcClient jdbc, EntitlementService entitlements, AuditService audit) {
        this.access = access; this.jdbc = jdbc; this.entitlements = entitlements; this.audit = audit;
    }

    public Page<BusinessRow> businesses(String q, int page, int size) {
        access.requireAny();
        int s = Math.min(Math.max(size, 1), 100), p = Math.max(page, 0);
        String like = q == null || q.isBlank() ? null : "%" + q.trim().toLowerCase().replace("%", "") + "%";
        var rows = jdbc.sql("""
            select id, slug, name, business_type, plan_code, status, published, plan_expires_at, created_at from businesses
            where (cast(:q as varchar) is null or lower(name) like :q or lower(slug) like :q)
            order by created_at desc limit :s offset :o
            """).param("q", like, java.sql.Types.VARCHAR).param("s", s).param("o", p * s).query((rs, i) -> row(rs)).list();
        return new Page<>(rows, p, s);
    }

    public BusinessDetail business(UUID id) {
        access.requireAny();
        var row = jdbc.sql("select id, slug, name, business_type, plan_code, status, published, plan_expires_at, created_at, suspended_reason from businesses where id = :id")
                .param("id", id).query((rs, i) -> new Object[]{row(rs), rs.getString("suspended_reason")}).optional()
                .orElseThrow(() -> ApiException.notFound("Business"));
        var history = jdbc.sql("""
            select from_plan, to_plan, reason, expires_at, actor_user_id, created_at from subscription_events
            where business_id = :id order by created_at desc limit 50
            """).param("id", id).query((rs, i) -> new SubscriptionEvent(rs.getString(1), rs.getString(2), rs.getString(3),
                rs.getTimestamp(4) == null ? null : rs.getTimestamp(4).toInstant(), rs.getObject(5, UUID.class), rs.getTimestamp(6).toInstant())).list();
        return new BusinessDetail((BusinessRow) row[0], entitlements.usage(id), (String) row[1], history);
    }

    @Transactional
    public BusinessDetail setPlan(UUID businessId, String planCode, Instant expiresAt, String reason) {
        UUID actor = access.require(PlatformRole.SUPER_ADMIN);
        if (reason == null || reason.isBlank()) throw ApiException.badRequest("REASON_REQUIRED", "A reason is required");
        if (expiresAt != null && !expiresAt.isAfter(Instant.now())) throw ApiException.badRequest("INVALID_EXPIRY", "Expiry must be in the future");
        boolean planOk = Boolean.TRUE.equals(jdbc.sql("select exists(select 1 from subscription_plans where code = :c and active)").param("c", planCode).query(Boolean.class).single());
        if (!planOk) throw ApiException.notFound("Plan");
        String from = jdbc.sql("select plan_code from businesses where id = :id for update").param("id", businessId).query(String.class).optional()
                .orElseThrow(() -> ApiException.notFound("Business"));
        jdbc.sql("update businesses set plan_code = :p, plan_expires_at = :e, updated_at = now() where id = :id")
                .param("p", planCode).param("e", expiresAt == null ? null : Timestamp.from(expiresAt), java.sql.Types.TIMESTAMP).param("id", businessId).update();
        event(businessId, from, planCode, reason, expiresAt, actor);
        audit.log(businessId, actor, "ADMIN_PLAN_CHANGED", "BUSINESS", businessId, "{\"from\":\"" + from + "\",\"to\":\"" + planCode + "\"}");
        return business(businessId);
    }

    @Transactional
    public BusinessDetail setSuspended(UUID businessId, boolean suspend, String reason) {
        UUID actor = access.require(PlatformRole.SUPER_ADMIN);
        if (suspend && (reason == null || reason.isBlank())) throw ApiException.badRequest("REASON_REQUIRED", "A reason is required");
        int n = jdbc.sql("update businesses set status = :s, suspended_reason = :r, published = case when :susp then false else published end, updated_at = now() where id = :id")
                .param("s", suspend ? "SUSPENDED" : "ACTIVE").param("r", suspend ? reason : null, java.sql.Types.VARCHAR).param("susp", suspend).param("id", businessId).update();
        if (n == 0) throw ApiException.notFound("Business");
        audit.log(businessId, actor, suspend ? "ADMIN_BUSINESS_SUSPENDED" : "ADMIN_BUSINESS_REACTIVATED", "BUSINESS", businessId, null);
        return business(businessId);
    }

    public Page<UserRow> users(String q, int page, int size) {
        access.require(PlatformRole.SUPER_ADMIN, PlatformRole.PLATFORM_SUPPORT); // e-mail addresses are personal data: analysts do not see them
        int s = Math.min(Math.max(size, 1), 100), p = Math.max(page, 0);
        String like = q == null || q.isBlank() ? null : "%" + q.trim().toLowerCase().replace("%", "") + "%";
        var rows = jdbc.sql("""
            select u.id, u.email, u.full_name, u.status, u.platform_role, u.created_at,
                   (select count(*) from memberships m where m.user_id = u.id) as businesses
            from users u where (cast(:q as varchar) is null or lower(u.email) like :q or lower(u.full_name) like :q)
            order by u.created_at desc limit :s offset :o
            """).param("q", like, java.sql.Types.VARCHAR).param("s", s).param("o", p * s)
                .query((rs, i) -> new UserRow(rs.getObject(1, UUID.class), rs.getString(2), rs.getString(3), rs.getString(4), rs.getString(5),
                        rs.getInt(7), rs.getTimestamp(6).toInstant())).list();
        return new Page<>(rows, p, s);
    }

    /** Disabling a user blocks sign-in and revokes every refresh token; an already issued access token lives out its short lifetime (<= 15 min). */
    @Transactional
    public UserRow setUserDisabled(UUID userId, boolean disable) {
        UUID actor = access.require(PlatformRole.SUPER_ADMIN);
        if (disable && actor.equals(userId)) throw ApiException.badRequest("CANNOT_DISABLE_SELF", "You cannot disable your own account");
        int n = jdbc.sql("update users set status = :s, updated_at = now() where id = :id").param("s", disable ? "DISABLED" : "ACTIVE").param("id", userId).update();
        if (n == 0) throw ApiException.notFound("User");
        if (disable) jdbc.sql("update refresh_tokens set revoked_at = now(), revoked_reason = 'ADMIN_DISABLED' where user_id = :id and revoked_at is null").param("id", userId).update();
        audit.log(null, actor, disable ? "ADMIN_USER_DISABLED" : "ADMIN_USER_ENABLED", "USER", userId, null);
        return jdbc.sql("""
            select u.id, u.email, u.full_name, u.status, u.platform_role, u.created_at, (select count(*) from memberships m where m.user_id = u.id)
            from users u where u.id = :id
            """).param("id", userId)
                .query((rs, i) -> new UserRow(rs.getObject(1, UUID.class), rs.getString(2), rs.getString(3), rs.getString(4), rs.getString(5), rs.getInt(7), rs.getTimestamp(6).toInstant())).single();
    }

    public List<Plan> plans() {
        access.requireAny();
        return jdbc.sql("select code, name, max_branches, max_employees, price_monthly, currency, active from subscription_plans order by code")
                .query((rs, i) -> new Plan(rs.getString(1), rs.getString(2), rs.getInt(3), rs.getInt(4), rs.getBigDecimal(5), rs.getString(6), rs.getBoolean(7))).list();
    }

    @Transactional
    public Plan updatePlan(String code, int maxBranches, int maxEmployees) {
        UUID actor = access.require(PlatformRole.SUPER_ADMIN);
        if (maxBranches < 1 || maxEmployees < 1) throw ApiException.badRequest("INVALID_LIMITS", "Limits must be at least 1");
        int n = jdbc.sql("update subscription_plans set max_branches = :b, max_employees = :e where code = :c")
                .param("b", maxBranches).param("e", maxEmployees).param("c", code).update();
        if (n == 0) throw ApiException.notFound("Plan");
        audit.log(null, actor, "ADMIN_PLAN_LIMITS_CHANGED", "PLAN", null, "{\"plan\":\"" + code + "\",\"maxBranches\":" + maxBranches + ",\"maxEmployees\":" + maxEmployees + "}");
        return plans().stream().filter(p -> p.code().equals(code)).findFirst().orElseThrow();
    }

    public Page<AuditRow> audit(UUID businessId, String action, int page, int size) {
        access.requireAny();
        int s = Math.min(Math.max(size, 1), 200), p = Math.max(page, 0);
        var rows = jdbc.sql("""
            select id, business_id, actor_user_id, action, entity_type, entity_id, created_at from audit_logs
            where (cast(:b as uuid) is null or business_id = :b) and (cast(:a as varchar) is null or action = :a)
            order by created_at desc limit :s offset :o
            """).param("b", businessId, java.sql.Types.OTHER).param("a", action, java.sql.Types.VARCHAR).param("s", s).param("o", p * s)
                .query((rs, i) -> new AuditRow(rs.getObject(1, UUID.class), rs.getObject(2, UUID.class), rs.getObject(3, UUID.class), rs.getString(4),
                        rs.getString(5), rs.getObject(6, UUID.class), rs.getTimestamp(7).toInstant())).list();
        return new Page<>(rows, p, s);
    }

    /** System job: plans whose period ended fall back to FREE (data is never deleted; limits apply to new additions only). */
    @Transactional
    public int downgradeExpiredPlans() {
        var expired = jdbc.sql("select id, plan_code from businesses where plan_expires_at is not null and plan_expires_at < now() and plan_code <> 'FREE' for update skip locked")
                .query((rs, i) -> new Object[]{rs.getObject(1, UUID.class), rs.getString(2)}).list();
        for (Object[] e : expired) {
            UUID id = (UUID) e[0];
            jdbc.sql("update businesses set plan_code = 'FREE', plan_expires_at = null, updated_at = now() where id = :id").param("id", id).update();
            event(id, (String) e[1], "FREE", "subscription period ended", null, null);
            audit.log(id, null, "SUBSCRIPTION_EXPIRED", "BUSINESS", id, null);
        }
        return expired.size();
    }

    private void event(UUID businessId, String from, String to, String reason, Instant expires, UUID actor) {
        jdbc.sql("insert into subscription_events (business_id, from_plan, to_plan, reason, expires_at, actor_user_id) values (:b,:f,:t,:r,:e,:a)")
                .param("b", businessId).param("f", from).param("t", to).param("r", reason, java.sql.Types.VARCHAR)
                .param("e", expires == null ? null : Timestamp.from(expires), java.sql.Types.TIMESTAMP).param("a", actor, java.sql.Types.OTHER).update();
    }

    private static BusinessRow row(java.sql.ResultSet rs) throws java.sql.SQLException {
        return new BusinessRow(rs.getObject("id", UUID.class), rs.getString("slug"), rs.getString("name"), rs.getString("business_type"),
                rs.getString("plan_code"), rs.getString("status"), rs.getBoolean("published"),
                rs.getTimestamp("plan_expires_at") == null ? null : rs.getTimestamp("plan_expires_at").toInstant(), rs.getTimestamp("created_at").toInstant());
    }
}
