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

  @override
  String get setupTitle => 'Бизнесті баптау';

  @override
  String get setupIntro => 'Онлайн жазылуды ашу үшін осы қадамдарды орындаңыз.';

  @override
  String get stepBranch => 'Филиал қосыңыз';

  @override
  String get stepHours => 'Жұмыс уақытын көрсетіңіз';

  @override
  String get stepService => 'Қызмет қосыңыз';

  @override
  String get stepEmployee => 'Маман қосып, қызметтерді тағайындаңыз';

  @override
  String get stepPublish => 'Жазылу бетін жариялаңыз';

  @override
  String get branches => 'Филиалдар және уақыт';

  @override
  String get addBranch => 'Филиал қосу';

  @override
  String get branchName => 'Филиал атауы';

  @override
  String get address => 'Мекенжай (міндетті емес)';

  @override
  String get workingHours => 'Жұмыс уақыты';

  @override
  String get closed => 'Демалыс';

  @override
  String get applyDefaultHours => 'Дс–Жс 09:00–18:00';

  @override
  String get save => 'Сақтау';

  @override
  String get saved => 'Сақталды';

  @override
  String get cancel => 'Болдырмау';

  @override
  String get services => 'Қызметтер';

  @override
  String get addService => 'Қызмет қосу';

  @override
  String get serviceName => 'Қызмет атауы';

  @override
  String get durationMin => 'Ұзақтығы, минут';

  @override
  String get priceField => 'Бағасы';

  @override
  String get depositPercentOptional => 'Депозит, % (міндетті емес)';

  @override
  String get bufferMin => 'Қызметтен кейінгі үзіліс, минут (міндетті емес)';

  @override
  String get noneYet => 'Әзірге ештеңе жоқ';

  @override
  String get employees => 'Мамандар';

  @override
  String get addEmployee => 'Маман қосу';

  @override
  String get employeeName => 'Маман аты';

  @override
  String get assignLocations => 'Жұмыс істейтін жері';

  @override
  String get assignServices => 'Орындайтын қызметтері';

  @override
  String get publish => 'Жазылу бетін жариялау';

  @override
  String get unpublish => 'Жарияланымнан алу';

  @override
  String get publishedHint => 'Жазылу бетіңіз жұмыс істеп тұр';

  @override
  String get bookingLink => 'Жазылу сілтемесі';

  @override
  String get copyLink => 'Сілтемені көшіру';

  @override
  String get copied => 'Көшірілді';

  @override
  String get errLimit =>
      'Тарифіңіздің шегіне жеттіңіз. Жаңарту үшін ORLEU-мен байланысыңыз.';

  @override
  String get errNotReady =>
      'Алдымен баптауды аяқтаңыз: жұмыс уақыты бар филиал, қызмет және тағайындалған маман.';

  @override
  String get errSuspended =>
      'Бизнес тоқтатылған. ORLEU қолдауына хабарласыңыз.';

  @override
  String get setupNav => 'Бизнесті баптау';

  @override
  String get minutesShort => 'мин';

  @override
  String get newBooking => 'Жаңа жазылу';

  @override
  String get selectService => 'Қызмет';

  @override
  String get selectLocation => 'Филиал';

  @override
  String get selectSpecialist => 'Маман';

  @override
  String get anySpecialist => 'Кез келген бос';

  @override
  String get pickDate => 'Күні';

  @override
  String get pickTime => 'Уақыты';

  @override
  String get noSlots => 'Бұл күні бос уақыт жоқ';

  @override
  String get clientName => 'Клиент аты';

  @override
  String get clientPhone => 'Клиент телефоны';

  @override
  String get validationPhone => 'Халықаралық формат, мысалы +7 701 123 45 67';

  @override
  String get notesOptional => 'Ескертпе (міндетті емес)';

  @override
  String get bookAction => 'Жазылу жасау';

  @override
  String get rescheduleAction => 'Көшіру';

  @override
  String get rescheduleTitle => 'Жазылуды көшіру';

  @override
  String get moveHere => 'Көшіру';

  @override
  String get errSlot => 'Бұл уақыт енді қолжетімсіз. Басқасын таңдаңыз.';

  @override
  String get errBlockedCustomer => 'Бұл клиент бұғатталған.';

  @override
  String get setupFirst =>
      'Алдымен баптауды аяқтаңыз: филиал, қызмет және маман.';

  @override
  String get bookingCreated => 'Жазылу жасалды';

  @override
  String get bookingMoved => 'Жазылу көшірілді';

  @override
  String get recordPayment => 'Төлем қабылдау';

  @override
  String get paymentAmount => 'Сома';

  @override
  String get paymentMethod => 'Тәсіл';

  @override
  String get methodCash => 'Қолма-қол';

  @override
  String get methodBank => 'Банк аударымы';

  @override
  String get methodCard => 'Карта (қолмен)';

  @override
  String get errOverpayment => 'Сома төленетін қалдықтан асып кетті.';

  @override
  String get paymentRecorded => 'Төлем тіркелді';

  @override
  String get validationAmount => 'Қалдықтан аспайтын соманы енгізіңіз';

  @override
  String get statVisits => 'Келулер';

  @override
  String get statCancelled => 'Бас тартулар';

  @override
  String get statNoShows => 'Келмеулер';

  @override
  String get statUpcoming => 'Алдағы';

  @override
  String get statLastVisit => 'Соңғы келуі';

  @override
  String get statSpent => 'Барлығы төленді';

  @override
  String get statAvg => 'Бір келуге орта есеппен';

  @override
  String get noVisitsYet => 'Келулер әзірге жоқ';

  @override
  String get historyTitle => 'Жазылулар тарихы';

  @override
  String get noHistory => 'Жазылулар әзірге жоқ';

  @override
  String get notes => 'Ескертпелер';

  @override
  String get editClient => 'Клиентті өзгерту';

  @override
  String get marketingConsent => 'Жарнамалық хабарламаларға келісімі бар';

  @override
  String get blockClient => 'Клиентті бұғаттау';

  @override
  String get unblockClient => 'Клиентті бұғаттан шығару';

  @override
  String get blockConfirm =>
      'Бұғатталған клиент онлайн жазыла алмайды және қызметкерлер оны жаза алмайды.';

  @override
  String get blocked => 'Бұғатталған';

  @override
  String get edit => 'Өзгерту';

  @override
  String get active => 'Белсенді';

  @override
  String get inactive => 'Белсенді емес';

  @override
  String get deactivateNote =>
      'Белсенді емес элементтер жазылуда көрінбейді. Бар жазылулар мен тарих сақталады.';

  @override
  String get editService => 'Қызметті өзгерту';

  @override
  String get editLocation => 'Филиалды өзгерту';

  @override
  String get editSpecialist => 'Маманды өзгерту';

  @override
  String get statsNote =>
      'Төленді = алынған ақша минус қайтарулар, жазылулар сомасы емес.';

  @override
  String get reportsTitle => 'Есептер';

  @override
  String reportPeriodDays(String n) {
    return '$n күн';
  }

  @override
  String get reportRevenueByDay => 'Күн сайынғы түскен төлем (қайтарымсыз)';

  @override
  String get reportTopServices => 'Қызметтер';

  @override
  String get reportTopEmployees => 'Мамандар';

  @override
  String get reportBranches => 'Филиалдар';

  @override
  String get reportPeakHours => 'Ең жүктелген сағаттар';

  @override
  String get reportCustomers => 'Жаңа және қайта келген клиенттер';

  @override
  String get reportNew => 'Жаңа';

  @override
  String get reportReturning => 'Қайта келген';

  @override
  String get reportNoData => 'Бұл кезеңде деректер әлі жоқ';

  @override
  String reportBookingsN(String n) {
    return 'Жазылу: $n';
  }

  @override
  String reportReturningShare(String p) {
    return 'Клиенттердің $p% қайта келді';
  }

  @override
  String get reportsNote =>
      'Мәліметтер таңдалған кезеңдегі жазылулар мен төлемдер бойынша есептеледі. Бас тартылған жазылулар сұраныс болып саналмайды.';

  @override
  String get messagesNav => 'Клиенттерге хабарламалар';

  @override
  String get messagesReminder => 'Келуге дейін клиенттерге еске салу';

  @override
  String get messagesReminderOff => 'Өшірулі';

  @override
  String messagesReminderHours(String n) {
    return '$n сағат бұрын';
  }

  @override
  String get messagesLanguage => 'Клиент хабарламаларының тілі';

  @override
  String get messagesPrepared => 'Дайындалған хабарламалар';

  @override
  String get messagesNone => 'Дайындалған хабарламалар әлі жоқ';

  @override
  String get messagesNotSent => 'Жіберілмеген';

  @override
  String get messagesNote =>
      'SMS немесе e-mail арқылы жіберу әлі қосылмаған: хабарламалар дайындалып, осында көрсетіледі, бірақ клиенттерге ештеңе жеткізілмейді.';

  @override
  String get messagesSaved => 'Сақталды';

  @override
  String get forgotPassword => 'Құпиясөзді ұмыттыңыз ба?';

  @override
  String get resetIntro =>
      'Құпиясөзді қалпына келтіру кодын сұрау үшін аккаунттың e-mail мекенжайын енгізіңіз.';

  @override
  String get resetRequest => 'Код сұрау';

  @override
  String get resetRequested =>
      'Егер бұл e-mail үшін аккаунт бар болса, қалпына келтіру коды сұралды. Алған кодты енгізіп, жаңа құпиясөз таңдаңыз.';

  @override
  String get resetCode => 'Қалпына келтіру коды';

  @override
  String get newPassword => 'Жаңа құпиясөз';

  @override
  String get resetConfirm => 'Жаңа құпиясөзді сақтау';

  @override
  String get resetDone => 'Құпиясөз өзгертілді. Жаңа құпиясөзбен кіріңіз.';

  @override
  String get backToSignIn => 'Кіруге оралу';

  @override
  String get errWrongPassword => 'Ағымдағы құпиясөз қате';

  @override
  String get errResetToken =>
      'Қалпына келтіру коды жарамсыз немесе мерзімі өтті';

  @override
  String get accountNav => 'Аккаунт және қауіпсіздік';

  @override
  String get changePassword => 'Құпиясөзді өзгерту';

  @override
  String get currentPassword => 'Ағымдағы құпиясөз';

  @override
  String get confirmPassword => 'Жаңа құпиясөзді қайталаңыз';

  @override
  String get passwordsDiffer => 'Құпиясөздер сәйкес келмейді';

  @override
  String get passwordChanged =>
      'Құпиясөз өзгертілді. Басқа құрылғылардан шығарылды.';

  @override
  String get sessionsTitle => 'Кірген құрылғылар';

  @override
  String get sessionsNote =>
      'Құпиясөзді өзгерту басқа барлық құрылғылардан шығарады. Осы құрылғының сессиясын аяқтасаңыз, осында да шығасыз.';

  @override
  String get sessionRevoke => 'Шығу';

  @override
  String get sessionUnknownDevice => 'Белгісіз құрылғы';

  @override
  String sessionSince(String date) {
    return '$date бастап';
  }

  @override
  String get signOutEverywhere => 'Барлық құрылғылардан шығу';

  @override
  String get sessionsNone => 'Белсенді сессиялар жоқ';

  @override
  String get calDay => 'Күн';

  @override
  String get calWeek => 'Апта';

  @override
  String get calMonth => 'Ай';

  @override
  String get filterAllSpecialists => 'Барлық мамандар';

  @override
  String get filterAllLocations => 'Барлық филиалдар';

  @override
  String calBookingsCount(int n) {
    return 'Жазылу: $n';
  }

  @override
  String get reviewsNav => 'Пікірлер';

  @override
  String get reviewsAverage => 'Орташа баға';

  @override
  String reviewsCount(int n) {
    return 'Пікір: $n';
  }

  @override
  String get reviewsNone =>
      'Пікір әлі жоқ. Клиент өз жазылуының сілтемесі арқылы өткен келуді бағалай алады.';

  @override
  String get reviewsNote =>
      'Пікірлер тек өткен келулерден келеді, бизнес оларды өзгерте алмайды.';
}
