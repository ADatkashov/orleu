package com.orleu.admin;

import com.orleu.admin.AdminService.*;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/admin")
public class AdminController {
    public record SetPlanRequest(@NotBlank String planCode, Instant expiresAt, @NotBlank @Size(max = 300) String reason) {}
    public record SuspendRequest(@Size(max = 300) String reason) {}
    public record PlanLimitsRequest(@NotNull Integer maxBranches, @NotNull Integer maxEmployees) {}

    public record MeView(PlatformRole role, boolean canModify) {}

    private final AdminService service;
    private final PlatformAccess access;
    public AdminController(AdminService service, PlatformAccess access) { this.service = service; this.access = access; }

    /** Lets the admin UI show only the actions the caller may perform (the server still enforces every one of them). */
    @GetMapping("/me")
    public MeView me() {
        PlatformRole r = access.currentRole();
        return new MeView(r, r == PlatformRole.SUPER_ADMIN);
    }

    @GetMapping("/businesses")
    public Page<BusinessRow> businesses(@RequestParam(required = false) String q, @RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "20") int size) {
        return service.businesses(q, page, size);
    }
    @GetMapping("/businesses/{id}")
    public BusinessDetail business(@PathVariable UUID id) { return service.business(id); }

    @PostMapping("/businesses/{id}/plan")
    public BusinessDetail setPlan(@PathVariable UUID id, @Valid @RequestBody SetPlanRequest r) { return service.setPlan(id, r.planCode(), r.expiresAt(), r.reason()); }

    @PostMapping("/businesses/{id}/suspend")
    public BusinessDetail suspend(@PathVariable UUID id, @Valid @RequestBody SuspendRequest r) { return service.setSuspended(id, true, r.reason()); }

    @PostMapping("/businesses/{id}/reactivate")
    public BusinessDetail reactivate(@PathVariable UUID id) { return service.setSuspended(id, false, null); }

    @GetMapping("/users")
    public Page<UserRow> users(@RequestParam(required = false) String q, @RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "20") int size) {
        return service.users(q, page, size);
    }

    @PostMapping("/users/{id}/disable")
    public UserRow disableUser(@PathVariable UUID id) { return service.setUserDisabled(id, true); }

    @PostMapping("/users/{id}/enable")
    public UserRow enableUser(@PathVariable UUID id) { return service.setUserDisabled(id, false); }

    @GetMapping("/plans")
    public List<Plan> plans() { return service.plans(); }

    @PutMapping("/plans/{code}")
    public Plan updatePlan(@PathVariable String code, @Valid @RequestBody PlanLimitsRequest r) { return service.updatePlan(code, r.maxBranches(), r.maxEmployees()); }

    @GetMapping("/audit-logs")
    public Page<AuditRow> audit(@RequestParam(required = false) UUID businessId, @RequestParam(required = false) String action,
                                @RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "50") int size) {
        return service.audit(businessId, action, page, size);
    }
}
