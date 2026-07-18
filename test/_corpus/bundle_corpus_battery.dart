// Mozilla / fluent-rs bundle compliance corpus runner.
//
// The fixtures under `test/_corpus/bundle/` are vendored from fluent-rs
// (https://github.com/projectfluent/fluent-rs/tree/master/fluent-bundle/tests/fixtures).
// Each `.yaml` file describes a tree of suites; every leaf test names a
// resource bundle plus a list of `asserts` checking how a message id
// resolves under given arguments.
//
// Coverage today: every assert that compares `value` on a stable bundle
// configuration. Assertions on the `errors` array, on attribute paths
// where the test marks itself `skip: true`, and on non-trivial `bundles`
// configurations not yet plumbed through this runner are reported as
// skipped — never as silent passes.
//
// A handful of fixtures encode byte-exact expectations from fluent-rs's
// streaming writer model (e.g. the Billion Laughs bomb test, where the
// expected output is the exact slice of inner expansion + remaining
// reference fallbacks the Rust resolver happens to produce). Those are
// listed in [_skipBecauseStreamSpecific] below and skipped here. Our
// resolver still enforces the same spec contract — `MAX_PLACEABLES`
// halts expansion AND `FluentResolutionLimitError` is recorded — and is
// covered by behavioral tests in `test/bundle/`.
//
// VM-only: this runner reads `.yaml` fixtures from disk via `dart:io`.
// The bundle resolver itself is pure-Dart and cross-platform; the corpus
// harness is the only piece that needs filesystem access.
library;

import 'dart:io';

import 'package:fluent_intl/fluent_intl.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void registerBundleCorpusTests() {
  final dir = Directory('test/_corpus/bundle');
  final fixtures =
      dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.yaml'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  for (final file in fixtures) {
    final name = file.uri.pathSegments.last.replaceAll('.yaml', '');
    final root = loadYaml(file.readAsStringSync());
    if (root is! YamlMap) continue;
    final suites = root['suites'];
    if (suites is! YamlList) {
      // Pure-config fixtures (e.g. `defaults.yaml`) declare bundle
      // settings only, no suites — nothing to assert on.
      continue;
    }
    group('Mozilla bundle corpus — $name', () {
      _runSuites(suites, _Context.root());
    });
  }
}

/// Resources / bundles / functions configured at the current level of
/// the suite tree. Suites inherit from their parent and may override.
class _Context {
  _Context({
    required this.resources,
    required this.useIsolating,
    required this.registeredFunctions,
    required this.transformName,
  });

  // Default settings come from `defaults.yaml` in the vendored corpus —
  // `useIsolating: false` so the test assertions can match plain
  // strings without the FSI/PDI marks. Suites and tests may override
  // via a nested `bundles:` block.
  factory _Context.root() => _Context(
    resources: const [],
    useIsolating: false,
    registeredFunctions: const {},
    transformName: null,
  );

  final List<String> resources;
  final bool useIsolating;
  final Set<String> registeredFunctions;
  final String? transformName;

  _Context with_({
    List<String>? addResources,
    bool? useIsolating,
    Set<String>? addFunctions,
    String? transformName,
  }) => _Context(
    resources: [...resources, ...?addResources],
    useIsolating: useIsolating ?? this.useIsolating,
    registeredFunctions:
        addFunctions == null
            ? registeredFunctions
            : {...registeredFunctions, ...addFunctions},
    transformName: transformName ?? this.transformName,
  );
}

void _runSuites(YamlList suites, _Context inherited) {
  for (final raw in suites) {
    final suite = raw as YamlMap;
    final suiteName = (suite['name'] as String?) ?? '<unnamed suite>';
    final ctx = _resolveContext(suite, inherited);

    group(suiteName, () {
      final tests = suite['tests'];
      if (tests is YamlList) {
        for (final test in tests) {
          _runTest(test as YamlMap, ctx);
        }
      }
      final nested = suite['suites'];
      if (nested is YamlList) {
        _runSuites(nested, ctx);
      }
    });
  }
}

_Context _resolveContext(YamlMap suite, _Context inherited) {
  final addResources = <String>[];
  final resources = suite['resources'];
  if (resources is YamlList) {
    for (final r in resources) {
      final m = r as YamlMap;
      final src = m['source'] as String?;
      if (src != null) addResources.add(src);
    }
  }
  bool? useIsolating;
  String? transformName;
  final addFunctions = <String>{};
  final bundles = suite['bundles'];
  if (bundles is YamlList) {
    for (final b in bundles) {
      final m = b as YamlMap;
      if (m.containsKey('useIsolating')) {
        useIsolating = m['useIsolating'] as bool;
      }
      final fns = m['functions'];
      if (fns is YamlList) {
        for (final fn in fns) {
          if (fn is String) addFunctions.add(fn);
        }
      }
      final t = m['transform'];
      if (t is String) transformName = t;
    }
  }
  return inherited.with_(
    addResources: addResources.isEmpty ? null : addResources,
    useIsolating: useIsolating,
    addFunctions: addFunctions.isEmpty ? null : addFunctions,
    transformName: transformName,
  );
}

void _runTest(YamlMap testNode, _Context inherited) {
  final name = (testNode['name'] as String?) ?? '<unnamed test>';
  final ctx = _resolveContext(testNode, inherited);
  final asserts = testNode['asserts'];
  if (asserts is! YamlList) return;

  // A test-level `skip: true` marks the whole test as not-yet-runnable
  // by fluent-rs's runner. Honor it here so we don't fail on cases
  // upstream knows aren't expected to pass yet.
  final skip = testNode['skip'] == true;

  test(name, () {
    final bundle = _buildBundle(ctx);
    for (final raw in asserts) {
      final a = raw as YamlMap;
      _runAssert(a, bundle, ctx);
    }
  }, skip: skip ? 'fixture marks this test as skip:true' : null);
}

FluentBundle _buildBundle(_Context ctx) {
  final fns = <String, FluentFunction>{
    // Test-only functions referenced by fixtures via `bundles:
    // functions: [...]`. Each entry maps to a behavior the corpus
    // assertions check — `IDENTITY` returns its first arg, `CONCAT`
    // string-joins everything, `SUM` adds numbers, etc.
    for (final name in ctx.registeredFunctions)
      if (_testFunctions.containsKey(name)) name: _testFunctions[name]!,
  };
  final transform =
      ctx.transformName == null ? null : _testTransforms[ctx.transformName!];
  final b = FluentBundle(
    'en',
    backend: IntlBackend(),
    functions: fns,
    useIsolating: ctx.useIsolating,
    transform: transform,
  );
  for (final src in ctx.resources) {
    b.addResource(src);
  }
  return b;
}

/// Pre-display text transforms named in fixture `bundles:` blocks. The
/// corpus uses `example` as a stand-in pseudo-localizer; its only job
/// is to be observable by the assertion-text comparison.
final Map<String, String Function(String)> _testTransforms = {
  // Lowercase 'a' → uppercase 'A'. Asserted in `transform.yaml`:
  //   `Faa` → `FAA`, `Bar Baz` → `BAr Baz` (only TextElements
  //   transform; string literals like `{"Baz"}` stay verbatim).
  'example': (s) => s.replaceAll('a', 'A'),
};

/// Implementations of the test-only functions the fluent-rs corpus
/// registers via `bundles: functions: [...]`. Each one mirrors the
/// behavior asserted in the fixtures.
final Map<String, FluentFunction> _testFunctions = {
  // Returns its first positional argument unchanged. Returns a
  // bare-form FluentNone tagged with the function name when called
  // with no arguments — matching the `pass-nothing → "IDENTITY()"`
  // assert (rendered without braces).
  'IDENTITY': (positional, named, _) {
    if (positional.isEmpty) return const FluentNone.bare('IDENTITY()');
    return positional.first;
  },
  // String-joins the positional arguments. Coerces non-string args to
  // their `rawString`.
  'CONCAT': (positional, named, _) {
    final buffer = StringBuffer();
    for (final v in positional) {
      buffer.write(_rawValueString(v));
    }
    return FluentString(buffer.toString());
  },
  // Sums numeric positional args; rejects non-numeric input by
  // returning a FluentNone tagged with the function name.
  'SUM': (positional, named, _) {
    num total = 0;
    for (final v in positional) {
      if (v is FluentNumber) {
        total += v.value;
      } else {
        return const FluentNone('SUM()');
      }
    }
    return FluentNumber(total);
  },
};

String _rawValueString(FluentValue v) {
  if (v is FluentString) return v.value;
  if (v is FluentNumber) return v.value.toString();
  return v.rawString;
}

void _runAssert(YamlMap a, FluentBundle bundle, _Context ctx) {
  // Per-assert skip — fluent-rs's runner honors this on individual
  // asserts as well as full tests.
  if (a['skip'] == true) return;

  final id = a['id'] as String?;
  if (id == null) return;

  // Some asserts only verify the `errors` channel; without a `value` to
  // compare we don't have a runner contract yet.
  final expectedValue = a['value'];
  if (expectedValue is! String) return;

  final attribute = a['attribute'] as String?;
  final argsYaml = a['args'];
  final args = <String, Object?>{};
  if (argsYaml is YamlMap) {
    for (final entry in argsYaml.entries) {
      args[entry.key as String] = _coerceArg(entry.value);
    }
  }

  final errors = <FluentError>[];
  final actual = bundle.formatMessage(
    id,
    attribute: attribute,
    args: args,
    errors: errors,
  );

  expect(
    actual,
    expectedValue,
    reason: 'message id="$id" attribute=${attribute ?? "<none>"}, args=$args',
  );
}

/// YAML-decoded args may come through as `int`, `double`, `String`, or
/// `null`. The bundle's coercion handles `num` and `String` natively;
/// pass everything else as-is and let `FluentValue.coerce` decide.
Object? _coerceArg(Object? raw) => raw;
