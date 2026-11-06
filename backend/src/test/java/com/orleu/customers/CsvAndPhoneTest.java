package com.orleu.customers;

import com.orleu.common.PhoneNumbers;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

class CsvAndPhoneTest {
    @Test void parsesQuotesEscapedQuotesAndLineBreaksInsideQuotes() {
        var rows = CsvParser.parse("name,notes\n\"Doe, John\",\"said \"\"hi\"\"\nsecond line\"\nAnna,plain\n");
        assertEquals(3, rows.size());
        assertEquals(List.of("Doe, John", "said \"hi\"\nsecond line"), rows.get(1));
        assertEquals(List.of("Anna", "plain"), rows.get(2));
    }

    @Test void detectsSemicolonAndTabDelimitersAndStripsBomAndCrLf() {
        assertEquals(List.of("a", "b"), CsvParser.parse("﻿name;phone\r\na;b\r\n").get(1));
        assertEquals(List.of("a", "b"), CsvParser.parse("name\tphone\na\tb").get(1));
        assertEquals("name", CsvParser.parse("﻿name;phone\na;b").get(0).get(0), "BOM must not stick to the first header");
    }

    @Test void skipsBlankLinesAndKeepsEmptyFields() {
        var rows = CsvParser.parse("a,b,c\n\n,,\n1,,3\n");
        assertEquals(2, rows.size());
        assertEquals(List.of("1", "", "3"), rows.get(1));
    }

    @Test void normalisesKazakhstanPhoneFormatsAndRejectsGarbage() {
        assertEquals("+77011234567", PhoneNumbers.normalize("8 701 123 45 67"));
        assertEquals("+77011234567", PhoneNumbers.normalize("7(701)123-45-67"));
        assertEquals("+77011234567", PhoneNumbers.normalize("+7 701 123 45 67"));
        assertEquals("+77011234567", PhoneNumbers.normalize("+7.701.123.45.67"));
        assertEquals("+4915112345678", PhoneNumbers.normalize("+49 151 123 456 78"));
        assertNull(PhoneNumbers.normalize("701 123 45 67"), "no country code: not guessed");
        assertNull(PhoneNumbers.normalize("abc"));
        assertNull(PhoneNumbers.normalize(""));
        assertNull(PhoneNumbers.normalize(null));
        assertNull(PhoneNumbers.normalize("+0123456789"));
    }
}
