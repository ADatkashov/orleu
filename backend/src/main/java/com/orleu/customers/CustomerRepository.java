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
        and (:tag is null or exists (select 1 from CustomerTag t where t.customerId = c.id and t.tag = :tag))
        order by c.fullName
        """)
    Page<Customer> search(@Param("businessId") UUID businessId, @Param("q") String q, @Param("tag") String tag, Pageable pageable);
}
