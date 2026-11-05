package com.orleu.subscriptions;

import com.orleu.common.ApiException;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;

import java.util.UUID;

/**
 * Central plan enforcement. Limits live in subscription_plans (configurable data), never in code.
 * The backend is the only enforcement point; clients merely display {@link #usage}.
 */
@Service
public class EntitlementService {
    private final JdbcClient jdbc;

    public EntitlementService(JdbcClient jdbc) { this.jdbc = jdbc; }

    public record Usage(String planCode, String planName, int maxBranches, int branches, int maxEmployees, int employees) {}

    public Usage usage(UUID businessId) {
        return jdbc.sql("""
                select p.code, p.name, p.max_branches, p.max_employees,
                       (select count(*) from branches br where br.business_id = b.id and br.active) as branches,
                       (select count(*) from employees e where e.business_id = b.id and e.active) as employees
                from businesses b join subscription_plans p on p.code = b.plan_code
                where b.id = :id
                """).param("id", businessId)
            .query((rs, i) -> new Usage(rs.getString("code"), rs.getString("name"), rs.getInt("max_branches"),
                    rs.getInt("branches"), rs.getInt("max_employees"), rs.getInt("employees")))
            .single();
    }

    public void assertCanAddBranch(UUID businessId) {
        Usage u = usage(businessId);
        if (u.branches() >= u.maxBranches()) {
            throw limit("BRANCH_LIMIT_REACHED", "Plan " + u.planCode() + " allows up to " + u.maxBranches() + " branch(es)");
        }
    }

    public void assertCanAddEmployee(UUID businessId) {
        Usage u = usage(businessId);
        if (u.employees() >= u.maxEmployees()) {
            throw limit("EMPLOYEE_LIMIT_REACHED", "Plan " + u.planCode() + " allows up to " + u.maxEmployees() + " employees");
        }
    }

    private static ApiException limit(String code, String msg) {
        return new ApiException(HttpStatus.PAYMENT_REQUIRED, code, msg);
    }
}
