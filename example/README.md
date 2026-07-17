# fluent_intl example

A console tour exercising every backend capability — locale-grouped
numbers, ECMA percent scaling, compact and coarse scientific notation,
currency with real minor-unit digits and spelled-out names, date
styles and field bags, a forced 24-hour clock, CLDR cardinal plurals,
inlined ordinal rules, and the degrade contract for the knobs
package:intl doesn't have. `IntlBackend` needs no initialization and
no assets — construct it and go. The tour runs anywhere `dart` runs.

## Run

```bash
# from the package root
fvm dart run example/main.dart
```

## Tests

```bash
# from the package root
make test-example

# or directly
fvm dart test test/example
```

The test runs this exact showcase and pins every output line, so every
claim in the tour is proven on every run. The pins are CLDR renderings
through package:intl — if one moves on an intl bump, the showcase text
moved too: re-verify, then re-pin. (One pin is byte-picky on purpose:
CLDR separates a time from its dayPeriod with U+202F, a narrow
no-break space, not an ASCII space.)

## What's inside

Five sections, one per capability area:

| Section | Surface | What it covers |
|---|---|---|
| **Numbers** | `NUMBER` | Grouping per locale (en / de / hi lakh-crore), ECMA percent ×100, compact notation (`1.2M`), coarse scientific (`1E5`) |
| **Currency** | `NUMBER` | USD symbol placement, JPY's zero minor units from intl's currency data, `currencyDisplay: name` spelled out via l10n_currencies |
| **Dates** | `DATETIME` | `dateStyle: full` + `timeStyle: short`, field bags in German, `hour12: false` forcing the 24-hour cycle |
| **Plurals** | select expressions | CLDR cardinals, and English ordinals (`1st, 2nd, 3rd, 4th`) through the inlined ordinal rules — intl ships none |
| **Degrade** | the gaps | `roundingMode` (no intl knob): nearest supported rendering PLUS a recorded `FluentTypeError` — never a silent drop |

## One file on purpose

The whole tour lives in `main.dart` because pub.dev renders that file
as the package's Example tab — splitting it would hide everything else
from that page.

## Zero setup on purpose

This backend is the family's instant-start option: pure Dart over
package:intl, nothing to download, nothing to compile. The trade is
fidelity — the full ECMA-402 surface (units, calendars, time zones,
every ordinal locale) lives in fluent_icu; the family option matrix in
`fluent_bundle/docs/CAPABILITY_ROADMAP.md` maps every cell.
