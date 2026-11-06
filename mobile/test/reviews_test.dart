import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orleu_mobile/app.dart';
import 'package:orleu_mobile/core/api/api_client.dart';
import 'package:orleu_mobile/core/api/token_store.dart';

import 'support/fake_api.dart';

Future<void> open(WidgetTester tester, {required Map<String, Object?> summary, required List<Map<String, Object?>> items, bool fail = false}) async {
  setPhone(tester, 390, 1200);
  final a = FakeAdapter({
    ...businessRoutes(),
    'GET /api/v1/businesses': (_) => ok([{'id': 'b1', 'name': 'Studio', 'slug': 'studio', 'currency': 'KZT', 'planCode': 'FREE', 'published': true, 'timezone': 'Asia/Almaty'}]),
    'GET /api/v1/businesses/b1/reviews/summary': (_) => fail ? err(500, 'X') : ok(summary),
    'GET /api/v1/businesses/b1/reviews': (_) => ok(items),
  });
  final store = MemoryTokenStore()..access = 'a'..refresh = 'r';
  await tester.pumpWidget(ProviderScope(retry: appRetry, overrides: overridesFor(a, store), child: const OrleuApp()));
  await tester.pumpAndSettle();
  await tester.tap(find.text('More').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Reviews'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the measured average, count and each review with its comment as plain text', (tester) async {
    await open(tester, summary: {'count': 2, 'average': 4.5, 'distribution': [0, 0, 0, 1, 1]}, items: [
      {'id': 'r1', 'rating': 5, 'comment': 'Great <b>cut</b>', 'customerName': 'Aigerim', 'serviceName': 'Haircut', 'createdAt': '2026-11-05T05:00:00Z'},
      {'id': 'r2', 'rating': 4, 'comment': null, 'customerName': 'Dana', 'serviceName': 'Beard', 'createdAt': '2026-11-04T05:00:00Z'},
    ]);
    expect(tester.widget<Text>(find.byKey(const Key('avg'))).data, '4.5');
    expect(find.text('2 reviews'), findsOneWidget);
    expect(find.text('Great <b>cut</b>'), findsOneWidget);
    expect(find.text('★★★★★'), findsOneWidget);
    expect(find.text('★★★★☆'), findsOneWidget);
    expect(find.textContaining('Aigerim · Haircut'), findsOneWidget);
  });

  testWidgets('no reviews yet explains how reviews arrive instead of showing a fake rating', (tester) async {
    await open(tester, summary: {'count': 0, 'distribution': [0, 0, 0, 0, 0]}, items: []);
    expect(find.textContaining('No reviews yet'), findsOneWidget);
    expect(find.byKey(const Key('avg')), findsNothing);
  });

  testWidgets('a failing request shows retry', (tester) async {
    await open(tester, summary: {}, items: [], fail: true);
    expect(find.text('Retry'), findsWidgets);
  });
}
