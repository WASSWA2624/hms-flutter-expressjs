import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/currency/fx_rate_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockDio extends Mock implements Dio {}

class _MockResponse extends Mock implements Response<dynamic> {}

void main() {
  late _MockDio dio;
  late FxRateService service;

  setUp(() {
    dio = _MockDio();
    service = FxRateService(client: dio);
    when(() => dio.close(force: any(named: 'force'))).thenReturn(null);
  });

  tearDown(() {
    service.dispose();
  });

  test('returns 1 for USD conversion', () async {
    expect(await service.convertUsdTo('USD'), 1);
    verifyNever(
      () => dio.get<dynamic>(
        any(),
        queryParameters: any(named: 'queryParameters'),
      ),
    );
  });

  test('fetches Frankfurter v1 rate', () async {
    final _MockResponse response = _MockResponse();
    when(() => response.data).thenReturn(<String, Object?>{
      'rates': <String, double>{'UGX': 3700},
    });
    when(
      () => dio.get<dynamic>(
        'https://api.frankfurter.dev/v1/latest',
        queryParameters: <String, String>{'base': 'USD', 'symbols': 'UGX'},
      ),
    ).thenAnswer((_) async => response);

    expect(await service.convertUsdTo('UGX'), 3700);
  });
}
