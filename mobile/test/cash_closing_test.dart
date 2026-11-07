import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orleu_mobile/app.dart';
import 'package:orleu_mobile/core/api/token_store.dart';

import 'support/fake_api.dart';

class Env {
  String role;
  double expected = 13000;
  Handler? closeOverride;
  var closings = <Map<String, Object?>>[];
  late final FakeAdapter adapter;

  Env({this.role = 'BUSINESS_OWNER'}) {
    adapter = FakeAdapter({
      ...businessRoutes(),
      'GET /api/v1/me': (_) => ok({'id': 'u1', 'email': 'a@b.kz', 'fullName': 'Aigerim', 'locale': 'en', 'memberships': [{'businessId': 'b1', 'role': role}]}),
      'GET /api/v1/businesses/b1/finance/closing-preview': (_) => ok({
            'periodStart': '2026-11-07T00:00:00Z', 'periodEnd': '2026-11-07T10:00:00Z', 'currency': 'KZT', 'firstClosing': closings.isEmpty,
            'cash': {'payments': expected + 2000, 'refunds': 2000, 'net': expected}, 'bank': {'payments': 7000, 'refunds': 0, 'net': 7000}, 'card': {'payments': 3000, 'refunds': 0, 'net': 3000},
          }),
      'GET /api/v1/businesses/b1/finance/closings': (_) => ok(closings),
      'POST /api/v1/businesses/b1/finance/closings': (o) => closeOverride?.call(o) ?? (() {
            final d = o.data as Map;
            closings = [{'id': 'c1', 'currency': 'KZT', 'periodStart': '2026-11-07T00:00:00Z', 'periodEnd': '2026-11-07T10:00:00Z', 'expectedCash': 13000, 'countedCash': double.parse(d['countedCash']),
              'difference': double.parse(d['countedCash']) - 13000, 'note': d['note'], 'closedByName': 'Aigerim'}];
            return (status: 201, body: closings.first);
          })(),
    });
  }
}

Future<void> openClosing(WidgetTester tester, Env env) async {
  setPhone(tester, 420, 1400);
  final store = MemoryTokenStore()..access = 'a'..refresh = 'r';
  await tester.pumpWidget(ProviderScope(overrides: overridesFor(env.adapter, store), child: const OrleuApp()));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Finance').last);
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(const Key('openClosing')));
  await tester.tap(find.byKey(const Key('openClosing')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the expected cash, a live shortage and sends expected + counted exactly', (tester) async {
    final env = Env();
    await openClosing(tester, env);
    expect(find.byKey(const Key('closingFirst')), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('confirmClosing'))).onPressed, isNull, reason: 'nothing counted yet');
    await tester.enterText(find.byKey(const Key('countedCash')), '12500');
    await tester.pump();
    expect(find.textContaining('Shortage'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('closingNote')), 'change');
    await tester.ensureVisible(find.byKey(const Key('confirmClosing')));
    await tester.tap(find.byKey(const Key('confirmClosing')));
    await tester.pumpAndSettle();
    final post = env.adapter.calls.firstWhere((c) => c.method == 'POST' && c.path.endsWith('/finance/closings'));
    expect(post.data, {'expectedCash': '13000.00', 'countedCash': '12500.00', 'note': 'change'});
    expect(find.text('Register closed'), findsOneWidget);
    expect(find.byKey(const Key('closing-c1')), findsOneWidget);
  });

  testWidgets('an exact match is shown as matching', (tester) async {
    final env = Env();
    await openClosing(tester, env);
    await tester.enterText(find.byKey(const Key('countedCash')), '13000');
    await tester.pump();
    expect(find.text('Matches the expected cash.'), findsOneWidget);
  });

  testWidgets('when payments changed (409) the message is shown inline and the new expected cash is loaded', (tester) async {
    final env = Env()..closeOverride = (_) => err(409, 'EXPECTED_CHANGED');
    await openClosing(tester, env);
    await tester.enterText(find.byKey(const Key('countedCash')), '13000');
    await tester.pump();
    env.expected = 14000;
    await tester.ensureVisible(find.byKey(const Key('confirmClosing')));
    await tester.tap(find.byKey(const Key('confirmClosing')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Payments changed while you were counting'), findsOneWidget);
    expect(find.byKey(const Key('formError')), findsOneWidget);
    expect(find.textContaining('14'), findsWidgets, reason: 'the refreshed expected cash');
    expect(find.text('Register closed'), findsNothing);
  });

  testWidgets('a role without finance management has no closing button', (tester) async {
    final env = Env(role: 'STAFF');
    setPhone(tester, 420, 1400);
    final store = MemoryTokenStore()..access = 'a'..refresh = 'r';
    await tester.pumpWidget(ProviderScope(overrides: overridesFor(env.adapter, store), child: const OrleuApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finance').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('openClosing')), findsNothing);
  });
}
