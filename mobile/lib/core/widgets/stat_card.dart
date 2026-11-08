import 'package:flutter/material.dart';

import '../design/tokens.dart';
import 'app_card.dart';

/// KPI card. [hero] is the dark brand-gradient variant (one per screen). [trend] is a short delta label.
class StatCard extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final String? note, trend;
  final bool hero;
  final Color? valueColor;
  final VoidCallback? onTap;
  const StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.note,
    this.trend,
    this.hero = false,
    this.valueColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final p = context.palette;
    final fg = hero ? p.onHero : t.colorScheme.onSurface;
    final muted = hero ? p.onHeroMuted : t.colorScheme.onSurfaceVariant;
    final body = Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        if (hero)
          Positioned(
            right: -48,
            top: -48,
            child: ExcludeSemantics(
              child: Container(
                width: 128,
                height: 128,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: p.heroAccent.withValues(alpha: 0.12), width: 22),
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: hero ? p.heroAccent : t.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(AppRadius.control)),
                child: Icon(icon, size: AppIconSize.md - 2, color: hero ? AppColors.primaryDark : t.colorScheme.primary),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: t.textTheme.labelLarge?.copyWith(color: muted, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppSpacing.xs),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value, style: t.textTheme.headlineMedium?.copyWith(color: valueColor ?? fg, fontSize: 28)),
              ),
              if (trend != null || note != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (trend != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: hero ? p.heroAccent : p.successSoft, borderRadius: BorderRadius.circular(AppRadius.pill)),
                        child: Text(
                          trend!,
                          style: t.textTheme.labelMedium?.copyWith(color: hero ? AppColors.primaryDark : p.successFg, fontWeight: FontWeight.w800),
                        ),
                      ),
                    if (note != null) Text(note!, style: t.textTheme.bodySmall?.copyWith(color: muted)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
    final card = hero
        ? AppCard(padding: EdgeInsets.zero, gradient: AppGradients.heroOf(context), elevated: true, radius: AppRadius.hero, onTap: onTap, child: body)
        : AppCard(padding: EdgeInsets.zero, radius: AppRadius.hero, onTap: onTap, child: body);
    return Semantics(
      container: true,
      label: '$label: $value',
      child: ExcludeSemantics(child: card),
    );
  }
}
