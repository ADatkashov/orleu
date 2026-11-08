// Developer tool, not a regression test: renders the main screens with realistic fake data (real Inter font,
// real icons) to PNG files so the visual design can be reviewed without a device.
//   ORLEU_SHOT_DIR=/some/dir flutter test test/tool/screenshots_test.dart
// Without the variable every test here is skipped.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orleu_mobile/admin/admin_app.dart';
import 'package:orleu_mobile/app.dart';
import 'package:orleu_mobile/core/api/token_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_api.dart';

final _dir = Platform.environment['ORLEU_SHOT_DIR'];

String _iso(int h, int m) {
  final n = DateTime.now().toUtc();
  return DateTime.utc(n.year, n.month, n.day, h, m).toIso8601String();
}

Map<String, Object?> _b(String id, String svc, String emp, String cust, int h, int m, int mins, String status, {double paid = 0, double price = 15000}) => {
  'id': id,
  'branchId': 'br',
  'serviceId': 's',
  'serviceName': svc,
  'employeeId': 'e',
  'employeeName': emp,
  'customerId': 'c$id',
  'customerName': cust,
  'customerPhone': '+77011234567',
  'startsAt': _iso(h, m),
  'endsAt': _iso(h + (m + mins) ~/ 60, (m + mins) % 60),
  'status': status,
  'currency': 'KZT',
  'notes': null,
  'holdExpiresAt': null,
  'financials': {
    'price': price,
    'depositAmount': 4500,
    'paid': paid,
    'refunded': 0,
    'netPaid': paid,
    'remaining': price - paid,
    'paymentStatus': paid > 0 ? 'PARTIAL' : 'UNPAID',
  },
};

Map<String, Handler> _routes() {
  final now = DateTime.now().toUtc();
  final bookings = [
    _b('1', 'Hair styling', 'Aigerim', 'Amina Sadykova', 23, 0, 45, 'CONFIRMED', paid: 15000),
    _b('2', 'Manicure', 'Dana', 'Madina Kenzhebek', 23, 30, 60, 'PENDING'),
    _b('3', 'Consultation', 'Aigerim', 'Daniyar Tulegenov', 23, 50, 30, 'CONFIRMED', paid: 4500),
    _b('4', 'Coloring', 'Dana', 'Aliya Nurlan', 23, 55, 90, 'IN_PROGRESS', paid: 8000, price: 32000),
    _b('5', 'Haircut', 'Aigerim', 'Saule Bekova', 23, 58, 45, 'CANCELLED'),
  ];
  return {
    ...businessRoutes(bookings: bookings),
    'GET /api/v1/businesses/b1/analytics/summary': (_) => ok({
      'totalBookings': 12,
      'bookedValue': 184500,
      'collected': 184500,
      'refunded': 0,
      'netCollected': 184500,
      'outstanding': 42000,
      'cancellationRate': 0.083,
      'noShowRate': 0.041,
    }),
    'GET /api/v1/businesses/b1/analytics/timeseries': (_) => ok([
      for (var i = 6; i >= 0; i--)
        {
          'date': now.subtract(Duration(days: i)).toIso8601String().substring(0, 10),
          'bookings': 3 + (i * 7) % 5,
          'netCollected': 90000.0 + ((i * 53) % 7) * 31000,
        },
    ]),
    'GET /api/v1/businesses/b1/customers': (_) => ok({
      'items': [
        for (final (i, n) in ['Amina Sadykova', 'Madina Kenzhebek', 'Daniyar Tulegenov', 'Aliya Nurlan', 'Saule Bekova', 'Ерлан Қасымов'].indexed)
          {
            'id': 'c$i',
            'fullName': n,
            'phone': '+7701123456$i',
            'email': null,
            'blocked': i == 4,
            'tags': i < 2 ? ['VIP', 'regular'] : <String>[],
          },
      ],
      'page': 0,
      'size': 50,
      'total': 6,
    }),
    'GET /api/v1/businesses/b1/customers/tags': (_) => ok([
      {'tag': 'VIP', 'customers': 2},
      {'tag': 'regular', 'customers': 2},
    ]),
    'GET /api/v1/businesses/b1/services': (_) => ok([
      {'id': 's1', 'name': 'Haircut', 'durationMinutes': 45, 'bufferMinutes': 0, 'price': 8000, 'depositPercent': null, 'active': true},
      {'id': 's2', 'name': 'Coloring', 'durationMinutes': 90, 'bufferMinutes': 10, 'price': 32000, 'depositPercent': 30, 'active': true},
      {'id': 's3', 'name': 'Manicure', 'durationMinutes': 60, 'bufferMinutes': 0, 'price': 12000, 'depositPercent': null, 'active': false},
    ]),
    'GET /api/v1/businesses/b1/employees': (_) => ok([
      {
        'id': 'e1',
        'displayName': 'Aigerim Sadykova',
        'active': true,
        'branchIds': ['br'],
        'serviceIds': ['s1', 's2'],
      },
      {
        'id': 'e2',
        'displayName': 'Dana Omarova',
        'active': true,
        'branchIds': ['br'],
        'serviceIds': ['s1'],
      },
    ]),
    'GET /api/v1/businesses/b1/branches': (_) => ok([
      {
        'id': 'br',
        'name': 'Main',
        'address': 'Abay 10, Almaty',
        'active': true,
        'hours': [
          for (var d = 1; d <= 6; d++) {'dayOfWeek': d, 'open': '09:00:00', 'close': '20:00:00'},
        ],
      },
    ]),
    'GET /api/v1/businesses/b1/notifications': (_) => ok([
      {
        'id': 'n1',
        'eventType': 'BOOKING_CREATED',
        'bookingId': '2',
        'customerName': 'Madina Kenzhebek',
        'serviceName': 'Manicure',
        'createdAt': now.subtract(const Duration(minutes: 12)).toIso8601String(),
        'startsAtInstant': _iso(23, 30),
        'read': false,
      },
      {
        'id': 'n2',
        'eventType': 'PAYMENT_RECEIVED',
        'bookingId': '1',
        'customerName': 'Amina Sadykova',
        'serviceName': 'Hair styling',
        'createdAt': now.subtract(const Duration(hours: 3)).toIso8601String(),
        'startsAtInstant': _iso(23, 0),
        'read': false,
      },
      {
        'id': 'n3',
        'eventType': 'BOOKING_CANCELLED',
        'bookingId': '5',
        'customerName': 'Saule Bekova',
        'serviceName': 'Haircut',
        'createdAt': now.subtract(const Duration(days: 1)).toIso8601String(),
        'startsAtInstant': _iso(23, 58),
        'read': true,
      },
    ]),
  };
}

Future<void> _shot(WidgetTester tester, GlobalKey key, String name) async {
  await tester.pump(const Duration(milliseconds: 600));
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  await tester.runAsync(() async {
    final img = await boundary.toImage(pixelRatio: 2);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    await Directory(_dir!).create(recursive: true);
    await File('$_dir/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
  });
}

Future<GlobalKey> _boot(WidgetTester tester, {required double w, required double h, bool dark = false, Locale? locale}) async {
  SharedPreferences.setMockInitialValues({'theme': dark ? 'dark' : 'light', if (locale != null) 'locale': locale.languageCode});
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(w, h);
  addTearDown(tester.view.reset);
  final key = GlobalKey();
  final store = MemoryTokenStore()
    ..access = 'a'
    ..refresh = 'r';
  await tester.pumpWidget(
    RepaintBoundary(
      key: key,
      child: ProviderScope(overrides: overridesFor(FakeAdapter(_routes()), store), child: const OrleuApp()),
    ),
  );
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 300));
  return key;
}

Future<void> _open(WidgetTester tester, GlobalKey key, String text, String name) async {
  await tester.scrollUntilVisible(find.text(text), 200, scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(text).first);
  await tester.pumpAndSettle();
  await _shot(tester, key, name);
  await tester.pageBack();
  await tester.pumpAndSettle();
}

Future<void> _tab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

/// flutter_test renders every glyph as a block unless fonts are loaded by hand.
Future<void> _loadFonts() async {
  final inter = FontLoader('Inter');
  for (final w in [400, 500, 600, 700, 800]) {
    inter.addFont(File('assets/fonts/Inter-$w.ttf').readAsBytes().then((b) => ByteData.view(b.buffer)));
  }
  await inter.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(
      File('${Platform.environment['FLUTTER_ROOT'] ?? '/opt/sdk/flutter'}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf')
          .readAsBytes()
          .then((b) => ByteData.view(b.buffer)),
    );
  await icons.load();
}

void main() {
  setUpAll(() async {
    if (_dir != null) await _loadFonts();
  });
  final skip = _dir == null; // set ORLEU_SHOT_DIR to render screenshots

  for (final dark in [false, true]) {
    final m = dark ? 'dark' : 'light';
    testWidgets('phone $m', skip: skip, (tester) async {
      final key = await _boot(tester, w: 390, h: 844, dark: dark);
      await _shot(tester, key, 'home-$m');
      await _tab(tester, 'Calendar');
      await _shot(tester, key, 'calendar-$m');
      await _tab(tester, 'Customers');
      await _shot(tester, key, 'customers-$m');
      await _tab(tester, 'Finance');
      await _shot(tester, key, 'finance-$m');
      await _tab(tester, 'More');
      await _shot(tester, key, 'more-$m');
    });
  }

  testWidgets('phone detail screens', skip: skip, (tester) async {
    final key = await _boot(tester, w: 390, h: 844);
    await tester.tap(find.byKey(const Key('bell')));
    await tester.pumpAndSettle();
    await _shot(tester, key, 'notifications-light');
  });

  for (final dark in [false, true]) {
    final m = dark ? 'dark' : 'light';
    testWidgets('detail screens $m', skip: skip, (tester) async {
      final key = await _boot(tester, w: 390, h: 844, dark: dark);
      await _tab(tester, 'More');
      for (final (text, name) in [
        ('Services', 'services'),
        ('Specialists', 'employees'),
        ('Locations & hours', 'branches'),
        ('Reviews', 'reviews'),
        ('Promo codes', 'promos'),
        ('Gift cards', 'giftcards'),
        ('Support', 'support'),
        ('Message log', 'messages'),
        ('Account & security', 'account'),
        ('Business setup', 'setup'),
      ]) {
        if (find.text(text).evaluate().isEmpty) continue;
        await _open(tester, key, text, '$name-$m');
      }
    });
    testWidgets('booking sheets $m', skip: skip, (tester) async {
      final key = await _boot(tester, w: 390, h: 844, dark: dark);
      await _tab(tester, 'Calendar');
      await tester.tap(find.text('Manicure'));
      await tester.pumpAndSettle();
      await _shot(tester, key, 'booking-sheet-$m');
      await tester.tapAt(const Offset(195, 40));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('newBooking')));
      await tester.pumpAndSettle();
      await _shot(tester, key, 'new-booking-$m');
    });
    testWidgets('signed out $m', skip: skip, (tester) async {
      SharedPreferences.setMockInitialValues({'theme': dark ? 'dark' : 'light'});
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: ProviderScope(overrides: overridesFor(FakeAdapter({}), MemoryTokenStore()), child: const OrleuApp()),
        ),
      );
      await tester.pumpAndSettle();
      await _shot(tester, key, 'login-$m');
      await tester.tap(find.byType(TextButton).first);
      await tester.pumpAndSettle();
      await _shot(tester, key, 'register-$m');
    });
  }

  testWidgets('admin console', skip: skip, (tester) async {
    final biz = {
      'id': 'b1',
      'slug': 'studio-almaty',
      'name': 'Studio Almaty',
      'businessType': 'BARBERSHOP',
      'planCode': 'PRO',
      'status': 'ACTIVE',
      'published': true,
      'createdAt': '2026-11-01T10:00:00Z',
    };
    final routes = <String, Handler>{
      'GET /api/v1/me': (_) => ok({'id': 'u1', 'email': 'admin@example.com', 'fullName': 'Admin', 'memberships': []}),
      'GET /api/v1/admin/me': (_) => ok({'role': 'SUPER_ADMIN', 'canModify': true}),
      'GET /api/v1/admin/businesses': (_) => ok({
        'items': [
          biz,
          {...biz, 'id': 'b2', 'name': 'Barber House', 'slug': 'barber-house', 'planCode': 'FREE', 'status': 'SUSPENDED', 'published': false},
        ],
        'page': 0,
        'size': 20,
      }),
    };
    for (final w in [1280.0, 390.0]) {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(w, 800);
      final key = GlobalKey();
      final store = MemoryTokenStore()
        ..access = 'a'
        ..refresh = 'r';
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: ProviderScope(overrides: overridesFor(FakeAdapter(routes), store), child: const AdminApp()),
        ),
      );
      await tester.pumpAndSettle();
      await _shot(tester, key, 'admin-${w.toInt()}');
    }
    addTearDown(tester.view.reset);
  });

  testWidgets('desktop and small phone', skip: skip, (tester) async {
    var key = await _boot(tester, w: 1280, h: 860);
    await _shot(tester, key, 'home-desktop');
    key = await _boot(tester, w: 768, h: 1024);
    await _shot(tester, key, 'home-tablet');
    key = await _boot(tester, w: 320, h: 640, locale: const Locale('kk'));
    await _shot(tester, key, 'home-320-kk');
  });
}
