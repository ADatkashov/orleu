import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_kk.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('kk'),
    Locale('ru'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'ORLEU'**
  String get appName;

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'Your Business. Your Growth.'**
  String get tagline;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccount;

  /// No description provided for @noAccountYet.
  ///
  /// In en, this message translates to:
  /// **'No account yet? Create one'**
  String get noAccountYet;

  /// No description provided for @haveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get haveAccount;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'E-mail'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullName;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get logout;

  /// No description provided for @validationRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get validationRequired;

  /// No description provided for @validationEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid e-mail'**
  String get validationEmail;

  /// No description provided for @validationPasswordShort.
  ///
  /// In en, this message translates to:
  /// **'At least 10 characters'**
  String get validationPasswordShort;

  /// No description provided for @validationSlug.
  ///
  /// In en, this message translates to:
  /// **'3-60 chars: lowercase letters, digits, hyphens'**
  String get validationSlug;

  /// No description provided for @errInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Wrong e-mail or password'**
  String get errInvalidCredentials;

  /// No description provided for @errEmailTaken.
  ///
  /// In en, this message translates to:
  /// **'An account with this e-mail already exists'**
  String get errEmailTaken;

  /// No description provided for @errAccountLocked.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again later.'**
  String get errAccountLocked;

  /// No description provided for @errSlugTaken.
  ///
  /// In en, this message translates to:
  /// **'This booking-page address is already taken'**
  String get errSlugTaken;

  /// No description provided for @errNetwork.
  ///
  /// In en, this message translates to:
  /// **'No connection to the server'**
  String get errNetwork;

  /// No description provided for @errGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errGeneric;

  /// No description provided for @errInvalidTransition.
  ///
  /// In en, this message translates to:
  /// **'This change is not allowed for the booking'**
  String get errInvalidTransition;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get navCalendar;

  /// No description provided for @navCustomers.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get navCustomers;

  /// No description provided for @navFinance.
  ///
  /// In en, this message translates to:
  /// **'Finance'**
  String get navFinance;

  /// No description provided for @navMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get navMore;

  /// No description provided for @greeting.
  ///
  /// In en, this message translates to:
  /// **'Hello, {name}'**
  String greeting(String name);

  /// No description provided for @todayCollected.
  ///
  /// In en, this message translates to:
  /// **'Collected today'**
  String get todayCollected;

  /// No description provided for @todayBookings.
  ///
  /// In en, this message translates to:
  /// **'Bookings today'**
  String get todayBookings;

  /// No description provided for @pendingBookings.
  ///
  /// In en, this message translates to:
  /// **'Awaiting action'**
  String get pendingBookings;

  /// No description provided for @upcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get upcoming;

  /// No description provided for @nothingUpcoming.
  ///
  /// In en, this message translates to:
  /// **'No upcoming bookings today'**
  String get nothingUpcoming;

  /// No description provided for @createBusinessTitle.
  ///
  /// In en, this message translates to:
  /// **'Set up your business'**
  String get createBusinessTitle;

  /// No description provided for @createBusinessIntro.
  ///
  /// In en, this message translates to:
  /// **'Create your business to start accepting bookings.'**
  String get createBusinessIntro;

  /// No description provided for @businessName.
  ///
  /// In en, this message translates to:
  /// **'Business name'**
  String get businessName;

  /// No description provided for @bookingPageAddress.
  ///
  /// In en, this message translates to:
  /// **'Booking page address'**
  String get bookingPageAddress;

  /// No description provided for @businessType.
  ///
  /// In en, this message translates to:
  /// **'Business type'**
  String get businessType;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @typeBarbershop.
  ///
  /// In en, this message translates to:
  /// **'Barbershop'**
  String get typeBarbershop;

  /// No description provided for @typeBeautySalon.
  ///
  /// In en, this message translates to:
  /// **'Beauty salon'**
  String get typeBeautySalon;

  /// No description provided for @typeClinic.
  ///
  /// In en, this message translates to:
  /// **'Clinic'**
  String get typeClinic;

  /// No description provided for @typeFitness.
  ///
  /// In en, this message translates to:
  /// **'Fitness studio'**
  String get typeFitness;

  /// No description provided for @typeOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get typeOther;

  /// No description provided for @noBookings.
  ///
  /// In en, this message translates to:
  /// **'No bookings for this day'**
  String get noBookings;

  /// No description provided for @statusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get statusPending;

  /// No description provided for @statusAwaitingPayment.
  ///
  /// In en, this message translates to:
  /// **'Awaiting payment'**
  String get statusAwaitingPayment;

  /// No description provided for @statusConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get statusConfirmed;

  /// No description provided for @statusCheckedIn.
  ///
  /// In en, this message translates to:
  /// **'Checked in'**
  String get statusCheckedIn;

  /// No description provided for @statusInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get statusInProgress;

  /// No description provided for @statusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get statusCompleted;

  /// No description provided for @statusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get statusCancelled;

  /// No description provided for @statusNoShow.
  ///
  /// In en, this message translates to:
  /// **'No-show'**
  String get statusNoShow;

  /// No description provided for @statusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get statusExpired;

  /// No description provided for @actionConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get actionConfirm;

  /// No description provided for @actionCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Check in'**
  String get actionCheckIn;

  /// No description provided for @actionStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get actionStart;

  /// No description provided for @actionComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get actionComplete;

  /// No description provided for @actionNoShow.
  ///
  /// In en, this message translates to:
  /// **'Mark no-show'**
  String get actionNoShow;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel booking'**
  String get actionCancel;

  /// No description provided for @price.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get price;

  /// No description provided for @deposit.
  ///
  /// In en, this message translates to:
  /// **'Deposit'**
  String get deposit;

  /// No description provided for @paid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paid;

  /// No description provided for @remaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get remaining;

  /// No description provided for @paymentStatus.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get paymentStatus;

  /// No description provided for @payUnpaid.
  ///
  /// In en, this message translates to:
  /// **'Unpaid'**
  String get payUnpaid;

  /// No description provided for @payPartial.
  ///
  /// In en, this message translates to:
  /// **'Partially paid'**
  String get payPartial;

  /// No description provided for @payDepositPaid.
  ///
  /// In en, this message translates to:
  /// **'Deposit paid'**
  String get payDepositPaid;

  /// No description provided for @payPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid in full'**
  String get payPaid;

  /// No description provided for @payRefunded.
  ///
  /// In en, this message translates to:
  /// **'Refunded'**
  String get payRefunded;

  /// No description provided for @employee.
  ///
  /// In en, this message translates to:
  /// **'Employee'**
  String get employee;

  /// No description provided for @customer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get customer;

  /// No description provided for @searchCustomers.
  ///
  /// In en, this message translates to:
  /// **'Search by name or phone'**
  String get searchCustomers;

  /// No description provided for @noCustomers.
  ///
  /// In en, this message translates to:
  /// **'No customers found'**
  String get noCustomers;

  /// No description provided for @financeTitle.
  ///
  /// In en, this message translates to:
  /// **'Finance, last 30 days'**
  String get financeTitle;

  /// No description provided for @bookedValue.
  ///
  /// In en, this message translates to:
  /// **'Booked value'**
  String get bookedValue;

  /// No description provided for @collected.
  ///
  /// In en, this message translates to:
  /// **'Collected'**
  String get collected;

  /// No description provided for @refunded.
  ///
  /// In en, this message translates to:
  /// **'Refunded'**
  String get refunded;

  /// No description provided for @netCollected.
  ///
  /// In en, this message translates to:
  /// **'Net collected'**
  String get netCollected;

  /// No description provided for @outstanding.
  ///
  /// In en, this message translates to:
  /// **'Outstanding balance'**
  String get outstanding;

  /// No description provided for @cancellationRate.
  ///
  /// In en, this message translates to:
  /// **'Cancellation rate'**
  String get cancellationRate;

  /// No description provided for @noShowRate.
  ///
  /// In en, this message translates to:
  /// **'No-show rate'**
  String get noShowRate;

  /// No description provided for @financeNote.
  ///
  /// In en, this message translates to:
  /// **'Booked value is not cash: collected payments are shown separately.'**
  String get financeNote;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @plan.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get plan;

  /// No description provided for @planUsage.
  ///
  /// In en, this message translates to:
  /// **'{used} of {limit} employees'**
  String planUsage(int used, int limit);

  /// No description provided for @setupTitle.
  ///
  /// In en, this message translates to:
  /// **'Business setup'**
  String get setupTitle;

  /// No description provided for @setupIntro.
  ///
  /// In en, this message translates to:
  /// **'Complete these steps to open online booking.'**
  String get setupIntro;

  /// No description provided for @stepBranch.
  ///
  /// In en, this message translates to:
  /// **'Add a location'**
  String get stepBranch;

  /// No description provided for @stepHours.
  ///
  /// In en, this message translates to:
  /// **'Set working hours'**
  String get stepHours;

  /// No description provided for @stepService.
  ///
  /// In en, this message translates to:
  /// **'Add a service'**
  String get stepService;

  /// No description provided for @stepEmployee.
  ///
  /// In en, this message translates to:
  /// **'Add a specialist and assign services'**
  String get stepEmployee;

  /// No description provided for @stepPublish.
  ///
  /// In en, this message translates to:
  /// **'Publish your booking page'**
  String get stepPublish;

  /// No description provided for @branches.
  ///
  /// In en, this message translates to:
  /// **'Locations & hours'**
  String get branches;

  /// No description provided for @addBranch.
  ///
  /// In en, this message translates to:
  /// **'Add location'**
  String get addBranch;

  /// No description provided for @branchName.
  ///
  /// In en, this message translates to:
  /// **'Location name'**
  String get branchName;

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'Address (optional)'**
  String get address;

  /// No description provided for @workingHours.
  ///
  /// In en, this message translates to:
  /// **'Working hours'**
  String get workingHours;

  /// No description provided for @closed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get closed;

  /// No description provided for @applyDefaultHours.
  ///
  /// In en, this message translates to:
  /// **'Mon–Sun 09:00–18:00'**
  String get applyDefaultHours;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @services.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get services;

  /// No description provided for @addService.
  ///
  /// In en, this message translates to:
  /// **'Add service'**
  String get addService;

  /// No description provided for @serviceName.
  ///
  /// In en, this message translates to:
  /// **'Service name'**
  String get serviceName;

  /// No description provided for @durationMin.
  ///
  /// In en, this message translates to:
  /// **'Duration, minutes'**
  String get durationMin;

  /// No description provided for @priceField.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get priceField;

  /// No description provided for @depositPercentOptional.
  ///
  /// In en, this message translates to:
  /// **'Deposit % (optional)'**
  String get depositPercentOptional;

  /// No description provided for @bufferMin.
  ///
  /// In en, this message translates to:
  /// **'Cleanup buffer, minutes (optional)'**
  String get bufferMin;

  /// No description provided for @noneYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get noneYet;

  /// No description provided for @employees.
  ///
  /// In en, this message translates to:
  /// **'Specialists'**
  String get employees;

  /// No description provided for @addEmployee.
  ///
  /// In en, this message translates to:
  /// **'Add specialist'**
  String get addEmployee;

  /// No description provided for @employeeName.
  ///
  /// In en, this message translates to:
  /// **'Specialist name'**
  String get employeeName;

  /// No description provided for @assignLocations.
  ///
  /// In en, this message translates to:
  /// **'Works at'**
  String get assignLocations;

  /// No description provided for @assignServices.
  ///
  /// In en, this message translates to:
  /// **'Performs'**
  String get assignServices;

  /// No description provided for @publish.
  ///
  /// In en, this message translates to:
  /// **'Publish booking page'**
  String get publish;

  /// No description provided for @unpublish.
  ///
  /// In en, this message translates to:
  /// **'Take offline'**
  String get unpublish;

  /// No description provided for @publishedHint.
  ///
  /// In en, this message translates to:
  /// **'Your booking page is live'**
  String get publishedHint;

  /// No description provided for @bookingLink.
  ///
  /// In en, this message translates to:
  /// **'Booking link'**
  String get bookingLink;

  /// No description provided for @copyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get copyLink;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @errLimit.
  ///
  /// In en, this message translates to:
  /// **'Your plan limit is reached. Contact ORLEU to upgrade.'**
  String get errLimit;

  /// No description provided for @errNotReady.
  ///
  /// In en, this message translates to:
  /// **'Finish the setup steps first: location with hours, a service and an assigned specialist.'**
  String get errNotReady;

  /// No description provided for @errSuspended.
  ///
  /// In en, this message translates to:
  /// **'This business is suspended. Please contact ORLEU support.'**
  String get errSuspended;

  /// No description provided for @setupNav.
  ///
  /// In en, this message translates to:
  /// **'Business setup'**
  String get setupNav;

  /// No description provided for @minutesShort.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get minutesShort;

  /// No description provided for @newBooking.
  ///
  /// In en, this message translates to:
  /// **'New booking'**
  String get newBooking;

  /// No description provided for @selectService.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get selectService;

  /// No description provided for @selectLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get selectLocation;

  /// No description provided for @selectSpecialist.
  ///
  /// In en, this message translates to:
  /// **'Specialist'**
  String get selectSpecialist;

  /// No description provided for @anySpecialist.
  ///
  /// In en, this message translates to:
  /// **'Any available'**
  String get anySpecialist;

  /// No description provided for @pickDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get pickDate;

  /// No description provided for @pickTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get pickTime;

  /// No description provided for @noSlots.
  ///
  /// In en, this message translates to:
  /// **'No free times on this day'**
  String get noSlots;

  /// No description provided for @clientName.
  ///
  /// In en, this message translates to:
  /// **'Client name'**
  String get clientName;

  /// No description provided for @clientPhone.
  ///
  /// In en, this message translates to:
  /// **'Client phone'**
  String get clientPhone;

  /// No description provided for @validationPhone.
  ///
  /// In en, this message translates to:
  /// **'Use international format, e.g. +7 701 123 45 67'**
  String get validationPhone;

  /// No description provided for @notesOptional.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get notesOptional;

  /// No description provided for @bookAction.
  ///
  /// In en, this message translates to:
  /// **'Create booking'**
  String get bookAction;

  /// No description provided for @rescheduleAction.
  ///
  /// In en, this message translates to:
  /// **'Reschedule'**
  String get rescheduleAction;

  /// No description provided for @rescheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'Move booking'**
  String get rescheduleTitle;

  /// No description provided for @moveHere.
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get moveHere;

  /// No description provided for @errSlot.
  ///
  /// In en, this message translates to:
  /// **'This time is no longer available. Pick another.'**
  String get errSlot;

  /// No description provided for @errBlockedCustomer.
  ///
  /// In en, this message translates to:
  /// **'This client is blocked.'**
  String get errBlockedCustomer;

  /// No description provided for @setupFirst.
  ///
  /// In en, this message translates to:
  /// **'Finish business setup first: a location, a service and a specialist.'**
  String get setupFirst;

  /// No description provided for @bookingCreated.
  ///
  /// In en, this message translates to:
  /// **'Booking created'**
  String get bookingCreated;

  /// No description provided for @bookingMoved.
  ///
  /// In en, this message translates to:
  /// **'Booking moved'**
  String get bookingMoved;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'kk', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'kk':
      return AppLocalizationsKk();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
