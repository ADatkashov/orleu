import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/data/auth_controller.dart';

/// Admin UI strings. The admin console is an internal tool: English only (documented), kept in one place instead of scattered literals.
class S {
  S._();
  static const title = 'ORLEU Admin';
  static const businesses = 'Businesses', plans = 'Plans', audit = 'Audit log', signOut = 'Sign out', signIn = 'Sign in';
  static const email = 'E-mail', password = 'Password', search = 'Search by name or booking-page slug', required = 'Required';
  static const noAccess = 'This account has no platform role.', noAccessHint = 'Ask a super admin to grant access, or sign in with another account.';
  static const retry = 'Retry', empty = 'Nothing found', previous = 'Previous', next = 'Next', page = 'Page';
  static const changePlan = 'Change plan', plan = 'Plan', expires = 'Expires (optional)', noExpiry = 'No expiry', reason = 'Reason', apply = 'Apply', cancel = 'Cancel';
  static const suspend = 'Suspend business', reactivate = 'Reactivate business', confirm = 'Confirm';
  static const suspendWarn = 'The business loses access immediately and its public booking page goes offline.';
  static const reactivateNote = 'The business regains access. Its booking page stays offline until the owner publishes it again.';
  static const history = 'Subscription history', usage = 'Usage', limits = 'Limits', edit = 'Edit', save = 'Save';
  static const branches = 'Branches', employees = 'Employees', status = 'Status', created = 'Created', published = 'Published';
  static const filterBusiness = 'Business ID (optional)', filterAction = 'Action (optional)', invalidId = 'Not a valid UUID';
  static const readOnly = 'Read-only role: changes require SUPER_ADMIN.';
  static const system = 'system';
  static const users = 'Users', support = 'Support', disable = 'Disable user', enable = 'Enable user', reply = 'Reply', send = 'Send', closeTicket = 'Close ticket', reopen = 'Reopen ticket';
}

class AdminMe {
  final String role;
  final bool canModify;
  const AdminMe(this.role, this.canModify);
  /// Users and support tickets contain personal data: SUPER_ADMIN and PLATFORM_SUPPORT only (the server enforces it too).
  bool get canSeePersonalData => role == 'SUPER_ADMIN' || role == 'PLATFORM_SUPPORT';
}

class AdminBusiness {
  final String id, slug, name, businessType, planCode, status;
  final bool published;
  final DateTime? planExpiresAt;
  final DateTime createdAt;
  const AdminBusiness({required this.id, required this.slug, required this.name, required this.businessType, required this.planCode,
      required this.status, required this.published, this.planExpiresAt, required this.createdAt});
  factory AdminBusiness.fromJson(Map<String, dynamic> j) => AdminBusiness(
      id: j['id'], slug: j['slug'], name: j['name'], businessType: j['businessType'] ?? '', planCode: j['planCode'], status: j['status'],
      published: j['published'] == true, planExpiresAt: j['planExpiresAt'] == null ? null : DateTime.parse(j['planExpiresAt']).toLocal(),
      createdAt: DateTime.parse(j['createdAt']).toLocal());
  bool get suspended => status == 'SUSPENDED';
}

class HistoryEvent {
  final String? fromPlan, reason, actorUserId;
  final String toPlan;
  final DateTime createdAt;
  const HistoryEvent({this.fromPlan, required this.toPlan, this.reason, this.actorUserId, required this.createdAt});
  factory HistoryEvent.fromJson(Map<String, dynamic> j) => HistoryEvent(
      fromPlan: j['fromPlan'], toPlan: j['toPlan'], reason: j['reason'], actorUserId: j['actorUserId'], createdAt: DateTime.parse(j['createdAt']).toLocal());
}

class AdminDetail {
  final AdminBusiness business;
  final String planName;
  final int maxBranches, branches, maxEmployees, employees;
  final String? suspendedReason;
  final List<HistoryEvent> history;
  const AdminDetail({required this.business, required this.planName, required this.maxBranches, required this.branches, required this.maxEmployees,
      required this.employees, this.suspendedReason, required this.history});
  factory AdminDetail.fromJson(Map<String, dynamic> j) => AdminDetail(
      business: AdminBusiness.fromJson(j['business']), planName: j['usage']['planName'], maxBranches: j['usage']['maxBranches'], branches: j['usage']['branches'],
      maxEmployees: j['usage']['maxEmployees'], employees: j['usage']['employees'], suspendedReason: j['suspendedReason'],
      history: [for (final h in (j['history'] as List)) HistoryEvent.fromJson(h)]);
}

class AdminPlan {
  final String code, name;
  final int maxBranches, maxEmployees;
  const AdminPlan(this.code, this.name, this.maxBranches, this.maxEmployees);
  factory AdminPlan.fromJson(Map<String, dynamic> j) => AdminPlan(j['code'], j['name'], j['maxBranches'], j['maxEmployees']);
}

class AuditRow {
  final String id, action;
  final String? businessId, actorUserId, entityType;
  final DateTime createdAt;
  const AuditRow({required this.id, required this.action, this.businessId, this.actorUserId, this.entityType, required this.createdAt});
  factory AuditRow.fromJson(Map<String, dynamic> j) => AuditRow(id: j['id'], action: j['action'], businessId: j['businessId'], actorUserId: j['actorUserId'],
      entityType: j['entityType'], createdAt: DateTime.parse(j['createdAt']).toLocal());
}

const adminPageSize = 20;
typedef BusinessQuery = ({String q, int page});
typedef AuditQuery = ({String businessId, String action, int page});

final adminMeProvider = FutureProvider.autoDispose<AdminMe>((ref) async {
  ref.watch(authControllerProvider);
  final r = await ref.watch(apiClientProvider).run((d) => d.get('/api/v1/admin/me'));
  return AdminMe(r.data['role'], r.data['canModify'] == true);
});

final adminBusinessesProvider = FutureProvider.autoDispose.family<List<AdminBusiness>, BusinessQuery>((ref, k) async {
  final r = await ref.watch(apiClientProvider).run((d) => d.get('/api/v1/admin/businesses',
      queryParameters: {'q': k.q, 'page': k.page, 'size': adminPageSize}));
  return [for (final e in (r.data['items'] as List)) AdminBusiness.fromJson(e)];
});

final adminDetailProvider = FutureProvider.autoDispose.family<AdminDetail, String>((ref, id) async {
  final r = await ref.watch(apiClientProvider).run((d) => d.get('/api/v1/admin/businesses/$id'));
  return AdminDetail.fromJson(r.data);
});

final adminPlansProvider = FutureProvider.autoDispose<List<AdminPlan>>((ref) async {
  final r = await ref.watch(apiClientProvider).run((d) => d.get('/api/v1/admin/plans'));
  return [for (final e in (r.data as List)) AdminPlan.fromJson(e)];
});

final adminAuditProvider = FutureProvider.autoDispose.family<List<AuditRow>, AuditQuery>((ref, k) async {
  final r = await ref.watch(apiClientProvider).run((d) => d.get('/api/v1/admin/audit-logs', queryParameters: {
        if (k.businessId.isNotEmpty) 'businessId': k.businessId,
        if (k.action.isNotEmpty) 'action': k.action,
        'page': k.page, 'size': 50,
      }));
  return [for (final e in (r.data['items'] as List)) AuditRow.fromJson(e)];
});

class AdminActions {
  final Ref ref;
  AdminActions(this.ref);

  Future<void> setPlan(String businessId, String planCode, DateTime? expiresAt, String reason) async {
    await ref.read(apiClientProvider).run((d) => d.post('/api/v1/admin/businesses/$businessId/plan',
        data: {'planCode': planCode, 'expiresAt': ?expiresAt?.toUtc().toIso8601String(), 'reason': reason}));
    ref.invalidate(adminDetailProvider);
    ref.invalidate(adminBusinessesProvider);
  }

  Future<void> suspend(String businessId, String reason) async {
    await ref.read(apiClientProvider).run((d) => d.post('/api/v1/admin/businesses/$businessId/suspend', data: {'reason': reason}));
    ref.invalidate(adminDetailProvider);
    ref.invalidate(adminBusinessesProvider);
  }

  Future<void> reactivate(String businessId) async {
    await ref.read(apiClientProvider).run((d) => d.post('/api/v1/admin/businesses/$businessId/reactivate'));
    ref.invalidate(adminDetailProvider);
    ref.invalidate(adminBusinessesProvider);
  }

  Future<void> updatePlanLimits(String code, int maxBranches, int maxEmployees) async {
    await ref.read(apiClientProvider).run((d) => d.put('/api/v1/admin/plans/$code', data: {'maxBranches': maxBranches, 'maxEmployees': maxEmployees}));
    ref.invalidate(adminPlansProvider);
  }
}

final adminActionsProvider = Provider<AdminActions>((ref) => AdminActions(ref));
