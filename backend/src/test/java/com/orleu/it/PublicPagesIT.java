package com.orleu.it;

import com.orleu.support.AbstractIT;
import com.orleu.support.Fixture;
import org.junit.jupiter.api.Test;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders;

import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

class PublicPagesIT extends AbstractIT {
    private MvcResult page(String path) throws Exception { return mvc.perform(MockMvcRequestBuilders.get(path)).andReturn(); }

    @Test void publishedBusinessPageIsServedWithSeoMetaAndStrictCsp() throws Exception {
        Fixture f = Fixture.create(this, 1, true);
        patch(f.ownerToken, "/api/v1/businesses/%s/settings", Map.of("name", "Almaty Barbers", "description", "Best fades in town"), f.businessId);
        MvcResult r = page("/b/" + f.slug);
        String html = r.getResponse().getContentAsString();
        assertEquals(200, r.getResponse().getStatus());
        assertTrue(html.contains("<title>Almaty Barbers — ORLEU</title>"));
        assertTrue(html.contains("content=\"Best fades in town\""));
        assertTrue(html.contains("data-slug=\"" + f.slug + "\""));
        String csp = r.getResponse().getHeader("Content-Security-Policy");
        assertTrue(csp.contains("script-src 'self'") && !csp.contains("unsafe-inline") && csp.contains("frame-ancestors 'none'"), csp);
        assertFalse(html.contains("<script>"), "no inline scripts allowed");
    }

    @Test void businessTextIsHtmlEscapedInThePage() throws Exception {
        Fixture f = Fixture.create(this, 1, true);
        patch(f.ownerToken, "/api/v1/businesses/%s/settings",
                Map.of("name", "<script>alert(1)</script>\"><img src=x onerror=alert(2)>", "description", "\"><script>alert(3)</script>"), f.businessId);
        String html = page("/b/" + f.slug).getResponse().getContentAsString();
        assertFalse(html.contains("<script>alert"), html);
        assertFalse(html.contains("<img src=x"), html);
        assertTrue(html.contains("&lt;script&gt;alert(1)&lt;/script&gt;"));
    }

    @Test void unpublishedOrUnknownPagesAre404WithoutRevealingExistence() throws Exception {
        Fixture f = Fixture.create(this, 1, false);
        MvcResult hidden = page("/b/" + f.slug), unknown = page("/b/nope-nope-nope");
        assertEquals(404, hidden.getResponse().getStatus());
        assertEquals(404, unknown.getResponse().getStatus());
        assertEquals(hidden.getResponse().getContentAsString(), unknown.getResponse().getContentAsString());
        assertFalse(hidden.getResponse().getContentAsString().contains("Test Salon"));
    }

    @Test void managePageNeverCachesOrLeaksTheTokenViaReferer() throws Exception {
        MvcResult r = page("/m/" + "A".repeat(43));
        assertEquals(200, r.getResponse().getStatus());
        assertEquals("no-referrer", r.getResponse().getHeader("Referrer-Policy"));
        assertTrue(r.getResponse().getHeader("Cache-Control").contains("no-store"));
        assertTrue(r.getResponse().getContentAsString().contains("noindex"));
        // token reflected only as an escaped attribute value
        String evil = page("/m/%22%3E%3Cscript%3Ealert(1)%3C/script%3E").getResponse().getContentAsString();
        assertFalse(evil.contains("<script>alert"));
    }

    @Test void staticAssetsArePublicAndProfileExposesDepositDefault() throws Exception {
        assertEquals(200, page("/pub/booking.js").getResponse().getStatus());
        assertEquals(200, page("/pub/booking.css").getResponse().getStatus());
        Fixture f = Fixture.create(this, 1, true);
        patch(f.ownerToken, "/api/v1/businesses/%s/settings", Map.of("depositPercent", 25), f.businessId);
        assertEquals(0, new java.math.BigDecimal("25").compareTo(get(null, "/api/v1/public/businesses/%s", f.slug).body().path("depositPercent").decimalValue()));
    }
}
