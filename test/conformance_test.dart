import 'package:fluent_bundle/testing.dart';
import 'package:fluent_intl/fluent_intl.dart';
import 'package:test/test.dart';

void main() {
  group('IntlBackend conformance', () {
    // intl gives real CLDR categories AND honors visible fraction digits
    // (the resolveDigits precision is threaded into Intl.pluralLogic), so
    // both plural flags stay at their default `true`.
    //
    // package:intl's honest capability set: compact notation, scientific
    // notation (coarse #E0 pattern — real exponent output, limited
    // fidelity), and hourCycle (via the j/H skeleton family) are wired.
    // signDisplay / roundingMode / roundingIncrement / trailingZeroDisplay
    // / numberingSystem / accounting / grouping strategies have NO
    // package:intl equivalent — recordsUnsupportedOptionErrors proves each
    // degrades to the locale-default rendering WITH a recorded error,
    // never silently.
    const expectations = BackendExpectations(
      signDisplay: false,
      roundingMode: false,
      roundingIncrement: false,
      trailingZeroDisplay: false,
      numberingSystem: false,
      groupingStrategies: false,
      calendar: false,
      timeZone: false,
      scientificNotation: true,
      recordsUnsupportedOptionErrors: true,
    );
    for (final check in fluentBackendConformanceChecks(
      IntlBackend.new,
      expectations: expectations,
    )) {
      test(check.name, check.run);
    }
  });
}
