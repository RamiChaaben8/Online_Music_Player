// ============================================================
// desktop/shell/desktop_shell.dart
// Main 3-column layout shell for Windows.
// Replaces AppShell on Platform.isWindows.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/playlist.dart';
import '../../providers/local_music_provider.dart';
import '../../providers/youtube_provider.dart';
import '../home/desktop_home_view.dart';
import '../now_playing/desktop_now_playing_panel.dart';
import '../player/desktop_player_bar.dart';
import '../sidebar/desktop_sidebar.dart';
import '../theme/desktop_theme.dart';
import '../desktop_search_view.dart';
import 'desktop_title_bar.dart';

class DesktopShell extends ConsumerStatefulWidget {
  const DesktopShell({super.key});

  @override
  ConsumerState<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends ConsumerState<DesktopShell>
    with WidgetsBindingObserver {
  bool _showNowPlaying = true;
  Playlist? _selectedPlaylist;
  int _currentView = 0; // 0=home, 1=search

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(localMusicProvider.notifier).scan();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(localMusicProvider.notifier).scan();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Collapse the now-playing panel when window is narrow
          final shouldShowNowPlaying =
              _showNowPlaying && constraints.maxWidth >= 1100;

          return Column(
            children: [
              // ── Title bar ───────────────────────────────────────────
              DesktopTitleBar(
                onSearchTap: () => setState(() => _currentView = 1),
                onSearch: (q) {
                  setState(() => _currentView = 1);
                  ref.read(searchProvider.notifier).search(q);
                },
              ),

              // ── Main content row ────────────────────────────────────
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Sidebar
                    DesktopSidebar(
                      selectedPlaylist: _selectedPlaylist,
                      onPlaylistSelected: (p) =>
                          setState(() => _selectedPlaylist = p),
                    ),

                    const SizedBox(width: 8),

                    // Center view
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: _currentView == 1
                            ? const DesktopSearchView(
                                key: ValueKey('search'))
                            : const DesktopHomeView(
                                key: ValueKey('home')),
                      ),
                    ),

                    // Now playing panel (collapses below 1100px)
                    if (shouldShowNowPlaying) ...[
                      const SizedBox(width: 8),
                      const DesktopNowPlayingPanel(),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // ── Player bar ──────────────────────────────────────────
              const DesktopPlayerBar(),
            ],
          );
        },
      ),
    );
  }
}
