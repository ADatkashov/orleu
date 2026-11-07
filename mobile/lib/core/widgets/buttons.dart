import 'package:flutter/material.dart';

import '../design/tokens.dart';
import 'pressable.dart';

/// Main call to action. Shows a spinner while [loading] and ignores taps (no double submit).
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool expand;
  const PrimaryButton({super.key, required this.label, required this.onPressed, this.icon, this.loading = false, this.expand = true});

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Theme.of(context).colorScheme.onPrimary))
        : Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: AppIconSize.md), const SizedBox(width: AppSpacing.sm)],
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis, maxLines: 1)),
          ]);
    return Pressable(
      enabled: onPressed != null && !loading,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: expand ? null : FilledButton.styleFrom(minimumSize: const Size(AppSizes.minTap, AppSizes.control)),
        child: AnimatedSwitcher(duration: AppMotion.fast, child: KeyedSubtree(key: ValueKey(loading), child: child)),
      ),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;
  final bool destructive;
  const SecondaryButton({super.key, required this.label, required this.onPressed, this.icon, this.expand = true, this.destructive = false});

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final c = destructive ? context.palette.dangerFg : null;
    return Pressable(
      enabled: onPressed != null,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: expand ? const Size.fromHeight(AppSizes.control) : const Size(AppSizes.minTap, AppSizes.control),
          foregroundColor: c, side: BorderSide(color: destructive ? context.palette.danger.withValues(alpha: 0.5) : s.outline),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: AppIconSize.md), const SizedBox(width: AppSpacing.sm)],
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis, maxLines: 1)),
        ]),
      ),
    );
  }
}

/// Round icon button on a surface chip; [badgeCount] shows the lime counter used for notifications.
class AppIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final int badgeCount;
  const AppIconButton({super.key, required this.icon, required this.tooltip, required this.onPressed, this.badgeCount = 0});

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(color: s.surface, shape: BoxShape.circle, border: Border.all(color: s.outlineVariant)),
      child: IconButton(
        tooltip: tooltip, onPressed: onPressed,
        icon: Badge(isLabelVisible: badgeCount > 0, label: Text('$badgeCount'), child: Icon(icon, size: AppIconSize.md + 2)),
      ),
    );
  }
}
