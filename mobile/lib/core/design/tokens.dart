import 'package:flutter/material.dart';

/// Central design tokens (ORLEU brand). Widgets must take colors from the theme / these tokens,
/// never hardcode hex values.
class AppColors {
  AppColors._();
  // Light
  static const background = Color(0xFFF7F8F5);
  static const surface = Color(0xFFFFFFFF);
  static const primaryDark = Color(0xFF14251D);
  static const primaryGreen = Color(0xFF176B52);
  static const secondaryGreen = Color(0xFFDDEDE3);
  static const accentLime = Color(0xFFC7F36B);
  static const textPrimary = Color(0xFF18231D);
  // Brand spec was #758078, which is only 4.1:1 on white (fails WCAG AA 4.5:1). Darkened slightly, same hue.
  static const textSecondary = Color(0xFF68736B);
  static const border = Color(0xFFE7EBE6);
  static const success = Color(0xFF25865B);
  static const warning = Color(0xFFD89B35);
  static const danger = Color(0xFFD95757);
  // Dark
  static const darkBackground = Color(0xFF101B16);
  static const darkSurface = Color(0xFF18251E);
  static const darkPrimary = Color(0xFFC7F36B);
  static const darkText = Color(0xFFF4F7F3);
}

/// Brand gradients and soft elevation used by hero surfaces (home dashboard).
class AppGradients {
  AppGradients._();
  static const hero = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF1B7A5C), AppColors.primaryDark],
  );
  static const logo = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [AppColors.primaryGreen, AppColors.primaryDark],
  );
  static List<BoxShadow> soft(BuildContext context) => [
        BoxShadow(
          color: AppColors.primaryDark.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.0 : 0.07),
          blurRadius: 24, offset: const Offset(0, 8),
        ),
      ];
}

class AppSpacing {
  AppSpacing._();
  static const double xs = 4, sm = 8, md = 16, lg = 24, xl = 32; // 8px grid
}

class AppRadius {
  AppRadius._();
  static const double card = 16; // spec: 14-18
  static const double hero = 24; // large dashboard cards
  static const double control = 12;
}

/// Semantic status colors shared by chips and badges.
extension StatusColors on ColorScheme {
  Color get success => AppColors.success;
  Color get warning => AppColors.warning;
  Color get danger => AppColors.danger;
}
