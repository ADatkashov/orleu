package com.orleu.customers;

import com.orleu.audit.AuditService;
import com.orleu.auth.CurrentUser;
import com.orleu.common.ApiException;
import com.orleu.customers.CustomerDtos.*;
import com.orleu.tenancy.Permission;
import com.orleu.tenancy.TenantAccess;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

@Service
public class CustomerService {
    private final CustomerRepository customers;
    private final TenantAccess access;
    private final AuditService audit;

    public CustomerService(CustomerRepository customers, TenantAccess access, AuditService audit) {
        this.customers = customers; this.access = access; this.audit = audit;
    }

    @Transactional
    public CustomerView create(UUID businessId, CustomerInput in) {
        access.require(businessId, Permission.CUSTOMERS_MANAGE);
        if (customers.findByBusinessIdAndPhone(businessId, in.phone()).isPresent()) {
            throw ApiException.conflict("CUSTOMER_EXISTS", "A customer with this phone already exists");
        }
        return CustomerView.of(upsert(businessId, in));
    }

    public PageView<CustomerView> search(UUID businessId, String q, int page, int size) {
        access.require(businessId, Permission.CUSTOMERS_VIEW);
        var p = customers.search(businessId, q == null || q.isBlank() ? null : q.trim(),
                PageRequest.of(Math.max(page, 0), Math.min(Math.max(size, 1), 100)));
        return new PageView<>(p.getContent().stream().map(CustomerView::of).toList(), p.getNumber(), p.getSize(), p.getTotalElements());
    }

    public CustomerView get(UUID businessId, UUID id) {
        access.require(businessId, Permission.CUSTOMERS_VIEW);
        return CustomerView.of(customers.findByIdAndBusinessId(id, businessId).orElseThrow(() -> ApiException.notFound("Customer")));
    }

    @Transactional
    public CustomerView setBlocked(UUID businessId, UUID id, boolean blocked) {
        access.require(businessId, Permission.CUSTOMERS_MANAGE);
        Customer c = customers.findByIdAndBusinessId(id, businessId).orElseThrow(() -> ApiException.notFound("Customer"));
        c.setBlocked(blocked);
        audit.log(businessId, CurrentUser.id(), blocked ? "CUSTOMER_BLOCKED" : "CUSTOMER_UNBLOCKED", "CUSTOMER", id, null);
        return CustomerView.of(c);
    }

    /** Finds a customer by phone within the business or creates one. No authorization: callers must have done it. */
    @Transactional
    public Customer upsert(UUID businessId, CustomerInput in) {
        Customer c = customers.findByBusinessIdAndPhone(businessId, in.phone()).orElseGet(() -> {
            Customer n = new Customer();
            n.setBusinessId(businessId);
            n.setPhone(in.phone());
            return n;
        });
        if (c.getId() == null) {
            c.setFullName(in.fullName().trim());
            c.setEmail(in.email());
            c.setNotes(in.notes());
            c.setMarketingOptIn(Boolean.TRUE.equals(in.marketingOptIn()));
            return customers.save(c);
        }
        return c; // existing customers are not silently overwritten by (possibly anonymous) public input
    }
}
