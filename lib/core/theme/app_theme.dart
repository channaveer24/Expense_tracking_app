import 'package:flutter/material.dart';

/// Design tokens: calm dark-first fintech look with a vivid violet primary
/// and mint accent; light theme mirrors it. 8-pt spacing, 20-px card radius,
/// tabular figures for money so columns of numbers line up.
class AppColors {
  static const primary = Color(0xFF7C6CF6);
  static const mint = Color(0xFF2ED3A3);
  static const danger = Color(0xFFEF5D6B);

  static const darkBg = Color(0xFF0D0F14);
  static const darkSurface = Color(0xFF161922);
  static const darkSurfaceHigh = Color(0xFF1F2330);
  static const darkOutline = Color(0xFF2A2F3D);

  static const lightBg = Color(0xFFF5F6FA);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceHigh = Color(0xFFEEF0F6);
  static const lightOutline = Color(0xFFE1E4EC);
}

class AppTheme {
  static const radius = 20.0;

  static ThemeData dark() => _build(Brightness.dark);
  static ThemeData light() => _build(Brightness.light);

  static ThemeData _build(Brightness b) {
    final dark = b == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: b,
    ).copyWith(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.mint,
      error: AppColors.danger,
      surface: dark ? AppColors.darkSurface : AppColors.lightSurface,
      surfaceContainerHighest: dark ? AppColors.darkSurfaceHigh : AppColors.lightSurfaceHigh,
      surfaceContainerHigh: dark ? AppColors.darkSurfaceHigh : AppColors.lightSurfaceHigh,
      surfaceContainer: dark ? AppColors.darkSurface : AppColors.lightSurface,
      outlineVariant: dark ? AppColors.darkOutline : AppColors.lightOutline,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: b);
    final text = base.textTheme.apply(
      bodyColor: dark ? const Color(0xFFE8EAF2) : const Color(0xFF151824),
      displayColor: dark ? Colors.white : const Color(0xFF0E1020),
    );

    return base.copyWith(
      scaffoldBackgroundColor: dark ? AppColors.darkBg : AppColors.lightBg,
      textTheme: text.copyWith(
        headlineLarge: text.headlineLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
        headlineMedium: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: dark ? 0.6 : 1)),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: scheme.outlineVariant),
        showCheckmark: false,
        labelStyle: text.labelLarge,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: dark ? AppColors.darkSurface : AppColors.lightSurface,
        indicatorColor: AppColors.primary.withValues(alpha: 0.18),
        surfaceTintColor: Colors.transparent,
        height: 68,
        labelTextStyle: WidgetStatePropertyAll(text.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: dark ? AppColors.darkSurface : AppColors.lightSurface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1, thickness: 1),
    );
  }
}

/// Money text with tabular figures.
const tabular = [FontFeature.tabularFigures()];
