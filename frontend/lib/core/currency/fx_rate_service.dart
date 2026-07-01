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
  final Map<String, double> _rateCache = <String, double>{};
  DateTime? _cacheLoadedAt;

  void dispose() {
    _client.close(force: true);
  }

  Future<double?> convertUsdTo(String targetCurrency) async {
    final String quote = targetCurrency.trim().toUpperCase();
    if (quote.isEmpty) {
      return null;
    }
    if (quote == subscriptionPlanBaseCurrencyCode) {
      return 1;
    }

    await _ensureRatesLoaded(quote);
    return _rateCache[quote];
  }

  Future<void> _ensureRatesLoaded(String quote) async {
    final DateTime now = DateTime.now();
    if (_cacheLoadedAt != null &&
        now.difference(_cacheLoadedAt!) < _cacheDuration &&
        _rateCache.containsKey(quote)) {
      return;
    }

    final double? v1Rate = await _fetchV1Rate(quote);
    if (v1Rate != null) {
      _rateCache[quote] = v1Rate;
      _cacheLoadedAt = now;
      return;
    }

    final double? v2Rate = await _fetchV2Rate(quote);
    if (v2Rate != null) {
      _rateCache[quote] = v2Rate;
      _cacheLoadedAt = now;
    }
  }

  Future<double?> _fetchV1Rate(String quote) async {
    try {
      final Response<dynamic> response = await _client.get<dynamic>(
        '$_baseUrl/v1/latest',
        queryParameters: <String, String>{
          'base': subscriptionPlanBaseCurrencyCode,
          'symbols': quote,
        },
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

  Future<double?> _fetchV2Rate(String quote) async {
    try {
      final Response<dynamic> response = await _client.get<dynamic>(
        '$_baseUrl/v2/rate/$subscriptionPlanBaseCurrencyCode/$quote',
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
