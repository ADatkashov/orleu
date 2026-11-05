package com.orleu.bookings;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;
import java.util.UUID;

public interface BookingRepository extends JpaRepository<Booking, UUID> {
    Optional<Booking> findByIdAndBusinessId(UUID id, UUID businessId);
}
