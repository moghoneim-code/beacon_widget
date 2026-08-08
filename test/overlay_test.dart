import 'package:beacon/beacon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// no_screenshot has no native implementation inside flutter test's plain
// Dart VM — without a mock, BeaconOverlay's screenshot listener setup
// throws a MissingPluginException that Flutter's services layer reports
// straight to FlutterError.onError (not through the stream's own onError,
// which is why production code can't simply catch it locally). Standard
// Flutter pattern for testing plugin-touching code: mock the channels.
const MethodChannel _noScreenshotMethods = MethodChannel('com.flutterplaza.no_screenshot_methods');
const EventChannel _noScreenshotEvents = EventChannel('com.flutterplaza.no_screenshot_streams');

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _noScreenshotMethods,
      (MethodCall call) async => null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockStreamHandler(
      _noScreenshotEvents,
      MockStreamHandler.inline(onListen: (Object? arguments, MockStreamHandlerEventSink events) {}),
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_noScreenshotMethods, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockStreamHandler(_noScreenshotEvents, null);
  });

  testWidgets('select mode resolves the actual app widget, not the overlay itself', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (BuildContext context, Widget? child) => Beacon.attach(child!),
        home: const Scaffold(body: Center(child: Text('Tap me'))),
      ),
    );
    await tester.pumpAndSettle();

    // Enter select mode.
    await tester.tap(find.byType(BeaconMark));
    await tester.pump();
    expect(find.byIcon(Icons.close), findsOneWidget, reason: 'FAB should flip to the close icon once select mode is on');

    // Tap the app content underneath the overlay.
    // warnIfMissed: false — the tap is meant to land on the select-mode
    // catcher above 'Tap me', not the text itself; that's the point.
    await tester.tap(find.text('Tap me'), warnIfMissed: false);
    await tester.pump(); // same-frame outline/chip
    expect(find.textContaining('Text ·'), findsOneWidget, reason: 'chip should name the real widget, not overlay.dart internals');
    // RenderRepaintBoundary.toImage() needs real engine rasterization, which
    // the fake test clock behind plain pump()/pumpAndSettle() never drives —
    // runAsync briefly steps outside it so that Future actually resolves.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
    await tester.pumpAndSettle();

    // One item should now be in the selection stack.
    expect(find.text('Tap to send 1'), findsOneWidget, reason: 'send pill should show one accumulated selection');
  });

  testWidgets('tapping the send pill broadcasts and clears the stack', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (BuildContext context, Widget? child) => Beacon.attach(child!),
        home: Scaffold(
          body: Column(
            children: <Widget>[
              ElevatedButton(onPressed: () {}, child: const Text('Alpha')),
              ElevatedButton(onPressed: () {}, child: const Text('Beta')),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(BeaconMark));
    await tester.pump();

    // warnIfMissed: false for the same reason as above — the select-mode
    // catcher is meant to intercept these, not the buttons underneath.
    await tester.tap(find.text('Alpha'), warnIfMissed: false);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beta'), warnIfMissed: false);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
    await tester.pumpAndSettle();

    expect(find.text('Tap to send 2'), findsOneWidget, reason: 'both taps should have landed in the stack');

    // Tap the send pill itself — deliberately a plain tap, not a long-press
    // (PLAN.md working notes: long-press on the same GestureDetector as the
    // drag handler lost the gesture arena to incidental pointer movement
    // during on-device testing, so broadcasting is a dedicated tap target).
    await tester.tap(find.text('Tap to send 2'));
    await tester.pump();

    expect(find.text('Sent 2 refs'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Sent 2 refs'), findsNothing, reason: 'confirmation chip should auto-dismiss like any other');
  });

  testWidgets('Beacon.hide hides the FAB and exits select mode; Beacon.show brings it back', (WidgetTester tester) async {
    addTearDown(() => Beacon.visible.value = true);

    await tester.pumpWidget(
      MaterialApp(
        builder: (BuildContext context, Widget? child) => Beacon.attach(child!),
        home: const Scaffold(body: Center(child: Text('Tap me'))),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(BeaconMark));
    await tester.pump();
    expect(find.byIcon(Icons.close), findsOneWidget, reason: 'select mode should be on before hiding');

    Beacon.hide();
    await tester.pump();
    expect(find.byIcon(Icons.close), findsNothing);
    expect(find.byType(BeaconMark), findsNothing, reason: 'the whole FAB should be gone, not just re-iconed');

    // A tap that would've landed on the select-mode catcher while hidden
    // should instead reach the app underneath, since hiding also exits
    // select mode — otherwise it'd be an invisible tap trap.
    await tester.tap(find.text('Tap me'));
    await tester.pump();
    expect(find.textContaining('Text ·'), findsNothing, reason: 'no chip should appear — the tap should reach the app, not resolve a selection');

    Beacon.show();
    await tester.pump();
    expect(find.byType(BeaconMark), findsOneWidget, reason: 'FAB should reappear, back in its default (not select-mode) state');
  });
}
