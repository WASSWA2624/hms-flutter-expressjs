import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_template/core/network/api_interceptors.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthInterceptor', () {
    test('attaches bearer tokens from the session boundary', () async {
      final adapter = _StaticHttpClientAdapter(
        (_) => ResponseBody.fromString('{}', 200),
      );
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
        ..httpClientAdapter = adapter
        ..interceptors.add(
          AuthInterceptor(readAccessToken: () async => ' access-token '),
        );

      await dio.get<Object?>('/private');

      expect(
        adapter.lastOptions?.headers[authorizationHeaderName],
        'Bearer access-token',
      );
    });

    test('runs the unauthorized handler for 401 responses', () async {
      var unauthorizedCallCount = 0;
      final adapter = _StaticHttpClientAdapter(
        (_) => ResponseBody.fromString('{}', 401),
      );
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
        ..httpClientAdapter = adapter
        ..interceptors.add(
          AuthInterceptor(
            readAccessToken: () async => null,
            onUnauthorizedResponse: () async {
              unauthorizedCallCount += 1;
            },
          ),
        );

      await expectLater(
        dio.get<Object?>('/private'),
        throwsA(isA<DioException>()),
      );

      expect(unauthorizedCallCount, 1);
    });
  });

  group('SafeDiagnosticsInterceptor', () {
    test(
      'logs safe request metadata without query, header, or body values',
      () async {
        final messages = <String>[];
        final adapter = _StaticHttpClientAdapter(
          (_) => ResponseBody.fromString('{}', 500),
        );
        final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
          ..httpClientAdapter = adapter
          ..interceptors.add(
            SafeDiagnosticsInterceptor(
              enabled: true,
              debugLog: messages.add,
              warningLog: messages.add,
            ),
          );

        await expectLater(
          dio.post<Object?>(
            '/users',
            data: <String, Object?>{'password': 'secret-password'},
            queryParameters: <String, Object?>{'token': 'secret-token'},
            options: Options(
              headers: <String, Object?>{
                authorizationHeaderName: 'Bearer secret-token',
              },
            ),
          ),
          throwsA(isA<DioException>()),
        );

        final logOutput = messages.join('\n');

        expect(logOutput, contains('/users'));
        expect(logOutput, isNot(contains('secret-token')));
        expect(logOutput, isNot(contains('secret-password')));
        expect(logOutput, isNot(contains('Authorization')));
        expect(logOutput, isNot(contains('token')));
      },
    );
  });
}

final class _StaticHttpClientAdapter implements HttpClientAdapter {
  _StaticHttpClientAdapter(this.responseFactory);

  final ResponseBody Function(RequestOptions options) responseFactory;
  RequestOptions? lastOptions;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastOptions = options;
    return responseFactory(options);
  }

  @override
  void close({bool force = false}) {}
}
