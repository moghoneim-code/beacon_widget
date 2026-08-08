import 'package:flutter/widgets.dart';

/// An app-authored source location.
class BeaconLocation {
  const BeaconLocation({required this.file, required this.line, required this.column});

  /// Absolute filesystem path (no `file://` scheme).
  final String file;
  final int line;
  final int column;

  @override
  String toString() => '$file:$line:$column';
}

/// The outcome of resolving a tap to a widget the developer actually wrote.
class ResolvedTarget {
  const ResolvedTarget({
    required this.element,
    required this.renderObject,
    required this.location,
    required this.confidence,
  });

  final Element element;
  final RenderObject renderObject;
  final BeaconLocation location;

  /// `'high'`: found by walking up from the tap to the nearest ancestor
  /// whose creation location isn't inside `package:flutter/` or a pub
  /// package. `'low'`: nothing in the hit path resolved that way; this is
  /// just the deepest hit-path entry with *any* creation location.
  final String confidence;

  String get widgetName => element.widget.runtimeType.toString();

  /// Global-coordinate bounds, or null if [renderObject] never got a
  /// layout size (defensive — every widget with a creation location has
  /// gone through layout by the time it can be hit-tested, but the type
  /// system doesn't know that).
  Rect? get bounds {
    final RenderObject ro = renderObject;
    if (ro is RenderBox && ro.hasSize) return ro.localToGlobal(Offset.zero) & ro.size;
    return null;
  }
}

const List<String> _denylistedPathSegments = <String>[
  'packages/flutter/',
  '/.pub-cache/',
  '/hosted/pub.dev/',
];

bool isDenylistedPath(String file) => _denylistedPathSegments.any(file.contains);

/// Wrapper types that are never what the developer meant to tap, even when
/// their own creation location happens to be app code (a bespoke gesture
/// wrapper, say). See PLAN.md §3.2.
const Set<String> neverTheTarget = <String>{
  'Semantics',
  'RawGestureDetector',
  'Listener',
  'MouseRegion',
  'IgnorePointer',
  'RepaintBoundary',
  '_InkFeatures',
  'AnimatedBuilder',
};

const int _maxChainDepth = 80;

/// The immediate creation location of [element] — no walk-up.
///
/// `InspectorSerializationDelegate` is `@visibleForTesting` upstream (see
/// PLAN.md Phase 0 notes), which is why this stays private: everything else
/// in this file only calls it as one step of a walk it controls itself,
/// never hands its result back as a final answer on its own.
BeaconLocation? locationOf(Element element) {
  try {
    final Map<String, Object?> json = element.toDiagnosticsNode().toJsonMap(
      InspectorSerializationDelegate(groupName: 'beacon', service: WidgetInspectorService.instance),
    );
    final Map<String, Object?>? loc = json['creationLocation'] as Map<String, Object?>?;
    if (loc == null) return null;
    final String? file = loc['file'] as String?;
    final int? line = loc['line'] as int?;
    final int? column = loc['column'] as int?;
    if (file == null || line == null || column == null) return null;
    return BeaconLocation(file: Uri.parse(file).path, line: line, column: column);
  } catch (_) {
    return null;
  }
}

/// Walks up from [start] (inclusive) to the nearest ancestor whose creation
/// location is app code, skipping [neverTheTarget] wrappers along the way.
///
/// This is the same algorithm `WidgetInspectorService`'s own "selected
/// summary widget" uses internally — confirmed against the SDK source
/// during the Phase 0 spike and validated on-device. Reimplemented directly
/// here (rather than via `selection` + `getSelectedSummaryWidget`) so the
/// resolved [Element] itself comes back, not just a JSON description of it.
({Element element, BeaconLocation location})? nearestAppCodeAncestor(Element start) {
  final List<Element> chain = start.debugGetDiagnosticChain();
  for (final Element node in chain.take(_maxChainDepth)) {
    if (node.debugIsDefunct) continue;
    final BeaconLocation? location = locationOf(node);
    if (location == null || isDenylistedPath(location.file)) continue;
    if (neverTheTarget.contains(node.widget.runtimeType.toString())) continue;
    return (element: node, location: location);
  }
  return null;
}

/// Resolves a hit-test path to the widget the developer actually tapped.
///
/// Walks [renderObjects] deepest-first; for each entry, walks up to the
/// nearest app-code ancestor and returns the first one found. Falls back to
/// the deepest entry with *any* location, marked `confidence: 'low'`, if
/// nothing in the whole path resolves to app code.
ResolvedTarget? resolveTapTarget(Iterable<RenderObject> renderObjects) {
  ResolvedTarget? fallback;

  for (final RenderObject renderObject in renderObjects) {
    final Object? creator = renderObject.debugCreator;
    if (creator is! DebugCreator) continue;
    final Element root = creator.element;
    if (root.debugIsDefunct) continue;

    if (fallback == null) {
      final BeaconLocation? raw = locationOf(root);
      if (raw != null) {
        fallback = ResolvedTarget(
          element: root,
          renderObject: root.renderObject ?? renderObject,
          location: raw,
          confidence: 'low',
        );
      }
    }

    final resolved = nearestAppCodeAncestor(root);
    if (resolved != null) {
      return ResolvedTarget(
        element: resolved.element,
        renderObject: resolved.element.renderObject ?? renderObject,
        location: resolved.location,
        confidence: 'high',
      );
    }
  }

  return fallback;
}
