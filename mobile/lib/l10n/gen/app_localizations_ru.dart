// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appName => 'ORLEU';

  @override
  String get tagline => 'Ваш бизнес. Ваш рост.';

  @override
  String get signIn => 'Войти';

  @override
  String get createAccount => 'Создать аккаунт';

  @override
  String get noAccountYet => 'Нет аккаунта? Создать';

  @override
  String get haveAccount => 'Уже есть аккаунт? Войти';

  @override
  String get email => 'E-mail';

  @override
  String get password => 'Пароль';

  @override
  String get fullName => 'Имя и фамилия';

  @override
  String get logout => 'Выйти';

  @override
  String get validationRequired => 'Обязательное поле';

  @override
  String get validationEmail => 'Введите корректный e-mail';

  @override
  String get validationPasswordShort => 'Не менее 10 символов';

  @override
  String get validationSlug => '3-60 символов: строчные буквы, цифры, дефисы';

  @override
  String get errInvalidCredentials => 'Неверный e-mail или пароль';

  @override
  String get errEmailTaken => 'Аккаунт с таким e-mail уже существует';

  @override
  String get errAccountLocked => 'Слишком много попыток. Попробуйте позже.';

  @override
  String get errSlugTaken => 'Этот адрес страницы записи уже занят';

  @override
  String get errNetwork => 'Нет связи с сервером';

  @override
  String get errGeneric => 'Что-то пошло не так. Попробуйте ещё раз.';

  @override
  String get errInvalidTransition => 'Это изменение недоступно для записи';

  @override
  String get retry => 'Повторить';

  @override
  String get navHome => 'Главная';

  @override
  String get navCalendar => 'Календарь';

  @override
  String get navCustomers => 'Клиенты';

  @override
  String get navFinance => 'Финансы';

  @override
  String get navMore => 'Ещё';

  @override
  String greeting(String name) {
    return 'Здравствуйте, $name';
  }

  @override
  String get todayCollected => 'Получено сегодня';

  @override
  String get todayBookings => 'Записей сегодня';

  @override
  String get pendingBookings => 'Ждут действия';

  @override
  String get upcoming => 'Ближайшие';

  @override
  String get nothingUpcoming => 'Сегодня больше нет записей';

  @override
  String get createBusinessTitle => 'Настройте ваш бизнес';

  @override
  String get createBusinessIntro => 'Создайте бизнес, чтобы принимать записи.';

  @override
  String get businessName => 'Название бизнеса';

  @override
  String get bookingPageAddress => 'Адрес страницы записи';

  @override
  String get businessType => 'Тип бизнеса';

  @override
  String get create => 'Создать';

  @override
  String get typeBarbershop => 'Барбершоп';

  @override
  String get typeBeautySalon => 'Салон красоты';

  @override
  String get typeClinic => 'Клиника';

  @override
  String get typeFitness => 'Фитнес-студия';

  @override
  String get typeOther => 'Другое';

  @override
  String get noBookings => 'На этот день записей нет';

  @override
  String get statusPending => 'Ожидает';

  @override
  String get statusAwaitingPayment => 'Ждёт оплаты';

  @override
  String get statusConfirmed => 'Подтверждена';

  @override
  String get statusCheckedIn => 'Клиент пришёл';

  @override
  String get statusInProgress => 'В процессе';

  @override
  String get statusCompleted => 'Завершена';

  @override
  String get statusCancelled => 'Отменена';

  @override
  String get statusNoShow => 'Не пришёл';

  @override
  String get statusExpired => 'Истекла';

  @override
  String get actionConfirm => 'Подтвердить';

  @override
  String get actionCheckIn => 'Клиент пришёл';

  @override
  String get actionStart => 'Начать';

  @override
  String get actionComplete => 'Завершить';

  @override
  String get actionNoShow => 'Не пришёл';

  @override
  String get actionCancel => 'Отменить запись';

  @override
  String get price => 'Цена';

  @override
  String get deposit => 'Депозит';

  @override
  String get paid => 'Оплачено';

  @override
  String get remaining => 'Остаток';

  @override
  String get paymentStatus => 'Оплата';

  @override
  String get payUnpaid => 'Не оплачено';

  @override
  String get payPartial => 'Частично оплачено';

  @override
  String get payDepositPaid => 'Депозит внесён';

  @override
  String get payPaid => 'Оплачено полностью';

  @override
  String get payRefunded => 'Возвращено';

  @override
  String get employee => 'Сотрудник';

  @override
  String get customer => 'Клиент';

  @override
  String get searchCustomers => 'Поиск по имени или телефону';

  @override
  String get noCustomers => 'Клиенты не найдены';

  @override
  String get financeTitle => 'Финансы за 30 дней';

  @override
  String get bookedValue => 'Сумма записей';

  @override
  String get collected => 'Получено';

  @override
  String get refunded => 'Возвращено';

  @override
  String get netCollected => 'Получено чистыми';

  @override
  String get outstanding => 'Неоплаченный остаток';

  @override
  String get cancellationRate => 'Доля отмен';

  @override
  String get noShowRate => 'Доля неявок';

  @override
  String get financeNote =>
      'Сумма записей — не деньги в кассе: полученные платежи показаны отдельно.';

  @override
  String get language => 'Язык';

  @override
  String get theme => 'Тема';

  @override
  String get themeSystem => 'Системная';

  @override
  String get themeLight => 'Светлая';

  @override
  String get themeDark => 'Тёмная';

  @override
  String get plan => 'Тариф';

  @override
  String planUsage(int used, int limit) {
    return '$used из $limit сотрудников';
  }

  @override
  String get setupTitle => 'Настройка бизнеса';

  @override
  String get setupIntro => 'Выполните эти шаги, чтобы открыть онлайн-запись.';

  @override
  String get stepBranch => 'Добавьте филиал';

  @override
  String get stepHours => 'Укажите часы работы';

  @override
  String get stepService => 'Добавьте услугу';

  @override
  String get stepEmployee => 'Добавьте специалиста и назначьте услуги';

  @override
  String get stepPublish => 'Опубликуйте страницу записи';

  @override
  String get branches => 'Филиалы и часы';

  @override
  String get addBranch => 'Добавить филиал';

  @override
  String get branchName => 'Название филиала';

  @override
  String get address => 'Адрес (необязательно)';

  @override
  String get workingHours => 'Часы работы';

  @override
  String get closed => 'Выходной';

  @override
  String get applyDefaultHours => 'Пн–Вс 09:00–18:00';

  @override
  String get save => 'Сохранить';

  @override
  String get saved => 'Сохранено';

  @override
  String get cancel => 'Отмена';

  @override
  String get services => 'Услуги';

  @override
  String get addService => 'Добавить услугу';

  @override
  String get serviceName => 'Название услуги';

  @override
  String get durationMin => 'Длительность, минут';

  @override
  String get priceField => 'Цена';

  @override
  String get depositPercentOptional => 'Депозит, % (необязательно)';

  @override
  String get bufferMin => 'Перерыв после услуги, минут (необязательно)';

  @override
  String get noneYet => 'Пока ничего нет';

  @override
  String get employees => 'Специалисты';

  @override
  String get addEmployee => 'Добавить специалиста';

  @override
  String get employeeName => 'Имя специалиста';

  @override
  String get assignLocations => 'Работает в';

  @override
  String get assignServices => 'Выполняет';

  @override
  String get publish => 'Опубликовать страницу записи';

  @override
  String get unpublish => 'Снять с публикации';

  @override
  String get publishedHint => 'Ваша страница записи работает';

  @override
  String get bookingLink => 'Ссылка для записи';

  @override
  String get copyLink => 'Скопировать ссылку';

  @override
  String get copied => 'Скопировано';

  @override
  String get errLimit =>
      'Достигнут лимит вашего тарифа. Свяжитесь с ORLEU для повышения.';

  @override
  String get errNotReady =>
      'Сначала завершите настройку: филиал с часами работы, услуга и назначенный специалист.';

  @override
  String get errSuspended =>
      'Бизнес приостановлен. Обратитесь в поддержку ORLEU.';

  @override
  String get setupNav => 'Настройка бизнеса';

  @override
  String get minutesShort => 'мин';

  @override
  String get newBooking => 'Новая запись';

  @override
  String get selectService => 'Услуга';

  @override
  String get selectLocation => 'Филиал';

  @override
  String get selectSpecialist => 'Специалист';

  @override
  String get anySpecialist => 'Любой свободный';

  @override
  String get pickDate => 'Дата';

  @override
  String get pickTime => 'Время';

  @override
  String get noSlots => 'На этот день нет свободного времени';

  @override
  String get clientName => 'Имя клиента';

  @override
  String get clientPhone => 'Телефон клиента';

  @override
  String get validationPhone =>
      'Международный формат, например +7 701 123 45 67';

  @override
  String get notesOptional => 'Заметка (необязательно)';

  @override
  String get bookAction => 'Создать запись';

  @override
  String get rescheduleAction => 'Перенести';

  @override
  String get rescheduleTitle => 'Перенос записи';

  @override
  String get moveHere => 'Перенести';

  @override
  String get errSlot => 'Это время уже недоступно. Выберите другое.';

  @override
  String get errBlockedCustomer => 'Этот клиент заблокирован.';

  @override
  String get setupFirst =>
      'Сначала завершите настройку: филиал, услуга и специалист.';

  @override
  String get bookingCreated => 'Запись создана';

  @override
  String get bookingMoved => 'Запись перенесена';

  @override
  String get recordPayment => 'Принять оплату';

  @override
  String get paymentAmount => 'Сумма';

  @override
  String get paymentMethod => 'Способ';

  @override
  String get methodCash => 'Наличные';

  @override
  String get methodBank => 'Банковский перевод';

  @override
  String get methodCard => 'Карта (вручную)';

  @override
  String get errOverpayment => 'Сумма превышает остаток к оплате.';

  @override
  String get paymentRecorded => 'Оплата записана';

  @override
  String get validationAmount => 'Введите сумму не больше остатка';

  @override
  String get statVisits => 'Визиты';

  @override
  String get statCancelled => 'Отмены';

  @override
  String get statNoShows => 'Неявки';

  @override
  String get statUpcoming => 'Предстоящие';

  @override
  String get statLastVisit => 'Последний визит';

  @override
  String get statSpent => 'Оплачено всего';

  @override
  String get statAvg => 'В среднем за визит';

  @override
  String get noVisitsYet => 'Визитов пока нет';

  @override
  String get historyTitle => 'История записей';

  @override
  String get noHistory => 'Записей пока нет';

  @override
  String get notes => 'Заметки';

  @override
  String get editClient => 'Изменить клиента';

  @override
  String get marketingConsent => 'Согласен на рекламные сообщения';

  @override
  String get blockClient => 'Заблокировать клиента';

  @override
  String get unblockClient => 'Разблокировать клиента';

  @override
  String get blockConfirm =>
      'Заблокированный клиент не может записаться онлайн, и сотрудники не смогут его записать.';

  @override
  String get blocked => 'Заблокирован';

  @override
  String get edit => 'Изменить';

  @override
  String get active => 'Активно';

  @override
  String get inactive => 'Неактивно';

  @override
  String get deactivateNote =>
      'Неактивное не показывается при записи. Существующие записи и история сохраняются.';

  @override
  String get editService => 'Изменить услугу';

  @override
  String get editLocation => 'Изменить филиал';

  @override
  String get editSpecialist => 'Изменить специалиста';

  @override
  String get statsNote =>
      'Оплачено = полученные деньги минус возвраты, а не сумма записей.';

  @override
  String get reportsTitle => 'Отчёты';

  @override
  String reportPeriodDays(String n) {
    return '$n дн.';
  }

  @override
  String get reportRevenueByDay => 'Получено по дням (за вычетом возвратов)';

  @override
  String get reportTopServices => 'Услуги';

  @override
  String get reportTopEmployees => 'Специалисты';

  @override
  String get reportBranches => 'Филиалы';

  @override
  String get reportPeakHours => 'Самые загруженные часы';

  @override
  String get reportCustomers => 'Новые и вернувшиеся клиенты';

  @override
  String get reportNew => 'Новые';

  @override
  String get reportReturning => 'Вернувшиеся';

  @override
  String get reportNoData => 'За этот период данных пока нет';

  @override
  String reportBookingsN(String n) {
    return 'Записей: $n';
  }

  @override
  String reportReturningShare(String p) {
    return 'Вернулись $p% клиентов';
  }

  @override
  String get reportsNote =>
      'Цифры считаются по записям и платежам за выбранный период. Отменённые записи не считаются спросом.';

  @override
  String get messagesNav => 'Сообщения клиентам';

  @override
  String get messagesReminder => 'Напоминать клиентам до визита';

  @override
  String get messagesReminderOff => 'Выкл.';

  @override
  String messagesReminderHours(String n) {
    return 'за $n ч';
  }

  @override
  String get messagesLanguage => 'Язык сообщений клиентам';

  @override
  String get messagesPrepared => 'Подготовленные сообщения';

  @override
  String get messagesNone => 'Подготовленных сообщений пока нет';

  @override
  String get messagesNotSent => 'Не отправлено';

  @override
  String get messagesNote =>
      'Отправка по SMS или e-mail ещё не подключена: сообщения готовятся и показаны здесь, но клиентам ничего не доставляется.';

  @override
  String get messagesSaved => 'Сохранено';

  @override
  String get forgotPassword => 'Забыли пароль?';

  @override
  String get resetIntro =>
      'Введите e-mail аккаунта, чтобы запросить код сброса пароля.';

  @override
  String get resetRequest => 'Запросить код';

  @override
  String get resetRequested =>
      'Если для этого e-mail есть аккаунт, код сброса запрошен. Введите полученный код и задайте новый пароль.';

  @override
  String get resetCode => 'Код сброса';

  @override
  String get newPassword => 'Новый пароль';

  @override
  String get resetConfirm => 'Сохранить новый пароль';

  @override
  String get resetDone => 'Пароль изменён. Войдите с новым паролем.';

  @override
  String get backToSignIn => 'Назад ко входу';

  @override
  String get errWrongPassword => 'Текущий пароль указан неверно';

  @override
  String get errResetToken => 'Код сброса недействителен или истёк';

  @override
  String get accountNav => 'Аккаунт и безопасность';

  @override
  String get changePassword => 'Сменить пароль';

  @override
  String get currentPassword => 'Текущий пароль';

  @override
  String get confirmPassword => 'Повторите новый пароль';

  @override
  String get passwordsDiffer => 'Пароли не совпадают';

  @override
  String get passwordChanged =>
      'Пароль изменён. Остальные устройства разлогинены.';

  @override
  String get sessionsTitle => 'Устройства с входом';

  @override
  String get sessionsNote =>
      'Смена пароля разлогинивает все остальные устройства. Если завершить сессию этого устройства, вы выйдете и здесь.';

  @override
  String get sessionRevoke => 'Выйти';

  @override
  String get sessionUnknownDevice => 'Неизвестное устройство';

  @override
  String sessionSince(String date) {
    return 'С $date';
  }

  @override
  String get signOutEverywhere => 'Выйти на всех устройствах';

  @override
  String get sessionsNone => 'Нет активных сессий';

  @override
  String get calDay => 'День';

  @override
  String get calWeek => 'Неделя';

  @override
  String get calMonth => 'Месяц';

  @override
  String get filterAllSpecialists => 'Все специалисты';

  @override
  String get filterAllLocations => 'Все филиалы';

  @override
  String calBookingsCount(int n) {
    return 'Записей: $n';
  }

  @override
  String get reviewsNav => 'Отзывы';

  @override
  String get reviewsAverage => 'Средняя оценка';

  @override
  String reviewsCount(int n) {
    return 'Отзывов: $n';
  }

  @override
  String get reviewsNone =>
      'Отзывов пока нет. Клиент может оценить состоявшийся визит по ссылке на свою запись.';

  @override
  String get reviewsNote =>
      'Отзывы приходят только от состоявшихся визитов, бизнес не может их менять.';

  @override
  String get supportNav => 'Поддержка';

  @override
  String get supportIntro =>
      'Напишите команде ORLEU о проблеме с оплатой, технической проблеме или аккаунтом. Ответы появятся здесь.';

  @override
  String get supportNew => 'Новое обращение';

  @override
  String get supportSubject => 'Тема';

  @override
  String get supportBody => 'Опишите проблему';

  @override
  String get supportCategory => 'Раздел';

  @override
  String get catBILLING => 'Оплата';

  @override
  String get catTECHNICAL => 'Техническое';

  @override
  String get catACCOUNT => 'Аккаунт';

  @override
  String get catOTHER => 'Другое';

  @override
  String get supportCreate => 'Отправить';

  @override
  String get supportNone => 'Обращений пока нет';

  @override
  String get stOPEN => 'Ждёт ответа поддержки';

  @override
  String get stANSWERED => 'Есть ответ';

  @override
  String get stCLOSED => 'Закрыто';

  @override
  String get supportReply => 'Ваш ответ';

  @override
  String get supportSend => 'Отправить';

  @override
  String get supportCloseTicket => 'Закрыть обращение';

  @override
  String get supportClosedNote =>
      'Обращение закрыто. Если нужна помощь, создайте новое.';

  @override
  String get supportTeam => 'Поддержка ORLEU';

  @override
  String get supportYou => 'Вы';

  @override
  String get errTicketClosed => 'Обращение закрыто';

  @override
  String get errTooManyTickets =>
      'Слишком много открытых обращений. Закройте часть или дождитесь ответов.';

  @override
  String get notifTitle => 'Уведомления';

  @override
  String get notifMarkAll => 'Отметить всё прочитанным';

  @override
  String get notifNone => 'Уведомлений пока нет';

  @override
  String get notifBOOKING_CREATED => 'Новая запись';

  @override
  String get notifBOOKING_CONFIRMED => 'Запись подтверждена';

  @override
  String get notifBOOKING_CANCELLED => 'Запись отменена';

  @override
  String get notifBOOKING_RESCHEDULED => 'Запись перенесена';

  @override
  String get notifBOOKING_EXPIRED => 'Неоплаченная запись истекла';

  @override
  String get notifBOOKING_CHECKED_IN => 'Клиент пришёл';

  @override
  String get notifBOOKING_IN_PROGRESS => 'Визит начался';

  @override
  String get notifBOOKING_COMPLETED => 'Визит завершён';

  @override
  String get notifBOOKING_NO_SHOW => 'Клиент не пришёл';

  @override
  String get notifBOOKING_REMINDER => 'Подготовлено напоминание клиенту';

  @override
  String get notifPAYMENT_RECEIVED => 'Платёж записан';

  @override
  String get notifSUPPORT_REPLIED =>
      'Поддержка ORLEU ответила на ваше обращение';

  @override
  String get notifOther => 'Обновление';

  @override
  String get importNav => 'Импорт клиентов (CSV)';

  @override
  String get importIntro =>
      'Сохраните таблицу как CSV (UTF-8). Первая строка — названия столбцов: обязательны имя и телефон, e-mail и заметки по желанию. Уже существующие клиенты не меняются, а импортированные не считаются давшими согласие на рекламные сообщения.';

  @override
  String get importChoose => 'Выбрать файл CSV';

  @override
  String importFile(String name) {
    return 'Файл: $name';
  }

  @override
  String get importNew => 'Новые клиенты';

  @override
  String get importExisting => 'Уже есть в списке';

  @override
  String get importDupes => 'Дубли внутри файла';

  @override
  String get importInvalid => 'Строки с ошибками';

  @override
  String get importProblems => 'Строки, которые будут пропущены';

  @override
  String importRow(String row, String reason) {
    return 'Строка $row: $reason';
  }

  @override
  String get imp_PHONE_INVALID => 'неверный номер телефона';

  @override
  String get imp_NAME_MISSING => 'нет имени';

  @override
  String get imp_NAME_TOO_LONG => 'слишком длинное имя';

  @override
  String get imp_EMAIL_INVALID => 'неверный e-mail';

  @override
  String get imp_NOTES_TOO_LONG => 'слишком длинные заметки';

  @override
  String get importMoreProblems => '…и ещё строки с ошибками';

  @override
  String importConfirm(String n) {
    return 'Импортировать клиентов: $n';
  }

  @override
  String get importNothing => 'Новых клиентов для импорта нет';

  @override
  String importDone(String n) {
    return 'Импортировано клиентов: $n';
  }

  @override
  String get importAnother => 'Импортировать другой файл';

  @override
  String get importPreviewSample => 'Первые новые клиенты';

  @override
  String get errImportEmpty => 'Файл пуст или в нём нет строк с клиентами';

  @override
  String get errImportColumns =>
      'В первой строке должны быть столбцы с именем и телефоном';

  @override
  String get errImportTooLarge =>
      'Файл слишком большой (не более 5000 клиентов и 2 МБ)';

  @override
  String get errImportEncoding =>
      'Файл не в кодировке UTF-8. В Excel при сохранении выберите «CSV UTF-8».';

  @override
  String get exportTitle => 'Экспорт для бухгалтерии';

  @override
  String get exportNote =>
      'CSV со всеми платежами и возвратами за выбранный период (возвраты отрицательные, время бизнеса). Без имён и телефонов клиентов; это не фискальный документ.';

  @override
  String get exportComma => 'Запятая';

  @override
  String get exportSemicolon => 'Точка с запятой (Excel RU/KZ)';

  @override
  String get exportButton => 'Экспорт CSV';

  @override
  String get exportSaved => 'Файл сохранён';

  @override
  String get exportCancelled => 'Не сохранено';

  @override
  String get errExportTooLarge =>
      'Слишком много записей: выберите период короче';

  @override
  String get errExportForbidden =>
      'Ваша роль не позволяет выгружать финансовые данные';

  @override
  String get mfaTitle => 'Двухфакторная аутентификация';

  @override
  String get mfaIntro =>
      'Защитите аккаунт кодом из приложения-аутентификатора (Google Authenticator, Microsoft Authenticator, Aegis и т. п.). Для входа понадобятся пароль и код.';

  @override
  String get mfaOff => 'Выкл.';

  @override
  String mfaOn(int n) {
    return 'Вкл. · резервных кодов: $n';
  }

  @override
  String get mfaEnable => 'Включить';

  @override
  String get mfaDisable => 'Выключить';

  @override
  String get mfaSetupKey => 'Ключ настройки';

  @override
  String get mfaSetupHint =>
      'В приложении-аутентификаторе добавьте аккаунт с этим ключом (по времени), затем введите 6-значный код оттуда.';

  @override
  String get mfaCopy => 'Скопировать ключ';

  @override
  String get mfaCode => '6-значный код';

  @override
  String get mfaConfirm => 'Подтвердить';

  @override
  String get mfaRecoveryTitle => 'Резервные коды';

  @override
  String get mfaRecoveryNote =>
      'Сохраните эти коды в надёжном месте. Каждый работает один раз, если вы потеряете телефон. Показаны только сейчас.';

  @override
  String get mfaSaved => 'Я сохранил(а)';

  @override
  String get mfaDisableHint =>
      'Введите пароль и текущий код (или резервный код).';

  @override
  String get mfaLoginTitle =>
      'Введите код из приложения-аутентификатора или резервный код.';

  @override
  String get mfaVerify => 'Проверить';

  @override
  String get errMfaCode => 'Неверный код';

  @override
  String get errMfaChallenge => 'Время попытки входа истекло. Войдите заново.';

  @override
  String get errMfaRequired =>
      'Для этого аккаунта обязательна двухфакторная аутентификация';

  @override
  String get histTitle => 'Последние входы';

  @override
  String histAlertFailed(int n) {
    return 'Неудачных попыток входа с прошлого успешного входа: $n.';
  }

  @override
  String get histAlertNewDevice =>
      'За последние 7 дней зафиксирован вход с нового устройства.';

  @override
  String get histAlertHint =>
      'Если это были не вы, смените пароль и выйдите на всех устройствах.';

  @override
  String get histSUCCESS => 'Вход выполнен';

  @override
  String get histFAILED_PASSWORD => 'Неверный пароль';

  @override
  String get histFAILED_MFA => 'Неверный код';

  @override
  String get histLOCKED => 'Блокировка: слишком много попыток';

  @override
  String get histNewDevice => 'Новое устройство';

  @override
  String get histWithCode => 'с кодом';

  @override
  String get histNone => 'Входов пока не зафиксировано';

  @override
  String get histNote =>
      'Хранится 90 дней. Устройство определяется по типу приложения или браузера, это не доказательство.';

  @override
  String get privacyExport => 'Выгрузить данные клиента';

  @override
  String get privacyDelete => 'Удалить персональные данные';

  @override
  String get privacyDeleteWarn =>
      'Имя, телефон, e-mail, заметки и сообщения этого клиента будут удалены навсегда, отменить нельзя. Записи и платежи останутся для вашей отчётности, но без персональных данных.';

  @override
  String get privacyConfirm => 'Удалить навсегда';

  @override
  String get privacyDone => 'Персональные данные удалены';

  @override
  String get errHasUpcoming => 'Сначала отмените будущие записи клиента';

  @override
  String get privacySaved => 'Файл сохранён';

  @override
  String get retentionTitle => 'Автоудаление неактивных клиентов';

  @override
  String get retentionNote =>
      'Обезличивать клиентов, у которых не было записей так долго (кроме тех, у кого есть будущие записи). По умолчанию выключено. Уточните требования закона вашей страны.';

  @override
  String get retentionOff => 'Выкл.';

  @override
  String retentionYears(String n) {
    return '$n г.';
  }

  @override
  String get scheduleOpen => 'Рабочие часы и отпуск';

  @override
  String get scheduleTitle => 'Рабочие часы';

  @override
  String get scheduleFollow => 'Как у филиала';

  @override
  String get scheduleFollowNote =>
      'Без личных часов специалист работает всё время, пока открыт филиал.';

  @override
  String get scheduleBreakHint =>
      'Добавьте два интервала в один день, чтобы сделать перерыв.';

  @override
  String get scheduleDayOff => 'Выходной';

  @override
  String get scheduleAddRange => 'Добавить часы';

  @override
  String get scheduleFrom => 'С';

  @override
  String get scheduleTo => 'До';

  @override
  String get scheduleSave => 'Сохранить часы';

  @override
  String get scheduleSaved => 'Часы сохранены';

  @override
  String scheduleAffected(int n) {
    return 'Будущих записей, не попадающих в эти часы: $n. Они не отменены: перенесите их в календаре.';
  }

  @override
  String get timeOffTitle => 'Отпуск и отсутствие';

  @override
  String get timeOffAdd => 'Добавить отсутствие';

  @override
  String get timeOffReason => 'Причина (необязательно)';

  @override
  String get timeOffNone => 'Отсутствий не запланировано';

  @override
  String timeOffAffected(int n) {
    return 'Записей за этот период: $n';
  }

  @override
  String get timeOffRemove => 'Удалить';

  @override
  String get errOverlap => 'Часы одного дня не должны пересекаться';

  @override
  String get errRangeOrder => 'Конец должен быть позже начала';

  @override
  String get errTooManyRanges => 'Не больше шести интервалов в день';

  @override
  String get promosNav => 'Промокоды';

  @override
  String get promosNone =>
      'Промокодов пока нет. Создайте промокод — гости смогут ввести его при записи.';

  @override
  String get promoAdd => 'Новый промокод';

  @override
  String get promoCode => 'Код';

  @override
  String get promoKindPercent => 'Процент';

  @override
  String get promoKindFixed => 'Фиксированная сумма';

  @override
  String get promoValue => 'Размер скидки';

  @override
  String get promoMaxUses => 'Макс. использований (необязательно)';

  @override
  String get promoUntil => 'Действует до (необязательно)';

  @override
  String get promoAnyService => 'Любая услуга';

  @override
  String get promoCodeOptional => 'Промокод (необязательно)';

  @override
  String get promoEnabled => 'Включён';

  @override
  String promoUsed(String used, String max) {
    return 'Использован $used$max';
  }

  @override
  String get promoOff => 'Выкл.';

  @override
  String promoDiscountOf(String value) {
    return 'Скидка $value';
  }

  @override
  String promoValidUntilLabel(String date) {
    return 'до $date';
  }

  @override
  String get errPromo => 'Промокод недействителен.';

  @override
  String get errCodeExists => 'Такой код уже существует.';

  @override
  String get tagsTitle => 'Теги';

  @override
  String get tagsHint => 'Через запятую, до 10 тегов по 30 символов';

  @override
  String get tagsInvalid => 'Не более 10 тегов, каждый до 30 символов.';

  @override
  String get mergeClient => 'Объединить дубликат';

  @override
  String mergeIntro(String name) {
    return 'Найдите дубликат клиента $name, чтобы влить его в эту карточку.';
  }

  @override
  String mergeWarning(String dup, String phone, String name) {
    return 'Влить $dup ($phone) в $name? Записи, теги и заметки перейдут к $name, карточка-дубликат будет удалена. Согласие на рекламу не переносится. Это нельзя отменить.';
  }

  @override
  String get exceptionsTitle => 'Особые дни';

  @override
  String get exceptionAdd => 'Добавить особый день';

  @override
  String get exceptionsNote =>
      'Дата здесь заменяет недельный график на этот один день: выходной или другие часы.';

  @override
  String get exceptionsNone => 'Особых дней нет';

  @override
  String get exceptionPickDate => 'Выберите дату';

  @override
  String get scheduleBadRange => 'Конец должен быть позже начала.';

  @override
  String get close => 'Закрыть';

  @override
  String get refundAction => 'Возврат';

  @override
  String get refundRecorded => 'Возврат записан';

  @override
  String get refundPending => 'Возврат отправлен на согласование';

  @override
  String get validationRefundAmount => 'Введите сумму не больше оплаченной';

  @override
  String get refundsNav => 'Возвраты';

  @override
  String get refundsNone => 'Запросов на возврат нет';

  @override
  String get refundsPolicyTitle => 'Согласование крупных возвратов';

  @override
  String get refundsPolicyOff =>
      'Выключено: каждый возврат записывается сразу.';

  @override
  String get refundsThreshold => 'Порог согласования';

  @override
  String get refundsThresholdHint =>
      'Возвраты выше этой суммы подтверждает владелец или администратор. Пусто = выключено.';

  @override
  String get refundStatusPending => 'Ожидает';

  @override
  String get refundStatusApproved => 'Одобрен';

  @override
  String get refundStatusRejected => 'Отклонён';

  @override
  String get refundApprove => 'Одобрить';

  @override
  String get refundReject => 'Отклонить';

  @override
  String refundRequestedBy(String name) {
    return 'Запросил(а): $name';
  }

  @override
  String refundsPolicyOn(String amount) {
    return 'Согласование нужно для сумм выше $amount';
  }

  @override
  String get closingTitle => 'Закрыть кассу';

  @override
  String get closingFirst =>
      'Первое закрытие: считается с начала сегодняшнего дня.';

  @override
  String get closingExpectedCash => 'Ожидаемо наличных в кассе';

  @override
  String get closingNotCounted =>
      'Суммы по банку и карте нужны бухгалтеру; в кассе они не пересчитываются.';

  @override
  String get closingCounted => 'Посчитано наличных';

  @override
  String get closingMatches => 'Совпадает с ожидаемой суммой.';

  @override
  String get closingConfirm => 'Закрыть кассу';

  @override
  String get closingDone => 'Касса закрыта';

  @override
  String get closingHistory => 'Прошлые закрытия';

  @override
  String get closingNone => 'Закрытий ещё не было';

  @override
  String get errExpectedChanged =>
      'Платежи изменились, пока вы считали. Проверьте новую ожидаемую сумму и подтвердите ещё раз.';

  @override
  String get errRefundExceeds => 'Возврат больше, чем сейчас оплачено.';

  @override
  String get errAlreadyDecided => 'По этому запросу уже принято решение.';

  @override
  String closingPeriod(String from, String to) {
    return 'Период: $from – $to';
  }

  @override
  String closingShortage(String amount) {
    return 'Недостача: $amount';
  }

  @override
  String closingSurplus(String amount) {
    return 'Излишек: $amount';
  }

  @override
  String closingRow(String expected, String counted) {
    return 'ожидалось $expected, посчитано $counted';
  }

  @override
  String get reviewReply => 'Ответить';

  @override
  String get reviewReplyRemove => 'Удалить ответ';

  @override
  String get reviewReplyNote =>
      'Ответ увидит гость на своей ссылке записи. Будьте вежливы и не называйте личных данных.';

  @override
  String reviewHidden(String reason) {
    return 'Скрыт платформой: $reason';
  }
}
