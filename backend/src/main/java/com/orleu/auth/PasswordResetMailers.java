package com.orleu.auth;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnMissingBean;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class PasswordResetMailers {
    private static final Logger log = LoggerFactory.getLogger(PasswordResetMailers.class);

    /** DEVELOPMENT ONLY (orleu.mail.provider=log): writes the token to the log. Never enable in production. */
    @Bean
    @ConditionalOnProperty(name = "orleu.mail.provider", havingValue = "log")
    PasswordResetMailer loggingMailer() {
        return (email, token) -> log.warn("DEV password reset for {}: token={}", email, token);
    }

    /** Default: nothing is sent and the token is never logged. Password reset is unusable until a provider exists. */
    @Bean
    @ConditionalOnMissingBean(PasswordResetMailer.class)
    PasswordResetMailer noProviderMailer() {
        return (email, token) -> log.warn("Password reset requested but no mail provider is configured; nothing was sent");
    }
}
