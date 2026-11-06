package com.orleu.customers;

import com.orleu.customers.CustomerDtos.*;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1/businesses/{businessId}/customers")
public class CustomerController {
    public record ImportRequest(@jakarta.validation.constraints.NotNull String csv, boolean dryRun) {}

    private final CustomerService service;
    private final CustomerImportService importer;
    private final CustomerPrivacyService privacy;
    public CustomerController(CustomerService service, CustomerImportService importer, CustomerPrivacyService privacy) { this.service = service; this.importer = importer; this.privacy = privacy; }

    @PostMapping @ResponseStatus(HttpStatus.CREATED)
    public CustomerView create(@PathVariable UUID businessId, @Valid @RequestBody CustomerInput in) { return service.create(businessId, in); }

    @GetMapping
    public PageView<CustomerView> search(@PathVariable UUID businessId, @RequestParam(required = false) String q,
                                         @RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "20") int size) {
        return service.search(businessId, q, page, size);
    }

    @GetMapping("/{id}")
    public CustomerView get(@PathVariable UUID businessId, @PathVariable UUID id) { return service.get(businessId, id); }

    @PatchMapping("/{id}")
    public CustomerView update(@PathVariable UUID businessId, @PathVariable UUID id, @Valid @RequestBody UpdateCustomerRequest r) { return service.update(businessId, id, r); }

    @GetMapping("/{id}/profile")
    public CustomerProfile profile(@PathVariable UUID businessId, @PathVariable UUID id) { return service.profile(businessId, id); }

    @PostMapping("/{id}/block")
    public CustomerView block(@PathVariable UUID businessId, @PathVariable UUID id) { return service.setBlocked(businessId, id, true); }

    @PostMapping("/{id}/unblock")
    public CustomerView unblock(@PathVariable UUID businessId, @PathVariable UUID id) { return service.setBlocked(businessId, id, false); }

    /** CSV text in the JSON body (the clients read the file themselves). dryRun=true reports without changing anything. */
    @PostMapping("/import")
    public CustomerImportService.ImportResult importCsv(@PathVariable UUID businessId, @Valid @RequestBody ImportRequest r) { return importer.run(businessId, r.csv(), r.dryRun()); }

    /** Everything held about one customer, as a JSON download (audited). */
    @GetMapping("/{id}/export")
    public org.springframework.http.ResponseEntity<java.util.Map<String, Object>> export(@PathVariable UUID businessId, @PathVariable UUID id) {
        return org.springframework.http.ResponseEntity.ok()
                .cacheControl(org.springframework.http.CacheControl.noStore())
                .header("Content-Disposition", "attachment; filename=\"customer-" + id + ".json\"")
                .body(privacy.export(businessId, id));
    }

    /** Irreversibly removes the customer's personal data (bookings and the ledger stay, anonymous). Owner/admin only. */
    @PostMapping("/{id}/anonymize") @ResponseStatus(HttpStatus.NO_CONTENT)
    public void anonymize(@PathVariable UUID businessId, @PathVariable UUID id) { privacy.anonymize(businessId, id); }
}
