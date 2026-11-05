import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/gen/app_localizations.dart';
import '../design/tokens.dart';
import '../errors.dart';

String money(BuildContext c, double v, String currency) {
  final f = NumberFormat.currency(locale: Localizations.localeOf(c).toLanguageTag(), name: currency, decimalDigits: v == v.roundToDouble() ? 0 : 2);
  return f.format(v);
}

class ErrorRetry extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const ErrorRetry({super.key, required this.error, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.cloud_off_outlined, size: 40, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: AppSpacing.md),
          Text(errorText(context, error), textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(onPressed: onRetry, child: Text(l.retry)),
        ]),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  const EmptyState({super.key, required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: AppSpacing.md),
            Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ]),
        ),
      );
}

class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key});
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.outline;
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: 5,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, _) => Container(height: 72, decoration: BoxDecoration(color: c.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(AppRadius.card))),
    );
  }
}

class StatTile extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  const StatTile({super.key, required this.label, required this.value, this.valueColor});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: t.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.xs),
          Text(value, style: t.textTheme.titleLarge?.copyWith(color: valueColor)),
        ]),
      ),
    );
  }
}

Color statusColor(BuildContext c, String status) => switch (status) {
      'CONFIRMED' || 'COMPLETED' => AppColors.success,
      'PENDING' || 'AWAITING_PAYMENT' => AppColors.warning,
      'CANCELLED' || 'NO_SHOW' || 'EXPIRED' => AppColors.danger,
      _ => Theme.of(c).colorScheme.primary,
    };

String statusLabel(AppLocalizations l, String s) => switch (s) {
      'PENDING' => l.statusPending,
      'AWAITING_PAYMENT' => l.statusAwaitingPayment,
      'CONFIRMED' => l.statusConfirmed,
      'CHECKED_IN' => l.statusCheckedIn,
      'IN_PROGRESS' => l.statusInProgress,
      'COMPLETED' => l.statusCompleted,
      'CANCELLED' => l.statusCancelled,
      'NO_SHOW' => l.statusNoShow,
      _ => l.statusExpired,
    };

class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip(this.status, {super.key});
  @override
  Widget build(BuildContext context) {
    final color = statusColor(context, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
      child: Text(statusLabel(AppLocalizations.of(context), status),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w600)),
    );
  }
}
