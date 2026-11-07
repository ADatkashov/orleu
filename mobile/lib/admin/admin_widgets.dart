import 'package:flutter/material.dart';

import '../core/api/api_client.dart';
import '../core/design/tokens.dart';
import '../core/widgets/widgets.dart';
import 'admin_data.dart';

/// Localization-free (English) error text for the admin console. Raw server messages are never shown.
String adminError(Object error) {
  final e = ApiError.from(error);
  if (e.isNetwork) return 'No connection to the server.';
  return switch (e.code) {
    'REASON_REQUIRED' => 'A reason is required.',
    'INVALID_EXPIRY' => 'The expiry must be in the future.',
    'INVALID_LIMITS' => 'Limits must be at least 1.',
    'NOT_FOUND' => 'Not found.',
    'FORBIDDEN' => 'You do not have permission for this action.',
    'INVALID_CREDENTIALS' => 'Wrong e-mail or password.',
    'ACCOUNT_LOCKED' => 'Too many attempts. Try again later.',
    'INVALID_MFA_CODE' => 'The code is not correct.',
    'INVALID_MFA_CHALLENGE' => 'The sign-in attempt expired. Please sign in again.',
    'MFA_REQUIRED' => 'Two-factor authentication is required for the admin console: enable it in the business app first.',
    'TICKET_CLOSED' => 'This ticket is closed. Reopen it first.',
    'CANNOT_DISABLE_SELF' => 'You cannot disable your own account.',
    'INVALID_MESSAGE' => 'The message must be 1-4000 characters.',
    _ => 'Something went wrong. Please try again.',
  };
}

Future<String?> adminAttempt(Future<void> Function() action) async {
  try {
    await action();
    return null;
  } catch (e) {
    return adminError(e);
  }
}

class InlineError extends StatelessWidget {
  final String? message;
  const InlineError(this.message, {super.key});
  @override
  Widget build(BuildContext context) => message == null
      ? const SizedBox.shrink()
      : Padding(padding: const EdgeInsets.only(top: 12), child: Text(message!, key: const Key('formError'), style: TextStyle(color: context.palette.dangerFg)));
}

class AdminError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const AdminError({super.key, required this.error, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(color: context.palette.dangerSoft, shape: BoxShape.circle),
              child: Icon(Icons.cloud_off_outlined, size: 28, color: context.palette.dangerFg),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(adminError(error), textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(onPressed: onRetry, child: const Text(S.retry)),
          ]),
        ),
      );
}

/// Status pill. [color] is one of the brand/semantic colors; it selects the matching soft-tint tone.
class Pill extends StatelessWidget {
  final String text;
  final Color color;
  const Pill(this.text, this.color, {super.key});
  @override
  Widget build(BuildContext context) {
    final tone = color == AppColors.success
        ? BadgeTone.success
        : color == AppColors.danger
            ? BadgeTone.danger
            : color == AppColors.warning
                ? BadgeTone.warning
                : color == AppColors.info
                    ? BadgeTone.info
                    : BadgeTone.accent;
    return StatusBadge(text, tone: tone, dot: false);
  }
}

Widget statusBadge(String status) => Pill(status, status == 'ACTIVE' ? AppColors.success : AppColors.danger);

class Pager extends StatelessWidget {
  final int page;
  final bool hasNext;
  final ValueChanged<int> onPage;
  const Pager({super.key, required this.page, required this.hasNext, required this.onPage});
  @override
  Widget build(BuildContext context) => Wrap(alignment: WrapAlignment.end, crossAxisAlignment: WrapCrossAlignment.center, runSpacing: 8, children: [
        OutlinedButton(key: const Key('prevPage'), onPressed: page > 0 ? () => onPage(page - 1) : null, child: const Text(S.previous)),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('${S.page} ${page + 1}')),
        OutlinedButton(key: const Key('nextPage'), onPressed: hasNext ? () => onPage(page + 1) : null, child: const Text(S.next)),
      ]);
}
