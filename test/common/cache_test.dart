// IntlMemoizer: same (kind, locale, optsKey) reuses the instance; any
// axis differing builds fresh; number and date namespaces never collide.

import 'package:fluent_intl/src/common/cache.dart';
import 'package:intl/date_symbol_data_local.dart' as intl_data;
import 'package:intl/intl.dart' as intl;
import 'package:test/test.dart';

void main() {
  group('IntlMemoizer', () {
    setUpAll(intl_data.initializeDateFormatting);
    test('same key returns the same instance without re-invoking create', () {
      final cache = IntlMemoizer();
      var calls = 0;
      intl.NumberFormat create() {
        calls++;
        return intl.NumberFormat.decimalPattern('en');
      }

      final a = cache.numberFormat('en', 'k', create);
      final b = cache.numberFormat('en', 'k', create);
      expect(identical(a, b), isTrue);
      expect(calls, 1);
    });

    test('locale and optsKey are both cache axes', () {
      final cache = IntlMemoizer();
      intl.NumberFormat en() => intl.NumberFormat.decimalPattern('en');
      final base = cache.numberFormat('en', 'k', en);
      expect(identical(cache.numberFormat('de', 'k', en), base), isFalse);
      expect(identical(cache.numberFormat('en', 'k2', en), base), isFalse);
    });

    test('number and date entries never collide on the same key', () {
      final cache = IntlMemoizer();
      cache.numberFormat('en', 'k', intl.NumberFormat.decimalPattern);
      // A colliding namespace would return the NumberFormat here and
      // throw a type error; a fresh DateFormat proves the prefixes hold.
      final df = cache.dateFormat('en', 'k', () => intl.DateFormat.yMd('en'));
      expect(df, isA<intl.DateFormat>());
    });
  });
}
