import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orleu_mobile/admin/admin_app.dart';
import 'package:orleu_mobile/app.dart';
import 'package:orleu_mobile/core/api/api_client.dart';
import 'package:orleu_mobile/core/api/token_store.dart';

import 'support/fake_api.dart';

Map<String, Object?> review({String? reply, bool hidden = false}) => {
      'id': 'r1', 'rating': 2, 'comment': 'waited too long', 'customerName': 'Aigerim', 'serviceName': 'Haircut', 'createdAt': '2026-11-05T05:00:00Z',
      'reply': reply, 'hidden': hidden, 'hiddenReason': hidden ? 'spam link' : null,
    };

class BizEnv {
  String role;
  String? reply;
  bool hidden = false;
  late final FakeAdapter adapter;
  BizEnv({this.role = 'BUSINESS_OWNER'}) {
    adapter = FakeAdapter({
      ...businessRoutes(),
      'GET /api/v1/me': (_) => ok({'id': 'u1', 'email': 'a@b.kz', 'fullName': 'A', 'locale': 'en', 'memberships': [{'businessId': 'b1', 'role': role}]}),
      'GET /api/v1/businesses/b1/reviews/summary': (_) => ok({'count': 1, 'average': 2.0, 'distribution': [0, 1, 0, 0, 0]}),
      'GET /api/v1/businesses/b1/reviews': (_) => ok([review(reply: reply, hidden: hidden)]),
      'PUT /api/v1/businesses/b1/reviews/r1/reply': (o) { reply = (o.data as Map)['text']; return ok(review(reply: reply)); },
      'DELETE /api/v1/businesses/b1/reviews/r1/reply': (_) { reply = null; return ok(review()); },
    });
  }
}

Future<void> openReviews(WidgetTester tester, BizEnv e) async {
  setPhone(tester, 390, 1400);
  final store = MemoryTokenStore()..access = 'a'..refresh = 'r';
  await tester.pumpWidget(ProviderScope(retry: appRetry, overrides: overridesFor(e.adapter, store), child: const OrleuApp()));
  await tester.pumpAndSettle();
  await tester.tap(find.text('More').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Reviews'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the owner replies to a review and can remove the reply', (tester) async {
    final e = BizEnv();
    await openReviews(tester, e);
    await tester.ensureVisible(find.byKey(const Key('reply-btn-r1')));
    await tester.tap(find.byKey(const Key('reply-btn-r1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sendReply')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('formError')), findsOneWidget, reason: 'an empty reply is refused locally, inside the dialog');
    await tester.enterText(find.byKey(const Key('replyText')), 'Sorry about that!');
    await tester.tap(find.byKey(const Key('sendReply')));
    await tester.pumpAndSettle();
    final put = e.adapter.calls.firstWhere((c) => c.method == 'PUT' && c.path.endsWith('/reply'));
    expect(put.data, {'text': 'Sorry about that!'});
    expect(find.text('Sorry about that!'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('removeReply-r1')));
    await tester.tap(find.byKey(const Key('removeReply-r1')));
    await tester.pumpAndSettle();
    expect(e.adapter.calls.any((c) => c.method == 'DELETE' && c.path.endsWith('/reply')), isTrue);
    expect(find.text('Sorry about that!'), findsNothing);
  });

  testWidgets('a receptionist cannot reply', (tester) async {
    final recep = BizEnv(role: 'RECEPTIONIST');
    await openReviews(tester, recep);
    expect(find.byKey(const Key('reply-btn-r1')), findsNothing);
  });

  testWidgets('a hidden review shows the platform reason and offers no reply', (tester) async {
    final owner = BizEnv()..hidden = true;
    await openReviews(tester, owner);
    expect(find.textContaining('Hidden by the platform: spam link'), findsOneWidget);
    expect(find.byKey(const Key('reply-btn-r1')), findsNothing);
  });

  testWidgets('platform support hides a review with a reason and shows it again', (tester) async {
    var hidden = false;
    String? sentReason;
    final a = FakeAdapter({
      'GET /api/v1/me': (_) => ok({'id': 'u1', 'email': 'admin@example.com', 'fullName': 'Admin', 'memberships': []}),
      'GET /api/v1/admin/me': (_) => ok({'role': 'PLATFORM_SUPPORT', 'canModify': false}),
      'GET /api/v1/admin/businesses': (_) => ok({'items': [], 'page': 0, 'size': 20}),
      'GET /api/v1/admin/reviews': (_) => ok([
            {'id': 'r1', 'businessId': 'b1', 'businessName': 'Studio Almaty', 'rating': 1, 'comment': 'spam http://x', 'customerName': 'Guest', 'createdAt': '2026-11-05T05:00:00Z', 'hidden': hidden, 'hiddenReason': hidden ? sentReason : null},
          ]),
      'POST /api/v1/admin/reviews/r1/hide': (o) {
        final reason = (o.data as Map)['reason'] as String;
        if (reason.length < 5) return err(400, 'VALIDATION_ERROR');
        sentReason = reason;
        hidden = true;
        return (status: 204, body: null);
      },
      'POST /api/v1/admin/reviews/r1/unhide': (_) { hidden = false; return (status: 204, body: null); },
    });
    setPhone(tester, 1280, 900);
    final store = MemoryTokenStore()..access = 'a'..refresh = 'r';
    await tester.pumpWidget(ProviderScope(retry: appRetry, overrides: overridesFor(a, store), child: const AdminApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reviews').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Studio Almaty'), findsOneWidget);
    await tester.tap(find.byKey(const Key('hide-r1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('hideReason')), 'no');
    await tester.tap(find.byKey(const Key('confirmHide')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('confirmHide')), findsOneWidget, reason: 'a rejected reason keeps the dialog open with an inline error');
    await tester.enterText(find.byKey(const Key('hideReason')), 'Spam with a link');
    await tester.tap(find.byKey(const Key('confirmHide')));
    await tester.pumpAndSettle();
    expect(sentReason, 'Spam with a link');
    expect(find.text('HIDDEN'), findsOneWidget);
    await tester.tap(find.byKey(const Key('unhide-r1')));
    await tester.pumpAndSettle();
    expect(find.text('HIDDEN'), findsNothing);
  });

  testWidgets('analysts do not get the Reviews section', (tester) async {
    final a = FakeAdapter({
      'GET /api/v1/me': (_) => ok({'id': 'u1', 'email': 'admin@example.com', 'fullName': 'Admin', 'memberships': []}),
      'GET /api/v1/admin/me': (_) => ok({'role': 'PLATFORM_ANALYST', 'canModify': false}),
      'GET /api/v1/admin/businesses': (_) => ok({'items': [], 'page': 0, 'size': 20}),
    });
    setPhone(tester, 1280, 900);
    final store = MemoryTokenStore()..access = 'a'..refresh = 'r';
    await tester.pumpWidget(ProviderScope(retry: appRetry, overrides: overridesFor(a, store), child: const AdminApp()));
    await tester.pumpAndSettle();
    expect(find.text('Reviews'), findsNothing);
  });
}
