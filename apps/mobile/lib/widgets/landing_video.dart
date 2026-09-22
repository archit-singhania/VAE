import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// The free, local landing artwork shared with the web experience.
///
/// The controller is deliberately initialized in the background. The auth
/// screen paints its shader on the first frame, then fades this video in only
/// after the device has confirmed that it can decode the MOV container. This
/// keeps launch fast and leaves older Android/iOS codecs with a graceful
/// shader fallback instead of a blank surface or a blocking spinner.
class LandingVideo extends StatefulWidget {
  const LandingVideo({super.key});

  @override
  State<LandingVideo> createState() => _LandingVideoState();
}

class _LandingVideoState extends State<LandingVideo> {
  VideoPlayerController? _controller;
  Future<void>? _initialization;

  @override
  void initState() {
    super.initState();
    final controller =
        VideoPlayerController.asset('assets/video/video_loop.MOV');
    _controller = controller;
    _initialization = controller.initialize().then((_) async {
      await controller.setLooping(true);
      await controller.setVolume(0);
      if (mounted) await controller.play();
    }).catchError((_) {
      // The shader underneath remains the supported fallback for a platform
      // whose media codecs do not include this MOV container.
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final initialization = _initialization;
    if (controller == null || initialization == null) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<void>(
      future: initialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done ||
            snapshot.hasError ||
            !controller.value.isInitialized ||
            controller.value.size.width <= 0 ||
            controller.value.size.height <= 0) {
          return const SizedBox.shrink();
        }

        return IgnorePointer(
          child: AnimatedOpacity(
            // Keep copy and form controls readable over the artwork.
            opacity: 0.34,
            duration: const Duration(milliseconds: 520),
            curve: Curves.easeOutCubic,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final viewport =
                    Size(constraints.maxWidth, constraints.maxHeight);
                final source = controller.value.size;
                final scale = math.max(
                  viewport.width / source.width,
                  viewport.height / source.height,
                );
                return Center(
                  child: SizedBox(
                    width: source.width * scale,
                    height: source.height * scale,
                    child: VideoPlayer(controller),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
