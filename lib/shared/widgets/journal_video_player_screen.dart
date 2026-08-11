import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Full-screen playback for a journal video, opened by tapping a video
/// tile in [JournalMediaCarousel] — previously that tap did nothing and
/// the tile tried to decode the video file as an image.
///
/// The `video_player` package only ships platform implementations for
/// Android, iOS, macOS and web — there's no Windows or Linux support, so
/// constructing a controller there throws `UnimplementedError` from the
/// very first call. Checked up front so that shows as a clear message
/// instead of a raw platform exception.
bool get _videoPlaybackSupported =>
    kIsWeb || Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

class JournalVideoPlayerScreen extends StatefulWidget {
  const JournalVideoPlayerScreen({super.key, required this.url});

  final String url;

  @override
  State<JournalVideoPlayerScreen> createState() => _JournalVideoPlayerScreenState();
}

class _JournalVideoPlayerScreenState extends State<JournalVideoPlayerScreen> {
  VideoPlayerController? _controller;
  bool _failed = false;
  String? _errorDetail;

  @override
  void initState() {
    super.initState();

    if (!_videoPlaybackSupported) {
      _failed = true;
      _errorDetail = 'Video playback isn\'t supported on this platform yet — try an Android or iOS device.';
      return;
    }

    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller = controller;
    // A player can fail either during initialize() (caught below) or later
    // mid-playback (surfaced only through value.hasError) — listening
    // catches both instead of just the first.
    controller.addListener(_onControllerUpdate);
    controller.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
      controller.play();
    }).catchError((Object error) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _errorDetail = error.toString();
      });
    });
  }

  void _onControllerUpdate() {
    if (!mounted) return;
    final controller = _controller;
    if (controller != null && controller.value.hasError && !_failed) {
      setState(() {
        _failed = true;
        _errorDetail = controller.value.errorDescription;
      });
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onControllerUpdate);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: _failed
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.white70, size: 32),
                    const SizedBox(height: 12),
                    const Text(
                      'Could not play this video.',
                      style: TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                    if (_errorDetail != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _errorDetail!,
                        style: const TextStyle(color: Colors.white38, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              )
            : controller != null && controller.value.isInitialized
                ? AspectRatio(
                    aspectRatio: controller.value.aspectRatio,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        VideoPlayer(controller),
                        _PlaybackOverlay(controller: controller),
                      ],
                    ),
                  )
                : const CircularProgressIndicator(color: Colors.white70),
      ),
    );
  }
}

class _PlaybackOverlay extends StatefulWidget {
  const _PlaybackOverlay({required this.controller});

  final VideoPlayerController controller;

  @override
  State<_PlaybackOverlay> createState() => _PlaybackOverlayState();
}

class _PlaybackOverlayState extends State<_PlaybackOverlay> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTick);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTick);
    super.dispose();
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = widget.controller.value.isPlaying;
    return GestureDetector(
      onTap: () => setState(() {
        isPlaying ? widget.controller.pause() : widget.controller.play();
      }),
      child: Container(
        color: Colors.transparent,
        alignment: Alignment.center,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: isPlaying ? 0 : 1,
          child: const Icon(Icons.play_arrow, size: 64, color: Colors.white70),
        ),
      ),
    );
  }
}
