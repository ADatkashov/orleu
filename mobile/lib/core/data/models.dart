/// Plain immutable models mirroring the backend DTOs. Money stays as decimal strings -> num only for display.
double _num(Object? v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

class Business {
  final String id, name, slug, currency, planCode;
  final bool published;
  const Business({required this.id, required this.name, required this.slug, required this.currency, required this.planCode, required this.published});
  factory Business.fromJson(Map<String, dynamic> j) => Business(
      id: j['id'], name: j['name'], slug: j['slug'], currency: j['currency'] ?? 'KZT', planCode: j['planCode'] ?? 'FREE', published: j['published'] == true);
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
  final DateTime startsAt, endsAt;
  final Financials financials;
  const Booking({required this.branchId, required this.serviceId, required this.employeeId, required this.id, required this.serviceName, required this.employeeName, required this.customerName, required this.customerPhone,
      required this.status, required this.currency, required this.startsAt, required this.endsAt, required this.financials});
  factory Booking.fromJson(Map<String, dynamic> j) => Booking(
      branchId: j['branchId'], serviceId: j['serviceId'], employeeId: j['employeeId'], id: j['id'], serviceName: j['serviceName'], employeeName: j['employeeName'], customerName: j['customerName'], customerPhone: j['customerPhone'],
      status: j['status'], currency: j['currency'], startsAt: DateTime.parse(j['startsAt']).toLocal(), endsAt: DateTime.parse(j['endsAt']).toLocal(),
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

class PlanUsage {
  final String planCode;
  final int employees, maxEmployees;
  const PlanUsage(this.planCode, this.employees, this.maxEmployees);
  factory PlanUsage.fromJson(Map<String, dynamic> j) => PlanUsage(j['planCode'], j['employees'], j['maxEmployees']);
}

class Branch {
  final String id, name;
  final String? address;
  /// ISO weekday (1=Mon..7=Sun) -> ('HH:mm', 'HH:mm'). Missing day = closed.
  final Map<int, (String, String)> hours;
  const Branch({required this.id, required this.name, this.address, required this.hours});
  factory Branch.fromJson(Map<String, dynamic> j) => Branch(
      id: j['id'], name: j['name'], address: j['address'],
      hours: {for (final h in (j['hours'] as List? ?? const [])) h['dayOfWeek'] as int: ((h['open'] as String).substring(0, 5), (h['close'] as String).substring(0, 5))});
}

class ServiceItem {
  final String id, name;
  final int durationMinutes;
  final double price;
  const ServiceItem({required this.id, required this.name, required this.durationMinutes, required this.price});
  factory ServiceItem.fromJson(Map<String, dynamic> j) => ServiceItem(id: j['id'], name: j['name'], durationMinutes: j['durationMinutes'], price: _num(j['price']));
}

class Employee {
  final String id, displayName;
  final List<String> branchIds, serviceIds;
  const Employee({required this.id, required this.displayName, required this.branchIds, required this.serviceIds});
  factory Employee.fromJson(Map<String, dynamic> j) => Employee(
      id: j['id'], displayName: j['displayName'], branchIds: List<String>.from(j['branchIds'] ?? const []), serviceIds: List<String>.from(j['serviceIds'] ?? const []));
}

class Slot {
  final DateTime start; // device-local; the API sends UTC instants
  final List<String> employeeIds;
  const Slot(this.start, this.employeeIds);
  factory Slot.fromJson(Map<String, dynamic> j) => Slot(DateTime.parse(j['start']).toLocal(), List<String>.from(j['employeeIds'] ?? const []));
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
