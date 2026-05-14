import 'package:flutter/widgets.dart';
import 'package:flutter_template/core/errors/app_failure.dart';
import 'package:flutter_template/l10n/app_localizations.dart';

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

extension StarterAppLocalizations on AppLocalizations {
  List<String> get supportedStarterPlatforms {
    return <String>[
      homeSupportedPlatformAndroid,
      homeSupportedPlatformIos,
      homeSupportedPlatformWeb,
      homeSupportedPlatformWindowsDesktop,
      homeSupportedPlatformMacosDesktop,
      homeSupportedPlatformLinuxDesktop,
    ];
  }
}
