package com.orleu.customers;

import com.orleu.customers.CustomerDtos.*;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1/businesses/{businessId}/customers")
public class CustomerController {
    private final CustomerService service;
    public CustomerController(CustomerService service) { this.service = service; }

    @PostMapping @ResponseStatus(HttpStatus.CREATED)
    public CustomerView create(@PathVariable UUID businessId, @Valid @RequestBody CustomerInput in) { return service.create(businessId, in); }

    @GetMapping
    public PageView<CustomerView> search(@PathVariable UUID businessId, @RequestParam(required = false) String q,
                                         @RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "20") int size) {
        return service.search(businessId, q, page, size);
    }

    @GetMapping("/{id}")
    public CustomerView get(@PathVariable UUID businessId, @PathVariable UUID id) { return service.get(businessId, id); }

    @PostMapping("/{id}/block")
    public CustomerView block(@PathVariable UUID businessId, @PathVariable UUID id) { return service.setBlocked(businessId, id, true); }

    @PostMapping("/{id}/unblock")
    public CustomerView unblock(@PathVariable UUID businessId, @PathVariable UUID id) { return service.setBlocked(businessId, id, false); }
}
