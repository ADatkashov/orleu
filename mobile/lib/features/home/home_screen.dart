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
    final gutter = AppSpacing.gutter(context);

    Future<void> refresh() async {
      ref.invalidate(bookingsProvider);
      ref.invalidate(todaySummaryProvider);
      ref.invalidate(weekSeriesProvider);
      await ref.read(bookingsProvider(today).future);
    }

    final hero = _Greeting(date: DateFormat.MMMMEEEEd(locale).format(today), text: l.greeting(name.split(' ').first));
    final kpis = summary.when(
      loading: () => const _KpiSkeleton(),
      error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(todaySummaryProvider)),
      data: (s) => IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: StatCard(icon: Icons.account_balance_wallet_outlined, label: l.todayCollected, value: money(context, s.netCollected, currency), hero: true)),
          const SizedBox(width: AppSpacing.sm + 4),
          Expanded(child: StatCard(icon: Icons.event_available_outlined, label: l.todayBookings, value: '${s.totalBookings}')),
        ]),
      ),
    );
    final performance = summary.maybeWhen(
      data: (s) => _Performance(summary: s, currency: currency),
      orElse: () => const SizedBox.shrink(),
    );
    final bookingsBlock = bookings.when(
      loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: AppSpacing.lg), child: LoadingState()),
      error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(bookingsProvider)),
      data: (list) {
        final pending = list.where((b) => b.needsAction).length;
        final upcoming = list.where((b) => b.isLive && b.endsInstant.isAfter(DateTime.now().toUtc())).take(5).toList();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (pending > 0) ...[
            _AttentionBanner(label: l.pendingBookings, count: pending, onTap: () => context.go('/calendar')),
            const SizedBox(height: AppSpacing.lg),
          ],
          SectionHeader(l.upcoming, actionLabel: l.seeAll, onAction: () => context.go('/calendar')),
          const SizedBox(height: AppSpacing.sm + 4),
          if (upcoming.isEmpty)
            AppCard(child: Row(children: [
              Icon(Icons.event_available_outlined, color: t.colorScheme.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(l.nothingUpcoming, style: t.textTheme.bodyMedium)),
            ]))
          else
            for (var i = 0; i < upcoming.length; i++)
              Entrance(index: i, child: Padding(padding: const EdgeInsets.only(bottom: AppSpacing.sm + 2), child: BookingCard(booking: upcoming[i], onTap: () => context.go('/calendar')))),
        ]);
      },
    );
    final week = _WeekChart(currency: currency, zone: zone);
    final quick = const _QuickActions();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: gutter,
        title: Row(children: [
          const LogoMark(),
          const SizedBox(width: AppSpacing.sm + 4),
          Flexible(child: Text(biz?.name ?? l.appName, overflow: TextOverflow.ellipsis, style: t.textTheme.titleLarge)),
        ]),
        actions: [
          Consumer(builder: (context, ref, _) => Padding(
                padding: EdgeInsets.only(right: gutter - 4),
                child: AppIconButton(key: const Key('bell'), icon: Icons.notifications_none_rounded, tooltip: l.notifTitle, badgeCount: ref.watch(unreadNotificationsProvider), onPressed: () => context.push('/notifications')),
              )),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: LayoutBuilder(builder: (context, box) {
          final wide = box.maxWidth >= AppBreakpoints.medium;
          final children = wide
              ? <Widget>[
                  hero, const SizedBox(height: AppSpacing.lg),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [kpis, const SizedBox(height: AppSpacing.md), week, const SizedBox(height: AppSpacing.lg), bookingsBlock])),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [performance, const SizedBox(height: AppSpacing.lg), quick])),
                  ]),
                ]
              : <Widget>[
                  hero, const SizedBox(height: AppSpacing.md + 4), kpis, const SizedBox(height: AppSpacing.md),
                  bookingsBlock, const SizedBox(height: AppSpacing.lg), performance, const SizedBox(height: AppSpacing.lg),
                  week, const SizedBox(height: AppSpacing.lg), quick,
                ];
          return ListView(padding: EdgeInsets.fromLTRB(gutter, AppSpacing.sm, gutter, AppSpacing.xl), children: children);
        }),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  final String date, text;
  const _Greeting({required this.date, required this.text});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        constraints: const BoxConstraints(maxWidth: 300),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: t.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(AppRadius.pill)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.calendar_today_outlined, size: AppIconSize.sm - 2, color: t.colorScheme.onPrimaryContainer),
          const SizedBox(width: 6),
          Flexible(child: Text(date, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.textTheme.labelLarge?.copyWith(color: t.colorScheme.onPrimaryContainer, fontWeight: FontWeight.w700))),
        ]),
      ),
      const SizedBox(height: AppSpacing.sm + 2),
      Semantics(header: true, child: Text(text, style: t.textTheme.headlineLarge)),
    ]);
  }
}

class _KpiSkeleton extends StatelessWidget {
  const _KpiSkeleton();
  @override
  Widget build(BuildContext context) => const Row(children: [
        Expanded(child: SkeletonBox(height: 168, radius: AppRadius.hero)),
        SizedBox(width: AppSpacing.sm + 4),
        Expanded(child: SkeletonBox(height: 168, radius: AppRadius.hero)),
      ]);
}

class _AttentionBanner extends StatelessWidget {
  final String label;
  final int count;
  final VoidCallback onTap;
  const _AttentionBanner({required this.label, required this.count, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final p = context.palette;
    return AppCard(
      onTap: onTap, radius: AppRadius.hero - 2, color: p.warningSoft,
      padding: const EdgeInsets.fromLTRB(12, 12, AppSpacing.md, 12),
      child: Row(children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: p.warning, shape: BoxShape.circle), child: const Icon(Icons.priority_high_rounded, size: AppIconSize.md, color: AppColors.primaryDark)),
        const SizedBox(width: AppSpacing.sm + 4),
        Expanded(child: Text('$count · $label', style: t.textTheme.titleSmall?.copyWith(color: p.warningFg, fontWeight: FontWeight.w700))),
        Icon(Icons.chevron_right_rounded, color: p.warningFg),
      ]),
    );
  }
}

class _Performance extends StatelessWidget {
  final Summary summary;
  final String currency;
  const _Performance({required this.summary, required this.currency});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    String pct(double v) => '${(v * 100).toStringAsFixed(1)}%';
    final p = context.palette;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionHeader(l.performanceTitle),
      const SizedBox(height: AppSpacing.sm + 4),
      StatTile(label: l.outstanding, value: money(context, summary.outstanding, currency), valueColor: summary.outstanding > 0 ? p.warningFg : null),
      const SizedBox(height: AppSpacing.sm + 2),
      Row(children: [
        Expanded(child: StatTile(label: l.cancellationRate, value: pct(summary.cancellationRate))),
        const SizedBox(width: AppSpacing.sm + 2),
        Expanded(child: StatTile(label: l.noShowRate, value: pct(summary.noShowRate))),
      ]),
    ]);
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final items = <(IconData, String, VoidCallback)>[
      (Icons.calendar_month_outlined, l.navCalendar, () => context.go('/calendar')),
      (Icons.people_outline_rounded, l.navCustomers, () => context.go('/customers')),
      (Icons.account_balance_wallet_outlined, l.navFinance, () => context.go('/finance')),
      (Icons.content_cut_rounded, l.services, () => context.push('/more/services')),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionHeader(l.quickActions),
      const SizedBox(height: AppSpacing.sm + 4),
      GridView.count(
        crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: AppSpacing.sm + 2, crossAxisSpacing: AppSpacing.sm + 2, childAspectRatio: 2.6,
        children: [for (final i in items) _QuickAction(icon: i.$1, label: i.$2, onTap: i.$3)],
      ),
    ]);
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return AppCard(
      onTap: onTap, padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(children: [
        Container(width: 32, height: 32, decoration: BoxDecoration(color: t.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: AppIconSize.md - 2, color: t.colorScheme.primary)),
        const SizedBox(width: AppSpacing.sm + 2),
        Expanded(child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: t.textTheme.labelLarge)),
      ]),
    );
  }
}

/// Net cash of the last 7 days from the real timeseries report. Hidden while loading or when the report fails
/// (it is secondary to the dashboard); an all-zero week shows the "no data" note instead of empty bars.
class _WeekChart extends ConsumerWidget {
  final String currency, zone;
  const _WeekChart({required this.currency, required this.zone});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context);
    final series = ref.watch(weekSeriesProvider);
    return series.maybeWhen(
      data: (pts) {
        if (pts.isEmpty) return const SizedBox.shrink();
        final total = pts.fold<double>(0, (a, p) => a + p.netCollected);
        final locale = Localizations.localeOf(context).toLanguageTag();
        final todayIdx = pts.length - 1;
        return AppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(l.sevenDays, style: t.textTheme.titleSmall?.copyWith(color: t.colorScheme.onSurfaceVariant))),
              Text(money(context, total, currency), style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: AppSpacing.md),
            if (total == 0 && pts.every((p) => p.bookings == 0))
              Text(l.reportNoData, style: t.textTheme.bodySmall)
            else
              AnalyticsBarChart(
                chartKey: const Key('week-chart'),
                values: [for (final p in pts) p.netCollected], highlight: todayIdx, height: 104,
                labels: [for (final p in pts) DateFormat.E(locale).format(p.date)],
                semanticLabel: '${l.sevenDays}: ${money(context, total, currency)}',
              ),
          ]),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
