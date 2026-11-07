import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../core/api/api_client.dart';
import '../core/data/auth_controller.dart';
import '../core/design/tokens.dart';
import 'admin_data.dart';
import 'admin_widgets.dart';

final _dateTime = DateFormat('yyyy-MM-dd HH:mm');
final _uuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

// ───────────────────────────── login ─────────────────────────────

class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});
  @override
  ConsumerState<AdminLoginScreen> createState() => _LoginState();
}

class _LoginState extends ConsumerState<AdminLoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController(), _password = TextEditingController(), _code = TextEditingController();
  bool _busy = false;
  String? _error, _mfaToken;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    String? pending;
    final err = await adminAttempt(() async {
      try {
        await ref.read(authControllerProvider.notifier).login(_email.text.trim(), _password.text);
      } on MfaRequired catch (m) {
        pending = m.token;
      }
    });
    if (mounted) setState(() { _busy = false; _error = err; if (pending != null) { _mfaToken = pending; _code.clear(); } });
  }

  Future<void> _verify() async {
    setState(() { _busy = true; _error = null; });
    final err = await adminAttempt(() => ref.read(authControllerProvider.notifier).verifyMfa(_mfaToken!, _code.text.trim()));
    if (mounted) setState(() { _busy = false; _error = err; if (err != null && err.contains('expired')) _mfaToken = null; });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    if (_mfaToken != null) {
      return Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('ORLEU', style: t.textTheme.headlineMedium?.copyWith(color: t.colorScheme.primary, letterSpacing: 4)),
                const SizedBox(height: AppSpacing.lg),
                const Text('Enter the code from your authenticator app, or a recovery code.', key: Key('adminMfaPrompt')),
                const SizedBox(height: AppSpacing.md),
                TextField(key: const Key('adminMfaCode'), controller: _code, autofocus: true, decoration: const InputDecoration(labelText: '6-digit code'), onSubmitted: (_) => _verify()),
                InlineError(_error),
                const SizedBox(height: AppSpacing.lg),
                FilledButton(key: const Key('adminMfaVerify'), onPressed: _busy ? null : _verify, child: const Text('Verify')),
                TextButton(onPressed: () => setState(() { _mfaToken = null; _error = null; }), child: const Text('Back')),
              ]),
            ),
          ),
        ),
      );
    }
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Form(
              key: _form,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('ORLEU', style: t.textTheme.headlineMedium?.copyWith(color: t.colorScheme.primary, letterSpacing: 4)),
                Text(S.title, style: t.textTheme.bodyMedium),
                const SizedBox(height: AppSpacing.xl),
                TextFormField(key: const Key('adminEmail'), controller: _email, decoration: const InputDecoration(labelText: S.email),
                    validator: (v) => v == null || v.trim().isEmpty ? S.required : null),
                const SizedBox(height: AppSpacing.md),
                TextFormField(key: const Key('adminPassword'), controller: _password, obscureText: true, decoration: const InputDecoration(labelText: S.password),
                    validator: (v) => v == null || v.isEmpty ? S.required : null, onFieldSubmitted: (_) => _submit()),
                InlineError(_error),
                const SizedBox(height: AppSpacing.lg),
                FilledButton(key: const Key('adminSignIn'), onPressed: _busy ? null : _submit, child: const Text(S.signIn)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────── shell ─────────────────────────────

class AdminShell extends ConsumerWidget {
  final String location;
  final Widget child;
  const AdminShell({super.key, required this.location, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(adminMeProvider);
    return me.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => ApiError.from(e).status == 403
          ? Scaffold(
              body: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.lock_outline, size: 48),
                  const SizedBox(height: AppSpacing.md),
                  const Text(S.noAccess, key: Key('noAccess')),
                  const SizedBox(height: AppSpacing.sm),
                  const Text(S.noAccessHint),
                  const SizedBox(height: AppSpacing.lg),
                  OutlinedButton(onPressed: () => ref.read(authControllerProvider.notifier).logout(), child: const Text(S.signOut)),
                ]),
              ),
            )
          : Scaffold(body: AdminError(error: e, onRetry: () => ref.invalidate(adminMeProvider))),
      data: (m) {
        final items = [
          (Icons.storefront_outlined, S.businesses, '/businesses'),
          (Icons.workspace_premium_outlined, S.plans, '/plans'),
          if (m.canSeePersonalData) (Icons.people_outline, S.users, '/users'),
          if (m.canSeePersonalData) (Icons.support_agent_outlined, S.support, '/support'),
          if (m.canSeePersonalData) (Icons.star_outline, S.reviews, '/reviews'),
          (Icons.fact_check_outlined, S.audit, '/audit'),
        ];
        final index = items.indexWhere((i) => location.startsWith(i.$3)).clamp(0, items.length - 1);
        final wide = MediaQuery.sizeOf(context).width >= 900;
        final header = Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: Row(children: [
            const Expanded(child: Text(S.title, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700))),
            Pill(m.role, m.canModify ? AppColors.primaryGreen : AppColors.warning, key: const Key('roleBadge')),
            const SizedBox(width: AppSpacing.sm),
            TextButton(key: const Key('signOut'), onPressed: () => ref.read(authControllerProvider.notifier).logout(), child: const Text(S.signOut)),
          ]),
        );
        final body = Column(children: [
          header,
          const Divider(),
          if (!m.canModify) Container(width: double.infinity, color: AppColors.warning.withValues(alpha: 0.12), padding: const EdgeInsets.all(8), child: const Text(S.readOnly, key: Key('readOnlyBanner'))),
          Expanded(child: child),
        ]);
        if (wide) {
          return Scaffold(
            body: Row(children: [
              NavigationRail(
                selectedIndex: index, labelType: NavigationRailLabelType.all,
                onDestinationSelected: (i) => context.go(items[i].$3),
                destinations: [for (final i in items) NavigationRailDestination(icon: Icon(i.$1), label: Text(i.$2))],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: body),
            ]),
          );
        }
        return Scaffold(
          body: SafeArea(child: body),
          bottomNavigationBar: NavigationBar(
            selectedIndex: index, onDestinationSelected: (i) => context.go(items[i].$3),
            destinations: [for (final i in items) NavigationDestination(icon: Icon(i.$1), label: i.$2)],
          ),
        );
      },
    );
  }
}

// ───────────────────────────── businesses ─────────────────────────────

class BusinessesScreen extends ConsumerStatefulWidget {
  const BusinessesScreen({super.key});
  @override
  ConsumerState<BusinessesScreen> createState() => _BusinessesState();
}

class _BusinessesState extends ConsumerState<BusinessesScreen> {
  String _q = '';
  int _page = 0;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final res = ref.watch(adminBusinessesProvider((q: _q, page: _page)));
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(S.businesses, style: t.textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: 420,
          child: TextField(
            key: const Key('businessSearch'),
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: S.search),
            onChanged: (v) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 350), () => setState(() { _q = v.trim(); _page = 0; }));
            },
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: res.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => AdminError(error: e, onRetry: () => ref.invalidate(adminBusinessesProvider)),
            data: (list) => Column(children: [
              Expanded(
                child: list.isEmpty
                    ? const Center(child: Text(S.empty))
                    : ListView.separated(
                        itemCount: list.length + (wide ? 1 : 0),
                        separatorBuilder: (_, _) => const Divider(),
                        itemBuilder: (_, i) {
                          if (wide && i == 0) return const _Header();
                          final b = list[wide ? i - 1 : i];
                          return wide ? _Row(b) : _Card(b);
                        },
                      ),
              ),
              Pager(page: _page, hasNext: list.length == adminPageSize, onPage: (p) => setState(() => _page = p)),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();
  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).textTheme.labelLarge;
    Widget c(String t, int flex) => Expanded(flex: flex, child: Text(t, style: s));
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Row(children: [c('Business', 4), c(S.plan, 2), c(S.status, 2), c(S.published, 2), c(S.created, 3)]));
  }
}

class _Row extends StatelessWidget {
  final AdminBusiness b;
  const _Row(this.b);
  @override
  Widget build(BuildContext context) => InkWell(
        key: Key('biz-${b.id}'),
        onTap: () => context.go('/businesses/${b.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(flex: 4, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(b.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('/b/${b.slug}', style: Theme.of(context).textTheme.bodySmall),
            ])),
            Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: Pill(b.planCode, AppColors.primaryGreen))),
            Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: statusBadge(b.status))),
            Expanded(flex: 2, child: Text(b.published ? 'Yes' : 'No')),
            Expanded(flex: 3, child: Text(_dateTime.format(b.createdAt))),
          ]),
        ),
      );
}

class _Card extends StatelessWidget {
  final AdminBusiness b;
  const _Card(this.b);
  @override
  Widget build(BuildContext context) => ListTile(
        key: Key('biz-${b.id}'),
        title: Text(b.name),
        subtitle: Text('/b/${b.slug} · ${b.planCode}'),
        trailing: statusBadge(b.status),
        onTap: () => context.go('/businesses/${b.id}'),
      );
}

// ───────────────────────────── business detail ─────────────────────────────

class BusinessDetailScreen extends ConsumerWidget {
  final String id;
  const BusinessDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final canModify = ref.watch(adminMeProvider).value?.canModify ?? false;
    final res = ref.watch(adminDetailProvider(id));
    return res.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AdminError(error: e, onRetry: () => ref.invalidate(adminDetailProvider)),
      data: (d) {
        final b = d.business;
        Widget usage(String label, int used, int max) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$label: $used / $max', key: Key('usage-$label')),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: max == 0 ? 0 : (used / max).clamp(0, 1).toDouble(), minHeight: 6, borderRadius: BorderRadius.circular(3),
                  color: used >= max ? AppColors.warning : Theme.of(context).colorScheme.primary, backgroundColor: Theme.of(context).colorScheme.outline,
                ),
              ]),
            );
        return ListView(padding: const EdgeInsets.all(AppSpacing.md), children: [
          Row(children: [
            IconButton(tooltip: S.businesses, icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/businesses')),
            Expanded(child: Text(b.name, style: t.textTheme.headlineMedium)),
            statusBadge(b.status),
          ]),
          Text('/b/${b.slug} · ${b.businessType} · ${S.created} ${_dateTime.format(b.createdAt)}', style: t.textTheme.bodySmall),
          if (b.suspended) Card(
            color: AppColors.danger.withValues(alpha: 0.10),
            child: Padding(padding: const EdgeInsets.all(12), child: Text('Suspended: ${d.suspendedReason ?? ''}', key: const Key('suspendedReason'))),
          ),
          const SizedBox(height: AppSpacing.md),
          Card(child: Padding(padding: const EdgeInsets.all(AppSpacing.md), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(S.usage, style: t.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Text('${S.plan}: ${d.planName} (${b.planCode})${b.planExpiresAt == null ? '' : ' · until ${_dateTime.format(b.planExpiresAt!)}'}', key: const Key('planLine')),
            const SizedBox(height: AppSpacing.sm),
            usage(S.branches, d.branches, d.maxBranches),
            usage(S.employees, d.employees, d.maxEmployees),
            if (canModify) FilledButton.tonal(key: const Key('changePlan'), onPressed: () => showDialog(context: context, builder: (_) => ChangePlanDialog(businessId: id, current: b.planCode)), child: const Text(S.changePlan)),
          ]))),
          const SizedBox(height: AppSpacing.md),
          if (canModify) Card(child: Padding(padding: const EdgeInsets.all(AppSpacing.md), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(S.status, style: t.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            if (!b.suspended)
              OutlinedButton(
                key: const Key('suspend'),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                onPressed: () => showDialog(context: context, builder: (_) => SuspendDialog(businessId: id, name: b.name)),
                child: const Text(S.suspend),
              )
            else
              OutlinedButton(key: const Key('reactivate'), onPressed: () => showDialog(context: context, builder: (_) => ReactivateDialog(businessId: id, name: b.name)), child: const Text(S.reactivate)),
          ]))),
          const SizedBox(height: AppSpacing.md),
          Card(child: Padding(padding: const EdgeInsets.all(AppSpacing.md), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(S.history, style: t.textTheme.titleMedium)),
              TextButton(key: const Key('viewAudit'), onPressed: () => context.go('/audit?businessId=$id'), child: const Text(S.audit)),
            ]),
            if (d.history.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text(S.empty)),
            for (final h in d.history) ListTile(
              dense: true, contentPadding: EdgeInsets.zero,
              title: Text('${h.fromPlan ?? '—'} → ${h.toPlan}'),
              subtitle: Text('${h.reason ?? ''} · ${_dateTime.format(h.createdAt)} · ${h.actorUserId ?? S.system}'),
            ),
          ]))),
        ]);
      },
    );
  }
}

class ChangePlanDialog extends ConsumerStatefulWidget {
  final String businessId, current;
  const ChangePlanDialog({super.key, required this.businessId, required this.current});
  @override
  ConsumerState<ChangePlanDialog> createState() => _ChangePlanState();
}

class _ChangePlanState extends ConsumerState<ChangePlanDialog> {
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();
  late String _plan = widget.current;
  DateTime? _expires;
  bool _busy = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final plans = ref.watch(adminPlansProvider).value ?? const <AdminPlan>[];
    return AlertDialog(
      title: const Text(S.changePlan),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _form,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              key: const Key('planSelect'), initialValue: plans.any((p) => p.code == _plan) ? _plan : null, decoration: const InputDecoration(labelText: S.plan),
              items: [for (final p in plans) DropdownMenuItem(value: p.code, child: Text('${p.name} (${p.code})'))],
              onChanged: (v) => setState(() => _plan = v ?? _plan),
            ),
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                key: const Key('pickExpiry'), icon: const Icon(Icons.event), label: Text(_expires == null ? S.noExpiry : DateFormat('yyyy-MM-dd').format(_expires!)),
                onPressed: () async {
                  final d = await showDatePicker(context: context, initialDate: DateTime.now().add(const Duration(days: 30)), firstDate: DateTime.now().add(const Duration(days: 1)), lastDate: DateTime.now().add(const Duration(days: 3650)));
                  if (d != null) setState(() => _expires = DateTime(d.year, d.month, d.day, 23, 59));
                },
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(key: const Key('planReason'), controller: _reason, decoration: const InputDecoration(labelText: S.reason), maxLength: 300,
                validator: (v) => v == null || v.trim().isEmpty ? S.required : null),
            InlineError(_error),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text(S.cancel)),
        FilledButton(
          key: const Key('applyPlan'), style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
          onPressed: _busy ? null : () async {
            if (!_form.currentState!.validate()) return;
            setState(() { _busy = true; _error = null; });
            final err = await adminAttempt(() => ref.read(adminActionsProvider).setPlan(widget.businessId, _plan, _expires, _reason.text.trim()));
            if (!context.mounted) return;
            if (err == null) { Navigator.pop(context); } else { setState(() { _busy = false; _error = err; }); }
          },
          child: const Text(S.apply),
        ),
      ],
    );
  }
}

class SuspendDialog extends ConsumerStatefulWidget {
  final String businessId, name;
  const SuspendDialog({super.key, required this.businessId, required this.name});
  @override
  ConsumerState<SuspendDialog> createState() => _SuspendState();
}

class _SuspendState extends ConsumerState<SuspendDialog> {
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('${S.suspend}: ${widget.name}'),
        content: SizedBox(
          width: 420,
          child: Form(
            key: _form,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text(S.suspendWarn),
              const SizedBox(height: AppSpacing.md),
              TextFormField(key: const Key('suspendReason'), controller: _reason, decoration: const InputDecoration(labelText: S.reason), maxLength: 300,
                  validator: (v) => v == null || v.trim().isEmpty ? S.required : null),
              InlineError(_error),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text(S.cancel)),
          FilledButton(
            key: const Key('confirmSuspend'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white, minimumSize: const Size(96, 44)),
            onPressed: _busy ? null : () async {
              if (!_form.currentState!.validate()) return;
              setState(() { _busy = true; _error = null; });
              final err = await adminAttempt(() => ref.read(adminActionsProvider).suspend(widget.businessId, _reason.text.trim()));
              if (!context.mounted) return;
              if (err == null) { Navigator.pop(context); } else { setState(() { _busy = false; _error = err; }); }
            },
            child: const Text(S.suspend),
          ),
        ],
      );
}

class ReactivateDialog extends ConsumerStatefulWidget {
  final String businessId, name;
  const ReactivateDialog({super.key, required this.businessId, required this.name});
  @override
  ConsumerState<ReactivateDialog> createState() => _ReactivateState();
}

class _ReactivateState extends ConsumerState<ReactivateDialog> {
  bool _busy = false;
  String? _error;

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('${S.reactivate}: ${widget.name}'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [const Text(S.reactivateNote), InlineError(_error)]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text(S.cancel)),
          FilledButton(
            key: const Key('confirmReactivate'),
            onPressed: _busy ? null : () async {
              setState(() { _busy = true; _error = null; });
              final err = await adminAttempt(() => ref.read(adminActionsProvider).reactivate(widget.businessId));
              if (!context.mounted) return;
              if (err == null) { Navigator.pop(context); } else { setState(() { _busy = false; _error = err; }); }
            },
            child: const Text(S.confirm),
          ),
        ],
      );
}

// ───────────────────────────── plans ─────────────────────────────

class PlansScreen extends ConsumerWidget {
  const PlansScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canModify = ref.watch(adminMeProvider).value?.canModify ?? false;
    final res = ref.watch(adminPlansProvider);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(S.plans, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: res.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => AdminError(error: e, onRetry: () => ref.invalidate(adminPlansProvider)),
            data: (list) => ListView(children: [
              for (final p in list) Card(
                child: ListTile(
                  key: Key('plan-${p.code}'),
                  title: Text('${p.name} (${p.code})'),
                  subtitle: Text('${S.branches}: up to ${p.maxBranches} · ${S.employees}: up to ${p.maxEmployees}'),
                  trailing: canModify ? TextButton(key: Key('editPlan-${p.code}'), onPressed: () => showDialog(context: context, builder: (_) => PlanLimitsDialog(plan: p)), child: const Text(S.edit)) : null,
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class PlanLimitsDialog extends ConsumerStatefulWidget {
  final AdminPlan plan;
  const PlanLimitsDialog({super.key, required this.plan});
  @override
  ConsumerState<PlanLimitsDialog> createState() => _PlanLimitsState();
}

class _PlanLimitsState extends ConsumerState<PlanLimitsDialog> {
  final _form = GlobalKey<FormState>();
  late final _branches = TextEditingController(text: '${widget.plan.maxBranches}');
  late final _employees = TextEditingController(text: '${widget.plan.maxEmployees}');
  bool _busy = false;
  String? _error;

  String? _v(String? v) {
    final n = int.tryParse(v ?? '');
    return n == null || n < 1 || n > 100000 ? 'Enter a whole number from 1' : null;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('${S.limits}: ${widget.plan.code}'),
        content: Form(
          key: _form,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(key: const Key('maxBranches'), controller: _branches, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: S.branches), validator: _v),
            const SizedBox(height: AppSpacing.md),
            TextFormField(key: const Key('maxEmployees'), controller: _employees, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: S.employees), validator: _v),
            InlineError(_error),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text(S.cancel)),
          FilledButton(
            key: const Key('saveLimits'), style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
            onPressed: _busy ? null : () async {
              if (!_form.currentState!.validate()) return;
              setState(() { _busy = true; _error = null; });
              final err = await adminAttempt(() => ref.read(adminActionsProvider).updatePlanLimits(widget.plan.code, int.parse(_branches.text), int.parse(_employees.text)));
              if (!context.mounted) return;
              if (err == null) { Navigator.pop(context); } else { setState(() { _busy = false; _error = err; }); }
            },
            child: const Text(S.save),
          ),
        ],
      );
}

// ───────────────────────────── audit ─────────────────────────────

class AuditScreen extends ConsumerStatefulWidget {
  final String initialBusinessId;
  const AuditScreen({super.key, this.initialBusinessId = ''});
  @override
  ConsumerState<AuditScreen> createState() => _AuditState();
}

class _AuditState extends ConsumerState<AuditScreen> {
  late final _business = TextEditingController(text: widget.initialBusinessId);
  final _action = TextEditingController();
  late String _bizFilter = widget.initialBusinessId;
  String _actionFilter = '';
  int _page = 0;
  String? _idError;

  void _apply() {
    final id = _business.text.trim();
    if (id.isNotEmpty && !_uuid.hasMatch(id)) {
      setState(() => _idError = S.invalidId);
      return;
    }
    setState(() { _idError = null; _bizFilter = id; _actionFilter = _action.text.trim(); _page = 0; });
  }

  @override
  Widget build(BuildContext context) {
    final res = ref.watch(adminAuditProvider((businessId: _bizFilter, action: _actionFilter, page: _page)));
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(S.audit, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.md),
        Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, crossAxisAlignment: WrapCrossAlignment.start, children: [
          SizedBox(width: 340, child: TextField(key: const Key('auditBusiness'), controller: _business, decoration: InputDecoration(labelText: S.filterBusiness, errorText: _idError), onSubmitted: (_) => _apply())),
          SizedBox(width: 260, child: TextField(key: const Key('auditAction'), controller: _action, decoration: const InputDecoration(labelText: S.filterAction), onSubmitted: (_) => _apply())),
          FilledButton(key: const Key('auditApply'), style: FilledButton.styleFrom(minimumSize: const Size(96, 52)), onPressed: _apply, child: const Text('Filter')),
        ]),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: res.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => AdminError(error: e, onRetry: () => ref.invalidate(adminAuditProvider)),
            data: (rows) => Column(children: [
              Expanded(
                child: rows.isEmpty
                    ? const Center(child: Text(S.empty))
                    : ListView.separated(
                        itemCount: rows.length,
                        separatorBuilder: (_, _) => const Divider(),
                        itemBuilder: (_, i) => ListTile(
                          dense: true,
                          title: Text(rows[i].action, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('${rows[i].entityType ?? ''} · actor ${rows[i].actorUserId ?? S.system} · business ${rows[i].businessId ?? '—'}'),
                          trailing: Text(_dateTime.format(rows[i].createdAt)),
                        ),
                      ),
              ),
              Pager(page: _page, hasNext: rows.length == 50, onPage: (p) => setState(() => _page = p)),
            ]),
          ),
        ),
      ]),
    );
  }
}
