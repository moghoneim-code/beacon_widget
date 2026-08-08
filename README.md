# beacon_widget

Tap a widget in your running app and get a precise, machine-readable reference to it on your
clipboard — ready to paste into Cursor, Claude Code, Codex CLI, or any other coding agent.

Instead of describing a widget, point at it. "Make the checkout button rounder" leaves an agent
guessing which of forty buttons you meant; a beacon reference tells it the exact file, line,
resolved theme properties, size, position, and ancestor chain.

```
[ref] ElevatedButton @ lib/features/pos/widgets/checkout_bar.dart:142 · 180×48 · bg=colorScheme.primary · radius=8 · parent Row:130
```

beacon has two halves — an overlay that runs in your app, and a bridge that runs on your
computer — but they ship as one package. There's nothing to install globally.

## Install

```bash
flutter pub add beacon_widget
```

## Usage

**1. Wrap your app once.**

```dart
import 'package:beacon_widget/beacon_widget.dart';

MaterialApp(
  builder: (context, child) => Beacon.attach(child!),
  home: const MyHomePage(),
)
```

This works with any root widget that exposes a `builder` — `MaterialApp`, `CupertinoApp`,
`GetMaterialApp`, and so on.

**2. Run your app with the VM service address written to a file.**

```bash
flutter run --vmservice-out-file=.ref/vm.json
```

**3. Run the bridge in a second terminal, from the same project root.**

```bash
dart run beacon_widget:bridge --vmservice-out-file=.ref/vm.json
```

Leave it running — it reconnects on its own across hot restarts and app relaunches.

**4. Tap the beacon button** in the corner of your app to enter select mode, then tap any widget.
The reference lands on your clipboard. Paste it into your agent.

To combine several widgets into one reference, tap each of them, then tap the **Tap to send N**
pill above the button.

Add `.ref/` to your `.gitignore`.

## What a reference contains

Each selection is copied to the clipboard as a single line and saved in full to
`.ref/sel-<id>.json`, alongside a cropped screenshot of the widget:

| | |
|---|---|
| **Location** | File, line and column where the widget was created |
| **Theme properties** | Resolved values with provenance — `colorScheme.primary` rather than `#FF6750A4`, where beacon can trace it |
| **Geometry** | Size, global position, and the constraints the widget was laid out under |
| **Context** | Enclosing route, enclosing `State` class, and the ancestor widget chain |
| **Screenshot** | The widget itself, cropped from the live frame |

## Bridge options

| Flag | Default | Description |
|---|---|---|
| `--vmservice-out-file=<path>` | `.ref/vm.json` | The file to watch for your app's VM service address. Must match the path passed to `flutter run`. |
| `--format=multiline` | single-line | Splits the reference across several lines. |

Single-line is the default because many chat inputs send the message on a newline. For terminal
agents that handle newlines, `--format=multiline` is easier to read:

```
[ref] ElevatedButton · lib/features/pos/widgets/checkout_bar.dart:142
180×48 · bg=colorScheme.primary · radius=8 · parent Row:130
→ .ref/sel-a3f2.json
```

The bridge overwrites your clipboard on every selection, with no undo — each copy prints a
confirmation so it's never silent. Files in `.ref/` older than an hour are deleted at startup and
every ten minutes while it runs.

### Running the bridge from your IDE

The bridge is a normal terminal command, so the built-in terminal works. For a Run button:

- **Android Studio / IntelliJ** — *Run* → *Edit Configurations…* → **+** → **Shell Script** → set
  *Execution* to *Script text*, with
  `dart run beacon_widget:bridge --vmservice-out-file=.ref/vm.json`, and the working directory to
  your project root.

- **VS Code** — add a task in `.vscode/tasks.json`:

  ```json
  {
    "version": "2.0.0",
    "tasks": [
      {
        "label": "beacon bridge",
        "type": "shell",
        "command": "dart run beacon_widget:bridge --vmservice-out-file=.ref/vm.json",
        "isBackground": true,
        "problemMatcher": [],
        "runOptions": { "runOn": "folderOpen" },
        "presentation": { "panel": "dedicated", "reveal": "silent" }
      }
    ]
  }
  ```

  `runOn: folderOpen` starts it with the project. Prefer it over `preLaunchTask`: the bridge runs
  indefinitely and never signals completion, so VS Code would wait on it forever before launching
  your app.

## Controlling the overlay

`Beacon.attach` hides its own overlay for a second whenever it detects an OS screenshot, so
screenshots you share don't include the dev-tool button.

This is reactive: the OS has already captured the frame by the time the detection fires, so an
isolated screenshot still shows the button once. It helps with bursts of screenshots and screen
recordings, where only the first frame would have included it.

For a screenshot guaranteed to be clean, hide the overlay yourself:

```dart
Beacon.hide();   // take the screenshot
Beacon.show();
```

| Method | Effect |
|---|---|
| `Beacon.hide()` | Hides the button, outline and chip. Also exits select mode. |
| `Beacon.show()` | Shows them again. |
| `Beacon.setVisible(bool)` | Sets visibility directly — convenient for a `Switch` in your own debug settings. |
| `Beacon.visible` | The underlying `ValueNotifier<bool>`, if you want to listen to it. |

```dart
// Wiring it to a toggle in your own debug UI:
ValueListenableBuilder<bool>(
  valueListenable: Beacon.visible,
  builder: (context, visible, _) => Switch(
    value: visible,
    onChanged: Beacon.setVisible,
  ),
)
```

## Debug builds only

`Beacon.attach` returns its child unmodified outside debug builds — no overlay, no VM service
traffic, nothing to strip before shipping.

This is a hard constraint rather than a safety setting. Resolving a widget to a source location
relies on Flutter's `--track-widget-creation` instrumentation, which Flutter only enables in
debug mode. There is no profile or release equivalent, so beacon is a development-time tool by
nature.

## Troubleshooting

**The bridge never connects — it sits on "Watching .ref/vm.json for the VM service address…"**

The `--vmservice-out-file` flag isn't reaching `flutter run`. Launching from your IDE's Run or
Debug button starts `flutter run` without it unless you add it to the run configuration:

- **Android Studio / IntelliJ** — *Run* → *Edit Configurations…* → select your Flutter
  configuration → **Additional run args** → add `--vmservice-out-file=.ref/vm.json`.

  (Note that **Additional run args** and *Attach args* are separate fields. The latter only
  applies to Flutter Attach.)

- **VS Code** — in `.vscode/launch.json`:

  ```json
  {
    "name": "Flutter (with beacon_widget)",
    "type": "dart",
    "request": "launch",
    "args": ["--vmservice-out-file=.ref/vm.json"]
  }
  ```

Use the same path in both places — the flag and the bridge are two ends of one handshake.

**Taps resolve to a widget I didn't expect**

beacon resolves to the nearest widget created in your own code, skipping framework internals and
widgets from packages you depend on. When it can't find one and has to fall back to a less
certain match, the on-screen chip turns amber and the saved JSON records
`"confidence": "low"`.

**Nothing happens when I tap**

Check that select mode is on — the button shows a close icon while it's active.

## Platform support

Android, iOS, macOS, Windows and Linux. Web is not supported.

## License

MIT
