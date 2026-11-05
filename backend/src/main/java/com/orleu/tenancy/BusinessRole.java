package com.orleu.tenancy;

import java.util.EnumSet;
import java.util.Set;

import static com.orleu.tenancy.Permission.*;

/** Business-scoped roles. A user may hold different roles in different businesses. */
public enum BusinessRole {
    BUSINESS_OWNER(EnumSet.allOf(Permission.class)),
    BUSINESS_ADMIN(EnumSet.allOf(Permission.class)),
    BRANCH_MANAGER(EnumSet.of(CATALOG_MANAGE, BOOKINGS_VIEW, BOOKINGS_MANAGE, CUSTOMERS_VIEW, CUSTOMERS_MANAGE, ANALYTICS_VIEW)),
    RECEPTIONIST(EnumSet.of(BOOKINGS_VIEW, BOOKINGS_MANAGE, CUSTOMERS_VIEW, CUSTOMERS_MANAGE, FINANCE_VIEW, FINANCE_MANAGE)),
    STAFF(EnumSet.of(BOOKINGS_VIEW, CUSTOMERS_VIEW)),
    ACCOUNTANT(EnumSet.of(FINANCE_VIEW, FINANCE_MANAGE, ANALYTICS_VIEW));

    private final Set<Permission> permissions;

    BusinessRole(Set<Permission> permissions) { this.permissions = permissions; }

    public boolean allows(Permission p) { return permissions.contains(p); }
}
