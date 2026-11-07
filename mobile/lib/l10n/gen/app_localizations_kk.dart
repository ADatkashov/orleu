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

  @override
  String get supportNav => 'Қолдау';

  @override
  String get supportIntro =>
      'Төлем, техникалық немесе аккаунт мәселесі бойынша ORLEU командасына жазыңыз. Жауаптар осы жерде көрінеді.';

  @override
  String get supportNew => 'Жаңа өтініш';

  @override
  String get supportSubject => 'Тақырып';

  @override
  String get supportBody => 'Мәселені сипаттаңыз';

  @override
  String get supportCategory => 'Бөлім';

  @override
  String get catBILLING => 'Төлем';

  @override
  String get catTECHNICAL => 'Техникалық';

  @override
  String get catACCOUNT => 'Аккаунт';

  @override
  String get catOTHER => 'Басқа';

  @override
  String get supportCreate => 'Жіберу';

  @override
  String get supportNone => 'Өтініштер әлі жоқ';

  @override
  String get stOPEN => 'Қолдау жауабын күтуде';

  @override
  String get stANSWERED => 'Жауап бар';

  @override
  String get stCLOSED => 'Жабылған';

  @override
  String get supportReply => 'Сіздің жауабыңыз';

  @override
  String get supportSend => 'Жіберу';

  @override
  String get supportCloseTicket => 'Өтінішті жабу';

  @override
  String get supportClosedNote =>
      'Өтініш жабылған. Көмек керек болса, жаңасын ашыңыз.';

  @override
  String get supportTeam => 'ORLEU қолдауы';

  @override
  String get supportYou => 'Сіз';

  @override
  String get errTicketClosed => 'Өтініш жабылған';

  @override
  String get errTooManyTickets =>
      'Ашық өтініштер тым көп. Біразын жабыңыз немесе жауапты күтіңіз.';

  @override
  String get notifTitle => 'Хабарландырулар';

  @override
  String get notifMarkAll => 'Барлығын оқылған деп белгілеу';

  @override
  String get notifNone => 'Хабарландырулар әлі жоқ';

  @override
  String get notifBOOKING_CREATED => 'Жаңа жазылу';

  @override
  String get notifBOOKING_CONFIRMED => 'Жазылу расталды';

  @override
  String get notifBOOKING_CANCELLED => 'Жазылудан бас тартылды';

  @override
  String get notifBOOKING_RESCHEDULED => 'Жазылу ауыстырылды';

  @override
  String get notifBOOKING_EXPIRED => 'Төленбеген жазылу мерзімі өтті';

  @override
  String get notifBOOKING_CHECKED_IN => 'Клиент келді';

  @override
  String get notifBOOKING_IN_PROGRESS => 'Келу басталды';

  @override
  String get notifBOOKING_COMPLETED => 'Келу аяқталды';

  @override
  String get notifBOOKING_NO_SHOW => 'Клиент келмеді';

  @override
  String get notifBOOKING_REMINDER => 'Клиентке еске салу дайындалды';

  @override
  String get notifPAYMENT_RECEIVED => 'Төлем тіркелді';

  @override
  String get notifSUPPORT_REPLIED => 'ORLEU қолдауы өтінішіңізге жауап берді';

  @override
  String get notifOther => 'Жаңарту';

  @override
  String get importNav => 'Клиенттерді импорттау (CSV)';

  @override
  String get importIntro =>
      'Кестені CSV (UTF-8) ретінде сақтаңыз. Бірінші жолда баған атаулары болады: аты мен телефон міндетті, e-mail және жазбалар қалауыңызша. Бар клиенттер өзгертілмейді, ал импортталғандар жарнамалық хабарламаларға келісім берген деп саналмайды.';

  @override
  String get importChoose => 'CSV файлын таңдау';

  @override
  String importFile(String name) {
    return 'Файл: $name';
  }

  @override
  String get importNew => 'Жаңа клиенттер';

  @override
  String get importExisting => 'Тізімде бар';

  @override
  String get importDupes => 'Файл ішіндегі қайталанулар';

  @override
  String get importInvalid => 'Қателі жолдар';

  @override
  String get importProblems => 'Өткізіп жіберілетін жолдар';

  @override
  String importRow(String row, String reason) {
    return '$row-жол: $reason';
  }

  @override
  String get imp_PHONE_INVALID => 'телефон нөмірі қате';

  @override
  String get imp_NAME_MISSING => 'аты жоқ';

  @override
  String get imp_NAME_TOO_LONG => 'аты тым ұзын';

  @override
  String get imp_EMAIL_INVALID => 'e-mail қате';

  @override
  String get imp_NOTES_TOO_LONG => 'жазбалар тым ұзын';

  @override
  String get importMoreProblems => '…және қателі жолдар бар';

  @override
  String importConfirm(String n) {
    return 'Клиенттерді импорттау: $n';
  }

  @override
  String get importNothing => 'Импорттауға жаңа клиент жоқ';

  @override
  String importDone(String n) {
    return 'Импортталған клиенттер: $n';
  }

  @override
  String get importAnother => 'Басқа файлды импорттау';

  @override
  String get importPreviewSample => 'Алғашқы жаңа клиенттер';

  @override
  String get errImportEmpty => 'Файл бос немесе клиент жолдары жоқ';

  @override
  String get errImportColumns =>
      'Бірінші жолда аты және телефон бағандары болуы керек';

  @override
  String get errImportTooLarge =>
      'Файл тым үлкен (5000 клиенттен және 2 МБ-тан аспауы керек)';

  @override
  String get errImportEncoding =>
      'Файл UTF-8 емес. Excel-де сақтағанда «CSV UTF-8» таңдаңыз.';

  @override
  String get exportTitle => 'Бухгалтерияға экспорт';

  @override
  String get exportNote =>
      'Таңдалған кезеңдегі барлық төлемдер мен қайтарымдардың CSV файлы (қайтарымдар теріс, бизнес уақыты). Клиенттердің аты-жөні мен телефондары жоқ; бұл фискалдық құжат емес.';

  @override
  String get exportComma => 'Үтір';

  @override
  String get exportSemicolon => 'Нүктелі үтір (Excel RU/KZ)';

  @override
  String get exportButton => 'CSV экспорты';

  @override
  String get exportSaved => 'Файл сақталды';

  @override
  String get exportCancelled => 'Сақталмады';

  @override
  String get errExportTooLarge => 'Жазбалар тым көп: қысқарақ кезеңді таңдаңыз';

  @override
  String get errExportForbidden =>
      'Сіздің рөліңіз қаржы деректерін экспорттауға рұқсат бермейді';

  @override
  String get mfaTitle => 'Екі факторлы аутентификация';

  @override
  String get mfaIntro =>
      'Аккаунтты аутентификатор қосымшасындағы кодпен қорғаңыз (Google Authenticator, Microsoft Authenticator, Aegis, …). Кіру үшін құпиясөз бен код қажет болады.';

  @override
  String get mfaOff => 'Өшірулі';

  @override
  String mfaOn(int n) {
    return 'Қосулы · резервтік кодтар: $n';
  }

  @override
  String get mfaEnable => 'Қосу';

  @override
  String get mfaDisable => 'Өшіру';

  @override
  String get mfaSetupKey => 'Баптау кілті';

  @override
  String get mfaSetupHint =>
      'Аутентификатор қосымшасында осы кілтпен аккаунт қосыңыз (уақытқа негізделген), сосын ол көрсеткен 6 таңбалы кодты енгізіңіз.';

  @override
  String get mfaCopy => 'Кілтті көшіру';

  @override
  String get mfaCode => '6 таңбалы код';

  @override
  String get mfaConfirm => 'Растау';

  @override
  String get mfaRecoveryTitle => 'Резервтік кодтар';

  @override
  String get mfaRecoveryNote =>
      'Бұл кодтарды сенімді жерде сақтаңыз. Телефонды жоғалтсаңыз, әрқайсысы бір рет жұмыс істейді. Тек қазір көрсетіледі.';

  @override
  String get mfaSaved => 'Сақтадым';

  @override
  String get mfaDisableHint =>
      'Құпиясөзді және ағымдағы кодты (немесе резервтік кодты) енгізіңіз.';

  @override
  String get mfaLoginTitle =>
      'Аутентификатор қосымшасындағы кодты немесе резервтік кодты енгізіңіз.';

  @override
  String get mfaVerify => 'Тексеру';

  @override
  String get errMfaCode => 'Код қате';

  @override
  String get errMfaChallenge => 'Кіру әрекетінің мерзімі өтті. Қайта кіріңіз.';

  @override
  String get errMfaRequired =>
      'Бұл аккаунт үшін екі факторлы аутентификация міндетті';

  @override
  String get histTitle => 'Соңғы кірулер';

  @override
  String histAlertFailed(int n) {
    return 'Соңғы сәтті кіруден кейінгі сәтсіз әрекеттер: $n.';
  }

  @override
  String get histAlertNewDevice =>
      'Соңғы 7 күнде жаңа құрылғыдан кіру тіркелді.';

  @override
  String get histAlertHint =>
      'Егер бұл сіз болмасаңыз, құпиясөзді өзгертіп, барлық құрылғылардан шығыңыз.';

  @override
  String get histSUCCESS => 'Кірді';

  @override
  String get histFAILED_PASSWORD => 'Құпиясөз қате';

  @override
  String get histFAILED_MFA => 'Код қате';

  @override
  String get histLOCKED => 'Бұғатталды: әрекет тым көп';

  @override
  String get histNewDevice => 'Жаңа құрылғы';

  @override
  String get histWithCode => 'кодпен';

  @override
  String get histNone => 'Кірулер әлі тіркелмеген';

  @override
  String get histNote =>
      '90 күн сақталады. Құрылғы қосымша немесе браузер түрі бойынша танылады, бұл дәлел емес.';

  @override
  String get privacyExport => 'Клиент деректерін шығару';

  @override
  String get privacyDelete => 'Жеке деректерді жою';

  @override
  String get privacyDeleteWarn =>
      'Бұл клиенттің аты, телефоны, e-mail, жазбалары мен хабарламалары біржола жойылады, қайтару мүмкін емес. Жазылулар мен төлемдер есептілік үшін жеке деректерсіз қалады.';

  @override
  String get privacyConfirm => 'Біржола жою';

  @override
  String get privacyDone => 'Жеке деректер жойылды';

  @override
  String get errHasUpcoming =>
      'Алдымен клиенттің алдағы жазылуларынан бас тартыңыз';

  @override
  String get privacySaved => 'Файл сақталды';

  @override
  String get retentionTitle => 'Белсенді емес клиенттерді автоматты жою';

  @override
  String get retentionNote =>
      'Осынша уақыт жазылуы болмаған клиенттерді иесіздендіру (алдағы жазылуы барларды қоспағанда). Әдепкіде өшірулі. Еліңіздегі заң талаптарын тексеріңіз.';

  @override
  String get retentionOff => 'Өшірулі';

  @override
  String retentionYears(String n) {
    return '$n жыл';
  }

  @override
  String get scheduleOpen => 'Жұмыс уақыты және демалыс';

  @override
  String get scheduleTitle => 'Жұмыс уақыты';

  @override
  String get scheduleFollow => 'Филиалдағыдай';

  @override
  String get scheduleFollowNote =>
      'Жеке уақытсыз маман филиал ашық кезде жұмыс істейді.';

  @override
  String get scheduleBreakHint =>
      'Үзіліс жасау үшін бір күнге екі аралық қосыңыз.';

  @override
  String get scheduleDayOff => 'Демалыс күні';

  @override
  String get scheduleAddRange => 'Уақыт қосу';

  @override
  String get scheduleFrom => 'Бастап';

  @override
  String get scheduleTo => 'Дейін';

  @override
  String get scheduleSave => 'Уақытты сақтау';

  @override
  String get scheduleSaved => 'Уақыт сақталды';

  @override
  String scheduleAffected(int n) {
    return 'Осы уақытқа сыймайтын алдағы жазылулар: $n. Олар бас тартылмады: күнтізбеде ауыстырыңыз.';
  }

  @override
  String get timeOffTitle => 'Демалыс';

  @override
  String get timeOffAdd => 'Демалыс қосу';

  @override
  String get timeOffReason => 'Себебі (міндетті емес)';

  @override
  String get timeOffNone => 'Жоспарланған демалыс жоқ';

  @override
  String timeOffAffected(int n) {
    return 'Осы кезеңдегі жазылулар: $n';
  }

  @override
  String get timeOffRemove => 'Жою';

  @override
  String get errOverlap => 'Бір күннің уақыттары қиылыспауы керек';

  @override
  String get errRangeOrder => 'Аяқталуы басталуынан кейін болуы керек';

  @override
  String get errTooManyRanges => 'Күніне алты аралықтан артық болмайды';

  @override
  String get promosNav => 'Промокодтар';

  @override
  String get promosNone =>
      'Промокод әлі жоқ. Промокод жасаңыз — қонақтар жазылу кезінде енгізе алады.';

  @override
  String get promoAdd => 'Жаңа промокод';

  @override
  String get promoCode => 'Код';

  @override
  String get promoKindPercent => 'Пайыз';

  @override
  String get promoKindFixed => 'Тіркелген сома';

  @override
  String get promoValue => 'Жеңілдік мөлшері';

  @override
  String get promoMaxUses => 'Ең көп қолдану (міндетті емес)';

  @override
  String get promoUntil => 'Жарамды мерзімі (міндетті емес)';

  @override
  String get promoAnyService => 'Кез келген қызмет';

  @override
  String get promoCodeOptional => 'Промокод (міндетті емес)';

  @override
  String get promoEnabled => 'Қосулы';

  @override
  String promoUsed(String used, String max) {
    return 'Қолданылды $used$max';
  }

  @override
  String get promoOff => 'Өшірулі';

  @override
  String promoDiscountOf(String value) {
    return 'Жеңілдік $value';
  }

  @override
  String promoValidUntilLabel(String date) {
    return '$date дейін';
  }

  @override
  String get errPromo => 'Промокод жарамсыз.';

  @override
  String get errCodeExists => 'Мұндай код бар.';

  @override
  String get tagsTitle => 'Тегтер';

  @override
  String get tagsHint =>
      'Үтір арқылы, ұзындығы 30 таңбаға дейінгі 10 тегке дейін';

  @override
  String get tagsInvalid => '10 тегтен көп емес, әрқайсысы 30 таңбаға дейін.';

  @override
  String get mergeClient => 'Қосарланған жазбаны біріктіру';

  @override
  String mergeIntro(String name) {
    return '$name клиентінің қосарланған жазбасын тауып, осы карточкаға біріктіріңіз.';
  }

  @override
  String mergeWarning(String dup, String phone, String name) {
    return '$dup ($phone) жазбасын $name карточкасына біріктіру керек пе? Жазбалар, тегтер мен ескертпелер $name карточкасына ауысады, қосарланған карточка жойылады. Жарнамаға келісім ауыспайды. Мұны қайтару мүмкін емес.';
  }
}
