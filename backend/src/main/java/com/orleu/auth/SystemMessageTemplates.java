package com.orleu.auth;

import java.util.Map;

/** Texts of system e-mails in kk/ru/en. Pure, so they are unit-tested. Native-speaker review is needed before launch. */
public final class SystemMessageTemplates {
    public record Rendered(String subject, String body) {}

    private static final Map<String, String> RESET_SUBJECT = Map.of(
            "en", "Reset your ORLEU password", "ru", "Сброс пароля ORLEU", "kk", "ORLEU құпия сөзін қалпына келтіру");
    private static final Map<String, String> RESET_BODY = Map.of(
            "en", "Someone asked to reset the password of your ORLEU account.\n\nYour reset code: {token}\n{link}\nIt works once and expires in {minutes} minutes. If this was not you, ignore this message: your password has not changed.",
            "ru", "Для вашей учётной записи ORLEU запрошен сброс пароля.\n\nВаш код сброса: {token}\n{link}\nОн действует один раз и истекает через {minutes} мин. Если это были не вы, просто проигнорируйте письмо: пароль не изменён.",
            "kk", "ORLEU тіркелгіңіздің құпия сөзін қалпына келтіру сұралды.\n\nҚалпына келтіру коды: {token}\n{link}\nОл бір рет қана жұмыс істейді және {minutes} минуттан кейін аяқталады. Бұл сіз болмасаңыз, хатты елемеңіз: құпия сөз өзгермеген.");

    private SystemMessageTemplates() {}

    /** {@code linkBase} may be empty (no web app configured); then only the code is shown. */
    public static Rendered passwordReset(String locale, String token, String linkBase, int minutes) {
        String l = RESET_SUBJECT.containsKey(locale) ? locale : "ru";
        String link = linkBase == null || linkBase.isBlank() ? "" : linkBase.replaceAll("/+$", "") + "/reset?token=" + token + "\n";
        return new Rendered(RESET_SUBJECT.get(l), RESET_BODY.get(l).replace("{token}", token).replace("{link}", link).replace("{minutes}", String.valueOf(minutes)));
    }
}
