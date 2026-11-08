import 'package:flutter/material.dart';

import '../design/tokens.dart';
import 'app_card.dart';

/// Titled card holding a list of [SettingsTile]s separated by hairlines.
class SettingsGroup extends StatelessWidget {
  final String? title;
  final List<Widget> children;
  const SettingsGroup({super.key, this.title, required this.children});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xs, 0, 0, AppSpacing.sm),
            child: Semantics(
              header: true,
              child: Text(title!.toUpperCase(), style: t.textTheme.labelSmall?.copyWith(letterSpacing: 0.8, fontWeight: FontWeight.w700)),
            ),
          ),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[if (i > 0) Divider(indent: 68, color: t.colorScheme.outlineVariant), children[i]],
            ],
          ),
        ),
      ],
    );
  }
}

/// Row with a tinted icon, title, optional subtitle and chevron.
class SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  const SettingsTile({super.key, required this.icon, required this.title, this.subtitle, this.onTap, this.trailing});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: t.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(AppRadius.control - 2)),
                child: Icon(icon, size: AppIconSize.md, color: t.colorScheme.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: t.textTheme.titleSmall?.copyWith(fontSize: 15)),
                    if (subtitle != null) Text(subtitle!, style: t.textTheme.bodySmall),
                  ],
                ),
              ),
              trailing ?? (onTap != null ? Icon(Icons.chevron_right_rounded, color: t.colorScheme.onSurfaceVariant) : const SizedBox.shrink()),
            ],
          ),
        ),
      ),
    );
  }
}
