import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mirror_logic/app/theme/medieval_colors.dart';

abstract final class MedievalTextStyles {
  static TextStyle cinzel({
    double? size,
    FontWeight? weight,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.cinzel(
      fontSize: size,
      fontWeight: weight ?? FontWeight.w600,
      color: color ?? MedievalColors.textCream,
      letterSpacing: letterSpacing,
      height: height,
      decoration: TextDecoration.none,
    );
  }

  static TextStyle cinzelDecorative({
    double? size,
    FontWeight? weight,
    Color? color,
    double? letterSpacing,
  }) {
    return GoogleFonts.cinzelDecorative(
      fontSize: size,
      fontWeight: weight ?? FontWeight.w700,
      color: color ?? MedievalColors.textGold,
      letterSpacing: letterSpacing,
      decoration: TextDecoration.none,
    );
  }

  static TextStyle imFell({
    double? size,
    FontWeight? weight,
    Color? color,
    double? height,
  }) {
    return GoogleFonts.imFellEnglish(
      fontSize: size,
      fontWeight: weight,
      color: color ?? MedievalColors.parchmentInk,
      height: height,
      decoration: TextDecoration.none,
    );
  }
}
