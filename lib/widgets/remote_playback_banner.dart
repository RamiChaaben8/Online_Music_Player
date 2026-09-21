// ============================================================
// widgets/remote_playback_banner.dart
//
// Slim banner shown when another device sent a remote command.
// Shows the device name, what it's doing, and the current song.
// No position ticker, no "take over" — just informational.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/player_provider.dart';
import '../services/sync_service.dart';
import '../desktop/theme/desktop_theme.dart';

class RemotePlaybackBanner extends ConsumerWidget {
  const RemotePlaybackBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remote = ref.watch(playerProvider.select((s) => s.remoteCommand));
    if (remote == null) return const SizedBox.shrink();
    final theme = AppThemeScope.maybeOf(context);

    final song = remote.currentSong;
    final deviceName = remote.deviceName;
    final isPlaying = remote.command == RemoteCommand.play ||
        remote.command == RemoteCommand.playSong ||
        remote.command == RemoteCommand.next ||
        remote.command == RemoteCommand.prev;

    return Material(
      color: theme?.main.withValues(alpha: 0) ?? Colors.transparent,
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        decoration: BoxDecoration(
          color: theme?.selectedRow ?? const Color(0xFF1A2A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (theme?.button ?? const Color(0xFF1DB954))
                .withValues(alpha: 0.45),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(
                isPlaying ? Icons.cast_connected : Icons.cast,
                color: theme?.button ?? const Color(0xFF1DB954),
                size: 18,
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Remote from $deviceName',
                      style: TextStyle(
                        color: theme?.text ?? Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (song != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme?.subtext ?? const Color(0xFFB3B3B3),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Dismiss
              GestureDetector(
                onTap: () =>
                    ref.read(playerProvider.notifier).dismissRemoteBanner(),
                child: Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close,
                      color: theme?.subtext ?? const Color(0xFFB3B3B3),
                      size: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
