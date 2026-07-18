// Runs the pub.dev showcase (example/main.dart) and pins its output —
// every claim on the Example tab stays proven. Values are CLDR renderings
// through package:intl; a pin moving on an intl bump means the showcase
// text moved too — re-verify, then re-pin.

import 'package:test/test.dart';

import '../../example/main.dart';

void registerExampleTests() {
  late Map<String, String> lines;

  setUpAll(() {
    lines = {
      for (final line in runShowcase())
        line.substring(0, line.indexOf(': ')): line.substring(
          line.indexOf(': ') + 2,
        ),
    };
  });

  test('showcase covers every section with unique labels', () {
    expect(
      lines.keys,
      hasLength(runShowcase().length),
      reason: 'duplicate showcase labels would hide a pinned line',
    );
  });

  test('numbers — grouping per locale, percent ×100, compact, scientific', () {
    expect(lines['number.en'], '1,234,567.89');
    expect(lines['number.de'], '1.234.567,89');
    expect(lines['number.hi'], '12,34,567.89');
    expect(lines['number.percent'], '42%');
    expect(lines['number.compact'], '1.2M');
    expect(lines['number.scientific'], '1E5');
  });

  test('currency — symbols, JPY zero minor units, spelled-out names', () {
    expect(lines['currency.usd'], r'$1,234.50');
    expect(lines['currency.jpy'], '¥1,235');
    expect(lines['currency.name'], '2.00 Euro');
  });

  test('dates — styles, field bags, forced 24-hour clock', () {
    // CLDR separates the time from the dayPeriod with U+202F (narrow
    // no-break space), not ASCII space.
    expect(lines['datetime.styled.en'], 'Thursday, January 15, 2026 2:05 PM');
    expect(lines['datetime.fields.de'], '15. Januar 2026');
    expect(lines['datetime.h23.de'], '14:05');
  });

  test('plurals — CLDR cardinals and ordinals', () {
    expect(lines['plural.cardinal'], '1 item / 2 items');
    expect(lines['plural.ordinal'], '1st, 2nd, 3rd, 4th');
  });

  test('degrade contract — nearest rendering plus a recorded error', () {
    expect(lines['degrade.output'], '2.9');
    expect(lines['degrade.errors'], '1');
    expect(lines['degrade.kind'], 'FluentTypeError');
  });
}
