package com.orleu.it;

import com.orleu.support.AbstractIT;
import com.orleu.support.Fixture;
import org.junit.jupiter.api.Test;
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders;

import java.time.Instant;
import java.util.Map;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

class LedgerExportIT extends AbstractIT {
    private UUID booking(Fixture f, int h, String phone) {
        Res r = post(f.ownerToken, "/api/v1/businesses/%s/bookings", Map.of("branchId", f.branchId, "serviceId", f.serviceId,
                "startsAt", at(bookingDate(), h, 0).toString(), "customer", Map.of("fullName", "Secret Customer", "phone", phone)), f.businessId);
        assertEquals(201, r.status(), r.body().toString());
        return r.id();
    }

    private void money(Fixture f, UUID id, String kind, String amount, String key) {
        assertEquals(201, call(MockMvcRequestBuilders.post("/api/v1/businesses/" + f.businessId + "/bookings/" + id + "/" + kind),
                f.ownerToken, Map.of("amount", amount, "method", "CASH"), "Idempotency-Key", key).status());
    }

    private org.springframework.mock.web.MockHttpServletResponse raw(String token, UUID business, String query) {
        try {
            var b = MockMvcRequestBuilders.get("/api/v1/businesses/" + business + "/finance/export?" + query);
            if (token != null) b.header("Authorization", "Bearer " + token);
            return mvc.perform(b).andReturn().getResponse();
        } catch (Exception e) { throw new RuntimeException(e); }
    }

    private String csv(String token, Fixture f, String extra) {
        var r = raw(token, f.businessId, "from=" + Instant.now().minusSeconds(3600) + "&to=" + Instant.now().plusSeconds(3600) + extra);
        assertEquals(200, r.getStatus());
        try { return r.getContentAsString(java.nio.charset.StandardCharsets.UTF_8); } catch (Exception e) { throw new RuntimeException(e); }
    }

    private int status(String token, UUID business, String query) { return raw(token, business, query).getStatus(); }

    private String window() { return "from=" + Instant.now().minusSeconds(60) + "&to=" + Instant.now().plusSeconds(60); }

    @Test void exportsLedgerRowsWithSignedAmountsAndNoCustomerData() {
        Fixture f = Fixture.create(this, 1, false);
        UUID id = booking(f, 10, "+77010005001");
        money(f, id, "payments", "20000", "ex-1");
        money(f, id, "refunds", "5000.50", "ex-2");
        String out = csv(f.ownerToken, f, "");
        assertTrue(out.startsWith("﻿recorded_at_local,recorded_at_utc,entry_id,type,amount_signed,currency,method,booking_id,booking_start_local,service,provider_ref\r\n"));
        String[] lines = out.split("\r\n");
        assertEquals(3, lines.length, out);
        assertTrue(lines[1].contains(",PAYMENT,20000.00,KZT,CASH,"), lines[1]);
        assertTrue(lines[2].contains(",REFUND,-5000.50,KZT,CASH,"), lines[2]);
        assertTrue(lines[1].contains(id.toString()));
        assertFalse(out.contains("Secret Customer") || out.contains("+77010005001"), "no customer personal data in the export");
        assertEquals(1, jdbc.queryForObject("select count(*) from audit_logs where business_id = ? and action = 'FINANCE_EXPORTED'", Integer.class, f.businessId));
    }

    @Test void semicolonVariantAndSpreadsheetFormulaInjectionIsNeutralised() {
        Fixture f = Fixture.create(this, 1, false);
        assertEquals(200, patch(f.ownerToken, "/api/v1/businesses/%s/services/%s", Map.of("name", "=HYPERLINK(\"http://evil\",\"x\")"), f.businessId, f.serviceId).status());
        UUID id = booking(f, 11, "+77010005002");
        money(f, id, "payments", "1000", "ex-3");
        String out = csv(f.ownerToken, f, "&delimiter=semicolon");
        String[] header = out.split("\r\n")[0].split(";");
        assertEquals(11, header.length);
        String row = out.split("\r\n")[1];
        assertTrue(row.contains("\"'=HYPERLINK(\"\"http://evil\"\",\"\"x\"\")\""), row);
        assertFalse(row.contains(";=HYPERLINK"), "a cell must never start with a formula character");
    }

    @Test void onlyOwnersAdminsAndAccountantsMayExportAndOtherTenantsSeeNothing() {
        Fixture f = Fixture.create(this, 1, false), other = Fixture.create(this, 1, false);
        UUID id = booking(f, 12, "+77010005003");
        money(f, id, "payments", "3000", "ex-4");
        for (String role : new String[]{"RECEPTIONIST", "STAFF", "BRANCH_MANAGER"}) {
            String t = newUser(role.toLowerCase());
            assertEquals(201, post(f.ownerToken, "/api/v1/businesses/%s/members", Map.of("email", get(t, "/api/v1/me").text("email"), "role", role), f.businessId).status());
            assertEquals(403, status(t, f.businessId, window()), role);
        }
        String acct = newUser("acct");
        assertEquals(201, post(f.ownerToken, "/api/v1/businesses/%s/members", Map.of("email", get(acct, "/api/v1/me").text("email"), "role", "ACCOUNTANT"), f.businessId).status());
        assertTrue(csv(acct, f, "").contains("PAYMENT,3000.00"), "the accountant is the intended user");
        assertEquals(404, status(other.ownerToken, f.businessId, window()));
        assertFalse(csv(other.ownerToken, other, "").contains("3000.00"), "another business's export never contains this tenant's entries");
        assertEquals(401, status(null, f.businessId, window()));
    }

    @Test void rangeIsValidatedAndTheResponseIsAnUncachedCsvDownload() {
        Fixture f = Fixture.create(this, 0, false);
        assertEquals(400, status(f.ownerToken, f.businessId, "from=" + Instant.now() + "&to=" + Instant.now().minusSeconds(10)));
        assertEquals(400, status(f.ownerToken, f.businessId, "from=" + Instant.now().minusSeconds(86400L * 400) + "&to=" + Instant.now()));
        var r = raw(f.ownerToken, f.businessId, window());
        assertEquals(200, r.getStatus());
        assertTrue(r.getContentType().startsWith("text/csv"));
        assertTrue(r.getHeader("Content-Disposition").startsWith("attachment; filename=\"orleu-ledger-"), r.getHeader("Content-Disposition"));
        assertTrue(r.getHeader("Cache-Control").contains("no-store"), "financial data must not be cached");
        assertEquals("nosniff", r.getHeader("X-Content-Type-Options"));
    }
}
