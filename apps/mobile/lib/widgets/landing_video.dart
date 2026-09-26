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
  const LandingVideo({super.key, this.admin = false});
  final bool admin;

  @override
  State<LandingVideo> createState() => _LandingVideoState();
}

class _LandingVideoState extends State<LandingVideo>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  Future<void>? _initialization;
  String? _asset;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void _load(String asset) {
    if (_asset == asset) return;
    final previous = _controller;
    _asset = asset;
    final controller = VideoPlayerController.asset(asset);
    _controller = controller;
    previous?.dispose();
    _initialization = controller.initialize().then((_) async {
      if (!mounted || _controller != controller) return;
      await controller.setLooping(true);
      if (!mounted || _controller != controller) return;
      await controller.setVolume(0);
      if (mounted &&
          _controller == controller &&
          !MediaQuery.disableAnimationsOf(context) &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        await controller.play();
      }
    }).catchError((_) {
      // The shader underneath remains the supported fallback for a platform
      // whose media codecs do not include the bundled video format.
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !MediaQuery.disableAnimationsOf(context)) {
      _controller?.play();
    } else {
      _controller?.pause();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final size = MediaQuery.sizeOf(context);
    _load(size.width / size.height < .82
        ? 'assets/video/video_loop_portrait.mp4'
        : 'assets/video/video_loop.MOV');
    if (MediaQuery.disableAnimationsOf(context)) _controller?.pause();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
            opacity: .78,
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
