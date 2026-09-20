// ============================================================
// desktop/theme/app_theme.dart
//
// Two built-in themes:
//   • Green  — current Spotify-green dark theme
//   • Red    — crimson/dark-red theme (Spotify-red inspired)
//
// Usage:
//   AppTheme.of(context).accent          // current accent colour
//   AppThemeNotifier.instance.toggle()   // switch theme
// ============================================================

import 'package:flutter/material.dart';

// ─── Theme data model ─────────────────────────────────────────────────────────

class AppThemeData {
  final String name;
  final Color accent;
  final Color bgColor;
  final Color panelColor;
  final Color panelLight;
  final Color cardColor;
  final Color borderColor;
  final Color textPrimary;
  final Color textSecondary;

  const AppThemeData({
    required this.name,
    required this.accent,
    required this.bgColor,
    required this.panelColor,
    required this.panelLight,
    required this.cardColor,
    required this.borderColor,
    required this.textPrimary,
    required this.textSecondary,
  });

  // ── Green theme (default) ─────────────────────────────────────────────────
  static const green = AppThemeData(
    name: 'Green',
    accent:       Color(0xFF1DB954),
    bgColor:      Color(0xFF0F0F0F),
    panelColor:   Color(0xFF121212),
    panelLight:   Color(0xFF181818),
    cardColor:    Color(0xFF282828),
    borderColor:  Color(0xFF333333),
    textPrimary:  Color(0xFFFFFFFF),
    textSecondary:Color(0xFFB3B3B3),
  );

  // ── Red theme (Spotify-red inspired) ──────────────────────────────────────
  static const red = AppThemeData(
    name: 'Red',
    accent:       Color(0xFFE8173A),  // bright crimson
    bgColor:      Color(0xFF0D0808),  // very dark warm black
    panelColor:   Color(0xFF130A0A),  // dark warm panel
    panelLight:   Color(0xFF1A0E0E),  // slightly lighter warm panel
    cardColor:    Color(0xFF2A1515),  // warm dark card
    borderColor:  Color(0xFF3D2020),  // warm border
    textPrimary:  Color(0xFFFFFFFF),
    textSecondary:Color(0xFFB3A3A3),  // slightly warm grey
  );

  static const List<AppThemeData> all = [green, red];
}

// ─── Global notifier ──────────────────────────────────────────────────────────

class AppThemeNotifier extends ValueNotifier<AppThemeData> {
  AppThemeNotifier._() : super(AppThemeData.green);

  static final instance = AppThemeNotifier._();

  void toggle() {
    value = value.name == 'Green' ? AppThemeData.red : AppThemeData.green;
  }

  void setTheme(AppThemeData theme) {
    value = theme;
  }
}

// ─── InheritedWidget for context access ──────────────────────────────────────

class AppThemeScope extends InheritedWidget {
  final AppThemeData theme;

  const AppThemeScope({
    super.key,
    required this.theme,
    required super.child,
  });

  static AppThemeData of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppThemeScope>();
    return scope?.theme ?? AppThemeData.green;
  }

  @override
  bool updateShouldNotify(AppThemeScope old) => theme != old.theme;
}

// ─── Root wrapper that rebuilds the whole tree on theme change ───────────────

class AppThemeBuilder extends StatefulWidget {
  final Widget Function(BuildContext context, AppThemeData theme) builder;

  const AppThemeBuilder({super.key, required this.builder});

  @override
  State<AppThemeBuilder> createState() => _AppThemeBuilderState();
}

class _AppThemeBuilderState extends State<AppThemeBuilder> {
  @override
  void initState() {
    super.initState();
    AppThemeNotifier.instance.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    AppThemeNotifier.instance.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeNotifier.instance.value;
    return AppThemeScope(
      theme: theme,
      child: widget.builder(context, theme),
    );
  }
}
