import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orleu_mobile/core/design/theme.dart';
import 'package:orleu_mobile/core/design/tokens.dart';
import 'package:orleu_mobile/core/widgets/widgets.dart';
import 'package:orleu_mobile/l10n/gen/app_localizations.dart';

double _lum(Color c) {
  double ch(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double contrast(Color a, Color b) {
  final l1 = _lum(a), l2 = _lum(b);
  return (math.max(l1, l2) + 0.05) / (math.min(l1, l2) + 0.05);
}

Widget _host(Widget child, {bool dark = false, double width = 320, Locale locale = const Locale('en')}) => MaterialApp(
  theme: dark ? AppTheme.dark() : AppTheme.light(),
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: width,
        child: SingleChildScrollView(child: child),
      ),
    ),
  ),
);

void main() {
  group('contrast (WCAG AA 4.5:1 for text)', () {
    for (final dark in [false, true]) {
      final name = dark ? 'dark' : 'light';
      final theme = dark ? AppTheme.dark() : AppTheme.light();
      final s = theme.colorScheme;
      final p = dark ? AppPalette.dark : AppPalette.light;
      test('$name: body and secondary text on surfaces', () {
        for (final bg in [s.surface, s.surfaceContainerLowest, s.surfaceContainerLow]) {
          expect(contrast(s.onSurface, bg), greaterThanOrEqualTo(4.5));
          expect(contrast(s.onSurfaceVariant, bg), greaterThanOrEqualTo(4.5), reason: 'secondary on $bg');
        }
      });
      test('$name: status badges', () {
        for (final (bg, fg) in [
          (p.successSoft, p.successFg),
          (p.warningSoft, p.warningFg),
          (p.dangerSoft, p.dangerFg),
          (p.infoSoft, p.infoFg),
          (p.neutralSoft, p.neutralFg),
        ]) {
          expect(contrast(fg, bg), greaterThanOrEqualTo(4.5), reason: '$fg on $bg');
        }
      });
      test('$name: hero surface and primary actions', () {
        expect(contrast(p.onHero, p.heroStart), greaterThanOrEqualTo(4.5));
        expect(contrast(p.onHeroMuted, p.heroStart), greaterThanOrEqualTo(4.5));
        expect(contrast(s.onPrimary, s.primary), greaterThanOrEqualTo(4.5));
        expect(contrast(AppColors.primaryDark, AppColors.accentLime), greaterThanOrEqualTo(4.5));
      });
    }
  });

  group('components', () {
    testWidgets('booking statuses map to the semantic tones', (tester) async {
      expect(statusTone('CONFIRMED'), BadgeTone.success);
      expect(statusTone('PENDING'), BadgeTone.warning);
      expect(statusTone('IN_PROGRESS'), BadgeTone.info);
      expect(statusTone('NO_SHOW'), BadgeTone.danger);
    });

    testWidgets('search field debounces and clears', (tester) async {
      final seen = <String>[];
      await tester.pumpWidget(_host(SearchField(hint: 'Search', onChanged: seen.add)));
      await tester.enterText(find.byType(TextField), 'am');
      await tester.enterText(find.byType(TextField), 'ami');
      await tester.pump(const Duration(milliseconds: 400));
      expect(seen, ['ami']);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      expect(seen.last, '');
    });

    testWidgets('primary button ignores taps while loading', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(PrimaryButton(label: 'Save', loading: true, onPressed: () => taps++)));
      await tester.tap(find.byType(FilledButton), warnIfMissed: false);
      expect(taps, 0);
      await tester.pumpWidget(_host(PrimaryButton(label: 'Save', onPressed: () => taps++)));
      await tester.tap(find.text('Save'));
      expect(taps, 1);
    });

    testWidgets('empty state shows its action', (tester) async {
      var done = false;
      await tester.pumpWidget(_host(EmptyState(icon: Icons.people_outline, text: 'Nothing here', actionLabel: 'Add', onAction: () => done = true)));
      await tester.tap(find.text('Add'));
      expect(done, isTrue);
    });

    testWidgets('gallery fits 320px in both themes and long Kazakh/Russian labels without overflow', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 900);
      addTearDown(tester.view.reset);
      for (final dark in [false, true]) {
        await tester.pumpWidget(
          _host(
            dark: dark,
            locale: const Locale('kk'),
            Column(
              children: const [
                StatCard(
                  icon: Icons.wallet,
                  label: 'Бүгін түскен қаражат сомасы',
                  value: '184 500 000 KZT',
                  hero: true,
                  trend: '+12.8%',
                  note: 'өткен айға қарағанда',
                ),
                SizedBox(height: 8),
                StatusBadge('Төлем күтілуде · Ожидает оплаты', tone: BadgeTone.warning),
                SizedBox(height: 8),
                SectionHeader('Жақын арада келетін жазылулар', actionLabel: 'Барлығы'),
                SizedBox(height: 8),
                AnalyticsBarChart(values: [1, 3, 2, 5, 0, 4, 2], labels: ['Дс', 'Сс', 'Ср', 'Бс', 'Жм', 'Сб', 'Жк'], highlight: 6, semanticLabel: 'chart'),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: dark ? 'dark' : 'light');
      }
    });
  });
}
