import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orleu_mobile/app.dart';
import 'package:orleu_mobile/core/api/api_client.dart';
import 'package:orleu_mobile/core/api/token_store.dart';

import 'support/fake_api.dart';

Future<void> open(WidgetTester tester, Map<String, Object?> history, {bool fail = false}) async {
  setPhone(tester, 390, 1600);
  final a = FakeAdapter({
    ...businessRoutes(),
    'GET /api/v1/auth/sessions': (_) => ok([]),
    'GET /api/v1/auth/mfa': (_) => ok({'enabled': false, 'recoveryCodesLeft': 0}),
    'GET /api/v1/auth/login-history': (_) => fail ? err(500, 'X') : ok(history),
  });
  final store = MemoryTokenStore()..access = 'a'..refresh = 'r';
  await tester.pumpWidget(ProviderScope(retry: appRetry, overrides: overridesFor(a, store), child: const OrleuApp()));
  await tester.pumpAndSettle();
  await tester.tap(find.text('More').last);
  await tester.pumpAndSettle();
  await tester.drag(find.byType(ListView).first, const Offset(0, -300));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Account & security'));
  await tester.pumpAndSettle();
  await tester.drag(find.byType(ListView).first, const Offset(0, -700));
  await tester.pumpAndSettle();
}

Map<String, Object?> ev(String outcome, {bool newDevice = false, bool mfa = false, String ua = 'Orleu/1.0'}) =>
    {'outcome': outcome, 'ip': '10.1.2.3', 'userAgent': ua, 'mfaUsed': mfa, 'newDevice': newDevice, 'occurredAt': '2026-11-05T10:00:00Z'};

void main() {
  testWidgets('failed attempts and a new device raise an alert above the list of recent sign-ins', (tester) async {
    await open(tester, {'events': [ev('FAILED_PASSWORD'), ev('FAILED_PASSWORD'), ev('SUCCESS', newDevice: true, mfa: true, ua: 'Mozilla/5.0'), ev('SUCCESS')], 'failedSinceLastSuccess': 2, 'newDeviceRecently': true});
    expect(find.byKey(const Key('historyAlert')), findsOneWidget);
    expect(find.text('2 failed sign-in attempts since your last successful sign-in.'), findsOneWidget);
    expect(find.text('A sign-in from a new device was recorded in the last 7 days.'), findsOneWidget);
    expect(find.text('Wrong password'), findsNWidgets(2));
    expect(find.text('Signed in (with code) · New device'), findsOneWidget);
    expect(find.textContaining('10.1.2.3 · Mozilla/5.0'), findsOneWidget);
  });

  testWidgets('a clean history shows no alert', (tester) async {
    await open(tester, {'events': [ev('SUCCESS')], 'failedSinceLastSuccess': 0, 'newDeviceRecently': false});
    expect(find.byKey(const Key('historyAlert')), findsNothing);
    expect(find.text('Signed in'), findsOneWidget);
  });

  testWidgets('no events yet and a failing request are both handled', (tester) async {
    await open(tester, {'events': [], 'failedSinceLastSuccess': 0, 'newDeviceRecently': false});
    expect(find.text('No sign-ins recorded yet'), findsOneWidget);
  });

  testWidgets('a failing history request shows retry instead of an empty list', (tester) async {
    await open(tester, {}, fail: true);
    expect(find.text('Retry'), findsWidgets);
    expect(find.text('No sign-ins recorded yet'), findsNothing);
  });
}
