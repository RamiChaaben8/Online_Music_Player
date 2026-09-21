import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/library_provider.dart';
import '../providers/youtube_provider.dart';

Future<void> showImportPlaylistDialog(
    BuildContext context, WidgetRef ref) async {
  final controller = TextEditingController();
  var importing = false;
  var progressCurrent = 0;
  int? progressTotal;
  String progressSource = '';
  String? error;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Import playlist'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Paste a public Spotify or YouTube playlist link.'),
              const SizedBox(height: 12),
              if (importing && progressCurrent > 0) ...[
                Text(
                  progressTotal == null || progressTotal! <= 0
                      ? '$progressSource: $progressCurrent songs processed'
                      : '$progressSource: $progressCurrent/$progressTotal songs processed '
                          '(${(progressCurrent / progressTotal! * 100).clamp(0, 100).round()}%)',
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progressTotal == null
                      ? null
                      : progressCurrent / progressTotal!,
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  hintText: 'https://...',
                  errorText: error,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: importing ? null : () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: importing
                ? null
                : () async {
                    setState(() {
                      importing = true;
                      progressCurrent = 0;
                      progressTotal = null;
                      progressSource = '';
                      error = null;
                    });
                    try {
                      final result = await ref
                          .read(playlistImportServiceProvider)
                          .importFromUrl(
                        controller.text,
                        onProgress: (progress) {
                          if (!context.mounted) return;
                          setState(() {
                            progressCurrent = progress.current;
                            progressTotal = progress.total;
                            progressSource = progress.source;
                          });
                        },
                      );
                      await ref
                          .read(libraryProvider.notifier)
                          .createPlaylistWithSongs(result.name, result.songs);
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                    } catch (e) {
                      setState(() {
                        importing = false;
                        error = e.toString().replaceFirst('Exception: ', '');
                      });
                    }
                  },
            icon: importing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download),
            label: Text(importing ? 'Importing…' : 'Import'),
          ),
        ],
      ),
    ),
  );
  controller.dispose();
}
