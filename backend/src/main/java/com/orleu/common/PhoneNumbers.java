package com.orleu.common;

import java.util.regex.Pattern;

/** Phone normalisation to E.164 for Kazakhstan-style input (8 701 123 45 67, 7(701)123-45-67). Same rules as the apps and the booking page. */
public final class PhoneNumbers {
    private static final Pattern E164 = Pattern.compile("^\\+[1-9][0-9]{7,14}$");
    private PhoneNumbers() {}

    /** @return the E.164 number, or null if the input cannot be interpreted as one. */
    public static String normalize(String raw) {
        if (raw == null) return null;
        String d = raw.replaceAll("[\\s\\-().]", "");
        if (d.matches("^8\\d{10}$")) d = "+7" + d.substring(1);
        else if (d.matches("^7\\d{10}$")) d = "+" + d;
        return E164.matcher(d).matches() ? d : null;
    }
}
