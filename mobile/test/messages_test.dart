import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orleu_mobile/app.dart';
import 'package:orleu_mobile/core/api/token_store.dart';

import 'support/fake_api.dart';

class Env {
  int reminderHours = 24;
  String locale = 'ru';
  List<Map<String, Object?>> messages = [
    {'id': 'm1', 'messageType': 'BOOKING_CONFIRMED', 'bookingId': 'k1', 'locale': 'ru', 'recipientPhone': '+77011234567',
     'body': 'Здравствуйте, Aigerim! Ваша запись подтверждена.', 'status': 'NOT_SENT', 'createdAt': '2026-11-05T05:00:00Z'},
  ];
  late final FakeAdapter adapter = FakeAdapter({
    ...businessRoutes(),
    'GET /api/v1/businesses': (_) => ok([{'id': 'b1', 'name': 'Studio', 'slug': 'studio', 'currency': 'KZT', 'planCode': 'FREE', 'published': true,
        'timezone': 'Asia/Almaty', 'reminderHours': reminderHours, 'customerLocale': locale}]),
    'GET /api/v1/businesses/b1/notifications/customer-messages': (_) => ok(messages),
    'PATCH /api/v1/businesses/b1/settings': (o) {
      final d = o.data as Map;
      if (d.containsKey('reminderHours')) reminderHours = d['reminderHours'];
      if (d.containsKey('customerLocale')) locale = d['customerLocale'];
      return ok({});
    },
  });
}

Future<Env> open(WidgetTester tester, {Env? env}) async {
  setPhone(tester, 390, 1200);
  final e = env ?? Env();
  final store = MemoryTokenStore()..access = 'a'..refresh = 'r';
  await tester.pumpWidget(ProviderScope(overrides: overridesFor(e.adapter, store), child: const OrleuApp()));
  await tester.pumpAndSettle();
  await tester.tap(find.text('More').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Customer messages'));
  await tester.pumpAndSettle();
  return e;
}

void main() {
  testWidgets('prepared messages are listed as NOT sent and the screen says delivery is not connected', (tester) async {
    await open(tester);
    expect(find.textContaining('Здравствуйте, Aigerim'), findsOneWidget);
    expect(find.text('Not sent'), findsOneWidget);
    expect(find.textContaining('nothing is delivered'), findsOneWidget);
  });

  testWidgets('changing reminder lead time and language is sent to the backend and reflected after reload', (tester) async {
    final e = await open(tester);
    await tester.tap(find.text('48 h before'));
    await tester.pumpAndSettle();
    expect(e.reminderHours, 48);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(e.locale, 'en');
    final patches = e.adapter.calls.where((c) => c.method == 'PATCH').toList();
    expect(patches.length, 2);
    expect(patches[0].data, {'reminderHours': 48});
    expect(patches[1].data, {'customerLocale': 'en'});
  });

  testWidgets('a rejected setting shows an error and keeps the old value', (tester) async {
    final e = Env();
    e.adapter.routes['PATCH /api/v1/businesses/b1/settings'] = (_) => err(400, 'VALIDATION_FAILED');
    await open(tester, env: e);
    await tester.tap(find.descendant(of: find.byKey(const Key('reminder-hours')), matching: find.text('Off')));
    await tester.pumpAndSettle();
    expect(e.reminderHours, 24);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('no messages yet shows the empty state', (tester) async {
    final e = Env()..messages = [];
    await open(tester, env: e);
    expect(find.byKey(const Key('no-messages')), findsOneWidget);
  });
}
