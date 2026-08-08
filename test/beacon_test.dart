import 'package:beacon/src/payload.dart';
import 'package:beacon/src/resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('relativizePath', () {
    test('strips everything up to the last /lib/', () {
      expect(relativizePath('/Users/dev/app/lib/features/pos/checkout.dart'), 'lib/features/pos/checkout.dart');
    });

    test('leaves paths with no /lib/ untouched', () {
      expect(relativizePath('/Users/dev/app/bin/main.dart'), '/Users/dev/app/bin/main.dart');
    });
  });

  group('isDenylistedPath', () {
    test('flags package:flutter and pub-cache sources', () {
      expect(isDenylistedPath('/sdk/flutter/packages/flutter/lib/src/widgets/text.dart'), isTrue);
      expect(isDenylistedPath('/Users/dev/.pub-cache/hosted/pub.dev/foo-1.0.0/lib/foo.dart'), isTrue);
    });

    test('does not flag app code', () {
      expect(isDenylistedPath('/Users/dev/app/lib/main.dart'), isFalse);
    });
  });

  test('randomSelectionId returns a 4-char lowercase hex id', () {
    final String id = randomSelectionId();
    expect(RegExp(r'^[0-9a-f]{4}$').hasMatch(id), isTrue);
  });
}
