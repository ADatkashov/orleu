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

const csvText = '﻿recorded_at_local;type;amount_signed\r\n2026-11-05 10:00:00;PAYMENT;20000.00\r\n';

Future<FakeAdapter> open(WidgetTester tester, {required String role, bool saved = true, Handler? export, void Function(String, Uint8List)? onSave}) async {
  setPhone(tester, 390, 2200);
  final a = FakeAdapter({
    ...businessRoutes(),
    'GET /api/v1/me': (_) => ok({'id': 'u1', 'email': 'a@b.kz', 'fullName': 'Aigerim', 'locale': 'en', 'memberships': [{'businessId': 'b1', 'businessName': 'Studio', 'role': role}]}),
    'GET /api/v1/businesses': (_) => ok([{'id': 'b1', 'name': 'Studio', 'slug': 'studio', 'currency': 'KZT', 'planCode': 'FREE', 'published': true, 'timezone': 'Asia/Almaty'}]),
    'GET /api/v1/businesses/b1/analytics/breakdown': (_) => ok([]),
    'GET /api/v1/businesses/b1/analytics/timeseries': (_) => ok([]),
    'GET /api/v1/businesses/b1/analytics/peak-hours': (_) => ok(List.filled(24, 0)),
    'GET /api/v1/businesses/b1/analytics/customers': (_) => ok({'newCustomers': 0, 'returningCustomers': 0, 'returningShare': 0}),
    'GET /api/v1/businesses/b1/finance/export': (o) => export?.call(o) ?? (status: 200, body: csvText),
  });
  final store = MemoryTokenStore()..access = 'a'..refresh = 'r';
  await tester.pumpWidget(ProviderScope(
    retry: appRetry,
    overrides: [...overridesFor(a, store), csvSaverProvider.overrideWithValue((name, bytes) async { onSave?.call(name, bytes); return saved; })],
    child: const OrleuApp(),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Finance').last);
  await tester.pumpAndSettle();
  await tester.drag(find.byType(ListView).first, const Offset(0, -2000));
  await tester.pumpAndSettle();
  return a;
}

void main() {
  testWidgets('an accountant exports the selected period: Excel-friendly delimiter by default, file handed to the save dialog', (tester) async {
    String? savedName;
    Uint8List? savedBytes;
    final a = await open(tester, role: 'ACCOUNTANT', onSave: (n, b) { savedName = n; savedBytes = b; });
    await tester.tap(find.byKey(const Key('exportCsv')));
    await tester.pumpAndSettle();
    final req = a.calls.lastWhere((c) => c.path.endsWith('/finance/export'));
    expect(req.queryParameters['delimiter'], 'semicolon');
    expect(DateTime.parse(req.queryParameters['to']).difference(DateTime.parse(req.queryParameters['from'])).inDays, inInclusiveRange(29, 31));
    expect(savedName, 'orleu-ledger-test.csv');
    expect(savedBytes!.sublist(0, 3), [0xEF, 0xBB, 0xBF], reason: 'the UTF-8 BOM is kept so Excel reads Cyrillic correctly');
    expect(utf8.decode(savedBytes!), csvText.substring(1)); // utf8.decode drops the BOM
    expect(find.text('File saved'), findsOneWidget);
  });

  testWidgets('switching to comma changes the request', (tester) async {
    final a = await open(tester, role: 'BUSINESS_OWNER');
    await tester.tap(find.text('Comma'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('exportCsv')));
    await tester.pumpAndSettle();
    expect(a.calls.lastWhere((c) => c.path.endsWith('/finance/export')).queryParameters['delimiter'], 'comma');
  });

  testWidgets('roles without export permission do not see the button at all', (tester) async {
    await open(tester, role: 'RECEPTIONIST');
    expect(find.byKey(const Key('exportCsv')), findsNothing);
  });

  testWidgets('cancelling the save dialog and a server refusal are both reported honestly', (tester) async {
    await open(tester, role: 'BUSINESS_ADMIN', saved: false);
    await tester.tap(find.byKey(const Key('exportCsv')));
    await tester.pumpAndSettle();
    expect(find.text('Not saved'), findsOneWidget);
  });

  testWidgets('a 403 from the server shows the permission message', (tester) async {
    await open(tester, role: 'ACCOUNTANT', export: (_) => err(403, 'FORBIDDEN'));
    await tester.tap(find.byKey(const Key('exportCsv')));
    await tester.pumpAndSettle();
    expect(find.text('Your role cannot export financial data'), findsOneWidget);
  });
}
