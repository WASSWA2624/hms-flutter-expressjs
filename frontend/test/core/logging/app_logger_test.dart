import 'package:flutter_template/core/config/app_config.dart';
import 'package:flutter_template/core/logging/app_logger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppLogger', () {
    tearDown(AppLogger.resetForTesting);

    test('redacts sensitive context and avoids logging exception values', () {
      final records = <AppLogRecord>[];
      AppLogger.initialize(AppLogLevel.debug, sink: records.add);

      AppLogger.error(
        'Request failed with Bearer secret-token.',
        const _SensitiveException('password=secret-password'),
        StackTrace.empty,
        context: <String, Object?>{
          'Authorization': 'Bearer secret-token',
          'password': 'secret-password',
          'uri': Uri.parse('https://api.example.test/users?token=secret-token'),
          'attempt': 1,
        },
        reportToFlutter: false,
      );

      final record = records.single;
      final output = record.formattedMessage;

      expect(record.message, 'Request failed with Bearer <redacted>.');
      expect(record.errorType, '_SensitiveException');
      expect(record.context['Authorization'], '<redacted>');
      expect(record.context['password'], '<redacted>');
      expect(record.context['uri'], '/users');
      expect(record.context['attempt'], 1);
      expect(output, isNot(contains('secret-token')));
      expect(output, isNot(contains('secret-password')));
    });

    test('filters records below the configured minimum level', () {
      final records = <AppLogRecord>[];
      AppLogger.initialize(AppLogLevel.warn, sink: records.add);

      AppLogger.debug('Debug event.');
      AppLogger.info('Info event.');
      AppLogger.warning('Warning event.');

      expect(records, hasLength(1));
      expect(records.single.level, AppLogLevel.warn);
      expect(records.single.message, 'Warning event.');
    });
  });
}

final class _SensitiveException implements Exception {
  const _SensitiveException(this.message);

  final String message;

  @override
  String toString() {
    return message;
  }
}
