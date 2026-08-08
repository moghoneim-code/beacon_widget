import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:beacon_widget/bridge.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _samplePayload({String? screenshotBase64}) => <String, Object?>{
  'v': 1,
  'id': 'a3f2',
  'capturedAt': '2026-08-08T14:22:01.000Z',
  'confidence': 'high',
  'target': <String, Object?>{
    'widget': 'ElevatedButton',
    'file': 'lib/features/pos/widgets/checkout_bar.dart',
    'absFile': '/Users/dev/app/lib/features/pos/widgets/checkout_bar.dart',
    'line': 142,
    'column': 15,
  },
  'geometry': <String, Object?>{
    'size': <double>[180.4, 47.9],
    'globalOffset': <double>[24.0, 612.0],
  },
  'resolvedProps': <String, Object?>{
    'backgroundColor': <String, Object?>{'value': '#1565C0', 'source': 'theme.colorScheme.primary'},
    'borderRadius': <String, Object?>{'value': '8.0', 'source': 'literal'},
  },
  'ancestors': <Object?>[
    <String, Object?>{'widget': 'Row', 'file': 'lib/features/pos/widgets/checkout_bar.dart', 'line': 130},
  ],
  'screenshotBase64': ?screenshotBase64,
};

void main() {
  group('writeSelection', () {
    test('writes json and png, swapping screenshotBase64 for a relative path', () {
      final Directory projectRoot = Directory.systemTemp.createTempSync('beacon_bridge_writer_test');
      addTearDown(() => projectRoot.deleteSync(recursive: true));
      final Directory refDir = Directory('${projectRoot.path}/.ref');

      final String pngBase64 = base64Encode(<int>[137, 80, 78, 71]); // PNG magic bytes, doesn't need to be a real image
      final WrittenSelection written = writeSelection(_samplePayload(screenshotBase64: pngBase64), refDir: refDir);

      expect(File('${refDir.path}/sel-a3f2.json').existsSync(), isTrue);
      expect(File('${refDir.path}/sel-a3f2.png').existsSync(), isTrue);
      expect(written.jsonPath, '.ref/sel-a3f2.json');
      expect(written.pngPath, '.ref/sel-a3f2.png');
      expect(written.payload.containsKey('screenshotBase64'), isFalse);
      expect(written.payload['screenshot'], '.ref/sel-a3f2.png');
    });

    test('omits the screenshot field entirely when there is no screenshot', () {
      final Directory projectRoot = Directory.systemTemp.createTempSync('beacon_bridge_writer_test');
      addTearDown(() => projectRoot.deleteSync(recursive: true));
      final Directory refDir = Directory('${projectRoot.path}/.ref');

      final WrittenSelection written = writeSelection(_samplePayload(), refDir: refDir);

      expect(written.pngPath, isNull);
      expect(written.payload.containsKey('screenshot'), isFalse);
      expect(File('${refDir.path}/sel-a3f2.png').existsSync(), isFalse);
    });
  });

  group('formatSelection', () {
    test('single line includes size, theme-stripped bg, radius, parent, and the json path', () {
      final String result = formatSelection(_samplePayload(), jsonPath: '.ref/sel-a3f2.json');
      expect(
        result,
        '[ref] ElevatedButton @ lib/features/pos/widgets/checkout_bar.dart:142 · '
        '180×48 · bg=colorScheme.primary · radius=8.0 · parent Row:130 · '
        'details: .ref/sel-a3f2.json',
      );
      expect(result.contains('\n'), isFalse, reason: 'single-line format must not contain newlines');
    });

    test('multiline splits widget/location, middle fields, and the json path across three lines', () {
      final String result = formatSelection(_samplePayload(), jsonPath: '.ref/sel-a3f2.json', multiline: true);
      final List<String> lines = result.split('\n');
      expect(lines, hasLength(3));
      expect(lines[0], '[ref] ElevatedButton · lib/features/pos/widgets/checkout_bar.dart:142');
      expect(lines[1], '180×48 · bg=colorScheme.primary · radius=8.0 · parent Row:130');
      expect(lines[2], '→ .ref/sel-a3f2.json');
    });

    test('a literal (non-theme) color shows its value instead of "literal"', () {
      final Map<String, Object?> payload = _samplePayload();
      (payload['resolvedProps'] as Map<String, Object?>)['backgroundColor'] = <String, Object?>{
        'value': '#123456',
        'source': 'literal',
      };
      final String result = formatSelection(payload, jsonPath: '.ref/sel-a3f2.json');
      expect(result, contains('bg=#123456'));
    });
  });

  group('formatMultiSelection', () {
    test('lists one compact ref per item, one per line', () {
      final String result = formatMultiSelection(<({Map<String, Object?> payload, String jsonPath})>[
        (payload: _samplePayload(), jsonPath: '.ref/sel-a3f2.json'),
        (payload: _samplePayload(), jsonPath: '.ref/sel-b1c2.json'),
      ]);
      expect(
        result,
        '[ref] ElevatedButton @ lib/features/pos/widgets/checkout_bar.dart:142 · details: .ref/sel-a3f2.json\n'
        '[ref] ElevatedButton @ lib/features/pos/widgets/checkout_bar.dart:142 · details: .ref/sel-b1c2.json',
      );
    });
  });

  group('housekeeping', () {
    test('pruneOldSelections deletes sel-* files older than maxAge and keeps the rest', () {
      final Directory refDir = Directory.systemTemp.createTempSync('beacon_bridge_housekeeping_test')
        ..createSync(recursive: true);
      addTearDown(() => refDir.deleteSync(recursive: true));

      final File oldFile = File('${refDir.path}/sel-old.json')..writeAsStringSync('{}');
      oldFile.setLastModifiedSync(DateTime.now().subtract(const Duration(hours: 2)));
      final File freshFile = File('${refDir.path}/sel-fresh.json')..writeAsStringSync('{}');
      final File unrelatedFile = File('${refDir.path}/vm.json')..writeAsStringSync('ws://x');
      unrelatedFile.setLastModifiedSync(DateTime.now().subtract(const Duration(hours: 2)));

      pruneOldSelections(refDir);

      expect(oldFile.existsSync(), isFalse);
      expect(freshFile.existsSync(), isTrue);
      expect(unrelatedFile.existsSync(), isTrue, reason: 'only sel-* files should be pruned');
    });

    test('schedulePeriodicPruning re-prunes on an interval, not just once', () async {
      final Directory refDir = Directory.systemTemp.createTempSync('beacon_bridge_periodic_prune_test')
        ..createSync(recursive: true);
      addTearDown(() => refDir.deleteSync(recursive: true));

      final File oldFile = File('${refDir.path}/sel-old.json')..writeAsStringSync('{}');
      oldFile.setLastModifiedSync(DateTime.now().subtract(const Duration(hours: 2)));

      // A short interval stands in for the real 10-minute default — this is
      // testing that the timer fires repeatedly, not the specific interval.
      final Timer timer = schedulePeriodicPruning(refDir, interval: const Duration(milliseconds: 20));
      addTearDown(timer.cancel);

      // Nothing pruned yet: schedulePeriodicPruning doesn't prune
      // immediately, only on each subsequent tick (the caller already runs
      // pruneOldSelections once upfront for the immediate case).
      expect(oldFile.existsSync(), isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(oldFile.existsSync(), isFalse, reason: 'the periodic timer should have pruned it by now');
    });

    test('checkGitignore warns when .gitignore is missing or does not mention .ref', () {
      final Directory projectRoot = Directory.systemTemp.createTempSync('beacon_bridge_gitignore_test');
      addTearDown(() => projectRoot.deleteSync(recursive: true));

      expect(checkGitignore(projectRoot), isNotNull);

      File('${projectRoot.path}/.gitignore').writeAsStringSync('build/\n');
      expect(checkGitignore(projectRoot), isNotNull);

      File('${projectRoot.path}/.gitignore').writeAsStringSync('build/\n.ref/\n');
      expect(checkGitignore(projectRoot), isNull);
    });
  });
}
