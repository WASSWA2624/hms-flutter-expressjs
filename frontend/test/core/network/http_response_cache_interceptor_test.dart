import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/network/http_response_cache_interceptor.dart';

void main() {
  test('successful mutations clear cached GET responses', () async {
    final HttpResponseCacheInterceptor interceptor =
        HttpResponseCacheInterceptor();
    final _FakeAdapter adapter = _FakeAdapter();
    final Dio dio = Dio()
      ..interceptors.add(interceptor)
      ..httpClientAdapter = adapter;

    await dio.get<dynamic>('/role-permissions');
    expect(interceptor.cacheSize, 1);
    expect(adapter.getCount, 1);

    await dio.put<dynamic>(
      '/roles/1',
      data: <String, Object?>{'permission_ids': <String>[]},
    );
    expect(interceptor.cacheSize, 0);

    await dio.get<dynamic>('/role-permissions');
    expect(adapter.getCount, 2);
    expect(interceptor.cacheSize, 1);
  });
}

final class _FakeAdapter implements HttpClientAdapter {
  int getCount = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method.toUpperCase() == 'GET') {
      getCount += 1;
      return ResponseBody.fromString(
        '{"data":[{"id":"$getCount"}]}',
        200,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>['application/json'],
        },
      );
    }
    return ResponseBody.fromString(
      '{}',
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json'],
      },
    );
  }
}
