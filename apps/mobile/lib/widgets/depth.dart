import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/aevra_theme.dart';
import 'advanced_ui.dart';

/// ---------------------------------------------------------------------
/// The depth system — the Flutter half of apps/web/components/depth.tsx.
/// The two are kept deliberately parallel: same four elevation tiers,
/// same tilt magnitudes, same specular treatment, so a screen ported
/// between platforms lands in the same visual language.
/// ---------------------------------------------------------------------

enum GlassElevation { flat, raised, floating, lifted }

/// Per-tier density and shadow, mirroring the web content planes.
class _GlassSpec {
  const _GlassSpec(this.fill, this.shadow);
  final double fill;
  final List<BoxShadow> shadow;
}

const _specs = <GlassElevation, _GlassSpec>{
  GlassElevation.flat: _GlassSpec(0.76, []),
  GlassElevation.raised: _GlassSpec(0.81, [
    BoxShadow(color: Color(0x18000000), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(
        color: Color(0x30000000),
        blurRadius: 24,
        spreadRadius: -12,
        offset: Offset(0, 8)),
  ]),
  GlassElevation.floating: _GlassSpec(0.84, [
    BoxShadow(color: Color(0x28000000), blurRadius: 5, offset: Offset(0, 2)),
    BoxShadow(
        color: Color(0x48000000),
        blurRadius: 54,
        spreadRadius: -20,
        offset: Offset(0, 20)),
  ]),
  GlassElevation.lifted: _GlassSpec(0.88, [
    BoxShadow(color: Color(0x35000000), blurRadius: 7, offset: Offset(0, 3)),
    BoxShadow(
        color: Color(0x65000000),
        blurRadius: 92,
        spreadRadius: -26,
        offset: Offset(0, 38)),
  ]),
};

/// Readable content plane. Frost is reserved for elevated chrome so lists
/// and grids do not each incur a backdrop read while they scroll.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.elevation = GlassElevation.raised,
    this.padding = const EdgeInsets.all(AevraSpace.md),
    this.radius = AevraRadius.md,
    this.borderColor,
    this.adaptive = true,
  });

  final Widget child;
  final GlassElevation elevation;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? borderColor;

  /// When true the surface densifies with scroll, reading [GlassScope].
  final bool adaptive;

  @override
  Widget build(BuildContext context) {
    final spec = _specs[elevation]!;
    final intensity = adaptive ? GlassScope.of(context) : 0.0;
    final light = Theme.of(context).brightness == Brightness.light;
    final highContrast = MediaQuery.maybeOf(context)?.highContrast ?? false;
    final fill = highContrast
        ? 1.0
        : light
            ? 0.92
            : (spec.fill + .09 + intensity * .1).clamp(0.0, 0.97);

    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: light
              ? [
                  BoxShadow(
                      color: const Color(0xFF35232A).withValues(alpha: .045),
                      blurRadius: 24,
                      offset: const Offset(0, 8)),
                ]
              : spec.shadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Container(
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.surface.withValues(alpha: fill),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                  color: borderColor ?? Theme.of(context).dividerColor),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                // The catching edge, matching web's `.glass::before` hairline.
                // Tinted with the cool `sheen` token rather than the warm
                // accent: a specular highlight is reflected light, and
                // tinting it with the brand colour makes glass look painted.
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AevraColors.sheen.withValues(alpha: 0.05),
                    Colors.transparent,
                    AevraColors.sheen.withValues(alpha: 0.014),
                  ],
                  stops: const [0.0, 0.38, 1.0],
                ),
              ),
              child: Padding(padding: padding, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// Translucent control plane for navigation, toolbars and floating sheets.
/// Keep one filter per chrome region rather than blurring every control.
class GlassChrome extends StatelessWidget {
  const GlassChrome({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(8),
    this.radius = 28,
    this.borderColor,
    this.dense = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? borderColor;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final light = theme.brightness == Brightness.light;
    final highContrast = MediaQuery.maybeOf(context)?.highContrast ?? false;
    final fill = highContrast
        ? 1.0
        : (light ? (dense ? .90 : .74) : (dense ? .90 : .72));
    final content = Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: fill),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor ??
              (highContrast
                  ? theme.colorScheme.onSurface.withValues(alpha: .5)
                  : theme.colorScheme.onSurface
                      .withValues(alpha: light ? .10 : .13)),
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: highContrast
              ? null
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: light ? .32 : .11),
                    Colors.transparent,
                    Colors.white.withValues(alpha: light ? .07 : .025),
                  ],
                  stops: const [0, .5, 1],
                ),
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: light ? .065 : .23),
              blurRadius: 30,
              spreadRadius: -8,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: highContrast
              ? content
              : BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: content,
                ),
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------
/// DepthCard — perspective tilt.
///
/// Web drives this from pointer position. A phone has no hover, so the
/// input here is the touch itself: the card tilts toward wherever the
/// finger lands and springs back on release. That keeps the effect
/// meaningful (it responds to a real gesture) instead of being a
/// permanently-tilted decoration.
/// ---------------------------------------------------------------------
class DepthCard extends StatefulWidget {
  const DepthCard({
    super.key,
    required this.child,
    this.elevation = GlassElevation.raised,
    this.padding = const EdgeInsets.all(AevraSpace.md),
    this.radius = AevraRadius.md,
    this.intensity = 0,
    this.onTap,
    this.enablePan = false,
  });

  final Widget child;
  final GlassElevation elevation;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// 0 disables tilt; 1 is the house default, matching web's ±7°/±9°.
  final double intensity;
  final VoidCallback? onTap;

  /// Whether the tilt should track a drag as well as the initial touch.
  ///
  /// Off by default, and that default matters: pan handlers here compete in
  /// the gesture arena with `Dismissible` (swipe-to-approve) and with
  /// `ReorderableListView`'s drag. A card that tilts under your finger while
  /// also trying to be swiped away resolves to neither. Tap-down tilt has no
  /// such conflict, so only enable this on cards that aren't swipeable or
  /// draggable.
  final bool enablePan;

  @override
  State<DepthCard> createState() => _DepthCardState();
}

class _DepthCardState extends State<DepthCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    value: 1,
  );

  // Normalised -0.5..0.5 touch position within the card.
  Offset _local = Offset.zero;
  bool _pressed = false;

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  void _setFrom(Offset globalPosition) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final local = box.globalToLocal(globalPosition);
    setState(() {
      _local = Offset(
        (local.dx / box.size.width) - 0.5,
        (local.dy / box.size.height) - 0.5,
      );
      _pressed = true;
    });
    _settle.value = 0;
  }

  void _release() {
    setState(() => _pressed = false);
    _settle.forward(from: _settle.value);
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.intensity == 0 || reduceMotion(context);

    final surface = GlassSurface(
      elevation: widget.elevation,
      padding: widget.padding,
      radius: widget.radius,
      child: widget.child,
    );

    if (disabled) {
      return GestureDetector(onTap: widget.onTap, child: surface);
    }

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (d) => _setFrom(d.globalPosition),
      onTapUp: (_) => _release(),
      onTapCancel: _release,
      onPanStart: widget.enablePan ? (d) => _setFrom(d.globalPosition) : null,
      onPanUpdate: widget.enablePan ? (d) => _setFrom(d.globalPosition) : null,
      onPanEnd: widget.enablePan ? (_) => _release() : null,
      child: AnimatedBuilder(
        animation: _settle,
        builder: (context, child) {
          // `_settle` runs 0 (fully tilted) → 1 (flat) on release, so the
          // card springs back rather than snapping.
          final relax = _pressed
              ? 0.0
              : Curves.easeOutBack.transform(_settle.value).clamp(0.0, 1.0);
          final amount = (1 - relax) * widget.intensity;

          final rotX = (-_local.dy * 7 * math.pi / 180) * amount;
          final rotY = (_local.dx * 9 * math.pi / 180) * amount;

          final shrink = 1 - 0.012 * amount;
          final matrix = Matrix4.identity()
            ..setEntry(
                3, 2, 1 / 1100) // perspective, matching --depth-perspective
            ..rotateX(rotX)
            ..rotateY(rotY)
            // `scale` is deprecated in favour of the explicit per-axis form.
            // The w component stays 1: scaling it would divide the whole
            // homogeneous coordinate and undo the perspective set above.
            ..scaleByDouble(shrink, shrink, shrink, 1);

          return Transform(
            alignment: Alignment.center,
            transform: matrix,
            child: Stack(
              children: [
                child!,
                if (amount > 0.01)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(widget.radius),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center:
                                  Alignment(_local.dx * 1.8, _local.dy * 1.8),
                              radius: 0.85,
                              colors: [
                                AevraColors.sheen
                                    .withValues(alpha: 0.14 * amount),
                                AevraColors.sheen
                                    .withValues(alpha: 0.04 * amount),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.32, 0.62],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
        child: surface,
      ),
    );
  }
}

/// ---------------------------------------------------------------------
/// ParallaxLayer — scroll-linked translation on a notional z-plane.
/// [depth] matches web: negative sits behind and moves slower, positive
/// sits in front and moves faster.
///
/// It reads the scroll offset from [GlassScope] rather than listening for
/// scroll notifications itself. A `NotificationListener` only sees
/// notifications bubbling up from its own descendants, so a widget *inside*
/// a list can never hear that list scrolling — the offset has to come down
/// the tree from [AdaptiveGlassScroll] above it.
/// ---------------------------------------------------------------------
class ParallaxLayer extends StatelessWidget {
  const ParallaxLayer({super.key, required this.child, this.depth = -1});

  final Widget child;
  final double depth;

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return child;
    final offset = GlassScope.offsetOf(context);
    return Transform.translate(
      offset: Offset(0, offset * depth * 0.06),
      child: child,
    );
  }
}
