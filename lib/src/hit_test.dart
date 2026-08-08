import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Runs a multi-view-aware hit test at [globalPosition], in the view that
/// contains [context].
HitTestResult hitTestAt(BuildContext context, Offset globalPosition) {
  final int viewId = View.of(context).viewId;
  final HitTestResult result = HitTestResult();
  WidgetsBinding.instance.hitTestInView(result, globalPosition, viewId);
  return result;
}

/// Hit-tests starting from [box]'s own subtree rather than the view root.
///
/// [BeaconOverlay] uses this so a tap only ever resolves against the app
/// content it wraps — never against the overlay's own FAB, outline, chip,
/// or tap-catching [Listener], which sit as *siblings* of that content in
/// the same [Stack], not ancestors of it. Starting the hit test lower in
/// the tree makes them structurally unreachable, rather than trying to
/// filter them back out after the fact.
HitTestResult hitTestInBox(RenderBox box, Offset globalPosition) {
  final BoxHitTestResult result = BoxHitTestResult();
  box.hitTest(result, position: box.globalToLocal(globalPosition));
  return result;
}

/// The [RenderObject]s along [result]'s path, deepest-first. Framework
/// internals (gesture arenas, layers with no render object, etc.) are
/// filtered out here; app-code filtering happens in the resolver.
Iterable<RenderObject> renderObjectsInPath(HitTestResult result) sync* {
  for (final HitTestEntry entry in result.path) {
    final Object target = entry.target;
    if (target is RenderObject) yield target;
  }
}
