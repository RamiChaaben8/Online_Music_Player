// ============================================================
// desktop/shell/desktop_shell.dart
// Main 3-column layout shell for Windows.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/playlist.dart';
import '../../providers/local_music_provider.dart';
import '../../providers/panel_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/sync_provider.dart';
import '../../providers/youtube_provider.dart';
import '../../services/firestore_service.dart';
import '../home/desktop_home_view.dart';
import '../now_playing/desktop_now_playing_panel.dart';
import '../player/desktop_player_bar.dart';
import '../player/lyrics_panel.dart';
import '../player/queue_panel.dart';
import '../playlist/desktop_playlist_view.dart';
import '../sidebar/desktop_sidebar.dart';
import '../theme/desktop_theme.dart';
import '../desktop_search_view.dart';
import 'desktop_title_bar.dart';
import '../../widgets/remote_playback_banner.dart';
import '../../widgets/offline_indicator.dart';

class DesktopShell extends ConsumerStatefulWidget {
  const DesktopShell({super.key});

  @override
  ConsumerState<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends ConsumerState<DesktopShell>
    with WidgetsBindingObserver {
  final List<int> _history = [0];
  int _historyIndex = 0;
  Playlist? _viewedPlaylist;

  int get _currentView => _history[_historyIndex];
  bool get _canGoBack => _historyIndex > 0;
  bool get _canGoForward => _historyIndex < _history.length - 1;

  void _navigateTo(int view, {Playlist? playlist}) {
    if (_currentView == view &&
        (view != 2 || _isSamePlaylist(_viewedPlaylist, playlist))) {
      return;
    }
    setState(() {
      _history.removeRange(_historyIndex + 1, _history.length);
      _history.add(view);
      _historyIndex = _history.length - 1;
      if (view == 2) {
        _viewedPlaylist = playlist;
      }
    });
  }

  /// Returns true if [a] and [b] refer to the same playlist.
  bool _isSamePlaylist(Playlist? a, Playlist? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    final aFsId = a.firestoreId;
    final bFsId = b.firestoreId;
    if (aFsId != null && bFsId != null) return aFsId == bFsId;
    final aKey = a.key;
    final bKey = b.key;
    if (aKey != null && bKey != null) return aKey == bKey;
    return a.name == b.name && a.createdAt == b.createdAt;
  }

  void _goBack() {
    if (!_canGoBack) return;
    setState(() => _historyIndex--);
  }

  void _goForward() {
    if (!_canGoForward) return;
    setState(() => _historyIndex++);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppThemeNotifier.instance.addListener(_onThemeChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(localMusicProvider.notifier).scan();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AppThemeNotifier.instance.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() => setState(() {});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(localMusicProvider.notifier).scan();
    }
    // Saving is enough when Windows hides/minimizes the window. Playback must
    // continue so the desktop app behaves like a background music player.
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      ref.read(playerProvider.notifier).saveSession().catchError((_) {});
    }
    // Release active-device claim when app is fully closed so another
    // device can auto-claim on next launch.
    if (state == AppLifecycleState.detached) {
      ref.read(playerProvider.notifier).saveSession().catchError((_) {});
      ref.read(playerProvider.notifier).pauseLocal();
      ref
          .read(syncProvider.notifier)
          .service
          .releaseIfActive()
          .catchError((_) {});
      ref
          .read(syncProvider.notifier)
          .service
          .unregisterCurrentDevice()
          .catchError((_) {});
    }
  }

  Future<void> _showAccountMenu() async {
    final user = ref.read(authServiceProvider).currentUser;
    final action = await showDialog<_AccountAction>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: kPanelLight,
        title: const Text(
          'Account',
          style: TextStyle(color: kTextPrimary, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_outline, color: kAccent),
              title: const Text('Profile',
                  style: TextStyle(color: kTextPrimary)),
              subtitle: Text(user?.email ?? 'Signed-in account',
                  style: const TextStyle(color: kTextSecondary)),
              onTap: () =>
                  Navigator.pop(dialogContext, _AccountAction.profile),
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined, color: kTextPrimary),
              title: const Text('Settings',
                  style: TextStyle(color: kTextPrimary)),
              onTap: () =>
                  Navigator.pop(dialogContext, _AccountAction.settings),
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('Sign out',
                  style: TextStyle(color: Colors.redAccent)),
              onTap: () =>
                  Navigator.pop(dialogContext, _AccountAction.signOut),
            ),
          ],
        ),
      ),
    );

    if (!mounted || action == null) return;
    if (action == _AccountAction.signOut) {
      await ref.read(playerProvider.notifier).pause().catchError((_) {});
      await ref.read(authServiceProvider).signOut();
    } else if (action == _AccountAction.profile) {
      _showInfoDialog(
          'Profile', user?.email ?? 'No profile details available.');
    } else {
      _showInfoDialog('Settings', 'Settings are coming soon.');
    }
  }

  void _showInfoDialog(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kPanelLight,
        title: Text(title, style: const TextStyle(color: kTextPrimary)),
        content: Text(message, style: const TextStyle(color: kTextSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: kAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final panelMode = ref.watch(panelModeProvider);

    return Scaffold(
      backgroundColor: AppThemeNotifier.instance.value.bgColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wideEnough = constraints.maxWidth >= 1100;

          // Full-screen lyrics overlay sits on top of the entire shell
          // (above the player bar too) when PanelMode.lyrics is active.
          final shell = Column(
            children: [
              // ── Title bar ───────────────────────────────────────
              DesktopTitleBar(
                currentView: _currentView,
                canGoBack: _canGoBack,
                canGoForward: _canGoForward,
                onBack: _goBack,
                onForward: _goForward,
                onHome: () => _navigateTo(0),
                onSearchTap: () => _navigateTo(1),
                onSearch: (q) {
                  ref.read(searchProvider.notifier).search(q);
                },
                // Called when user presses Enter or taps a recent search —
                // the provider search is already fired inside the title bar,
                // so we only need to navigate here.
                onNavigateToSearch: (q) => _navigateTo(1),
                onProfileTap: _showAccountMenu,
              ),

              // ── Main content row ──────────────────────────────────
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DesktopSidebar(
                      selectedPlaylist:
                          _currentView == 2 ? _viewedPlaylist : null,
                      onPlaylistSelected: (p) {
                        if (p != null) {
                          _navigateTo(2, playlist: p);
                        } else {
                          _navigateTo(0);
                        }

                      },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRect(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: _buildCenterView(),
                        ),
                      ),
                    ),
                    // Right panel — always NowPlaying or Queue.
                    // LyricsPanel is a separate fullscreen overlay (below).
                    if (wideEnough) ...[
                      const SizedBox(width: 8),
                      if (panelMode == PanelMode.queue)
                        QueuePanel(
                          key: const ValueKey('queue'),
                          onClose: () => ref
                              .read(panelModeProvider.notifier)
                              .state = PanelMode.none,
                        )
                      else
                        const DesktopNowPlayingPanel(
                            key: ValueKey('nowplaying')),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // ── Offline indicator ─────────────────────────────────
              const OfflineIndicator(),

              // ── Player bar ────────────────────────────────────────
              const DesktopPlayerBar(),
            ],
          );

          // Always wrap in a Stack so the shell (and its VideoPreviewWidget)
          // is never disposed when the lyrics overlay opens/closes.
          // Using Offstage keeps the LyricsPanel in the tree but invisible
          // when not active, which also prevents it from re-fetching lyrics
          // on every open. We flip to visible only when lyrics mode is on.
          return Stack(
            children: [
              shell,
              // Cross-device banner (top of shell, below title bar)
              const Positioned(
                top: 40, // below title bar
                left: 0,
                right: 0,
                child: RemotePlaybackBanner(),
              ),
              if (panelMode == PanelMode.lyrics)
                LyricsPanel(
                  key: const ValueKey('lyrics_overlay'),
                  onClose: () => ref.read(panelModeProvider.notifier).state =
                      PanelMode.none,
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCenterView() {
    switch (_currentView) {
      case 1:
        return const DesktopSearchView(key: ValueKey('search'));
      case 2:
        final p = _viewedPlaylist;
        if (p != null) {
          return DesktopPlaylistView(
            key: ValueKey('playlist_${p.firestoreId ?? p.key ?? p.name}'),
            playlist: p,
          );
        }

        return const DesktopHomeView(key: ValueKey('home'));
      default:
        return const DesktopHomeView(key: ValueKey('home'));
    }

  }
}

enum _AccountAction { profile, settings, signOut }
