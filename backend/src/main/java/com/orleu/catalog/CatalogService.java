package com.orleu.catalog;

import com.orleu.audit.AuditService;
import com.orleu.auth.CurrentUser;
import com.orleu.business.Business;
import com.orleu.business.BusinessRepository;
import com.orleu.catalog.CatalogDtos.*;
import com.orleu.catalog.BranchRepository;
import com.orleu.catalog.EmployeeRepository;
import com.orleu.catalog.ServiceRepository;
import com.orleu.common.ApiException;
import com.orleu.subscriptions.EntitlementService;
import com.orleu.tenancy.Permission;
import com.orleu.tenancy.TenantAccess;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.ZoneId;
import java.util.HashSet;
import java.util.List;
import java.util.UUID;

@Service
public class CatalogService {
    private final TenantAccess access;
    private final BusinessRepository businesses;
    private final BranchRepository branches;
    private final ServiceRepository services;
    private final EmployeeRepository employees;
    private final EntitlementService entitlements;
    private final AuditService audit;
    private final JdbcClient jdbc;

    public CatalogService(TenantAccess access, BusinessRepository businesses, BranchRepository branches,
                          ServiceRepository services, EmployeeRepository employees, EntitlementService entitlements,
                          AuditService audit, JdbcClient jdbc) {
        this.access = access; this.businesses = businesses; this.branches = branches; this.services = services;
        this.employees = employees; this.entitlements = entitlements; this.audit = audit; this.jdbc = jdbc;
    }

    // ---- branches ----
    @Transactional
    public BranchView createBranch(UUID businessId, CreateBranchRequest r) {
        access.require(businessId, Permission.CATALOG_MANAGE);
        entitlements.assertCanAddBranch(businessId);
        Business biz = businesses.findById(businessId).orElseThrow(() -> ApiException.notFound("Business"));
        Branch b = new Branch();
        b.setBusinessId(businessId);
        b.setName(r.name().trim());
        b.setAddress(r.address());
        b.setPhone(r.phone());
        b.setTimezone(r.timezone() == null ? biz.getTimezone() : zone(r.timezone()));
        branches.save(b);
        audit.log(businessId, CurrentUser.id(), "BRANCH_CREATED", "BRANCH", b.getId(), null);
        return BranchView.of(b, List.of());
    }

    public List<BranchView> listBranches(UUID businessId) {
        access.require(businessId, Permission.BOOKINGS_VIEW);
        var hours = new java.util.HashMap<UUID, List<HourRange>>();
        jdbc.sql("""
            select h.branch_id, h.day_of_week, h.open_time, h.close_time from branch_hours h
            join branches b on b.id = h.branch_id where b.business_id = :b order by h.day_of_week
            """).param("b", businessId).query((rs, i) -> {
                hours.computeIfAbsent(rs.getObject(1, UUID.class), k -> new java.util.ArrayList<>())
                        .add(new HourRange(rs.getInt(2), rs.getObject(3, java.time.LocalTime.class), rs.getObject(4, java.time.LocalTime.class)));
                return 0;
            }).list();
        return branches.findByBusinessIdOrderByName(businessId).stream()
                .map(b -> BranchView.of(b, hours.getOrDefault(b.getId(), List.of()))).toList();
    }

    @Transactional
    public void setHours(UUID businessId, UUID branchId, SetHoursRequest r) {
        access.require(businessId, Permission.CATALOG_MANAGE);
        branches.findByIdAndBusinessId(branchId, businessId).orElseThrow(() -> ApiException.notFound("Branch"));
        var seen = new HashSet<Integer>();
        for (HourRange h : r.hours()) {
            if (!h.close().isAfter(h.open())) throw ApiException.badRequest("INVALID_HOURS", "close must be after open");
            if (!seen.add(h.dayOfWeek())) throw ApiException.badRequest("INVALID_HOURS", "duplicate day " + h.dayOfWeek());
        }
        jdbc.sql("delete from branch_hours where branch_id = :b").param("b", branchId).update();
        for (HourRange h : r.hours()) {
            jdbc.sql("insert into branch_hours (branch_id, day_of_week, open_time, close_time) values (:b,:d,:o,:c)")
                    .param("b", branchId).param("d", h.dayOfWeek()).param("o", h.open()).param("c", h.close()).update();
        }
        audit.log(businessId, CurrentUser.id(), "BRANCH_HOURS_SET", "BRANCH", branchId, null);
    }

    @Transactional
    public BranchView updateBranch(UUID businessId, UUID branchId, UpdateBranchRequest r) {
        access.require(businessId, Permission.CATALOG_MANAGE);
        Branch b = branches.findByIdAndBusinessId(branchId, businessId).orElseThrow(() -> ApiException.notFound("Branch"));
        if (Boolean.TRUE.equals(r.active()) && !b.isActive()) entitlements.assertCanAddBranch(businessId); // reactivation counts against the plan
        if (r.name() != null) { if (r.name().isBlank()) throw ApiException.badRequest("INVALID_NAME", "Name cannot be blank"); b.setName(r.name().trim()); }
        if (r.address() != null) b.setAddress(r.address());
        if (r.phone() != null) b.setPhone(r.phone());
        if (r.active() != null) b.setActive(r.active());
        audit.log(businessId, CurrentUser.id(), r.active() != null && !r.active() ? "BRANCH_DEACTIVATED" : "BRANCH_UPDATED", "BRANCH", branchId, null);
        return BranchView.of(b);
    }

    // ---- services ----
    @Transactional
    public ServiceView createService(UUID businessId, CreateServiceRequest r) {
        access.require(businessId, Permission.CATALOG_MANAGE);
        ServiceOffering s = new ServiceOffering();
        s.setBusinessId(businessId);
        s.setName(r.name().trim());
        s.setDescription(r.description());
        s.setCategory(r.category());
        s.setDurationMinutes(r.durationMinutes());
        s.setBufferMinutes(r.bufferMinutes() == null ? 0 : r.bufferMinutes());
        s.setPrice(com.orleu.common.Money.scale(r.price()));
        s.setDepositPercent(r.depositPercent());
        if (r.onlineBookable() != null) s.setOnlineBookable(r.onlineBookable());
        services.save(s);
        audit.log(businessId, CurrentUser.id(), "SERVICE_CREATED", "SERVICE", s.getId(), null);
        return ServiceView.of(s);
    }

    /** Existing bookings keep the price/duration they were made with; changes apply to new bookings only. */
    @Transactional
    public ServiceView updateService(UUID businessId, UUID serviceId, UpdateServiceRequest r) {
        access.require(businessId, Permission.CATALOG_MANAGE);
        ServiceOffering s = services.findByIdAndBusinessId(serviceId, businessId).orElseThrow(() -> ApiException.notFound("Service"));
        if (r.name() != null) { if (r.name().isBlank()) throw ApiException.badRequest("INVALID_NAME", "Name cannot be blank"); s.setName(r.name().trim()); }
        if (r.description() != null) s.setDescription(r.description());
        if (r.category() != null) s.setCategory(r.category());
        if (r.durationMinutes() != null) s.setDurationMinutes(r.durationMinutes());
        if (r.bufferMinutes() != null) s.setBufferMinutes(r.bufferMinutes());
        if (r.price() != null) s.setPrice(com.orleu.common.Money.scale(r.price()));
        if (Boolean.TRUE.equals(r.useBusinessDeposit())) s.setDepositPercent(null);
        else if (r.depositPercent() != null) s.setDepositPercent(r.depositPercent());
        if (r.onlineBookable() != null) s.setOnlineBookable(r.onlineBookable());
        if (r.active() != null) s.setActive(r.active());
        audit.log(businessId, CurrentUser.id(), r.active() != null && !r.active() ? "SERVICE_DEACTIVATED" : "SERVICE_UPDATED", "SERVICE", serviceId, null);
        return ServiceView.of(s);
    }

    public List<ServiceView> listServices(UUID businessId) {
        access.require(businessId, Permission.BOOKINGS_VIEW);
        return services.findByBusinessIdOrderByName(businessId).stream().map(ServiceView::of).toList();
    }

    // ---- employees ----
    @Transactional
    public EmployeeView createEmployee(UUID businessId, CreateEmployeeRequest r) {
        access.require(businessId, Permission.STAFF_MANAGE);
        entitlements.assertCanAddEmployee(businessId);
        Employee e = new Employee();
        e.setBusinessId(businessId);
        e.setDisplayName(r.displayName().trim());
        employees.save(e);
        audit.log(businessId, CurrentUser.id(), "EMPLOYEE_CREATED", "EMPLOYEE", e.getId(), null);
        return view(e);
    }

    /** Deactivation removes the specialist from availability immediately; their existing bookings stay and must be handled by staff. */
    @Transactional
    public EmployeeView updateEmployee(UUID businessId, UUID employeeId, UpdateEmployeeRequest r) {
        access.require(businessId, Permission.STAFF_MANAGE);
        Employee e = employees.findByIdAndBusinessId(employeeId, businessId).orElseThrow(() -> ApiException.notFound("Employee"));
        if (Boolean.TRUE.equals(r.active()) && !e.isActive()) entitlements.assertCanAddEmployee(businessId);
        if (r.displayName() != null) { if (r.displayName().isBlank()) throw ApiException.badRequest("INVALID_NAME", "Name cannot be blank"); e.setDisplayName(r.displayName().trim()); }
        if (r.active() != null) e.setActive(r.active());
        audit.log(businessId, CurrentUser.id(), r.active() != null && !r.active() ? "EMPLOYEE_DEACTIVATED" : "EMPLOYEE_UPDATED", "EMPLOYEE", employeeId, null);
        return view(e);
    }

    public List<EmployeeView> listEmployees(UUID businessId) {
        access.require(businessId, Permission.BOOKINGS_VIEW);
        return employees.findByBusinessIdOrderByDisplayName(businessId).stream().map(this::view).toList();
    }

    @Transactional
    public EmployeeView setAssignments(UUID businessId, UUID employeeId, AssignmentsRequest r) {
        access.require(businessId, Permission.STAFF_MANAGE);
        Employee e = employees.findByIdAndBusinessId(employeeId, businessId).orElseThrow(() -> ApiException.notFound("Employee"));
        // Every referenced id must belong to THIS business; foreign ids are reported as not found.
        for (UUID id : r.branchIds()) branches.findByIdAndBusinessId(id, businessId).orElseThrow(() -> ApiException.notFound("Branch"));
        for (UUID id : r.serviceIds()) services.findByIdAndBusinessId(id, businessId).orElseThrow(() -> ApiException.notFound("Service"));
        jdbc.sql("delete from employee_branches where employee_id = :e").param("e", employeeId).update();
        jdbc.sql("delete from employee_services where employee_id = :e").param("e", employeeId).update();
        for (UUID id : new HashSet<>(r.branchIds())) {
            jdbc.sql("insert into employee_branches (employee_id, branch_id, business_id) values (:e,:x,:b)")
                    .param("e", employeeId).param("x", id).param("b", businessId).update();
        }
        for (UUID id : new HashSet<>(r.serviceIds())) {
            jdbc.sql("insert into employee_services (employee_id, service_id, business_id) values (:e,:x,:b)")
                    .param("e", employeeId).param("x", id).param("b", businessId).update();
        }
        audit.log(businessId, CurrentUser.id(), "EMPLOYEE_ASSIGNMENTS_SET", "EMPLOYEE", employeeId, null);
        return view(e);
    }

    @Transactional
    public void addTimeOff(UUID businessId, UUID employeeId, TimeOffRequest r) {
        access.require(businessId, Permission.STAFF_MANAGE);
        employees.findByIdAndBusinessId(employeeId, businessId).orElseThrow(() -> ApiException.notFound("Employee"));
        if (!r.endsAt().isAfter(r.startsAt())) throw ApiException.badRequest("INVALID_RANGE", "endsAt must be after startsAt");
        jdbc.sql("insert into employee_time_off (business_id, employee_id, starts_at, ends_at, reason) values (:b,:e,:s,:en,:r)")
                .param("b", businessId).param("e", employeeId).param("s", java.sql.Timestamp.from(r.startsAt()))
                .param("en", java.sql.Timestamp.from(r.endsAt())).param("r", r.reason()).update();
    }

    public EmployeeView view(Employee e) {
        List<UUID> bs = jdbc.sql("select branch_id from employee_branches where employee_id = :e").param("e", e.getId()).query(UUID.class).list();
        List<UUID> ss = jdbc.sql("select service_id from employee_services where employee_id = :e").param("e", e.getId()).query(UUID.class).list();
        return new EmployeeView(e.getId(), e.getDisplayName(), e.isActive(), bs, ss);
    }

    private static String zone(String tz) {
        try { return ZoneId.of(tz).getId(); }
        catch (java.time.DateTimeException ex) { throw ApiException.badRequest("INVALID_TIMEZONE", "Unknown timezone"); }
    }
}
