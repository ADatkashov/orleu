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

    public PlatformAccess(JdbcClient jdbc) { this.jdbc = jdbc; }

    public UUID require(PlatformRole... allowed) {
        UUID user = CurrentUser.id();
        String role = jdbc.sql("select platform_role from users where id = :id and status = 'ACTIVE'")
                .param("id", user).query(String.class).optional().orElse(null);
        if (role == null || !Set.of(allowed).contains(PlatformRole.valueOf(role))) {
            throw ApiException.forbidden();
        }
        return user;
    }

    /** Any platform role (read access). */
    public UUID requireAny() { return require(PlatformRole.values()); }
}
