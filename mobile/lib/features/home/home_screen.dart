import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/data/models.dart';
import '../../core/data/repository.dart';
import '../../core/tz.dart';
import '../../core/design/tokens.dart';
import '../../core/widgets/common.dart';
import '../../l10n/gen/app_localizations.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context);
    final biz = ref.watch(currentBusinessProvider).value;
    final name = ref.watch(meNameProvider).value ?? '';
    final zone = ref.watch(businessZoneProvider);
    final today = dayStart(nowWall(zone));
    final bookings = ref.watch(bookingsProvider(today));
    final summary = ref.watch(todaySummaryProvider);
    final currency = biz?.currency ?? 'KZT';
    final locale = Localizations.localeOf(context).toString();

    Future<void> refresh() async {
      ref.invalidate(bookingsProvider);
      ref.invalidate(todaySummaryProvider);
      await ref.read(bookingsProvider(today).future);
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppSpacing.md,
        title: Row(children: [
          const _LogoMark(),
          const SizedBox(width: AppSpacing.sm + 2),
          Flexible(child: Text(biz?.name ?? l.appName, overflow: TextOverflow.ellipsis, style: t.textTheme.titleLarge?.copyWith(letterSpacing: -0.3))),
        ]),
        actions: [
          Consumer(builder: (context, ref, _) {
            final unread = ref.watch(unreadNotificationsProvider);
            return Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm + 4),
              child: DecoratedBox(
                decoration: BoxDecoration(color: t.colorScheme.surface, shape: BoxShape.circle, boxShadow: AppGradients.soft(context)),
                child: IconButton(
                  key: const Key('bell'),
                  tooltip: l.notifTitle,
                  icon: Badge(
                    isLabelVisible: unread > 0,
                    label: Text('$unread'),
                    backgroundColor: AppColors.accentLime,
                    textColor: AppColors.primaryDark,
                    child: const Icon(Icons.notifications_none_rounded),
                  ),
                  onPressed: () => context.push('/notifications'),
                ),
              ),
            );
          }),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(padding: const EdgeInsets.fromLTRB(AppSpacing.md + 4, AppSpacing.sm, AppSpacing.md + 4, AppSpacing.lg), children: [
          _DateChip(DateFormat.MMMMEEEEd(locale).format(today)),
          const SizedBox(height: AppSpacing.sm),
          Text(l.greeting(name.split(' ').first), style: t.textTheme.headlineMedium?.copyWith(fontSize: 30, height: 1.15)),
          const SizedBox(height: AppSpacing.md + 4),
          summary.when(
            loading: () => const SizedBox(height: 148, child: Center(child: CircularProgressIndicator())),
            error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(todaySummaryProvider)),
            data: (s) => IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(child: _KpiCard(icon: Icons.account_balance_wallet_outlined, label: l.todayCollected, value: money(context, s.netCollected, currency), hero: true)),
                const SizedBox(width: AppSpacing.sm + 4),
                Expanded(child: _KpiCard(icon: Icons.event_available_outlined, label: l.todayBookings, value: '${s.totalBookings}')),
              ]),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          bookings.when(
            loading: () => const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
            error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(bookingsProvider)),
            data: (list) {
              final pending = list.where((b) => b.needsAction).length;
              final upcoming = list.where((b) => b.isLive && b.endsInstant.isAfter(DateTime.now().toUtc())).take(5).toList();
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (pending > 0) ...[
                  _AttentionBanner(label: l.pendingBookings, count: pending, onTap: () => context.go('/calendar')),
                  const SizedBox(height: AppSpacing.lg),
                ],
                Text(l.upcoming, style: t.textTheme.titleLarge?.copyWith(fontSize: 18)),
                const SizedBox(height: AppSpacing.md - 4),
                if (upcoming.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: AppSpacing.md), child: Text(l.nothingUpcoming, style: t.textTheme.bodySmall))
                else for (final b in upcoming) Padding(padding: const EdgeInsets.only(bottom: AppSpacing.sm + 2), child: _Row(b)),
              ]);
            },
          ),
        ]),
      ),
    );
  }
}

class _LogoMark extends StatelessWidget {
  const _LogoMark();
  @override
  Widget build(BuildContext context) => Container(
        width: 38, height: 38, alignment: Alignment.center,
        decoration: BoxDecoration(gradient: AppGradients.logo, borderRadius: BorderRadius.circular(13)),
        child: Text('O', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.accentLime, fontWeight: FontWeight.w800, height: 1)),
      );
}

class _DateChip extends StatelessWidget {
  final String text;
  const _DateChip(this.text);
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: t.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.calendar_today_outlined, size: 14, color: t.colorScheme.onPrimaryContainer),
          const SizedBox(width: 6),
          Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.textTheme.labelLarge?.copyWith(color: t.colorScheme.onPrimaryContainer, fontWeight: FontWeight.w700))),
        ]),
      ),
    );
  }
}

/// Dashboard KPI card; [hero] renders the dark gradient variant with a decorative lime ring.
class _KpiCard extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final bool hero;
  const _KpiCard({required this.icon, required this.label, required this.value, this.hero = false});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final fg = hero ? Colors.white : t.colorScheme.onSurface;
    final muted = hero ? Colors.white.withValues(alpha: 0.72) : t.colorScheme.onSurfaceVariant;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: hero ? AppGradients.hero : null,
        color: hero ? null : t.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.hero),
        boxShadow: AppGradients.soft(context),
      ),
      child: Stack(children: [
        if (hero)
          Positioned(
            right: -44, top: -44,
            child: Container(
              width: 120, height: 120,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.accentLime.withValues(alpha: 0.12), width: 20)),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(color: hero ? AppColors.accentLime : t.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 18, color: hero ? AppColors.primaryDark : t.colorScheme.primary),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.textTheme.bodySmall?.copyWith(color: muted, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
              child: Text(value, style: t.textTheme.headlineMedium?.copyWith(color: fg, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -1)),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _AttentionBanner extends StatelessWidget {
  final String label;
  final int count;
  final VoidCallback onTap;
  const _AttentionBanner({required this.label, required this.count, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final dark = t.brightness == Brightness.dark;
    return Material(
      color: dark ? t.colorScheme.surface : AppColors.accentLime.withValues(alpha: 0.28),
      borderRadius: BorderRadius.circular(AppRadius.hero - 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.hero - 2),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, AppSpacing.md, 12),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: const BoxDecoration(color: AppColors.accentLime, shape: BoxShape.circle),
              child: const Icon(Icons.priority_high_rounded, size: 20, color: AppColors.primaryDark),
            ),
            const SizedBox(width: AppSpacing.sm + 4),
            Expanded(child: Text('$count · $label', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
            Icon(Icons.chevron_right_rounded, color: t.colorScheme.primary),
          ]),
        ),
      ),
    );
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  final first = String.fromCharCode(parts.first.runes.first).toUpperCase();
  if (parts.length == 1) return first;
  return first + String.fromCharCode(parts.last.runes.first).toUpperCase();
}

class _Row extends StatelessWidget {
  final Booking b;
  const _Row(this.b);
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      decoration: BoxDecoration(color: t.colorScheme.surface, borderRadius: BorderRadius.circular(AppRadius.hero - 2), boxShadow: AppGradients.soft(context)),
      child: Row(children: [
        Container(
          width: 44, height: 44, alignment: Alignment.center,
          decoration: BoxDecoration(color: t.colorScheme.primaryContainer, shape: BoxShape.circle),
          child: Text(_initials(b.customerName), style: t.textTheme.titleMedium?.copyWith(color: t.colorScheme.onPrimaryContainer, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: AppSpacing.sm + 4),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(b.serviceName, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text('${b.customerName} · ${b.employeeName}', maxLines: 1, overflow: TextOverflow.ellipsis, style: t.textTheme.bodySmall),
          ]),
        ),
        const SizedBox(width: AppSpacing.sm),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(DateFormat.Hm().format(b.startsAt), style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          StatusChip(b.status),
        ]),
      ]),
    );
  }
}
