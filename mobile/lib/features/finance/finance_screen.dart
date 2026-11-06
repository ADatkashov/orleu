import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/repository.dart';
import '../../core/design/tokens.dart';
import '../../core/widgets/common.dart';
import '../../l10n/gen/app_localizations.dart';
import 'reports_section.dart';

class FinanceScreen extends ConsumerWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context);
    final cur = ref.watch(currentBusinessProvider).value?.currency ?? 'KZT';
    final s = ref.watch(summaryProvider);
    String pct(double v) => '${(v * 100).toStringAsFixed(1)}%';
    return Scaffold(
      appBar: AppBar(title: Text(l.navFinance)),
      body: s.when(
        loading: () => const SkeletonList(),
        error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(summaryProvider)),
        data: (s) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(summaryProvider),
          child: ListView(padding: const EdgeInsets.all(AppSpacing.md), children: [
            Text(l.financeTitle, style: t.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Row(children: [
              Expanded(child: StatTile(label: l.netCollected, value: money(context, s.netCollected, cur))),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: StatTile(label: l.outstanding, value: money(context, s.outstanding, cur), valueColor: s.outstanding > 0 ? AppColors.warning : null)),
            ]),
            const SizedBox(height: AppSpacing.sm),
            Row(children: [
              Expanded(child: StatTile(label: l.collected, value: money(context, s.collected, cur))),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: StatTile(label: l.refunded, value: money(context, s.refunded, cur))),
            ]),
            const SizedBox(height: AppSpacing.sm),
            StatTile(label: l.bookedValue, value: money(context, s.bookedValue, cur)),
            const SizedBox(height: AppSpacing.sm),
            Row(children: [
              Expanded(child: StatTile(label: l.cancellationRate, value: pct(s.cancellationRate))),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: StatTile(label: l.noShowRate, value: pct(s.noShowRate))),
            ]),
            const SizedBox(height: AppSpacing.md),
            Text(l.financeNote, style: t.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.lg),
            const ReportsSection(),
          ]),
        ),
      ),
    );
  }
}
