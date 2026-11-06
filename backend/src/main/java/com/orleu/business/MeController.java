package com.orleu.business;

import com.orleu.auth.CurrentUser;
import com.orleu.auth.User;
import com.orleu.auth.UserRepository;
import com.orleu.common.ApiException;
import com.orleu.tenancy.MembershipRepository;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

/**
 * The signed-in user with their business memberships. It lives in the business module (not auth) because it joins identity
 * with tenancy data; keeping it here lets auth stay free of any dependency on business/tenancy.
 */
@RestController
@RequestMapping("/api/v1")
public class MeController {
    public record MembershipView(UUID businessId, String businessName, String role) {}
    public record MeResponse(UUID id, String email, String fullName, String locale, List<MembershipView> memberships) {}

    private final UserRepository users;
    private final MembershipRepository memberships;
    private final BusinessRepository businesses;

    public MeController(UserRepository users, MembershipRepository memberships, BusinessRepository businesses) {
        this.users = users; this.memberships = memberships; this.businesses = businesses;
    }

    @GetMapping("/me")
    public MeResponse me() {
        var id = CurrentUser.id();
        User u = users.findById(id).orElseThrow(() -> ApiException.notFound("User"));
        var views = memberships.findByUserIdAndStatus(id, "ACTIVE").stream()
                .map(m -> new MembershipView(m.getBusinessId(), businesses.findById(m.getBusinessId()).map(Business::getName).orElse(""), m.getRole().name()))
                .toList();
        return new MeResponse(u.getId(), u.getEmail(), u.getFullName(), u.getLocale(), views);
    }
}
