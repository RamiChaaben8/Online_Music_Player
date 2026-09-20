import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song.dart';
import '../providers/library_provider.dart';

class AddToPlaylistSheet extends ConsumerWidget {
  final Song song;

  const AddToPlaylistSheet({super.key, required this.song});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider);
    final playlists = library.playlists;

    return Container(
      color: const Color(0xFF1A1A1A),
      padding: const EdgeInsets.only(top: 16, bottom: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Add to Playlist',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.add, color: Colors.white),
            title: const Text('Create New Playlist',
                style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              _showCreatePlaylistDialog(context, ref);
            },
          ),
          const Divider(color: Colors.grey),
          if (playlists.isEmpty)
            const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No playlists yet',
                    style: TextStyle(color: Colors.grey)))
          else
            // Use the Playlist object directly — not a list index
            ...playlists.map((pl) => ListTile(
                  leading:
                      const Icon(Icons.queue_music, color: Colors.white),
                  title: Text(pl.name,
                      style: const TextStyle(color: Colors.white)),
                  onTap: () {
                    ref
                        .read(libraryProvider.notifier)
                        .addSongToPlaylistObj(pl, song);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Added to ${pl.name}')));
                  },
                )),
        ],
      ),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF282828),
        title: const Text('New Playlist',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Playlist name',
            hintStyle: TextStyle(color: Colors.grey),
          ),
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) {
              ref
                  .read(libraryProvider.notifier)
                  .createPlaylist(v.trim());
            }
            Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                ref
                    .read(libraryProvider.notifier)
                    .createPlaylist(controller.text.trim());
              }
              Navigator.pop(ctx);
            },
            child: const Text('Create',
                style: TextStyle(color: Color(0xFF1DB954))),
          ),
        ],
      ),
    );
  }
}
