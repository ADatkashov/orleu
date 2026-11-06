import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../core/data/auth_controller.dart';
import '../core/design/tokens.dart';
import 'admin_data.dart';
import 'admin_widgets.dart';

final _dt = DateFormat('yyyy-MM-dd HH:mm');

class AdminUser {
  final String id, email, fullName, status;
  final String? platformRole;
  final int businesses;
  final DateTime createdAt;
  const AdminUser({required this.id, required this.email, required this.fullName, required this.status, this.platformRole, required this.businesses, required this.createdAt});
  factory AdminUser.fromJson(Map<String, dynamic> j) => AdminUser(
      id: j['id'], email: j['email'], fullName: j['fullName'] ?? '', status: j['status'], platformRole: j['platformRole'], businesses: j['businesses'] ?? 0,
      createdAt: DateTime.parse(j['createdAt']).toLocal());
  bool get disabled => status == 'DISABLED';
}

class AdminTicket {
  final String id, businessName, subject, category, status, createdByEmail;
  final DateTime updatedAt;
  const AdminTicket({required this.id, required this.businessName, required this.subject, required this.category, required this.status, required this.createdByEmail, required this.updatedAt});
  factory AdminTicket.fromJson(Map<String, dynamic> j) => AdminTicket(
      id: j['id'], businessName: j['businessName'] ?? '', subject: j['subject'], category: j['category'], status: j['status'], createdByEmail: j['createdByEmail'] ?? '',
      updatedAt: DateTime.parse(j['updatedAt']).toLocal());
}

class TicketMessage {
  final bool fromPlatform;
  final String authorName, body;
  final DateTime createdAt;
  const TicketMessage({required this.fromPlatform, required this.authorName, required this.body, required this.createdAt});
  factory TicketMessage.fromJson(Map<String, dynamic> j) =>
      TicketMessage(fromPlatform: j['fromPlatform'] == true, authorName: j['authorName'] ?? '', body: j['body'], createdAt: DateTime.parse(j['createdAt']).toLocal());
}

class AdminTicketDetail {
  final AdminTicket ticket;
  final List<TicketMessage> messages;
  const AdminTicketDetail(this.ticket, this.messages);
  factory AdminTicketDetail.fromJson(Map<String, dynamic> j) =>
      AdminTicketDetail(AdminTicket.fromJson(j['ticket']), [for (final m in (j['messages'] as List)) TicketMessage.fromJson(m)]);
}

typedef UserQuery = ({String q, int page});
typedef TicketQuery = ({String status, int page});

final adminUsersProvider = FutureProvider.autoDispose.family<List<AdminUser>, UserQuery>((ref, k) async {
  final r = await ref.watch(apiClientProvider).run((d) => d.get('/api/v1/admin/users', queryParameters: {'q': k.q, 'page': k.page, 'size': adminPageSize}));
  return [for (final e in (r.data['items'] as List)) AdminUser.fromJson(e)];
});

final adminTicketsProvider = FutureProvider.autoDispose.family<List<AdminTicket>, TicketQuery>((ref, k) async {
  final r = await ref.watch(apiClientProvider).run((d) => d.get('/api/v1/admin/support/tickets',
      queryParameters: {if (k.status.isNotEmpty) 'status': k.status, 'page': k.page, 'size': adminPageSize}));
  return [for (final e in (r.data as List)) AdminTicket.fromJson(e)];
});

final adminTicketProvider = FutureProvider.autoDispose.family<AdminTicketDetail, String>((ref, id) async {
  final r = await ref.watch(apiClientProvider).run((d) => d.get('/api/v1/admin/support/tickets/$id'));
  return AdminTicketDetail.fromJson(r.data);
});

Future<void> setUserDisabled(WidgetRef ref, String id, bool disable) async {
  await ref.read(apiClientProvider).run((d) => d.post('/api/v1/admin/users/$id/${disable ? 'disable' : 'enable'}'));
  ref.invalidate(adminUsersProvider);
}

Future<void> replyToTicket(WidgetRef ref, String id, String body) async {
  await ref.read(apiClientProvider).run((d) => d.post('/api/v1/admin/support/tickets/$id/reply', data: {'body': body}));
  ref.invalidate(adminTicketProvider);
  ref.invalidate(adminTicketsProvider);
}

Future<void> setTicketStatus(WidgetRef ref, String id, String status) async {
  await ref.read(apiClientProvider).run((d) => d.post('/api/v1/admin/support/tickets/$id/status', data: {'status': status}));
  ref.invalidate(adminTicketProvider);
  ref.invalidate(adminTicketsProvider);
}

Color _statusColor(String s) => switch (s) { 'OPEN' => AppColors.warning, 'ANSWERED' => AppColors.primaryGreen, _ => AppColors.textSecondary };

// ---------------- users ----------------

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});
  @override
  ConsumerState<AdminUsersScreen> createState() => _UsersState();
}

class _UsersState extends ConsumerState<AdminUsersScreen> {
  String _q = '';
  int _page = 0;
  Timer? _debounce;
  String? _error;

  @override
  void dispose() { _debounce?.cancel(); super.dispose(); }

  Future<void> _toggle(AdminUser u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(u.disabled ? S.enable : S.disable),
        content: Text(u.disabled ? '${u.email} will be able to sign in again.' : '${u.email} is signed out everywhere and cannot sign in until enabled.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text(S.cancel)), FilledButton(key: const Key('confirmToggle'), onPressed: () => Navigator.pop(ctx, true), child: const Text(S.confirm))],
      ),
    );
    if (ok != true) return;
    final err = await adminAttempt(() => setUserDisabled(ref, u.id, !u.disabled));
    if (mounted) setState(() => _error = err);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final canModify = ref.watch(adminMeProvider).value?.canModify ?? false;
    final res = ref.watch(adminUsersProvider((q: _q, page: _page)));
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(S.users, style: t.textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: 420,
          child: TextField(
            key: const Key('userSearch'),
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search by e-mail or name'),
            onChanged: (v) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 350), () => setState(() { _q = v.trim(); _page = 0; }));
            },
          ),
        ),
        InlineError(_error),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: res.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => AdminError(error: e, onRetry: () => ref.invalidate(adminUsersProvider)),
            data: (list) => Column(children: [
              Expanded(
                child: list.isEmpty
                    ? const Center(child: Text(S.empty))
                    : ListView.separated(
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const Divider(),
                        itemBuilder: (_, i) {
                          final u = list[i];
                          return ListTile(
                            key: Key('user-${u.email}'),
                            title: Text(u.email, overflow: TextOverflow.ellipsis),
                            subtitle: Text('${u.fullName} · ${u.businesses} business(es) · ${_dt.format(u.createdAt)}', overflow: TextOverflow.ellipsis),
                            trailing: Wrap(spacing: AppSpacing.sm, crossAxisAlignment: WrapCrossAlignment.center, children: [
                              if (u.platformRole != null) Pill(u.platformRole!, AppColors.primaryGreen),
                              Pill(u.status, u.disabled ? AppColors.danger : AppColors.primaryGreen),
                              if (canModify) TextButton(key: Key('toggle-${u.email}'), onPressed: () => _toggle(u), child: Text(u.disabled ? S.enable : S.disable)),
                            ]),
                          );
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

// ---------------- support ----------------

class AdminSupportScreen extends ConsumerStatefulWidget {
  const AdminSupportScreen({super.key});
  @override
  ConsumerState<AdminSupportScreen> createState() => _SupportState();
}

class _SupportState extends ConsumerState<AdminSupportScreen> {
  String _status = 'OPEN';
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final res = ref.watch(adminTicketsProvider((status: _status, page: _page)));
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(S.support, style: t.textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.md),
        Wrap(spacing: AppSpacing.sm, children: [
          for (final s in const [('OPEN', 'Open'), ('ANSWERED', 'Answered'), ('CLOSED', 'Closed'), ('', 'All')])
            ChoiceChip(key: Key('filter-${s.$1}'), label: Text(s.$2), selected: _status == s.$1, onSelected: (_) => setState(() { _status = s.$1; _page = 0; })),
        ]),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: res.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => AdminError(error: e, onRetry: () => ref.invalidate(adminTicketsProvider)),
            data: (list) => Column(children: [
              Expanded(
                child: list.isEmpty
                    ? const Center(child: Text(S.empty))
                    : ListView.separated(
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const Divider(),
                        itemBuilder: (_, i) {
                          final x = list[i];
                          return ListTile(
                            key: Key('ticket-${x.id}'),
                            title: Text(x.subject, overflow: TextOverflow.ellipsis),
                            subtitle: Text('${x.businessName} · ${x.category} · ${_dt.format(x.updatedAt)}', overflow: TextOverflow.ellipsis),
                            trailing: Pill(x.status, _statusColor(x.status)),
                            onTap: () => context.go('/support/${x.id}'),
                          );
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

class AdminTicketScreen extends ConsumerStatefulWidget {
  final String id;
  const AdminTicketScreen({super.key, required this.id});
  @override
  ConsumerState<AdminTicketScreen> createState() => _TicketState();
}

class _TicketState extends ConsumerState<AdminTicketScreen> {
  final _body = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _run(Future<void> Function() a, {bool clear = false}) async {
    setState(() { _busy = true; _error = null; });
    final err = await adminAttempt(a);
    if (!mounted) return;
    setState(() { _busy = false; _error = err; });
    if (err == null && clear) _body.clear();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final canReply = ref.watch(adminMeProvider).value?.canSeePersonalData ?? false;
    final res = ref.watch(adminTicketProvider(widget.id));
    return res.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AdminError(error: e, onRetry: () => ref.invalidate(adminTicketProvider)),
      data: (d) {
        final closed = d.ticket.status == 'CLOSED';
        return ListView(padding: const EdgeInsets.all(AppSpacing.md), children: [
          Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () => context.go('/support'), icon: const Icon(Icons.arrow_back), label: const Text(S.support))),
          Row(children: [Expanded(child: Text(d.ticket.subject, style: t.textTheme.headlineSmall)), Pill(d.ticket.status, _statusColor(d.ticket.status))]),
          Text('${d.ticket.businessName} · ${d.ticket.createdByEmail} · ${d.ticket.category}', style: t.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.md),
          for (final m in d.messages) Card(
            color: m.fromPlatform ? AppColors.primaryGreen.withValues(alpha: 0.08) : null,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${m.fromPlatform ? 'Platform team' : 'Business'} · ${m.authorName} · ${_dt.format(m.createdAt)}', style: t.textTheme.bodySmall),
                const SizedBox(height: AppSpacing.xs),
                SelectableText(m.body),
              ]),
            ),
          ),
          if (canReply) ...[
            if (!closed) ...[
              TextField(key: const Key('replyBody'), controller: _body, minLines: 3, maxLines: 8, maxLength: 4000, decoration: const InputDecoration(labelText: S.reply)),
              Row(children: [
                FilledButton(key: const Key('send'), style: FilledButton.styleFrom(minimumSize: const Size(96, 44)), onPressed: _busy ? null : () => _run(() => replyToTicket(ref, widget.id, _body.text), clear: true), child: const Text(S.send)),
                const SizedBox(width: AppSpacing.sm),
                OutlinedButton(key: const Key('close'), style: OutlinedButton.styleFrom(minimumSize: const Size(96, 44)), onPressed: _busy ? null : () => _run(() => setTicketStatus(ref, widget.id, 'CLOSED')), child: const Text(S.closeTicket)),
              ]),
            ] else
              OutlinedButton(key: const Key('reopen'), style: OutlinedButton.styleFrom(minimumSize: const Size(96, 44)), onPressed: _busy ? null : () => _run(() => setTicketStatus(ref, widget.id, 'OPEN')), child: const Text(S.reopen)),
            InlineError(_error),
          ],
        ]);
      },
    );
  }
}
