import 'package:flutter/material.dart';
import '../../core/design/tokens.dart';

import '../../core/errors.dart';

/// Runs [action], shows a localized error snackbar on failure. Returns true on success.
Future<bool> guarded(BuildContext context, Future<void> Function() action) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    return true;
  } catch (e) {
    if (context.mounted) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(context, e)), behavior: SnackBarBehavior.floating));
    }
    return false;
  }
}

/// Weekday label (1=Mon..7=Sun) in the current locale.
String weekdayLabel(BuildContext context, int isoDay) {
  const names = {
    'en': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
    'ru': ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'],
    'kk': ['Дс', 'Сс', 'Ср', 'Бс', 'Жм', 'Сн', 'Жс'],
  };
  return (names[Localizations.localeOf(context).languageCode] ?? names['en']!)[isoDay - 1];
}

String hhmm(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

TimeOfDay parseHhmm(String s) => TimeOfDay(hour: int.parse(s.substring(0, 2)), minute: int.parse(s.substring(3, 5)));

/// Like [guarded] but for MODAL forms: returns the localized error text (null on success) so the form can show it inline.
/// A SnackBar would be drawn BEHIND a bottom sheet / dialog and the user would never see it.
Future<String?> attempt(BuildContext context, Future<void> Function() action) async {
  try {
    await action();
    return null;
  } catch (e) {
    return context.mounted ? errorText(context, e) : '';
  }
}

class FormError extends StatelessWidget {
  final String? message;
  const FormError(this.message, {super.key});
  @override
  Widget build(BuildContext context) => message == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(message!, key: const Key('formError'), style: TextStyle(color: context.palette.dangerFg)),
        );
}
