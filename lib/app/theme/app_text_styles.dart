import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shared text styles — always without underline (Google Fonts safe).
abstract final class AppTextStyles {
  static TextStyle exo2({
    double? size,
    FontWeight? weight,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.exo2(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      decoration: TextDecoration.none,
      decorationColor: Colors.transparent,
    );
  }

  static TextStyle orbitron({
    double? size,
    FontWeight? weight,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.orbitron(
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      decoration: TextDecoration.none,
      decorationColor: Colors.transparent,
    );
  }
}
