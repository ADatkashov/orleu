import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import '../design/tokens.dart';

/// Yes/no confirmation. Returns true only when the user confirms. [destructive] colors the confirm action as danger.
Future<bool> showConfirmationDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final l = AppLocalizations.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actionsPadding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: ctx.palette.danger, foregroundColor: AppColors.primaryDark, minimumSize: const Size(96, 44))
              : FilledButton.styleFrom(minimumSize: const Size(96, 44)),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}
