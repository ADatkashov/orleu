package com.orleu.auth;

import com.orleu.auth.AuthDtos.*;
import com.orleu.tenancy.MembershipRepository;
import com.orleu.business.BusinessRepository;
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
    private final MembershipRepository memberships;
    private final BusinessRepository businesses;
    private final PasswordService passwords;

    public AuthController(AuthService auth, UserRepository users, MembershipRepository memberships, BusinessRepository businesses, PasswordService passwords) {
        this.passwords = passwords;
        this.auth = auth;
        this.users = users;
        this.memberships = memberships;
        this.businesses = businesses;
    }

    @PostMapping("/auth/register")
    @ResponseStatus(HttpStatus.CREATED)
    public TokenResponse register(@Valid @RequestBody RegisterRequest r, HttpServletRequest req) {
        return auth.register(r, req.getHeader("User-Agent"));
    }

    @PostMapping("/auth/login")
    public TokenResponse login(@Valid @RequestBody LoginRequest r, HttpServletRequest req) {
        return auth.login(r, req.getHeader("User-Agent"));
    }

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

    @GetMapping("/me")
    public MeResponse me() {
        var id = CurrentUser.id();
        User u = users.findById(id).orElseThrow(() -> ApiException.notFound("User"));
        var views = memberships.findByUserIdAndStatus(id, "ACTIVE").stream()
                .map(m -> new MembershipView(m.getBusinessId(),
                        businesses.findById(m.getBusinessId()).map(b -> b.getName()).orElse(""), m.getRole().name()))
                .toList();
        return new MeResponse(u.getId(), u.getEmail(), u.getFullName(), u.getLocale(), views);
    }
}
