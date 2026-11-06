package com.orleu.support;

import com.orleu.admin.PlatformAccess;
import com.orleu.admin.PlatformRole;
import com.orleu.audit.AuditService;
import com.orleu.auth.CurrentUser;
import com.orleu.common.ApiException;
import com.orleu.tenancy.Permission;
import com.orleu.tenancy.TenantAccess;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.Set;
import java.util.UUID;

/**
 * Support tickets between a business (its owners/admins) and the platform team (SUPER_ADMIN, PLATFORM_SUPPORT).
 * Tenant side is scoped by business id; platform side is role-checked on every call. Analysts cannot read tickets
 * (they contain free text from customers' businesses).
 */
@Service
public class SupportService {
    private static final Set<String> CATEGORIES = Set.of("BILLING", "TECHNICAL", "ACCOUNT", "OTHER");
    private static final int MAX_OPEN_PER_BUSINESS = 20;

    public record TicketRow(UUID id, UUID businessId, String businessName, String subject, String category, String status,
                            String createdByEmail, Instant createdAt, Instant updatedAt) {}
    public record Message(UUID id, boolean fromPlatform, String authorName, String body, Instant createdAt) {}
    public record TicketDetail(TicketRow ticket, List<Message> messages) {}

    private final JdbcClient jdbc;
    private final TenantAccess tenant;
    private final PlatformAccess platform;
    private final AuditService audit;
    private final com.orleu.notifications.OutboxService outbox;

    public SupportService(JdbcClient jdbc, TenantAccess tenant, PlatformAccess platform, AuditService audit,
                          com.orleu.notifications.OutboxService outbox) {
        this.outbox = outbox; this.jdbc = jdbc; this.tenant = tenant; this.platform = platform; this.audit = audit;
    }

    private static final String ROW = """
        select t.id, t.business_id, b.name, t.subject, t.category, t.status, u.email, t.created_at, t.updated_at
        from support_tickets t join businesses b on b.id = t.business_id join users u on u.id = t.created_by
        """;

    private TicketRow row(java.sql.ResultSet rs) throws java.sql.SQLException {
        return new TicketRow(rs.getObject(1, UUID.class), rs.getObject(2, UUID.class), rs.getString(3), rs.getString(4), rs.getString(5),
                rs.getString(6), rs.getString(7), rs.getTimestamp(8).toInstant(), rs.getTimestamp(9).toInstant());
    }

    private List<Message> messages(UUID ticketId) {
        return jdbc.sql("""
            select m.id, m.from_platform, u.full_name, m.body, m.created_at from support_messages m join users u on u.id = m.author_user_id
            where m.ticket_id = :t order by m.created_at, m.id
            """).param("t", ticketId)
            .query((rs, i) -> new Message(rs.getObject(1, UUID.class), rs.getBoolean(2), rs.getString(3), rs.getString(4), rs.getTimestamp(5).toInstant())).list();
    }

    // ---------- business side ----------

    @Transactional
    public TicketDetail create(UUID businessId, String subject, String category, String body) {
        tenant.require(businessId, Permission.BUSINESS_MANAGE);
        String cat = category == null ? "OTHER" : category;
        if (!CATEGORIES.contains(cat)) throw ApiException.badRequest("INVALID_CATEGORY", "unknown category");
        int open = jdbc.sql("select count(*) from support_tickets where business_id = :b and status <> 'CLOSED'").param("b", businessId).query(Integer.class).single();
        if (open >= MAX_OPEN_PER_BUSINESS) throw ApiException.conflict("TOO_MANY_OPEN_TICKETS", "Please wait for your open requests to be answered or close some");
        UUID id = jdbc.sql("insert into support_tickets (business_id, created_by, subject, category) values (:b, :u, :s, :c) returning id")
                .param("b", businessId).param("u", CurrentUser.id()).param("s", subject.strip()).param("c", cat).query(UUID.class).single();
        addMessage(id, businessId, CurrentUser.id(), false, body);
        audit.log(businessId, CurrentUser.id(), "SUPPORT_TICKET_CREATED", "SUPPORT_TICKET", id, null);
        return detail(id, businessId);
    }

    @Transactional(readOnly = true)
    public List<TicketRow> list(UUID businessId) {
        tenant.require(businessId, Permission.BUSINESS_MANAGE);
        return jdbc.sql(ROW + " where t.business_id = :b order by t.updated_at desc limit 100").param("b", businessId).query((rs, i) -> row(rs)).list();
    }

    @Transactional(readOnly = true)
    public TicketDetail get(UUID businessId, UUID ticketId) {
        tenant.require(businessId, Permission.BUSINESS_MANAGE);
        return detail(ticketId, businessId);
    }

    @Transactional
    public TicketDetail reply(UUID businessId, UUID ticketId, String body) {
        tenant.require(businessId, Permission.BUSINESS_MANAGE);
        String status = lockStatus(ticketId, businessId);
        if ("CLOSED".equals(status)) throw ApiException.conflict("TICKET_CLOSED", "This request is closed; please open a new one");
        addMessage(ticketId, businessId, CurrentUser.id(), false, body);
        setStatus(ticketId, "OPEN");
        return detail(ticketId, businessId);
    }

    @Transactional
    public TicketDetail close(UUID businessId, UUID ticketId) {
        tenant.require(businessId, Permission.BUSINESS_MANAGE);
        lockStatus(ticketId, businessId);
        setStatus(ticketId, "CLOSED");
        audit.log(businessId, CurrentUser.id(), "SUPPORT_TICKET_CLOSED", "SUPPORT_TICKET", ticketId, null);
        return detail(ticketId, businessId);
    }

    // ---------- platform side ----------

    private UUID supportStaff() { return platform.require(PlatformRole.SUPER_ADMIN, PlatformRole.PLATFORM_SUPPORT); }

    @Transactional(readOnly = true)
    public List<TicketRow> adminList(String status, int page, int size) {
        supportStaff();
        int s = Math.min(Math.max(size, 1), 100), p = Math.max(page, 0);
        if (status != null && !Set.of("OPEN", "ANSWERED", "CLOSED").contains(status)) throw ApiException.badRequest("INVALID_STATUS", "unknown status");
        return jdbc.sql(ROW + " where (cast(:st as varchar) is null or t.status = :st) order by (t.status = 'OPEN') desc, t.updated_at desc limit :s offset :o")
                .param("st", status, java.sql.Types.VARCHAR).param("s", s).param("o", p * s).query((rs, i) -> row(rs)).list();
    }

    @Transactional(readOnly = true)
    public TicketDetail adminGet(UUID ticketId) {
        supportStaff();
        UUID biz = businessOf(ticketId);
        return detail(ticketId, biz);
    }

    @Transactional
    public TicketDetail adminReply(UUID ticketId, String body) {
        UUID staff = supportStaff();
        UUID biz = businessOf(ticketId);
        String status = lockStatus(ticketId, biz);
        if ("CLOSED".equals(status)) throw ApiException.conflict("TICKET_CLOSED", "Reopen the ticket before replying");
        addMessage(ticketId, biz, staff, true, body);
        setStatus(ticketId, "ANSWERED");
        audit.log(biz, staff, "SUPPORT_TICKET_REPLIED", "SUPPORT_TICKET", ticketId, null);
        outbox.publish(biz, "SUPPORT_REPLIED", null, "SUPPORT_REPLIED:" + ticketId + ":" + System.currentTimeMillis()); // shown as an in-app notification
        return detail(ticketId, biz);
    }

    @Transactional
    public TicketDetail adminSetStatus(UUID ticketId, String status) {
        UUID staff = supportStaff();
        if (!Set.of("OPEN", "CLOSED").contains(status)) throw ApiException.badRequest("INVALID_STATUS", "status must be OPEN or CLOSED");
        UUID biz = businessOf(ticketId);
        lockStatus(ticketId, biz);
        setStatus(ticketId, status);
        audit.log(biz, staff, "SUPPORT_TICKET_" + status, "SUPPORT_TICKET", ticketId, null);
        return detail(ticketId, biz);
    }

    // ---------- helpers ----------

    private UUID businessOf(UUID ticketId) {
        return jdbc.sql("select business_id from support_tickets where id = :id").param("id", ticketId).query(UUID.class).optional()
                .orElseThrow(() -> ApiException.notFound("Ticket"));
    }

    private String lockStatus(UUID ticketId, UUID businessId) {
        return jdbc.sql("select status from support_tickets where id = :id and business_id = :b for update").param("id", ticketId).param("b", businessId)
                .query(String.class).optional().orElseThrow(() -> ApiException.notFound("Ticket"));
    }

    private void setStatus(UUID ticketId, String status) {
        jdbc.sql("update support_tickets set status = :s, updated_at = now() where id = :id").param("s", status).param("id", ticketId).update();
    }

    private void addMessage(UUID ticketId, UUID businessId, UUID author, boolean fromPlatform, String body) {
        String text = body == null ? "" : body.strip();
        if (text.isEmpty() || text.length() > 4000) throw ApiException.badRequest("INVALID_MESSAGE", "message must be 1-4000 characters");
        jdbc.sql("insert into support_messages (ticket_id, business_id, author_user_id, from_platform, body) values (:t, :b, :a, :p, :body)")
                .param("t", ticketId).param("b", businessId).param("a", author).param("p", fromPlatform).param("body", text).update();
    }

    private TicketDetail detail(UUID ticketId, UUID businessId) {
        TicketRow t = jdbc.sql(ROW + " where t.id = :id and t.business_id = :b").param("id", ticketId).param("b", businessId)
                .query((rs, i) -> row(rs)).optional().orElseThrow(() -> ApiException.notFound("Ticket"));
        return new TicketDetail(t, messages(ticketId));
    }
}
