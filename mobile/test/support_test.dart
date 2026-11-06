import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orleu_mobile/app.dart';
import 'package:orleu_mobile/core/api/api_client.dart';
import 'package:orleu_mobile/core/api/token_store.dart';

import 'support/fake_api.dart';

class Env {
  String status = 'OPEN';
  bool hasTicket = true;
  Handler? createOverride;
  final messages = <Map<String, Object?>>[
    {'id': 'm1', 'fromPlatform': false, 'authorName': 'Aigerim', 'body': 'How do I upgrade?', 'createdAt': '2026-11-05T05:00:00Z'},
    {'id': 'm2', 'fromPlatform': true, 'authorName': 'Support', 'body': 'We can do that manually.', 'createdAt': '2026-11-05T06:00:00Z'},
  ];
  Map<String, Object?> ticket() => {'id': 't1', 'businessId': 'b1', 'businessName': 'Studio', 'subject': 'Cannot upgrade', 'category': 'BILLING', 'status': status,
        'createdByEmail': 'a@b.kz', 'createdAt': '2026-11-05T05:00:00Z', 'updatedAt': '2026-11-05T06:00:00Z'};
  late final FakeAdapter adapter = FakeAdapter({
    ...businessRoutes(),
    'GET /api/v1/businesses': (_) => ok([{'id': 'b1', 'name': 'Studio', 'slug': 'studio', 'currency': 'KZT', 'planCode': 'FREE', 'published': true, 'timezone': 'Asia/Almaty'}]),
    'GET /api/v1/businesses/b1/support/tickets': (_) => ok(hasTicket ? [ticket()] : []),
    'GET /api/v1/businesses/b1/support/tickets/t1': (_) => ok({'ticket': ticket(), 'messages': messages}),
    'POST /api/v1/businesses/b1/support/tickets': (o) => createOverride?.call(o) ?? (() { hasTicket = true; return (status: 201, body: {'ticket': ticket(), 'messages': messages}); })(),
    'POST /api/v1/businesses/b1/support/tickets/t1/messages': (o) {
      messages.add({'id': 'm3', 'fromPlatform': false, 'authorName': 'Aigerim', 'body': (o.data as Map)['body'], 'createdAt': '2026-11-05T07:00:00Z'});
      status = 'OPEN';
      return ok({});
    },
    'POST /api/v1/businesses/b1/support/tickets/t1/close': (_) { status = 'CLOSED'; return ok({}); },
  });
}

Future<void> open(WidgetTester tester, Env e) async {
  setPhone(tester, 390, 1200);
  final store = MemoryTokenStore()..access = 'a'..refresh = 'r';
  await tester.pumpWidget(ProviderScope(retry: appRetry, overrides: overridesFor(e.adapter, store), child: const OrleuApp()));
  await tester.pumpAndSettle();
  await tester.tap(find.text('More').last);
  await tester.pumpAndSettle();
  await tester.drag(find.byType(ListView).first, const Offset(0, -200));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Support'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('tickets are listed with their status; the thread shows both sides; a reply is sent and appears', (tester) async {
    final e = Env();
    await open(tester, e);
    expect(find.text('Cannot upgrade'), findsOneWidget);
    expect(find.text('Waiting for support'), findsOneWidget);
    await tester.tap(find.byKey(const Key('ticket-t1')));
    await tester.pumpAndSettle();
    expect(find.text('How do I upgrade?'), findsOneWidget);
    expect(find.text('We can do that manually.'), findsOneWidget);
    expect(find.textContaining('ORLEU support'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('reply')), 'Please go ahead');
    await tester.tap(find.byKey(const Key('sendReply')));
    await tester.pumpAndSettle();
    expect(find.text('Please go ahead'), findsOneWidget);
  });

  testWidgets('closing a request removes the reply box and explains it', (tester) async {
    final e = Env();
    await open(tester, e);
    await tester.tap(find.byKey(const Key('ticket-t1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('closeTicket')));
    await tester.pumpAndSettle();
    expect(e.status, 'CLOSED');
    expect(find.byKey(const Key('closedNote')), findsOneWidget);
    expect(find.byKey(const Key('reply')), findsNothing);
  });

  testWidgets('a new request needs subject and text, and server rejections stay inline in the sheet', (tester) async {
    final e = Env()..hasTicket = false..createOverride = (_) => err(409, 'TOO_MANY_OPEN_TICKETS');
    await open(tester, e);
    expect(find.byKey(const Key('noTickets')), findsOneWidget);
    await tester.tap(find.byKey(const Key('newTicket')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('createTicket')));
    await tester.pump();
    expect(find.text('Required'), findsOneWidget);
    expect(e.adapter.calls.where((c) => c.method == 'POST'), isEmpty);
    await tester.enterText(find.byKey(const Key('subject')), 'Help');
    await tester.enterText(find.byKey(const Key('body')), 'Something broke');
    await tester.tap(find.byKey(const Key('createTicket')));
    await tester.pumpAndSettle();
    expect(find.text('Too many open requests. Close some or wait for answers.'), findsOneWidget);
    expect(find.byKey(const Key('createTicket')), findsOneWidget, reason: 'sheet stays open so the text is not lost');
  });

  testWidgets('creating a request opens its thread', (tester) async {
    final e = Env()..hasTicket = false;
    await open(tester, e);
    await tester.tap(find.byKey(const Key('newTicket')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cat-BILLING')));
    await tester.enterText(find.byKey(const Key('subject')), 'Cannot upgrade');
    await tester.enterText(find.byKey(const Key('body')), 'How do I upgrade?');
    await tester.tap(find.byKey(const Key('createTicket')));
    await tester.pumpAndSettle();
    final post = e.adapter.calls.firstWhere((c) => c.method == 'POST');
    expect(post.data, {'subject': 'Cannot upgrade', 'category': 'BILLING', 'body': 'How do I upgrade?'});
    expect(find.text('How do I upgrade?'), findsOneWidget);
  });
}
