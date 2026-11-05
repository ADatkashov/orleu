package com.orleu.admin;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
public class PlatformJobs implements ApplicationRunner {
    private static final Logger log = LoggerFactory.getLogger(PlatformJobs.class);
    private final AdminService admin;
    private final JdbcClient jdbc;
    private final String bootstrapEmail;

    public PlatformJobs(AdminService admin, JdbcClient jdbc, @Value("${orleu.bootstrap-admin-email:}") String bootstrapEmail) {
        this.admin = admin; this.jdbc = jdbc; this.bootstrapEmail = bootstrapEmail;
    }

    @Scheduled(fixedDelayString = "${orleu.jobs.subscription-interval:PT10M}")
    public void expireSubscriptions() {
        try {
            int n = admin.downgradeExpiredPlans();
            if (n > 0) log.info("Downgraded {} expired subscriptions", n);
        } catch (Exception e) { log.error("Subscription expiry failed", e); }
    }

    /**
     * Bootstrap: if ORLEU_BOOTSTRAP_ADMIN_EMAIL names an existing user and the platform has NO super admin yet,
     * that user becomes SUPER_ADMIN. It never changes anything once a super admin exists.
     */
    @Override
    public void run(ApplicationArguments args) {
        if (bootstrapEmail == null || bootstrapEmail.isBlank()) return;
        int n = jdbc.sql("""
            update users set platform_role = 'SUPER_ADMIN'
            where lower(email) = lower(:e) and not exists (select 1 from users where platform_role = 'SUPER_ADMIN')
            """).param("e", bootstrapEmail.trim()).update();
        if (n > 0) log.warn("Bootstrapped SUPER_ADMIN for the configured e-mail");
    }
}
