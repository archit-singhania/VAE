import 'package:flutter/material.dart';
import '../theme/aevra_theme.dart';
import 'depth.dart';

/// The mobile counterpart of the web app's `.panel`.
///
/// This is now a thin alias over [GlassSurface] at the `raised` tier. Keeping
/// the old name means the four screens didn't need touching, but there is
/// only one frosted-surface implementation in the app rather than two that
/// drift apart.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AevraSpace.md),
    this.borderColor,
    this.elevation = GlassElevation.raised,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final GlassElevation elevation;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      elevation: elevation,
      padding: padding,
      borderColor: borderColor,
      child: child,
    );
  }
}

/// A small circular progress ring used for scores (mirrors `.score-ring`).
///
/// The track is a token rather than a hardcoded grey, and the value animates
/// from zero on mount so a score arrives rather than appearing — the same
/// treatment every other number in the app gets.
class ScoreRing extends StatelessWidget {
  const ScoreRing({
    super.key,
    required this.value,
    this.label = '/100',
    this.color,
    this.size = 66,
  });

  final int value;
  final String label;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ringColor = color ?? Theme.of(context).colorScheme.tertiary;
    final trackColor = Theme.of(context).brightness == Brightness.light
        ? AevraLightColors.surface4
        : AevraColors.surface4;
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: (value / 100).clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 820),
        curve: Curves.easeOutCubic,
        builder: (context, progress, _) => Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: size * 0.055,
                strokeCap: StrokeCap.round,
                backgroundColor: trackColor,
                valueColor: AlwaysStoppedAnimation(ringColor),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  (progress * 100).round().toString(),
                  style: AevraType.metric(size * 0.28),
                ),
                const SizedBox(height: 2),
                Text(label, style: AevraType.mono(size: size * 0.125)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
