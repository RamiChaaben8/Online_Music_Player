// ============================================================
// desktop/player/queue_panel.dart
//
// Slide-in side panel showing the current playback queue.
// Supports reordering, removal, and jumping to a track.
// ============================================================

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/player_provider.dart';
import '../theme/desktop_theme.dart';

class QueuePanel extends ConsumerWidget {
  final VoidCallback onClose;
  const QueuePanel({super.key, required this.onClose});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ps = ref.watch(playerProvider);
    final queue = ps.queue;
    final currentIndex = ps.currentIndex;

    return Container(
      width: 320,
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        border: Border(left: BorderSide(color: Color(0xFF2A2A2A))),
      ),
      child: Column(
        children: [
          // ── Header ────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF2A2A2A))),
            ),
            child: Row(
              children: [
                const Icon(Icons.queue_music, color: kAccent, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'Queue',
                  style: TextStyle(
                    color: kTextPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: kAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${queue.length}',
                    style: const TextStyle(
                      color: kAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: kTextSecondary, size: 18),
                  onPressed: onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
              ],
            ),
          ),

          // ── Queue list ────────────────────────────────────────────────
          Expanded(
            child: queue.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.queue_music,
                            color: kTextSecondary, size: 40),
                        SizedBox(height: 10),
                        Text(
                          'Queue is empty',
                          style: TextStyle(
                              color: kTextSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: queue.length,
                    onReorder: (oldIndex, newIndex) {
                      ref
                          .read(playerProvider.notifier)
                          .reorderQueue(oldIndex, newIndex);
                    },
                    proxyDecorator: (child, index, animation) {
                      return Material(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(6),
                        child: child,
                      );
                    },
                    itemBuilder: (ctx, i) {
                      final song = queue[i];
                      final isCurrent = i == currentIndex;

                      return _QueueTile(
                        key: ValueKey('${song.id}_$i'),
                        song: song,
                        isCurrent: isCurrent,
                        index: i,
                        onTap: () {
                          ref.read(playerProvider.notifier).playSong(
                                song,
                                queue: queue,
                              );
                        },
                        onRemove: isCurrent
                            ? null
                            : () => ref
                                .read(playerProvider.notifier)
                                .removeFromQueue(i),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Queue tile ───────────────────────────────────────────────────────────────

class _QueueTile extends StatelessWidget {
  final dynamic song; // Song
  final bool isCurrent;
  final int index;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  const _QueueTile({
    super.key,
    required this.song,
    required this.isCurrent,
    required this.index,
    required this.onTap,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: isCurrent
            ? BoxDecoration(
                color: kAccent.withOpacity(0.08),
                border: const Border(
                  left: BorderSide(color: kAccent, width: 2),
                ),
              )
            : null,
        child: Row(
          children: [
            // ── Thumbnail ────────────────────────────────────────────────
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: song.thumbnailUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: song.thumbnailUrl,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                              width: 40, height: 40, color: kCardColor),
                          errorWidget: (_, __, ___) => Container(
                            width: 40,
                            height: 40,
                            color: kCardColor,
                            child: const Icon(Icons.music_note,
                                color: Colors.white38, size: 16),
                          ),
                        )
                      : Container(
                          width: 40,
                          height: 40,
                          color: kCardColor,
                          child: const Icon(Icons.music_note,
                              color: Colors.white38, size: 16),
                        ),
                ),
                if (isCurrent)
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.graphic_eq,
                        color: kAccent, size: 18),
                  ),
              ],
            ),
            const SizedBox(width: 10),

            // ── Title + artist ───────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isCurrent ? kAccent : kTextPrimary,
                      fontSize: 13,
                      fontWeight:
                          isCurrent ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  Text(
                    song.channelName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: kTextSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),

            // ── Actions ──────────────────────────────────────────────────
            if (onRemove != null)
              IconButton(
                icon: const Icon(Icons.close,
                    color: kTextSecondary, size: 16),
                onPressed: onRemove,
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 28, minHeight: 28),
              )
            else
              const SizedBox(width: 28),

            const Icon(Icons.drag_handle,
                color: Color(0xFF3A3A3A), size: 18),
          ],
        ),
      ),
    );
  }
}
