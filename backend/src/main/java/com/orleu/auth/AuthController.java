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

    public AuthController(AuthService auth, UserRepository users, MembershipRepository memberships, BusinessRepository businesses) {
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
