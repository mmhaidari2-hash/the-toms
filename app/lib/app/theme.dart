import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// "Postbox & Paper" design system — London palette, editorial serif + clean sans.
class BL {
  static const navy = Color(0xFF1B2A4A);
  static const ink = Color(0xFF14203A);
  static const red = Color(0xFFC8102E);
  static const green = Color(0xFF1F5E45);
  static const gold = Color(0xFFE9B949);
  static const cream = Color(0xFFFBF7F0);
  static const paper = Color(0xFFFFFFFF);
  static const mist = Color(0xFFEEE8DD);
  static const muted = Color(0xFF6B7385);
  static const radius = 22.0;
  static bool useGoogleFonts = true;

  static TextStyle display(double size, {Color color = ink, FontWeight w = FontWeight.w600}) =>
      useGoogleFonts ? GoogleFonts.fraunces(fontSize: size, color: color, fontWeight: w, height: 1.1, letterSpacing: -0.3) : TextStyle(fontSize: size, color: color, fontWeight: w, height: 1.1);
  static TextStyle fa(double size, {Color color = muted, FontWeight w = FontWeight.w400}) =>
      useGoogleFonts ? GoogleFonts.vazirmatn(fontSize: size, color: color, fontWeight: w, height: 1.6) : TextStyle(fontSize: size, color: color, fontWeight: w, height: 1.6);

  static List<BoxShadow> shadow([double o = .07]) => [
    BoxShadow(
      color: navy.withValues(alpha: o),
      blurRadius: 24,
      offset: const Offset(0, 10),
    ),
    BoxShadow(
      color: navy.withValues(alpha: o * .6),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];

  static ThemeData theme() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: navy, primary: navy, secondary: red, surface: cream),
      scaffoldBackgroundColor: cream,
      splashFactory: InkSparkle.splashFactory,
    );
    final family = useGoogleFonts ? GoogleFonts.inter().fontFamily : null;
    return base.copyWith(
      textTheme: base.textTheme.apply(bodyColor: ink, displayColor: ink, fontFamily: family),
    );
  }
}
