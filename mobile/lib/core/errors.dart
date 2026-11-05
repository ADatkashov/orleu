import 'package:flutter/widgets.dart';

import '../l10n/gen/app_localizations.dart';
import 'api/api_client.dart';

/// Maps backend error codes to localized, user-facing text. Raw server messages are never shown.
String errorText(BuildContext context, Object error) {
  final l = AppLocalizations.of(context);
  final e = ApiError.from(error);
  if (e.isNetwork) return l.errNetwork;
  return switch (e.code) {
    'INVALID_CREDENTIALS' => l.errInvalidCredentials,
    'EMAIL_TAKEN' || 'ACCOUNT_EXISTS' => l.errEmailTaken,
    'ACCOUNT_LOCKED' => l.errAccountLocked,
    'SLUG_TAKEN' => l.errSlugTaken,
    'INVALID_TRANSITION' || 'PAYMENT_REQUIRED' => l.errInvalidTransition,
    'BRANCH_LIMIT_REACHED' || 'EMPLOYEE_LIMIT_REACHED' => l.errLimit,
    'NOT_READY_TO_PUBLISH' => l.errNotReady,
    'BUSINESS_SUSPENDED' => l.errSuspended,
    _ => l.errGeneric,
  };
}
