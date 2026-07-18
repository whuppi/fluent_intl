// The NUMBER path end-to-end through the intl backend: locale-aware
// rendering, the currency-code guard, and the ECMA compact default.

import 'package:fluent_intl/fluent_intl.dart';
import 'package:test/test.dart';

void registerNumberMapTests() {
  group('IntlBackend — locale-aware NUMBER', () {
    test('grouping separators per locale', () {
      final b = FluentBundle('en', backend: IntlBackend(), useIsolating: false)
        ..addResource('m = { NUMBER(\$n) }');
      expect(b.formatMessage('m', args: {'n': 1234567}), '1,234,567');
    });

    test('currency symbol', () {
      final b = FluentBundle(
        'en',
        backend: IntlBackend(),
        useIsolating: false,
      )..addResource('m = { NUMBER(\$n, style: "currency", currency: "USD") }');
      expect(b.formatMessage('m', args: {'n': 5}), contains('5.00'));
    });

    test('currency without a 3-letter code degrades to decimal + error', () {
      // Without the guard package:intl silently substitutes the LOCALE's
      // default currency — a wrong-currency render.
      final b = FluentBundle('en', backend: IntlBackend(), useIsolating: false)
        ..addResource('m = { NUMBER(\$n, style: "currency") }');
      final errors = <FluentError>[];
      final out = b.formatMessage('m', args: {'n': 5}, errors: errors);
      expect(out, isNot(contains(r'$')));
      expect(errors.whereType<FluentTypeError>(), isNotEmpty);
    });

    test('compact uses the ECMA 1-2 significant-digit default', () {
      final b = FluentBundle('en', backend: IntlBackend(), useIsolating: false)
        ..addResource('m = { NUMBER(\$n, notation: "compact") }');
      expect(b.formatMessage('m', args: {'n': 1234567}), '1.2M');
    });
  });
}
