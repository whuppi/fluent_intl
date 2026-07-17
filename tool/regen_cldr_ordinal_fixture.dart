// Regenerator for `test/plural/_cldr_ordinal_examples.dart`.
//
// Pulls CLDR's `ordinals.json` from the upstream `unicode-org/cldr-json`
// repo and writes a Dart const file containing three sections:
//
//   1. `cldrOrdinalExamples` — per-locale, per-category integer
//      examples for every locale we actively support.
//   2. `cldrAllOrdinalLocales` — every locale CLDR ships an ordinal
//      rule for. Used by the compliance test to catch orphans (a
//      locale we registered that CLDR no longer ships).
//   3. `cldrNonTrivialOrdinalLocales` — the subset of CLDR locales
//      whose ordinal rule is something other than "everything is
//      `other`". Used by the compliance test to catch coverage gaps
//      (a CLDR non-trivial locale we don't support).
//
// The compliance test in `test/plural/ordinal_cldr_compliance_test.dart`
// uses all three sections to fire LOUD on any drift between the
// CLDR snapshot baked into the fixture and our predicates in
// `lib/src/plural/ordinal.dart`. There is no manual audit step —
// after running this regen, `dart test` is the gate.
//
// Usage:
//   fvm dart run tool/regen_cldr_ordinal_fixture.dart
//   fvm dart test test/plural/ordinal_cldr_compliance_test.dart
//
// New failures point at one of three things:
//   - A CLDR non-trivial locale we don't support → add a predicate
//     in `lib/src/plural/ordinal.dart` and register here in
//     `kSupportedLocales`, then rerun.
//   - A locale we registered but CLDR no longer ships → remove from
//     `kSupportedLocales` and (probably) from `_ordinalRules`.
//   - A predicate diverges from CLDR for a specific integer → fix
//     the predicate.
//
// The script lives under `tool/` (Dart's standard convention for
// build-time scripts that aren't part of the published package).

import 'dart:convert';
import 'dart:io';

/// Locales for which `lib/src/plural/ordinal.dart` defines an
/// inlined ordinal rule. MUST match the keys of `_ordinalRules`.
///
/// CLDR distinguishes script-suffixed locale variants (e.g. `kok-Latn`
/// vs `kok`). Our `_languageOf` strips script and region subtags, so
/// both resolve to the same predicate at runtime. List every CLDR key
/// — including script variants — that should be verified.
const Set<String> kSupportedLocales = {
  'en',
  // single-category (one ↔ n=1)
  'fr', 'ga', 'fil', 'tl', 'vi', 'hy', 'lo', 'ms', 'ro', 'mo', 'bal',
  // Hindi-family
  'hi', 'mr', 'gu', 'kok', 'kok-Latn',
  // Bengali-family
  'as', 'bn', 'or',
  // Italian-family
  'it', 'lld', 'sc', 'vec', 'lij', 'scn',
  // Slavic
  'be', 'mk', 'uk',
  // Turkic
  'az', 'kk', 'tk',
  // Other multi-category
  'ca', 'cy', 'hu', 'ka', 'ne', 'sq', 'sv',
  // Less-common
  'blo', 'gd', 'kw',
};

/// Where the generated fixture lands. Path is relative to the package
/// root (the script's `Directory.current` when invoked via `dart run`).
const String kOutputPath = 'test/plural/_cldr_ordinal_examples.dart';

/// CLDR data URL (master / latest). When running this script, expect
/// the resulting file's `Generated` line to match whatever CLDR HEAD
/// happens to be the day you run it.
final Uri kCldrUrl = Uri.parse(
  'https://raw.githubusercontent.com/unicode-org/cldr-json/main/cldr-json/cldr-core/supplemental/ordinals.json',
);

/// Parse CLDR's `@integer 1, 5, 7~10, 100, 1000, …` syntax into a
/// finite list of integers. The `…` sentinel and any value at or
/// above 100,000 are dropped — every CLDR ordinal predicate that
/// behaves a certain way at 100,000 also behaves that way at 1,000,
/// so excluding the larger numbers keeps the table small without
/// losing categorization coverage.
List<int> parseIntegerList(String s) {
  final out = <int>[];
  for (final raw in s.split(',')) {
    final part = raw.trim();
    if (part.isEmpty || part == '…') continue;
    final maybeInt = int.tryParse(part);
    if (maybeInt != null) {
      if (maybeInt >= 100000) continue;
      out.add(maybeInt);
      continue;
    }
    if (part.contains('~')) {
      final parts = part.split('~');
      final lo = int.parse(parts[0].trim());
      final hi = int.parse(parts[1].trim());
      for (var i = lo; i <= hi; i++) {
        if (i >= 100000) continue;
        out.add(i);
      }
    }
  }
  return out;
}

/// True if [byCategory] declares only the `other` category. CLDR
/// emits a single `pluralRule-count-other` entry for locales whose
/// ordinal rule is "everything is `other`" — those are byte-
/// equivalent to fall-through, no predicate required.
bool isTrivialRule(Map<String, dynamic> byCategory) {
  if (byCategory.length != 1) return false;
  return byCategory.keys.first == 'pluralRule-count-other';
}

Future<void> main() async {
  final client = HttpClient();
  final req = await client.getUrl(kCldrUrl);
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  client.close();

  final json = jsonDecode(body) as Map<String, dynamic>;
  final rules = (json['supplemental']
      as Map<String, dynamic>)['plurals-type-ordinal'] as Map<String, dynamic>;

  // Build the inventory. `allLocales` is sorted for determinism so
  // the file diff is minimal across regens.
  final allLocales = rules.keys.toList()..sort();
  final nonTrivialLocales = <String>[];
  for (final loc in allLocales) {
    final byCat = rules[loc] as Map<String, dynamic>;
    if (!isTrivialRule(byCat)) nonTrivialLocales.add(loc);
  }

  final buf = StringBuffer();
  buf.writeln('// AUTOGENERATED. Do not edit by hand — regenerate with:');
  buf.writeln('//   fvm dart run tool/regen_cldr_ordinal_fixture.dart');
  buf.writeln('//');
  buf.writeln('// Source: $kCldrUrl');
  buf.writeln('// Generated: ${DateTime.now().toUtc().toIso8601String()}');
  buf.writeln('//');
  buf.writeln('// Three sections:');
  buf.writeln('//   - cldrOrdinalExamples: per-locale per-category integer');
  buf.writeln('//     examples for every locale we actively verify.');
  buf.writeln('//   - cldrAllOrdinalLocales: every CLDR ordinal locale.');
  buf.writeln('//     Used by the compliance test to fail loud when a');
  buf.writeln('//     supported-locale entry no longer exists upstream.');
  buf.writeln('//   - cldrNonTrivialOrdinalLocales: CLDR locales with a');
  buf.writeln('//     non-`other` rule. Used by the compliance test to');
  buf.writeln('//     fail loud when CLDR adds a non-trivial locale we');
  buf.writeln('//     do not yet support.');
  buf.writeln('');

  // Section 1: examples per supported locale.
  buf.writeln('/// Per-locale, per-category integer examples lifted');
  buf.writeln('/// verbatim from CLDR for every locale in');
  buf.writeln('/// `tool/regen_cldr_ordinal_fixture.dart`\'s');
  buf.writeln('/// `kSupportedLocales`.');
  buf.writeln(
    'const Map<String, Map<String, List<int>>> cldrOrdinalExamples = {',
  );
  for (final loc in (kSupportedLocales.toList()..sort())) {
    final raw = rules[loc];
    if (raw == null) continue; // orphan check happens in the test
    final byCat = raw as Map<String, dynamic>;
    buf.writeln("  '$loc': {");
    for (final entry in byCat.entries) {
      final cat = entry.key.replaceAll('pluralRule-count-', '');
      final spec = entry.value as String;
      final at = spec.indexOf('@integer');
      if (at == -1) continue;
      final intList = spec.substring(at + '@integer'.length);
      final ints = parseIntegerList(intList);
      buf.writeln("    '$cat': [${ints.join(', ')}],");
    }
    buf.writeln('  },');
  }
  buf.writeln('};');
  buf.writeln('');

  // Section 2: every CLDR locale.
  buf.writeln('/// Every locale CLDR ships an ordinal rule for. The');
  buf.writeln('/// compliance test cross-checks our supported set');
  buf.writeln('/// against this — any registered locale not in CLDR');
  buf.writeln('/// is an orphan and fails the suite.');
  buf.writeln('const Set<String> cldrAllOrdinalLocales = {');
  for (final loc in allLocales) {
    buf.writeln("  '$loc',");
  }
  buf.writeln('};');
  buf.writeln('');

  // Section 3: non-trivial CLDR locales.
  buf.writeln('/// CLDR locales whose ordinal rule is something other');
  buf.writeln('/// than "everything is `other`". The compliance test');
  buf.writeln('/// cross-checks our supported set against this — any');
  buf.writeln('/// CLDR non-trivial locale we do NOT support fails the');
  buf.writeln('/// suite. (Trivial CLDR locales fall through to');
  buf.writeln('/// `PluralCategory.other` correctly without a');
  buf.writeln('/// dedicated predicate.)');
  buf.writeln('const Set<String> cldrNonTrivialOrdinalLocales = {');
  for (final loc in nonTrivialLocales) {
    buf.writeln("  '$loc',");
  }
  buf.writeln('};');
  buf.writeln('');

  // Section 4: the supported set itself, mirrored from this script.
  // The compliance test reads this constant — keeping it in the
  // generated fixture means the test never has to import the regen
  // script, and future contributors can read the file in isolation.
  buf.writeln('/// Locales `lib/src/plural/ordinal.dart` registers');
  buf.writeln('/// an inlined predicate for. Mirrored from');
  buf.writeln('/// `tool/regen_cldr_ordinal_fixture.dart`\'s');
  buf.writeln('/// `kSupportedLocales`. If you add a locale here,');
  buf.writeln('/// regenerate the fixture so this entry updates too.');
  buf.writeln('const Set<String> supportedOrdinalLocales = {');
  for (final loc in (kSupportedLocales.toList()..sort())) {
    buf.writeln("  '$loc',");
  }
  buf.writeln('};');

  await File(kOutputPath).writeAsString(buf.toString());
  // Normalize to the formatter's shape so the emitted fixture matches
  // what the format gate enforces — a regen never shows style-only diffs.
  final fmt =
      await Process.run(Platform.resolvedExecutable, ['format', kOutputPath]);
  if (fmt.exitCode != 0) {
    stderr.write(fmt.stderr);
    exitCode = fmt.exitCode;
    return;
  }
  stdout.writeln('Wrote $kOutputPath');
  stdout.writeln(
    '  ${allLocales.length} CLDR locales total, '
    '${nonTrivialLocales.length} non-trivial, '
    '${kSupportedLocales.length} supported.',
  );
}
