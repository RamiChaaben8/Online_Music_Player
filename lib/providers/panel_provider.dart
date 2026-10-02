// ============================================================
// providers/panel_provider.dart
//
// Shared state for the right-side panel shown in the desktop
// shell. Controlled by the title-bar friends button, the player bar
// buttons and read by the shell to decide which panel to render.
//
// Only one right-hand panel is ever visible, so these are mutually
// exclusive: opening one replaces the others.
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

enum PanelMode { none, lyrics, queue, friends }

final panelModeProvider = StateProvider<PanelMode>((ref) => PanelMode.none);
