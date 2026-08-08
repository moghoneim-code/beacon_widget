import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Captures the whole screen behind [boundaryKey] and crops to
/// [targetGlobalBounds] (inflated by [padding] logical pixels). Returns PNG
/// bytes, or null if the boundary isn't mounted or the crop is empty.
///
/// An arbitrary [RenderObject] isn't a repaint boundary, so it can't be
/// imaged directly (PLAN.md §3.5) — [boundaryKey] must be attached to a
/// `RepaintBoundary` wrapping the whole app (see `Beacon.attach`).
///
/// This is async (~15-50ms GPU readback). Call it eagerly, at tap time, in
/// parallel with the rest of the payload — never lazily on demand.
Future<Uint8List?> captureCropped({
  required GlobalKey boundaryKey,
  required Rect targetGlobalBounds,
  double pixelRatio = 1.0,
  double padding = 8,
}) async {
  final RenderObject? boundaryRenderObject = boundaryKey.currentContext?.findRenderObject();
  if (boundaryRenderObject is! RenderRepaintBoundary) return null;
  if (targetGlobalBounds.isEmpty) return null;

  final ui.Image fullImage = await boundaryRenderObject.toImage(pixelRatio: pixelRatio);
  try {
    final Offset boundaryOrigin = boundaryRenderObject.localToGlobal(Offset.zero);
    final Rect fullImageBounds = Rect.fromLTWH(0, 0, fullImage.width / pixelRatio, fullImage.height / pixelRatio);
    final Rect cropRect = targetGlobalBounds.shift(-boundaryOrigin).inflate(padding).intersect(fullImageBounds);
    if (cropRect.isEmpty) return null;

    final int width = (cropRect.width * pixelRatio).round();
    final int height = (cropRect.height * pixelRatio).round();
    if (width <= 0 || height <= 0) return null;

    final Rect srcRect = Rect.fromLTWH(
      cropRect.left * pixelRatio,
      cropRect.top * pixelRatio,
      width.toDouble(),
      height.toDouble(),
    );
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    canvas.drawImageRect(fullImage, srcRect, Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), Paint());
    final ui.Picture picture = recorder.endRecording();
    final ui.Image cropped = await picture.toImage(width, height);
    try {
      final ByteData? bytes = await cropped.toByteData(format: ui.ImageByteFormat.png);
      return bytes?.buffer.asUint8List();
    } finally {
      cropped.dispose();
    }
  } finally {
    fullImage.dispose();
  }
}
