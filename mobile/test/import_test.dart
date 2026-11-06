import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orleu_mobile/app.dart';
import 'package:orleu_mobile/core/api/api_client.dart';
import 'package:orleu_mobile/core/api/token_store.dart';
import 'package:orleu_mobile/features/customers/import_screen.dart';

import 'support/fake_api.dart';

Map<String, Object?> report({required bool dry, int created = 2, int invalid = 1}) => {
      'dryRun': dry, 'totalRows': 4, 'created': created, 'existing': 1, 'duplicatesInFile': 0, 'invalid': invalid,
      'issues': invalid > 0 ? [{'row': 4, 'reason': 'PHONE_INVALID'}] : [], 'issuesTruncated': false,
      'preview': [{'fullName': 'Aigerim', 'phone': '+77011234567', 'email': null}, {'fullName': 'Dana', 'phone': '+77022223344', 'email': null}],
    };

Future<FakeAdapter> open(WidgetTester tester, {PickedCsv? file, Handler? dry, Handler? real}) async {
  setPhone(tester, 390, 1200);
  final a = FakeAdapter({
    ...businessRoutes(),
    'GET /api/v1/businesses': (_) => ok([{'id': 'b1', 'name': 'Studio', 'slug': 'studio', 'currency': 'KZT', 'planCode': 'FREE', 'published': true, 'timezone': 'Asia/Almaty'}]),
    'POST /api/v1/businesses/b1/customers/import': (o) => (o.data as Map)['dryRun'] == true ? (dry?.call(o) ?? ok(report(dry: true))) : (real?.call(o) ?? ok(report(dry: false))),
  });
  final store = MemoryTokenStore()..access = 'a'..refresh = 'r';
  await tester.pumpWidget(ProviderScope(
    retry: appRetry,
    overrides: [...overridesFor(a, store), csvPickerProvider.overrideWithValue(() async => file)],
    child: const OrleuApp(),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Customers').last);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('importCsv')));
  await tester.pumpAndSettle();
  return a;
}

PickedCsv csv(String text) => (name: 'clients.csv', bytes: Uint8List.fromList(utf8.encode(text)));

void main() {
  testWidgets('choosing a file shows a dry-run preview with counts and row problems, nothing is imported yet', (tester) async {
    final a = await open(tester, file: csv('name,phone\nAigerim,8 701 123 45 67\n'));
    await tester.tap(find.byKey(const Key('chooseFile')));
    await tester.pumpAndSettle();
    expect(find.text('New clients'), findsOneWidget);
    expect(find.text('Aigerim · +77011234567'), findsOneWidget);
    expect(find.text('Row 4: invalid phone number'), findsOneWidget);
    expect(find.text('Import 2 clients'), findsOneWidget);
    final posts = a.calls.where((c) => c.method == 'POST').toList();
    expect(posts.length, 1);
    expect((posts.single.data as Map)['dryRun'], true);
    expect((posts.single.data as Map)['csv'], contains('Aigerim'));
  });

  testWidgets('confirming sends the same file for real and shows the result', (tester) async {
    final a = await open(tester, file: csv('name,phone\nAigerim,+77011234567\n'));
    await tester.tap(find.byKey(const Key('chooseFile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmImport')));
    await tester.pumpAndSettle();
    expect(find.text('Imported 2 clients'), findsOneWidget);
    final real = a.calls.where((c) => c.method == 'POST' && (c.data as Map)['dryRun'] == false);
    expect(real.length, 1);
  });

  testWidgets('a file with nothing new offers no import button', (tester) async {
    await open(tester, file: csv('name,phone\nA,+77011234567\n'), dry: (_) => ok(report(dry: true, created: 0, invalid: 0)));
    await tester.tap(find.byKey(const Key('chooseFile')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('nothingNew')), findsOneWidget);
    expect(find.byKey(const Key('confirmImport')), findsNothing);
  });

  testWidgets('a file that is not UTF-8 is rejected before anything is sent, with a hint about Excel', (tester) async {
    final a = await open(tester, file: (name: 'old.csv', bytes: Uint8List.fromList([0x41, 0xC0, 0xC1, 0xFF])));
    await tester.tap(find.byKey(const Key('chooseFile')));
    await tester.pumpAndSettle();
    expect(find.textContaining('CSV UTF-8'), findsOneWidget);
    expect(a.calls.where((c) => c.method == 'POST'), isEmpty);
  });

  testWidgets('server rejections are explained in plain language', (tester) async {
    await open(tester, file: csv('foo,bar\n1,2\n'), dry: (_) => err(400, 'IMPORT_MISSING_COLUMNS'));
    await tester.tap(find.byKey(const Key('chooseFile')));
    await tester.pumpAndSettle();
    expect(find.text('The first row must contain a name column and a phone column'), findsOneWidget);
    expect(find.byKey(const Key('confirmImport')), findsNothing);
  });

  testWidgets('cancelling the picker changes nothing', (tester) async {
    final a = await open(tester, file: null);
    await tester.tap(find.byKey(const Key('chooseFile')));
    await tester.pumpAndSettle();
    expect(a.calls.where((c) => c.method == 'POST'), isEmpty);
    expect(find.byKey(const Key('importError')), findsNothing);
  });
}
