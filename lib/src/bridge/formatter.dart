/// Builds the string that goes on the clipboard for one written selection.
///
/// [payload] is the map [writeSelection] wrote to disk (target, geometry,
/// resolvedProps, ancestors, and a `screenshot` path already resolved).
/// [jsonPath] is that same selection's own `.json` file, referenced at the
/// end so a competent agent can read it for the full payload without
/// polluting the chat (PLAN.md §5.1).
String formatSelection(Map<String, Object?> payload, {required String jsonPath, bool multiline = false}) {
  final Map<String, Object?> target = payload['target'] as Map<String, Object?>? ?? const <String, Object?>{};
  final String widget = (target['widget'] as String?) ?? 'Widget';
  final String file = (target['file'] as String?) ?? '?';
  final Object? line = target['line'];

  final List<String> middle = <String>[
    if (_sizeSegment(payload) case final String s) s,
    if (_propSegment(payload, 'backgroundColor', 'bg') case final String s) s,
    if (_propSegment(payload, 'borderRadius', 'radius') case final String s) s,
    if (_parentSegment(payload) case final String s) s,
  ];

  if (!multiline) {
    final List<String> segments = <String>[...middle, 'details: $jsonPath'];
    return '[ref] $widget @ $file:$line${segments.isEmpty ? '' : ' · ${segments.join(' · ')}'}';
  }

  final StringBuffer buffer = StringBuffer('[ref] $widget · $file:$line');
  if (middle.isNotEmpty) buffer.write('\n${middle.join(' · ')}');
  buffer.write('\n→ $jsonPath');
  return buffer.toString();
}

/// Builds the combined paste string for a broadcast selection stack
/// (PLAN.md §6: "the paste string for a multi-selection lists all three
/// refs"). One compact ref per line — always multiline regardless of the
/// `--format` flag, since several distinct references don't have a
/// sensible single-line form the way one reference's optional detail
/// lines do.
String formatMultiSelection(List<({Map<String, Object?> payload, String jsonPath})> items) {
  return items
      .map((({Map<String, Object?> payload, String jsonPath}) item) {
        final Map<String, Object?> target =
            item.payload['target'] as Map<String, Object?>? ?? const <String, Object?>{};
        final String widget = (target['widget'] as String?) ?? 'Widget';
        final String file = (target['file'] as String?) ?? '?';
        final Object? line = target['line'];
        return '[ref] $widget @ $file:$line · details: ${item.jsonPath}';
      })
      .join('\n');
}

String? _sizeSegment(Map<String, Object?> payload) {
  final Map<String, Object?>? geometry = payload['geometry'] as Map<String, Object?>?;
  final List<Object?>? size = geometry?['size'] as List<Object?>?;
  if (size == null || size.length != 2) return null;
  final num? w = size[0] as num?;
  final num? h = size[1] as num?;
  if (w == null || h == null) return null;
  return '${w.round()}×${h.round()}';
}

String? _propSegment(Map<String, Object?> payload, String propKey, String label) {
  final Map<String, Object?>? props = payload['resolvedProps'] as Map<String, Object?>?;
  final Map<String, Object?>? prop = props?[propKey] as Map<String, Object?>?;
  if (prop == null) return null;
  final String? source = prop['source'] as String?;
  final String? value = prop['value'] as String?;
  if (source == null || value == null) return null;
  final String display = source.startsWith('theme.') ? source.substring('theme.'.length) : value;
  return '$label=$display';
}

String? _parentSegment(Map<String, Object?> payload) {
  final List<Object?>? ancestors = payload['ancestors'] as List<Object?>?;
  if (ancestors == null || ancestors.isEmpty) return null;
  final Map<String, Object?>? first = ancestors.first as Map<String, Object?>?;
  if (first == null) return null;
  return 'parent ${first['widget']}:${first['line']}';
}
