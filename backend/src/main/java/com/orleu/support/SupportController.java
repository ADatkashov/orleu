package com.orleu.support;

import com.orleu.support.SupportService.*;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
public class SupportController {
    public record CreateTicket(@NotBlank @Size(max = 200) String subject, @Size(max = 12) String category, @NotBlank @Size(max = 4000) String body) {}
    public record MessageRequest(@NotBlank @Size(max = 4000) String body) {}
    public record StatusRequest(@NotBlank String status) {}

    private final SupportService support;

    public SupportController(SupportService support) { this.support = support; }

    @PostMapping("/api/v1/businesses/{businessId}/support/tickets") @ResponseStatus(HttpStatus.CREATED)
    public TicketDetail create(@PathVariable UUID businessId, @Valid @RequestBody CreateTicket r) { return support.create(businessId, r.subject(), r.category(), r.body()); }

    @GetMapping("/api/v1/businesses/{businessId}/support/tickets")
    public List<TicketRow> list(@PathVariable UUID businessId) { return support.list(businessId); }

    @GetMapping("/api/v1/businesses/{businessId}/support/tickets/{id}")
    public TicketDetail get(@PathVariable UUID businessId, @PathVariable UUID id) { return support.get(businessId, id); }

    @PostMapping("/api/v1/businesses/{businessId}/support/tickets/{id}/messages")
    public TicketDetail reply(@PathVariable UUID businessId, @PathVariable UUID id, @Valid @RequestBody MessageRequest r) { return support.reply(businessId, id, r.body()); }

    @PostMapping("/api/v1/businesses/{businessId}/support/tickets/{id}/close")
    public TicketDetail close(@PathVariable UUID businessId, @PathVariable UUID id) { return support.close(businessId, id); }

    @GetMapping("/api/v1/admin/support/tickets")
    public List<TicketRow> adminList(@RequestParam(required = false) String status, @RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "50") int size) {
        return support.adminList(status, page, size);
    }

    @GetMapping("/api/v1/admin/support/tickets/{id}")
    public TicketDetail adminGet(@PathVariable UUID id) { return support.adminGet(id); }

    @PostMapping("/api/v1/admin/support/tickets/{id}/reply")
    public TicketDetail adminReply(@PathVariable UUID id, @Valid @RequestBody MessageRequest r) { return support.adminReply(id, r.body()); }

    @PostMapping("/api/v1/admin/support/tickets/{id}/status")
    public TicketDetail adminStatus(@PathVariable UUID id, @Valid @RequestBody StatusRequest r) { return support.adminSetStatus(id, r.status()); }
}
