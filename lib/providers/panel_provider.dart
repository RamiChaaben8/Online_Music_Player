// ============================================================
// providers/panel_provider.dart
//
// Shared state for the right-side panel shown in the desktop
// shell. Controlled by the player bar buttons and read by the
// shell to decide which panel to render.
// ============================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';

enum PanelMode { none, lyrics, queue }

final panelModeProvider = StateProvider<PanelMode>((ref) => PanelMode.none);
