import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orleu_mobile/app.dart';
import 'package:orleu_mobile/core/api/token_store.dart';

import 'support/fake_api.dart';

const goodToken = 'abcdefghijklmnopqrstuvwxyz123456';

Future<void> pump(WidgetTester tester, FakeAdapter a, MemoryTokenStore s) async {
  setPhone(tester, 390, 1000);
  await tester.pumpWidget(ProviderScope(overrides: overridesFor(a, s), child: const OrleuApp()));
  await tester.pumpAndSettle();
}

void main() {
  group('forgot password', () {
    testWidgets('request, then confirm with the code; the success text never claims an e-mail was sent', (tester) async {
      final a = FakeAdapter({
        'POST /api/v1/auth/password-reset/request': (_) => (status: 202, body: null),
        'POST /api/v1/auth/password-reset/confirm': (o) => (o.data as Map)['token'] == goodToken ? (status: 204, body: null) : err(400, 'INVALID_RESET_TOKEN'),
      });
      await pump(tester, a, MemoryTokenStore());
      await tester.tap(find.byKey(const Key('forgot')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Request reset code'));
      await tester.pump();
      expect(find.text('Enter a valid e-mail'), findsOneWidget);
      expect(a.calls, isEmpty);
      await tester.enterText(find.byType(TextField), 'a@b.kz');
      await tester.tap(find.text('Request reset code'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('resetRequested')), findsOneWidget);
      expect(find.textContaining('If an account exists'), findsOneWidget);
      expect(find.textContaining('was sent'), findsNothing);

      await tester.enterText(find.byType(TextField).at(0), 'x' * 24); // wrong code
      await tester.enterText(find.byType(TextField).at(1), 'long-enough-pass');
      await tester.tap(find.text('Set new password'));
      await tester.pumpAndSettle();
      expect(find.text('This reset code is invalid or has expired'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(0), goodToken);
      await tester.tap(find.text('Set new password'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('resetDone')), findsOneWidget);
    });

    testWidgets('a short new password is rejected before the server is called', (tester) async {
      final a = FakeAdapter({'POST /api/v1/auth/password-reset/request': (_) => (status: 202, body: null)});
      await pump(tester, a, MemoryTokenStore());
      await tester.tap(find.byKey(const Key('forgot')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'a@b.kz');
      await tester.tap(find.text('Request reset code'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), goodToken);
      await tester.enterText(find.byType(TextField).at(1), 'short');
      await tester.tap(find.text('Set new password'));
      await tester.pump();
      expect(a.calls.where((c) => c.path.endsWith('/confirm')), isEmpty);
    });
  });

  group('account & sessions', () {
    var sessions = <Map<String, Object?>>[];
    Map<String, Handler> routes({Handler? change}) => {
          ...businessRoutes(),
          'GET /api/v1/auth/sessions': (_) => ok(sessions),
          'POST /api/v1/auth/change-password': change ?? (_) => ok({...tokenJson, 'accessToken': 'access-2', 'refreshToken': 'refresh-2'}),
          'DELETE /api/v1/auth/sessions/s2': (_) { sessions = sessions.where((s) => s['id'] != 's2').toList(); return (status: 204, body: null); },
          'POST /api/v1/auth/logout-all': (_) => (status: 204, body: null),
        };

    Future<(FakeAdapter, MemoryTokenStore)> open(WidgetTester tester, {Handler? change}) async {
      sessions = [
        {'id': 's1', 'userAgent': 'Orleu Android', 'createdAt': '2026-11-01T05:00:00Z', 'expiresAt': '2026-12-01T05:00:00Z'},
        {'id': 's2', 'userAgent': null, 'createdAt': '2026-10-01T05:00:00Z', 'expiresAt': '2026-12-01T05:00:00Z'},
      ];
      final a = FakeAdapter(routes(change: change));
      final s = MemoryTokenStore()..access = 'access-1'..refresh = 'refresh-1';
      await pump(tester, a, s);
      await tester.tap(find.text('More').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Account & security'));
      await tester.pumpAndSettle();
      return (a, s);
    }

    testWidgets('changing the password stores the fresh tokens the server returns', (tester) async {
      final (a, s) = await open(tester);
      await tester.enterText(find.byKey(const Key('current')), 'old-password-1');
      await tester.enterText(find.byKey(const Key('next')), 'brand-new-password');
      await tester.enterText(find.byKey(const Key('repeat')), 'brand-new-password');
      await tester.tap(find.byKey(const Key('change')));
      await tester.pumpAndSettle();
      expect(s.access, 'access-2');
      expect(s.refresh, 'refresh-2');
      final call = a.calls.firstWhere((c) => c.path.endsWith('/change-password'));
      expect(call.data, {'currentPassword': 'old-password-1', 'newPassword': 'brand-new-password'});
    });

    testWidgets('mismatch and wrong current password are explained inline without losing the session', (tester) async {
      final (a, s) = await open(tester, change: (_) => err(400, 'WRONG_PASSWORD'));
      await tester.enterText(find.byKey(const Key('current')), 'old-password-1');
      await tester.enterText(find.byKey(const Key('next')), 'brand-new-password');
      await tester.enterText(find.byKey(const Key('repeat')), 'different-password');
      await tester.tap(find.byKey(const Key('change')));
      await tester.pump();
      expect(find.text('Passwords do not match'), findsOneWidget);
      expect(a.calls.where((c) => c.path.endsWith('/change-password')), isEmpty);
      await tester.enterText(find.byKey(const Key('repeat')), 'brand-new-password');
      await tester.tap(find.byKey(const Key('change')));
      await tester.pumpAndSettle();
      expect(find.text('The current password is incorrect'), findsOneWidget);
      expect(s.access, 'access-1');
    });

    testWidgets('sessions are listed and one can be revoked', (tester) async {
      final (a, _) = await open(tester);
      await tester.drag(find.byType(ListView).first, const Offset(0, -900)); // the sessions list is below the password form and the MFA card
      await tester.pumpAndSettle();
      expect(find.text('Orleu Android'), findsOneWidget);
      expect(find.text('Unknown device'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('revoke-s2')));
      await tester.tap(find.byKey(const Key('revoke-s2')));
      await tester.pumpAndSettle();
      expect(a.calls.any((c) => c.method == 'DELETE' && c.path.endsWith('/sessions/s2')), isTrue);
      expect(find.text('Unknown device'), findsNothing);
    });

    testWidgets('sign out everywhere ends the local session', (tester) async {
      final (_, s) = await open(tester);
      await tester.scrollUntilVisible(find.byKey(const Key('logout-all')), 300, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('logout-all')));
      await tester.pumpAndSettle();
      expect(s.refresh, isNull);
      expect(find.text('Your Business. Your Growth.'), findsOneWidget);
    });
  });
}
