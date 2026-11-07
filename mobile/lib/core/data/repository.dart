import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../tz.dart';
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

/// Timezone of the current business (UTC until it is loaded; screens only render after the business gate anyway).
/// The signed-in user's role in the current business (null until loaded), e.g. BUSINESS_OWNER, ACCOUNTANT.
final myRoleProvider = FutureProvider<String?>((ref) async {
  final b = await ref.watch(currentBusinessProvider.future);
  if (b == null) return null;
  final r = await ref.watch(apiClientProvider).run((d) => d.get('/api/v1/me'));
  for (final m in (r.data['memberships'] as List? ?? const [])) {
    if (m['businessId'] == b.id) return m['role'] as String?;
  }
  return null;
});

/// Roles the server allows to export the ledger (FINANCE_EXPORT). The server enforces it; this only hides the button.
bool canExportFinance(String? role) => const {'BUSINESS_OWNER', 'BUSINESS_ADMIN', 'ACCOUNTANT'}.contains(role);

final businessZoneProvider = Provider<String>((ref) => ref.watch(currentBusinessProvider).value?.timezone ?? 'UTC');

/// [day] is a calendar date in the BUSINESS timezone (time of day ignored).
final bookingsProvider = FutureProvider.autoDispose.family<List<Booking>, DateTime>((ref, day) async {
  final b = await _biz(ref);
  final from = instantFromWall(dayStart(day), b.timezone), to = instantFromWall(nextDay(day), b.timezone);
  final r = await ref.watch(apiClientProvider).run((d) => d.get('/api/v1/businesses/${b.id}/bookings',
      queryParameters: {'from': from.toIso8601String(), 'to': to.toIso8601String()}));
  return (r.data as List).map((e) => Booking.fromJson(e, zone: b.timezone)).toList();
});

/// Bookings of the business-timezone calendar days [from, to) (wall dates, at most 92 days), optionally one specialist.
typedef CalendarQuery = (DateTime from, DateTime to, String? employeeId);

final bookingsRangeProvider = FutureProvider.autoDispose.family<List<Booking>, CalendarQuery>((ref, q) async {
  final b = await _biz(ref);
  final r = await ref.watch(apiClientProvider).run((d) => d.get('/api/v1/businesses/${b.id}/bookings', queryParameters: {
        'from': instantFromWall(dayStart(q.$1), b.timezone).toIso8601String(),
        'to': instantFromWall(dayStart(q.$2), b.timezone).toIso8601String(),
        'employeeId': ?q.$3,
      }));
  return (r.data as List).map((e) => Booking.fromJson(e, zone: b.timezone)).toList();
});

/// Selected tag filter of the customer list (null = everyone).
class CustomerTagFilter extends Notifier<String?> {
  @override
  String? build() => null;
  void select(String? tag) => state = tag;
}

final customerTagFilterProvider = NotifierProvider<CustomerTagFilter, String?>(CustomerTagFilter.new);

Future<List<Customer>> _searchCustomers(Ref ref, String q, String? tag) async {
  final b = await _biz(ref);
  final r = await ref.watch(apiClientProvider).run((d) => d.get('/api/v1/businesses/${b.id}/customers',
      queryParameters: {'q': q, 'size': 50, 'tag': ?tag}));
  return (r.data['items'] as List).map((e) => Customer.fromJson(e)).toList();
}

final customersProvider = FutureProvider.autoDispose.family<List<Customer>, String>(
    (ref, q) => _searchCustomers(ref, q, ref.watch(customerTagFilterProvider)));

/// Plain search without the list's tag filter (used by the merge picker).
final customerSearchProvider = FutureProvider.autoDispose.family<List<Customer>, String>((ref, q) => _searchCustomers(ref, q, null));

/// Tags in use with their customer counts (filter chips).
final customerTagsProvider = FutureProvider.autoDispose<List<({String tag, int customers})>>((ref) async {
  final b = await _biz(ref);
  final r = await ref.watch(apiClientProvider).run((d) => d.get('/api/v1/businesses/${b.id}/customers/tags'));
  return [for (final e in (r.data as List)) (tag: e['tag'] as String, customers: (e['customers'] as num).toInt())];
});

/// Last-30-days summary; the end of the range reaches into tomorrow so payments recorded today are included.
final summaryProvider = FutureProvider.autoDispose<Summary>((ref) async {
  final b = await _biz(ref);
  final now = nowWall(b.timezone);
  final from = instantFromWall(DateTime(now.year, now.month, now.day - 30), b.timezone);
  final to = instantFromWall(nextDay(now), b.timezone);
  final r = await ref.watch(apiClientProvider).run((d) => d.get('/api/v1/businesses/${b.id}/analytics/summary',
      queryParameters: {'from': from.toIso8601String(), 'to': to.toIso8601String()}));
  return Summary.fromJson(r.data);
});

final todaySummaryProvider = FutureProvider.autoDispose<Summary>((ref) async {
  final b = await _biz(ref);
  final today = dayStart(nowWall(b.timezone));
  final r = await ref.watch(apiClientProvider).run((d) => d.get('/api/v1/businesses/${b.id}/analytics/summary',
      queryParameters: {'from': instantFromWall(today, b.timezone).toIso8601String(), 'to': instantFromWall(nextDay(today), b.timezone).toIso8601String()}));
  return Summary.fromJson(r.data);
});

final customerProfileProvider = FutureProvider.autoDispose.family<CustomerProfile, String>((ref, id) async {
  final b = await _biz(ref);
  final r = await ref.watch(apiClientProvider).run((d) => d.get('/api/v1/businesses/${b.id}/customers/$id/profile'));
  return CustomerProfile.fromJson(r.data, zone: b.timezone);
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
  return (r.data as List).map((e) => Slot.fromJson(e, zone: b.timezone)).toList();
});

class BookingActions {
  final Ref ref;
  BookingActions(this.ref);

  /// Asks the backend to change the status; the server validates the transition.
  Future<void> transition(String bookingId, String status) async {
    final b = await _biz(ref);
    await ref.read(apiClientProvider).run((d) => d.post('/api/v1/businesses/${b.id}/bookings/$bookingId/transition', data: {'status': status}));
    ref.invalidate(bookingsProvider);
    ref.invalidate(bookingsRangeProvider);
    ref.invalidate(todaySummaryProvider);
    ref.invalidate(summaryProvider);
  }

  Future<String> _id() async => (await _biz(ref)).id;

  Future<void> recordPayment({required String bookingId, required String amount, required String method, required String idempotencyKey}) async {
    final id = await _id();
    await ref.read(apiClientProvider).run((d) => d.post('/api/v1/businesses/$id/bookings/$bookingId/payments',
        data: {'amount': amount, 'method': method}, options: Options(headers: {'Idempotency-Key': idempotencyKey})));
    ref.invalidate(bookingsProvider);
    ref.invalidate(bookingsRangeProvider);
    ref.invalidate(todaySummaryProvider);
    ref.invalidate(summaryProvider);
  }

  Future<void> createBooking({required String branchId, required String serviceId, String? employeeId, required DateTime startsAtInstant,
      required String name, required String phone, String? notes, String? promoCode}) async {
    final id = await _id();
    await ref.read(apiClientProvider).run((d) => d.post('/api/v1/businesses/$id/bookings', data: {
          'branchId': branchId, 'serviceId': serviceId, 'employeeId': ?employeeId, 'startsAt': startsAtInstant.toUtc().toIso8601String(),
          'customer': {'fullName': name, 'phone': phone}, 'notes': ?(notes == null || notes.isEmpty ? null : notes),
          'promoCode': ?(promoCode == null || promoCode.trim().isEmpty ? null : promoCode.trim()),
        }));
    ref.invalidate(bookingsProvider);
    ref.invalidate(bookingsRangeProvider);
    ref.invalidate(todaySummaryProvider);
    ref.invalidate(customersProvider);
  }

  /// [startsAtInstant] is the exact UTC moment of the chosen slot (Slot.instant), never a wall-clock time.
  Future<void> reschedule(String bookingId, DateTime startsAtInstant) async {
    final id = await _id();
    await ref.read(apiClientProvider).run((d) => d.post('/api/v1/businesses/$id/bookings/$bookingId/reschedule', data: {'startsAt': startsAtInstant.toUtc().toIso8601String()}));
    ref.invalidate(bookingsProvider);
    ref.invalidate(bookingsRangeProvider);
  }

  Future<void> markNotificationRead(String id) async {
    final biz = await _id();
    await ref.read(apiClientProvider).run((d) => d.post('/api/v1/businesses/$biz/notifications/$id/read'));
    ref.invalidate(notificationsProvider);
  }

  Future<void> markAllNotificationsRead() async {
    final biz = await _id();
    await ref.read(apiClientProvider).run((d) => d.post('/api/v1/businesses/$biz/notifications/read-all'));
    ref.invalidate(notificationsProvider);
  }

  Future<ImportReport> importCustomers(String csv, {required bool dryRun}) async {
    final biz = await _id();
    final r = await ref.read(apiClientProvider).run((d) => d.post('/api/v1/businesses/$biz/customers/import', data: {'csv': csv, 'dryRun': dryRun}));
    if (!dryRun) ref.invalidate(customersProvider);
    return ImportReport.fromJson(r.data);
  }

  /// CSV of ledger entries for the last [days] days (business time). Returns the server's file name and the bytes.
  Future<({String name, Uint8List bytes})> exportLedger({required int days, required bool semicolon}) async {
    final b = await _biz(ref);
    final now = nowWall(b.timezone);
    final from = instantFromWall(DateTime(now.year, now.month, now.day - (days - 1)), b.timezone), to = instantFromWall(nextDay(now), b.timezone);
    final r = await ref.read(apiClientProvider).run((d) => d.get<List<int>>('/api/v1/businesses/${b.id}/finance/export',
        queryParameters: {'from': from.toIso8601String(), 'to': to.toIso8601String(), 'delimiter': semicolon ? 'semicolon' : 'comma'},
        options: Options(responseType: ResponseType.bytes)));
    final cd = r.headers.value('content-disposition') ?? '';
    final name = RegExp(r'filename="?([^";]+)"?').firstMatch(cd)?.group(1) ?? 'orleu-ledger.csv';
    return (name: name, bytes: Uint8List.fromList(r.data!));
  }

  /// Replaces the weekly hours of a specialist (empty = follow the location). Returns how many upcoming bookings no longer fit.
  Future<int> setEmployeeHours(String employeeId, List<ScheduleRange> ranges) async {
    final biz = await _id();
    final r = await ref.read(apiClientProvider).run((d) => d.put('/api/v1/businesses/$biz/employees/$employeeId/hours', data: {'hours': [for (final x in ranges) x.toJson()]}));
    ref.invalidate(employeeScheduleProvider);
    ref.invalidate(availabilityProvider);
    return r.data['affectedBookings'] ?? 0;
  }

  /// [firstDay]..[lastDay] are calendar days in the business timezone; the whole of both days is off.
  Future<void> addTimeOff(String employeeId, DateTime firstDay, DateTime lastDay, String? reason) async {
    final b = await _biz(ref);
    final from = instantFromWall(dayStart(firstDay), b.timezone), to = instantFromWall(nextDay(lastDay), b.timezone);
    await ref.read(apiClientProvider).run((d) => d.post('/api/v1/businesses/${b.id}/employees/$employeeId/time-off',
        data: {'startsAt': from.toIso8601String(), 'endsAt': to.toIso8601String(), 'reason': ?((reason ?? '').trim().isEmpty ? null : reason!.trim())}));
    ref.invalidate(employeeScheduleProvider);
    ref.invalidate(availabilityProvider);
  }

  /// One date differs from the weekly schedule. [dayOff] or a single [start]-[end] range ('HH:mm'). Returns how many bookings that day no longer fit.
  Future<int> setDateException(String employeeId, DateTime date, {required bool dayOff, String? start, String? end}) async {
    final biz = await _id();
    final day = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final r = await ref.read(apiClientProvider).run((d) => d.put('/api/v1/businesses/$biz/employees/$employeeId/exceptions/$day',
        data: {'dayOff': dayOff, 'ranges': dayOff ? [] : [{'start': start, 'end': end}]}));
    ref.invalidate(employeeScheduleProvider);
    ref.invalidate(availabilityProvider);
    return r.data['affectedBookings'] ?? 0;
  }

  Future<void> removeDateException(String employeeId, DateTime date) async {
    final biz = await _id();
    final day = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    await ref.read(apiClientProvider).run((d) => d.delete('/api/v1/businesses/$biz/employees/$employeeId/exceptions/$day'));
    ref.invalidate(employeeScheduleProvider);
    ref.invalidate(availabilityProvider);
  }

  Future<void> removeTimeOff(String employeeId, String timeOffId) async {
    final biz = await _id();
    await ref.read(apiClientProvider).run((d) => d.delete('/api/v1/businesses/$biz/employees/$employeeId/time-off/$timeOffId'));
    ref.invalidate(employeeScheduleProvider);
    ref.invalidate(availabilityProvider);
  }

  /// Business-level customer messaging settings (reminder lead time in hours, 0 = off; language of customer messages).
  Future<void> updateMessaging({int? reminderHours, String? customerLocale, int? retentionMonths}) async {
    final biz = await _id();
    await ref.read(apiClientProvider).run((d) => d.patch('/api/v1/businesses/$biz/settings', data: {'reminderHours': ?reminderHours, 'customerLocale': ?customerLocale, 'customerRetentionMonths': ?retentionMonths}));
    ref.invalidate(currentBusinessProvider);
  }

  /// Everything held about one client as JSON bytes (the server audits the export).
  Future<({String name, Uint8List bytes})> exportCustomer(String customerId) async {
    final biz = await _id();
    final r = await ref.read(apiClientProvider).run((d) => d.get<List<int>>('/api/v1/businesses/$biz/customers/$customerId/export', options: Options(responseType: ResponseType.bytes)));
    return (name: 'customer-$customerId.json', bytes: Uint8List.fromList(r.data!));
  }

  /// Irreversible: removes the client's personal data; bookings and payments stay without it.
  Future<void> anonymizeCustomer(String customerId) async {
    final biz = await _id();
    await ref.read(apiClientProvider).run((d) => d.post('/api/v1/businesses/$biz/customers/$customerId/anonymize'));
    ref.invalidate(customerProfileProvider);
    ref.invalidate(customersProvider);
  }

  Future<void> updateCustomer(String id, {String? fullName, String? email, String? notes, bool? marketingOptIn}) async {
    final biz = await _id();
    await ref.read(apiClientProvider).run((d) => d.patch('/api/v1/businesses/$biz/customers/$id',
        data: {'fullName': ?fullName, 'email': ?email, 'notes': ?notes, 'marketingOptIn': ?marketingOptIn}));
    ref.invalidate(customerProfileProvider);
    ref.invalidate(customersProvider);
  }

  Future<void> setCustomerTags(String id, List<String> tags) async {
    final biz = await _id();
    await ref.read(apiClientProvider).run((d) => d.put('/api/v1/businesses/$biz/customers/$id/tags', data: {'tags': tags}));
    ref.invalidate(customerProfileProvider);
    ref.invalidate(customersProvider);
    ref.invalidate(customerTagsProvider);
  }

  /// Merges the duplicate [sourceId] into [targetId]; the duplicate is deleted on the server.
  Future<void> mergeCustomer(String targetId, String sourceId) async {
    final biz = await _id();
    await ref.read(apiClientProvider).run((d) => d.post('/api/v1/businesses/$biz/customers/$targetId/merge', data: {'sourceId': sourceId}));
    ref.invalidate(customerProfileProvider);
    ref.invalidate(customersProvider);
    ref.invalidate(customerSearchProvider);
    ref.invalidate(customerTagsProvider);
  }

  Future<void> setCustomerBlocked(String id, bool blocked) async {
    final biz = await _id();
    await ref.read(apiClientProvider).run((d) => d.post('/api/v1/businesses/$biz/customers/$id/${blocked ? 'block' : 'unblock'}'));
    ref.invalidate(customerProfileProvider);
    ref.invalidate(customersProvider);
  }

  Future<void> updateBranch(String id, {String? name, String? address, bool? active}) async {
    final biz = await _id();
    await ref.read(apiClientProvider).run((d) => d.patch('/api/v1/businesses/$biz/branches/$id', data: {'name': ?name, 'address': ?address, 'active': ?active}));
    ref.invalidate(branchesProvider);
  }

  /// [depositPercent] null together with [useBusinessDeposit] = true clears the service-level override.
  Future<void> updateService(String id, {String? name, int? durationMinutes, int? bufferMinutes, String? price, String? depositPercent,
      bool useBusinessDeposit = false, bool? active}) async {
    final biz = await _id();
    await ref.read(apiClientProvider).run((d) => d.patch('/api/v1/businesses/$biz/services/$id', data: {
          'name': ?name, 'durationMinutes': ?durationMinutes, 'bufferMinutes': ?bufferMinutes, 'price': ?price,
          if (useBusinessDeposit) 'useBusinessDeposit': true else 'depositPercent': ?depositPercent,
          'active': ?active,
        }));
    ref.invalidate(servicesProvider);
  }

  Future<void> updateEmployee(String id, {String? displayName, bool? active}) async {
    final biz = await _id();
    await ref.read(apiClientProvider).run((d) => d.patch('/api/v1/businesses/$biz/employees/$id', data: {'displayName': ?displayName, 'active': ?active}));
    ref.invalidate(employeesProvider);
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

/// Report period in days (7/30/90) selected on the finance screen.
class ReportDays extends Notifier<int> {
  @override
  int build() => 30;
  void set(int days) => state = days;
}

final reportDaysProvider = NotifierProvider<ReportDays, int>(ReportDays.new);

typedef _Range = ({String from, String to});

Future<_Range> _reportRange(Ref ref) async {
  final b = await _biz(ref);
  final days = ref.watch(reportDaysProvider);
  final now = nowWall(b.timezone);
  return (
    from: instantFromWall(DateTime(now.year, now.month, now.day - (days - 1)), b.timezone).toIso8601String(),
    to: instantFromWall(nextDay(now), b.timezone).toIso8601String(),
  );
}

Future<dynamic> _report(Ref ref, String what, [Map<String, dynamic> extra = const {}]) async {
  final b = await _biz(ref);
  final r = await _reportRange(ref);
  final res = await ref.watch(apiClientProvider).run((d) => d.get('/api/v1/businesses/${b.id}/analytics/$what',
      queryParameters: {'from': r.from, 'to': r.to, ...extra}));
  return res.data;
}

final breakdownProvider = FutureProvider.autoDispose.family<List<BreakdownRow>, String>((ref, by) async =>
    ((await _report(ref, 'breakdown', {'by': by})) as List).map((e) => BreakdownRow.fromJson(e)).toList());

final timeseriesProvider = FutureProvider.autoDispose<List<DayPoint>>((ref) async =>
    ((await _report(ref, 'timeseries')) as List).map((e) => DayPoint.fromJson(e)).toList());

final peakHoursProvider = FutureProvider.autoDispose<List<int>>((ref) async =>
    ((await _report(ref, 'peak-hours')) as List).map((e) => (e as num).toInt()).toList());

final customerMixProvider = FutureProvider.autoDispose<CustomerMix>((ref) async => CustomerMix.fromJson(await _report(ref, 'customers')));

final customerMessagesProvider = FutureProvider.autoDispose<List<CustomerMessage>>((ref) async {
  final b = await _biz(ref);
  final r = await ref.watch(apiClientProvider).run((d) => d.get('/api/v1/businesses/${b.id}/notifications/customer-messages'));
  return (r.data as List).map((e) => CustomerMessage.fromJson(e)).toList();
});

final sessionsProvider = FutureProvider.autoDispose<List<DeviceSession>>((ref) async {
  final r = await ref.watch(apiClientProvider).run((d) => d.get('/api/v1/auth/sessions'));
  return (r.data as List).map((e) => DeviceSession.fromJson(e)).toList();
});

Future<void> revokeSession(WidgetRef ref, String id) async {
  await ref.read(apiClientProvider).run((d) => d.delete('/api/v1/auth/sessions/$id'));
  ref.invalidate(sessionsProvider);
}

final promosProvider = FutureProvider.autoDispose<List<PromoItem>>((ref) async {
  final b = await _biz(ref);
  final r = await ref.watch(apiClientProvider).run((d) => d.get('/api/v1/businesses/${b.id}/promo-codes'));
  return (r.data as List).map((e) => PromoItem.fromJson(e)).toList();
});

Future<void> createPromo(WidgetRef ref, Map<String, Object?> body) async {
  final b = await ref.read(currentBusinessProvider.future);
  await ref.read(apiClientProvider).run((d) => d.post('/api/v1/businesses/${b!.id}/promo-codes', data: body));
  ref.invalidate(promosProvider);
}

Future<void> setPromoActive(WidgetRef ref, String id, bool active) async {
  final b = await ref.read(currentBusinessProvider.future);
  await ref.read(apiClientProvider).run((d) => d.patch('/api/v1/businesses/${b!.id}/promo-codes/$id', data: {'active': active}));
  ref.invalidate(promosProvider);
}

final reviewsProvider = FutureProvider.autoDispose<(ReviewSummary, List<ReviewItem>)>((ref) async {
  final b = await _biz(ref);
  final api = ref.watch(apiClientProvider);
  final sum = await api.run((d) => d.get('/api/v1/businesses/${b.id}/reviews/summary'));
  final list = await api.run((d) => d.get('/api/v1/businesses/${b.id}/reviews'));
  return (ReviewSummary.fromJson(sum.data), (list.data as List).map((e) => ReviewItem.fromJson(e)).toList());
});

/// Notifications of the business. Refreshed every minute while something watches it (the home bell), and on pull-to-refresh.
final notificationsProvider = FutureProvider.autoDispose<List<AppNotification>>((ref) async {
  final b = await _biz(ref);
  final timer = Timer(const Duration(seconds: 60), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  final r = await ref.watch(apiClientProvider).run((d) => d.get('/api/v1/businesses/${b.id}/notifications'));
  return (r.data as List).map((e) => AppNotification.fromJson(e)).toList();
});

final unreadNotificationsProvider = Provider.autoDispose<int>((ref) => ref.watch(notificationsProvider).value?.where((n) => !n.read).length ?? 0);

class MfaStatus {
  final bool enabled;
  final int recoveryCodesLeft;
  const MfaStatus(this.enabled, this.recoveryCodesLeft);
}

final mfaStatusProvider = FutureProvider.autoDispose<MfaStatus>((ref) async {
  final r = await ref.watch(apiClientProvider).run((d) => d.get('/api/v1/auth/mfa'));
  return MfaStatus(r.data['enabled'] == true, r.data['recoveryCodesLeft'] ?? 0);
});

class MfaApi {
  final WidgetRef ref;
  MfaApi(this.ref);
  Future<({String secret, String uri})> setup() async {
    final r = await ref.read(apiClientProvider).run((d) => d.post('/api/v1/auth/mfa/setup'));
    return (secret: r.data['secret'] as String, uri: r.data['otpauthUri'] as String);
  }

  Future<List<String>> enable(String code) async {
    final r = await ref.read(apiClientProvider).run((d) => d.post('/api/v1/auth/mfa/enable', data: {'code': code}));
    ref.invalidate(mfaStatusProvider);
    return List<String>.from(r.data['recoveryCodes']);
  }

  Future<void> disable(String password, String code) async {
    await ref.read(apiClientProvider).run((d) => d.post('/api/v1/auth/mfa/disable', data: {'password': password, 'code': code}));
    ref.invalidate(mfaStatusProvider);
  }
}

final loginHistoryProvider = FutureProvider.autoDispose<LoginHistory>((ref) async {
  final r = await ref.watch(apiClientProvider).run((d) => d.get('/api/v1/auth/login-history'));
  return LoginHistory.fromJson(r.data);
});

final employeeScheduleProvider = FutureProvider.autoDispose.family<EmployeeSchedule, String>((ref, employeeId) async {
  final b = await _biz(ref);
  final r = await ref.watch(apiClientProvider).run((d) => d.get('/api/v1/businesses/${b.id}/employees/$employeeId/schedule'));
  return EmployeeSchedule.fromJson(r.data);
});

/// Roles holding FINANCE_MANAGE (may record a refund) and REFUND_APPROVE (decide requests). The server enforces both; this only hides buttons.
bool canRefund(String? role) => const {'BUSINESS_OWNER', 'BUSINESS_ADMIN', 'RECEPTIONIST', 'ACCOUNTANT'}.contains(role);
bool canApproveRefund(String? role) => const {'BUSINESS_OWNER', 'BUSINESS_ADMIN'}.contains(role);

final refundRequestsProvider = FutureProvider.autoDispose<List<RefundRequest>>((ref) async {
  final b = await _biz(ref);
  final r = await ref.watch(apiClientProvider).run((d) => d.get('/api/v1/businesses/${b.id}/refund-requests'));
  return (r.data as List).map((e) => RefundRequest.fromJson(e)).toList();
});

/// Refund above this amount needs an approver; null = no approval needed.
final refundPolicyProvider = FutureProvider.autoDispose<double?>((ref) async {
  final b = await _biz(ref);
  final r = await ref.watch(apiClientProvider).run((d) => d.get('/api/v1/businesses/${b.id}/refund-policy'));
  final t = r.data['threshold'];
  return t == null ? null : (t as num).toDouble();
});

/// Returns true when the refund was recorded now, false when it is waiting for approval (HTTP 202).
Future<bool> refundBooking(WidgetRef ref, {required String bookingId, required String amount, required String method, required String idempotencyKey}) async {
  final b = await ref.read(currentBusinessProvider.future);
  final res = await ref.read(apiClientProvider).run((d) => d.post('/api/v1/businesses/${b!.id}/bookings/$bookingId/refunds',
      data: {'amount': amount, 'method': method}, options: Options(headers: {'Idempotency-Key': idempotencyKey})));
  ref.invalidate(bookingsProvider);
  ref.invalidate(bookingsRangeProvider);
  ref.invalidate(todaySummaryProvider);
  ref.invalidate(summaryProvider);
  ref.invalidate(refundRequestsProvider);
  return res.statusCode == 201;
}

Future<void> decideRefund(WidgetRef ref, String id, {required bool approve, String? note}) async {
  final b = await ref.read(currentBusinessProvider.future);
  await ref.read(apiClientProvider).run((d) => d.post('/api/v1/businesses/${b!.id}/refund-requests/$id/${approve ? 'approve' : 'reject'}', data: {'note': ?note}));
  ref.invalidate(refundRequestsProvider);
  ref.invalidate(bookingsProvider);
  ref.invalidate(bookingsRangeProvider);
  ref.invalidate(summaryProvider);
}

Future<void> setRefundPolicy(WidgetRef ref, double? threshold) async {
  final b = await ref.read(currentBusinessProvider.future);
  await ref.read(apiClientProvider).run((d) => d.put('/api/v1/businesses/${b!.id}/refund-policy', data: {'threshold': threshold}));
  ref.invalidate(refundPolicyProvider);
}
