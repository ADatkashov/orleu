import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import '../design/tokens.dart';
import '../errors.dart';
import 'buttons.dart';

/// Empty list / nothing to show. [text] is the message; [title] and an action are optional.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? title, actionLabel;
  final VoidCallback? onAction;
  const EmptyState({super.key, required this.icon, required this.text, this.title, this.actionLabel, this.onAction});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(color: t.colorScheme.primaryContainer, shape: BoxShape.circle),
              child: Icon(icon, size: 36, color: t.colorScheme.primary),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (title != null) ...[
              Text(title!, textAlign: TextAlign.center, style: t.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
            ],
            Text(text, textAlign: TextAlign.center, style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(label: actionLabel!, onPressed: onAction, expand: false),
            ],
          ]),
        ),
      ),
    );
  }
}

/// Failed load with a retry button. The message comes from [errorText] so it is always localized.
class ErrorState extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const ErrorState({super.key, required this.error, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(color: context.palette.dangerSoft, shape: BoxShape.circle),
            child: Icon(Icons.cloud_off_outlined, size: 28, color: context.palette.dangerFg),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(errorText(context, error), textAlign: TextAlign.center, style: t.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.md),
          SecondaryButton(label: l.retry, onPressed: onRetry, icon: Icons.refresh_rounded, expand: false),
        ]),
      ),
    );
  }
}

/// Shimmering placeholder block. Static when the platform asks to reduce motion.
class SkeletonBox extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;
  const SkeletonBox({super.key, this.width, this.height = 16, this.radius = AppRadius.control});
  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduce) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final base = s.surfaceContainerHigh, hi = s.surfaceContainerLow;
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Container(
          width: widget.width, height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1.5 + 3 * _c.value, 0), end: Alignment(-0.5 + 3 * _c.value, 0),
              colors: [base, hi, base],
            ),
          ),
        ),
      ),
    );
  }
}

/// Loading placeholder shaped like a list of cards (avatar + two lines).
class SkeletonList extends StatelessWidget {
  final int count;
  const SkeletonList({super.key, this.count = 5});
  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Semantics(
      label: AppLocalizations.of(context).loading,
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: count,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm + 2),
        itemBuilder: (_, _) => Container(
          height: 76, padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(color: s.surface, borderRadius: BorderRadius.circular(AppRadius.card), border: Border.all(color: s.outlineVariant)),
          child: const Row(children: [
            SkeletonBox(width: 44, height: 44, radius: 22),
            SizedBox(width: AppSpacing.md),
            Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              SkeletonBox(width: 140, height: 14), SizedBox(height: 8), SkeletonBox(width: 90, height: 12),
            ])),
          ]),
        ),
      ),
    );
  }
}

/// Centered spinner for short, non-list loads.
class LoadingState extends StatelessWidget {
  const LoadingState({super.key});
  @override
  Widget build(BuildContext context) => Center(child: Semantics(label: AppLocalizations.of(context).loading, child: const CircularProgressIndicator()));
}
