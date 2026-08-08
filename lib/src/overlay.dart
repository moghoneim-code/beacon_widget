import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:no_screenshot/no_screenshot.dart';
import 'package:no_screenshot/screenshot_snapshot.dart';

import '../beacon_widget.dart';
import 'payload.dart';

// This file's `dart:io` use (for the Platform.is* checks below) means the
// `beacon` package doesn't support Flutter Web — an acceptable trade-off
// for a tool whose entire premise is a physical phone in hand (PLAN.md's
// Flow diagram), not a web target that was never in scope. (no_screenshot
// itself does ship a web implementation; only this guard doesn't reach it.)

/// The chip is the product (PLAN.md §6): a draggable FAB toggles select
/// mode; while it's on, taps resolve synchronously (via [Beacon.peek]) so
/// the outline and chip paint on the same frame as the tap, while the full
/// payload — props, ancestors, screenshot — builds and broadcasts
/// underneath asynchronously. Long-pressing the FAB broadcasts everything
/// tapped since the last broadcast as one combined `beacon.selectedMany`
/// event.
class BeaconOverlay extends StatefulWidget {
  const BeaconOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<BeaconOverlay> createState() => _BeaconOverlayState();
}

class _BeaconOverlayState extends State<BeaconOverlay> {
  static const int _maxStack = 5;
  static const Duration _dismissAfter = Duration(seconds: 2);
  static const Duration _hideChromeAfter = Duration(seconds: 1);

  final GlobalKey _stackKey = GlobalKey();
  final GlobalKey _childKey = GlobalKey();
  final List<BeaconPayload> _stack = <BeaconPayload>[];

  bool _selectMode = false;
  Rect? _outlineBounds;
  String? _chipText;
  bool _chipLowConfidence = false;
  bool _hideChrome = false;
  Timer? _dismissTimer;
  Timer? _hideChromeTimer;

  StreamSubscription<ScreenshotSnapshot>? _screenshotSubscription;

  @override
  void initState() {
    super.initState();
    // no_screenshot ships real Android/iOS/macOS implementations (macOS via
    // NSMetadataQuery + NSWorkspace + pasteboard polling — no extra
    // permissions). Elsewhere — Linux/Windows/Web have plugin scaffolding
    // registered but aren't in the package's own supported-features table,
    // and there's no native implementation at all inside `flutter test` —
    // failures here surface asynchronously (a stream error, or a rejected
    // Future from startScreenshotListening()), not as a synchronous throw a
    // try/catch around this block would catch. Both are handled explicitly
    // below instead: a missing or failing listener should never take the
    // rest of the overlay down with it.
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      _screenshotSubscription = NoScreenshot.instance.screenshotStream.listen((ScreenshotSnapshot snapshot) {
        if (snapshot.wasScreenshotTaken) _handleScreenshotDetected();
      }, onError: (Object _) {});
      unawaited(NoScreenshot.instance.startScreenshotListening().catchError((Object _) {}));
    }
    Beacon.visible.addListener(_handleVisibilityChanged);
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _hideChromeTimer?.cancel();
    if (_screenshotSubscription != null) {
      _screenshotSubscription!.cancel();
      unawaited(NoScreenshot.instance.stopScreenshotListening().catchError((Object _) {}));
    }
    Beacon.visible.removeListener(_handleVisibilityChanged);
    super.dispose();
  }

  /// [Beacon.hide]/[Beacon.show] flip [Beacon.visible] directly rather than
  /// calling back into this state, so this listener is the one place that
  /// reacts. Hiding also exits select mode: otherwise the full-screen tap
  /// catcher would keep intercepting taps meant for the app underneath
  /// while invisible, with no FAB left for the developer to notice and turn
  /// it off.
  void _handleVisibilityChanged() {
    if (!mounted) return;
    setState(() {
      if (!Beacon.visible.value && _selectMode) {
        _selectMode = false;
        _outlineBounds = null;
        _chipText = null;
      }
    });
  }

  /// Reacts to an OS screenshot by hiding every Beacon element on screen —
  /// FAB, outline, chip — so a developer sharing that screenshot (a bug
  /// report, docs, a Slack message) doesn't have to explain away dev-tool
  /// chrome.
  ///
  /// Necessarily reactive, not preventative, and worth being honest about:
  /// Flutter composites the whole app into one surface, and the OS has
  /// already rasterized it by the time this callback fires — there is no
  /// per-widget way to opt out of a screenshot the way [Beacon]'s own
  /// payload captures do (their `RepaintBoundary` sits inside this overlay,
  /// not around it — see `Beacon.attach`, which is a real, structural
  /// guarantee, not a best-effort one like this). What this reliably does
  /// help with: a burst of several screenshots, or a screen recording,
  /// where only the very first frame would have shown Beacon's chrome.
  void _handleScreenshotDetected() {
    _hideChromeTimer?.cancel();
    setState(() => _hideChrome = true);
    _hideChromeTimer = Timer(_hideChromeAfter, () {
      if (mounted) setState(() => _hideChrome = false);
    });
  }

  void _toggleSelectMode() {
    setState(() {
      _selectMode = !_selectMode;
      // Exiting select mode leaves a stale outline pointing at whatever was
      // last tapped, and the FAB's own icon/color flip (touch_app→close,
      // default→red) turns out not to read as confirmation on its own — a
      // developer tapping it can't tell whether the tap actually landed.
      // The chip is the one feedback channel already proven visible (it's
      // what confirms every other action here), so reuse it instead of
      // inventing a second mechanism.
      _outlineBounds = null;
      _chipText = _selectMode ? 'Select mode on' : 'Select mode off';
      _chipLowConfidence = false;
    });
    _armDismissTimer();
  }

  Future<void> _handleTap(BuildContext context, Offset globalPosition) async {
    // Resolve scoped to widget.child's own subtree — never the whole view —
    // so this can never land on the overlay's own FAB, outline, chip, or
    // tap-catcher, which are siblings of widget.child in the Stack below,
    // not ancestors of it.
    final RenderObject? childRenderObject = _childKey.currentContext?.findRenderObject();
    if (childRenderObject is! RenderBox) return;
    final ResolvedTarget? resolved = Beacon.peek(context, globalPosition, within: childRenderObject);
    if (resolved == null) return;

    // Everything up to here is synchronous — the outline and chip land on
    // the same frame as the tap. The full payload (props, ancestors,
    // screenshot) is built and broadcast below, asynchronously.
    setState(() {
      _outlineBounds = _toLocal(resolved.bounds);
      _chipText = '${resolved.widgetName} · ${relativizePath(resolved.location.file)}:${resolved.location.line}';
      _chipLowConfidence = resolved.confidence == 'low';
    });
    _armDismissTimer();

    final BeaconPayload payload = await Beacon.selectResolved(context, resolved);
    if (mounted) {
      setState(() {
        _stack.add(payload);
        if (_stack.length > _maxStack) _stack.removeAt(0);
      });
    }
  }

  void _handleBroadcastStack() {
    if (_stack.isEmpty) return;
    final int count = _stack.length;
    Beacon.broadcastStack(List<BeaconPayload>.of(_stack));
    setState(() {
      _stack.clear();
      _outlineBounds = null;
      _chipText = 'Sent $count refs';
      _chipLowConfidence = false;
    });
    _armDismissTimer();
  }

  void _armDismissTimer() {
    _dismissTimer?.cancel();
    _dismissTimer = Timer(_dismissAfter, () {
      if (mounted) setState(() => _outlineBounds = _chipText = null);
    });
  }

  /// Combines the two independent reasons chrome might be hidden right now:
  /// a just-detected screenshot ([_hideChrome], transient) and an explicit
  /// [Beacon.hide] call (persistent until [Beacon.show]).
  bool get _chromeVisible => Beacon.visible.value && !_hideChrome;

  Rect? _toLocal(Rect? globalRect) {
    if (globalRect == null) return null;
    final RenderObject? renderObject = _stackKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox) return null;
    return (renderObject.globalToLocal(globalRect.topLeft)) & globalRect.size;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      key: _stackKey,
      children: <Widget>[
        KeyedSubtree(key: _childKey, child: widget.child),
        if (_selectMode)
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (PointerDownEvent event) => _handleTap(context, event.position),
            ),
          ),
        if (_chromeVisible && _outlineBounds != null)
          Positioned.fromRect(
            rect: _outlineBounds!,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(border: Border.all(color: Colors.blueAccent, width: 2)),
              ),
            ),
          ),
        if (_chromeVisible && _chipText != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 100,
            child: IgnorePointer(
              child: Center(
                child: _SelectionChip(text: _chipText!, lowConfidence: _chipLowConfidence),
              ),
            ),
          ),
        if (_chromeVisible)
          _DraggableFab(
            selectMode: _selectMode,
            stackCount: _stack.length,
            onTap: _toggleSelectMode,
            onBroadcast: _handleBroadcastStack,
          ),
      ],
    );
  }
}

class _SelectionChip extends StatelessWidget {
  const _SelectionChip({required this.text, required this.lowConfidence});

  final String text;
  final bool lowConfidence;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: lowConfidence ? Colors.amber.shade800 : Colors.black87,
      borderRadius: BorderRadius.circular(20),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

/// A [FloatingActionButton] the developer can drag out of the way, since it
/// sits on top of whatever app it's dropped into (PLAN.md §6: "must not eat
/// the app's own gestures when select mode is off" — dragging it clear of
/// content it'd otherwise cover is part of that).
///
/// The send-stack pill (see [_SendStackPill]) is its own tappable target
/// for [onBroadcast], deliberately separate from the FAB's drag handling: a
/// long-press on the same [GestureDetector] as `onPanUpdate` loses to the
/// pan recognizer on any incidental pointer movement — a real bug hit
/// testing this on-device, where the long-press routinely lost the gesture
/// arena to the drag.
class _DraggableFab extends StatefulWidget {
  const _DraggableFab({
    required this.selectMode,
    required this.stackCount,
    required this.onTap,
    required this.onBroadcast,
  });

  final bool selectMode;
  final int stackCount;
  final VoidCallback onTap;
  final VoidCallback onBroadcast;

  @override
  State<_DraggableFab> createState() => _DraggableFabState();
}

class _DraggableFabState extends State<_DraggableFab> {
  Offset _insetFromBottomRight = const Offset(16, 96);

  @override
  Widget build(BuildContext context) {
    final Size screen = MediaQuery.sizeOf(context);
    return Positioned(
      right: _insetFromBottomRight.dx,
      bottom: _insetFromBottomRight.dy,
      // A Stack sized only by the FAB (its one non-Positioned child) hit-
      // tests against that 56x56 box regardless of Clip.none — overflow
      // painting isn't overflow hit-testing, so the pill above it would
      // paint but never receive taps. Sizing the box explicitly to cover
      // both, and making the FAB a Positioned child too, fixes that; found
      // via a widget test where a tap square on the pill's own text still
      // fell through to the select-mode catcher behind it.
      child: SizedBox(
        width: 200,
        height: 132,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned(
              right: 0,
              bottom: 0,
              child: GestureDetector(
                onPanUpdate: (DragUpdateDetails details) {
                  setState(() {
                    _insetFromBottomRight = Offset(
                      (_insetFromBottomRight.dx - details.delta.dx).clamp(0, screen.width - 56),
                      (_insetFromBottomRight.dy - details.delta.dy).clamp(0, screen.height - 56),
                    );
                  });
                },
                child: FloatingActionButton(
                  heroTag: 'beacon-fab',
                  backgroundColor: widget.selectMode ? Colors.redAccent : null,
                  onPressed: widget.onTap,
                  child: widget.selectMode ? const Icon(Icons.close) : const BeaconMark(),
                ),
              ),
            ),
            if (widget.stackCount > 0)
              Positioned(
                right: 0,
                bottom: 64,
                child: _SendStackPill(count: widget.stackCount, onTap: widget.onBroadcast),
              ),
          ],
        ),
      ),
    );
  }
}

/// Replaces what used to be a bare-number badge overlapping the FAB's
/// corner: a 20px `CircleAvatar` that was genuinely hard to hit precisely
/// (found hitting this on-device) and, worse, didn't say what tapping it
/// *did* — a number alone doesn't read as "tap here to send". Sitting above
/// the FAB instead of clipping its corner gives it a tap target several
/// times larger, and the label spells out the action instead of leaving it
/// to be inferred. Auto-send-per-tap is unchanged; this only makes the
/// separate "combine and send the stack" action easier to find and hit.
class _SendStackPill extends StatelessWidget {
  const _SendStackPill({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.orange.shade700,
      borderRadius: BorderRadius.circular(20),
      elevation: 4,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            'Tap to send $count',
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
