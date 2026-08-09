import 'package:flutter/widgets.dart';

/// Beacon's mark: a crosshair around a filled centre.
///
/// Used as the overlay button's resting-state icon, and drawn to the same
/// proportions as `doc/logo.svg` so the button and the project's logo read
/// as one thing.
///
/// The metaphor is pointing, not broadcasting — the button puts you into
/// select mode so you can pick a widget out of the tree. An earlier version
/// drew concentric arcs over a dot and was indistinguishable from a wifi
/// icon, which suggested the opposite of what the button does.
///
/// Hand-drawn with [CustomPainter] rather than a bundled asset: it is four
/// strokes and a dot, scales to any size without a raster source, and
/// inherits its colour from [IconTheme] the way a built-in [Icon] would, so
/// it drops into [FloatingActionButton.child] and picks up whatever
/// foreground colour the ambient theme computes.
class BeaconMark extends StatelessWidget {
  const BeaconMark({super.key, this.size = 24, this.color});

  /// Side length of the square the mark is drawn into.
  final double size;

  /// Overrides the inherited [IconTheme] colour when set.
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

  // Fractions of the side length, taken from doc/logo.svg (a 512pt canvas)
  // so the two stay in step if either is retouched.
  static const double _ring = 112 / 512;
  static const double _stroke = 30 / 512;
  static const double _dot = 38 / 512;
  static const double _tickInner = 108 / 512;
  static const double _tickOuter = 160 / 512;

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.shortestSide;
    final Offset c = Offset(size.width / 2, size.height / 2);

    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * _stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(c, s * _ring, stroke);

    // Four ticks on the axes. They start just inside the ring so the mark
    // stays one connected shape at small sizes, where a gap turns to mush.
    final double inner = s * _tickInner;
    final double outer = s * _tickOuter;
    for (final Offset axis in const <Offset>[Offset(0, -1), Offset(0, 1), Offset(-1, 0), Offset(1, 0)]) {
      canvas.drawLine(c + axis * inner, c + axis * outer, stroke);
    }

    canvas.drawCircle(c, s * _dot, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _BeaconMarkPainter oldDelegate) => oldDelegate.color != color;
}
