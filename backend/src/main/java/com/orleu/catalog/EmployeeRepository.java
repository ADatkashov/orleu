package com.orleu.catalog;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

/** Tenant-scoped: there is intentionally no findById without a business id in use. */
public interface EmployeeRepository extends JpaRepository<Employee, UUID> {
    Optional<Employee> findByIdAndBusinessId(UUID id, UUID businessId);
    List<Employee> findByBusinessIdOrderByDisplayName(UUID businessId);
}
