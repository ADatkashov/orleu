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
}
