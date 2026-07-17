import 'package:intl/intl.dart' as intl;

/// Cache of `package:intl` formatter instances, keyed by
/// `(constructor-tag, locale, opts-canonical-string)`.
///
/// Constructing a [intl.NumberFormat] or [intl.DateFormat] is non-trivial:
/// it parses the locale's CLDR pattern data on every call. The same
/// `(locale, opts)` pair recurs across every format call for the same
/// rendered phrase, so a per-bundle cache keeps the cost flat.
class IntlMemoizer {
  final Map<String, Object> _cache = {};

  /// Get-or-create a [intl.NumberFormat] for [locale] keyed by [optsKey].
  /// The factory is invoked lazily on cache miss.
  intl.NumberFormat numberFormat(
    String locale,
    String optsKey,
    intl.NumberFormat Function() create,
  ) {
    final key = 'NF|$locale|$optsKey';
    final cached = _cache[key];
    if (cached is intl.NumberFormat) return cached;
    final created = create();
    _cache[key] = created;
    return created;
  }

  /// Get-or-create a [intl.DateFormat] for [locale] keyed by [optsKey].
  intl.DateFormat dateFormat(
    String locale,
    String optsKey,
    intl.DateFormat Function() create,
  ) {
    final key = 'DF|$locale|$optsKey';
    final cached = _cache[key];
    if (cached is intl.DateFormat) return cached;
    final created = create();
    _cache[key] = created;
    return created;
  }
}
