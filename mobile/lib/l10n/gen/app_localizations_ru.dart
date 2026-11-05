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
}
