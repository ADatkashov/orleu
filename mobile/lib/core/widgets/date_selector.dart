import 'package:flutter/material.dart';

import '../design/tokens.dart';

/// Previous / label / next control for stepping through days, weeks or months. The label opens [onPick] when given.
class DateSelector extends StatelessWidget {
  final String label;
  final VoidCallback onPrev, onNext;
  final VoidCallback? onPick;
  final String prevTooltip, nextTooltip;
  final Key? prevKey, nextKey, labelKey;
  const DateSelector({
    super.key,
    required this.label,
    required this.onPrev,
    required this.onNext,
    this.onPick,
    required this.prevTooltip,
    required this.nextTooltip,
    this.prevKey,
    this.nextKey,
    this.labelKey,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Row(
      children: [
        IconButton(
          key: prevKey,
          tooltip: prevTooltip,
          onPressed: onPrev,
          icon: const Icon(Icons.chevron_left_rounded, size: AppIconSize.lg + 2),
        ),
        Expanded(
          child: InkWell(
            key: labelKey,
            onTap: onPick,
            borderRadius: BorderRadius.circular(AppRadius.control),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.textTheme.titleMedium),
                  ),
                  if (onPick != null) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.expand_more_rounded, size: AppIconSize.md, color: t.colorScheme.onSurfaceVariant),
                  ],
                ],
              ),
            ),
          ),
        ),
        IconButton(
          key: nextKey,
          tooltip: nextTooltip,
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right_rounded, size: AppIconSize.lg + 2),
        ),
      ],
    );
  }
}
