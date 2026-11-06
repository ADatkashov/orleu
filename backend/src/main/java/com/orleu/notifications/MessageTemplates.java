package com.orleu.notifications;

import java.util.Map;
import java.util.Optional;

/**
 * Customer-facing message texts in kk/ru/en. Pure and side-effect free so every template is unit-testable.
 * Kazakh and Russian texts are plain transactional wording; a native speaker should review them before launch.
 */
public final class MessageTemplates {
    public record Context(String customerName, String businessName, String serviceName, String when) {}

    private static final Map<String, Map<String, String>> T = Map.of(
        "BOOKING_CONFIRMED", Map.of(
            "en", "Hello, {name}! Your booking at {business} is confirmed: {service}, {when}.",
            "ru", "Здравствуйте, {name}! Ваша запись в «{business}» подтверждена: {service}, {when}.",
            "kk", "Сәлеметсіз бе, {name}! «{business}» бойынша жазылуыңыз расталды: {service}, {when}."),
        "BOOKING_CANCELLED", Map.of(
            "en", "Hello, {name}. Your booking at {business} ({service}, {when}) was cancelled.",
            "ru", "Здравствуйте, {name}. Ваша запись в «{business}» ({service}, {when}) отменена.",
            "kk", "Сәлеметсіз бе, {name}. «{business}» бойынша жазылуыңыз ({service}, {when}) бас тартылды."),
        "BOOKING_RESCHEDULED", Map.of(
            "en", "Hello, {name}! Your booking at {business} was moved: {service}, now {when}.",
            "ru", "Здравствуйте, {name}! Ваша запись в «{business}» перенесена: {service}, теперь {when}.",
            "kk", "Сәлеметсіз бе, {name}! «{business}» бойынша жазылуыңыз ауыстырылды: {service}, енді {when}."),
        "BOOKING_REMINDER", Map.of(
            "en", "Reminder, {name}: {service} at {business}, {when}.",
            "ru", "Напоминание, {name}: {service} в «{business}», {when}.",
            "kk", "Еске салу, {name}: «{business}», {service}, {when}."));

    private MessageTemplates() {}

    /** Event types that produce a customer message. Others (e.g. PAYMENT_RECEIVED) are business-internal. */
    public static boolean handles(String eventType) { return T.containsKey(eventType); }

    public static Optional<String> render(String eventType, String locale, Context c) {
        Map<String, String> byLocale = T.get(eventType);
        if (byLocale == null) return Optional.empty();
        String tpl = byLocale.getOrDefault(locale, byLocale.get("ru"));
        return Optional.of(tpl.replace("{name}", c.customerName()).replace("{business}", c.businessName())
                .replace("{service}", c.serviceName()).replace("{when}", c.when()));
    }
}
