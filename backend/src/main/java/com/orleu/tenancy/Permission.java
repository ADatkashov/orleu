package com.orleu.tenancy;

public enum Permission {
    BUSINESS_MANAGE, STAFF_MANAGE, CATALOG_MANAGE, BOOKINGS_VIEW, BOOKINGS_MANAGE,
    CUSTOMERS_VIEW, CUSTOMERS_MANAGE, FINANCE_VIEW, FINANCE_MANAGE, FINANCE_EXPORT, ANALYTICS_VIEW,
    /** Approve or reject refund requests above the business threshold; refunds by holders are never held back. Owner and admin only. */
    REFUND_APPROVE
}
