package com.orleu.auth;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public final class AuthDtos {
    private AuthDtos() {}

    public record RegisterRequest(
            @NotBlank @Email @Size(max = 254) String email,
            @NotBlank @Size(min = 10, max = 128, message = "password must be 10-128 characters") String password,
            @NotBlank @Size(max = 200) String fullName,
            @Pattern(regexp = "^\\+[1-9][0-9]{7,14}$", message = "phone must be E.164, e.g. +77011234567") String phone,
            @Pattern(regexp = "^(kk|ru|en)$") String locale) {}

    public record LoginRequest(@NotBlank String email, @NotBlank String password) {}

    public record PasswordResetRequest(@NotBlank @Email String email) {}

    public record PasswordResetConfirm(@NotBlank @Size(min = 20, max = 100) String token,
                                       @NotBlank @Size(min = 10, max = 128, message = "password must be 10-128 characters") String newPassword) {}

    public record ChangePasswordRequest(@NotBlank String currentPassword,
                                        @NotBlank @Size(min = 10, max = 128, message = "password must be 10-128 characters") String newPassword) {}

    public record RefreshRequest(@NotBlank String refreshToken) {}

    public record TokenResponse(String accessToken, String refreshToken, long expiresInSeconds, String tokenType) {}

    public record MeResponse(java.util.UUID id, String email, String fullName, String locale,
                             java.util.List<MembershipView> memberships) {}

    public record MembershipView(java.util.UUID businessId, String businessName, String role) {}
}
