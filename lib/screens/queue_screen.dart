// ============================================================
// screens/queue_screen.dart
//
// Displays the current playback queue.
// Supports reordering and removal.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/player_provider.dart';

class QueueScreen extends ConsumerWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final queue = playerState.queue;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Up Next', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: queue.isEmpty
          ? const Center(
              child: Text(
                'Queue is empty',
                style: TextStyle(color: Color(0xFFB3B3B3)),
              ),
            )
          : ReorderableListView.builder(
              itemCount: queue.length,
              onReorder: (oldIndex, newIndex) {
                ref.read(playerProvider.notifier).reorderQueue(oldIndex, newIndex);
              },
              proxyDecorator: (child, index, animation) {
                return Material(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(8),
                  child: child,
                );
              },
              itemBuilder: (ctx, i) {
                final song = queue[i];
                final isCurrent = i == playerState.currentIndex;

                return ListTile(
                  key: ValueKey(song.id + i.toString()),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          song.thumbnailUrl,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 48,
                            height: 48,
                            color: const Color(0xFF282828),
                            child: const Icon(Icons.music_note, color: Color(0xFF3A3A3A)),
                          ),
                        ),
                      ),
                      if (isCurrent)
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.graphic_eq,
                            color: Color(0xFF1DB954),
                            size: 24,
                          ),
                        ),
                    ],
                  ),
                  title: Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isCurrent ? const Color(0xFF1DB954) : Colors.white,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    song.channelName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFFB3B3B3), fontSize: 13),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isCurrent)
                        IconButton(
                          icon: const Icon(Icons.close, color: Color(0xFFB3B3B3), size: 20),
                          onPressed: () =>
                              ref.read(playerProvider.notifier).removeFromQueue(i),
                        ),
                      const Icon(Icons.drag_handle, color: Color(0xFF3A3A3A)),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
