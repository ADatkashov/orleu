import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orleu_mobile/app.dart';
import 'package:orleu_mobile/core/api/token_store.dart';

import 'support/fake_api.dart';

Map<String, Handler> routes({bool empty = false, bool failBreakdown = false}) => {
      ...businessRoutes(),
      'GET /api/v1/businesses': (_) => ok([{'id': 'b1', 'name': 'Studio', 'slug': 'studio', 'currency': 'KZT', 'planCode': 'FREE', 'published': true, 'timezone': 'Asia/Almaty'}]),
      'GET /api/v1/businesses/b1/analytics/breakdown': (o) {
        if (failBreakdown) return err(500, 'INTERNAL');
        if (empty) return ok([]);
        final by = o.queryParameters['by'];
        return ok(switch (by) {
          'SERVICE' => [row('Haircut', 5, 40000), row('Beard', 1, 0)],
          'EMPLOYEE' => [row('Master Dana', 4, 25000)],
          _ => [row('Main branch', 6, 40000)],
        });
      },
      'GET /api/v1/businesses/b1/analytics/timeseries': (_) => ok(empty ? [] : [
            for (var i = 0; i < 7; i++) {'date': '2026-11-0${i + 1}', 'bookings': i, 'completed': 0, 'bookedValue': 0, 'netCollected': i * 1000}
          ]),
      'GET /api/v1/businesses/b1/analytics/peak-hours': (_) => ok(empty ? List.filled(24, 0) : [for (var h = 0; h < 24; h++) h == 10 ? 4 : 0]),
      'GET /api/v1/businesses/b1/analytics/customers': (_) => ok({'newCustomers': empty ? 0 : 3, 'returningCustomers': empty ? 0 : 2, 'returningShare': empty ? 0 : 0.4}),
    };

Map<String, Object?> row(String name, int bookings, num net) => {
      'id': name, 'name': name, 'bookings': bookings, 'completed': 1, 'cancelled': 0, 'noShows': 0,
      'bookedValue': net, 'collected': net, 'refunded': 0, 'netCollected': net,
    };

Future<FakeAdapter> open(WidgetTester tester, Map<String, Handler> r) async {
  setPhone(tester, 390, 1800);
  final a = FakeAdapter(r);
  final store = MemoryTokenStore()..access = 'a'..refresh = 'r';
  await tester.pumpWidget(ProviderScope(overrides: overridesFor(a, store), child: const OrleuApp()));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Finance').last);
  await tester.pumpAndSettle();
  await tester.drag(find.byType(ListView).first, const Offset(0, -900));
  await tester.pumpAndSettle();
  return a;
}

void main() {
  testWidgets('reports show real breakdowns, charts and customer mix from the API', (tester) async {
    final a = await open(tester, routes());
    expect(find.text('Reports'), findsOneWidget);
    expect(find.text('Haircut'), findsOneWidget);
    expect(find.text('Master Dana'), findsOneWidget);
    expect(find.text('5 bookings'), findsOneWidget);
    expect(find.byKey(const Key('daily-chart')), findsOneWidget);
    expect(find.byKey(const Key('peak-chart')), findsOneWidget);
    expect(find.text('40% of customers returned'), findsOneWidget);
    final first = a.calls.firstWhere((c) => c.path.endsWith('/analytics/timeseries'));
    expect(first.queryParameters.containsKey('from') && first.queryParameters.containsKey('to'), isTrue);
  });

  testWidgets('changing the period refetches with a different range', (tester) async {
    final a = await open(tester, routes());
    String fromOf() => a.calls.lastWhere((c) => c.path.endsWith('/analytics/timeseries')).queryParameters['from'] as String;
    final before = DateTime.parse(fromOf());
    await tester.tap(find.text('90 days'));
    await tester.pumpAndSettle();
    final after = DateTime.parse(fromOf());
    expect(before.difference(after).inDays, 60);
  });

  testWidgets('empty period says so instead of drawing empty charts', (tester) async {
    await open(tester, routes(empty: true));
    expect(find.text('No data for this period yet'), findsWidgets);
    expect(find.byKey(const Key('daily-chart')), findsNothing);
    expect(find.byKey(const Key('peak-chart')), findsNothing);
  });

  testWidgets('a failing report shows a retry, not zeros', (tester) async {
    await open(tester, routes(failBreakdown: true));
    expect(find.text('Haircut'), findsNothing);
    expect(find.text('Retry'), findsWidgets);
  });
}
