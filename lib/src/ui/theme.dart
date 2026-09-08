import 'package:flutter/material.dart';

/// Palette of the organizer. Dark by design: the tool sits next to a fullscreen
/// game client and must not flash white when it comes back from the tray.
abstract final class AppColors {
  static const Color background = Color(0xFF0E1014);
  static const Color surface = Color(0xFF16191F);
  static const Color surfaceHigh = Color(0xFF1D212A);
  static const Color outline = Color(0xFF272C36);
  static const Color accent = Color(0xFFD9A441);
  static const Color accentSoft = Color(0x33D9A441);
  static const Color live = Color(0xFF4ADE80);
  static const Color danger = Color(0xFFF87171);
  static const Color textPrimary = Color(0xFFE6E9EF);
  static const Color textSecondary = Color(0xFF8B93A3);
  static const Color textDisabled = Color(0xFF5A6272);
}

ThemeData buildAppTheme() {
  const colorScheme = ColorScheme.dark(
    primary: AppColors.accent,
    onPrimary: Color(0xFF17140C),
    secondary: AppColors.live,
    onSecondary: Color(0xFF0B1A11),
    error: AppColors.danger,
    onError: Color(0xFF2A0E0E),
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    surfaceContainerHighest: AppColors.surfaceHigh,
    outline: AppColors.outline,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: 'Segoe UI',
    visualDensity: VisualDensity.compact,
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.outline,
      space: 1,
      thickness: 1,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.background,
      isDense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.accent),
      ),
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      hintStyle: const TextStyle(color: AppColors.textDisabled),
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: AppColors.surfaceHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        border: Border.all(color: AppColors.outline),
        borderRadius: BorderRadius.circular(6),
      ),
      textStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
      waitDuration: const Duration(milliseconds: 500),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.surfaceHigh,
      contentTextStyle: TextStyle(color: AppColors.textPrimary),
      behavior: SnackBarBehavior.floating,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.selected)
            ? AppColors.live
            : AppColors.textDisabled;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.selected)
            ? AppColors.live.withValues(alpha: 0.25)
            : AppColors.surfaceHigh;
      }),
      trackOutlineColor:
          const WidgetStatePropertyAll<Color>(AppColors.outline),
    ),
  );
}
