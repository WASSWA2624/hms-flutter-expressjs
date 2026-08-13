import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/network/connection_retry_interceptor.dart';

void main() {
  test('does not retry long-running AI tasks on connection timeout', () async {
    final _CountingAdapter adapter = _CountingAdapter(
      errorType: DioExceptionType.connectionTimeout,
    );
    final Dio dio = Dio()
      ..httpClientAdapter = adapter
      ..interceptors.add(ConnectionRetryInterceptor(retryClient: Dio()..httpClientAdapter = adapter));

    await expectLater(
      dio.post<dynamic>(
        '/api/v1/ai/tasks/clinical_note_format',
        options: Options(
          extra: const <String, Object?>{'ai_long_running': true},
        ),
      ),
      throwsA(isA<DioException>()),
    );
    expect(adapter.fetchCount, 1);
  });
}

final class _CountingAdapter implements HttpClientAdapter {
  _CountingAdapter({required this.errorType});

  final DioExceptionType errorType;
  int fetchCount = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    fetchCount += 1;
    throw DioException(requestOptions: options, type: errorType);
  }
}
