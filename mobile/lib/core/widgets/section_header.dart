import 'package:flutter/material.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle, actionLabel;
  final VoidCallback? onAction;
  const SectionHeader(this.title, {super.key, this.subtitle, this.actionLabel, this.onAction});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(header: true, child: Text(title, style: t.textTheme.titleLarge)),
              if (subtitle != null) Text(subtitle!, style: t.textTheme.bodySmall),
            ],
          ),
        ),
        if (actionLabel != null) TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}
