package com.orleu.notifications;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class MessageTemplatesTest {
    private static final MessageTemplates.Context CTX = new MessageTemplates.Context("Aigerim", "Studio Almaty", "Haircut", "07.11.2026 10:00");

    @Test void everyTypeRendersInEveryLocaleWithAllValuesAndNoLeftoverPlaceholders() {
        for (String type : new String[]{"BOOKING_CONFIRMED", "BOOKING_CANCELLED", "BOOKING_RESCHEDULED", "BOOKING_REMINDER"}) {
            for (String loc : new String[]{"kk", "ru", "en"}) {
                String text = MessageTemplates.render(type, loc, CTX).orElseThrow();
                for (String v : new String[]{"Aigerim", "Studio Almaty", "Haircut", "07.11.2026 10:00"}) assertTrue(text.contains(v), type + "/" + loc + " lacks " + v + ": " + text);
                assertFalse(text.contains("{"), type + "/" + loc + ": " + text);
            }
        }
    }

    @Test void localesDiffer() {
        String en = MessageTemplates.render("BOOKING_REMINDER", "en", CTX).orElseThrow();
        assertNotEquals(en, MessageTemplates.render("BOOKING_REMINDER", "ru", CTX).orElseThrow());
        assertNotEquals(en, MessageTemplates.render("BOOKING_REMINDER", "kk", CTX).orElseThrow());
        assertTrue(MessageTemplates.render("BOOKING_REMINDER", "ru", CTX).orElseThrow().contains("Напоминание"));
    }

    @Test void internalEventsProduceNoCustomerMessage() {
        assertFalse(MessageTemplates.handles("PAYMENT_RECEIVED"));
        assertTrue(MessageTemplates.render("PAYMENT_RECEIVED", "en", CTX).isEmpty());
    }
}
