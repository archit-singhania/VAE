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

/// Per-tier constants, mirroring the CSS custom properties. Blur values
/// are sigma, not CSS px: Flutter's `ImageFilter.blur` takes a Gaussian
/// sigma, and CSS `blur(Npx)` is roughly sigma = N/2, so these are the
/// web numbers halved rather than copied.
class _GlassSpec {
  const _GlassSpec(this.sigma, this.fill, this.shadow);
  final double sigma;
  final double fill;
  final List<BoxShadow> shadow;
}

const _specs = <GlassElevation, _GlassSpec>{
  GlassElevation.flat: _GlassSpec(5, 0.30, []),
  GlassElevation.raised: _GlassSpec(9, 0.46, [
    BoxShadow(color: Color(0x6E000000), blurRadius: 3, offset: Offset(0, 1)),
    BoxShadow(
        color: Color(0x8C000000),
        blurRadius: 28,
        spreadRadius: -14,
        offset: Offset(0, 10)),
  ]),
  GlassElevation.floating: _GlassSpec(14, 0.60, [
    BoxShadow(color: Color(0x78000000), blurRadius: 5, offset: Offset(0, 2)),
    BoxShadow(
        color: Color(0xB8000000),
        blurRadius: 54,
        spreadRadius: -20,
        offset: Offset(0, 20)),
  ]),
  GlassElevation.lifted: _GlassSpec(20, 0.74, [
    BoxShadow(color: Color(0x85000000), blurRadius: 7, offset: Offset(0, 3)),
    BoxShadow(
        color: Color(0xD6000000),
        blurRadius: 92,
        spreadRadius: -26,
        offset: Offset(0, 38)),
  ]),
};

/// A tiered frosted surface.
///
/// Performance note: every one of these is a `BackdropFilter`, which forces
/// a saveLayer and reads back the whole area beneath it. Nesting them
/// multiplies that cost, so a [GlassSurface] should never contain another
/// one — use a plain `Container` for inner rows and let the outer surface
/// provide the frost.
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
    final sigma = spec.sigma + intensity * 5;
    final fill = Theme.of(context).brightness == Brightness.light
        ? 0.92
        : (spec.fill + intensity * 0.14).clamp(0.0, 0.95);

    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: spec.shadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surface
                    .withValues(alpha: fill),
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(
                    color: borderColor ?? Theme.of(context).dividerColor),
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
              child: child,
            ),
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
