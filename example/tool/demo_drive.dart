// Drives the demo storefront hands-free, for recording a screencast.
//
// It taps the beacon button, selects three widgets from three different
// files, broadcasts them as one combined reference, then leaves select mode.
// Taps are injected through the app's own gesture pipeline over the Dart VM
// Service, so they take exactly the path a real tap takes — hit test, then
// BeaconOverlay's listener.
//
// Usage, with the app and the bridge already running:
//
//   dart run tool/demo_drive.dart .ref/vm.json
//
// Start your screen recorder first; the script waits two seconds before the
// first tap.
import 'dart:io';

import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln('usage: dart run tool/demo_drive.dart <path to vm.json>');
    exit(64);
  }

  final String wsUri = File(args.first).readAsStringSync().trim();
  final VmService service = await vmServiceConnectUri(wsUri);
  final VM vm = await service.getVM();
  final String isolateId = vm.isolates!.first.id!;
  final Isolate isolate = await service.getIsolate(isolateId);
  final LibraryRef lib = isolate.libraries!.firstWhere(
    (LibraryRef l) => l.uri!.endsWith('assist/main.dart'),
  );

  Future<String> eval(String expression) async {
    final Response r = await service.evaluate(isolateId, lib.id!, expression);
    if (r is InstanceRef) return r.valueAsString ?? 'ok';
    if (r is ErrorRef) return 'ERROR: ${r.message}';
    return 'ok';
  }

  Future<double> viewMetric(String property) async {
    final String value = await eval(
      '(WidgetsBinding.instance.platformDispatcher.views.first.physicalSize.$property / '
      'WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio).toString()',
    );
    return double.parse(value);
  }

  final double width = await viewMetric('width');
  final double height = await viewMetric('height');
  stdout.writeln(
    'view ${width.toStringAsFixed(0)}x${height.toStringAsFixed(0)}',
  );

  Future<void> tap(
    double x,
    double y,
    String label, {
    int pauseMs = 2000,
  }) async {
    stdout.writeln('  $label');
    await eval(
      'WidgetsBinding.instance.handlePointerEvent(PointerDownEvent(pointer: 1, position: Offset($x, $y)))',
    );
    await eval(
      'WidgetsBinding.instance.handlePointerEvent(PointerUpEvent(pointer: 1, position: Offset($x, $y)))',
    );
    await Future<void>.delayed(Duration(milliseconds: pauseMs));
  }

  // The overlay's own chrome, positioned relative to the bottom-right corner.
  final double fabX = width - 44;
  final double fabY = height - 124;
  final double pillX = width - 76;
  final double pillY = height - 178;

  await Future<void>.delayed(const Duration(seconds: 2));

  await tap(fabX, fabY, 'select mode on');
  await tap(109, 213, 'Shop now button — promo_banner.dart');
  await tap(70, 630, 'price tag — product_card.dart');
  await tap(1082, 711, 'Checkout button — checkout_bar.dart');
  await tap(pillX, pillY, 'send all three as one reference', pauseMs: 3000);
  await tap(fabX, fabY, 'select mode off', pauseMs: 1500);

  await service.dispose();
  stdout.writeln('done');
}
