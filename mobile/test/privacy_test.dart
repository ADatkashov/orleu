import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orleu_mobile/app.dart';
import 'package:orleu_mobile/core/api/api_client.dart';
import 'package:orleu_mobile/core/api/token_store.dart';
import 'package:orleu_mobile/features/finance/export_section.dart';

import 'support/fake_api.dart';

Map<String, Object?> profile() => {
      'customer': {'id': 'c1', 'fullName': 'Aigerim Sadykova', 'phone': '+77011234567', 'email': null, 'notes': null, 'marketingOptIn': false, 'blocked': false},
      'stats': {'totalBookings': 0, 'completedVisits': 0, 'cancelled': 0, 'noShows': 0, 'upcoming': 0, 'lastVisit': null, 'totalSpent': 0, 'averageSpendPerVisit': null},
      'bookings': [],
    };

Future<FakeAdapter> openProfile(WidgetTester tester, {String role = 'BUSINESS_OWNER', Handler? erase, void Function(String, Uint8List)? onSave}) async {
  setPhone(tester, 390, 1800);
  final a = FakeAdapter({
    ...businessRoutes(),
    'GET /api/v1/me': (_) => ok({'id': 'u1', 'email': 'a@b.kz', 'fullName': 'Aigerim', 'locale': 'en', 'memberships': [{'businessId': 'b1', 'businessName': 'Studio', 'role': role}]}),
    'GET /api/v1/businesses': (_) => ok([{'id': 'b1', 'name': 'Studio', 'slug': 'studio', 'currency': 'KZT', 'planCode': 'FREE', 'published': true, 'timezone': 'Asia/Almaty'}]),
    'GET /api/v1/businesses/b1/customers': (_) => ok({'items': [{'id': 'c1', 'fullName': 'Aigerim Sadykova', 'phone': '+77011234567', 'blocked': false}], 'page': 0, 'size': 50, 'total': 1}),
    'GET /api/v1/businesses/b1/customers/c1/profile': (_) => ok(profile()),
    'GET /api/v1/businesses/b1/customers/c1/export': (_) => ok({'customer': {'fullName': 'Aigerim Sadykova'}, 'bookings': []}),
    'POST /api/v1/businesses/b1/customers/c1/anonymize': (o) => erase?.call(o) ?? (status: 204, body: null),
  });
  final store = MemoryTokenStore()..access = 'a'..refresh = 'r';
  await tester.pumpWidget(ProviderScope(
    retry: appRetry,
    overrides: [...overridesFor(a, store), csvSaverProvider.overrideWithValue((name, bytes) async { onSave?.call(name, bytes); return true; })],
    child: const OrleuApp(),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Customers').last);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('customer-c1')));
  await tester.pumpAndSettle();
  await tester.drag(find.byType(ListView).first, const Offset(0, -400));
  await tester.pumpAndSettle();
  return a;
}

void main() {
  testWidgets('exporting a client saves a JSON file named after the client id', (tester) async {
    String? name;
    Uint8List? bytes;
    await openProfile(tester, onSave: (n, b) { name = n; bytes = b; });
    await tester.tap(find.byKey(const Key('exportClient')));
    await tester.pumpAndSettle();
    expect(name, 'customer-c1.json');
    expect(jsonDecode(utf8.decode(bytes!))['customer']['fullName'], 'Aigerim Sadykova');
  });

  testWidgets('only owners and admins see the delete button', (tester) async {
    await openProfile(tester, role: 'RECEPTIONIST');
    expect(find.byKey(const Key('exportClient')), findsOneWidget);
    expect(find.byKey(const Key('eraseClient')), findsNothing);
  });

  testWidgets('deleting personal data needs a confirmation that states what is lost; a server refusal stays inline and keeps the dialog', (tester) async {
    var calls = 0;
    final a = await openProfile(tester, erase: (_) { calls++; return calls == 1 ? err(409, 'HAS_UPCOMING_BOOKINGS') : (status: 204, body: null); });
    await tester.tap(find.byKey(const Key('eraseClient')));
    await tester.pumpAndSettle();
    expect(find.textContaining('cannot be undone'), findsOneWidget);
    expect(a.calls.where((c) => c.method == 'POST'), isEmpty, reason: 'nothing is sent before confirming');
    await tester.tap(find.byKey(const Key('confirmErase')));
    await tester.pumpAndSettle();
    expect(find.text('Cancel the upcoming bookings of this client first'), findsOneWidget);
    expect(find.byKey(const Key('confirmErase')), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirmErase')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('confirmErase')), findsNothing, reason: 'the dialog closes after success');
    expect(calls, 2);
  });

  testWidgets('the retention setting sends months (0 = off)', (tester) async {
    setPhone(tester, 390, 1400);
    var months = 0;
    final a = FakeAdapter({
      ...businessRoutes(),
      'GET /api/v1/businesses': (_) => ok([{'id': 'b1', 'name': 'Studio', 'slug': 'studio', 'currency': 'KZT', 'planCode': 'FREE', 'published': true, 'timezone': 'Asia/Almaty', 'customerRetentionMonths': months == 0 ? null : months}]),
      'GET /api/v1/businesses/b1/notifications/customer-messages': (_) => ok([]),
      'PATCH /api/v1/businesses/b1/settings': (o) { months = (o.data as Map)['customerRetentionMonths'] ?? months; return ok({}); },
    });
    final store = MemoryTokenStore()..access = 'a'..refresh = 'r';
    await tester.pumpWidget(ProviderScope(retry: appRetry, overrides: overridesFor(a, store), child: const OrleuApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('More').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Customer messages'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3 years'));
    await tester.pumpAndSettle();
    expect(months, 36);
    await tester.tap(find.descendant(of: find.byKey(const Key('retention')), matching: find.text('Off')));
    await tester.pumpAndSettle();
    expect(months, 0);
    expect(a.calls.where((c) => c.method == 'PATCH').map((c) => (c.data as Map)['customerRetentionMonths']), [36, 0]);
  });
}
