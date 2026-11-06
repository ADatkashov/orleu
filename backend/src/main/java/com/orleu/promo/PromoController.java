package com.orleu.promo;

import com.orleu.promo.PromoService.*;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/businesses/{businessId}/promo-codes")
public class PromoController {
    private final PromoService service;
    public PromoController(PromoService service) { this.service = service; }

    @GetMapping public List<PromoView> list(@PathVariable UUID businessId) { return service.list(businessId); }

    @PostMapping @ResponseStatus(HttpStatus.CREATED)
    public PromoView create(@PathVariable UUID businessId, @RequestBody PromoRequest r) { return service.create(businessId, r); }

    @PatchMapping("/{id}")
    public void toggle(@PathVariable UUID businessId, @PathVariable UUID id, @RequestBody PromoRequest r) { service.setActive(businessId, id, Boolean.TRUE.equals(r.active())); }
}
