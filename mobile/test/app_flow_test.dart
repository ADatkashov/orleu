import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orleu_mobile/app.dart';
import 'package:orleu_mobile/core/api/api_client.dart';
import 'package:orleu_mobile/core/api/token_store.dart';
import 'package:orleu_mobile/core/data/models.dart';

import 'support/fake_api.dart';

Future<void> pumpApp(WidgetTester tester, FakeAdapter adapter, MemoryTokenStore store) async {
  await tester.binding.setSurfaceSize(const Size(420, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(ProviderScope(overrides: overridesFor(adapter, store), child: const OrleuApp()));
  await tester.pumpAndSettle();
}

final booking = {
  'id': 'k1', 'branchId': 'br', 'serviceId': 's', 'serviceName': 'Haircut', 'employeeId': 'e', 'employeeName': 'Master Dana',
  'customerId': 'c', 'customerName': 'Aigerim', 'customerPhone': '+77011234567',
  'startsAt': DateTime.now().add(const Duration(hours: 1)).toUtc().toIso8601String(),
  'endsAt': DateTime.now().add(const Duration(hours: 2)).toUtc().toIso8601String(),
  'status': 'PENDING', 'currency': 'KZT', 'notes': null, 'holdExpiresAt': null,
  'financials': {'price': 20000, 'depositAmount': 6000, 'paid': 0, 'refunded': 0, 'netPaid': 0, 'remaining': 20000, 'paymentStatus': 'UNPAID'},
};

void main() {
  testWidgets('signed-out user lands on the login screen with brand tagline', (tester) async {
    await pumpApp(tester, FakeAdapter({}), MemoryTokenStore());
    expect(find.text('Your Business. Your Growth.'), findsOneWidget);
    expect(find.text('Sign in'), findsWidgets);
  });

  testWidgets('login form validates before calling the server', (tester) async {
    final adapter = FakeAdapter({});
    await pumpApp(tester, adapter, MemoryTokenStore());
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();
    expect(find.text('Enter a valid e-mail'), findsOneWidget);
    expect(find.text('Required'), findsOneWidget);
    expect(adapter.calls, isEmpty);
  });

  testWidgets('wrong password shows a localized message, not the raw server text', (tester) async {
    final adapter = FakeAdapter({'POST /api/v1/auth/login': (_) => err(401, 'INVALID_CREDENTIALS')});
    await pumpApp(tester, adapter, MemoryTokenStore());
    await tester.enterText(find.byType(TextFormField).at(0), 'a@b.kz');
    await tester.enterText(find.byType(TextFormField).at(1), 'wrong-password');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Wrong e-mail or password'), findsOneWidget);
    expect(find.text('srv'), findsNothing);
  });

  testWidgets('register enforces the 10 character password rule', (tester) async {
    await pumpApp(tester, FakeAdapter({}), MemoryTokenStore());
    await tester.tap(find.text('No account yet? Create one'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Aigerim');
    await tester.enterText(find.byType(TextFormField).at(1), 'a@b.kz');
    await tester.enterText(find.byType(TextFormField).at(2), 'short');
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pump();
    expect(find.text('At least 10 characters'), findsOneWidget);
  });

  testWidgets('successful login opens the dashboard with data from the API', (tester) async {
    final adapter = FakeAdapter({...businessRoutes(bookings: [booking]), 'POST /api/v1/auth/login': (_) => ok(tokenJson)});
    final store = MemoryTokenStore();
    await pumpApp(tester, adapter, store);
    await tester.enterText(find.byType(TextFormField).at(0), 'a@b.kz');
    await tester.enterText(find.byType(TextFormField).at(1), 'correct-horse-battery');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(store.refresh, 'refresh-1'); // tokens persisted
    expect(find.text('Studio Almaty'), findsOneWidget);
    expect(find.text('Hello, Aigerim'), findsOneWidget);
    expect(find.textContaining('Haircut'), findsWidgets);
    expect(find.textContaining('Master Dana'), findsWidgets);
    // five navigation destinations
    for (final label in ['Home', 'Calendar', 'Customers', 'Finance', 'More']) {
      expect(find.text(label), findsWidgets, reason: label);
    }
  });

  testWidgets('user without a business is sent to onboarding', (tester) async {
    final routes = {...businessRoutes(), 'GET /api/v1/businesses': (_) => ok([])};
    final store = MemoryTokenStore()..access = 'a'..refresh = 'r';
    await pumpApp(tester, FakeAdapter(routes), store);
    expect(find.text('Set up your business'), findsOneWidget);
  });

  testWidgets('opening a booking lets staff change status through the API', (tester) async {
    final adapter = FakeAdapter({...businessRoutes(bookings: [booking]),
      'POST /api/v1/businesses/b1/bookings/k1/transition': (o) => ok({...booking, 'status': (o.data as Map)['status']})});
    final store = MemoryTokenStore()..access = 'a'..refresh = 'r';
    await pumpApp(tester, adapter, store);
    await tester.tap(find.text('Calendar').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Haircut').first);
    await tester.pumpAndSettle();
    expect(find.text('Unpaid'), findsOneWidget);   // payment status from the backend, not computed in the UI
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await tester.pumpAndSettle();
    final call = adapter.calls.where((c) => c.path.endsWith('/transition')).single;
    expect(call.data, {'status': 'CONFIRMED'});
  });

  testWidgets('language switch changes the UI language and persists the choice in state', (tester) async {
    final store = MemoryTokenStore()..access = 'a'..refresh = 'r';
    await pumpApp(tester, FakeAdapter(businessRoutes()), store);
    await tester.tap(find.text('More').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Русский'));
    await tester.pumpAndSettle();
    expect(find.text('Язык'), findsOneWidget);
    await tester.tap(find.text('Қазақша'));
    await tester.pumpAndSettle();
    expect(find.text('Тіл'), findsOneWidget);
  });

  testWidgets('logout returns to the login screen and clears tokens', (tester) async {
    final adapter = FakeAdapter({...businessRoutes(), 'POST /api/v1/auth/logout': (_) => (status: 204, body: null)});
    final store = MemoryTokenStore()..access = 'a'..refresh = 'r';
    await pumpApp(tester, adapter, store);
    await tester.tap(find.text('More').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsWidgets);
    expect(store.refresh, isNull);
  });

  group('ApiClient', () {
    test('refreshes the access token once on 401 and retries the request', () async {
      final store = MemoryTokenStore()..access = 'old'..refresh = 'r1';
      var meCalls = 0;
      final adapter = FakeAdapter({
        'GET /api/v1/me': (o) {
          meCalls++;
          return o.headers['Authorization'] == 'Bearer access-1' ? ok({'ok': true}) : err(401, 'UNAUTHENTICATED');
        },
        'POST /api/v1/auth/refresh': (_) => ok(tokenJson),
      });
      final api = ApiClient(store, adapter: adapter, baseUrl: 'http://test');
      final r = await api.run((d) => d.get('/api/v1/me'));
      expect(r.data['ok'], true);
      expect(meCalls, 2);
      expect(store.access, 'access-1');
      expect(store.refresh, 'refresh-1');
    });

    test('concurrent 401s trigger a single refresh', () async {
      final store = MemoryTokenStore()..access = 'old'..refresh = 'r1';
      final adapter = FakeAdapter({
        'GET /x': (o) => o.headers['Authorization'] == 'Bearer access-1' ? ok({}) : err(401, 'UNAUTHENTICATED'),
        'POST /api/v1/auth/refresh': (_) => ok(tokenJson),
      });
      final api = ApiClient(store, adapter: adapter, baseUrl: 'http://test');
      await Future.wait([api.run((d) => d.get('/x')), api.run((d) => d.get('/x')), api.run((d) => d.get('/x'))]);
      expect(adapter.calls.where((c) => c.path == '/api/v1/auth/refresh').length, 1);
    });

    test('failed refresh clears tokens and reports session expiry', () async {
      final store = MemoryTokenStore()..access = 'old'..refresh = 'r1';
      var expired = false;
      final adapter = FakeAdapter({'GET /x': (_) => err(401, 'UNAUTHENTICATED'), 'POST /api/v1/auth/refresh': (_) => err(401, 'INVALID_REFRESH_TOKEN')});
      final api = ApiClient(store, adapter: adapter, baseUrl: 'http://test', onSessionExpired: () => expired = true);
      await expectLater(api.run((d) => d.get('/x')), throwsA(isA<ApiError>()));
      expect(expired, true);
      expect(store.refresh, isNull);
    });

    test('ApiError exposes backend code and maps transport failures to network', () {
      final e = ApiError.from(DioException(requestOptions: RequestOptions(path: '/x'),
          response: Response(requestOptions: RequestOptions(path: '/x'), statusCode: 409, data: {'code': 'SLOT_UNAVAILABLE', 'message': 'm'})));
      expect(e.code, 'SLOT_UNAVAILABLE');
      expect(ApiError.from(DioException(requestOptions: RequestOptions(path: '/x'))).isNetwork, true);
    });
  });

  test('booking actions mirror the backend state machine', () {
    Booking b(String s) => Booking.fromJson({...booking, 'status': s});
    expect(b('PENDING').nextActions, ['CONFIRMED', 'CANCELLED']);
    expect(b('AWAITING_PAYMENT').nextActions, ['CANCELLED']); // confirmation only via payment
    expect(b('COMPLETED').nextActions, isEmpty);
    expect(b('CANCELLED').nextActions, isEmpty);
  });
}
