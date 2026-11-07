import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import '../design/tokens.dart';

enum BadgeTone { success, warning, danger, info, neutral, accent }

/// Pill with a soft tinted background and AA-contrast text in both themes.
class StatusBadge extends StatelessWidget {
  final String label;
  final BadgeTone tone;
  final bool dot;
  const StatusBadge(this.label, {super.key, this.tone = BadgeTone.neutral, this.dot = true});

  static (Color bg, Color fg) colors(BuildContext c, BadgeTone tone) {
    final p = c.palette;
    return switch (tone) {
      BadgeTone.success => (p.successSoft, p.successFg),
      BadgeTone.warning => (p.warningSoft, p.warningFg),
      BadgeTone.danger => (p.dangerSoft, p.dangerFg),
      BadgeTone.info => (p.infoSoft, p.infoFg),
      BadgeTone.neutral => (p.neutralSoft, p.neutralFg),
      BadgeTone.accent => (c.isDark ? AppColors.accentLime : AppColors.accentLime, AppColors.primaryDark),
    };
  }

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = colors(context, tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (dot) ...[Container(width: 6, height: 6, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)), const SizedBox(width: 6)],
        Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg, fontWeight: FontWeight.w700))),
      ]),
    );
  }
}

BadgeTone statusTone(String status) => switch (status) {
      'CONFIRMED' || 'COMPLETED' => BadgeTone.success,
      'PENDING' || 'AWAITING_PAYMENT' => BadgeTone.warning,
      'CHECKED_IN' || 'IN_PROGRESS' => BadgeTone.info,
      'CANCELLED' || 'NO_SHOW' || 'EXPIRED' => BadgeTone.danger,
      _ => BadgeTone.neutral,
    };

/// Solid accent color for a booking status (calendar markers, timeline bars).
Color statusAccent(BuildContext c, String status) {
  final p = c.palette;
  return switch (statusTone(status)) {
    BadgeTone.success => p.success,
    BadgeTone.warning => p.warning,
    BadgeTone.info => p.info,
    BadgeTone.danger => p.danger,
    _ => Theme.of(c).colorScheme.primary,
  };
}

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

class BookingStatusBadge extends StatelessWidget {
  final String status;
  const BookingStatusBadge(this.status, {super.key});
  @override
  Widget build(BuildContext context) => StatusBadge(statusLabel(AppLocalizations.of(context), status), tone: statusTone(status));
}
