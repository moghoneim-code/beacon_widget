import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'src/ancestors.dart';
import 'src/capture.dart';
import 'src/hit_test.dart';
import 'src/overlay.dart';
import 'src/payload.dart';
import 'src/props.dart';
import 'src/resolver.dart';
export 'src/ancestors.dart' show BeaconAncestor;
export 'src/beacon_mark.dart' show BeaconMark;
export 'src/payload.dart' show BeaconGeometry, BeaconPayload, BeaconTarget;
export 'src/props.dart' show PropValue;
export 'src/resolver.dart' show BeaconLocation, ResolvedTarget;

/// Tap a widget on a physical phone, get a precise reference to it back on
/// the Mac. See PLAN.md for the full design.
class Beacon {
  Beacon._();

  static final GlobalKey _boundaryKey = GlobalKey(debugLabel: 'BeaconRepaintBoundary');

  static const int _maxScreenshotBytes = 200 * 1024;

  /// Whether [BeaconOverlay]'s chrome (FAB, outline, chip, select-mode tap
  /// catcher) should currently be shown. Defaults to visible; toggle with
  /// [show]/[hide]/[setVisible].
  ///
  /// This exists because [BeaconOverlay]'s own screenshot-triggered hiding
  /// is necessarily reactive — it can only hide the chrome *after* the OS
  /// has already rasterized a screenshot's first frame, so a single,
  /// isolated screenshot will still show it once no matter what (see that
  /// class's doc comment for why there's no per-widget way around this).
  /// [hide] is the actual guarantee: flip it off before taking a screenshot
  /// you want clean, back on after — nothing reactive to race.
  static final ValueNotifier<bool> visible = ValueNotifier<bool>(true);

  /// Shorthand for `visible.value = true`.
  static void show() => visible.value = true;

  /// Shorthand for `visible.value = false`. Also exits select mode if it
  /// was on — otherwise the (now invisible) full-screen tap catcher would
  /// keep eating taps meant for the app underneath with no FAB left to
  /// visibly turn it off.
  static void hide() => visible.value = false;

  /// Sets [visible] directly — convenient for wiring to a toggle already in
  /// the app's own UI (e.g. `onChanged: Beacon.setVisible`).
  static void setVisible(bool value) => visible.value = value;

  /// Wraps [child] in the `RepaintBoundary` screenshots are captured from,
  /// plus the select-mode FAB/outline/chip overlay (PLAN.md §6), and
  /// registers the Mac→phone service extensions (PLAN.md §4.2). A no-op
  /// outside debug builds — [child] comes back unmodified.
  static Widget attach(Widget child) {
    if (!kDebugMode) return child;
    _registerExtensions();
    return BeaconOverlay(child: RepaintBoundary(key: _boundaryKey, child: child));
  }

  static bool _extensionsRegistered = false;

  /// Registered now so the return-path features (confirm referent, pulse on
  /// hot reload) don't need a protocol change later — unused in v1
  /// (PLAN.md §4.2).
  static void _registerExtensions() {
    if (_extensionsRegistered) return;
    _extensionsRegistered = true;
    developer.registerExtension('ext.beacon.ping', (String method, Map<String, String> params) async {
      return developer.ServiceExtensionResponse.result('{"status":"ok"}');
    });
    developer.registerExtension('ext.beacon.highlight', (String method, Map<String, String> params) async {
      return developer.ServiceExtensionResponse.result('{"status":"ok"}');
    });
  }

  /// Resolves whatever's at [globalPosition] without building the full
  /// payload — no props, no ancestors, no screenshot. Synchronous, so a
  /// caller painting a same-frame outline (PLAN.md §6) can do so on the
  /// exact frame the tap lands, before the heavier async work in [select]
  /// even starts. Null if the tap didn't land on anything resolvable, or
  /// outside debug builds.
  ///
  /// Pass [within] to hit-test starting from that box's own subtree rather
  /// than the whole view — [BeaconOverlay] always does, scoping every tap
  /// to the app content it wraps so it can never resolve to its own FAB,
  /// outline, chip, or tap-catcher.
  static ResolvedTarget? peek(BuildContext context, Offset globalPosition, {RenderBox? within}) {
    if (!kDebugMode) return null;
    final HitTestResult result = within != null ? hitTestInBox(within, globalPosition) : hitTestAt(context, globalPosition);
    return resolveTapTarget(renderObjectsInPath(result));
  }

  /// Builds a payload for whatever's at [globalPosition] and broadcasts it
  /// over the VM service `Extension` stream as a `beacon.selected` event
  /// (PLAN.md §4.1), for `beacon_bridge` to pick up. Returns the same
  /// payload `captureAt` would, so callers can also inspect it directly.
  static Future<BeaconPayload?> select(BuildContext context, Offset globalPosition, {RenderBox? within}) async {
    final ResolvedTarget? resolved = peek(context, globalPosition, within: within);
    if (resolved == null) return null;
    return selectResolved(context, resolved);
  }

  /// Same as [select], for a target a caller already resolved itself (e.g.
  /// [BeaconOverlay], which resolves once synchronously for the same-frame
  /// outline and reuses that result here rather than hit-testing twice).
  static Future<BeaconPayload> selectResolved(BuildContext context, ResolvedTarget resolved) async {
    final BeaconPayload payload = await captureFrom(context, resolved);
    if (kDebugMode) developer.postEvent('beacon.selected', payload.toEventMap());
    return payload;
  }

  /// Broadcasts several already-built payloads as one `beacon.selectedMany`
  /// event — the selection stack's "tap three things, then combine them"
  /// move (PLAN.md §6). A no-op if [payloads] is empty.
  static void broadcastStack(List<BeaconPayload> payloads) {
    if (!kDebugMode || payloads.isEmpty) return;
    developer.postEvent('beacon.selectedMany', <String, Object?>{
      'v': BeaconPayload.schemaVersion,
      'items': payloads.map((BeaconPayload p) => p.toEventMap()).toList(),
    });
  }

  /// Builds a full payload for whatever's at [globalPosition] in the view
  /// containing [context]. Returns null if the tap didn't land on anything
  /// resolvable, or outside debug builds.
  static Future<BeaconPayload?> captureAt(BuildContext context, Offset globalPosition, {RenderBox? within}) async {
    final ResolvedTarget? resolved = peek(context, globalPosition, within: within);
    if (resolved == null) return null;
    return captureFrom(context, resolved);
  }

  /// Builds a full payload for an already-resolved [resolved] target.
  static Future<BeaconPayload> captureFrom(BuildContext context, ResolvedTarget resolved) async {
    final RenderObject renderObject = resolved.renderObject;
    final Rect? bounds = resolved.bounds;
    final Size size = bounds?.size ?? Size.zero;
    final Offset globalOffset = bounds?.topLeft ?? Offset.zero;
    final String? constraints = renderObject is RenderBox && renderObject.hasSize
        ? renderObject.constraints.toString()
        : null;
    final String? route = ModalRoute.of(context)?.settings.name;

    // Fire the screenshot capture immediately, in parallel with the rest of
    // the payload — never build it lazily on request (PLAN.md §3.6).
    final Future<Uint8List?> screenshotFuture = captureCropped(
      boundaryKey: _boundaryKey,
      targetGlobalBounds: bounds ?? Rect.zero,
    );

    final String id = randomSelectionId();
    Uint8List? screenshotBytes = await screenshotFuture;

    // A cropped button is small; a resolved target that's a whole screen
    // (e.g. a bare ListView) isn't. Downscale rather than split across
    // multiple wire events (PLAN.md §4.1).
    if (screenshotBytes != null && screenshotBytes.length > _maxScreenshotBytes) {
      for (final double pixelRatio in const <double>[0.5, 0.25]) {
        final Uint8List? smaller = await captureCropped(
          boundaryKey: _boundaryKey,
          targetGlobalBounds: bounds ?? Rect.zero,
          pixelRatio: pixelRatio,
        );
        if (smaller == null) break;
        screenshotBytes = smaller;
        if (smaller.length <= _maxScreenshotBytes) break;
      }
    }

    return BeaconPayload(
      id: id,
      capturedAt: DateTime.now(),
      confidence: resolved.confidence,
      target: BeaconTarget(
        widget: resolved.widgetName,
        absFile: resolved.location.file,
        line: resolved.location.line,
        column: resolved.location.column,
        enclosingState: _enclosingStateOf(resolved.element),
        route: route,
      ),
      geometry: BeaconGeometry(size: size, globalOffset: globalOffset, constraints: constraints),
      resolvedProps: resolvedPropsOf(resolved.element),
      ancestors: ancestorsOf(resolved.element),
      screenshotBytes: screenshotBytes,
    );
  }

  static String? _enclosingStateOf(Element element) {
    StatefulElement? found;
    element.visitAncestorElements((Element ancestor) {
      if (ancestor is StatefulElement) {
        found = ancestor;
        return false;
      }
      return true;
    });
    return found?.state.runtimeType.toString();
  }
}
