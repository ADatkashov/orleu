package com.orleu.publicapi;

import com.orleu.bookings.BookingService;
import org.springframework.web.bind.annotation.*;

/**
 * Self-service for guests: the unguessable token from the booking confirmation IS the credential.
 * Responses contain no personal data of the customer.
 */
@RestController
@RequestMapping("/api/v1/public/manage/{token}")
public class PublicManageController {
    private final BookingService bookings;

    public PublicManageController(BookingService bookings) { this.bookings = bookings; }

    @GetMapping
    public BookingService.ManageView view(@PathVariable String token) { return bookings.manageView(token); }

    @PostMapping("/cancel")
    public BookingService.ManageView cancel(@PathVariable String token) { return bookings.cancelByCustomer(token); }
}
