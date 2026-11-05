package com.orleu.auth;

import com.orleu.common.ApiException;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.jwt.Jwt;

import java.util.UUID;

public final class CurrentUser {
    private CurrentUser() {}

    public static UUID id() {
        Authentication a = SecurityContextHolder.getContext().getAuthentication();
        if (a != null && a.getPrincipal() instanceof Jwt jwt) {
            return UUID.fromString(jwt.getSubject());
        }
        throw new ApiException(org.springframework.http.HttpStatus.UNAUTHORIZED, "UNAUTHENTICATED", "Authentication required");
    }
}
