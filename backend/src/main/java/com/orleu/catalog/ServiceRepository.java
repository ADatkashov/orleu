package com.orleu.catalog;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

/** Tenant-scoped: there is intentionally no findById without a business id in use. */
public interface ServiceRepository extends JpaRepository<ServiceOffering, UUID> {
    Optional<ServiceOffering> findByIdAndBusinessId(UUID id, UUID businessId);
    List<ServiceOffering> findByBusinessIdOrderByName(UUID businessId);
    List<ServiceOffering> findByBusinessIdAndActiveTrueAndOnlineBookableTrueOrderByName(UUID businessId);
}
