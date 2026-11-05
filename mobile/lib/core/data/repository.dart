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

  Future<void> createBusiness(String name, String slug, String type) async {
    await ref.read(apiClientProvider).run((d) => d.post('/api/v1/businesses', data: {'name': name, 'slug': slug, 'businessType': type}));
    ref.invalidate(currentBusinessProvider);
  }
}

final bookingActionsProvider = Provider<BookingActions>((ref) => BookingActions(ref));
