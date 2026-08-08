import 'package:flutter/widgets.dart';

import 'resolver.dart';

/// One entry in a target's ancestor chain, app-code only.
class BeaconAncestor {
  const BeaconAncestor({required this.widget, required this.location});

  final String widget;
  final BeaconLocation location;
}

/// Up to [max] distinct app-code ancestors of [target], nearest first.
///
/// Continues the same walk `resolver.dart` uses to find [target] itself,
/// skipping `package:flutter/`, pub packages, and [neverTheTarget] wrappers,
/// and collapsing consecutive hits that land on the same source line (many
/// framework-internal elements in a row commonly resolve to the one widget
/// that created them).
List<BeaconAncestor> ancestorsOf(Element target, {int max = 3}) {
  final List<BeaconAncestor> result = <BeaconAncestor>[];
  final List<Element> chain = target.debugGetDiagnosticChain();
  BeaconLocation? lastLocation;

  for (final Element node in chain.skip(1)) {
    if (result.length >= max) break;
    if (node.debugIsDefunct) continue;

    final BeaconLocation? location = locationOf(node);
    if (location == null || isDenylistedPath(location.file)) continue;
    final String widgetName = node.widget.runtimeType.toString();
    if (neverTheTarget.contains(widgetName)) continue;

    if (lastLocation != null && lastLocation.file == location.file && lastLocation.line == location.line) {
      continue;
    }
    lastLocation = location;
    result.add(BeaconAncestor(widget: widgetName, location: location));
  }

  return result;
}
