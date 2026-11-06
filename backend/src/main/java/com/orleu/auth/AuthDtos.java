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

    /** Login result: either the tokens, or {mfaRequired:true, mfaToken} when the account has a second factor. */
    @com.fasterxml.jackson.annotation.JsonInclude(com.fasterxml.jackson.annotation.JsonInclude.Include.NON_NULL)
    public record LoginResponse(String accessToken, String refreshToken, Long expiresInSeconds, String tokenType, Boolean mfaRequired, String mfaToken) {
        static LoginResponse of(TokenResponse t) { return new LoginResponse(t.accessToken(), t.refreshToken(), t.expiresInSeconds(), t.tokenType(), null, null); }
        static LoginResponse challenge(String token) { return new LoginResponse(null, null, null, null, true, token); }
    }

    public record MfaVerifyRequest(@NotBlank String mfaToken, @NotBlank @Size(max = 40) String code) {}
    public record MfaCodeRequest(@NotBlank @Size(max = 40) String code) {}
    public record MfaDisableRequest(@NotBlank String password, @NotBlank @Size(max = 40) String code) {}
    public record RecoveryCodesResponse(java.util.List<String> recoveryCodes) {}

    public record TokenResponse(String accessToken, String refreshToken, long expiresInSeconds, String tokenType) {}


}
