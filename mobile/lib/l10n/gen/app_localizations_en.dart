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
}
