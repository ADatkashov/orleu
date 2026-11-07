import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orleu_mobile/app.dart';
import 'package:orleu_mobile/core/api/api_client.dart';
import 'package:orleu_mobile/core/api/token_store.dart';
import 'package:orleu_mobile/features/setup/schedule_screen.dart';

import 'support/fake_api.dart';

class Env {
  List<Map<String, Object?>> hours = [];
  List<Map<String, Object?>> timeOff = [];
  List<Map<String, Object?>> exceptions = [];
  int exceptionAffected = 0;
  Handler? putOverride;
  late final FakeAdapter adapter = FakeAdapter({
    ...businessRoutes(),
    'GET /api/v1/businesses': (_) => ok([{'id': 'b1', 'name': 'Studio', 'slug': 'studio', 'currency': 'KZT', 'planCode': 'FREE', 'published': true, 'timezone': 'Asia/Almaty'}]),
    'GET /api/v1/businesses/b1/employees': (_) => ok([{'id': 'e1', 'displayName': 'Master Dana', 'active': true, 'branchIds': ['br1'], 'serviceIds': ['s1']}]),
    'GET /api/v1/businesses/b1/branches': (_) => ok([{'id': 'br1', 'name': 'Main', 'active': true, 'hours': []}]),
    'GET /api/v1/businesses/b1/services': (_) => ok([{'id': 's1', 'name': 'Haircut', 'durationMinutes': 60, 'bufferMinutes': 0, 'price': 20000, 'depositPercent': 0, 'active': true}]),
    'GET /api/v1/businesses/b1/employees/e1/schedule': (_) => ok({'hours': hours, 'timeOff': timeOff, 'exceptions': exceptions}),
    'PUT /api/v1/businesses/b1/employees/e1/hours': (o) => putOverride?.call(o) ?? (() {
          hours = [for (final h in (o.data as Map)['hours']) {'dayOfWeek': h['dayOfWeek'], 'start': '${h['start']}:00', 'end': '${h['end']}:00'}];
          return ok({'hours': hours, 'affectedBookings': 2});
        })(),
    'POST /api/v1/businesses/b1/employees/e1/time-off': (o) {
      final d = o.data as Map;
      timeOff = [...timeOff, {'id': 't${timeOff.length + 1}', 'startsAt': d['startsAt'], 'endsAt': d['endsAt'], 'reason': d['reason'], 'affectedBookings': 0}];
      return (status: 204, body: null);
    },
    'PUT /api/v1/businesses/b1/employees/e1/exceptions/2030-03-04': (o) {
      final d = o.data as Map;
      exceptions = [{'date': '2030-03-04', 'dayOff': d['dayOff'], 'ranges': [for (final r in d['ranges']) {'start': '${r['start']}:00', 'end': '${r['end']}:00'}]}];
      return ok({'exception': exceptions.first, 'affectedBookings': exceptionAffected});
    },
    'DELETE /api/v1/businesses/b1/employees/e1/exceptions/2030-03-04': (_) { exceptions = []; return (status: 204, body: null); },
    'DELETE /api/v1/businesses/b1/employees/e1/time-off/t1': (_) { timeOff = []; return (status: 204, body: null); },
  });
}

Future<void> open(WidgetTester tester, Env e, {DateTimeRange? range, DateTime? date}) async {
  setPhone(tester, 390, 2000);
  final store = MemoryTokenStore()..access = 'a'..refresh = 'r';
  await tester.pumpWidget(ProviderScope(
    retry: appRetry,
    overrides: [...overridesFor(e.adapter, store), dateRangePickerProvider.overrideWithValue((_) async => range), datePickerProvider.overrideWithValue((_) async => date)],
    child: const OrleuApp(),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text('More').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Specialists'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Master Dana'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(const Key('openSchedule')));
  await tester.tap(find.byKey(const Key('openSchedule')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a specialist follows the location until personal hours are switched on; hours, a break and day-offs are saved as ranges', (tester) async {
    final e = Env();
    await open(tester, e);
    expect(find.byKey(const Key('followBranch')), findsOneWidget);
    expect(find.byKey(const Key('addRange-1')), findsNothing, reason: 'no per-day editor while following the location');
    await tester.tap(find.byKey(const Key('followBranch')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('range-1-09:00')), findsOneWidget);
    expect(find.byKey(const Key('off-6')), findsOneWidget, reason: 'Saturday is a day off by default');
    // a break: split Monday into 09:00-13:00 and 14:00-18:00
    await tester.tap(find.descendant(of: find.byKey(const Key('range-1-09:00')), matching: find.byType(Icon))); // the chip's delete icon
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('range-1-09:00')), findsNothing);
    for (final r in [('09:00', '13:00'), ('14:00', '18:00')]) {
      await tester.tap(find.byKey(const Key('addRange-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('rangeStart')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(r.$1).last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('rangeEnd')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(r.$2).last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirmRange')));
      await tester.pumpAndSettle();
    }
    expect(find.byKey(const Key('range-1-09:00')), findsOneWidget);
    expect(find.byKey(const Key('range-1-14:00')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('saveHours')));
    await tester.tap(find.byKey(const Key('saveHours')));
    await tester.pumpAndSettle();
    final put = e.adapter.calls.firstWhere((c) => c.method == 'PUT');
    final sent = (put.data as Map)['hours'] as List;
    expect(sent.where((h) => h['dayOfWeek'] == 1).map((h) => '${h['start']}-${h['end']}'), ['09:00-13:00', '14:00-18:00']);
    expect(sent.any((h) => h['dayOfWeek'] == 6 || h['dayOfWeek'] == 7), isFalse, reason: 'weekend stays a day off');
    expect(find.text('2 upcoming bookings no longer fit these hours. They were not cancelled: move them in the calendar.'), findsOneWidget);
  });

  testWidgets('switching back to the location hours sends an empty schedule', (tester) async {
    final e = Env()..hours = [{'dayOfWeek': 1, 'start': '09:00:00', 'end': '18:00:00'}];
    await open(tester, e);
    expect(find.byKey(const Key('range-1-09:00')), findsOneWidget);
    await tester.tap(find.byKey(const Key('followBranch')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('saveHours')));
    await tester.tap(find.byKey(const Key('saveHours')));
    await tester.pumpAndSettle();
    expect((e.adapter.calls.firstWhere((c) => c.method == 'PUT').data as Map)['hours'], isEmpty);
  });

  testWidgets('a server rejection is explained inline', (tester) async {
    final e = Env()..putOverride = (_) => err(400, 'OVERLAPPING_RANGES');
    await open(tester, e);
    await tester.tap(find.byKey(const Key('followBranch')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('saveHours')));
    await tester.tap(find.byKey(const Key('saveHours')));
    await tester.pumpAndSettle();
    expect(find.text('Hours of one day must not overlap'), findsOneWidget);
  });

  testWidgets('time off: added for whole business-time days, listed with affected bookings, removable', (tester) async {
    final e = Env()..timeOff = [{'id': 't1', 'startsAt': '2026-11-09T19:00:00Z', 'endsAt': '2026-11-11T19:00:00Z', 'reason': 'Vacation', 'affectedBookings': 3}];
    await open(tester, e, range: DateTimeRange(start: DateTime(2026, 12, 1), end: DateTime(2026, 12, 3)));
    await tester.scrollUntilVisible(find.byKey(const Key('timeOff-t1')), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('10.11.2026 – 11.11.2026'), findsOneWidget);
    expect(find.textContaining('Vacation · 3 bookings in this period'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('addTimeOff')));
    await tester.tap(find.byKey(const Key('addTimeOff')));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byKey(const Key('confirmTimeOff'))).onPressed, isNull, reason: 'dates are required');
    await tester.tap(find.byKey(const Key('pickDates')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('timeOffReason')), 'Course');
    await tester.tap(find.byKey(const Key('confirmTimeOff')));
    await tester.pumpAndSettle();
    final post = e.adapter.calls.firstWhere((c) => c.method == 'POST').data as Map;
    expect(post['startsAt'], '2026-11-30T19:00:00.000Z', reason: 'midnight of 1 Dec in Almaty (UTC+5)');
    expect(post['endsAt'], '2026-12-03T19:00:00.000Z', reason: 'end of 3 Dec: the whole last day is off');
    expect(post['reason'], 'Course');

    await tester.scrollUntilVisible(find.byKey(const Key('removeTimeOff-t1')), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const Key('removeTimeOff-t1')));
    await tester.pumpAndSettle();
    expect(e.adapter.calls.any((c) => c.method == 'DELETE' && c.path.endsWith('/time-off/t1')), isTrue);
  });

  testWidgets('a special day is saved for one date (day off), listed, and can be removed', (tester) async {
    final e = Env();
    await open(tester, e, date: DateTime(2030, 3, 4));
    await tester.scrollUntilVisible(find.byKey(const Key('addException')), 200, scrollable: find.byType(Scrollable).first);
    expect(find.byKey(const Key('noExceptions')), findsOneWidget);
    await tester.tap(find.byKey(const Key('addException')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('confirmException')).evaluate().isNotEmpty, isTrue);
    expect(tester.widget<FilledButton>(find.byKey(const Key('confirmException'))).onPressed, isNull, reason: 'no date picked yet');
    await tester.tap(find.byKey(const Key('pickExceptionDate')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmException')));
    await tester.pumpAndSettle();
    final put = e.adapter.calls.lastWhere((c) => c.method == 'PUT' && c.path.endsWith('/exceptions/2030-03-04'));
    expect(put.data, {'dayOff': true, 'ranges': []});
    await tester.scrollUntilVisible(find.byKey(const Key('exception-2030-03-04')), 200, scrollable: find.byType(Scrollable).first);
    expect(find.byKey(const Key('exception-2030-03-04')), findsOneWidget);
    await tester.tap(find.byKey(const Key('removeException-2030-03-04')));
    await tester.pumpAndSettle();
    expect(e.adapter.calls.any((c) => c.method == 'DELETE' && c.path.endsWith('/exceptions/2030-03-04')), isTrue);
    expect(find.byKey(const Key('exception-2030-03-04')), findsNothing);
  });

  testWidgets('special hours send one range, and bookings that no longer fit are shown before the dialog closes', (tester) async {
    final e = Env()..exceptionAffected = 2;
    await open(tester, e, date: DateTime(2030, 3, 4));
    await tester.scrollUntilVisible(find.byKey(const Key('addException')), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const Key('addException')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pickExceptionDate')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('exceptionDayOff')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('exceptionStart')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('12:00').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('exceptionEnd')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15:00').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmException')));
    await tester.pumpAndSettle();
    final put = e.adapter.calls.lastWhere((c) => c.method == 'PUT' && c.path.endsWith('/exceptions/2030-03-04'));
    expect(put.data, {'dayOff': false, 'ranges': [{'start': '12:00', 'end': '15:00'}]});
    expect(find.byKey(const Key('exceptionAffected')), findsOneWidget, reason: 'the warning stays visible instead of silently closing');
  });
}
