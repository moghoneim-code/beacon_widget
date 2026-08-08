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
}
