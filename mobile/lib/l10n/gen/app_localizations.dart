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

  /// No description provided for @recordPayment.
  ///
  /// In en, this message translates to:
  /// **'Record payment'**
  String get recordPayment;

  /// No description provided for @paymentAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get paymentAmount;

  /// No description provided for @paymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Method'**
  String get paymentMethod;

  /// No description provided for @methodCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get methodCash;

  /// No description provided for @methodBank.
  ///
  /// In en, this message translates to:
  /// **'Bank transfer'**
  String get methodBank;

  /// No description provided for @methodCard.
  ///
  /// In en, this message translates to:
  /// **'Card (manual)'**
  String get methodCard;

  /// No description provided for @errOverpayment.
  ///
  /// In en, this message translates to:
  /// **'The amount exceeds the remaining balance.'**
  String get errOverpayment;

  /// No description provided for @paymentRecorded.
  ///
  /// In en, this message translates to:
  /// **'Payment recorded'**
  String get paymentRecorded;

  /// No description provided for @validationAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount up to the remaining balance'**
  String get validationAmount;

  /// No description provided for @statVisits.
  ///
  /// In en, this message translates to:
  /// **'Visits'**
  String get statVisits;

  /// No description provided for @statCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancellations'**
  String get statCancelled;

  /// No description provided for @statNoShows.
  ///
  /// In en, this message translates to:
  /// **'No-shows'**
  String get statNoShows;

  /// No description provided for @statUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get statUpcoming;

  /// No description provided for @statLastVisit.
  ///
  /// In en, this message translates to:
  /// **'Last visit'**
  String get statLastVisit;

  /// No description provided for @statSpent.
  ///
  /// In en, this message translates to:
  /// **'Total paid'**
  String get statSpent;

  /// No description provided for @statAvg.
  ///
  /// In en, this message translates to:
  /// **'Average per visit'**
  String get statAvg;

  /// No description provided for @noVisitsYet.
  ///
  /// In en, this message translates to:
  /// **'No visits yet'**
  String get noVisitsYet;

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'Booking history'**
  String get historyTitle;

  /// No description provided for @noHistory.
  ///
  /// In en, this message translates to:
  /// **'No bookings yet'**
  String get noHistory;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @editClient.
  ///
  /// In en, this message translates to:
  /// **'Edit client'**
  String get editClient;

  /// No description provided for @marketingConsent.
  ///
  /// In en, this message translates to:
  /// **'Agrees to marketing messages'**
  String get marketingConsent;

  /// No description provided for @blockClient.
  ///
  /// In en, this message translates to:
  /// **'Block client'**
  String get blockClient;

  /// No description provided for @unblockClient.
  ///
  /// In en, this message translates to:
  /// **'Unblock client'**
  String get unblockClient;

  /// No description provided for @blockConfirm.
  ///
  /// In en, this message translates to:
  /// **'A blocked client cannot book online and cannot be booked by staff.'**
  String get blockConfirm;

  /// No description provided for @blocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get blocked;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @inactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get inactive;

  /// No description provided for @deactivateNote.
  ///
  /// In en, this message translates to:
  /// **'Inactive items disappear from booking. Existing bookings and history are kept.'**
  String get deactivateNote;

  /// No description provided for @editService.
  ///
  /// In en, this message translates to:
  /// **'Edit service'**
  String get editService;

  /// No description provided for @editLocation.
  ///
  /// In en, this message translates to:
  /// **'Edit location'**
  String get editLocation;

  /// No description provided for @editSpecialist.
  ///
  /// In en, this message translates to:
  /// **'Edit specialist'**
  String get editSpecialist;

  /// No description provided for @statsNote.
  ///
  /// In en, this message translates to:
  /// **'Paid = cash collected minus refunds, not booked value.'**
  String get statsNote;

  /// No description provided for @reportsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reportsTitle;

  /// No description provided for @reportPeriodDays.
  ///
  /// In en, this message translates to:
  /// **'{n} days'**
  String reportPeriodDays(String n);

  /// No description provided for @reportRevenueByDay.
  ///
  /// In en, this message translates to:
  /// **'Cash collected per day (net of refunds)'**
  String get reportRevenueByDay;

  /// No description provided for @reportTopServices.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get reportTopServices;

  /// No description provided for @reportTopEmployees.
  ///
  /// In en, this message translates to:
  /// **'Specialists'**
  String get reportTopEmployees;

  /// No description provided for @reportBranches.
  ///
  /// In en, this message translates to:
  /// **'Branches'**
  String get reportBranches;

  /// No description provided for @reportPeakHours.
  ///
  /// In en, this message translates to:
  /// **'Busiest hours'**
  String get reportPeakHours;

  /// No description provided for @reportCustomers.
  ///
  /// In en, this message translates to:
  /// **'New vs returning customers'**
  String get reportCustomers;

  /// No description provided for @reportNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get reportNew;

  /// No description provided for @reportReturning.
  ///
  /// In en, this message translates to:
  /// **'Returning'**
  String get reportReturning;

  /// No description provided for @reportNoData.
  ///
  /// In en, this message translates to:
  /// **'No data for this period yet'**
  String get reportNoData;

  /// No description provided for @reportBookingsN.
  ///
  /// In en, this message translates to:
  /// **'{n} bookings'**
  String reportBookingsN(String n);

  /// No description provided for @reportReturningShare.
  ///
  /// In en, this message translates to:
  /// **'{p}% of customers returned'**
  String reportReturningShare(String p);

  /// No description provided for @reportsNote.
  ///
  /// In en, this message translates to:
  /// **'Figures come from recorded bookings and payments for the selected period. Cancelled bookings are not counted as demand.'**
  String get reportsNote;

  /// No description provided for @messagesNav.
  ///
  /// In en, this message translates to:
  /// **'Customer messages'**
  String get messagesNav;

  /// No description provided for @messagesReminder.
  ///
  /// In en, this message translates to:
  /// **'Remind customers before the visit'**
  String get messagesReminder;

  /// No description provided for @messagesReminderOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get messagesReminderOff;

  /// No description provided for @messagesReminderHours.
  ///
  /// In en, this message translates to:
  /// **'{n} h before'**
  String messagesReminderHours(String n);

  /// No description provided for @messagesLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language of customer messages'**
  String get messagesLanguage;

  /// No description provided for @messagesPrepared.
  ///
  /// In en, this message translates to:
  /// **'Prepared messages'**
  String get messagesPrepared;

  /// No description provided for @messagesNone.
  ///
  /// In en, this message translates to:
  /// **'No messages prepared yet'**
  String get messagesNone;

  /// No description provided for @messagesNotSent.
  ///
  /// In en, this message translates to:
  /// **'Not sent'**
  String get messagesNotSent;

  /// No description provided for @messagesNote.
  ///
  /// In en, this message translates to:
  /// **'Sending by SMS or e-mail is not connected yet: messages are prepared and listed here, but nothing is delivered to customers.'**
  String get messagesNote;

  /// No description provided for @messagesSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get messagesSaved;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @resetIntro.
  ///
  /// In en, this message translates to:
  /// **'Enter your account e-mail to request a password reset code.'**
  String get resetIntro;

  /// No description provided for @resetRequest.
  ///
  /// In en, this message translates to:
  /// **'Request reset code'**
  String get resetRequest;

  /// No description provided for @resetRequested.
  ///
  /// In en, this message translates to:
  /// **'If an account exists for this e-mail, a reset code was requested. Enter the code you received and choose a new password.'**
  String get resetRequested;

  /// No description provided for @resetCode.
  ///
  /// In en, this message translates to:
  /// **'Reset code'**
  String get resetCode;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPassword;

  /// No description provided for @resetConfirm.
  ///
  /// In en, this message translates to:
  /// **'Set new password'**
  String get resetConfirm;

  /// No description provided for @resetDone.
  ///
  /// In en, this message translates to:
  /// **'Your password was changed. Sign in with the new password.'**
  String get resetDone;

  /// No description provided for @backToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get backToSignIn;

  /// No description provided for @errWrongPassword.
  ///
  /// In en, this message translates to:
  /// **'The current password is incorrect'**
  String get errWrongPassword;

  /// No description provided for @errResetToken.
  ///
  /// In en, this message translates to:
  /// **'This reset code is invalid or has expired'**
  String get errResetToken;

  /// No description provided for @accountNav.
  ///
  /// In en, this message translates to:
  /// **'Account & security'**
  String get accountNav;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePassword;

  /// No description provided for @currentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get currentPassword;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Repeat new password'**
  String get confirmPassword;

  /// No description provided for @passwordsDiffer.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDiffer;

  /// No description provided for @passwordChanged.
  ///
  /// In en, this message translates to:
  /// **'Password changed. Other devices were signed out.'**
  String get passwordChanged;

  /// No description provided for @sessionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Signed-in devices'**
  String get sessionsTitle;

  /// No description provided for @sessionsNote.
  ///
  /// In en, this message translates to:
  /// **'Changing your password signs out all other devices. Revoking the session of this device signs you out here too.'**
  String get sessionsNote;

  /// No description provided for @sessionRevoke.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get sessionRevoke;

  /// No description provided for @sessionUnknownDevice.
  ///
  /// In en, this message translates to:
  /// **'Unknown device'**
  String get sessionUnknownDevice;

  /// No description provided for @sessionSince.
  ///
  /// In en, this message translates to:
  /// **'Since {date}'**
  String sessionSince(String date);

  /// No description provided for @signOutEverywhere.
  ///
  /// In en, this message translates to:
  /// **'Sign out on all devices'**
  String get signOutEverywhere;

  /// No description provided for @sessionsNone.
  ///
  /// In en, this message translates to:
  /// **'No active sessions'**
  String get sessionsNone;

  /// No description provided for @calDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get calDay;

  /// No description provided for @calWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get calWeek;

  /// No description provided for @calMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get calMonth;

  /// No description provided for @filterAllSpecialists.
  ///
  /// In en, this message translates to:
  /// **'All specialists'**
  String get filterAllSpecialists;

  /// No description provided for @filterAllLocations.
  ///
  /// In en, this message translates to:
  /// **'All locations'**
  String get filterAllLocations;

  /// No description provided for @calBookingsCount.
  ///
  /// In en, this message translates to:
  /// **'{n} bookings'**
  String calBookingsCount(int n);

  /// No description provided for @reviewsNav.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get reviewsNav;

  /// No description provided for @reviewsAverage.
  ///
  /// In en, this message translates to:
  /// **'Average rating'**
  String get reviewsAverage;

  /// No description provided for @reviewsCount.
  ///
  /// In en, this message translates to:
  /// **'{n} reviews'**
  String reviewsCount(int n);

  /// No description provided for @reviewsNone.
  ///
  /// In en, this message translates to:
  /// **'No reviews yet. Customers can review a completed visit from their booking link.'**
  String get reviewsNone;

  /// No description provided for @reviewsNote.
  ///
  /// In en, this message translates to:
  /// **'Reviews come only from completed visits and cannot be edited by the business.'**
  String get reviewsNote;

  /// No description provided for @supportNav.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get supportNav;

  /// No description provided for @supportIntro.
  ///
  /// In en, this message translates to:
  /// **'Write to the ORLEU team about billing, technical or account problems. Answers appear here.'**
  String get supportIntro;

  /// No description provided for @supportNew.
  ///
  /// In en, this message translates to:
  /// **'New request'**
  String get supportNew;

  /// No description provided for @supportSubject.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get supportSubject;

  /// No description provided for @supportBody.
  ///
  /// In en, this message translates to:
  /// **'Describe the problem'**
  String get supportBody;

  /// No description provided for @supportCategory.
  ///
  /// In en, this message translates to:
  /// **'Topic'**
  String get supportCategory;

  /// No description provided for @catBILLING.
  ///
  /// In en, this message translates to:
  /// **'Billing'**
  String get catBILLING;

  /// No description provided for @catTECHNICAL.
  ///
  /// In en, this message translates to:
  /// **'Technical'**
  String get catTECHNICAL;

  /// No description provided for @catACCOUNT.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get catACCOUNT;

  /// No description provided for @catOTHER.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get catOTHER;

  /// No description provided for @supportCreate.
  ///
  /// In en, this message translates to:
  /// **'Send request'**
  String get supportCreate;

  /// No description provided for @supportNone.
  ///
  /// In en, this message translates to:
  /// **'No requests yet'**
  String get supportNone;

  /// No description provided for @stOPEN.
  ///
  /// In en, this message translates to:
  /// **'Waiting for support'**
  String get stOPEN;

  /// No description provided for @stANSWERED.
  ///
  /// In en, this message translates to:
  /// **'Answered'**
  String get stANSWERED;

  /// No description provided for @stCLOSED.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get stCLOSED;

  /// No description provided for @supportReply.
  ///
  /// In en, this message translates to:
  /// **'Your reply'**
  String get supportReply;

  /// No description provided for @supportSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get supportSend;

  /// No description provided for @supportCloseTicket.
  ///
  /// In en, this message translates to:
  /// **'Close request'**
  String get supportCloseTicket;

  /// No description provided for @supportClosedNote.
  ///
  /// In en, this message translates to:
  /// **'This request is closed. Open a new one if you still need help.'**
  String get supportClosedNote;

  /// No description provided for @supportTeam.
  ///
  /// In en, this message translates to:
  /// **'ORLEU support'**
  String get supportTeam;

  /// No description provided for @supportYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get supportYou;

  /// No description provided for @errTicketClosed.
  ///
  /// In en, this message translates to:
  /// **'This request is closed'**
  String get errTicketClosed;

  /// No description provided for @errTooManyTickets.
  ///
  /// In en, this message translates to:
  /// **'Too many open requests. Close some or wait for answers.'**
  String get errTooManyTickets;

  /// No description provided for @notifTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifTitle;

  /// No description provided for @notifMarkAll.
  ///
  /// In en, this message translates to:
  /// **'Mark all as read'**
  String get notifMarkAll;

  /// No description provided for @notifNone.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get notifNone;

  /// No description provided for @notifBOOKING_CREATED.
  ///
  /// In en, this message translates to:
  /// **'New booking'**
  String get notifBOOKING_CREATED;

  /// No description provided for @notifBOOKING_CONFIRMED.
  ///
  /// In en, this message translates to:
  /// **'Booking confirmed'**
  String get notifBOOKING_CONFIRMED;

  /// No description provided for @notifBOOKING_CANCELLED.
  ///
  /// In en, this message translates to:
  /// **'Booking cancelled'**
  String get notifBOOKING_CANCELLED;

  /// No description provided for @notifBOOKING_RESCHEDULED.
  ///
  /// In en, this message translates to:
  /// **'Booking rescheduled'**
  String get notifBOOKING_RESCHEDULED;

  /// No description provided for @notifBOOKING_EXPIRED.
  ///
  /// In en, this message translates to:
  /// **'Unpaid booking expired'**
  String get notifBOOKING_EXPIRED;

  /// No description provided for @notifBOOKING_CHECKED_IN.
  ///
  /// In en, this message translates to:
  /// **'Customer arrived'**
  String get notifBOOKING_CHECKED_IN;

  /// No description provided for @notifBOOKING_IN_PROGRESS.
  ///
  /// In en, this message translates to:
  /// **'Visit started'**
  String get notifBOOKING_IN_PROGRESS;

  /// No description provided for @notifBOOKING_COMPLETED.
  ///
  /// In en, this message translates to:
  /// **'Visit completed'**
  String get notifBOOKING_COMPLETED;

  /// No description provided for @notifBOOKING_NO_SHOW.
  ///
  /// In en, this message translates to:
  /// **'Customer did not show up'**
  String get notifBOOKING_NO_SHOW;

  /// No description provided for @notifBOOKING_REMINDER.
  ///
  /// In en, this message translates to:
  /// **'Reminder prepared for a customer'**
  String get notifBOOKING_REMINDER;

  /// No description provided for @notifPAYMENT_RECEIVED.
  ///
  /// In en, this message translates to:
  /// **'Payment recorded'**
  String get notifPAYMENT_RECEIVED;

  /// No description provided for @notifSUPPORT_REPLIED.
  ///
  /// In en, this message translates to:
  /// **'ORLEU support replied to your request'**
  String get notifSUPPORT_REPLIED;

  /// No description provided for @notifOther.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get notifOther;

  /// No description provided for @importNav.
  ///
  /// In en, this message translates to:
  /// **'Import clients (CSV)'**
  String get importNav;

  /// No description provided for @importIntro.
  ///
  /// In en, this message translates to:
  /// **'Export your spreadsheet as CSV (UTF-8). The first row names the columns: name and phone are required, e-mail and notes are optional. Clients that already exist are never changed, and imported clients are not marked as agreeing to marketing messages.'**
  String get importIntro;

  /// No description provided for @importChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose CSV file'**
  String get importChoose;

  /// No description provided for @importFile.
  ///
  /// In en, this message translates to:
  /// **'File: {name}'**
  String importFile(String name);

  /// No description provided for @importNew.
  ///
  /// In en, this message translates to:
  /// **'New clients'**
  String get importNew;

  /// No description provided for @importExisting.
  ///
  /// In en, this message translates to:
  /// **'Already in your list'**
  String get importExisting;

  /// No description provided for @importDupes.
  ///
  /// In en, this message translates to:
  /// **'Duplicates inside the file'**
  String get importDupes;

  /// No description provided for @importInvalid.
  ///
  /// In en, this message translates to:
  /// **'Rows with problems'**
  String get importInvalid;

  /// No description provided for @importProblems.
  ///
  /// In en, this message translates to:
  /// **'Rows that will be skipped'**
  String get importProblems;

  /// No description provided for @importRow.
  ///
  /// In en, this message translates to:
  /// **'Row {row}: {reason}'**
  String importRow(String row, String reason);

  /// No description provided for @imp_PHONE_INVALID.
  ///
  /// In en, this message translates to:
  /// **'invalid phone number'**
  String get imp_PHONE_INVALID;

  /// No description provided for @imp_NAME_MISSING.
  ///
  /// In en, this message translates to:
  /// **'name is missing'**
  String get imp_NAME_MISSING;

  /// No description provided for @imp_NAME_TOO_LONG.
  ///
  /// In en, this message translates to:
  /// **'name is too long'**
  String get imp_NAME_TOO_LONG;

  /// No description provided for @imp_EMAIL_INVALID.
  ///
  /// In en, this message translates to:
  /// **'invalid e-mail'**
  String get imp_EMAIL_INVALID;

  /// No description provided for @imp_NOTES_TOO_LONG.
  ///
  /// In en, this message translates to:
  /// **'notes are too long'**
  String get imp_NOTES_TOO_LONG;

  /// No description provided for @importMoreProblems.
  ///
  /// In en, this message translates to:
  /// **'…and more rows with problems'**
  String get importMoreProblems;

  /// No description provided for @importConfirm.
  ///
  /// In en, this message translates to:
  /// **'Import {n} clients'**
  String importConfirm(String n);

  /// No description provided for @importNothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing new to import'**
  String get importNothing;

  /// No description provided for @importDone.
  ///
  /// In en, this message translates to:
  /// **'Imported {n} clients'**
  String importDone(String n);

  /// No description provided for @importAnother.
  ///
  /// In en, this message translates to:
  /// **'Import another file'**
  String get importAnother;

  /// No description provided for @importPreviewSample.
  ///
  /// In en, this message translates to:
  /// **'First new clients'**
  String get importPreviewSample;

  /// No description provided for @errImportEmpty.
  ///
  /// In en, this message translates to:
  /// **'The file is empty or has no client rows'**
  String get errImportEmpty;

  /// No description provided for @errImportColumns.
  ///
  /// In en, this message translates to:
  /// **'The first row must contain a name column and a phone column'**
  String get errImportColumns;

  /// No description provided for @errImportTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The file is too large (at most 5000 clients, 2 MB)'**
  String get errImportTooLarge;

  /// No description provided for @errImportEncoding.
  ///
  /// In en, this message translates to:
  /// **'The file is not UTF-8. In Excel choose \"CSV UTF-8\" when saving.'**
  String get errImportEncoding;

  /// No description provided for @exportTitle.
  ///
  /// In en, this message translates to:
  /// **'Export for accounting'**
  String get exportTitle;

  /// No description provided for @exportNote.
  ///
  /// In en, this message translates to:
  /// **'CSV of all payments and refunds in the selected period (refunds negative, business time). It contains no customer names or phone numbers and is not a fiscal document.'**
  String get exportNote;

  /// No description provided for @exportComma.
  ///
  /// In en, this message translates to:
  /// **'Comma'**
  String get exportComma;

  /// No description provided for @exportSemicolon.
  ///
  /// In en, this message translates to:
  /// **'Semicolon (Excel RU/KZ)'**
  String get exportSemicolon;

  /// No description provided for @exportButton.
  ///
  /// In en, this message translates to:
  /// **'Export CSV'**
  String get exportButton;

  /// No description provided for @exportSaved.
  ///
  /// In en, this message translates to:
  /// **'File saved'**
  String get exportSaved;

  /// No description provided for @exportCancelled.
  ///
  /// In en, this message translates to:
  /// **'Not saved'**
  String get exportCancelled;

  /// No description provided for @errExportTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Too many entries: choose a shorter period'**
  String get errExportTooLarge;

  /// No description provided for @errExportForbidden.
  ///
  /// In en, this message translates to:
  /// **'Your role cannot export financial data'**
  String get errExportForbidden;

  /// No description provided for @mfaTitle.
  ///
  /// In en, this message translates to:
  /// **'Two-factor authentication'**
  String get mfaTitle;

  /// No description provided for @mfaIntro.
  ///
  /// In en, this message translates to:
  /// **'Protect your account with a code from an authenticator app (Google Authenticator, Microsoft Authenticator, Aegis, …). Sign-in then needs your password and a code.'**
  String get mfaIntro;

  /// No description provided for @mfaOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get mfaOff;

  /// No description provided for @mfaOn.
  ///
  /// In en, this message translates to:
  /// **'On · {n} recovery codes left'**
  String mfaOn(int n);

  /// No description provided for @mfaEnable.
  ///
  /// In en, this message translates to:
  /// **'Turn on'**
  String get mfaEnable;

  /// No description provided for @mfaDisable.
  ///
  /// In en, this message translates to:
  /// **'Turn off'**
  String get mfaDisable;

  /// No description provided for @mfaSetupKey.
  ///
  /// In en, this message translates to:
  /// **'Setup key'**
  String get mfaSetupKey;

  /// No description provided for @mfaSetupHint.
  ///
  /// In en, this message translates to:
  /// **'In your authenticator app add an account with this key (time-based), then enter the 6-digit code it shows.'**
  String get mfaSetupHint;

  /// No description provided for @mfaCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy key'**
  String get mfaCopy;

  /// No description provided for @mfaCode.
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get mfaCode;

  /// No description provided for @mfaConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get mfaConfirm;

  /// No description provided for @mfaRecoveryTitle.
  ///
  /// In en, this message translates to:
  /// **'Recovery codes'**
  String get mfaRecoveryTitle;

  /// No description provided for @mfaRecoveryNote.
  ///
  /// In en, this message translates to:
  /// **'Store these codes somewhere safe. Each works once if you lose your phone. They are shown only now.'**
  String get mfaRecoveryNote;

  /// No description provided for @mfaSaved.
  ///
  /// In en, this message translates to:
  /// **'I saved them'**
  String get mfaSaved;

  /// No description provided for @mfaDisableHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your password and a current code (or a recovery code).'**
  String get mfaDisableHint;

  /// No description provided for @mfaLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the code from your authenticator app, or a recovery code.'**
  String get mfaLoginTitle;

  /// No description provided for @mfaVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get mfaVerify;

  /// No description provided for @errMfaCode.
  ///
  /// In en, this message translates to:
  /// **'The code is not correct'**
  String get errMfaCode;

  /// No description provided for @errMfaChallenge.
  ///
  /// In en, this message translates to:
  /// **'The sign-in attempt expired. Please sign in again.'**
  String get errMfaChallenge;

  /// No description provided for @errMfaRequired.
  ///
  /// In en, this message translates to:
  /// **'Two-factor authentication is required for this account'**
  String get errMfaRequired;

  /// No description provided for @histTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent sign-ins'**
  String get histTitle;

  /// No description provided for @histAlertFailed.
  ///
  /// In en, this message translates to:
  /// **'{n} failed sign-in attempts since your last successful sign-in.'**
  String histAlertFailed(int n);

  /// No description provided for @histAlertNewDevice.
  ///
  /// In en, this message translates to:
  /// **'A sign-in from a new device was recorded in the last 7 days.'**
  String get histAlertNewDevice;

  /// No description provided for @histAlertHint.
  ///
  /// In en, this message translates to:
  /// **'If this was not you, change your password and sign out on all devices.'**
  String get histAlertHint;

  /// No description provided for @histSUCCESS.
  ///
  /// In en, this message translates to:
  /// **'Signed in'**
  String get histSUCCESS;

  /// No description provided for @histFAILED_PASSWORD.
  ///
  /// In en, this message translates to:
  /// **'Wrong password'**
  String get histFAILED_PASSWORD;

  /// No description provided for @histFAILED_MFA.
  ///
  /// In en, this message translates to:
  /// **'Wrong code'**
  String get histFAILED_MFA;

  /// No description provided for @histLOCKED.
  ///
  /// In en, this message translates to:
  /// **'Blocked: too many attempts'**
  String get histLOCKED;

  /// No description provided for @histNewDevice.
  ///
  /// In en, this message translates to:
  /// **'New device'**
  String get histNewDevice;

  /// No description provided for @histWithCode.
  ///
  /// In en, this message translates to:
  /// **'with code'**
  String get histWithCode;

  /// No description provided for @histNone.
  ///
  /// In en, this message translates to:
  /// **'No sign-ins recorded yet'**
  String get histNone;

  /// No description provided for @histNote.
  ///
  /// In en, this message translates to:
  /// **'Kept for 90 days. The device is recognised by its app or browser type, not proven.'**
  String get histNote;

  /// No description provided for @privacyExport.
  ///
  /// In en, this message translates to:
  /// **'Export client data'**
  String get privacyExport;

  /// No description provided for @privacyDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete personal data'**
  String get privacyDelete;

  /// No description provided for @privacyDeleteWarn.
  ///
  /// In en, this message translates to:
  /// **'This removes the name, phone, e-mail, notes and messages of this client for good and cannot be undone. Bookings and payments stay for your accounting, without personal data.'**
  String get privacyDeleteWarn;

  /// No description provided for @privacyConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete for good'**
  String get privacyConfirm;

  /// No description provided for @privacyDone.
  ///
  /// In en, this message translates to:
  /// **'Personal data deleted'**
  String get privacyDone;

  /// No description provided for @errHasUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Cancel the upcoming bookings of this client first'**
  String get errHasUpcoming;

  /// No description provided for @privacySaved.
  ///
  /// In en, this message translates to:
  /// **'File saved'**
  String get privacySaved;

  /// No description provided for @retentionTitle.
  ///
  /// In en, this message translates to:
  /// **'Automatic deletion of inactive clients'**
  String get retentionTitle;

  /// No description provided for @retentionNote.
  ///
  /// In en, this message translates to:
  /// **'Anonymise clients who had no booking for this long (never those with upcoming bookings). Off by default. Check what the law requires in your country.'**
  String get retentionNote;

  /// No description provided for @retentionOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get retentionOff;

  /// No description provided for @retentionYears.
  ///
  /// In en, this message translates to:
  /// **'{n} years'**
  String retentionYears(String n);

  /// No description provided for @scheduleOpen.
  ///
  /// In en, this message translates to:
  /// **'Working hours and time off'**
  String get scheduleOpen;

  /// No description provided for @scheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'Working hours'**
  String get scheduleTitle;

  /// No description provided for @scheduleFollow.
  ///
  /// In en, this message translates to:
  /// **'Follow the location hours'**
  String get scheduleFollow;

  /// No description provided for @scheduleFollowNote.
  ///
  /// In en, this message translates to:
  /// **'Without personal hours the specialist works whenever the location is open.'**
  String get scheduleFollowNote;

  /// No description provided for @scheduleBreakHint.
  ///
  /// In en, this message translates to:
  /// **'Add two ranges in one day to make a break.'**
  String get scheduleBreakHint;

  /// No description provided for @scheduleDayOff.
  ///
  /// In en, this message translates to:
  /// **'Day off'**
  String get scheduleDayOff;

  /// No description provided for @scheduleAddRange.
  ///
  /// In en, this message translates to:
  /// **'Add hours'**
  String get scheduleAddRange;

  /// No description provided for @scheduleFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get scheduleFrom;

  /// No description provided for @scheduleTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get scheduleTo;

  /// No description provided for @scheduleSave.
  ///
  /// In en, this message translates to:
  /// **'Save hours'**
  String get scheduleSave;

  /// No description provided for @scheduleSaved.
  ///
  /// In en, this message translates to:
  /// **'Hours saved'**
  String get scheduleSaved;

  /// No description provided for @scheduleAffected.
  ///
  /// In en, this message translates to:
  /// **'{n} upcoming bookings no longer fit these hours. They were not cancelled: move them in the calendar.'**
  String scheduleAffected(int n);

  /// No description provided for @timeOffTitle.
  ///
  /// In en, this message translates to:
  /// **'Time off'**
  String get timeOffTitle;

  /// No description provided for @timeOffAdd.
  ///
  /// In en, this message translates to:
  /// **'Add time off'**
  String get timeOffAdd;

  /// No description provided for @timeOffReason.
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get timeOffReason;

  /// No description provided for @timeOffNone.
  ///
  /// In en, this message translates to:
  /// **'No time off planned'**
  String get timeOffNone;

  /// No description provided for @timeOffAffected.
  ///
  /// In en, this message translates to:
  /// **'{n} bookings in this period'**
  String timeOffAffected(int n);

  /// No description provided for @timeOffRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get timeOffRemove;

  /// No description provided for @errOverlap.
  ///
  /// In en, this message translates to:
  /// **'Hours of one day must not overlap'**
  String get errOverlap;

  /// No description provided for @errRangeOrder.
  ///
  /// In en, this message translates to:
  /// **'The end must be after the start'**
  String get errRangeOrder;

  /// No description provided for @errTooManyRanges.
  ///
  /// In en, this message translates to:
  /// **'At most six ranges per day'**
  String get errTooManyRanges;

  /// No description provided for @promosNav.
  ///
  /// In en, this message translates to:
  /// **'Promo codes'**
  String get promosNav;

  /// No description provided for @promosNone.
  ///
  /// In en, this message translates to:
  /// **'No promo codes yet. Create one and guests can enter it when booking.'**
  String get promosNone;

  /// No description provided for @promoAdd.
  ///
  /// In en, this message translates to:
  /// **'New promo code'**
  String get promoAdd;

  /// No description provided for @promoCode.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get promoCode;

  /// No description provided for @promoKindPercent.
  ///
  /// In en, this message translates to:
  /// **'Percent'**
  String get promoKindPercent;

  /// No description provided for @promoKindFixed.
  ///
  /// In en, this message translates to:
  /// **'Fixed amount'**
  String get promoKindFixed;

  /// No description provided for @promoValue.
  ///
  /// In en, this message translates to:
  /// **'Discount value'**
  String get promoValue;

  /// No description provided for @promoMaxUses.
  ///
  /// In en, this message translates to:
  /// **'Max uses (optional)'**
  String get promoMaxUses;

  /// No description provided for @promoUntil.
  ///
  /// In en, this message translates to:
  /// **'Valid until (optional)'**
  String get promoUntil;

  /// No description provided for @promoAnyService.
  ///
  /// In en, this message translates to:
  /// **'Any service'**
  String get promoAnyService;

  /// No description provided for @promoCodeOptional.
  ///
  /// In en, this message translates to:
  /// **'Promo code (optional)'**
  String get promoCodeOptional;

  /// No description provided for @promoEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get promoEnabled;

  /// No description provided for @promoUsed.
  ///
  /// In en, this message translates to:
  /// **'Used {used}{max}'**
  String promoUsed(String used, String max);

  /// No description provided for @promoOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get promoOff;

  /// No description provided for @promoDiscountOf.
  ///
  /// In en, this message translates to:
  /// **'{value} off'**
  String promoDiscountOf(String value);

  /// No description provided for @promoValidUntilLabel.
  ///
  /// In en, this message translates to:
  /// **'until {date}'**
  String promoValidUntilLabel(String date);

  /// No description provided for @errPromo.
  ///
  /// In en, this message translates to:
  /// **'This promo code is not valid.'**
  String get errPromo;

  /// No description provided for @errCodeExists.
  ///
  /// In en, this message translates to:
  /// **'This code already exists.'**
  String get errCodeExists;

  /// No description provided for @tagsTitle.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get tagsTitle;

  /// No description provided for @tagsHint.
  ///
  /// In en, this message translates to:
  /// **'Comma-separated, up to 10 tags of 30 characters'**
  String get tagsHint;

  /// No description provided for @tagsInvalid.
  ///
  /// In en, this message translates to:
  /// **'Up to 10 tags, each at most 30 characters.'**
  String get tagsInvalid;

  /// No description provided for @mergeClient.
  ///
  /// In en, this message translates to:
  /// **'Merge a duplicate'**
  String get mergeClient;

  /// No description provided for @mergeIntro.
  ///
  /// In en, this message translates to:
  /// **'Find the duplicate of {name} to merge into this card.'**
  String mergeIntro(String name);

  /// No description provided for @mergeWarning.
  ///
  /// In en, this message translates to:
  /// **'Merge {dup} ({phone}) into {name}? Its bookings, tags and notes move to {name}; the duplicate record is deleted. Marketing consent is not transferred. This cannot be undone.'**
  String mergeWarning(String dup, String phone, String name);

  /// No description provided for @exceptionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Special days'**
  String get exceptionsTitle;

  /// No description provided for @exceptionAdd.
  ///
  /// In en, this message translates to:
  /// **'Add special day'**
  String get exceptionAdd;

  /// No description provided for @exceptionsNote.
  ///
  /// In en, this message translates to:
  /// **'A date here replaces the weekly hours for that one day: a day off or different hours.'**
  String get exceptionsNote;

  /// No description provided for @exceptionsNone.
  ///
  /// In en, this message translates to:
  /// **'No special days planned'**
  String get exceptionsNone;

  /// No description provided for @exceptionPickDate.
  ///
  /// In en, this message translates to:
  /// **'Choose date'**
  String get exceptionPickDate;

  /// No description provided for @scheduleBadRange.
  ///
  /// In en, this message translates to:
  /// **'The end must be after the start.'**
  String get scheduleBadRange;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @refundAction.
  ///
  /// In en, this message translates to:
  /// **'Refund'**
  String get refundAction;

  /// No description provided for @refundRecorded.
  ///
  /// In en, this message translates to:
  /// **'Refund recorded'**
  String get refundRecorded;

  /// No description provided for @refundPending.
  ///
  /// In en, this message translates to:
  /// **'Refund sent for approval'**
  String get refundPending;

  /// No description provided for @validationRefundAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount up to what has been paid'**
  String get validationRefundAmount;

  /// No description provided for @refundsNav.
  ///
  /// In en, this message translates to:
  /// **'Refunds'**
  String get refundsNav;

  /// No description provided for @refundsNone.
  ///
  /// In en, this message translates to:
  /// **'No refund requests'**
  String get refundsNone;

  /// No description provided for @refundsPolicyTitle.
  ///
  /// In en, this message translates to:
  /// **'Approval of large refunds'**
  String get refundsPolicyTitle;

  /// No description provided for @refundsPolicyOff.
  ///
  /// In en, this message translates to:
  /// **'Off: every refund is recorded immediately.'**
  String get refundsPolicyOff;

  /// No description provided for @refundsThreshold.
  ///
  /// In en, this message translates to:
  /// **'Approval threshold'**
  String get refundsThreshold;

  /// No description provided for @refundsThresholdHint.
  ///
  /// In en, this message translates to:
  /// **'Refunds above this amount need an owner or admin. Empty = off.'**
  String get refundsThresholdHint;

  /// No description provided for @refundStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get refundStatusPending;

  /// No description provided for @refundStatusApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get refundStatusApproved;

  /// No description provided for @refundStatusRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get refundStatusRejected;

  /// No description provided for @refundApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get refundApprove;

  /// No description provided for @refundReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get refundReject;

  /// No description provided for @refundRequestedBy.
  ///
  /// In en, this message translates to:
  /// **'Requested by {name}'**
  String refundRequestedBy(String name);

  /// No description provided for @refundsPolicyOn.
  ///
  /// In en, this message translates to:
  /// **'Approval required above {amount}'**
  String refundsPolicyOn(String amount);

  /// No description provided for @closingTitle.
  ///
  /// In en, this message translates to:
  /// **'Close cash register'**
  String get closingTitle;

  /// No description provided for @closingFirst.
  ///
  /// In en, this message translates to:
  /// **'First closing: counted from the start of today.'**
  String get closingFirst;

  /// No description provided for @closingExpectedCash.
  ///
  /// In en, this message translates to:
  /// **'Expected cash in the drawer'**
  String get closingExpectedCash;

  /// No description provided for @closingNotCounted.
  ///
  /// In en, this message translates to:
  /// **'Bank and card amounts are for the accountant; they are not counted in the drawer.'**
  String get closingNotCounted;

  /// No description provided for @closingCounted.
  ///
  /// In en, this message translates to:
  /// **'Cash counted'**
  String get closingCounted;

  /// No description provided for @closingMatches.
  ///
  /// In en, this message translates to:
  /// **'Matches the expected cash.'**
  String get closingMatches;

  /// No description provided for @closingConfirm.
  ///
  /// In en, this message translates to:
  /// **'Close the register'**
  String get closingConfirm;

  /// No description provided for @closingDone.
  ///
  /// In en, this message translates to:
  /// **'Register closed'**
  String get closingDone;

  /// No description provided for @closingHistory.
  ///
  /// In en, this message translates to:
  /// **'Previous closings'**
  String get closingHistory;

  /// No description provided for @closingNone.
  ///
  /// In en, this message translates to:
  /// **'No closings yet'**
  String get closingNone;

  /// No description provided for @errExpectedChanged.
  ///
  /// In en, this message translates to:
  /// **'Payments changed while you were counting. Check the new expected cash and confirm again.'**
  String get errExpectedChanged;

  /// No description provided for @errRefundExceeds.
  ///
  /// In en, this message translates to:
  /// **'The refund is larger than what is currently paid.'**
  String get errRefundExceeds;

  /// No description provided for @errAlreadyDecided.
  ///
  /// In en, this message translates to:
  /// **'This request was already decided.'**
  String get errAlreadyDecided;

  /// No description provided for @closingPeriod.
  ///
  /// In en, this message translates to:
  /// **'Period: {from} – {to}'**
  String closingPeriod(String from, String to);

  /// No description provided for @closingShortage.
  ///
  /// In en, this message translates to:
  /// **'Shortage: {amount}'**
  String closingShortage(String amount);

  /// No description provided for @closingSurplus.
  ///
  /// In en, this message translates to:
  /// **'Surplus: {amount}'**
  String closingSurplus(String amount);

  /// No description provided for @closingRow.
  ///
  /// In en, this message translates to:
  /// **'expected {expected}, counted {counted}'**
  String closingRow(String expected, String counted);

  /// No description provided for @reviewReply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get reviewReply;

  /// No description provided for @reviewReplyRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove reply'**
  String get reviewReplyRemove;

  /// No description provided for @reviewReplyNote.
  ///
  /// In en, this message translates to:
  /// **'Your reply is shown to the guest on their booking link. Be polite and do not share personal details.'**
  String get reviewReplyNote;

  /// No description provided for @reviewHidden.
  ///
  /// In en, this message translates to:
  /// **'Hidden by the platform: {reason}'**
  String reviewHidden(String reason);

  /// No description provided for @giftCardsNav.
  ///
  /// In en, this message translates to:
  /// **'Gift cards'**
  String get giftCardsNav;

  /// No description provided for @giftSell.
  ///
  /// In en, this message translates to:
  /// **'Sell a gift card'**
  String get giftSell;

  /// No description provided for @giftNone.
  ///
  /// In en, this message translates to:
  /// **'No gift cards sold yet'**
  String get giftNone;

  /// No description provided for @giftNote.
  ///
  /// In en, this message translates to:
  /// **'Money taken for a gift card is not income until it is spent on a booking. The code is shown once when the card is sold.'**
  String get giftNote;

  /// No description provided for @giftVoid.
  ///
  /// In en, this message translates to:
  /// **'Void'**
  String get giftVoid;

  /// No description provided for @giftExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get giftExpired;

  /// No description provided for @giftVoidAction.
  ///
  /// In en, this message translates to:
  /// **'Void card'**
  String get giftVoidAction;

  /// No description provided for @giftBuyer.
  ///
  /// In en, this message translates to:
  /// **'Buyer (optional)'**
  String get giftBuyer;

  /// No description provided for @giftCodeOnce.
  ///
  /// In en, this message translates to:
  /// **'Give this code to the buyer. It is shown only now and cannot be recovered.'**
  String get giftCodeOnce;

  /// No description provided for @giftCodeLost.
  ///
  /// In en, this message translates to:
  /// **'This card was already created on an earlier attempt, but its code was not received. Void it in the list and sell a new one.'**
  String get giftCodeLost;

  /// No description provided for @giftCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get giftCopy;

  /// No description provided for @giftPay.
  ///
  /// In en, this message translates to:
  /// **'Pay with gift card'**
  String get giftPay;

  /// No description provided for @giftCode.
  ///
  /// In en, this message translates to:
  /// **'Gift card code'**
  String get giftCode;

  /// No description provided for @validationGiftCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the 12-character code'**
  String get validationGiftCode;

  /// No description provided for @errGiftInvalid.
  ///
  /// In en, this message translates to:
  /// **'This gift card cannot be used (unknown, void or expired).'**
  String get errGiftInvalid;

  /// No description provided for @errGiftInsufficient.
  ///
  /// In en, this message translates to:
  /// **'The gift card balance is too low for this amount.'**
  String get errGiftInsufficient;

  /// No description provided for @giftVoidWarning.
  ///
  /// In en, this message translates to:
  /// **'Void card {code}? The customer will not be able to use it. This cannot be undone.'**
  String giftVoidWarning(String code);
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
