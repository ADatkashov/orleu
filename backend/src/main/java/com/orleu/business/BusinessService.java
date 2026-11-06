package com.orleu.business;

import com.orleu.audit.AuditService;
import com.orleu.auth.CurrentUser;
import com.orleu.auth.UserRepository;
import com.orleu.business.BusinessDtos.*;
import com.orleu.common.ApiException;
import com.orleu.tenancy.*;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.DateTimeException;
import java.time.ZoneId;
import java.util.List;
import java.util.UUID;

@Service
public class BusinessService {
    private final BusinessRepository businesses;
    private final MembershipRepository memberships;
    private final UserRepository users;
    private final TenantAccess access;
    private final AuditService audit;
    private final JdbcClient jdbc;

    public BusinessService(BusinessRepository businesses, MembershipRepository memberships, UserRepository users,
                           TenantAccess access, AuditService audit, JdbcClient jdbc) {
        this.businesses = businesses;
        this.memberships = memberships;
        this.users = users;
        this.access = access;
        this.audit = audit;
        this.jdbc = jdbc;
    }

    @Transactional
    public BusinessView create(CreateBusinessRequest r) {
        UUID userId = CurrentUser.id();
        if (businesses.existsBySlug(r.slug())) {
            throw ApiException.conflict("SLUG_TAKEN", "This booking-page address is already taken");
        }
        Business b = new Business();
        b.setName(r.name().trim());
        b.setSlug(r.slug());
        b.setBusinessType(r.businessType());
        b.setDescription(r.description());
        if (r.country() != null) b.setCountry(r.country());
        b.setCity(r.city());
        b.setAddress(r.address());
        b.setPhone(r.phone());
        if (r.currency() != null) b.setCurrency(r.currency());
        if (r.timezone() != null) b.setTimezone(validZone(r.timezone()));
        try {
            businesses.saveAndFlush(b);
        } catch (org.springframework.dao.DataIntegrityViolationException e) {
            throw ApiException.conflict("SLUG_TAKEN", "This booking-page address is already taken");
        }
        Membership m = new Membership();
        m.setUserId(userId);
        m.setBusinessId(b.getId());
        m.setRole(BusinessRole.BUSINESS_OWNER);
        memberships.save(m);
        audit.log(b.getId(), userId, "BUSINESS_CREATED", "BUSINESS", b.getId(), null);
        return BusinessView.of(b);
    }

    public List<BusinessView> mine() {
        return memberships.findByUserIdAndStatus(CurrentUser.id(), "ACTIVE").stream()
                .map(m -> businesses.findById(m.getBusinessId()).orElse(null))
                .filter(java.util.Objects::nonNull).map(BusinessView::of).toList();
    }

    public BusinessView get(UUID businessId) {
        access.require(businessId, Permission.BOOKINGS_VIEW);
        return BusinessView.of(load(businessId));
    }

    @Transactional
    public BusinessView updateSettings(UUID businessId, UpdateSettingsRequest r) {
        access.require(businessId, Permission.BUSINESS_MANAGE);
        Business b = load(businessId);
        if (r.name() != null && !r.name().isBlank()) b.setName(r.name().trim());
        if (r.description() != null) b.setDescription(r.description());
        if (r.city() != null) b.setCity(r.city());
        if (r.address() != null) b.setAddress(r.address());
        if (r.depositPercent() != null) b.setDepositPercent(r.depositPercent());
        if (r.autoConfirm() != null) b.setAutoConfirm(r.autoConfirm());
        if (r.minNoticeMinutes() != null) b.setMinNoticeMinutes(r.minNoticeMinutes());
        if (r.maxAdvanceDays() != null) b.setMaxAdvanceDays(r.maxAdvanceDays());
        if (r.paymentHoldMinutes() != null) b.setPaymentHoldMinutes(r.paymentHoldMinutes());
        if (r.cancellationDeadlineHours() != null) b.setCancellationDeadlineHours(r.cancellationDeadlineHours());
        if (r.reminderHours() != null) b.setReminderHours(r.reminderHours());
        if (r.customerLocale() != null) b.setCustomerLocale(r.customerLocale());
        if (r.customerRetentionMonths() != null) {
            int m = r.customerRetentionMonths();
            if (m != 0 && m < 12) throw ApiException.badRequest("INVALID_RETENTION", "Retention must be 0 (off) or 12-120 months");
            b.setCustomerRetentionMonths(m == 0 ? null : m);
        }
        audit.log(businessId, CurrentUser.id(), "BUSINESS_SETTINGS_UPDATED", "BUSINESS", businessId, null);
        return BusinessView.of(b);
    }

    /** Publishing requires a bookable setup: branch with hours, an online service and an assigned employee. */
    @Transactional
    public BusinessView publish(UUID businessId, boolean publish) {
        access.require(businessId, Permission.BUSINESS_MANAGE);
        Business b = load(businessId);
        if (publish) {
            boolean ready = Boolean.TRUE.equals(jdbc.sql("""
                select exists (
                  select 1
                  from branches br
                  join branch_hours h on h.branch_id = br.id
                  join employee_branches eb on eb.branch_id = br.id
                  join employees e on e.id = eb.employee_id and e.active
                  join employee_services es on es.employee_id = e.id
                  join services s on s.id = es.service_id and s.active and s.online_bookable
                  where br.business_id = :b and br.active)
                """).param("b", businessId).query(Boolean.class).single());
            if (!ready) {
                throw ApiException.conflict("NOT_READY_TO_PUBLISH",
                        "Add a branch with working hours, an online service and an employee assigned to it first");
            }
        }
        b.setPublished(publish);
        b.setOnboardingStep(publish ? 10 : b.getOnboardingStep());
        audit.log(businessId, CurrentUser.id(), publish ? "BUSINESS_PUBLISHED" : "BUSINESS_UNPUBLISHED", "BUSINESS", businessId, null);
        return BusinessView.of(b);
    }

    @Transactional
    public MemberView addMember(UUID businessId, AddMemberRequest r) {
        access.require(businessId, Permission.STAFF_MANAGE);
        if (r.role() == BusinessRole.BUSINESS_OWNER) {
            throw ApiException.badRequest("INVALID_ROLE", "Ownership cannot be assigned through this endpoint");
        }
        var user = users.findByEmailIgnoreCase(r.email())
                .orElseThrow(() -> ApiException.notFound("User")); // invitations by e-mail are a later increment
        Membership m = memberships.findByUserIdAndBusinessId(user.getId(), businessId).orElseGet(Membership::new);
        if (m.getRole() == BusinessRole.BUSINESS_OWNER) {
            throw ApiException.badRequest("INVALID_ROLE", "The owner's role cannot be changed");
        }
        m.setUserId(user.getId());
        m.setBusinessId(businessId);
        m.setRole(r.role());
        m.setStatus("ACTIVE");
        memberships.save(m);
        audit.log(businessId, CurrentUser.id(), "MEMBER_ROLE_SET", "USER", user.getId(), "{\"role\":\"" + r.role() + "\"}");
        return new MemberView(user.getId(), user.getEmail(), user.getFullName(), m.getRole().name(), m.getStatus());
    }

    @Transactional
    public void deactivateMember(UUID businessId, UUID userId) {
        access.require(businessId, Permission.STAFF_MANAGE);
        Membership m = memberships.findByUserIdAndBusinessId(userId, businessId).orElseThrow(() -> ApiException.notFound("Member"));
        if (m.getRole() == BusinessRole.BUSINESS_OWNER) {
            throw ApiException.badRequest("INVALID_ROLE", "The owner cannot be deactivated");
        }
        m.setStatus("DEACTIVATED");
        audit.log(businessId, CurrentUser.id(), "MEMBER_DEACTIVATED", "USER", userId, null);
    }

    private Business load(UUID id) {
        return businesses.findById(id).orElseThrow(() -> ApiException.notFound("Business"));
    }

    static String validZone(String tz) {
        try { return ZoneId.of(tz).getId(); }
        catch (DateTimeException e) { throw ApiException.badRequest("INVALID_TIMEZONE", "Unknown timezone"); }
    }
}
