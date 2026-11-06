import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/models.dart';
import '../../core/data/repository.dart';
import '../../core/design/tokens.dart';
import '../../core/widgets/common.dart';
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
      Text(l.reportsTitle, style: t.textTheme.titleMedium),
      const SizedBox(height: AppSpacing.sm),
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
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              child,
            ]),
          ),
        ),
      );
}

Widget _async<T>(BuildContext context, WidgetRef ref, AsyncValue<T> v, VoidCallback retry, Widget Function(T) build) => v.when(
      loading: () => const Padding(padding: EdgeInsets.all(AppSpacing.md), child: Center(child: CircularProgressIndicator())),
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
      final maxV = pts.fold<double>(0, (a, p) => p.netCollected > a ? p.netCollected : a);
      final label = money(context, total, cur);
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        Semantics(
          label: '${l.reportRevenueByDay}: $label',
          child: SizedBox(
            height: 120,
            width: double.infinity,
            child: CustomPaint(key: const Key('daily-chart'), painter: _BarsPainter([for (final p in pts) p.netCollected], maxV, AppColors.primaryGreen)),
          ),
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
        Semantics(
          label: '${l.reportPeakHours}: ${top.toString().padLeft(2, '0')}:00',
          child: SizedBox(
            height: 80,
            width: double.infinity,
            child: CustomPaint(key: const Key('peak-chart'), painter: _BarsPainter([for (final v in h) v.toDouble()], maxV.toDouble(), AppColors.primaryGreen, highlight: top)),
          ),
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

class _BarsPainter extends CustomPainter {
  final List<double> values;
  final double maxValue;
  final Color color;
  final int? highlight;
  _BarsPainter(this.values, this.maxValue, this.color, {this.highlight});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final slot = size.width / values.length;
    final w = (slot * 0.7).clamp(1.0, 24.0);
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      final h = maxValue <= 0 ? 0.0 : (v / maxValue) * size.height;
      final paint = Paint()..color = (highlight == null || highlight == i) ? color : color.withValues(alpha: 0.45);
      final x = i * slot + (slot - w) / 2;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, size.height - (v > 0 ? h.clamp(2.0, size.height) : 1), w, v > 0 ? h.clamp(2.0, size.height) : 1), const Radius.circular(2)), paint);
    }
  }

  @override
  bool shouldRepaint(_BarsPainter o) => o.values != values || o.maxValue != maxValue || o.highlight != highlight;
}
