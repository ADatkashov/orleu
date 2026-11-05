import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orleu_mobile/admin/admin_app.dart';
import 'package:orleu_mobile/core/api/token_store.dart';

import 'support/fake_api.dart';

class Backend {
  String role = 'SUPER_ADMIN';
  String plan = 'FREE';
  bool suspended = false;
  Handler? planOverride;
  late final FakeAdapter adapter;

  Map<String, Object?> business() => {
        'id': 'b1', 'slug': 'studio', 'name': 'Studio Almaty', 'businessType': 'BARBERSHOP', 'planCode': plan,
        'status': suspended ? 'SUSPENDED' : 'ACTIVE', 'published': true, 'createdAt': '2026-11-01T10:00:00Z'
      };

  Backend() {
    adapter = FakeAdapter({
      'POST /api/v1/auth/login': (_) => ok(tokenJson),
      'GET /api/v1/me': (_) => ok({'id': 'u1', 'email': 'admin@example.com', 'fullName': 'Admin', 'memberships': []}),
      'GET /api/v1/admin/me': (_) => role == 'NONE' ? err(403, 'FORBIDDEN') : ok({'role': role, 'canModify': role == 'SUPER_ADMIN'}),
      'GET /api/v1/admin/businesses': (_) => ok({'items': [business()], 'page': 0, 'size': 20}),
      'GET /api/v1/admin/businesses/b1': (_) => ok({
            'business': business(), 'suspendedReason': suspended ? 'chargeback fraud' : null,
            'usage': {'planCode': plan, 'planName': plan == 'PRO' ? 'Pro' : 'Free', 'maxBranches': 1, 'branches': 1, 'maxEmployees': 3, 'employees': 2},
            'history': [{'fromPlan': 'FREE', 'toPlan': 'PRO', 'reason': 'trial', 'createdAt': '2026-11-02T10:00:00Z'}],
          }),
      'GET /api/v1/admin/plans': (_) => ok([
            {'code': 'FREE', 'name': 'Free', 'maxBranches': 1, 'maxEmployees': 3, 'priceMonthly': 0, 'currency': 'KZT', 'active': true},
            {'code': 'PRO', 'name': 'Pro', 'maxBranches': 20, 'maxEmployees': 200, 'priceMonthly': 0, 'currency': 'KZT', 'active': true},
          ]),
      'POST /api/v1/admin/businesses/b1/plan': (o) => planOverride?.call(o) ?? (() { plan = (o.data as Map)['planCode']; return ok({}); })(),
      'POST /api/v1/admin/businesses/b1/suspend': (_) { suspended = true; return ok({}); },
      'POST /api/v1/admin/businesses/b1/reactivate': (_) { suspended = false; return ok({}); },
      'PUT /api/v1/admin/plans/FREE': (_) => ok({}),
      'GET /api/v1/admin/audit-logs': (_) => ok({'items': [
            {'id': 'a1', 'businessId': 'b1', 'actorUserId': 'u1', 'action': 'ADMIN_PLAN_CHANGED', 'entityType': 'BUSINESS', 'createdAt': '2026-11-03T10:00:00Z'}
          ], 'page': 0, 'size': 50}),
      'POST /api/v1/auth/logout': (_) => (status: 204, body: null),
    });
  }
}

Future<void> pump(WidgetTester tester, Backend be, {bool signedIn = true, double width = 1280}) async {
  setPhone(tester, width, 900);
  final store = MemoryTokenStore();
  if (signedIn) { store.access = 'a'; store.refresh = 'r'; }
  await tester.pumpWidget(ProviderScope(overrides: overridesFor(be.adapter, store), child: const AdminApp()));
  await tester.pumpAndSettle();
}

Future<void> openDetail(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('biz-b1')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a user without a platform role sees "no access" and can sign out', (tester) async {
    final be = Backend()..role = 'NONE';
    await pump(tester, be, signedIn: false);
    await tester.enterText(find.byKey(const Key('adminEmail')), 'owner@example.com');
    await tester.enterText(find.byKey(const Key('adminPassword')), 'correct-horse-battery');
    await tester.tap(find.byKey(const Key('adminSignIn')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('noAccess')), findsOneWidget);
    expect(find.byKey(const Key('biz-b1')), findsNothing);       // no data was even requested
    expect(be.adapter.calls.where((c) => c.path == '/api/v1/admin/businesses'), isEmpty);
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('adminSignIn')), findsOneWidget);
  });

  testWidgets('super admin: businesses list, role badge, search and pagination state', (tester) async {
    final be = Backend();
    await pump(tester, be);
    expect(find.text('Studio Almaty'), findsOneWidget);
    expect(find.text('SUPER_ADMIN'), findsOneWidget);
    expect(find.byKey(const Key('readOnlyBanner')), findsNothing);
    expect(tester.widget<OutlinedButton>(find.byKey(const Key('nextPage'))).onPressed, isNull);  // fewer than a page
    expect(tester.widget<OutlinedButton>(find.byKey(const Key('prevPage'))).onPressed, isNull);
    await tester.enterText(find.byKey(const Key('businessSearch')), 'studio');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(be.adapter.calls.where((c) => c.path == '/api/v1/admin/businesses').last.queryParameters['q'], 'studio');
  });

  testWidgets('read-only role sees data but no mutation controls', (tester) async {
    final be = Backend()..role = 'PLATFORM_SUPPORT';
    await pump(tester, be);
    expect(find.byKey(const Key('readOnlyBanner')), findsOneWidget);
    await openDetail(tester);
    expect(find.text('Studio Almaty'), findsWidgets);
    expect(find.byKey(const Key('changePlan')), findsNothing);
    expect(find.byKey(const Key('suspend')), findsNothing);
    await tester.tap(find.text('Plans').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('plan-FREE')), findsOneWidget);
    expect(find.byKey(const Key('editPlan-FREE')), findsNothing);
  });

  testWidgets('change plan needs a reason, then sends exactly plan + reason and refreshes the view', (tester) async {
    final be = Backend();
    await pump(tester, be);
    await openDetail(tester);
    expect(find.byKey(const Key('usage-Employees')), findsOneWidget);
    await tester.tap(find.byKey(const Key('changePlan')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('planSelect')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pro (PRO)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('applyPlan')));
    await tester.pump();
    expect(find.text('Required'), findsOneWidget);
    expect(be.adapter.calls.where((c) => c.path.endsWith('/plan')), isEmpty);
    await tester.enterText(find.byKey(const Key('planReason')), 'annual deal');
    await tester.tap(find.byKey(const Key('applyPlan')));
    await tester.pumpAndSettle();
    expect(be.adapter.calls.firstWhere((c) => c.path.endsWith('/plan')).data, {'planCode': 'PRO', 'reason': 'annual deal'});
    expect(find.textContaining('(PRO)'), findsWidgets); // detail reloaded with the new plan
  });

  testWidgets('server-side rejection is shown inside the dialog', (tester) async {
    final be = Backend()..planOverride = (_) => err(400, 'INVALID_EXPIRY');
    await pump(tester, be);
    await openDetail(tester);
    await tester.tap(find.byKey(const Key('changePlan')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('planReason')), 'x');
    await tester.tap(find.byKey(const Key('applyPlan')));
    await tester.pumpAndSettle();
    expect(find.text('The expiry must be in the future.'), findsOneWidget);
    expect(find.byKey(const Key('planReason')), findsOneWidget); // dialog stays open
  });

  testWidgets('suspend is a confirmed, reasoned action; reactivate warns it does not republish', (tester) async {
    final be = Backend();
    await pump(tester, be);
    await openDetail(tester);
    await tester.tap(find.byKey(const Key('suspend')));
    await tester.pumpAndSettle();
    expect(find.textContaining('loses access immediately'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirmSuspend')));   // no reason -> blocked
    await tester.pump();
    expect(be.adapter.calls.where((c) => c.path.endsWith('/suspend')), isEmpty);
    await tester.enterText(find.byKey(const Key('suspendReason')), 'chargeback fraud');
    await tester.tap(find.byKey(const Key('confirmSuspend')));
    await tester.pumpAndSettle();
    expect(be.adapter.calls.firstWhere((c) => c.path.endsWith('/suspend')).data, {'reason': 'chargeback fraud'});
    expect(find.byKey(const Key('suspendedReason')), findsOneWidget);
    expect(find.byKey(const Key('suspend')), findsNothing);

    await tester.tap(find.byKey(const Key('reactivate')));
    await tester.pumpAndSettle();
    expect(find.textContaining('stays offline until the owner publishes'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirmReactivate')));
    await tester.pumpAndSettle();
    expect(be.suspended, isFalse);
    expect(find.byKey(const Key('suspendedReason')), findsNothing);
  });

  testWidgets('plan limits are validated and saved', (tester) async {
    final be = Backend();
    await pump(tester, be);
    await tester.tap(find.text('Plans').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('editPlan-FREE')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('maxBranches')), '0');
    await tester.tap(find.byKey(const Key('saveLimits')));
    await tester.pump();
    expect(find.text('Enter a whole number from 1'), findsOneWidget);
    expect(be.adapter.calls.where((c) => c.method == 'PUT'), isEmpty);
    await tester.enterText(find.byKey(const Key('maxBranches')), '2');
    await tester.enterText(find.byKey(const Key('maxEmployees')), '5');
    await tester.tap(find.byKey(const Key('saveLimits')));
    await tester.pumpAndSettle();
    expect(be.adapter.calls.firstWhere((c) => c.method == 'PUT').data, {'maxBranches': 2, 'maxEmployees': 5});
  });

  testWidgets('audit log: invalid business id is rejected locally, valid one is sent as a filter, detail links with a prefilled filter', (tester) async {
    final be = Backend();
    await pump(tester, be);
    await tester.tap(find.text('Audit log').last);
    await tester.pumpAndSettle();
    expect(find.text('ADMIN_PLAN_CHANGED'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('auditBusiness')), 'not-a-uuid');
    await tester.tap(find.byKey(const Key('auditApply')));
    await tester.pump();
    expect(find.text('Not a valid UUID'), findsOneWidget);
    final before = be.adapter.calls.where((c) => c.path.endsWith('/audit-logs')).length;
    await tester.enterText(find.byKey(const Key('auditBusiness')), '3f2504e0-4f89-11d3-9a0c-0305e82c3301');
    await tester.enterText(find.byKey(const Key('auditAction')), 'ADMIN_PLAN_CHANGED');
    await tester.tap(find.byKey(const Key('auditApply')));
    await tester.pumpAndSettle();
    final q = be.adapter.calls.where((c) => c.path.endsWith('/audit-logs')).last.queryParameters;
    expect(be.adapter.calls.where((c) => c.path.endsWith('/audit-logs')).length, greaterThan(before));
    expect(q['businessId'], '3f2504e0-4f89-11d3-9a0c-0305e82c3301');
    expect(q['action'], 'ADMIN_PLAN_CHANGED');

    await tester.tap(find.text('Businesses').last);
    await tester.pumpAndSettle();
    await openDetail(tester);
    await tester.tap(find.byKey(const Key('viewAudit')));
    await tester.pumpAndSettle();
    expect(be.adapter.calls.where((c) => c.path.endsWith('/audit-logs')).last.queryParameters['businessId'], 'b1');
  });

  testWidgets('narrow screens use bottom navigation and card rows without overflow', (tester) async {
    final be = Backend();
    await pump(tester, be, width: 390);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byKey(const Key('biz-b1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
