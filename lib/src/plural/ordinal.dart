import 'package:fluent_bundle/fluent_bundle.dart';

/// CLDR ordinal plural category for [value] in [locale].
///
/// `package:intl` does not ship ordinal rules, so the major locales are
/// inlined here from Unicode CLDR. Locales without an entry fall back to
/// [PluralCategory.other] so the `*[other]` default variant always wins —
/// a translator who needs ordinal-aware variants in an unsupported locale
/// either supplies their own backend or uses numeric variant keys
/// (`[1]`, `[2]`, …) instead.
///
/// Source:
/// https://www.unicode.org/cldr/charts/latest/supplemental/language_plural_rules.html
PluralCategory ordinalCategory(num value, String locale) {
  final lang = _languageOf(locale);
  final rule = _ordinalRules[lang];
  if (rule == null) return PluralCategory.other;
  return rule(value);
}

/// Strip region / script subtags so `'pt-BR'` and `'pt_BR'` both look up
/// the language-level rule for `'pt'`.
String _languageOf(String locale) {
  final lower = locale.toLowerCase();
  final dash = lower.indexOf('-');
  final under = lower.indexOf('_');
  final cut =
      (dash == -1)
          ? under
          : (under == -1 ? dash : (dash < under ? dash : under));
  return cut == -1 ? lower : lower.substring(0, cut);
}

typedef _OrdinalRule = PluralCategory Function(num n);

/// Each rule receives the input and returns the matching CLDR ordinal
/// category. Predicates work on the absolute integer part — fractional
/// ordinals (`1.5th`) are not in CLDR.
final Map<String, _OrdinalRule> _ordinalRules = {
  // Single-category locales — `one` for n=1, everything else `other`.
  // Several distinct languages share this rule shape; we route them
  // through a single implementation. The "_oneIfOne" entries are
  // grouped here both to make the table easy to scan and to make new
  // additions obvious.
  'en': _enOrdinal,
  'fr': _oneIfOne, // French
  'ga': _oneIfOne, // Irish
  'fil': _oneIfOne, // Filipino
  'tl': _oneIfOne, // Tagalog == Filipino in CLDR
  'vi': _oneIfOne, // Vietnamese
  'hy': _oneIfOne, // Armenian
  'lo': _oneIfOne, // Lao
  'ms': _oneIfOne, // Malay
  'ro': _oneIfOne, // Romanian
  'mo': _oneIfOne, // Moldovan (alias of Romanian per CLDR)
  'bal': _oneIfOne, // Baluchi
  // Hindi-family — Indic ordinal pattern. Hindi (hi) and Gujarati
  // (gu) share the rule with the `many` slot at n=6. Marathi (mr)
  // and Konkani (kok) DROP the `many` slot — n=6 routes to `other`,
  // not `many`. Don't quietly merge mr/kok back into `_hiOrdinal`;
  // CLDR distinguishes them and the compliance test catches the
  // drift if the routing is wrong.
  'hi': _hiOrdinal,
  'gu': _hiOrdinal, // identical to Hindi
  'mr': _kokOrdinal, // no `many` — same shape as Konkani
  'kok': _kokOrdinal, // Konkani
  // Bengali-family — extended Indic pattern with `one` covering 1, 5,
  // 7-10. Assamese (as) and Bengali (bn) share the rule exactly. Odia
  // (or) has the SAME categories but `one` only covers 1, 5, 7-9 (no
  // 10), so it routes through a distinct predicate. Easy to lump them
  // together visually; not equivalent in CLDR — verify against
  // upstream `ordinals.json` if you ever re-touch this list.
  'as': _bnOrdinal,
  'bn': _bnOrdinal,
  'or': _orOrdinal,

  // Italian-family — `many` for {8, 11, 80, 800}. Italian itself, plus
  // Sardinian (sc), Ladin (lld), and Venetian (vec) follow the strict
  // form. Ligurian (lij) and Sicilian (scn) extend it with full 80-89
  // and 800-899 ranges; they get a separate rule.
  'it': _itOrdinal,
  'lld': _itOrdinal,
  'sc': _itOrdinal,
  'vec': _itOrdinal,
  'lij': _lijOrdinal,
  'scn': _lijOrdinal, // Sicilian — same extended ranges
  // Slavic + adjacent.
  'be': _beOrdinal,
  'mk': _mkOrdinal,
  'uk': _ukOrdinal,

  // Turkic.
  'az': _azOrdinal,
  'kk': _kkOrdinal,
  'tk': _tkOrdinal,

  // Other multi-category rules.
  'ca': _caOrdinal,
  'cy': _cyOrdinal,
  'hu': _huOrdinal,
  'ka': _kaOrdinal,
  'ne': _neOrdinal,
  'sq': _sqOrdinal,
  'sv': _svOrdinal,

  // Less-common rules.
  'blo': _bloOrdinal, // Anii — zero/one/few/other
  'gd': _gdOrdinal, // Scottish Gaelic — one/two/few overlap teens
  'kw': _kwOrdinal, // Cornish — modular range rule
};

/// `n` as a non-negative integer. CLDR ordinal predicates work on the
/// absolute integer; fractional input is treated as its truncation.
int _absInt(num n) => n.abs().toInt();

PluralCategory _enOrdinal(num value) {
  final n = _absInt(value);
  final mod10 = n % 10;
  final mod100 = n % 100;
  if (mod10 == 1 && mod100 != 11) return PluralCategory.one;
  if (mod10 == 2 && mod100 != 12) return PluralCategory.two;
  if (mod10 == 3 && mod100 != 13) return PluralCategory.few;
  return PluralCategory.other;
}

/// Shared "one ↔ n=1, otherwise other" rule.
///
/// CLDR groups several languages under this minimal shape: French,
/// Irish, Filipino/Tagalog, Vietnamese, Armenian, Lao, Malay,
/// Romanian/Moldovan, Baluchi. Routing them through a single
/// implementation keeps the cardinality of the rule table low and
/// makes the equivalence visible to readers.
PluralCategory _oneIfOne(num value) {
  return _absInt(value) == 1 ? PluralCategory.one : PluralCategory.other;
}

PluralCategory _azOrdinal(num value) {
  // Azerbaijani:
  //   one  — n%10 ∈ {1,2,5,7,8} OR n%100 ∈ {20,50,70,80}
  //   few  — n%10 ∈ {3,4} OR n%1000 ∈ {100,200,300,400,500,600,700,800,900}
  //   many — n=0 OR n%10=6 OR n%100 ∈ {40,60,90}
  //   other — otherwise
  final n = _absInt(value);
  final mod10 = n % 10;
  final mod100 = n % 100;
  final mod1000 = n % 1000;
  if (mod10 == 1 ||
      mod10 == 2 ||
      mod10 == 5 ||
      mod10 == 7 ||
      mod10 == 8 ||
      mod100 == 20 ||
      mod100 == 50 ||
      mod100 == 70 ||
      mod100 == 80) {
    return PluralCategory.one;
  }
  if (mod10 == 3 ||
      mod10 == 4 ||
      mod1000 == 100 ||
      mod1000 == 200 ||
      mod1000 == 300 ||
      mod1000 == 400 ||
      mod1000 == 500 ||
      mod1000 == 600 ||
      mod1000 == 700 ||
      mod1000 == 800 ||
      mod1000 == 900) {
    return PluralCategory.few;
  }
  if (n == 0 || mod10 == 6 || mod100 == 40 || mod100 == 60 || mod100 == 90) {
    return PluralCategory.many;
  }
  return PluralCategory.other;
}

PluralCategory _beOrdinal(num value) {
  // Belarusian: `few` when n%10 ∈ {2,3} AND n%100 ∉ {12,13}.
  final n = _absInt(value);
  final mod10 = n % 10;
  final mod100 = n % 100;
  if ((mod10 == 2 || mod10 == 3) && mod100 != 12 && mod100 != 13) {
    return PluralCategory.few;
  }
  return PluralCategory.other;
}

PluralCategory _caOrdinal(num value) {
  // Catalan: one — n ∈ {1,3}, two — n=2, few — n=4, other — otherwise.
  final n = _absInt(value);
  if (n == 1 || n == 3) return PluralCategory.one;
  if (n == 2) return PluralCategory.two;
  if (n == 4) return PluralCategory.few;
  return PluralCategory.other;
}

PluralCategory _cyOrdinal(num value) {
  // Welsh:
  //   zero — n ∈ {0, 7, 8, 9}
  //   one  — n=1
  //   two  — n=2
  //   few  — n ∈ {3, 4}
  //   many — n ∈ {5, 6}
  //   other — otherwise
  final n = _absInt(value);
  if (n == 0 || n == 7 || n == 8 || n == 9) return PluralCategory.zero;
  if (n == 1) return PluralCategory.one;
  if (n == 2) return PluralCategory.two;
  if (n == 3 || n == 4) return PluralCategory.few;
  if (n == 5 || n == 6) return PluralCategory.many;
  return PluralCategory.other;
}

PluralCategory _hiOrdinal(num value) {
  // Hindi / Marathi / Gujarati share the same ordinal rule:
  //   one — n=1, two — n ∈ {2,3}, few — n=4, many — n=6, other — otherwise.
  final n = _absInt(value);
  if (n == 1) return PluralCategory.one;
  if (n == 2 || n == 3) return PluralCategory.two;
  if (n == 4) return PluralCategory.few;
  if (n == 6) return PluralCategory.many;
  return PluralCategory.other;
}

PluralCategory _huOrdinal(num value) {
  // Hungarian: `one` when n ∈ {1, 5}; otherwise `other`.
  final n = _absInt(value);
  if (n == 1 || n == 5) return PluralCategory.one;
  return PluralCategory.other;
}

PluralCategory _itOrdinal(num value) {
  // Italian: `many` for n ∈ {8, 11, 80, 800}; otherwise `other`.
  final n = _absInt(value);
  if (n == 8 || n == 11 || n == 80 || n == 800) return PluralCategory.many;
  return PluralCategory.other;
}

PluralCategory _kaOrdinal(num value) {
  // Georgian:
  //   one  — n=1
  //   many — n=0 OR n%100 ∈ 2..20 OR n%100 ∈ {40, 60, 80}
  //   other — otherwise
  final n = _absInt(value);
  if (n == 1) return PluralCategory.one;
  final mod100 = n % 100;
  if (n == 0 ||
      (mod100 >= 2 && mod100 <= 20) ||
      mod100 == 40 ||
      mod100 == 60 ||
      mod100 == 80) {
    return PluralCategory.many;
  }
  return PluralCategory.other;
}

PluralCategory _kkOrdinal(num value) {
  // Kazakh CLDR rule: `many` when
  //   n%10 = 6 OR n%10 = 9 OR (n%10 = 0 AND n != 0)
  //
  // The earlier shape "n%10 ∈ {6,9} OR n=10" was wrong — it caught
  // n=10 but missed n=20, 30, 40, 100, 1000, … . CLDR's `n%10 = 0
  // AND n != 0` slots every nonzero multiple-of-ten into `many`,
  // exactly as the example list `[6, 9, 10, 16, 19, 20, …, 100,
  // 1000]` requires. Verified against
  // `test/intl/_cldr_ordinal_examples.dart`.
  final n = _absInt(value);
  final mod10 = n % 10;
  if (mod10 == 6 || mod10 == 9 || (mod10 == 0 && n != 0)) {
    return PluralCategory.many;
  }
  return PluralCategory.other;
}

PluralCategory _mkOrdinal(num value) {
  // Macedonian:
  //   one  — n%10=1 AND n%100≠11
  //   two  — n%10=2 AND n%100≠12
  //   many — n%10 ∈ {7,8} AND n%100 ∉ {17,18}
  //   other — otherwise
  final n = _absInt(value);
  final mod10 = n % 10;
  final mod100 = n % 100;
  if (mod10 == 1 && mod100 != 11) return PluralCategory.one;
  if (mod10 == 2 && mod100 != 12) return PluralCategory.two;
  if ((mod10 == 7 || mod10 == 8) && mod100 != 17 && mod100 != 18) {
    return PluralCategory.many;
  }
  return PluralCategory.other;
}

PluralCategory _neOrdinal(num value) {
  // Nepali: `one` for n ∈ 1..4; otherwise `other`.
  final n = _absInt(value);
  if (n >= 1 && n <= 4) return PluralCategory.one;
  return PluralCategory.other;
}

PluralCategory _sqOrdinal(num value) {
  // Albanian:
  //   one  — n=1
  //   many — n%10=4 AND n%100≠14
  //   other — otherwise
  final n = _absInt(value);
  final mod10 = n % 10;
  final mod100 = n % 100;
  if (n == 1) return PluralCategory.one;
  if (mod10 == 4 && mod100 != 14) return PluralCategory.many;
  return PluralCategory.other;
}

PluralCategory _svOrdinal(num value) {
  // Swedish: `one` when n%10 ∈ {1,2} AND n%100 ∉ {11,12}; otherwise `other`.
  final n = _absInt(value);
  final mod10 = n % 10;
  final mod100 = n % 100;
  if ((mod10 == 1 || mod10 == 2) && mod100 != 11 && mod100 != 12) {
    return PluralCategory.one;
  }
  return PluralCategory.other;
}

PluralCategory _tkOrdinal(num value) {
  // Turkmen: `few` when n%10 ∈ {6, 9} OR n=10; otherwise `other`.
  final n = _absInt(value);
  final mod10 = n % 10;
  if (mod10 == 6 || mod10 == 9 || n == 10) return PluralCategory.few;
  return PluralCategory.other;
}

PluralCategory _ukOrdinal(num value) {
  // Ukrainian: `few` when n%10=3 AND n%100≠13; otherwise `other`.
  final n = _absInt(value);
  if (n % 10 == 3 && n % 100 != 13) return PluralCategory.few;
  return PluralCategory.other;
}

PluralCategory _kokOrdinal(num value) {
  // Konkani: one — n=1, two — n ∈ {2,3}, few — n=4, other — otherwise.
  // Same shape as Hindi without the `many` slot for n=6.
  final n = _absInt(value);
  if (n == 1) return PluralCategory.one;
  if (n == 2 || n == 3) return PluralCategory.two;
  if (n == 4) return PluralCategory.few;
  return PluralCategory.other;
}

PluralCategory _bnOrdinal(num value) {
  // Bengali / Assamese:
  //   one  — n ∈ {1, 5, 7, 8, 9, 10}
  //   two  — n ∈ {2, 3}
  //   few  — n = 4
  //   many — n = 6
  //   other — otherwise
  final n = _absInt(value);
  if (n == 1 || n == 5 || n == 7 || n == 8 || n == 9 || n == 10) {
    return PluralCategory.one;
  }
  if (n == 2 || n == 3) return PluralCategory.two;
  if (n == 4) return PluralCategory.few;
  if (n == 6) return PluralCategory.many;
  return PluralCategory.other;
}

PluralCategory _orOrdinal(num value) {
  // Odia: SAME categories as bn/as except `one` covers {1, 5, 7, 8,
  // 9} only — n=10 falls into `other`. Keeping this distinct from
  // `_bnOrdinal` so a future contributor doesn't quietly merge them.
  final n = _absInt(value);
  if (n == 1 || n == 5 || n == 7 || n == 8 || n == 9) {
    return PluralCategory.one;
  }
  if (n == 2 || n == 3) return PluralCategory.two;
  if (n == 4) return PluralCategory.few;
  if (n == 6) return PluralCategory.many;
  return PluralCategory.other;
}

PluralCategory _gdOrdinal(num value) {
  // Scottish Gaelic:
  //   one — n ∈ {1, 11}
  //   two — n ∈ {2, 12}
  //   few — n ∈ {3, 13}
  //   other — otherwise
  final n = _absInt(value);
  if (n == 1 || n == 11) return PluralCategory.one;
  if (n == 2 || n == 12) return PluralCategory.two;
  if (n == 3 || n == 13) return PluralCategory.few;
  return PluralCategory.other;
}

PluralCategory _kwOrdinal(num value) {
  // Cornish:
  //   one  — n ∈ 1..4 OR n%100 ∈ {1..4, 21..24, 41..44, 61..64, 81..84}
  //   many — n=5 OR n%100 = 5
  //   other — otherwise
  //
  // Note that n=1..4 alone covers {1, 2, 3, 4}; n%100 ∈ 1..4 also
  // captures {101, 102, 103, 104, 201, …}. The mod-100 ranges extend
  // the rule across higher numbers in 20-unit windows.
  final n = _absInt(value);
  if (n >= 1 && n <= 4) return PluralCategory.one;
  final mod100 = n % 100;
  if ((mod100 >= 1 && mod100 <= 4) ||
      (mod100 >= 21 && mod100 <= 24) ||
      (mod100 >= 41 && mod100 <= 44) ||
      (mod100 >= 61 && mod100 <= 64) ||
      (mod100 >= 81 && mod100 <= 84)) {
    return PluralCategory.one;
  }
  if (n == 5 || mod100 == 5) return PluralCategory.many;
  return PluralCategory.other;
}

PluralCategory _lijOrdinal(num value) {
  // Ligurian / Sicilian: `many` for n ∈ {8, 11} OR n%100 ∈ 80..89 OR
  // n%1000 ∈ 800..899. Same structural shape as Italian's rule but
  // extended across each 80-89 / 800-899 range instead of just the
  // exact values 80 and 800.
  final n = _absInt(value);
  if (n == 8 || n == 11) return PluralCategory.many;
  final mod100 = n % 100;
  final mod1000 = n % 1000;
  if (mod100 >= 80 && mod100 <= 89) return PluralCategory.many;
  if (mod1000 >= 800 && mod1000 <= 899) return PluralCategory.many;
  return PluralCategory.other;
}

PluralCategory _bloOrdinal(num value) {
  // Anii (`blo`):
  //   zero — i = 0
  //   one  — i = 1
  //   few  — i ∈ {2, 3, 4, 5, 6}
  //   other — otherwise
  //
  // CLDR keys this rule on `i` (the integer part) — for ordinal
  // input we floor to integer first, so n=2.7 still slots into
  // `few`. (CLDR ordinals are defined for integers; our floor
  // matches every other rule in this file.)
  final n = _absInt(value);
  if (n == 0) return PluralCategory.zero;
  if (n == 1) return PluralCategory.one;
  if (n >= 2 && n <= 6) return PluralCategory.few;
  return PluralCategory.other;
}
