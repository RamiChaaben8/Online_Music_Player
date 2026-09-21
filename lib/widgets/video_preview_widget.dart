// ============================================================
// widgets/video_preview_widget.dart
//
// Inline video preview for the Now Playing screen.
// Loads a muxed MP4 stream URL from YoutubeService and plays
// it with video_player. The audio track in the muxed stream
// is intentionally muted so just_audio remains the audio
// authority — this widget is purely a visual preview.
//
// Usage:
//   VideoPreviewWidget(videoId: song.id)
// ============================================================

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:math';

import '../services/youtube_service.dart';

class VideoPreviewWidget extends StatefulWidget {
  final String videoId;

  /// How to fit the video within its container. Defaults to [BoxFit.contain].
  final BoxFit fit;

  const VideoPreviewWidget({
    super.key,
    required this.videoId,
    this.fit = BoxFit.contain,
  });

  @override
  State<VideoPreviewWidget> createState() => _VideoPreviewWidgetState();
}

class _VideoPreviewWidgetState extends State<VideoPreviewWidget> {
  final YoutubeService _yt = YoutubeService();
  static const _previewDuration = Duration(seconds: 10);
  final Random _random = Random();
  VideoPlayerController? _controller;

  bool _loading = true;
  String? _error;
  Duration _previewStart = Duration.zero;
  bool _seekingToLoopStart = false;
  int _loadSerial = 0;

  @override
  void initState() {
    super.initState();
    _initVideo(widget.videoId);
  }

  @override
  void didUpdateWidget(VideoPreviewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId != widget.videoId) {
      _loadSerial++;
      _disposeController();
      setState(() {
        _loading = true;
        _error = null;
      });
      _initVideo(widget.videoId);
    }
  }

  Future<void> _initVideo(String videoId) async {
    final loadSerial = ++_loadSerial;
    try {
      final url = await _yt.getVideoStreamUrl(videoId);
      if (!mounted || loadSerial != _loadSerial) return;

      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await controller.initialize();
      if (!mounted || loadSerial != _loadSerial) {
        controller.dispose();
        return;
      }

      // Mute video player — just_audio owns the audio
      await controller.setVolume(0);
      _previewStart = _randomPreviewStart(controller.value.duration);
      controller.addListener(_loopPreviewSegment);
      await controller.seekTo(_previewStart);
      await controller.play();

      setState(() {
        _controller = controller;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || loadSerial != _loadSerial) return;
      setState(() {
        _loading = false;
        _error = e is YoutubeServiceException ? e.message : 'Video unavailable';
      });
    }
  }

  Duration _randomPreviewStart(Duration duration) {
    final maxStart = duration - _previewDuration;
    if (maxStart <= Duration.zero) return Duration.zero;

    // Choose from the middle half of the video rather than the intro/outro.
    final middleStart = maxStart * 0.25;
    final middleEnd = maxStart * 0.75;
    final seconds = middleStart.inSeconds +
        _random.nextInt(max(1, (middleEnd - middleStart).inSeconds + 1));
    return Duration(seconds: seconds);
  }

  void _loopPreviewSegment() {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _seekingToLoopStart) {
      return;
    }

    final segmentEnd = _previewStart + _previewDuration;
    if (controller.value.position >= segmentEnd) {
      _seekingToLoopStart = true;
      controller.seekTo(_previewStart).whenComplete(() {
        _seekingToLoopStart = false;
      });
    }
  }

  void _disposeController() {
    _controller?.removeListener(_loopPreviewSegment);
    _controller?.dispose();
    _controller = null;
  }

  @override
  void dispose() {
    _disposeController();
    _yt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return _shell(
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: Color(0xFF1DB954),
                strokeWidth: 2.5,
              ),
              SizedBox(height: 12),
              Text(
                'Loading video…',
                style: TextStyle(color: Color(0xFFB3B3B3), fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return _shell(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.videocam_off_outlined,
                  color: Color(0xFF555555), size: 40),
              const SizedBox(height: 10),
              const Text(
                'Video preview unavailable',
                style: TextStyle(
                    color: Color(0xFFB3B3B3),
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                _error!,
                style: const TextStyle(color: Color(0xFF666666), fontSize: 11),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      );
    }

    final controller = _controller!;
    final videoWidget = ClipRRect(
      borderRadius: widget.fit == BoxFit.cover
          ? BorderRadius.zero
          : BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: VideoPlayer(controller),
      ),
    );

    if (widget.fit == BoxFit.cover) {
      // Fill the parent and crop to cover, preserving aspect ratio
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: controller.value.size.width,
            height: controller.value.size.height,
            child: VideoPlayer(controller),
          ),
        ),
      );
    }

    return videoWidget;
  }

  /// Shared dark container that matches the album art area's dimensions.
  Widget _shell({required Widget child}) {
    if (widget.fit == BoxFit.cover) {
      // In cover/desktop mode, expand to fill parent
      return ColoredBox(
        color: const Color(0xFF1A1A1A),
        child: SizedBox.expand(child: child),
      );
    }
    return Container(
      width: double.infinity,
      height: 320,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: child,
    );
  }
}
