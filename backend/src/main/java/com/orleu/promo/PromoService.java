package com.orleu.promo;

import com.orleu.audit.AuditService;
import com.orleu.auth.CurrentUser;
import com.orleu.common.ApiException;
import com.orleu.common.Money;
import com.orleu.tenancy.Permission;
import com.orleu.tenancy.TenantAccess;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;
import java.util.Locale;
import java.util.UUID;

/**
 * Promo codes. Discount maths is decimal-only (scale 2, HALF_UP) and the discount can never exceed the price;
 * the deposit is then computed by the booking on the DISCOUNTED price. Redemption is an atomic conditional UPDATE so two
 * concurrent bookings cannot both use the last redemption. Cancelling a booking does not give the redemption back (documented limitation).
 */
@Service
public class PromoService {
    public record PromoView(UUID id, String code, String kind, BigDecimal value, LocalDate validFrom, LocalDate validUntil,
                            Integer maxUses, int usedCount, UUID serviceId, boolean active) {}
    public record PromoRequest(String code, String kind, BigDecimal value, LocalDate validFrom, LocalDate validUntil,
                               Integer maxUses, UUID serviceId, Boolean active) {}
    /** Result of applying a code to a price. */
    public record Applied(UUID promoId, BigDecimal discount, BigDecimal finalPrice) {}

    private final TenantAccess access;
    private final JdbcClient jdbc;
    private final AuditService audit;

    public PromoService(TenantAccess access, JdbcClient jdbc, AuditService audit) { this.access = access; this.jdbc = jdbc; this.audit = audit; }

    // ---------- management ----------

    public List<PromoView> list(UUID businessId) {
        access.require(businessId, Permission.CATALOG_MANAGE);
        return jdbc.sql("select id, code, kind, value, valid_from, valid_until, max_uses, used_count, service_id, active from promo_codes where business_id = :b order by created_at desc")
                .param("b", businessId).query((rs, i) -> new PromoView(rs.getObject(1, UUID.class), rs.getString(2), rs.getString(3), rs.getBigDecimal(4),
                        rs.getObject(5, LocalDate.class), rs.getObject(6, LocalDate.class), (Integer) rs.getObject(7), rs.getInt(8), rs.getObject(9, UUID.class), rs.getBoolean(10))).list();
    }

    @Transactional
    public PromoView create(UUID businessId, PromoRequest r) {
        access.require(businessId, Permission.CATALOG_MANAGE);
        String code = normalize(r.code());
        if (code == null || !code.matches("[A-Z0-9_-]{3,32}")) throw ApiException.badRequest("INVALID_CODE", "Code must be 3-32 letters, digits, - or _");
        String kind = r.kind() == null ? "" : r.kind().toUpperCase(Locale.ROOT);
        if (!kind.equals("PERCENT") && !kind.equals("FIXED")) throw ApiException.badRequest("INVALID_KIND", "kind must be PERCENT or FIXED");
        if (r.value() == null || r.value().signum() <= 0) throw ApiException.badRequest("INVALID_VALUE", "value must be positive");
        if (kind.equals("PERCENT") && r.value().compareTo(new BigDecimal("100")) > 0) throw ApiException.badRequest("INVALID_VALUE", "percent must be at most 100");
        if (r.validFrom() != null && r.validUntil() != null && r.validUntil().isBefore(r.validFrom())) throw ApiException.badRequest("INVALID_PERIOD", "validUntil is before validFrom");
        if (r.maxUses() != null && r.maxUses() <= 0) throw ApiException.badRequest("INVALID_MAX_USES", "maxUses must be positive");
        if (r.serviceId() != null && jdbc.sql("select count(*) from services where id = :s and business_id = :b").param("s", r.serviceId()).param("b", businessId).query(Long.class).single() == 0) {
            throw ApiException.notFound("Service");
        }
        if (jdbc.sql("select count(*) from promo_codes where business_id = :b and code = :c").param("b", businessId).param("c", code).query(Long.class).single() > 0) {
            throw ApiException.conflict("CODE_EXISTS", "This code already exists");
        }
        UUID id = jdbc.sql("""
                insert into promo_codes (business_id, code, kind, value, valid_from, valid_until, max_uses, service_id)
                values (:b, :c, :k, :v, :f, :u, :m, :s) returning id""")
                .param("b", businessId).param("c", code).param("k", kind).param("v", Money.scale(r.value()))
                .param("f", r.validFrom()).param("u", r.validUntil()).param("m", r.maxUses()).param("s", r.serviceId())
                .query(UUID.class).single();
        audit.log(businessId, CurrentUser.id(), "PROMO_CREATED", "PROMO", id, null);
        return list(businessId).stream().filter(p -> p.id().equals(id)).findFirst().orElseThrow();
    }

    @Transactional
    public void setActive(UUID businessId, UUID promoId, boolean active) {
        access.require(businessId, Permission.CATALOG_MANAGE);
        int n = jdbc.sql("update promo_codes set active = :a where id = :id and business_id = :b").param("a", active).param("id", promoId).param("b", businessId).update();
        if (n == 0) throw ApiException.notFound("Promo code");
        audit.log(businessId, CurrentUser.id(), active ? "PROMO_ENABLED" : "PROMO_DISABLED", "PROMO", promoId, null);
    }

    // ---------- applying (no permission check: used by the public booking flow and by staff booking creation) ----------

    /** Validates the code for this service/price and returns the discount WITHOUT consuming a redemption. */
    public Applied preview(UUID businessId, String rawCode, UUID serviceId, BigDecimal price) {
        String code = normalize(rawCode);
        if (code == null) throw invalid();
        var row = jdbc.sql("select id, kind, value, valid_from, valid_until, max_uses, used_count, service_id, active from promo_codes where business_id = :b and code = :c")
                .param("b", businessId).param("c", code)
                .query((rs, i) -> new Object[]{rs.getObject(1, UUID.class), rs.getString(2), rs.getBigDecimal(3), rs.getObject(4, LocalDate.class),
                        rs.getObject(5, LocalDate.class), rs.getObject(6), rs.getInt(7), rs.getObject(8, UUID.class), rs.getBoolean(9)}).optional().orElseThrow(PromoService::invalid);
        LocalDate today = LocalDate.now(ZoneId.of(jdbc.sql("select timezone from businesses where id = :b").param("b", businessId).query(String.class).single()));
        LocalDate from = (LocalDate) row[3], until = (LocalDate) row[4];
        Integer max = (Integer) row[5];
        UUID svc = (UUID) row[7];
        if (!(Boolean) row[8] || (from != null && today.isBefore(from)) || (until != null && today.isAfter(until))
                || (svc != null && !svc.equals(serviceId)) || (max != null && (Integer) row[6] >= max)) {
            throw invalid();
        }
        BigDecimal value = (BigDecimal) row[2];
        BigDecimal discount = "PERCENT".equals(row[1]) ? Money.percentOf(price, value) : Money.scale(value);
        discount = discount.min(price);
        return new Applied((UUID) row[0], discount, Money.scale(price.subtract(discount)));
    }

    /** Atomically consumes one redemption; fails if another booking took the last one in the meantime. */
    public void redeem(UUID businessId, UUID promoId) {
        int n = jdbc.sql("update promo_codes set used_count = used_count + 1 where id = :id and business_id = :b and active and (max_uses is null or used_count < max_uses)")
                .param("id", promoId).param("b", businessId).update();
        if (n == 0) throw invalid();
    }

    private static ApiException invalid() { return ApiException.badRequest("PROMO_INVALID", "This promo code is not valid"); }

    private static String normalize(String c) { return c == null || c.isBlank() ? null : c.trim().toUpperCase(Locale.ROOT); }
}
