import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// Application title shown in app bars and platform task lists.
  ///
  /// In en, this message translates to:
  /// **'HOSSPI Hospital Management System'**
  String get appTitle;

  /// Short application title shown in compact headers.
  ///
  /// In en, this message translates to:
  /// **'HOSSPI HMS'**
  String get appShortTitle;

  /// Title shown while startup dependencies initialize.
  ///
  /// In en, this message translates to:
  /// **'Starting app'**
  String get startupLoadingTitle;

  /// Body text shown while startup dependencies initialize.
  ///
  /// In en, this message translates to:
  /// **'Preparing local services.'**
  String get startupLoadingBody;

  /// Title shown when startup initialization fails.
  ///
  /// In en, this message translates to:
  /// **'The app could not start'**
  String get startupErrorTitle;

  /// Safe user-facing startup error message.
  ///
  /// In en, this message translates to:
  /// **'Restart the app or try again.'**
  String get startupErrorBody;

  /// Label for actions that retry a failed operation.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get commonRetryActionLabel;

  /// Label for actions that navigate back to the home route.
  ///
  /// In en, this message translates to:
  /// **'Go home'**
  String get commonGoHomeActionLabel;

  /// Label for actions that dismiss the current dialog or flow.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancelActionLabel;

  /// Label shown in the app header when network connectivity is available.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get appStatusOnlineLabel;

  /// Label shown in the app header when network connectivity is unavailable.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get appStatusOfflineLabel;

  /// Tooltip for the mobile navigation drawer open button.
  ///
  /// In en, this message translates to:
  /// **'Open navigation menu'**
  String get appOpenNavigationMenuTooltip;

  /// Tooltip for the mobile navigation drawer close button.
  ///
  /// In en, this message translates to:
  /// **'Close navigation menu'**
  String get appCloseNavigationMenuTooltip;

  /// Tooltip for the desktop sidebar collapse and expand button.
  ///
  /// In en, this message translates to:
  /// **'Toggle sidebar'**
  String get appToggleSidebarTooltip;

  /// Tooltip for the account avatar in the app header.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get appAccountTooltip;

  /// Tooltip for the app header notifications button.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get appNotificationsTooltip;

  /// Accessibility label for unread notification count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No unread notifications} =1{1 unread notification} other{{count} unread notifications}}'**
  String appNotificationsUnreadLabel(int count);

  /// Account menu profile action label.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get appUserMenuProfileLabel;

  /// Account menu settings action label.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get appUserMenuSettingsLabel;

  /// Account menu change password action label.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get appUserMenuChangePasswordLabel;

  /// Account menu logout action label.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get appUserMenuLogoutLabel;

  /// Navigation label for the home destination.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navigationHomeLabel;

  /// Navigation label for the settings destination.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navigationSettingsLabel;

  /// Home page title for the HMS overview state.
  ///
  /// In en, this message translates to:
  /// **'Hospital operations workspace'**
  String get homeReadyTitle;

  /// Home page body for the HMS overview state.
  ///
  /// In en, this message translates to:
  /// **'Coordinate patient registration, clinical care, pharmacy, billing, diagnostics, operations, and compliance from one responsive HMS shell.'**
  String get homeReadyBody;

  /// Heading for the HMS module entry point summary.
  ///
  /// In en, this message translates to:
  /// **'Core entry points'**
  String get homeEntryPointsLabel;

  /// Feature summary title for responsive layout support.
  ///
  /// In en, this message translates to:
  /// **'Patient front desk'**
  String get homeFeatureResponsiveTitle;

  /// Feature summary body for responsive layout support.
  ///
  /// In en, this message translates to:
  /// **'Register patients, book appointments, and manage queues for OPD and emergency intake.'**
  String get homeFeatureResponsiveBody;

  /// Feature summary title for navigation support.
  ///
  /// In en, this message translates to:
  /// **'Clinical workspace'**
  String get homeFeatureNavigationTitle;

  /// Feature summary body for navigation support.
  ///
  /// In en, this message translates to:
  /// **'Open encounters, clinical notes, diagnoses, care plans, orders, and inpatient handovers.'**
  String get homeFeatureNavigationBody;

  /// Feature summary title for localization support.
  ///
  /// In en, this message translates to:
  /// **'Revenue cycle'**
  String get homeFeatureLocalizationTitle;

  /// Feature summary body for localization support.
  ///
  /// In en, this message translates to:
  /// **'Track invoices, cashier payments, refunds, coverage, pre-authorizations, and claims.'**
  String get homeFeatureLocalizationBody;

  /// Feature summary title for settings support.
  ///
  /// In en, this message translates to:
  /// **'Facility operations'**
  String get homeFeatureSettingsTitle;

  /// Feature summary body for settings support.
  ///
  /// In en, this message translates to:
  /// **'Coordinate wards, beds, departments, equipment, housekeeping, maintenance, and staff rosters.'**
  String get homeFeatureSettingsBody;

  /// Title shown while the home feature controller loads readiness state.
  ///
  /// In en, this message translates to:
  /// **'Preparing home'**
  String get homeLoadingTitle;

  /// Body shown while the home feature controller loads readiness state.
  ///
  /// In en, this message translates to:
  /// **'Loading readiness.'**
  String get homeLoadingBody;

  /// Title shown when the home feature controller fails.
  ///
  /// In en, this message translates to:
  /// **'Home could not load'**
  String get homeLoadErrorTitle;

  /// Body shown when the home feature controller fails.
  ///
  /// In en, this message translates to:
  /// **'Try the request again.'**
  String get homeLoadErrorBody;

  /// Heading for the list of HMS service areas.
  ///
  /// In en, this message translates to:
  /// **'Service areas'**
  String get homeServiceAreasLabel;

  /// HMS service area label for outpatient and emergency workflows.
  ///
  /// In en, this message translates to:
  /// **'Outpatient, triage, emergency, and ambulance'**
  String get homeServiceAreaOutpatient;

  /// HMS service area label for inpatient workflows.
  ///
  /// In en, this message translates to:
  /// **'Inpatient, ICU, theater, nursing, and discharge'**
  String get homeServiceAreaInpatient;

  /// HMS service area label for diagnostics and pharmacy workflows.
  ///
  /// In en, this message translates to:
  /// **'Laboratory, radiology, pharmacy, and medication dispensing'**
  String get homeServiceAreaDiagnostics;

  /// HMS service area label for administration workflows.
  ///
  /// In en, this message translates to:
  /// **'Billing, claims, subscriptions, reports, audit, and integrations'**
  String get homeServiceAreaAdministration;

  /// Settings page title.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Settings page intro body.
  ///
  /// In en, this message translates to:
  /// **'Set HOSSPI HMS preferences.'**
  String get settingsBody;

  /// Settings section title for language preferences.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageSectionTitle;

  /// Settings section body for language preferences.
  ///
  /// In en, this message translates to:
  /// **'English is included. Add more locales later.'**
  String get settingsLanguageSectionBody;

  /// Label for the language selection field.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get settingsLanguageFieldLabel;

  /// English language option label.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// Settings section title for theme preferences.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsThemeSectionTitle;

  /// Settings section body for theme preferences.
  ///
  /// In en, this message translates to:
  /// **'Use system, light, or dark mode.'**
  String get settingsThemeSectionBody;

  /// Label for the theme mode selection control.
  ///
  /// In en, this message translates to:
  /// **'App theme'**
  String get settingsThemeModeFieldLabel;

  /// Theme option label for following the system setting.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsThemeModeSystem;

  /// Theme option description for following the system setting.
  ///
  /// In en, this message translates to:
  /// **'Follow the device setting.'**
  String get settingsThemeModeSystemDescription;

  /// Theme option label for light mode.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeModeLight;

  /// Theme option description for light mode.
  ///
  /// In en, this message translates to:
  /// **'Use the light color scheme.'**
  String get settingsThemeModeLightDescription;

  /// Theme option label for dark mode.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeModeDark;

  /// Theme option description for dark mode.
  ///
  /// In en, this message translates to:
  /// **'Use the dark color scheme.'**
  String get settingsThemeModeDarkDescription;

  /// Snackbar message shown when saving a setting fails.
  ///
  /// In en, this message translates to:
  /// **'The preference could not be saved.'**
  String get settingsSaveErrorMessage;

  /// Title shown while session restoration blocks a guarded route.
  ///
  /// In en, this message translates to:
  /// **'Checking session'**
  String get routeSessionRestoringTitle;

  /// Body shown while session restoration blocks a guarded route.
  ///
  /// In en, this message translates to:
  /// **'Finish session restore first.'**
  String get routeSessionRestoringBody;

  /// Title shown when a route requires authentication.
  ///
  /// In en, this message translates to:
  /// **'Sign-in required'**
  String get routeAuthRequiredTitle;

  /// Body shown when a route requires authentication.
  ///
  /// In en, this message translates to:
  /// **'Sign in to open this page.'**
  String get routeAuthRequiredBody;

  /// Title shown when a session lacks route permission.
  ///
  /// In en, this message translates to:
  /// **'Access denied'**
  String get routeForbiddenTitle;

  /// Body shown when a session lacks route permission.
  ///
  /// In en, this message translates to:
  /// **'You do not have access to this page.'**
  String get routeForbiddenBody;

  /// Title shown when a route cannot be matched.
  ///
  /// In en, this message translates to:
  /// **'Page not found'**
  String get routeNotFoundTitle;

  /// Body shown when a route cannot be matched.
  ///
  /// In en, this message translates to:
  /// **'This route is not available.'**
  String get routeNotFoundBody;

  /// Authentication login page title.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authLoginTitle;

  /// Authentication login page supporting text.
  ///
  /// In en, this message translates to:
  /// **'Use your facility account to open the HMS workspace.'**
  String get authLoginBody;

  /// Login identifier field label.
  ///
  /// In en, this message translates to:
  /// **'Email or phone'**
  String get authIdentifierLabel;

  /// Email field label.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmailLabel;

  /// Password field label.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPasswordLabel;

  /// Password visibility action label.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get authShowPasswordLabel;

  /// Password visibility action label.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get authHidePasswordLabel;

  /// Login submit action label.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authLoginActionLabel;

  /// Navigate to self-registration action label.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get authCreateAccountActionLabel;

  /// Self-registration page title.
  ///
  /// In en, this message translates to:
  /// **'Create facility account'**
  String get authRegisterTitle;

  /// Self-registration page supporting text.
  ///
  /// In en, this message translates to:
  /// **'Register the first administrator for a facility workspace.'**
  String get authRegisterBody;

  /// Self-registration submit action label.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get authRegisterActionLabel;

  /// Navigate back to login action label.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get authBackToLoginActionLabel;

  /// Email verification form submit action label.
  ///
  /// In en, this message translates to:
  /// **'Verify email'**
  String get authVerifyEmailActionLabel;

  /// Resend email verification code action label.
  ///
  /// In en, this message translates to:
  /// **'Send new code'**
  String get authSendNewCodeActionLabel;

  /// Facility administrator name field label.
  ///
  /// In en, this message translates to:
  /// **'Administrator name'**
  String get authAdminNameLabel;

  /// Facility name field label.
  ///
  /// In en, this message translates to:
  /// **'Facility name'**
  String get authFacilityNameLabel;

  /// Facility type field label.
  ///
  /// In en, this message translates to:
  /// **'Facility type'**
  String get authFacilityTypeLabel;

  /// Hospital facility type option.
  ///
  /// In en, this message translates to:
  /// **'Hospital'**
  String get authFacilityTypeHospital;

  /// Clinic facility type option.
  ///
  /// In en, this message translates to:
  /// **'Clinic'**
  String get authFacilityTypeClinic;

  /// Lab facility type option.
  ///
  /// In en, this message translates to:
  /// **'Lab'**
  String get authFacilityTypeLab;

  /// Pharmacy facility type option.
  ///
  /// In en, this message translates to:
  /// **'Pharmacy'**
  String get authFacilityTypePharmacy;

  /// Other facility type option.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get authFacilityTypeOther;

  /// Optional phone field label.
  ///
  /// In en, this message translates to:
  /// **'Phone (optional)'**
  String get authPhoneOptionalLabel;

  /// Optional location field label.
  ///
  /// In en, this message translates to:
  /// **'Location (optional)'**
  String get authLocationOptionalLabel;

  /// Title shown after registration request succeeds.
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get authRegistrationSubmittedTitle;

  /// Body shown after registration request succeeds.
  ///
  /// In en, this message translates to:
  /// **'We sent a verification link before the workspace can be used.'**
  String get authRegistrationSubmittedBody;

  /// Change password dialog title.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get authChangePasswordTitle;

  /// Current password field label.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get authCurrentPasswordLabel;

  /// New password field label.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get authNewPasswordLabel;

  /// Confirm password field label.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get authConfirmPasswordLabel;

  /// Change password submit action label.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get authChangePasswordActionLabel;

  /// Snackbar shown after password is changed and sessions are revoked.
  ///
  /// In en, this message translates to:
  /// **'Password changed. Sign in again.'**
  String get authPasswordChangedMessage;

  /// Safe login failure message.
  ///
  /// In en, this message translates to:
  /// **'The sign-in details are not valid.'**
  String get authInvalidCredentialsMessage;

  /// Safe auth forbidden failure message.
  ///
  /// In en, this message translates to:
  /// **'This account cannot complete that action.'**
  String get authForbiddenMessage;

  /// Email validation message.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get authEmailInvalidMessage;

  /// Password minimum length validation message.
  ///
  /// In en, this message translates to:
  /// **'Use at least 8 characters.'**
  String get authPasswordMinLengthMessage;

  /// Password confirmation mismatch validation message.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match.'**
  String get authPasswordMismatchMessage;

  /// Generic required-field validation message for forms.
  ///
  /// In en, this message translates to:
  /// **'This field is required.'**
  String get validationRequired;

  /// Title for a generic network failure.
  ///
  /// In en, this message translates to:
  /// **'Connection problem'**
  String get errorNetworkTitle;

  /// Safe user-facing message for a generic network failure.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again.'**
  String get errorNetworkMessage;

  /// Title for a timeout failure.
  ///
  /// In en, this message translates to:
  /// **'Request timed out'**
  String get errorTimeoutTitle;

  /// Safe user-facing message for a timeout failure.
  ///
  /// In en, this message translates to:
  /// **'The request took too long. Try again.'**
  String get errorTimeoutMessage;

  /// Title for an offline failure.
  ///
  /// In en, this message translates to:
  /// **'No connection'**
  String get errorOfflineTitle;

  /// Safe user-facing message for an offline failure.
  ///
  /// In en, this message translates to:
  /// **'Connect to the internet and try again.'**
  String get errorOfflineMessage;

  /// Title for a cancelled request failure.
  ///
  /// In en, this message translates to:
  /// **'Request cancelled'**
  String get errorCancelledTitle;

  /// Safe user-facing message for a cancelled request failure.
  ///
  /// In en, this message translates to:
  /// **'The request was cancelled.'**
  String get errorCancelledMessage;

  /// Title for an unauthorized failure.
  ///
  /// In en, this message translates to:
  /// **'Sign-in required'**
  String get errorUnauthorizedTitle;

  /// Safe user-facing message for an unauthorized failure.
  ///
  /// In en, this message translates to:
  /// **'Sign in again to continue.'**
  String get errorUnauthorizedMessage;

  /// Title for a forbidden failure.
  ///
  /// In en, this message translates to:
  /// **'Access denied'**
  String get errorForbiddenTitle;

  /// Safe user-facing message for a forbidden failure.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission.'**
  String get errorForbiddenMessage;

  /// Title for a not-found failure.
  ///
  /// In en, this message translates to:
  /// **'Not found'**
  String get errorNotFoundTitle;

  /// Safe user-facing message for a not-found failure.
  ///
  /// In en, this message translates to:
  /// **'The item is not available.'**
  String get errorNotFoundMessage;

  /// Title for a validation failure.
  ///
  /// In en, this message translates to:
  /// **'Check the details'**
  String get errorValidationTitle;

  /// Safe user-facing message for a validation failure.
  ///
  /// In en, this message translates to:
  /// **'Check the highlighted details.'**
  String get errorValidationMessage;

  /// Title for an unexpected API response failure.
  ///
  /// In en, this message translates to:
  /// **'Unexpected response'**
  String get errorUnexpectedResponseTitle;

  /// Safe user-facing message for an unexpected API response failure.
  ///
  /// In en, this message translates to:
  /// **'Try again later.'**
  String get errorUnexpectedResponseMessage;

  /// Title for a local storage failure.
  ///
  /// In en, this message translates to:
  /// **'Storage unavailable'**
  String get errorStorageTitle;

  /// Safe user-facing message for a local storage failure.
  ///
  /// In en, this message translates to:
  /// **'Local data could not be accessed. Try again.'**
  String get errorStorageMessage;

  /// Title for an unexpected failure.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errorUnexpectedTitle;

  /// Generic safe error message for unexpected recoverable failures.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again.'**
  String get errorUnexpectedMessage;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
