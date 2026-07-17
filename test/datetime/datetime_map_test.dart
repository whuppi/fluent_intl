// The DATETIME hour machinery through the intl backend: bare hour fields
// keep the locale-preferred cycle, hour12 forces one, and hourCycle is
// part of the formatter cache key.

import 'package:fluent_intl/fluent_intl.dart';
import 'package:test/test.dart';

void main() {
  group('IntlBackend — DATETIME hour fields', () {
    test('bare hour fields keep the locale-preferred cycle', () {
      // en prefers 12-hour time; a bare `hour` must NOT force 24h.
      final b = FluentBundle('en', backend: IntlBackend(), useIsolating: false)
        ..addResource(
          'm = { DATETIME(\$d, hour: "numeric", minute: "numeric") }',
        );
      final out = b.formatMessage(
        'm',
        args: {'d': DateTime.utc(2026, 1, 2, 13, 0)},
      );
      expect(out, isNot(contains('13')));
    });

    test('hourCycle is in the formatter cache key (no h23/h12 collision)', () {
      // Same field set, different hourCycle, ONE bundle: the second call
      // must not be served the first call's cached formatter.
      final b = FluentBundle('en', backend: IntlBackend(), useIsolating: false)
        ..addResource(
          'a = { DATETIME(\$d, hour: "numeric", minute: "numeric", '
          'hourCycle: "h23") }\n'
          'b = { DATETIME(\$d, hour: "numeric", minute: "numeric", '
          'hourCycle: "h12") }',
        );
      final args = {'d': DateTime.utc(2026, 1, 2, 13, 0)};
      expect(b.formatMessage('a', args: args), contains('13'));
      expect(b.formatMessage('b', args: args), isNot(contains('13')));
    });

    test('hour12: false forces the 24-hour cycle', () {
      final b = FluentBundle('en', backend: IntlBackend(), useIsolating: false)
        ..addResource(
          'm = { DATETIME(\$d, hour: "numeric", minute: "numeric", '
          'hour12: "false") }',
        );
      final out = b.formatMessage(
        'm',
        args: {'d': DateTime.utc(2026, 1, 2, 13, 0)},
      );
      expect(out, contains('13'));
    });
  });
}
