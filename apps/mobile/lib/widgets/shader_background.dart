import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/material.dart';

import '../theme/aevra_theme.dart';

/// Full-bleed animated GPU background, driven by a hand-written GLSL
/// fragment shader (see shaders/background.frag) — the mobile counterpart
/// to the web app's WebGL background, same palette and motion language.
///
/// Falls back to a quiet static gradient if the shader fails to load (older
/// devices / engines without Impeller) or if the platform reports a
/// reduced-motion preference, in which case the animation simply stops on
/// its first frame instead of looping.
class ShaderBackground extends StatefulWidget {
  const ShaderBackground({super.key});

  @override
  State<ShaderBackground> createState() => _ShaderBackgroundState();
}

class _ShaderBackgroundState extends State<ShaderBackground>
    with SingleTickerProviderStateMixin {
  ui.FragmentShader? _shader;
  bool _failed = false;
  late final Ticker _ticker;
  late final AppLifecycleListener _lifecycle;

  /// Driven directly as the painter's `repaint` signal. Ticking a
  /// ValueNotifier instead of calling setState keeps the per-frame cost to
  /// a repaint — no rebuild, no relayout of a full-bleed widget 60 times a
  /// second for a background that never changes size.
  final ValueNotifier<double> _time = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    // A GPU shader that keeps running behind a backgrounded app is pure
    // battery drain, and on some devices the engine drops the surface
    // anyway. Pause on the way out, resume on the way back in.
    _lifecycle = AppLifecycleListener(
      onHide: _pause,
      onPause: _pause,
      onRestart: _resume,
      onShow: _resume,
    );
    _load();
  }

  void _pause() {
    if (_ticker.isActive) _ticker.stop();
  }

  void _resume() {
    if (_shader != null && !_ticker.isActive && mounted) _maybeStart();
  }

  Future<void> _load() async {
    try {
      final program =
          await ui.FragmentProgram.fromAsset('shaders/background.frag');
      if (!mounted) return;
      setState(() => _shader = program.fragmentShader());
      _maybeStart();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _maybeStart() {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (!reduceMotion) {
      _ticker.start();
    }
  }

  void _onTick(Duration elapsed) {
    _time.value = elapsed.inMicroseconds / 1e6;
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _ticker.dispose();
    _time.dispose();
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return const _StaticFallback();
    final shader = _shader;
    if (shader == null) return const _StaticFallback();

    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _ShaderPainter(shader: shader, time: _time),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _ShaderPainter extends CustomPainter {
  _ShaderPainter({required this.shader, required this.time})
      : super(repaint: time);

  final ui.FragmentShader shader;
  final ValueNotifier<double> time;

  @override
  void paint(Canvas canvas, Size size) {
    // Uniform indices must match the declaration order in
    // shaders/background.frag: uSize.x, uSize.y, uTime.
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, time.value);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant _ShaderPainter oldDelegate) =>
      oldDelegate.shader != shader || oldDelegate.time != time;
}

class _StaticFallback extends StatelessWidget {
  const _StaticFallback();

  @override
  Widget build(BuildContext context) {
    // Two stacked radial washes rather than one: a warm copper bloom high
    // right and a cool jade one low left. A single centred gradient reads as
    // a vignette; two offset ones read as light in a room, which is what the
    // live shader produces and what this has to stand in for.
    return const DecoratedBox(
      decoration: BoxDecoration(color: AevraColors.bg),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.55, -0.72),
            radius: 1.15,
            colors: [Color(0x1FC4855A), Color(0x0006070A)],
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(-0.7, 0.85),
              radius: 1.05,
              colors: [Color(0x164E9C82), Color(0x0006070A)],
            ),
          ),
          child: SizedBox.expand(),
        ),
      ),
    );
  }
}
