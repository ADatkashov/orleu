import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;

import 'tokens.dart';

class AppTheme {
  AppTheme._();
  static const fontFamily = 'Inter';

  static ThemeData light() => _build(
    const ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primaryGreen,
      onPrimary: Colors.white,
      primaryContainer: AppColors.secondaryGreen,
      onPrimaryContainer: AppColors.primaryDark,
      secondary: AppColors.primaryDark,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.accentLime,
      onSecondaryContainer: AppColors.primaryDark,
      tertiary: AppColors.info,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.borderStrong,
      outlineVariant: AppColors.border,
      error: AppColors.danger,
      onError: Colors.white,
      surfaceContainerLowest: AppColors.background,
      surfaceContainerLow: AppColors.surfaceMuted,
      surfaceContainer: AppColors.surfaceMuted,
      surfaceContainerHigh: AppColors.surfaceStrong,
      surfaceContainerHighest: AppColors.surfaceStrong,
      shadow: AppColors.primaryDark,
    ),
    AppColors.background,
    AppPalette.light,
  );

  static ThemeData dark() => _build(
    const ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.darkPrimary,
      onPrimary: AppColors.primaryDark,
      primaryContainer: Color(0xFF243A2F),
      onPrimaryContainer: AppColors.darkText,
      secondary: AppColors.accentLime,
      onSecondary: AppColors.primaryDark,
      secondaryContainer: AppColors.primaryGreen,
      onSecondaryContainer: AppColors.darkText,
      tertiary: Color(0xFF7BA7F5),
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkText,
      onSurfaceVariant: AppColors.darkTextSecondary,
      outline: Color(0xFF3A4D42),
      outlineVariant: AppColors.darkBorder,
      error: Color(0xFFF08080),
      onError: AppColors.primaryDark,
      surfaceContainerLowest: AppColors.darkBackground,
      surfaceContainerLow: AppColors.darkSurfaceMuted,
      surfaceContainer: AppColors.darkSurfaceMuted,
      surfaceContainerHigh: AppColors.darkSurfaceStrong,
      surfaceContainerHighest: AppColors.darkSurfaceStrong,
      shadow: Colors.black,
    ),
    AppColors.darkBackground,
    AppPalette.dark,
  );

  /// Typography scale. Sizes in logical px; Inter ships with Latin, Cyrillic and Kazakh letters.
  static TextTheme _textTheme(ColorScheme s) {
    TextStyle t(double size, FontWeight w, {double ls = 0, double h = 1.3, Color? c}) =>
        TextStyle(fontFamily: fontFamily, fontSize: size, fontWeight: w, letterSpacing: ls, height: h, color: c ?? s.onSurface);
    return TextTheme(
      displaySmall: t(34, FontWeight.w800, ls: -1.0, h: 1.15),
      headlineLarge: t(30, FontWeight.w800, ls: -0.8, h: 1.2),
      headlineMedium: t(26, FontWeight.w800, ls: -0.6, h: 1.2),
      headlineSmall: t(22, FontWeight.w700, ls: -0.4, h: 1.25),
      titleLarge: t(19, FontWeight.w700, ls: -0.3, h: 1.3),
      titleMedium: t(16, FontWeight.w600, ls: -0.1, h: 1.35),
      titleSmall: t(14, FontWeight.w600, h: 1.35),
      bodyLarge: t(16, FontWeight.w400, h: 1.45),
      bodyMedium: t(14, FontWeight.w400, h: 1.45),
      bodySmall: t(12.5, FontWeight.w400, h: 1.4, c: s.onSurfaceVariant),
      labelLarge: t(14, FontWeight.w600, ls: 0.1, h: 1.25),
      labelMedium: t(12, FontWeight.w600, ls: 0.1, h: 1.25),
      labelSmall: t(11, FontWeight.w600, ls: 0.3, h: 1.2, c: s.onSurfaceVariant),
    );
  }

  static ThemeData _build(ColorScheme s, Color background, AppPalette palette) {
    final dark = s.brightness == Brightness.dark;
    final text = _textTheme(s);
    RoundedRectangleBorder shape(double r) => RoundedRectangleBorder(borderRadius: BorderRadius.circular(r));
    OutlineInputBorder field(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.control + 2),
      borderSide: BorderSide(color: c, width: w),
    );
    final base = ThemeData(useMaterial3: true, colorScheme: s, scaffoldBackgroundColor: background, fontFamily: fontFamily);
    return base.copyWith(
      extensions: [palette],
      textTheme: text,
      primaryTextTheme: text,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: s.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleSpacing: AppSpacing.md,
        titleTextStyle: text.titleLarge,
        toolbarHeight: 64,
        iconTheme: IconThemeData(color: s.onSurface, size: AppIconSize.lg),
      ),
      cardTheme: CardThemeData(
        color: s.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: s.outlineVariant),
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 2),
        minVerticalPadding: AppSpacing.sm + 2,
        iconColor: s.onSurfaceVariant,
        titleTextStyle: text.titleSmall?.copyWith(fontSize: 15),
        subtitleTextStyle: text.bodySmall,
        shape: shape(AppRadius.card),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: s.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 15),
        hintStyle: text.bodyMedium?.copyWith(color: dark ? AppColors.darkTextSecondary : AppColors.textSecondary),
        labelStyle: text.bodyMedium?.copyWith(color: s.onSurfaceVariant),
        floatingLabelStyle: text.labelMedium?.copyWith(color: s.primary),
        helperStyle: text.bodySmall,
        errorStyle: text.bodySmall?.copyWith(color: s.error),
        prefixIconColor: s.onSurfaceVariant,
        suffixIconColor: s.onSurfaceVariant,
        border: field(s.outlineVariant),
        enabledBorder: field(s.outlineVariant),
        focusedBorder: field(s.primary, 2),
        errorBorder: field(s.error),
        focusedErrorBorder: field(s.error, 2),
        disabledBorder: field(s.outlineVariant.withValues(alpha: 0.5)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSizes.control),
          textStyle: text.labelLarge?.copyWith(fontSize: 15),
          shape: shape(AppRadius.control + 2),
          elevation: 0,
          backgroundColor: s.primary,
          foregroundColor: s.onPrimary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSizes.control),
          textStyle: text.labelLarge?.copyWith(fontSize: 15),
          shape: shape(AppRadius.control + 2),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(AppSizes.minTap, AppSizes.control),
          textStyle: text.labelLarge?.copyWith(fontSize: 15),
          shape: shape(AppRadius.control + 2),
          side: BorderSide(color: s.outline),
          foregroundColor: s.onSurface,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(AppSizes.minTap, AppSizes.minTap),
          textStyle: text.labelLarge,
          shape: shape(AppRadius.control),
          foregroundColor: s.primary,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(AppSizes.minTap, AppSizes.minTap), shape: const CircleBorder()),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: dark ? AppColors.accentLime : AppColors.primaryDark,
        foregroundColor: dark ? AppColors.primaryDark : AppColors.accentLime,
        elevation: 2,
        highlightElevation: 4,
        shape: shape(AppRadius.card + 2),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(shape(AppRadius.control + 2)),
          side: WidgetStatePropertyAll(BorderSide(color: s.outlineVariant)),
          textStyle: WidgetStatePropertyAll(text.labelLarge),
          backgroundColor: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.selected) ? (dark ? s.primary : AppColors.primaryDark) : s.surface),
          foregroundColor: WidgetStateProperty.resolveWith(
            (st) => st.contains(WidgetState.selected) ? (dark ? s.onPrimary : AppColors.accentLime) : s.onSurfaceVariant,
          ),
          iconColor: WidgetStateProperty.resolveWith(
            (st) => st.contains(WidgetState.selected) ? (dark ? s.onPrimary : AppColors.accentLime) : s.onSurfaceVariant,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: s.surface,
        selectedColor: dark ? s.primaryContainer : AppColors.primaryDark,
        side: BorderSide(color: s.outlineVariant),
        shape: const StadiumBorder(),
        labelStyle: text.labelLarge,
        secondaryLabelStyle: text.labelLarge,
        checkmarkColor: dark ? s.primary : AppColors.accentLime,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xs),
        showCheckmark: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: s.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
        indicatorColor: dark ? s.primaryContainer : AppColors.primaryDark,
        indicatorShape: const StadiumBorder(),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (st) =>
              IconThemeData(size: AppIconSize.lg, color: st.contains(WidgetState.selected) ? (dark ? s.primary : AppColors.accentLime) : s.onSurfaceVariant),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (st) => text.labelMedium?.copyWith(
            color: st.contains(WidgetState.selected) ? s.onSurface : s.onSurfaceVariant,
            fontWeight: st.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: s.surface,
        indicatorColor: dark ? s.primaryContainer : AppColors.primaryDark,
        indicatorShape: shape(AppRadius.card),
        selectedIconTheme: IconThemeData(color: dark ? s.primary : AppColors.accentLime),
        unselectedIconTheme: IconThemeData(color: s.onSurfaceVariant),
        selectedLabelTextStyle: text.labelMedium?.copyWith(fontWeight: FontWeight.w700),
        unselectedLabelTextStyle: text.labelMedium?.copyWith(color: s.onSurfaceVariant, fontWeight: FontWeight.w500),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: s.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sheet - 4),
          side: BorderSide(color: s.outlineVariant),
        ),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium?.copyWith(color: s.onSurfaceVariant),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: s.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        modalElevation: 0,
        dragHandleColor: s.outline,
        dragHandleSize: const Size(40, 4),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet))),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? AppColors.darkSurfaceStrong : AppColors.primaryDark,
        contentTextStyle: text.bodyMedium?.copyWith(color: AppColors.darkText),
        actionTextColor: AppColors.accentLime,
        shape: shape(AppRadius.control + 2),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: s.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shape: shape(AppRadius.card),
        textStyle: text.bodyMedium,
      ),
      tabBarTheme: TabBarThemeData(
        labelStyle: text.labelLarge,
        unselectedLabelStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w500),
        labelColor: s.onSurface,
        unselectedLabelColor: s.onSurfaceVariant,
        dividerColor: s.outlineVariant,
        indicatorColor: s.primary,
        indicatorSize: TabBarIndicatorSize.label,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.selected) ? (dark ? AppColors.primaryDark : Colors.white) : s.outline),
        trackColor: WidgetStateProperty.resolveWith((st) => st.contains(WidgetState.selected) ? s.primary : s.surfaceContainerHigh),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: shape(6),
        side: BorderSide(color: s.outline, width: 1.5),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: s.primary, linearTrackColor: s.surfaceContainerHigh, circularTrackColor: Colors.transparent),
      dividerTheme: DividerThemeData(color: s.outlineVariant, space: 1, thickness: 1),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: dark ? AppColors.darkSurfaceStrong : AppColors.primaryDark, borderRadius: BorderRadius.circular(8)),
        textStyle: text.labelMedium?.copyWith(color: AppColors.darkText),
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: AppColors.accentLime,
        textColor: AppColors.primaryDark,
        textStyle: text.labelSmall?.copyWith(color: AppColors.primaryDark, fontWeight: FontWeight.w800),
      ),
    );
  }
}
