import 'dart:async';

import 'package:fluent_bundle/fluent_bundle.dart';
import 'package:fluent_intl/src/common/cache.dart';
import 'package:intl/date_symbol_data_local.dart' as intl_data;
import 'package:intl/intl.dart' as intl;

bool _dateFormattingInitialized = false;

void _ensureDateFormattingInitialized() {
  if (_dateFormattingInitialized) return;
  // package:intl ships the full CLDR symbol+pattern tables with the
  // library; this call is synchronous (returns Future.value() immediately
  // after registering the maps). Calling it once removes the
  // "LocaleDataException: Locale data has not been initialized" failure
  // mode that bites every Flutter app on first non-default-locale use.
  unawaited(intl_data.initializeDateFormatting());
  _dateFormattingInitialized = true;
}

/// Build a date-time formatter backed by `package:intl`.
///
/// Coverage: `dateStyle`, `timeStyle`, plus the field-level overrides
/// (`year`, `month`, `day`, `hour`, `minute`, `second`, `weekday`, `era`,
/// `dayPeriod`, `fractionalSecondDigits`, `timeZoneName`, `hour12`,
/// `hourCycle` via the j/H family). `timeZone`, `calendar`, and
/// `numberingSystem` aren't supported by `package:intl`'s `DateFormat`
/// and degrade with a recorded error, as do the value forms intl can't
/// express (offset/generic zone names, narrow weekday, h11/h24).
String Function(FluentDateTime, String, List<FluentError>)
createIntlDateTimeFormatter({IntlMemoizer? memoizer}) {
  _ensureDateFormattingInitialized();
  final cache = memoizer ?? IntlMemoizer();
  return (FluentDateTime value, String locale, List<FluentError> errors) {
    final opts = value.options;

    // Degrades record HERE, per call — never inside the cached builder,
    // where a cache hit would silence the error on every call but the
    // first. Nearest-supported rendering + recorded error, matching the
    // NUMBER path's contract.
    void unsupported(String what, String effect) {
      errors.add(
        FluentTypeError.unsupportedOption(
          builtin: 'DATETIME',
          option: what,
          backend: 'package:intl',
          effect: effect,
          hint:
              'Use IcuBackend from package:fluent_icu for full '
              'ECMA-402 support.',
        ),
      );
    }

    if (opts.timeZone != null) {
      unsupported('timeZone', "the value formats in the host's local zone");
    }
    if (opts.calendar != null) {
      unsupported('calendar', 'the gregorian calendar is used');
    }
    if (opts.numberingSystem != null) {
      unsupported('numberingSystem', "the locale's default digits are used");
    }
    if (const {
      'shortOffset',
      'longOffset',
      'shortGeneric',
      'longGeneric',
    }.contains(opts.timeZoneName)) {
      unsupported(
        'timeZoneName "${opts.timeZoneName}"',
        'the localized zone name is used',
      );
    }
    if (opts.weekday == 'narrow') {
      unsupported('weekday "narrow"', 'the short weekday form is used');
    }
    if (opts.hourCycle == 'h11' || opts.hourCycle == 'h24') {
      unsupported(
        'hourCycle "${opts.hourCycle}"',
        'the nearest cycle in the same 12/24 family is used',
      );
    }

    final cacheKey = _optionsCacheKey(opts);
    final formatter = cache.dateFormat(
      locale,
      cacheKey,
      () => _buildFormatter(opts, locale),
    );
    return formatter.format(value.value);
  };
}

/// Build a `DateFormat` instance from [opts] in [locale].
///
/// Strategy:
///   - If `dateStyle` / `timeStyle` are set, compose with the named
///     skeleton factories (`DateFormat.yMMMd()`, `add_jm()`, etc.).
///   - Otherwise, build from per-field overrides via the named-symbol
///     adders (`add_y`, `add_M`, …) when possible, falling back to a
///     hand-rolled pattern only if the field set has no canonical
///     skeleton.
///   - Field-level codes win over style codes when both are set, matching
///     ECMA-402 precedence.
intl.DateFormat _buildFormatter(FluentDateTimeOptions opts, String locale) {
  // hourCycle normalizes onto the hour12 skeleton machinery: h11/h12 pick
  // the 12-hour (j/jm) skeletons, h23/h24 the 24-hour (H/Hm) ones. intl
  // can't distinguish within a family (h11 vs h12); the closure already
  // recorded the degrade for the two forms outside the j/H surface.
  if (opts.hourCycle != null) {
    opts = opts.merge(
      FluentDateTimeOptions(
        hour12: opts.hourCycle == 'h11' || opts.hourCycle == 'h12',
      ),
    );
  }

  final hasFieldOverrides =
      opts.year != null ||
      opts.month != null ||
      opts.day != null ||
      opts.hour != null ||
      opts.minute != null ||
      opts.second != null ||
      opts.weekday != null ||
      opts.era != null ||
      opts.dayPeriod != null ||
      opts.fractionalSecondDigits != null ||
      opts.timeZoneName != null;

  if (!hasFieldOverrides &&
      (opts.dateStyle != null || opts.timeStyle != null)) {
    return _buildStyleFormatter(
      locale: locale,
      dateStyle: opts.dateStyle,
      timeStyle: opts.timeStyle,
      hour12: opts.hour12,
    );
  }

  if (hasFieldOverrides) {
    return _buildFieldFormatter(opts, locale);
  }

  // No options at all → sensible default: short date + short time.
  return intl.DateFormat.yMd(locale).add_jm();
}

/// Compose a [intl.DateFormat] from `dateStyle` and/or `timeStyle`.
///
/// Each style maps to a named skeleton factory; the time skeleton is
/// added with `add_*` so the resulting formatter combines both into one
/// localized pattern (which is NOT what raw skeleton concatenation
/// would produce — `intl.DateFormat('yMd jm')` builds a literal string
/// pattern, not a composed skeleton).
intl.DateFormat _buildStyleFormatter({
  required String locale,
  required String? dateStyle,
  required String? timeStyle,
  required bool? hour12,
}) {
  intl.DateFormat? f = switch (dateStyle) {
    'short' => intl.DateFormat.yMd(locale),
    'medium' => intl.DateFormat.yMMMd(locale),
    'long' => intl.DateFormat.yMMMMd(locale),
    'full' => intl.DateFormat.yMMMMEEEEd(locale),
    _ => null,
  };

  if (timeStyle != null) {
    final timeSkeleton = _timeSkeletonFor(timeStyle, hour12);
    if (f == null) {
      // Time-only request — start from the time skeleton.
      f = intl.DateFormat(timeSkeleton, locale);
    } else {
      _addTimeSkeleton(f, timeStyle, hour12);
    }
  }

  return f ?? intl.DateFormat.yMd(locale);
}

/// Add the requested time skeleton to an existing formatter using the
/// `add_*` family of methods. Each method composes the skeleton with the
/// existing date pattern in a locale-correct way.
void _addTimeSkeleton(intl.DateFormat f, String timeStyle, bool? hour12) {
  switch (timeStyle) {
    case 'short':
      hour12 == false ? f.add_Hm() : f.add_jm();
    case 'medium':
    case 'long':
    case 'full':
      hour12 == false ? f.add_Hms() : f.add_jms();
  }
}

/// The bare skeleton string for a time-only formatter (no date part).
String _timeSkeletonFor(String timeStyle, bool? hour12) {
  return switch (timeStyle) {
    'short' => hour12 == false ? 'Hm' : 'jm',
    'medium' || 'long' || 'full' => hour12 == false ? 'Hms' : 'jms',
    _ => 'jm',
  };
}

/// Compose a formatter from per-field overrides (`year`, `month`, …).
///
/// Each set of fields maps to a named-skeleton factory + `add_*` calls
/// where possible. Unmapped combinations fall back to a hand-built
/// pattern string.
intl.DateFormat _buildFieldFormatter(
  FluentDateTimeOptions opts,
  String locale,
) {
  // Try to match the most common field combinations to canonical
  // skeleton factories. ECMA-402 doesn't enumerate every combination,
  // so we cover the practical ones and fall back to a custom pattern
  // for the rest.
  final hasYear = opts.year != null;
  final hasMonth = opts.month != null;
  final hasDay = opts.day != null;
  final hasWeekday = opts.weekday != null;
  final hasHour = opts.hour != null;
  final hasMinute = opts.minute != null;
  final hasSecond = opts.second != null;
  final hasFractional = opts.fractionalSecondDigits != null;
  final hasEra = opts.era != null;
  final hasDayPeriod = opts.dayPeriod != null;
  final hasTimeZoneName = opts.timeZoneName != null;

  // Canonical-factory path: pick the longest match for the date side.
  // When weekday + year + month + day are ALL set, use the canonical
  // weekday-first factories — they place the weekday in the locale's
  // natural position (`Monday, April 27, 2026` in en, `2026年4月27日月曜日`
  // in ja). For partial combinations, compose with add_E* below.
  intl.DateFormat? f;
  bool weekdayHandledByFactory = false;
  if (hasYear && hasMonth && hasDay && hasWeekday) {
    f = switch ((opts.month, opts.weekday)) {
      ('long', _) when opts.weekday == 'long' => intl.DateFormat.yMMMMEEEEd(
        locale,
      ),
      ('short', _) || (_, 'long') => intl.DateFormat.yMMMEd(locale),
      _ => intl.DateFormat.yMEd(locale),
    };
    weekdayHandledByFactory = true;
  } else if (hasYear && hasMonth && hasDay) {
    f = switch (opts.month) {
      'long' => intl.DateFormat.yMMMMd(locale),
      'short' => intl.DateFormat.yMMMd(locale),
      _ => intl.DateFormat.yMd(locale),
    };
  } else if (hasYear && hasMonth) {
    f = switch (opts.month) {
      'long' => intl.DateFormat.yMMMM(locale),
      'short' => intl.DateFormat.yMMM(locale),
      _ => intl.DateFormat.yM(locale),
    };
  } else if (hasMonth && hasDay) {
    f = switch (opts.month) {
      'long' => intl.DateFormat.MMMMd(locale),
      'short' => intl.DateFormat.MMMd(locale),
      _ => intl.DateFormat.Md(locale),
    };
  } else if (hasYear) {
    f = intl.DateFormat.y(locale);
  } else if (hasMonth) {
    f = switch (opts.month) {
      'long' => intl.DateFormat.MMMM(locale),
      'short' => intl.DateFormat.MMM(locale),
      _ => intl.DateFormat.M(locale),
    };
  } else if (hasDay) {
    f = intl.DateFormat.d(locale);
  }

  // Weekday: compose onto whatever date skeleton we picked. The
  // year+month+day+weekday case is already covered by the canonical
  // factory above (weekday-first, locale-natural ordering); only fall
  // through to compose when we have a partial date.
  if (hasWeekday && !weekdayHandledByFactory) {
    if (f == null) {
      f = switch (opts.weekday) {
        'narrow' => intl.DateFormat.E(locale),
        'short' => intl.DateFormat.E(locale),
        _ => intl.DateFormat.EEEE(locale),
      };
    } else {
      // add_E adds the abbreviated weekday; for 'long' we want the
      // full name. intl.DateFormat exposes add_E (short) and add_EEEE
      // (long); narrow falls back to short since CLDR's narrow form
      // isn't reachable through the named adders.
      switch (opts.weekday) {
        case 'long':
          f.add_EEEE();
        case 'narrow':
        case 'short':
        default:
          f.add_E();
      }
    }
  }

  // Layer the time side on with add_* if we have any time fields. Same
  // rule as the style path: only an explicit hour12=false forces the
  // H-family; null uses the j-family so the locale keeps its preferred
  // cycle (a bare `hour: "numeric"` must not silently force 24h).
  if (hasHour || hasMinute || hasSecond) {
    final force24 = opts.hour12 == false;
    f ??= intl.DateFormat('', locale);
    if (hasHour && hasMinute && hasSecond) {
      force24 ? f.add_Hms() : f.add_jms();
    } else if (hasHour && hasMinute) {
      force24 ? f.add_Hm() : f.add_jm();
    } else if (hasHour) {
      force24 ? f.add_H() : f.add_j();
    } else if (hasMinute) {
      f.add_m();
    } else if (hasSecond) {
      f.add_s();
    }
  }

  // Fields without a canonical factory match get appended via a custom
  // pattern. fractionalSecondDigits, era, dayPeriod, timeZoneName don't
  // have add_* methods on intl.DateFormat — build a supplemental pattern
  // alongside the canonical formatter when present.
  if (hasFractional || hasEra || hasDayPeriod || hasTimeZoneName) {
    final extras = StringBuffer();
    if (hasEra) extras.write(_eraCode(opts.era!));
    if (hasDayPeriod) extras.write('a');
    if (hasFractional) {
      extras.write('S' * opts.fractionalSecondDigits!.clamp(1, 3));
    }
    if (hasTimeZoneName) {
      extras.write(opts.timeZoneName == 'long' ? 'zzzz' : 'z');
    }
    if (f == null) {
      f = intl.DateFormat(extras.toString(), locale);
    } else {
      f.addPattern(extras.toString());
    }
  }

  return f ?? intl.DateFormat.yMd(locale);
}

String _eraCode(String era) {
  switch (era) {
    case 'narrow':
      return 'GGGGG';
    case 'long':
      return 'GGGG';
    case 'short':
    default:
      return 'G';
  }
}

/// Stable, canonical key for [FluentDateTimeOptions], used to memoize
/// `package:intl` formatter instances per `(locale, opts)` pair.
///
/// EVERY option field belongs in the key, whether or not today's builder
/// reads it at construction time — a field left out is a cache-collision
/// bug the moment the builder starts consuming it (hourCycle was exactly
/// that: h23 formatters served h12 calls until it joined the key).
String _optionsCacheKey(FluentDateTimeOptions o) {
  String s(String? v) => v ?? '-';
  String i(int? v) => v == null ? '-' : v.toString();
  String b(bool? v) => v == null ? '-' : (v ? 't' : 'f');
  return [
    s(o.dateStyle),
    s(o.timeStyle),
    s(o.weekday),
    s(o.era),
    s(o.dayPeriod),
    s(o.timeZoneName),
    s(o.year),
    s(o.month),
    s(o.day),
    s(o.hour),
    s(o.minute),
    s(o.second),
    i(o.fractionalSecondDigits),
    b(o.hour12),
    s(o.hourCycle),
    s(o.timeZone),
    s(o.calendar),
    s(o.numberingSystem),
  ].join('|');
}
