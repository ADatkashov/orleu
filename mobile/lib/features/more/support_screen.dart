import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/data/auth_controller.dart';
import '../../core/data/repository.dart';
import '../../core/design/tokens.dart';
import '../../core/tz.dart';
import '../../core/widgets/widgets.dart' hide statusLabel, statusColor;
import '../../l10n/gen/app_localizations.dart';
import '../setup/setup_common.dart';

class SupportTicket {
  final String id, subject, category, status;
  final DateTime updatedAt;
  const SupportTicket({required this.id, required this.subject, required this.category, required this.status, required this.updatedAt});
  factory SupportTicket.fromJson(Map<String, dynamic> j) =>
      SupportTicket(id: j['id'], subject: j['subject'], category: j['category'], status: j['status'], updatedAt: DateTime.parse(j['updatedAt']));
}

class SupportMessage {
  final bool fromPlatform;
  final String authorName, body;
  final DateTime createdAt;
  const SupportMessage({required this.fromPlatform, required this.authorName, required this.body, required this.createdAt});
  factory SupportMessage.fromJson(Map<String, dynamic> j) =>
      SupportMessage(fromPlatform: j['fromPlatform'] == true, authorName: j['authorName'] ?? '', body: j['body'], createdAt: DateTime.parse(j['createdAt']));
}

final supportTicketsProvider = FutureProvider.autoDispose<List<SupportTicket>>((ref) async {
  final b = await ref.watch(currentBusinessProvider.future);
  final r = await ref.watch(apiClientProvider).run((d) => d.get('/api/v1/businesses/${b!.id}/support/tickets'));
  return (r.data as List).map((e) => SupportTicket.fromJson(e)).toList();
});

final supportTicketProvider = FutureProvider.autoDispose.family<(SupportTicket, List<SupportMessage>), String>((ref, id) async {
  final b = await ref.watch(currentBusinessProvider.future);
  final r = await ref.watch(apiClientProvider).run((d) => d.get('/api/v1/businesses/${b!.id}/support/tickets/$id'));
  return (SupportTicket.fromJson(r.data['ticket']), (r.data['messages'] as List).map((e) => SupportMessage.fromJson(e)).toList());
});

Future<String> _bizId(WidgetRef ref) async => (await ref.read(currentBusinessProvider.future))!.id;

Future<String> createTicket(WidgetRef ref, String subject, String category, String body) async {
  final id = await _bizId(ref);
  final r = await ref.read(apiClientProvider).run((d) => d.post('/api/v1/businesses/$id/support/tickets', data: {'subject': subject, 'category': category, 'body': body}));
  ref.invalidate(supportTicketsProvider);
  return r.data['ticket']['id'] as String;
}

Future<void> replyTicket(WidgetRef ref, String ticketId, String body) async {
  final id = await _bizId(ref);
  await ref.read(apiClientProvider).run((d) => d.post('/api/v1/businesses/$id/support/tickets/$ticketId/messages', data: {'body': body}));
  ref.invalidate(supportTicketProvider);
  ref.invalidate(supportTicketsProvider);
}

Future<void> closeTicket(WidgetRef ref, String ticketId) async {
  final id = await _bizId(ref);
  await ref.read(apiClientProvider).run((d) => d.post('/api/v1/businesses/$id/support/tickets/$ticketId/close'));
  ref.invalidate(supportTicketProvider);
  ref.invalidate(supportTicketsProvider);
}

String statusLabel(AppLocalizations l, String s) => switch (s) { 'OPEN' => l.stOPEN, 'ANSWERED' => l.stANSWERED, _ => l.stCLOSED };
Color statusColor(BuildContext context, String s) => switch (s) { 'OPEN' => context.palette.warningFg, 'ANSWERED' => context.palette.successFg, _ => Theme.of(context).colorScheme.onSurfaceVariant };

class SupportScreen extends ConsumerWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context);
    final zone = ref.watch(businessZoneProvider);
    final tickets = ref.watch(supportTicketsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.supportNav)),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('newTicket'), icon: const Icon(Icons.add), label: Text(l.supportNew),
        onPressed: () => showModalBottomSheet(context: context, isScrollControlled: true, showDragHandle: true, builder: (_) => const _NewTicketSheet()),
      ),
      body: tickets.when(
        loading: () => const SkeletonList(),
        error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(supportTicketsProvider)),
        data: (list) => ListView(padding: EdgeInsets.fromLTRB(AppSpacing.gutter(context), AppSpacing.md, AppSpacing.gutter(context), 96), children: [
          Text(l.supportIntro, style: t.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.md),
          if (list.isEmpty) Text(l.supportNone, key: const Key('noTickets')),
          for (final x in list) Padding(padding: const EdgeInsets.only(bottom: AppSpacing.sm + 2), child: AppCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              key: Key('ticket-${x.id}'),
              title: Text(x.subject, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text(DateFormat('dd.MM HH:mm').format(wallFromInstant(x.updatedAt, zone))),
              trailing: StatusBadge(statusLabel(l, x.status), tone: x.status == 'OPEN' ? BadgeTone.warning : x.status == 'ANSWERED' ? BadgeTone.success : BadgeTone.neutral),
              onTap: () => context.push('/more/support/${x.id}'),
            ),
          )),
        ]),
      ),
    );
  }
}

class _NewTicketSheet extends ConsumerStatefulWidget {
  const _NewTicketSheet();
  @override
  ConsumerState<_NewTicketSheet> createState() => _NewTicketState();
}

class _NewTicketState extends ConsumerState<_NewTicketSheet> {
  final _subject = TextEditingController(), _body = TextEditingController();
  String _category = 'OTHER';
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    if (_subject.text.trim().isEmpty || _body.text.trim().isEmpty) { setState(() => _error = l.validationRequired); return; }
    setState(() { _busy = true; _error = null; });
    String? id;
    final err = await attempt(context, () async { id = await createTicket(ref, _subject.text.trim(), _category, _body.text.trim()); });
    if (!mounted) return;
    if (err == null) {
      Navigator.pop(context);
      context.push('/more/support/$id');
    } else {
      setState(() { _busy = false; _error = err; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cats = {'BILLING': l.catBILLING, 'TECHNICAL': l.catTECHNICAL, 'ACCOUNT': l.catACCOUNT, 'OTHER': l.catOTHER};
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(l.supportNew, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          Wrap(spacing: AppSpacing.sm, children: [
            for (final e in cats.entries) ChoiceChip(key: Key('cat-${e.key}'), label: Text(e.value), selected: _category == e.key, onSelected: (_) => setState(() => _category = e.key)),
          ]),
          const SizedBox(height: AppSpacing.sm),
          TextField(key: const Key('subject'), controller: _subject, maxLength: 200, decoration: InputDecoration(labelText: l.supportSubject)),
          TextField(key: const Key('body'), controller: _body, minLines: 3, maxLines: 8, maxLength: 4000, decoration: InputDecoration(labelText: l.supportBody)),
          FormError(_error),
          const SizedBox(height: AppSpacing.md),
          FilledButton(key: const Key('createTicket'), onPressed: _busy ? null : _submit, child: Text(l.supportCreate)),
        ]),
      ),
    );
  }
}

class TicketScreen extends ConsumerStatefulWidget {
  final String id;
  const TicketScreen({super.key, required this.id});
  @override
  ConsumerState<TicketScreen> createState() => _TicketState();
}

class _TicketState extends ConsumerState<TicketScreen> {
  final _body = TextEditingController();
  bool _busy = false;

  Future<void> _send() async {
    if (_body.text.trim().isEmpty) return;
    setState(() => _busy = true);
    final ok = await guarded(context, () => replyTicket(ref, widget.id, _body.text.trim()));
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) _body.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context);
    final zone = ref.watch(businessZoneProvider);
    final data = ref.watch(supportTicketProvider(widget.id));
    return Scaffold(
      appBar: AppBar(title: Text(l.supportNav)),
      body: data.when(
        loading: () => const SkeletonList(),
        error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(supportTicketProvider)),
        data: (d) {
          final (ticket, messages) = d;
          final closed = ticket.status == 'CLOSED';
          return ListView(padding: const EdgeInsets.all(AppSpacing.md), children: [
            Text(ticket.subject, style: t.textTheme.titleLarge),
            Text(statusLabel(l, ticket.status), key: const Key('ticketStatus'), style: t.textTheme.labelMedium?.copyWith(color: statusColor(context, ticket.status))),
            const SizedBox(height: AppSpacing.md),
            for (final m in messages) Align(
              alignment: m.fromPlatform ? Alignment.centerLeft : Alignment.centerRight,
              child: Container(
                constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.82),
                margin: const EdgeInsets.only(bottom: AppSpacing.sm + 2),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: m.fromPlatform ? t.colorScheme.surface : t.colorScheme.primaryContainer,
                  border: m.fromPlatform ? Border.all(color: t.colorScheme.outlineVariant) : null,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(AppRadius.card), topRight: const Radius.circular(AppRadius.card),
                    bottomLeft: Radius.circular(m.fromPlatform ? 4 : AppRadius.card), bottomRight: Radius.circular(m.fromPlatform ? AppRadius.card : 4),
                  ),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${m.fromPlatform ? l.supportTeam : l.supportYou} · ${DateFormat('dd.MM HH:mm').format(wallFromInstant(m.createdAt, zone))}', style: t.textTheme.bodySmall?.copyWith(color: m.fromPlatform ? null : t.colorScheme.onPrimaryContainer.withValues(alpha: 0.75))),
                  const SizedBox(height: AppSpacing.xs),
                  Text(m.body, style: t.textTheme.bodyMedium?.copyWith(color: m.fromPlatform ? null : t.colorScheme.onPrimaryContainer)),
                ]),
              ),
            ),
            if (closed) Text(l.supportClosedNote, key: const Key('closedNote'), style: t.textTheme.bodySmall)
            else ...[
              TextField(key: const Key('reply'), controller: _body, minLines: 2, maxLines: 6, maxLength: 4000, decoration: InputDecoration(labelText: l.supportReply)),
              Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
                FilledButton(key: const Key('sendReply'), style: FilledButton.styleFrom(minimumSize: const Size(96, 44)), onPressed: _busy ? null : _send, child: Text(l.supportSend)),
                OutlinedButton(key: const Key('closeTicket'), style: OutlinedButton.styleFrom(minimumSize: const Size(96, 44)), onPressed: () => guarded(context, () => closeTicket(ref, widget.id)), child: Text(l.supportCloseTicket)),
              ]),
            ],
          ]);
        },
      ),
    );
  }
}
