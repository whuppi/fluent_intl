// Chrome lane — every dual-world battery (the same logic as the VM lane,
// minus the vm-only batteries; the `test-guards` target enforces the
// battery/runner completeness rules).
@TestOn('browser')
library;

import 'package:test/test.dart';

import '../common/cache_battery.dart';
import '../conformance_battery.dart';
import '../datetime/datetime_map_battery.dart';
import '../example/example_battery.dart';
import '../number/number_map_cache_battery.dart';
import '../number/number_map_battery.dart';
import '../plural/cardinal_battery.dart';
import '../plural/ordinal_cldr_compliance_battery.dart';

void main() {
  group('cache', registerCacheTests);
  group('conformance', registerConformanceTests);
  group('datetime_map', registerDatetimeMapTests);
  group('example', registerExampleTests);
  group('number_map_cache', registerNumberMapCacheTests);
  group('number_map', registerNumberMapTests);
  group('cardinal', registerCardinalTests);
  group('ordinal_cldr_compliance', registerOrdinalCldrComplianceTests);
}
