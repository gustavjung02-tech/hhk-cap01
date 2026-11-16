import 'package:material_ui/material_ui.dart';

class HhkTheme {
  static const orange = Color(0xFFFF7900);
  static const teal = Color(0xFF006B6C);
  static const lavender = Color(0xFF7862E8);
  static const ink = Color(0xFF26243D);
  static const background = Color(0xFFF7F6FF);
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: lavender, primary: lavender,
      secondary: orange, surface: background);
    return ThemeData(
      useMaterial3: true, colorScheme: scheme,
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        centerTitle: true, elevation: 0,
        backgroundColor: background, foregroundColor: ink),
      cardTheme: CardThemeData(
        elevation: 0, color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22))),
      chipTheme: ChipThemeData(
        selectedColor: const Color(0xFFEDE9FF),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16))),
    );
  }
}
