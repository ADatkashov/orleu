package com.orleu.tenancy;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface MembershipRepository extends JpaRepository<Membership, UUID> {
    Optional<Membership> findByUserIdAndBusinessIdAndStatus(UUID userId, UUID businessId, String status);
    List<Membership> findByUserIdAndStatus(UUID userId, String status);
    List<Membership> findByBusinessId(UUID businessId);
    Optional<Membership> findByUserIdAndBusinessId(UUID userId, UUID businessId);
}
