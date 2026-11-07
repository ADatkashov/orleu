import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orleu_mobile/app.dart';
import 'package:orleu_mobile/core/api/token_store.dart';
import 'package:orleu_mobile/core/data/models.dart';

import 'support/fake_api.dart';

Map<String, Object?> profileJson({bool blocked = false, String? notes = 'Prefers mornings', bool visits = true, bool optIn = false, List<String> tags = const []}) => {
      'customer': {'tags': tags, 'id': 'c1', 'fullName': 'Aigerim Sadykova', 'phone': '+77011234567', 'email': 'a@example.com', 'notes': notes, 'marketingOptIn': optIn, 'blocked': blocked},
      'stats': {
        'totalBookings': visits ? 4 : 0, 'completedVisits': visits ? 1 : 0, 'cancelled': visits ? 1 : 0, 'noShows': visits ? 1 : 0, 'upcoming': visits ? 1 : 0,
        'lastVisit': visits ? '2026-11-05T05:00:00Z' : null, 'totalSpent': visits ? 18000 : 0, 'averageSpendPerVisit': visits ? 15000 : null,
      },
      'bookings': visits
          ? [{'id': 'k1', 'startsAt': '2026-11-05T05:00:00Z', 'serviceName': 'Haircut', 'employeeName': 'Master Dana', 'status': 'COMPLETED', 'price': 20000, 'netPaid': 15000}]
          : [],
    };

class Env {
  bool blocked = false, optIn = false, noVisits = false;
  var tags = <String>[];
  String? notes = 'Prefers mornings';
  Handler? patchOverride;
  var service = <String, Object?>{'id': 's1', 'name': 'Haircut', 'durationMinutes': 60, 'bufferMinutes': 15, 'price': 20000, 'depositPercent': 30, 'active': true};
  var employee = <String, Object?>{'id': 'e1', 'displayName': 'Master Dana', 'active': true, 'branchIds': ['br1'], 'serviceIds': ['s1']};
  var branch = <String, Object?>{'id': 'br1', 'name': 'Main', 'address': 'Abay 1', 'active': true, 'hours': [{'dayOfWeek': 1, 'open': '09:00:00', 'close': '18:00:00'}]};
  late final FakeAdapter adapter;

  Env() {
    adapter = FakeAdapter({
      ...businessRoutes(),
      'GET /api/v1/businesses': (_) => ok([{'id': 'b1', 'name': 'Studio', 'slug': 'studio', 'currency': 'KZT', 'planCode': 'FREE', 'published': true, 'timezone': 'Asia/Almaty'}]),
      'GET /api/v1/businesses/b1/customers': (_) => ok({'items': [{'id': 'c1', 'fullName': 'Aigerim Sadykova', 'phone': '+77011234567', 'blocked': blocked}], 'page': 0, 'size': 50, 'total': 1}),
      'GET /api/v1/businesses/b1/customers/c1/profile': (_) => ok(profileJson(blocked: blocked, notes: notes, visits: !noVisits, optIn: optIn, tags: tags)),
      'PATCH /api/v1/businesses/b1/customers/c1': (o) {
        final d = o.data as Map;
        if (d.containsKey('notes')) notes = d['notes'];
        if (d.containsKey('marketingOptIn')) optIn = d['marketingOptIn'];
        return patchOverride?.call(o) ?? ok({});
      },
      'PUT /api/v1/businesses/b1/customers/c1/tags': (o) { tags = [for (final t in (o.data as Map)['tags']) t as String]; return ok({}); },
      'GET /api/v1/businesses/b1/customers/tags': (_) => ok([{'tag': 'vip', 'customers': 2}]),
      'POST /api/v1/businesses/b1/customers/c1/block': (_) { blocked = true; return ok({}); },
      'POST /api/v1/businesses/b1/customers/c1/unblock': (_) { blocked = false; return ok({}); },
      'GET /api/v1/businesses/b1/services': (_) => ok([service]),
      'GET /api/v1/businesses/b1/employees': (_) => ok([employee]),
      'GET /api/v1/businesses/b1/branches': (_) => ok([branch]),
      'PATCH /api/v1/businesses/b1/services/s1': (o) { service = {...service, ...(o.data as Map).cast<String, Object?>()}; return patchOverride?.call(o) ?? ok(service); },
      'PATCH /api/v1/businesses/b1/employees/e1': (o) { employee = {...employee, ...(o.data as Map).cast<String, Object?>()}; return ok(employee); },
      'PATCH /api/v1/businesses/b1/branches/br1': (o) { branch = {...branch, ...(o.data as Map).cast<String, Object?>()}; return ok(branch); },
      'PUT /api/v1/businesses/b1/employees/e1/assignments': (o) => ok(employee),
    });
  }

  Map<String, dynamic>? bodyOf(String method, String endsWith) {
    final c = adapter.calls.where((c) => c.method == method && c.path.endsWith(endsWith));
    return c.isEmpty ? null : Map<String, dynamic>.from(c.last.data as Map);
  }
}

Future<void> open(WidgetTester tester, Env env, String tab) async {
  setPhone(tester, 420, 1100);
  final store = MemoryTokenStore()..access = 'a'..refresh = 'r';
  await tester.pumpWidget(ProviderScope(overrides: overridesFor(env.adapter, store), child: const OrleuApp()));
  await tester.pumpAndSettle();
  await tester.tap(find.text(tab).last);
  await tester.pumpAndSettle();
}

Future<void> openProfile(WidgetTester tester, Env env) async {
  await open(tester, env, 'Customers');
  await tester.tap(find.byKey(const Key('customer-c1')));
  await tester.pumpAndSettle();
}

Future<void> openFromMore(WidgetTester tester, Env env, String entry) async {
  await open(tester, env, 'More');
  await tester.tap(find.text(entry));
  await tester.pumpAndSettle();
}

void main() {
  group('customer card', () {
    testWidgets('shows measured statistics, cash (not booked value) and history in business time', (tester) async {
      await openProfile(tester, Env());
      expect(find.text('Aigerim Sadykova'), findsWidgets);
      expect(find.text('+77011234567'), findsOneWidget);
      for (final label in ['Visits', 'Upcoming', 'Cancellations', 'No-shows', 'Total paid', 'Average per visit', 'Last visit']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.textContaining('18'), findsWidgets);           // total paid 18 000 (cash)
      expect(find.textContaining('15'), findsWidgets);           // average per completed visit
      expect(find.textContaining('Paid = cash collected minus refunds'), findsOneWidget);
      await tester.scrollUntilVisible(find.byKey(const Key('line-k1')), 200, scrollable: find.byType(Scrollable).first);
      expect(find.byKey(const Key('line-k1')), findsOneWidget);
      expect(find.textContaining('10:00'), findsWidgets);        // 05:00Z is 10:00 in Almaty, even on a UTC device
      expect(find.text('Prefers mornings'), findsOneWidget);
    });

    testWidgets('a client without visits shows placeholders instead of invented numbers', (tester) async {
      await openProfile(tester, Env()..noVisits = true..notes = null);
      expect(find.text('No visits yet'), findsOneWidget);
      expect(find.byKey(const Key('noHistory')), findsOneWidget);
      expect(find.text('—'), findsWidgets);                      // average and notes
    });

    testWidgets('editing sends only the form fields and validates the e-mail first', (tester) async {
      final env = Env();
      await openProfile(tester, env);
      await tester.tap(find.byKey(const Key('editClient')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('editEmail')), 'broken');
      await tester.tap(find.byKey(const Key('saveClient')));
      await tester.pump();
      expect(find.text('Enter a valid e-mail'), findsOneWidget);
      expect(env.bodyOf('PATCH', '/customers/c1'), isNull);
      await tester.enterText(find.byKey(const Key('editName')), 'Aigerim S.');
      await tester.enterText(find.byKey(const Key('editEmail')), 'new@example.com');
      await tester.enterText(find.byKey(const Key('editNotes')), 'Likes tea');
      await tester.tap(find.byKey(const Key('saveClient')));
      await tester.pumpAndSettle();
      expect(env.bodyOf('PATCH', '/customers/c1'), {'fullName': 'Aigerim S.', 'email': 'new@example.com', 'notes': 'Likes tea'});
      expect(find.text('Likes tea'), findsOneWidget);            // reloaded from the server, not faked locally
    });

    testWidgets('a server rejection stays inside the edit dialog', (tester) async {
      final env = Env()..patchOverride = (_) => err(400, 'INVALID_NAME');
      await openProfile(tester, env);
      await tester.tap(find.byKey(const Key('editClient')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('saveClient')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('formError')), findsOneWidget);
      expect(find.byKey(const Key('editName')), findsOneWidget);
    });

    testWidgets('tags are edited as a comma-separated list and shown as chips', (tester) async {
      final env = Env();
      await openProfile(tester, env);
      expect(find.byKey(const Key('noTags')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('editTags')));
      await tester.tap(find.byKey(const Key('editTags')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('tagsField')), 'vip, allergy ,');
      await tester.tap(find.byKey(const Key('saveTags')));
      await tester.pumpAndSettle();
      expect(env.bodyOf('PUT', '/customers/c1/tags'), {'tags': ['vip', 'allergy']});
      expect(find.byKey(const Key('tag-vip')), findsOneWidget);
      expect(find.byKey(const Key('tag-allergy')), findsOneWidget);
    });

    testWidgets('a tag that is too long is rejected locally, inside the dialog', (tester) async {
      final env = Env();
      await openProfile(tester, env);
      await tester.ensureVisible(find.byKey(const Key('editTags')));
      await tester.tap(find.byKey(const Key('editTags')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('tagsField')), 'x' * 31);
      await tester.tap(find.byKey(const Key('saveTags')));
      await tester.pumpAndSettle();
      expect(find.textContaining('at most 30'), findsOneWidget);
      expect(env.bodyOf('PUT', '/customers/c1/tags'), isNull);
    });

    testWidgets('marketing consent toggles through the API', (tester) async {
      final env = Env();
      await openProfile(tester, env);
      await tester.tap(find.byKey(const Key('marketingSwitch')));
      await tester.pumpAndSettle();
      expect(env.bodyOf('PATCH', '/customers/c1'), {'marketingOptIn': true});
      expect(tester.widget<SwitchListTile>(find.byKey(const Key('marketingSwitch'))).value, isTrue);
    });

    testWidgets('blocking needs a confirmation and is reversible', (tester) async {
      final env = Env();
      await openProfile(tester, env);
      await tester.tap(find.byKey(const Key('block')));
      await tester.pumpAndSettle();
      expect(find.textContaining('cannot book online'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(env.adapter.calls.where((c) => c.path.endsWith('/block')), isEmpty);      // cancelling the dialog changes nothing
      await tester.tap(find.byKey(const Key('block')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirmBlock')));
      await tester.pumpAndSettle();
      expect(env.blocked, isTrue);
      expect(find.byKey(const Key('blockedBadge')), findsOneWidget);
      await tester.tap(find.byKey(const Key('unblock')));
      await tester.pumpAndSettle();
      expect(env.blocked, isFalse);
      expect(find.byKey(const Key('blockedBadge')), findsNothing);
    });
  });

  group('catalog editing', () {
    testWidgets('editing a service sends the changes; an empty deposit falls back to the business default', (tester) async {
      final env = Env();
      await openFromMore(tester, env, 'Services');
      await tester.tap(find.byKey(const Key('service-s1')));
      await tester.pumpAndSettle();
      expect((tester.widget(find.byKey(const Key('svcName'))) as TextFormField).controller!.text, 'Haircut');   // prefilled
      expect((tester.widget(find.byKey(const Key('svcDeposit'))) as TextFormField).controller!.text, '30');
      await tester.enterText(find.byKey(const Key('svcPrice')), '25000');
      await tester.enterText(find.byKey(const Key('svcDeposit')), '');
      await tester.ensureVisible(find.byKey(const Key('svcSave')));
      await tester.tap(find.byKey(const Key('svcSave')));
      await tester.pumpAndSettle();
      expect(env.bodyOf('PATCH', '/services/s1'), {'name': 'Haircut', 'durationMinutes': 60, 'bufferMinutes': 15, 'price': '25000', 'useBusinessDeposit': true, 'active': true});
    });

    testWidgets('deactivating a service is explained, sent, and the service stops being offered for booking', (tester) async {
      final env = Env();
      await openFromMore(tester, env, 'Services');
      await tester.tap(find.byKey(const Key('service-s1')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Existing bookings and history are kept'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('svcActive')));
      await tester.tap(find.byKey(const Key('svcActive')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('svcSave')));
      await tester.tap(find.byKey(const Key('svcSave')));
      await tester.pumpAndSettle();
      expect(env.bodyOf('PATCH', '/services/s1')!['active'], false);
      expect(find.textContaining('Inactive'), findsOneWidget);

      // the booking form no longer offers it
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Calendar').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('newBooking')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('setupFirst')), findsOneWidget);
    });

    testWidgets('editing a specialist renames and deactivates, then saves assignments', (tester) async {
      final env = Env();
      await openFromMore(tester, env, 'Specialists');
      await tester.tap(find.byKey(const Key('emp-e1')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('empEditName')), 'Dana K.');
      await tester.tap(find.byKey(const Key('empActive')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('saveAssignments')));
      await tester.tap(find.byKey(const Key('saveAssignments')));
      await tester.pumpAndSettle();
      expect(env.bodyOf('PATCH', '/employees/e1'), {'displayName': 'Dana K.', 'active': false});
      expect(env.bodyOf('PUT', '/assignments'), {'branchIds': ['br1'], 'serviceIds': ['s1']});
      expect(find.text('Dana K.'), findsOneWidget);
      expect(find.text('Inactive'), findsOneWidget);
    });

    testWidgets('an empty specialist name is rejected locally with the right message (not "no connection")', (tester) async {
      final env = Env();
      await openFromMore(tester, env, 'Specialists');
      await tester.tap(find.byKey(const Key('emp-e1')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('empEditName')), '   ');
      await tester.ensureVisible(find.byKey(const Key('saveAssignments')));
      await tester.tap(find.byKey(const Key('saveAssignments')));
      await tester.pump();
      expect(find.text('Required'), findsOneWidget);
      expect(find.text('No connection to the server'), findsNothing);
      expect(env.adapter.calls.where((c) => c.method == 'PATCH'), isEmpty);
    });

    testWidgets('editing a location sends name, address and active state', (tester) async {
      final env = Env();
      await openFromMore(tester, env, 'Locations & hours');
      await tester.tap(find.byKey(const Key('editBranch-br1')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Central');
      await tester.enterText(find.byType(TextFormField).last, 'Dostyk 10');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(env.bodyOf('PATCH', '/branches/br1'), {'name': 'Central', 'address': 'Dostyk 10', 'active': true});
      expect(find.text('Central'), findsOneWidget);
    });

    testWidgets('the plan limit on reactivation is explained inside the dialog', (tester) async {
      final env = Env();
      env.branch = {...env.branch, 'active': false};
      env.adapter.routes['PATCH /api/v1/businesses/b1/branches/br1'] = (_) => err(402, 'BRANCH_LIMIT_REACHED');
      await openFromMore(tester, env, 'Locations & hours');
      await tester.tap(find.byKey(const Key('editBranch-br1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('branchActive')));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.text('Your plan limit is reached. Contact ORLEU to upgrade.'), findsOneWidget);
      expect(find.byKey(const Key('formError')), findsOneWidget);
    });
  });

  test('models parse the new profile and catalog fields', () {
    final p = CustomerProfile.fromJson(profileJson(), zone: 'Asia/Almaty');
    expect(p.stats.lastVisit, DateTime(2026, 11, 5, 10, 0));
    expect(p.stats.averageSpendPerVisit, 15000);
    expect(p.bookings.single.startsAt, DateTime(2026, 11, 5, 10, 0));
    expect(CustomerProfile.fromJson(profileJson(visits: false)).stats.averageSpendPerVisit, isNull);
    expect(ServiceItem.fromJson({'id': 's', 'name': 'n', 'durationMinutes': 30, 'price': 1}).active, isTrue);
    expect(ServiceItem.fromJson({'id': 's', 'name': 'n', 'durationMinutes': 30, 'price': 1}).depositPercent, isNull);
    expect(Employee.fromJson({'id': 'e', 'displayName': 'n', 'active': false}).active, isFalse);
  });
}
