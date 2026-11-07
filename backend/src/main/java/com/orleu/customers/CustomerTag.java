package com.orleu.customers;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.io.Serializable;
import java.util.UUID;

/** Read-only mapping used by the customer search filter; tags are written with SQL in {@link CustomerService}. */
@Entity @Table(name = "customer_tags") @IdClass(CustomerTag.Key.class)
@Getter @NoArgsConstructor
public class CustomerTag {
    public record Key(UUID customerId, String tag) implements Serializable {}
    @Id @Column(name = "customer_id", insertable = false, updatable = false) private UUID customerId;
    @Id @Column(insertable = false, updatable = false) private String tag;
    @Column(name = "business_id", insertable = false, updatable = false) private UUID businessId;
}
