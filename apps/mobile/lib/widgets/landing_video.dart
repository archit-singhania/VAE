import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Local film shared with the web landing experience. The portrait edit keeps
/// the composition natural on a phone; wider layouts use the original film.
/// A real frame stays visible while decoding and when Reduce Motion is enabled.
class LandingVideo extends StatefulWidget {
  const LandingVideo({super.key, this.admin = false, this.portrait});

  final bool admin;
  final bool? portrait;

  @override
  State<LandingVideo> createState() => _LandingVideoState();
}

class _LandingVideoState extends State<LandingVideo>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  Future<void>? _initialization;
  String? _asset;
  bool _portrait = true;
  bool _reduceMotion = false;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
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
          !_reduceMotion &&
          _foreground) {
        await controller.play();
      }
    }).catchError((_) {
      // Keep the actual film poster when a device cannot decode the source.
    });
  }

  void _syncPlayback() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (!_reduceMotion && _foreground) {
      controller.play();
    } else {
      controller.pause();
    }
  }

  void _selectFilm() {
    final size = MediaQuery.sizeOf(context);
    _portrait = widget.portrait ?? size.width / size.height < .82;
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (!_reduceMotion) {
      _load(_portrait
          ? 'assets/video/video_loop_portrait.mp4'
          : 'assets/video/video_loop.MOV');
    }
    _syncPlayback();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _selectFilm();
  }

  @override
  void didUpdateWidget(LandingVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.portrait != widget.portrait) _selectFilm();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncPlayback();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  Widget _poster() => Image.asset(
        _portrait
            ? 'assets/video/video_loop_portrait-poster.jpg'
            : 'assets/video/video_loop-poster.jpg',
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        excludeFromSemantics: true,
        errorBuilder: (_, __, ___) => ColoredBox(
          color:
              widget.admin ? const Color(0xFF0D1420) : const Color(0xFF121016),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final initialization = _initialization;
    if (_reduceMotion || controller == null || initialization == null) {
      return IgnorePointer(child: _poster());
    }
    return IgnorePointer(
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            _poster(),
            FutureBuilder<void>(
              future: initialization,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done ||
                    snapshot.hasError ||
                    !controller.value.isInitialized ||
                    controller.value.size.width <= 0 ||
                    controller.value.size.height <= 0) {
                  return const SizedBox.shrink();
                }
                final source = controller.value.size;
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 420),
                  curve: Curves.easeOutCubic,
                  builder: (context, opacity, child) =>
                      Opacity(opacity: opacity, child: child),
                  child: FittedBox(
                    fit: BoxFit.cover,
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                      width: source.width,
                      height: source.height,
                      child: VideoPlayer(controller),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
