// ============================================================
// desktop/desktop_app.dart
// Root widget for Windows — wraps DesktopShell in MaterialApp.
// Used only on Platform.isWindows; Android uses TuneifyApp/AppShell.
// ============================================================

import 'package:flutter/material.dart';

import 'shell/desktop_shell.dart';
import 'theme/desktop_theme.dart';

class DesktopApp extends StatelessWidget {
  const DesktopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tuneify',
      debugShowCheckedModeBanner: false,
      theme: _buildDesktopTheme(),
      home: const DesktopShell(),
    );
  }

  ThemeData _buildDesktopTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: kBgColor,
      colorScheme: const ColorScheme.dark(
        primary: kAccent,
        secondary: kAccent,
        surface: kPanelColor,
        onSurface: kTextPrimary,
        onPrimary: Colors.black,
      ),
      cardColor: kCardColor,
      dividerColor: kBorderColor,
      textTheme: const TextTheme(
        displayLarge: TextStyle(
            color: kTextPrimary, fontWeight: FontWeight.bold),
        displayMedium: TextStyle(
            color: kTextPrimary, fontWeight: FontWeight.bold),
        headlineLarge: TextStyle(
            color: kTextPrimary, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(
            color: kTextPrimary, fontWeight: FontWeight.w700),
        titleLarge: TextStyle(
            color: kTextPrimary, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(
            color: kTextPrimary, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(color: kTextPrimary),
        bodyMedium: TextStyle(color: kTextSecondary),
        labelLarge: TextStyle(
            color: kTextPrimary, fontWeight: FontWeight.w600),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2A2A2A),
        hintStyle: const TextStyle(color: kTextSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      iconTheme: const IconThemeData(color: kTextPrimary),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: kAccent),
      sliderTheme: SliderThemeData(
        activeTrackColor: kAccent,
        inactiveTrackColor: const Color(0xFF3A3A3A),
        thumbColor: Colors.white,
        overlayColor: kAccent.withOpacity(0.2),
        trackHeight: 3,
        thumbShape:
            const RoundSliderThumbShape(enabledThumbRadius: 6),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(kBorderColor),
        thickness: WidgetStateProperty.all(4),
        radius: const Radius.circular(2),
      ),
    );
  }
}
