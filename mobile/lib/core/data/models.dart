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
  final String id, serviceName, employeeName, customerName, customerPhone, status, currency;
  final DateTime startsAt, endsAt;
  final Financials financials;
  const Booking({required this.id, required this.serviceName, required this.employeeName, required this.customerName, required this.customerPhone,
      required this.status, required this.currency, required this.startsAt, required this.endsAt, required this.financials});
  factory Booking.fromJson(Map<String, dynamic> j) => Booking(
      id: j['id'], serviceName: j['serviceName'], employeeName: j['employeeName'], customerName: j['customerName'], customerPhone: j['customerPhone'],
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
