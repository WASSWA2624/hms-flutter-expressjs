import 'package:flutter/widgets.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/validation_message_presenter.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';

extension AppLocalizationsBuildContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

extension AppFailureLocalizations on AppLocalizations {
  String failureTitle(AppFailure failure) {
    final String? knownTitle = switch (failure.code) {
      'PERMANENT_DELETE_BLOCKED' =>
        tenantFacilityPermanentDeleteBlockedTitle,
      _ => null,
    };
    if (knownTitle != null) {
      return knownTitle;
    }

    return switch (failure.category) {
      AppFailureCategory.network => errorNetworkTitle,
      AppFailureCategory.timeout => errorTimeoutTitle,
      AppFailureCategory.offline => errorOfflineTitle,
      AppFailureCategory.cancelled => errorCancelledTitle,
      AppFailureCategory.unauthorized => errorUnauthorizedTitle,
      AppFailureCategory.forbidden => errorForbiddenTitle,
      AppFailureCategory.notFound => errorNotFoundTitle,
      AppFailureCategory.conflict => errorConflictTitle,
      AppFailureCategory.validation => errorValidationTitle,
      AppFailureCategory.unexpectedResponse => errorUnexpectedResponseTitle,
      AppFailureCategory.storage => errorStorageTitle,
      AppFailureCategory.unexpected => errorUnexpectedTitle,
    };
  }

  String failureMessage(AppFailure failure) {
    return failure.displayMessage(this);
  }

  String failureDisplayMessage(AppFailure failure) {
    return ValidationMessagePresenter.displayMessage(failure, this);
  }

  String validationFieldLabel(String field) {
    return ValidationMessagePresenter.fieldLabel(this, field);
  }
}

extension AppFailureDisplay on AppFailure {
  String displayMessage(AppLocalizations l10n) =>
      l10n.failureDisplayMessage(this);

  String? messageForField(String field) => fieldMessages[field];
}

extension HosspiHmsLocalizations on AppLocalizations {
  List<String> get homeServiceAreas {
    return <String>[
      homeServiceAreaOutpatient,
      homeServiceAreaInpatient,
      homeServiceAreaDiagnostics,
      homeServiceAreaAdministration,
    ];
  }
}
