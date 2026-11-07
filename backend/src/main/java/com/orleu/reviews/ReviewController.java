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

    public record ReplyRequest(@NotBlank @Size(max = 1000) String text) {}
    public record HideRequest(@NotBlank @Size(min = 5, max = 300) String reason) {}

    private final ReviewService reviews;

    public ReviewController(ReviewService reviews) { this.reviews = reviews; }

    /** Guest: the unguessable manage token from the booking confirmation is the credential. */
    @PostMapping("/api/v1/public/manage/{token}/review") @ResponseStatus(HttpStatus.CREATED)
    public void submit(@PathVariable String token, @Valid @RequestBody ReviewRequest r) { reviews.submit(token, r.rating(), r.comment()); }

    @GetMapping("/api/v1/businesses/{businessId}/reviews")
    public List<ReviewService.ReviewRow> list(@PathVariable UUID businessId) { return reviews.list(businessId); }

    @GetMapping("/api/v1/businesses/{businessId}/reviews/summary")
    public ReviewService.Summary summary(@PathVariable UUID businessId) { return reviews.summary(businessId); }

    /** Public reply of the business; visible to the guest on their booking link. */
    @PutMapping("/api/v1/businesses/{businessId}/reviews/{id}/reply")
    public ReviewService.ReviewRow reply(@PathVariable UUID businessId, @PathVariable UUID id, @Valid @RequestBody ReplyRequest r) { return reviews.reply(businessId, id, r.text()); }

    @DeleteMapping("/api/v1/businesses/{businessId}/reviews/{id}/reply")
    public ReviewService.ReviewRow deleteReply(@PathVariable UUID businessId, @PathVariable UUID id) { return reviews.deleteReply(businessId, id); }

    @GetMapping("/api/v1/admin/reviews")
    public List<ReviewService.AdminReviewRow> adminList(@RequestParam(defaultValue = "false") boolean hidden, @RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "50") int size) {
        return reviews.adminList(hidden, page, size);
    }

    @PostMapping("/api/v1/admin/reviews/{id}/hide") @ResponseStatus(HttpStatus.NO_CONTENT)
    public void hide(@PathVariable UUID id, @Valid @RequestBody HideRequest r) { reviews.hide(id, r.reason()); }

    @PostMapping("/api/v1/admin/reviews/{id}/unhide") @ResponseStatus(HttpStatus.NO_CONTENT)
    public void unhide(@PathVariable UUID id) { reviews.unhide(id); }
}
