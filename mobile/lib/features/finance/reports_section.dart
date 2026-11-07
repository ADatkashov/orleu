import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/models.dart';
import '../../core/data/repository.dart';
import '../../core/design/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../l10n/gen/app_localizations.dart';
import 'export_section.dart';

/// Period selector, daily cash chart, breakdown tables, peak hours and new-vs-returning customers.
/// Every number comes from the backend reports; nothing is computed from UI state except bar heights.
class ReportsSection extends ConsumerWidget {
  const ReportsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context);
    final days = ref.watch(reportDaysProvider);
    final cur = ref.watch(currentBusinessProvider).value?.currency ?? 'KZT';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionHeader(l.reportsTitle),
      const SizedBox(height: AppSpacing.sm + 4),
      SegmentedButton<int>(
        showSelectedIcon: false,
        segments: [for (final d in const [7, 30, 90]) ButtonSegment(value: d, label: Text(l.reportPeriodDays('$d')))],
        selected: {days},
        onSelectionChanged: (s) => ref.read(reportDaysProvider.notifier).set(s.first),
      ),
      const SizedBox(height: AppSpacing.md),
      _Block(title: l.reportRevenueByDay, child: _Daily(cur: cur)),
      _Block(title: l.reportTopServices, child: _Table(by: 'SERVICE', cur: cur)),
      _Block(title: l.reportTopEmployees, child: _Table(by: 'EMPLOYEE', cur: cur)),
      _Block(title: l.reportBranches, child: _Table(by: 'BRANCH', cur: cur)),
      _Block(title: l.reportPeakHours, child: const _Peak()),
      _Block(title: l.reportCustomers, child: const _Mix()),
      Text(l.reportsNote, style: t.textTheme.bodySmall),
      const SizedBox(height: AppSpacing.md),
      const ExportSection(),
    ]);
  }
}

class _Block extends StatelessWidget {
  final String title;
  final Widget child;
  const _Block({required this.title, required this.child});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: AppSpacing.md),
            child,
          ]),
        ),
      );
}

Widget _async<T>(BuildContext context, WidgetRef ref, AsyncValue<T> v, VoidCallback retry, Widget Function(T) build) => v.when(
      loading: () => const Padding(padding: EdgeInsets.all(AppSpacing.md), child: SkeletonBox(height: 96)),
      error: (e, _) => ErrorRetry(error: e, onRetry: retry),
      data: build,
    );

class _Daily extends ConsumerWidget {
  final String cur;
  const _Daily({required this.cur});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return _async<List<DayPoint>>(context, ref, ref.watch(timeseriesProvider), () => ref.invalidate(timeseriesProvider), (pts) {
      final total = pts.fold<double>(0, (a, p) => a + p.netCollected);
      if (pts.isEmpty || (total == 0 && pts.every((p) => p.bookings == 0))) return Text(l.reportNoData);
      final label = money(context, total, cur);
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        AnalyticsBarChart(
          chartKey: const Key('daily-chart'), height: 132,
          values: [for (final p in pts) p.netCollected],
          semanticLabel: '${l.reportRevenueByDay}: $label',
        ),
      ]);
    });
  }
}

class _Table extends ConsumerWidget {
  final String by, cur;
  const _Table({required this.by, required this.cur});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context);
    final p = breakdownProvider(by);
    return _async<List<BreakdownRow>>(context, ref, ref.watch(p), () => ref.invalidate(p), (rows) {
      final shown = rows.where((r) => r.bookings > 0 || r.netCollected != 0).take(8).toList();
      if (shown.isEmpty) return Text(l.reportNoData);
      return Column(children: [
        for (final r in shown)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.name, style: t.textTheme.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(l.reportBookingsN('${r.bookings}'), style: t.textTheme.bodySmall),
                ]),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(money(context, r.netCollected, cur), style: t.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            ]),
          ),
      ]);
    });
  }
}

class _Peak extends ConsumerWidget {
  const _Peak();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return _async<List<int>>(context, ref, ref.watch(peakHoursProvider), () => ref.invalidate(peakHoursProvider), (h) {
      final maxV = h.fold<int>(0, (a, v) => v > a ? v : a);
      if (maxV == 0) return Text(l.reportNoData);
      final top = h.indexOf(maxV);
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AnalyticsBarChart(
          chartKey: const Key('peak-chart'), height: 96,
          values: [for (final v in h) v.toDouble()], highlight: top,
          semanticLabel: '${l.reportPeakHours}: ${top.toString().padLeft(2, '0')}:00',
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          for (final x in const ['00', '06', '12', '18', '23']) Text(x, style: Theme.of(context).textTheme.bodySmall),
        ]),
      ]);
    });
  }
}

class _Mix extends ConsumerWidget {
  const _Mix();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return _async<CustomerMix>(context, ref, ref.watch(customerMixProvider), () => ref.invalidate(customerMixProvider), (m) {
      if (m.newCustomers + m.returningCustomers == 0) return Text(l.reportNoData);
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: StatTile(label: l.reportNew, value: '${m.newCustomers}')),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: StatTile(label: l.reportReturning, value: '${m.returningCustomers}')),
        ]),
        const SizedBox(height: AppSpacing.xs),
        Text(l.reportReturningShare((m.returningShare * 100).toStringAsFixed(0)), style: Theme.of(context).textTheme.bodySmall),
      ]);
    });
  }
}
