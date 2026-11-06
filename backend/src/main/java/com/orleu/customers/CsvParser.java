package com.orleu.customers;

import java.util.ArrayList;
import java.util.List;

/**
 * Minimal RFC 4180 CSV reader: quoted fields, doubled quotes, line breaks inside quotes, BOM. The delimiter (comma, semicolon
 * or tab) is detected from the first line because Excel in Russian/Kazakh locales exports semicolon-separated files.
 */
final class CsvParser {
    private CsvParser() {}

    static List<List<String>> parse(String text) {
        String s = text.startsWith("﻿") ? text.substring(1) : text;
        char delim = detectDelimiter(s);
        List<List<String>> rows = new ArrayList<>();
        List<String> row = new ArrayList<>();
        StringBuilder cur = new StringBuilder();
        boolean quoted = false, fieldStarted = false;
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            if (quoted) {
                if (c == '"') {
                    if (i + 1 < s.length() && s.charAt(i + 1) == '"') { cur.append('"'); i++; } else quoted = false;
                } else cur.append(c);
            } else if (c == '"' && cur.length() == 0 && !fieldStarted) {
                quoted = true; fieldStarted = true;
            } else if (c == delim) {
                row.add(cur.toString()); cur.setLength(0); fieldStarted = false;
            } else if (c == '\n' || c == '\r') {
                if (c == '\r' && i + 1 < s.length() && s.charAt(i + 1) == '\n') i++;
                row.add(cur.toString()); cur.setLength(0); fieldStarted = false;
                addRow(rows, row);
                row = new ArrayList<>();
            } else { cur.append(c); fieldStarted = true; }
        }
        if (cur.length() > 0 || fieldStarted || !row.isEmpty()) { row.add(cur.toString()); addRow(rows, row); }
        return rows;
    }

    private static void addRow(List<List<String>> rows, List<String> row) {
        boolean blank = row.stream().allMatch(f -> f.isBlank());
        if (!blank) rows.add(row);
    }

    private static char detectDelimiter(String s) {
        int end = s.indexOf('\n');
        String first = end < 0 ? s : s.substring(0, end);
        int comma = 0, semi = 0, tab = 0;
        boolean q = false;
        for (char c : first.toCharArray()) {
            if (c == '"') q = !q;
            else if (!q) { if (c == ',') comma++; else if (c == ';') semi++; else if (c == '\t') tab++; }
        }
        if (semi > comma && semi >= tab) return ';';
        if (tab > comma) return '\t';
        return ',';
    }
}
