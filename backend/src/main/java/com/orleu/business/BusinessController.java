package com.orleu.business;

import com.orleu.business.BusinessDtos.*;
import com.orleu.subscriptions.EntitlementService;
import com.orleu.tenancy.Permission;
import com.orleu.tenancy.TenantAccess;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/businesses")
public class BusinessController {
    private final BusinessService service;
    private final EntitlementService entitlements;
    private final TenantAccess access;

    public BusinessController(BusinessService service, EntitlementService entitlements, TenantAccess access) {
        this.service = service;
        this.entitlements = entitlements;
        this.access = access;
    }

    @PostMapping @ResponseStatus(HttpStatus.CREATED)
    public BusinessView create(@Valid @RequestBody CreateBusinessRequest r) { return service.create(r); }

    @GetMapping
    public List<BusinessView> mine() { return service.mine(); }

    @GetMapping("/{businessId}")
    public BusinessView get(@PathVariable UUID businessId) { return service.get(businessId); }

    @PatchMapping("/{businessId}/settings")
    public BusinessView settings(@PathVariable UUID businessId, @Valid @RequestBody UpdateSettingsRequest r) {
        return service.updateSettings(businessId, r);
    }

    @PostMapping("/{businessId}/publish")
    public BusinessView publish(@PathVariable UUID businessId) { return service.publish(businessId, true); }

    @PostMapping("/{businessId}/unpublish")
    public BusinessView unpublish(@PathVariable UUID businessId) { return service.publish(businessId, false); }

    @PostMapping("/{businessId}/members") @ResponseStatus(HttpStatus.CREATED)
    public MemberView addMember(@PathVariable UUID businessId, @Valid @RequestBody AddMemberRequest r) {
        return service.addMember(businessId, r);
    }

    @DeleteMapping("/{businessId}/members/{userId}") @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deactivate(@PathVariable UUID businessId, @PathVariable UUID userId) {
        service.deactivateMember(businessId, userId);
    }

    @GetMapping("/{businessId}/subscription")
    public EntitlementService.Usage subscription(@PathVariable UUID businessId) {
        access.require(businessId, Permission.BOOKINGS_VIEW);
        return entitlements.usage(businessId);
    }
}
