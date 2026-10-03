import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Shared 64-unit geometry with the editable SVGs in web/public/branding.
/// Creator / Business uses a folded V; Administration uses a vaulted gateway.
class AevraMark extends StatelessWidget {
  const AevraMark(
      {super.key,
      this.size = 26,
      this.color,
      this.ringColor,
      this.admin = false});
  final double size;
  final Color? color;
  // Retained for callers that tint the specular edge during theme transitions.
  final Color? ringColor;
  final bool admin;

  @override
  Widget build(BuildContext context) => Semantics(
        label:
            admin ? 'VAE Administration mark' : 'VAE Creator and Business mark',
        image: true,
        child: SizedBox.square(
            dimension: size,
            child: CustomPaint(
              painter:
                  _VaeMarkPainter(admin: admin, tint: color, edge: ringColor),
            )),
      );
}

class _VaeMarkPainter extends CustomPainter {
  const _VaeMarkPainter({required this.admin, this.tint, this.edge});
  final bool admin;
  final Color? tint;
  final Color? edge;

  List<Color> _colors(List<Color> originals) => tint == null
      ? originals
      : [
          Color.lerp(tint, Colors.white, .55)!,
          tint!,
          Color.lerp(tint, Colors.black, .22)!,
        ];
  Paint _gradient(Offset start, Offset end, List<Color> colors,
          [List<double> stops = const [0, .36, 1]]) =>
      Paint()..shader = ui.Gradient.linear(start, end, _colors(colors), stops);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    final scale = size.shortestSide / 64;
    canvas.translate(
        (size.width - 64 * scale) / 2, (size.height - 64 * scale) / 2);
    canvas.scale(scale);
    final specular = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = (edge ?? Colors.white).withValues(alpha: .5);
    if (admin) {
      final arch = Path()
        ..moveTo(9, 53)
        ..lineTo(9, 26)
        ..cubicTo(9, 13, 19, 6, 32, 6)
        ..cubicTo(45, 6, 55, 13, 55, 26)
        ..lineTo(55, 53)
        ..lineTo(44, 53)
        ..lineTo(44, 26)
        ..cubicTo(44, 20, 39, 17, 32, 17)
        ..cubicTo(25, 17, 20, 20, 20, 26)
        ..lineTo(20, 53)
        ..close();
      canvas.drawPath(
          arch,
          _gradient(
              const Offset(13, 7),
              const Offset(51, 54),
              const [Color(0xFFB1D6FF), Color(0xFF599BFF), Color(0xFF2865D6)],
              const [0, .35, 1]));
      final fold = Path()
        ..moveTo(24, 39)
        ..lineTo(32, 47)
        ..lineTo(40, 39)
        ..lineTo(40, 51)
        ..lineTo(32, 59)
        ..lineTo(24, 51)
        ..close();
      canvas.drawPath(
          fold,
          Paint()
            ..shader = ui.Gradient.linear(
                const Offset(25, 39),
                const Offset(39, 60),
                tint == null
                    ? const [Color(0xFF91BFFF), Color(0xFF3578EA)]
                    : [Color.lerp(tint, Colors.white, .4)!, tint!]));
      canvas.drawPath(
          Path()
            ..moveTo(11, 51)
            ..lineTo(11, 26)
            ..cubicTo(11, 15, 20, 8, 32, 8)
            ..cubicTo(44, 8, 53, 15, 53, 26)
            ..moveTo(26, 42)
            ..lineTo(32, 48)
            ..lineTo(38, 42),
          specular);
    } else {
      canvas.drawPath(
          Path()
            ..moveTo(7, 10)
            ..lineTo(19, 10)
            ..lineTo(36, 43)
            ..lineTo(29, 55)
            ..cubicTo(27, 54, 26, 52, 25, 50)
            ..lineTo(5, 15)
            ..quadraticBezierTo(3, 10, 7, 10)
            ..close(),
          _gradient(
              const Offset(8, 10),
              const Offset(34, 55),
              const [Color(0xFFFF9CAA), Color(0xFFE5485D), Color(0xFF8B1838)],
              const [0, .38, 1]));
      canvas.drawPath(
          Path()
            ..moveTo(45, 10)
            ..lineTo(57, 10)
            ..quadraticBezierTo(61, 10, 59, 15)
            ..lineTo(38, 51)
            ..quadraticBezierTo(35, 57, 29, 55)
            ..lineTo(24, 44)
            ..close(),
          _gradient(const Offset(52, 10), const Offset(27, 55),
              const [Color(0xFFFFB5BF), Color(0xFFED6175), Color(0xFFC72F47)]));
      canvas.drawPath(
          Path()
            ..moveTo(9, 12)
            ..lineTo(18, 12)
            ..lineTo(31, 37)
            ..moveTo(46, 12)
            ..lineTo(56, 12)
            ..lineTo(37, 48),
          specular);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _VaeMarkPainter oldDelegate) =>
      oldDelegate.admin != admin ||
      oldDelegate.tint != tint ||
      oldDelegate.edge != edge;
}

class AevraWordmark extends StatelessWidget {
  const AevraWordmark(
      {super.key,
      this.markSize = 26,
      this.fontSize = 17,
      this.color,
      this.markColor,
      this.admin = false});
  final double markSize;
  final double fontSize;
  final Color? color;
  final Color? markColor;
  final bool admin;

  @override
  Widget build(BuildContext context) => Semantics(
        label: admin ? 'VAE Administration' : 'VAE Creator and Business',
        excludeSemantics: true,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          AevraMark(size: markSize, admin: admin, color: markColor),
          SizedBox(width: markSize * .24),
          Text('VAE',
              style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  color: color ?? Theme.of(context).colorScheme.onSurface,
                  letterSpacing: -fontSize * .035,
                  height: 1.1)),
        ]),
      );
}
