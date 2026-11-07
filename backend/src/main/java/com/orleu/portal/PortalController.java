package com.orleu.portal;

import com.orleu.portal.PortalService.*;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

/** Public API (no business login): the portal session token travels in the X-Portal-Token header. All responses are no-store. */
@RestController
@RequestMapping("/api/v1/public/businesses/{slug}/portal")
public class PortalController {
    public record CodeRequest(@NotBlank @Size(max = 30) String phone) {}
    public record VerifyRequest(@NotBlank @Size(max = 30) String phone, @NotBlank @Size(max = 10) String code) {}

    private final PortalService service;
    public PortalController(PortalService service) { this.service = service; }

    private static <T> ResponseEntity<T> noStore(HttpStatus s, T body) { return ResponseEntity.status(s).cacheControl(CacheControl.noStore()).body(body); }

    /** 202 whether or not a code was sent. */
    @PostMapping("/code")
    public ResponseEntity<Void> code(@PathVariable String slug, @Valid @RequestBody CodeRequest r) {
        service.requestCode(slug, r.phone());
        return ResponseEntity.accepted().cacheControl(CacheControl.noStore()).build();
    }

    @PostMapping("/verify")
    public ResponseEntity<Session> verify(@PathVariable String slug, @Valid @RequestBody VerifyRequest r) { return noStore(HttpStatus.OK, service.verify(slug, r.phone(), r.code())); }

    @GetMapping("/me")
    public ResponseEntity<Me> me(@PathVariable String slug, @RequestHeader(value = "X-Portal-Token", required = false) String token) { return noStore(HttpStatus.OK, service.me(slug, token)); }

    @PostMapping("/bookings/{id}/cancel")
    public ResponseEntity<BookingRow> cancel(@PathVariable String slug, @RequestHeader(value = "X-Portal-Token", required = false) String token, @PathVariable UUID id) { return noStore(HttpStatus.OK, service.cancel(slug, token, id)); }

    @PostMapping("/logout") @ResponseStatus(HttpStatus.NO_CONTENT)
    public void logout(@RequestHeader(value = "X-Portal-Token", required = false) String token) { service.logout(token); }
}
