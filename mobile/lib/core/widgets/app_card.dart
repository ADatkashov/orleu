import 'package:flutter/material.dart';

import '../design/tokens.dart';
import 'pressable.dart';

/// The base surface: white card, hairline border. [elevated] adds the soft shadow (hero surfaces only).
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Gradient? gradient;
  final bool elevated;
  final double radius;
  final String? semanticLabel;
  const AppCard({
    super.key, required this.child, this.padding = const EdgeInsets.all(AppSpacing.md), this.onTap, this.color, this.gradient,
    this.elevated = false, this.radius = AppRadius.card, this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final shape = BorderRadius.circular(radius);
    Widget card = Container(
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? s.surface) : null,
        gradient: gradient,
        borderRadius: shape,
        border: gradient == null ? Border.all(color: s.outlineVariant) : null,
        boxShadow: elevated ? AppShadows.soft(context) : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, borderRadius: shape, child: Padding(padding: padding, child: child)),
      ),
    );
    if (onTap != null) card = Pressable(child: card);
    return semanticLabel == null ? card : Semantics(container: true, label: semanticLabel, child: card);
  }
}
