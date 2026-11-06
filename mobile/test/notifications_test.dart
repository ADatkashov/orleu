import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orleu_mobile/app.dart';
import 'package:orleu_mobile/core/api/api_client.dart';
import 'package:orleu_mobile/core/api/token_store.dart';

import 'support/fake_api.dart';

class Env {
  var items = <Map<String, Object?>>[
    {'id': 'n1', 'eventType': 'BOOKING_CREATED', 'bookingId': 'k1', 'createdAt': '2026-11-05T05:00:00Z', 'read': false, 'customerName': 'Aigerim', 'serviceName': 'Haircut', 'startsAt': '2026-11-12T06:00:00Z'},
    {'id': 'n2', 'eventType': 'SUPPORT_REPLIED', 'bookingId': null, 'createdAt': '2026-11-05T06:00:00Z', 'read': false},
    {'id': 'n3', 'eventType': 'PAYMENT_RECEIVED', 'bookingId': 'k1', 'createdAt': '2026-11-04T06:00:00Z', 'read': true, 'customerName': 'Dana', 'serviceName': 'Beard', 'startsAt': '2026-11-13T06:00:00Z'},
    {'id': 'n4', 'eventType': 'SOMETHING_NEW', 'bookingId': null, 'createdAt': '2026-11-03T06:00:00Z', 'read': true},
  ];
  Handler? markOverride;
  late final FakeAdapter adapter = FakeAdapter({
    ...businessRoutes(),
    'GET /api/v1/businesses': (_) => ok([{'id': 'b1', 'name': 'Studio', 'slug': 'studio', 'currency': 'KZT', 'planCode': 'FREE', 'published': true, 'timezone': 'Asia/Almaty'}]),
    'GET /api/v1/businesses/b1/notifications': (_) => ok(items),
    'POST /api/v1/businesses/b1/notifications/n1/read': (o) => markOverride?.call(o) ?? (() { items = [for (final i in items) i['id'] == 'n1' ? {...i, 'read': true} : i]; return (status: 204, body: null); })(),
    'POST /api/v1/businesses/b1/notifications/read-all': (_) { items = [for (final i in items) {...i, 'read': true}]; return (status: 204, body: null); },
    'GET /api/v1/businesses/b1/support/tickets': (_) => ok([]),
  });
}

Future<void> open(WidgetTester tester, Env e) async {
  setPhone(tester, 390, 1000);
  final store = MemoryTokenStore()..access = 'a'..refresh = 'r';
  await tester.pumpWidget(ProviderScope(retry: appRetry, overrides: overridesFor(e.adapter, store), child: const OrleuApp()));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the home bell shows the unread count and opens the list with localized titles and booking context', (tester) async {
    final e = Env();
    await open(tester, e);
    expect(find.descendant(of: find.byKey(const Key('bell')), matching: find.text('2')), findsOneWidget);
    await tester.tap(find.byKey(const Key('bell')));
    await tester.pumpAndSettle();
    expect(find.text('New booking'), findsOneWidget);
    expect(find.textContaining('Aigerim · Haircut'), findsOneWidget);
    expect(find.text('ORLEU support replied to your request'), findsOneWidget);
    expect(find.text('Payment recorded'), findsOneWidget);
    expect(find.text('Update'), findsOneWidget, reason: 'an unknown event type still shows something sensible');
  });

  testWidgets('opening a notification marks it read on the server and the badge drops', (tester) async {
    final e = Env();
    await open(tester, e);
    await tester.tap(find.byKey(const Key('bell')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('notif-n1')));
    await tester.pumpAndSettle();
    expect(e.adapter.calls.any((c) => c.method == 'POST' && c.path.endsWith('/notifications/n1/read')), isTrue);
    expect(e.items.firstWhere((i) => i['id'] == 'n1')['read'], isTrue);
    await tester.tap(find.text('Home').last); // a booking notification leads to the calendar; the bell lives on Home
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byKey(const Key('bell')), matching: find.text('1')), findsOneWidget);
  });

  testWidgets('mark all as read clears the badge', (tester) async {
    final e = Env();
    await open(tester, e);
    await tester.tap(find.byKey(const Key('bell')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('markAll')));
    await tester.pumpAndSettle();
    expect(e.items.every((i) => i['read'] == true), isTrue);
    expect(find.byKey(const Key('markAll')), findsNothing);
  });

  testWidgets('a support notification leads to the support screen', (tester) async {
    final e = Env()..items = [{'id': 'n2', 'eventType': 'SUPPORT_REPLIED', 'bookingId': null, 'createdAt': '2026-11-05T06:00:00Z', 'read': true}];
    await open(tester, e);
    await tester.tap(find.byKey(const Key('bell')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('notif-n2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('newTicket')), findsOneWidget);
  });

  testWidgets('empty list says so', (tester) async {
    final e = Env()..items = [];
    await open(tester, e);
    await tester.tap(find.byKey(const Key('bell')));
    await tester.pumpAndSettle();
    expect(find.text('No notifications yet'), findsOneWidget);
  });
}
