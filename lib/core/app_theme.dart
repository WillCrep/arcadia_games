import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color bg = Color(0xFF07090E);
  static const Color panel = Color(0xFF0E121D);
  static const Color panelHover = Color(0xFF161C2D);
  static const Color accent = Color(0xFF8B5CF6);
  static const Color cyan = Color(0xFF06B6D4);
  static const Color lime = Color(0xFF10B981);
  static const Color danger = Color(0xFFF43F5E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color text = Color(0xFFF3F4F6);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color border = Color(0x14FFFFFF);
  static const Color borderAccent = Color(0x598B5CF6); 

  static ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: bg,
      primaryColor: accent,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: cyan,
        surface: panel,
        error: danger,
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(
        ThemeData.dark().textTheme.apply(bodyColor: text, displayColor: text),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.spaceGrotesk(
          color: text,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: border),
        ),
      ),
    );
  }
}