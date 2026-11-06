import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/api/api_client.dart';
import 'core/api/token_store.dart';
import 'core/data/auth_controller.dart';

/// DEMO entry point: the real app and the real ApiClient, but every HTTP call is answered from memory
/// by [DemoAdapter] (no backend, no network). Run: `flutter run -t lib/demo_main.dart`.
/// Nothing here is real business data.
void main() {
  final store = MemoryTokenStore()..access = 'demo-access'..refresh = 'demo-refresh';
  runApp(ProviderScope(
    retry: appRetry,
    overrides: [
      tokenStoreProvider.overrideWithValue(store),
      apiClientProvider.overrideWith((ref) => ApiClient(store,
          adapter: DemoAdapter(), baseUrl: 'http://demo', onSessionExpired: () => ref.read(authControllerProvider.notifier).sessionExpired())),
    ],
    child: const OrleuApp(),
  ));
}

/// Answers the REST API with deterministic fake data for a beauty studio in Almaty (UTC+5).
class DemoAdapter implements HttpClientAdapter {
  static const _tz = 'Asia/Almaty';
  static const _off = Duration(hours: 5);

  // --- catalog -------------------------------------------------------------
  static const _branches = [
    ('br1', 'Studio Dostyk', 'Dostyk Ave 120, Almaty'),
    ('br2', 'Studio Mega', 'Mega Center, Rozybakiev St 247А'),
  ];
  static const _services = [
    ('sv1', 'Women\'s haircut', 60, 12000.0),
    ('sv2', 'Manicure + gel polish', 90, 9000.0),
    ('sv3', 'Hair colouring', 150, 28000.0),
    ('sv4', 'Facial cleansing', 75, 15000.0),
    ('sv5', 'Men\'s haircut', 45, 7000.0),
  ];
  static const _staff = [
    ('em1', 'Aigerim S.'),
    ('em2', 'Dana K.'),
    ('em3', 'Madina T.'),
    ('em4', 'Arman B.'),
  ];
  static const _clients = [
    ('cu1', 'Aliya Nurgaliyeva', '+77011234567'),
    ('cu2', 'Dinara Omarova', '+77075557812'),
    ('cu3', 'Zhanna Kenzhebayeva', '+77472218890'),
    ('cu4', 'Kamila Sarsenova', '+77019001122'),
    ('cu5', 'Ruslan Abdrakhmanov', '+77783456701'),
    ('cu6', 'Saltanat Bekova', '+77052349911'),
    ('cu7', 'Mira Tleuova', '+77013332211'),
    ('cu8', 'Yerlan Mukhamedov', '+77771239876'),
  ];

  // (service idx, employee idx, client idx, hour-in-local-day offset in minutes, status, paid)
  // days: relative to today in Almaty.
  late final List<Map<String, Object?>> _bookings = _buildBookings();

  DateTime get _nowWall => DateTime.now().toUtc().add(_off);
  DateTime _wallToUtc(DateTime wall) => DateTime.utc(wall.year, wall.month, wall.day, wall.hour, wall.minute).subtract(_off);

  List<Map<String, Object?>> _buildBookings() {
    final today = DateTime(_nowWall.year, _nowWall.month, _nowWall.day);
    final out = <Map<String, Object?>>[];
    var n = 0;
    void add(int dayOffset, int h, int m, int sv, int em, int cu, String status, double paid) {
      final svc = _services[sv];
      final start = _wallToUtc(today.add(Duration(days: dayOffset, hours: h, minutes: m)));
      final end = start.add(Duration(minutes: svc.$3));
      final price = svc.$4;
      final deposit = price * 0.3;
      out.add({
        'id': 'bk${++n}', 'branchId': _branches[em % 2].$1, 'serviceId': svc.$1, 'employeeId': _staff[em].$1,
        'serviceName': svc.$2, 'employeeName': _staff[em].$2, 'customerName': _clients[cu].$2, 'customerPhone': _clients[cu].$3,
        'status': status, 'currency': 'KZT', 'startsAt': start.toIso8601String(), 'endsAt': end.toIso8601String(),
        'financials': {
          'price': price, 'depositAmount': deposit, 'netPaid': paid, 'remaining': price - paid,
          'paymentStatus': paid >= price ? 'PAID' : paid >= deposit ? 'DEPOSIT_PAID' : 'UNPAID',
        },
      });
    }

    // today
    add(0, 9, 0, 0, 0, 0, 'COMPLETED', 12000);
    add(0, 10, 30, 1, 1, 1, 'COMPLETED', 9000);
    add(0, 12, 0, 2, 2, 2, 'IN_PROGRESS', 8400);
    add(0, 14, 0, 3, 1, 3, 'CONFIRMED', 4500);
    add(0, 15, 30, 4, 3, 4, 'CONFIRMED', 2100);
    add(0, 16, 30, 0, 0, 5, 'PENDING', 0);
    add(0, 18, 0, 1, 1, 6, 'AWAITING_PAYMENT', 0);
    // tomorrow & later this week
    add(1, 10, 0, 2, 2, 0, 'CONFIRMED', 8400);
    add(1, 13, 0, 0, 0, 7, 'CONFIRMED', 3600);
    add(1, 15, 0, 3, 1, 1, 'PENDING', 0);
    add(2, 11, 0, 4, 3, 4, 'CONFIRMED', 2100);
    add(2, 16, 0, 1, 1, 2, 'CONFIRMED', 2700);
    add(3, 12, 0, 2, 2, 5, 'CONFIRMED', 8400);
    add(4, 10, 30, 0, 0, 3, 'CONFIRMED', 3600);
    add(5, 14, 0, 3, 1, 6, 'PENDING', 0);
    // past
    add(-1, 11, 0, 0, 0, 1, 'COMPLETED', 12000);
    add(-1, 14, 0, 1, 1, 0, 'COMPLETED', 9000);
    add(-1, 17, 0, 4, 3, 7, 'NO_SHOW', 0);
    add(-2, 10, 0, 2, 2, 3, 'COMPLETED', 28000);
    add(-3, 13, 0, 3, 1, 4, 'CANCELLED', 0);
    add(-5, 12, 0, 0, 0, 0, 'COMPLETED', 12000);
    return out;
  }

  Map<String, Object?> _summary(Map<String, dynamic> q) {
    final from = DateTime.parse(q['from'] as String).toUtc(), to = DateTime.parse(q['to'] as String).toUtc();
    final inRange = _bookings.where((b) {
      final s = DateTime.parse(b['startsAt'] as String);
      return !s.isBefore(from) && s.isBefore(to);
    }).toList();
    final live = inRange.where((b) => !const {'CANCELLED', 'EXPIRED'}.contains(b['status']));
    double sum(double Function(Map f) f) => live.fold(0.0, (a, b) => a + f(b['financials'] as Map));
    final booked = sum((f) => (f['price'] as num).toDouble());
    final paid = sum((f) => (f['netPaid'] as num).toDouble());
    return {
      'totalBookings': inRange.length, 'bookedValue': booked, 'collected': paid, 'refunded': 0, 'netCollected': paid,
      'outstanding': booked - paid, 'cancellationRate': 0.05, 'noShowRate': 0.05,
    };
  }

  // --- HTTP ------------------------------------------------------------------
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? body, Future<void>? cancel) async {
    await Future<void>.delayed(const Duration(milliseconds: 40));
    final path = o.path.replaceFirst('/api/v1', '');
    final r = _route(o.method, path, o);
    if (r is String) {
      return ResponseBody.fromString(r, 200, headers: {Headers.contentTypeHeader: ['text/csv'], 'content-disposition': ['attachment; filename="orleu-ledger-demo.csv"']});
    }
    if (r == null) return ResponseBody.fromString(jsonEncode({'code': 'NOT_FOUND', 'message': 'demo'}), 404, headers: {Headers.contentTypeHeader: ['application/json']});
    return ResponseBody.fromString(jsonEncode(r), 200, headers: {Headers.contentTypeHeader: ['application/json']});
  }

  Object? _route(String method, String path, RequestOptions o) {
    final q = o.queryParameters;
    if (method != 'GET') {
      if (path.endsWith('/transition')) {
        final id = RegExp(r'/bookings/([^/]+)/').firstMatch(path)!.group(1);
        for (final b in _bookings) {
          if (b['id'] == id) b['status'] = (o.data as Map)['status'];
        }
      }
      return <String, Object?>{'ok': true, 'affectedBookings': 0};
    }
    switch (path) {
      case '/me':
        return {'id': 'u1', 'email': 'aigerim@studio.kz', 'fullName': 'Aigerim Sadykova', 'locale': 'en',
          'memberships': [{'businessId': 'b1', 'role': 'BUSINESS_OWNER'}]};
      case '/businesses':
        return [{'id': 'b1', 'name': 'Studio Almaty', 'slug': 'studio-almaty', 'currency': 'KZT', 'planCode': 'FREE', 'published': true,
          'timezone': _tz, 'reminderHours': 24, 'customerLocale': 'ru', 'customerRetentionMonths': 0}];
      case '/auth/sessions':
        final now = DateTime.now().toUtc();
        return [
          {'id': 's1', 'userAgent': 'Chrome 130 · Windows', 'createdAt': now.subtract(const Duration(hours: 2)).toIso8601String()},
          {'id': 's2', 'userAgent': 'ORLEU iOS 0.1 · iPhone', 'createdAt': now.subtract(const Duration(days: 3)).toIso8601String()},
        ];
      case '/auth/mfa':
        return {'enabled': false, 'recoveryCodesLeft': 0};
      case '/auth/login-history':
        final now = DateTime.now().toUtc();
        return {'failedSinceLastSuccess': 0, 'newDeviceRecently': false, 'events': [
          {'outcome': 'SUCCESS', 'ip': '95.59.12.4', 'userAgent': 'Chrome 130 · Windows', 'mfaUsed': false, 'newDevice': false, 'occurredAt': now.subtract(const Duration(hours: 2)).toIso8601String()},
          {'outcome': 'FAILED_PASSWORD', 'ip': '95.59.12.4', 'userAgent': 'Chrome 130 · Windows', 'mfaUsed': false, 'newDevice': false, 'occurredAt': now.subtract(const Duration(hours: 2, minutes: 1)).toIso8601String()},
          {'outcome': 'SUCCESS', 'ip': '178.91.3.77', 'userAgent': 'ORLEU iOS 0.1 · iPhone', 'mfaUsed': false, 'newDevice': false, 'occurredAt': now.subtract(const Duration(days: 3)).toIso8601String()},
        ]};
    }
    final m = RegExp(r'^/businesses/b1/(.+)$').firstMatch(path);
    if (m == null) return null;
    final rest = m.group(1)!;
    switch (rest) {
      case 'bookings':
        final from = DateTime.parse(q['from'] as String).toUtc(), to = DateTime.parse(q['to'] as String).toUtc();
        final emp = q['employeeId'];
        return [
          for (final b in _bookings)
            if (!DateTime.parse(b['startsAt'] as String).isBefore(from) && DateTime.parse(b['startsAt'] as String).isBefore(to) && (emp == null || b['employeeId'] == emp)) b
        ]..sort((a, b) => (a['startsAt'] as String).compareTo(b['startsAt'] as String));
      case 'analytics/summary':
        return _summary(q);
      case 'analytics/breakdown':
        return _breakdown('${q['by']}');
      case 'analytics/timeseries':
        return _timeseries(q);
      case 'analytics/peak-hours':
        return [for (var h = 0; h < 24; h++) h < 9 || h > 20 ? 0 : [3, 6, 8, 9, 7, 10, 12, 11, 9, 8, 5, 2][h - 9]];
      case 'analytics/customers':
        return {'newCustomers': 23, 'returningCustomers': 41, 'returningShare': 0.64};
      case 'subscription':
        return {'planCode': 'FREE', 'employees': 3, 'maxEmployees': 3};
      case 'customers':
        final s = '${q['q'] ?? ''}'.toLowerCase();
        return {'items': [
          for (final c in _clients)
            if (s.isEmpty || c.$2.toLowerCase().contains(s) || c.$3.contains(s)) {'id': c.$1, 'fullName': c.$2, 'phone': c.$3, 'email': null, 'blocked': false}
        ], 'page': 0, 'size': 50, 'total': _clients.length};
      case 'branches':
        return [for (final b in _branches) {'id': b.$1, 'name': b.$2, 'address': b.$3, 'active': true,
          'hours': [for (var d = 1; d <= 6; d++) {'dayOfWeek': d, 'open': '09:00:00', 'close': d == 6 ? '18:00:00' : '20:00:00'}]}];
      case 'services':
        return [for (final s in _services) {'id': s.$1, 'name': s.$2, 'durationMinutes': s.$3, 'bufferMinutes': 10, 'price': s.$4, 'depositPercent': 30, 'active': true}];
      case 'employees':
        return [for (var i = 0; i < _staff.length; i++) {'id': _staff[i].$1, 'displayName': _staff[i].$2, 'active': true,
          'branchIds': [_branches[i % 2].$1], 'serviceIds': [for (final s in _services) s.$1]}];
      case 'availability':
        final date = DateTime.parse('${q['date']}');
        return [
          for (var h = 9; h < 19; h++)
            for (final mm in const [0, 30])
              if ((h * 2 + mm ~/ 30 + date.day) % 4 != 0)
                {'start': _wallToUtc(DateTime(date.year, date.month, date.day, h, mm)).toIso8601String(), 'employeeIds': [_staff[(h + mm) % 2].$1]}
        ];
      case 'notifications':
        final now = DateTime.now().toUtc();
        return [
          {'id': 'n1', 'eventType': 'BOOKING_CREATED', 'bookingId': 'bk6', 'customerName': 'Saltanat Bekova', 'serviceName': 'Women\'s haircut', 'createdAt': now.subtract(const Duration(minutes: 8)).toIso8601String(), 'startsAt': now.add(const Duration(hours: 4)).toIso8601String(), 'read': false},
          {'id': 'n2', 'eventType': 'PAYMENT_RECORDED', 'bookingId': 'bk4', 'customerName': 'Kamila Sarsenova', 'serviceName': 'Facial cleansing', 'createdAt': now.subtract(const Duration(hours: 1)).toIso8601String(), 'read': false},
          {'id': 'n3', 'eventType': 'BOOKING_CANCELLED', 'bookingId': 'bk20', 'customerName': 'Ruslan Abdrakhmanov', 'serviceName': 'Facial cleansing', 'createdAt': now.subtract(const Duration(days: 1)).toIso8601String(), 'read': true},
        ];
      case 'notifications/customer-messages':
        final now = DateTime.now().toUtc();
        return [
          {'id': 'm1', 'messageType': 'REMINDER', 'locale': 'ru', 'recipientPhone': '+77011234567', 'body': 'Напоминаем: завтра в 10:00 вас ждёт Aigerim S. в Studio Almaty.', 'status': 'NOT_SENT', 'createdAt': now.toIso8601String()},
          {'id': 'm2', 'messageType': 'BOOKING_CONFIRMED', 'locale': 'ru', 'recipientPhone': '+77075557812', 'body': 'Запись подтверждена: Маникюр, сегодня в 14:00.', 'status': 'NOT_SENT', 'createdAt': now.subtract(const Duration(hours: 3)).toIso8601String()},
        ];
      case 'promo-codes':
        return [
          {'id': 'p1', 'code': 'WELCOME10', 'kind': 'PERCENT', 'value': 10, 'validUntil': '2026-12-31', 'maxUses': 100, 'usedCount': 14, 'active': true},
          {'id': 'p2', 'code': 'NEWYEAR', 'kind': 'FIXED', 'value': 2000, 'validUntil': '2027-01-10', 'maxUses': 50, 'usedCount': 0, 'active': true},
          {'id': 'p3', 'code': 'SUMMER', 'kind': 'PERCENT', 'value': 15, 'maxUses': null, 'usedCount': 37, 'active': false},
        ];
      case 'reviews/summary':
        return {'count': 52, 'average': 4.7, 'distribution': [1, 1, 3, 12, 35]};
      case 'reviews':
        final now = DateTime.now().toUtc();
        return [
          {'id': 'r1', 'customerName': 'Aliya N.', 'serviceName': 'Women\'s haircut', 'rating': 5, 'comment': 'Great haircut, very attentive master!', 'createdAt': now.subtract(const Duration(days: 1)).toIso8601String()},
          {'id': 'r2', 'customerName': 'Dinara O.', 'serviceName': 'Manicure + gel polish', 'rating': 5, 'comment': 'Perfect nails, lasted 3 weeks.', 'createdAt': now.subtract(const Duration(days: 2)).toIso8601String()},
          {'id': 'r3', 'customerName': 'Zhanna K.', 'serviceName': 'Hair colouring', 'rating': 4, 'comment': 'Nice result, but waited 15 minutes.', 'createdAt': now.subtract(const Duration(days: 4)).toIso8601String()},
        ];
      case 'support/tickets':
        return <Object>[];
    }
    final prof = RegExp(r'^customers/([^/]+)/profile$').firstMatch(rest);
    if (prof != null) return _profile(prof.group(1)!);
    final sched = RegExp(r'^employees/([^/]+)/schedule$').firstMatch(rest);
    if (sched != null) {
      return {
        'hours': [for (var d = 1; d <= 5; d++) ...[
          {'dayOfWeek': d, 'start': '09:00:00', 'end': '13:00:00'}, {'dayOfWeek': d, 'start': '14:00:00', 'end': '19:00:00'}]],
        'timeOff': [{'id': 't1', 'startsAt': DateTime.now().toUtc().add(const Duration(days: 20)).toIso8601String(),
          'endsAt': DateTime.now().toUtc().add(const Duration(days: 27)).toIso8601String(), 'reason': 'Vacation', 'affectedBookings': 0}],
      };
    }
    return null;
  }

  Object _profile(String id) {
    final c = _clients.firstWhere((c) => c.$1 == id, orElse: () => _clients.first);
    final mine = _bookings.where((b) => b['customerName'] == c.$2).toList();
    final done = mine.where((b) => b['status'] == 'COMPLETED').toList();
    final spent = done.fold(0.0, (a, b) => a + ((b['financials'] as Map)['netPaid'] as num));
    return {
      'customer': {'id': c.$1, 'fullName': c.$2, 'phone': c.$3, 'email': 'client@example.kz', 'blocked': false, 'marketingOptIn': true, 'notes': 'Prefers morning slots. Allergic to ammonia dyes.'},
      'stats': {
        'totalBookings': mine.length, 'completedVisits': done.length, 'cancelled': mine.where((b) => b['status'] == 'CANCELLED').length,
        'noShows': mine.where((b) => b['status'] == 'NO_SHOW').length, 'upcoming': mine.where((b) => const {'CONFIRMED', 'PENDING'}.contains(b['status'])).length,
        'lastVisit': done.isEmpty ? null : done.last['startsAt'], 'totalSpent': spent, 'averageSpendPerVisit': done.isEmpty ? null : spent / done.length,
      },
      'bookings': [for (final b in mine) {'id': b['id'], 'serviceName': b['serviceName'], 'employeeName': b['employeeName'], 'status': b['status'],
        'startsAt': b['startsAt'], 'price': (b['financials'] as Map)['price'], 'netPaid': (b['financials'] as Map)['netPaid']}],
    };
  }

  Object _breakdown(String by) {
    final rows = switch (by) {
      'SERVICE' => [for (final s in _services) (s.$1, s.$2)],
      'EMPLOYEE' => [for (final e in _staff) (e.$1, e.$2)],
      _ => [for (final b in _branches) (b.$1, b.$2)],
    };
    final rnd = Random(by.length);
    return [
      for (var i = 0; i < rows.length; i++)
        () {
          final n = 48 - i * 7 + rnd.nextInt(4);
          final value = n * (11000.0 - i * 900);
          return {'id': rows[i].$1, 'name': rows[i].$2, 'bookings': n, 'completed': n - 4, 'cancelled': 3, 'noShows': 1,
            'bookedValue': value, 'collected': value * .86, 'refunded': 0, 'netCollected': value * .86};
        }()
    ]..sort((a, b) => (b['netCollected'] as double).compareTo(a['netCollected'] as double));
  }

  Object _timeseries(Map<String, dynamic> q) {
    final from = DateTime.parse(q['from'] as String).toUtc().add(_off), to = DateTime.parse(q['to'] as String).toUtc().add(_off);
    final rnd = Random(7);
    final out = <Map<String, Object?>>[];
    for (var d = DateTime(from.year, from.month, from.day); d.isBefore(DateTime(to.year, to.month, to.day)); d = d.add(const Duration(days: 1))) {
      final weekend = d.weekday >= 6;
      final n = weekend ? 4 + rnd.nextInt(3) : 7 + rnd.nextInt(6);
      out.add({'date': '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}', 'bookings': n, 'netCollected': n * (8000 + rnd.nextInt(5000)).toDouble()});
    }
    return out;
  }

  @override
  void close({bool force = false}) {}
}
