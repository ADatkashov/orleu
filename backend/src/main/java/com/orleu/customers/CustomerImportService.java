package com.orleu.customers;

import com.orleu.audit.AuditService;
import com.orleu.auth.CurrentUser;
import com.orleu.common.ApiException;
import com.orleu.common.PhoneNumbers;
import com.orleu.tenancy.Permission;
import com.orleu.tenancy.TenantAccess;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.*;
import java.util.regex.Pattern;

/**
 * CSV import of customers (Excel "Save as CSV"). Two steps with the same code path: dryRun=true only reports what would happen.
 * Rules: the phone number is the identity; customers that already exist are NEVER changed; duplicates inside the file are
 * skipped; invalid rows are reported with their row number and skipped (valid rows are still imported); imported customers
 * never get marketing consent (consent cannot be inferred from a spreadsheet).
 */
@Service
public class CustomerImportService {
    static final int MAX_CHARS = 2_000_000, MAX_ROWS = 5000, MAX_ISSUES = 50;
    private static final Pattern EMAIL = Pattern.compile("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$");
    private static final Map<String, String> ALIASES = new HashMap<>();
    static {
        for (String a : new String[]{"name", "full name", "fullname", "full_name", "client", "customer", "имя", "фио", "клиент", "ф.и.о.", "аты", "аты-жөні"}) ALIASES.put(a, "name");
        for (String a : new String[]{"phone", "phone number", "mobile", "tel", "telephone", "телефон", "тел", "тел.", "номер", "номер телефона", "телефон нөмірі"}) ALIASES.put(a, "phone");
        for (String a : new String[]{"email", "e-mail", "mail", "почта", "эл. почта", "электронная почта"}) ALIASES.put(a, "email");
        for (String a : new String[]{"notes", "note", "comment", "comments", "заметки", "заметка", "комментарий", "примечание"}) ALIASES.put(a, "notes");
    }

    public record RowIssue(int row, String reason) {}
    public record Sample(String fullName, String phone, String email) {}
    public record ImportResult(boolean dryRun, int totalRows, int created, int existing, int duplicatesInFile, int invalid,
                               List<RowIssue> issues, boolean issuesTruncated, List<Sample> preview) {}

    private final TenantAccess access;
    private final JdbcClient jdbc;
    private final AuditService audit;

    public CustomerImportService(TenantAccess access, JdbcClient jdbc, AuditService audit) { this.access = access; this.jdbc = jdbc; this.audit = audit; }

    private record Parsed(String name, String phone, String email, String notes) {}

    @Transactional
    public ImportResult run(UUID businessId, String csv, boolean dryRun) {
        access.require(businessId, Permission.CUSTOMERS_MANAGE);
        if (csv == null || csv.isBlank()) throw ApiException.badRequest("IMPORT_EMPTY", "The file is empty");
        if (csv.length() > MAX_CHARS) throw ApiException.badRequest("IMPORT_TOO_LARGE", "The file is too large (max 2 MB)");
        List<List<String>> rows = CsvParser.parse(csv);
        if (rows.size() < 2) throw ApiException.badRequest("IMPORT_EMPTY", "The file needs a header row and at least one customer");
        if (rows.size() - 1 > MAX_ROWS) throw ApiException.badRequest("IMPORT_TOO_LARGE", "At most " + MAX_ROWS + " customers per import");

        Map<String, Integer> cols = new HashMap<>();
        List<String> header = rows.get(0);
        for (int i = 0; i < header.size(); i++) {
            String key = ALIASES.get(header.get(i).trim().toLowerCase());
            if (key != null) cols.putIfAbsent(key, i);
        }
        if (!cols.containsKey("name") || !cols.containsKey("phone"))
            throw ApiException.badRequest("IMPORT_MISSING_COLUMNS", "The header must contain a name column and a phone column");

        List<RowIssue> issues = new ArrayList<>();
        int invalid = 0, dupes = 0;
        LinkedHashMap<String, Parsed> fresh = new LinkedHashMap<>();
        for (int r = 1; r < rows.size(); r++) {
            List<String> f = rows.get(r);
            int line = r + 1; // 1-based spreadsheet row number including the header
            String name = cell(f, cols.get("name")), rawPhone = cell(f, cols.get("phone")), email = cell(f, cols.get("email")), notes = cell(f, cols.get("notes"));
            String problem = null, phone = PhoneNumbers.normalize(rawPhone);
            if (name.isEmpty()) problem = "NAME_MISSING";
            else if (name.length() > 200) problem = "NAME_TOO_LONG";
            else if (phone == null) problem = "PHONE_INVALID";
            else if (!email.isEmpty() && (!EMAIL.matcher(email).matches() || email.length() > 254)) problem = "EMAIL_INVALID";
            else if (notes.length() > 2000) problem = "NOTES_TOO_LONG";
            if (problem != null) { invalid++; if (issues.size() < MAX_ISSUES) issues.add(new RowIssue(line, problem)); continue; }
            if (fresh.containsKey(phone)) { dupes++; continue; }
            fresh.put(phone, new Parsed(name, phone, email.isEmpty() ? null : email, notes.isEmpty() ? null : notes));
        }
        Set<String> existingPhones = new HashSet<>();
        if (!fresh.isEmpty()) {
            existingPhones.addAll(jdbc.sql("select phone from customers where business_id = :b and phone in (:p)")
                    .param("b", businessId).param("p", new ArrayList<>(fresh.keySet())).query(String.class).list());
        }
        List<Parsed> toCreate = fresh.values().stream().filter(p -> !existingPhones.contains(p.phone())).toList();
        int created = toCreate.size();
        if (!dryRun) {
            created = 0;
            for (Parsed p : toCreate) {
                created += jdbc.sql("""
                    insert into customers (business_id, full_name, phone, email, notes, marketing_opt_in) values (:b, :n, :p, :e, :no, false)
                    on conflict (business_id, phone) do nothing
                    """).param("b", businessId).param("n", p.name()).param("p", p.phone()).param("e", p.email(), java.sql.Types.VARCHAR)
                        .param("no", p.notes(), java.sql.Types.VARCHAR).update();
            }
            audit.log(businessId, CurrentUser.id(), "CUSTOMERS_IMPORTED", "CUSTOMER", null,
                    "{\"created\":" + created + ",\"existing\":" + existingPhones.size() + ",\"invalid\":" + invalid + "}");
        }
        List<Sample> preview = toCreate.stream().limit(10).map(p -> new Sample(p.name(), p.phone(), p.email())).toList();
        return new ImportResult(dryRun, rows.size() - 1, created, existingPhones.size(), dupes, invalid, issues, invalid > issues.size(), preview);
    }

    private static String cell(List<String> f, Integer i) { return i == null || i >= f.size() ? "" : f.get(i).trim(); }
}
