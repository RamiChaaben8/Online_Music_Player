// ============================================================
// desktop/desktop_app.dart
// Root widget for Windows — wraps DesktopShell in MaterialApp.
// ============================================================

import 'package:flutter/material.dart';

import 'shell/desktop_shell.dart';
import 'theme/desktop_theme.dart';

class DesktopApp extends StatelessWidget {
  const DesktopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AppThemeBuilder(
      builder: (context, theme) => MaterialApp(
        title: 'Tuneify',
        debugShowCheckedModeBanner: false,
        theme: _buildDesktopTheme(theme),
        home: const DesktopShell(),
      ),
    );
  }

  ThemeData _buildDesktopTheme(AppThemeData t) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: t.bgColor,
      colorScheme: ColorScheme.dark(
        primary: t.accent,
        secondary: t.accent,
        surface: t.panelColor,
        onSurface: t.textPrimary,
        onPrimary: Colors.black,
      ),
      cardColor: t.cardColor,
      dividerColor: t.borderColor,
      textTheme: TextTheme(
        displayLarge:  TextStyle(color: t.textPrimary, fontWeight: FontWeight.bold),
        displayMedium: TextStyle(color: t.textPrimary, fontWeight: FontWeight.bold),
        headlineLarge: TextStyle(color: t.textPrimary, fontWeight: FontWeight.bold),
        headlineMedium:TextStyle(color: t.textPrimary, fontWeight: FontWeight.w700),
        titleLarge:    TextStyle(color: t.textPrimary, fontWeight: FontWeight.w600),
        titleMedium:   TextStyle(color: t.textPrimary, fontWeight: FontWeight.w500),
        bodyLarge:     TextStyle(color: t.textPrimary),
        bodyMedium:    TextStyle(color: t.textSecondary),
        labelLarge:    TextStyle(color: t.textPrimary, fontWeight: FontWeight.w600),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.cardColor,
        hintStyle: TextStyle(color: t.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      iconTheme: IconThemeData(color: t.textPrimary),
      progressIndicatorTheme:
          ProgressIndicatorThemeData(color: t.accent),
      sliderTheme: SliderThemeData(
        activeTrackColor:   t.accent,
        inactiveTrackColor: t.borderColor,
        thumbColor:         Colors.white,
        overlayColor:       t.accent.withValues(alpha: 0.2),
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(t.borderColor),
        thickness:  WidgetStateProperty.all(4),
        radius: const Radius.circular(2),
      ),
    );
  }
}
