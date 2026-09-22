import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/aevra_theme.dart';

/// The Aevra brand mark — vector-drawn, not an image asset, so it stays
/// crisp at any size and always tracks the live theme tokens.
///
/// Geometry (Nocturne): an open aperture ring in the cool `sheen` tint with
/// a deliberate gap at the top-right, and inside it a monoline "A" — apex,
/// two legs, offset crossbar — in copper. The gap is the point: a closed
/// ring reads as a generic app chip, while an interrupted one reads as an
/// instrument dial, which is what the product is.
///
/// Everything is proportional to [size], so the same painter is correct at
/// 22px in a top bar and 96px on a splash.
class AevraMark extends StatelessWidget {
  const AevraMark({super.key, this.size = 26, this.color, this.ringColor});

  final double size;

  /// The monogram colour. Defaults to the copper accent.
  final Color? color;

  /// The aperture ring colour. Defaults to the cool specular tint.
  final Color? ringColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _AevraMarkPainter(
          color: color ?? AevraColors.accent,
          ring: ringColor ?? AevraColors.sheen,
        ),
      ),
    );
  }
}

class _AevraMarkPainter extends CustomPainter {
  _AevraMarkPainter({required this.color, required this.ring});

  final Color color;
  final Color ring;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final center = Offset(size.width / 2, size.height / 2);

    // ---- aperture ring -------------------------------------------------
    // Drawn as two arcs rather than one so the gap sits exactly where the
    // accent tick lands, instead of wherever a single sweep happens to end.
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.055
      ..strokeCap = StrokeCap.round
      ..color = ring.withValues(alpha: 0.30);

    final ringRect = Rect.fromCircle(center: center, radius: s * 0.43);
    // -150° sweeping 250°, leaving a clean notch in the upper right.
    canvas.drawArc(ringRect, _rad(-150), _rad(250), false, ringPaint);

    // The tick closing the notch, in the accent — the one saturated pixel
    // in the mark at small sizes.
    canvas.drawArc(
      ringRect,
      _rad(-62),
      _rad(26),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.055
        ..strokeCap = StrokeCap.round
        ..color = color,
    );

    // ---- the "A" monogram ---------------------------------------------
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.082
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;

    final apex = Offset(center.dx, size.height * 0.30);
    final leftFoot = Offset(size.width * 0.315, size.height * 0.705);
    final rightFoot = Offset(size.width * 0.685, size.height * 0.705);

    canvas.drawPath(
      Path()
        ..moveTo(leftFoot.dx, leftFoot.dy)
        ..lineTo(apex.dx, apex.dy)
        ..lineTo(rightFoot.dx, rightFoot.dy),
      strokePaint,
    );

    // The crossbar is deliberately short and sits low — it keeps the
    // counter open so the glyph stays legible at 20px, where a centred
    // full-width bar closes up into a solid triangle.
    canvas.drawLine(
      Offset(size.width * 0.415, size.height * 0.585),
      Offset(size.width * 0.585, size.height * 0.585),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.058
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: 0.75),
    );
  }

  static double _rad(double degrees) => degrees * math.pi / 180;

  @override
  bool shouldRepaint(covariant _AevraMarkPainter old) =>
      old.color != color || old.ring != ring;
}

/// Mark + wordmark. The wordmark is set in the display serif with wide
/// tracking: at this size the serif reads as an identity rather than as
/// running text, and the tracking is what stops five capitals looking like
/// an acronym.
class AevraWordmark extends StatelessWidget {
  const AevraWordmark({
    super.key,
    this.markSize = 26,
    this.fontSize = 17,
    this.color,
    this.markColor,
  });

  final double markSize;
  final double fontSize;
  final Color? color;
  final Color? markColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AevraMark(size: markSize, color: markColor),
        SizedBox(width: markSize * 0.42),
        Text(
          'VAE',
          style: TextStyle(
            fontFamily: 'PlayfairDisplay',
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            letterSpacing: fontSize * 0.26,
            height: 1,
            color: color ?? AevraColors.text,
          ),
        ),
      ],
    );
  }
}
