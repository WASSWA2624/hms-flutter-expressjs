import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/network/api_client.dart';
import 'package:hosspi_hms/core/network/api_endpoints.dart';

void main() {
  group('ApiClient', () {
    test('keeps endpoint path segments URL encoded', () {
      expect(
        ApiEndpoints.byId(HmsApiResource.patients, 'patient 1').toString(),
        '/api/v1/patients/patient%201',
      );
    });

    test('centralizes root and module API endpoints', () {
      expect(ApiEndpoints.health.toString(), '/health');
      expect(ApiEndpoints.readiness.toString(), '/ready');
      expect(ApiEndpoints.liveness.toString(), '/live');
      expect(
        ApiEndpoints.auth(AuthEndpoint.login).toString(),
        '/api/v1/auth/login',
      );
      expect(
        ApiEndpoints.collection(
          HmsApiResource.appointments,
          queryParameters: <String, String>{'status': 'booked'},
        ).toString(),
        '/api/v1/appointments?status=booked',
      );
      expect(
        HmsApiResource.pharmacy.group,
        HmsApiEndpointGroup.diagnosticsPharmacyBilling,
      );
    });

    test(
      'decodes successful responses through the configured Dio client',
      () async {
        final adapter = _StaticHttpClientAdapter(
          (_) => ResponseBody.fromString(
            '{"ready":true}',
            200,
            headers: <String, List<String>>{
              Headers.contentTypeHeader: <String>[Headers.jsonContentType],
            },
          ),
        );
        final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
          ..httpClientAdapter = adapter;
        final client = ApiClient(dio: dio);

        final result = await client.get<Map<String, Object?>>(
          Uri(
            path: '/readiness',
            queryParameters: <String, String>{'page': '1'},
          ),
          queryParameters: <String, Object?>{'filter': 'active'},
          decoder: (data) {
            if (data is! Map<String, Object?>) {
              throw const FormatException('Invalid response.');
            }

            return data;
          },
        );

        result.when(
          success: (data) => expect(data['ready'], isTrue),
          failure: (_) => fail('Expected a successful API result.'),
        );
        expect(adapter.lastOptions?.path, '/readiness');
        expect(adapter.lastOptions?.queryParameters, containsPair('page', '1'));
        expect(
          adapter.lastOptions?.queryParameters,
          containsPair('filter', 'active'),
        );
      },
    );

    test('maps decoder exceptions into typed failures', () async {
      final adapter = _StaticHttpClientAdapter(
        (_) => ResponseBody.fromString(
          '[]',
          200,
          headers: <String, List<String>>{
            Headers.contentTypeHeader: <String>[Headers.jsonContentType],
          },
        ),
      );
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.test'))
        ..httpClientAdapter = adapter;
      final client = ApiClient(dio: dio);

      final result = await client.get<Map<String, Object?>>(
        Uri(path: '/readiness'),
        decoder: (_) => throw const FormatException('Invalid response.'),
      );

      result.when(
        success: (_) => fail('Expected a failed API result.'),
        failure: (failure) =>
            expect(failure.category, AppFailureCategory.unexpectedResponse),
      );
    });
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
