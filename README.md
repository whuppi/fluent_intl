<h1 align="center">fluent_intl</h1>

<p align="center">
  <a href="https://pub.dev/packages/fluent_intl"><img src="https://img.shields.io/pub/v/fluent_intl.svg" alt="pub package"></a>
  <a href="https://pub.dev/packages/fluent_intl/score"><img src="https://img.shields.io/pub/likes/fluent_intl" alt="likes"></a>
  <a href="https://pub.dev/packages/fluent_intl/score"><img src="https://img.shields.io/pub/points/fluent_intl" alt="pub points"></a>
  <a href="https://github.com/whuppi/fluent_intl"><img src="https://img.shields.io/github/stars/whuppi/fluent_bundle?style=flat&logo=github" alt="GitHub stars"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="license: MIT"></a>
</p>

The zero-setup CLDR backend for [`fluent_bundle`](https://pub.dev/packages/fluent_bundle). Plug it into a bundle and Fluent's `[one]` / `[few]` / `[many]` variants fire per real CLDR plural rules, and `NUMBER` / `DATETIME` render locale-aware — grouping, currency symbols, minor units, date styles — through `package:intl`.

No initialization, no native code, no assets. Construct `IntlBackend()` and go. Pure Dart on every platform.

> **This is a backend — an add-on, not a starting point.** Flutter apps start at [`fluent_flutter`](https://pub.dev/packages/fluent_flutter); pure Dart starts at [`fluent_bundle`](https://pub.dev/packages/fluent_bundle). Between the two backends, this one is the lightweight default; when you need the options `package:intl` has no knob for (measurement units, non-Gregorian calendars, time zones, numbering systems, every-locale ordinals), that's [`fluent_icu`](https://pub.dev/packages/fluent_icu) — same FTL, same call sites, swap the constructor.

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
- [Error handling — the degrade contract](#error-handling--the-degrade-contract)
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
  fluent_intl:
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

That's the whole integration. Everything else — messages, selectors, markup, chains, errors — is `fluent_bundle`'s surface, unchanged; this package only decides how numbers, dates, and plural categories render.

---

## Usage

One `NUMBER` / `DATETIME` option family per section. Every snippet's output is pinned by the example test.

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

// ECMA-402 percent scales ×100 — pass the fraction, not the percentage:
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

Both shapes work: the two-knob `dateStyle` / `timeStyle` presets, and the per-field bags (`year`, `month`, `day`, `hour`, `minute`, …) composed into an intl skeleton.

### Plurals and ordinals

The reason a backend exists at all — CLDR category selection for Fluent's selectors:

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

Cardinals cover every CLDR locale. Ordinals are this package's own contribution — `package:intl` ships no ordinal rules, so the 42 CLDR locales with non-trivial ones are inlined here and compliance-tested against CLDR. Beyond those, categories fall back to `other`; [`fluent_icu`](https://pub.dev/packages/fluent_icu) covers every locale.

---

## Error handling — the degrade contract

`package:intl` has no knob for some ECMA-402 options (`roundingMode`, `signDisplay`, measurement units, calendars, time zones). This backend never silently drops one: it renders the nearest supported form **and** records a `FluentTypeError` in the caller's error list.

```dart
final en = FluentBundle('en', backend: IntlBackend(), useIsolating: false)
  ..addResource(r'rounded = { NUMBER($n, roundingMode: "floor") }');

final errors = <FluentError>[];
final out = en.formatMessage('rounded', args: {'n': 2.9}, errors: errors);
// out:    "2.9"               ← nearest supported rendering
// errors: [FluentTypeError]   ← the gap, on the record
```

Users see reasonable output; QA sees every gap in the error stream. The core's conformance harness proves this in both directions for every declared gap — supported options render with zero errors, unsupported ones degrade with exactly one. The full support matrix per option lives in [Capabilities](docs/CAPABILITY_ROADMAP.md).

Everything else about errors is [`fluent_bundle`'s contract](https://pub.dev/packages/fluent_bundle): inert values, never throws.

---

## Platform support

Pure Dart, no conditional imports, no platform code:

| Android | iOS | macOS | Windows | Linux | Web | Servers / CLI |
|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

---

## Not in the box

What `package:intl` can't do, this backend can't either — by design it degrades loud (see above) rather than approximating quietly:

- **Measurement units** (`style: "unit"`), **non-Gregorian calendars**, **time zones**, **numbering systems**, **`signDisplay` / `roundingMode`** — [`fluent_icu`](https://pub.dev/packages/fluent_icu) renders all of these, on the same FTL.
- **Ordinal rules beyond the 42 inlined locales** — same answer.
- **Message translation workflow** (ARB catalogs, extraction) — different job; this package formats, it doesn't manage translations.

---

## Docs

The README covers the everyday stuff. wanna go deeper?

| Doc | What's inside |
|---|---|
| [Architecture](docs/ARCHITECTURE.md) | How it's built: the backend surface, the option mapping, the degrade walls |
| [Capabilities](docs/CAPABILITY_ROADMAP.md) | The per-option support matrix: rendered, degraded, or spec-fallback |
| [Updating](docs/UPDATING.md) | Maintenance recipes and the upstream (intl) watchlist |
| [Example](example/) | The whole tour in one runnable file, output pinned by test |

---

## License

MIT. See [LICENSE](LICENSE).
