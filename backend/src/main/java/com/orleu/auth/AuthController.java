package com.orleu.auth;

import com.orleu.auth.AuthDtos.*;
import com.orleu.common.ApiException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1")
public class AuthController {
    private final AuthService auth;
    private final UserRepository users;
    private final PasswordService passwords;
    private final MfaService mfa;

    public AuthController(AuthService auth, UserRepository users, PasswordService passwords, MfaService mfa) {
        this.mfa = mfa;
        this.passwords = passwords;
        this.auth = auth;
        this.users = users;
    }

    @PostMapping("/auth/register")
    @ResponseStatus(HttpStatus.CREATED)
    public TokenResponse register(@Valid @RequestBody RegisterRequest r, HttpServletRequest req) {
        return auth.register(r, req.getHeader("User-Agent"));
    }

    @PostMapping("/auth/login")
    public LoginResponse login(@Valid @RequestBody LoginRequest r, HttpServletRequest req) {
        return auth.login(r, req.getHeader("User-Agent"));
    }

    @PostMapping("/auth/mfa/verify")
    public TokenResponse verifyMfa(@Valid @RequestBody MfaVerifyRequest r, HttpServletRequest req) {
        return auth.verifyMfa(r.mfaToken(), r.code(), req.getHeader("User-Agent"));
    }

    @GetMapping("/auth/mfa")
    public MfaService.Status mfaStatus() { return mfa.status(CurrentUser.id()); }

    @PostMapping("/auth/mfa/setup")
    public MfaService.Setup mfaSetup() { return mfa.setup(CurrentUser.id()); }

    @PostMapping("/auth/mfa/enable")
    public RecoveryCodesResponse mfaEnable(@Valid @RequestBody MfaCodeRequest r) { return new RecoveryCodesResponse(mfa.enable(CurrentUser.id(), r.code())); }

    @PostMapping("/auth/mfa/disable")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void mfaDisable(@Valid @RequestBody MfaDisableRequest r) { mfa.disable(CurrentUser.id(), r.password(), r.code()); }

    @PostMapping("/auth/refresh")
    public TokenResponse refresh(@Valid @RequestBody RefreshRequest r, HttpServletRequest req) {
        return auth.refresh(r.refreshToken(), req.getHeader("User-Agent"));
    }

    @PostMapping("/auth/logout")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void logout(@Valid @RequestBody RefreshRequest r) {
        auth.logout(r.refreshToken());
    }

    @PostMapping("/auth/logout-all")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void logoutAll() {
        auth.logoutEverywhere(CurrentUser.id());
    }

    @PostMapping("/auth/password-reset/request")
    @ResponseStatus(HttpStatus.ACCEPTED)
    public void requestReset(@Valid @RequestBody PasswordResetRequest r) { passwords.requestReset(r.email()); }

    @PostMapping("/auth/password-reset/confirm")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void confirmReset(@Valid @RequestBody PasswordResetConfirm r) { passwords.confirmReset(r.token(), r.newPassword()); }

    @PostMapping("/auth/change-password")
    public TokenResponse changePassword(@Valid @RequestBody ChangePasswordRequest r, HttpServletRequest req) {
        return passwords.changePassword(CurrentUser.id(), r.currentPassword(), r.newPassword(), req.getHeader("User-Agent"));
    }

    @GetMapping("/auth/sessions")
    public java.util.List<PasswordService.SessionView> sessions() { return passwords.sessions(CurrentUser.id()); }

    @DeleteMapping("/auth/sessions/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void revokeSession(@PathVariable java.util.UUID id) { passwords.revokeSession(CurrentUser.id(), id); }
}
