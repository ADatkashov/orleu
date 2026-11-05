package com.orleu.tenancy;

import com.orleu.auth.CurrentUser;
import com.orleu.common.ApiException;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Component;

import java.util.UUID;

/**
 * Single choke point for tenant authorization. The business id from the URL is NEVER trusted:
 * every business-scoped endpoint must call {@link #require} before touching data, and every
 * repository lookup afterwards is additionally filtered by business id.
 *
 * Non-members get 404 (not 403) so that business ids cannot be enumerated.
 */
@Component
public class TenantAccess {
    private final MembershipRepository memberships;
    private final JdbcClient jdbc;

    public TenantAccess(MembershipRepository memberships, JdbcClient jdbc) { this.memberships = memberships; this.jdbc = jdbc; }

    public Membership require(UUID businessId, Permission permission) {
        UUID userId = CurrentUser.id();
        Membership m = memberships.findByUserIdAndBusinessIdAndStatus(userId, businessId, "ACTIVE")
                .orElseThrow(() -> ApiException.notFound("Business"));
        if (!m.getRole().allows(permission)) {
            throw ApiException.forbidden();
        }
        boolean suspended = jdbc.sql("select status = 'SUSPENDED' from businesses where id = :id").param("id", businessId)
                .query(Boolean.class).optional().orElse(false);
        if (suspended) {
            throw new ApiException(org.springframework.http.HttpStatus.FORBIDDEN, "BUSINESS_SUSPENDED",
                    "This business is suspended. Please contact ORLEU support.");
        }
        return m;
    }
}
