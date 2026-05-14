import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/network/api_response.dart';

void main() {
  group('ApiResponseEnvelope', () {
    test('decodes successful backend response envelopes', () {
      final value = ApiResponseEnvelope.decodeData<String>(
        <String, Object?>{
          'success': true,
          'data': <String, Object?>{'name': 'DemoCare'},
          'meta': <String, Object?>{'page': 1},
        },
        decoder: (data) {
          if (data case <String, Object?>{'name': final String name}) {
            return name;
          }

          throw const FormatException('Invalid data.');
        },
      );

      expect(value, 'DemoCare');
    });

    test('decodes status-based backend response envelopes', () {
      final value = ApiResponseEnvelope.decodeData<String>(
        <String, Object?>{
          'status': 200,
          'message': 'Login successful',
          'data': <String, Object?>{'name': 'DemoCare'},
          'meta': <String, Object?>{'locale': 'en'},
        },
        decoder: (data) {
          if (data case <String, Object?>{'name': final String name}) {
            return name;
          }

          throw const FormatException('Invalid data.');
        },
      );

      expect(value, 'DemoCare');
    });

    test(
      'rejects invalid response envelopes before mapping to domain data',
      () {
        expect(
          () => ApiResponseEnvelope.decodeData<Object?>(<String, Object?>{
            'success': false,
            'data': null,
          }, decoder: (data) => data),
          throwsFormatException,
        );
        expect(
          () => ApiResponseEnvelope.decodeData<Object?>(<String, Object?>{
            'data': null,
          }, decoder: (data) => data),
          throwsFormatException,
        );
      },
    );
  });
}
