import 'package:flutter/material.dart';
class HhkTheme {
  static const orange = Color(0xFFFF7900);
  static const teal = Color(0xFF006B6C);
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(seedColor: orange,
        primary: orange, secondary: teal,
        surface: const Color(0xFFFFFBF5));
    return ThemeData(useMaterial3: true, colorScheme: scheme,
        scaffoldBackgroundColor: const Color(0xFFFFFBF5),
        appBarTheme: const AppBarTheme(centerTitle: false,
          backgroundColor: Color(0xFFFFFBF5), foregroundColor: teal),
        cardTheme: CardThemeData(elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))));
  }
}
