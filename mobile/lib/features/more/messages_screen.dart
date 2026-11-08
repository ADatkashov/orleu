import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/data/models.dart';
import '../../core/data/repository.dart';
import '../../core/design/tokens.dart';
import '../../core/tz.dart';
import '../../core/widgets/widgets.dart';
import '../../l10n/gen/app_localizations.dart';
import '../setup/setup_common.dart';

/// Reminder + customer-message-language settings and the list of messages the backend has prepared.
/// Delivery providers are not connected, so every message is shown as "not sent" — the UI never implies delivery.
class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  static const _langs = {'kk': 'Қазақша', 'ru': 'Русский', 'en': 'English'};
  static const _hours = [0, 2, 24, 48];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context);
    final biz = ref.watch(currentBusinessProvider).value;
    final msgs = ref.watch(customerMessagesProvider);
    final zone = ref.watch(businessZoneProvider);
    final mode = ref.watch(messagingStatusProvider).value;
    Future<void> save({int? hours, String? lang, int? retention}) async {
      final ok = await guarded(context, () => ref.read(bookingActionsProvider).updateMessaging(reminderHours: hours, customerLocale: lang, retentionMonths: retention));
      if (ok && context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.messagesSaved)));
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.messagesNav)),
      body: ListView(padding: EdgeInsets.fromLTRB(AppSpacing.gutter(context), AppSpacing.sm, AppSpacing.gutter(context), AppSpacing.xl), children: [
        Text(l.messagesNote, style: t.textTheme.bodySmall),
        if (mode != null && mode.testMode) Container(
          key: const Key('testMode'), margin: const EdgeInsets.only(top: AppSpacing.sm), padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(color: context.palette.warningSoft, borderRadius: BorderRadius.circular(AppRadius.card)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.science_outlined, size: AppIconSize.md, color: context.palette.warningFg),
            const SizedBox(width: AppSpacing.sm + 2),
            Expanded(child: Text(l.messagesTestMode, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.palette.warningFg))),
          ]),
        ),
        const SizedBox(height: AppSpacing.md),
        if (biz != null) ...[
          Text(l.messagesReminder, style: t.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<int>(
            key: const Key('reminder-hours'),
            showSelectedIcon: false,
            emptySelectionAllowed: true,
            segments: [for (final h in _hours) ButtonSegment(value: h, label: Text(h == 0 ? l.messagesReminderOff : l.messagesReminderHours('$h')))],
            selected: _hours.contains(biz.reminderHours) ? {biz.reminderHours} : {},
            onSelectionChanged: (s) { if (s.isNotEmpty) save(hours: s.first); },
          ),
          const SizedBox(height: AppSpacing.md),
          Text(l.messagesLanguage, style: t.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<String>(
            key: const Key('customer-locale'),
            showSelectedIcon: false,
            segments: [for (final e in _langs.entries) ButtonSegment(value: e.key, label: Text(e.value))],
            selected: {biz.customerLocale},
            onSelectionChanged: (s) => save(lang: s.first),
          ),
        ],
        if (biz != null) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(l.retentionTitle, style: t.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(l.retentionNote, style: t.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<int>(
            key: const Key('retention'),
            showSelectedIcon: false,
            emptySelectionAllowed: true,
            segments: [for (final m in const [0, 24, 36, 60]) ButtonSegment(value: m, label: Text(m == 0 ? l.retentionOff : l.retentionYears('${m ~/ 12}')))],
            selected: const [0, 24, 36, 60].contains(biz.customerRetentionMonths) ? {biz.customerRetentionMonths} : {},
            onSelectionChanged: (s) { if (s.isNotEmpty) save(retention: s.first); },
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Text(l.messagesPrepared, style: t.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        msgs.when(
          loading: () => const Padding(padding: EdgeInsets.all(AppSpacing.md), child: Center(child: CircularProgressIndicator())),
          error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(customerMessagesProvider)),
          data: (list) => list.isEmpty
              ? Text(l.messagesNone, key: const Key('no-messages'))
              : Column(children: [for (final m in list) _MessageCard(m, zone)]),
        ),
      ]),
    );
  }
}

class _MessageCard extends ConsumerWidget {
  final CustomerMessage m;
  final String zone;
  const _MessageCard(this.m, this.zone);
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context);
    final when = DateFormat('dd.MM HH:mm').format(wallFromInstant(m.createdAt, zone));
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('${m.recipientPhone} · $when', style: t.textTheme.bodySmall)),
            StatusBadge(
              switch (m.status) { 'NOT_SENT' => m.attempts > 0 ? l.messagesRetrying(m.attempts) : l.messagesNotSent, 'SENT' => l.messagesSent, _ => l.messagesFailed },
              key: Key('status-${m.id}'), tone: m.status == 'SENT' ? BadgeTone.success : m.status == 'FAILED' ? BadgeTone.danger : BadgeTone.warning,
            ),
          ]),
          const SizedBox(height: AppSpacing.xs),
          Text(m.body, style: t.textTheme.bodyMedium),
          if (m.status == 'FAILED') Row(children: [
            Expanded(child: Text(m.lastError ?? '', style: t.textTheme.bodySmall)),
            TextButton(key: Key('retry-${m.id}'), onPressed: () => guarded(context, () => retryMessage(ref, m.id)), child: Text(l.messagesRetry)),
          ]),
        ]),
      ),
    );
  }
}
