package com.orleu.portal;

import java.util.Map;

/** SMS text of the portal sign-in code in kk/ru/en. Short on purpose (one SMS), no link. Native-speaker review needed before launch. */
final class PortalMessages {
    private static final Map<String, String> T = Map.of(
            "en", "{business}: your sign-in code is {code}. Valid {minutes} min. Do not share it with anyone.",
            "ru", "{business}: код входа {code}. Действует {minutes} мин. Никому не сообщайте его.",
            "kk", "{business}: кіру коды {code}. {minutes} минут жарамды. Ешкімге айтпаңыз.");

    private PortalMessages() {}

    static String code(String locale, String business, String code, int minutes) {
        String tpl = T.getOrDefault(locale, T.get("ru"));
        String b = business == null ? "ORLEU" : (business.length() > 30 ? business.substring(0, 30) : business);
        return tpl.replace("{business}", b).replace("{code}", code).replace("{minutes}", String.valueOf(minutes));
    }
}
