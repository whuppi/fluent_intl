// Plural selection through the intl backend: real CLDR categories, with
// visible fraction digits (CLDR operand `v`) driving selection (F8).

import 'package:fluent_intl/fluent_intl.dart';
import 'package:test/test.dart';

void registerCardinalTests() {
  group('IntlBackend — plural selection uses visible fraction digits (F8)', () {
    const ftl = 'count = { \$n ->\n    [one] one\n   *[other] other\n}';
    test('1 => one; 1 with minFrac 1 (renders "1.0") => other', () {
      final b = FluentBundle('en', backend: IntlBackend(), useIsolating: false)
        ..addResource(ftl);
      expect(b.formatMessage('count', args: {'n': 1}), 'one');
      expect(
        b.formatMessage(
          'count',
          args: {
            'n': const FluentNumber(
              1,
              FluentNumberOptions(minimumFractionDigits: 1),
            ),
          },
        ),
        'other',
      );
    });

    test('Polish few/many categories', () {
      final b = FluentBundle(
        'pl',
        backend: IntlBackend(),
        useIsolating: false,
      )..addResource(
        'n = { \$x ->\n [one] one\n [few] few\n [many] many\n *[other] other\n}',
      );
      expect(b.formatMessage('n', args: {'x': 1}), 'one');
      expect(b.formatMessage('n', args: {'x': 2}), 'few');
      expect(b.formatMessage('n', args: {'x': 5}), 'many');
    });
  });
}
