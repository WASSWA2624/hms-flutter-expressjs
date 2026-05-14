import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/network/api_interceptors.dart';

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

  group('CsrfInterceptor', () {
    test('adds CSRF tokens to state-changing requests', () async {
      final tokenAdapter = _StaticHttpClientAdapter(
        (_) => ResponseBody.fromString(
          '{"data":{"token":"csrf-token"}}',
          200,
          headers: <String, List<String>>{
            Headers.contentTypeHeader: <String>[Headers.jsonContentType],
          },
        ),
      );
      final requestAdapter = _StaticHttpClientAdapter(
        (_) => ResponseBody.fromString('{}', 200),
      );
      final tokenDio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
        ..httpClientAdapter = tokenAdapter;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
        ..httpClientAdapter = requestAdapter
        ..interceptors.add(CsrfInterceptor(tokenDio: tokenDio));

      await dio.post<Object?>('/api/v1/branches');

      expect(requestAdapter.lastOptions?.headers[csrfHeaderName], 'csrf-token');
      expect(tokenAdapter.lastOptions?.path, '/api/v1/auth/csrf-token');
    });

    test('does not add CSRF tokens to exempt auth requests', () async {
      final tokenAdapter = _StaticHttpClientAdapter(
        (_) => ResponseBody.fromString('{"data":{"token":"csrf-token"}}', 200),
      );
      final requestAdapter = _StaticHttpClientAdapter(
        (_) => ResponseBody.fromString('{}', 200),
      );
      final tokenDio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
        ..httpClientAdapter = tokenAdapter;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
        ..httpClientAdapter = requestAdapter
        ..interceptors.add(CsrfInterceptor(tokenDio: tokenDio));

      await dio.post<Object?>('/api/v1/auth/login');

      expect(requestAdapter.lastOptions?.headers[csrfHeaderName], isNull);
      expect(tokenAdapter.lastOptions, isNull);
    });

    test('refreshes token after CSRF failure responses', () async {
      var tokenRequestCount = 0;
      final tokenAdapter = _StaticHttpClientAdapter((_) {
        tokenRequestCount += 1;
        return ResponseBody.fromString(
          '{"data":{"token":"csrf-token-$tokenRequestCount"}}',
          200,
          headers: <String, List<String>>{
            Headers.contentTypeHeader: <String>[Headers.jsonContentType],
          },
        );
      });
      var requestCount = 0;
      final sentTokens = <Object?>[];
      final requestAdapter = _StaticHttpClientAdapter((options) {
        requestCount += 1;
        sentTokens.add(options.headers[csrfHeaderName]);
        if (requestCount == 1) {
          return ResponseBody.fromString(
            '{"code":"INVALID"}',
            403,
            headers: <String, List<String>>{
              Headers.contentTypeHeader: <String>[Headers.jsonContentType],
            },
          );
        }

        return ResponseBody.fromString('{}', 200);
      });
      final tokenDio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
        ..httpClientAdapter = tokenAdapter;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
        ..httpClientAdapter = requestAdapter
        ..interceptors.add(CsrfInterceptor(tokenDio: tokenDio));

      await expectLater(
        dio.post<Object?>('/api/v1/branches'),
        throwsA(isA<DioException>()),
      );
      await dio.post<Object?>('/api/v1/branches');

      expect(sentTokens, <Object?>['csrf-token-1', 'csrf-token-2']);
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
