import 'package:fluent_bundle/fluent_bundle.dart';
import 'package:fluent_intl/src/datetime/datetime_map.dart';
import 'package:fluent_intl/src/number/number_map.dart';
import 'package:fluent_intl/src/plural/plural_map.dart';

/// A [FluentBackend] backed by `package:intl` (+ `l10n_currencies` for
/// currency names): CLDR plural rules for every locale (ordinals for the
/// major ones), locale-aware decimal / percent / currency formatting, and
/// skeleton-composed date/time formatting.
///
/// Wire it into a bundle:
///
/// ```dart
/// final bundle = FluentBundle('en', backend: IntlBackend());
/// ```
class IntlBackend extends FluentBackend {
  /// Creates an intl-backed backend. Each instance owns formatter caches,
  /// so construct one per bundle and reuse it.
  IntlBackend()
    : _formatNumber = createIntlNumberFormatter(),
      _formatDateTime = createIntlDateTimeFormatter();

  final String Function(FluentNumber, String, List<FluentError>) _formatNumber;
  final String Function(FluentDateTime, String, List<FluentError>)
  _formatDateTime;

  @override
  PluralCategory pluralCategory(
    FluentNumber value,
    PluralRuleType type,
    FluentFormatContext context,
  ) => intlPluralRules(value, type, context.locale);

  @override
  String formatNumber(FluentNumber value, FluentFormatContext context) =>
      _formatNumber(value, context.locale, context.errors);

  @override
  String formatDateTime(FluentDateTime value, FluentFormatContext context) =>
      _formatDateTime(value, context.locale, context.errors);
}
