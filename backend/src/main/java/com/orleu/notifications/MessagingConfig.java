package com.orleu.notifications;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.env.Environment;

/**
 * Selects the delivery channel with {@code orleu.messaging.provider}: {@code none} (default, messages stay NOT_SENT as before) or {@code fake} (test mode).
 * The fake sender is REFUSED in the prod profile so a mock can never silently stand in for real delivery.
 */
@Configuration
public class MessagingConfig {
    @Bean
    @ConditionalOnProperty(name = "orleu.messaging.provider", havingValue = "fake")
    MessageSender fakeMessageSender(Environment env) {
        if (env.acceptsProfiles(org.springframework.core.env.Profiles.of("prod"))) {
            throw new IllegalStateException("orleu.messaging.provider=fake is a test mode and is not allowed in the prod profile");
        }
        return new FakeMessageSender();
    }
}
