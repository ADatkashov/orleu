import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../design/tokens.dart';
import 'app_card.dart';
import 'states.dart';
import 'status_badge.dart';

export 'states.dart' show EmptyState, ErrorState, SkeletonList, SkeletonBox, LoadingState;
export 'status_badge.dart' show StatusBadge, BadgeTone, BookingStatusBadge, statusLabel, statusTone, statusAccent;

String money(BuildContext c, double v, String currency) {
  final f = NumberFormat.currency(locale: Localizations.localeOf(c).toLanguageTag(), name: currency, decimalDigits: v == v.roundToDouble() ? 0 : 2);
  return f.format(v);
}

/// Legacy name for [ErrorState] (kept so existing screens keep compiling).
class ErrorRetry extends ErrorState {
  const ErrorRetry({super.key, required super.error, required super.onRetry});
}

/// Compact label/value tile used in dense summaries (finance, customer card). Dashboards use `StatCard`.
class StatTile extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  const StatTile({super.key, required this.label, required this.value, this.valueColor});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return AppCard(
      semanticLabel: '$label: $value',
      child: ExcludeSemantics(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: t.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.xs),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: t.textTheme.titleLarge?.copyWith(color: valueColor, fontWeight: FontWeight.w800))),
        ]),
      ),
    );
  }
}

Color statusColor(BuildContext c, String status) => statusAccent(c, status);

/// Legacy name for [BookingStatusBadge].
class StatusChip extends BookingStatusBadge {
  const StatusChip(super.status, {super.key});
}
