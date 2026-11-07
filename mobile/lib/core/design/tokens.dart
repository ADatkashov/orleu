import 'package:flutter/material.dart';

/// Central design tokens (ORLEU brand). Widgets take colors from the theme, [AppPalette] or these
/// tokens and never hardcode hex values.
class AppColors {
  AppColors._();
  // Light
  static const background = Color(0xFFF7F8F5);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF1F4EF);
  static const surfaceStrong = Color(0xFFE8EDE6);
  static const primaryDark = Color(0xFF14251D);
  static const primaryGreen = Color(0xFF176B52);
  static const primaryGreenLight = Color(0xFF1F8A67);
  static const secondaryGreen = Color(0xFFDDEDE3);
  static const accentLime = Color(0xFFC7F36B);
  static const accentLimeSoft = Color(0xFFEBF9C8);
  static const textPrimary = Color(0xFF18231D);
  // Brand spec was #758078, which is only 4.1:1 on white (fails WCAG AA 4.5:1). Darkened slightly, same hue.
  static const textSecondary = Color(0xFF68736B);
  static const border = Color(0xFFE7EBE6);
  static const borderStrong = Color(0xFFD3DAD1);
  // Semantic (fills / icons). Text on a soft tint uses the matching *Fg in [AppPalette] (AA contrast).
  static const success = Color(0xFF25865B);
  static const warning = Color(0xFFD89B35);
  static const danger = Color(0xFFD95757);
  static const info = Color(0xFF3B6FE0);
  // Dark
  static const darkBackground = Color(0xFF101B16);
  static const darkSurface = Color(0xFF18251E);
  static const darkSurfaceMuted = Color(0xFF1F2E26);
  static const darkSurfaceStrong = Color(0xFF283A31);
  static const darkPrimary = Color(0xFFC7F36B);
  static const darkText = Color(0xFFF4F7F3);
  static const darkTextSecondary = Color(0xFFA6B2AA);
  static const darkBorder = Color(0xFF2A3A31);
}

/// Semantic roles that differ between light and dark. Read with `context.palette`.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Color success, successSoft, successFg;
  final Color warning, warningSoft, warningFg;
  final Color danger, dangerSoft, dangerFg;
  final Color info, infoSoft, infoFg;
  final Color neutralSoft, neutralFg;
  final Color heroStart, heroEnd, onHero, onHeroMuted, heroAccent;
  final Color chartBar, chartBarMuted, chartHighlight, chartGrid;

  const AppPalette({
    required this.success, required this.successSoft, required this.successFg,
    required this.warning, required this.warningSoft, required this.warningFg,
    required this.danger, required this.dangerSoft, required this.dangerFg,
    required this.info, required this.infoSoft, required this.infoFg,
    required this.neutralSoft, required this.neutralFg,
    required this.heroStart, required this.heroEnd, required this.onHero, required this.onHeroMuted, required this.heroAccent,
    required this.chartBar, required this.chartBarMuted, required this.chartHighlight, required this.chartGrid,
  });

  static const light = AppPalette(
    success: AppColors.success, successSoft: Color(0xFFE3F3EA), successFg: Color(0xFF176B52),
    warning: AppColors.warning, warningSoft: Color(0xFFFCF0D0), warningFg: Color(0xFF8A5A00),
    danger: AppColors.danger, dangerSoft: Color(0xFFFBE4E4), dangerFg: Color(0xFFA83232),
    info: AppColors.info, infoSoft: Color(0xFFE4ECFD), infoFg: Color(0xFF2F58B5),
    neutralSoft: AppColors.surfaceStrong, neutralFg: AppColors.textSecondary,
    heroStart: Color(0xFF1B7A5C), heroEnd: AppColors.primaryDark, onHero: Colors.white, onHeroMuted: Color(0xFFB9D3C7), heroAccent: AppColors.accentLime,
    chartBar: AppColors.primaryGreen, chartBarMuted: AppColors.secondaryGreen, chartHighlight: AppColors.accentLime, chartGrid: AppColors.border,
  );

  static const dark = AppPalette(
    success: Color(0xFF5FD08F), successSoft: Color(0xFF1B3A2B), successFg: Color(0xFF8BE0AE),
    warning: Color(0xFFF0B955), warningSoft: Color(0xFF3D3015), warningFg: Color(0xFFF5CD84),
    danger: Color(0xFFF08080), dangerSoft: Color(0xFF402020), dangerFg: Color(0xFFF6A3A3),
    info: Color(0xFF7BA7F5), infoSoft: Color(0xFF1E2C4A), infoFg: Color(0xFFA6C3F8),
    neutralSoft: AppColors.darkSurfaceStrong, neutralFg: AppColors.darkTextSecondary,
    heroStart: Color(0xFF1F5F4A), heroEnd: Color(0xFF0B1712), onHero: AppColors.darkText, onHeroMuted: Color(0xFFA6C2B5), heroAccent: AppColors.accentLime,
    chartBar: Color(0xFF3FA882), chartBarMuted: Color(0xFF2A3A31), chartHighlight: AppColors.accentLime, chartGrid: AppColors.darkBorder,
  );

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      success: l(success, other.success), successSoft: l(successSoft, other.successSoft), successFg: l(successFg, other.successFg),
      warning: l(warning, other.warning), warningSoft: l(warningSoft, other.warningSoft), warningFg: l(warningFg, other.warningFg),
      danger: l(danger, other.danger), dangerSoft: l(dangerSoft, other.dangerSoft), dangerFg: l(dangerFg, other.dangerFg),
      info: l(info, other.info), infoSoft: l(infoSoft, other.infoSoft), infoFg: l(infoFg, other.infoFg),
      neutralSoft: l(neutralSoft, other.neutralSoft), neutralFg: l(neutralFg, other.neutralFg),
      heroStart: l(heroStart, other.heroStart), heroEnd: l(heroEnd, other.heroEnd), onHero: l(onHero, other.onHero),
      onHeroMuted: l(onHeroMuted, other.onHeroMuted), heroAccent: l(heroAccent, other.heroAccent),
      chartBar: l(chartBar, other.chartBar), chartBarMuted: l(chartBarMuted, other.chartBarMuted),
      chartHighlight: l(chartHighlight, other.chartHighlight), chartGrid: l(chartGrid, other.chartGrid),
    );
  }
}

extension AppThemeX on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

/// Brand gradients and soft elevation used by hero surfaces.
class AppGradients {
  AppGradients._();
  static const hero = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF1B7A5C), AppColors.primaryDark],
  );
  static const logo = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [AppColors.primaryGreenLight, AppColors.primaryDark],
  );
  static LinearGradient heroOf(BuildContext c) {
    final p = c.palette;
    return LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [p.heroStart, p.heroEnd]);
  }

  static List<BoxShadow> soft(BuildContext context) => AppShadows.soft(context);
}

/// Elevation: used sparingly (hero + floating surfaces). Dark mode relies on surface tone, not shadow.
class AppShadows {
  AppShadows._();
  static List<BoxShadow> soft(BuildContext context) => context.isDark
      ? const []
      : [BoxShadow(color: AppColors.primaryDark.withValues(alpha: 0.06), blurRadius: 24, offset: const Offset(0, 8))];
  static List<BoxShadow> raised(BuildContext context) => context.isDark
      ? const []
      : [
          BoxShadow(color: AppColors.primaryDark.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 1)),
          BoxShadow(color: AppColors.primaryDark.withValues(alpha: 0.08), blurRadius: 32, offset: const Offset(0, 12)),
        ];
}

class AppSpacing {
  AppSpacing._();
  static const double xxs = 2, xs = 4, sm = 8, md = 16, lg = 24, xl = 32, xxl = 48; // 8px grid (+ 2/4 hairlines)
  /// Horizontal page gutter for the current width.
  static double gutter(BuildContext c) => AppBreakpoints.isCompact(c) ? md : lg;
}

class AppRadius {
  AppRadius._();
  static const double control = 12; // inputs, buttons, small tiles
  static const double card = 16; // spec: 14-18
  static const double hero = 24; // large dashboard surfaces
  static const double sheet = 28; // bottom sheets, dialogs
  static const double pill = 999;
}

class AppIconSize {
  AppIconSize._();
  static const double sm = 16, md = 20, lg = 24, xl = 32;
}

class AppSizes {
  AppSizes._();
  static const double minTap = 48; // touch target
  static const double control = 52; // buttons and fields
  static const double avatar = 44;
  static const double maxContentWidth = 960; // forms and lists never stretch beyond this on large screens
}

class AppMotion {
  AppMotion._();
  static const fast = Duration(milliseconds: 120);
  static const base = Duration(milliseconds: 220);
  static const slow = Duration(milliseconds: 420);
  static const curve = Curves.easeOutCubic;
  static const curveEmphasized = Curves.easeInOutCubicEmphasized;
}

class AppBreakpoints {
  AppBreakpoints._();
  static const double compact = 600, medium = 840, expanded = 1200;
  static bool isCompact(BuildContext c) => MediaQuery.sizeOf(c).width < compact;
  static bool isWide(BuildContext c) => MediaQuery.sizeOf(c).width >= medium;
}

/// Semantic status colors shared by chips and badges.
extension StatusColors on ColorScheme {
  Color get success => AppColors.success;
  Color get warning => AppColors.warning;
  Color get danger => AppColors.danger;
}
