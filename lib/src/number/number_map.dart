import 'package:fluent_bundle/fluent_bundle.dart';
import 'package:fluent_intl/src/common/cache.dart';
import 'package:fluent_intl/src/number/builder.dart';
import 'package:fluent_intl/src/number/currency_name.dart';

/// Build a number formatter backed by `package:intl` for number
/// shaping, plus `l10n_currencies` for the long-form currency NAME slot
/// that `package:intl` doesn't ship.
///
/// Each formatter owns an [IntlMemoizer] so repeated `(locale, opts)`
/// pairs reuse the same `package:intl` formatter instance - important
/// because constructing one parses CLDR pattern data.
///
/// Coverage:
///   * `style: 'decimal'` (default) - locale separators, useGrouping, sign.
///   * `style: 'percent'` - locale percent pattern.
///   * `style: 'currency'` with `currencyDisplay: 'symbol' | 'narrowSymbol'`
///     - locale-correct symbol via `intl.NumberFormat.simpleCurrency`.
///   * `style: 'currency'` with `currencyDisplay: 'code'` - 3-letter ISO
///     code via `intl.NumberFormat.currency`.
///   * `style: 'currency'` with `currencyDisplay: 'name'` - locale-correct
///     long form ("1,234.56 US Dollars") via decimal formatter +
///     `l10n_currencies` name lookup. Covered for 149 locales.
///   * `notation: 'compact'` - `intl.NumberFormat.compact` /
///     `compactLong` / `compactSimpleCurrency` (decimal + currency styles).
///   * `notation: 'scientific'` - `intl.NumberFormat.scientificPattern`
///     (real exponent output; coarse #E0 fidelity, decimal style only).
///
/// Everything `package:intl` has no equivalent for degrades to the
/// locale-default rendering WITH a recorded `FluentTypeError`, per call:
/// `style: 'unit'`, `signDisplay`, `roundingMode`, `roundingIncrement`,
/// `trailingZeroDisplay`, `numberingSystem`, `currencySign: 'accounting'`,
/// the v3 grouping strategies (`min2` / `always`), and
/// `notation: 'engineering'` (degrades to scientific). Apps that need
/// those use the icu backend.
String Function(FluentNumber, String, List<FluentError>)
createIntlNumberFormatter({IntlMemoizer? memoizer}) {
  final cache = memoizer ?? IntlMemoizer();
  // l10n_currencies' CurrenciesLocaleMapper is *single-use* by design
  // (its localize() clears internal data after the call). We can't
  // share one mapper across format calls. To avoid recreating it on
  // every call (and re-allocating its 149-locale data tables), cache
  // the resolved name by (locale, isoCode) instead. The mapper itself
  // is rebuilt per cache miss; the resolved string is reused.
  final currencyNameCache = <String, String>{};

  return (FluentNumber value, String locale, List<FluentError> errors) {
    final opts = value.options;

    // Per-call knobs package:intl has no equivalent for — degrade to the
    // locale-default rendering + record, never drop silently. Apps that
    // need these use the icu backend.
    void unsupported(String option, String effect) {
      errors.add(
        FluentTypeError.unsupportedOption(
          builtin: 'NUMBER',
          option: option,
          backend: 'package:intl',
          effect: effect,
          hint:
              'Use IcuBackend from package:fluent_icu for full '
              'ECMA-402 support.',
        ),
      );
    }

    if (opts.signDisplay != null && opts.signDisplay != 'auto') {
      unsupported(
        'signDisplay "${opts.signDisplay}"',
        'the locale-default sign is rendered',
      );
    }
    if (opts.roundingMode != null && opts.roundingMode != 'halfEven') {
      // package:intl rounds half-even internally and exposes no knob.
      unsupported(
        'roundingMode "${opts.roundingMode}"',
        'half-even rounding is used',
      );
    }
    if (opts.roundingIncrement != null && opts.roundingIncrement != 1) {
      unsupported(
        'roundingIncrement ${opts.roundingIncrement}',
        'plain positional rounding is used',
      );
    }
    if (opts.trailingZeroDisplay == 'stripIfInteger') {
      unsupported(
        'trailingZeroDisplay "stripIfInteger"',
        'padded fraction zeros are kept',
      );
    }
    if (opts.numberingSystem != null) {
      unsupported(
        'numberingSystem "${opts.numberingSystem}"',
        "the locale's default digits are used",
      );
    }
    if (opts.currencySign == 'accounting') {
      unsupported('currencySign "accounting"', 'the standard sign is rendered');
    }
    // "auto" IS package:intl's pattern-driven behavior, so only the two
    // strategies that would change grouping degrade.
    if (opts.groupingStrategy == 'min2' || opts.groupingStrategy == 'always') {
      unsupported(
        'useGrouping "${opts.groupingStrategy}"',
        "the locale pattern's grouping is used",
      );
    }

    // Notation + style routing. All degrade decisions happen HERE, per
    // call — never inside the cached builder, where an error would only
    // record on the first (cache-miss) call. Engineering has no intl
    // equivalent (its scientific pattern is plain #E0) — degrade to
    // scientific.
    var style = opts.style ?? 'decimal';
    var notation = opts.notation ?? 'standard';
    if (notation == 'engineering') {
      unsupported('notation "engineering"', 'scientific notation is used');
      notation = 'scientific';
    }
    if (style == 'unit') {
      unsupported(
        'style "unit"',
        'falling back to decimal formatting (the unit suffix will not appear)',
      );
    }
    // The shared currency guard: without it package:intl's currency
    // factories silently substitute the LOCALE's default currency — a
    // wrong-currency render, the worst kind of silent. Resolved before
    // the notation checks so compact/scientific route against the
    // effective style.
    if (style == 'currency' && !isValidCurrencyCode(opts.currency)) {
      errors.add(FluentTypeError.invalidCurrencyCode(opts.currency));
      style = 'decimal';
    }
    if (notation == 'compact' &&
        !(style == 'decimal' ||
            (style == 'currency' && opts.currency != null))) {
      unsupported(
        'notation "compact" with style "$style"',
        'standard notation is used',
      );
      notation = 'standard';
    } else if (notation == 'scientific' && style != 'decimal') {
      unsupported(
        'notation "scientific" with style "$style"',
        'standard notation is used',
      );
      notation = 'standard';
    }

    // currencyDisplay: name routes through the l10n_currencies composer.
    if (style == 'currency' &&
        opts.currencyDisplay == 'name' &&
        opts.currency != null) {
      if (notation != 'standard') {
        unsupported(
          'notation "$notation" with currencyDisplay "name"',
          'standard notation is used',
        );
        notation = 'standard';
      }
      return formatCurrencyName(
        value: value,
        locale: locale,
        opts: opts,
        cache: cache,
        nameCache: currencyNameCache,
        errors: errors,
      );
    }

    final formatter = cache.numberFormat(
      locale,
      '${optsKey(opts)}|$notation|$style',
      () => buildFormatter(opts, locale, notation, style),
    );
    return formatter.format(value.value);
  };
}
