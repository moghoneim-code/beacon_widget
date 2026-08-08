import 'package:assist/main.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// The overlay's screenshot detection has no native implementation inside
// flutter test, so its channels are mocked the same way the package's own
// tests do it.
const MethodChannel _noScreenshotMethods = MethodChannel(
  'com.flutterplaza.no_screenshot_methods',
);
const EventChannel _noScreenshotEvents = EventChannel(
  'com.flutterplaza.no_screenshot_streams',
);

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          _noScreenshotMethods,
          (MethodCall call) async => null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
          _noScreenshotEvents,
          MockStreamHandler.inline(
            onListen: (Object? arguments, MockStreamHandlerEventSink events) {},
          ),
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_noScreenshotMethods, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(_noScreenshotEvents, null);
  });

  testWidgets('storefront renders its main sections', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const BeaconDemoApp());
    await tester.pumpAndSettle();

    expect(find.text('Northwind'), findsOneWidget);
    expect(find.text('Spring refresh,\nup to 40% off'), findsOneWidget);
    expect(find.text('Aurora Headphones'), findsOneWidget);
    expect(find.text('Checkout'), findsOneWidget);
  });

  testWidgets('tapping a category filters the grid', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const BeaconDemoApp());
    await tester.pumpAndSettle();

    expect(find.text('Aurora Headphones'), findsOneWidget);
    expect(find.text('Grove Backpack'), findsOneWidget);

    await tester.tap(find.text('Outdoor').first);
    await tester.pumpAndSettle();

    expect(
      find.text('Aurora Headphones'),
      findsNothing,
      reason: 'Audio product should be filtered out',
    );
    expect(find.text('Grove Backpack'), findsOneWidget);
  });
}
