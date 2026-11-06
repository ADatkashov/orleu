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
    'WRONG_PASSWORD' => l.errWrongPassword,
    'INVALID_MFA_CODE' => l.errMfaCode,
    'INVALID_MFA_CHALLENGE' => l.errMfaChallenge,
    'MFA_REQUIRED' => l.errMfaRequired,
    'EXPORT_TOO_LARGE' => l.errExportTooLarge,
    'OVERLAPPING_RANGES' => l.errOverlap,
    'INVALID_RANGE' => l.errRangeOrder,
    'TOO_MANY_RANGES' => l.errTooManyRanges,
    'HAS_UPCOMING_BOOKINGS' => l.errHasUpcoming,
    'IMPORT_EMPTY' => l.errImportEmpty,
    'IMPORT_MISSING_COLUMNS' => l.errImportColumns,
    'IMPORT_TOO_LARGE' => l.errImportTooLarge,
    'TICKET_CLOSED' => l.errTicketClosed,
    'TOO_MANY_OPEN_TICKETS' => l.errTooManyTickets,
    'INVALID_RESET_TOKEN' => l.errResetToken,
    'SLUG_TAKEN' => l.errSlugTaken,
    'INVALID_TRANSITION' || 'PAYMENT_REQUIRED' => l.errInvalidTransition,
    'BRANCH_LIMIT_REACHED' || 'EMPLOYEE_LIMIT_REACHED' => l.errLimit,
    'NOT_READY_TO_PUBLISH' => l.errNotReady,
    'BUSINESS_SUSPENDED' => l.errSuspended,
    'SLOT_UNAVAILABLE' => l.errSlot,
    'PROMO_INVALID' => l.errPromo,
    'CODE_EXISTS' => l.errCodeExists,
    'OVERPAYMENT' => l.errOverpayment,
    'INVALID_NAME' => l.validationRequired,
    'FORBIDDEN' => l.errBlockedCustomer,
    _ => l.errGeneric,
  };
}
