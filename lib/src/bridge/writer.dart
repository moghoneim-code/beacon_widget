import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// What got written to disk for one `beacon.selected` event.
class WrittenSelection {
  const WrittenSelection({required this.id, required this.jsonPath, required this.pngPath, required this.payload});

  final String id;

  /// Relative to [refDir]'s parent (the project root), e.g. `.ref/sel-a3f2.json`.
  final String jsonPath;

  /// Same, or null if the event carried no screenshot.
  final String? pngPath;

  /// The map that was written to [jsonPath] — the wire payload with
  /// `screenshotBase64` swapped for a `screenshot` path, matching the
  /// schema in PLAN.md §3.3.
  final Map<String, Object?> payload;
}

/// Writes `sel-<id>.json` and `sel-<id>.png` into [refDir] for [payload] (a
/// decoded `beacon.selected` event) and returns what was written.
WrittenSelection writeSelection(Map<String, Object?> payload, {required Directory refDir}) {
  if (!refDir.existsSync()) refDir.createSync(recursive: true);

  final String id = (payload['id'] as String?) ?? DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final String projectRoot = refDir.parent.path;

  final Map<String, Object?> json = Map<String, Object?>.of(payload)
    ..remove('screenshotBase64')
    ..remove('screenshotSizeBytes');

  String? pngPath;
  final String? screenshotBase64 = payload['screenshotBase64'] as String?;
  if (screenshotBase64 != null && screenshotBase64.isNotEmpty) {
    final File pngFile = File(p.join(refDir.path, 'sel-$id.png'));
    pngFile.writeAsBytesSync(base64Decode(screenshotBase64));
    pngPath = p.relative(pngFile.path, from: projectRoot);
    json['screenshot'] = pngPath;
  }

  final File jsonFile = File(p.join(refDir.path, 'sel-$id.json'));
  jsonFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(json));

  return WrittenSelection(
    id: id,
    jsonPath: p.relative(jsonFile.path, from: projectRoot),
    pngPath: pngPath,
    payload: json,
  );
}
