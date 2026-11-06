package com.orleu.reviews;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
public class ReviewController {
    public record ReviewRequest(@Min(1) @Max(5) int rating, @Size(max = 1000) String comment) {}

    private final ReviewService reviews;

    public ReviewController(ReviewService reviews) { this.reviews = reviews; }

    /** Guest: the unguessable manage token from the booking confirmation is the credential. */
    @PostMapping("/api/v1/public/manage/{token}/review") @ResponseStatus(HttpStatus.CREATED)
    public void submit(@PathVariable String token, @Valid @RequestBody ReviewRequest r) { reviews.submit(token, r.rating(), r.comment()); }

    @GetMapping("/api/v1/businesses/{businessId}/reviews")
    public List<ReviewService.ReviewRow> list(@PathVariable UUID businessId) { return reviews.list(businessId); }

    @GetMapping("/api/v1/businesses/{businessId}/reviews/summary")
    public ReviewService.Summary summary(@PathVariable UUID businessId) { return reviews.summary(businessId); }
}
