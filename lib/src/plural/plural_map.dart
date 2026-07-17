import 'package:fluent_bundle/fluent_bundle.dart';
import 'package:fluent_intl/src/plural/cardinal.dart';
import 'package:fluent_intl/src/plural/ordinal.dart';

/// CLDR plural category backed by `package:intl`. Consumed by
/// `IntlBackend.pluralCategory`; not wired directly by app code.
///
/// Cardinals cover every CLDR locale via `Intl.pluralLogic`; ordinals
/// cover the ~25 locales inlined in `ordinal.dart`.
PluralCategory intlPluralRules(
  FluentNumber value,
  PluralRuleType type,
  String locale,
) {
  if (type == PluralRuleType.ordinal) {
    return ordinalCategory(value.value, locale);
  }
  // Visible fraction digits (CLDR operand `v`) drive cardinal selection:
  // NUMBER($n, minimumFractionDigits: 1) with n=1 selects `other`, not
  // `one`, in English. resolveDigits computes exactly that.
  final precision = value.resolveDigits().fractionDigits;
  return cardinalCategory(value.value, locale, precision);
}
