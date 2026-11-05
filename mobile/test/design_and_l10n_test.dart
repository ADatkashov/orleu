import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orleu_mobile/core/design/theme.dart';
import 'package:orleu_mobile/core/design/tokens.dart';

void main() {
  test('light theme uses the ORLEU brand tokens', () {
    final t = AppTheme.light();
    expect(t.colorScheme.primary, AppColors.primaryGreen);
    expect(t.scaffoldBackgroundColor, const Color(0xFFF7F8F5));
    expect(t.colorScheme.surface, Colors.white);
    expect(t.colorScheme.secondaryContainer, const Color(0xFFC7F36B));
  });

  test('dark theme uses the dark tokens', () {
    final t = AppTheme.dark();
    expect(t.scaffoldBackgroundColor, const Color(0xFF101B16));
    expect(t.colorScheme.primary, const Color(0xFFC7F36B));
    expect(t.colorScheme.surface, const Color(0xFF18251E));
  });

  test('primary text keeps WCAG AA contrast on background and surface', () {
    double lum(Color c) {
      double ch(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
      return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
    }
    double ratio(Color a, Color b) {
      final l1 = lum(a), l2 = lum(b);
      return (l1 > l2 ? l1 + 0.05 : l2 + 0.05) / (l1 > l2 ? l2 + 0.05 : l1 + 0.05);
    }
    expect(ratio(AppColors.textPrimary, AppColors.background), greaterThan(4.5));
    expect(ratio(AppColors.textSecondary, AppColors.surface), greaterThan(4.5));
    expect(ratio(AppColors.textSecondary, AppColors.background), greaterThan(4.5));
    expect(ratio(Colors.white, AppColors.primaryGreen), greaterThan(4.5));
    expect(ratio(AppColors.darkText, AppColors.darkBackground), greaterThan(4.5));
  });

  test('kk, ru and en ARB files define exactly the same keys', () {
    Set<String> keys(String lang) => (jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync()) as Map<String, dynamic>)
        .keys.where((k) => !k.startsWith('@')).toSet();
    final en = keys('en');
    expect(keys('ru'), en, reason: 'ru is missing/extra keys');
    expect(keys('kk'), en, reason: 'kk is missing/extra keys');
  });

  test('no translation is left empty or identical-by-accident for the tagline', () {
    Map<String, dynamic> arb(String l) => jsonDecode(File('lib/l10n/app_$l.arb').readAsStringSync());
    for (final l in ['en', 'ru', 'kk']) {
      for (final e in arb(l).entries.where((e) => !e.key.startsWith('@'))) {
        expect((e.value as String).trim(), isNotEmpty, reason: '$l:${e.key}');
      }
    }
    expect(arb('kk')['tagline'], isNot(arb('ru')['tagline']));
    expect(arb('en')['tagline'], 'Your Business. Your Growth.');
  });
}
