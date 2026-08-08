## 0.1.0

Initial release.

- `Beacon.attach(child)` — one-line install, wraps your app in the select-mode
  overlay. A genuine no-op outside debug builds: returns `child` unmodified,
  with no overlay and no VM service traffic.
- Tap-to-resolve: resolves a tapped widget to the exact `file:line` it was
  created at, using Flutter's `--track-widget-creation` instrumentation, and
  walks past framework internals to the nearest widget in your own code.
- Rich payload per selection: resolved theme properties (with provenance — it
  reports `colorScheme.primary` rather than a raw hex value where it can),
  geometry, constraints, enclosing route and state, ancestor chain, and a
  cropped screenshot of the widget.
- Selection stack: tap several widgets, then send them as one combined
  reference.
- `Beacon.hide()` / `Beacon.show()` / `Beacon.setVisible(bool)` to control the
  on-screen overlay, plus automatic (best-effort) hiding when a screenshot is
  detected.
- Broadcasts selections over the Dart VM Service for
  [`beacon_bridge`](https://pub.dev/packages/beacon_bridge) to pick up.

Requires `beacon_bridge` running on your development machine to get selections
onto your clipboard.
