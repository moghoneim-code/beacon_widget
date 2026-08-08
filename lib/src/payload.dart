import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'ancestors.dart';
import 'props.dart';

/// Strips everything up to and including the last `/lib/` so agents get the
/// project-relative form (PLAN.md §3.3) instead of a full device path.
/// Derived per-call from [absFile] itself, not cached — a monorepo can have
/// more than one `lib/` root, and this is cheap enough not to matter.
String relativizePath(String absFile) {
  const String marker = '/lib/';
  final int index = absFile.lastIndexOf(marker);
  if (index == -1) return absFile;
  return absFile.substring(index + 1);
}

class BeaconTarget {
  const BeaconTarget({
    required this.widget,
    required this.absFile,
    required this.line,
    required this.column,
    this.enclosingState,
    this.route,
  });

  final String widget;
  final String absFile;
  final int line;
  final int column;
  final String? enclosingState;
  final String? route;

  String get file => relativizePath(absFile);

  Map<String, Object?> toJson() => <String, Object?>{
    'widget': widget,
    'file': file,
    'absFile': absFile,
    'line': line,
    'column': column,
    if (enclosingState != null) 'enclosingState': enclosingState,
    if (route != null) 'route': route,
  };
}

class BeaconGeometry {
  const BeaconGeometry({required this.size, required this.globalOffset, this.constraints});

  final Size size;
  final Offset globalOffset;
  final String? constraints;

  Map<String, Object?> toJson() => <String, Object?>{
    'size': <double>[size.width, size.height],
    'globalOffset': <double>[globalOffset.dx, globalOffset.dy],
    if (constraints != null) 'constraints': constraints,
  };
}

class BeaconPayload {
  const BeaconPayload({
    required this.id,
    required this.capturedAt,
    required this.confidence,
    required this.target,
    required this.geometry,
    required this.resolvedProps,
    required this.ancestors,
    this.screenshotBytes,
  });

  static const int schemaVersion = 1;

  final String id;
  final DateTime capturedAt;

  /// `'high'` or `'low'` — see `resolver.dart`.
  final String confidence;

  final BeaconTarget target;
  final BeaconGeometry geometry;
  final Map<String, PropValue> resolvedProps;
  final List<BeaconAncestor> ancestors;

  /// Raw PNG bytes. The `.ref/sel-<id>.png` path in the JSON schema is
  /// written by the CLI once it receives [toEventMap]'s base64 form — this
  /// package never touches the filesystem itself.
  final List<int>? screenshotBytes;

  Map<String, Object?> toJson() => <String, Object?>{
    'v': schemaVersion,
    'id': id,
    'capturedAt': capturedAt.toUtc().toIso8601String(),
    'confidence': confidence,
    'target': target.toJson(),
    'geometry': geometry.toJson(),
    'resolvedProps': resolvedProps.map((String key, PropValue value) => MapEntry<String, Object?>(key, value.toJson())),
    'ancestors': ancestors
        .map(
          (BeaconAncestor a) => <String, Object?>{
            'widget': a.widget,
            'file': relativizePath(a.location.file),
            'line': a.location.line,
          },
        )
        .toList(),
    if (screenshotBytes != null) 'screenshotSizeBytes': screenshotBytes!.length,
  };

  /// [toJson] plus the screenshot as base64, for the `beacon.selected` VM
  /// service event (PLAN.md §4.1) — `developer.postEvent` payloads travel
  /// as a single JSON-able map, so the image rides along in the same event
  /// rather than a separate message.
  Map<String, Object?> toEventMap() => <String, Object?>{
    ...toJson(),
    if (screenshotBytes != null) 'screenshotBase64': base64Encode(screenshotBytes!),
  };
}

String randomSelectionId() {
  final Random random = Random();
  return List<String>.generate(4, (_) => random.nextInt(16).toRadixString(16)).join();
}
