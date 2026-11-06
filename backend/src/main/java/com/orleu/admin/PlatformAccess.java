package com.orleu.admin;

import com.orleu.auth.CurrentUser;
import com.orleu.common.ApiException;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Component;

import java.util.Set;
import java.util.UUID;

/**
 * Authorization for /api/v1/admin/**. The role is read from the database on every call (not from the JWT),
 * so revoking a platform role takes effect immediately. There is deliberately NO impersonation feature.
 */
@Component
public class PlatformAccess {
    private final JdbcClient jdbc;

    private final com.orleu.auth.SecurityProperties props;

    public PlatformAccess(JdbcClient jdbc, com.orleu.auth.SecurityProperties props) { this.jdbc = jdbc; this.props = props; }

    /** With orleu.security.require-mfa-for-platform-roles=true, platform staff without an enabled second factor get 403 MFA_REQUIRED. */
    private void enforceMfa(UUID user) {
        if (!props.requireMfaForPlatformRoles()) return;
        boolean on = Boolean.TRUE.equals(jdbc.sql("select enabled from user_mfa where user_id = :u").param("u", user).query(Boolean.class).optional().orElse(false));
        if (!on) throw new ApiException(org.springframework.http.HttpStatus.FORBIDDEN, "MFA_REQUIRED", "Enable two-factor authentication to use the admin console");
    }

    public UUID require(PlatformRole... allowed) {
        UUID user = CurrentUser.id();
        String role = jdbc.sql("select platform_role from users where id = :id and status = 'ACTIVE'")
                .param("id", user).query(String.class).optional().orElse(null);
        if (role == null || !Set.of(allowed).contains(PlatformRole.valueOf(role))) {
            throw ApiException.forbidden();
        }
        enforceMfa(user);
        return user;
    }

    /** The caller's platform role; 403 for users without one. */
    public PlatformRole currentRole() {
        String role = jdbc.sql("select platform_role from users where id = :id and status = 'ACTIVE'")
                .param("id", CurrentUser.id()).query(String.class).optional().orElse(null);
        if (role == null) throw ApiException.forbidden();
        enforceMfa(CurrentUser.id());
        return PlatformRole.valueOf(role);
    }

    /** Any platform role (read access). */
    public UUID requireAny() { return require(PlatformRole.values()); }
}
