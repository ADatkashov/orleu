package com.orleu.bookings;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
public class BookingExpiryJob {
    private static final Logger log = LoggerFactory.getLogger(BookingExpiryJob.class);
    private final BookingService bookings;

    public BookingExpiryJob(BookingService bookings) { this.bookings = bookings; }

    @Scheduled(fixedDelayString = "${orleu.jobs.expiry-interval:PT1M}")
    public void run() {
        try {
            int n = bookings.expireStaleHolds();
            if (n > 0) log.info("Expired {} unpaid booking holds", n);
        } catch (Exception e) {
            log.error("Hold expiry failed", e); // next run retries; never crashes the scheduler
        }
    }
}
