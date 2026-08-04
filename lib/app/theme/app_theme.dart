import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mirror_logic/app/theme/medieval_colors.dart';
import 'package:mirror_logic/app/theme/medieval_text_styles.dart';

abstract final class AppTheme {
  /// Material defaults dressed in bronze.
  ///
  /// The screens draw their own surfaces, so this exists for the widgets that
  /// insist on theming themselves — sliders, switches, dialogs, snackbars,
  /// text selection — which would otherwise show up in stock Material blue.
  static ThemeData get dark {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: MedievalColors.woodDeep,
      colorScheme: ColorScheme.dark(
        primary: MedievalColors.bronzeLight,
        onPrimary: MedievalColors.woodDeep,
        secondary: MedievalColors.laserMid,
        onSecondary: MedievalColors.woodDeep,
        surface: MedievalColors.woodMid,
        onSurface: MedievalColors.textCream,
        error: MedievalColors.rejectMid,
      ),
    );

    final textTheme = GoogleFonts.cinzelTextTheme(base.textTheme).apply(
      bodyColor: MedievalColors.textCream,
      displayColor: MedievalColors.textGold,
      decoration: TextDecoration.none,
      decorationColor: Colors.transparent,
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: MedievalTextStyles.cinzel(
          size: 18,
          weight: FontWeight.w700,
          letterSpacing: 2,
          color: MedievalColors.textGold,
        ),
        iconTheme: IconThemeData(color: MedievalColors.textGold),
      ),
      iconTheme: IconThemeData(color: MedievalColors.textGold),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: MedievalTextStyles.cinzel(weight: FontWeight.w700),
          foregroundColor: MedievalColors.bronzeLight,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: MedievalColors.bronzeLight,
        inactiveTrackColor: MedievalColors.woodDeep,
        thumbColor: MedievalColors.bronzeHighlight,
        overlayColor: MedievalColors.bronzeLight.withValues(alpha: 0.18),
        valueIndicatorColor: MedievalColors.bronzeDark,
        trackHeight: 5,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? MedievalColors.bronzeHighlight
              : MedievalColors.textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? MedievalColors.bronze
              : MedievalColors.woodDeep;
        }),
        trackOutlineColor: WidgetStateProperty.all(MedievalColors.bronzeDark),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: MedievalColors.bronzeLight,
        linearTrackColor: MedievalColors.woodDeep,
        circularTrackColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: MedievalColors.woodPlank,
        contentTextStyle: MedievalTextStyles.cinzel(size: 13),
        actionTextColor: MedievalColors.bronzeHighlight,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: MedievalColors.bronze, width: 1.5),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: MedievalColors.woodMid,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: MedievalTextStyles.cinzel(
          size: 17,
          weight: FontWeight.w700,
          letterSpacing: 1.2,
          color: MedievalColors.textGold,
        ),
        contentTextStyle: MedievalTextStyles.cinzel(size: 13, height: 1.35),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: MedievalColors.bronzeLight, width: 2),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      dividerTheme: DividerThemeData(
        color: MedievalColors.bronze.withValues(alpha: 0.4),
        thickness: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: MedievalColors.textGold,
        textColor: MedievalColors.textCream,
        titleTextStyle: MedievalTextStyles.cinzel(size: 14),
        subtitleTextStyle: MedievalTextStyles.cinzel(
          size: 11,
          color: MedievalColors.textMuted,
        ),
      ),
    );
  }
}
