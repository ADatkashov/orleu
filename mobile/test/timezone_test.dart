import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orleu_mobile/app.dart';
import 'package:orleu_mobile/core/api/token_store.dart';
import 'package:orleu_mobile/core/data/models.dart';
import 'package:orleu_mobile/core/tz.dart';

import 'app_flow_test.dart' show booking;
import 'support/fake_api.dart';

void main() {
  group('timezone conversion', () {
    test('Almaty is UTC+5 all year (no DST since 2024)', () {
      expect(wallFromInstant(DateTime.utc(2026, 11, 5, 5, 0), 'Asia/Almaty'), DateTime(2026, 11, 5, 10, 0));
      expect(wallFromInstant(DateTime.utc(2026, 7, 1, 5, 0), 'Asia/Almaty'), DateTime(2026, 7, 1, 10, 0));
      expect(instantFromWall(DateTime(2026, 11, 5, 10, 0), 'Asia/Almaty'), DateTime.utc(2026, 11, 5, 5, 0));
    });

    test('a zone with DST shifts the offset (New York: EDT -4 in July, EST -5 in December)', () {
      expect(wallFromInstant(DateTime.utc(2026, 7, 1, 14, 0), 'America/New_York'), DateTime(2026, 7, 1, 10, 0));
      expect(wallFromInstant(DateTime.utc(2026, 12, 1, 15, 0), 'America/New_York'), DateTime(2026, 12, 1, 10, 0));
    });

    test('round trip, day boundaries and DST day length', () {
      final i = DateTime.utc(2026, 11, 5, 21, 30); // 02:30 next day in Almaty
      expect(instantFromWall(wallFromInstant(i, 'Asia/Almaty'), 'Asia/Almaty'), i);
      expect(wallFromInstant(i, 'Asia/Almaty').day, 6);
      // local midnight Almaty = 19:00 UTC of the previous day
      expect(instantFromWall(DateTime(2026, 11, 6), 'Asia/Almaty'), DateTime.utc(2026, 11, 5, 19));
      // the day the US springs forward is 23h long: nextDay() must use calendar days, not +24h
      final from = instantFromWall(DateTime(2027, 3, 14), 'America/New_York');
      final to = instantFromWall(nextDay(DateTime(2027, 3, 14)), 'America/New_York');
      expect(to.difference(from), const Duration(hours: 23));
    });

    test('unknown zone ids fall back to UTC instead of crashing', () {
      expect(wallFromInstant(DateTime.utc(2026, 1, 1, 12), 'Mars/Olympus'), DateTime(2026, 1, 1, 12));
    });

    test('models convert API instants to business wall-clock and keep the exact instant for slots', () {
      final b = Booking.fromJson({...booking, 'startsAt': '2026-11-05T05:00:00Z', 'endsAt': '2026-11-05T06:00:00Z'}, zone: 'Asia/Almaty');
      expect(b.startsAt, DateTime(2026, 11, 5, 10, 0));
      expect(b.endsAt, DateTime(2026, 11, 5, 11, 0));
      expect(b.endsInstant, DateTime.utc(2026, 11, 5, 6, 0));
      final s = Slot.fromJson({'start': '2026-11-05T05:15:00Z', 'employeeIds': ['e1']}, zone: 'Asia/Almaty');
      expect(s.start, DateTime(2026, 11, 5, 10, 15));
      expect(s.instant, DateTime.utc(2026, 11, 5, 5, 15));
      expect(Business.fromJson({'id': 'b', 'name': 'n', 'slug': 's', 'timezone': 'Asia/Almaty'}).timezone, 'Asia/Almaty');
    });
  });

  group('UI uses the business timezone, not the device timezone', () {
    // Test device timezone is UTC; the business is in Almaty (+5).
    final instant = DateTime.utc(2026, 11, 5, 5, 0); // = 10:00 in Almaty, 05:00 on a UTC device

    Map<String, Handler> routes(List<Map<String, Object?>> bookings) => {
          ...businessRoutes(),
          'GET /api/v1/businesses': (_) => ok([
                {'id': 'b1', 'name': 'Studio Almaty', 'slug': 'studio', 'currency': 'KZT', 'planCode': 'FREE', 'published': true, 'timezone': 'Asia/Almaty'}
              ]),
          'GET /api/v1/businesses/b1/bookings': (_) => ok(bookings),
          'GET /api/v1/businesses/b1/branches': (_) => ok([{'id': 'br1', 'name': 'Main', 'hours': [{'dayOfWeek': 1, 'open': '09:00:00', 'close': '18:00:00'}]}]),
          'GET /api/v1/businesses/b1/services': (_) => ok([{'id': 's1', 'name': 'Haircut', 'durationMinutes': 60, 'price': 20000}]),
          'GET /api/v1/businesses/b1/employees': (_) => ok([{'id': 'e1', 'displayName': 'Master Dana', 'branchIds': ['br1'], 'serviceIds': ['s1']}]),
          'GET /api/v1/businesses/b1/availability': (_) => ok([
                {'start': instant.toIso8601String(), 'employeeIds': ['e1']},
                {'start': instant.add(const Duration(minutes: 15)).toIso8601String(), 'employeeIds': ['e1']},
              ]),
          'POST /api/v1/businesses/b1/bookings': (_) => (status: 201, body: booking),
        };

    Future<FakeAdapter> open(WidgetTester tester, Map<String, Handler> r) async {
      setPhone(tester, 420, 1000);
      final adapter = FakeAdapter(r);
      final store = MemoryTokenStore()..access = 'a'..refresh = 'r';
      await tester.pumpWidget(ProviderScope(overrides: overridesFor(adapter, store), child: const OrleuApp()));
      await tester.pumpAndSettle();
      return adapter;
    }

    testWidgets('calendar shows booking times in the business timezone', (tester) async {
      final adapter = await open(tester, routes([{...booking, 'startsAt': instant.toIso8601String(), 'endsAt': instant.add(const Duration(hours: 1)).toIso8601String()}]));
      await tester.tap(find.text('Calendar').last);
      await tester.pumpAndSettle();
      expect(find.text('10:00'), findsOneWidget);   // not 05:00
      expect(find.text('05:00'), findsNothing);
      expect(adapter.calls.isNotEmpty, isTrue);
    });

    testWidgets('the day being viewed is queried as local midnight-to-midnight in the business timezone', (tester) async {
      final adapter = await open(tester, routes([]));
      await tester.tap(find.text('Calendar').last);
      await tester.pumpAndSettle();
      final q = adapter.calls.where((c) => c.path.endsWith('/bookings')).last.queryParameters;
      final from = DateTime.parse(q['from']), to = DateTime.parse(q['to']);
      expect(from.hour, 19);                            // 00:00 Almaty == 19:00 UTC the day before
      expect(from.minute, 0);
      expect(to.difference(from), const Duration(hours: 24));
    });

    testWidgets('slots are shown in business time and booking sends the exact UTC instant the server offered', (tester) async {
      final adapter = await open(tester, routes([]));
      await tester.tap(find.text('Calendar').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('newBooking')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('selService')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Haircut').last);
      await tester.pumpAndSettle();
      expect(find.text('10:00'), findsOneWidget);       // 05:00Z shown as Almaty time
      expect(find.text('05:00'), findsNothing);
      await tester.tap(find.byKey(Key('slot-${instant.toIso8601String()}')));
      await tester.enterText(find.byKey(const Key('clientName')), 'Aigerim');
      await tester.enterText(find.byKey(const Key('clientPhone')), '+77011234567');
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('createBooking')));
      await tester.tap(find.byKey(const Key('createBooking')));
      await tester.pumpAndSettle();
      final body = adapter.calls.firstWhere((c) => c.method == 'POST' && c.path.endsWith('/bookings')).data as Map;
      expect(body['startsAt'], instant.toIso8601String());
    });
  });
}
