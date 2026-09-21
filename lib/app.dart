// ============================================================
// app.dart — Root widget, theme, and navigation scaffold
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'providers/auth_provider.dart';
import 'dart:io';

import 'screens/search_screen.dart';
import 'screens/library_screen.dart';
import 'screens/friends_screen.dart';
import 'screens/home_screen.dart';
import 'widgets/mini_player.dart';
import 'widgets/remote_playback_banner.dart';
import 'widgets/offline_indicator.dart';
import 'widgets/listen_party_controls.dart';
import 'providers/player_provider.dart';
import 'providers/local_music_provider.dart';
import 'providers/sync_provider.dart';
import 'providers/presence_provider.dart';
import 'platform/permissions.dart';
import 'desktop/shell/desktop_shell.dart';
import 'desktop/theme/desktop_theme.dart';
import 'screens/auth/auth_gate.dart';

class TuneifyApp extends StatelessWidget {
  const TuneifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    if (Platform.isWindows) {
      return AppThemeBuilder(
        builder: (context, theme) => MaterialApp(
          title: 'Tuneify',
          debugShowCheckedModeBanner: false,
          theme: _buildDesktopTheme(theme),
          builder: (context, child) => _MediaKeyListener(
            child: child ?? const SizedBox.shrink(),
          ),
          home: AuthGate(child: const DesktopShell()),
        ),
      );
    }
    return MaterialApp(
      title: 'Tuneify',
      debugShowCheckedModeBanner: false,
      theme: _buildDarkTheme(),
      builder: (context, child) => _MediaKeyListener(
        child: child ?? const SizedBox.shrink(),
      ),
      home: AuthGate(
        child: Platform.isWindows ? const DesktopShell() : const AppShell(),
      ),
    );
  }

  ThemeData _buildDesktopTheme(AppThemeData t) {
    return ThemeData(
      useMaterial3: true,
      brightness: t.brightness,
      scaffoldBackgroundColor: t.main,
      colorScheme: ColorScheme(
        brightness: t.brightness,
        primary: t.button,
        onPrimary: t.text,
        secondary: t.buttonActive,
        onSecondary: t.text,
        error: t.notificationError,
        onError: t.text,
        surface: t.main,
        onSurface: t.text,
      ),
      cardColor: t.card,
      dividerColor: t.shadow,
      textTheme: TextTheme(
        displayLarge: TextStyle(color: t.text, fontWeight: FontWeight.bold),
        displayMedium: TextStyle(color: t.text, fontWeight: FontWeight.bold),
        headlineLarge: TextStyle(color: t.text, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(color: t.text, fontWeight: FontWeight.w700),
        titleLarge: TextStyle(color: t.text, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: t.text, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(color: t.text),
        bodyMedium: TextStyle(color: t.subtext),
        labelLarge: TextStyle(color: t.text, fontWeight: FontWeight.w600),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.card,
        hintStyle: TextStyle(color: t.subtext),
        border: const OutlineInputBorder(borderSide: BorderSide.none),
      ),
      iconTheme: IconThemeData(color: t.text),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: t.button),
      sliderTheme: SliderThemeData(
        activeTrackColor: t.button,
        inactiveTrackColor: t.shadow,
        thumbColor: t.text,
        overlayColor: t.button.withValues(alpha: 0.2),
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(t.button),
        thickness: const WidgetStatePropertyAll(4),
        radius: const Radius.circular(2),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    const bgColor = Color(0xFF0A0A0A);
    const surfaceColor = Color(0xFF121212);
    const cardColor = Color(0xFF1A1A1A);
    const accentGreen = Color(0xFF1DB954);
    const onSurface = Color(0xFFFFFFFF);
    const subtext = Color(0xFFB3B3B3);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgColor,
      colorScheme: const ColorScheme.dark(
        primary: accentGreen,
        secondary: accentGreen,
        surface: surfaceColor,
        onSurface: onSurface,
        onPrimary: Colors.black,
      ),
      cardColor: cardColor,
      dividerColor: const Color(0xFF282828),
      textTheme: TextTheme(
        displayLarge:
            const TextStyle(color: onSurface, fontWeight: FontWeight.bold),
        displayMedium:
            const TextStyle(color: onSurface, fontWeight: FontWeight.bold),
        headlineLarge:
            const TextStyle(color: onSurface, fontWeight: FontWeight.bold),
        headlineMedium:
            const TextStyle(color: onSurface, fontWeight: FontWeight.w700),
        titleLarge:
            const TextStyle(color: onSurface, fontWeight: FontWeight.w600),
        titleMedium:
            const TextStyle(color: onSurface, fontWeight: FontWeight.w500),
        bodyLarge: const TextStyle(color: onSurface),
        bodyMedium: const TextStyle(color: subtext),
        labelLarge:
            const TextStyle(color: onSurface, fontWeight: FontWeight.w600),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: onSurface,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF0D0D0D),
        indicatorColor: accentGreen.withOpacity(0.2),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
                color: accentGreen, fontSize: 12, fontWeight: FontWeight.w600);
          }
          return const TextStyle(color: subtext, fontSize: 12);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: accentGreen);
          }
          return const IconThemeData(color: subtext);
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2A2A2A),
        hintStyle: const TextStyle(color: subtext),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      iconTheme: const IconThemeData(color: onSurface),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: accentGreen),
      sliderTheme: SliderThemeData(
        activeTrackColor: accentGreen,
        inactiveTrackColor: const Color(0xFF3A3A3A),
        thumbColor: Colors.white,
        overlayColor: accentGreen.withOpacity(0.2),
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      ),
    );
  }
}

class _MediaKeyListener extends ConsumerStatefulWidget {
  final Widget child;

  const _MediaKeyListener({required this.child});

  @override
  ConsumerState<_MediaKeyListener> createState() => _MediaKeyListenerState();
}

class _MediaKeyListenerState extends ConsumerState<_MediaKeyListener> {
  final FocusNode _focusNode = FocusNode();
  static const _mediaKeyChannel = MethodChannel('com.tuneify/media_keys');

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows) {
      _mediaKeyChannel.setMethodCallHandler(_handleGlobalMediaKey);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  Future<void> _handleGlobalMediaKey(MethodCall call) async {
    if (call.method != 'mediaKey' || call.arguments is! String) return;

    final player = ref.read(playerProvider.notifier);
    switch (call.arguments as String) {
      case 'playPause':
        await player.togglePlayPause();
        break;
      case 'stop':
        await player.stop();
        break;
      case 'next':
        await player.skipToNext();
        break;
      case 'previous':
        await player.skipToPrevious();
        break;
    }
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final player = ref.read(playerProvider.notifier);
    switch (event.logicalKey) {
      case LogicalKeyboardKey.mediaPlayPause:
        player.togglePlayPause();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.mediaStop:
        player.stop();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.mediaTrackNext:
        player.skipToNext();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.mediaTrackPrevious:
        player.skipToPrevious();
        return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    if (Platform.isWindows) {
      _mediaKeyChannel.setMethodCallHandler(null);
    }
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isWindows) return widget.child;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKeyEvent,
      child: widget.child,
    );
  }
}

// ─── App Shell (bottom nav + mini-player) ─────────────────────────────────
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  static const _androidLifecycleChannel =
      MethodChannel('com.example.testf/lifecycle');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (Platform.isAndroid) {
      _androidLifecycleChannel.setMethodCallHandler((call) async {
        if (call.method == 'taskRemoved') {
          await ref.read(presenceProvider.notifier).stop();
          final sync = ref.read(syncProvider.notifier).service;
          await sync.releaseIfActive().catchError((_) {});
          await sync.unregisterCurrentDevice().catchError((_) {});
        }
      });
    }
    // Request storage permission then scan for local music on first frame
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _requestStoragePermission();
      if (mounted) {
        ref.read(localMusicProvider.notifier).scan();
        final uid = ref.read(authServiceProvider).currentUser?.uid;
        if (uid != null) {
          ref.read(presenceProvider.notifier).start(
                uid,
                playerState: ref.read(playerProvider),
              );
        }
      }
    });
  }

  /// Request the appropriate storage/audio permission for the platform.
  /// On Android 11+ we also try to get MANAGE_EXTERNAL_STORAGE so the
  /// scanner can see the whole phone — the user is sent to the OS settings
  /// page for this one since it can't be requested inline.
  Future<void> _requestStoragePermission() async {
    if (!Platform.isAndroid) return;
    await requestStoragePermission();
  }

  @override
  void dispose() {
    if (Platform.isAndroid) {
      _androidLifecycleChannel.setMethodCallHandler(null);
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(localMusicProvider.notifier).scan();
      final uid = ref.read(authServiceProvider).currentUser?.uid;
      if (uid != null) {
        ref.read(presenceProvider.notifier).start(
              uid,
              playerState: ref.read(playerProvider),
            );
      }
    }
    // Release active-device claim when app is fully closed so another
    // device can auto-claim on next launch.
    if (state == AppLifecycleState.detached) {
      ref.read(presenceProvider.notifier).stop();
      final player = ref.read(playerProvider.notifier);
      player.saveSession().catchError((_) {});
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
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      ref.read(playerProvider.notifier).saveSession().catchError((_) {});
      ref.read(presenceProvider.notifier).stop();
    }
  }

  final List<Widget> _screens = const [
    HomeScreen(),
    SearchScreen(),
    LibraryScreen(),
    FriendsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    ref.listen<PlayerState>(playerProvider, (_, next) {
      ref.read(presenceProvider.notifier).updateFromPlayer(next);
    });
    final playerState = ref.watch(playerProvider);
    final hasSong = playerState.currentSong != null;

    return Scaffold(
      body: Stack(
        children: [
          _screens[_currentIndex],
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: RemotePlaybackBanner(),
            ),
          ),
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: OfflineIndicator(),
          ),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mini-player sits above the nav bar when a song is playing
          if (hasSong) const MiniPlayer(),
          Row(
            children: [
              Expanded(
                child: NavigationBar(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: (i) =>
                      setState(() => _currentIndex = i),
                  destinations: [
                    NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home),
                      label: 'Home',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.search_outlined),
                      selectedIcon: Icon(Icons.search),
                      label: 'Search',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.library_music_outlined),
                      selectedIcon: Icon(Icons.library_music),
                      label: 'Library',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.people_outline),
                      selectedIcon: Icon(Icons.people),
                      label: 'Friends',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 52, child: PartyInviteButton()),
            ],
          ),
        ],
      ),
    );
  }
}
