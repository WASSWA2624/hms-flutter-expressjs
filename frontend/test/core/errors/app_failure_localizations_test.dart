import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/l10n/app_localizations_en.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppFailureLocalizations', () {
    final l10n = AppLocalizationsEn();

    test('maps typed failures to localized safe messages', () {
      final cases = <AppFailure, String>{
        const AppFailure.network(): l10n.errorNetworkMessage,
        const AppFailure.timeout(): l10n.errorTimeoutMessage,
        const AppFailure.offline(): l10n.errorOfflineMessage,
        const AppFailure.cancelled(): l10n.errorCancelledMessage,
        const AppFailure.unauthorized(): l10n.errorUnauthorizedMessage,
        const AppFailure.forbidden(): l10n.errorForbiddenMessage,
        const AppFailure.notFound(): l10n.errorNotFoundMessage,
        AppFailure.validation(): l10n.errorValidationMessage,
        const AppFailure.unexpectedResponse():
            l10n.errorUnexpectedResponseMessage,
        const AppFailure.storage(): l10n.errorStorageMessage,
        const AppFailure.unexpected(): l10n.errorUnexpectedMessage,
      };

      for (final entry in cases.entries) {
        expect(l10n.failureMessage(entry.key), entry.value);
      }
    });

    test('does not expose validation field names in user-facing messages', () {
      final failure = AppFailure.validation(
        validationFields: <String>{'password', 'token'},
      );

      final message = l10n.failureMessage(failure);

      expect(message, isNot(contains('password')));
      expect(message, isNot(contains('token')));
    });

    test('keeps factory constructors backed by concrete failure classes', () {
      expect(const AppFailure.network(), isA<NetworkFailure>());
      expect(AppFailure.validation(), isA<ValidationFailure>());
      expect(const AppFailure.storage(), isA<StorageFailure>());
    });
  });
}
