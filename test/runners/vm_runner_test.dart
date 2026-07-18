// VM lane — every battery, including the VM-only ones (the resolver
// corpus reads its fixtures from disk).
//
// Batteries register their groups when called; the call-site group() wrap
// scopes any battery-level setUpAll to that battery alone.
@TestOn('vm')
library;

import 'package:test/test.dart';

import '../_corpus/bundle_corpus_battery.dart';
import '../common/cache_battery.dart';
import '../conformance_battery.dart';
import '../datetime/datetime_map_battery.dart';
import '../example/example_battery.dart';
import '../number/number_map_cache_battery.dart';
import '../number/number_map_battery.dart';
import '../plural/cardinal_battery.dart';
import '../plural/ordinal_cldr_compliance_battery.dart';

void main() {
  group('bundle_corpus', registerBundleCorpusTests);
  group('cache', registerCacheTests);
  group('conformance', registerConformanceTests);
  group('datetime_map', registerDatetimeMapTests);
  group('example', registerExampleTests);
  group('number_map_cache', registerNumberMapCacheTests);
  group('number_map', registerNumberMapTests);
  group('cardinal', registerCardinalTests);
  group('ordinal_cldr_compliance', registerOrdinalCldrComplianceTests);
}
