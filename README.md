<h1 align="center">fluent_intl</h1>

<p align="center">
  <a href="https://pub.dev/packages/fluent_intl"><img src="https://img.shields.io/pub/v/fluent_intl.svg" alt="pub package"></a>
  <a href="https://pub.dev/packages/fluent_intl/score"><img src="https://img.shields.io/pub/likes/fluent_intl" alt="likes"></a>
  <a href="https://pub.dev/packages/fluent_intl/score"><img src="https://img.shields.io/pub/points/fluent_intl" alt="pub points"></a>
  <a href="https://github.com/whuppi/fluent_intl"><img src="https://img.shields.io/github/stars/whuppi/fluent_intl?style=flat&logo=github" alt="GitHub stars"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="license: MIT"></a>
</p>

The zero-setup formatting backend for [`fluent_bundle`](https://pub.dev/packages/fluent_bundle). Add it to a bundle, and Fluent's `[one]` / `[few]` / `[many]` plural cases start matching by each language's real rules, while `NUMBER` and `DATETIME` format the local way — digit grouping, currency symbols, the right number of decimal places, date styles — using `package:intl`.

No initialization, no native code, no assets. Construct `IntlBackend()` and go. Pure Dart on every platform.

> **This is a backend — an add-on, not a starting point.** Flutter apps start at [`fluent_flutter`](https://pub.dev/packages/fluent_flutter); pure Dart starts at [`fluent_bundle`](https://pub.dev/packages/fluent_bundle). Of the two backends, this is the lighter default. When you need something `package:intl` has no option for — measurement units, non-Gregorian calendars, time zones, other digit systems, ordinals for every language — switch to [`fluent_icu`](https://pub.dev/packages/fluent_icu): same `.ftl`, same calls, one changed line.

> **Status:** 0.x. The API can change between minor versions until `1.0.0` — pre-1.0, the minor is the breaking axis, so pin `^0.N.0` and read the changelog on minor bumps.

> like it? a [⭐ star](https://github.com/whuppi/fluent_intl) or [👍 like](https://pub.dev/packages/fluent_intl) is the entire marketing budget. [Bugs & features →](https://github.com/whuppi/fluent_intl/issues)

---

<details>
<summary><b>👀 Peek inside</b></summary>

- [Install](#install)
- [Quick start](#quick-start)
- [Usage](#usage)
  - [Numbers](#numbers)
  - [Currency](#currency)
  - [Dates and times](#dates-and-times)
  - [Plurals and ordinals](#plurals-and-ordinals)
- [Error handling — when an option can't be applied](#error-handling--when-an-option-cant-be-applied)
- [Platform support](#platform-support)
- [Not in the box](#not-in-the-box)
- [Docs](#docs)
- [License](#license)

</details>

---

## Install

```yaml
dependencies:
  fluent_bundle:
  fluent_intl: ^0.1.0-dev.0
```

Nothing else to do, on any platform.

---

## Quick start

Same bundle, one extra constructor argument — and the plural rules become real:

```dart
import 'package:fluent_intl/fluent_intl.dart';   // re-exports fluent_bundle

final bundle = FluentBundle('en', backend: IntlBackend())..addResource(r'''
items = { $count ->
    [one] { $count } item
   *[other] { $count } items
}
price = { NUMBER($amount, style: "currency", currency: "USD") }
''');

print(bundle.formatMessage('items', args: {'count': 1}));       // "1 item"
print(bundle.formatMessage('items', args: {'count': 5}));       // "5 items"
print(bundle.formatMessage('price', args: {'amount': 1234.5})); // "$1,234.50"
```

That's the whole integration. Everything else — messages, selectors, markup, fallback, errors — works exactly as it does in `fluent_bundle`; this package only decides how numbers, dates, and plural categories come out.

---

## Usage

One group of `NUMBER` / `DATETIME` options per section. Every result below is checked by the example test.

### Numbers

```dart
const ftl = r'''
plain = { NUMBER($n) }
pct = { NUMBER($share, style: "percent") }
compact = { NUMBER($n, notation: "compact") }
sci = { NUMBER($n, notation: "scientific") }
''';

// Same value, three locales — separators, and even the GROUPS, differ:
en.formatMessage('plain', args: {'n': 1234567.89});   // "1,234,567.89"
de.formatMessage('plain', args: {'n': 1234567.89});   // "1.234.567,89"
hi.formatMessage('plain', args: {'n': 1234567.89});   // "12,34,567.89"  ← lakh/crore grouping

// Percent multiplies the value by 100 — pass the fraction, not the percentage:
en.formatMessage('pct', args: {'share': 0.42});       // "42%"

en.formatMessage('compact', args: {'n': 1234000});    // "1.2M"
en.formatMessage('sci', args: {'n': 123456});         // "1E5"
```

### Currency

```dart
const ftl = r'''
price = { NUMBER($amount, style: "currency", currency: "USD") }
yen = { NUMBER($amount, style: "currency", currency: "JPY") }
spelled = { NUMBER($amount, style: "currency", currency: "EUR", currencyDisplay: "name") }
''';

en.formatMessage('price', args: {'amount': 1234.5});   // "$1,234.50"

// JPY has zero minor units — no decimals, and no code to write for it:
en.formatMessage('yen', args: {'amount': 1234.5});     // "¥1,235"

// currencyDisplay: "name" spells the currency out:
en.formatMessage('spelled', args: {'amount': 2});      // "2.00 Euro"
```

### Dates and times

```dart
const ftl = r'''
styled = { DATETIME($at, dateStyle: "full", timeStyle: "short") }
fields = { DATETIME($at, year: "numeric", month: "long", day: "numeric") }
clock = { DATETIME($at, hour: "numeric", minute: "2-digit", hour12: "false") }
''';
final at = DateTime(2026, 1, 15, 14, 5);

en.formatMessage('styled', args: {'at': at});
// "Thursday, January 15, 2026 2:05 PM"

de.formatMessage('fields', args: {'at': at});   // "15. Januar 2026"
de.formatMessage('clock', args: {'at': at});    // "14:05"
```

Both styles work: the two presets `dateStyle` / `timeStyle`, and the per-field options (`year`, `month`, `day`, `hour`, `minute`, …) combined into a custom format.

### Plurals and ordinals

The main reason to add a backend — picking the right plural category for Fluent's selectors:

```dart
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

en.formatMessage('items', args: {'count': 1});   // "1 item"
en.formatMessage('items', args: {'count': 2});   // "2 items"

// type: "ordinal" switches the category rules — "1st, 2nd, 3rd, 4th":
[1, 2, 3, 4].map((n) => en.formatMessage('place', args: {'pos': n}));
// "1st", "2nd", "3rd", "4th"
```

Cardinal plurals ("1 item" / "5 items") work for every language. Ordinals ("1st, 2nd, 3rd") are this package's own addition — `package:intl` ships none — so the languages with non-trivial ordinal rules are built in here and tested against the Unicode data. Other languages fall back to the catch-all category; [`fluent_icu`](https://pub.dev/packages/fluent_icu) covers every language.

---

## Error handling — when an option can't be applied

`package:intl` has no setting for some options (`roundingMode`, `signDisplay`, measurement units, calendars, time zones). This backend never quietly ignores one: it renders the closest form it can **and** records a `FluentTypeError` in the error list you pass in.

```dart
final en = FluentBundle('en', backend: IntlBackend(), useIsolating: false)
  ..addResource(r'rounded = { NUMBER($n, roundingMode: "floor") }');

final errors = <FluentError>[];
final out = en.formatMessage('rounded', args: {'n': 2.9}, errors: errors);
// out:    "2.9"               ← nearest supported rendering
// errors: [FluentTypeError]   ← the gap, on the record
```

Users see reasonable output; your tests see every gap. `fluent_bundle`'s test harness checks both directions for every known gap — supported options render with no error, unsupported ones fall back with exactly one. The full per-option list is in [Capabilities](docs/CAPABILITY_ROADMAP.md).

Everything else about errors follows [`fluent_bundle`'s rule](https://pub.dev/packages/fluent_bundle): failures are values, never thrown.

---

## Platform support

Pure Dart, no conditional imports, no platform code:

| Android | iOS | macOS | Windows | Linux | Web | Servers / CLI |
|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

---

## Not in the box

What `package:intl` can't do, this backend can't either — and by design it says so out loud (see above) instead of quietly guessing:

- **Measurement units** (`style: "unit"`), **non-Gregorian calendars**, **time zones**, **numbering systems**, **`signDisplay` / `roundingMode`** — [`fluent_icu`](https://pub.dev/packages/fluent_icu) renders all of these, on the same FTL.
- **Ordinal rules beyond the inlined locales** — same answer.
- **Message translation workflow** (ARB catalogs, extraction) — different job; this package formats, it doesn't manage translations.

---

## Docs

The README covers the everyday stuff. wanna go deeper?

| Doc | What's inside |
|---|---|
| [Architecture](docs/ARCHITECTURE.md) | How it's built: the backend, how options map across, where it falls back |
| [Capabilities](docs/CAPABILITY_ROADMAP.md) | Every option, and whether it renders fully, falls back, or isn't supported |
| [Updating](docs/UPDATING.md) | Maintenance recipes and the upstream (intl) watchlist |
| [Example](example/) | The whole tour in one runnable file, output checked by test |

---

## License

MIT. See [LICENSE](LICENSE).
