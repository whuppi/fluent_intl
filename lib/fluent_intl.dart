/// `package:intl` backend for Project Fluent — real CLDR plurals and
/// locale-aware formatting for `fluent_bundle`.
///
/// This barrel re-exports the entire `fluent_bundle` runtime, so a single
/// import gives you `FluentBundle` plus `IntlBackend`:
///
/// ```dart
/// import 'package:fluent_intl/fluent_intl.dart';
///
/// final bundle = FluentBundle('en', backend: IntlBackend());
/// ```
///
/// `IntlBackend` covers cardinal plurals for every CLDR locale, ordinals
/// for the major ones, and decimal / percent / currency / date-time
/// formatting. For full ECMA-402 (units, all-locale ordinals, calendars,
/// numbering systems, time zones) use `package:fluent_icu`.
library;

export 'package:fluent_bundle/fluent_bundle.dart';

export 'src/backend.dart' show IntlBackend;
