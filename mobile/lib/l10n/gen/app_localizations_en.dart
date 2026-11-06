// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'ORLEU';

  @override
  String get tagline => 'Your Business. Your Growth.';

  @override
  String get signIn => 'Sign in';

  @override
  String get createAccount => 'Create account';

  @override
  String get noAccountYet => 'No account yet? Create one';

  @override
  String get haveAccount => 'Already have an account? Sign in';

  @override
  String get email => 'E-mail';

  @override
  String get password => 'Password';

  @override
  String get fullName => 'Full name';

  @override
  String get logout => 'Sign out';

  @override
  String get validationRequired => 'Required';

  @override
  String get validationEmail => 'Enter a valid e-mail';

  @override
  String get validationPasswordShort => 'At least 10 characters';

  @override
  String get validationSlug => '3-60 chars: lowercase letters, digits, hyphens';

  @override
  String get errInvalidCredentials => 'Wrong e-mail or password';

  @override
  String get errEmailTaken => 'An account with this e-mail already exists';

  @override
  String get errAccountLocked => 'Too many attempts. Try again later.';

  @override
  String get errSlugTaken => 'This booking-page address is already taken';

  @override
  String get errNetwork => 'No connection to the server';

  @override
  String get errGeneric => 'Something went wrong. Please try again.';

  @override
  String get errInvalidTransition =>
      'This change is not allowed for the booking';

  @override
  String get retry => 'Retry';

  @override
  String get navHome => 'Home';

  @override
  String get navCalendar => 'Calendar';

  @override
  String get navCustomers => 'Customers';

  @override
  String get navFinance => 'Finance';

  @override
  String get navMore => 'More';

  @override
  String greeting(String name) {
    return 'Hello, $name';
  }

  @override
  String get todayCollected => 'Collected today';

  @override
  String get todayBookings => 'Bookings today';

  @override
  String get pendingBookings => 'Awaiting action';

  @override
  String get upcoming => 'Upcoming';

  @override
  String get nothingUpcoming => 'No upcoming bookings today';

  @override
  String get createBusinessTitle => 'Set up your business';

  @override
  String get createBusinessIntro =>
      'Create your business to start accepting bookings.';

  @override
  String get businessName => 'Business name';

  @override
  String get bookingPageAddress => 'Booking page address';

  @override
  String get businessType => 'Business type';

  @override
  String get create => 'Create';

  @override
  String get typeBarbershop => 'Barbershop';

  @override
  String get typeBeautySalon => 'Beauty salon';

  @override
  String get typeClinic => 'Clinic';

  @override
  String get typeFitness => 'Fitness studio';

  @override
  String get typeOther => 'Other';

  @override
  String get noBookings => 'No bookings for this day';

  @override
  String get statusPending => 'Pending';

  @override
  String get statusAwaitingPayment => 'Awaiting payment';

  @override
  String get statusConfirmed => 'Confirmed';

  @override
  String get statusCheckedIn => 'Checked in';

  @override
  String get statusInProgress => 'In progress';

  @override
  String get statusCompleted => 'Completed';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get statusNoShow => 'No-show';

  @override
  String get statusExpired => 'Expired';

  @override
  String get actionConfirm => 'Confirm';

  @override
  String get actionCheckIn => 'Check in';

  @override
  String get actionStart => 'Start';

  @override
  String get actionComplete => 'Complete';

  @override
  String get actionNoShow => 'Mark no-show';

  @override
  String get actionCancel => 'Cancel booking';

  @override
  String get price => 'Price';

  @override
  String get deposit => 'Deposit';

  @override
  String get paid => 'Paid';

  @override
  String get remaining => 'Remaining';

  @override
  String get paymentStatus => 'Payment';

  @override
  String get payUnpaid => 'Unpaid';

  @override
  String get payPartial => 'Partially paid';

  @override
  String get payDepositPaid => 'Deposit paid';

  @override
  String get payPaid => 'Paid in full';

  @override
  String get payRefunded => 'Refunded';

  @override
  String get employee => 'Employee';

  @override
  String get customer => 'Customer';

  @override
  String get searchCustomers => 'Search by name or phone';

  @override
  String get noCustomers => 'No customers found';

  @override
  String get financeTitle => 'Finance, last 30 days';

  @override
  String get bookedValue => 'Booked value';

  @override
  String get collected => 'Collected';

  @override
  String get refunded => 'Refunded';

  @override
  String get netCollected => 'Net collected';

  @override
  String get outstanding => 'Outstanding balance';

  @override
  String get cancellationRate => 'Cancellation rate';

  @override
  String get noShowRate => 'No-show rate';

  @override
  String get financeNote =>
      'Booked value is not cash: collected payments are shown separately.';

  @override
  String get language => 'Language';

  @override
  String get theme => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get plan => 'Plan';

  @override
  String planUsage(int used, int limit) {
    return '$used of $limit employees';
  }

  @override
  String get setupTitle => 'Business setup';

  @override
  String get setupIntro => 'Complete these steps to open online booking.';

  @override
  String get stepBranch => 'Add a location';

  @override
  String get stepHours => 'Set working hours';

  @override
  String get stepService => 'Add a service';

  @override
  String get stepEmployee => 'Add a specialist and assign services';

  @override
  String get stepPublish => 'Publish your booking page';

  @override
  String get branches => 'Locations & hours';

  @override
  String get addBranch => 'Add location';

  @override
  String get branchName => 'Location name';

  @override
  String get address => 'Address (optional)';

  @override
  String get workingHours => 'Working hours';

  @override
  String get closed => 'Closed';

  @override
  String get applyDefaultHours => 'Mon–Sun 09:00–18:00';

  @override
  String get save => 'Save';

  @override
  String get saved => 'Saved';

  @override
  String get cancel => 'Cancel';

  @override
  String get services => 'Services';

  @override
  String get addService => 'Add service';

  @override
  String get serviceName => 'Service name';

  @override
  String get durationMin => 'Duration, minutes';

  @override
  String get priceField => 'Price';

  @override
  String get depositPercentOptional => 'Deposit % (optional)';

  @override
  String get bufferMin => 'Cleanup buffer, minutes (optional)';

  @override
  String get noneYet => 'Nothing here yet';

  @override
  String get employees => 'Specialists';

  @override
  String get addEmployee => 'Add specialist';

  @override
  String get employeeName => 'Specialist name';

  @override
  String get assignLocations => 'Works at';

  @override
  String get assignServices => 'Performs';

  @override
  String get publish => 'Publish booking page';

  @override
  String get unpublish => 'Take offline';

  @override
  String get publishedHint => 'Your booking page is live';

  @override
  String get bookingLink => 'Booking link';

  @override
  String get copyLink => 'Copy link';

  @override
  String get copied => 'Copied';

  @override
  String get errLimit =>
      'Your plan limit is reached. Contact ORLEU to upgrade.';

  @override
  String get errNotReady =>
      'Finish the setup steps first: location with hours, a service and an assigned specialist.';

  @override
  String get errSuspended =>
      'This business is suspended. Please contact ORLEU support.';

  @override
  String get setupNav => 'Business setup';

  @override
  String get minutesShort => 'min';

  @override
  String get newBooking => 'New booking';

  @override
  String get selectService => 'Service';

  @override
  String get selectLocation => 'Location';

  @override
  String get selectSpecialist => 'Specialist';

  @override
  String get anySpecialist => 'Any available';

  @override
  String get pickDate => 'Date';

  @override
  String get pickTime => 'Time';

  @override
  String get noSlots => 'No free times on this day';

  @override
  String get clientName => 'Client name';

  @override
  String get clientPhone => 'Client phone';

  @override
  String get validationPhone =>
      'Use international format, e.g. +7 701 123 45 67';

  @override
  String get notesOptional => 'Notes (optional)';

  @override
  String get bookAction => 'Create booking';

  @override
  String get rescheduleAction => 'Reschedule';

  @override
  String get rescheduleTitle => 'Move booking';

  @override
  String get moveHere => 'Move';

  @override
  String get errSlot => 'This time is no longer available. Pick another.';

  @override
  String get errBlockedCustomer => 'This client is blocked.';

  @override
  String get setupFirst =>
      'Finish business setup first: a location, a service and a specialist.';

  @override
  String get bookingCreated => 'Booking created';

  @override
  String get bookingMoved => 'Booking moved';

  @override
  String get recordPayment => 'Record payment';

  @override
  String get paymentAmount => 'Amount';

  @override
  String get paymentMethod => 'Method';

  @override
  String get methodCash => 'Cash';

  @override
  String get methodBank => 'Bank transfer';

  @override
  String get methodCard => 'Card (manual)';

  @override
  String get errOverpayment => 'The amount exceeds the remaining balance.';

  @override
  String get paymentRecorded => 'Payment recorded';

  @override
  String get validationAmount => 'Enter an amount up to the remaining balance';

  @override
  String get statVisits => 'Visits';

  @override
  String get statCancelled => 'Cancellations';

  @override
  String get statNoShows => 'No-shows';

  @override
  String get statUpcoming => 'Upcoming';

  @override
  String get statLastVisit => 'Last visit';

  @override
  String get statSpent => 'Total paid';

  @override
  String get statAvg => 'Average per visit';

  @override
  String get noVisitsYet => 'No visits yet';

  @override
  String get historyTitle => 'Booking history';

  @override
  String get noHistory => 'No bookings yet';

  @override
  String get notes => 'Notes';

  @override
  String get editClient => 'Edit client';

  @override
  String get marketingConsent => 'Agrees to marketing messages';

  @override
  String get blockClient => 'Block client';

  @override
  String get unblockClient => 'Unblock client';

  @override
  String get blockConfirm =>
      'A blocked client cannot book online and cannot be booked by staff.';

  @override
  String get blocked => 'Blocked';

  @override
  String get edit => 'Edit';

  @override
  String get active => 'Active';

  @override
  String get inactive => 'Inactive';

  @override
  String get deactivateNote =>
      'Inactive items disappear from booking. Existing bookings and history are kept.';

  @override
  String get editService => 'Edit service';

  @override
  String get editLocation => 'Edit location';

  @override
  String get editSpecialist => 'Edit specialist';

  @override
  String get statsNote =>
      'Paid = cash collected minus refunds, not booked value.';

  @override
  String get reportsTitle => 'Reports';

  @override
  String reportPeriodDays(String n) {
    return '$n days';
  }

  @override
  String get reportRevenueByDay => 'Cash collected per day (net of refunds)';

  @override
  String get reportTopServices => 'Services';

  @override
  String get reportTopEmployees => 'Specialists';

  @override
  String get reportBranches => 'Branches';

  @override
  String get reportPeakHours => 'Busiest hours';

  @override
  String get reportCustomers => 'New vs returning customers';

  @override
  String get reportNew => 'New';

  @override
  String get reportReturning => 'Returning';

  @override
  String get reportNoData => 'No data for this period yet';

  @override
  String reportBookingsN(String n) {
    return '$n bookings';
  }

  @override
  String reportReturningShare(String p) {
    return '$p% of customers returned';
  }

  @override
  String get reportsNote =>
      'Figures come from recorded bookings and payments for the selected period. Cancelled bookings are not counted as demand.';

  @override
  String get messagesNav => 'Customer messages';

  @override
  String get messagesReminder => 'Remind customers before the visit';

  @override
  String get messagesReminderOff => 'Off';

  @override
  String messagesReminderHours(String n) {
    return '$n h before';
  }

  @override
  String get messagesLanguage => 'Language of customer messages';

  @override
  String get messagesPrepared => 'Prepared messages';

  @override
  String get messagesNone => 'No messages prepared yet';

  @override
  String get messagesNotSent => 'Not sent';

  @override
  String get messagesNote =>
      'Sending by SMS or e-mail is not connected yet: messages are prepared and listed here, but nothing is delivered to customers.';

  @override
  String get messagesSaved => 'Saved';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get resetIntro =>
      'Enter your account e-mail to request a password reset code.';

  @override
  String get resetRequest => 'Request reset code';

  @override
  String get resetRequested =>
      'If an account exists for this e-mail, a reset code was requested. Enter the code you received and choose a new password.';

  @override
  String get resetCode => 'Reset code';

  @override
  String get newPassword => 'New password';

  @override
  String get resetConfirm => 'Set new password';

  @override
  String get resetDone =>
      'Your password was changed. Sign in with the new password.';

  @override
  String get backToSignIn => 'Back to sign in';

  @override
  String get errWrongPassword => 'The current password is incorrect';

  @override
  String get errResetToken => 'This reset code is invalid or has expired';

  @override
  String get accountNav => 'Account & security';

  @override
  String get changePassword => 'Change password';

  @override
  String get currentPassword => 'Current password';

  @override
  String get confirmPassword => 'Repeat new password';

  @override
  String get passwordsDiffer => 'Passwords do not match';

  @override
  String get passwordChanged =>
      'Password changed. Other devices were signed out.';

  @override
  String get sessionsTitle => 'Signed-in devices';

  @override
  String get sessionsNote =>
      'Changing your password signs out all other devices. Revoking the session of this device signs you out here too.';

  @override
  String get sessionRevoke => 'Sign out';

  @override
  String get sessionUnknownDevice => 'Unknown device';

  @override
  String sessionSince(String date) {
    return 'Since $date';
  }

  @override
  String get signOutEverywhere => 'Sign out on all devices';

  @override
  String get sessionsNone => 'No active sessions';

  @override
  String get calDay => 'Day';

  @override
  String get calWeek => 'Week';

  @override
  String get calMonth => 'Month';

  @override
  String get filterAllSpecialists => 'All specialists';

  @override
  String get filterAllLocations => 'All locations';

  @override
  String calBookingsCount(int n) {
    return '$n bookings';
  }

  @override
  String get reviewsNav => 'Reviews';

  @override
  String get reviewsAverage => 'Average rating';

  @override
  String reviewsCount(int n) {
    return '$n reviews';
  }

  @override
  String get reviewsNone =>
      'No reviews yet. Customers can review a completed visit from their booking link.';

  @override
  String get reviewsNote =>
      'Reviews come only from completed visits and cannot be edited by the business.';

  @override
  String get supportNav => 'Support';

  @override
  String get supportIntro =>
      'Write to the ORLEU team about billing, technical or account problems. Answers appear here.';

  @override
  String get supportNew => 'New request';

  @override
  String get supportSubject => 'Subject';

  @override
  String get supportBody => 'Describe the problem';

  @override
  String get supportCategory => 'Topic';

  @override
  String get catBILLING => 'Billing';

  @override
  String get catTECHNICAL => 'Technical';

  @override
  String get catACCOUNT => 'Account';

  @override
  String get catOTHER => 'Other';

  @override
  String get supportCreate => 'Send request';

  @override
  String get supportNone => 'No requests yet';

  @override
  String get stOPEN => 'Waiting for support';

  @override
  String get stANSWERED => 'Answered';

  @override
  String get stCLOSED => 'Closed';

  @override
  String get supportReply => 'Your reply';

  @override
  String get supportSend => 'Send';

  @override
  String get supportCloseTicket => 'Close request';

  @override
  String get supportClosedNote =>
      'This request is closed. Open a new one if you still need help.';

  @override
  String get supportTeam => 'ORLEU support';

  @override
  String get supportYou => 'You';

  @override
  String get errTicketClosed => 'This request is closed';

  @override
  String get errTooManyTickets =>
      'Too many open requests. Close some or wait for answers.';

  @override
  String get notifTitle => 'Notifications';

  @override
  String get notifMarkAll => 'Mark all as read';

  @override
  String get notifNone => 'No notifications yet';

  @override
  String get notifBOOKING_CREATED => 'New booking';

  @override
  String get notifBOOKING_CONFIRMED => 'Booking confirmed';

  @override
  String get notifBOOKING_CANCELLED => 'Booking cancelled';

  @override
  String get notifBOOKING_RESCHEDULED => 'Booking rescheduled';

  @override
  String get notifBOOKING_EXPIRED => 'Unpaid booking expired';

  @override
  String get notifBOOKING_CHECKED_IN => 'Customer arrived';

  @override
  String get notifBOOKING_IN_PROGRESS => 'Visit started';

  @override
  String get notifBOOKING_COMPLETED => 'Visit completed';

  @override
  String get notifBOOKING_NO_SHOW => 'Customer did not show up';

  @override
  String get notifBOOKING_REMINDER => 'Reminder prepared for a customer';

  @override
  String get notifPAYMENT_RECEIVED => 'Payment recorded';

  @override
  String get notifSUPPORT_REPLIED => 'ORLEU support replied to your request';

  @override
  String get notifOther => 'Update';

  @override
  String get importNav => 'Import clients (CSV)';

  @override
  String get importIntro =>
      'Export your spreadsheet as CSV (UTF-8). The first row names the columns: name and phone are required, e-mail and notes are optional. Clients that already exist are never changed, and imported clients are not marked as agreeing to marketing messages.';

  @override
  String get importChoose => 'Choose CSV file';

  @override
  String importFile(String name) {
    return 'File: $name';
  }

  @override
  String get importNew => 'New clients';

  @override
  String get importExisting => 'Already in your list';

  @override
  String get importDupes => 'Duplicates inside the file';

  @override
  String get importInvalid => 'Rows with problems';

  @override
  String get importProblems => 'Rows that will be skipped';

  @override
  String importRow(String row, String reason) {
    return 'Row $row: $reason';
  }

  @override
  String get imp_PHONE_INVALID => 'invalid phone number';

  @override
  String get imp_NAME_MISSING => 'name is missing';

  @override
  String get imp_NAME_TOO_LONG => 'name is too long';

  @override
  String get imp_EMAIL_INVALID => 'invalid e-mail';

  @override
  String get imp_NOTES_TOO_LONG => 'notes are too long';

  @override
  String get importMoreProblems => '…and more rows with problems';

  @override
  String importConfirm(String n) {
    return 'Import $n clients';
  }

  @override
  String get importNothing => 'Nothing new to import';

  @override
  String importDone(String n) {
    return 'Imported $n clients';
  }

  @override
  String get importAnother => 'Import another file';

  @override
  String get importPreviewSample => 'First new clients';

  @override
  String get errImportEmpty => 'The file is empty or has no client rows';

  @override
  String get errImportColumns =>
      'The first row must contain a name column and a phone column';

  @override
  String get errImportTooLarge =>
      'The file is too large (at most 5000 clients, 2 MB)';

  @override
  String get errImportEncoding =>
      'The file is not UTF-8. In Excel choose \"CSV UTF-8\" when saving.';

  @override
  String get exportTitle => 'Export for accounting';

  @override
  String get exportNote =>
      'CSV of all payments and refunds in the selected period (refunds negative, business time). It contains no customer names or phone numbers and is not a fiscal document.';

  @override
  String get exportComma => 'Comma';

  @override
  String get exportSemicolon => 'Semicolon (Excel RU/KZ)';

  @override
  String get exportButton => 'Export CSV';

  @override
  String get exportSaved => 'File saved';

  @override
  String get exportCancelled => 'Not saved';

  @override
  String get errExportTooLarge => 'Too many entries: choose a shorter period';

  @override
  String get errExportForbidden => 'Your role cannot export financial data';

  @override
  String get mfaTitle => 'Two-factor authentication';

  @override
  String get mfaIntro =>
      'Protect your account with a code from an authenticator app (Google Authenticator, Microsoft Authenticator, Aegis, …). Sign-in then needs your password and a code.';

  @override
  String get mfaOff => 'Off';

  @override
  String mfaOn(int n) {
    return 'On · $n recovery codes left';
  }

  @override
  String get mfaEnable => 'Turn on';

  @override
  String get mfaDisable => 'Turn off';

  @override
  String get mfaSetupKey => 'Setup key';

  @override
  String get mfaSetupHint =>
      'In your authenticator app add an account with this key (time-based), then enter the 6-digit code it shows.';

  @override
  String get mfaCopy => 'Copy key';

  @override
  String get mfaCode => '6-digit code';

  @override
  String get mfaConfirm => 'Confirm';

  @override
  String get mfaRecoveryTitle => 'Recovery codes';

  @override
  String get mfaRecoveryNote =>
      'Store these codes somewhere safe. Each works once if you lose your phone. They are shown only now.';

  @override
  String get mfaSaved => 'I saved them';

  @override
  String get mfaDisableHint =>
      'Enter your password and a current code (or a recovery code).';

  @override
  String get mfaLoginTitle =>
      'Enter the code from your authenticator app, or a recovery code.';

  @override
  String get mfaVerify => 'Verify';

  @override
  String get errMfaCode => 'The code is not correct';

  @override
  String get errMfaChallenge =>
      'The sign-in attempt expired. Please sign in again.';

  @override
  String get errMfaRequired =>
      'Two-factor authentication is required for this account';

  @override
  String get histTitle => 'Recent sign-ins';

  @override
  String histAlertFailed(int n) {
    return '$n failed sign-in attempts since your last successful sign-in.';
  }

  @override
  String get histAlertNewDevice =>
      'A sign-in from a new device was recorded in the last 7 days.';

  @override
  String get histAlertHint =>
      'If this was not you, change your password and sign out on all devices.';

  @override
  String get histSUCCESS => 'Signed in';

  @override
  String get histFAILED_PASSWORD => 'Wrong password';

  @override
  String get histFAILED_MFA => 'Wrong code';

  @override
  String get histLOCKED => 'Blocked: too many attempts';

  @override
  String get histNewDevice => 'New device';

  @override
  String get histWithCode => 'with code';

  @override
  String get histNone => 'No sign-ins recorded yet';

  @override
  String get histNote =>
      'Kept for 90 days. The device is recognised by its app or browser type, not proven.';

  @override
  String get privacyExport => 'Export client data';

  @override
  String get privacyDelete => 'Delete personal data';

  @override
  String get privacyDeleteWarn =>
      'This removes the name, phone, e-mail, notes and messages of this client for good and cannot be undone. Bookings and payments stay for your accounting, without personal data.';

  @override
  String get privacyConfirm => 'Delete for good';

  @override
  String get privacyDone => 'Personal data deleted';

  @override
  String get errHasUpcoming =>
      'Cancel the upcoming bookings of this client first';

  @override
  String get privacySaved => 'File saved';

  @override
  String get retentionTitle => 'Automatic deletion of inactive clients';

  @override
  String get retentionNote =>
      'Anonymise clients who had no booking for this long (never those with upcoming bookings). Off by default. Check what the law requires in your country.';

  @override
  String get retentionOff => 'Off';

  @override
  String retentionYears(String n) {
    return '$n years';
  }
}
