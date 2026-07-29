import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mirror_logic/app/theme/app_colors.dart';
import 'package:mirror_logic/app/theme/app_text_styles.dart';

abstract final class AppTheme {
  static ThemeData get dark {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.primaryDark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accentBright,
        secondary: AppColors.cyan,
        surface: AppColors.secondaryDark,
        error: AppColors.laserRed,
        onPrimary: Colors.white,
        onSecondary: AppColors.primaryDark,
        onSurface: AppColors.textPrimary,
      ),
    );

    final textTheme = GoogleFonts.exo2TextTheme(base.textTheme).apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
      decoration: TextDecoration.none,
      decorationColor: Colors.transparent,
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTextStyles.orbitron(
          size: 18,
          weight: FontWeight.w600,
          letterSpacing: 1.2,
          color: AppColors.textPrimary,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: AppTextStyles.exo2(),
          foregroundColor: AppColors.cyan,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.accentBright,
        inactiveTrackColor: AppColors.panel,
        thumbColor: AppColors.accentBright,
        overlayColor: AppColors.accentBright.withValues(alpha: 0.2),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return Colors.white70;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.accentBright;
          }
          return AppColors.panel;
        }),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.panel,
        contentTextStyle: TextStyle(color: AppColors.textPrimary),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.secondaryDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
