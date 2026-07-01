import 'package:flutter/widgets.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';

extension AppLocalizationsBuildContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

extension AppFailureLocalizations on AppLocalizations {
  String failureTitle(AppFailure failure) {
    return switch (failure.category) {
      AppFailureCategory.network => errorNetworkTitle,
      AppFailureCategory.timeout => errorTimeoutTitle,
      AppFailureCategory.offline => errorOfflineTitle,
      AppFailureCategory.cancelled => errorCancelledTitle,
      AppFailureCategory.unauthorized => errorUnauthorizedTitle,
      AppFailureCategory.forbidden => errorForbiddenTitle,
      AppFailureCategory.notFound => errorNotFoundTitle,
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
    if (failure.fieldMessages.isNotEmpty) {
      return failure.fieldMessages.values.join('\n');
    }
    final String? detailMessage = failure.detailMessage;
    if (detailMessage != null && detailMessage.isNotEmpty) {
      return detailMessage;
    }
    return switch (failure.category) {
      AppFailureCategory.network => errorNetworkMessage,
      AppFailureCategory.timeout => errorTimeoutMessage,
      AppFailureCategory.offline => errorOfflineMessage,
      AppFailureCategory.cancelled => errorCancelledMessage,
      AppFailureCategory.unauthorized => errorUnauthorizedMessage,
      AppFailureCategory.forbidden => errorForbiddenMessage,
      AppFailureCategory.notFound => errorNotFoundMessage,
      AppFailureCategory.validation => errorValidationMessage,
      AppFailureCategory.unexpectedResponse => errorUnexpectedResponseMessage,
      AppFailureCategory.storage => errorStorageMessage,
      AppFailureCategory.unexpected => errorUnexpectedMessage,
    };
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
