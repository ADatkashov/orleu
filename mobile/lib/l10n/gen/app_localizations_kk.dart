// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Kazakh (`kk`).
class AppLocalizationsKk extends AppLocalizations {
  AppLocalizationsKk([String locale = 'kk']) : super(locale);

  @override
  String get appName => 'ORLEU';

  @override
  String get tagline => 'Сіздің бизнесіңіз. Сіздің өсуіңіз.';

  @override
  String get signIn => 'Кіру';

  @override
  String get createAccount => 'Тіркелу';

  @override
  String get noAccountYet => 'Аккаунт жоқ па? Тіркелу';

  @override
  String get haveAccount => 'Аккаунтыңыз бар ма? Кіру';

  @override
  String get email => 'E-mail';

  @override
  String get password => 'Құпиясөз';

  @override
  String get fullName => 'Аты-жөні';

  @override
  String get logout => 'Шығу';

  @override
  String get validationRequired => 'Міндетті өріс';

  @override
  String get validationEmail => 'Дұрыс e-mail енгізіңіз';

  @override
  String get validationPasswordShort => 'Кемінде 10 таңба';

  @override
  String get validationSlug => '3-60 таңба: кіші әріптер, сандар, дефис';

  @override
  String get errInvalidCredentials => 'E-mail немесе құпиясөз қате';

  @override
  String get errEmailTaken => 'Бұл e-mail бойынша аккаунт бар';

  @override
  String get errAccountLocked => 'Әрекет тым көп. Кейінірек қайталаңыз.';

  @override
  String get errSlugTaken => 'Жазылу беті мекенжайы бос емес';

  @override
  String get errNetwork => 'Сервермен байланыс жоқ';

  @override
  String get errGeneric => 'Бір нәрсе дұрыс болмады. Қайталап көріңіз.';

  @override
  String get errInvalidTransition => 'Бұл өзгеріс жазылу үшін рұқсат етілмейді';

  @override
  String get retry => 'Қайталау';

  @override
  String get navHome => 'Басты бет';

  @override
  String get navCalendar => 'Күнтізбе';

  @override
  String get navCustomers => 'Клиенттер';

  @override
  String get navFinance => 'Қаржы';

  @override
  String get navMore => 'Тағы';

  @override
  String greeting(String name) {
    return 'Сәлем, $name';
  }

  @override
  String get todayCollected => 'Бүгін түскен';

  @override
  String get todayBookings => 'Бүгінгі жазылулар';

  @override
  String get pendingBookings => 'Әрекет күтуде';

  @override
  String get upcoming => 'Жақын арада';

  @override
  String get nothingUpcoming => 'Бүгін басқа жазылу жоқ';

  @override
  String get createBusinessTitle => 'Бизнесті баптаңыз';

  @override
  String get createBusinessIntro => 'Жазылуларды қабылдау үшін бизнес жасаңыз.';

  @override
  String get businessName => 'Бизнес атауы';

  @override
  String get bookingPageAddress => 'Жазылу беті мекенжайы';

  @override
  String get businessType => 'Бизнес түрі';

  @override
  String get create => 'Жасау';

  @override
  String get typeBarbershop => 'Барбершоп';

  @override
  String get typeBeautySalon => 'Сән салоны';

  @override
  String get typeClinic => 'Клиника';

  @override
  String get typeFitness => 'Фитнес-студия';

  @override
  String get typeOther => 'Басқа';

  @override
  String get noBookings => 'Бұл күні жазылу жоқ';

  @override
  String get statusPending => 'Күтуде';

  @override
  String get statusAwaitingPayment => 'Төлем күтілуде';

  @override
  String get statusConfirmed => 'Расталды';

  @override
  String get statusCheckedIn => 'Клиент келді';

  @override
  String get statusInProgress => 'Орындалуда';

  @override
  String get statusCompleted => 'Аяқталды';

  @override
  String get statusCancelled => 'Бас тартылды';

  @override
  String get statusNoShow => 'Келмеді';

  @override
  String get statusExpired => 'Мерзімі өтті';

  @override
  String get actionConfirm => 'Растау';

  @override
  String get actionCheckIn => 'Клиент келді';

  @override
  String get actionStart => 'Бастау';

  @override
  String get actionComplete => 'Аяқтау';

  @override
  String get actionNoShow => 'Келмеді';

  @override
  String get actionCancel => 'Жазылудан бас тарту';

  @override
  String get price => 'Бағасы';

  @override
  String get deposit => 'Депозит';

  @override
  String get paid => 'Төленді';

  @override
  String get remaining => 'Қалдық';

  @override
  String get paymentStatus => 'Төлем';

  @override
  String get payUnpaid => 'Төленбеген';

  @override
  String get payPartial => 'Ішінара төленді';

  @override
  String get payDepositPaid => 'Депозит төленді';

  @override
  String get payPaid => 'Толық төленді';

  @override
  String get payRefunded => 'Қайтарылды';

  @override
  String get employee => 'Қызметкер';

  @override
  String get customer => 'Клиент';

  @override
  String get searchCustomers => 'Аты немесе телефон бойынша іздеу';

  @override
  String get noCustomers => 'Клиенттер табылмады';

  @override
  String get financeTitle => 'Соңғы 30 күндегі қаржы';

  @override
  String get bookedValue => 'Жазылулар сомасы';

  @override
  String get collected => 'Түскен';

  @override
  String get refunded => 'Қайтарылған';

  @override
  String get netCollected => 'Таза түсім';

  @override
  String get outstanding => 'Төленбеген қалдық';

  @override
  String get cancellationRate => 'Бас тарту үлесі';

  @override
  String get noShowRate => 'Келмеу үлесі';

  @override
  String get financeNote =>
      'Жазылулар сомасы — кассадағы ақша емес: түскен төлемдер бөлек көрсетіледі.';

  @override
  String get language => 'Тіл';

  @override
  String get theme => 'Тақырып';

  @override
  String get themeSystem => 'Жүйелік';

  @override
  String get themeLight => 'Ашық';

  @override
  String get themeDark => 'Қараңғы';

  @override
  String get plan => 'Тариф';

  @override
  String planUsage(int used, int limit) {
    return '$used / $limit қызметкер';
  }
}
