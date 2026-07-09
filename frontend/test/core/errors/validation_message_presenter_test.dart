import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/validation_message_presenter.dart';
import 'package:hosspi_hms/l10n/app_localizations_en.dart';

void main() {
  final AppLocalizationsEn l10n = AppLocalizationsEn();

  group('ValidationMessagePresenter', () {
    test('maps required tenant_id errors to a friendly label', () {
      final AppFailure failure = AppFailure.validation(
        validationFields: <String>{'tenant_id'},
        detailMessage: 'tenant_id is required',
        fieldMessages: <String, String>{'tenant_id': 'tenant_id is required'},
      );

      expect(
        ValidationMessagePresenter.displayMessage(failure, l10n),
        'Tenant is required.',
      );
    });

    test('maps patient registration field errors to form labels', () {
      final AppFailure failure = AppFailure.validation(
        fieldMessages: <String, String>{
          'first_name': 'first_name is required',
          'primary_email': 'Invalid value for primary_email',
        },
      );

      expect(
        ValidationMessagePresenter.displayMessage(failure, l10n),
        'First name is required.\nEnter a valid Email.',
      );
    });

    test('humanizes unresolved template placeholders', () {
      final AppFailure failure = AppFailure.validation(
        validationFields: <String>{'gender'},
        detailMessage: '{{field}} is required',
      );

      expect(
        ValidationMessagePresenter.displayMessage(failure, l10n),
        'Gender is required.',
      );
    });

    test('maps tenant field errors to form labels', () {
      final AppFailure failure = AppFailure.validation(
        fieldMessages: <String, String>{'slug': 'slug is already in use'},
      );

      expect(
        ValidationMessagePresenter.displayMessage(failure, l10n),
        'Tenant slug is already in use.',
      );
    });

    test('preserves already human-readable backend messages', () {
      final AppFailure failure = AppFailure.validation(
        detailMessage: 'Invalid email format',
      );

      expect(
        ValidationMessagePresenter.displayMessage(failure, l10n),
        'Invalid email format',
      );
    });
  });
}
