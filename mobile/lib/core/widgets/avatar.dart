import 'package:flutter/material.dart';

import '../design/tokens.dart';

String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  final first = String.fromCharCode(parts.first.runes.first).toUpperCase();
  if (parts.length == 1) return first;
  return first + String.fromCharCode(parts.last.runes.first).toUpperCase();
}

/// Initials avatar; tint is derived from the name so the same person always looks the same.
class AppAvatar extends StatelessWidget {
  final String name;
  final double size;
  const AppAvatar(this.name, {super.key, this.size = AppSizes.avatar});
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = Theme.of(context).colorScheme;
    final tints = [(s.primaryContainer, s.onPrimaryContainer), (p.infoSoft, p.infoFg), (p.successSoft, p.successFg), (p.warningSoft, p.warningFg)];
    final (bg, fg) = tints[name.runes.fold<int>(0, (a, b) => a + b) % tints.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: ExcludeSemantics(
        child: Text(
          initialsOf(name),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(color: fg, fontWeight: FontWeight.w800, fontSize: size * 0.32),
        ),
      ),
    );
  }
}
