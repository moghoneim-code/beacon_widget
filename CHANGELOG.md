## 0.3.1

- Add a demo recording to the README and as a pub.dev screenshot: tapping
  widgets in an app running on a phone, then pasting their references into a
  coding agent.

## 0.3.0

The bridge now explains itself when it can't connect, instead of waiting in
silence. Both cases below were hit repeatedly in real use, and neither was
diagnosable from the output.

- If the vmservice-out-file never appears, the bridge prints where the flag
  has to go for the terminal, Android Studio and VS Code — including that
  Android Studio's "Additional run args" and "Attach args" are different
  fields, and that a repo with several packages has more than one run
  configuration to choose between. Printed once, not on a loop.
- If the file is already there but predates the bridge starting, it says so.
  A leftover address points at a port that died with the previous run, so
  connecting fails in a way that looks like a bug in the app.
- Expand the README's troubleshooting with the same three causes, and the
  single check that distinguishes them: whether .ref/vm.json has a fresh
  timestamp after launching.

## 0.2.3

- Replace the example app with a small storefront: a gradient promo banner,
  category filters, a product grid and a checkout bar, built from named
  widgets across several files so the references it produces look like the
  ones you'd get from a real app.
- Add `example/tool/demo_drive.dart`, which scripts a selection run through
  the VM Service — useful for recording a screencast without hand-tapping.

## 0.2.2

- Document the Android Studio / IntelliJ run configuration for the bridge as a
  drop-in `.idea/runConfigurations/*.xml`, rather than a walk through the
  Edit Configurations dialog.
- Warn that a run configuration's login shell can resolve a different `dart`
  than your terminal does. With more than one Flutter SDK installed (fvm plus a
  system-wide install, say), the older one can win and fail to resolve the
  project's dependencies.

## 0.2.1

- Rewrite the README: lead with the paste-into-an-agent workflow, explain how
  widget resolution actually works, and fold the IDE setup for both the app and
  the bridge into one section.

## 0.2.0

The desktop bridge now ships inside this package. `beacon_bridge` is
discontinued — there is nothing to install globally any more.

**Migrating from 0.1.x:** drop `beacon_bridge`, and run the bridge from your
project instead:

```bash
dart pub global deactivate beacon_bridge
dart run beacon_widget:bridge --vmservice-out-file=.ref/vm.json
```

The Flutter API is unchanged; `Beacon.attach` and everything on it keep their
names and behaviour. The paste format and the `.ref/` layout are unchanged too,
so an existing setup keeps working once the command is swapped.

- Add the `bridge` executable, runnable with `dart run beacon_widget:bridge`
  from any project that depends on this package. No `dart pub global activate`,
  no `~/.pub-cache/bin` on your `PATH`.
- Add `package:beacon_widget/bridge.dart`, the bridge's library surface. It is
  deliberately not exported from `beacon_widget.dart` — it targets your
  development machine, not the widget tree.
- Add `meta`, `path` and `vm_service` as dependencies. They are needed to
  resolve the bridge executable from a consuming project, and are not reachable
  from the Flutter API.

## 0.1.1

- Shorten the package description to pub.dev's recommended 60–180 characters.
- Point the repository links at the renamed GitHub repository.
- Set the formatter's page width to 120 to match the codebase, and format
  accordingly.

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
