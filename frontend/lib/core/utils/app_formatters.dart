import 'dart:ui';

import 'package:intl/intl.dart';

abstract final class AppFormatters {
  static String shortDate(DateTime value, Locale locale) {
    return DateFormat.yMd(_localeName(locale)).format(value);
  }

  static String mediumDate(DateTime value, Locale locale) {
    return DateFormat.yMMMd(_localeName(locale)).format(value);
  }

  static String time(DateTime value, Locale locale) {
    return DateFormat.jm(_localeName(locale)).format(value);
  }

  static String dateTime(DateTime value, Locale locale) {
    return DateFormat.yMMMd(_localeName(locale)).add_jm().format(value);
  }

  static String decimal(num value, Locale locale) {
    return NumberFormat.decimalPattern(_localeName(locale)).format(value);
  }

  static String compactNumber(num value, Locale locale) {
    return NumberFormat.compact(locale: _localeName(locale)).format(value);
  }

  static String currency(
    num value,
    Locale locale, {
    String? currencyCode,
    int? decimalDigits,
  }) {
    final String formatted = NumberFormat.simpleCurrency(
      locale: _localeName(locale),
      name: currencyCode,
      decimalDigits: decimalDigits,
    ).format(value);
    return _normalizeCurrencySpacing(formatted, currencyCode);
  }

  static String _normalizeCurrencySpacing(
    String formatted,
    String? currencyCode,
  ) {
    final String normalized = formatted
        .replaceAll('\u00a0', ' ')
        .replaceAll('\u202f', ' ');
    final String? code = currencyCode?.trim();
    if (code == null || code.length != 3) {
      return normalized;
    }
    return normalized.replaceFirst(RegExp('^$code(?=\\d)'), '$code ');
  }

  static String percent(num value, Locale locale) {
    return NumberFormat.percentPattern(_localeName(locale)).format(value);
  }

  static String _localeName(Locale locale) {
    return locale.toLanguageTag();
  }
}
