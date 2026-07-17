// fluent_intl showcase — the zero-setup CLDR backend, every capability
// in one runnable file.
//
// The whole tour lives in this one file because pub.dev renders it on the
// package's Example tab. `test/example/example_test.dart` runs this exact
// showcase and pins its output, so every line below is proven.
//
// `IntlBackend` needs no initialization and no native or web assets —
// construct it and go. It renders through `package:intl` (+
// `package:l10n_currencies` for currency names). Where intl has no knob
// for an ECMA-402 option, the backend degrades loud: nearest supported
// rendering plus a recorded `FluentTypeError` — never a silent drop.
//
// Run with: dart run example/main.dart

import 'package:fluent_intl/fluent_intl.dart';

/// Every section of the tour, as `label: value` lines. The example test
/// asserts on these — keep labels stable.
List<String> runShowcase() => [
  ...numberShowcase(),
  ...currencyShowcase(),
  ...datetimeShowcase(),
  ...pluralShowcase(),
  ...degradeShowcase(),
];

/// A bundle for [locale] with [ftl] loaded, formatting through intl.
FluentBundle bundleFor(String locale, String ftl) =>
    FluentBundle(locale, backend: IntlBackend(), useIsolating: false)
      ..addResource(ftl);

// ── §1 Numbers — grouping, percent, compact, numbering systems ─────────

List<String> numberShowcase() {
  const ftl = r'''
plain = { NUMBER($n) }
pct = { NUMBER($share, style: "percent") }
compact = { NUMBER($n, notation: "compact") }
sci = { NUMBER($n, notation: "scientific") }
''';
  final en = bundleFor('en', ftl);
  final de = bundleFor('de', ftl);
  final hi = bundleFor('hi', ftl);
  return [
    'number.en: ${en.formatMessage('plain', args: {'n': 1234567.89})}',
    'number.de: ${de.formatMessage('plain', args: {'n': 1234567.89})}',
    // Hindi groups 12,34,567 — lakh/crore grouping, straight from CLDR.
    'number.hi: ${hi.formatMessage('plain', args: {'n': 1234567.89})}',
    // ECMA percent scales ×100: 0.42 renders as 42%.
    'number.percent: ${en.formatMessage('pct', args: {'share': 0.42})}',
    'number.compact: ${en.formatMessage('compact', args: {'n': 1234000})}',
    'number.scientific: ${en.formatMessage('sci', args: {'n': 123456})}',
  ];
}

// ── §2 Currency — symbols, minor units, spelled-out names ──────────────

List<String> currencyShowcase() {
  const ftl = r'''
price = { NUMBER($amount, style: "currency", currency: "USD") }
yen = { NUMBER($amount, style: "currency", currency: "JPY") }
spelled = { NUMBER($amount, style: "currency", currency: "EUR", currencyDisplay: "name") }
''';
  final en = bundleFor('en', ftl);
  return [
    'currency.usd: ${en.formatMessage('price', args: {'amount': 1234.5})}',
    // JPY has zero minor units — no decimals, from intl's currency data.
    'currency.jpy: ${en.formatMessage('yen', args: {'amount': 1234.5})}',
    // currencyDisplay: "name" spells the currency out (l10n_currencies).
    'currency.name: ${en.formatMessage('spelled', args: {'amount': 2})}',
  ];
}

// ── §3 Dates and times — styles, field bags, hour12 ────────────────────

List<String> datetimeShowcase() {
  const ftl = r'''
styled = { DATETIME($at, dateStyle: "full", timeStyle: "short") }
fields = { DATETIME($at, year: "numeric", month: "long", day: "numeric") }
clock = { DATETIME($at, hour: "numeric", minute: "2-digit", hour12: "false") }
''';
  final at = DateTime(2026, 1, 15, 14, 5);
  final en = bundleFor(
    'en',
    'styled = { DATETIME(\$at, dateStyle: "full", timeStyle: "short") }',
  );
  final de = bundleFor('de', ftl);
  return [
    'datetime.styled.en: ${en.formatMessage('styled', args: {'at': at})}',
    'datetime.fields.de: ${de.formatMessage('fields', args: {'at': at})}',
    // intl composes bare-time skeletons with a leading separator space —
    // shown verbatim (trimmed here only to keep the tour output tidy).
    'datetime.h23.de: ${de.formatMessage('clock', args: {'at': at}).trim()}',
  ];
}

// ── §4 Plurals — CLDR cardinals plus ordinals ("1st", "2nd", "3rd") ────

List<String> pluralShowcase() {
  const ftl = r'''
items = { $count ->
    [one] { $count } item
   *[other] { $count } items
}
place = { NUMBER($pos, type: "ordinal") ->
    [one] { $pos }st
    [two] { $pos }nd
    [few] { $pos }rd
   *[other] { $pos }th
}
''';
  final en = bundleFor('en', ftl);
  String items(num n) => en.formatMessage('items', args: {'count': n});
  String place(num n) => en.formatMessage('place', args: {'pos': n});
  return [
    'plural.cardinal: ${items(1)} / ${items(2)}',
    'plural.ordinal: ${place(1)}, ${place(2)}, ${place(3)}, ${place(4)}',
  ];
}

// ── §5 The degrade contract — unsupported options fail LOUD ────────────

List<String> degradeShowcase() {
  // package:intl has no roundingMode knob. The backend renders the
  // nearest supported form AND records a FluentTypeError — the harness
  // in the core proves this both directions for every declared gap.
  final en = bundleFor(
    'en',
    r'rounded = { NUMBER($n, roundingMode: "floor") }',
  );
  final errors = <FluentError>[];
  final output = en.formatMessage('rounded', args: {'n': 2.9}, errors: errors);
  return [
    'degrade.output: $output',
    'degrade.errors: ${errors.length}',
    'degrade.kind: ${errors.single.runtimeType}',
  ];
}

void main() => runShowcase().forEach(print);
