Tap a widget on your phone, get a precise, machine-readable reference to it on your computer's
clipboard — ready to paste into Cursor, Claude Code, or Codex CLI.

Point instead of describing: "make the checkout button rounder" makes an agent guess which of
40 buttons you meant. This gets it the exact file, line, resolved theme props, geometry, and
ancestor chain, for free.

## Getting started

Wrap your app once:

```dart
MaterialApp(
  builder: (context, child) => Beacon.attach(child!),
  home: const MyHomePage(),
)
```

Then run [`beacon_bridge`](https://pub.dev/packages/beacon_bridge) on your computer, attached to
the same `flutter run` you're already using:

```bash
flutter run --vmservice-out-file=.ref/vm.json
```

```bash
# Once beacon_bridge is on pub.dev:
dart pub global activate beacon_bridge
beacon_bridge --vmservice-out-file=.ref/vm.json

# Before then, installing from a local checkout:
dart pub global activate --source path /path/to/packages/beacon_bridge
dart pub global run beacon_bridge --vmservice-out-file=.ref/vm.json
```

A path-based activation deliberately doesn't put a `beacon_bridge` command on your `PATH` the
way a pub.dev activation does — see
[`beacon_bridge`'s README](https://pub.dev/packages/beacon_bridge) for why, and use the
`dart pub global run` form until it's published.

Tap the FAB to enter select mode, then tap anything in your app. A `[ref] ...` line lands on
your clipboard — paste it into your agent chat.

### IDE setup (Android Studio / VS Code)

**The `--vmservice-out-file` flag has to actually reach `flutter run`.** Clicking your IDE's
Run/Debug button launches `flutter run` the same way the terminal does — same VM Service, same
USB tunnel — but *without* that flag by default. If `beacon_bridge` never seems to connect (it
just sits on "Watching .ref/vm.json for the VM service address..." forever), this is almost
always why: the file it's watching for is never getting written, because nothing told
`flutter run` to write it.

Fix it once, per run configuration:

- **Android Studio / IntelliJ:** *Run* → *Edit Configurations…* → select your Flutter app's
  configuration → **Additional run args** → add `--vmservice-out-file=.ref/vm.json`.
- **VS Code:** in `.vscode/launch.json`, add an `args` array to the configuration you use to
  launch the app:

  ```json
  {
    "name": "Flutter (with beacon)",
    "type": "dart",
    "request": "launch",
    "args": ["--vmservice-out-file=.ref/vm.json"]
  }
  ```

Either way, use the *same* path you pass to `beacon_bridge --vmservice-out-file=...` on your
computer — they're just two ends of the same handshake.

## Hiding the FAB

`Beacon.attach` also hides its own chrome (FAB, outline, chip) for a second whenever it detects
an OS screenshot, so a screenshot you're sharing (a bug report, docs, Slack) doesn't need the
dev-tool overlay explained away. **This is reactive, not preventative** — the OS has already
rasterized the frame by the time the detection callback fires, so a single, isolated screenshot
will still show the FAB once; it reliably helps with a burst of screenshots or a screen
recording, where only the very first frame would've shown it.

If you want a screenshot guaranteed clean — no race, no "the first one still shows it" — hide
the chrome yourself first:

```dart
Beacon.hide();   // take your screenshot
Beacon.show();   // bring the FAB back
```

`Beacon.setVisible(bool)` is the same thing as a single call, handy for wiring to a toggle
already in your own debug UI. Hiding also exits select mode if it was on, so there's never an
invisible tap-catcher left eating taps meant for your app.

## Debug-only, by design

`Beacon.attach` is a genuine no-op outside debug builds — it returns its child unmodified, no
overlay, no VM service traffic. This isn't just a safety guard: it can't work any other way.
Widget resolution
depends on Flutter's `--track-widget-creation` instrumentation (the `file:line` every widget
gets tagged with when building in debug mode), which Flutter itself only enables for debug
builds. There is no profile/release equivalent to fall back to — this is inherently, and only
ever, a development-time tool.

## Additional information

See `PLAN.md` in this repo for the full design and the phase-by-phase implementation notes.
