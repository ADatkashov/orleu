import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orleu_mobile/app.dart';
import 'package:orleu_mobile/core/api/api_client.dart';
import 'package:orleu_mobile/core/api/token_store.dart';

import 'package:orleu_mobile/features/setup/setup_common.dart';

import 'support/fake_api.dart';

class Env {
  List<Map<String, Object?>> promos = [
    {'id': 'p1', 'code': 'SUMMER15', 'kind': 'PERCENT', 'value': 15, 'validUntil': null, 'maxUses': 10, 'usedCount': 3, 'serviceId': null, 'active': true},
    {'id': 'p2', 'code': 'MINUS2000', 'kind': 'FIXED', 'value': 2000, 'validUntil': '2026-12-31', 'maxUses': null, 'usedCount': 0, 'serviceId': null, 'active': false},
  ];
  Handler? postOverride;
  late final FakeAdapter adapter = FakeAdapter({
    ...businessRoutes(),
    'GET /api/v1/businesses': (_) => ok([{'id': 'b1', 'name': 'Studio', 'slug': 'studio', 'currency': 'KZT', 'planCode': 'FREE', 'published': true, 'timezone': 'Asia/Almaty'}]),
    'GET /api/v1/businesses/b1/promo-codes': (_) => ok(promos),
    'PATCH /api/v1/businesses/b1/promo-codes/p1': (o) { promos[0] = {...promos[0], 'active': (o.data as Map)['active']}; return (status: 200, body: null); },
    'POST /api/v1/businesses/b1/promo-codes': (o) => postOverride?.call(o) ?? (() {
          final d = o.data as Map;
          promos = [{'id': 'p3', 'code': (d['code'] as String).toUpperCase(), 'kind': d['kind'], 'value': double.parse(d['value']), 'validUntil': d['validUntil'], 'maxUses': d['maxUses'], 'usedCount': 0, 'serviceId': null, 'active': true}, ...promos];
          return ok(promos.first);
        })(),
  });
}

Future<void> open(WidgetTester tester, Env e) async {
  setPhone(tester, 390, 1200);
  final store = MemoryTokenStore()..access = 'a'..refresh = 'r';
  await tester.pumpWidget(ProviderScope(retry: appRetry, overrides: overridesFor(e.adapter, store), child: const OrleuApp()));
  await tester.pumpAndSettle();
  await tester.tap(find.text('More').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Promo codes'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists codes with discount, usage and validity and toggles one off/on', (tester) async {
    final e = Env();
    await open(tester, e);
    expect(find.text('SUMMER15'), findsOneWidget);
    expect(find.textContaining('15% off'), findsOneWidget);
    expect(find.textContaining('Used 3 / 10'), findsOneWidget);
    expect(find.textContaining('until 31.12.2026'), findsOneWidget);
    expect(tester.widget<SwitchListTile>(find.byKey(const Key('promo-SUMMER15'))).value, true);
    expect(tester.widget<SwitchListTile>(find.byKey(const Key('promo-MINUS2000'))).value, false);
    await tester.tap(find.byKey(const Key('promo-SUMMER15')));
    await tester.pumpAndSettle();
    final patch = e.adapter.calls.firstWhere((c) => c.method == 'PATCH');
    expect(patch.data, {'active': false});
    expect(tester.widget<SwitchListTile>(find.byKey(const Key('promo-SUMMER15'))).value, false);
  });

  testWidgets('creating a code sends exact values; validation blocks bad input; server errors stay inline in the dialog', (tester) async {
    final e = Env();
    await open(tester, e);
    await tester.tap(find.byKey(const Key('addPromo')));
    await tester.pumpAndSettle();
    // percent over 100 and short code are rejected locally, nothing is sent
    await tester.enterText(find.byKey(const Key('promoCode')), 'ab');
    await tester.enterText(find.byKey(const Key('promoValue')), '150');
    await tester.tap(find.byKey(const Key('savePromo')));
    await tester.pumpAndSettle();
    expect(e.adapter.calls.where((c) => c.method == 'POST'), isEmpty);

    // server-side rejection is shown inside the dialog (not a SnackBar behind the modal)
    e.postOverride = (_) => err(409, 'CODE_EXISTS');
    await tester.enterText(find.byKey(const Key('promoCode')), 'summer15');
    await tester.enterText(find.byKey(const Key('promoValue')), '15');
    await tester.tap(find.byKey(const Key('savePromo')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.byType(FormError), findsOneWidget);

    e.postOverride = null;
    await tester.enterText(find.byKey(const Key('promoCode')), 'spring10');
    await tester.enterText(find.byKey(const Key('promoValue')), '10');
    await tester.enterText(find.byKey(const Key('promoMax')), '5');
    await tester.tap(find.byKey(const Key('savePromo')));
    await tester.pumpAndSettle();
    final body = e.adapter.calls.where((c) => c.method == 'POST').last.data as Map;
    expect(body, {'code': 'spring10', 'kind': 'PERCENT', 'value': '10', 'maxUses': 5, 'validUntil': null});
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('SPRING10'), findsOneWidget);
  });

  testWidgets('empty state explains what promo codes are for', (tester) async {
    final e = Env()..promos = [];
    await open(tester, e);
    expect(find.textContaining('No promo codes yet'), findsOneWidget);
  });
}
