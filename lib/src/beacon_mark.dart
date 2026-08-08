import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Beacon's own mark — a dot broadcasting a signal upward — used as the
/// FAB's resting-state icon instead of a generic Material icon. `touch_app`
/// said "tap here"; this says "this is Beacon", which is the point of
/// putting a mark on the one piece of chrome every user of the tool sees.
///
/// Hand-drawn with [CustomPainter] rather than a bundled image asset: it's
/// three primitives (an arc, an arc, a dot), scales to any size without a
/// raster source, and inherits its color from [IconTheme] the same way a
/// built-in [Icon] would, so it drops into [FloatingActionButton.child]
/// (or anywhere else) and automatically matches whatever foreground color
/// the ambient theme computes.
class BeaconMark extends StatelessWidget {
  const BeaconMark({super.key, this.size = 24, this.color});

  /// Side length of the square the mark is drawn into.
  final double size;

  /// Overrides the inherited [IconTheme] color when set.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color resolvedColor = color ?? IconTheme.of(context).color ?? const Color(0xFFFFFFFF);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _BeaconMarkPainter(resolvedColor)),
    );
  }
}

class _BeaconMarkPainter extends CustomPainter {
  _BeaconMarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset dot = Offset(size.width / 2, size.height * 0.72);
    final double dotRadius = size.width * 0.09;
    canvas.drawCircle(dot, dotRadius, Paint()..color = color);

    final Paint arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.09
      ..strokeCap = StrokeCap.round;

    // Two rings, upper half only (math.pi → 2*math.pi sweeps west→north→east
    // in Canvas's y-down angle convention) — waves rising from the dot,
    // rather than a full bullseye, so it reads as "broadcasting" and not
    // "target".
    for (final double radius in <double>[size.width * 0.27, size.width * 0.42]) {
      canvas.drawArc(Rect.fromCircle(center: dot, radius: radius), math.pi, math.pi, false, arcPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BeaconMarkPainter oldDelegate) => oldDelegate.color != color;
}
