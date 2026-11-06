import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/data/repository.dart';
import '../../core/design/tokens.dart';
import '../../core/tz.dart';
import '../../core/widgets/common.dart';
import '../../l10n/gen/app_localizations.dart';

/// Measured average and distribution plus the reviews themselves. Reviews come only from completed visits (server-enforced).
class ReviewsScreen extends ConsumerWidget {
  const ReviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context);
    final zone = ref.watch(businessZoneProvider);
    final data = ref.watch(reviewsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.reviewsNav)),
      body: data.when(
        loading: () => const SkeletonList(),
        error: (e, _) => ErrorRetry(error: e, onRetry: () => ref.invalidate(reviewsProvider)),
        data: (d) {
          final (sum, items) = d;
          if (sum.count == 0) return EmptyState(icon: Icons.star_outline, text: l.reviewsNone);
          final maxCount = sum.distribution.fold<int>(1, (a, v) => v > a ? v : a);
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(reviewsProvider),
            child: ListView(padding: const EdgeInsets.all(AppSpacing.md), children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(l.reviewsAverage, style: t.textTheme.bodySmall),
                      Text(sum.average!.toStringAsFixed(1), key: const Key('avg'), style: t.textTheme.headlineMedium),
                      Text(l.reviewsCount(sum.count), style: t.textTheme.bodySmall),
                    ]),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(child: Column(children: [
                      for (var star = 5; star >= 1; star--) Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(children: [
                          SizedBox(width: 16, child: Text('$star', style: t.textTheme.bodySmall)),
                          Expanded(child: LinearProgressIndicator(value: sum.distribution[star - 1] / maxCount, minHeight: 8, borderRadius: BorderRadius.circular(4))),
                          SizedBox(width: 28, child: Text('${sum.distribution[star - 1]}', textAlign: TextAlign.end, style: t.textTheme.bodySmall)),
                        ]),
                      ),
                    ])),
                  ]),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(l.reviewsNote, style: t.textTheme.bodySmall),
              const SizedBox(height: AppSpacing.sm),
              for (final r in items) Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Semantics(label: '${r.rating}/5', child: Text('★' * r.rating + '☆' * (5 - r.rating), style: t.textTheme.titleMedium?.copyWith(color: AppColors.warning))),
                      const Spacer(),
                      Text(DateFormat('dd.MM.yyyy').format(wallFromInstant(r.createdAt, zone)), style: t.textTheme.bodySmall),
                    ]),
                    Text('${r.customerName} · ${r.serviceName}', style: t.textTheme.bodySmall),
                    if (r.comment != null && r.comment!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: AppSpacing.xs), child: Text(r.comment!)),
                  ]),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }
}
