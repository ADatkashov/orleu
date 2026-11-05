import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orleu_mobile/app.dart';
import 'package:orleu_mobile/core/api/token_store.dart';
import 'package:orleu_mobile/core/data/models.dart';

import 'support/fake_api.dart';

Map<String, dynamic> branchJson({List<Map<String, Object>> hours = const []}) =>
    {'id': 'br1', 'name': 'Main', 'address': 'Abay 1', 'timezone': 'Asia/Almaty', 'active': true, 'hours': hours};

class Server {
  var branches = <Map<String, dynamic>>[];
  var services = <Map<String, dynamic>>[];
  var employees = <Map<String, dynamic>>[];
  var published = false;
  late final FakeAdapter adapter;
  Handler? publishOverride, createEmployeeOverride;

  Server() {
    adapter = FakeAdapter({
      ...businessRoutes(),
      'GET /api/v1/businesses': (_) => ok([
            {'id': 'b1', 'name': 'Studio Almaty', 'slug': 'studio', 'currency': 'KZT', 'planCode': 'FREE', 'published': published}
          ]),
      'GET /api/v1/businesses/b1/branches': (_) => ok(branches),
      'GET /api/v1/businesses/b1/services': (_) => ok(services),
      'GET /api/v1/businesses/b1/employees': (_) => ok(employees),
      'POST /api/v1/businesses/b1/branches': (o) {
        branches = [...branches, branchJson()..['name'] = (o.data as Map)['name']];
        return (status: 201, body: branches.last);
      },
      'PUT /api/v1/businesses/b1/branches/br1/hours': (o) {
        branches = [branchJson(hours: [for (final h in (o.data as Map)['hours'] as List) {'dayOfWeek': h['dayOfWeek'], 'open': '${h['open']}:00', 'close': '${h['close']}:00'}])];
        return (status: 204, body: null);
      },
      'POST /api/v1/businesses/b1/services': (o) {
        services = [...services, {'id': 's1', 'name': (o.data as Map)['name'], 'durationMinutes': (o.data as Map)['durationMinutes'], 'price': (o.data as Map)['price'], 'onlineBookable': true, 'active': true}];
        return (status: 201, body: services.last);
      },
      'POST /api/v1/businesses/b1/employees': (o) => createEmployeeOverride?.call(o) ?? (() {
            employees = [...employees, {'id': 'e1', 'displayName': (o.data as Map)['displayName'], 'active': true, 'branchIds': [], 'serviceIds': []}];
            return (status: 201, body: employees.last);
          })(),
      'PUT /api/v1/businesses/b1/employees/e1/assignments': (o) {
        employees = [{...employees.first, 'branchIds': (o.data as Map)['branchIds'], 'serviceIds': (o.data as Map)['serviceIds']}];
        return ok(employees.first);
      },
      'POST /api/v1/businesses/b1/publish': (o) => publishOverride?.call(o) ?? (() { published = true; return ok({'published': true}); })(),
    });
  }
}

Future<void> pump(WidgetTester tester, Server s) async {
  setPhone(tester, 420, 1000);
  final store = MemoryTokenStore()..access = 'a'..refresh = 'r';
  await tester.pumpWidget(ProviderScope(overrides: overridesFor(s.adapter, store), child: const OrleuApp()));
  await tester.pumpAndSettle();
  await tester.tap(find.text('More').last);
  await tester.pumpAndSettle();
}

Future<void> openFromMore(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  narrowLayout();
  testWidgets('setup checklist starts empty and the server explains what is missing on publish', (tester) async {
    final s = Server()
      ..publishOverride = (_) => err(409, 'NOT_READY_TO_PUBLISH');
    await pump(tester, s);
    await openFromMore(tester, 'Business setup');
    expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(4));
    await tester.ensureVisible(find.byKey(const Key('publish')));
    await tester.tap(find.byKey(const Key('publish')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Finish the setup steps first'), findsWidgets);
  });

  testWidgets('owner builds the whole setup and publishes: bodies sent to the API are exactly what was entered', (tester) async {
    final s = Server();
    await pump(tester, s);

    // 1. location
    await openFromMore(tester, 'Locations & hours');
    await tester.tap(find.text('Add location'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Main');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect((s.adapter.calls.firstWhere((c) => c.method == 'POST' && c.path.endsWith('/branches')).data as Map)['name'], 'Main');

    // 2. hours: default template, close Sunday
    await tester.tap(find.text('Main'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('applyDefaultHours')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('day7')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('saveHours')));
    await tester.tap(find.byKey(const Key('saveHours')));
    await tester.pumpAndSettle();
    final hoursBody = s.adapter.calls.firstWhere((c) => c.method == 'PUT' && c.path.endsWith('/hours')).data as Map;
    final days = (hoursBody['hours'] as List).map((h) => h['dayOfWeek']).toList()..sort();
    expect(days, [1, 2, 3, 4, 5, 6]);
    expect((hoursBody['hours'] as List).first, {'dayOfWeek': 1, 'open': '09:00', 'close': '18:00'});
    expect(s.branches.first['hours'], isNotEmpty);

    // back to More -> Services
    await tester.pageBack();
    await tester.pumpAndSettle();
    await openFromMore(tester, 'Services');
    await tester.tap(find.text('Add service'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('svcName')), 'Haircut');
    await tester.enterText(find.byKey(const Key('svcPrice')), '20000');
    await tester.enterText(find.byKey(const Key('svcDeposit')), '30');
    await tester.tap(find.byKey(const Key('svcSave')));
    await tester.pumpAndSettle();
    final svc = s.adapter.calls.firstWhere((c) => c.method == 'POST' && c.path.endsWith('/services')).data as Map;
    expect(svc, {'name': 'Haircut', 'durationMinutes': 60, 'price': '20000', 'depositPercent': '30'});
    expect(find.text('Haircut'), findsOneWidget);

    // 3. specialist + assignment
    await tester.pageBack();
    await tester.pumpAndSettle();
    await openFromMore(tester, 'Specialists');
    await tester.tap(find.text('Add specialist'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('empName')), 'Master Dana');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Master Dana'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('branch-br1')));
    await tester.tap(find.byKey(const Key('service-s1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('saveAssignments')));
    await tester.pumpAndSettle();
    final asg = s.adapter.calls.firstWhere((c) => c.method == 'PUT' && c.path.endsWith('/assignments')).data as Map;
    expect(asg, {'branchIds': ['br1'], 'serviceIds': ['s1']});

    // 4. checklist is now complete and publish succeeds, showing the public link
    await tester.pageBack();
    await tester.pumpAndSettle();
    await openFromMore(tester, 'Business setup');
    expect(find.byIcon(Icons.check_circle), findsNWidgets(4));
    await tester.ensureVisible(find.byKey(const Key('publish')));
    await tester.tap(find.byKey(const Key('publish')));
    await tester.pumpAndSettle();
    expect(find.text('Your booking page is live'), findsOneWidget);
    expect(find.byKey(const Key('bookingLink')), findsOneWidget);
    expect((tester.widget(find.byKey(const Key('bookingLink'))) as SelectableText).data, endsWith('/b/studio'));
  });

  testWidgets('service form validates input before sending', (tester) async {
    final s = Server();
    await pump(tester, s);
    await openFromMore(tester, 'Services');
    await tester.tap(find.text('Add service'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('svcDuration')), '2');     // below 5 minutes
    await tester.enterText(find.byKey(const Key('svcPrice')), '12abc');
    await tester.enterText(find.byKey(const Key('svcDeposit')), '150');    // above 100%
    await tester.tap(find.byKey(const Key('svcSave')));
    await tester.pump();
    expect(find.text('Required'), findsNWidgets(4)); // name, duration, price, deposit
    expect(s.adapter.calls.where((c) => c.method == 'POST'), isEmpty);
  });

  testWidgets('plan limit from the server is shown as a localized upgrade hint', (tester) async {
    final s = Server()..createEmployeeOverride = (_) => err(402, 'EMPLOYEE_LIMIT_REACHED');
    await pump(tester, s);
    await openFromMore(tester, 'Specialists');
    await tester.tap(find.text('Add specialist'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('empName')), 'Fourth');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.text('Your plan limit is reached. Contact ORLEU to upgrade.'), findsOneWidget);
    expect(find.byKey(const Key('formError')), findsOneWidget); // inline in the dialog, not behind it
    expect(find.byType(SnackBar), findsNothing);
    expect(find.byKey(const Key('empName')), findsOneWidget);    // the dialog stays open so the user can react
  });

  test('branch model parses backend time strings and treats missing days as closed', () {
    final b = Branch.fromJson(branchJson(hours: [{'dayOfWeek': 1, 'open': '09:00:00', 'close': '18:30:00'}]));
    expect(b.hours[1], ('09:00', '18:30'));
    expect(b.hours.containsKey(2), isFalse);
    expect(Branch.fromJson({'id': 'x', 'name': 'n'}).hours, isEmpty); // public-style payload without hours
  });
}

// Layout guard at the narrowest supported phone width (true logical 320px).
void narrowLayout() {
  testWidgets('hours editor fits a 320px-wide phone without overflow', (tester) async {
    setPhone(tester, 320, 700);
    final s = Server()..branches = [branchJson(hours: [for (var d = 1; d <= 7; d++) {'dayOfWeek': d, 'open': '09:00:00', 'close': '18:00:00'}])];
    final store = MemoryTokenStore()..access = 'a'..refresh = 'r';
    await tester.pumpWidget(ProviderScope(overrides: overridesFor(s.adapter, store), child: const OrleuApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('More').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Locations & hours'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Main'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('open1')), findsOneWidget);
  });
}
