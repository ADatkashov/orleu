package com.orleu.auth;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class PasswordResetMailers {
    private static final Logger log = LoggerFactory.getLogger(PasswordResetMailers.class);

    /**
     * One bean decides how a reset token leaves the system:
     * - orleu.mail.provider=log: DEVELOPMENT ONLY, writes the token to the log; REFUSED in the prod profile.
     * - a message sender is configured (a {@link SystemEmailQueue} exists): the e-mail is queued in the user's language and delivered by the dispatcher
     *   with retries; the token sits in the queued body only until the message is final or expired (30-minute reset lifetime).
     * - otherwise nothing is sent and the token is never logged: password reset is unusable until a provider exists.
     */
    @Bean
    public PasswordResetMailer passwordResetMailer(org.springframework.core.env.Environment env, ObjectProvider<SystemEmailQueue> queue,
                                            org.springframework.jdbc.core.simple.JdbcClient jdbc,
                                            @org.springframework.beans.factory.annotation.Value("${orleu.mail.provider:none}") String mailProvider,
                                            @org.springframework.beans.factory.annotation.Value("${orleu.app-base-url:}") String baseUrl) {
        if ("log".equals(mailProvider)) {
            if (env.acceptsProfiles(org.springframework.core.env.Profiles.of("prod"))) {
                throw new IllegalStateException("orleu.mail.provider=log writes reset tokens to the log and is not allowed in the prod profile");
            }
            return (email, token) -> log.warn("DEV password reset for {}: token={}", email, token);
        }
        SystemEmailQueue q = queue.getIfAvailable();
        if (q != null) {
            return (email, token) -> {
                String locale = jdbc.sql("select locale from users where lower(email) = lower(:e)").param("e", email).query(String.class).optional().orElse("ru");
                var m = SystemMessageTemplates.passwordReset(locale, token, baseUrl, (int) PasswordService.RESET_TTL.toMinutes());
                q.enqueue(email, m.subject(), m.body(), "PASSWORD_RESET", PasswordService.RESET_TTL);
            };
        }
        return (email, token) -> log.warn("Password reset requested but no mail provider is configured; nothing was sent");
    }
}
