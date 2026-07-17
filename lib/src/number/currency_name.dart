/// The `currencyDisplay: name` path — the one that needs cross-library
/// composition. package:intl can't render currency NAMES at all, so the
/// result assembles from two sources: the number portion via a
/// locale-aware decimal formatter (cached), and the name via
/// `l10n_currencies` (149 locales of currency-name data).
library;

import 'package:fluent_bundle/fluent_bundle.dart';
import 'package:fluent_intl/src/common/cache.dart';
import 'package:fluent_intl/src/number/builder.dart';
import 'package:intl/intl.dart' as intl;
import 'package:l10n_currencies/l10n_currencies.dart' as l10n;

/// Compose `<number> <currency-name>` for `currencyDisplay: name`.
///
/// The number portion uses a decimal formatter (locale-correct
/// separators + grouping). The name portion uses `l10n_currencies` for
/// the localized name. If the locale has no name data for the requested
/// currency, fall back to the ISO code so output is never broken.
String formatCurrencyName({
  required FluentNumber value,
  required String locale,
  required FluentNumberOptions opts,
  required IntlMemoizer cache,
  required Map<String, String> nameCache,
  required List<FluentError> errors,
}) {
  // Build a decimal formatter with the same digit knobs the caller
  // would have gotten from the currency formatter. Cached per (locale,
  // opts-without-currency) so other format calls with the same digit
  // shape share the instance.
  final decimalKey = 'currencyName|$locale|${optsKey(opts)}';
  final decimal = cache.numberFormat(locale, decimalKey, () {
    final f = intl.NumberFormat.decimalPattern(locale);
    applyDigitKnobs(f, opts);
    // For currency-name we want the sensible currency-default of 2
    // fraction digits when caller didn't specify; this matches what
    // the currency formatter does and what Intl.NumberFormat does in
    // ECMA-402 for `style: currency`.
    if (opts.minimumFractionDigits == null) f.minimumFractionDigits = 2;
    if (opts.maximumFractionDigits == null) f.maximumFractionDigits = 2;
    return f;
  });
  final numberPart = decimal.format(value.value);

  // Look up the localized currency name. l10n_currencies' mapper is
  // single-use, so we instantiate one per cache miss and cache the
  // resolved string by (locale, isoCode). This keeps repeated format
  // calls flat and respects the mapper's lifecycle contract.
  final code = opts.currency!;
  final cacheKey = '$locale|$code';
  final name = nameCache.putIfAbsent(cacheKey, () {
    final mapper = l10n.CurrenciesLocaleMapper();
    final localized = mapper.localize(
      {code},
      mainLocale: locale,
      // useLanguageFallback: true (the default) handles 'en_US' -> 'en'
      // automatically. Setting fallbackLocale to 'en' ensures we always
      // get a name even for locales l10n_currencies doesn't ship.
      fallbackLocale: 'en',
    );
    // localize() returns Map<LocaleKey, String> where LocaleKey is a
    // record `({String isoCode, String locale})`. Find the entry that
    // matches our requested isoCode; locale may be the language-fallback
    // ('en') if the requested locale wasn't shipped.
    for (final entry in localized.entries) {
      if (entry.key.isoCode == code) return entry.value;
    }
    // Fallback to the ISO code itself if l10n_currencies has nothing.
    // Surface as a non-fatal warning so the caller knows the name slot
    // didn't fully populate for this currency in this locale.
    errors.add(
      FluentTypeError(
        'NUMBER currencyDisplay="name" found no localized name for "$code" '
        'in locale "$locale" (l10n_currencies + en fallback). Falling back '
        'to ISO code.',
      ),
    );
    return code;
  });

  return '$numberPart $name';
}
