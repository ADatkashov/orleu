import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orleu_mobile/admin/admin_app.dart';
import 'package:orleu_mobile/app.dart';
import 'package:orleu_mobile/core/api/api_client.dart';
import 'package:orleu_mobile/core/api/token_store.dart';

import 'support/fake_api.dart';

Map<String, Handler> loginRoutes({String right = '123456', bool expired = false}) => {
      ...businessRoutes(),
      'POST /api/v1/auth/login': (_) => ok({'mfaRequired': true, 'mfaToken': 'challenge-1'}),
      'POST /api/v1/auth/mfa/verify': (o) {
        if (expired) return err(401, 'INVALID_MFA_CHALLENGE');
        final d = o.data as Map;
        return d['mfaToken'] == 'challenge-1' && d['code'] == right ? ok(tokenJson) : err(401, 'INVALID_MFA_CODE');
      },
    };

Future<void> pump(WidgetTester tester, Widget app, FakeAdapter a, MemoryTokenStore s) async {
  setPhone(tester, 420, 1000);
  await tester.pumpWidget(ProviderScope(retry: appRetry, overrides: overridesFor(a, s), child: app));
  await tester.pumpAndSettle();
}

Future<void> signIn(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField).at(0), 'a@b.kz');
  await tester.enterText(find.byType(TextFormField).at(1), 'correct-horse-battery');
  await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
  await tester.pumpAndSettle();
}

void main() {
  group('sign-in with a second factor', () {
    testWidgets('the code step appears after the password, a wrong code is explained, the right one signs in', (tester) async {
      final store = MemoryTokenStore();
      final a = FakeAdapter(loginRoutes());
      await pump(tester, const OrleuApp(), a, store);
      await signIn(tester);
      expect(find.byKey(const Key('mfaPrompt')), findsOneWidget);
      expect(store.access, isNull, reason: 'no tokens before the second factor');
      await tester.enterText(find.byKey(const Key('mfaCode')), '000000');
      await tester.tap(find.byKey(const Key('mfaVerify')));
      await tester.pumpAndSettle();
      expect(find.text('The code is not correct'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('mfaCode')), '123456');
      await tester.tap(find.byKey(const Key('mfaVerify')));
      await tester.pumpAndSettle();
      expect(store.access, 'access-1');
      expect(find.byKey(const Key('mfaPrompt')), findsNothing);
    });

    testWidgets('an expired challenge sends the user back to the password step', (tester) async {
      final a = FakeAdapter(loginRoutes(expired: true));
      await pump(tester, const OrleuApp(), a, MemoryTokenStore());
      await signIn(tester);
      await tester.enterText(find.byKey(const Key('mfaCode')), '123456');
      await tester.tap(find.byKey(const Key('mfaVerify')));
      await tester.pumpAndSettle();
      expect(find.text('The sign-in attempt expired. Please sign in again.'), findsOneWidget);
      expect(find.byKey(const Key('mfaPrompt')), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
    });

    testWidgets('the admin console asks for the code too', (tester) async {
      final store = MemoryTokenStore();
      final a = FakeAdapter({
        ...loginRoutes(),
        'GET /api/v1/admin/me': (_) => ok({'role': 'SUPER_ADMIN', 'canModify': true}),
        'GET /api/v1/admin/businesses': (_) => ok({'items': [], 'page': 0, 'size': 20}),
      });
      await pump(tester, const AdminApp(), a, store);
      await tester.enterText(find.byKey(const Key('adminEmail')), 'root@example.com');
      await tester.enterText(find.byKey(const Key('adminPassword')), 'correct-horse-battery');
      await tester.tap(find.byKey(const Key('adminSignIn')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('adminMfaPrompt')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('adminMfaCode')), '123456');
      await tester.tap(find.byKey(const Key('adminMfaVerify')));
      await tester.pumpAndSettle();
      expect(store.access, 'access-1');
    });
  });

  group('enrolment', () {
    var enabled = false;
    var left = 10;
    Map<String, Handler> routes({String? enableError}) => {
          ...businessRoutes(),
          'GET /api/v1/auth/sessions': (_) => ok([]),
          'GET /api/v1/auth/mfa': (_) => ok({'enabled': enabled, 'recoveryCodesLeft': enabled ? left : 0}),
          'POST /api/v1/auth/mfa/setup': (_) => ok({'secret': 'JBSWY3DPEHPK3PXP', 'otpauthUri': 'otpauth://totp/ORLEU:a@b.kz?secret=JBSWY3DPEHPK3PXP'}),
          'POST /api/v1/auth/mfa/enable': (o) {
            if ((o.data as Map)['code'] != '654321') return err(400, 'INVALID_MFA_CODE');
            enabled = true;
            return ok({'recoveryCodes': ['abcde-fghjk', 'mnpqr-stuvw']});
          },
          'POST /api/v1/auth/mfa/disable': (o) {
            final d = o.data as Map;
            if (d['password'] != 'right-password') return err(400, 'WRONG_PASSWORD');
            enabled = false;
            return (status: 204, body: null);
          },
        };

    Future<FakeAdapter> openAccount(WidgetTester tester, {bool startEnabled = false}) async {
      enabled = startEnabled;
      left = 10;
      final a = FakeAdapter(routes());
      final store = MemoryTokenStore()..access = 'a'..refresh = 'r';
      await pump(tester, const OrleuApp(), a, store);
      await tester.tap(find.text('More').last);
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).first, const Offset(0, -300));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Account & security'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).first, const Offset(0, -500));
      await tester.pumpAndSettle();
      return a;
    }

    testWidgets('enable: setup key, a wrong code stays inline, the right code shows one-time recovery codes', (tester) async {
      await openAccount(tester);
      expect(find.text('Off'), findsOneWidget);
      await tester.tap(find.byKey(const Key('mfaEnable')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('setupKey')), findsOneWidget);
      expect(find.text('JBSWY3DPEHPK3PXP'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('enableCode')), '111111');
      await tester.tap(find.byKey(const Key('mfaConfirm')));
      await tester.pumpAndSettle();
      expect(find.text('The code is not correct'), findsOneWidget);
      expect(find.byKey(const Key('setupKey')), findsOneWidget, reason: 'the user can retry with the same key');
      await tester.enterText(find.byKey(const Key('enableCode')), '654321');
      await tester.tap(find.byKey(const Key('mfaConfirm')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('recoveryCodes')), findsOneWidget);
      expect(find.textContaining('abcde-fghjk'), findsOneWidget);
      await tester.tap(find.byKey(const Key('recoverySaved')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('recoveryCodes')), findsNothing, reason: 'recovery codes are shown only once');
      expect(find.text('On · 10 recovery codes left'), findsOneWidget);
    });

    testWidgets('disable needs the password; a wrong one is explained inside the dialog, the right one turns MFA off', (tester) async {
      final a = await openAccount(tester, startEnabled: true);
      expect(find.text('On · 10 recovery codes left'), findsOneWidget);
      await tester.tap(find.byKey(const Key('mfaDisable')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('disablePassword')), 'wrong');
      await tester.enterText(find.byKey(const Key('disableCode')), '123456');
      await tester.tap(find.byKey(const Key('confirmDisable')));
      await tester.pumpAndSettle();
      expect(find.text('The current password is incorrect'), findsOneWidget);
      expect(enabled, isTrue);
      await tester.enterText(find.byKey(const Key('disablePassword')), 'right-password');
      await tester.tap(find.byKey(const Key('confirmDisable')));
      await tester.pumpAndSettle();
      expect(enabled, isFalse);
      expect(find.text('Off'), findsOneWidget);
      final call = a.calls.lastWhere((c) => c.path.endsWith('/mfa/disable'));
      expect(call.data, {'password': 'right-password', 'code': '123456'});
    });
  });
}
