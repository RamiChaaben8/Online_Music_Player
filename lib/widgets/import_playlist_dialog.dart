import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/library_provider.dart';
import '../providers/youtube_provider.dart';

Future<void> showImportPlaylistDialog(
    BuildContext context, WidgetRef ref) async {
  final overlay = Overlay.of(context, rootOverlay: true);
  final done = Completer<void>();
  late final OverlayEntry entry;

  entry = OverlayEntry(
    builder: (_) => _ImportPlaylistPanel(
      ref: ref,
      onClose: () {
        if (entry.mounted) entry.remove();
        if (!done.isCompleted) done.complete();
      },
    ),
  );
  overlay.insert(entry);
  await done.future;
}

class _ImportPlaylistPanel extends StatefulWidget {
  final WidgetRef ref;
  final VoidCallback onClose;

  const _ImportPlaylistPanel({
    required this.ref,
    required this.onClose,
  });

  @override
  State<_ImportPlaylistPanel> createState() => _ImportPlaylistPanelState();
}

class _ImportPlaylistPanelState extends State<_ImportPlaylistPanel> {
  final _controller = TextEditingController();
  var _importing = false;
  var _minimized = false;
  var _progressCurrent = 0;
  int? _progressTotal;
  String _progressSource = '';
  String? _error;
  Offset _position = const Offset(48, 48);
  Size _size = const Size(484, 304);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _move(DragUpdateDetails details) {
    setState(() {
      _position += details.delta;
    });
  }

  void _resize(DragUpdateDetails details) {
    setState(() {
      _size = Size(
        (_size.width + details.delta.dx).clamp(360, 760),
        (_size.height + details.delta.dy).clamp(240, 620),
      );
    });
  }

  Future<void> _import() async {
    if (_importing || _controller.text.trim().isEmpty) return;
    setState(() {
      _importing = true;
      _progressCurrent = 0;
      _progressTotal = null;
      _progressSource = '';
      _error = null;
    });

    try {
      final result =
          await widget.ref.read(playlistImportServiceProvider).importFromUrl(
        _controller.text,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() {
            _progressCurrent = progress.current;
            _progressTotal = progress.total;
            _progressSource = progress.source;
          });
        },
      );
      await widget.ref
          .read(libraryProvider.notifier)
          .createPlaylistWithSongs(result.name, result.songs);
      if (mounted) widget.onClose();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _importing = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: Material(
        color: Colors.transparent,
        child: _minimized ? _buildMinimized() : _buildExpanded(),
      ),
    );
  }

  Widget _buildMinimized() {
    return GestureDetector(
      onPanUpdate: _move,
      child: Container(
        width: 240,
        height: 48,
        decoration: _decoration(),
        child: Row(
          children: [
            const SizedBox(width: 14),
            const Icon(Icons.download, color: Color(0xFF1DB954), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _importing
                    ? 'Importing ${_progressTotal == null ? '' : '$_progressCurrent/$_progressTotal'}'
                    : 'Import playlist',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
            IconButton(
              tooltip: 'Restore',
              onPressed: () => setState(() => _minimized = false),
              icon: const Icon(Icons.open_in_full, size: 17),
              color: Colors.white70,
              splashRadius: 18,
            ),
            IconButton(
              tooltip: 'Close',
              onPressed: widget.onClose,
              icon: const Icon(Icons.close, size: 17),
              color: Colors.white70,
              splashRadius: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpanded() {
    final progress = _progressTotal == null || _progressTotal! <= 0
        ? null
        : (_progressCurrent / _progressTotal!).clamp(0.0, 1.0);

    return Container(
      width: _size.width,
      height: _size.height,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      decoration: _decoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onPanUpdate: _move,
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Import playlist',
                    style: TextStyle(color: Colors.white, fontSize: 22),
                  ),
                ),
                IconButton(
                  tooltip: 'Minimize',
                  onPressed: () => setState(() => _minimized = true),
                  icon: const Icon(Icons.minimize, size: 19),
                  color: Colors.white70,
                  splashRadius: 18,
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close, size: 19),
                  color: Colors.white70,
                  splashRadius: 18,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Paste a public Spotify or YouTube playlist link.',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          if (_importing && _progressCurrent > 0) ...[
            const SizedBox(height: 14),
            Text(
              _progressTotal == null || _progressTotal! <= 0
                  ? '$_progressSource: $_progressCurrent songs processed'
                  : '$_progressSource: $_progressCurrent/$_progressTotal songs processed '
                      '(${(_progressCurrent / _progressTotal! * 100).round()}%)',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              color: const Color(0xFF1DB954),
              backgroundColor: Colors.white12,
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              hintText: 'https://...',
              errorText: _error,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _importing ? null : widget.onClose,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _importing ? null : _import,
                icon: _importing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download),
                label: Text(_importing ? 'Importing…' : 'Import'),
              ),
            ],
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: GestureDetector(
              onPanUpdate: _resize,
              child: const SizedBox(
                width: 18,
                height: 18,
                child: Icon(
                  Icons.drag_handle,
                  color: Colors.white38,
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _decoration() {
    return BoxDecoration(
      color: const Color(0xFF151515),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.white12),
      boxShadow: const [
        BoxShadow(
          color: Colors.black54,
          blurRadius: 20,
          offset: Offset(0, 8),
        ),
      ],
    );
  }
}
