import 'package:fluent_bundle/fluent_bundle.dart';
import 'package:intl/intl.dart' as intl;

/// CLDR cardinal plural category for [value] in [locale], honoring the
/// visible fraction digit count [precision] (CLDR operand `v`).
///
/// [precision] is what makes `1` and `1.0` land in different categories in
/// English (`one` vs `other`) — the caller derives it from the number's
/// visible digits (`FluentNumber.resolveDigits().fractionDigits`).
PluralCategory cardinalCategory(num value, String locale, int precision) {
  // Do NOT replace this with `Intl.plural`. That API treats explicit
  // `zero` / `one` / `two` arguments as overrides for n=0/1/2 regardless
  // of the locale's actual CLDR category — useful for writing translated
  // messages, wrong for asking "which category does this number fall in?"
  // `pluralLogic` with `useExplicitNumberCases: false` returns the pure
  // CLDR category, which is what variant matching needs.
  return intl.Intl.pluralLogic<PluralCategory>(
    value,
    precision: precision,
    zero: PluralCategory.zero,
    one: PluralCategory.one,
    two: PluralCategory.two,
    few: PluralCategory.few,
    many: PluralCategory.many,
    other: PluralCategory.other,
    locale: locale,
    useExplicitNumberCases: false,
  );
}
