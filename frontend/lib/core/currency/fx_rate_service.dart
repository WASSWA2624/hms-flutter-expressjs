import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/currency/fx_currency_utils.dart';

final fxRateServiceProvider = Provider<FxRateService>((Ref ref) {
  final FxRateService service = FxRateService();
  ref.onDispose(service.dispose);
  return service;
});

class FxRateService {
  FxRateService({Dio? client})
    : _client =
          client ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
            ),
          );

  static const String _baseUrl = 'https://api.frankfurter.dev';
  static const Duration _cacheDuration = Duration(hours: 1);

  final Dio _client;

  /// Cache key: `BASE:QUOTE` → rate (1 BASE = rate QUOTE).
  final Map<String, double> _rateCache = <String, double>{};
  final Map<String, DateTime> _cacheLoadedAt = <String, DateTime>{};

  void dispose() {
    _client.close(force: true);
  }

  Future<double?> convertUsdTo(String targetCurrency) {
    return getRate(from: subscriptionPlanBaseCurrencyCode, to: targetCurrency);
  }

  /// Returns how many units of [to] equal 1 unit of [from].
  Future<double?> getRate({required String from, required String to}) async {
    final String base = from.trim().toUpperCase();
    final String quote = to.trim().toUpperCase();
    if (base.isEmpty || quote.isEmpty) {
      return null;
    }
    if (base == quote) {
      return 1;
    }

    final String directKey = '$base:$quote';
    final double? cached = _cachedRate(directKey);
    if (cached != null) {
      return cached;
    }

    final double? direct = await _fetchRate(base: base, quote: quote);
    if (direct != null) {
      _storeRate(directKey, direct);
      if (direct != 0) {
        _storeRate('$quote:$base', 1 / direct);
      }
      return direct;
    }

    // Pivot through USD when a direct pair is unavailable.
    if (base != subscriptionPlanBaseCurrencyCode &&
        quote != subscriptionPlanBaseCurrencyCode) {
      final double? baseToUsd = await getRate(
        from: base,
        to: subscriptionPlanBaseCurrencyCode,
      );
      final double? usdToQuote = await getRate(
        from: subscriptionPlanBaseCurrencyCode,
        to: quote,
      );
      if (baseToUsd != null && usdToQuote != null) {
        final double pivoted = baseToUsd * usdToQuote;
        _storeRate(directKey, pivoted);
        if (pivoted != 0) {
          _storeRate('$quote:$base', 1 / pivoted);
        }
        return pivoted;
      }
    }

    return null;
  }

  Future<double?> convertAmount({
    required double amount,
    required String from,
    required String to,
  }) async {
    final double? rate = await getRate(from: from, to: to);
    if (rate == null) {
      return null;
    }
    return roundConvertedAmount(amount * rate, to);
  }

  double? _cachedRate(String key) {
    final DateTime? loadedAt = _cacheLoadedAt[key];
    final double? rate = _rateCache[key];
    if (loadedAt == null || rate == null) {
      return null;
    }
    if (DateTime.now().difference(loadedAt) >= _cacheDuration) {
      return null;
    }
    return rate;
  }

  void _storeRate(String key, double rate) {
    _rateCache[key] = rate;
    _cacheLoadedAt[key] = DateTime.now();
  }

  Future<double?> _fetchRate({
    required String base,
    required String quote,
  }) async {
    final double? v1Rate = await _fetchV1Rate(base: base, quote: quote);
    if (v1Rate != null) {
      return v1Rate;
    }
    return _fetchV2Rate(base: base, quote: quote);
  }

  Future<double?> _fetchV1Rate({
    required String base,
    required String quote,
  }) async {
    try {
      final Response<dynamic> response = await _client.get<dynamic>(
        '$_baseUrl/v1/latest',
        queryParameters: <String, String>{'base': base, 'symbols': quote},
      );
      final Object? ratesRaw = (response.data as Map?)?['rates'];
      if (ratesRaw is! Map) {
        return null;
      }
      final Object? rateRaw = ratesRaw[quote];
      if (rateRaw is num) {
        return rateRaw.toDouble();
      }
      return double.tryParse('$rateRaw');
    } on DioException {
      return null;
    }
  }

  Future<double?> _fetchV2Rate({
    required String base,
    required String quote,
  }) async {
    try {
      final Response<dynamic> response = await _client.get<dynamic>(
        '$_baseUrl/v2/rate/$base/$quote',
      );
      final Object? data = response.data;
      if (data is Map) {
        final Object? rateRaw = data['rate'];
        if (rateRaw is num) {
          return rateRaw.toDouble();
        }
        return double.tryParse('$rateRaw');
      }
      if (data is List && data.isNotEmpty) {
        final Object? first = data.first;
        if (first is Map) {
          final Object? rateRaw = first['rate'];
          if (rateRaw is num) {
            return rateRaw.toDouble();
          }
          return double.tryParse('$rateRaw');
        }
      }
      return null;
    } on DioException {
      return null;
    }
  }
}
