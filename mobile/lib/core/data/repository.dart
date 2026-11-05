import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_controller.dart';
import 'models.dart';

/// Business data providers. Each reads the current authenticated ApiClient.
final meNameProvider = FutureProvider<String>((ref) async {
  ref.watch(authControllerProvider);
  final r = await ref.watch(apiClientProvider).run((d) => d.get('/api/v1/me'));
  return r.data['fullName'] as String;
});

/// The user's first business, or null if they have none yet (-> onboarding).
final currentBusinessProvider = FutureProvider<Business?>((ref) async {
  final r = await ref.watch(apiClientProvider).run((d) => d.get('/api/v1/businesses'));
  final list = (r.data as List).map((e) => Business.fromJson(e)).toList();
  return list.isEmpty ? null : list.first;
});

Future<Business> _biz(Ref ref) async {
  final b = await ref.watch(currentBusinessProvider.future);
  if (b == null) throw StateError('no business');
  return b;
}

/// Random 128-bit hex key. One key identifies ONE payment attempt: retrying the same attempt reuses it so the server never charges twice.
String newIdempotencyKey() {
  final r = Random.secure();
  return List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

DateTime dayStart(DateTime d) => DateTime(d.year, d.month, d.day);

final bookingsProvider = FutureProvider.autoDispose.family<List<Booking>, DateTime>((ref, day) async {
  final b = await _biz(ref);
  final from = dayStart(day), to = from.add(const Duration(days: 1));
  final r = await ref.watch(apiClientProvider).run((d) => d.get('/api/v1/businesses/${b.id}/bookings',
      queryParameters: {'from': from.toUtc().toIso8601String(), 'to': to.toUtc().toIso8601String()}));
  return (r.data as List).map((e) => Booking.fromJson(e)).toList();
});

final customersProvider = FutureProvider.autoDispose.family<List<Customer>, String>((ref, q) async {
  final b = await _biz(ref);
  final r = await ref.watch(apiClientProvider).run((d) => d.get('/api/v1/businesses/${b.id}/customers',
      queryParameters: {'q': q, 'size': 50}));
  return (r.data['items'] as List).map((e) => Customer.fromJson(e)).toList();
});

/// Last-30-days summary; the end of the range reaches into tomorrow so payments recorded today are included.
final summaryProvider = FutureProvider.autoDispose<Summary>((ref) async {
  final b = await _biz(ref);
  final now = DateTime.now();
  final from = dayStart(now).subtract(const Duration(days: 30));
  final to = dayStart(now).add(const Duration(days: 1));
  final r = await ref.watch(apiClientProvider).run((d) => d.get('/api/v1/businesses/${b.id}/analytics/summary',
      queryParameters: {'from': from.toUtc().toIso8601String(), 'to': to.toUtc().toIso8601String()}));
  return Summary.fromJson(r.data);
});

final todaySummaryProvider = FutureProvider.autoDispose<Summary>((ref) async {
  final b = await _biz(ref);
  final from = dayStart(DateTime.now());
  final r = await ref.watch(apiClientProvider).run((d) => d.get('/api/v1/businesses/${b.id}/analytics/summary',
      queryParameters: {'from': from.toUtc().toIso8601String(), 'to': from.add(const Duration(days: 1)).toUtc().toIso8601String()}));
  return Summary.fromJson(r.data);
});

final usageProvider = FutureProvider.autoDispose<PlanUsage>((ref) async {
  final b = await _biz(ref);
  final r = await ref.watch(apiClientProvider).run((d) => d.get('/api/v1/businesses/${b.id}/subscription'));
  return PlanUsage.fromJson(r.data);
});

final branchesProvider = FutureProvider.autoDispose<List<Branch>>((ref) async {
  final b = await _biz(ref);
  final r = await ref.watch(apiClientProvider).run((d) => d.get('/api/v1/businesses/${b.id}/branches'));
  return (r.data as List).map((e) => Branch.fromJson(e)).toList();
});

final servicesProvider = FutureProvider.autoDispose<List<ServiceItem>>((ref) async {
  final b = await _biz(ref);
  final r = await ref.watch(apiClientProvider).run((d) => d.get('/api/v1/businesses/${b.id}/services'));
  return (r.data as List).map((e) => ServiceItem.fromJson(e)).toList();
});

final employeesProvider = FutureProvider.autoDispose<List<Employee>>((ref) async {
  final b = await _biz(ref);
  final r = await ref.watch(apiClientProvider).run((d) => d.get('/api/v1/businesses/${b.id}/employees'));
  return (r.data as List).map((e) => Employee.fromJson(e)).toList();
});

typedef AvailabilityKey = ({String branchId, String serviceId, String? employeeId, String date, String? excludeBookingId});

final availabilityProvider = FutureProvider.autoDispose.family<List<Slot>, AvailabilityKey>((ref, k) async {
  final b = await _biz(ref);
  final r = await ref.watch(apiClientProvider).run((d) => d.get('/api/v1/businesses/${b.id}/availability', queryParameters: {
        'branchId': k.branchId, 'serviceId': k.serviceId, 'date': k.date,
        'employeeId': ?k.employeeId, 'excludeBookingId': ?k.excludeBookingId,
      }));
  return (r.data as List).map((e) => Slot.fromJson(e)).toList();
});

class BookingActions {
  final Ref ref;
  BookingActions(this.ref);

  /// Asks the backend to change the status; the server validates the transition.
  Future<void> transition(String bookingId, String status) async {
    final b = await _biz(ref);
    await ref.read(apiClientProvider).run((d) => d.post('/api/v1/businesses/${b.id}/bookings/$bookingId/transition', data: {'status': status}));
    ref.invalidate(bookingsProvider);
    ref.invalidate(todaySummaryProvider);
    ref.invalidate(summaryProvider);
  }

  Future<String> _id() async => (await _biz(ref)).id;

  Future<void> recordPayment({required String bookingId, required String amount, required String method, required String idempotencyKey}) async {
    final id = await _id();
    await ref.read(apiClientProvider).run((d) => d.post('/api/v1/businesses/$id/bookings/$bookingId/payments',
        data: {'amount': amount, 'method': method}, options: Options(headers: {'Idempotency-Key': idempotencyKey})));
    ref.invalidate(bookingsProvider);
    ref.invalidate(todaySummaryProvider);
    ref.invalidate(summaryProvider);
  }

  Future<void> createBooking({required String branchId, required String serviceId, String? employeeId, required DateTime startsAt,
      required String name, required String phone, String? notes}) async {
    final id = await _id();
    await ref.read(apiClientProvider).run((d) => d.post('/api/v1/businesses/$id/bookings', data: {
          'branchId': branchId, 'serviceId': serviceId, 'employeeId': ?employeeId, 'startsAt': startsAt.toUtc().toIso8601String(),
          'customer': {'fullName': name, 'phone': phone}, 'notes': ?(notes == null || notes.isEmpty ? null : notes),
        }));
    ref.invalidate(bookingsProvider);
    ref.invalidate(todaySummaryProvider);
    ref.invalidate(customersProvider);
  }

  Future<void> reschedule(String bookingId, DateTime startsAt) async {
    final id = await _id();
    await ref.read(apiClientProvider).run((d) => d.post('/api/v1/businesses/$id/bookings/$bookingId/reschedule', data: {'startsAt': startsAt.toUtc().toIso8601String()}));
    ref.invalidate(bookingsProvider);
  }

  Future<void> createBranch(String name, String? address) async {
    final id = await _id();
    await ref.read(apiClientProvider).run((d) => d.post('/api/v1/businesses/$id/branches', data: {'name': name, 'address': ?(address == null || address.isEmpty ? null : address)}));
    ref.invalidate(branchesProvider);
  }

  /// hours: ISO weekday -> (open, close) as 'HH:mm'. Days not present are closed.
  Future<void> setHours(String branchId, Map<int, (String, String)> hours) async {
    final id = await _id();
    await ref.read(apiClientProvider).run((d) => d.put('/api/v1/businesses/$id/branches/$branchId/hours', data: {
          'hours': [for (final e in hours.entries) {'dayOfWeek': e.key, 'open': e.value.$1, 'close': e.value.$2}]
        }));
    ref.invalidate(branchesProvider);
  }

  Future<void> createService({required String name, required int durationMinutes, required String price, String? depositPercent, int? bufferMinutes}) async {
    final id = await _id();
    await ref.read(apiClientProvider).run((d) => d.post('/api/v1/businesses/$id/services', data: {
          'name': name, 'durationMinutes': durationMinutes, 'price': price,
          if (depositPercent != null && depositPercent.isNotEmpty) 'depositPercent': depositPercent,
          'bufferMinutes': ?bufferMinutes,
        }));
    ref.invalidate(servicesProvider);
  }

  Future<void> createEmployee(String name) async {
    final id = await _id();
    await ref.read(apiClientProvider).run((d) => d.post('/api/v1/businesses/$id/employees', data: {'displayName': name}));
    ref.invalidate(employeesProvider);
  }

  Future<void> setAssignments(String employeeId, List<String> branchIds, List<String> serviceIds) async {
    final id = await _id();
    await ref.read(apiClientProvider).run((d) => d.put('/api/v1/businesses/$id/employees/$employeeId/assignments', data: {'branchIds': branchIds, 'serviceIds': serviceIds}));
    ref.invalidate(employeesProvider);
  }

  Future<void> setPublished(bool publish) async {
    final id = await _id();
    await ref.read(apiClientProvider).run((d) => d.post('/api/v1/businesses/$id/${publish ? 'publish' : 'unpublish'}'));
    ref.invalidate(currentBusinessProvider);
  }

  Future<void> createBusiness(String name, String slug, String type) async {
    await ref.read(apiClientProvider).run((d) => d.post('/api/v1/businesses', data: {'name': name, 'slug': slug, 'businessType': type}));
    ref.invalidate(currentBusinessProvider);
  }
}

final bookingActionsProvider = Provider<BookingActions>((ref) => BookingActions(ref));
