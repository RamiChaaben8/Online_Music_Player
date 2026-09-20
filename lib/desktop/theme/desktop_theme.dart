// ============================================================
// desktop/theme/desktop_theme.dart
// Windows-only theme constants — does NOT affect Android theme.
// ============================================================

import 'package:flutter/material.dart';

const kBgColor = Color(0xFF0F0F0F);
const kPanelColor = Color(0xFF121212);
const kPanelLight = Color(0xFF181818);
const kAccent = Color(0xFF1DB954); // Spotify green
const kTextPrimary = Color(0xFFFFFFFF);
const kTextSecondary = Color(0xFFB3B3B3);
const kCardColor = Color(0xFF282828);
const kBorderColor = Color(0xFF333333);

const double kSidebarWidth = 300.0;
const double kNowPlayingWidth = 380.0;
const double kTopBarHeight = 64.0;
const double kPlayerBarHeight = 80.0;

// Pastel accent colors for artist cards (cycle through these)
const List<Color> kPastelColors = [
  Color(0xFF3D3D6B),
  Color(0xFF4A2C2C),
  Color(0xFF2C4A2C),
  Color(0xFF4A3D2C),
  Color(0xFF2C3D4A),
  Color(0xFF4A2C4A),
  Color(0xFF2C4A4A),
];
