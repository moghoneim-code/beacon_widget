<img src="https://raw.githubusercontent.com/moghoneim-code/beacon_widget/main/doc/logo.png" width="88" alt="beacon">

# beacon_widget

Tap a widget in your running Flutter app. Get an exact reference to it on your clipboard:

```
[ref] ElevatedButton @ lib/features/pos/widgets/checkout_bar.dart:142 · 180×48 · bg=colorScheme.primary · radius=8 · parent Row:130 · details: .ref/sel-a3f2.json
```

Paste that into Cursor, Claude Code, Codex CLI, or any other coding agent.

![Tapping widgets in an app running on a phone, then pasting their references into a coding agent](https://raw.githubusercontent.com/moghoneim-code/beacon_widget/main/doc/demo.gif)

## Why

Describing a widget to an agent is lossy. "Make the checkout button rounder" leaves it guessing
which of forty buttons you meant, then grepping for a plausible one. Pointing is exact:

> Make this rounder and full-width on tablets.
> `[ref] ElevatedButton @ lib/features/pos/widgets/checkout_bar.dart:142 · 180×48 · bg=colorScheme.primary · radius=8 · parent Row:130`

The agent gets the file, the line, the resolved theme token, the size, and what it sits inside —
without opening a thing.

## Quick start

**1. Add the package.**

```bash
flutter pub add beacon_widget
```

**2. Wrap your app once.**

```dart
import 'package:beacon_widget/beacon_widget.dart';

MaterialApp(
  builder: (context, child) => Beacon.attach(child!),
  home: const MyHomePage(),
)
```

Any root widget with a `builder` works — `MaterialApp`, `CupertinoApp`, `GetMaterialApp`.

**3. Run your app, and the bridge, in two terminals.**

```bash
flutter run --vmservice-out-file=.ref/vm.json
```

```bash
dart run beacon_widget:bridge --vmservice-out-file=.ref/vm.json
```

The two `--vmservice-out-file` paths must match — that file is how the bridge finds your app.
Leave the bridge running; it reconnects across hot restarts and relaunches.

**4. Tap the beacon button**, then tap any widget. The reference is on your clipboard.

To combine several widgets into one reference, tap each of them, then tap the **Tap to send N**
pill above the button.

Add `.ref/` to your `.gitignore` — the bridge warns you at startup if it's missing.

## How it works

Flutter's `--track-widget-creation` tags every widget with the source location it was built from,
which is what powers the Flutter Inspector. `flutter run` turns it on by default in debug builds.

beacon reads that tag off whatever you tapped, then walks up the widget tree until it reaches
code you actually wrote — past `Padding`, `Semantics`, `RepaintBoundary`, and anything from your
`pub` dependencies — so you get *your* `SearchTextField`, not the `TextField` buried inside it.
The rest of the payload comes from the live render tree.

## What a reference contains

The clipboard gets one line. The full payload is saved to `.ref/sel-<id>.json`, next to a cropped
screenshot of the widget:

| | |
|---|---|
| **Location** | File, line and column the widget was created at |
| **Theme properties** | Resolved with provenance — `colorScheme.primary` rather than `#FF6750A4`, where beacon can trace it |
| **Geometry** | Size, global position, and the constraints it was laid out under |
| **Context** | Enclosing route, enclosing `State` class, and the ancestor chain |
| **Screenshot** | The widget itself, cropped from the live frame |

The clipboard line links to that JSON, so an agent can read the full detail when the summary
isn't enough.

## Controlling the overlay

beacon hides its own button for a second when it detects an OS screenshot, so screenshots you
share don't show dev-tool chrome.

That's reactive — the OS has already captured the frame by the time the detection fires, so an
isolated screenshot still catches the button once. It helps with bursts and screen recordings.
For a guaranteed-clean shot, hide it yourself:

```dart
Beacon.hide();   // take the screenshot
Beacon.show();
```

| Member | Effect |
|---|---|
| `Beacon.hide()` | Hides the button, outline and chip. Also exits select mode. |
| `Beacon.show()` | Shows them again. |
| `Beacon.setVisible(bool)` | Sets visibility directly. |
| `Beacon.visible` | The underlying `ValueNotifier<bool>`. |

```dart
// A toggle in your own debug settings:
ValueListenableBuilder<bool>(
  valueListenable: Beacon.visible,
  builder: (context, visible, _) => Switch(
    value: visible,
    onChanged: Beacon.setVisible,
  ),
)
```

## Bridge options

| Flag | Default | Description |
|---|---|---|
| `--vmservice-out-file=<path>` | `.ref/vm.json` | File to watch for your app's VM service address. Must match what you pass to `flutter run`. |
| `--format=multiline` | single-line | Splits the reference across several lines. |

Single-line is the default because many chat inputs send on Enter. For terminal agents that
handle newlines:

```
[ref] ElevatedButton · lib/features/pos/widgets/checkout_bar.dart:142
180×48 · bg=colorScheme.primary · radius=8 · parent Row:130
→ .ref/sel-a3f2.json
```

The bridge replaces your clipboard on every selection, with no undo — it prints a confirmation
each time, so it's never silent. Files in `.ref/` older than an hour are pruned at startup and
every ten minutes while it runs.

## IDE setup

Launching from your IDE's Run button skips `--vmservice-out-file` unless you add it. Both halves,
once per project:

### Android Studio / IntelliJ

**Pass the flag to your app** — *Run* → *Edit Configurations…* → your Flutter configuration →
**Additional run args**:

```
--vmservice-out-file=.ref/vm.json
```

Use **Additional run args**, not *Attach args*. They're separate fields, and the latter only
applies to Flutter Attach — a flag in the wrong box does nothing, which looks exactly like the
bridge failing to connect.

**Run the bridge** from the built-in terminal, or give it a Run button by dropping this in
`.idea/runConfigurations/beacon_bridge.xml`:

```xml
<component name="ProjectRunConfigurationManager">
  <configuration default="false" name="beacon bridge" type="ShConfigurationType">
    <option name="SCRIPT_TEXT" value="dart run beacon_widget:bridge --vmservice-out-file=.ref/vm.json" />
    <option name="INDEPENDENT_SCRIPT_PATH" value="true" />
    <option name="INDEPENDENT_SCRIPT_WORKING_DIRECTORY" value="true" />
    <option name="SCRIPT_WORKING_DIRECTORY" value="$PROJECT_DIR$" />
    <option name="INDEPENDENT_INTERPRETER_PATH" value="true" />
    <option name="INTERPRETER_PATH" value="/bin/zsh" />
    <option name="INTERPRETER_OPTIONS" value="-l" />
    <option name="EXECUTE_IN_TERMINAL" value="true" />
    <option name="EXECUTE_SCRIPT_FILE" value="false" />
    <envs />
    <method v="2" />
  </configuration>
</component>
```

It appears in the run dropdown as *beacon bridge* after the IDE reloads. Equivalent to doing it by
hand: *Run* → *Edit Configurations…* → **+** → **Shell Script** → *Execution: Script text*.

> **If you have more than one Flutter SDK installed, check which `dart` this picks up.** The run
> configuration uses a login shell, which may resolve `dart` differently from the terminal you
> normally use — with fvm, a system-wide Flutter often wins, and an older Dart will fail to
> resolve your dependencies at all. Run `zsh -lc 'dart --version'` to see which one you'd get. If
> it's the wrong one, use `fvm dart run beacon_widget:bridge …` in `SCRIPT_TEXT`, or the absolute
> path to the right SDK.

### VS Code

**Pass the flag to your app**, in `.vscode/launch.json`:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Flutter (with beacon)",
      "type": "dart",
      "request": "launch",
      "program": "lib/main.dart",
      "args": ["--vmservice-out-file=.ref/vm.json"]
    }
  ]
}
```

**Run the bridge** as a task in `.vscode/tasks.json`:

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

`runOn: folderOpen` starts it with the project. Prefer it over `preLaunchTask` — the bridge runs
indefinitely and never reports completion, so VS Code would wait on it forever before launching
your app.

## Troubleshooting

**The bridge sits on "Watching .ref/vm.json…" and never connects.**

Leave it running — after a few seconds it prints what to check. Almost always the flag isn't
reaching `flutter run`; see [IDE setup](#ide-setup). Three things catch people out:

- **The flag is in the wrong field.** In Android Studio, *Additional run args* is what regular
  Run/Debug uses. *Attach args* only applies to Flutter Attach, and a flag there does nothing.
- **You're editing a different project's configuration.** A repo with a package and its example
  has two `.idea` directories, and only the one for the project you actually opened is read.
- **`.ref/vm.json` is stale.** A file from an earlier run points at a port that died with it, so
  the bridge connects to nothing. Delete it and relaunch.

The one check that separates these: after launching your app, confirm `.ref/vm.json` has a
**fresh timestamp**. If it's missing or old, the flag isn't getting through, and nothing
downstream can work.

```bash
ls -l .ref/vm.json
```

**Taps resolve to a widget I didn't expect.**
beacon reports the nearest widget in your own code. If it can't find one and falls back to a less
certain match, the on-screen chip turns amber and the JSON records `"confidence": "low"`.

**Nothing happens when I tap.**
Check select mode is on — the button shows a close icon while it's active.

**`Beacon` is undefined.**
Add `import 'package:beacon_widget/beacon_widget.dart';`, and keep `beacon_widget` under
`dependencies` rather than `dev_dependencies` if you import it from `lib/`.

## Debug builds only

`Beacon.attach` returns its child unmodified outside debug builds — no overlay, no VM service
traffic, nothing to strip before shipping.

That's a constraint, not just a safety setting: `--track-widget-creation` is debug-only, and there
is no profile or release equivalent to fall back on. beacon is a development-time tool by nature.

## Platform support

Android, iOS, macOS, Windows and Linux. Web is not supported.

The bridge runs wherever you develop — it copies via `pbcopy`, `xclip` or `clip`, so there's no
clipboard dependency or permission prompt. On Linux, install `xclip`.

## License

MIT
