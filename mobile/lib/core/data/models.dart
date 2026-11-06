import '../tz.dart';

/// Plain immutable models mirroring the backend DTOs. Money stays as decimal strings -> num only for display.
double _num(Object? v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

class Business {
  final String id, name, slug, currency, planCode, timezone, customerLocale;
  final bool published;
  final int reminderHours;
  const Business({required this.id, required this.name, required this.slug, required this.currency, required this.planCode, required this.published, this.timezone = 'UTC',
      this.reminderHours = 24, this.customerLocale = 'ru'});
  factory Business.fromJson(Map<String, dynamic> j) => Business(
      id: j['id'], name: j['name'], slug: j['slug'], currency: j['currency'] ?? 'KZT', planCode: j['planCode'] ?? 'FREE', published: j['published'] == true, timezone: j['timezone'] ?? 'UTC',
      reminderHours: j['reminderHours'] ?? 24, customerLocale: j['customerLocale'] ?? 'ru');
}

class Financials {
  final double price, deposit, paid, remaining;
  final String paymentStatus;
  const Financials({required this.price, required this.deposit, required this.paid, required this.remaining, required this.paymentStatus});
  factory Financials.fromJson(Map<String, dynamic> j) => Financials(
      price: _num(j['price']), deposit: _num(j['depositAmount']), paid: _num(j['netPaid']), remaining: _num(j['remaining']), paymentStatus: j['paymentStatus']);
}

const bookingStatuses = ['PENDING', 'AWAITING_PAYMENT', 'CONFIRMED', 'CHECKED_IN', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED', 'NO_SHOW', 'EXPIRED'];

class Booking {
  final String branchId, serviceId, employeeId;
  final String id, serviceName, employeeName, customerName, customerPhone, status, currency;
  /// Wall-clock times in the business timezone (see tz.dart); [endsInstant] is the exact UTC moment.
  final DateTime startsAt, endsAt, endsInstant;
  final Financials financials;
  const Booking({required this.branchId, required this.serviceId, required this.employeeId, required this.id, required this.serviceName, required this.employeeName, required this.customerName, required this.customerPhone,
      required this.status, required this.currency, required this.startsAt, required this.endsAt, required this.endsInstant, required this.financials});
  factory Booking.fromJson(Map<String, dynamic> j, {String zone = 'UTC'}) => Booking(
      branchId: j['branchId'], serviceId: j['serviceId'], employeeId: j['employeeId'], id: j['id'], serviceName: j['serviceName'], employeeName: j['employeeName'], customerName: j['customerName'], customerPhone: j['customerPhone'],
      status: j['status'], currency: j['currency'], startsAt: wallFromInstant(DateTime.parse(j['startsAt']), zone), endsAt: wallFromInstant(DateTime.parse(j['endsAt']), zone),
      endsInstant: DateTime.parse(j['endsAt']).toUtc(),
      financials: Financials.fromJson(j['financials']));

  /// Status changes the UI offers. The backend remains the authority and rejects anything else.
  List<String> get nextActions => switch (status) {
        'PENDING' => ['CONFIRMED', 'CANCELLED'],
        'AWAITING_PAYMENT' => ['CANCELLED'],
        'CONFIRMED' => ['CHECKED_IN', 'NO_SHOW', 'CANCELLED'],
        'CHECKED_IN' => ['IN_PROGRESS', 'CANCELLED'],
        'IN_PROGRESS' => ['COMPLETED'],
        _ => const [],
      };
  /// Money can be taken while something is owed and the booking is not closed without service.
  bool get canTakePayment => financials.remaining > 0 && !const {'CANCELLED', 'NO_SHOW', 'EXPIRED'}.contains(status);
  bool get canReschedule => const {'PENDING', 'AWAITING_PAYMENT', 'CONFIRMED'}.contains(status);
  bool get needsAction => status == 'PENDING' || status == 'AWAITING_PAYMENT';
  bool get isLive => const {'PENDING', 'AWAITING_PAYMENT', 'CONFIRMED', 'CHECKED_IN', 'IN_PROGRESS'}.contains(status);
}

class Customer {
  final String id, fullName, phone;
  final String? email;
  final bool blocked;
  const Customer({required this.id, required this.fullName, required this.phone, this.email, required this.blocked});
  factory Customer.fromJson(Map<String, dynamic> j) =>
      Customer(id: j['id'], fullName: j['fullName'], phone: j['phone'], email: j['email'], blocked: j['blocked'] == true);
}

class Summary {
  final double bookedValue, collected, refunded, netCollected, outstanding, cancellationRate, noShowRate;
  final int totalBookings;
  const Summary({required this.bookedValue, required this.collected, required this.refunded, required this.netCollected, required this.outstanding,
      required this.cancellationRate, required this.noShowRate, required this.totalBookings});
  factory Summary.fromJson(Map<String, dynamic> j) => Summary(
      bookedValue: _num(j['bookedValue']), collected: _num(j['collected']), refunded: _num(j['refunded']), netCollected: _num(j['netCollected']),
      outstanding: _num(j['outstanding']), cancellationRate: _num(j['cancellationRate']), noShowRate: _num(j['noShowRate']), totalBookings: j['totalBookings'] ?? 0);
}

class BreakdownRow {
  final String id, name;
  final int bookings, completed, cancelled, noShows;
  final double bookedValue, collected, refunded, netCollected;
  const BreakdownRow({required this.id, required this.name, required this.bookings, required this.completed, required this.cancelled,
      required this.noShows, required this.bookedValue, required this.collected, required this.refunded, required this.netCollected});
  factory BreakdownRow.fromJson(Map<String, dynamic> j) => BreakdownRow(
      id: '${j['id']}', name: j['name'] ?? '', bookings: j['bookings'] ?? 0, completed: j['completed'] ?? 0, cancelled: j['cancelled'] ?? 0,
      noShows: j['noShows'] ?? 0, bookedValue: _num(j['bookedValue']), collected: _num(j['collected']), refunded: _num(j['refunded']),
      netCollected: _num(j['netCollected']));
}

class DayPoint {
  final DateTime date; // calendar day in the business timezone
  final int bookings;
  final double netCollected;
  const DayPoint({required this.date, required this.bookings, required this.netCollected});
  factory DayPoint.fromJson(Map<String, dynamic> j) {
    final d = DateTime.parse(j['date']);
    return DayPoint(date: DateTime(d.year, d.month, d.day), bookings: j['bookings'] ?? 0, netCollected: _num(j['netCollected']));
  }
}

class CustomerMix {
  final int newCustomers, returningCustomers;
  final double returningShare;
  const CustomerMix({required this.newCustomers, required this.returningCustomers, required this.returningShare});
  factory CustomerMix.fromJson(Map<String, dynamic> j) => CustomerMix(
      newCustomers: j['newCustomers'] ?? 0, returningCustomers: j['returningCustomers'] ?? 0, returningShare: _num(j['returningShare']));
}

class CustomerMessage {
  final String id, messageType, locale, recipientPhone, body, status;
  final DateTime createdAt;
  const CustomerMessage({required this.id, required this.messageType, required this.locale, required this.recipientPhone, required this.body, required this.status, required this.createdAt});
  factory CustomerMessage.fromJson(Map<String, dynamic> j) => CustomerMessage(
      id: j['id'], messageType: j['messageType'], locale: j['locale'], recipientPhone: j['recipientPhone'], body: j['body'], status: j['status'],
      createdAt: DateTime.parse(j['createdAt']));
}

class DeviceSession {
  final String id;
  final String? userAgent;
  final DateTime createdAt;
  const DeviceSession({required this.id, this.userAgent, required this.createdAt});
  factory DeviceSession.fromJson(Map<String, dynamic> j) => DeviceSession(id: j['id'], userAgent: j['userAgent'], createdAt: DateTime.parse(j['createdAt']));
}

class ReviewItem {
  final String id, customerName, serviceName;
  final int rating;
  final String? comment;
  final DateTime createdAt;
  const ReviewItem({required this.id, required this.customerName, required this.serviceName, required this.rating, this.comment, required this.createdAt});
  factory ReviewItem.fromJson(Map<String, dynamic> j) => ReviewItem(
      id: j['id'], customerName: j['customerName'] ?? '', serviceName: j['serviceName'] ?? '', rating: j['rating'], comment: j['comment'], createdAt: DateTime.parse(j['createdAt']));
}

class ReviewSummary {
  final int count;
  final double? average;
  final List<int> distribution; // index 0 = one star
  const ReviewSummary({required this.count, this.average, required this.distribution});
  factory ReviewSummary.fromJson(Map<String, dynamic> j) => ReviewSummary(
      count: j['count'] ?? 0, average: j['average'] == null ? null : _num(j['average']), distribution: List<int>.from(j['distribution'] ?? const [0, 0, 0, 0, 0]));
}

class AppNotification {
  final String id, eventType;
  final String? bookingId, customerName, serviceName;
  final DateTime createdAt;
  final DateTime? startsAtInstant;
  final bool read;
  const AppNotification({required this.id, required this.eventType, this.bookingId, this.customerName, this.serviceName, required this.createdAt, this.startsAtInstant, required this.read});
  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
      id: j['id'], eventType: j['eventType'], bookingId: j['bookingId'], customerName: j['customerName'], serviceName: j['serviceName'],
      createdAt: DateTime.parse(j['createdAt']), startsAtInstant: j['startsAt'] == null ? null : DateTime.parse(j['startsAt']), read: j['read'] == true);
}

class ImportReport {
  final bool dryRun, issuesTruncated;
  final int totalRows, created, existing, duplicatesInFile, invalid;
  final List<(int, String)> issues; // (row, reason code)
  final List<(String, String)> preview; // (name, phone)
  const ImportReport({required this.dryRun, required this.issuesTruncated, required this.totalRows, required this.created, required this.existing,
      required this.duplicatesInFile, required this.invalid, required this.issues, required this.preview});
  factory ImportReport.fromJson(Map<String, dynamic> j) => ImportReport(
      dryRun: j['dryRun'] == true, issuesTruncated: j['issuesTruncated'] == true, totalRows: j['totalRows'] ?? 0, created: j['created'] ?? 0, existing: j['existing'] ?? 0,
      duplicatesInFile: j['duplicatesInFile'] ?? 0, invalid: j['invalid'] ?? 0,
      issues: [for (final i in (j['issues'] as List? ?? const [])) (i['row'] as int, i['reason'] as String)],
      preview: [for (final p in (j['preview'] as List? ?? const [])) (p['fullName'] as String, p['phone'] as String)]);
}

class LoginEvent {
  final String outcome;
  final String? ip, userAgent;
  final bool mfaUsed, newDevice;
  final DateTime occurredAt;
  const LoginEvent({required this.outcome, this.ip, this.userAgent, required this.mfaUsed, required this.newDevice, required this.occurredAt});
  factory LoginEvent.fromJson(Map<String, dynamic> j) => LoginEvent(
      outcome: j['outcome'], ip: j['ip'], userAgent: j['userAgent'], mfaUsed: j['mfaUsed'] == true, newDevice: j['newDevice'] == true, occurredAt: DateTime.parse(j['occurredAt']));
}

class LoginHistory {
  final List<LoginEvent> events;
  final int failedSinceLastSuccess;
  final bool newDeviceRecently;
  const LoginHistory(this.events, this.failedSinceLastSuccess, this.newDeviceRecently);
  factory LoginHistory.fromJson(Map<String, dynamic> j) => LoginHistory(
      [for (final e in (j['events'] as List)) LoginEvent.fromJson(e)], j['failedSinceLastSuccess'] ?? 0, j['newDeviceRecently'] == true);
}

class PlanUsage {
  final String planCode;
  final int employees, maxEmployees;
  const PlanUsage(this.planCode, this.employees, this.maxEmployees);
  factory PlanUsage.fromJson(Map<String, dynamic> j) => PlanUsage(j['planCode'], j['employees'], j['maxEmployees']);
}

class Branch {
  final String id, name;
  final String? address;
  final bool active;
  /// ISO weekday (1=Mon..7=Sun) -> ('HH:mm', 'HH:mm'). Missing day = closed.
  final Map<int, (String, String)> hours;
  const Branch({required this.id, required this.name, this.address, this.active = true, required this.hours});
  factory Branch.fromJson(Map<String, dynamic> j) => Branch(
      id: j['id'], name: j['name'], address: j['address'], active: j['active'] != false,
      hours: {for (final h in (j['hours'] as List? ?? const [])) h['dayOfWeek'] as int: ((h['open'] as String).substring(0, 5), (h['close'] as String).substring(0, 5))});
}

class ServiceItem {
  final String id, name;
  final int durationMinutes, bufferMinutes;
  final double price;
  final double? depositPercent; // null = the business default applies
  final bool active;
  const ServiceItem({required this.id, required this.name, required this.durationMinutes, this.bufferMinutes = 0, required this.price, this.depositPercent, this.active = true});
  factory ServiceItem.fromJson(Map<String, dynamic> j) => ServiceItem(id: j['id'], name: j['name'], durationMinutes: j['durationMinutes'], bufferMinutes: j['bufferMinutes'] ?? 0,
      price: _num(j['price']), depositPercent: j['depositPercent'] == null ? null : _num(j['depositPercent']), active: j['active'] != false);
}

class Employee {
  final String id, displayName;
  final bool active;
  final List<String> branchIds, serviceIds;
  const Employee({required this.id, required this.displayName, this.active = true, required this.branchIds, required this.serviceIds});
  factory Employee.fromJson(Map<String, dynamic> j) => Employee(
      id: j['id'], displayName: j['displayName'], active: j['active'] != false, branchIds: List<String>.from(j['branchIds'] ?? const []), serviceIds: List<String>.from(j['serviceIds'] ?? const []));
}

class Slot {
  final DateTime start;   // wall clock in the business timezone (for display)
  final DateTime instant; // the exact UTC moment the server offered (what is sent back when booking)
  final List<String> employeeIds;
  const Slot(this.start, this.instant, this.employeeIds);
  factory Slot.fromJson(Map<String, dynamic> j, {String zone = 'UTC'}) {
    final utc = DateTime.parse(j['start']).toUtc();
    return Slot(wallFromInstant(utc, zone), utc, List<String>.from(j['employeeIds'] ?? const []));
  }
}

/// Normalises typed phone numbers to E.164 for Kazakhstan-style input (8 701 ... / 7 701 ... / +7 701 ...).
String normalizePhone(String raw) {
  var d = raw.replaceAll(RegExp(r'[\s\-()]'), '');
  if (RegExp(r'^8\d{10}$').hasMatch(d)) {
    d = '+7${d.substring(1)}';
  } else if (RegExp(r'^7\d{10}$').hasMatch(d)) {
    d = '+$d';
  }
  return d;
}

final phoneE164 = RegExp(r'^\+[1-9]\d{7,14}$');

class BookingLine {
  final String id, serviceName, employeeName, status;
  final DateTime startsAt; // wall clock in the business timezone
  final double price, netPaid;
  const BookingLine({required this.id, required this.serviceName, required this.employeeName, required this.status, required this.startsAt, required this.price, required this.netPaid});
  factory BookingLine.fromJson(Map<String, dynamic> j, {String zone = 'UTC'}) => BookingLine(id: j['id'], serviceName: j['serviceName'], employeeName: j['employeeName'],
      status: j['status'], startsAt: wallFromInstant(DateTime.parse(j['startsAt']), zone), price: _num(j['price']), netPaid: _num(j['netPaid']));
}

class CustomerStats {
  final int totalBookings, completedVisits, cancelled, noShows, upcoming;
  final DateTime? lastVisit; // wall clock in the business timezone
  final double totalSpent;
  final double? averageSpendPerVisit; // null until there is a completed visit
  const CustomerStats({required this.totalBookings, required this.completedVisits, required this.cancelled, required this.noShows, required this.upcoming,
      this.lastVisit, required this.totalSpent, this.averageSpendPerVisit});
  factory CustomerStats.fromJson(Map<String, dynamic> j, {String zone = 'UTC'}) => CustomerStats(
      totalBookings: j['totalBookings'] ?? 0, completedVisits: j['completedVisits'] ?? 0, cancelled: j['cancelled'] ?? 0, noShows: j['noShows'] ?? 0, upcoming: j['upcoming'] ?? 0,
      lastVisit: j['lastVisit'] == null ? null : wallFromInstant(DateTime.parse(j['lastVisit']), zone), totalSpent: _num(j['totalSpent']),
      averageSpendPerVisit: j['averageSpendPerVisit'] == null ? null : _num(j['averageSpendPerVisit']));
}

class CustomerProfile {
  final Customer customer;
  final bool marketingOptIn;
  final String? notes;
  final CustomerStats stats;
  final List<BookingLine> bookings;
  const CustomerProfile({required this.customer, required this.marketingOptIn, this.notes, required this.stats, required this.bookings});
  factory CustomerProfile.fromJson(Map<String, dynamic> j, {String zone = 'UTC'}) => CustomerProfile(
      customer: Customer.fromJson(j['customer']), marketingOptIn: j['customer']['marketingOptIn'] == true, notes: j['customer']['notes'],
      stats: CustomerStats.fromJson(j['stats'], zone: zone), bookings: [for (final b in (j['bookings'] as List)) BookingLine.fromJson(b, zone: zone)]);
}
