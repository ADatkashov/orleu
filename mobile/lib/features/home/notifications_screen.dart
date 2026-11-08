import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/data/models.dart';
import '../../core/data/repository.dart';
import '../../core/design/tokens.dart';
import '../../core/tz.dart';
import '../../core/widgets/widgets.dart';
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

enum _Cat { all, bookings, payments, support }

_Cat _catOf(String type) => switch (type) {
      'PAYMENT_RECEIVED' => _Cat.payments,
      'SUPPORT_REPLIED' => _Cat.support,
      _ => _Cat.bookings,
    };

(IconData, BadgeTone) _look(String type) => switch (type) {
      'PAYMENT_RECEIVED' => (Icons.payments_outlined, BadgeTone.success),
      'SUPPORT_REPLIED' => (Icons.support_agent_outlined, BadgeTone.info),
      'BOOKING_CONFIRMED' || 'BOOKING_COMPLETED' => (Icons.event_available_outlined, BadgeTone.success),
      'BOOKING_CANCELLED' || 'BOOKING_NO_SHOW' || 'BOOKING_EXPIRED' => (Icons.event_busy_outlined, BadgeTone.danger),
      'BOOKING_CREATED' => (Icons.event_note_outlined, BadgeTone.warning),
      'BOOKING_REMINDER' => (Icons.notifications_active_outlined, BadgeTone.neutral),
      _ => (Icons.event_note_outlined, BadgeTone.info),
    };

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});
  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsState();
}

class _NotificationsState extends ConsumerState<NotificationsScreen> {
  _Cat _cat = _Cat.all;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final zone = ref.watch(businessZoneProvider);
    final data = ref.watch(notificationsProvider);
    final unread = ref.watch(unreadNotificationsProvider);
    final gutter = AppSpacing.gutter(context);
    final labels = {_Cat.all: l.notifCatAll, _Cat.bookings: l.notifCatBookings, _Cat.payments: l.notifCatPayments, _Cat.support: l.notifCatSupport};
    return Scaffold(
      appBar: AppBar(title: Text(l.notifTitle), actions: [
        if (unread > 0) TextButton(key: const Key('markAll'), onPressed: () => guarded(context, () => ref.read(bookingActionsProvider).markAllNotificationsRead()), child: Text(l.notifMarkAll)),
        SizedBox(width: gutter - 8),
      ]),
      body: data.when(
        loading: () => const SkeletonList(),
        error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(notificationsProvider)),
        data: (all) {
          if (all.isEmpty) return EmptyState(icon: Icons.notifications_none_rounded, title: l.notifTitle, text: l.notifNone);
          final list = _cat == _Cat.all ? all : all.where((n) => _catOf(n.eventType) == _cat).toList();
          final now = wallFromInstant(DateTime.now().toUtc(), zone);
          final today = dayStart(now);
          final todays = [for (final n in list) if (!wallFromInstant(n.createdAt, zone).isBefore(today)) n];
          final earlier = [for (final n in list) if (wallFromInstant(n.createdAt, zone).isBefore(today)) n];
          Widget group(String title, List<AppNotification> items) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.sm), child: Text(title.toUpperCase(), style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 0.8, fontWeight: FontWeight.w700))),
                for (final n in items) Padding(padding: const EdgeInsets.only(bottom: AppSpacing.sm), child: _Tile(n, zone)),
              ]);
          return Column(children: [
            SizedBox(
              height: 44,
              child: ListView(scrollDirection: Axis.horizontal, padding: EdgeInsets.symmetric(horizontal: gutter), children: [
                for (final c in _Cat.values) Padding(padding: const EdgeInsets.only(right: AppSpacing.sm), child: AppFilterChip(label: labels[c]!, selected: _cat == c, onSelected: (_) => setState(() => _cat = c))),
              ]),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => ref.invalidate(notificationsProvider),
                child: list.isEmpty
                    ? ListView(children: [SizedBox(height: 320, child: EmptyState(icon: Icons.notifications_none_rounded, text: l.notifNone))])
                    : ListView(padding: EdgeInsets.fromLTRB(gutter, AppSpacing.sm, gutter, AppSpacing.xl), children: [
                        if (todays.isNotEmpty) group(l.notifToday, todays),
                        if (earlier.isNotEmpty) group(l.notifEarlier, earlier),
                      ]),
              ),
            ),
          ]);
        },
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
    final (icon, tone) = _look(n.eventType);
    final (bg, fg) = StatusBadge.colors(context, tone);
    final details = [
      if (n.customerName != null) n.customerName!,
      if (n.serviceName != null) n.serviceName!,
      if (n.startsAtInstant != null) DateFormat('dd.MM HH:mm').format(wallFromInstant(n.startsAtInstant!, zone)),
    ].join(' · ');
    return AppCard(
      key: Key('notif-${n.id}'),
      color: n.read ? null : t.colorScheme.primaryContainer.withValues(alpha: context.isDark ? 0.5 : 0.45),
      onTap: () async {
        if (!n.read) await guarded(context, () => ref.read(bookingActionsProvider).markNotificationRead(n.id));
        if (!context.mounted) return;
        if (n.eventType == 'SUPPORT_REPLIED') {
          context.go('/more/support');
        } else if (n.bookingId != null) {
          context.go('/calendar');
        }
      },
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: bg, shape: BoxShape.circle), child: Icon(icon, size: AppIconSize.md, color: fg)),
        const SizedBox(width: AppSpacing.sm + 4),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(notificationTitle(l, n.eventType), style: t.textTheme.titleSmall?.copyWith(fontWeight: n.read ? FontWeight.w500 : FontWeight.w800)),
            if (details.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(details, style: t.textTheme.bodySmall)),
            Padding(padding: const EdgeInsets.only(top: 2), child: Text(DateFormat('dd.MM HH:mm').format(wallFromInstant(n.createdAt, zone)), style: t.textTheme.labelSmall)),
          ]),
        ),
        if (!n.read) Padding(
          padding: const EdgeInsets.only(left: AppSpacing.sm, top: 6),
          child: Container(width: 10, height: 10, decoration: BoxDecoration(color: t.colorScheme.primary, shape: BoxShape.circle)),
        ),
      ]),
    );
  }
}
