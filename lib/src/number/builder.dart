/// `intl.NumberFormat` construction: the factory routing per
/// (style, notation), the shared digit/grouping knobs, and the canonical
/// memoization key. Degrade decisions do NOT happen here — the closure in
/// `number_map.dart` records them per call before building.
library;

import 'package:fluent_bundle/fluent_bundle.dart';
import 'package:intl/intl.dart' as intl;

/// Construct the `intl.NumberFormat` for one (locale, style, notation,
/// options) combination — the constructor choice IS the style/notation
/// routing (decimal / percent / currency / compact / scientific).
intl.NumberFormat buildFormatter(
  FluentNumberOptions opts,
  String locale,
  String notation,
  String style,
) {
  final intl.NumberFormat formatter;

  // Non-standard notation routes to intl's dedicated factories. The
  // closure has already degraded any combination intl can't express (and
  // recorded the error, per call), so `notation` AND `style` arrive
  // pre-validated: compact only with decimal or currency-with-code,
  // scientific only with decimal, currency only with a 3-letter code.
  if (notation == 'compact') {
    final intl.NumberFormat f;
    if (style == 'currency') {
      f = intl.NumberFormat.compactSimpleCurrency(
        locale: locale,
        name: opts.currency,
      );
    } else {
      f =
          opts.compactDisplay == 'long'
              ? intl.NumberFormat.compactLong(locale: locale)
              : intl.NumberFormat.compact(locale: locale);
    }
    applyDigitKnobs(f, opts);
    // ECMA-402 compact default: 1-2 significant digits when the caller
    // gave no digit options (1234567 → "1.2M"). package:intl's own
    // compact default is 3 significant digits ("1.23M") — pin the ECMA
    // shape so both backends and all three icu engines agree.
    if (opts.minimumFractionDigits == null &&
        opts.maximumFractionDigits == null &&
        opts.minimumSignificantDigits == null &&
        opts.maximumSignificantDigits == null) {
      f.minimumSignificantDigits = 1;
      f.maximumSignificantDigits = 2;
    }
    return f;
  } else if (notation == 'scientific') {
    // intl's scientific pattern is plain #E0 — a coarse mantissa with no
    // significant-digit shaping. Real scientific output; limited fidelity.
    final f = intl.NumberFormat.scientificPattern(locale);
    applyDigitKnobs(f, opts);
    return f;
  }

  switch (style) {
    case 'currency':
      // currencyDisplay: 'name' is handled at the closure level via
      // l10n_currencies (currency_name.dart) and never reaches here.
      final display = opts.currencyDisplay ?? 'symbol';
      if (display == 'code') {
        formatter = intl.NumberFormat.currency(
          locale: locale,
          name: opts.currency,
          decimalDigits: opts.maximumFractionDigits,
        );
      } else {
        // 'symbol' or 'narrowSymbol' (package:intl doesn't distinguish
        // narrow; same simpleCurrency factory for both).
        formatter = intl.NumberFormat.simpleCurrency(
          locale: locale,
          name: opts.currency,
          decimalDigits: opts.maximumFractionDigits,
        );
      }
      break;

    case 'percent':
      formatter = intl.NumberFormat.percentPattern(locale);
      break;

    case 'unit':
      // package:intl has no unit formatter. Degrade to a decimal pattern;
      // the closure already recorded the error (per call, not per cache
      // miss). Apps that need unit formatting use the icu backend.
      formatter = intl.NumberFormat.decimalPattern(locale);
      break;

    case 'decimal':
    default:
      formatter = intl.NumberFormat.decimalPattern(locale);
  }

  applyDigitKnobs(formatter, opts);
  return formatter;
}

/// Apply the digit / grouping knobs that all NumberFormat factories
/// accept. Factored out so the currency-name path (which builds a
/// decimal formatter inside `formatCurrencyName`) shares the logic.
void applyDigitKnobs(intl.NumberFormat formatter, FluentNumberOptions opts) {
  if (opts.useGrouping == false) {
    formatter.turnOffGrouping();
  }
  if (opts.minimumIntegerDigits != null) {
    formatter.minimumIntegerDigits = opts.minimumIntegerDigits!;
  }
  if (opts.minimumFractionDigits != null) {
    formatter.minimumFractionDigits = opts.minimumFractionDigits!;
  }
  if (opts.maximumFractionDigits != null) {
    formatter.maximumFractionDigits = opts.maximumFractionDigits!;
  }
  if (opts.minimumSignificantDigits != null) {
    formatter.minimumSignificantDigits = opts.minimumSignificantDigits;
  }
  if (opts.maximumSignificantDigits != null) {
    formatter.maximumSignificantDigits = opts.maximumSignificantDigits;
  }
}

/// Stable canonical key for [FluentNumberOptions], used for memoization.
/// Two option bags with the same effective settings produce the same key.
///
/// EVERY option field belongs in the key, whether or not today's builder
/// reads it at construction time — a field left out is a cache-collision
/// bug the moment the builder starts consuming it (compactDisplay was
/// exactly that: short-form formatters served `compactDisplay: "long"`
/// calls until it joined the key).
String optsKey(FluentNumberOptions o) {
  // Order is fixed so ordering changes don't break the cache. Empty
  // values use a sentinel (`-`) instead of an empty string so a
  // present-but-empty currency couldn't collide with an absent one.
  String s(String? v) => v ?? '-';
  String i(int? v) => v == null ? '-' : v.toString();
  String b(bool? v) => v == null ? '-' : (v ? 't' : 'f');
  return [
    s(o.style),
    s(o.currency),
    s(o.currencyDisplay),
    s(o.unit),
    s(o.unitDisplay),
    s(o.notation),
    s(o.compactDisplay),
    s(o.signDisplay),
    s(o.currencySign),
    s(o.roundingMode),
    i(o.roundingIncrement),
    s(o.trailingZeroDisplay),
    s(o.numberingSystem),
    b(o.useGrouping),
    s(o.groupingStrategy),
    i(o.minimumIntegerDigits),
    i(o.minimumFractionDigits),
    i(o.maximumFractionDigits),
    i(o.minimumSignificantDigits),
    i(o.maximumSignificantDigits),
  ].join('|');
}
