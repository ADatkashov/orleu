import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orleu_mobile/admin/admin_app.dart';
import 'package:orleu_mobile/core/api/api_client.dart';
import 'package:orleu_mobile/core/api/token_store.dart';

import 'support/fake_api.dart';

class Env {
  String role;
  bool disabled = false;
  String ticketStatus = 'OPEN';
  final messages = <Map<String, Object?>>[
    {'id': 'm1', 'fromPlatform': false, 'authorName': 'Owner', 'body': 'How do I upgrade?', 'createdAt': '2026-11-05T10:00:00Z'},
  ];
  Handler? replyOverride;
  late final FakeAdapter adapter;

  Map<String, Object?> ticket() => {
        'id': 't1', 'businessId': 'b1', 'businessName': 'Studio Almaty', 'subject': 'Cannot upgrade', 'category': 'BILLING', 'status': ticketStatus,
        'createdByEmail': 'owner@example.com', 'createdAt': '2026-11-05T10:00:00Z', 'updatedAt': '2026-11-05T10:00:00Z',
      };

  Env({this.role = 'SUPER_ADMIN'}) {
    adapter = FakeAdapter({
      'GET /api/v1/me': (_) => ok({'id': 'u1', 'email': 'admin@example.com', 'fullName': 'Admin', 'memberships': []}),
      'GET /api/v1/admin/me': (_) => ok({'role': role, 'canModify': role == 'SUPER_ADMIN'}),
      'GET /api/v1/admin/businesses': (_) => ok({'items': [], 'page': 0, 'size': 20}),
      'GET /api/v1/admin/users': (_) => ok({'items': [
            {'id': 'u9', 'email': 'owner@example.com', 'fullName': 'Aigerim', 'status': disabled ? 'DISABLED' : 'ACTIVE', 'platformRole': null, 'businesses': 1, 'createdAt': '2026-11-01T10:00:00Z'},
          ], 'page': 0, 'size': 20}),
      'POST /api/v1/admin/users/u9/disable': (_) { disabled = true; return ok({}); },
      'POST /api/v1/admin/users/u9/enable': (_) { disabled = false; return ok({}); },
      'GET /api/v1/admin/support/tickets': (o) => ok(o.queryParameters['status'] == 'CLOSED' ? [] : [ticket()]),
      'GET /api/v1/admin/support/tickets/t1': (_) => ok({'ticket': ticket(), 'messages': messages}),
      'POST /api/v1/admin/support/tickets/t1/reply': (o) =>
          replyOverride?.call(o) ?? (() {
            messages.add({'id': 'm2', 'fromPlatform': true, 'authorName': 'Admin', 'body': (o.data as Map)['body'], 'createdAt': '2026-11-05T11:00:00Z'});
            ticketStatus = 'ANSWERED';
            return ok({});
          })(),
      'POST /api/v1/admin/support/tickets/t1/status': (o) { ticketStatus = (o.data as Map)['status']; return ok({}); },
    });
  }
}

Future<void> open(WidgetTester tester, Env e, String path) async {
  setPhone(tester, 1280, 900);
  final store = MemoryTokenStore()..access = 'a'..refresh = 'r';
  await tester.pumpWidget(ProviderScope(retry: appRetry, overrides: overridesFor(e.adapter, store), child: const AdminApp()));
  await tester.pumpAndSettle();
  await tester.tap(find.text(path).last);
  await tester.pumpAndSettle();
}

void main() {
  group('users', () {
    testWidgets('super admin can disable and re-enable a user after confirming', (tester) async {
      final e = Env();
      await open(tester, e, 'Users');
      expect(find.text('owner@example.com'), findsOneWidget);
      await tester.tap(find.byKey(const Key('toggle-owner@example.com')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirmToggle')));
      await tester.pumpAndSettle();
      expect(e.disabled, isTrue);
      expect(find.text('DISABLED'), findsOneWidget);
      await tester.tap(find.byKey(const Key('toggle-owner@example.com')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirmToggle')));
      await tester.pumpAndSettle();
      expect(e.disabled, isFalse);
    });

    testWidgets('support staff see users read-only; analysts see neither Users nor Support', (tester) async {
      final support = Env(role: 'PLATFORM_SUPPORT');
      await open(tester, support, 'Users');
      expect(find.text('owner@example.com'), findsOneWidget);
      expect(find.byKey(const Key('toggle-owner@example.com')), findsNothing);
    });

    testWidgets('analysts do not get the personal-data sections', (tester) async {
      setPhone(tester, 1280, 900);
      final e = Env(role: 'PLATFORM_ANALYST');
      final store = MemoryTokenStore()..access = 'a'..refresh = 'r';
      await tester.pumpWidget(ProviderScope(retry: appRetry, overrides: overridesFor(e.adapter, store), child: const AdminApp()));
      await tester.pumpAndSettle();
      expect(find.text('Businesses'), findsWidgets);
      expect(find.text('Users'), findsNothing);
      expect(find.text('Support'), findsNothing);
    });
  });

  group('support tickets', () {
    testWidgets('open tickets are listed, replying sends the text and the thread refreshes', (tester) async {
      final e = Env();
      await open(tester, e, 'Support');
      expect(find.text('Cannot upgrade'), findsOneWidget);
      await tester.tap(find.byKey(const Key('ticket-t1')));
      await tester.pumpAndSettle();
      expect(find.text('How do I upgrade?'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('replyBody')), 'We upgraded you.');
      await tester.tap(find.byKey(const Key('send')));
      await tester.pumpAndSettle();
      expect(find.text('We upgraded you.'), findsOneWidget);
      expect(find.text('ANSWERED'), findsOneWidget);
      expect(find.text('Platform team · Admin · 2026-11-05 ${DateTime.parse('2026-11-05T11:00:00Z').toLocal().hour.toString().padLeft(2, '0')}:00'), findsOneWidget);
    });

    testWidgets('a rejected reply is explained inline and the text is kept', (tester) async {
      final e = Env()..replyOverride = (_) => err(409, 'TICKET_CLOSED');
      await open(tester, e, 'Support');
      await tester.tap(find.byKey(const Key('ticket-t1')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('replyBody')), 'late answer');
      await tester.tap(find.byKey(const Key('send')));
      await tester.pumpAndSettle();
      expect(find.text('This ticket is closed. Reopen it first.'), findsOneWidget);
      expect(find.text('late answer'), findsOneWidget);
    });

    testWidgets('closing a ticket offers to reopen it', (tester) async {
      final e = Env();
      await open(tester, e, 'Support');
      await tester.tap(find.byKey(const Key('ticket-t1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('close')));
      await tester.pumpAndSettle();
      expect(e.ticketStatus, 'CLOSED');
      expect(find.byKey(const Key('reopen')), findsOneWidget);
      expect(find.byKey(const Key('replyBody')), findsNothing);
    });
  });
}
