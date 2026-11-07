import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orleu_mobile/app.dart';
import 'package:orleu_mobile/core/api/token_store.dart';

import 'app_flow_test.dart' show booking;
import 'support/fake_api.dart';

Map<String, Object?> paidBooking() => {...booking, 'financials': {'price': 20000, 'depositAmount': 6000, 'paid': 10000, 'refunded': 0, 'netPaid': 10000, 'remaining': 10000, 'paymentStatus': 'PARTIAL'}};

class Env {
  String role;
  int refundStatus = 201;
  double? threshold;
  var requests = <Map<String, Object?>>[];
  late final FakeAdapter adapter;

  Env({this.role = 'RECEPTIONIST'}) {
    adapter = FakeAdapter({
      ...businessRoutes(bookings: [paidBooking()]),
      'GET /api/v1/me': (_) => ok({'id': 'u1', 'email': 'a@b.kz', 'fullName': 'Aigerim', 'locale': 'en', 'memberships': [{'businessId': 'b1', 'role': role}]}),
      'POST /api/v1/businesses/b1/bookings/k1/refunds': (_) => (status: refundStatus, body: refundStatus == 201 ? paidBooking() : {'id': 'r1', 'status': 'PENDING'}),
      'GET /api/v1/businesses/b1/refund-requests': (_) => ok(requests),
      'GET /api/v1/businesses/b1/refund-policy': (_) => ok({'threshold': threshold}),
      'PUT /api/v1/businesses/b1/refund-policy': (o) { threshold = ((o.data as Map)['threshold'] as num?)?.toDouble(); return ok({'threshold': threshold}); },
      'POST /api/v1/businesses/b1/refund-requests/r1/approve': (_) { requests = [{...requests.first, 'status': 'APPROVED'}]; return ok(requests.first); },
      'POST /api/v1/businesses/b1/refund-requests/r1/reject': (_) { requests = [{...requests.first, 'status': 'REJECTED'}]; return ok(requests.first); },
    });
  }
}

Future<void> openCalendar(WidgetTester tester, Env env) async {
  setPhone(tester, 420, 1000);
  final store = MemoryTokenStore()..access = 'a'..refresh = 'r';
  await tester.pumpWidget(ProviderScope(overrides: overridesFor(env.adapter, store), child: const OrleuApp()));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Calendar').last);
  await tester.pumpAndSettle();
}

Future<void> openRefundSheet(WidgetTester tester, Env env) async {
  await openCalendar(tester, env);
  await tester.tap(find.text('Haircut').first);
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(const Key('refundAction')));
  await tester.tap(find.byKey(const Key('refundAction')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a refund is recorded with an idempotency key and confirmed', (tester) async {
    final env = Env();
    await openRefundSheet(tester, env);
    await tester.enterText(find.byKey(const Key('refundAmount')), '4000');
    await tester.tap(find.byKey(const Key('refundSave')));
    await tester.pumpAndSettle();
    final call = env.adapter.calls.firstWhere((c) => c.path.endsWith('/refunds'));
    expect(call.data, {'amount': '4000', 'method': 'CASH'});
    expect(call.headers['Idempotency-Key'], matches(RegExp(r'^[0-9a-f]{32}$')));
    expect(find.text('Refund recorded'), findsOneWidget);
  });

  testWidgets('a refund above the threshold (HTTP 202) is reported as sent for approval, not as recorded', (tester) async {
    final env = Env()..refundStatus = 202;
    await openRefundSheet(tester, env);
    await tester.enterText(find.byKey(const Key('refundAmount')), '9000');
    await tester.tap(find.byKey(const Key('refundSave')));
    await tester.pumpAndSettle();
    expect(find.text('Refund sent for approval'), findsOneWidget);
    expect(find.text('Refund recorded'), findsNothing);
  });

  testWidgets('more than was paid is rejected locally, inside the sheet', (tester) async {
    final env = Env();
    await openRefundSheet(tester, env);
    await tester.enterText(find.byKey(const Key('refundAmount')), '10001');
    await tester.tap(find.byKey(const Key('refundSave')));
    await tester.pumpAndSettle();
    expect(find.text('Enter an amount up to what has been paid'), findsOneWidget);
    expect(env.adapter.calls.any((c) => c.path.endsWith('/refunds')), isFalse);
  });

  testWidgets('a role without finance access gets no refund button', (tester) async {
    final env = Env(role: 'BRANCH_MANAGER');
    await openCalendar(tester, env);
    await tester.tap(find.text('Haircut').first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('refundAction')), findsNothing);
  });

  Future<void> openRefunds(WidgetTester tester, Env env) async {
    setPhone(tester, 420, 1000);
    final store = MemoryTokenStore()..access = 'a'..refresh = 'r';
    await tester.pumpWidget(ProviderScope(overrides: overridesFor(env.adapter, store), child: const OrleuApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('More').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Refunds'));
    await tester.pumpAndSettle();
  }

  final pending = {'id': 'r1', 'bookingId': 'k1', 'amount': 9000, 'currency': 'KZT', 'method': 'CASH', 'status': 'PENDING', 'requestedByName': 'Dana Reception'};

  testWidgets('an owner approves a pending request', (tester) async {
    final env = Env(role: 'BUSINESS_OWNER')..requests = [pending];
    await openRefunds(tester, env);
    expect(find.text('Requested by Dana Reception'), findsOneWidget);
    await tester.tap(find.byKey(const Key('approve-r1')));
    await tester.pumpAndSettle();
    expect(env.adapter.calls.any((c) => c.method == 'POST' && c.path.endsWith('/refund-requests/r1/approve')), isTrue);
    expect(find.text('Approved'), findsOneWidget);
    expect(find.byKey(const Key('approve-r1')), findsNothing);
  });

  testWidgets('a receptionist sees pending requests but has no decision buttons or policy editor', (tester) async {
    final env = Env()..requests = [pending];
    await openRefunds(tester, env);
    expect(find.byKey(const Key('refund-r1')), findsOneWidget);
    expect(find.byKey(const Key('approve-r1')), findsNothing);
    expect(find.byKey(const Key('reject-r1')), findsNothing);
    expect(find.byKey(const Key('policyThreshold')), findsNothing);
  });

  testWidgets('the owner sets and clears the approval threshold', (tester) async {
    final env = Env(role: 'BUSINESS_OWNER');
    await openRefunds(tester, env);
    expect(find.text('Off: every refund is recorded immediately.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('policyThreshold')), '5000');
    await tester.tap(find.byKey(const Key('savePolicy')));
    await tester.pumpAndSettle();
    expect(env.threshold, 5000);
    expect(find.textContaining('Approval required above'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('policyThreshold')), '');
    await tester.tap(find.byKey(const Key('savePolicy')));
    await tester.pumpAndSettle();
    expect(env.threshold, isNull);
  });
}
