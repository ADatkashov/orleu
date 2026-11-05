import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orleu_mobile/app.dart';
import 'package:orleu_mobile/core/api/token_store.dart';
import 'package:orleu_mobile/core/data/models.dart';

import 'app_flow_test.dart' show booking;
import 'support/fake_api.dart';

final tomorrow10 = () {
  final d = DateTime.now().add(const Duration(days: 1));
  return DateTime(d.year, d.month, d.day, 10);
}();

Map<String, Object?> slot(DateTime t) => {'start': t.toUtc().toIso8601String(), 'employeeIds': ['e1']};

class Env {
  late final FakeAdapter adapter;
  bool hasCatalog = true;
  Handler? createOverride;
  List<Map<String, Object?>> bookings = [];

  Env() {
    adapter = FakeAdapter({
      ...businessRoutes(),
      'GET /api/v1/businesses/b1/bookings': (_) => ok(bookings),
      'GET /api/v1/businesses/b1/branches': (_) => ok(hasCatalog ? [{'id': 'br1', 'name': 'Main', 'hours': [{'dayOfWeek': 1, 'open': '09:00:00', 'close': '18:00:00'}]}] : []),
      'GET /api/v1/businesses/b1/services': (_) => ok(hasCatalog ? [{'id': 's1', 'name': 'Haircut', 'durationMinutes': 60, 'price': 20000}] : []),
      'GET /api/v1/businesses/b1/employees': (_) => ok(hasCatalog ? [{'id': 'e1', 'displayName': 'Master Dana', 'branchIds': ['br1'], 'serviceIds': ['s1']}] : []),
      'GET /api/v1/businesses/b1/availability': (_) => ok([slot(tomorrow10), slot(tomorrow10.add(const Duration(minutes: 15)))]),
      'POST /api/v1/businesses/b1/bookings': (o) => createOverride?.call(o) ?? (status: 201, body: booking),
      'POST /api/v1/businesses/b1/bookings/k1/reschedule': (_) => ok(booking),
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

Future<void> pickFirst(WidgetTester tester, Key dropdown, String option) async {
  await tester.ensureVisible(find.byKey(dropdown));
  await tester.tap(find.byKey(dropdown));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('staff creates a booking: exact request body, phone normalised, any specialist omitted', (tester) async {
    final env = Env();
    await openCalendar(tester, env);
    await tester.tap(find.byKey(const Key('newBooking')));
    await tester.pumpAndSettle();
    await pickFirst(tester, const Key('selService'), 'Haircut');
    await tester.tap(find.byKey(Key('slot-${tomorrow10.toUtc().toIso8601String()}')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('clientName')), 'Aigerim');
    await tester.enterText(find.byKey(const Key('clientPhone')), '8 701 123 45 67');
    await tester.ensureVisible(find.byKey(const Key('createBooking')));
    await tester.tap(find.byKey(const Key('createBooking')));
    await tester.pumpAndSettle();

    final body = env.adapter.calls.firstWhere((c) => c.method == 'POST' && c.path == '/api/v1/businesses/b1/bookings').data as Map;
    expect(body, {
      'branchId': 'br1', 'serviceId': 's1', 'startsAt': tomorrow10.toUtc().toIso8601String(),
      'customer': {'fullName': 'Aigerim', 'phone': '+77011234567'},
    });
    expect(find.text('Booking created'), findsOneWidget);
  });

  testWidgets('create button needs a chosen time and the phone must be valid', (tester) async {
    final env = Env();
    await openCalendar(tester, env);
    await tester.tap(find.byKey(const Key('newBooking')));
    await tester.pumpAndSettle();
    await pickFirst(tester, const Key('selService'), 'Haircut');
    await tester.ensureVisible(find.byKey(const Key('createBooking')));
    expect(tester.widget<FilledButton>(find.byKey(const Key('createBooking'))).onPressed, isNull); // no time chosen yet
    await tester.tap(find.byKey(Key('slot-${tomorrow10.toUtc().toIso8601String()}')));
    await tester.enterText(find.byKey(const Key('clientName')), 'Aigerim');
    await tester.enterText(find.byKey(const Key('clientPhone')), '12345');
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('createBooking')));
    await tester.tap(find.byKey(const Key('createBooking')));
    await tester.pump();
    expect(find.text('Use international format, e.g. +7 701 123 45 67'), findsOneWidget);
    expect(env.adapter.calls.where((c) => c.method == 'POST' && c.path.endsWith('/bookings')), isEmpty);
  });

  testWidgets('a taken slot (409) shows a localized message and refreshes availability', (tester) async {
    final env = Env()..createOverride = (_) => err(409, 'SLOT_UNAVAILABLE');
    await openCalendar(tester, env);
    await tester.tap(find.byKey(const Key('newBooking')));
    await tester.pumpAndSettle();
    await pickFirst(tester, const Key('selService'), 'Haircut');
    await tester.tap(find.byKey(Key('slot-${tomorrow10.toUtc().toIso8601String()}')));
    await tester.enterText(find.byKey(const Key('clientName')), 'Aigerim');
    await tester.enterText(find.byKey(const Key('clientPhone')), '+77011234567');
    await tester.pump();
    final before = env.adapter.calls.where((c) => c.path.endsWith('/availability')).length;
    await tester.ensureVisible(find.byKey(const Key('createBooking')));
    await tester.tap(find.byKey(const Key('createBooking')));
    await tester.pumpAndSettle();
    expect(find.text('This time is no longer available. Pick another.'), findsOneWidget);
    expect(env.adapter.calls.where((c) => c.path.endsWith('/availability')).length, greaterThan(before));
    expect(find.text('Booking created'), findsNothing);
  });

  testWidgets('without catalog the sheet tells the owner to finish setup', (tester) async {
    final env = Env()..hasCatalog = false;
    await openCalendar(tester, env);
    await tester.tap(find.byKey(const Key('newBooking')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('setupFirst')), findsOneWidget);
  });

  testWidgets('reschedule asks availability excluding the booking itself and posts the chosen time', (tester) async {
    final env = Env()..bookings = [booking];
    await openCalendar(tester, env);
    await tester.tap(find.text('Haircut').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reschedule')));
    await tester.pumpAndSettle();
    final q = env.adapter.calls.lastWhere((c) => c.path.endsWith('/availability')).queryParameters;
    expect(q['excludeBookingId'], 'k1');
    expect(q['employeeId'], 'e');
    expect(q['branchId'], 'br');
    await tester.tap(find.byKey(Key('slot-${tomorrow10.add(const Duration(minutes: 15)).toUtc().toIso8601String()}')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('moveBooking')));
    await tester.pumpAndSettle();
    final body = env.adapter.calls.firstWhere((c) => c.path.endsWith('/reschedule')).data as Map;
    expect(body, {'startsAt': tomorrow10.add(const Duration(minutes: 15)).toUtc().toIso8601String()});
    expect(find.text('Booking moved'), findsOneWidget);
  });

  test('phone normalisation covers common Kazakhstan inputs', () {
    expect(normalizePhone('8 701 123 45 67'), '+77011234567');
    expect(normalizePhone('+7 (701) 123-45-67'), '+77011234567');
    expect(normalizePhone('77011234567'), '+77011234567');
    expect(phoneE164.hasMatch(normalizePhone('12345')), isFalse);
    expect(phoneE164.hasMatch(normalizePhone('+447911123456')), isTrue);
  });
}
