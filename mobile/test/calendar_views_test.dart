import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orleu_mobile/app.dart';
import 'package:orleu_mobile/core/api/token_store.dart';

import 'support/fake_api.dart';

/// Bookings are positioned relative to the REQUESTED range start so the tests do not depend on today's date:
/// the range start is local midnight in Asia/Almaty (UTC+5), so +6h is 11:00 local.
Map<String, Object?> bk(String id, DateTime from, int dayOffset, {String status = 'CONFIRMED', String employee = 'e1', String branch = 'br1', String service = 'Haircut'}) {
  final s = from.toUtc().add(Duration(days: dayOffset, hours: 6));
  return {
    'id': id, 'branchId': branch, 'serviceId': 's', 'serviceName': service, 'employeeId': employee, 'employeeName': employee == 'e1' ? 'Master Dana' : 'Master Ali',
    'customerId': 'c', 'customerName': 'Aigerim', 'customerPhone': '+77011234567',
    'startsAt': s.toIso8601String(), 'endsAt': s.add(const Duration(hours: 1)).toIso8601String(), 'status': status, 'currency': 'KZT', 'notes': null, 'holdExpiresAt': null,
    'financials': {'price': 20000, 'depositAmount': 0, 'paid': 0, 'refunded': 0, 'netPaid': 0, 'remaining': 20000, 'paymentStatus': 'UNPAID'},
  };
}

class Env {
  late final FakeAdapter adapter;
  Env() {
    adapter = FakeAdapter({
      ...businessRoutes(),
      'GET /api/v1/businesses': (_) => ok([{'id': 'b1', 'name': 'Studio', 'slug': 'studio', 'currency': 'KZT', 'planCode': 'FREE', 'published': true, 'timezone': 'Asia/Almaty'}]),
      'GET /api/v1/businesses/b1/employees': (_) => ok([
            {'id': 'e1', 'displayName': 'Master Dana', 'active': true, 'branchIds': ['br1'], 'serviceIds': ['s']},
            {'id': 'e2', 'displayName': 'Master Ali', 'active': true, 'branchIds': ['br2'], 'serviceIds': ['s']},
          ]),
      'GET /api/v1/businesses/b1/branches': (_) => ok([
            {'id': 'br1', 'name': 'Abay branch', 'active': true, 'hours': []},
            {'id': 'br2', 'name': 'Dostyk branch', 'active': true, 'hours': []},
          ]),
      'GET /api/v1/businesses/b1/bookings': (o) {
        final from = DateTime.parse(o.queryParameters['from']);
        final emp = o.queryParameters['employeeId'];
        final all = [
          bk('k1', from, 1, service: 'Haircut'),
          bk('k2', from, 1, service: 'Beard', employee: 'e2', branch: 'br2'),
          bk('k3', from, 1, status: 'CANCELLED', service: 'Cancelled one'),
          bk('k4', from, 3, service: 'Manicure'),
        ];
        return ok(emp == null ? all : all.where((b) => b['employeeId'] == emp).toList());
      },
    });
  }
}

Future<Env> open(WidgetTester tester) async {
  setPhone(tester, 390, 1400);
  final e = Env();
  final store = MemoryTokenStore()..access = 'a'..refresh = 'r';
  await tester.pumpWidget(ProviderScope(overrides: overridesFor(e.adapter, store), child: const OrleuApp()));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Calendar').last);
  await tester.pumpAndSettle();
  return e;
}

Future<void> mode(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(of: find.byKey(const Key('calMode')), matching: find.text(label)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('week view lists seven days, groups bookings per day, counts only time-occupying ones', (tester) async {
    await open(tester);
    await mode(tester, 'Week');
    for (var i = 0; i < 7; i++) { expect(find.byKey(Key('weekDay-$i')), findsOneWidget); }
    expect(find.text('Haircut'), findsOneWidget);
    expect(find.text('Manicure'), findsOneWidget);
    expect(find.text('2 bookings'), findsOneWidget); // Tuesday: k1 + k2, the cancelled k3 is listed but not counted
    expect(find.text('Cancelled one'), findsOneWidget);
  });

  testWidgets('tapping a day in the week view opens that day', (tester) async {
    final e = await open(tester);
    await mode(tester, 'Week');
    await tester.tap(find.byKey(const Key('weekDay-1')));
    await tester.pumpAndSettle();
    final last = e.adapter.calls.lastWhere((c) => c.path.endsWith('/bookings'));
    final span = DateTime.parse(last.queryParameters['to']).difference(DateTime.parse(last.queryParameters['from']));
    expect(span.inHours, inInclusiveRange(23, 25), reason: 'day view requests a single day');
  });

  testWidgets('month view shows per-day counts and opens a day', (tester) async {
    final e = await open(tester);
    await mode(tester, 'Month');
    expect(find.byKey(const Key('monthCount-2')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('monthCount-2'))).data, '2'); // k1+k2, cancelled excluded
    expect(tester.widget<Text>(find.byKey(const Key('monthCount-4'))).data, '1');
    final req = e.adapter.calls.lastWhere((c) => c.path.endsWith('/bookings'));
    expect(DateTime.parse(req.queryParameters['to']).difference(DateTime.parse(req.queryParameters['from'])).inDays, inInclusiveRange(28, 31));
    await tester.tap(find.byKey(const Key('monthDay-2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('monthDay-2')), findsNothing); // back in the day view
  });

  testWidgets('specialist filter is applied by the server, location filter on the client', (tester) async {
    final e = await open(tester);
    await mode(tester, 'Week');
    expect(find.text('Beard'), findsOneWidget);
    await tester.tap(find.byKey(const Key('filterBranch')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abay branch').last);
    await tester.pumpAndSettle();
    expect(find.text('Beard'), findsNothing);
    expect(find.text('Haircut'), findsOneWidget);

    await tester.tap(find.byKey(const Key('filterBranch')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All locations').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('filterEmployee')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Master Ali').last);
    await tester.pumpAndSettle();
    expect(e.adapter.calls.last.queryParameters['employeeId'], 'e2');
    expect(find.text('Beard'), findsOneWidget);
    expect(find.text('Haircut'), findsNothing);
  });

  testWidgets('previous / next move by the size of the current view', (tester) async {
    final e = await open(tester);
    await mode(tester, 'Week');
    DateTime fromOf() => DateTime.parse(e.adapter.calls.lastWhere((c) => c.path.endsWith('/bookings')).queryParameters['from']);
    final w0 = fromOf();
    await tester.tap(find.byKey(const Key('next')));
    await tester.pumpAndSettle();
    expect(fromOf().difference(w0).inDays, 7);
    await mode(tester, 'Month');
    final m0 = fromOf();
    await tester.tap(find.byKey(const Key('prev')));
    await tester.pumpAndSettle();
    expect(m0.difference(fromOf()).inDays, inInclusiveRange(28, 31));
  });
}
