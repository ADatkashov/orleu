import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/data/models.dart';
import '../../core/data/repository.dart';
import '../../core/design/tokens.dart';
import '../../core/tz.dart';
import '../../core/widgets/common.dart';
import '../../l10n/gen/app_localizations.dart';
import '../setup/setup_common.dart';

String notificationTitle(AppLocalizations l, String type) => switch (type) {
      'BOOKING_CREATED' => l.notifBOOKING_CREATED,
      'BOOKING_CONFIRMED' => l.notifBOOKING_CONFIRMED,
      'BOOKING_CANCELLED' => l.notifBOOKING_CANCELLED,
      'BOOKING_RESCHEDULED' => l.notifBOOKING_RESCHEDULED,
      'BOOKING_EXPIRED' => l.notifBOOKING_EXPIRED,
      'BOOKING_CHECKED_IN' => l.notifBOOKING_CHECKED_IN,
      'BOOKING_IN_PROGRESS' => l.notifBOOKING_IN_PROGRESS,
      'BOOKING_COMPLETED' => l.notifBOOKING_COMPLETED,
      'BOOKING_NO_SHOW' => l.notifBOOKING_NO_SHOW,
      'BOOKING_REMINDER' => l.notifBOOKING_REMINDER,
      'PAYMENT_RECEIVED' => l.notifPAYMENT_RECEIVED,
      'SUPPORT_REPLIED' => l.notifSUPPORT_REPLIED,
      _ => l.notifOther,
    };

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final zone = ref.watch(businessZoneProvider);
    final data = ref.watch(notificationsProvider);
    final unread = ref.watch(unreadNotificationsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.notifTitle), actions: [
        if (unread > 0) TextButton(key: const Key('markAll'), onPressed: () => guarded(context, () => ref.read(bookingActionsProvider).markAllNotificationsRead()), child: Text(l.notifMarkAll)),
      ]),
      body: data.when(
        loading: () => const SkeletonList(),
        error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(notificationsProvider)),
        data: (list) => list.isEmpty
            ? EmptyState(icon: Icons.notifications_none, text: l.notifNone)
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(notificationsProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, i) => _Tile(list[i], zone),
                ),
              ),
      ),
    );
  }
}

class _Tile extends ConsumerWidget {
  final AppNotification n;
  final String zone;
  const _Tile(this.n, this.zone);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context);
    final details = [
      if (n.customerName != null) n.customerName!,
      if (n.serviceName != null) n.serviceName!,
      if (n.startsAtInstant != null) DateFormat('dd.MM HH:mm').format(wallFromInstant(n.startsAtInstant!, zone)),
    ].join(' · ');
    return Card(
      color: n.read ? null : AppColors.primaryGreen.withValues(alpha: 0.08),
      child: ListTile(
        key: Key('notif-${n.id}'),
        leading: Icon(n.eventType == 'SUPPORT_REPLIED' ? Icons.support_agent_outlined : n.eventType == 'PAYMENT_RECEIVED' ? Icons.payments_outlined : Icons.event_note_outlined),
        title: Text(notificationTitle(l, n.eventType), style: t.textTheme.titleSmall?.copyWith(fontWeight: n.read ? FontWeight.w400 : FontWeight.w700)),
        subtitle: Text([if (details.isNotEmpty) details, DateFormat('dd.MM HH:mm').format(wallFromInstant(n.createdAt, zone))].join('\n')),
        isThreeLine: details.isNotEmpty,
        onTap: () async {
          if (!n.read) await guarded(context, () => ref.read(bookingActionsProvider).markNotificationRead(n.id));
          if (!context.mounted) return;
          if (n.eventType == 'SUPPORT_REPLIED') {
            context.go('/more/support');
          } else if (n.bookingId != null) {
            context.go('/calendar');
          }
        },
      ),
    );
  }
}
