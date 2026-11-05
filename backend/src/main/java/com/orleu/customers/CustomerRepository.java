package com.orleu.customers;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;
import java.util.UUID;

public interface CustomerRepository extends JpaRepository<Customer, UUID> {
    Optional<Customer> findByIdAndBusinessId(UUID id, UUID businessId);
    Optional<Customer> findByBusinessIdAndPhone(UUID businessId, String phone);

    @Query("""
        select c from Customer c where c.businessId = :businessId
        and (:q is null or lower(c.fullName) like lower(concat('%', cast(:q as string), '%')) or c.phone like concat('%', cast(:q as string), '%'))
        order by c.fullName
        """)
    Page<Customer> search(@Param("businessId") UUID businessId, @Param("q") String q, Pageable pageable);
}
