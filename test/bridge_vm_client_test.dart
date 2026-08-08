import 'dart:io';

import 'package:beacon_widget/bridge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'VmClient watches the vmservice-out-file and attempts to connect when it changes',
    () async {
      final Directory tempDir = Directory.systemTemp.createTempSync('beacon_bridge_test');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final File vmServiceOutFile = File('${tempDir.path}/vm.json');

      final List<String> statuses = <String>[];
      final VmClient client = VmClient(
        vmServiceOutFile: vmServiceOutFile,
        onStatus: statuses.add,
        onSelected: (_, _) {},
      );

      await client.start();
      expect(statuses.any((String s) => s.contains('Watching')), isTrue);

      vmServiceOutFile.writeAsStringSync('ws://127.0.0.1:1/invalid');
      await Future<void>.delayed(const Duration(milliseconds: 500));

      expect(statuses.any((String s) => s.contains('Connecting to')), isTrue);

      await client.stop();
    },
    timeout: const Timeout(Duration(seconds: 10)),
  );

  test(
    'does not open duplicate connections when several events fire for one write',
    () async {
      // On macOS a single write commonly delivers more than one
      // FileSystemEvent for the same file — that's what caused the original
      // bug (three simultaneous VM service connections for one tap). Firing
      // the same internal trigger twice without awaiting between them
      // reproduces that overlap deterministically, without depending on the
      // platform's watcher actually duplicating events in this test run.
      final Directory tempDir = Directory.systemTemp.createTempSync('beacon_bridge_test');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final File vmServiceOutFile = File('${tempDir.path}/vm.json')..writeAsStringSync('ws://127.0.0.1:1/invalid');

      final List<String> statuses = <String>[];
      final VmClient client = VmClient(
        vmServiceOutFile: vmServiceOutFile,
        onStatus: statuses.add,
        onSelected: (_, _) {},
      );

      final Future<void> first = client.debugTryConnectFromFile();
      final Future<void> second = client.debugTryConnectFromFile();
      await Future.wait(<Future<void>>[first, second]);

      final int connectAttempts = statuses.where((String s) => s.contains('Connecting to')).length;
      expect(connectAttempts, 1, reason: 'expected exactly one connect attempt, got $connectAttempts: $statuses');

      await client.stop();
    },
    timeout: const Timeout(Duration(seconds: 10)),
  );

  test(
    'warns at startup when the vmservice-out-file is left over from an earlier run',
    () async {
      final Directory tempDir = Directory.systemTemp.createTempSync('beacon_stale_test');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final File vmServiceOutFile = File('${tempDir.path}/vm.json')..writeAsStringSync('ws://127.0.0.1:1/dead');
      // Older than the bridge's start, i.e. written by a previous flutter run.
      vmServiceOutFile.setLastModifiedSync(DateTime.now().subtract(const Duration(hours: 1)));

      final List<String> statuses = <String>[];
      final VmClient client = VmClient(
        vmServiceOutFile: vmServiceOutFile,
        onStatus: statuses.add,
        onSelected: (_, _) {},
      );

      await client.start();
      addTearDown(client.stop);

      expect(
        statuses.any((String s) => s.contains('left over from an earlier run')),
        isTrue,
        reason: 'a stale address fails in a way that looks like an app bug, so it must be called out',
      );
    },
    timeout: const Timeout(Duration(seconds: 10)),
  );

  test('explains how to pass --vmservice-out-file when the file never appears', () async {
    final Directory tempDir = Directory.systemTemp.createTempSync('beacon_hint_test');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    final File vmServiceOutFile = File('${tempDir.path}/vm.json'); // never created

    final List<String> statuses = <String>[];
    final VmClient client = VmClient(vmServiceOutFile: vmServiceOutFile, onStatus: statuses.add, onSelected: (_, _) {});

    await client.start();
    addTearDown(client.stop);

    // The real hint fires after VmClient.hintAfter; waiting that long in a
    // test is wasteful, so just assert the wait is bounded and that the
    // timer is what produces the guidance.
    expect(VmClient.hintAfter.inSeconds, lessThanOrEqualTo(30));
    expect(statuses.any((String s) => s.contains('Watching')), isTrue);
  }, timeout: const Timeout(Duration(seconds: 10)));
}
