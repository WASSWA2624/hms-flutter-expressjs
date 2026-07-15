import 'dart:collection';

import 'package:dio/dio.dart';

const String _cacheBypassExtraKey = 'cache_bypass';
const String _cacheFromCacheExtraKey = 'cache_from_cache';

/// In-memory LRU cache for GET responses that avoids redundant network
/// round-trips when the same resource is requested within a short window.
///
/// Cached entries are stored in a bounded map and evicted either when they
/// expire ([maxAge]) or when the cache exceeds [maxEntries].
/// Only successful GET requests (2xx) are cached.
final class HttpResponseCacheInterceptor extends Interceptor {
  HttpResponseCacheInterceptor({
    this.maxEntries = 64,
    this.maxAge = const Duration(seconds: 30),
  });

  final int maxEntries;
  final Duration maxAge;

  final LinkedHashMap<String, _CacheEntry> _cache =
      LinkedHashMap<String, _CacheEntry>();

  int get cacheSize => _cache.length;

  void clearCache() => _cache.clear();

  void evict(String cacheKey) => _cache.remove(cacheKey);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!_isCacheable(options)) {
      handler.next(options);
      return;
    }

    final String key = _cacheKey(options);
    final _CacheEntry? entry = _cache[key];

    if (entry != null && !entry.isExpired(maxAge)) {
      // Promote to most-recently-used.
      _cache.remove(key);
      _cache[key] = entry;

      final Response<dynamic> cachedResponse = Response<dynamic>(
        requestOptions: options,
        data: entry.data,
        statusCode: entry.statusCode,
        headers: entry.headers,
      );
      cachedResponse.extra[_cacheFromCacheExtraKey] = true;
      handler.resolve(cachedResponse, true);
      return;
    }

    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final RequestOptions options = response.requestOptions;
    if (_isCacheable(options) && _isSuccessStatus(response.statusCode)) {
      final String key = _cacheKey(options);
      _cache[key] = _CacheEntry(
        data: response.data,
        statusCode: response.statusCode,
        headers: response.headers,
        createdAt: DateTime.now(),
      );
      _evictOverflow();
    }

    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final RequestOptions options = err.requestOptions;
    if (_isCacheable(options)) {
      _cache.remove(_cacheKey(options));
    }
    handler.next(err);
  }

  void _evictOverflow() {
    while (_cache.length > maxEntries) {
      _cache.remove(_cache.keys.first);
    }
  }

  static bool _isCacheable(RequestOptions options) {
    if (options.method.toUpperCase() != 'GET') {
      return false;
    }
    if (options.extra[_cacheBypassExtraKey] == true) {
      return false;
    }
    return true;
  }

  static bool _isSuccessStatus(int? statusCode) {
    return statusCode != null && statusCode >= 200 && statusCode < 300;
  }

  static String _cacheKey(RequestOptions options) {
    final StringBuffer buffer = StringBuffer()
      ..write(options.method)
      ..write(' ')
      ..write(options.uri.toString());

    final Map<String, dynamic> queryParams = options.queryParameters;
    if (queryParams.isNotEmpty) {
      final List<String> sortedKeys = queryParams.keys.toList()..sort();
      buffer.write('?');
      for (final String key in sortedKeys) {
        buffer
          ..write(key)
          ..write('=')
          ..write(queryParams[key])
          ..write('&');
      }
    }

    return buffer.toString();
  }
}

final class _CacheEntry {
  const _CacheEntry({
    required this.data,
    required this.statusCode,
    required this.headers,
    required this.createdAt,
  });

  final Object? data;
  final int? statusCode;
  final Headers headers;
  final DateTime createdAt;

  bool isExpired(Duration maxAge) {
    return DateTime.now().difference(createdAt) > maxAge;
  }
}
