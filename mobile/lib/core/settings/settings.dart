import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const supportedLocales = [Locale('kk'), Locale('ru'), Locale('en')];

/// Per-device preferences (language, theme). Not sensitive, so SharedPreferences is fine.
class SettingsState {
  final Locale? locale; // null = follow the device
  final ThemeMode themeMode;
  const SettingsState({this.locale, this.themeMode = ThemeMode.system});
}

class SettingsController extends Notifier<SettingsState> {
  SharedPreferences? _prefs;

  @override
  SettingsState build() {
    _load();
    return const SettingsState();
  }

  Future<void> _load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final lang = _prefs!.getString('locale');
      final theme = _prefs!.getString('theme');
      state = SettingsState(
        locale: lang == null ? null : Locale(lang),
        themeMode: ThemeMode.values.firstWhere((m) => m.name == theme, orElse: () => ThemeMode.system),
      );
    } catch (_) {/* preferences unavailable: keep defaults */}
  }

  Future<void> setLocale(Locale? l) async {
    state = SettingsState(locale: l, themeMode: state.themeMode);
    final p = _prefs ?? await SharedPreferences.getInstance();
    l == null ? await p.remove('locale') : await p.setString('locale', l.languageCode);
  }

  Future<void> setThemeMode(ThemeMode m) async {
    state = SettingsState(locale: state.locale, themeMode: m);
    final p = _prefs ?? await SharedPreferences.getInstance();
    await p.setString('theme', m.name);
  }
}

final settingsProvider = NotifierProvider<SettingsController, SettingsState>(SettingsController.new);
