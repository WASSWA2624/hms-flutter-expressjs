// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'HOSSPI Hospital Management System';

  @override
  String get appShortTitle => 'HOSSPI HMS';

  @override
  String get startupLoadingTitle => 'Starting app';

  @override
  String get startupLoadingBody => 'Preparing local services.';

  @override
  String get startupErrorTitle => 'The app could not start';

  @override
  String get startupErrorBody => 'Restart the app or try again.';

  @override
  String get commonRetryActionLabel => 'Try again';

  @override
  String get commonGoHomeActionLabel => 'Go home';

  @override
  String get commonCancelActionLabel => 'Cancel';

  @override
  String get appStatusOnlineLabel => 'Online';

  @override
  String get appStatusOfflineLabel => 'Offline';

  @override
  String get appOpenNavigationMenuTooltip => 'Open navigation menu';

  @override
  String get appCloseNavigationMenuTooltip => 'Close navigation menu';

  @override
  String get appToggleSidebarTooltip => 'Toggle sidebar';

  @override
  String get appAccountTooltip => 'Account';

  @override
  String get appNotificationsTooltip => 'Notifications';

  @override
  String appNotificationsUnreadLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unread notifications',
      one: '1 unread notification',
      zero: 'No unread notifications',
    );
    return '$_temp0';
  }

  @override
  String get appUserMenuProfileLabel => 'Profile';

  @override
  String get appUserMenuSettingsLabel => 'Settings';

  @override
  String get appUserMenuChangePasswordLabel => 'Change password';

  @override
  String get appUserMenuLogoutLabel => 'Logout';

  @override
  String get navigationHomeLabel => 'Home';

  @override
  String get navigationSettingsLabel => 'Settings';

  @override
  String get homeReadyTitle => 'Hospital operations workspace';

  @override
  String get homeReadyBody =>
      'Coordinate patient registration, clinical care, pharmacy, billing, diagnostics, operations, and compliance from one responsive HMS shell.';

  @override
  String get homeEntryPointsLabel => 'Core entry points';

  @override
  String get homeFeatureResponsiveTitle => 'Patient front desk';

  @override
  String get homeFeatureResponsiveBody =>
      'Register patients, book appointments, and manage queues for OPD and emergency intake.';

  @override
  String get homeFeatureNavigationTitle => 'Clinical workspace';

  @override
  String get homeFeatureNavigationBody =>
      'Open encounters, clinical notes, diagnoses, care plans, orders, and inpatient handovers.';

  @override
  String get homeFeatureLocalizationTitle => 'Revenue cycle';

  @override
  String get homeFeatureLocalizationBody =>
      'Track invoices, cashier payments, refunds, coverage, pre-authorizations, and claims.';

  @override
  String get homeFeatureSettingsTitle => 'Facility operations';

  @override
  String get homeFeatureSettingsBody =>
      'Coordinate wards, beds, departments, equipment, housekeeping, maintenance, and staff rosters.';

  @override
  String get homeLoadingTitle => 'Preparing home';

  @override
  String get homeLoadingBody => 'Loading readiness.';

  @override
  String get homeLoadErrorTitle => 'Home could not load';

  @override
  String get homeLoadErrorBody => 'Try the request again.';

  @override
  String get homeServiceAreasLabel => 'Service areas';

  @override
  String get homeServiceAreaOutpatient =>
      'Outpatient, triage, emergency, and ambulance';

  @override
  String get homeServiceAreaInpatient =>
      'Inpatient, ICU, theater, nursing, and discharge';

  @override
  String get homeServiceAreaDiagnostics =>
      'Laboratory, radiology, pharmacy, and medication dispensing';

  @override
  String get homeServiceAreaAdministration =>
      'Billing, claims, subscriptions, reports, audit, and integrations';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsBody => 'Set HOSSPI HMS preferences.';

  @override
  String get settingsLanguageSectionTitle => 'Language';

  @override
  String get settingsLanguageSectionBody =>
      'English is included. Add more locales later.';

  @override
  String get settingsLanguageFieldLabel => 'App language';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsThemeSectionTitle => 'Theme';

  @override
  String get settingsThemeSectionBody => 'Use system, light, or dark mode.';

  @override
  String get settingsThemeModeFieldLabel => 'App theme';

  @override
  String get settingsThemeModeSystem => 'System';

  @override
  String get settingsThemeModeSystemDescription => 'Follow the device setting.';

  @override
  String get settingsThemeModeLight => 'Light';

  @override
  String get settingsThemeModeLightDescription => 'Use the light color scheme.';

  @override
  String get settingsThemeModeDark => 'Dark';

  @override
  String get settingsThemeModeDarkDescription => 'Use the dark color scheme.';

  @override
  String get settingsSaveErrorMessage => 'The preference could not be saved.';

  @override
  String get routeSessionRestoringTitle => 'Checking session';

  @override
  String get routeSessionRestoringBody => 'Finish session restore first.';

  @override
  String get routeAuthRequiredTitle => 'Sign-in required';

  @override
  String get routeAuthRequiredBody => 'Sign in to open this page.';

  @override
  String get routeForbiddenTitle => 'Access denied';

  @override
  String get routeForbiddenBody => 'You do not have access to this page.';

  @override
  String get routeNotFoundTitle => 'Page not found';

  @override
  String get routeNotFoundBody => 'This route is not available.';

  @override
  String get authLoginTitle => 'Sign in';

  @override
  String get authLoginBody =>
      'Use your facility account to open the HMS workspace.';

  @override
  String get authIdentifierLabel => 'Email or phone';

  @override
  String get authEmailLabel => 'Email';

  @override
  String get authPasswordLabel => 'Password';

  @override
  String get authShowPasswordLabel => 'Show password';

  @override
  String get authHidePasswordLabel => 'Hide password';

  @override
  String get authLoginActionLabel => 'Sign in';

  @override
  String get authCreateAccountActionLabel => 'Create account';

  @override
  String get authRegisterTitle => 'Create facility account';

  @override
  String get authRegisterBody =>
      'Register the first administrator for a facility workspace.';

  @override
  String get authRegisterActionLabel => 'Create account';

  @override
  String get authBackToLoginActionLabel => 'Back to sign in';

  @override
  String get authVerifyEmailActionLabel => 'Verify';

  @override
  String get authSendNewCodeActionLabel => 'Send new code';

  @override
  String get authVerifyEmailTitle => 'Verify your email';

  @override
  String get authEmailVerifiedTitle => 'Email verified';

  @override
  String authVerifyEmailBody(String email) {
    return 'Enter the verification code sent to $email.';
  }

  @override
  String authPendingVerificationBody(String email) {
    return 'This email is already registered but has not been verified. Enter the verification code sent to $email.';
  }

  @override
  String get authVerifyEmailBodyNoEmail =>
      'Enter the verification code sent to your email.';

  @override
  String get authEmailVerifiedBody =>
      'Your account is verified. You can now sign in.';

  @override
  String get authVerificationCodeResentMessage =>
      'A new verification code has been sent.';

  @override
  String get authVerificationCodeLabel => 'Verification code';

  @override
  String get authVerificationCodeInvalidMessage =>
      'Enter the 6-digit verification code.';

  @override
  String get authAccountPendingMessage =>
      'This email is already registered but has not been verified. Enter the email verification code we sent to continue.';

  @override
  String get authAdminNameLabel => 'Administrator name';

  @override
  String get authFacilityNameLabel => 'Facility name';

  @override
  String get authFacilityTypeLabel => 'Facility type';

  @override
  String get authFacilityTypeHospital => 'Hospital';

  @override
  String get authFacilityTypeClinic => 'Clinic';

  @override
  String get authFacilityTypeLab => 'Lab';

  @override
  String get authFacilityTypePharmacy => 'Pharmacy';

  @override
  String get authFacilityTypeOther => 'Other';

  @override
  String get authPhoneOptionalLabel => 'Phone (optional)';

  @override
  String get authLocationOptionalLabel => 'Location (optional)';

  @override
  String get authRegistrationSubmittedTitle => 'Check your email';

  @override
  String get authRegistrationSubmittedBody =>
      'We sent a verification code before the workspace can be used.';

  @override
  String get authChangePasswordTitle => 'Change password';

  @override
  String get authCurrentPasswordLabel => 'Current password';

  @override
  String get authNewPasswordLabel => 'New password';

  @override
  String get authConfirmPasswordLabel => 'Confirm password';

  @override
  String get authChangePasswordActionLabel => 'Change password';

  @override
  String get authPasswordChangedMessage => 'Password changed. Sign in again.';

  @override
  String get authInvalidCredentialsMessage =>
      'The sign-in details are not valid.';

  @override
  String get authForbiddenMessage =>
      'This account cannot complete that action.';

  @override
  String get authEmailInvalidMessage => 'Enter a valid email address.';

  @override
  String get authPasswordMinLengthMessage => 'Use at least 8 characters.';

  @override
  String get authPasswordMismatchMessage => 'Passwords do not match.';

  @override
  String get validationRequired => 'This field is required.';

  @override
  String get errorNetworkTitle => 'Connection problem';

  @override
  String get errorNetworkMessage => 'Check your connection and try again.';

  @override
  String get errorTimeoutTitle => 'Request timed out';

  @override
  String get errorTimeoutMessage => 'The request took too long. Try again.';

  @override
  String get errorOfflineTitle => 'No connection';

  @override
  String get errorOfflineMessage => 'Connect to the internet and try again.';

  @override
  String get errorCancelledTitle => 'Request cancelled';

  @override
  String get errorCancelledMessage => 'The request was cancelled.';

  @override
  String get errorUnauthorizedTitle => 'Sign-in required';

  @override
  String get errorUnauthorizedMessage => 'Sign in again to continue.';

  @override
  String get errorForbiddenTitle => 'Access denied';

  @override
  String get errorForbiddenMessage => 'You do not have permission.';

  @override
  String get errorNotFoundTitle => 'Not found';

  @override
  String get errorNotFoundMessage => 'The item is not available.';

  @override
  String get errorValidationTitle => 'Check the details';

  @override
  String get errorValidationMessage => 'Check the highlighted details.';

  @override
  String get errorUnexpectedResponseTitle => 'Unexpected response';

  @override
  String get errorUnexpectedResponseMessage => 'Try again later.';

  @override
  String get errorStorageTitle => 'Storage unavailable';

  @override
  String get errorStorageMessage =>
      'Local data could not be accessed. Try again.';

  @override
  String get errorUnexpectedTitle => 'Something went wrong';

  @override
  String get errorUnexpectedMessage => 'Something went wrong. Try again.';
}
