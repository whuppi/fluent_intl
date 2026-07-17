// The inlined ordinal rules vs the CLDR snapshot, three directions:
//
//   1. Every per-locale, per-category integer example CLDR publishes
//      classifies to that category through `ordinalCategory`.
//   2. Orphans fail loud: a locale we register that CLDR no longer
//      ships an ordinal rule for.
//   3. Coverage gaps fail loud: a CLDR locale with a non-trivial rule
//      (anything beyond "everything is `other`") that we do NOT
//      support. Trivial locales fall through to `other` correctly
//      without a predicate, so only non-trivial ones must be inlined.
//
// The fixture is regenerated from upstream CLDR by
// `tool/regen_cldr_ordinal_fixture.dart`; after a regen, this suite is
// the whole gate — no manual audit step.

import 'package:fluent_bundle/fluent_bundle.dart';
import 'package:fluent_intl/src/plural/ordinal.dart';
import 'package:test/test.dart';

import '_cldr_ordinal_examples.dart';

void main() {
  group('ordinal rules match the CLDR examples', () {
    for (final entry in cldrOrdinalExamples.entries) {
      final locale = entry.key;
      test(locale, () {
        for (final byCategory in entry.value.entries) {
          final expected = PluralCategory.values.byName(byCategory.key);
          for (final n in byCategory.value) {
            expect(
              ordinalCategory(n, locale),
              expected,
              reason: 'ordinal($n, $locale)',
            );
          }
        }
      });
    }
  });

  test('no orphans: every supported locale still exists in CLDR', () {
    final orphans = supportedOrdinalLocales.difference(cldrAllOrdinalLocales);
    expect(
      orphans,
      isEmpty,
      reason: 'registered locales CLDR no longer ships: $orphans',
    );
  });

  test('no gaps: every non-trivial CLDR locale is supported', () {
    final gaps = cldrNonTrivialOrdinalLocales.difference(
      supportedOrdinalLocales,
    );
    expect(
      gaps,
      isEmpty,
      reason: 'CLDR non-trivial ordinal locales we do not support: $gaps',
    );
  });
}
