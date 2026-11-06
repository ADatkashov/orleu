package com.orleu.it;

import com.orleu.support.AbstractIT;
import com.orleu.support.Fixture;
import org.junit.jupiter.api.Test;

import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

class CustomerImportIT extends AbstractIT {
    private static final String CSV = """
            Имя;Телефон;Email;Заметки
            Айгерим Садыкова;8 701 123 45 67;aigerim@example.com;любит утро
            Дана;+7 (702) 222-33-44;;
            Без телефона;;;
            Плохой номер;12345;;
            Плохой email;+77013334455;not-an-email;
            Дубль в файле;87011234567;;
            ;+77015556677;;
            """;

    private Res imp(Fixture f, String csv, boolean dry) {
        return post(f.ownerToken, "/api/v1/businesses/%s/customers/import", Map.of("csv", csv, "dryRun", dry), f.businessId);
    }

    private int count(Fixture f) { return jdbc.queryForObject("select count(*) from customers where business_id = ?", Integer.class, f.businessId); }

    @Test void dryRunReportsWithoutChangingAnythingThenImportCreatesOnlyValidNewCustomers() {
        Fixture f = Fixture.create(this, 0, false);
        Res dry = imp(f, CSV, true);
        assertEquals(200, dry.status(), dry.body().toString());
        assertTrue(dry.body().path("dryRun").asBoolean());
        assertEquals(7, dry.body().path("totalRows").asInt());
        assertEquals(2, dry.body().path("created").asInt());
        assertEquals(1, dry.body().path("duplicatesInFile").asInt());
        assertEquals(4, dry.body().path("invalid").asInt(), "no phone, bad phone, bad email, no name");
        assertEquals(0, count(f), "a dry run never writes");

        Res real = imp(f, CSV, false);
        assertEquals(2, real.body().path("created").asInt());
        assertEquals(2, count(f));
        assertEquals("+77011234567", jdbc.queryForObject("select phone from customers where business_id = ? and full_name = 'Айгерим Садыкова'", String.class, f.businessId));
        assertEquals("любит утро", jdbc.queryForObject("select notes from customers where business_id = ? and phone = '+77011234567'", String.class, f.businessId));
        assertEquals(0, jdbc.queryForObject("select count(*) from customers where business_id = ? and marketing_opt_in", Integer.class, f.businessId), "imports never grant marketing consent");
        assertEquals(1, jdbc.queryForObject("select count(*) from audit_logs where business_id = ? and action = 'CUSTOMERS_IMPORTED'", Integer.class, f.businessId));
    }

    @Test void issuesNameTheRowAndReason() {
        Fixture f = Fixture.create(this, 0, false);
        var issues = imp(f, CSV, true).body().path("issues");
        java.util.Map<Integer, String> byRow = new java.util.HashMap<>();
        for (var i : issues) byRow.put(i.path("row").asInt(), i.path("reason").asText());
        assertEquals("PHONE_INVALID", byRow.get(4), "row 4 = 'Без телефона' (header is row 1)");
        assertEquals("PHONE_INVALID", byRow.get(5));
        assertEquals("EMAIL_INVALID", byRow.get(6));
        assertEquals("NAME_MISSING", byRow.get(8));
    }

    @Test void existingCustomersAreNeverChangedAndReimportingIsIdempotent() {
        Fixture f = Fixture.create(this, 0, false);
        post(f.ownerToken, "/api/v1/businesses/%s/customers", Map.of("fullName", "Original Name", "phone", "+77011234567", "notes", "keep me"), f.businessId);
        Res r = imp(f, CSV, false);
        assertEquals(1, r.body().path("existing").asInt());
        assertEquals(1, r.body().path("created").asInt());
        assertEquals("Original Name", jdbc.queryForObject("select full_name from customers where business_id = ? and phone = '+77011234567'", String.class, f.businessId));
        assertEquals("keep me", jdbc.queryForObject("select notes from customers where business_id = ? and phone = '+77011234567'", String.class, f.businessId));
        Res again = imp(f, CSV, false);
        assertEquals(0, again.body().path("created").asInt());
        assertEquals(2, again.body().path("existing").asInt());
        assertEquals(2, count(f));
    }

    @Test void sameCsvInTwoBusinessesCreatesIndependentCustomers() {
        Fixture a = Fixture.create(this, 0, false), b = Fixture.create(this, 0, false);
        imp(a, CSV, false);
        Res rb = imp(b, CSV, false);
        assertEquals(2, rb.body().path("created").asInt());
        assertEquals(2, count(a));
        assertEquals(2, count(b));
        assertEquals(404, post(b.ownerToken, "/api/v1/businesses/%s/customers/import", Map.of("csv", CSV, "dryRun", true), a.businessId).status());
    }

    @Test void structuralProblemsAreRejectedWithClearCodes() {
        Fixture f = Fixture.create(this, 0, false);
        assertEquals("IMPORT_EMPTY", imp(f, "", false).text("code"));
        assertEquals("IMPORT_EMPTY", imp(f, "name,phone\n", false).text("code"));
        assertEquals("IMPORT_MISSING_COLUMNS", imp(f, "foo,bar\n1,2\n", false).text("code"));
        assertEquals("IMPORT_MISSING_COLUMNS", imp(f, "name,email\nA,a@b.kz\n", false).text("code"));
        StringBuilder big = new StringBuilder("name,phone\n");
        for (int i = 0; i < 5001; i++) big.append("N").append(i).append(",+7701").append(String.format("%07d", i)).append("\n");
        assertEquals("IMPORT_TOO_LARGE", imp(f, big.toString(), false).text("code"));
        assertEquals(0, count(f));
    }

    @Test void rolesWithoutCustomerManagementCannotImport() {
        Fixture f = Fixture.create(this, 0, false);
        String acct = newUser("acct");
        String email = get(acct, "/api/v1/me").text("email");
        assertEquals(201, post(f.ownerToken, "/api/v1/businesses/%s/members", Map.of("email", email, "role", "ACCOUNTANT"), f.businessId).status());
        assertEquals(403, post(acct, "/api/v1/businesses/%s/customers/import", Map.of("csv", CSV, "dryRun", true), f.businessId).status());
        assertEquals(401, post(null, "/api/v1/businesses/%s/customers/import", Map.of("csv", CSV, "dryRun", true), f.businessId).status());
    }

    @Test void largeValidFileImportsAllRows() {
        Fixture f = Fixture.create(this, 0, false);
        StringBuilder sb = new StringBuilder("name,phone\n");
        for (int i = 0; i < 3000; i++) sb.append("Client ").append(i).append(",+7702").append(String.format("%07d", i)).append("\n");
        Res r = imp(f, sb.toString(), false);
        assertEquals(3000, r.body().path("created").asInt());
        assertEquals(3000, count(f));
    }
}
