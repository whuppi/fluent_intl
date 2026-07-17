// Formatter-memoization regression: every option that picks a DIFFERENT
// intl formatter must reach the cache key. compactDisplay once didn't —
// a short-form compact formatter served `compactDisplay: "long"` calls.

import 'package:fluent_intl/fluent_intl.dart';
import 'package:test/test.dart';

void main() {
  test('compactDisplay variants do not collide in the formatter cache', () {
    final bundle = FluentBundle(
      'en-US',
      backend: IntlBackend(),
      useIsolating: false,
    )..addResource(
      'short = { NUMBER(\$n, notation: "compact") }\n'
      'long = { NUMBER(\$n, notation: "compact", '
      'compactDisplay: "long") }\n',
    );
    // Format short FIRST so a colliding key would poison the long call.
    final short = bundle.formatMessage('short', args: {'n': 1234567});
    final long = bundle.formatMessage('long', args: {'n': 1234567});
    expect(short, contains('M'));
    expect(long.toLowerCase(), contains('million'));
  });

  test('degrade errors record on EVERY call, not just the cache miss', () {
    final bundle = FluentBundle(
      'en-US',
      backend: IntlBackend(),
      useIsolating: false,
    )..addResource('m = { NUMBER(\$n, style: "unit", unit: "meter") }\n');
    for (var i = 0; i < 2; i++) {
      final errors = <FluentError>[];
      bundle.formatMessage('m', args: {'n': 5}, errors: errors);
      expect(
        errors.whereType<FluentTypeError>(),
        isNotEmpty,
        reason: 'call ${i + 1} must record the unit degrade error',
      );
    }
  });
}
