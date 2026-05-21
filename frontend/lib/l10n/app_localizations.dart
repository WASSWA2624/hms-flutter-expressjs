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

  /// Label for actions that refresh visible data without reloading the current screen.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get commonRefreshActionLabel;

  /// Label for opening a worklist table column settings dialog.
  ///
  /// In en, this message translates to:
  /// **'Table settings'**
  String get commonTableSettingsActionLabel;

  /// Title for the emergency case detail dialog.
  ///
  /// In en, this message translates to:
  /// **'Emergency case'**
  String get emergencyCaseDialogTitle;

  /// Title for the ICU stay detail dialog.
  ///
  /// In en, this message translates to:
  /// **'ICU stay'**
  String get icuStayDialogTitle;

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

  /// Label for actions that close the current dialog.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonCloseActionLabel;

  /// Validation message for manually typed date fields.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid date.'**
  String get appDateInvalidMessage;

  /// Hint text showing the supported manual date entry format.
  ///
  /// In en, this message translates to:
  /// **'DD/MM/YYYY'**
  String get appDateFormatHint;

  /// Button tooltip or action label for opening a time picker.
  ///
  /// In en, this message translates to:
  /// **'Select time'**
  String get appTimePickerAction;

  /// Validation message for manually typed time fields.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid time.'**
  String get appTimeInvalidMessage;

  /// Hint text showing the supported manual time entry format.
  ///
  /// In en, this message translates to:
  /// **'HH:MM'**
  String get appTimeFormatHint;

  /// Label for the country-code selector inside phone input fields.
  ///
  /// In en, this message translates to:
  /// **'Country code'**
  String get appPhoneCountryLabel;

  /// Label for the search field in the phone country-code picker.
  ///
  /// In en, this message translates to:
  /// **'Search country'**
  String get appPhoneCountrySearchLabel;

  /// Empty-state text shown when no phone country-code picker results match the search query.
  ///
  /// In en, this message translates to:
  /// **'No countries found'**
  String get appPhoneCountryNoResults;

  /// Label for the national phone number field inside phone input fields.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get appPhoneNumberLabel;

  /// Placeholder text for the phone number digits field after a country code is selected.
  ///
  /// In en, this message translates to:
  /// **'Remaining number digits'**
  String get appPhoneNumberHint;

  /// Validation message for invalid phone numbers.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid phone number.'**
  String get appPhoneInvalidMessage;

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

  /// Accessibility label for the desktop side navigation search field.
  ///
  /// In en, this message translates to:
  /// **'Search menu'**
  String get appNavigationSearchLabel;

  /// Hint text for the desktop side navigation search field.
  ///
  /// In en, this message translates to:
  /// **'Search menu'**
  String get appNavigationSearchHint;

  /// Empty-state label shown when side navigation search has no matching menu items.
  ///
  /// In en, this message translates to:
  /// **'No menu items found'**
  String get appNavigationSearchNoResultsLabel;

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

  /// Fallback account menu header label for authenticated users without profile details.
  ///
  /// In en, this message translates to:
  /// **'Signed in'**
  String get appUserMenuSignedInLabel;

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

  /// Navigation label for tenant and facility setup.
  ///
  /// In en, this message translates to:
  /// **'Setup'**
  String get navigationSetupLabel;

  /// Navigation label for the patient registry destination.
  ///
  /// In en, this message translates to:
  /// **'Patients'**
  String get navigationPatientsLabel;

  /// Navigation label for the billing workspace.
  ///
  /// In en, this message translates to:
  /// **'Billing'**
  String get navigationBillingLabel;

  /// Navigation label for the subscriptions workspace.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions'**
  String get navigationSubscriptionsLabel;

  /// Navigation label for the emergency workspace.
  ///
  /// In en, this message translates to:
  /// **'Emergency'**
  String get navigationEmergencyLabel;

  /// Navigation label for the ICU workspace.
  ///
  /// In en, this message translates to:
  /// **'ICU'**
  String get navigationIcuLabel;

  /// Navigation label for the human resources workspace.
  ///
  /// In en, this message translates to:
  /// **'HR'**
  String get navigationHrLabel;

  /// Desktop side navigation group label for overview destinations.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get navigationGroupOverviewLabel;

  /// Desktop side navigation group label for front-desk and access destinations.
  ///
  /// In en, this message translates to:
  /// **'Patient access'**
  String get navigationGroupPatientAccessLabel;

  /// Desktop side navigation group label for inpatient care destinations.
  ///
  /// In en, this message translates to:
  /// **'Inpatient care'**
  String get navigationGroupInpatientCareLabel;

  /// Desktop side navigation group label for clinical service destinations.
  ///
  /// In en, this message translates to:
  /// **'Clinical services'**
  String get navigationGroupClinicalServicesLabel;

  /// Desktop side navigation group label for diagnostic and medication destinations.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics and medication'**
  String get navigationGroupDiagnosticsMedicationLabel;

  /// Desktop side navigation group label for billing and revenue destinations.
  ///
  /// In en, this message translates to:
  /// **'Revenue cycle'**
  String get navigationGroupRevenueCycleLabel;

  /// Desktop side navigation group label for facility operations destinations.
  ///
  /// In en, this message translates to:
  /// **'Facility operations'**
  String get navigationGroupFacilityOperationsLabel;

  /// Desktop side navigation group label for administrative destinations.
  ///
  /// In en, this message translates to:
  /// **'Administration'**
  String get navigationGroupAdministrationLabel;

  /// Navigation label for the OPD workflow destination.
  ///
  /// In en, this message translates to:
  /// **'OPD'**
  String get navigationOpdLabel;

  /// Navigation label for the theater workflow destination.
  ///
  /// In en, this message translates to:
  /// **'Theater'**
  String get navigationTheaterLabel;

  /// Navigation label for the communications workspace.
  ///
  /// In en, this message translates to:
  /// **'Communications'**
  String get navigationCommunicationsLabel;

  /// Human resources workspace text for hrTitle.
  ///
  /// In en, this message translates to:
  /// **'Human resources'**
  String get hrTitle;

  /// Navigation label for the integrations workspace.
  ///
  /// In en, this message translates to:
  /// **'Integrations'**
  String get navigationIntegrationsLabel;

  /// Navigation label for the mortuary workspace.
  ///
  /// In en, this message translates to:
  /// **'Mortuary'**
  String get navigationMortuaryLabel;

  /// Navigation label for the reports workspace.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get navigationReportsLabel;

  /// Title for the theater workspace.
  ///
  /// In en, this message translates to:
  /// **'Theater'**
  String get theaterTitle;

  /// Description for the theater workspace.
  ///
  /// In en, this message translates to:
  /// **'Manage daily cases, readiness, room and team allocation, anesthesia, post-op notes, and handover.'**
  String get theaterDescription;

  /// Loading title for the theater workspace.
  ///
  /// In en, this message translates to:
  /// **'Loading theater'**
  String get theaterLoadingTitle;

  /// Loading body for the theater workspace.
  ///
  /// In en, this message translates to:
  /// **'Loading theater cases and clinical records.'**
  String get theaterLoadingBody;

  /// Status label when theater data is synced.
  ///
  /// In en, this message translates to:
  /// **'Live sync'**
  String get theaterLiveStatus;

  /// Status label when theater data is being saved.
  ///
  /// In en, this message translates to:
  /// **'Saving'**
  String get theaterSavingStatus;

  /// Snackbar message after theater mutations succeed.
  ///
  /// In en, this message translates to:
  /// **'Theater changes saved.'**
  String get theaterSavedMessage;

  /// Action label for scheduling a theater case.
  ///
  /// In en, this message translates to:
  /// **'Schedule case'**
  String get theaterScheduleCaseAction;

  /// Summary card label for scheduled theater cases.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get theaterScheduledSummaryLabel;

  /// Summary card label for active theater cases.
  ///
  /// In en, this message translates to:
  /// **'In theater'**
  String get theaterInTheaterSummaryLabel;

  /// Summary card label for ready theater cases.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get theaterReadySummaryLabel;

  /// Summary card label for completed theater cases.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get theaterCompletedSummaryLabel;

  /// Accessibility label for theater filters.
  ///
  /// In en, this message translates to:
  /// **'Theater filters'**
  String get theaterFiltersLabel;

  /// Label for theater search field.
  ///
  /// In en, this message translates to:
  /// **'Search theater'**
  String get theaterSearchLabel;

  /// Hint for theater search field.
  ///
  /// In en, this message translates to:
  /// **'Search patient, case, encounter, notes, or record text'**
  String get theaterSearchHint;

  /// Label for theater schedule date filter.
  ///
  /// In en, this message translates to:
  /// **'Schedule date'**
  String get theaterScheduleDateFilterLabel;

  /// Action label for picking a theater schedule date.
  ///
  /// In en, this message translates to:
  /// **'Pick schedule date'**
  String get theaterPickScheduleDateAction;

  /// Label for theater status filter.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get theaterStatusFilterLabel;

  /// Label for theater stage filter.
  ///
  /// In en, this message translates to:
  /// **'Stage'**
  String get theaterStageFilterLabel;

  /// Action label for opening theater resource filters.
  ///
  /// In en, this message translates to:
  /// **'Resource filters'**
  String get theaterResourceFiltersAction;

  /// Action label for clearing theater filters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get theaterClearFiltersAction;

  /// Title for theater case board.
  ///
  /// In en, this message translates to:
  /// **'Daily cases'**
  String get theaterCasesTitle;

  /// Description for theater case board.
  ///
  /// In en, this message translates to:
  /// **'Select a case to review readiness, records, resources, and handover.'**
  String get theaterCasesDescription;

  /// Empty-state title when no theater cases match filters.
  ///
  /// In en, this message translates to:
  /// **'No theater cases'**
  String get theaterNoCasesTitle;

  /// Empty-state body when no theater cases match filters.
  ///
  /// In en, this message translates to:
  /// **'Scheduled and active theater cases will appear here.'**
  String get theaterNoCasesBody;

  /// Empty detail title when no theater case is selected.
  ///
  /// In en, this message translates to:
  /// **'No case selected'**
  String get theaterNoCaseSelectedTitle;

  /// Empty detail body when no theater case is selected.
  ///
  /// In en, this message translates to:
  /// **'Select a theater case to review readiness, records, and handover.'**
  String get theaterNoCaseSelectedBody;

  /// Theater case list patient column label.
  ///
  /// In en, this message translates to:
  /// **'Patient'**
  String get theaterPatientColumnLabel;

  /// Theater case list time column label.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get theaterTimeColumnLabel;

  /// Theater case list room column label.
  ///
  /// In en, this message translates to:
  /// **'Room'**
  String get theaterRoomColumnLabel;

  /// Theater case list status column label.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get theaterStatusColumnLabel;

  /// Theater case list readiness column label.
  ///
  /// In en, this message translates to:
  /// **'Readiness'**
  String get theaterReadinessColumnLabel;

  /// Theater case list next action column label.
  ///
  /// In en, this message translates to:
  /// **'Next action'**
  String get theaterNextActionColumnLabel;

  /// Pagination label for theater data lists.
  ///
  /// In en, this message translates to:
  /// **'{from}-{to} of {total}'**
  String theaterPageLabel(int from, int to, int total);

  /// Title for theater case detail panel.
  ///
  /// In en, this message translates to:
  /// **'Case detail'**
  String get theaterCaseDetailTitle;

  /// Action label for rescheduling a theater case.
  ///
  /// In en, this message translates to:
  /// **'Reschedule'**
  String get theaterRescheduleAction;

  /// Action label for updating theater case stage.
  ///
  /// In en, this message translates to:
  /// **'Update stage'**
  String get theaterUpdateStageAction;

  /// Label for encounter in theater detail.
  ///
  /// In en, this message translates to:
  /// **'Encounter'**
  String get theaterEncounterLabel;

  /// Label for scheduled date time in theater forms and detail.
  ///
  /// In en, this message translates to:
  /// **'Scheduled at'**
  String get theaterScheduledAtLabel;

  /// Label for theater room.
  ///
  /// In en, this message translates to:
  /// **'Room'**
  String get theaterRoomLabel;

  /// Label for theater readiness.
  ///
  /// In en, this message translates to:
  /// **'Readiness'**
  String get theaterReadinessLabel;

  /// Title for theater team and flow section.
  ///
  /// In en, this message translates to:
  /// **'Team and flow'**
  String get theaterTeamTitle;

  /// Label for theater surgeon.
  ///
  /// In en, this message translates to:
  /// **'Surgeon'**
  String get theaterSurgeonLabel;

  /// Label for theater anesthetist.
  ///
  /// In en, this message translates to:
  /// **'Anesthetist'**
  String get theaterAnesthetistLabel;

  /// Label for theater workflow stage.
  ///
  /// In en, this message translates to:
  /// **'Stage'**
  String get theaterStageLabel;

  /// Label for theater status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get theaterStatusLabel;

  /// Label for theater stage notes.
  ///
  /// In en, this message translates to:
  /// **'Stage notes'**
  String get theaterStageNotesLabel;

  /// Action label for assigning a theater resource.
  ///
  /// In en, this message translates to:
  /// **'Assign resource'**
  String get theaterAssignResourceAction;

  /// Action label for updating theater readiness checklist.
  ///
  /// In en, this message translates to:
  /// **'Update readiness'**
  String get theaterUpdateReadinessAction;

  /// Action label for editing anesthesia record.
  ///
  /// In en, this message translates to:
  /// **'Anesthesia'**
  String get theaterAnesthesiaAction;

  /// Action label for editing post-op note.
  ///
  /// In en, this message translates to:
  /// **'Post-op'**
  String get theaterPostOpAction;

  /// Action label for theater handover.
  ///
  /// In en, this message translates to:
  /// **'Handover'**
  String get theaterHandoverAction;

  /// Action label for finalizing theater records.
  ///
  /// In en, this message translates to:
  /// **'Finalize'**
  String get theaterFinalizeAction;

  /// Action label for cancelling a theater case.
  ///
  /// In en, this message translates to:
  /// **'Cancel case'**
  String get theaterCancelCaseAction;

  /// Next-action label for starting a ready scheduled case.
  ///
  /// In en, this message translates to:
  /// **'Start case'**
  String get theaterStartCaseAction;

  /// Title for theater readiness checklist.
  ///
  /// In en, this message translates to:
  /// **'Readiness checklist'**
  String get theaterChecklistTitle;

  /// Empty text for theater checklist items.
  ///
  /// In en, this message translates to:
  /// **'No checklist items recorded'**
  String get theaterNoChecklistItemsLabel;

  /// Title for theater clinical records section.
  ///
  /// In en, this message translates to:
  /// **'Clinical records'**
  String get theaterRecordsTitle;

  /// Label for anesthesia record status.
  ///
  /// In en, this message translates to:
  /// **'Anesthesia status'**
  String get theaterAnesthesiaStatusLabel;

  /// Label for post-op record status.
  ///
  /// In en, this message translates to:
  /// **'Post-op status'**
  String get theaterPostOpStatusLabel;

  /// Label for anesthesia notes.
  ///
  /// In en, this message translates to:
  /// **'Anesthesia notes'**
  String get theaterAnesthesiaNotesLabel;

  /// Label for post-op note.
  ///
  /// In en, this message translates to:
  /// **'Post-op note'**
  String get theaterPostOpNoteLabel;

  /// Empty text for anesthesia observations.
  ///
  /// In en, this message translates to:
  /// **'No anesthesia observations recorded'**
  String get theaterNoObservationsLabel;

  /// Title for theater resource allocations section.
  ///
  /// In en, this message translates to:
  /// **'Resources'**
  String get theaterResourcesTitle;

  /// Empty text for theater resources.
  ///
  /// In en, this message translates to:
  /// **'No resources assigned'**
  String get theaterNoResourcesLabel;

  /// Title for theater timeline.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get theaterTimelineTitle;

  /// Empty text for theater timeline.
  ///
  /// In en, this message translates to:
  /// **'No timeline entries'**
  String get theaterNoTimelineLabel;

  /// Dialog title for scheduling a theater case.
  ///
  /// In en, this message translates to:
  /// **'Schedule theater case'**
  String get theaterScheduleCaseDialogTitle;

  /// Dialog title for rescheduling a theater case.
  ///
  /// In en, this message translates to:
  /// **'Reschedule theater case'**
  String get theaterRescheduleDialogTitle;

  /// Dialog title for updating theater stage.
  ///
  /// In en, this message translates to:
  /// **'Update theater stage'**
  String get theaterUpdateStageDialogTitle;

  /// Dialog title for theater handover.
  ///
  /// In en, this message translates to:
  /// **'Complete handover'**
  String get theaterHandoverDialogTitle;

  /// Label for theater handover notes.
  ///
  /// In en, this message translates to:
  /// **'Handover notes'**
  String get theaterHandoverNotesLabel;

  /// Dialog title for cancelling a theater case.
  ///
  /// In en, this message translates to:
  /// **'Cancel theater case'**
  String get theaterCancelCaseDialogTitle;

  /// Label for theater cancellation reason.
  ///
  /// In en, this message translates to:
  /// **'Cancellation reason'**
  String get theaterCancellationReasonLabel;

  /// Dialog title for assigning a theater resource.
  ///
  /// In en, this message translates to:
  /// **'Assign theater resource'**
  String get theaterAssignResourceDialogTitle;

  /// Dialog title for updating theater readiness.
  ///
  /// In en, this message translates to:
  /// **'Update readiness'**
  String get theaterReadinessDialogTitle;

  /// Dialog title for editing anesthesia record.
  ///
  /// In en, this message translates to:
  /// **'Anesthesia record'**
  String get theaterAnesthesiaDialogTitle;

  /// Dialog title for editing post-op note.
  ///
  /// In en, this message translates to:
  /// **'Post-op note'**
  String get theaterPostOpDialogTitle;

  /// Dialog title for finalizing theater records.
  ///
  /// In en, this message translates to:
  /// **'Finalize records'**
  String get theaterFinalizeDialogTitle;

  /// Dialog title for theater resource filters.
  ///
  /// In en, this message translates to:
  /// **'Resource filters'**
  String get theaterResourceFiltersDialogTitle;

  /// Label for encounter ID in theater forms.
  ///
  /// In en, this message translates to:
  /// **'Encounter ID'**
  String get theaterEncounterIdLabel;

  /// Hint for encounter ID in theater forms.
  ///
  /// In en, this message translates to:
  /// **'Encounter UUID or case source identifier'**
  String get theaterEncounterIdHint;

  /// Hint for ISO date time entry in theater forms.
  ///
  /// In en, this message translates to:
  /// **'YYYY-MM-DDTHH:MM:SS'**
  String get theaterDateTimeHint;

  /// Label for theater room ID.
  ///
  /// In en, this message translates to:
  /// **'Room ID'**
  String get theaterRoomIdLabel;

  /// Label for surgeon user ID.
  ///
  /// In en, this message translates to:
  /// **'Surgeon user ID'**
  String get theaterSurgeonIdLabel;

  /// Label for anesthetist user ID.
  ///
  /// In en, this message translates to:
  /// **'Anesthetist user ID'**
  String get theaterAnesthetistIdLabel;

  /// Label for theater resource type.
  ///
  /// In en, this message translates to:
  /// **'Resource type'**
  String get theaterResourceTypeLabel;

  /// Label for theater resource ID.
  ///
  /// In en, this message translates to:
  /// **'Resource ID'**
  String get theaterResourceIdLabel;

  /// Label for theater staff role.
  ///
  /// In en, this message translates to:
  /// **'Staff role'**
  String get theaterStaffRoleLabel;

  /// Generic notes label for theater forms.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get theaterNotesLabel;

  /// Label for theater checklist phase.
  ///
  /// In en, this message translates to:
  /// **'Checklist phase'**
  String get theaterChecklistPhaseLabel;

  /// Label for theater checklist item code.
  ///
  /// In en, this message translates to:
  /// **'Item code'**
  String get theaterChecklistItemCodeLabel;

  /// Label for theater checklist item label.
  ///
  /// In en, this message translates to:
  /// **'Item label'**
  String get theaterChecklistItemLabel;

  /// Label for checklist completed checkbox.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get theaterChecklistCheckedLabel;

  /// Label for clinical record status.
  ///
  /// In en, this message translates to:
  /// **'Record status'**
  String get theaterRecordStatusLabel;

  /// Action label for saving a theater clinical record.
  ///
  /// In en, this message translates to:
  /// **'Save record'**
  String get theaterSaveRecordAction;

  /// Label for theater record type.
  ///
  /// In en, this message translates to:
  /// **'Record type'**
  String get theaterRecordTypeLabel;

  /// Action label for applying theater filters.
  ///
  /// In en, this message translates to:
  /// **'Apply filters'**
  String get theaterApplyFiltersAction;

  /// Validation message for required theater form fields.
  ///
  /// In en, this message translates to:
  /// **'{label} is required.'**
  String theaterFieldRequiredLabel(String label);

  /// Display label for scheduled theater case status.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get theaterStatusScheduled;

  /// Display label for in-progress theater case status.
  ///
  /// In en, this message translates to:
  /// **'In theater'**
  String get theaterStatusInTheater;

  /// Display label for completed theater case status.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get theaterStatusCompleted;

  /// Display label for cancelled theater case status.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get theaterStatusCancelled;

  /// Display label for pre-op theater stage.
  ///
  /// In en, this message translates to:
  /// **'Pre-op'**
  String get theaterStagePreOp;

  /// Display label for sign-in theater stage.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get theaterStageSignIn;

  /// Display label for time-out theater stage.
  ///
  /// In en, this message translates to:
  /// **'Time out'**
  String get theaterStageTimeOut;

  /// Display label for intra-op theater stage.
  ///
  /// In en, this message translates to:
  /// **'Intra-op'**
  String get theaterStageIntraOp;

  /// Display label for sign-out theater stage.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get theaterStageSignOut;

  /// Display label for post-op theater stage.
  ///
  /// In en, this message translates to:
  /// **'Post-op'**
  String get theaterStagePostOp;

  /// Display label for PACU handover theater stage.
  ///
  /// In en, this message translates to:
  /// **'PACU handover'**
  String get theaterStagePacuHandoff;

  /// Display label for completed theater stage.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get theaterStageCompleted;

  /// Display label for draft clinical record status.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get theaterRecordDraft;

  /// Display label for final clinical record status.
  ///
  /// In en, this message translates to:
  /// **'Final'**
  String get theaterRecordFinal;

  /// Display label when theater readiness has no checklist items.
  ///
  /// In en, this message translates to:
  /// **'Not started'**
  String get theaterReadinessNotStarted;

  /// Progress label for theater readiness checklist.
  ///
  /// In en, this message translates to:
  /// **'{completed}/{total} complete'**
  String theaterReadinessProgress(int completed, int total);

  /// OPD workspace title.
  ///
  /// In en, this message translates to:
  /// **'OPD flow'**
  String get opdTitle;

  /// OPD workspace description.
  ///
  /// In en, this message translates to:
  /// **'Manage arrivals, queues, provider readiness, and outpatient clinical handoffs.'**
  String get opdDescription;

  /// Title while OPD data loads.
  ///
  /// In en, this message translates to:
  /// **'Loading OPD flow'**
  String get opdLoadingTitle;

  /// Body while OPD data loads.
  ///
  /// In en, this message translates to:
  /// **'Loading outpatient queue and encounter data.'**
  String get opdLoadingBody;

  /// Status badge shown when OPD data is syncing.
  ///
  /// In en, this message translates to:
  /// **'Live sync'**
  String get opdLiveStatus;

  /// Status badge shown while OPD changes are saving.
  ///
  /// In en, this message translates to:
  /// **'Saving'**
  String get opdSavingStatus;

  /// Action label to create or continue an OPD encounter.
  ///
  /// In en, this message translates to:
  /// **'Start OPD encounter'**
  String get opdStartWalkInAction;

  /// Primary button label for creating a new OPD encounter.
  ///
  /// In en, this message translates to:
  /// **'Start encounter'**
  String get opdStartEncounterAction;

  /// Primary button label when a selected patient already has an active OPD encounter.
  ///
  /// In en, this message translates to:
  /// **'Open active encounter'**
  String get opdOpenActiveEncounterAction;

  /// Tooltip for the shared OPD encounter start action.
  ///
  /// In en, this message translates to:
  /// **'Create or continue an OPD encounter for this patient'**
  String get opdStartEncounterTooltip;

  /// Snackbar shown after an OPD operation succeeds.
  ///
  /// In en, this message translates to:
  /// **'OPD changes saved.'**
  String get opdSavedMessage;

  /// Summary label for OPD arrivals.
  ///
  /// In en, this message translates to:
  /// **'Arrivals'**
  String get opdArrivalsSummaryLabel;

  /// Summary label for OPD queue entries.
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get opdQueueSummaryLabel;

  /// Summary label for active OPD flows.
  ///
  /// In en, this message translates to:
  /// **'Active flows'**
  String get opdActiveFlowSummaryLabel;

  /// Summary label for completed OPD flows.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get opdCompletedFlowSummaryLabel;

  /// Semantic label for OPD filters.
  ///
  /// In en, this message translates to:
  /// **'OPD filters'**
  String get opdFiltersLabel;

  /// Action label for opening the OPD table filter dialog.
  ///
  /// In en, this message translates to:
  /// **'Filter OPD table'**
  String get opdFilterAction;

  /// OPD table filter dialog title.
  ///
  /// In en, this message translates to:
  /// **'Filter OPD table'**
  String get opdFilterDialogTitle;

  /// Label for choosing which OPD table field the search text applies to.
  ///
  /// In en, this message translates to:
  /// **'Search in'**
  String get opdSearchFieldFilterLabel;

  /// Option label for searching or filtering all available OPD table fields.
  ///
  /// In en, this message translates to:
  /// **'All fields'**
  String get opdAllFieldsFilterLabel;

  /// Label for the OPD arrival date range filter.
  ///
  /// In en, this message translates to:
  /// **'Arrival date'**
  String get opdArrivalDateFilterLabel;

  /// Label for the start date in OPD date range filters.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get opdDateFromLabel;

  /// Label for the end date in OPD date range filters.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get opdDateToLabel;

  /// Button label for opening the OPD date picker.
  ///
  /// In en, this message translates to:
  /// **'Choose date'**
  String get opdDatePickerButtonLabel;

  /// Validation message for invalid OPD date filter values.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid date.'**
  String get opdInvalidDateMessage;

  /// Label for the OPD quick arrival date range filter.
  ///
  /// In en, this message translates to:
  /// **'Arrival range'**
  String get opdArrivalRangeFilterLabel;

  /// Option label for not restricting OPD rows by arrival date.
  ///
  /// In en, this message translates to:
  /// **'Any arrival date'**
  String get opdAnyArrivalDateOption;

  /// Quick OPD date filter option for today's arrivals.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get opdDatePresetToday;

  /// Quick OPD date filter option for yesterday's arrivals.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get opdDatePresetYesterday;

  /// Quick OPD date filter option for arrivals in the last seven days.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days'**
  String get opdDatePresetLast7Days;

  /// Quick OPD date filter option for arrivals in the last thirty days.
  ///
  /// In en, this message translates to:
  /// **'Last 30 days'**
  String get opdDatePresetLast30Days;

  /// OPD table category filter label.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get opdCategoryFilterLabel;

  /// OPD table status filter label.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get opdStatusFilterLabel;

  /// OPD table visit type filter label.
  ///
  /// In en, this message translates to:
  /// **'Visit type'**
  String get opdVisitTypeFilterLabel;

  /// OPD table queue filter label.
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get opdQueueFilterLabel;

  /// OPD table provider filter label.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get opdProviderFilterLabel;

  /// OPD table billing filter label.
  ///
  /// In en, this message translates to:
  /// **'Billing'**
  String get opdBillingFilterLabel;

  /// OPD table next action filter label.
  ///
  /// In en, this message translates to:
  /// **'Next action'**
  String get opdNextActionFilterLabel;

  /// All categories option label in OPD filters.
  ///
  /// In en, this message translates to:
  /// **'All categories'**
  String get opdAllCategoriesOption;

  /// All statuses option label in OPD filters.
  ///
  /// In en, this message translates to:
  /// **'All statuses'**
  String get opdAllStatusesOption;

  /// All visit types option label in OPD filters.
  ///
  /// In en, this message translates to:
  /// **'All visit types'**
  String get opdAllVisitTypesOption;

  /// All queues option label in OPD filters.
  ///
  /// In en, this message translates to:
  /// **'All queues'**
  String get opdAllQueuesOption;

  /// All providers option label in OPD filters.
  ///
  /// In en, this message translates to:
  /// **'All providers'**
  String get opdAllProvidersOption;

  /// All billing states option label in OPD filters.
  ///
  /// In en, this message translates to:
  /// **'All billing states'**
  String get opdAllBillingStatesOption;

  /// All next actions option label in OPD filters.
  ///
  /// In en, this message translates to:
  /// **'All next actions'**
  String get opdAllNextActionsOption;

  /// Search field label for OPD.
  ///
  /// In en, this message translates to:
  /// **'Search OPD'**
  String get opdSearchLabel;

  /// Search field hint for OPD.
  ///
  /// In en, this message translates to:
  /// **'Search patient, identifier, or provider'**
  String get opdSearchHint;

  /// Action label to apply OPD filters.
  ///
  /// In en, this message translates to:
  /// **'Apply filters'**
  String get opdApplyFiltersAction;

  /// Action label to clear OPD filters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get opdClearFiltersAction;

  /// Filter label for appointment status.
  ///
  /// In en, this message translates to:
  /// **'Appointment status'**
  String get opdAppointmentStatusFilterLabel;

  /// Filter label for queue status.
  ///
  /// In en, this message translates to:
  /// **'Queue status'**
  String get opdQueueStatusFilterLabel;

  /// Filter label for OPD flow stage.
  ///
  /// In en, this message translates to:
  /// **'Flow stage'**
  String get opdFlowStageFilterLabel;

  /// OPD arrivals panel title.
  ///
  /// In en, this message translates to:
  /// **'Arrivals'**
  String get opdArrivalsTitle;

  /// OPD queue board panel title.
  ///
  /// In en, this message translates to:
  /// **'Queue board'**
  String get opdQueueBoardTitle;

  /// OPD encounters panel title.
  ///
  /// In en, this message translates to:
  /// **'OPD encounters'**
  String get opdFlowsTitle;

  /// OPD main table description.
  ///
  /// In en, this message translates to:
  /// **'Track arrivals, queue status, billing state, provider ownership, and next steps.'**
  String get opdTableDescription;

  /// OPD provider readiness panel title.
  ///
  /// In en, this message translates to:
  /// **'Provider readiness'**
  String get opdProviderReadinessTitle;

  /// OPD activity panel title.
  ///
  /// In en, this message translates to:
  /// **'Recent OPD activity'**
  String get opdActivityTitle;

  /// OPD activity panel description.
  ///
  /// In en, this message translates to:
  /// **'Latest visible outpatient flow changes.'**
  String get opdActivityDescription;

  /// Empty state title for OPD arrivals.
  ///
  /// In en, this message translates to:
  /// **'No arrivals'**
  String get opdNoArrivalsTitle;

  /// Empty state body for OPD arrivals.
  ///
  /// In en, this message translates to:
  /// **'Scheduled and checked-in patients will appear here.'**
  String get opdNoArrivalsBody;

  /// Empty state title for OPD queue.
  ///
  /// In en, this message translates to:
  /// **'No queued patients'**
  String get opdNoQueueTitle;

  /// Empty state body for OPD queue.
  ///
  /// In en, this message translates to:
  /// **'Reception queue entries will appear here as patients are routed.'**
  String get opdNoQueueBody;

  /// Empty state title for OPD encounters.
  ///
  /// In en, this message translates to:
  /// **'No OPD encounters'**
  String get opdNoFlowsTitle;

  /// Empty state body for OPD encounters.
  ///
  /// In en, this message translates to:
  /// **'Started outpatient encounters will appear here.'**
  String get opdNoFlowsBody;

  /// Detail panel empty state title.
  ///
  /// In en, this message translates to:
  /// **'No encounter selected'**
  String get opdNoFlowSelectedTitle;

  /// Detail panel empty state body.
  ///
  /// In en, this message translates to:
  /// **'Select an OPD encounter to review actions and related records.'**
  String get opdNoFlowSelectedBody;

  /// Empty state title for provider readiness.
  ///
  /// In en, this message translates to:
  /// **'No providers ready'**
  String get opdNoProvidersTitle;

  /// Empty state body for provider readiness.
  ///
  /// In en, this message translates to:
  /// **'Provider schedules and available slots will appear here.'**
  String get opdNoProvidersBody;

  /// Empty state title for OPD activity.
  ///
  /// In en, this message translates to:
  /// **'No recent activity'**
  String get opdNoActivityTitle;

  /// Empty state body for OPD activity.
  ///
  /// In en, this message translates to:
  /// **'OPD activity appears once encounters start moving.'**
  String get opdNoActivityBody;

  /// Empty state title for OPD summary patient lists.
  ///
  /// In en, this message translates to:
  /// **'No patients'**
  String get opdNoSummaryPatientsTitle;

  /// Empty state body for OPD summary patient lists.
  ///
  /// In en, this message translates to:
  /// **'Matching OPD patients will appear here.'**
  String get opdNoSummaryPatientsBody;

  /// Patient column label.
  ///
  /// In en, this message translates to:
  /// **'Patient'**
  String get opdPatientColumnLabel;

  /// Category column label for the main OPD table.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get opdCategoryColumnLabel;

  /// Status column label.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get opdStatusColumnLabel;

  /// Visit type column label for the main OPD table.
  ///
  /// In en, this message translates to:
  /// **'Visit type'**
  String get opdVisitTypeColumnLabel;

  /// Queue and status column label for the main OPD table.
  ///
  /// In en, this message translates to:
  /// **'Queue / status'**
  String get opdQueueStatusColumnLabel;

  /// Arrival time column label.
  ///
  /// In en, this message translates to:
  /// **'Arrival time'**
  String get opdTimeColumnLabel;

  /// Wait time column label for the main OPD table.
  ///
  /// In en, this message translates to:
  /// **'Wait time'**
  String get opdWaitingTimeColumnLabel;

  /// Provider column label.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get opdProviderColumnLabel;

  /// Payer and billing column label for the main OPD table.
  ///
  /// In en, this message translates to:
  /// **'Payer / billing'**
  String get opdPayerBillingColumnLabel;

  /// Actions column label.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get opdActionsColumnLabel;

  /// Stage column label.
  ///
  /// In en, this message translates to:
  /// **'Stage'**
  String get opdStageColumnLabel;

  /// Next step column label.
  ///
  /// In en, this message translates to:
  /// **'Next step'**
  String get opdNextStepColumnLabel;

  /// Tooltip for opening OPD row actions.
  ///
  /// In en, this message translates to:
  /// **'Open actions'**
  String get opdOpenActions;

  /// Empty label for a queue status column.
  ///
  /// In en, this message translates to:
  /// **'No patients'**
  String get opdQueueEmptyColumnLabel;

  /// Empty label for related OPD records.
  ///
  /// In en, this message translates to:
  /// **'No related records'**
  String get opdNoRelatedRecordsLabel;

  /// Empty label for OPD timeline.
  ///
  /// In en, this message translates to:
  /// **'No timeline entries'**
  String get opdNoTimelineLabel;

  /// OPD timeline title.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get opdTimelineTitle;

  /// OPD referrals title.
  ///
  /// In en, this message translates to:
  /// **'Referrals'**
  String get opdReferralsTitle;

  /// OPD follow-ups title.
  ///
  /// In en, this message translates to:
  /// **'Follow-ups'**
  String get opdFollowUpsTitle;

  /// Payment status label.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get opdPaymentStatusLabel;

  /// Paid payment label.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get opdPaymentPaidLabel;

  /// Payment required label.
  ///
  /// In en, this message translates to:
  /// **'Payment required'**
  String get opdPaymentRequiredLabel;

  /// Payment not required label.
  ///
  /// In en, this message translates to:
  /// **'Not required'**
  String get opdPaymentNotRequiredLabel;

  /// Title for the reusable OPD encounter context panel.
  ///
  /// In en, this message translates to:
  /// **'Encounter context'**
  String get opdEncounterContextTitle;

  /// Action label to copy the OPD patient identifier.
  ///
  /// In en, this message translates to:
  /// **'Copy patient ID'**
  String get opdCopyPatientIdAction;

  /// Action label to copy the OPD encounter identifier.
  ///
  /// In en, this message translates to:
  /// **'Copy encounter ID'**
  String get opdCopyEncounterIdAction;

  /// Snackbar shown after copying an OPD encounter identifier.
  ///
  /// In en, this message translates to:
  /// **'Encounter ID copied.'**
  String get opdEncounterIdCopiedMessage;

  /// Pagination label for OPD data lists.
  ///
  /// In en, this message translates to:
  /// **'{from}-{to} of {total}'**
  String opdPageLabel(int from, int to, int total);

  /// Previous page label for OPD lists.
  ///
  /// In en, this message translates to:
  /// **'Previous page'**
  String get opdPreviousPageLabel;

  /// Next page label for OPD lists.
  ///
  /// In en, this message translates to:
  /// **'Next page'**
  String get opdNextPageLabel;

  /// Provider availability slot count label.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No open slots} =1{1 open slot} other{{count} open slots}}'**
  String opdAvailableSlotsLabel(int count);

  /// Dialog title for the shared OPD encounter start flow.
  ///
  /// In en, this message translates to:
  /// **'Start OPD encounter'**
  String get opdWalkInDialogTitle;

  /// Title for the patient section in the OPD walk-in form.
  ///
  /// In en, this message translates to:
  /// **'Patient'**
  String get opdPatientSectionTitle;

  /// Title for the routing section in the OPD walk-in form.
  ///
  /// In en, this message translates to:
  /// **'Routing'**
  String get opdRoutingSectionTitle;

  /// Title for the billing section in the OPD walk-in form.
  ///
  /// In en, this message translates to:
  /// **'Billing'**
  String get opdBillingSectionTitle;

  /// Mode label for starting OPD with an existing patient.
  ///
  /// In en, this message translates to:
  /// **'Existing patient'**
  String get opdExistingPatientModeLabel;

  /// Mode label for starting OPD from an appointment.
  ///
  /// In en, this message translates to:
  /// **'Appointment patient'**
  String get opdAppointmentPatientModeLabel;

  /// Mode label for registering a new OPD patient.
  ///
  /// In en, this message translates to:
  /// **'New patient'**
  String get opdNewPatientModeLabel;

  /// Searchable existing patient field label in OPD.
  ///
  /// In en, this message translates to:
  /// **'Search patient'**
  String get opdSearchPatientLabel;

  /// Searchable appointment patient field label in OPD.
  ///
  /// In en, this message translates to:
  /// **'Search appointment'**
  String get opdAppointmentPatientLabel;

  /// Helper text for selecting appointment patients in OPD.
  ///
  /// In en, this message translates to:
  /// **'Select a scheduled appointment to check the patient into OPD.'**
  String get opdAppointmentPatientHelper;

  /// Message shown while checking whether the selected OPD patient already has an active encounter.
  ///
  /// In en, this message translates to:
  /// **'Checking for an active OPD encounter...'**
  String get opdActiveEncounterCheckingLabel;

  /// Title shown when the selected OPD patient already has an active encounter.
  ///
  /// In en, this message translates to:
  /// **'Active OPD encounter found'**
  String get opdActiveEncounterFoundTitle;

  /// Body text shown when an OPD encounter selection matches an already active encounter.
  ///
  /// In en, this message translates to:
  /// **'This patient already has an active OPD encounter. Open the active encounter instead of creating a duplicate.'**
  String get opdActiveEncounterFoundBody;

  /// Searchable provider field label in OPD.
  ///
  /// In en, this message translates to:
  /// **'Search provider'**
  String get opdSearchProviderLabel;

  /// Helper text explaining the selected OPD provider.
  ///
  /// In en, this message translates to:
  /// **'This provider will handle the patient.'**
  String get opdSearchProviderHelper;

  /// Helper text shown when no OPD providers can be loaded.
  ///
  /// In en, this message translates to:
  /// **'No registered providers were found. Check doctor setup or provider permissions.'**
  String get opdNoProvidersHelper;

  /// Toggle label for new patient registration in OPD.
  ///
  /// In en, this message translates to:
  /// **'Register a new patient'**
  String get opdRegisterNewPatientLabel;

  /// Patient ID field label.
  ///
  /// In en, this message translates to:
  /// **'Patient ID'**
  String get opdPatientIdLabel;

  /// First name field label.
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get opdFirstNameLabel;

  /// Last name field label.
  ///
  /// In en, this message translates to:
  /// **'Last name'**
  String get opdLastNameLabel;

  /// Gender field label.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get opdGenderLabel;

  /// Provider ID field label.
  ///
  /// In en, this message translates to:
  /// **'Provider ID'**
  String get opdProviderIdLabel;

  /// Consultation fee field label.
  ///
  /// In en, this message translates to:
  /// **'Consultation fee'**
  String get opdConsultationFeeLabel;

  /// Currency field label.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get opdCurrencyLabel;

  /// Notes field label.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get opdNotesLabel;

  /// Action label to queue an appointment.
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get opdQueueAction;

  /// Action label to reschedule an appointment.
  ///
  /// In en, this message translates to:
  /// **'Reschedule'**
  String get opdRescheduleAction;

  /// Action label to cancel an appointment.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get opdCancelAction;

  /// Action label to check in an appointment.
  ///
  /// In en, this message translates to:
  /// **'Start OPD encounter'**
  String get opdCheckInAction;

  /// Appointment start field label.
  ///
  /// In en, this message translates to:
  /// **'Start time'**
  String get opdAppointmentStartLabel;

  /// Appointment end field label.
  ///
  /// In en, this message translates to:
  /// **'End time'**
  String get opdAppointmentEndLabel;

  /// Date-time input hint for OPD forms.
  ///
  /// In en, this message translates to:
  /// **'YYYY-MM-DDTHH:MM:SS'**
  String get opdDateTimeHint;

  /// Save action label for OPD forms.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get opdSaveAction;

  /// Cancellation reason field label.
  ///
  /// In en, this message translates to:
  /// **'Cancellation reason'**
  String get opdCancellationReasonLabel;

  /// Queue status field label.
  ///
  /// In en, this message translates to:
  /// **'Queue status'**
  String get opdQueueStatusLabel;

  /// Reason field label.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get opdReasonLabel;

  /// Action label to prioritize a queue entry.
  ///
  /// In en, this message translates to:
  /// **'Prioritize'**
  String get opdPrioritizeAction;

  /// Action label to move a queue entry.
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get opdMoveQueueAction;

  /// Action label to start consultation.
  ///
  /// In en, this message translates to:
  /// **'Start consultation'**
  String get opdStartConsultationAction;

  /// Action label to assign doctor.
  ///
  /// In en, this message translates to:
  /// **'Assign doctor'**
  String get opdAssignDoctorAction;

  /// Action label to change the assigned OPD doctor.
  ///
  /// In en, this message translates to:
  /// **'Change doctor'**
  String get opdChangeDoctorAction;

  /// Action label to record consultation payment.
  ///
  /// In en, this message translates to:
  /// **'Pay consultation'**
  String get opdPayConsultationAction;

  /// Action label to manage OPD consultation billing.
  ///
  /// In en, this message translates to:
  /// **'Manage consultation billing'**
  String get opdManageConsultationBillingAction;

  /// Action label to update OPD consultation billing.
  ///
  /// In en, this message translates to:
  /// **'Update consultation billing'**
  String get opdUpdateConsultationBillingAction;

  /// Action label to correct OPD stage.
  ///
  /// In en, this message translates to:
  /// **'Correct stage'**
  String get opdCorrectStageAction;

  /// Action label to create a referral.
  ///
  /// In en, this message translates to:
  /// **'Refer'**
  String get opdReferAction;

  /// Action label to create a follow-up.
  ///
  /// In en, this message translates to:
  /// **'Follow up'**
  String get opdFollowUpAction;

  /// Action label to apply OPD disposition.
  ///
  /// In en, this message translates to:
  /// **'Disposition'**
  String get opdDispositionAction;

  /// Amount field label.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get opdAmountLabel;

  /// Payment method field label.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get opdPaymentMethodLabel;

  /// Transaction reference field label.
  ///
  /// In en, this message translates to:
  /// **'Transaction reference'**
  String get opdTransactionReferenceLabel;

  /// Stage field label.
  ///
  /// In en, this message translates to:
  /// **'Stage'**
  String get opdStageLabel;

  /// Current OPD workflow stage label.
  ///
  /// In en, this message translates to:
  /// **'Current stage'**
  String get opdCurrentStageLabel;

  /// Target OPD workflow stage label.
  ///
  /// In en, this message translates to:
  /// **'Target stage'**
  String get opdTargetStageLabel;

  /// Validation message when an OPD stage correction requires a reason.
  ///
  /// In en, this message translates to:
  /// **'Enter a reason for this stage correction.'**
  String get opdStageCorrectionReasonRequiredMessage;

  /// External facility field label.
  ///
  /// In en, this message translates to:
  /// **'External facility'**
  String get opdExternalFacilityLabel;

  /// Follow-up date field label.
  ///
  /// In en, this message translates to:
  /// **'Follow-up date'**
  String get opdFollowUpDateLabel;

  /// Follow-up time field label.
  ///
  /// In en, this message translates to:
  /// **'Follow-up time'**
  String get opdFollowUpTimeLabel;

  /// Disposition decision field label.
  ///
  /// In en, this message translates to:
  /// **'Decision'**
  String get opdDecisionLabel;

  /// Triage route decision field label.
  ///
  /// In en, this message translates to:
  /// **'Route decision'**
  String get opdRouteDecisionLabel;

  /// Arrival mode field label.
  ///
  /// In en, this message translates to:
  /// **'Arrival mode'**
  String get opdArrivalModeLabel;

  /// Emergency severity field label.
  ///
  /// In en, this message translates to:
  /// **'Emergency severity'**
  String get opdEmergencySeverityLabel;

  /// Triage level field label.
  ///
  /// In en, this message translates to:
  /// **'Triage level'**
  String get opdTriageLevelLabel;

  /// Chief complaint field label.
  ///
  /// In en, this message translates to:
  /// **'Chief complaint'**
  String get opdChiefComplaintLabel;

  /// Emergency indicators toggle label.
  ///
  /// In en, this message translates to:
  /// **'Emergency indicators'**
  String get opdEmergencyIndicatorsLabel;

  /// Reception and queue workflow section title.
  ///
  /// In en, this message translates to:
  /// **'Reception and queue'**
  String get opdWorkflowReceptionTitle;

  /// Triage workflow section title.
  ///
  /// In en, this message translates to:
  /// **'Triage'**
  String get opdWorkflowTriageTitle;

  /// Doctor consultation workflow section title.
  ///
  /// In en, this message translates to:
  /// **'Doctor consultation'**
  String get opdWorkflowDoctorTitle;

  /// Services workflow section title.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get opdWorkflowServicesTitle;

  /// Printing workflow section title.
  ///
  /// In en, this message translates to:
  /// **'Printing'**
  String get opdWorkflowPrintTitle;

  /// Action label to route an OPD patient to triage.
  ///
  /// In en, this message translates to:
  /// **'Send to triage'**
  String get opdSendToTriageAction;

  /// Action label to route an OPD patient to doctor review.
  ///
  /// In en, this message translates to:
  /// **'Send to doctor'**
  String get opdSendToDoctorAction;

  /// Action label to record OPD vitals.
  ///
  /// In en, this message translates to:
  /// **'Record vitals'**
  String get opdRecordVitalsAction;

  /// Action label to edit OPD vitals.
  ///
  /// In en, this message translates to:
  /// **'Edit vitals'**
  String get opdEditVitalsAction;

  /// Action label to record a doctor review.
  ///
  /// In en, this message translates to:
  /// **'Doctor review'**
  String get opdDoctorReviewAction;

  /// Action label to route an OPD patient to lab.
  ///
  /// In en, this message translates to:
  /// **'Send to lab'**
  String get opdRouteLabAction;

  /// Action label to route an OPD patient to radiology.
  ///
  /// In en, this message translates to:
  /// **'Send to radiology'**
  String get opdRouteRadiologyAction;

  /// Action label to route an OPD patient to pharmacy.
  ///
  /// In en, this message translates to:
  /// **'Send to pharmacy'**
  String get opdRoutePharmacyAction;

  /// Action label to open the OPD print summary.
  ///
  /// In en, this message translates to:
  /// **'Print summary'**
  String get opdPrintSummaryAction;

  /// Print action label.
  ///
  /// In en, this message translates to:
  /// **'Print'**
  String get opdPrintAction;

  /// Copy OPD summary action label.
  ///
  /// In en, this message translates to:
  /// **'Copy summary'**
  String get opdCopySummaryAction;

  /// Vitals summary label.
  ///
  /// In en, this message translates to:
  /// **'Vitals'**
  String get opdVitalsSummaryLabel;

  /// Abnormal vital signs summary label.
  ///
  /// In en, this message translates to:
  /// **'Abnormal vitals'**
  String get opdAbnormalVitalsSummaryLabel;

  /// Clinical alerts summary label.
  ///
  /// In en, this message translates to:
  /// **'Clinical alerts'**
  String get opdClinicalAlertsSummaryLabel;

  /// Services summary label.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get opdServicesSummaryLabel;

  /// Clinical notes summary label.
  ///
  /// In en, this message translates to:
  /// **'Clinical notes'**
  String get opdClinicalNotesSummaryLabel;

  /// Procedures summary label.
  ///
  /// In en, this message translates to:
  /// **'Procedures'**
  String get opdProceduresSummaryLabel;

  /// Clinical note field label.
  ///
  /// In en, this message translates to:
  /// **'Clinical note'**
  String get opdClinicalNoteLabel;

  /// Diagnosis type field label.
  ///
  /// In en, this message translates to:
  /// **'Diagnosis type'**
  String get opdDiagnosisTypeLabel;

  /// Diagnosis field label.
  ///
  /// In en, this message translates to:
  /// **'Diagnosis'**
  String get opdDiagnosisLabel;

  /// Diagnosis code field label.
  ///
  /// In en, this message translates to:
  /// **'Diagnosis code'**
  String get opdDiagnosisCodeLabel;

  /// Procedure field label.
  ///
  /// In en, this message translates to:
  /// **'Procedure or minor surgery'**
  String get opdProcedureLabel;

  /// Procedure code field label.
  ///
  /// In en, this message translates to:
  /// **'Procedure code'**
  String get opdProcedureCodeLabel;

  /// Lab test identifiers field label.
  ///
  /// In en, this message translates to:
  /// **'Lab test IDs'**
  String get opdLabTestIdsLabel;

  /// Lab panel identifiers field label.
  ///
  /// In en, this message translates to:
  /// **'Lab panel IDs'**
  String get opdLabPanelIdsLabel;

  /// Radiology test identifiers field label.
  ///
  /// In en, this message translates to:
  /// **'Radiology test IDs'**
  String get opdRadiologyTestIdsLabel;

  /// Available drug field label.
  ///
  /// In en, this message translates to:
  /// **'Available drug'**
  String get opdDrugLabel;

  /// Drug quantity field label.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get opdDrugQuantityLabel;

  /// Dosage field label.
  ///
  /// In en, this message translates to:
  /// **'Dosage'**
  String get opdDosageLabel;

  /// Medication frequency field label.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get opdFrequencyLabel;

  /// Medication route field label.
  ///
  /// In en, this message translates to:
  /// **'Medication route'**
  String get opdMedicationRouteLabel;

  /// Prescription notes field label.
  ///
  /// In en, this message translates to:
  /// **'Prescription notes'**
  String get opdPrescriptionNotesLabel;

  /// Temperature field label.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get opdTemperatureLabel;

  /// Systolic blood pressure field label.
  ///
  /// In en, this message translates to:
  /// **'Systolic'**
  String get opdSystolicLabel;

  /// Diastolic blood pressure field label.
  ///
  /// In en, this message translates to:
  /// **'Diastolic'**
  String get opdDiastolicLabel;

  /// Heart rate field label.
  ///
  /// In en, this message translates to:
  /// **'Heart rate'**
  String get opdHeartRateLabel;

  /// Respiratory rate field label.
  ///
  /// In en, this message translates to:
  /// **'Respiratory rate'**
  String get opdRespiratoryRateLabel;

  /// Oxygen saturation field label.
  ///
  /// In en, this message translates to:
  /// **'Oxygen saturation'**
  String get opdOxygenSaturationLabel;

  /// Weight field label.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get opdWeightLabel;

  /// Triage notes field label.
  ///
  /// In en, this message translates to:
  /// **'Triage notes'**
  String get opdTriageNotesLabel;

  /// Triage worklist scope filter label.
  ///
  /// In en, this message translates to:
  /// **'Triage scope'**
  String get opdTriageScopeFilterLabel;

  /// All triage scopes filter option.
  ///
  /// In en, this message translates to:
  /// **'All triage scopes'**
  String get opdAllTriageScopesOption;

  /// Triage scope option for waiting patients.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get opdTriageScopeWaiting;

  /// Triage scope option for urgent patients.
  ///
  /// In en, this message translates to:
  /// **'Urgent'**
  String get opdTriageScopeUrgent;

  /// Triage scope option for emergency patients.
  ///
  /// In en, this message translates to:
  /// **'Emergency'**
  String get opdTriageScopeEmergency;

  /// Triage scope option for routine patients.
  ///
  /// In en, this message translates to:
  /// **'Routine'**
  String get opdTriageScopeRoutine;

  /// Triage scope option for direct service patients.
  ///
  /// In en, this message translates to:
  /// **'Service-only'**
  String get opdTriageScopeServiceOnly;

  /// Short wait duration label for OPD queue rows.
  ///
  /// In en, this message translates to:
  /// **'Wait {duration}'**
  String opdWaitDurationShort(String duration);

  /// Symptoms field label in triage capture.
  ///
  /// In en, this message translates to:
  /// **'Symptoms'**
  String get opdSymptomsLabel;

  /// Pain severity field label in triage capture.
  ///
  /// In en, this message translates to:
  /// **'Pain severity'**
  String get opdPainSeverityLabel;

  /// Allergies field label in triage capture.
  ///
  /// In en, this message translates to:
  /// **'Allergies'**
  String get opdAllergiesLabel;

  /// Risk flags section label in triage capture.
  ///
  /// In en, this message translates to:
  /// **'Risk flags'**
  String get opdRiskFlagsLabel;

  /// Fall risk triage flag label.
  ///
  /// In en, this message translates to:
  /// **'Fall risk'**
  String get opdRiskFlagFall;

  /// Pregnancy triage flag label.
  ///
  /// In en, this message translates to:
  /// **'Pregnancy'**
  String get opdRiskFlagPregnancy;

  /// Infection risk triage flag label.
  ///
  /// In en, this message translates to:
  /// **'Infection risk'**
  String get opdRiskFlagInfection;

  /// Altered mental state triage flag label.
  ///
  /// In en, this message translates to:
  /// **'Altered mental state'**
  String get opdRiskFlagAlteredMentalState;

  /// Bleeding triage flag label.
  ///
  /// In en, this message translates to:
  /// **'Bleeding'**
  String get opdRiskFlagBleeding;

  /// Option for saving triage without routing yet.
  ///
  /// In en, this message translates to:
  /// **'Do not route yet'**
  String get opdNoRouteDecisionLabel;

  /// Patient registry screen title.
  ///
  /// In en, this message translates to:
  /// **'Patient registry'**
  String get patientsTitle;

  /// Patient registry screen body.
  ///
  /// In en, this message translates to:
  /// **'Find, register, and maintain patient records across front desk and care workflows.'**
  String get patientsBody;

  /// Patient registry table title.
  ///
  /// In en, this message translates to:
  /// **'Patient records'**
  String get patientsTableTitle;

  /// Patient registry table description.
  ///
  /// In en, this message translates to:
  /// **'Browse registered patients, visit context, alerts, status, and available next actions.'**
  String get patientsTableDescription;

  /// Title while the patient registry loads.
  ///
  /// In en, this message translates to:
  /// **'Loading patients'**
  String get patientsLoadingTitle;

  /// Body while the patient registry loads.
  ///
  /// In en, this message translates to:
  /// **'Loading patient registry data.'**
  String get patientsLoadingBody;

  /// Patient registry status badge label.
  ///
  /// In en, this message translates to:
  /// **'Registry ready'**
  String get patientsStatusReady;

  /// Create patient action label.
  ///
  /// In en, this message translates to:
  /// **'Add patient'**
  String get patientsAddAction;

  /// Emergency patient registration action label.
  ///
  /// In en, this message translates to:
  /// **'Emergency registration'**
  String get patientsEmergencyRegisterAction;

  /// Edit patient or related record action label.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get patientsEditAction;

  /// Delete patient or related record action label.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get patientsDeleteAction;

  /// Save patient form action label.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get patientsSaveAction;

  /// Save patient despite duplicate warning action label.
  ///
  /// In en, this message translates to:
  /// **'Save anyway'**
  String get patientsSaveAnywayAction;

  /// Snackbar shown after a patient registry change is saved.
  ///
  /// In en, this message translates to:
  /// **'Patient registry changes saved.'**
  String get patientsSavedMessage;

  /// Snackbar shown after emergency patient registration.
  ///
  /// In en, this message translates to:
  /// **'Emergency patient registered for completion.'**
  String get patientsEmergencySavedMessage;

  /// Snackbar shown after a patient registry record is deleted.
  ///
  /// In en, this message translates to:
  /// **'Patient registry record deleted.'**
  String get patientsDeletedMessage;

  /// Snackbar shown after patient records are merged.
  ///
  /// In en, this message translates to:
  /// **'Patient records merged.'**
  String get patientsMergedMessage;

  /// Snackbar shown after a duplicate review is dismissed.
  ///
  /// In en, this message translates to:
  /// **'Duplicate review dismissed.'**
  String get patientsDuplicateDismissedMessage;

  /// Patient registry total patients summary label.
  ///
  /// In en, this message translates to:
  /// **'Total patients'**
  String get patientsTotalSummaryLabel;

  /// Patient registry total patients summary body.
  ///
  /// In en, this message translates to:
  /// **'All visible patient records in scope.'**
  String get patientsTotalSummaryBody;

  /// Patient registry active patients summary label.
  ///
  /// In en, this message translates to:
  /// **'Active patients'**
  String get patientsActiveSummaryLabel;

  /// Patient registry active patients summary body.
  ///
  /// In en, this message translates to:
  /// **'Patients available for current workflows.'**
  String get patientsActiveSummaryBody;

  /// Patient registry waiting queue summary label.
  ///
  /// In en, this message translates to:
  /// **'Waiting queue'**
  String get patientsQueueSummaryLabel;

  /// Patient registry waiting queue summary body.
  ///
  /// In en, this message translates to:
  /// **'Patients currently waiting for service.'**
  String get patientsQueueSummaryBody;

  /// Patient registry duplicate review summary label.
  ///
  /// In en, this message translates to:
  /// **'Duplicate review'**
  String get patientsDuplicateSummaryLabel;

  /// Patient registry duplicate review summary body.
  ///
  /// In en, this message translates to:
  /// **'Potential matches needing review.'**
  String get patientsDuplicateSummaryBody;

  /// Accessibility label for patient registry filters.
  ///
  /// In en, this message translates to:
  /// **'Patient filters'**
  String get patientsFiltersLabel;

  /// Patient registry search field label.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get patientsSearchLabel;

  /// Patient registry search field hint.
  ///
  /// In en, this message translates to:
  /// **'Name, phone, email, identifier, or contact'**
  String get patientsSearchHint;

  /// Patient registry patient ID filter label.
  ///
  /// In en, this message translates to:
  /// **'Patient ID'**
  String get patientsPatientIdFilterLabel;

  /// Patient registry gender filter label.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get patientsGenderFilterLabel;

  /// Patient registry status filter label.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get patientsStatusFilterLabel;

  /// Patient registry consent filter label.
  ///
  /// In en, this message translates to:
  /// **'Consent'**
  String get patientsConsentFilterLabel;

  /// Patient registry contact filter label.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get patientsContactFilterLabel;

  /// Patient registry exact visit date filter label.
  ///
  /// In en, this message translates to:
  /// **'Visit date'**
  String get patientsVisitDateFilterLabel;

  /// Patient registry visit date range start label.
  ///
  /// In en, this message translates to:
  /// **'Visit from'**
  String get patientsVisitFromFilterLabel;

  /// Patient registry visit date range end label.
  ///
  /// In en, this message translates to:
  /// **'Visit to'**
  String get patientsVisitToFilterLabel;

  /// Patient registry date of birth range start label.
  ///
  /// In en, this message translates to:
  /// **'DOB from'**
  String get patientsDobFromFilterLabel;

  /// Patient registry date of birth range end label.
  ///
  /// In en, this message translates to:
  /// **'DOB to'**
  String get patientsDobToFilterLabel;

  /// Patient registry created date range start label.
  ///
  /// In en, this message translates to:
  /// **'Registered from'**
  String get patientsCreatedFromFilterLabel;

  /// Patient registry created date range end label.
  ///
  /// In en, this message translates to:
  /// **'Registered to'**
  String get patientsCreatedToFilterLabel;

  /// Patient registry active admission filter label.
  ///
  /// In en, this message translates to:
  /// **'Active admission'**
  String get patientsActiveAdmissionFilterLabel;

  /// Patient registry outstanding balance filter label.
  ///
  /// In en, this message translates to:
  /// **'Outstanding balance'**
  String get patientsOutstandingBalanceFilterLabel;

  /// Yes option label for patient filters.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get patientsYesFilterLabel;

  /// No option label for patient filters.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get patientsNoFilterLabel;

  /// Patient advanced filters identity section title.
  ///
  /// In en, this message translates to:
  /// **'Identity'**
  String get patientsFilterIdentitySectionTitle;

  /// Patient advanced filters visit section title.
  ///
  /// In en, this message translates to:
  /// **'Visits'**
  String get patientsFilterVisitSectionTitle;

  /// Patient advanced filters record state section title.
  ///
  /// In en, this message translates to:
  /// **'Record state'**
  String get patientsFilterRecordSectionTitle;

  /// Apply patient registry filters action label.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get patientsApplyFiltersAction;

  /// Clear patient registry filters action label.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get patientsClearFiltersAction;

  /// Open patient registry advanced filters action label.
  ///
  /// In en, this message translates to:
  /// **'Advanced filters'**
  String get patientsAdvancedFiltersAction;

  /// Patient registry advanced filters dialog title.
  ///
  /// In en, this message translates to:
  /// **'Advanced filters'**
  String get patientsAdvancedFiltersTitle;

  /// Patient summary modal loading title.
  ///
  /// In en, this message translates to:
  /// **'Loading patients'**
  String get patientsSummaryLoadingTitle;

  /// Patient summary modal loading body.
  ///
  /// In en, this message translates to:
  /// **'Loading related patient records.'**
  String get patientsSummaryLoadingBody;

  /// Active patient status label.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get patientsActiveFilter;

  /// Inactive patient status label.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get patientsInactiveFilter;

  /// Patient list patient column label.
  ///
  /// In en, this message translates to:
  /// **'Patient'**
  String get patientsPatientColumnLabel;

  /// Patient list patient number column label.
  ///
  /// In en, this message translates to:
  /// **'Patient no.'**
  String get patientsPatientNumberColumnLabel;

  /// Patient list age and sex column label.
  ///
  /// In en, this message translates to:
  /// **'Age / sex'**
  String get patientsAgeSexColumnLabel;

  /// Patient list phone and identifier column label.
  ///
  /// In en, this message translates to:
  /// **'Phone / ID'**
  String get patientsPhoneIdentifierColumnLabel;

  /// Patient list alert and allergy column label.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get patientsAlertColumnLabel;

  /// Patient list current or latest visit column label.
  ///
  /// In en, this message translates to:
  /// **'Visit'**
  String get patientsVisitColumnLabel;

  /// Patient list next permitted action column label.
  ///
  /// In en, this message translates to:
  /// **'Next action'**
  String get patientsNextActionColumnLabel;

  /// Patient list identifier column label.
  ///
  /// In en, this message translates to:
  /// **'Identifier'**
  String get patientsIdentifierColumnLabel;

  /// Patient list contact column label.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get patientsContactColumnLabel;

  /// Patient list date of birth column label.
  ///
  /// In en, this message translates to:
  /// **'DOB'**
  String get patientsDobColumnLabel;

  /// Patient list status column label.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get patientsStatusColumnLabel;

  /// Label shown when a patient has no visible alerts.
  ///
  /// In en, this message translates to:
  /// **'No alerts'**
  String get patientsNoAlertsLabel;

  /// Short allergy alert label.
  ///
  /// In en, this message translates to:
  /// **'Allergy'**
  String get patientsAllergyAlertLabel;

  /// Label shown when no visit context is available.
  ///
  /// In en, this message translates to:
  /// **'No visit'**
  String get patientsNoVisitLabel;

  /// Next action label for incomplete patient registration records.
  ///
  /// In en, this message translates to:
  /// **'Complete record'**
  String get patientsCompleteRecordAction;

  /// Next action label for opening a patient record.
  ///
  /// In en, this message translates to:
  /// **'Open record'**
  String get patientsOpenRecordAction;

  /// Patient list pagination range label.
  ///
  /// In en, this message translates to:
  /// **'{from}-{to} of {total}'**
  String patientsPageLabel(int from, int to, int total);

  /// Previous patient page button accessibility label.
  ///
  /// In en, this message translates to:
  /// **'Previous patients page'**
  String get patientsPreviousPageLabel;

  /// Next patient page button accessibility label.
  ///
  /// In en, this message translates to:
  /// **'Next patients page'**
  String get patientsNextPageLabel;

  /// Patient list empty state title.
  ///
  /// In en, this message translates to:
  /// **'No patients found'**
  String get patientsEmptyTitle;

  /// Patient list empty state body.
  ///
  /// In en, this message translates to:
  /// **'Adjust the filters or register a patient.'**
  String get patientsEmptyBody;

  /// Patient detail panel title.
  ///
  /// In en, this message translates to:
  /// **'Patient details'**
  String get patientsDetailTitle;

  /// Patient detail loading state title.
  ///
  /// In en, this message translates to:
  /// **'Loading patient'**
  String get patientsDetailLoadingTitle;

  /// Patient detail loading state body.
  ///
  /// In en, this message translates to:
  /// **'Loading demographics and related records.'**
  String get patientsDetailLoadingBody;

  /// Patient detail empty selection title.
  ///
  /// In en, this message translates to:
  /// **'Select a patient'**
  String get patientsNoSelectionTitle;

  /// Patient detail empty selection body.
  ///
  /// In en, this message translates to:
  /// **'Open a patient to review demographics, contacts, clinical flags, documents, and visits.'**
  String get patientsNoSelectionBody;

  /// Patient name detail label.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get patientsNameLabel;

  /// Patient identifier detail label.
  ///
  /// In en, this message translates to:
  /// **'Identifier'**
  String get patientsIdentifierLabel;

  /// Patient date of birth label.
  ///
  /// In en, this message translates to:
  /// **'Date of birth'**
  String get patientsDobLabel;

  /// Patient gender label.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get patientsGenderLabel;

  /// Patient phone label.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get patientsPhoneLabel;

  /// Patient email label.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get patientsEmailLabel;

  /// Patient facility label.
  ///
  /// In en, this message translates to:
  /// **'Facility'**
  String get patientsFacilityLabel;

  /// Patient registration completion status label.
  ///
  /// In en, this message translates to:
  /// **'Registration'**
  String get patientsRegistrationStatusLabel;

  /// Patient registration incomplete status value.
  ///
  /// In en, this message translates to:
  /// **'Completion needed'**
  String get patientsRegistrationIncompleteValue;

  /// Patient first name field label.
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get patientsFirstNameLabel;

  /// Patient last name field label.
  ///
  /// In en, this message translates to:
  /// **'Last name'**
  String get patientsLastNameLabel;

  /// Patient identifier type field label.
  ///
  /// In en, this message translates to:
  /// **'Identifier type'**
  String get patientsIdentifierTypeLabel;

  /// Patient identifier value field label.
  ///
  /// In en, this message translates to:
  /// **'Identifier value'**
  String get patientsIdentifierValueLabel;

  /// Patient active checkbox label.
  ///
  /// In en, this message translates to:
  /// **'Patient is active'**
  String get patientsActiveCheckboxLabel;

  /// Patient form date picker button label.
  ///
  /// In en, this message translates to:
  /// **'Select date'**
  String get patientsDatePickerAction;

  /// Add patient dialog title.
  ///
  /// In en, this message translates to:
  /// **'Add patient'**
  String get patientsAddTitle;

  /// Emergency patient registration dialog title.
  ///
  /// In en, this message translates to:
  /// **'Emergency registration'**
  String get patientsEmergencyRegisterTitle;

  /// Emergency patient registration dialog body.
  ///
  /// In en, this message translates to:
  /// **'Create a minimal patient record now; demographics and documents can be completed after urgent care starts.'**
  String get patientsEmergencyRegisterBody;

  /// Emergency patient first name field label.
  ///
  /// In en, this message translates to:
  /// **'Known first name'**
  String get patientsEmergencyFirstNameLabel;

  /// Emergency patient last name field label.
  ///
  /// In en, this message translates to:
  /// **'Known last name'**
  String get patientsEmergencyLastNameLabel;

  /// Emergency patient registration submit action label.
  ///
  /// In en, this message translates to:
  /// **'Register emergency patient'**
  String get patientsEmergencySaveAction;

  /// Edit patient dialog title.
  ///
  /// In en, this message translates to:
  /// **'Edit patient'**
  String get patientsEditTitle;

  /// Delete patient confirmation title.
  ///
  /// In en, this message translates to:
  /// **'Delete patient'**
  String get patientsDeleteTitle;

  /// Delete patient confirmation body.
  ///
  /// In en, this message translates to:
  /// **'Delete {name} from active patient records?'**
  String patientsDeleteBody(String name);

  /// Male patient gender label.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get patientsGenderMale;

  /// Female patient gender label.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get patientsGenderFemale;

  /// Other patient gender label.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get patientsGenderOther;

  /// Unknown patient gender label.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get patientsGenderUnknown;

  /// Patient quick actions section title.
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get patientsQuickActionsTitle;

  /// Patient quick appointment action label.
  ///
  /// In en, this message translates to:
  /// **'Appointment'**
  String get patientsQuickAppointmentAction;

  /// Patient quick action label for creating or continuing an OPD encounter.
  ///
  /// In en, this message translates to:
  /// **'Start / Check in OPD'**
  String get patientsQuickOpdCheckInAction;

  /// Patient quick action label for opening the active OPD encounter actions.
  ///
  /// In en, this message translates to:
  /// **'Continue OPD flow'**
  String get patientsQuickViewActiveOpdAction;

  /// Patient quick triage action label.
  ///
  /// In en, this message translates to:
  /// **'Triage'**
  String get patientsQuickTriageAction;

  /// Patient quick clinical visit action label.
  ///
  /// In en, this message translates to:
  /// **'Clinical visit'**
  String get patientsQuickClinicalAction;

  /// Patient quick billing action label.
  ///
  /// In en, this message translates to:
  /// **'Billing'**
  String get patientsQuickBillingAction;

  /// Patient quick admission action label.
  ///
  /// In en, this message translates to:
  /// **'Admission'**
  String get patientsQuickAdmissionAction;

  /// Patient quick report action label.
  ///
  /// In en, this message translates to:
  /// **'Patient report'**
  String get patientsQuickReportAction;

  /// Snackbar shown when a patient quick action is selected.
  ///
  /// In en, this message translates to:
  /// **'The patient context is ready for the selected workflow.'**
  String get patientsQuickActionQueuedMessage;

  /// Snackbar shown after a patient quick action completes successfully.
  ///
  /// In en, this message translates to:
  /// **'Patient workflow updated.'**
  String get patientsQuickActionSavedMessage;

  /// Patient workflow validation failure message with field names.
  ///
  /// In en, this message translates to:
  /// **'Check these fields and try again: {fields}.'**
  String patientsWorkflowValidationMessage(String fields);

  /// Patient quick appointment dialog title.
  ///
  /// In en, this message translates to:
  /// **'Schedule appointment'**
  String get patientsAppointmentDialogTitle;

  /// Patient appointment date field label.
  ///
  /// In en, this message translates to:
  /// **'Appointment date'**
  String get patientsAppointmentDateLabel;

  /// Patient appointment start time field label.
  ///
  /// In en, this message translates to:
  /// **'Start time'**
  String get patientsAppointmentTimeLabel;

  /// Patient appointment duration field label.
  ///
  /// In en, this message translates to:
  /// **'Duration minutes'**
  String get patientsAppointmentDurationLabel;

  /// Patient appointment status field label.
  ///
  /// In en, this message translates to:
  /// **'Appointment status'**
  String get patientsAppointmentStatusLabel;

  /// Patient appointment reason field label.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get patientsAppointmentReasonLabel;

  /// Patient workflow provider select field label.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get patientsProviderLabel;

  /// Helper text for optional provider selection.
  ///
  /// In en, this message translates to:
  /// **'Optional provider assignment.'**
  String get patientsProviderOptionalHelper;

  /// Patient quick action workflow section title.
  ///
  /// In en, this message translates to:
  /// **'Workflow'**
  String get patientsWorkflowSectionTitle;

  /// Patient quick action arrival section title.
  ///
  /// In en, this message translates to:
  /// **'Arrival'**
  String get patientsArrivalSectionTitle;

  /// Patient triage priority form section title.
  ///
  /// In en, this message translates to:
  /// **'Triage priority'**
  String get patientsTriagePrioritySectionTitle;

  /// Patient triage vital signs section title.
  ///
  /// In en, this message translates to:
  /// **'Vital signs'**
  String get patientsVitalsSectionTitle;

  /// Patient clinical quick action assessment section title.
  ///
  /// In en, this message translates to:
  /// **'Assessment'**
  String get patientsClinicalAssessmentSectionTitle;

  /// Patient billing quick action section title.
  ///
  /// In en, this message translates to:
  /// **'Billing details'**
  String get patientsBillingSectionTitle;

  /// Patient admission clinical section title.
  ///
  /// In en, this message translates to:
  /// **'Clinical approval'**
  String get patientsAdmissionClinicalSectionTitle;

  /// Patient admission location section title.
  ///
  /// In en, this message translates to:
  /// **'Admission location'**
  String get patientsAdmissionLocationSectionTitle;

  /// Patient quick action notes section title.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get patientsNotesSectionTitle;

  /// Patient OPD encounter dialog title.
  ///
  /// In en, this message translates to:
  /// **'Start OPD encounter'**
  String get patientsOpdCheckInDialogTitle;

  /// Patient triage dialog title.
  ///
  /// In en, this message translates to:
  /// **'Triage intake'**
  String get patientsTriageDialogTitle;

  /// Patient clinical visit dialog title.
  ///
  /// In en, this message translates to:
  /// **'Clinical visit'**
  String get patientsClinicalDialogTitle;

  /// Patient billing dialog title.
  ///
  /// In en, this message translates to:
  /// **'Consultation billing'**
  String get patientsBillingDialogTitle;

  /// Patient admission dialog title.
  ///
  /// In en, this message translates to:
  /// **'Admit patient'**
  String get patientsAdmissionDialogTitle;

  /// Patient OPD arrival mode field label.
  ///
  /// In en, this message translates to:
  /// **'Arrival mode'**
  String get patientsArrivalModeLabel;

  /// Patient emergency severity field label.
  ///
  /// In en, this message translates to:
  /// **'Emergency severity'**
  String get patientsEmergencySeverityLabel;

  /// Patient triage level field label.
  ///
  /// In en, this message translates to:
  /// **'Triage level'**
  String get patientsTriageLevelLabel;

  /// Patient systolic blood pressure field label.
  ///
  /// In en, this message translates to:
  /// **'Systolic'**
  String get patientsSystolicLabel;

  /// Patient blood pressure vital signs group label.
  ///
  /// In en, this message translates to:
  /// **'Blood pressure'**
  String get patientsBloodPressureLabel;

  /// Patient diastolic blood pressure field label.
  ///
  /// In en, this message translates to:
  /// **'Diastolic'**
  String get patientsDiastolicLabel;

  /// Patient temperature vital field label.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get patientsTemperatureLabel;

  /// Patient heart rate vital field label.
  ///
  /// In en, this message translates to:
  /// **'Heart rate'**
  String get patientsHeartRateLabel;

  /// Patient respiratory rate vital field label.
  ///
  /// In en, this message translates to:
  /// **'Respiratory rate'**
  String get patientsRespiratoryRateLabel;

  /// Patient oxygen saturation vital field label.
  ///
  /// In en, this message translates to:
  /// **'Oxygen saturation'**
  String get patientsOxygenSaturationLabel;

  /// Patient weight vital field label.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get patientsWeightLabel;

  /// Patient height vital field label.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get patientsHeightLabel;

  /// Validation message when triage has no vital signs.
  ///
  /// In en, this message translates to:
  /// **'Enter at least one vital sign before completing triage.'**
  String get patientsVitalsRequiredMessage;

  /// Unit field label for vital sign inputs.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get patientsVitalUnitLabel;

  /// Normal vital sign status label.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get patientsVitalNormalLabel;

  /// Abnormal vital sign status label.
  ///
  /// In en, this message translates to:
  /// **'Abnormal'**
  String get patientsVitalAbnormalLabel;

  /// Validation message for non-numeric vital sign input.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid number.'**
  String get patientsVitalNumberInvalidMessage;

  /// Helper text showing the expected vital sign range for the patient profile.
  ///
  /// In en, this message translates to:
  /// **'Expected for {profile}: {range}'**
  String patientsVitalRangeSuggestion(String profile, String range);

  /// Validation message for vital sign values outside supported input limits.
  ///
  /// In en, this message translates to:
  /// **'Enter a value between {range}.'**
  String patientsVitalLimitMessage(String range);

  /// Patient chief complaint field label.
  ///
  /// In en, this message translates to:
  /// **'Chief complaint'**
  String get patientsChiefComplaintLabel;

  /// Patient clinical note field label.
  ///
  /// In en, this message translates to:
  /// **'Clinical note'**
  String get patientsClinicalNoteLabel;

  /// Patient diagnosis field label.
  ///
  /// In en, this message translates to:
  /// **'Diagnosis'**
  String get patientsDiagnosisLabel;

  /// Patient consultation fee field label.
  ///
  /// In en, this message translates to:
  /// **'Consultation fee'**
  String get patientsConsultationFeeLabel;

  /// Patient currency field label.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get patientsCurrencyLabel;

  /// Patient billing payment received checkbox label.
  ///
  /// In en, this message translates to:
  /// **'Payment received'**
  String get patientsMarkPaymentReceivedLabel;

  /// Patient payment method field label.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get patientsPaymentMethodLabel;

  /// Patient payment transaction reference field label.
  ///
  /// In en, this message translates to:
  /// **'Transaction reference'**
  String get patientsTransactionReferenceLabel;

  /// Patient admission reason field label.
  ///
  /// In en, this message translates to:
  /// **'Admission reason'**
  String get patientsAdmissionReasonLabel;

  /// Patient admission ward field label.
  ///
  /// In en, this message translates to:
  /// **'Ward'**
  String get patientsWardLabel;

  /// Patient admission room field label.
  ///
  /// In en, this message translates to:
  /// **'Room'**
  String get patientsRoomLabel;

  /// Patient admission bed field label.
  ///
  /// In en, this message translates to:
  /// **'Bed'**
  String get patientsBedLabel;

  /// Patient report dialog title.
  ///
  /// In en, this message translates to:
  /// **'Patient report'**
  String get patientsReportDialogTitle;

  /// Patient report print action label.
  ///
  /// In en, this message translates to:
  /// **'Print report'**
  String get patientsPrintReportAction;

  /// Patient report appointments section title.
  ///
  /// In en, this message translates to:
  /// **'Appointments'**
  String get patientsAppointmentsSectionTitle;

  /// Patient report encounters section title.
  ///
  /// In en, this message translates to:
  /// **'Encounters'**
  String get patientsEncountersSectionTitle;

  /// Patient report admissions section title.
  ///
  /// In en, this message translates to:
  /// **'Admissions'**
  String get patientsAdmissionsSectionTitle;

  /// Patient report invoices section title.
  ///
  /// In en, this message translates to:
  /// **'Invoices'**
  String get patientsInvoicesSectionTitle;

  /// Patient report summary section title.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get patientsReportSummarySectionTitle;

  /// Patient report generated metadata section title.
  ///
  /// In en, this message translates to:
  /// **'Generated'**
  String get patientsReportGeneratedSectionTitle;

  /// Patient report print preview dialog title.
  ///
  /// In en, this message translates to:
  /// **'Print preview'**
  String get patientsReportPreviewDialogTitle;

  /// Patient report period selector label.
  ///
  /// In en, this message translates to:
  /// **'Report period'**
  String get patientsReportPeriodLabel;

  /// Patient report period option for all dates.
  ///
  /// In en, this message translates to:
  /// **'All dates'**
  String get patientsReportAllDatesOption;

  /// Patient report period option for a single date.
  ///
  /// In en, this message translates to:
  /// **'Single date'**
  String get patientsReportSingleDateOption;

  /// Patient report period option for a date range.
  ///
  /// In en, this message translates to:
  /// **'Date range'**
  String get patientsReportDateRangeOption;

  /// Patient report single date field label.
  ///
  /// In en, this message translates to:
  /// **'Report date'**
  String get patientsReportDateLabel;

  /// Patient report start date field label.
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get patientsReportStartDateLabel;

  /// Patient report end date field label.
  ///
  /// In en, this message translates to:
  /// **'End date'**
  String get patientsReportEndDateLabel;

  /// Patient report section selector title.
  ///
  /// In en, this message translates to:
  /// **'Report sections'**
  String get patientsReportSectionsLabel;

  /// Patient report preview section title.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get patientsReportPreviewSectionTitle;

  /// Patient report patient information section title.
  ///
  /// In en, this message translates to:
  /// **'Patient information'**
  String get patientsReportPatientInfoSectionTitle;

  /// Patient report hospital information section title.
  ///
  /// In en, this message translates to:
  /// **'Hospital information'**
  String get patientsReportHospitalInfoSectionTitle;

  /// Patient report vital signs section title.
  ///
  /// In en, this message translates to:
  /// **'Vital signs'**
  String get patientsReportVitalsSectionTitle;

  /// Patient report payments section title.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get patientsReportPaymentsSectionTitle;

  /// Patient report page number label.
  ///
  /// In en, this message translates to:
  /// **'Page {page} of {total}'**
  String patientsReportPageNumberLabel(int page, int total);

  /// Patient report empty section label.
  ///
  /// In en, this message translates to:
  /// **'No records available for the selected period.'**
  String get patientsReportNoRecordsForSection;

  /// Patient report prepared date label.
  ///
  /// In en, this message translates to:
  /// **'Prepared on'**
  String get patientsReportPreparedOnLabel;

  /// Patient report hospital name label.
  ///
  /// In en, this message translates to:
  /// **'Hospital name'**
  String get patientsReportHospitalNameLabel;

  /// Patient report hospital contact label.
  ///
  /// In en, this message translates to:
  /// **'Contact information'**
  String get patientsReportHospitalContactLabel;

  /// Patient report hospital location label.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get patientsReportHospitalLocationLabel;

  /// Patient report hospital address label.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get patientsReportHospitalAddressLabel;

  /// Patient report print preview action label.
  ///
  /// In en, this message translates to:
  /// **'Print'**
  String get patientsReportPrintNowAction;

  /// Patient report date range validation message.
  ///
  /// In en, this message translates to:
  /// **'Start date must be on or before end date.'**
  String get patientsReportDateRangeInvalidMessage;

  /// Validation message for invalid time fields.
  ///
  /// In en, this message translates to:
  /// **'Enter time as HH:MM.'**
  String get patientsTimeInvalidMessage;

  /// Hint for time fields that expect 24-hour HH:MM input.
  ///
  /// In en, this message translates to:
  /// **'HH:MM'**
  String get patientsTimeHint;

  /// Validation message for invalid appointment duration.
  ///
  /// In en, this message translates to:
  /// **'Enter a duration between 1 and 720 minutes.'**
  String get patientsDurationInvalidMessage;

  /// Patient identifiers section title.
  ///
  /// In en, this message translates to:
  /// **'Identifiers'**
  String get patientsIdentifiersSectionTitle;

  /// Patient contacts section title.
  ///
  /// In en, this message translates to:
  /// **'Contacts'**
  String get patientsContactsSectionTitle;

  /// Patient guardians section title.
  ///
  /// In en, this message translates to:
  /// **'Guardians'**
  String get patientsGuardiansSectionTitle;

  /// Patient allergies section title.
  ///
  /// In en, this message translates to:
  /// **'Allergies'**
  String get patientsAllergiesSectionTitle;

  /// Patient medical history section title.
  ///
  /// In en, this message translates to:
  /// **'Medical history'**
  String get patientsMedicalHistorySectionTitle;

  /// Patient documents section title.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get patientsDocumentsSectionTitle;

  /// Patient consents section title.
  ///
  /// In en, this message translates to:
  /// **'Consents'**
  String get patientsConsentsSectionTitle;

  /// Patient timeline section title.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get patientsTimelineSectionTitle;

  /// Patient identifiers empty label.
  ///
  /// In en, this message translates to:
  /// **'No identifiers recorded.'**
  String get patientsNoIdentifiers;

  /// Patient contacts empty label.
  ///
  /// In en, this message translates to:
  /// **'No contacts recorded.'**
  String get patientsNoContacts;

  /// Patient guardians empty label.
  ///
  /// In en, this message translates to:
  /// **'No guardians recorded.'**
  String get patientsNoGuardians;

  /// Patient allergies empty label.
  ///
  /// In en, this message translates to:
  /// **'No allergies recorded.'**
  String get patientsNoAllergies;

  /// Patient medical history empty label.
  ///
  /// In en, this message translates to:
  /// **'No medical history recorded.'**
  String get patientsNoMedicalHistory;

  /// Patient documents empty label.
  ///
  /// In en, this message translates to:
  /// **'No documents recorded.'**
  String get patientsNoDocuments;

  /// Patient consents empty label.
  ///
  /// In en, this message translates to:
  /// **'No consents recorded.'**
  String get patientsNoConsents;

  /// Patient timeline empty label.
  ///
  /// In en, this message translates to:
  /// **'No timeline entries recorded.'**
  String get patientsNoTimeline;

  /// Add patient related record action label.
  ///
  /// In en, this message translates to:
  /// **'Add record'**
  String get patientsAddRelatedAction;

  /// Add patient related record dialog title.
  ///
  /// In en, this message translates to:
  /// **'Add patient record'**
  String get patientsAddRelatedTitle;

  /// Edit patient related record dialog title.
  ///
  /// In en, this message translates to:
  /// **'Edit patient record'**
  String get patientsEditRelatedTitle;

  /// Delete patient related record confirmation title.
  ///
  /// In en, this message translates to:
  /// **'Delete patient record'**
  String get patientsRelatedDeleteTitle;

  /// Delete patient related record confirmation body.
  ///
  /// In en, this message translates to:
  /// **'Delete this patient record?'**
  String get patientsRelatedDeleteBody;

  /// Patient contact type field label.
  ///
  /// In en, this message translates to:
  /// **'Contact type'**
  String get patientsContactTypeLabel;

  /// Patient contact value field label.
  ///
  /// In en, this message translates to:
  /// **'Contact value'**
  String get patientsContactValueLabel;

  /// Validation message for invalid patient contact values.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid contact value.'**
  String get patientsContactInvalidMessage;

  /// Patient primary related record checkbox label.
  ///
  /// In en, this message translates to:
  /// **'Primary record'**
  String get patientsPrimaryRecordLabel;

  /// Patient guardian name field label.
  ///
  /// In en, this message translates to:
  /// **'Guardian name'**
  String get patientsGuardianNameLabel;

  /// Patient guardian relationship field label.
  ///
  /// In en, this message translates to:
  /// **'Relationship'**
  String get patientsGuardianRelationshipLabel;

  /// Patient allergy allergen field label.
  ///
  /// In en, this message translates to:
  /// **'Allergen'**
  String get patientsAllergenLabel;

  /// Patient allergy severity field label.
  ///
  /// In en, this message translates to:
  /// **'Severity'**
  String get patientsSeverityLabel;

  /// Patient allergy reaction field label.
  ///
  /// In en, this message translates to:
  /// **'Reaction'**
  String get patientsReactionLabel;

  /// Patient notes field label.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get patientsNotesLabel;

  /// Patient medical history condition field label.
  ///
  /// In en, this message translates to:
  /// **'Condition'**
  String get patientsConditionLabel;

  /// Patient medical history diagnosis date field label.
  ///
  /// In en, this message translates to:
  /// **'Diagnosis date'**
  String get patientsDiagnosisDateLabel;

  /// Patient document type field label.
  ///
  /// In en, this message translates to:
  /// **'Document type'**
  String get patientsDocumentTypeLabel;

  /// Patient document storage key field label.
  ///
  /// In en, this message translates to:
  /// **'Storage key'**
  String get patientsStorageKeyLabel;

  /// Patient document advanced storage key field label.
  ///
  /// In en, this message translates to:
  /// **'Storage key (advanced)'**
  String get patientsStorageKeyAdvancedLabel;

  /// Helper text for patient document storage key.
  ///
  /// In en, this message translates to:
  /// **'Upload a file instead. Only enter this when referencing an existing stored document.'**
  String get patientsStorageKeyAdvancedHelper;

  /// Patient document upload panel title.
  ///
  /// In en, this message translates to:
  /// **'Document upload'**
  String get patientsDocumentUploadTitle;

  /// Patient document upload empty selection text.
  ///
  /// In en, this message translates to:
  /// **'No file selected. PDF, JPG, and PNG files up to 10 MB are supported.'**
  String get patientsDocumentUploadEmpty;

  /// Patient document file picker action label.
  ///
  /// In en, this message translates to:
  /// **'Choose file'**
  String get patientsChooseDocumentAction;

  /// Patient document file name field label.
  ///
  /// In en, this message translates to:
  /// **'File name'**
  String get patientsFileNameLabel;

  /// Patient document content type field label.
  ///
  /// In en, this message translates to:
  /// **'Content type'**
  String get patientsContentTypeLabel;

  /// Patient consent type field label.
  ///
  /// In en, this message translates to:
  /// **'Consent type'**
  String get patientsConsentTypeLabel;

  /// Patient consent status field label.
  ///
  /// In en, this message translates to:
  /// **'Consent status'**
  String get patientsConsentStatusLabel;

  /// Patient consent date field label.
  ///
  /// In en, this message translates to:
  /// **'Consent date'**
  String get patientsConsentDateLabel;

  /// Patient registration duplicate warning title.
  ///
  /// In en, this message translates to:
  /// **'Potential duplicate found'**
  String get patientsDuplicateWarningTitle;

  /// Patient registration duplicate warning body.
  ///
  /// In en, this message translates to:
  /// **'Review the matches before creating another patient record. Continue only when this is a different patient.'**
  String get patientsDuplicateWarningBody;

  /// Patient duplicate review dialog title.
  ///
  /// In en, this message translates to:
  /// **'Duplicate review'**
  String get patientsDuplicateReviewTitle;

  /// Patient duplicate review empty state title.
  ///
  /// In en, this message translates to:
  /// **'No duplicates to review'**
  String get patientsNoDuplicateReviewsTitle;

  /// Patient duplicate review empty state body.
  ///
  /// In en, this message translates to:
  /// **'Potential duplicate patient records will appear here.'**
  String get patientsNoDuplicateReviewsBody;

  /// Patient merge preview loading title.
  ///
  /// In en, this message translates to:
  /// **'Loading merge preview'**
  String get patientsMergePreviewLoadingTitle;

  /// Patient merge preview loading body.
  ///
  /// In en, this message translates to:
  /// **'Checking which records will move to the retained patient.'**
  String get patientsMergePreviewLoadingBody;

  /// Patient duplicate match score label.
  ///
  /// In en, this message translates to:
  /// **'{score}% match'**
  String patientsDuplicateScoreLabel(int score);

  /// Patient duplicate review merge preview action label.
  ///
  /// In en, this message translates to:
  /// **'Review merge'**
  String get patientsReviewMergeAction;

  /// Patient duplicate review dismiss action label.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get patientsDismissDuplicateAction;

  /// Patient duplicate merge preview title.
  ///
  /// In en, this message translates to:
  /// **'Merge preview'**
  String get patientsMergePreviewTitle;

  /// Patient merge transfer count badge label.
  ///
  /// In en, this message translates to:
  /// **'{resource}: {count}'**
  String patientsMergeTransferCountLabel(String resource, int count);

  /// Patient duplicate merge confirm action label.
  ///
  /// In en, this message translates to:
  /// **'Merge patients'**
  String get patientsMergePatientsAction;

  /// Patient registry activity section title.
  ///
  /// In en, this message translates to:
  /// **'Registry attention'**
  String get patientsActivityTitle;

  /// Patient registry activity section body.
  ///
  /// In en, this message translates to:
  /// **'Patient record issues that may need review.'**
  String get patientsActivityBody;

  /// Patient registry activity empty title.
  ///
  /// In en, this message translates to:
  /// **'No registry issues'**
  String get patientsActivityEmptyTitle;

  /// Patient registry activity empty body.
  ///
  /// In en, this message translates to:
  /// **'No duplicate, consent, or document alerts are visible.'**
  String get patientsActivityEmptyBody;

  /// Patient duplicate activity title.
  ///
  /// In en, this message translates to:
  /// **'Possible duplicate'**
  String get patientsDuplicateActivityTitle;

  /// Patient duplicate activity confidence subtitle.
  ///
  /// In en, this message translates to:
  /// **'{score}% match confidence'**
  String patientsDuplicateActivitySubtitle(int score);

  /// Patient consent activity title.
  ///
  /// In en, this message translates to:
  /// **'Consent review'**
  String get patientsConsentActivityTitle;

  /// Patient consent activity count subtitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 consent needs review} other{{count} consents need review}}'**
  String patientsConsentActivitySubtitle(int count);

  /// Patient missing documents activity title.
  ///
  /// In en, this message translates to:
  /// **'Missing documents'**
  String get patientsDocumentsActivityTitle;

  /// Patient missing documents activity count subtitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 patient has no documents} other{{count} patients have no documents}}'**
  String patientsDocumentsActivitySubtitle(int count);

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

  /// User profile screen title.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// User profile screen intro body.
  ///
  /// In en, this message translates to:
  /// **'Review your account, role, and facility details.'**
  String get profileBody;

  /// User profile account section title.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get profileAccountSectionTitle;

  /// User profile account section body.
  ///
  /// In en, this message translates to:
  /// **'Core identity and login information.'**
  String get profileAccountSectionBody;

  /// User profile professional details section title.
  ///
  /// In en, this message translates to:
  /// **'Professional details'**
  String get profileProfessionalSectionTitle;

  /// User profile professional details section body.
  ///
  /// In en, this message translates to:
  /// **'Role, title, user type, and facility context.'**
  String get profileProfessionalSectionBody;

  /// User profile name field label.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get profileNameLabel;

  /// User profile email field label.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get profileEmailLabel;

  /// User profile phone field label.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get profilePhoneLabel;

  /// User profile status field label.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get profileStatusLabel;

  /// User profile professional title field label.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get profileTitleLabel;

  /// User profile overall role field label.
  ///
  /// In en, this message translates to:
  /// **'Overall role'**
  String get profileOverallRoleLabel;

  /// User profile user type field label.
  ///
  /// In en, this message translates to:
  /// **'User type'**
  String get profileUserTypeLabel;

  /// User profile tenant field label.
  ///
  /// In en, this message translates to:
  /// **'Tenant'**
  String get profileTenantLabel;

  /// User profile facility field label.
  ///
  /// In en, this message translates to:
  /// **'Facility'**
  String get profileFacilityLabel;

  /// User profile facility type field label.
  ///
  /// In en, this message translates to:
  /// **'Facility type'**
  String get profileFacilityTypeLabel;

  /// User profile staff number field label.
  ///
  /// In en, this message translates to:
  /// **'Staff number'**
  String get profileStaffNumberLabel;

  /// User profile user identifier field label.
  ///
  /// In en, this message translates to:
  /// **'User ID'**
  String get profileUserIdLabel;

  /// User profile direct permission count label.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No direct permissions} =1{1 direct permission} other{{count} direct permissions}}'**
  String profilePermissionCountLabel(int count);

  /// Profile screen title when session profile data is missing.
  ///
  /// In en, this message translates to:
  /// **'Profile unavailable'**
  String get profileUnavailableTitle;

  /// Profile screen body when session profile data is missing.
  ///
  /// In en, this message translates to:
  /// **'Sign in again to reload your account details.'**
  String get profileUnavailableBody;

  /// Fallback value for unavailable profile fields.
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get profileUnknownValue;

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

  /// Settings section title for personal app preferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get settingsPreferencesSectionTitle;

  /// Settings section body for personal app preferences.
  ///
  /// In en, this message translates to:
  /// **'Theme, language, and local display choices.'**
  String get settingsPreferencesSectionBody;

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

  /// Settings section title for account and security entry points.
  ///
  /// In en, this message translates to:
  /// **'Account and security'**
  String get settingsAccountSectionTitle;

  /// Settings section body for account and security entry points.
  ///
  /// In en, this message translates to:
  /// **'Profile and sign-in controls stay with the user account.'**
  String get settingsAccountSectionBody;

  /// Settings action title for opening the user profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get settingsProfileActionTitle;

  /// Settings action body for opening the user profile.
  ///
  /// In en, this message translates to:
  /// **'Review identity, role, and facility context.'**
  String get settingsProfileActionBody;

  /// Settings action title for opening change password.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get settingsChangePasswordActionTitle;

  /// Settings action body for opening change password.
  ///
  /// In en, this message translates to:
  /// **'Update your password and restart the session.'**
  String get settingsChangePasswordActionBody;

  /// Settings section title for admin settings boundaries.
  ///
  /// In en, this message translates to:
  /// **'Administration boundaries'**
  String get settingsAdministrationSectionTitle;

  /// Settings section body for admin settings boundaries.
  ///
  /// In en, this message translates to:
  /// **'Workspace administration stays in dedicated modules.'**
  String get settingsAdministrationSectionBody;

  /// Boundary label for tenant administration.
  ///
  /// In en, this message translates to:
  /// **'Tenant settings'**
  String get settingsTenantBoundaryLabel;

  /// Boundary label for facility administration.
  ///
  /// In en, this message translates to:
  /// **'Facility settings'**
  String get settingsFacilityBoundaryLabel;

  /// Boundary label for user and security administration.
  ///
  /// In en, this message translates to:
  /// **'User and security settings'**
  String get settingsSecurityBoundaryLabel;

  /// Settings action body for security administration entry point.
  ///
  /// In en, this message translates to:
  /// **'Review administrator access before opening user management.'**
  String get settingsSecurityBoundaryBody;

  /// Settings action title for opening tenant and facility setup.
  ///
  /// In en, this message translates to:
  /// **'Tenant and facility setup'**
  String get settingsTenantFacilitySetupActionTitle;

  /// Settings action body for opening tenant and facility setup.
  ///
  /// In en, this message translates to:
  /// **'Configure organization identity, facility profile, departments, units, and physical locations.'**
  String get settingsTenantFacilitySetupActionBody;

  /// Tenant and facility setup screen title.
  ///
  /// In en, this message translates to:
  /// **'Tenant and facility setup'**
  String get tenantFacilitySetupTitle;

  /// Tenant and facility setup screen body.
  ///
  /// In en, this message translates to:
  /// **'Prepare the organization and facility before daily hospital operations begin.'**
  String get tenantFacilitySetupBody;

  /// Title while tenant and facility setup loads.
  ///
  /// In en, this message translates to:
  /// **'Loading setup'**
  String get tenantFacilitySetupLoadingTitle;

  /// Body while tenant and facility setup loads.
  ///
  /// In en, this message translates to:
  /// **'Loading organization and facility configuration.'**
  String get tenantFacilitySetupLoadingBody;

  /// Configured setup summary status label.
  ///
  /// In en, this message translates to:
  /// **'Configured'**
  String get tenantFacilitySummaryConfigured;

  /// Incomplete setup summary status label.
  ///
  /// In en, this message translates to:
  /// **'Needs setup'**
  String get tenantFacilitySummaryNeedsSetup;

  /// Tenant setup summary detail when no tenant is configured.
  ///
  /// In en, this message translates to:
  /// **'No tenant profile'**
  String get tenantFacilitySummaryNoTenant;

  /// Facility setup summary detail when no facility is selected.
  ///
  /// In en, this message translates to:
  /// **'No facility selected'**
  String get tenantFacilitySummaryNoFacility;

  /// Generic setup record count summary.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No records} =1{1 record} other{{count} records}}'**
  String tenantFacilitySummaryRecordCount(int count);

  /// Department and unit count summary.
  ///
  /// In en, this message translates to:
  /// **'{departments, plural, =0{No departments} =1{1 department} other{{departments} departments}}, {units, plural, =0{no units} =1{1 unit} other{{units} units}}'**
  String tenantFacilitySummaryDepartmentUnitCount(int departments, int units);

  /// Ward room and bed count summary.
  ///
  /// In en, this message translates to:
  /// **'{wards, plural, =0{No wards} =1{1 ward} other{{wards} wards}}, {rooms, plural, =0{no rooms} =1{1 room} other{{rooms} rooms}}, {beds, plural, =0{no beds} =1{1 bed} other{{beds} beds}}'**
  String tenantFacilitySummaryLocationCount(int wards, int rooms, int beds);

  /// Setup checklist section title.
  ///
  /// In en, this message translates to:
  /// **'First-run checklist'**
  String get tenantFacilityChecklistTitle;

  /// Setup checklist completion summary.
  ///
  /// In en, this message translates to:
  /// **'{completed} of {total} setup areas complete.'**
  String tenantFacilityChecklistBody(int completed, int total);

  /// Checklist item for tenant profile.
  ///
  /// In en, this message translates to:
  /// **'Tenant profile is configured'**
  String get tenantFacilityChecklistTenant;

  /// Checklist item for facility identity.
  ///
  /// In en, this message translates to:
  /// **'Facility identity and contacts are configured'**
  String get tenantFacilityChecklistIdentity;

  /// Checklist item for departments and units.
  ///
  /// In en, this message translates to:
  /// **'Departments and units are configured'**
  String get tenantFacilityChecklistDepartments;

  /// Checklist item for physical locations.
  ///
  /// In en, this message translates to:
  /// **'Rooms, wards, or beds are configured'**
  String get tenantFacilityChecklistLocations;

  /// Permission summary section title.
  ///
  /// In en, this message translates to:
  /// **'Permission gates'**
  String get tenantFacilityPermissionsTitle;

  /// Permission summary section body.
  ///
  /// In en, this message translates to:
  /// **'Write actions require tenant or facility administrator permissions.'**
  String get tenantFacilityPermissionsBody;

  /// Tenant admin permission label.
  ///
  /// In en, this message translates to:
  /// **'Tenant administrator'**
  String get tenantFacilityTenantAdminPermission;

  /// Facility admin permission label.
  ///
  /// In en, this message translates to:
  /// **'Facility administrator'**
  String get tenantFacilityFacilityAdminPermission;

  /// Allowed permission status label.
  ///
  /// In en, this message translates to:
  /// **'Allowed'**
  String get tenantFacilityPermissionAllowed;

  /// Denied permission status label.
  ///
  /// In en, this message translates to:
  /// **'Denied'**
  String get tenantFacilityPermissionDenied;

  /// Message shown when a setup action is disabled by permissions.
  ///
  /// In en, this message translates to:
  /// **'Administrator permission is required for this action.'**
  String get tenantFacilityPermissionRequired;

  /// Tenant profile form section title.
  ///
  /// In en, this message translates to:
  /// **'Tenant profile'**
  String get tenantFacilityTenantSectionTitle;

  /// Tenant profile form section body.
  ///
  /// In en, this message translates to:
  /// **'Organization details shared across facilities.'**
  String get tenantFacilityTenantSectionBody;

  /// Tenant name field label.
  ///
  /// In en, this message translates to:
  /// **'Tenant name'**
  String get tenantFacilityTenantNameLabel;

  /// Tenant slug field label.
  ///
  /// In en, this message translates to:
  /// **'Tenant slug'**
  String get tenantFacilityTenantSlugLabel;

  /// Active status switch label.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get tenantFacilityActiveLabel;

  /// Save tenant button label.
  ///
  /// In en, this message translates to:
  /// **'Save tenant'**
  String get tenantFacilitySaveTenantAction;

  /// Facility profile form section title.
  ///
  /// In en, this message translates to:
  /// **'Facility profile'**
  String get tenantFacilityFacilitySectionTitle;

  /// Facility profile form section body.
  ///
  /// In en, this message translates to:
  /// **'Facility name, logo reference, contact details, address, type, and active state.'**
  String get tenantFacilityFacilitySectionBody;

  /// Facility logo URL field label.
  ///
  /// In en, this message translates to:
  /// **'Logo storage URL'**
  String get tenantFacilityLogoUrlLabel;

  /// Facility logo URL helper text.
  ///
  /// In en, this message translates to:
  /// **'Use a URL created by the approved storage service.'**
  String get tenantFacilityLogoUrlHelper;

  /// Facility address line field label.
  ///
  /// In en, this message translates to:
  /// **'Address line'**
  String get tenantFacilityAddressLineLabel;

  /// Facility city field label.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get tenantFacilityCityLabel;

  /// Facility country field label.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get tenantFacilityCountryLabel;

  /// Save facility button label.
  ///
  /// In en, this message translates to:
  /// **'Save facility'**
  String get tenantFacilitySaveFacilityAction;

  /// Searchable facility selector label.
  ///
  /// In en, this message translates to:
  /// **'Facility'**
  String get tenantFacilityFacilitySelectLabel;

  /// Create setup record button label.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get tenantFacilityCreateAction;

  /// Save setup record button label.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get tenantFacilitySaveAction;

  /// Edit setup record action label.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get tenantFacilityEditAction;

  /// Delete setup record action label.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get tenantFacilityDeleteAction;

  /// Confirm delete setup record button label.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get tenantFacilityDeleteConfirmAction;

  /// Setup record deletion confirmation title.
  ///
  /// In en, this message translates to:
  /// **'Delete record'**
  String get tenantFacilityDeleteConfirmationTitle;

  /// Setup record deletion confirmation body.
  ///
  /// In en, this message translates to:
  /// **'This setup record will be removed.'**
  String get tenantFacilityDeleteConfirmationBody;

  /// Optional select empty value label.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get tenantFacilityNoSelectionLabel;

  /// Generic setup modal search field label.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get tenantFacilitySearchLabel;

  /// Clear setup modal search field action label.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get tenantFacilityClearSearchAction;

  /// Setup modal empty state when a search has no matching rows.
  ///
  /// In en, this message translates to:
  /// **'No matching records found.'**
  String get tenantFacilitySearchNoResults;

  /// Active status label.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get tenantFacilityStatusActive;

  /// Inactive status label.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get tenantFacilityStatusInactive;

  /// Branches setup section title.
  ///
  /// In en, this message translates to:
  /// **'Branches'**
  String get tenantFacilityBranchesSectionTitle;

  /// Branches setup section body.
  ///
  /// In en, this message translates to:
  /// **'Add branch entry points for facilities that operate across sites.'**
  String get tenantFacilityBranchesSectionBody;

  /// Empty branch list label.
  ///
  /// In en, this message translates to:
  /// **'No branches have been added.'**
  String get tenantFacilityNoBranches;

  /// Branch name field label.
  ///
  /// In en, this message translates to:
  /// **'Branch name'**
  String get tenantFacilityBranchNameLabel;

  /// Branches list subheading.
  ///
  /// In en, this message translates to:
  /// **'Branch records'**
  String get tenantFacilityBranchesListTitle;

  /// Branches modal search field hint.
  ///
  /// In en, this message translates to:
  /// **'Search branches by name or status'**
  String get tenantFacilityBranchSearchHint;

  /// Add branch button label.
  ///
  /// In en, this message translates to:
  /// **'Add branch'**
  String get tenantFacilityAddBranchAction;

  /// Add branch modal title.
  ///
  /// In en, this message translates to:
  /// **'Add branch'**
  String get tenantFacilityAddBranchTitle;

  /// Edit branch modal title.
  ///
  /// In en, this message translates to:
  /// **'Edit branch'**
  String get tenantFacilityEditBranchTitle;

  /// Departments and units setup section title.
  ///
  /// In en, this message translates to:
  /// **'Departments and units'**
  String get tenantFacilityDepartmentsSectionTitle;

  /// Departments and units setup section body.
  ///
  /// In en, this message translates to:
  /// **'Create departments first, then add units under the facility.'**
  String get tenantFacilityDepartmentsSectionBody;

  /// Empty department list label.
  ///
  /// In en, this message translates to:
  /// **'No departments have been added.'**
  String get tenantFacilityNoDepartments;

  /// Empty unit list label.
  ///
  /// In en, this message translates to:
  /// **'No units have been added.'**
  String get tenantFacilityNoUnits;

  /// Departments list subheading.
  ///
  /// In en, this message translates to:
  /// **'Departments'**
  String get tenantFacilityDepartmentsListTitle;

  /// Departments modal body.
  ///
  /// In en, this message translates to:
  /// **'Manage department records for the selected facility.'**
  String get tenantFacilityDepartmentsModalBody;

  /// Departments modal search field hint.
  ///
  /// In en, this message translates to:
  /// **'Search departments by name, type, branch, or status'**
  String get tenantFacilityDepartmentSearchHint;

  /// Units list subheading.
  ///
  /// In en, this message translates to:
  /// **'Units'**
  String get tenantFacilityUnitsListTitle;

  /// Units modal body.
  ///
  /// In en, this message translates to:
  /// **'Manage units under facility departments.'**
  String get tenantFacilityUnitsModalBody;

  /// Units modal search field hint.
  ///
  /// In en, this message translates to:
  /// **'Search units by name, department, or status'**
  String get tenantFacilityUnitSearchHint;

  /// Department name field label.
  ///
  /// In en, this message translates to:
  /// **'Department name'**
  String get tenantFacilityDepartmentNameLabel;

  /// Department short name field label.
  ///
  /// In en, this message translates to:
  /// **'Short name'**
  String get tenantFacilityDepartmentShortNameLabel;

  /// Department type field label.
  ///
  /// In en, this message translates to:
  /// **'Department type'**
  String get tenantFacilityDepartmentTypeLabel;

  /// Department branch selection field label.
  ///
  /// In en, this message translates to:
  /// **'Branch'**
  String get tenantFacilityDepartmentBranchLabel;

  /// Clinical department type label.
  ///
  /// In en, this message translates to:
  /// **'Clinical'**
  String get tenantFacilityDepartmentTypeClinical;

  /// Administrative department type label.
  ///
  /// In en, this message translates to:
  /// **'Administrative'**
  String get tenantFacilityDepartmentTypeAdministrative;

  /// Support department type label.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get tenantFacilityDepartmentTypeSupport;

  /// Diagnostics department type label.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get tenantFacilityDepartmentTypeDiagnostics;

  /// Other department type label.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get tenantFacilityDepartmentTypeOther;

  /// Add department button label.
  ///
  /// In en, this message translates to:
  /// **'Add department'**
  String get tenantFacilityAddDepartmentAction;

  /// Add department modal title.
  ///
  /// In en, this message translates to:
  /// **'Add department'**
  String get tenantFacilityAddDepartmentTitle;

  /// Edit department modal title.
  ///
  /// In en, this message translates to:
  /// **'Edit department'**
  String get tenantFacilityEditDepartmentTitle;

  /// Unit name field label.
  ///
  /// In en, this message translates to:
  /// **'Unit name'**
  String get tenantFacilityUnitNameLabel;

  /// Unit department selection field label.
  ///
  /// In en, this message translates to:
  /// **'Department'**
  String get tenantFacilityUnitDepartmentLabel;

  /// Add unit button label.
  ///
  /// In en, this message translates to:
  /// **'Add unit'**
  String get tenantFacilityAddUnitAction;

  /// Add unit modal title.
  ///
  /// In en, this message translates to:
  /// **'Add unit'**
  String get tenantFacilityAddUnitTitle;

  /// Edit unit modal title.
  ///
  /// In en, this message translates to:
  /// **'Edit unit'**
  String get tenantFacilityEditUnitTitle;

  /// Rooms wards and beds section title.
  ///
  /// In en, this message translates to:
  /// **'Rooms, wards, and beds'**
  String get tenantFacilityLocationsSectionTitle;

  /// Rooms wards and beds section body.
  ///
  /// In en, this message translates to:
  /// **'Use the location setup entry points after facility identity and departments are in place.'**
  String get tenantFacilityLocationsSectionBody;

  /// Rooms count label.
  ///
  /// In en, this message translates to:
  /// **'Rooms'**
  String get tenantFacilityRoomsLabel;

  /// Wards count label.
  ///
  /// In en, this message translates to:
  /// **'Wards'**
  String get tenantFacilityWardsLabel;

  /// Beds count label.
  ///
  /// In en, this message translates to:
  /// **'Beds'**
  String get tenantFacilityBedsLabel;

  /// Empty ward list label.
  ///
  /// In en, this message translates to:
  /// **'No wards have been added.'**
  String get tenantFacilityNoWards;

  /// Wards modal body.
  ///
  /// In en, this message translates to:
  /// **'Manage ward records and department assignments.'**
  String get tenantFacilityWardsModalBody;

  /// Wards modal search field hint.
  ///
  /// In en, this message translates to:
  /// **'Search wards by name, type, department, or status'**
  String get tenantFacilityWardSearchHint;

  /// Empty room list label.
  ///
  /// In en, this message translates to:
  /// **'No rooms have been added.'**
  String get tenantFacilityNoRooms;

  /// Rooms modal body.
  ///
  /// In en, this message translates to:
  /// **'Manage rooms and their ward assignments.'**
  String get tenantFacilityRoomsModalBody;

  /// Rooms modal search field hint.
  ///
  /// In en, this message translates to:
  /// **'Search rooms by name, ward, floor, or status'**
  String get tenantFacilityRoomSearchHint;

  /// Empty bed list label.
  ///
  /// In en, this message translates to:
  /// **'No beds have been added.'**
  String get tenantFacilityNoBeds;

  /// Beds modal body.
  ///
  /// In en, this message translates to:
  /// **'Manage bed labels, room links, and availability status.'**
  String get tenantFacilityBedsModalBody;

  /// Beds modal search field hint.
  ///
  /// In en, this message translates to:
  /// **'Search beds by label, ward, room, or status'**
  String get tenantFacilityBedSearchHint;

  /// Add ward button label.
  ///
  /// In en, this message translates to:
  /// **'Add ward'**
  String get tenantFacilityAddWardAction;

  /// Add ward modal title.
  ///
  /// In en, this message translates to:
  /// **'Add ward'**
  String get tenantFacilityAddWardTitle;

  /// Edit ward modal title.
  ///
  /// In en, this message translates to:
  /// **'Edit ward'**
  String get tenantFacilityEditWardTitle;

  /// Ward name field label.
  ///
  /// In en, this message translates to:
  /// **'Ward name'**
  String get tenantFacilityWardNameLabel;

  /// Ward type field label.
  ///
  /// In en, this message translates to:
  /// **'Ward type'**
  String get tenantFacilityWardTypeLabel;

  /// Ward department selection field label.
  ///
  /// In en, this message translates to:
  /// **'Department'**
  String get tenantFacilityWardDepartmentLabel;

  /// General ward type label.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get tenantFacilityWardTypeGeneral;

  /// ICU ward type label.
  ///
  /// In en, this message translates to:
  /// **'ICU'**
  String get tenantFacilityWardTypeIcu;

  /// Maternity ward type label.
  ///
  /// In en, this message translates to:
  /// **'Maternity'**
  String get tenantFacilityWardTypeMaternity;

  /// Pediatric ward type label.
  ///
  /// In en, this message translates to:
  /// **'Pediatric'**
  String get tenantFacilityWardTypePediatric;

  /// Surgical ward type label.
  ///
  /// In en, this message translates to:
  /// **'Surgical'**
  String get tenantFacilityWardTypeSurgical;

  /// Other ward type label.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get tenantFacilityWardTypeOther;

  /// Add room button label.
  ///
  /// In en, this message translates to:
  /// **'Add room'**
  String get tenantFacilityAddRoomAction;

  /// Add room modal title.
  ///
  /// In en, this message translates to:
  /// **'Add room'**
  String get tenantFacilityAddRoomTitle;

  /// Edit room modal title.
  ///
  /// In en, this message translates to:
  /// **'Edit room'**
  String get tenantFacilityEditRoomTitle;

  /// Room name field label.
  ///
  /// In en, this message translates to:
  /// **'Room name'**
  String get tenantFacilityRoomNameLabel;

  /// Room ward selection field label.
  ///
  /// In en, this message translates to:
  /// **'Ward'**
  String get tenantFacilityRoomWardLabel;

  /// Room floor field label.
  ///
  /// In en, this message translates to:
  /// **'Floor'**
  String get tenantFacilityRoomFloorLabel;

  /// Add bed button label.
  ///
  /// In en, this message translates to:
  /// **'Add bed'**
  String get tenantFacilityAddBedAction;

  /// Add bed modal title.
  ///
  /// In en, this message translates to:
  /// **'Add bed'**
  String get tenantFacilityAddBedTitle;

  /// Edit bed modal title.
  ///
  /// In en, this message translates to:
  /// **'Edit bed'**
  String get tenantFacilityEditBedTitle;

  /// Bed label field label.
  ///
  /// In en, this message translates to:
  /// **'Bed label'**
  String get tenantFacilityBedLabelLabel;

  /// Bed ward selection field label.
  ///
  /// In en, this message translates to:
  /// **'Ward'**
  String get tenantFacilityBedWardLabel;

  /// Bed room selection field label.
  ///
  /// In en, this message translates to:
  /// **'Room'**
  String get tenantFacilityBedRoomLabel;

  /// Bed status field label.
  ///
  /// In en, this message translates to:
  /// **'Bed status'**
  String get tenantFacilityBedStatusLabel;

  /// Available bed status label.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get tenantFacilityBedStatusAvailable;

  /// Occupied bed status label.
  ///
  /// In en, this message translates to:
  /// **'Occupied'**
  String get tenantFacilityBedStatusOccupied;

  /// Reserved bed status label.
  ///
  /// In en, this message translates to:
  /// **'Reserved'**
  String get tenantFacilityBedStatusReserved;

  /// Out of service bed status label.
  ///
  /// In en, this message translates to:
  /// **'Out of service'**
  String get tenantFacilityBedStatusOutOfService;

  /// Snackbar shown after setup changes are saved.
  ///
  /// In en, this message translates to:
  /// **'Setup changes saved.'**
  String get tenantFacilitySavedMessage;

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
  /// **'Verify'**
  String get authVerifyEmailActionLabel;

  /// Resend email verification code action label.
  ///
  /// In en, this message translates to:
  /// **'Send new code'**
  String get authSendNewCodeActionLabel;

  /// Email verification page title before verification succeeds.
  ///
  /// In en, this message translates to:
  /// **'Verify your email'**
  String get authVerifyEmailTitle;

  /// Email verification page title after verification succeeds.
  ///
  /// In en, this message translates to:
  /// **'Email verified'**
  String get authEmailVerifiedTitle;

  /// Email verification page body with target email.
  ///
  /// In en, this message translates to:
  /// **'Enter the verification code sent to {email}.'**
  String authVerifyEmailBody(String email);

  /// Email verification page body after login is attempted with an unverified registered email.
  ///
  /// In en, this message translates to:
  /// **'This email is already registered but has not been verified. Enter the verification code sent to {email}.'**
  String authPendingVerificationBody(String email);

  /// Email verification page body when no email is available.
  ///
  /// In en, this message translates to:
  /// **'Enter the verification code sent to your email.'**
  String get authVerifyEmailBodyNoEmail;

  /// Email verification success body.
  ///
  /// In en, this message translates to:
  /// **'Your account is verified. You can now sign in.'**
  String get authEmailVerifiedBody;

  /// Message shown after requesting a fresh email verification code.
  ///
  /// In en, this message translates to:
  /// **'A new verification code has been sent.'**
  String get authVerificationCodeResentMessage;

  /// Email verification code input label.
  ///
  /// In en, this message translates to:
  /// **'Verification code'**
  String get authVerificationCodeLabel;

  /// Email verification code validation error.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit verification code.'**
  String get authVerificationCodeInvalidMessage;

  /// Login failure message when an email account exists but has not been verified.
  ///
  /// In en, this message translates to:
  /// **'This email is already registered but has not been verified. Enter the email verification code we sent to continue.'**
  String get authAccountPendingMessage;

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
  /// **'We sent a verification code before the workspace can be used.'**
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

  /// Login failure message when the entered email or phone does not match an account.
  ///
  /// In en, this message translates to:
  /// **'No account exists for that email or phone. Check the details or create an account.'**
  String get authAccountNotFoundMessage;

  /// Login failure message when the account exists but the password is wrong.
  ///
  /// In en, this message translates to:
  /// **'The password is incorrect for this account.'**
  String get authWrongPasswordMessage;

  /// Auth failure message when the server temporarily rate limits repeated auth attempts.
  ///
  /// In en, this message translates to:
  /// **'Too many sign-in attempts. Please wait a moment and try again.'**
  String get authRateLimitedMessage;

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

  /// OPD form field label pattern for required fields.
  ///
  /// In en, this message translates to:
  /// **'{label} (required)'**
  String opdFieldRequiredLabel(String label);

  /// OPD form field label pattern for optional fields.
  ///
  /// In en, this message translates to:
  /// **'{label} (optional)'**
  String opdFieldOptionalLabel(String label);

  /// Instruction shown in the OPD vitals modal when individual vital fields are optional but one vital sign is required.
  ///
  /// In en, this message translates to:
  /// **'Enter at least one vital sign.'**
  String get opdVitalsAtLeastOneRequiredHelper;

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

  /// Navigation label for the clinical workspace.
  ///
  /// In en, this message translates to:
  /// **'Clinical'**
  String get navigationClinicalLabel;

  /// Clinical workspace page title.
  ///
  /// In en, this message translates to:
  /// **'Clinical workspace'**
  String get clinicalTitle;

  /// Clinical workspace page description.
  ///
  /// In en, this message translates to:
  /// **'Review clinical queues, document care, order services, prescribe, refer, admit, and complete encounters.'**
  String get clinicalDescription;

  /// Clinical workspace loading title.
  ///
  /// In en, this message translates to:
  /// **'Loading clinical workspace'**
  String get clinicalLoadingTitle;

  /// Clinical workspace loading body.
  ///
  /// In en, this message translates to:
  /// **'Loading provider worklist and encounter context.'**
  String get clinicalLoadingBody;

  /// Clinical workspace live synchronization status.
  ///
  /// In en, this message translates to:
  /// **'Live sync'**
  String get clinicalLiveStatus;

  /// Clinical workspace saving status.
  ///
  /// In en, this message translates to:
  /// **'Saving'**
  String get clinicalSavingStatus;

  /// Clinical workspace successful save message.
  ///
  /// In en, this message translates to:
  /// **'Clinical changes saved.'**
  String get clinicalSavedMessage;

  /// Snackbar message after copying a clinical patient ID.
  ///
  /// In en, this message translates to:
  /// **'Patient ID copied.'**
  String get clinicalPatientIdCopiedMessage;

  /// Semantic label for clinical workspace filters.
  ///
  /// In en, this message translates to:
  /// **'Clinical filters'**
  String get clinicalFiltersLabel;

  /// Clinical worklist search field label.
  ///
  /// In en, this message translates to:
  /// **'Search clinical worklist'**
  String get clinicalSearchLabel;

  /// Clinical worklist search field hint.
  ///
  /// In en, this message translates to:
  /// **'Patient, encounter, queue, provider, or location'**
  String get clinicalSearchHint;

  /// Clinical queue scope filter label.
  ///
  /// In en, this message translates to:
  /// **'Queue scope'**
  String get clinicalScopeFilterLabel;

  /// Clinical queue scope label for all active clinical work.
  ///
  /// In en, this message translates to:
  /// **'All active work'**
  String get clinicalAllScopeLabel;

  /// Clinical queue scope label for today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get clinicalTodayScopeLabel;

  /// Clinical summary label for encounters waiting review.
  ///
  /// In en, this message translates to:
  /// **'Waiting review'**
  String get clinicalWaitingReviewSummaryLabel;

  /// Clinical summary label for urgent encounters.
  ///
  /// In en, this message translates to:
  /// **'Urgent'**
  String get clinicalUrgentSummaryLabel;

  /// Clinical summary label for encounters with results ready.
  ///
  /// In en, this message translates to:
  /// **'Results ready'**
  String get clinicalResultsReadySummaryLabel;

  /// Clinical summary label for encounters in consultation.
  ///
  /// In en, this message translates to:
  /// **'In consultation'**
  String get clinicalInConsultationSummaryLabel;

  /// Clinical summary label for completed encounters.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get clinicalCompletedSummaryLabel;

  /// Clinical provider worklist title.
  ///
  /// In en, this message translates to:
  /// **'Provider worklist'**
  String get clinicalWorklistTitle;

  /// Clinical provider worklist description.
  ///
  /// In en, this message translates to:
  /// **'Open consultations, admissions, triage handoffs, and result-review queues.'**
  String get clinicalWorklistDescription;

  /// Clinical empty worklist title.
  ///
  /// In en, this message translates to:
  /// **'No clinical work'**
  String get clinicalNoWorklistTitle;

  /// Clinical empty worklist body.
  ///
  /// In en, this message translates to:
  /// **'No encounters match the current search and queue scope.'**
  String get clinicalNoWorklistBody;

  /// Clinical no selection title.
  ///
  /// In en, this message translates to:
  /// **'No encounter selected'**
  String get clinicalNoSelectionTitle;

  /// Clinical no selection body.
  ///
  /// In en, this message translates to:
  /// **'Open a patient from the worklist to review context, document care, and place orders.'**
  String get clinicalNoSelectionBody;

  /// Clinical source queue label.
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get clinicalSourceQueueLabel;

  /// Clinical encounter queue label.
  ///
  /// In en, this message translates to:
  /// **'Encounter queue'**
  String get clinicalEncounterQueueLabel;

  /// Clinical worklist last updated column label.
  ///
  /// In en, this message translates to:
  /// **'Last updated'**
  String get clinicalLastUpdatedLabel;

  /// Clinical encounter number label.
  ///
  /// In en, this message translates to:
  /// **'Encounter'**
  String get clinicalEncounterNumberLabel;

  /// Clinical admission number label.
  ///
  /// In en, this message translates to:
  /// **'Admission'**
  String get clinicalAdmissionNumberLabel;

  /// Clinical encounter type label.
  ///
  /// In en, this message translates to:
  /// **'Encounter type'**
  String get clinicalEncounterTypeLabel;

  /// Clinical patient age label.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get clinicalAgeLabel;

  /// Clinical location label.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get clinicalLocationLabel;

  /// Clinical actions panel title.
  ///
  /// In en, this message translates to:
  /// **'Clinical actions'**
  String get clinicalActionsTitle;

  /// Clinical add note action label.
  ///
  /// In en, this message translates to:
  /// **'Add note'**
  String get clinicalAddNoteAction;

  /// Clinical add note dialog title.
  ///
  /// In en, this message translates to:
  /// **'Add patient clinical note'**
  String get clinicalAddNoteTitle;

  /// Clinical add diagnosis action label.
  ///
  /// In en, this message translates to:
  /// **'Add diagnosis'**
  String get clinicalAddDiagnosisAction;

  /// Clinical request lab action label.
  ///
  /// In en, this message translates to:
  /// **'Request lab'**
  String get clinicalRequestLabAction;

  /// Clinical update lab order action label.
  ///
  /// In en, this message translates to:
  /// **'Update lab order'**
  String get clinicalUpdateLabOrderAction;

  /// Clinical lab request selector mode for individual tests.
  ///
  /// In en, this message translates to:
  /// **'Individual tests'**
  String get clinicalLabRequestTestsModeLabel;

  /// Clinical lab request selector mode for lab panels.
  ///
  /// In en, this message translates to:
  /// **'Lab panels'**
  String get clinicalLabRequestPanelsModeLabel;

  /// Clinical lab request catalog search field label.
  ///
  /// In en, this message translates to:
  /// **'Search lab catalog'**
  String get clinicalLabRequestSearchLabel;

  /// Clinical lab request catalog search field hint.
  ///
  /// In en, this message translates to:
  /// **'Search by name, code, category, specimen, or status'**
  String get clinicalLabRequestSearchHint;

  /// Clinical lab request selected items section title.
  ///
  /// In en, this message translates to:
  /// **'Selected lab requests'**
  String get clinicalLabRequestSelectedTitle;

  /// Clinical lab request selected item count.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String clinicalLabRequestSelectedCount(int count);

  /// Clinical lab request empty selected items message.
  ///
  /// In en, this message translates to:
  /// **'No lab requests selected'**
  String get clinicalLabRequestNoSelection;

  /// Clinical lab request add selected catalog item action.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get clinicalLabRequestAddSelectionAction;

  /// Clinical lab request update selected catalog item action.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get clinicalLabRequestUpdateSelectionAction;

  /// Clinical lab request cancel edit action.
  ///
  /// In en, this message translates to:
  /// **'Cancel edit'**
  String get clinicalLabRequestCancelEditAction;

  /// Clinical lab request edit selected item action.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get clinicalLabRequestEditSelectionAction;

  /// Clinical lab request delete selected item action.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get clinicalLabRequestDeleteSelectionAction;

  /// Clinical lab request selected item type label for tests.
  ///
  /// In en, this message translates to:
  /// **'Test'**
  String get clinicalLabRequestTestTypeLabel;

  /// Clinical lab request selected item type label for panels.
  ///
  /// In en, this message translates to:
  /// **'Panel'**
  String get clinicalLabRequestPanelTypeLabel;

  /// Clinical lab request search result count label.
  ///
  /// In en, this message translates to:
  /// **'Showing {shown} of {total} matches'**
  String clinicalLabRequestMatchesLabel(int shown, int total);

  /// Clinical lab request no matching search results message.
  ///
  /// In en, this message translates to:
  /// **'No matching lab catalog items'**
  String get clinicalLabRequestNoCatalogOptions;

  /// Clinical patient detail lab orders section title.
  ///
  /// In en, this message translates to:
  /// **'Lab orders'**
  String get clinicalLabOrdersTitle;

  /// Clinical patient detail lab orders section body.
  ///
  /// In en, this message translates to:
  /// **'Requested lab orders for this patient.'**
  String get clinicalLabOrdersBody;

  /// Clinical patient detail empty lab orders message.
  ///
  /// In en, this message translates to:
  /// **'No lab orders have been requested for this patient.'**
  String get clinicalNoLabOrdersLabel;

  /// Clinical lab order requested tests label.
  ///
  /// In en, this message translates to:
  /// **'Requested lab tests'**
  String get clinicalLabOrderTestsLabel;

  /// Clinical lab order requested panels label.
  ///
  /// In en, this message translates to:
  /// **'Requested lab panels'**
  String get clinicalLabOrderPanelsLabel;

  /// Clinical lab order no requested tests label.
  ///
  /// In en, this message translates to:
  /// **'No requested lab tests recorded.'**
  String get clinicalNoLabOrderTestsLabel;

  /// Clinical lab order no requested panels label.
  ///
  /// In en, this message translates to:
  /// **'No requested lab panels recorded.'**
  String get clinicalNoLabOrderPanelsLabel;

  /// Clinical lab order requested test count.
  ///
  /// In en, this message translates to:
  /// **'{count} tests'**
  String clinicalLabOrderItemCount(int count);

  /// Clinical lab order sample count.
  ///
  /// In en, this message translates to:
  /// **'{count} samples'**
  String clinicalLabOrderSampleCount(int count);

  /// Clinical edit lab order action label.
  ///
  /// In en, this message translates to:
  /// **'Edit order'**
  String get clinicalEditLabOrderAction;

  /// Clinical cancel lab order action label.
  ///
  /// In en, this message translates to:
  /// **'Cancel order'**
  String get clinicalCancelLabOrderAction;

  /// Clinical delete lab order action label.
  ///
  /// In en, this message translates to:
  /// **'Delete order'**
  String get clinicalDeleteLabOrderAction;

  /// Clinical cancel lab order confirmation title.
  ///
  /// In en, this message translates to:
  /// **'Cancel lab order'**
  String get clinicalCancelLabOrderDialogTitle;

  /// Clinical cancel lab order confirmation body.
  ///
  /// In en, this message translates to:
  /// **'Cancel this lab order and mark its requested tests as cancelled?'**
  String get clinicalCancelLabOrderDialogBody;

  /// Clinical delete lab order confirmation title.
  ///
  /// In en, this message translates to:
  /// **'Delete lab order'**
  String get clinicalDeleteLabOrderDialogTitle;

  /// Clinical delete lab order confirmation body.
  ///
  /// In en, this message translates to:
  /// **'Delete this lab order from the active patient record?'**
  String get clinicalDeleteLabOrderDialogBody;

  /// Clinical request radiology action label.
  ///
  /// In en, this message translates to:
  /// **'Request radiology'**
  String get clinicalRequestRadiologyAction;

  /// Clinical radiology request catalog search field label.
  ///
  /// In en, this message translates to:
  /// **'Search radiology catalog'**
  String get clinicalRadiologyRequestSearchLabel;

  /// Clinical radiology request catalog search field hint.
  ///
  /// In en, this message translates to:
  /// **'Search by test, intervention, modality, equipment, region, code, or priority'**
  String get clinicalRadiologyRequestSearchHint;

  /// Clinical radiology request selected items section title.
  ///
  /// In en, this message translates to:
  /// **'Selected radiology requests'**
  String get clinicalRadiologyRequestSelectedTitle;

  /// Clinical radiology request selected item count.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String clinicalRadiologyRequestSelectedCount(int count);

  /// Clinical radiology request empty selected items message.
  ///
  /// In en, this message translates to:
  /// **'No radiology requests selected'**
  String get clinicalRadiologyRequestNoSelection;

  /// Clinical radiology request add selected catalog item action.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get clinicalRadiologyAddSelectionAction;

  /// Clinical radiology request update selected catalog item action.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get clinicalRadiologyUpdateSelectionAction;

  /// Clinical radiology request cancel edit action.
  ///
  /// In en, this message translates to:
  /// **'Cancel edit'**
  String get clinicalRadiologyCancelEditAction;

  /// Clinical radiology request edit selected item action.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get clinicalRadiologyEditSelectionAction;

  /// Clinical radiology request delete selected item action.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get clinicalRadiologyDeleteSelectionAction;

  /// Clinical radiology request search result count label.
  ///
  /// In en, this message translates to:
  /// **'Showing {shown} of {total} matches'**
  String clinicalRadiologyRequestMatchesLabel(int shown, int total);

  /// Clinical radiology request no matching search results message.
  ///
  /// In en, this message translates to:
  /// **'No matching radiology catalog items'**
  String get clinicalRadiologyRequestNoCatalogOptions;

  /// Clinical radiology request priority field label.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get clinicalRadiologyPriorityLabel;

  /// Clinical radiology request laterality field label.
  ///
  /// In en, this message translates to:
  /// **'Laterality'**
  String get clinicalRadiologyLateralityLabel;

  /// Clinical radiology request body region field label.
  ///
  /// In en, this message translates to:
  /// **'Body region'**
  String get clinicalRadiologyBodyRegionLabel;

  /// Clinical prescribe action label.
  ///
  /// In en, this message translates to:
  /// **'Prescribe'**
  String get clinicalPrescribeAction;

  /// Clinical prescription dialog header title.
  ///
  /// In en, this message translates to:
  /// **'Build prescription'**
  String get clinicalPrescriptionHeaderTitle;

  /// Clinical prescription dialog header body.
  ///
  /// In en, this message translates to:
  /// **'Add one or more medicines, then send them together to pharmacy.'**
  String get clinicalPrescriptionHeaderBody;

  /// Clinical prescription available drug field label.
  ///
  /// In en, this message translates to:
  /// **'Available drug'**
  String get clinicalPrescriptionDrugLabel;

  /// Clinical prescription item title prefix.
  ///
  /// In en, this message translates to:
  /// **'Medicine'**
  String get clinicalPrescriptionMedicineLabel;

  /// Clinical prescription item helper text before a drug is selected.
  ///
  /// In en, this message translates to:
  /// **'Select a drug and complete the prescription details.'**
  String get clinicalPrescriptionItemDescription;

  /// Clinical prescription quantity unit field label.
  ///
  /// In en, this message translates to:
  /// **'Quantity unit'**
  String get clinicalPrescriptionQuantityUnitLabel;

  /// Clinical prescription add medicine button label.
  ///
  /// In en, this message translates to:
  /// **'Add medicine'**
  String get clinicalPrescriptionAddMedicineAction;

  /// Clinical prescription remove medicine button tooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove medicine'**
  String get clinicalPrescriptionRemoveMedicineAction;

  /// Clinical add procedure action label.
  ///
  /// In en, this message translates to:
  /// **'Add procedure'**
  String get clinicalRequestProcedureAction;

  /// Clinical procedure dialog helper text.
  ///
  /// In en, this message translates to:
  /// **'Search the procedure catalog, add one or more procedures to the review list, then save them together.'**
  String get clinicalProcedureDialogHelp;

  /// Clinical procedure searchable select label.
  ///
  /// In en, this message translates to:
  /// **'Procedure or minor surgery'**
  String get clinicalProcedureSearchLabel;

  /// Clinical procedure searchable select hint.
  ///
  /// In en, this message translates to:
  /// **'Search by name, body area, or minor surgery type'**
  String get clinicalProcedureSearchHint;

  /// Clinical procedure code searchable select hint.
  ///
  /// In en, this message translates to:
  /// **'Search by procedure code'**
  String get clinicalProcedureCodeSearchHint;

  /// Clinical procedure selected list title.
  ///
  /// In en, this message translates to:
  /// **'Selected procedures'**
  String get clinicalProcedureSelectedTitle;

  /// Clinical procedure selected item count.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String clinicalProcedureSelectedCount(int count);

  /// Clinical procedure empty selected items message.
  ///
  /// In en, this message translates to:
  /// **'No procedures selected'**
  String get clinicalProcedureNoSelection;

  /// Clinical care plan action label.
  ///
  /// In en, this message translates to:
  /// **'Care plan'**
  String get clinicalCarePlanAction;

  /// Clinical request admission action label.
  ///
  /// In en, this message translates to:
  /// **'Request admission'**
  String get clinicalRequestAdmissionAction;

  /// Clinical complete consultation action label.
  ///
  /// In en, this message translates to:
  /// **'Complete consultation'**
  String get clinicalCompleteConsultationAction;

  /// Clinical complete disposition action label.
  ///
  /// In en, this message translates to:
  /// **'Complete disposition'**
  String get clinicalCompleteDispositionAction;

  /// Clinical print summary action label.
  ///
  /// In en, this message translates to:
  /// **'Print summary'**
  String get clinicalPrintSummaryAction;

  /// Clinical result review panel title.
  ///
  /// In en, this message translates to:
  /// **'Result review'**
  String get clinicalResultReviewTitle;

  /// Clinical result review panel body.
  ///
  /// In en, this message translates to:
  /// **'Released diagnostic results are ready for clinical review.'**
  String get clinicalResultReviewBody;

  /// Clinical no results ready body.
  ///
  /// In en, this message translates to:
  /// **'No released lab or radiology results are ready for review.'**
  String get clinicalNoResultsReadyBody;

  /// Clinical patient notes section title.
  ///
  /// In en, this message translates to:
  /// **'Patient clinical notes'**
  String get clinicalPatientNotesTitle;

  /// Clinical patient notes empty state label.
  ///
  /// In en, this message translates to:
  /// **'No patient clinical notes have been recorded yet.'**
  String get clinicalNoPatientNotesLabel;

  /// Clinical diagnoses section title.
  ///
  /// In en, this message translates to:
  /// **'Diagnoses'**
  String get clinicalDiagnosesTitle;

  /// Clinical patient diagnoses section title.
  ///
  /// In en, this message translates to:
  /// **'Patient diagnoses'**
  String get clinicalPatientDiagnosesTitle;

  /// Clinical patient diagnoses empty state label.
  ///
  /// In en, this message translates to:
  /// **'No diagnoses have been recorded for this patient yet.'**
  String get clinicalNoPatientDiagnosesLabel;

  /// Clinical diagnosis dialog form section title.
  ///
  /// In en, this message translates to:
  /// **'Diagnosis details'**
  String get clinicalDiagnosisFormTitle;

  /// Clinical care plans section title.
  ///
  /// In en, this message translates to:
  /// **'Care plans'**
  String get clinicalCarePlansTitle;

  /// Clinical orders section title.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get clinicalOrdersTitle;

  /// Clinical handoffs section title.
  ///
  /// In en, this message translates to:
  /// **'Handoffs'**
  String get clinicalHandoffsTitle;

  /// Clinical term search field label.
  ///
  /// In en, this message translates to:
  /// **'Clinical term'**
  String get clinicalTermSearchLabel;

  /// Clinical care plan field label.
  ///
  /// In en, this message translates to:
  /// **'Care plan'**
  String get clinicalCarePlanLabel;

  /// Clinical prescription dose amount field label.
  ///
  /// In en, this message translates to:
  /// **'Dose amount'**
  String get clinicalDoseAmountLabel;

  /// Clinical prescription dose unit field label.
  ///
  /// In en, this message translates to:
  /// **'Dose unit'**
  String get clinicalDoseUnitLabel;

  /// Clinical prescription duration value field label.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get clinicalDurationValueLabel;

  /// Clinical prescription duration unit field label.
  ///
  /// In en, this message translates to:
  /// **'Duration unit'**
  String get clinicalDurationUnitLabel;

  /// Clinical prescription instructions field label.
  ///
  /// In en, this message translates to:
  /// **'Instructions'**
  String get clinicalInstructionsLabel;

  /// Clinical admission available bed field label.
  ///
  /// In en, this message translates to:
  /// **'Available bed'**
  String get clinicalAvailableBedLabel;

  /// Clinical admission details form section title.
  ///
  /// In en, this message translates to:
  /// **'Admission details'**
  String get clinicalAdmissionDetailsTitle;

  /// Clinical admission ward field label.
  ///
  /// In en, this message translates to:
  /// **'Ward'**
  String get clinicalAdmissionWardLabel;

  /// Clinical admission room field label.
  ///
  /// In en, this message translates to:
  /// **'Room'**
  String get clinicalAdmissionRoomLabel;

  /// Clinical admission bed field label.
  ///
  /// In en, this message translates to:
  /// **'Bed'**
  String get clinicalAdmissionBedLabel;

  /// Clinical admission bed availability field label.
  ///
  /// In en, this message translates to:
  /// **'Bed availability'**
  String get clinicalAdmissionAvailabilityLabel;

  /// Clinical admission empty-state title when no beds are available.
  ///
  /// In en, this message translates to:
  /// **'No available beds'**
  String get clinicalAdmissionNoBedsTitle;

  /// Clinical admission empty-state message when no beds are available.
  ///
  /// In en, this message translates to:
  /// **'No available beds found. Refresh bed availability before requesting admission.'**
  String get clinicalAdmissionNoBedsMessage;

  /// Clinical disposition reason field label.
  ///
  /// In en, this message translates to:
  /// **'Disposition reason'**
  String get clinicalDispositionReasonLabel;

  /// Clinical consultation summary print title.
  ///
  /// In en, this message translates to:
  /// **'Consultation summary'**
  String get clinicalConsultationSummaryTitle;

  /// Navigation label for the inpatient department workspace.
  ///
  /// In en, this message translates to:
  /// **'IPD'**
  String get navigationIpdLabel;

  /// Inpatient workspace page title.
  ///
  /// In en, this message translates to:
  /// **'Inpatient workspace'**
  String get ipdTitle;

  /// Inpatient workspace page description.
  ///
  /// In en, this message translates to:
  /// **'Manage admission queues, beds, transfers, ward rounds, nursing handoffs, medication records, and discharge readiness.'**
  String get ipdDescription;

  /// Inpatient workspace loading title.
  ///
  /// In en, this message translates to:
  /// **'Loading inpatient workspace'**
  String get ipdLoadingTitle;

  /// Inpatient workspace loading body.
  ///
  /// In en, this message translates to:
  /// **'Loading admissions, beds, and ward context.'**
  String get ipdLoadingBody;

  /// Inpatient workspace live synchronization status.
  ///
  /// In en, this message translates to:
  /// **'Live sync'**
  String get ipdLiveStatus;

  /// Inpatient workspace saving status.
  ///
  /// In en, this message translates to:
  /// **'Saving'**
  String get ipdSavingStatus;

  /// Inpatient workspace successful save message.
  ///
  /// In en, this message translates to:
  /// **'Inpatient changes saved.'**
  String get ipdSavedMessage;

  /// IPD summary label for admitted patients waiting for a bed.
  ///
  /// In en, this message translates to:
  /// **'Waiting bed'**
  String get ipdAdmissionQueueSummaryLabel;

  /// IPD summary label for active patients assigned to beds.
  ///
  /// In en, this message translates to:
  /// **'In beds'**
  String get ipdActivePatientsSummaryLabel;

  /// IPD summary label for pending or in-progress transfers.
  ///
  /// In en, this message translates to:
  /// **'Transfers'**
  String get ipdTransferPendingSummaryLabel;

  /// IPD summary label for admissions with discharge plans.
  ///
  /// In en, this message translates to:
  /// **'Discharge planned'**
  String get ipdDischargePlannedSummaryLabel;

  /// IPD summary label for active critical alerts.
  ///
  /// In en, this message translates to:
  /// **'Critical alerts'**
  String get ipdCriticalAlertsSummaryLabel;

  /// Semantic label for inpatient workspace filters.
  ///
  /// In en, this message translates to:
  /// **'Inpatient filters'**
  String get ipdFiltersLabel;

  /// IPD admission search field label.
  ///
  /// In en, this message translates to:
  /// **'Search admissions'**
  String get ipdSearchLabel;

  /// IPD admission search field hint.
  ///
  /// In en, this message translates to:
  /// **'Patient, admission, encounter, ward, or bed'**
  String get ipdSearchHint;

  /// IPD queue scope filter label.
  ///
  /// In en, this message translates to:
  /// **'Board scope'**
  String get ipdScopeFilterLabel;

  /// IPD ward filter label.
  ///
  /// In en, this message translates to:
  /// **'Ward'**
  String get ipdWardFilterLabel;

  /// IPD ward filter option for all wards.
  ///
  /// In en, this message translates to:
  /// **'All wards'**
  String get ipdAllWardsOption;

  /// IPD admissions board title.
  ///
  /// In en, this message translates to:
  /// **'Inpatient board'**
  String get ipdBoardTitle;

  /// IPD admissions board description.
  ///
  /// In en, this message translates to:
  /// **'Track waiting admissions, bedded patients, transfers, ward activity, and discharge plans.'**
  String get ipdBoardDescription;

  /// IPD admissions board empty title.
  ///
  /// In en, this message translates to:
  /// **'No admissions'**
  String get ipdNoAdmissionsTitle;

  /// IPD admissions board empty body.
  ///
  /// In en, this message translates to:
  /// **'No inpatient admissions match the current filters.'**
  String get ipdNoAdmissionsBody;

  /// IPD board column label for location.
  ///
  /// In en, this message translates to:
  /// **'Ward and bed'**
  String get ipdLocationColumnLabel;

  /// IPD board column label for pending action.
  ///
  /// In en, this message translates to:
  /// **'Next action'**
  String get ipdPendingActionColumnLabel;

  /// IPD board column label for admission date.
  ///
  /// In en, this message translates to:
  /// **'Admitted'**
  String get ipdAdmittedAtColumnLabel;

  /// IPD admission detail panel title.
  ///
  /// In en, this message translates to:
  /// **'Admission detail'**
  String get ipdAdmissionDetailTitle;

  /// IPD admission detail panel description.
  ///
  /// In en, this message translates to:
  /// **'Review bed status, transfers, ward rounds, medication records, nursing notes, and discharge state.'**
  String get ipdAdmissionDetailDescription;

  /// IPD no selection title.
  ///
  /// In en, this message translates to:
  /// **'No admission selected'**
  String get ipdNoSelectionTitle;

  /// IPD no selection body.
  ///
  /// In en, this message translates to:
  /// **'Open an admission from the board to manage inpatient care.'**
  String get ipdNoSelectionBody;

  /// IPD patient context heading label.
  ///
  /// In en, this message translates to:
  /// **'Patient context'**
  String get ipdPatientContextLabel;

  /// IPD admission identifier label.
  ///
  /// In en, this message translates to:
  /// **'Admission'**
  String get ipdAdmissionIdLabel;

  /// IPD encounter identifier label.
  ///
  /// In en, this message translates to:
  /// **'Encounter'**
  String get ipdEncounterIdLabel;

  /// IPD ward and bed label.
  ///
  /// In en, this message translates to:
  /// **'Ward and bed'**
  String get ipdWardBedLabel;

  /// IPD facility label.
  ///
  /// In en, this message translates to:
  /// **'Facility'**
  String get ipdFacilityLabel;

  /// IPD ICU status label.
  ///
  /// In en, this message translates to:
  /// **'ICU status'**
  String get ipdIcuStatusLabel;

  /// IPD action label to assign a bed.
  ///
  /// In en, this message translates to:
  /// **'Assign bed'**
  String get ipdAssignBedAction;

  /// IPD action label to release a bed.
  ///
  /// In en, this message translates to:
  /// **'Release bed'**
  String get ipdReleaseBedAction;

  /// IPD action label to reject an admission.
  ///
  /// In en, this message translates to:
  /// **'Reject admission'**
  String get ipdRejectAdmissionAction;

  /// IPD action label to request a transfer.
  ///
  /// In en, this message translates to:
  /// **'Request transfer'**
  String get ipdRequestTransferAction;

  /// IPD action label to update an open transfer.
  ///
  /// In en, this message translates to:
  /// **'Manage transfer'**
  String get ipdManageTransferAction;

  /// IPD action label to add a ward round.
  ///
  /// In en, this message translates to:
  /// **'Add ward round'**
  String get ipdAddWardRoundAction;

  /// IPD action label to add a nursing note.
  ///
  /// In en, this message translates to:
  /// **'Add nursing note'**
  String get ipdAddNursingNoteAction;

  /// IPD action label to record medication administration.
  ///
  /// In en, this message translates to:
  /// **'Record medication'**
  String get ipdRecordMedicationAction;

  /// IPD action label to plan discharge.
  ///
  /// In en, this message translates to:
  /// **'Plan discharge'**
  String get ipdPlanDischargeAction;

  /// IPD action label to finalize discharge.
  ///
  /// In en, this message translates to:
  /// **'Finalize discharge'**
  String get ipdFinalizeDischargeAction;

  /// IPD transfer section title.
  ///
  /// In en, this message translates to:
  /// **'Transfers'**
  String get ipdTransfersSectionTitle;

  /// IPD ward rounds section title.
  ///
  /// In en, this message translates to:
  /// **'Ward rounds'**
  String get ipdRoundsSectionTitle;

  /// IPD nursing notes section title.
  ///
  /// In en, this message translates to:
  /// **'Nursing notes'**
  String get ipdNursingSectionTitle;

  /// IPD medication section title.
  ///
  /// In en, this message translates to:
  /// **'Medication'**
  String get ipdMedicationSectionTitle;

  /// IPD bed allocation section title.
  ///
  /// In en, this message translates to:
  /// **'Bed allocation'**
  String get ipdBedSectionTitle;

  /// IPD discharge section title.
  ///
  /// In en, this message translates to:
  /// **'Discharge'**
  String get ipdDischargeSectionTitle;

  /// IPD timeline section title.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get ipdTimelineSectionTitle;

  /// IPD empty transfers title.
  ///
  /// In en, this message translates to:
  /// **'No transfers'**
  String get ipdNoTransfersTitle;

  /// IPD empty transfers body.
  ///
  /// In en, this message translates to:
  /// **'No transfer requests are recorded for this admission.'**
  String get ipdNoTransfersBody;

  /// IPD empty ward rounds title.
  ///
  /// In en, this message translates to:
  /// **'No ward rounds'**
  String get ipdNoRoundsTitle;

  /// IPD empty ward rounds body.
  ///
  /// In en, this message translates to:
  /// **'No ward rounds have been documented yet.'**
  String get ipdNoRoundsBody;

  /// IPD empty nursing notes title.
  ///
  /// In en, this message translates to:
  /// **'No nursing notes'**
  String get ipdNoNursingNotesTitle;

  /// IPD empty nursing notes body.
  ///
  /// In en, this message translates to:
  /// **'No nursing notes have been documented yet.'**
  String get ipdNoNursingNotesBody;

  /// IPD empty medication title.
  ///
  /// In en, this message translates to:
  /// **'No medication records'**
  String get ipdNoMedicationTitle;

  /// IPD empty medication body.
  ///
  /// In en, this message translates to:
  /// **'No medication administrations are recorded for this admission.'**
  String get ipdNoMedicationBody;

  /// IPD empty timeline title.
  ///
  /// In en, this message translates to:
  /// **'No timeline entries'**
  String get ipdNoTimelineTitle;

  /// IPD empty timeline body.
  ///
  /// In en, this message translates to:
  /// **'No care activity has been recorded yet.'**
  String get ipdNoTimelineBody;

  /// IPD bed selection field label.
  ///
  /// In en, this message translates to:
  /// **'Bed'**
  String get ipdBedFieldLabel;

  /// IPD bed selection field hint.
  ///
  /// In en, this message translates to:
  /// **'Select a bed'**
  String get ipdSelectBedHint;

  /// IPD release bed confirmation body.
  ///
  /// In en, this message translates to:
  /// **'Release the current bed assignment for this admission?'**
  String get ipdReleaseBedConfirmationBody;

  /// IPD transfer target ward field label.
  ///
  /// In en, this message translates to:
  /// **'Target ward'**
  String get ipdTargetWardFieldLabel;

  /// IPD ward selection field hint.
  ///
  /// In en, this message translates to:
  /// **'Select a ward'**
  String get ipdSelectWardHint;

  /// IPD transfer action field label.
  ///
  /// In en, this message translates to:
  /// **'Transfer action'**
  String get ipdTransferActionFieldLabel;

  /// IPD transfer destination bed field label.
  ///
  /// In en, this message translates to:
  /// **'Destination bed'**
  String get ipdDestinationBedFieldLabel;

  /// IPD notes field label.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get ipdNotesFieldLabel;

  /// IPD summary field label.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get ipdSummaryFieldLabel;

  /// IPD reason field label.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get ipdReasonFieldLabel;

  /// IPD medication order field label.
  ///
  /// In en, this message translates to:
  /// **'Medication order'**
  String get ipdMedicationOrderFieldLabel;

  /// IPD medication order selection hint.
  ///
  /// In en, this message translates to:
  /// **'Select a suggested order'**
  String get ipdMedicationOrderHint;

  /// IPD medication field label.
  ///
  /// In en, this message translates to:
  /// **'Medication'**
  String get ipdMedicationFieldLabel;

  /// IPD dose field label.
  ///
  /// In en, this message translates to:
  /// **'Dose'**
  String get ipdDoseFieldLabel;

  /// IPD dose unit field label.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get ipdUnitFieldLabel;

  /// IPD medication route field label.
  ///
  /// In en, this message translates to:
  /// **'Route'**
  String get ipdRouteFieldLabel;

  /// IPD medication frequency field label.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get ipdFrequencyFieldLabel;

  /// IPD medication administration status field label.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get ipdMedicationStatusFieldLabel;

  /// IPD discharged date label.
  ///
  /// In en, this message translates to:
  /// **'Discharged'**
  String get ipdDischargedAtLabel;

  /// IPD scope label for admissions waiting for a bed.
  ///
  /// In en, this message translates to:
  /// **'Waiting bed'**
  String get ipdScopeAdmissionQueue;

  /// IPD scope label for active bedded patients.
  ///
  /// In en, this message translates to:
  /// **'In beds'**
  String get ipdScopeActivePatients;

  /// IPD scope label for transfer requests.
  ///
  /// In en, this message translates to:
  /// **'Transfers'**
  String get ipdScopeTransferPending;

  /// IPD scope label for planned discharges.
  ///
  /// In en, this message translates to:
  /// **'Discharge planned'**
  String get ipdScopeDischargePlanned;

  /// IPD scope label for admissions awaiting discharge clearance.
  ///
  /// In en, this message translates to:
  /// **'Awaiting clearance'**
  String get ipdScopeAwaitingClearance;

  /// IPD scope label for discharged admissions.
  ///
  /// In en, this message translates to:
  /// **'Discharged'**
  String get ipdScopeDischarged;

  /// IPD scope label for all admissions.
  ///
  /// In en, this message translates to:
  /// **'All admissions'**
  String get ipdScopeAll;

  /// IPD stage label for admitted pending bed.
  ///
  /// In en, this message translates to:
  /// **'Waiting bed'**
  String get ipdStatusAdmittedPendingBed;

  /// IPD stage label for admitted in bed.
  ///
  /// In en, this message translates to:
  /// **'In bed'**
  String get ipdStatusAdmittedInBed;

  /// IPD stage label for transfer requested.
  ///
  /// In en, this message translates to:
  /// **'Transfer requested'**
  String get ipdStatusTransferRequested;

  /// IPD stage label for transfer in progress.
  ///
  /// In en, this message translates to:
  /// **'Transfer in progress'**
  String get ipdStatusTransferInProgress;

  /// IPD stage label for discharge planned.
  ///
  /// In en, this message translates to:
  /// **'Discharge planned'**
  String get ipdStatusDischargePlanned;

  /// IPD stage label for discharged.
  ///
  /// In en, this message translates to:
  /// **'Discharged'**
  String get ipdStatusDischarged;

  /// IPD stage label for cancelled admission.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get ipdStatusCancelled;

  /// IPD next action label for assigning a bed.
  ///
  /// In en, this message translates to:
  /// **'Assign bed'**
  String get ipdNextAssignBed;

  /// IPD next action label for recording a nursing note.
  ///
  /// In en, this message translates to:
  /// **'Record nursing note'**
  String get ipdNextRecordNursingNote;

  /// IPD next action label for approving a transfer.
  ///
  /// In en, this message translates to:
  /// **'Approve transfer'**
  String get ipdNextApproveTransfer;

  /// IPD next action label for starting a transfer.
  ///
  /// In en, this message translates to:
  /// **'Start transfer'**
  String get ipdNextStartTransfer;

  /// IPD next action label for completing a transfer.
  ///
  /// In en, this message translates to:
  /// **'Complete transfer'**
  String get ipdNextCompleteTransfer;

  /// IPD next action label for finalizing discharge.
  ///
  /// In en, this message translates to:
  /// **'Finalize discharge'**
  String get ipdNextFinalizeDischarge;

  /// IPD default next action label.
  ///
  /// In en, this message translates to:
  /// **'Continue care'**
  String get ipdNextContinueCare;

  /// IPD bed status label for available.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get ipdBedStatusAvailable;

  /// IPD bed status label for occupied.
  ///
  /// In en, this message translates to:
  /// **'Occupied'**
  String get ipdBedStatusOccupied;

  /// IPD bed status label for reserved.
  ///
  /// In en, this message translates to:
  /// **'Reserved'**
  String get ipdBedStatusReserved;

  /// IPD bed status label for out of service.
  ///
  /// In en, this message translates to:
  /// **'Out of service'**
  String get ipdBedStatusOutOfService;

  /// IPD discharge status label for planned.
  ///
  /// In en, this message translates to:
  /// **'Planned'**
  String get ipdDischargeStatusPlanned;

  /// IPD discharge status label for completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get ipdDischargeStatusCompleted;

  /// IPD ICU status label for active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get ipdIcuStatusActive;

  /// IPD ICU status label for ended.
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get ipdIcuStatusEnded;

  /// IPD ICU status label when no ICU stay is active.
  ///
  /// In en, this message translates to:
  /// **'No ICU stay'**
  String get ipdIcuStatusNone;

  /// IPD critical alert label.
  ///
  /// In en, this message translates to:
  /// **'Critical alert'**
  String get ipdCriticalAlertLabel;

  /// IPD critical alert label with severity.
  ///
  /// In en, this message translates to:
  /// **'Critical: {severity}'**
  String ipdCriticalSeverityLabel(String severity);

  /// IPD timeline label for ward rounds.
  ///
  /// In en, this message translates to:
  /// **'Ward round'**
  String get ipdTimelineWardRound;

  /// IPD timeline label for nursing notes.
  ///
  /// In en, this message translates to:
  /// **'Nursing note'**
  String get ipdTimelineNursingNote;

  /// IPD timeline label for medication administration.
  ///
  /// In en, this message translates to:
  /// **'Medication'**
  String get ipdTimelineMedication;

  /// IPD timeline label for medication reminders.
  ///
  /// In en, this message translates to:
  /// **'Medication reminder'**
  String get ipdTimelineMedicationReminder;

  /// IPD timeline label for transfers.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get ipdTimelineTransfer;

  /// IPD timeline label for ICU observations.
  ///
  /// In en, this message translates to:
  /// **'ICU observation'**
  String get ipdTimelineIcuObservation;

  /// IPD timeline label for critical alerts.
  ///
  /// In en, this message translates to:
  /// **'Critical alert'**
  String get ipdTimelineCriticalAlert;

  /// IPD timeline fallback label for care events.
  ///
  /// In en, this message translates to:
  /// **'Care event'**
  String get ipdTimelineCareEvent;

  /// IPD transfer update action for approval.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get ipdTransferApproveAction;

  /// IPD transfer update action to start the transfer.
  ///
  /// In en, this message translates to:
  /// **'Start transfer'**
  String get ipdTransferStartAction;

  /// IPD transfer update action to complete the transfer.
  ///
  /// In en, this message translates to:
  /// **'Complete transfer'**
  String get ipdTransferCompleteAction;

  /// IPD transfer update action to cancel the transfer.
  ///
  /// In en, this message translates to:
  /// **'Cancel transfer'**
  String get ipdTransferCancelAction;

  /// Medication route option for oral.
  ///
  /// In en, this message translates to:
  /// **'Oral'**
  String get ipdRouteOral;

  /// Medication route option for intravenous.
  ///
  /// In en, this message translates to:
  /// **'IV'**
  String get ipdRouteIv;

  /// Medication route option for intramuscular.
  ///
  /// In en, this message translates to:
  /// **'IM'**
  String get ipdRouteIm;

  /// Medication route option for topical.
  ///
  /// In en, this message translates to:
  /// **'Topical'**
  String get ipdRouteTopical;

  /// Medication route option for inhalation.
  ///
  /// In en, this message translates to:
  /// **'Inhalation'**
  String get ipdRouteInhalation;

  /// Medication route option for other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get ipdRouteOther;

  /// Medication frequency option for once.
  ///
  /// In en, this message translates to:
  /// **'Once'**
  String get ipdFrequencyOnce;

  /// Medication frequency option for twice daily.
  ///
  /// In en, this message translates to:
  /// **'BID'**
  String get ipdFrequencyBid;

  /// Medication frequency option for three times daily.
  ///
  /// In en, this message translates to:
  /// **'TID'**
  String get ipdFrequencyTid;

  /// Medication frequency option for four times daily.
  ///
  /// In en, this message translates to:
  /// **'QID'**
  String get ipdFrequencyQid;

  /// Medication frequency option for as needed.
  ///
  /// In en, this message translates to:
  /// **'PRN'**
  String get ipdFrequencyPrn;

  /// Medication frequency option for immediate administration.
  ///
  /// In en, this message translates to:
  /// **'STAT'**
  String get ipdFrequencyStat;

  /// Medication frequency option for custom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get ipdFrequencyCustom;

  /// Medication administration status option for given.
  ///
  /// In en, this message translates to:
  /// **'Given'**
  String get ipdMedicationGiven;

  /// Medication administration status option for missed.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get ipdMedicationMissed;

  /// Medication administration status option for delayed.
  ///
  /// In en, this message translates to:
  /// **'Delayed'**
  String get ipdMedicationDelayed;

  /// Medication administration status option for refused.
  ///
  /// In en, this message translates to:
  /// **'Refused'**
  String get ipdMedicationRefused;

  /// Navigation label for the nursing workspace.
  ///
  /// In en, this message translates to:
  /// **'Nursing'**
  String get navigationNursingLabel;

  /// Nursing workspace page title.
  ///
  /// In en, this message translates to:
  /// **'Nursing'**
  String get nursingTitle;

  /// Nursing workspace page description.
  ///
  /// In en, this message translates to:
  /// **'Monitor ward queues, observations, medication administration, handovers, transfers, and escalation.'**
  String get nursingDescription;

  /// Nursing workspace loading title.
  ///
  /// In en, this message translates to:
  /// **'Loading nursing workspace'**
  String get nursingLoadingTitle;

  /// Nursing workspace loading body.
  ///
  /// In en, this message translates to:
  /// **'Loading ward patients, observations, medications, and handovers.'**
  String get nursingLoadingBody;

  /// Nursing workspace live synchronization status.
  ///
  /// In en, this message translates to:
  /// **'Live sync'**
  String get nursingLiveStatus;

  /// Nursing workspace saving status.
  ///
  /// In en, this message translates to:
  /// **'Saving'**
  String get nursingSavingStatus;

  /// Snackbar message after a nursing workspace mutation succeeds.
  ///
  /// In en, this message translates to:
  /// **'Nursing changes saved.'**
  String get nursingSavedMessage;

  /// Nursing summary label for assigned ward patients.
  ///
  /// In en, this message translates to:
  /// **'Assigned ward'**
  String get nursingAssignedWardSummaryLabel;

  /// Nursing summary label for urgent ward patients.
  ///
  /// In en, this message translates to:
  /// **'Urgent'**
  String get nursingUrgentSummaryLabel;

  /// Nursing summary label for patients with medication due.
  ///
  /// In en, this message translates to:
  /// **'Medication due'**
  String get nursingMedicationDueSummaryLabel;

  /// Nursing summary label for pending handovers.
  ///
  /// In en, this message translates to:
  /// **'Handover pending'**
  String get nursingHandoverPendingSummaryLabel;

  /// Nursing summary label for pending transfers.
  ///
  /// In en, this message translates to:
  /// **'Transfer pending'**
  String get nursingTransferPendingSummaryLabel;

  /// Nursing summary label for pending discharges.
  ///
  /// In en, this message translates to:
  /// **'Discharge pending'**
  String get nursingDischargePendingSummaryLabel;

  /// Accessibility label for nursing workspace filters.
  ///
  /// In en, this message translates to:
  /// **'Nursing filters'**
  String get nursingFiltersLabel;

  /// Nursing worklist search field label.
  ///
  /// In en, this message translates to:
  /// **'Search nursing worklist'**
  String get nursingSearchLabel;

  /// Nursing worklist search field hint.
  ///
  /// In en, this message translates to:
  /// **'Patient, admission, encounter, ward, bed, or observation'**
  String get nursingSearchHint;

  /// Nursing queue scope filter label.
  ///
  /// In en, this message translates to:
  /// **'Queue scope'**
  String get nursingScopeFilterLabel;

  /// Nursing ward or bed filter label.
  ///
  /// In en, this message translates to:
  /// **'Ward or bed'**
  String get nursingWardFilterLabel;

  /// Nursing ward or bed filter hint.
  ///
  /// In en, this message translates to:
  /// **'Filter by ward or bed'**
  String get nursingWardFilterHint;

  /// Nursing queue scope option for assigned ward patients.
  ///
  /// In en, this message translates to:
  /// **'Assigned ward'**
  String get nursingScopeAssignedWardLabel;

  /// Nursing queue scope option for urgent patients.
  ///
  /// In en, this message translates to:
  /// **'Urgent'**
  String get nursingScopeUrgentLabel;

  /// Nursing queue scope option for medication due.
  ///
  /// In en, this message translates to:
  /// **'Medication due'**
  String get nursingScopeMedicationDueLabel;

  /// Nursing queue scope option for handover pending.
  ///
  /// In en, this message translates to:
  /// **'Handover pending'**
  String get nursingScopeHandoverPendingLabel;

  /// Nursing queue scope option for transfer pending.
  ///
  /// In en, this message translates to:
  /// **'Transfer pending'**
  String get nursingScopeTransferPendingLabel;

  /// Nursing queue scope option for discharge pending.
  ///
  /// In en, this message translates to:
  /// **'Discharge pending'**
  String get nursingScopeDischargePendingLabel;

  /// Nursing queue scope option for all ward patients.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get nursingScopeAllLabel;

  /// Nursing ward worklist panel title.
  ///
  /// In en, this message translates to:
  /// **'Ward worklist'**
  String get nursingWorklistTitle;

  /// Nursing ward worklist panel description.
  ///
  /// In en, this message translates to:
  /// **'Patients needing observations, medication, handover, transfer, or discharge coordination.'**
  String get nursingWorklistDescription;

  /// Nursing empty worklist title.
  ///
  /// In en, this message translates to:
  /// **'No nursing work'**
  String get nursingNoWorklistTitle;

  /// Nursing empty worklist body.
  ///
  /// In en, this message translates to:
  /// **'No ward patients match the current search and queue scope.'**
  String get nursingNoWorklistBody;

  /// Nursing detail empty state title.
  ///
  /// In en, this message translates to:
  /// **'No ward patient selected'**
  String get nursingNoSelectionTitle;

  /// Nursing detail empty state body.
  ///
  /// In en, this message translates to:
  /// **'Open a patient from the worklist to review observations, medications, handovers, and ward activity.'**
  String get nursingNoSelectionBody;

  /// Accessibility label for the selected nursing patient context header.
  ///
  /// In en, this message translates to:
  /// **'Selected nursing patient context'**
  String get nursingPatientContextLabel;

  /// Nursing worklist location column label.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get nursingLocationColumnLabel;

  /// Nursing worklist due action column label.
  ///
  /// In en, this message translates to:
  /// **'Due action'**
  String get nursingDueActionColumnLabel;

  /// Nursing worklist last observation column label.
  ///
  /// In en, this message translates to:
  /// **'Last observation'**
  String get nursingLastObservationColumnLabel;

  /// Nursing patient context admission field label.
  ///
  /// In en, this message translates to:
  /// **'Admission'**
  String get nursingAdmissionLabel;

  /// Nursing patient context encounter field label.
  ///
  /// In en, this message translates to:
  /// **'Encounter'**
  String get nursingEncounterLabel;

  /// Nursing patient context location field label.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get nursingLocationLabel;

  /// Nursing patient context facility field label.
  ///
  /// In en, this message translates to:
  /// **'Facility'**
  String get nursingFacilityLabel;

  /// Nursing patient context ICU field label.
  ///
  /// In en, this message translates to:
  /// **'ICU'**
  String get nursingIcuLabel;

  /// Nursing patient context bed field label.
  ///
  /// In en, this message translates to:
  /// **'Bed'**
  String get nursingBedLabel;

  /// Nursing actions panel title.
  ///
  /// In en, this message translates to:
  /// **'Nursing actions'**
  String get nursingActionsTitle;

  /// Action label for recording nursing vitals.
  ///
  /// In en, this message translates to:
  /// **'Record vitals'**
  String get nursingActionRecordVitals;

  /// Action label for adding a nursing note.
  ///
  /// In en, this message translates to:
  /// **'Add note'**
  String get nursingActionAddNote;

  /// Action label for administering medication.
  ///
  /// In en, this message translates to:
  /// **'Administer medication'**
  String get nursingActionAdministerMedication;

  /// Action label for completing a nursing task.
  ///
  /// In en, this message translates to:
  /// **'Complete task'**
  String get nursingActionCompleteTask;

  /// Action label for creating a nursing handover.
  ///
  /// In en, this message translates to:
  /// **'Create handover'**
  String get nursingActionCreateHandover;

  /// Action label for escalating nursing care.
  ///
  /// In en, this message translates to:
  /// **'Escalate'**
  String get nursingActionEscalate;

  /// Action label for acknowledging or updating a transfer.
  ///
  /// In en, this message translates to:
  /// **'Acknowledge transfer'**
  String get nursingActionAcknowledgeTransfer;

  /// Action label for accepting a nursing handover.
  ///
  /// In en, this message translates to:
  /// **'Accept handover'**
  String get nursingActionAcceptHandover;

  /// Action label for printing a nursing summary report.
  ///
  /// In en, this message translates to:
  /// **'Print nursing summary'**
  String get nursingActionPrintSummary;

  /// Title for the generated nursing care summary report.
  ///
  /// In en, this message translates to:
  /// **'Nursing care summary'**
  String get nursingReportTitle;

  /// Footer note for generated nursing reports.
  ///
  /// In en, this message translates to:
  /// **'Generated from the nursing report template for clinical audit.'**
  String get nursingReportFooter;

  /// Nursing observations section title.
  ///
  /// In en, this message translates to:
  /// **'Observations'**
  String get nursingObservationsTitle;

  /// Nursing medications section title.
  ///
  /// In en, this message translates to:
  /// **'Medications'**
  String get nursingMedicationsTitle;

  /// Nursing notes section title.
  ///
  /// In en, this message translates to:
  /// **'Nursing notes'**
  String get nursingNotesTitle;

  /// Nursing care plans section title.
  ///
  /// In en, this message translates to:
  /// **'Care plans'**
  String get nursingCarePlansTitle;

  /// Nursing handovers section title.
  ///
  /// In en, this message translates to:
  /// **'Handovers'**
  String get nursingHandoversTitle;

  /// Nursing ward activity section title.
  ///
  /// In en, this message translates to:
  /// **'Ward activity'**
  String get nursingWardActivityTitle;

  /// Nursing record list empty label.
  ///
  /// In en, this message translates to:
  /// **'No records yet'**
  String get nursingNoRecordsLabel;

  /// Nursing vitals type field label.
  ///
  /// In en, this message translates to:
  /// **'Vital type'**
  String get nursingVitalsTypeLabel;

  /// Nursing vital value field label.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get nursingVitalValueLabel;

  /// Nursing vital unit field label.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get nursingVitalUnitLabel;

  /// Nursing blood pressure systolic field label.
  ///
  /// In en, this message translates to:
  /// **'Systolic'**
  String get nursingSystolicLabel;

  /// Nursing blood pressure diastolic field label.
  ///
  /// In en, this message translates to:
  /// **'Diastolic'**
  String get nursingDiastolicLabel;

  /// Nursing mean arterial pressure field label.
  ///
  /// In en, this message translates to:
  /// **'MAP'**
  String get nursingMapLabel;

  /// Nursing vital recorded-at field label.
  ///
  /// In en, this message translates to:
  /// **'Recorded at'**
  String get nursingRecordedAtLabel;

  /// Nursing medication administered-at field label.
  ///
  /// In en, this message translates to:
  /// **'Administered at'**
  String get nursingAdministeredAtLabel;

  /// Hint for ISO-8601 date time entry in nursing forms.
  ///
  /// In en, this message translates to:
  /// **'YYYY-MM-DDTHH:mm:ssZ'**
  String get nursingDateTimeHint;

  /// Nursing note field label.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get nursingNoteLabel;

  /// Nursing task field label.
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get nursingTaskLabel;

  /// Nursing medication selection field label.
  ///
  /// In en, this message translates to:
  /// **'Medication'**
  String get nursingMedicationLabel;

  /// Nursing medication dose field label.
  ///
  /// In en, this message translates to:
  /// **'Dose'**
  String get nursingDoseLabel;

  /// Nursing medication route field label.
  ///
  /// In en, this message translates to:
  /// **'Route'**
  String get nursingRouteLabel;

  /// Nursing medication administration status field label.
  ///
  /// In en, this message translates to:
  /// **'Administration status'**
  String get nursingAdministrationStatusLabel;

  /// Nursing medication frequency field label.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get nursingFrequencyLabel;

  /// Nursing medication administration note field label.
  ///
  /// In en, this message translates to:
  /// **'Administration note'**
  String get nursingAdministrationNoteLabel;

  /// Nursing medication reminder scheduling checkbox label.
  ///
  /// In en, this message translates to:
  /// **'Schedule reminders'**
  String get nursingScheduleRemindersLabel;

  /// Nursing medication administration confirmation checkbox label.
  ///
  /// In en, this message translates to:
  /// **'Confirm medication administration'**
  String get nursingConfirmMedicationLabel;

  /// Nursing medication administration confirmation checkbox helper text.
  ///
  /// In en, this message translates to:
  /// **'Verify the patient, medication, dose, route, and time before saving.'**
  String get nursingConfirmMedicationSubtitle;

  /// Nursing handover recipient searchable user field label.
  ///
  /// In en, this message translates to:
  /// **'Recipient'**
  String get nursingHandoverToUserLabel;

  /// Nursing handover notes field label.
  ///
  /// In en, this message translates to:
  /// **'Handover notes'**
  String get nursingHandoverNotesLabel;

  /// Nursing escalation message field label.
  ///
  /// In en, this message translates to:
  /// **'Escalation message'**
  String get nursingEscalationMessageLabel;

  /// Nursing escalation confirmation checkbox label.
  ///
  /// In en, this message translates to:
  /// **'Confirm escalation'**
  String get nursingConfirmEscalationLabel;

  /// Nursing transfer action field label.
  ///
  /// In en, this message translates to:
  /// **'Transfer action'**
  String get nursingTransferActionLabel;

  /// Nursing transfer destination bed ID field label.
  ///
  /// In en, this message translates to:
  /// **'To bed ID'**
  String get nursingToBedLabel;

  /// Nursing transfer confirmation checkbox label.
  ///
  /// In en, this message translates to:
  /// **'Confirm transfer update'**
  String get nursingConfirmTransferLabel;

  /// Localized text for nursingAdvancedFiltersLabel.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get nursingAdvancedFiltersLabel;

  /// Localized text for nursingAdvancedFiltersTitle.
  ///
  /// In en, this message translates to:
  /// **'Nursing worklist filters'**
  String get nursingAdvancedFiltersTitle;

  /// Localized text for nursingApplyFiltersLabel.
  ///
  /// In en, this message translates to:
  /// **'Apply filters'**
  String get nursingApplyFiltersLabel;

  /// Localized text for nursingResetFiltersLabel.
  ///
  /// In en, this message translates to:
  /// **'Reset filters'**
  String get nursingResetFiltersLabel;

  /// Localized text for nursingSearchFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Search fields'**
  String get nursingSearchFieldLabel;

  /// Localized text for nursingAllFieldsLabel.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get nursingAllFieldsLabel;

  /// Localized text for nursingDateFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Due or observation date'**
  String get nursingDateFilterLabel;

  /// Localized text for nursingDateFromLabel.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get nursingDateFromLabel;

  /// Localized text for nursingDateToLabel.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get nursingDateToLabel;

  /// Localized text for nursingDatePickerLabel.
  ///
  /// In en, this message translates to:
  /// **'Choose date'**
  String get nursingDatePickerLabel;

  /// Localized text for nursingInvalidDateMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid date.'**
  String get nursingInvalidDateMessage;

  /// Localized text for nursingPatientFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Patient'**
  String get nursingPatientFilterLabel;

  /// Localized text for nursingPatientFilterHint.
  ///
  /// In en, this message translates to:
  /// **'Name, number, admission, or encounter'**
  String get nursingPatientFilterHint;

  /// Localized text for nursingUnitFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get nursingUnitFilterLabel;

  /// Localized text for nursingUnitFilterHint.
  ///
  /// In en, this message translates to:
  /// **'Ward, ICU, recovery, or unit'**
  String get nursingUnitFilterHint;

  /// Localized text for nursingShiftFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Shift'**
  String get nursingShiftFilterLabel;

  /// Localized text for nursingShiftFilterHint.
  ///
  /// In en, this message translates to:
  /// **'Morning, evening, night, or current shift'**
  String get nursingShiftFilterHint;

  /// Localized text for nursingCareTaskFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Care task'**
  String get nursingCareTaskFilterLabel;

  /// Localized text for nursingCareTaskFilterHint.
  ///
  /// In en, this message translates to:
  /// **'Vitals, medication, handover, transfer, or discharge'**
  String get nursingCareTaskFilterHint;

  /// Localized text for nursingAdmissionStatusFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Admission status'**
  String get nursingAdmissionStatusFilterLabel;

  /// Localized text for nursingAdmissionStatusFilterHint.
  ///
  /// In en, this message translates to:
  /// **'Active, admitted, transfer, or discharge status'**
  String get nursingAdmissionStatusFilterHint;

  /// Localized text for nursingDischargeReadinessFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Discharge readiness'**
  String get nursingDischargeReadinessFilterLabel;

  /// Localized text for nursingDischargeReadinessFilterHint.
  ///
  /// In en, this message translates to:
  /// **'Planned, pending, ready, or blocked'**
  String get nursingDischargeReadinessFilterHint;

  /// Localized text for nursingPriorityFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get nursingPriorityFilterLabel;

  /// Localized text for nursingPriorityHighLabel.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get nursingPriorityHighLabel;

  /// Localized text for nursingPriorityMediumLabel.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get nursingPriorityMediumLabel;

  /// Localized text for nursingPriorityRoutineLabel.
  ///
  /// In en, this message translates to:
  /// **'Routine'**
  String get nursingPriorityRoutineLabel;

  /// Localized text for nursingAdmissionColumnLabel.
  ///
  /// In en, this message translates to:
  /// **'Admission'**
  String get nursingAdmissionColumnLabel;

  /// Localized text for nursingTaskTypeColumnLabel.
  ///
  /// In en, this message translates to:
  /// **'Task type'**
  String get nursingTaskTypeColumnLabel;

  /// Localized text for nursingPriorityColumnLabel.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get nursingPriorityColumnLabel;

  /// Localized text for nursingDueTimeColumnLabel.
  ///
  /// In en, this message translates to:
  /// **'Due time'**
  String get nursingDueTimeColumnLabel;

  /// Localized text for nursingResponsibleNurseColumnLabel.
  ///
  /// In en, this message translates to:
  /// **'Responsible nurse'**
  String get nursingResponsibleNurseColumnLabel;

  /// Localized text for nursingDueNowLabel.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get nursingDueNowLabel;

  /// Localized text for nursingAssignedShiftLabel.
  ///
  /// In en, this message translates to:
  /// **'Assigned shift'**
  String get nursingAssignedShiftLabel;

  /// Localized text for nursingWardAdmissionChecklistTitle.
  ///
  /// In en, this message translates to:
  /// **'Ward admission checklist'**
  String get nursingWardAdmissionChecklistTitle;

  /// Localized text for nursingWardAdmissionChecklistDescription.
  ///
  /// In en, this message translates to:
  /// **'Checks tied to bed location, admission handover, observations, care plan, medication, and discharge readiness.'**
  String get nursingWardAdmissionChecklistDescription;

  /// Localized text for nursingChecklistCompleteStatus.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get nursingChecklistCompleteStatus;

  /// Localized text for nursingChecklistPendingStatus.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get nursingChecklistPendingStatus;

  /// Localized text for nursingChecklistLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'Location confirmed'**
  String get nursingChecklistLocationTitle;

  /// Localized text for nursingChecklistLocationReadyBody.
  ///
  /// In en, this message translates to:
  /// **'Patient location is available.'**
  String get nursingChecklistLocationReadyBody;

  /// Localized text for nursingChecklistLocationPendingBody.
  ///
  /// In en, this message translates to:
  /// **'Waiting for bed allocation or authorized holding area.'**
  String get nursingChecklistLocationPendingBody;

  /// Localized text for nursingChecklistHandoverTitle.
  ///
  /// In en, this message translates to:
  /// **'Admission handover'**
  String get nursingChecklistHandoverTitle;

  /// Localized text for nursingChecklistHandoverReadyBody.
  ///
  /// In en, this message translates to:
  /// **'A nursing handover is linked to this admission.'**
  String get nursingChecklistHandoverReadyBody;

  /// Localized text for nursingChecklistHandoverPendingBody.
  ///
  /// In en, this message translates to:
  /// **'Record or accept the admission handover before ward care continues.'**
  String get nursingChecklistHandoverPendingBody;

  /// Localized text for nursingChecklistVitalsTitle.
  ///
  /// In en, this message translates to:
  /// **'Initial observations'**
  String get nursingChecklistVitalsTitle;

  /// Localized text for nursingChecklistVitalsPendingBody.
  ///
  /// In en, this message translates to:
  /// **'Record baseline vital signs for the admission.'**
  String get nursingChecklistVitalsPendingBody;

  /// Localized text for nursingChecklistCarePlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Care plan started'**
  String get nursingChecklistCarePlanTitle;

  /// Localized text for nursingChecklistCarePlanReadyBody.
  ///
  /// In en, this message translates to:
  /// **'At least one care task or plan is recorded.'**
  String get nursingChecklistCarePlanReadyBody;

  /// Localized text for nursingChecklistCarePlanPendingBody.
  ///
  /// In en, this message translates to:
  /// **'Add a care task or plan for ward follow-up.'**
  String get nursingChecklistCarePlanPendingBody;

  /// Localized text for nursingChecklistMedicationTitle.
  ///
  /// In en, this message translates to:
  /// **'Medication queue clear'**
  String get nursingChecklistMedicationTitle;

  /// Localized text for nursingChecklistMedicationReadyBody.
  ///
  /// In en, this message translates to:
  /// **'No medication administration is currently due.'**
  String get nursingChecklistMedicationReadyBody;

  /// Localized text for nursingChecklistMedicationPendingBody.
  ///
  /// In en, this message translates to:
  /// **'Medication administration remains due for this patient.'**
  String get nursingChecklistMedicationPendingBody;

  /// Localized text for nursingChecklistDischargeTitle.
  ///
  /// In en, this message translates to:
  /// **'Discharge nursing readiness'**
  String get nursingChecklistDischargeTitle;

  /// Localized text for nursingChecklistDischargeReadyBody.
  ///
  /// In en, this message translates to:
  /// **'No discharge nursing checklist is pending.'**
  String get nursingChecklistDischargeReadyBody;

  /// Localized text for nursingChecklistDischargePendingBody.
  ///
  /// In en, this message translates to:
  /// **'Discharge nursing checks are pending; do not close the admission here.'**
  String get nursingChecklistDischargePendingBody;

  /// Localized text for nursingShiftContextTitle.
  ///
  /// In en, this message translates to:
  /// **'Shift context'**
  String get nursingShiftContextTitle;

  /// Localized text for nursingShiftContextDescription.
  ///
  /// In en, this message translates to:
  /// **'Current roster and handover items stay visible without opening another module.'**
  String get nursingShiftContextDescription;

  /// Localized text for nursingRosterTitle.
  ///
  /// In en, this message translates to:
  /// **'Roster assignments'**
  String get nursingRosterTitle;

  /// Localized text for nursingPendingHandoverTitle.
  ///
  /// In en, this message translates to:
  /// **'Pending handovers'**
  String get nursingPendingHandoverTitle;

  /// Localized text for nursingNoRosterLabel.
  ///
  /// In en, this message translates to:
  /// **'No roster assignments found for this shift.'**
  String get nursingNoRosterLabel;

  /// Navigation label for the discharge workspace.
  ///
  /// In en, this message translates to:
  /// **'Discharge'**
  String get navigationDischargeLabel;

  /// Discharge workspace page title.
  ///
  /// In en, this message translates to:
  /// **'Discharge workspace'**
  String get dischargeWorkspaceTitle;

  /// Discharge workspace page description.
  ///
  /// In en, this message translates to:
  /// **'Coordinate discharge plans, clearances, medicines, final billing, documents, and bed release.'**
  String get dischargeWorkspaceDescription;

  /// Discharge workspace operational status label.
  ///
  /// In en, this message translates to:
  /// **'Discharge desk active'**
  String get dischargeOperationalStatusLabel;

  /// Discharge summary card label for planned discharges.
  ///
  /// In en, this message translates to:
  /// **'Planned'**
  String get dischargePlannedSummaryLabel;

  /// Discharge summary card label for admissions awaiting a discharge summary.
  ///
  /// In en, this message translates to:
  /// **'Summary pending'**
  String get dischargeSummaryPendingSummaryLabel;

  /// Discharge summary card label for generated discharge documents.
  ///
  /// In en, this message translates to:
  /// **'Documents ready'**
  String get dischargeDocumentsReadySummaryLabel;

  /// Discharge summary card label for completed discharges.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get dischargeCompletedSummaryLabel;

  /// Accessible label for discharge queue search.
  ///
  /// In en, this message translates to:
  /// **'Search discharge queue'**
  String get dischargeQueueSearchLabel;

  /// Hint text for discharge queue search.
  ///
  /// In en, this message translates to:
  /// **'Search patient, admission, or ward'**
  String get dischargeQueueSearchHint;

  /// Discharge queue status filter label.
  ///
  /// In en, this message translates to:
  /// **'Discharge status'**
  String get dischargeStatusFilterLabel;

  /// Discharge status filter option for all statuses.
  ///
  /// In en, this message translates to:
  /// **'All discharges'**
  String get dischargeStatusAll;

  /// Discharge status filter option for planned discharges.
  ///
  /// In en, this message translates to:
  /// **'Planned'**
  String get dischargeStatusPlanned;

  /// Discharge status filter option for admissions awaiting summary.
  ///
  /// In en, this message translates to:
  /// **'Summary pending'**
  String get dischargeStatusSummaryPending;

  /// Discharge status filter option for pharmacy clearance.
  ///
  /// In en, this message translates to:
  /// **'Pharmacy pending'**
  String get dischargeStatusPharmacyPending;

  /// Discharge status filter option for nursing clearance.
  ///
  /// In en, this message translates to:
  /// **'Nursing pending'**
  String get dischargeStatusNursingPending;

  /// Discharge status filter option for billing clearance.
  ///
  /// In en, this message translates to:
  /// **'Billing pending'**
  String get dischargeStatusBillingPending;

  /// Discharge status filter option for insurance clearance.
  ///
  /// In en, this message translates to:
  /// **'Insurance pending'**
  String get dischargeStatusInsurancePending;

  /// Discharge status filter option for document readiness.
  ///
  /// In en, this message translates to:
  /// **'Documents ready'**
  String get dischargeStatusDocumentsReady;

  /// Discharge status filter option for completed discharges.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get dischargeStatusCompleted;

  /// Discharge queue panel title.
  ///
  /// In en, this message translates to:
  /// **'Discharge worklist'**
  String get dischargeWorklistTitle;

  /// Discharge queue panel description.
  ///
  /// In en, this message translates to:
  /// **'Patients with a discharge plan, pending clearance, or recent completion.'**
  String get dischargeWorklistDescription;

  /// Discharge queue previous page button label.
  ///
  /// In en, this message translates to:
  /// **'Previous discharges'**
  String get dischargePreviousPageLabel;

  /// Discharge queue next page button label.
  ///
  /// In en, this message translates to:
  /// **'Next discharges'**
  String get dischargeNextPageLabel;

  /// Pagination label for discharge data lists.
  ///
  /// In en, this message translates to:
  /// **'{from}-{to} of {total}'**
  String dischargePageLabel(int from, int to, int total);

  /// Empty state title for discharge queue.
  ///
  /// In en, this message translates to:
  /// **'No discharges in this view'**
  String get dischargeEmptyQueueTitle;

  /// Empty state body for discharge queue.
  ///
  /// In en, this message translates to:
  /// **'Adjust the status filter or search term to find discharge work.'**
  String get dischargeEmptyQueueBody;

  /// Discharge queue patient column label.
  ///
  /// In en, this message translates to:
  /// **'Patient'**
  String get dischargePatientColumnLabel;

  /// Discharge queue location column label.
  ///
  /// In en, this message translates to:
  /// **'Ward and bed'**
  String get dischargeLocationColumnLabel;

  /// Discharge queue status column label.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get dischargeStatusColumnLabel;

  /// Discharge queue next action column label.
  ///
  /// In en, this message translates to:
  /// **'Next action'**
  String get dischargeNextActionColumnLabel;

  /// Discharge queue target date column label.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get dischargeTargetColumnLabel;

  /// Discharge detail panel title.
  ///
  /// In en, this message translates to:
  /// **'Discharge detail'**
  String get dischargeDetailTitle;

  /// Discharge detail loading title.
  ///
  /// In en, this message translates to:
  /// **'Loading discharge detail'**
  String get dischargeDetailLoadingTitle;

  /// Discharge detail loading body.
  ///
  /// In en, this message translates to:
  /// **'Loading patient context, clearance, medicines, billing, and documents.'**
  String get dischargeDetailLoadingBody;

  /// Discharge detail empty selection title.
  ///
  /// In en, this message translates to:
  /// **'Select a discharge'**
  String get dischargeNoSelectionTitle;

  /// Discharge detail empty selection body.
  ///
  /// In en, this message translates to:
  /// **'Choose a patient from the worklist to coordinate discharge.'**
  String get dischargeNoSelectionBody;

  /// Discharge summary print action label.
  ///
  /// In en, this message translates to:
  /// **'Print discharge summary'**
  String get dischargePrintSummaryAction;

  /// Accessible label for discharge patient context card.
  ///
  /// In en, this message translates to:
  /// **'Patient discharge context'**
  String get dischargePatientContextLabel;

  /// Discharge patient context admission field label.
  ///
  /// In en, this message translates to:
  /// **'Admission'**
  String get dischargeAdmissionFieldLabel;

  /// Discharge patient context encounter field label.
  ///
  /// In en, this message translates to:
  /// **'Encounter'**
  String get dischargeEncounterFieldLabel;

  /// Discharge patient context location field label.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get dischargeLocationFieldLabel;

  /// Discharge patient context target field label.
  ///
  /// In en, this message translates to:
  /// **'Target discharge'**
  String get dischargeTargetFieldLabel;

  /// Action label to start a discharge plan.
  ///
  /// In en, this message translates to:
  /// **'Start discharge plan'**
  String get dischargeStartPlanAction;

  /// Action label to edit the discharge summary.
  ///
  /// In en, this message translates to:
  /// **'Edit summary'**
  String get dischargeEditSummaryAction;

  /// Action label to request final billing for discharge.
  ///
  /// In en, this message translates to:
  /// **'Request final billing'**
  String get dischargeRequestBillingAction;

  /// Action label to request discharge medicines.
  ///
  /// In en, this message translates to:
  /// **'Request medicines'**
  String get dischargeRequestPharmacyAction;

  /// Action label to complete discharge.
  ///
  /// In en, this message translates to:
  /// **'Complete discharge'**
  String get dischargeCompleteAction;

  /// Discharge clearance checklist title.
  ///
  /// In en, this message translates to:
  /// **'Clearance checklist'**
  String get dischargeChecklistTitle;

  /// Discharge clearance checklist body.
  ///
  /// In en, this message translates to:
  /// **'Track clinical, nursing, pharmacy, billing, documents, and bed release readiness.'**
  String get dischargeChecklistBody;

  /// Clearance status for completed discharge checklist item.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get dischargeClearanceComplete;

  /// Clearance status for pending discharge checklist item.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get dischargeClearancePending;

  /// Clearance status for discharge checklist item without backend support.
  ///
  /// In en, this message translates to:
  /// **'Backend gap'**
  String get dischargeClearanceBackendGap;

  /// Clearance status for discharge data that could not be loaded.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get dischargeClearanceUnavailable;

  /// Discharge checklist doctor clearance label.
  ///
  /// In en, this message translates to:
  /// **'Doctor summary'**
  String get dischargeClearanceDoctor;

  /// Discharge checklist nursing clearance label.
  ///
  /// In en, this message translates to:
  /// **'Nursing handover'**
  String get dischargeClearanceNursing;

  /// Discharge checklist pharmacy clearance label.
  ///
  /// In en, this message translates to:
  /// **'Pharmacy medicines'**
  String get dischargeClearancePharmacy;

  /// Discharge checklist billing clearance label.
  ///
  /// In en, this message translates to:
  /// **'Final billing'**
  String get dischargeClearanceBilling;

  /// Discharge checklist insurance clearance label.
  ///
  /// In en, this message translates to:
  /// **'Insurance clearance'**
  String get dischargeClearanceInsurance;

  /// Discharge checklist documents label.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get dischargeClearanceDocuments;

  /// Discharge checklist bed release label.
  ///
  /// In en, this message translates to:
  /// **'Bed release'**
  String get dischargeClearanceBedRelease;

  /// Discharge checklist housekeeping label.
  ///
  /// In en, this message translates to:
  /// **'Housekeeping'**
  String get dischargeClearanceHousekeeping;

  /// Discharge clinical summary section title.
  ///
  /// In en, this message translates to:
  /// **'Clinical summary'**
  String get dischargeSummarySectionTitle;

  /// Discharge clinical summary section body.
  ///
  /// In en, this message translates to:
  /// **'Capture diagnosis, treatment, medicines, advice, follow-up, warnings, and signature context.'**
  String get dischargeSummarySectionBody;

  /// Empty state title for missing discharge summary.
  ///
  /// In en, this message translates to:
  /// **'No summary recorded'**
  String get dischargeEmptySummaryTitle;

  /// Empty state body for missing discharge summary.
  ///
  /// In en, this message translates to:
  /// **'Start a discharge plan to prepare the printable summary.'**
  String get dischargeEmptySummaryBody;

  /// Discharge generated document preview title.
  ///
  /// In en, this message translates to:
  /// **'Generated document preview'**
  String get dischargeGeneratedDocumentsTitle;

  /// Discharge medicines section title.
  ///
  /// In en, this message translates to:
  /// **'Discharge medicines'**
  String get dischargeMedicinesSectionTitle;

  /// Empty state body for discharge medicines.
  ///
  /// In en, this message translates to:
  /// **'No discharge medicine orders are linked to this admission.'**
  String get dischargeNoMedicinesBody;

  /// Unavailable state body for pharmacy order data.
  ///
  /// In en, this message translates to:
  /// **'Pharmacy orders could not be loaded. Refresh before completing discharge.'**
  String get dischargePharmacyUnavailableBody;

  /// Discharge billing section title.
  ///
  /// In en, this message translates to:
  /// **'Billing clearance'**
  String get dischargeBillingSectionTitle;

  /// Empty state body for discharge billing records.
  ///
  /// In en, this message translates to:
  /// **'No final invoices are linked to this admission.'**
  String get dischargeNoInvoicesBody;

  /// Unavailable state body for billing data.
  ///
  /// In en, this message translates to:
  /// **'Billing records could not be loaded. Refresh before completing discharge.'**
  String get dischargeBillingUnavailableBody;

  /// Generic empty state title for discharge related records.
  ///
  /// In en, this message translates to:
  /// **'No records'**
  String get dischargeNoRecordsTitle;

  /// Discharge admission timeline section title.
  ///
  /// In en, this message translates to:
  /// **'Admission timeline'**
  String get dischargeTimelineSectionTitle;

  /// Empty state title for discharge timeline.
  ///
  /// In en, this message translates to:
  /// **'No timeline activity'**
  String get dischargeNoTimelineTitle;

  /// Empty state body for discharge timeline.
  ///
  /// In en, this message translates to:
  /// **'Admission timeline events will appear after activity is recorded.'**
  String get dischargeNoTimelineBody;

  /// Discharge backend gaps section title.
  ///
  /// In en, this message translates to:
  /// **'Backend gaps'**
  String get dischargeBackendGapsTitle;

  /// Discharge backend gaps empty body.
  ///
  /// In en, this message translates to:
  /// **'These workflow actions are shown as gaps because no confirmed backend contract exists yet.'**
  String get dischargeBackendGapsBody;

  /// Subtitle for discharge workflow backend gap items.
  ///
  /// In en, this message translates to:
  /// **'Backend endpoint required'**
  String get dischargeGapBackendSubtitle;

  /// Discharge backend gap title for checklist persistence.
  ///
  /// In en, this message translates to:
  /// **'Persistent clearance checklist'**
  String get dischargeGapChecklistTitle;

  /// Discharge backend gap body for checklist persistence.
  ///
  /// In en, this message translates to:
  /// **'No confirmed endpoint persists individual doctor, nursing, pharmacy, billing, document, or exit checklist decisions.'**
  String get dischargeGapChecklistBody;

  /// Discharge backend gap title for insurance clearance.
  ///
  /// In en, this message translates to:
  /// **'Insurance clearance workflow'**
  String get dischargeGapInsuranceTitle;

  /// Discharge backend gap body for insurance clearance.
  ///
  /// In en, this message translates to:
  /// **'No confirmed insurance clearance endpoint is tied to the discharge workflow.'**
  String get dischargeGapInsuranceBody;

  /// Discharge backend gap title for document readiness.
  ///
  /// In en, this message translates to:
  /// **'Document ready state'**
  String get dischargeGapDocumentsTitle;

  /// Discharge backend gap body for document readiness.
  ///
  /// In en, this message translates to:
  /// **'Discharge documents can be generated from the summary, but no confirmed endpoint marks handover documents ready.'**
  String get dischargeGapDocumentsBody;

  /// Discharge backend gap title for housekeeping task creation.
  ///
  /// In en, this message translates to:
  /// **'Housekeeping task handoff'**
  String get dischargeGapHousekeepingTitle;

  /// Discharge backend gap body for housekeeping task creation.
  ///
  /// In en, this message translates to:
  /// **'Final discharge releases the bed, but no confirmed atomic housekeeping task creation is part of that workflow.'**
  String get dischargeGapHousekeepingBody;

  /// Discharge plan dialog title.
  ///
  /// In en, this message translates to:
  /// **'Discharge plan'**
  String get dischargePlanDialogTitle;

  /// Discharge plan dialog body.
  ///
  /// In en, this message translates to:
  /// **'Prepare the clinical discharge summary and target discharge date.'**
  String get dischargePlanDialogBody;

  /// Discharge summary text field label.
  ///
  /// In en, this message translates to:
  /// **'Discharge summary'**
  String get dischargeSummaryFieldLabel;

  /// Discharge summary field helper text.
  ///
  /// In en, this message translates to:
  /// **'Include diagnosis, treatment, medicines, advice, follow-up, warning signs, and signature context.'**
  String get dischargeSummaryHelperText;

  /// Validation message for required discharge summary.
  ///
  /// In en, this message translates to:
  /// **'Enter the discharge summary.'**
  String get dischargeSummaryRequiredMessage;

  /// Discharge target date field label.
  ///
  /// In en, this message translates to:
  /// **'Target discharge date'**
  String get dischargeTargetDateLabel;

  /// Discharge date picker button label.
  ///
  /// In en, this message translates to:
  /// **'Choose date'**
  String get dischargeDatePickerLabel;

  /// Validation message for invalid discharge date.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid discharge date.'**
  String get dischargeInvalidDateMessage;

  /// Discharge save plan action label.
  ///
  /// In en, this message translates to:
  /// **'Save plan'**
  String get dischargeSavePlanAction;

  /// Discharge final billing dialog title.
  ///
  /// In en, this message translates to:
  /// **'Final billing request'**
  String get dischargeBillingDialogTitle;

  /// Discharge final billing dialog body.
  ///
  /// In en, this message translates to:
  /// **'Create a final invoice request for billing clearance.'**
  String get dischargeBillingDialogBody;

  /// Discharge billing amount field label.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get dischargeBillingAmountLabel;

  /// Validation message for required billing amount.
  ///
  /// In en, this message translates to:
  /// **'Enter the final billing amount.'**
  String get dischargeBillingAmountRequiredMessage;

  /// Discharge billing currency field label.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get dischargeBillingCurrencyLabel;

  /// Validation message for required billing currency.
  ///
  /// In en, this message translates to:
  /// **'Enter the billing currency.'**
  String get dischargeBillingCurrencyRequiredMessage;

  /// Submit action label for discharge billing request.
  ///
  /// In en, this message translates to:
  /// **'Create invoice request'**
  String get dischargeRequestBillingSubmitAction;

  /// Discharge pharmacy medicines dialog title.
  ///
  /// In en, this message translates to:
  /// **'Discharge medicines'**
  String get dischargePharmacyDialogTitle;

  /// Discharge pharmacy medicines dialog body.
  ///
  /// In en, this message translates to:
  /// **'Send discharge medicines to pharmacy using the confirmed order route.'**
  String get dischargePharmacyDialogBody;

  /// Discharge medicine drug field label.
  ///
  /// In en, this message translates to:
  /// **'Medicine'**
  String get dischargeDrugFieldLabel;

  /// Validation message for required discharge medicine.
  ///
  /// In en, this message translates to:
  /// **'Select a medicine.'**
  String get dischargeDrugRequiredMessage;

  /// Discharge prescription field label.
  ///
  /// In en, this message translates to:
  /// **'Prescription'**
  String get dischargePrescriptionFieldLabel;

  /// Discharge prescription helper text.
  ///
  /// In en, this message translates to:
  /// **'State dose, duration, and any patient instructions.'**
  String get dischargePrescriptionHelperText;

  /// Validation message for required discharge prescription.
  ///
  /// In en, this message translates to:
  /// **'Enter the discharge prescription.'**
  String get dischargePrescriptionRequiredMessage;

  /// Discharge medicine quantity field label.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get dischargeQuantityFieldLabel;

  /// Discharge medicine route field label.
  ///
  /// In en, this message translates to:
  /// **'Route'**
  String get dischargeMedicationRouteLabel;

  /// Discharge medicine frequency field label.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get dischargeMedicationFrequencyLabel;

  /// Discharge medicine instructions field label.
  ///
  /// In en, this message translates to:
  /// **'Instructions'**
  String get dischargeMedicineInstructionsLabel;

  /// Submit action label for discharge pharmacy request.
  ///
  /// In en, this message translates to:
  /// **'Send to pharmacy'**
  String get dischargeRequestPharmacySubmitAction;

  /// Complete discharge dialog title.
  ///
  /// In en, this message translates to:
  /// **'Complete discharge'**
  String get dischargeCompleteDialogTitle;

  /// Complete discharge dialog body.
  ///
  /// In en, this message translates to:
  /// **'Confirm the patient exit only after required clinical, nursing, pharmacy, billing, and document checks are complete.'**
  String get dischargeCompleteDialogBody;

  /// Complete discharge blocker state title.
  ///
  /// In en, this message translates to:
  /// **'Clearance still pending'**
  String get dischargeCompletionBlockersTitle;

  /// Complete discharge blocker state body.
  ///
  /// In en, this message translates to:
  /// **'Resolve pending or unavailable clearance items before finalizing the admission.'**
  String get dischargeCompletionBlockersBody;

  /// Complete discharge confirmation checkbox label.
  ///
  /// In en, this message translates to:
  /// **'I confirm the patient has exited and documents were handed over.'**
  String get dischargeCompleteConfirmLabel;

  /// Validation message for complete discharge confirmation.
  ///
  /// In en, this message translates to:
  /// **'Confirm patient exit before completing discharge.'**
  String get dischargeCompleteConfirmRequiredMessage;

  /// Complete discharge submit action label.
  ///
  /// In en, this message translates to:
  /// **'Finalize discharge'**
  String get dischargeCompleteSubmitAction;

  /// Next action label for completed discharge rows.
  ///
  /// In en, this message translates to:
  /// **'Discharge completed'**
  String get dischargeNextActionCompleted;

  /// Next action label for discharge rows awaiting clearance.
  ///
  /// In en, this message translates to:
  /// **'Clear pending items'**
  String get dischargeNextActionClearance;

  /// Next action label for discharge rows awaiting a plan.
  ///
  /// In en, this message translates to:
  /// **'Start summary'**
  String get dischargeNextActionStartPlan;

  /// Discharge patient demographic age and sex label.
  ///
  /// In en, this message translates to:
  /// **'{age} / {sex}'**
  String dischargePatientAgeSexLabel(String age, String sex);

  /// Snackbar shown after a discharge workflow update succeeds.
  ///
  /// In en, this message translates to:
  /// **'Discharge workflow updated.'**
  String get dischargeSavedMessage;

  /// Printable discharge report title.
  ///
  /// In en, this message translates to:
  /// **'Discharge summary'**
  String get dischargeReportTitle;

  /// Printable discharge report patient label.
  ///
  /// In en, this message translates to:
  /// **'Patient'**
  String get dischargeReportPatientLabel;

  /// Printable discharge report patient number label.
  ///
  /// In en, this message translates to:
  /// **'Patient number'**
  String get dischargeReportPatientNoLabel;

  /// Printable discharge report admission label.
  ///
  /// In en, this message translates to:
  /// **'Admission'**
  String get dischargeReportAdmissionLabel;

  /// Printable discharge report location label.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get dischargeReportLocationLabel;

  /// Printable discharge report generated date label.
  ///
  /// In en, this message translates to:
  /// **'Generated'**
  String get dischargeReportGeneratedLabel;

  /// Printable discharge report doctor signature label.
  ///
  /// In en, this message translates to:
  /// **'Doctor signature'**
  String get dischargeDoctorSignatureLabel;

  /// Printable discharge report nurse signature label.
  ///
  /// In en, this message translates to:
  /// **'Nurse signature'**
  String get dischargeNurseSignatureLabel;

  /// Printable discharge report footer.
  ///
  /// In en, this message translates to:
  /// **'Generated from confirmed discharge workflow data.'**
  String get dischargeReportFooter;

  /// Discharge workspace loading title.
  ///
  /// In en, this message translates to:
  /// **'Loading discharge workspace'**
  String get dischargeLoadingTitle;

  /// Discharge workspace loading body.
  ///
  /// In en, this message translates to:
  /// **'Loading discharge queue and reference data.'**
  String get dischargeLoadingBody;

  /// Discharge workspace load error title.
  ///
  /// In en, this message translates to:
  /// **'Discharge workspace unavailable'**
  String get dischargeLoadErrorTitle;

  /// Discharge workspace load error body.
  ///
  /// In en, this message translates to:
  /// **'The discharge queue could not be loaded. Refresh to try again.'**
  String get dischargeLoadErrorBody;

  /// Localized text for radiologyTitle.
  ///
  /// In en, this message translates to:
  /// **'Radiology'**
  String get radiologyTitle;

  /// Localized text for radiologyDescription.
  ///
  /// In en, this message translates to:
  /// **'Manage imaging requests, modality worklists, study capture, PACS links, reporting, and release.'**
  String get radiologyDescription;

  /// Localized text for radiologyLoadingTitle.
  ///
  /// In en, this message translates to:
  /// **'Loading radiology workspace'**
  String get radiologyLoadingTitle;

  /// Localized text for radiologyLoadingBody.
  ///
  /// In en, this message translates to:
  /// **'Loading imaging orders, reports, studies, and reference data.'**
  String get radiologyLoadingBody;

  /// Localized text for radiologyLiveStatus.
  ///
  /// In en, this message translates to:
  /// **'Live sync'**
  String get radiologyLiveStatus;

  /// Localized text for radiologySavingStatus.
  ///
  /// In en, this message translates to:
  /// **'Saving'**
  String get radiologySavingStatus;

  /// Localized text for radiologySavedMessage.
  ///
  /// In en, this message translates to:
  /// **'Radiology workflow updated.'**
  String get radiologySavedMessage;

  /// Localized text for radiologyRequestImagingAction.
  ///
  /// In en, this message translates to:
  /// **'Request imaging'**
  String get radiologyRequestImagingAction;

  /// Localized text for radiologyRefreshCatalogAction.
  ///
  /// In en, this message translates to:
  /// **'Refresh catalog'**
  String get radiologyRefreshCatalogAction;

  /// Localized text for radiologyTotalOrdersSummaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Total orders'**
  String get radiologyTotalOrdersSummaryLabel;

  /// Localized text for radiologyWaitingImagingSummaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Waiting imaging'**
  String get radiologyWaitingImagingSummaryLabel;

  /// Localized text for radiologyReportingSummaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Reporting'**
  String get radiologyReportingSummaryLabel;

  /// Localized text for radiologyReleasedSummaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Released'**
  String get radiologyReleasedSummaryLabel;

  /// Localized text for radiologyUnsyncedSummaryLabel.
  ///
  /// In en, this message translates to:
  /// **'PACS sync due'**
  String get radiologyUnsyncedSummaryLabel;

  /// Localized text for radiologyFiltersLabel.
  ///
  /// In en, this message translates to:
  /// **'Radiology filters'**
  String get radiologyFiltersLabel;

  /// Localized text for radiologySearchLabel.
  ///
  /// In en, this message translates to:
  /// **'Search radiology'**
  String get radiologySearchLabel;

  /// Localized text for radiologySearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search patient, order, encounter, study, report, or PACS text'**
  String get radiologySearchHint;

  /// Localized text for radiologyOrderDateFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Order date'**
  String get radiologyOrderDateFilterLabel;

  /// Localized text for radiologyPickOrderDateAction.
  ///
  /// In en, this message translates to:
  /// **'Pick order date'**
  String get radiologyPickOrderDateAction;

  /// Localized text for radiologyStageFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Stage'**
  String get radiologyStageFilterLabel;

  /// Localized text for radiologyStatusFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get radiologyStatusFilterLabel;

  /// Localized text for radiologyModalityFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Modality'**
  String get radiologyModalityFilterLabel;

  /// Localized text for radiologyClearFiltersAction.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get radiologyClearFiltersAction;

  /// Localized text for radiologyWorklistTitle.
  ///
  /// In en, this message translates to:
  /// **'Imaging worklist'**
  String get radiologyWorklistTitle;

  /// Localized text for radiologyWorklistDescription.
  ///
  /// In en, this message translates to:
  /// **'Backend-backed imaging orders with modality workflow and report status.'**
  String get radiologyWorklistDescription;

  /// Localized text for radiologyPreviousPageLabel.
  ///
  /// In en, this message translates to:
  /// **'Previous orders'**
  String get radiologyPreviousPageLabel;

  /// Localized text for radiologyNextPageLabel.
  ///
  /// In en, this message translates to:
  /// **'Next orders'**
  String get radiologyNextPageLabel;

  /// No description provided for @radiologyPageLabel.
  ///
  /// In en, this message translates to:
  /// **'Showing {from}-{to} of {total}'**
  String radiologyPageLabel(int from, int to, int total);

  /// Localized text for radiologyNoOrdersTitle.
  ///
  /// In en, this message translates to:
  /// **'No radiology orders'**
  String get radiologyNoOrdersTitle;

  /// Localized text for radiologyNoOrdersBody.
  ///
  /// In en, this message translates to:
  /// **'Orders matching this search and filter will appear here.'**
  String get radiologyNoOrdersBody;

  /// Localized text for radiologyPatientColumnLabel.
  ///
  /// In en, this message translates to:
  /// **'Patient'**
  String get radiologyPatientColumnLabel;

  /// Localized text for radiologyOrderColumnLabel.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get radiologyOrderColumnLabel;

  /// Localized text for radiologyStudyColumnLabel.
  ///
  /// In en, this message translates to:
  /// **'Study'**
  String get radiologyStudyColumnLabel;

  /// Localized text for radiologyPriorityColumnLabel.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get radiologyPriorityColumnLabel;

  /// Localized text for radiologyPaymentAuthColumnLabel.
  ///
  /// In en, this message translates to:
  /// **'Billing'**
  String get radiologyPaymentAuthColumnLabel;

  /// Localized text for radiologyStatusColumnLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get radiologyStatusColumnLabel;

  /// Localized text for radiologyNextActionColumnLabel.
  ///
  /// In en, this message translates to:
  /// **'Next action'**
  String get radiologyNextActionColumnLabel;

  /// Localized text for radiologyDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Radiology workflow'**
  String get radiologyDetailTitle;

  /// Localized text for radiologyDetailLoadingTitle.
  ///
  /// In en, this message translates to:
  /// **'Loading order'**
  String get radiologyDetailLoadingTitle;

  /// Localized text for radiologyDetailLoadingBody.
  ///
  /// In en, this message translates to:
  /// **'Loading selected imaging workflow.'**
  String get radiologyDetailLoadingBody;

  /// Localized text for radiologyNoSelectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Select an order'**
  String get radiologyNoSelectionTitle;

  /// Localized text for radiologyNoSelectionBody.
  ///
  /// In en, this message translates to:
  /// **'Choose an imaging request to view study, report, and release details.'**
  String get radiologyNoSelectionBody;

  /// Localized text for radiologyPatientContextLabel.
  ///
  /// In en, this message translates to:
  /// **'Radiology patient context'**
  String get radiologyPatientContextLabel;

  /// Localized text for radiologyBillingGateUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Billing gate unavailable'**
  String get radiologyBillingGateUnavailable;

  /// Localized text for radiologyEncounterLabel.
  ///
  /// In en, this message translates to:
  /// **'Encounter'**
  String get radiologyEncounterLabel;

  /// Localized text for radiologyOrderedAtLabel.
  ///
  /// In en, this message translates to:
  /// **'Ordered'**
  String get radiologyOrderedAtLabel;

  /// Localized text for radiologyModalityLabel.
  ///
  /// In en, this message translates to:
  /// **'Modality'**
  String get radiologyModalityLabel;

  /// Localized text for radiologyPaymentLabel.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get radiologyPaymentLabel;

  /// Localized text for radiologyAuthorizationLabel.
  ///
  /// In en, this message translates to:
  /// **'Authorization'**
  String get radiologyAuthorizationLabel;

  /// Localized text for radiologyAssignAction.
  ///
  /// In en, this message translates to:
  /// **'Assign'**
  String get radiologyAssignAction;

  /// Localized text for radiologyStartImagingAction.
  ///
  /// In en, this message translates to:
  /// **'Start imaging'**
  String get radiologyStartImagingAction;

  /// Localized text for radiologyStartDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Start imaging order'**
  String get radiologyStartDialogTitle;

  /// Localized text for radiologyNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get radiologyNotesLabel;

  /// Localized text for radiologyPerformStudyAction.
  ///
  /// In en, this message translates to:
  /// **'Perform study'**
  String get radiologyPerformStudyAction;

  /// Localized text for radiologyCancelOrderAction.
  ///
  /// In en, this message translates to:
  /// **'Cancel order'**
  String get radiologyCancelOrderAction;

  /// Localized text for radiologyRequestDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Request details'**
  String get radiologyRequestDetailsTitle;

  /// Localized text for radiologyStudyLabel.
  ///
  /// In en, this message translates to:
  /// **'Study'**
  String get radiologyStudyLabel;

  /// Localized text for radiologyPriorityLabel.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get radiologyPriorityLabel;

  /// Localized text for radiologyBodyRegionLabel.
  ///
  /// In en, this message translates to:
  /// **'Body region'**
  String get radiologyBodyRegionLabel;

  /// Localized text for radiologyLateralityLabel.
  ///
  /// In en, this message translates to:
  /// **'Laterality'**
  String get radiologyLateralityLabel;

  /// Localized text for radiologyClinicalNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'Clinical notes'**
  String get radiologyClinicalNotesLabel;

  /// Localized text for radiologyReportSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get radiologyReportSectionTitle;

  /// Localized text for radiologyReportSectionBody.
  ///
  /// In en, this message translates to:
  /// **'Draft, finalize, attest, and amend radiology reports using backend workflow actions.'**
  String get radiologyReportSectionBody;

  /// Localized text for radiologyDraftReportAction.
  ///
  /// In en, this message translates to:
  /// **'Draft report'**
  String get radiologyDraftReportAction;

  /// Localized text for radiologyReleaseReportAction.
  ///
  /// In en, this message translates to:
  /// **'Release report'**
  String get radiologyReleaseReportAction;

  /// Localized text for radiologyRequestFinalizationAction.
  ///
  /// In en, this message translates to:
  /// **'Request finalization'**
  String get radiologyRequestFinalizationAction;

  /// Localized text for radiologyRequestFinalizationDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Request report finalization'**
  String get radiologyRequestFinalizationDialogTitle;

  /// Localized text for radiologyAttestFinalizationAction.
  ///
  /// In en, this message translates to:
  /// **'Attest finalization'**
  String get radiologyAttestFinalizationAction;

  /// Localized text for radiologyAttestFinalizationDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Attest report finalization'**
  String get radiologyAttestFinalizationDialogTitle;

  /// Localized text for radiologyAddendumAction.
  ///
  /// In en, this message translates to:
  /// **'Add addendum'**
  String get radiologyAddendumAction;

  /// Localized text for radiologyPendingAttestationLabel.
  ///
  /// In en, this message translates to:
  /// **'Pending attestation'**
  String get radiologyPendingAttestationLabel;

  /// Localized text for radiologyNoReportTitle.
  ///
  /// In en, this message translates to:
  /// **'No report yet'**
  String get radiologyNoReportTitle;

  /// Localized text for radiologyNoReportBody.
  ///
  /// In en, this message translates to:
  /// **'A draft or final report will appear after reporting begins.'**
  String get radiologyNoReportBody;

  /// Localized text for radiologyReportedAtLabel.
  ///
  /// In en, this message translates to:
  /// **'Reported'**
  String get radiologyReportedAtLabel;

  /// Localized text for radiologyGeneratedReportPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Generated report preview'**
  String get radiologyGeneratedReportPreviewTitle;

  /// Localized text for radiologyEmptyReportBody.
  ///
  /// In en, this message translates to:
  /// **'No report text captured.'**
  String get radiologyEmptyReportBody;

  /// Localized text for radiologyStudiesAssetsTitle.
  ///
  /// In en, this message translates to:
  /// **'Studies and assets'**
  String get radiologyStudiesAssetsTitle;

  /// Localized text for radiologyStudiesAssetsBody.
  ///
  /// In en, this message translates to:
  /// **'Track imaging studies, uploaded assets, and PACS synchronization state.'**
  String get radiologyStudiesAssetsBody;

  /// Localized text for radiologyNoStudiesTitle.
  ///
  /// In en, this message translates to:
  /// **'No imaging studies'**
  String get radiologyNoStudiesTitle;

  /// Localized text for radiologyNoStudiesBody.
  ///
  /// In en, this message translates to:
  /// **'Studies will appear after imaging is performed.'**
  String get radiologyNoStudiesBody;

  /// Localized text for radiologySyncPacsAction.
  ///
  /// In en, this message translates to:
  /// **'Sync PACS'**
  String get radiologySyncPacsAction;

  /// Localized text for radiologyAssetsLabel.
  ///
  /// In en, this message translates to:
  /// **'Assets'**
  String get radiologyAssetsLabel;

  /// Localized text for radiologyNoAssetsLabel.
  ///
  /// In en, this message translates to:
  /// **'No assets recorded'**
  String get radiologyNoAssetsLabel;

  /// Localized text for radiologyPacsLinksLabel.
  ///
  /// In en, this message translates to:
  /// **'PACS links'**
  String get radiologyPacsLinksLabel;

  /// Localized text for radiologyNoPacsLinksLabel.
  ///
  /// In en, this message translates to:
  /// **'No PACS links recorded'**
  String get radiologyNoPacsLinksLabel;

  /// Localized text for radiologyDoctorReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Doctor review'**
  String get radiologyDoctorReviewTitle;

  /// Localized text for radiologyDoctorReviewReleasedBody.
  ///
  /// In en, this message translates to:
  /// **'The latest report is released for clinical review.'**
  String get radiologyDoctorReviewReleasedBody;

  /// Localized text for radiologyDoctorReviewPendingBody.
  ///
  /// In en, this message translates to:
  /// **'Clinical review becomes available after report release.'**
  String get radiologyDoctorReviewPendingBody;

  /// Localized text for radiologyDoctorReviewReadyLabel.
  ///
  /// In en, this message translates to:
  /// **'Ready for review'**
  String get radiologyDoctorReviewReadyLabel;

  /// Localized text for radiologyDoctorReviewPendingLabel.
  ///
  /// In en, this message translates to:
  /// **'Pending release'**
  String get radiologyDoctorReviewPendingLabel;

  /// Localized text for radiologyTimelineTitle.
  ///
  /// In en, this message translates to:
  /// **'Workflow timeline'**
  String get radiologyTimelineTitle;

  /// Localized text for radiologyNoTimelineTitle.
  ///
  /// In en, this message translates to:
  /// **'No timeline events'**
  String get radiologyNoTimelineTitle;

  /// Localized text for radiologyNoTimelineBody.
  ///
  /// In en, this message translates to:
  /// **'Workflow events will appear as the order progresses.'**
  String get radiologyNoTimelineBody;

  /// Localized text for radiologyBackendGapsTitle.
  ///
  /// In en, this message translates to:
  /// **'Backend gaps'**
  String get radiologyBackendGapsTitle;

  /// Localized text for radiologyBackendGapsBody.
  ///
  /// In en, this message translates to:
  /// **'These controls are shown as unavailable until backend support is added.'**
  String get radiologyBackendGapsBody;

  /// Localized text for radiologyGapSchedulingTitle.
  ///
  /// In en, this message translates to:
  /// **'Room scheduling'**
  String get radiologyGapSchedulingTitle;

  /// Localized text for radiologyGapBackendSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Not exposed by API'**
  String get radiologyGapBackendSubtitle;

  /// Localized text for radiologyGapSchedulingBody.
  ///
  /// In en, this message translates to:
  /// **'The current radiology API has no room or appointment assignment fields.'**
  String get radiologyGapSchedulingBody;

  /// Localized text for radiologyGapBillingTitle.
  ///
  /// In en, this message translates to:
  /// **'Billing authorization'**
  String get radiologyGapBillingTitle;

  /// Localized text for radiologyGapBillingBody.
  ///
  /// In en, this message translates to:
  /// **'Payment and authorization status is displayed only when returned by the backend.'**
  String get radiologyGapBillingBody;

  /// Localized text for radiologyCreateOrderDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Request imaging'**
  String get radiologyCreateOrderDialogTitle;

  /// Localized text for radiologyReferenceSearchLabel.
  ///
  /// In en, this message translates to:
  /// **'Catalog search'**
  String get radiologyReferenceSearchLabel;

  /// Localized text for radiologyReferenceSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search test code, name, modality, or body region'**
  String get radiologyReferenceSearchHint;

  /// Localized text for radiologySearchReferenceAction.
  ///
  /// In en, this message translates to:
  /// **'Search catalog'**
  String get radiologySearchReferenceAction;

  /// Localized text for radiologyPatientLabel.
  ///
  /// In en, this message translates to:
  /// **'Patient'**
  String get radiologyPatientLabel;

  /// No description provided for @radiologyFieldRequiredLabel.
  ///
  /// In en, this message translates to:
  /// **'{label} is required.'**
  String radiologyFieldRequiredLabel(String label);

  /// Localized text for radiologyAssignDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Assign imaging order'**
  String get radiologyAssignDialogTitle;

  /// Localized text for radiologyAssigneeLabel.
  ///
  /// In en, this message translates to:
  /// **'Assignee'**
  String get radiologyAssigneeLabel;

  /// Localized text for radiologyPerformStudyDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Perform imaging study'**
  String get radiologyPerformStudyDialogTitle;

  /// Localized text for radiologyPerformedAtLabel.
  ///
  /// In en, this message translates to:
  /// **'Performed at'**
  String get radiologyPerformedAtLabel;

  /// Localized text for radiologyDateTimeHint.
  ///
  /// In en, this message translates to:
  /// **'YYYY-MM-DD HH:MM'**
  String get radiologyDateTimeHint;

  /// Localized text for radiologyReportDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Draft radiology report'**
  String get radiologyReportDialogTitle;

  /// Localized text for radiologyFindingsLabel.
  ///
  /// In en, this message translates to:
  /// **'Findings'**
  String get radiologyFindingsLabel;

  /// Localized text for radiologyImpressionLabel.
  ///
  /// In en, this message translates to:
  /// **'Impression'**
  String get radiologyImpressionLabel;

  /// Localized text for radiologyReportTextLabel.
  ///
  /// In en, this message translates to:
  /// **'Report text'**
  String get radiologyReportTextLabel;

  /// Localized text for radiologyReportTextHelper.
  ///
  /// In en, this message translates to:
  /// **'Leave blank to combine findings and impression.'**
  String get radiologyReportTextHelper;

  /// Localized text for radiologyReleaseReportDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Release report'**
  String get radiologyReleaseReportDialogTitle;

  /// Localized text for radiologyReleaseNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'Release notes'**
  String get radiologyReleaseNotesLabel;

  /// Localized text for radiologyFinalizationStatementLabel.
  ///
  /// In en, this message translates to:
  /// **'Finalization statement'**
  String get radiologyFinalizationStatementLabel;

  /// Localized text for radiologyFinalizationReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get radiologyFinalizationReasonLabel;

  /// Localized text for radiologyAddendumDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Add report addendum'**
  String get radiologyAddendumDialogTitle;

  /// Localized text for radiologyAddendumTextLabel.
  ///
  /// In en, this message translates to:
  /// **'Addendum text'**
  String get radiologyAddendumTextLabel;

  /// Localized text for radiologyCancelDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel radiology order'**
  String get radiologyCancelDialogTitle;

  /// Localized text for radiologyCancellationReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Cancellation reason'**
  String get radiologyCancellationReasonLabel;

  /// Localized text for radiologyPacsSyncDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync study to PACS'**
  String get radiologyPacsSyncDialogTitle;

  /// Localized text for radiologyStudyUidLabel.
  ///
  /// In en, this message translates to:
  /// **'Study UID'**
  String get radiologyStudyUidLabel;

  /// Localized text for radiologyStageAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get radiologyStageAll;

  /// Localized text for radiologyStageOrdered.
  ///
  /// In en, this message translates to:
  /// **'Ordered'**
  String get radiologyStageOrdered;

  /// Localized text for radiologyStageProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get radiologyStageProcessing;

  /// Localized text for radiologyStageReporting.
  ///
  /// In en, this message translates to:
  /// **'Reporting'**
  String get radiologyStageReporting;

  /// Localized text for radiologyStageCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get radiologyStageCompleted;

  /// Localized text for radiologyStageCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get radiologyStageCancelled;

  /// Localized text for radiologyStatusOrdered.
  ///
  /// In en, this message translates to:
  /// **'Ordered'**
  String get radiologyStatusOrdered;

  /// Localized text for radiologyStatusInProcess.
  ///
  /// In en, this message translates to:
  /// **'In process'**
  String get radiologyStatusInProcess;

  /// Localized text for radiologyStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get radiologyStatusCompleted;

  /// Localized text for radiologyStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get radiologyStatusCancelled;

  /// Localized text for radiologyResultDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get radiologyResultDraft;

  /// Localized text for radiologyResultFinal.
  ///
  /// In en, this message translates to:
  /// **'Final'**
  String get radiologyResultFinal;

  /// Localized text for radiologyResultAmended.
  ///
  /// In en, this message translates to:
  /// **'Amended'**
  String get radiologyResultAmended;

  /// Localized text for radiologyModalityXray.
  ///
  /// In en, this message translates to:
  /// **'X-ray'**
  String get radiologyModalityXray;

  /// Localized text for radiologyModalityCt.
  ///
  /// In en, this message translates to:
  /// **'CT'**
  String get radiologyModalityCt;

  /// Localized text for radiologyModalityMri.
  ///
  /// In en, this message translates to:
  /// **'MRI'**
  String get radiologyModalityMri;

  /// Localized text for radiologyModalityUltrasound.
  ///
  /// In en, this message translates to:
  /// **'Ultrasound'**
  String get radiologyModalityUltrasound;

  /// Localized text for radiologyModalityPet.
  ///
  /// In en, this message translates to:
  /// **'PET'**
  String get radiologyModalityPet;

  /// Localized text for radiologyModalityEcg.
  ///
  /// In en, this message translates to:
  /// **'ECG'**
  String get radiologyModalityEcg;

  /// Localized text for radiologyModalityEcho.
  ///
  /// In en, this message translates to:
  /// **'Echo'**
  String get radiologyModalityEcho;

  /// Localized text for radiologyModalityEndo.
  ///
  /// In en, this message translates to:
  /// **'Endoscopy'**
  String get radiologyModalityEndo;

  /// Localized text for radiologyModalityGastro.
  ///
  /// In en, this message translates to:
  /// **'Gastro'**
  String get radiologyModalityGastro;

  /// Localized text for radiologyModalityOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get radiologyModalityOther;

  /// Localized text for radiologyNextActionConfirmBilling.
  ///
  /// In en, this message translates to:
  /// **'Confirm billing'**
  String get radiologyNextActionConfirmBilling;

  /// Localized text for radiologyNextActionStartImaging.
  ///
  /// In en, this message translates to:
  /// **'Start imaging'**
  String get radiologyNextActionStartImaging;

  /// Localized text for radiologyNextActionPerformStudy.
  ///
  /// In en, this message translates to:
  /// **'Perform study'**
  String get radiologyNextActionPerformStudy;

  /// Localized text for radiologyNextActionReleaseReport.
  ///
  /// In en, this message translates to:
  /// **'Release report'**
  String get radiologyNextActionReleaseReport;

  /// Localized text for radiologyNextActionDoctorReview.
  ///
  /// In en, this message translates to:
  /// **'Doctor review'**
  String get radiologyNextActionDoctorReview;

  /// Localized text for radiologyNextActionReportPending.
  ///
  /// In en, this message translates to:
  /// **'Report pending'**
  String get radiologyNextActionReportPending;

  /// Navigation destination label for the pharmacy workspace.
  ///
  /// In en, this message translates to:
  /// **'Pharmacy'**
  String get navigationPharmacyLabel;

  /// Navigation destination label for the lab workspace.
  ///
  /// In en, this message translates to:
  /// **'Lab'**
  String get navigationLabLabel;

  /// Navigation destination label for the radiology workspace.
  ///
  /// In en, this message translates to:
  /// **'Radiology'**
  String get navigationRadiologyLabel;

  /// Pharmacy workspace loading title.
  ///
  /// In en, this message translates to:
  /// **'Loading pharmacy workspace'**
  String get pharmacyLoadingTitle;

  /// Pharmacy workspace loading body.
  ///
  /// In en, this message translates to:
  /// **'Loading pharmacy orders, dispense state, and stock visibility.'**
  String get pharmacyLoadingBody;

  /// Pharmacy workspace title.
  ///
  /// In en, this message translates to:
  /// **'Pharmacy'**
  String get pharmacyTitle;

  /// Pharmacy workspace header description.
  ///
  /// In en, this message translates to:
  /// **'Manage prescriptions, dispense handoff, returns, and drug stock visibility from one queue.'**
  String get pharmacyDescription;

  /// Pharmacy workspace saving status.
  ///
  /// In en, this message translates to:
  /// **'Saving'**
  String get pharmacyStatusSaving;

  /// Pharmacy workspace live synchronization status.
  ///
  /// In en, this message translates to:
  /// **'Live sync'**
  String get pharmacyStatusLiveSync;

  /// Semantic label for pharmacy queue filters.
  ///
  /// In en, this message translates to:
  /// **'Pharmacy queue filters'**
  String get pharmacyFiltersSemanticLabel;

  /// Pharmacy queue search semantic label.
  ///
  /// In en, this message translates to:
  /// **'Search pharmacy'**
  String get pharmacySearchLabel;

  /// Pharmacy queue search hint.
  ///
  /// In en, this message translates to:
  /// **'Search patient, order, encounter, medication, or batch'**
  String get pharmacySearchHint;

  /// Pharmacy queue filter field label.
  ///
  /// In en, this message translates to:
  /// **'Queue filter'**
  String get pharmacyQueueFilterLabel;

  /// Pharmacy summary label for ready orders.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get pharmacySummaryReadyLabel;

  /// Pharmacy summary label for partially dispensed orders.
  ///
  /// In en, this message translates to:
  /// **'Partial'**
  String get pharmacySummaryPartialLabel;

  /// Pharmacy summary label for dispense batches awaiting attestation.
  ///
  /// In en, this message translates to:
  /// **'Awaiting attest'**
  String get pharmacySummaryAttestationLabel;

  /// Pharmacy summary label for completed orders.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get pharmacySummaryCompletedLabel;

  /// Pharmacy order queue panel title.
  ///
  /// In en, this message translates to:
  /// **'Order queue'**
  String get pharmacyQueuePanelTitle;

  /// Pharmacy order queue panel description.
  ///
  /// In en, this message translates to:
  /// **'Backend-backed pharmacy orders with dispense and return actions.'**
  String get pharmacyQueuePanelDescription;

  /// Empty pharmacy order queue title.
  ///
  /// In en, this message translates to:
  /// **'No pharmacy orders'**
  String get pharmacyNoOrdersTitle;

  /// Empty pharmacy order queue body.
  ///
  /// In en, this message translates to:
  /// **'Orders matching this search and filter will appear here.'**
  String get pharmacyNoOrdersBody;

  /// Pharmacy patient column label.
  ///
  /// In en, this message translates to:
  /// **'Patient'**
  String get pharmacyPatientColumnLabel;

  /// Pharmacy order column label.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get pharmacyOrderColumnLabel;

  /// Pharmacy items column label.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get pharmacyItemsColumnLabel;

  /// Pharmacy dispense progress column label.
  ///
  /// In en, this message translates to:
  /// **'Dispense'**
  String get pharmacyDispenseColumnLabel;

  /// Pharmacy status column label.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get pharmacyStatusColumnLabel;

  /// Status label for a pending dispense batch.
  ///
  /// In en, this message translates to:
  /// **'Pending batch'**
  String get pharmacyPendingBatchLabel;

  /// Pharmacy prescription detail loading title.
  ///
  /// In en, this message translates to:
  /// **'Loading prescription'**
  String get pharmacyDetailLoadingTitle;

  /// Pharmacy prescription detail loading body.
  ///
  /// In en, this message translates to:
  /// **'Loading medicines, dispense history, and workflow actions.'**
  String get pharmacyDetailLoadingBody;

  /// Title for the pharmacy prescription detail dialog.
  ///
  /// In en, this message translates to:
  /// **'Prescription detail'**
  String get pharmacyPrescriptionDetailTitle;

  /// Pharmacy detail empty title.
  ///
  /// In en, this message translates to:
  /// **'No prescription selected'**
  String get pharmacyNoSelectionTitle;

  /// Pharmacy detail empty body.
  ///
  /// In en, this message translates to:
  /// **'Select an order to review medicines, stock mapping, billing gate visibility, and dispense history.'**
  String get pharmacyNoSelectionBody;

  /// Pharmacy label for unavailable billing gate data.
  ///
  /// In en, this message translates to:
  /// **'Billing gate unavailable'**
  String get pharmacyBillingGateUnavailableTitle;

  /// Pharmacy patient context order field label.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get pharmacyOrderFieldLabel;

  /// Pharmacy patient context encounter field label.
  ///
  /// In en, this message translates to:
  /// **'Encounter'**
  String get pharmacyEncounterFieldLabel;

  /// Pharmacy patient context source field label.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get pharmacySourceFieldLabel;

  /// Pharmacy patient context ordered date field label.
  ///
  /// In en, this message translates to:
  /// **'Ordered'**
  String get pharmacyOrderedFieldLabel;

  /// Pharmacy action panel title.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get pharmacyActionsPanelTitle;

  /// Pharmacy dispense action label.
  ///
  /// In en, this message translates to:
  /// **'Dispense'**
  String get pharmacyDispenseAction;

  /// Pharmacy prepare dispense submit label.
  ///
  /// In en, this message translates to:
  /// **'Prepare dispense'**
  String get pharmacyPrepareDispenseAction;

  /// Pharmacy dispense attestation action label.
  ///
  /// In en, this message translates to:
  /// **'Attest'**
  String get pharmacyAttestAction;

  /// Pharmacy return action label.
  ///
  /// In en, this message translates to:
  /// **'Return'**
  String get pharmacyReturnAction;

  /// Pharmacy cancel order action label.
  ///
  /// In en, this message translates to:
  /// **'Cancel order'**
  String get pharmacyCancelOrderAction;

  /// Pharmacy print medication instructions action label.
  ///
  /// In en, this message translates to:
  /// **'Print instructions'**
  String get pharmacyPrintInstructionsAction;

  /// Pharmacy medication panel title.
  ///
  /// In en, this message translates to:
  /// **'Medicines'**
  String get pharmacyMedicationPanelTitle;

  /// Pharmacy medication panel description.
  ///
  /// In en, this message translates to:
  /// **'Drug, dose, route, frequency, duration, quantity, instructions, and dispense state.'**
  String get pharmacyMedicationPanelDescription;

  /// Empty pharmacy medicines title.
  ///
  /// In en, this message translates to:
  /// **'No medicines'**
  String get pharmacyNoMedicationTitle;

  /// Empty pharmacy medicines body.
  ///
  /// In en, this message translates to:
  /// **'This order has no medicines exposed by the pharmacy workflow API.'**
  String get pharmacyNoMedicationBody;

  /// Pharmacy medication column label.
  ///
  /// In en, this message translates to:
  /// **'Medication'**
  String get pharmacyMedicationColumnLabel;

  /// Pharmacy dose column label.
  ///
  /// In en, this message translates to:
  /// **'Dose'**
  String get pharmacyDoseColumnLabel;

  /// Pharmacy quantity column label.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get pharmacyQuantityColumnLabel;

  /// Pharmacy stock column label.
  ///
  /// In en, this message translates to:
  /// **'Stock'**
  String get pharmacyStockColumnLabel;

  /// Pharmacy backend gaps panel title.
  ///
  /// In en, this message translates to:
  /// **'Backend sync gaps'**
  String get pharmacyBackendGapsTitle;

  /// Pharmacy backend gaps panel body.
  ///
  /// In en, this message translates to:
  /// **'The confirmed API does not yet expose every state requested by the pharmacy plan.'**
  String get pharmacyBackendGapsBody;

  /// Pharmacy backend gap for payment authorization.
  ///
  /// In en, this message translates to:
  /// **'Payment and authorization status is not present on pharmacy order workflow responses.'**
  String get pharmacyGapPaymentAuthorization;

  /// Pharmacy backend gap for batch availability.
  ///
  /// In en, this message translates to:
  /// **'Drug batch availability is not attached to order items; only inventory item mapping is available.'**
  String get pharmacyGapBatchAvailability;

  /// Pharmacy backend gap for hold and substitution actions.
  ///
  /// In en, this message translates to:
  /// **'Hold and drug substitution actions do not have confirmed pharmacy workflow routes.'**
  String get pharmacyGapHoldSubstitution;

  /// Pharmacy backend gap for report templates.
  ///
  /// In en, this message translates to:
  /// **'Medication printouts use local HTML until report-template routes expose pharmacy templates.'**
  String get pharmacyGapReportTemplates;

  /// Pharmacy timeline panel title.
  ///
  /// In en, this message translates to:
  /// **'Dispense history'**
  String get pharmacyTimelinePanelTitle;

  /// Pharmacy timeline panel description.
  ///
  /// In en, this message translates to:
  /// **'Order placement, prepare, attest, dispense, and return events from the workflow API.'**
  String get pharmacyTimelinePanelDescription;

  /// Pharmacy empty timeline body.
  ///
  /// In en, this message translates to:
  /// **'No dispense history is available yet.'**
  String get pharmacyNoTimelineBody;

  /// Pharmacy drug and stock panel title.
  ///
  /// In en, this message translates to:
  /// **'Formulary and stock'**
  String get pharmacyDrugPanelTitle;

  /// Pharmacy drug and stock panel description.
  ///
  /// In en, this message translates to:
  /// **'Search configured drugs and review aggregate stock visibility from the confirmed pharmacy API.'**
  String get pharmacyDrugPanelDescription;

  /// Semantic label for pharmacy drug stock filters.
  ///
  /// In en, this message translates to:
  /// **'Drug stock filters'**
  String get pharmacyDrugFiltersSemanticLabel;

  /// Pharmacy drug search semantic label.
  ///
  /// In en, this message translates to:
  /// **'Search drugs'**
  String get pharmacyDrugSearchLabel;

  /// Pharmacy drug search hint.
  ///
  /// In en, this message translates to:
  /// **'Search drug, code, form, or strength'**
  String get pharmacyDrugSearchHint;

  /// Pharmacy stock status filter label.
  ///
  /// In en, this message translates to:
  /// **'Stock status'**
  String get pharmacyStockStatusFilterLabel;

  /// Empty pharmacy drug search title.
  ///
  /// In en, this message translates to:
  /// **'No drugs found'**
  String get pharmacyNoDrugsTitle;

  /// Empty pharmacy drug search body.
  ///
  /// In en, this message translates to:
  /// **'Matching formulary drugs and stock rows will appear here.'**
  String get pharmacyNoDrugsBody;

  /// Pharmacy drug column label.
  ///
  /// In en, this message translates to:
  /// **'Drug'**
  String get pharmacyDrugColumnLabel;

  /// Pharmacy available quantity column label.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get pharmacyAvailableColumnLabel;

  /// Pharmacy stock status column label.
  ///
  /// In en, this message translates to:
  /// **'Stock status'**
  String get pharmacyStockStatusColumnLabel;

  /// Pharmacy available quantity label.
  ///
  /// In en, this message translates to:
  /// **'{quantity} available'**
  String pharmacyAvailableQuantityLabel(String quantity);

  /// Pharmacy dispense dialog title.
  ///
  /// In en, this message translates to:
  /// **'Prepare dispense'**
  String get pharmacyDispenseDialogTitle;

  /// Pharmacy attest dialog title.
  ///
  /// In en, this message translates to:
  /// **'Attest dispense'**
  String get pharmacyAttestDialogTitle;

  /// Pharmacy attest dialog body.
  ///
  /// In en, this message translates to:
  /// **'Confirm the prepared batch after physical medication handoff.'**
  String get pharmacyAttestDialogBody;

  /// Pharmacy return dialog title.
  ///
  /// In en, this message translates to:
  /// **'Return medicines'**
  String get pharmacyReturnDialogTitle;

  /// Pharmacy return dialog body.
  ///
  /// In en, this message translates to:
  /// **'Record returned quantities so order status and stock are synchronized.'**
  String get pharmacyReturnDialogBody;

  /// Pharmacy cancel dialog title.
  ///
  /// In en, this message translates to:
  /// **'Cancel pharmacy order'**
  String get pharmacyCancelDialogTitle;

  /// Pharmacy cancel dialog body.
  ///
  /// In en, this message translates to:
  /// **'Cancel only when the order should no longer be dispensed.'**
  String get pharmacyCancelDialogBody;

  /// Pharmacy billing gate unavailable body.
  ///
  /// In en, this message translates to:
  /// **'Payment clearance is visible as a backend gap because the pharmacy workflow response does not include invoice or payment state.'**
  String get pharmacyBillingGateUnavailableBody;

  /// Pharmacy dispense batch reference field label.
  ///
  /// In en, this message translates to:
  /// **'Batch reference'**
  String get pharmacyBatchRefLabel;

  /// Pharmacy statement field label.
  ///
  /// In en, this message translates to:
  /// **'Statement'**
  String get pharmacyStatementLabel;

  /// Pharmacy reason field label.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get pharmacyReasonLabel;

  /// Pharmacy notes field label.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get pharmacyNotesLabel;

  /// Pharmacy quantity field label.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get pharmacyQuantityFieldLabel;

  /// Pharmacy inventory item selector label.
  ///
  /// In en, this message translates to:
  /// **'Inventory item'**
  String get pharmacyInventoryItemLabel;

  /// Pharmacy quantity validation label.
  ///
  /// In en, this message translates to:
  /// **'Enter a quantity from 0 to {maximum}.'**
  String pharmacyQuantityValidationLabel(String maximum);

  /// Pharmacy success snackbar message.
  ///
  /// In en, this message translates to:
  /// **'Pharmacy workflow updated.'**
  String get pharmacySavedMessage;

  /// Pharmacy all orders filter label.
  ///
  /// In en, this message translates to:
  /// **'All orders'**
  String get pharmacyFilterAll;

  /// Pharmacy ready filter label.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get pharmacyFilterReady;

  /// Pharmacy partial filter label.
  ///
  /// In en, this message translates to:
  /// **'Partial'**
  String get pharmacyFilterPartial;

  /// Pharmacy completed filter label.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get pharmacyFilterCompleted;

  /// Pharmacy cancelled filter label.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get pharmacyFilterCancelled;

  /// Pharmacy unsupported pending payment filter label.
  ///
  /// In en, this message translates to:
  /// **'Pending payment - backend gap'**
  String get pharmacyFilterPendingPayment;

  /// Pharmacy unsupported partial stock filter label.
  ///
  /// In en, this message translates to:
  /// **'Partial stock - backend gap'**
  String get pharmacyFilterPartialStock;

  /// Pharmacy unsupported urgent filter label.
  ///
  /// In en, this message translates to:
  /// **'Urgent - backend gap'**
  String get pharmacyFilterUrgent;

  /// Pharmacy unsupported discharge filter label.
  ///
  /// In en, this message translates to:
  /// **'Discharge - backend gap'**
  String get pharmacyFilterDischarge;

  /// Pharmacy in stock label.
  ///
  /// In en, this message translates to:
  /// **'In stock'**
  String get pharmacyStockInStock;

  /// Pharmacy almost out of stock label.
  ///
  /// In en, this message translates to:
  /// **'Almost out'**
  String get pharmacyStockAlmostOut;

  /// Pharmacy low stock label.
  ///
  /// In en, this message translates to:
  /// **'Low stock'**
  String get pharmacyStockLow;

  /// Pharmacy out of stock label.
  ///
  /// In en, this message translates to:
  /// **'Out of stock'**
  String get pharmacyStockOut;

  /// Pharmacy unknown stock label.
  ///
  /// In en, this message translates to:
  /// **'Stock unknown'**
  String get pharmacyStockUnknown;

  /// Pharmacy unknown status label.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get pharmacyUnknownStatusLabel;

  /// Pharmacy unavailable stock mapping label.
  ///
  /// In en, this message translates to:
  /// **'Stock mapping unavailable'**
  String get pharmacyStockMappingUnavailable;

  /// Pharmacy medication timeline event label.
  ///
  /// In en, this message translates to:
  /// **'{medication} {status}'**
  String pharmacyTimelineMedicationEvent(String medication, String status);

  /// Pharmacy batch timeline event label.
  ///
  /// In en, this message translates to:
  /// **'{type} {batch}'**
  String pharmacyTimelineBatchEvent(String type, String batch);

  /// Pharmacy order placed timeline label.
  ///
  /// In en, this message translates to:
  /// **'Order placed'**
  String get pharmacyTimelineOrderPlaced;

  /// Pharmacy dispense progress label.
  ///
  /// In en, this message translates to:
  /// **'{dispensed} / {prescribed}'**
  String pharmacyDispenseProgressLabel(String dispensed, String prescribed);

  /// Pharmacy medication printout title.
  ///
  /// In en, this message translates to:
  /// **'Medication instructions'**
  String get pharmacyReportTitle;

  /// Pharmacy report patient label.
  ///
  /// In en, this message translates to:
  /// **'Patient'**
  String get pharmacyReportPatientLabel;

  /// Pharmacy report order label.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get pharmacyReportOrderLabel;

  /// Pharmacy report generated label.
  ///
  /// In en, this message translates to:
  /// **'Generated'**
  String get pharmacyReportGeneratedLabel;

  /// Pharmacy report footer.
  ///
  /// In en, this message translates to:
  /// **'Generated from confirmed pharmacy workflow data.'**
  String get pharmacyReportFooter;

  /// Localized text for navigationClaimsLabel.
  ///
  /// In en, this message translates to:
  /// **'Claims'**
  String get navigationClaimsLabel;

  /// Localized text for claimsWorkspaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Insurance and claims'**
  String get claimsWorkspaceTitle;

  /// Localized text for claimsWorkspaceDescription.
  ///
  /// In en, this message translates to:
  /// **'Manage authorizations, payer responses, claim submission, resubmission, and invoice follow-up.'**
  String get claimsWorkspaceDescription;

  /// Localized text for claimsOperationalStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Billing synced'**
  String get claimsOperationalStatusLabel;

  /// Localized text for claimsNeedsAttentionStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get claimsNeedsAttentionStatusLabel;

  /// Localized text for claimsLoadingTitle.
  ///
  /// In en, this message translates to:
  /// **'Loading claims'**
  String get claimsLoadingTitle;

  /// Localized text for claimsLoadingBody.
  ///
  /// In en, this message translates to:
  /// **'Fetching authorization and claim queues.'**
  String get claimsLoadingBody;

  /// Localized text for claimsLoadErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Claims unavailable'**
  String get claimsLoadErrorTitle;

  /// Localized text for claimsLoadErrorBody.
  ///
  /// In en, this message translates to:
  /// **'The claims workspace could not be loaded.'**
  String get claimsLoadErrorBody;

  /// Localized text for claimsRequestAuthorizationAction.
  ///
  /// In en, this message translates to:
  /// **'Request authorization'**
  String get claimsRequestAuthorizationAction;

  /// Localized text for claimsPrepareClaimAction.
  ///
  /// In en, this message translates to:
  /// **'Prepare claim'**
  String get claimsPrepareClaimAction;

  /// Localized text for claimsAuthorizationPendingSummaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Auth pending'**
  String get claimsAuthorizationPendingSummaryLabel;

  /// Localized text for claimsAuthorizationApprovedSummaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Auth approved'**
  String get claimsAuthorizationApprovedSummaryLabel;

  /// Localized text for claimsSubmittedSummaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get claimsSubmittedSummaryLabel;

  /// Localized text for claimsRejectedSummaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get claimsRejectedSummaryLabel;

  /// Localized text for claimsApprovedSummaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get claimsApprovedSummaryLabel;

  /// Localized text for claimsPaidClosedSummaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Paid/closed'**
  String get claimsPaidClosedSummaryLabel;

  /// Localized text for claimsSearchSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Search claims and authorizations'**
  String get claimsSearchSemanticLabel;

  /// Localized text for claimsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search reference, coverage, invoice, or patient'**
  String get claimsSearchHint;

  /// Localized text for claimsQueueFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get claimsQueueFilterLabel;

  /// Localized text for claimsWorklistTitle.
  ///
  /// In en, this message translates to:
  /// **'Claims worklist'**
  String get claimsWorklistTitle;

  /// Localized text for claimsWorklistDescription.
  ///
  /// In en, this message translates to:
  /// **'Review pre-authorizations and claim records backed by the billing API.'**
  String get claimsWorklistDescription;

  /// Localized text for claimsPreviousPageLabel.
  ///
  /// In en, this message translates to:
  /// **'Previous claims page'**
  String get claimsPreviousPageLabel;

  /// Localized text for claimsNextPageLabel.
  ///
  /// In en, this message translates to:
  /// **'Next claims page'**
  String get claimsNextPageLabel;

  /// No description provided for @claimsPageLabel.
  ///
  /// In en, this message translates to:
  /// **'{start} - {end} of {total}'**
  String claimsPageLabel(int start, int end, int total);

  /// Localized text for claimsEmptyQueueTitle.
  ///
  /// In en, this message translates to:
  /// **'No claims found'**
  String get claimsEmptyQueueTitle;

  /// Localized text for claimsEmptyQueueBody.
  ///
  /// In en, this message translates to:
  /// **'No authorization or claim records match the current queue.'**
  String get claimsEmptyQueueBody;

  /// Localized text for claimsTypeColumnLabel.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get claimsTypeColumnLabel;

  /// Localized text for claimsReferenceColumnLabel.
  ///
  /// In en, this message translates to:
  /// **'Reference'**
  String get claimsReferenceColumnLabel;

  /// Localized text for claimsCoverageColumnLabel.
  ///
  /// In en, this message translates to:
  /// **'Coverage'**
  String get claimsCoverageColumnLabel;

  /// Localized text for claimsInvoiceColumnLabel.
  ///
  /// In en, this message translates to:
  /// **'Invoice'**
  String get claimsInvoiceColumnLabel;

  /// Localized text for claimsStatusColumnLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get claimsStatusColumnLabel;

  /// Localized text for claimsTimelineColumnLabel.
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get claimsTimelineColumnLabel;

  /// No description provided for @claimsMobileQueueSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Coverage {coverage} | Link {link}'**
  String claimsMobileQueueSubtitle(String coverage, String link);

  /// Localized text for claimsDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Claim detail'**
  String get claimsDetailTitle;

  /// Localized text for claimsDetailLoadingTitle.
  ///
  /// In en, this message translates to:
  /// **'Loading detail'**
  String get claimsDetailLoadingTitle;

  /// Localized text for claimsDetailLoadingBody.
  ///
  /// In en, this message translates to:
  /// **'Fetching payer, invoice, and coverage context.'**
  String get claimsDetailLoadingBody;

  /// Localized text for claimsNoSelectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Select a record'**
  String get claimsNoSelectionTitle;

  /// Localized text for claimsNoSelectionBody.
  ///
  /// In en, this message translates to:
  /// **'Choose a row to review coverage, billing impact, and next actions.'**
  String get claimsNoSelectionBody;

  /// Localized text for claimsPrintStatementAction.
  ///
  /// In en, this message translates to:
  /// **'Print statement'**
  String get claimsPrintStatementAction;

  /// Localized text for claimsPatientContextLabel.
  ///
  /// In en, this message translates to:
  /// **'Claim patient and coverage context'**
  String get claimsPatientContextLabel;

  /// Localized text for claimsCoverageFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Coverage'**
  String get claimsCoverageFieldLabel;

  /// Localized text for claimsPayerFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Payer'**
  String get claimsPayerFieldLabel;

  /// Localized text for claimsUnknownPayerLabel.
  ///
  /// In en, this message translates to:
  /// **'Payer not recorded'**
  String get claimsUnknownPayerLabel;

  /// Localized text for claimsInvoiceFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Invoice'**
  String get claimsInvoiceFieldLabel;

  /// Localized text for claimsAmountFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get claimsAmountFieldLabel;

  /// Localized text for claimsBillingImpactTitle.
  ///
  /// In en, this message translates to:
  /// **'Billing impact'**
  String get claimsBillingImpactTitle;

  /// Localized text for claimsAuthorizationBillingImpactBody.
  ///
  /// In en, this message translates to:
  /// **'Service clearance should wait for payer response where authorization is required.'**
  String get claimsAuthorizationBillingImpactBody;

  /// Localized text for claimsCoveragePercentLabel.
  ///
  /// In en, this message translates to:
  /// **'Coverage'**
  String get claimsCoveragePercentLabel;

  /// No description provided for @claimsCoveragePercentValue.
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String claimsCoveragePercentValue(String percent);

  /// Localized text for claimsInvoiceStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Invoice status'**
  String get claimsInvoiceStatusLabel;

  /// Localized text for claimsPatientBalanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Patient balance'**
  String get claimsPatientBalanceLabel;

  /// Localized text for claimsBillingInvoiceUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'Invoice details are not available, so the patient balance cannot be confirmed here.'**
  String get claimsBillingInvoiceUnavailableBody;

  /// Localized text for claimsBillingAuthorizedBody.
  ///
  /// In en, this message translates to:
  /// **'Authorized by payer. Confirm any uncovered balance before final clearance.'**
  String get claimsBillingAuthorizedBody;

  /// Localized text for claimsBillingPaidBody.
  ///
  /// In en, this message translates to:
  /// **'Claim is paid or closed. Billing can use the latest invoice status for follow-up.'**
  String get claimsBillingPaidBody;

  /// Localized text for claimsBillingRejectedBody.
  ///
  /// In en, this message translates to:
  /// **'Rejected by payer. Billing staff should prepare resubmission or patient balance follow-up.'**
  String get claimsBillingRejectedBody;

  /// Localized text for claimsBillingPendingBody.
  ///
  /// In en, this message translates to:
  /// **'Pending payer response. Keep billing clearance visible until the response is recorded.'**
  String get claimsBillingPendingBody;

  /// Localized text for claimsBillingNeutralBody.
  ///
  /// In en, this message translates to:
  /// **'Review invoice and payer state before clearing the service.'**
  String get claimsBillingNeutralBody;

  /// Localized text for claimsRequiredDocumentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Required documents'**
  String get claimsRequiredDocumentsTitle;

  /// Localized text for claimsRequiredDocumentsBody.
  ///
  /// In en, this message translates to:
  /// **'Document readiness is shown from available claim, invoice, and coverage data.'**
  String get claimsRequiredDocumentsBody;

  /// Localized text for claimsDocumentInvoiceSummary.
  ///
  /// In en, this message translates to:
  /// **'Invoice summary'**
  String get claimsDocumentInvoiceSummary;

  /// Localized text for claimsDocumentCoveragePlan.
  ///
  /// In en, this message translates to:
  /// **'Coverage plan'**
  String get claimsDocumentCoveragePlan;

  /// Localized text for claimsDocumentPayerResponse.
  ///
  /// In en, this message translates to:
  /// **'Payer response'**
  String get claimsDocumentPayerResponse;

  /// Localized text for claimsTimelineTitle.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get claimsTimelineTitle;

  /// Localized text for claimsTimelineDescription.
  ///
  /// In en, this message translates to:
  /// **'Authorization, submission, and response timestamps from the backend.'**
  String get claimsTimelineDescription;

  /// Localized text for claimsTimelineAuthorizationRequested.
  ///
  /// In en, this message translates to:
  /// **'Authorization requested'**
  String get claimsTimelineAuthorizationRequested;

  /// Localized text for claimsTimelineAuthorizationResponded.
  ///
  /// In en, this message translates to:
  /// **'Authorization responded'**
  String get claimsTimelineAuthorizationResponded;

  /// Localized text for claimsTimelineClaimSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Claim submitted'**
  String get claimsTimelineClaimSubmitted;

  /// Localized text for claimsTimelineCurrentStatus.
  ///
  /// In en, this message translates to:
  /// **'Current status'**
  String get claimsTimelineCurrentStatus;

  /// Localized text for claimsBackendGapTitle.
  ///
  /// In en, this message translates to:
  /// **'Backend gaps'**
  String get claimsBackendGapTitle;

  /// Localized text for claimsBackendGapDescription.
  ///
  /// In en, this message translates to:
  /// **'These items are shown as integration gaps because the current API does not expose dedicated endpoints for them.'**
  String get claimsBackendGapDescription;

  /// Localized text for claimsBackendGapDraftTitle.
  ///
  /// In en, this message translates to:
  /// **'Claim draft queue'**
  String get claimsBackendGapDraftTitle;

  /// Localized text for claimsBackendGapDraftBody.
  ///
  /// In en, this message translates to:
  /// **'The claim API supports submitted, approved, rejected, paid, and cancelled states, but no draft status.'**
  String get claimsBackendGapDraftBody;

  /// Localized text for claimsBackendGapDocumentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Document upload and requests'**
  String get claimsBackendGapDocumentsTitle;

  /// Localized text for claimsBackendGapDocumentsBody.
  ///
  /// In en, this message translates to:
  /// **'Required document tracking is not yet backed by a document request endpoint.'**
  String get claimsBackendGapDocumentsBody;

  /// Localized text for claimsBackendGapReportsTitle.
  ///
  /// In en, this message translates to:
  /// **'Generated payer packs'**
  String get claimsBackendGapReportsTitle;

  /// Localized text for claimsBackendGapReportsBody.
  ///
  /// In en, this message translates to:
  /// **'Printable payer packs should move to report templates when the reports plan is implemented.'**
  String get claimsBackendGapReportsBody;

  /// Localized text for claimsCoveragePlanFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Coverage plan'**
  String get claimsCoveragePlanFieldLabel;

  /// Localized text for claimsCoveragePlanHint.
  ///
  /// In en, this message translates to:
  /// **'Select payer coverage'**
  String get claimsCoveragePlanHint;

  /// Localized text for claimsCoveragePlanRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'Select a coverage plan.'**
  String get claimsCoveragePlanRequiredMessage;

  /// Localized text for claimsCoverageUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Coverage plans unavailable'**
  String get claimsCoverageUnavailableTitle;

  /// Localized text for claimsCoverageUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'Coverage plans could not be loaded, so authorization cannot be requested yet.'**
  String get claimsCoverageUnavailableBody;

  /// Localized text for claimsRequestAuthorizationSubmitAction.
  ///
  /// In en, this message translates to:
  /// **'Request authorization'**
  String get claimsRequestAuthorizationSubmitAction;

  /// Localized text for claimsPrepareClaimDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Prepare claim'**
  String get claimsPrepareClaimDialogTitle;

  /// Localized text for claimsPrepareClaimSubmitAction.
  ///
  /// In en, this message translates to:
  /// **'Prepare and submit'**
  String get claimsPrepareClaimSubmitAction;

  /// Localized text for claimsInvoiceHint.
  ///
  /// In en, this message translates to:
  /// **'Select invoice'**
  String get claimsInvoiceHint;

  /// Localized text for claimsInvoiceRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'Select an invoice.'**
  String get claimsInvoiceRequiredMessage;

  /// Localized text for claimsPrepareClaimUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Claim inputs unavailable'**
  String get claimsPrepareClaimUnavailableTitle;

  /// Localized text for claimsPrepareClaimUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'A coverage plan and invoice are required before a claim can be prepared.'**
  String get claimsPrepareClaimUnavailableBody;

  /// Localized text for claimsAuthorizationStatusFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Authorization status'**
  String get claimsAuthorizationStatusFieldLabel;

  /// Localized text for claimsStatusRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'Select a status.'**
  String get claimsStatusRequiredMessage;

  /// Localized text for claimsUpdateStatusSubmitAction.
  ///
  /// In en, this message translates to:
  /// **'Update status'**
  String get claimsUpdateStatusSubmitAction;

  /// Localized text for claimsNotesFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get claimsNotesFieldLabel;

  /// Localized text for claimsSubmitClaimSubmitAction.
  ///
  /// In en, this message translates to:
  /// **'Submit claim'**
  String get claimsSubmitClaimSubmitAction;

  /// Localized text for claimsClaimResponseFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Payer response'**
  String get claimsClaimResponseFieldLabel;

  /// Localized text for claimsSavedMessage.
  ///
  /// In en, this message translates to:
  /// **'Claims workspace updated.'**
  String get claimsSavedMessage;

  /// Localized text for claimsRequestAuthorizationDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Request pre-authorization'**
  String get claimsRequestAuthorizationDialogTitle;

  /// Localized text for claimsUpdateAuthorizationDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Update authorization status'**
  String get claimsUpdateAuthorizationDialogTitle;

  /// Localized text for claimsSubmitClaimDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Submit claim'**
  String get claimsSubmitClaimDialogTitle;

  /// Localized text for claimsRecordResponseDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Record payer response'**
  String get claimsRecordResponseDialogTitle;

  /// Localized text for claimsRecordResponseSubmitAction.
  ///
  /// In en, this message translates to:
  /// **'Record response'**
  String get claimsRecordResponseSubmitAction;

  /// Localized text for claimsCloseClaimDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Close claim'**
  String get claimsCloseClaimDialogTitle;

  /// Localized text for claimsCloseClaimSubmitAction.
  ///
  /// In en, this message translates to:
  /// **'Close as paid'**
  String get claimsCloseClaimSubmitAction;

  /// Localized text for claimsUpdateStatusAction.
  ///
  /// In en, this message translates to:
  /// **'Update status'**
  String get claimsUpdateStatusAction;

  /// Localized text for claimsSubmitClaimAction.
  ///
  /// In en, this message translates to:
  /// **'Submit claim'**
  String get claimsSubmitClaimAction;

  /// Localized text for claimsResubmitClaimAction.
  ///
  /// In en, this message translates to:
  /// **'Resubmit claim'**
  String get claimsResubmitClaimAction;

  /// Localized text for claimsRecordResponseAction.
  ///
  /// In en, this message translates to:
  /// **'Record response'**
  String get claimsRecordResponseAction;

  /// Localized text for claimsCloseClaimAction.
  ///
  /// In en, this message translates to:
  /// **'Close as paid'**
  String get claimsCloseClaimAction;

  /// Localized text for claimsFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All queues'**
  String get claimsFilterAll;

  /// Localized text for claimsFilterAuthorizationPending.
  ///
  /// In en, this message translates to:
  /// **'Authorization pending'**
  String get claimsFilterAuthorizationPending;

  /// Localized text for claimsFilterAuthorizationApproved.
  ///
  /// In en, this message translates to:
  /// **'Authorization approved'**
  String get claimsFilterAuthorizationApproved;

  /// Localized text for claimsFilterAuthorizationDenied.
  ///
  /// In en, this message translates to:
  /// **'Authorization denied'**
  String get claimsFilterAuthorizationDenied;

  /// Localized text for claimsFilterAuthorizationExpired.
  ///
  /// In en, this message translates to:
  /// **'Authorization expired'**
  String get claimsFilterAuthorizationExpired;

  /// Localized text for claimsFilterClaimSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Claim submitted'**
  String get claimsFilterClaimSubmitted;

  /// Localized text for claimsFilterClaimApproved.
  ///
  /// In en, this message translates to:
  /// **'Claim approved'**
  String get claimsFilterClaimApproved;

  /// Localized text for claimsFilterClaimRejected.
  ///
  /// In en, this message translates to:
  /// **'Claim rejected'**
  String get claimsFilterClaimRejected;

  /// Localized text for claimsFilterClaimPaid.
  ///
  /// In en, this message translates to:
  /// **'Claim paid'**
  String get claimsFilterClaimPaid;

  /// Localized text for claimsFilterClaimCancelled.
  ///
  /// In en, this message translates to:
  /// **'Claim cancelled'**
  String get claimsFilterClaimCancelled;

  /// Localized text for claimsStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get claimsStatusPending;

  /// Localized text for claimsStatusApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get claimsStatusApproved;

  /// Localized text for claimsStatusDenied.
  ///
  /// In en, this message translates to:
  /// **'Denied'**
  String get claimsStatusDenied;

  /// Localized text for claimsStatusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get claimsStatusExpired;

  /// Localized text for claimsStatusSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get claimsStatusSubmitted;

  /// Localized text for claimsStatusRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get claimsStatusRejected;

  /// Localized text for claimsStatusPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get claimsStatusPaid;

  /// Localized text for claimsStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get claimsStatusCancelled;

  /// Localized text for claimsAuthorizationTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Authorization'**
  String get claimsAuthorizationTypeLabel;

  /// Localized text for claimsClaimTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Claim'**
  String get claimsClaimTypeLabel;

  /// Localized text for claimsAuthorizationTitle.
  ///
  /// In en, this message translates to:
  /// **'Coverage authorization'**
  String get claimsAuthorizationTitle;

  /// Localized text for claimsClaimPatientTitle.
  ///
  /// In en, this message translates to:
  /// **'Claim patient'**
  String get claimsClaimPatientTitle;

  /// Localized text for claimsAuthorizationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Payer coverage request'**
  String get claimsAuthorizationSubtitle;

  /// No description provided for @claimsClaimSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Claim {claimId}'**
  String claimsClaimSubtitle(String claimId);

  /// Localized text for claimsAuthorizationStatementTitle.
  ///
  /// In en, this message translates to:
  /// **'Pre-authorization statement'**
  String get claimsAuthorizationStatementTitle;

  /// Localized text for claimsClaimStatementTitle.
  ///
  /// In en, this message translates to:
  /// **'Claim statement'**
  String get claimsClaimStatementTitle;

  /// Localized text for claimsReportGeneratedLabel.
  ///
  /// In en, this message translates to:
  /// **'Generated'**
  String get claimsReportGeneratedLabel;

  /// Localized text for claimsReportFooter.
  ///
  /// In en, this message translates to:
  /// **'Generated from backend-backed claims and billing data.'**
  String get claimsReportFooter;

  /// Localized text for labTitle.
  ///
  /// In en, this message translates to:
  /// **'Laboratory'**
  String get labTitle;

  /// Localized text for labDescription.
  ///
  /// In en, this message translates to:
  /// **'Manage lab catalog, order queues, samples, result release, QC, and clinician review handoff.'**
  String get labDescription;

  /// Localized text for labLoadingTitle.
  ///
  /// In en, this message translates to:
  /// **'Loading laboratory'**
  String get labLoadingTitle;

  /// Localized text for labLoadingBody.
  ///
  /// In en, this message translates to:
  /// **'Loading lab queues, catalog, samples, results, and QC logs.'**
  String get labLoadingBody;

  /// Localized text for labLiveStatus.
  ///
  /// In en, this message translates to:
  /// **'Live sync'**
  String get labLiveStatus;

  /// Localized text for labSavingStatus.
  ///
  /// In en, this message translates to:
  /// **'Saving'**
  String get labSavingStatus;

  /// Localized text for labSavedMessage.
  ///
  /// In en, this message translates to:
  /// **'Laboratory workflow updated.'**
  String get labSavedMessage;

  /// Localized text for labRequestOrderAction.
  ///
  /// In en, this message translates to:
  /// **'Request lab'**
  String get labRequestOrderAction;

  /// Localized text for labRecordQcAction.
  ///
  /// In en, this message translates to:
  /// **'Record QC'**
  String get labRecordQcAction;

  /// Localized text for labTotalOrdersSummaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Total orders'**
  String get labTotalOrdersSummaryLabel;

  /// Localized text for labWaitingSampleSummaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Waiting sample'**
  String get labWaitingSampleSummaryLabel;

  /// Localized text for labProcessingSummaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get labProcessingSummaryLabel;

  /// Localized text for labResultPendingSummaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Result pending'**
  String get labResultPendingSummaryLabel;

  /// Localized text for labCriticalSummaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Critical'**
  String get labCriticalSummaryLabel;

  /// Localized text for labCompletedSummaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Released'**
  String get labCompletedSummaryLabel;

  /// Localized text for labFiltersLabel.
  ///
  /// In en, this message translates to:
  /// **'Laboratory filters'**
  String get labFiltersLabel;

  /// Localized text for labSearchLabel.
  ///
  /// In en, this message translates to:
  /// **'Search laboratory'**
  String get labSearchLabel;

  /// Localized text for labSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search patient, order, sample, test, or encounter'**
  String get labSearchHint;

  /// Localized text for labScopeFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get labScopeFilterLabel;

  /// Localized text for labScopeAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get labScopeAll;

  /// Localized text for labScopeCollection.
  ///
  /// In en, this message translates to:
  /// **'Waiting sample'**
  String get labScopeCollection;

  /// Localized text for labScopeProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get labScopeProcessing;

  /// Localized text for labScopeResults.
  ///
  /// In en, this message translates to:
  /// **'Result pending'**
  String get labScopeResults;

  /// Localized text for labScopeCritical.
  ///
  /// In en, this message translates to:
  /// **'Critical'**
  String get labScopeCritical;

  /// Localized text for labScopeCompleted.
  ///
  /// In en, this message translates to:
  /// **'Released'**
  String get labScopeCompleted;

  /// Localized text for labScopeCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get labScopeCancelled;

  /// Localized text for labWorklistTitle.
  ///
  /// In en, this message translates to:
  /// **'Lab queue'**
  String get labWorklistTitle;

  /// Localized text for labWorklistDescription.
  ///
  /// In en, this message translates to:
  /// **'Actionable lab orders with sample, processing, result, and release state.'**
  String get labWorklistDescription;

  /// Localized text for labNoOrdersTitle.
  ///
  /// In en, this message translates to:
  /// **'No lab orders'**
  String get labNoOrdersTitle;

  /// Localized text for labNoOrdersBody.
  ///
  /// In en, this message translates to:
  /// **'Adjust the queue filter or search term to find laboratory work.'**
  String get labNoOrdersBody;

  /// Localized text for labPatientColumnLabel.
  ///
  /// In en, this message translates to:
  /// **'Patient'**
  String get labPatientColumnLabel;

  /// Localized text for labOrderColumnLabel.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get labOrderColumnLabel;

  /// Localized text for labTestsColumnLabel.
  ///
  /// In en, this message translates to:
  /// **'Tests'**
  String get labTestsColumnLabel;

  /// Localized text for labSampleColumnLabel.
  ///
  /// In en, this message translates to:
  /// **'Sample'**
  String get labSampleColumnLabel;

  /// Localized text for labResultColumnLabel.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get labResultColumnLabel;

  /// Localized text for labNextActionColumnLabel.
  ///
  /// In en, this message translates to:
  /// **'Next action'**
  String get labNextActionColumnLabel;

  /// No description provided for @labPageLabel.
  ///
  /// In en, this message translates to:
  /// **'{from}-{to} of {total}'**
  String labPageLabel(int from, int to, int total);

  /// Localized text for labPreviousPageLabel.
  ///
  /// In en, this message translates to:
  /// **'Previous lab page'**
  String get labPreviousPageLabel;

  /// Localized text for labNextPageLabel.
  ///
  /// In en, this message translates to:
  /// **'Next lab page'**
  String get labNextPageLabel;

  /// Localized text for labDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Lab detail'**
  String get labDetailTitle;

  /// Localized text for labDetailLoadingTitle.
  ///
  /// In en, this message translates to:
  /// **'Loading lab detail'**
  String get labDetailLoadingTitle;

  /// Localized text for labDetailLoadingBody.
  ///
  /// In en, this message translates to:
  /// **'Loading samples, results, timeline, and available workflow actions.'**
  String get labDetailLoadingBody;

  /// Localized text for labNoSelectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Select an order'**
  String get labNoSelectionTitle;

  /// Localized text for labNoSelectionBody.
  ///
  /// In en, this message translates to:
  /// **'Choose a lab order from the queue to collect samples, process results, and release reports.'**
  String get labNoSelectionBody;

  /// Localized text for labPatientContextLabel.
  ///
  /// In en, this message translates to:
  /// **'Lab patient context'**
  String get labPatientContextLabel;

  /// Localized text for labOrderFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Lab order'**
  String get labOrderFieldLabel;

  /// Localized text for labEncounterFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Encounter'**
  String get labEncounterFieldLabel;

  /// Localized text for labOrderedAtFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Ordered at'**
  String get labOrderedAtFieldLabel;

  /// Localized text for labItemsSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Order items'**
  String get labItemsSectionTitle;

  /// Localized text for labSamplesSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Samples'**
  String get labSamplesSectionTitle;

  /// Localized text for labResultsSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Results'**
  String get labResultsSectionTitle;

  /// Localized text for labTimelineSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get labTimelineSectionTitle;

  /// Localized text for labNoSamplesLabel.
  ///
  /// In en, this message translates to:
  /// **'No samples recorded'**
  String get labNoSamplesLabel;

  /// Localized text for labNoResultsLabel.
  ///
  /// In en, this message translates to:
  /// **'No released results'**
  String get labNoResultsLabel;

  /// Localized text for labNoTimelineLabel.
  ///
  /// In en, this message translates to:
  /// **'No timeline entries'**
  String get labNoTimelineLabel;

  /// Localized text for labReferenceRangeLabel.
  ///
  /// In en, this message translates to:
  /// **'Reference range'**
  String get labReferenceRangeLabel;

  /// Localized text for labReportedAtLabel.
  ///
  /// In en, this message translates to:
  /// **'Reported'**
  String get labReportedAtLabel;

  /// Localized text for labCollectSampleAction.
  ///
  /// In en, this message translates to:
  /// **'Collect sample'**
  String get labCollectSampleAction;

  /// Localized text for labReceiveSampleAction.
  ///
  /// In en, this message translates to:
  /// **'Receive sample'**
  String get labReceiveSampleAction;

  /// Localized text for labRejectSampleAction.
  ///
  /// In en, this message translates to:
  /// **'Reject sample'**
  String get labRejectSampleAction;

  /// Localized text for labReleaseResultAction.
  ///
  /// In en, this message translates to:
  /// **'Release result'**
  String get labReleaseResultAction;

  /// Localized text for labReverseWorkflowAction.
  ///
  /// In en, this message translates to:
  /// **'Reverse step'**
  String get labReverseWorkflowAction;

  /// Localized text for labViewCatalogAction.
  ///
  /// In en, this message translates to:
  /// **'View catalog'**
  String get labViewCatalogAction;

  /// Localized text for labCatalogQcTitle.
  ///
  /// In en, this message translates to:
  /// **'Catalog and QC'**
  String get labCatalogQcTitle;

  /// Localized text for labCatalogTitle.
  ///
  /// In en, this message translates to:
  /// **'Lab catalog'**
  String get labCatalogTitle;

  /// Localized text for labQcTitle.
  ///
  /// In en, this message translates to:
  /// **'Quality control'**
  String get labQcTitle;

  /// Localized text for labBackendGapsTitle.
  ///
  /// In en, this message translates to:
  /// **'Backend gaps'**
  String get labBackendGapsTitle;

  /// Localized text for labBackendGapsBody.
  ///
  /// In en, this message translates to:
  /// **'No confirmed backend gaps are blocking the displayed lab queue.'**
  String get labBackendGapsBody;

  /// Localized text for labNoCatalogItemsLabel.
  ///
  /// In en, this message translates to:
  /// **'No catalog items found'**
  String get labNoCatalogItemsLabel;

  /// Localized text for labNoQcLogsLabel.
  ///
  /// In en, this message translates to:
  /// **'No QC logs recorded'**
  String get labNoQcLogsLabel;

  /// Localized text for labTestsTabLabel.
  ///
  /// In en, this message translates to:
  /// **'Tests'**
  String get labTestsTabLabel;

  /// Localized text for labPanelsTabLabel.
  ///
  /// In en, this message translates to:
  /// **'Panels'**
  String get labPanelsTabLabel;

  /// Localized text for labRequestOrderDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Request lab order'**
  String get labRequestOrderDialogTitle;

  /// Localized text for labPatientIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Patient ID'**
  String get labPatientIdLabel;

  /// Localized text for labEncounterIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Encounter ID'**
  String get labEncounterIdLabel;

  /// Localized text for labCatalogSearchLabel.
  ///
  /// In en, this message translates to:
  /// **'Search lab catalog'**
  String get labCatalogSearchLabel;

  /// Localized text for labCatalogSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search tests, panels, codes, category, or specimen'**
  String get labCatalogSearchHint;

  /// Localized text for labCreateOrderSubmitAction.
  ///
  /// In en, this message translates to:
  /// **'Create lab order'**
  String get labCreateOrderSubmitAction;

  /// Localized text for labCollectDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Collect sample'**
  String get labCollectDialogTitle;

  /// Localized text for labCollectedAtLabel.
  ///
  /// In en, this message translates to:
  /// **'Collected at'**
  String get labCollectedAtLabel;

  /// Localized text for labDateTimeHint.
  ///
  /// In en, this message translates to:
  /// **'YYYY-MM-DDTHH:MM:SS'**
  String get labDateTimeHint;

  /// Localized text for labNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get labNotesLabel;

  /// Localized text for labReceiveDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Receive sample'**
  String get labReceiveDialogTitle;

  /// Localized text for labSampleFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Sample'**
  String get labSampleFieldLabel;

  /// Localized text for labReceivedAtLabel.
  ///
  /// In en, this message translates to:
  /// **'Received at'**
  String get labReceivedAtLabel;

  /// Localized text for labRejectDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Reject sample'**
  String get labRejectDialogTitle;

  /// Localized text for labRejectReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Rejection reason'**
  String get labRejectReasonLabel;

  /// Localized text for labReleaseDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Release lab result'**
  String get labReleaseDialogTitle;

  /// Localized text for labOrderItemFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Order item'**
  String get labOrderItemFieldLabel;

  /// Localized text for labResultStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Result status'**
  String get labResultStatusLabel;

  /// Localized text for labResultValueLabel.
  ///
  /// In en, this message translates to:
  /// **'Result value'**
  String get labResultValueLabel;

  /// Localized text for labResultUnitLabel.
  ///
  /// In en, this message translates to:
  /// **'Result unit'**
  String get labResultUnitLabel;

  /// Localized text for labResultTextLabel.
  ///
  /// In en, this message translates to:
  /// **'Result comments'**
  String get labResultTextLabel;

  /// Localized text for labReportedAtInputLabel.
  ///
  /// In en, this message translates to:
  /// **'Reported at'**
  String get labReportedAtInputLabel;

  /// Localized text for labReverseDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Reverse lab workflow'**
  String get labReverseDialogTitle;

  /// Localized text for labReverseReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get labReverseReasonLabel;

  /// Localized text for labRecordQcDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Record quality control'**
  String get labRecordQcDialogTitle;

  /// Localized text for labQcTestFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Lab test'**
  String get labQcTestFieldLabel;

  /// Localized text for labQcStatusFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'QC status'**
  String get labQcStatusFieldLabel;

  /// Localized text for labLoggedAtLabel.
  ///
  /// In en, this message translates to:
  /// **'Logged at'**
  String get labLoggedAtLabel;

  /// Localized text for labQcNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'QC notes'**
  String get labQcNotesLabel;

  /// Localized text for labStatusOrdered.
  ///
  /// In en, this message translates to:
  /// **'Ordered'**
  String get labStatusOrdered;

  /// Localized text for labStatusCollected.
  ///
  /// In en, this message translates to:
  /// **'Collected'**
  String get labStatusCollected;

  /// Localized text for labStatusInProcess.
  ///
  /// In en, this message translates to:
  /// **'In process'**
  String get labStatusInProcess;

  /// Localized text for labStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Released'**
  String get labStatusCompleted;

  /// Localized text for labStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get labStatusCancelled;

  /// Localized text for labStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get labStatusPending;

  /// Localized text for labStatusNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get labStatusNormal;

  /// Localized text for labStatusAbnormal.
  ///
  /// In en, this message translates to:
  /// **'Abnormal'**
  String get labStatusAbnormal;

  /// Localized text for labStatusCritical.
  ///
  /// In en, this message translates to:
  /// **'Critical'**
  String get labStatusCritical;

  /// Localized text for labStatusRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get labStatusRejected;

  /// Localized text for labStatusReceived.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get labStatusReceived;

  /// Localized text for labNextActionCancelled.
  ///
  /// In en, this message translates to:
  /// **'Order cancelled'**
  String get labNextActionCancelled;

  /// Localized text for labNextActionCollect.
  ///
  /// In en, this message translates to:
  /// **'Collect sample'**
  String get labNextActionCollect;

  /// Localized text for labNextActionReceive.
  ///
  /// In en, this message translates to:
  /// **'Receive sample'**
  String get labNextActionReceive;

  /// Localized text for labNextActionRelease.
  ///
  /// In en, this message translates to:
  /// **'Enter and release result'**
  String get labNextActionRelease;

  /// Localized text for labNextActionReviewCritical.
  ///
  /// In en, this message translates to:
  /// **'Escalate critical result'**
  String get labNextActionReviewCritical;

  /// Localized text for labNextActionCompleted.
  ///
  /// In en, this message translates to:
  /// **'Ready for doctor review'**
  String get labNextActionCompleted;

  /// Localized text for labNextActionWatch.
  ///
  /// In en, this message translates to:
  /// **'Review order'**
  String get labNextActionWatch;

  /// Localized text for labReportPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Result report preview'**
  String get labReportPreviewTitle;

  /// Localized text for labReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Laboratory result report'**
  String get labReportTitle;

  /// Localized text for labCopyReportAction.
  ///
  /// In en, this message translates to:
  /// **'Copy report'**
  String get labCopyReportAction;

  /// Localized text for labReportPatientLabel.
  ///
  /// In en, this message translates to:
  /// **'Patient'**
  String get labReportPatientLabel;

  /// Localized text for labReportOrderLabel.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get labReportOrderLabel;

  /// Localized text for labReportResultLabel.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get labReportResultLabel;

  /// Localized text for labReportRangeLabel.
  ///
  /// In en, this message translates to:
  /// **'Reference range'**
  String get labReportRangeLabel;

  /// Localized text for labReportVerifiedLabel.
  ///
  /// In en, this message translates to:
  /// **'Released'**
  String get labReportVerifiedLabel;

  /// Localized text for labReportFooter.
  ///
  /// In en, this message translates to:
  /// **'Generated from confirmed laboratory workflow data.'**
  String get labReportFooter;

  /// Localized text for labGapBillingTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment and authorization gate'**
  String get labGapBillingTitle;

  /// Localized text for labGapBillingBody.
  ///
  /// In en, this message translates to:
  /// **'The current lab workbench contract does not expose payment or authorization blockers.'**
  String get labGapBillingBody;

  /// Localized text for labGapVerificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Separate verification step'**
  String get labGapVerificationTitle;

  /// Localized text for labGapVerificationBody.
  ///
  /// In en, this message translates to:
  /// **'The confirmed workflow releases an order item result, but does not expose a separate verified-before-release state.'**
  String get labGapVerificationBody;

  /// Localized text for labGapReportGenerationTitle.
  ///
  /// In en, this message translates to:
  /// **'Generated report endpoint'**
  String get labGapReportGenerationTitle;

  /// Localized text for labGapReportGenerationBody.
  ///
  /// In en, this message translates to:
  /// **'The frontend shows a shared report preview; no confirmed lab-specific generated PDF endpoint is exposed.'**
  String get labGapReportGenerationBody;

  /// Navigation label for the operations workspace.
  ///
  /// In en, this message translates to:
  /// **'Operations'**
  String get navigationOperationsLabel;

  /// Title for the operations workspace.
  ///
  /// In en, this message translates to:
  /// **'Operations'**
  String get operationsTitle;

  /// Loading title for the operations workspace.
  ///
  /// In en, this message translates to:
  /// **'Loading operations'**
  String get operationsLoadingTitle;

  /// Loading body for the operations workspace.
  ///
  /// In en, this message translates to:
  /// **'Loading maintenance requests, assets, and service logs.'**
  String get operationsLoadingBody;

  /// Status label when operations data is synced.
  ///
  /// In en, this message translates to:
  /// **'Live sync'**
  String get operationsLiveStatus;

  /// Status label when operations data is being saved.
  ///
  /// In en, this message translates to:
  /// **'Saving'**
  String get operationsSavingStatus;

  /// Snackbar message after operations mutations succeed.
  ///
  /// In en, this message translates to:
  /// **'Operations changes saved.'**
  String get operationsSavedMessage;

  /// Action label for creating an operations maintenance request.
  ///
  /// In en, this message translates to:
  /// **'Create request'**
  String get operationsCreateRequestAction;

  /// Action label for opening an operations report preview.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get operationsOpenReportAction;

  /// Summary card label for all operations requests.
  ///
  /// In en, this message translates to:
  /// **'All requests'**
  String get operationsAllRequestsSummaryLabel;

  /// Summary card label for open operations requests.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get operationsOpenSummaryLabel;

  /// Summary card label for in-progress operations requests.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get operationsInProgressSummaryLabel;

  /// Summary card label for completed operations requests.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get operationsCompletedSummaryLabel;

  /// Summary card label for cancelled operations requests.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get operationsCancelledSummaryLabel;

  /// Summary card label for configured assets.
  ///
  /// In en, this message translates to:
  /// **'Assets'**
  String get operationsAssetsSummaryLabel;

  /// Title for the operations maintenance queue.
  ///
  /// In en, this message translates to:
  /// **'Maintenance queue'**
  String get operationsQueueTitle;

  /// Description for the operations maintenance queue.
  ///
  /// In en, this message translates to:
  /// **'Track facility repairs, assets, safety notes, and readiness work.'**
  String get operationsQueueDescription;

  /// Accessibility label for operations search.
  ///
  /// In en, this message translates to:
  /// **'Search operations'**
  String get operationsSearchLabel;

  /// Hint text for operations search.
  ///
  /// In en, this message translates to:
  /// **'Search request, location, system, priority, status, assignee, or notes'**
  String get operationsSearchHint;

  /// Action label for clearing operations filters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get operationsClearFiltersAction;

  /// Title and label for operations filters.
  ///
  /// In en, this message translates to:
  /// **'Operations filters'**
  String get operationsFiltersLabel;

  /// Label for choosing operations search fields.
  ///
  /// In en, this message translates to:
  /// **'Search fields'**
  String get operationsSearchFieldsLabel;

  /// All option label for operations filters.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get operationsAllFilterOption;

  /// Label for reported date filtering.
  ///
  /// In en, this message translates to:
  /// **'Reported date'**
  String get operationsReportedDateFilterLabel;

  /// Label for the start reported date filter.
  ///
  /// In en, this message translates to:
  /// **'Reported from'**
  String get operationsReportedFromLabel;

  /// Label for the end reported date filter.
  ///
  /// In en, this message translates to:
  /// **'Reported to'**
  String get operationsReportedToLabel;

  /// Action label for choosing a reported date.
  ///
  /// In en, this message translates to:
  /// **'Pick reported date'**
  String get operationsPickReportedDateAction;

  /// Filter label for operations request status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get operationsStatusFilterLabel;

  /// Filter label for operations request priority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get operationsPriorityFilterLabel;

  /// Filter and field label for facility identifier.
  ///
  /// In en, this message translates to:
  /// **'Facility'**
  String get operationsFacilityFilterLabel;

  /// Filter and field label for asset identifier.
  ///
  /// In en, this message translates to:
  /// **'Asset'**
  String get operationsAssetFilterLabel;

  /// Pagination label for operations requests.
  ///
  /// In en, this message translates to:
  /// **'{first} - {last} of {total} requests'**
  String operationsPageLabel(int first, int last, int total);

  /// Empty-state title for operations requests.
  ///
  /// In en, this message translates to:
  /// **'No maintenance requests'**
  String get operationsNoRequestsTitle;

  /// Empty-state body for operations requests.
  ///
  /// In en, this message translates to:
  /// **'Create a request or adjust the filters.'**
  String get operationsNoRequestsBody;

  /// Title for operations request detail.
  ///
  /// In en, this message translates to:
  /// **'Request detail'**
  String get operationsDetailTitle;

  /// Empty detail title when no operations request is selected.
  ///
  /// In en, this message translates to:
  /// **'Select a request'**
  String get operationsNoSelectionTitle;

  /// Empty detail body when no operations request is selected.
  ///
  /// In en, this message translates to:
  /// **'Choose a queue row to review assignments, service logs, and readiness notes.'**
  String get operationsNoSelectionBody;

  /// Column label for operations request reference.
  ///
  /// In en, this message translates to:
  /// **'Request'**
  String get operationsRequestColumnLabel;

  /// Column label for operations area or system.
  ///
  /// In en, this message translates to:
  /// **'Area/system'**
  String get operationsAreaColumnLabel;

  /// Column label for operations request priority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get operationsPriorityColumnLabel;

  /// Column label for operations request location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get operationsLocationColumnLabel;

  /// Column label for operations assignee or team.
  ///
  /// In en, this message translates to:
  /// **'Assignee/team'**
  String get operationsAssigneeColumnLabel;

  /// Column label for operations request status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get operationsStatusColumnLabel;

  /// Column label for operations request due time.
  ///
  /// In en, this message translates to:
  /// **'Due time'**
  String get operationsDueColumnLabel;

  /// Column label for operations request next action.
  ///
  /// In en, this message translates to:
  /// **'Next action'**
  String get operationsNextActionColumnLabel;

  /// Field label for operations request category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get operationsCategoryLabel;

  /// Section title for operations issue details.
  ///
  /// In en, this message translates to:
  /// **'Issue and notes'**
  String get operationsIssueTitle;

  /// Section title for operations request actions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get operationsActionsTitle;

  /// Action label for assigning an operations request.
  ///
  /// In en, this message translates to:
  /// **'Assign'**
  String get operationsAssignAction;

  /// Action label for updating operations request status.
  ///
  /// In en, this message translates to:
  /// **'Update status'**
  String get operationsUpdateStatusAction;

  /// Action label for adding an asset service log.
  ///
  /// In en, this message translates to:
  /// **'Add service log'**
  String get operationsAddServiceLogAction;

  /// Action label for adding parts or vendor notes.
  ///
  /// In en, this message translates to:
  /// **'Parts/vendor note'**
  String get operationsPartsVendorAction;

  /// Action label for adding a safety note.
  ///
  /// In en, this message translates to:
  /// **'Safety note'**
  String get operationsSafetyNoteAction;

  /// Action label for adding evidence notes.
  ///
  /// In en, this message translates to:
  /// **'Evidence note'**
  String get operationsEvidenceNoteAction;

  /// Action label for adding handover notes.
  ///
  /// In en, this message translates to:
  /// **'Handover note'**
  String get operationsHandoverNoteAction;

  /// Action label for adding closeout notes.
  ///
  /// In en, this message translates to:
  /// **'Closeout note'**
  String get operationsCloseoutNoteAction;

  /// Field label for parts or vendor note.
  ///
  /// In en, this message translates to:
  /// **'Parts or vendor note'**
  String get operationsPartsVendorNoteLabel;

  /// Field label for safety note.
  ///
  /// In en, this message translates to:
  /// **'Safety note'**
  String get operationsSafetyNoteLabel;

  /// Field label for evidence note.
  ///
  /// In en, this message translates to:
  /// **'Evidence note'**
  String get operationsEvidenceNoteLabel;

  /// Field label for handover note.
  ///
  /// In en, this message translates to:
  /// **'Handover note'**
  String get operationsHandoverNoteLabel;

  /// Field label for closeout note.
  ///
  /// In en, this message translates to:
  /// **'Closeout note'**
  String get operationsCloseoutNoteLabel;

  /// Action label for saving an operations note.
  ///
  /// In en, this message translates to:
  /// **'Save note'**
  String get operationsSaveNoteAction;

  /// Title for asset service logs in operations.
  ///
  /// In en, this message translates to:
  /// **'Service logs'**
  String get operationsServiceLogsTitle;

  /// Empty-state title for operations service logs.
  ///
  /// In en, this message translates to:
  /// **'No service logs'**
  String get operationsNoServiceLogsTitle;

  /// Empty-state body for operations service logs.
  ///
  /// In en, this message translates to:
  /// **'Service logs appear after an asset-backed repair is recorded.'**
  String get operationsNoServiceLogsBody;

  /// Fallback value for unknown operations fields.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get operationsUnknownValue;

  /// Fallback value when an operations request has no assignee.
  ///
  /// In en, this message translates to:
  /// **'Unassigned'**
  String get operationsUnassignedValue;

  /// Fallback value when an operations request has no due time.
  ///
  /// In en, this message translates to:
  /// **'No due time'**
  String get operationsNoDueTimeValue;

  /// Fallback value when an operations record has no notes.
  ///
  /// In en, this message translates to:
  /// **'No notes recorded.'**
  String get operationsNoNotesValue;

  /// Field label for free-text operations location note.
  ///
  /// In en, this message translates to:
  /// **'Location note'**
  String get operationsLocationNoteLabel;

  /// Field label for operations issue.
  ///
  /// In en, this message translates to:
  /// **'Issue'**
  String get operationsIssueFieldLabel;

  /// Field label for operations notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get operationsNotesLabel;

  /// Submit label for creating an operations request.
  ///
  /// In en, this message translates to:
  /// **'Create request'**
  String get operationsCreateRequestSubmitAction;

  /// Field label for operations technician or team.
  ///
  /// In en, this message translates to:
  /// **'Technician or team'**
  String get operationsAssigneeFieldLabel;

  /// Field label for operations SLA hours.
  ///
  /// In en, this message translates to:
  /// **'SLA hours'**
  String get operationsSlaHoursFieldLabel;

  /// Field label for operations triage summary.
  ///
  /// In en, this message translates to:
  /// **'Assignment note'**
  String get operationsTriageSummaryFieldLabel;

  /// Submit label for assigning an operations request.
  ///
  /// In en, this message translates to:
  /// **'Save assignment'**
  String get operationsAssignSubmitAction;

  /// Field label for operations status note.
  ///
  /// In en, this message translates to:
  /// **'Status note'**
  String get operationsStatusNoteLabel;

  /// Submit label for updating operations request status.
  ///
  /// In en, this message translates to:
  /// **'Save status'**
  String get operationsUpdateStatusSubmitAction;

  /// Field label for operations service log notes.
  ///
  /// In en, this message translates to:
  /// **'Service notes'**
  String get operationsServiceNotesLabel;

  /// Submit label for adding an operations service log.
  ///
  /// In en, this message translates to:
  /// **'Save service log'**
  String get operationsAddServiceLogSubmitAction;

  /// Disabled select option when no assets are loaded.
  ///
  /// In en, this message translates to:
  /// **'No configured assets'**
  String get operationsNoConfiguredAssetsOption;

  /// Status label for open operations requests.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get operationsStatusOpen;

  /// Status label for in-progress operations requests.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get operationsStatusInProgress;

  /// Status label for completed operations requests.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get operationsStatusCompleted;

  /// Status label for cancelled operations requests.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get operationsStatusCancelled;

  /// Priority label for urgent operations requests.
  ///
  /// In en, this message translates to:
  /// **'Urgent'**
  String get operationsPriorityUrgent;

  /// Priority label for high operations requests.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get operationsPriorityHigh;

  /// Priority label for normal operations requests.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get operationsPriorityNormal;

  /// Priority label for low operations requests.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get operationsPriorityLow;

  /// Category label for electrical operations requests.
  ///
  /// In en, this message translates to:
  /// **'Electrical'**
  String get operationsCategoryElectrical;

  /// Category label for plumbing operations requests.
  ///
  /// In en, this message translates to:
  /// **'Plumbing'**
  String get operationsCategoryPlumbing;

  /// Category label for water operations requests.
  ///
  /// In en, this message translates to:
  /// **'Water'**
  String get operationsCategoryWater;

  /// Category label for power backup operations requests.
  ///
  /// In en, this message translates to:
  /// **'Power backup'**
  String get operationsCategoryPowerBackup;

  /// Category label for HVAC operations requests.
  ///
  /// In en, this message translates to:
  /// **'HVAC'**
  String get operationsCategoryHvac;

  /// Category label for general asset operations requests.
  ///
  /// In en, this message translates to:
  /// **'General asset'**
  String get operationsCategoryGeneralAsset;

  /// Category label for safety operations requests.
  ///
  /// In en, this message translates to:
  /// **'Safety'**
  String get operationsCategorySafety;

  /// Category label for other operations requests.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get operationsCategoryOther;

  /// Next action label for open operations requests.
  ///
  /// In en, this message translates to:
  /// **'Assign technician or team'**
  String get operationsNextActionAssign;

  /// Next action label for asset-backed in-progress operations requests.
  ///
  /// In en, this message translates to:
  /// **'Record service work'**
  String get operationsNextActionServiceLog;

  /// Next action label for in-progress operations requests.
  ///
  /// In en, this message translates to:
  /// **'Update repair status'**
  String get operationsNextActionUpdateStatus;

  /// Next action label for completed operations requests.
  ///
  /// In en, this message translates to:
  /// **'Add closeout note if needed'**
  String get operationsNextActionCloseout;

  /// Next action label for cancelled operations requests.
  ///
  /// In en, this message translates to:
  /// **'Request cancelled'**
  String get operationsNextActionCancelled;

  /// Fallback next action label for operations requests.
  ///
  /// In en, this message translates to:
  /// **'Review request'**
  String get operationsNextActionReview;

  /// Title for the operations report preview.
  ///
  /// In en, this message translates to:
  /// **'Operations report'**
  String get operationsReportTitle;

  /// Title for the operations report preview body.
  ///
  /// In en, this message translates to:
  /// **'Report preview'**
  String get operationsReportPreviewTitle;

  /// Generated timestamp line for operations reports.
  ///
  /// In en, this message translates to:
  /// **'Generated {generatedAt}'**
  String operationsGeneratedAtLabel(String generatedAt);

  /// Summary line for operations report counts.
  ///
  /// In en, this message translates to:
  /// **'{total} requests: {open} open, {inProgress} in progress, {completed} completed.'**
  String operationsReportSummaryLine(
    int total,
    int open,
    int inProgress,
    int completed,
  );

  /// Navigation label for the biomedical workspace.
  ///
  /// In en, this message translates to:
  /// **'Biomedical'**
  String get navigationBiomedicalLabel;

  /// Title for the biomedical workspace.
  ///
  /// In en, this message translates to:
  /// **'Biomedical'**
  String get biomedicalTitle;

  /// Loading title for the biomedical workspace.
  ///
  /// In en, this message translates to:
  /// **'Loading biomedical'**
  String get biomedicalLoadingTitle;

  /// Loading body for the biomedical workspace.
  ///
  /// In en, this message translates to:
  /// **'Loading equipment registry, work orders, and compliance records.'**
  String get biomedicalLoadingBody;

  /// Status label when biomedical data is synced.
  ///
  /// In en, this message translates to:
  /// **'Live sync'**
  String get biomedicalLiveStatus;

  /// Status label when biomedical data is being saved.
  ///
  /// In en, this message translates to:
  /// **'Saving'**
  String get biomedicalSavingStatus;

  /// Snackbar message after biomedical mutations succeed.
  ///
  /// In en, this message translates to:
  /// **'Biomedical changes saved.'**
  String get biomedicalSavedMessage;

  /// Action label for registering biomedical equipment.
  ///
  /// In en, this message translates to:
  /// **'Register asset'**
  String get biomedicalRegisterAssetAction;

  /// Action label for reporting a biomedical equipment fault.
  ///
  /// In en, this message translates to:
  /// **'Report fault'**
  String get biomedicalReportFaultAction;

  /// Summary label for total equipment.
  ///
  /// In en, this message translates to:
  /// **'Total equipment'**
  String get biomedicalTotalEquipmentSummaryLabel;

  /// Summary label for overdue preventive maintenance.
  ///
  /// In en, this message translates to:
  /// **'Overdue PM'**
  String get biomedicalOverduePmSummaryLabel;

  /// Summary label for open biomedical work orders.
  ///
  /// In en, this message translates to:
  /// **'Open work orders'**
  String get biomedicalOpenWorkOrdersSummaryLabel;

  /// Summary label for critical equipment downtime.
  ///
  /// In en, this message translates to:
  /// **'Critical downtime'**
  String get biomedicalCriticalDowntimeSummaryLabel;

  /// Summary label for active equipment recalls.
  ///
  /// In en, this message translates to:
  /// **'Active recalls'**
  String get biomedicalActiveRecallsSummaryLabel;

  /// Title for the biomedical equipment list.
  ///
  /// In en, this message translates to:
  /// **'Equipment worklist'**
  String get biomedicalAssetListTitle;

  /// Description for the biomedical equipment list.
  ///
  /// In en, this message translates to:
  /// **'Search equipment, schedules, work orders, downtime, recalls, and lifecycle records.'**
  String get biomedicalAssetListDescription;

  /// Search field label for the biomedical workspace.
  ///
  /// In en, this message translates to:
  /// **'Search biomedical'**
  String get biomedicalSearchLabel;

  /// Search field hint for the biomedical workspace.
  ///
  /// In en, this message translates to:
  /// **'Search asset tag, equipment, category, location, status, date, or provider'**
  String get biomedicalSearchHint;

  /// Advanced filter label for the biomedical workspace.
  ///
  /// In en, this message translates to:
  /// **'Biomedical filters'**
  String get biomedicalFiltersLabel;

  /// Filter label for biomedical panel.
  ///
  /// In en, this message translates to:
  /// **'Panel'**
  String get biomedicalPanelFilterLabel;

  /// Filter label for biomedical status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get biomedicalStatusFilterLabel;

  /// Filter label for biomedical priority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get biomedicalPriorityFilterLabel;

  /// Filter label for biomedical facility.
  ///
  /// In en, this message translates to:
  /// **'Facility'**
  String get biomedicalFacilityFilterLabel;

  /// Filter label for biomedical due-date preset.
  ///
  /// In en, this message translates to:
  /// **'Due date'**
  String get biomedicalDatePresetFilterLabel;

  /// Biomedical list asset tag column label.
  ///
  /// In en, this message translates to:
  /// **'Asset tag'**
  String get biomedicalAssetTagColumnLabel;

  /// Biomedical list equipment column label.
  ///
  /// In en, this message translates to:
  /// **'Equipment'**
  String get biomedicalEquipmentColumnLabel;

  /// Biomedical list category column label.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get biomedicalCategoryColumnLabel;

  /// Biomedical list location column label.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get biomedicalLocationColumnLabel;

  /// Biomedical list risk column label.
  ///
  /// In en, this message translates to:
  /// **'Risk'**
  String get biomedicalRiskColumnLabel;

  /// Biomedical list status column label.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get biomedicalStatusColumnLabel;

  /// Biomedical list owner column label.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get biomedicalOwnerColumnLabel;

  /// Biomedical list next action column label.
  ///
  /// In en, this message translates to:
  /// **'Next action'**
  String get biomedicalNextActionColumnLabel;

  /// Previous page action label for biomedical lists.
  ///
  /// In en, this message translates to:
  /// **'Previous equipment'**
  String get biomedicalPreviousPageLabel;

  /// Next page action label for biomedical lists.
  ///
  /// In en, this message translates to:
  /// **'Next equipment'**
  String get biomedicalNextPageLabel;

  /// Pagination label for biomedical lists.
  ///
  /// In en, this message translates to:
  /// **'Showing {from}-{to} of {total}'**
  String biomedicalPageLabel(int from, int to, int total);

  /// Empty title for biomedical equipment list.
  ///
  /// In en, this message translates to:
  /// **'No equipment records'**
  String get biomedicalNoAssetsTitle;

  /// Empty body for biomedical equipment list.
  ///
  /// In en, this message translates to:
  /// **'Equipment records matching this search and filter will appear here.'**
  String get biomedicalNoAssetsBody;

  /// Title for the biomedical detail panel.
  ///
  /// In en, this message translates to:
  /// **'Equipment detail'**
  String get biomedicalDetailTitle;

  /// Empty title when no biomedical record is selected.
  ///
  /// In en, this message translates to:
  /// **'Select equipment'**
  String get biomedicalNoSelectionTitle;

  /// Empty body when no biomedical record is selected.
  ///
  /// In en, this message translates to:
  /// **'Choose equipment or a related record to review readiness, work orders, compliance, and lifecycle actions.'**
  String get biomedicalNoSelectionBody;

  /// Biomedical detail registry section title.
  ///
  /// In en, this message translates to:
  /// **'Registry'**
  String get biomedicalRegistrySectionTitle;

  /// Biomedical detail readiness section title.
  ///
  /// In en, this message translates to:
  /// **'Readiness'**
  String get biomedicalReadinessSectionTitle;

  /// Biomedical detail maintenance section title.
  ///
  /// In en, this message translates to:
  /// **'Maintenance'**
  String get biomedicalMaintenanceSectionTitle;

  /// Biomedical detail compliance section title.
  ///
  /// In en, this message translates to:
  /// **'Compliance'**
  String get biomedicalComplianceSectionTitle;

  /// Biomedical detail lifecycle section title.
  ///
  /// In en, this message translates to:
  /// **'Lifecycle'**
  String get biomedicalLifecycleSectionTitle;

  /// Biomedical detail report preview section title.
  ///
  /// In en, this message translates to:
  /// **'Report preview'**
  String get biomedicalReportsSectionTitle;

  /// Fallback value when biomedical data is unavailable.
  ///
  /// In en, this message translates to:
  /// **'-'**
  String get biomedicalNotAvailableLabel;

  /// Label for biomedical asset tag.
  ///
  /// In en, this message translates to:
  /// **'Asset tag'**
  String get biomedicalAssetTagLabel;

  /// Label for biomedical resource type.
  ///
  /// In en, this message translates to:
  /// **'Record type'**
  String get biomedicalResourceLabel;

  /// Label for biomedical equipment.
  ///
  /// In en, this message translates to:
  /// **'Equipment'**
  String get biomedicalEquipmentLabel;

  /// Label for biomedical equipment category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get biomedicalCategoryLabel;

  /// Label for biomedical facility.
  ///
  /// In en, this message translates to:
  /// **'Facility'**
  String get biomedicalFacilityLabel;

  /// Label for biomedical owner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get biomedicalOwnerLabel;

  /// Label for biomedical status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get biomedicalStatusLabel;

  /// Label for biomedical priority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get biomedicalPriorityLabel;

  /// Label for biomedical next due date.
  ///
  /// In en, this message translates to:
  /// **'Next due'**
  String get biomedicalNextDueLabel;

  /// Label for biomedical last updated timestamp.
  ///
  /// In en, this message translates to:
  /// **'Last updated'**
  String get biomedicalLastUpdatedLabel;

  /// Label for biomedical target path.
  ///
  /// In en, this message translates to:
  /// **'Audit path'**
  String get biomedicalTargetPathLabel;

  /// Action label for editing biomedical asset.
  ///
  /// In en, this message translates to:
  /// **'Edit asset'**
  String get biomedicalEditAssetAction;

  /// Action label for transferring equipment location.
  ///
  /// In en, this message translates to:
  /// **'Transfer location'**
  String get biomedicalTransferLocationAction;

  /// Action label for scheduling maintenance.
  ///
  /// In en, this message translates to:
  /// **'Schedule maintenance'**
  String get biomedicalScheduleMaintenanceAction;

  /// Action label for creating biomedical work order.
  ///
  /// In en, this message translates to:
  /// **'Create work order'**
  String get biomedicalCreateWorkOrderAction;

  /// Action label for updating biomedical work order.
  ///
  /// In en, this message translates to:
  /// **'Update work order'**
  String get biomedicalUpdateWorkOrderAction;

  /// Action label for starting biomedical work order.
  ///
  /// In en, this message translates to:
  /// **'Start work order'**
  String get biomedicalStartWorkOrderAction;

  /// Action label for returning equipment to service.
  ///
  /// In en, this message translates to:
  /// **'Return to service'**
  String get biomedicalReturnToServiceAction;

  /// Action label for recording calibration.
  ///
  /// In en, this message translates to:
  /// **'Record calibration'**
  String get biomedicalRecordCalibrationAction;

  /// Action label for recording safety test.
  ///
  /// In en, this message translates to:
  /// **'Record safety test'**
  String get biomedicalRecordSafetyTestAction;

  /// Action label for reporting downtime.
  ///
  /// In en, this message translates to:
  /// **'Report downtime'**
  String get biomedicalReportDowntimeAction;

  /// Action label for closing downtime.
  ///
  /// In en, this message translates to:
  /// **'Close downtime'**
  String get biomedicalCloseDowntimeAction;

  /// Action label for logging biomedical incident.
  ///
  /// In en, this message translates to:
  /// **'Log incident'**
  String get biomedicalLogIncidentAction;

  /// Action label for acknowledging recall.
  ///
  /// In en, this message translates to:
  /// **'Acknowledge recall'**
  String get biomedicalAcknowledgeRecallAction;

  /// Action label for equipment disposal or transfer.
  ///
  /// In en, this message translates to:
  /// **'Dispose or transfer'**
  String get biomedicalDisposeTransferAction;

  /// Action label for previewing biomedical report.
  ///
  /// In en, this message translates to:
  /// **'Preview report'**
  String get biomedicalPrintReportAction;

  /// Dialog title for registering equipment.
  ///
  /// In en, this message translates to:
  /// **'Register equipment'**
  String get biomedicalRegisterAssetDialogTitle;

  /// Dialog title for editing equipment.
  ///
  /// In en, this message translates to:
  /// **'Edit equipment'**
  String get biomedicalEditAssetDialogTitle;

  /// Dialog title for transferring equipment.
  ///
  /// In en, this message translates to:
  /// **'Transfer equipment location'**
  String get biomedicalTransferLocationDialogTitle;

  /// Dialog title for scheduling maintenance.
  ///
  /// In en, this message translates to:
  /// **'Schedule maintenance'**
  String get biomedicalScheduleMaintenanceDialogTitle;

  /// Dialog title for creating work order.
  ///
  /// In en, this message translates to:
  /// **'Create work order'**
  String get biomedicalWorkOrderDialogTitle;

  /// Dialog title for updating work order.
  ///
  /// In en, this message translates to:
  /// **'Update work order'**
  String get biomedicalUpdateWorkOrderDialogTitle;

  /// Dialog title for starting work order.
  ///
  /// In en, this message translates to:
  /// **'Start work order'**
  String get biomedicalStartWorkOrderDialogTitle;

  /// Dialog title for returning equipment to service.
  ///
  /// In en, this message translates to:
  /// **'Return equipment to service'**
  String get biomedicalReturnToServiceDialogTitle;

  /// Dialog title for recording calibration.
  ///
  /// In en, this message translates to:
  /// **'Record calibration'**
  String get biomedicalCalibrationDialogTitle;

  /// Dialog title for recording safety test.
  ///
  /// In en, this message translates to:
  /// **'Record safety test'**
  String get biomedicalSafetyTestDialogTitle;

  /// Dialog title for reporting downtime.
  ///
  /// In en, this message translates to:
  /// **'Report downtime'**
  String get biomedicalDowntimeDialogTitle;

  /// Dialog title for closing downtime.
  ///
  /// In en, this message translates to:
  /// **'Close downtime'**
  String get biomedicalCloseDowntimeDialogTitle;

  /// Dialog title for logging incident.
  ///
  /// In en, this message translates to:
  /// **'Log incident'**
  String get biomedicalIncidentDialogTitle;

  /// Dialog title for acknowledging recall.
  ///
  /// In en, this message translates to:
  /// **'Acknowledge recall'**
  String get biomedicalRecallDialogTitle;

  /// Dialog title for disposal or transfer.
  ///
  /// In en, this message translates to:
  /// **'Dispose or transfer equipment'**
  String get biomedicalDisposalDialogTitle;

  /// Dialog title for reporting equipment fault.
  ///
  /// In en, this message translates to:
  /// **'Report equipment fault'**
  String get biomedicalFaultDialogTitle;

  /// Dialog title for biomedical report preview.
  ///
  /// In en, this message translates to:
  /// **'Biomedical report'**
  String get biomedicalPrintReportDialogTitle;

  /// Form label for equipment name.
  ///
  /// In en, this message translates to:
  /// **'Equipment name'**
  String get biomedicalAssetNameLabel;

  /// Form label for asset code.
  ///
  /// In en, this message translates to:
  /// **'Asset code'**
  String get biomedicalAssetCodeLabel;

  /// Form label for serial number.
  ///
  /// In en, this message translates to:
  /// **'Serial number'**
  String get biomedicalSerialNumberLabel;

  /// Form label for room.
  ///
  /// In en, this message translates to:
  /// **'Room'**
  String get biomedicalRoomLabel;

  /// Form label for notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get biomedicalNotesLabel;

  /// Form label for description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get biomedicalDescriptionLabel;

  /// Form label for work order title.
  ///
  /// In en, this message translates to:
  /// **'Work order title'**
  String get biomedicalWorkOrderTitleLabel;

  /// Form label for engineer.
  ///
  /// In en, this message translates to:
  /// **'Engineer'**
  String get biomedicalEngineerLabel;

  /// Form label for maintenance plan name.
  ///
  /// In en, this message translates to:
  /// **'Plan name'**
  String get biomedicalPlanNameLabel;

  /// Form label for maintenance type.
  ///
  /// In en, this message translates to:
  /// **'Maintenance type'**
  String get biomedicalMaintenanceTypeLabel;

  /// Form label for maintenance frequency days.
  ///
  /// In en, this message translates to:
  /// **'Frequency days'**
  String get biomedicalFrequencyDaysLabel;

  /// Form label for next due date time.
  ///
  /// In en, this message translates to:
  /// **'Next due at'**
  String get biomedicalNextDueAtLabel;

  /// Form label for result.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get biomedicalResultLabel;

  /// Form label for calibration date.
  ///
  /// In en, this message translates to:
  /// **'Calibrated at'**
  String get biomedicalCalibratedAtLabel;

  /// Form label for safety test date.
  ///
  /// In en, this message translates to:
  /// **'Tested at'**
  String get biomedicalTestedAtLabel;

  /// Form label for downtime start date.
  ///
  /// In en, this message translates to:
  /// **'Downtime started'**
  String get biomedicalDowntimeStartedAtLabel;

  /// Form label for downtime end date.
  ///
  /// In en, this message translates to:
  /// **'Downtime ended'**
  String get biomedicalDowntimeEndedAtLabel;

  /// Form label for reason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get biomedicalReasonLabel;

  /// Form label for severity.
  ///
  /// In en, this message translates to:
  /// **'Severity'**
  String get biomedicalSeverityLabel;

  /// Form label for started at.
  ///
  /// In en, this message translates to:
  /// **'Started at'**
  String get biomedicalStartedAtLabel;

  /// Form label for recorded at.
  ///
  /// In en, this message translates to:
  /// **'Recorded at'**
  String get biomedicalRecordedAtLabel;

  /// Form label for effective date.
  ///
  /// In en, this message translates to:
  /// **'Effective at'**
  String get biomedicalEffectiveAtLabel;

  /// Form label for temporary equipment name in fault reports.
  ///
  /// In en, this message translates to:
  /// **'Temporary equipment name'**
  String get biomedicalReportedEquipmentNameLabel;

  /// Checkbox label for patient safety risk.
  ///
  /// In en, this message translates to:
  /// **'Patient safety risk'**
  String get biomedicalPatientSafetyRiskLabel;

  /// Hint for biomedical date time fields.
  ///
  /// In en, this message translates to:
  /// **'YYYY-MM-DDTHH:MM'**
  String get biomedicalDateTimeHint;

  /// Submit action label for biomedical dialogs.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get biomedicalSubmitAction;

  /// Save action label for biomedical dialogs.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get biomedicalSaveAction;

  /// Create action label for biomedical dialogs.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get biomedicalCreateAction;

  /// Validation message for required biomedical fields.
  ///
  /// In en, this message translates to:
  /// **'{label} is required.'**
  String biomedicalFieldRequiredLabel(String label);

  /// Biomedical overview panel label.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get biomedicalPanelOverview;

  /// Biomedical registry panel label.
  ///
  /// In en, this message translates to:
  /// **'Registry'**
  String get biomedicalPanelRegistry;

  /// Biomedical preventive maintenance panel label.
  ///
  /// In en, this message translates to:
  /// **'Preventive'**
  String get biomedicalPanelPreventive;

  /// Biomedical work orders panel label.
  ///
  /// In en, this message translates to:
  /// **'Work orders'**
  String get biomedicalPanelWorkOrders;

  /// Biomedical compliance panel label.
  ///
  /// In en, this message translates to:
  /// **'Compliance'**
  String get biomedicalPanelCompliance;

  /// Biomedical support panel label.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get biomedicalPanelSupport;

  /// Biomedical analytics panel label.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get biomedicalPanelAnalytics;

  /// Biomedical date preset for today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get biomedicalDatePresetToday;

  /// Biomedical date preset for next 7 days.
  ///
  /// In en, this message translates to:
  /// **'Next 7 days'**
  String get biomedicalDatePresetNext7Days;

  /// Biomedical date preset for overdue items.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get biomedicalDatePresetOverdue;

  /// Biomedical date preset for this month.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get biomedicalDatePresetThisMonth;

  /// Next action label for maintenance records.
  ///
  /// In en, this message translates to:
  /// **'Perform maintenance'**
  String get biomedicalNextActionMaintain;

  /// Next action label for calibration and safety records.
  ///
  /// In en, this message translates to:
  /// **'Review compliance'**
  String get biomedicalNextActionCalibrate;

  /// Next action label for downtime records.
  ///
  /// In en, this message translates to:
  /// **'Return to service'**
  String get biomedicalNextActionReturnService;

  /// Next action label for recall records.
  ///
  /// In en, this message translates to:
  /// **'Review recall'**
  String get biomedicalNextActionReviewRecall;

  /// Next action label for work orders.
  ///
  /// In en, this message translates to:
  /// **'Work order follow-up'**
  String get biomedicalNextActionWorkOrder;

  /// Default next action label for biomedical records.
  ///
  /// In en, this message translates to:
  /// **'Review record'**
  String get biomedicalNextActionReview;

  /// Body text for the biomedical report preview.
  ///
  /// In en, this message translates to:
  /// **'Generated from backend-backed biomedical registry, readiness, compliance, and lifecycle data.'**
  String get biomedicalPrintReportBody;

  /// Localized text for integrationsLoadErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Integrations could not load'**
  String get integrationsLoadErrorTitle;

  /// Localized text for integrationsLoadErrorBody.
  ///
  /// In en, this message translates to:
  /// **'Refresh the workspace or check service availability.'**
  String get integrationsLoadErrorBody;

  /// Localized text for integrationsLoadingTitle.
  ///
  /// In en, this message translates to:
  /// **'Loading integrations'**
  String get integrationsLoadingTitle;

  /// Localized text for integrationsLoadingBody.
  ///
  /// In en, this message translates to:
  /// **'Preparing integrations, API keys, webhooks, and logs.'**
  String get integrationsLoadingBody;

  /// Localized text for integrationsFailedStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get integrationsFailedStatusLabel;

  /// Localized text for integrationsWarningStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get integrationsWarningStatusLabel;

  /// Localized text for integrationsOperationalStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Operational'**
  String get integrationsOperationalStatusLabel;

  /// Localized text for integrationsWorkspaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Integrations'**
  String get integrationsWorkspaceTitle;

  /// Localized text for integrationsCreateIntegrationAction.
  ///
  /// In en, this message translates to:
  /// **'Create integration'**
  String get integrationsCreateIntegrationAction;

  /// Localized text for integrationsCreateApiKeyAction.
  ///
  /// In en, this message translates to:
  /// **'Create API key'**
  String get integrationsCreateApiKeyAction;

  /// Localized text for integrationsCreateWebhookAction.
  ///
  /// In en, this message translates to:
  /// **'Create webhook'**
  String get integrationsCreateWebhookAction;

  /// Localized text for integrationsAllSummaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Total items'**
  String get integrationsAllSummaryLabel;

  /// Localized text for integrationsActiveSummaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get integrationsActiveSummaryLabel;

  /// Localized text for integrationsWarningsSummaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Warnings'**
  String get integrationsWarningsSummaryLabel;

  /// Localized text for integrationsFailedSummaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get integrationsFailedSummaryLabel;

  /// Localized text for integrationsApiKeysSummaryLabel.
  ///
  /// In en, this message translates to:
  /// **'API keys'**
  String get integrationsApiKeysSummaryLabel;

  /// Localized text for integrationsWebhooksSummaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Webhooks'**
  String get integrationsWebhooksSummaryLabel;

  /// Localized text for integrationsWorklistTitle.
  ///
  /// In en, this message translates to:
  /// **'Integration worklist'**
  String get integrationsWorklistTitle;

  /// Localized text for integrationsWorklistDescription.
  ///
  /// In en, this message translates to:
  /// **'Review integrations, API keys, webhooks, sanitized logs, and interoperability readiness.'**
  String get integrationsWorklistDescription;

  /// Localized text for integrationsSearchLabel.
  ///
  /// In en, this message translates to:
  /// **'Search integrations'**
  String get integrationsSearchLabel;

  /// Localized text for integrationsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name, type, status, owner, or reference'**
  String get integrationsSearchHint;

  /// Localized text for integrationsFiltersLabel.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get integrationsFiltersLabel;

  /// Localized text for integrationsFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get integrationsFilterAll;

  /// Localized text for integrationsFilterGroupLabel.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get integrationsFilterGroupLabel;

  /// Localized text for integrationsPreviousPageLabel.
  ///
  /// In en, this message translates to:
  /// **'Previous page'**
  String get integrationsPreviousPageLabel;

  /// Localized text for integrationsNextPageLabel.
  ///
  /// In en, this message translates to:
  /// **'Next page'**
  String get integrationsNextPageLabel;

  /// Localized text for integrationsPageLabel.
  ///
  /// In en, this message translates to:
  /// **'{from}-{to} of {total}'**
  String integrationsPageLabel(int from, int to, int total);

  /// Localized text for integrationsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No integration items'**
  String get integrationsEmptyTitle;

  /// Localized text for integrationsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Create an integration, API key, or webhook to populate this workspace.'**
  String get integrationsEmptyBody;

  /// Localized text for integrationsTypeColumnLabel.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get integrationsTypeColumnLabel;

  /// Localized text for integrationsNameColumnLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get integrationsNameColumnLabel;

  /// Localized text for integrationsStatusColumnLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get integrationsStatusColumnLabel;

  /// Localized text for integrationsOwnerColumnLabel.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get integrationsOwnerColumnLabel;

  /// Localized text for integrationsScopeColumnLabel.
  ///
  /// In en, this message translates to:
  /// **'Scope'**
  String get integrationsScopeColumnLabel;

  /// Localized text for integrationsLastEventColumnLabel.
  ///
  /// In en, this message translates to:
  /// **'Last event'**
  String get integrationsLastEventColumnLabel;

  /// Localized text for integrationsNextActionColumnLabel.
  ///
  /// In en, this message translates to:
  /// **'Next action'**
  String get integrationsNextActionColumnLabel;

  /// Localized text for integrationsMobileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{kind} | {scope}'**
  String integrationsMobileSubtitle(String kind, String scope);

  /// Localized text for integrationsNoSelectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Select an integration item'**
  String get integrationsNoSelectionTitle;

  /// Localized text for integrationsNoSelectionBody.
  ///
  /// In en, this message translates to:
  /// **'Choose a row to review configuration, keys, webhooks, logs, and available actions.'**
  String get integrationsNoSelectionBody;

  /// Localized text for integrationsConfigureAction.
  ///
  /// In en, this message translates to:
  /// **'Configure'**
  String get integrationsConfigureAction;

  /// Localized text for integrationsTestConnectionAction.
  ///
  /// In en, this message translates to:
  /// **'Test connection'**
  String get integrationsTestConnectionAction;

  /// Localized text for integrationsSyncNowAction.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get integrationsSyncNowAction;

  /// Localized text for integrationsDisableAction.
  ///
  /// In en, this message translates to:
  /// **'Disable'**
  String get integrationsDisableAction;

  /// Localized text for integrationsEnableAction.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get integrationsEnableAction;

  /// Localized text for integrationsManagePermissionsAction.
  ///
  /// In en, this message translates to:
  /// **'Manage permissions'**
  String get integrationsManagePermissionsAction;

  /// Localized text for integrationsRevokeApiKeyAction.
  ///
  /// In en, this message translates to:
  /// **'Revoke key'**
  String get integrationsRevokeApiKeyAction;

  /// Localized text for integrationsEditWebhookAction.
  ///
  /// In en, this message translates to:
  /// **'Edit webhook'**
  String get integrationsEditWebhookAction;

  /// Localized text for integrationsReplayWebhookAction.
  ///
  /// In en, this message translates to:
  /// **'Replay webhook'**
  String get integrationsReplayWebhookAction;

  /// Localized text for integrationsReplayLogAction.
  ///
  /// In en, this message translates to:
  /// **'Replay log'**
  String get integrationsReplayLogAction;

  /// Localized text for integrationsReferenceLabel.
  ///
  /// In en, this message translates to:
  /// **'Reference'**
  String get integrationsReferenceLabel;

  /// Localized text for integrationsActionResultTitle.
  ///
  /// In en, this message translates to:
  /// **'Latest action result'**
  String get integrationsActionResultTitle;

  /// Localized text for integrationsMaskedSecretTitle.
  ///
  /// In en, this message translates to:
  /// **'Masked key'**
  String get integrationsMaskedSecretTitle;

  /// Localized text for integrationsRotationGapTitle.
  ///
  /// In en, this message translates to:
  /// **'Key rotation gap'**
  String get integrationsRotationGapTitle;

  /// Localized text for integrationsRotationGapBody.
  ///
  /// In en, this message translates to:
  /// **'The backend does not expose a rotate endpoint. Create a replacement key, update downstream systems, then revoke the old key.'**
  String get integrationsRotationGapBody;

  /// Localized text for integrationsEventLabel.
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get integrationsEventLabel;

  /// Localized text for integrationsTargetHostLabel.
  ///
  /// In en, this message translates to:
  /// **'Target host'**
  String get integrationsTargetHostLabel;

  /// Localized text for integrationsIntegrationLabel.
  ///
  /// In en, this message translates to:
  /// **'Integration'**
  String get integrationsIntegrationLabel;

  /// Localized text for integrationsSanitizedLogTitle.
  ///
  /// In en, this message translates to:
  /// **'Sanitized log message'**
  String get integrationsSanitizedLogTitle;

  /// Localized text for integrationsInteropReadyBody.
  ///
  /// In en, this message translates to:
  /// **'Interoperability actions are available through the backend action endpoints.'**
  String get integrationsInteropReadyBody;

  /// Localized text for integrationsConfigurationTitle.
  ///
  /// In en, this message translates to:
  /// **'Configuration'**
  String get integrationsConfigurationTitle;

  /// Localized text for integrationsConfigurationMaskedBody.
  ///
  /// In en, this message translates to:
  /// **'Sensitive values are masked by the backend response.'**
  String get integrationsConfigurationMaskedBody;

  /// Localized text for integrationsConfigurationEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'No configuration values are available for this integration.'**
  String get integrationsConfigurationEmptyBody;

  /// Localized text for integrationsNoConfigurationRows.
  ///
  /// In en, this message translates to:
  /// **'No configuration rows'**
  String get integrationsNoConfigurationRows;

  /// Localized text for integrationsRelatedWebhooksTitle.
  ///
  /// In en, this message translates to:
  /// **'Related webhooks'**
  String get integrationsRelatedWebhooksTitle;

  /// Localized text for integrationsNoRelatedWebhooks.
  ///
  /// In en, this message translates to:
  /// **'No related webhooks'**
  String get integrationsNoRelatedWebhooks;

  /// Localized text for integrationsRelatedLogsTitle.
  ///
  /// In en, this message translates to:
  /// **'Related logs'**
  String get integrationsRelatedLogsTitle;

  /// Localized text for integrationsNoRelatedLogs.
  ///
  /// In en, this message translates to:
  /// **'No related logs'**
  String get integrationsNoRelatedLogs;

  /// Localized text for integrationsPermissionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get integrationsPermissionsTitle;

  /// Localized text for integrationsNoPermissions.
  ///
  /// In en, this message translates to:
  /// **'No permissions granted'**
  String get integrationsNoPermissions;

  /// Localized text for integrationsRemovePermissionDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove permission?'**
  String get integrationsRemovePermissionDialogTitle;

  /// Localized text for integrationsRemovePermissionDialogBody.
  ///
  /// In en, this message translates to:
  /// **'This API key will immediately lose the selected permission.'**
  String get integrationsRemovePermissionDialogBody;

  /// Localized text for integrationsRemovePermissionAction.
  ///
  /// In en, this message translates to:
  /// **'Remove permission'**
  String get integrationsRemovePermissionAction;

  /// Localized text for integrationsNameFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get integrationsNameFieldLabel;

  /// Localized text for integrationsNameRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter a name.'**
  String get integrationsNameRequiredMessage;

  /// Localized text for integrationsTypeFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get integrationsTypeFieldLabel;

  /// Localized text for integrationsConfigFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Configuration'**
  String get integrationsConfigFieldLabel;

  /// Localized text for integrationsConfigCreateHelper.
  ///
  /// In en, this message translates to:
  /// **'Enter one key=value setting per line. Sensitive keys are accepted but are not shown again.'**
  String get integrationsConfigCreateHelper;

  /// Localized text for integrationsConfigUpdateHelper.
  ///
  /// In en, this message translates to:
  /// **'Enter only settings to change. Existing sensitive values are not shown here.'**
  String get integrationsConfigUpdateHelper;

  /// Localized text for integrationsCreateIntegrationSubmitAction.
  ///
  /// In en, this message translates to:
  /// **'Create integration'**
  String get integrationsCreateIntegrationSubmitAction;

  /// Localized text for integrationsSaveIntegrationAction.
  ///
  /// In en, this message translates to:
  /// **'Save integration'**
  String get integrationsSaveIntegrationAction;

  /// Localized text for integrationsApiKeyNameFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Key name'**
  String get integrationsApiKeyNameFieldLabel;

  /// Localized text for integrationsApiKeyNameRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter a key name.'**
  String get integrationsApiKeyNameRequiredMessage;

  /// Localized text for integrationsExpiresAtFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Expires at'**
  String get integrationsExpiresAtFieldLabel;

  /// Localized text for integrationsIsoDateHint.
  ///
  /// In en, this message translates to:
  /// **'YYYY-MM-DD or ISO timestamp'**
  String get integrationsIsoDateHint;

  /// Localized text for integrationsCreateApiKeySubmitAction.
  ///
  /// In en, this message translates to:
  /// **'Create API key'**
  String get integrationsCreateApiKeySubmitAction;

  /// Localized text for integrationsIntegrationFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Integration'**
  String get integrationsIntegrationFieldLabel;

  /// Localized text for integrationsEventFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get integrationsEventFieldLabel;

  /// Localized text for integrationsEventRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter an event name.'**
  String get integrationsEventRequiredMessage;

  /// Localized text for integrationsTargetUrlFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Target URL'**
  String get integrationsTargetUrlFieldLabel;

  /// Localized text for integrationsTargetUrlRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter a target URL.'**
  String get integrationsTargetUrlRequiredMessage;

  /// Localized text for integrationsWebhookActiveFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Webhook active'**
  String get integrationsWebhookActiveFieldLabel;

  /// Localized text for integrationsCreateWebhookSubmitAction.
  ///
  /// In en, this message translates to:
  /// **'Create webhook'**
  String get integrationsCreateWebhookSubmitAction;

  /// Localized text for integrationsSaveWebhookAction.
  ///
  /// In en, this message translates to:
  /// **'Save webhook'**
  String get integrationsSaveWebhookAction;

  /// Localized text for integrationsApiKeyFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get integrationsApiKeyFieldLabel;

  /// Localized text for integrationsApiKeyRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'Choose an API key.'**
  String get integrationsApiKeyRequiredMessage;

  /// Localized text for integrationsPermissionFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Permission'**
  String get integrationsPermissionFieldLabel;

  /// Localized text for integrationsPermissionRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'Choose a permission.'**
  String get integrationsPermissionRequiredMessage;

  /// Localized text for integrationsAddPermissionAction.
  ///
  /// In en, this message translates to:
  /// **'Add permission'**
  String get integrationsAddPermissionAction;

  /// Localized text for integrationsCreateIntegrationDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Create integration'**
  String get integrationsCreateIntegrationDialogTitle;

  /// Localized text for integrationsConfigureIntegrationDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Configure integration'**
  String get integrationsConfigureIntegrationDialogTitle;

  /// Localized text for integrationsCreateApiKeyDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Create API key'**
  String get integrationsCreateApiKeyDialogTitle;

  /// Localized text for integrationsCreateWebhookDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Create webhook'**
  String get integrationsCreateWebhookDialogTitle;

  /// Localized text for integrationsEditWebhookDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit webhook'**
  String get integrationsEditWebhookDialogTitle;

  /// Localized text for integrationsManagePermissionsDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Manage API key permissions'**
  String get integrationsManagePermissionsDialogTitle;

  /// Localized text for integrationsSecretMissing.
  ///
  /// In en, this message translates to:
  /// **'Secret not returned'**
  String get integrationsSecretMissing;

  /// Localized text for integrationsApiKeyCreatedDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'API key created'**
  String get integrationsApiKeyCreatedDialogTitle;

  /// Localized text for integrationsApiKeyCreatedSecretTitle.
  ///
  /// In en, this message translates to:
  /// **'One-time secret'**
  String get integrationsApiKeyCreatedSecretTitle;

  /// Localized text for integrationsApiKeyCreatedSecretBody.
  ///
  /// In en, this message translates to:
  /// **'This value is shown once. Store it securely before closing this dialog.'**
  String get integrationsApiKeyCreatedSecretBody;

  /// Localized text for integrationsCopySecretAction.
  ///
  /// In en, this message translates to:
  /// **'Copy secret'**
  String get integrationsCopySecretAction;

  /// Localized text for integrationsTestConnectionDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Test connection?'**
  String get integrationsTestConnectionDialogTitle;

  /// Localized text for integrationsTestConnectionDialogBody.
  ///
  /// In en, this message translates to:
  /// **'The backend will run the integration connection test.'**
  String get integrationsTestConnectionDialogBody;

  /// Localized text for integrationsSyncNowDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync now?'**
  String get integrationsSyncNowDialogTitle;

  /// Localized text for integrationsSyncNowDialogBody.
  ///
  /// In en, this message translates to:
  /// **'The backend will enqueue an immediate integration sync.'**
  String get integrationsSyncNowDialogBody;

  /// Localized text for integrationsEnableIntegrationDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable integration?'**
  String get integrationsEnableIntegrationDialogTitle;

  /// Localized text for integrationsDisableIntegrationDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Disable integration?'**
  String get integrationsDisableIntegrationDialogTitle;

  /// Localized text for integrationsEnableIntegrationDialogBody.
  ///
  /// In en, this message translates to:
  /// **'This integration will become available for downstream workflows.'**
  String get integrationsEnableIntegrationDialogBody;

  /// Localized text for integrationsDisableIntegrationDialogBody.
  ///
  /// In en, this message translates to:
  /// **'This integration will stop participating in downstream workflows.'**
  String get integrationsDisableIntegrationDialogBody;

  /// Localized text for integrationsEnableApiKeyDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable API key?'**
  String get integrationsEnableApiKeyDialogTitle;

  /// Localized text for integrationsDisableApiKeyDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Disable API key?'**
  String get integrationsDisableApiKeyDialogTitle;

  /// Localized text for integrationsEnableApiKeyDialogBody.
  ///
  /// In en, this message translates to:
  /// **'This API key can authenticate requests again.'**
  String get integrationsEnableApiKeyDialogBody;

  /// Localized text for integrationsDisableApiKeyDialogBody.
  ///
  /// In en, this message translates to:
  /// **'This API key will stop authenticating requests.'**
  String get integrationsDisableApiKeyDialogBody;

  /// Localized text for integrationsEnableWebhookDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable webhook?'**
  String get integrationsEnableWebhookDialogTitle;

  /// Localized text for integrationsDisableWebhookDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Disable webhook?'**
  String get integrationsDisableWebhookDialogTitle;

  /// Localized text for integrationsEnableWebhookDialogBody.
  ///
  /// In en, this message translates to:
  /// **'This webhook will receive matching events again.'**
  String get integrationsEnableWebhookDialogBody;

  /// Localized text for integrationsDisableWebhookDialogBody.
  ///
  /// In en, this message translates to:
  /// **'This webhook will stop receiving matching events.'**
  String get integrationsDisableWebhookDialogBody;

  /// Localized text for integrationsRevokeApiKeyDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Revoke API key?'**
  String get integrationsRevokeApiKeyDialogTitle;

  /// Localized text for integrationsRevokeApiKeyDialogBody.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes the API key and its local permission grants.'**
  String get integrationsRevokeApiKeyDialogBody;

  /// Localized text for integrationsReplayWebhookDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Replay webhook?'**
  String get integrationsReplayWebhookDialogTitle;

  /// Localized text for integrationsReplayWebhookDialogBody.
  ///
  /// In en, this message translates to:
  /// **'The backend will replay the webhook delivery.'**
  String get integrationsReplayWebhookDialogBody;

  /// Localized text for integrationsReplayLogDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Replay log?'**
  String get integrationsReplayLogDialogTitle;

  /// Localized text for integrationsReplayLogDialogBody.
  ///
  /// In en, this message translates to:
  /// **'The backend will retry the logged integration event.'**
  String get integrationsReplayLogDialogBody;

  /// Localized text for integrationsFilterIntegrations.
  ///
  /// In en, this message translates to:
  /// **'Integrations'**
  String get integrationsFilterIntegrations;

  /// Localized text for integrationsFilterApiKeys.
  ///
  /// In en, this message translates to:
  /// **'API keys'**
  String get integrationsFilterApiKeys;

  /// Localized text for integrationsFilterWebhooks.
  ///
  /// In en, this message translates to:
  /// **'Webhooks'**
  String get integrationsFilterWebhooks;

  /// Localized text for integrationsFilterLogs.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get integrationsFilterLogs;

  /// Localized text for integrationsFilterInterop.
  ///
  /// In en, this message translates to:
  /// **'Interop'**
  String get integrationsFilterInterop;

  /// Localized text for integrationsFilterActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get integrationsFilterActive;

  /// Localized text for integrationsFilterWarning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get integrationsFilterWarning;

  /// Localized text for integrationsFilterFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get integrationsFilterFailed;

  /// Localized text for integrationsFilterDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get integrationsFilterDisabled;

  /// Localized text for integrationsTypeHl7.
  ///
  /// In en, this message translates to:
  /// **'HL7'**
  String get integrationsTypeHl7;

  /// Localized text for integrationsTypeFhir.
  ///
  /// In en, this message translates to:
  /// **'FHIR'**
  String get integrationsTypeFhir;

  /// Localized text for integrationsTypeLab.
  ///
  /// In en, this message translates to:
  /// **'Lab'**
  String get integrationsTypeLab;

  /// Localized text for integrationsTypeRadiology.
  ///
  /// In en, this message translates to:
  /// **'Radiology'**
  String get integrationsTypeRadiology;

  /// Localized text for integrationsTypeBilling.
  ///
  /// In en, this message translates to:
  /// **'Billing'**
  String get integrationsTypeBilling;

  /// Localized text for integrationsTypeOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get integrationsTypeOther;

  /// Localized text for integrationsStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get integrationsStatusActive;

  /// Localized text for integrationsStatusInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get integrationsStatusInactive;

  /// Localized text for integrationsStatusError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get integrationsStatusError;

  /// Localized text for integrationsStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get integrationsStatusFailed;

  /// Localized text for integrationsStatusReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get integrationsStatusReady;

  /// Localized text for integrationsStatusBackendGap.
  ///
  /// In en, this message translates to:
  /// **'Backend gap'**
  String get integrationsStatusBackendGap;

  /// Localized text for integrationsStatusQueued.
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get integrationsStatusQueued;

  /// Localized text for integrationsStatusConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get integrationsStatusConnected;

  /// Localized text for integrationsKindIntegration.
  ///
  /// In en, this message translates to:
  /// **'Integration'**
  String get integrationsKindIntegration;

  /// Localized text for integrationsKindApiKey.
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get integrationsKindApiKey;

  /// Localized text for integrationsKindWebhook.
  ///
  /// In en, this message translates to:
  /// **'Webhook'**
  String get integrationsKindWebhook;

  /// Localized text for integrationsKindLog.
  ///
  /// In en, this message translates to:
  /// **'Log'**
  String get integrationsKindLog;

  /// Localized text for integrationsKindInterop.
  ///
  /// In en, this message translates to:
  /// **'Interop'**
  String get integrationsKindInterop;

  /// Localized text for integrationsNoScopesLabel.
  ///
  /// In en, this message translates to:
  /// **'No scopes'**
  String get integrationsNoScopesLabel;

  /// Localized text for integrationsOneScopeLabel.
  ///
  /// In en, this message translates to:
  /// **'1 scope'**
  String get integrationsOneScopeLabel;

  /// Localized text for integrationsInteropFhirScope.
  ///
  /// In en, this message translates to:
  /// **'FHIR exchange'**
  String get integrationsInteropFhirScope;

  /// Localized text for integrationsInteropHl7Scope.
  ///
  /// In en, this message translates to:
  /// **'HL7 messaging'**
  String get integrationsInteropHl7Scope;

  /// Localized text for integrationsInteropDicomScope.
  ///
  /// In en, this message translates to:
  /// **'DICOM linking'**
  String get integrationsInteropDicomScope;

  /// Localized text for integrationsInteropMigrationScope.
  ///
  /// In en, this message translates to:
  /// **'Migration import and export'**
  String get integrationsInteropMigrationScope;

  /// Localized text for integrationsInteropStatusScope.
  ///
  /// In en, this message translates to:
  /// **'Readiness status'**
  String get integrationsInteropStatusScope;

  /// Localized text for integrationsManyScopesLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} scopes'**
  String integrationsManyScopesLabel(String count);

  /// Localized text for integrationsNextActionReviewFailure.
  ///
  /// In en, this message translates to:
  /// **'Review failure'**
  String get integrationsNextActionReviewFailure;

  /// Localized text for integrationsNextActionEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable item'**
  String get integrationsNextActionEnable;

  /// Localized text for integrationsNextActionMonitor.
  ///
  /// In en, this message translates to:
  /// **'Monitor'**
  String get integrationsNextActionMonitor;

  /// Localized text for integrationsNextActionReviewKey.
  ///
  /// In en, this message translates to:
  /// **'Review key'**
  String get integrationsNextActionReviewKey;

  /// Localized text for integrationsNextActionRotateOrMonitor.
  ///
  /// In en, this message translates to:
  /// **'Rotate or monitor'**
  String get integrationsNextActionRotateOrMonitor;

  /// Localized text for integrationsNextActionEnableWebhook.
  ///
  /// In en, this message translates to:
  /// **'Enable webhook'**
  String get integrationsNextActionEnableWebhook;

  /// Localized text for integrationsNextActionMonitorDelivery.
  ///
  /// In en, this message translates to:
  /// **'Monitor delivery'**
  String get integrationsNextActionMonitorDelivery;

  /// Localized text for integrationsNextActionReplayOrEscalate.
  ///
  /// In en, this message translates to:
  /// **'Replay or escalate'**
  String get integrationsNextActionReplayOrEscalate;

  /// Localized text for integrationsNextActionReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get integrationsNextActionReview;

  /// Localized text for integrationsNextActionRunEndpoint.
  ///
  /// In en, this message translates to:
  /// **'Run endpoint'**
  String get integrationsNextActionRunEndpoint;

  /// Localized text for integrationsNextActionUseStatusLogs.
  ///
  /// In en, this message translates to:
  /// **'Use status logs'**
  String get integrationsNextActionUseStatusLogs;

  /// Localized text for integrationsInteropFhirTitle.
  ///
  /// In en, this message translates to:
  /// **'FHIR exchange'**
  String get integrationsInteropFhirTitle;

  /// Localized text for integrationsInteropHl7Title.
  ///
  /// In en, this message translates to:
  /// **'HL7 messages'**
  String get integrationsInteropHl7Title;

  /// Localized text for integrationsInteropDicomTitle.
  ///
  /// In en, this message translates to:
  /// **'DICOM study linking'**
  String get integrationsInteropDicomTitle;

  /// Localized text for integrationsInteropMigrationTitle.
  ///
  /// In en, this message translates to:
  /// **'Migration tools'**
  String get integrationsInteropMigrationTitle;

  /// Localized text for integrationsInteropReadinessTitle.
  ///
  /// In en, this message translates to:
  /// **'Interop readiness'**
  String get integrationsInteropReadinessTitle;

  /// Localized text for integrationsInteropReadinessGapBody.
  ///
  /// In en, this message translates to:
  /// **'No dedicated interoperability readiness endpoint is exposed. Use integration status and sanitized logs until the backend adds one.'**
  String get integrationsInteropReadinessGapBody;

  /// Localized text for integrationsSavedMessage.
  ///
  /// In en, this message translates to:
  /// **'Integration changes saved.'**
  String get integrationsSavedMessage;

  /// Title for the reports and audit workspace.
  ///
  /// In en, this message translates to:
  /// **'Reports and audit'**
  String get reportsTitle;

  /// Loading title for the reports workspace.
  ///
  /// In en, this message translates to:
  /// **'Loading reports workspace'**
  String get reportsLoadingTitle;

  /// Loading body for the reports workspace.
  ///
  /// In en, this message translates to:
  /// **'Fetching report definitions, runs, schedules, dashboards, and audit evidence.'**
  String get reportsLoadingBody;

  /// Status label when the reports workspace is live.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get reportsLiveStatus;

  /// Status label while a report action is saving.
  ///
  /// In en, this message translates to:
  /// **'Saving'**
  String get reportsSavingStatus;

  /// Action label to run a report.
  ///
  /// In en, this message translates to:
  /// **'Run report'**
  String get reportsRunAction;

  /// Action label to schedule a report.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get reportsScheduleAction;

  /// Action label to retry a report run.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get reportsRetryAction;

  /// Action label to cancel a report run.
  ///
  /// In en, this message translates to:
  /// **'Cancel run'**
  String get reportsCancelRunAction;

  /// Action label to download a generated report.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get reportsDownloadAction;

  /// Action label to print report or evidence details.
  ///
  /// In en, this message translates to:
  /// **'Print'**
  String get reportsPrintAction;

  /// Action label to export compliance evidence.
  ///
  /// In en, this message translates to:
  /// **'Export evidence'**
  String get reportsExportEvidenceAction;

  /// Accessible label for reports workspace search.
  ///
  /// In en, this message translates to:
  /// **'Search reports and logs'**
  String get reportsSearchLabel;

  /// Search hint for report data.
  ///
  /// In en, this message translates to:
  /// **'Search report name, module, owner, status, or record'**
  String get reportsSearchHint;

  /// Search hint for compliance logs.
  ///
  /// In en, this message translates to:
  /// **'Search user, action, record, patient, purpose, or reason'**
  String get reportsComplianceSearchHint;

  /// Clear search action label for reports search.
  ///
  /// In en, this message translates to:
  /// **'Clear reports search'**
  String get reportsClearSearchLabel;

  /// Advanced filter dialog label for reports.
  ///
  /// In en, this message translates to:
  /// **'Report filters'**
  String get reportsFiltersLabel;

  /// Filter label for reports workspace panel.
  ///
  /// In en, this message translates to:
  /// **'Workspace panel'**
  String get reportsPanelFilterLabel;

  /// Filter label for report status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get reportsStatusFilterLabel;

  /// Filter label for report output format.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get reportsFormatFilterLabel;

  /// Filter label for report dataset.
  ///
  /// In en, this message translates to:
  /// **'Dataset'**
  String get reportsDatasetFilterLabel;

  /// Filter label for report date range.
  ///
  /// In en, this message translates to:
  /// **'Date range'**
  String get reportsDateFilterLabel;

  /// Start date label for report filters.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get reportsDateFromLabel;

  /// End date label for report filters.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get reportsDateToLabel;

  /// Date picker button label for report filters.
  ///
  /// In en, this message translates to:
  /// **'Choose date'**
  String get reportsDatePickerLabel;

  /// Validation message for invalid report filter dates.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid date.'**
  String get reportsInvalidDateMessage;

  /// Filter label for compliance event type.
  ///
  /// In en, this message translates to:
  /// **'Event type'**
  String get reportsComplianceTypeFilterLabel;

  /// All statuses filter label.
  ///
  /// In en, this message translates to:
  /// **'All statuses'**
  String get reportsAllStatusesLabel;

  /// All formats filter label.
  ///
  /// In en, this message translates to:
  /// **'All formats'**
  String get reportsAllFormatsLabel;

  /// All datasets filter label.
  ///
  /// In en, this message translates to:
  /// **'All datasets'**
  String get reportsAllDatasetsLabel;

  /// Reports workspace overview panel label.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get reportsPanelOverview;

  /// Reports workspace catalog panel label.
  ///
  /// In en, this message translates to:
  /// **'Catalog'**
  String get reportsPanelCatalog;

  /// Reports workspace delivery panel label.
  ///
  /// In en, this message translates to:
  /// **'Runs and delivery'**
  String get reportsPanelDelivery;

  /// Reports workspace dashboards panel label.
  ///
  /// In en, this message translates to:
  /// **'Dashboards'**
  String get reportsPanelDashboards;

  /// Reports workspace KPI monitor panel label.
  ///
  /// In en, this message translates to:
  /// **'KPI monitor'**
  String get reportsPanelMonitor;

  /// Reports workspace analytics activity panel label.
  ///
  /// In en, this message translates to:
  /// **'Analytics activity'**
  String get reportsPanelActivity;

  /// Reports workspace audit logs panel label.
  ///
  /// In en, this message translates to:
  /// **'Audit logs'**
  String get reportsPanelAudit;

  /// Reports workspace PHI access panel label.
  ///
  /// In en, this message translates to:
  /// **'PHI access'**
  String get reportsPanelPhi;

  /// Reports workspace data processing logs panel label.
  ///
  /// In en, this message translates to:
  /// **'Processing logs'**
  String get reportsPanelProcessing;

  /// Description for the report worklist panel.
  ///
  /// In en, this message translates to:
  /// **'Search, filter, preview, run, schedule, print, and export backend-backed report records.'**
  String get reportsWorklistDescription;

  /// Description for compliance log worklists.
  ///
  /// In en, this message translates to:
  /// **'Search and review audit, PHI access, and data processing logs within permitted scope.'**
  String get reportsComplianceDescription;

  /// Title for report schedule list.
  ///
  /// In en, this message translates to:
  /// **'Schedules'**
  String get reportsSchedulesTitle;

  /// Description for report schedule list.
  ///
  /// In en, this message translates to:
  /// **'Saved schedules stay backend-backed and refresh independently from report runs.'**
  String get reportsSchedulesDescription;

  /// Empty state title for report records.
  ///
  /// In en, this message translates to:
  /// **'No report records'**
  String get reportsNoItemsTitle;

  /// Empty state body for report records.
  ///
  /// In en, this message translates to:
  /// **'No backend report records match the current filters.'**
  String get reportsNoItemsBody;

  /// Empty state title for report schedules.
  ///
  /// In en, this message translates to:
  /// **'No schedules'**
  String get reportsNoSchedulesTitle;

  /// Empty state body for report schedules.
  ///
  /// In en, this message translates to:
  /// **'No saved report schedules match this view.'**
  String get reportsNoSchedulesBody;

  /// Empty state title for compliance logs.
  ///
  /// In en, this message translates to:
  /// **'No compliance logs'**
  String get reportsNoComplianceLogsTitle;

  /// Empty state body for compliance logs.
  ///
  /// In en, this message translates to:
  /// **'No audit or compliance evidence matches the current filters.'**
  String get reportsNoComplianceLogsBody;

  /// Title for report preview panel.
  ///
  /// In en, this message translates to:
  /// **'Report preview'**
  String get reportsPreviewTitle;

  /// Title for compliance evidence detail panel.
  ///
  /// In en, this message translates to:
  /// **'Evidence detail'**
  String get reportsComplianceDetailTitle;

  /// No selection title in reports workspace.
  ///
  /// In en, this message translates to:
  /// **'No selection'**
  String get reportsNoSelectionTitle;

  /// No selection body in reports workspace.
  ///
  /// In en, this message translates to:
  /// **'Choose a report definition, run, widget, KPI, event, or schedule to preview generated details.'**
  String get reportsNoSelectionBody;

  /// No selection body for compliance detail.
  ///
  /// In en, this message translates to:
  /// **'Choose an audit, PHI access, or processing log to review evidence details.'**
  String get reportsNoComplianceSelectionBody;

  /// Report table name column label.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get reportsNameColumnLabel;

  /// Report table status column label.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get reportsStatusColumnLabel;

  /// Report reference label.
  ///
  /// In en, this message translates to:
  /// **'Reference'**
  String get reportsReferenceLabel;

  /// Report owner label.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get reportsOwnerLabel;

  /// Report updated timestamp column label.
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get reportsUpdatedColumnLabel;

  /// Report format column label.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get reportsFormatColumnLabel;

  /// Report category label.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get reportsCategoryLabel;

  /// Report dataset label.
  ///
  /// In en, this message translates to:
  /// **'Dataset'**
  String get reportsDatasetLabel;

  /// Report facility label.
  ///
  /// In en, this message translates to:
  /// **'Facility'**
  String get reportsFacilityLabel;

  /// Report value label.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get reportsValueLabel;

  /// Report error label.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get reportsErrorLabel;

  /// Compliance event column label.
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get reportsEventColumnLabel;

  /// Compliance user column label.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get reportsUserColumnLabel;

  /// Compliance record column label.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get reportsRecordColumnLabel;

  /// Compliance timestamp column label.
  ///
  /// In en, this message translates to:
  /// **'Timestamp'**
  String get reportsTimestampColumnLabel;

  /// Compliance patient label.
  ///
  /// In en, this message translates to:
  /// **'Patient'**
  String get reportsPatientLabel;

  /// Compliance action label.
  ///
  /// In en, this message translates to:
  /// **'Action'**
  String get reportsActionLabel;

  /// Compliance entity label.
  ///
  /// In en, this message translates to:
  /// **'Entity'**
  String get reportsEntityLabel;

  /// PHI access scope label.
  ///
  /// In en, this message translates to:
  /// **'Scope'**
  String get reportsScopeLabel;

  /// Data processing purpose label.
  ///
  /// In en, this message translates to:
  /// **'Purpose'**
  String get reportsPurposeLabel;

  /// Data processing legal basis label.
  ///
  /// In en, this message translates to:
  /// **'Legal basis'**
  String get reportsLegalBasisLabel;

  /// Audit IP address label.
  ///
  /// In en, this message translates to:
  /// **'IP address'**
  String get reportsIpAddressLabel;

  /// Compliance details label.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get reportsDetailsLabel;

  /// Previous page action label for reports tables.
  ///
  /// In en, this message translates to:
  /// **'Previous page'**
  String get reportsPreviousPageLabel;

  /// Next page action label for reports tables.
  ///
  /// In en, this message translates to:
  /// **'Next page'**
  String get reportsNextPageLabel;

  /// Pagination label for reports tables.
  ///
  /// In en, this message translates to:
  /// **'{first}-{last} of {total}'**
  String reportsPageLabel(int first, int last, int total);

  /// Title for recent report activity panel.
  ///
  /// In en, this message translates to:
  /// **'Recent report activity'**
  String get reportsTimelineTitle;

  /// Description for recent report activity panel.
  ///
  /// In en, this message translates to:
  /// **'Latest backend report runs, schedules, KPI snapshots, and analytics events.'**
  String get reportsTimelineDescription;

  /// Dialog title for running a report.
  ///
  /// In en, this message translates to:
  /// **'Run report'**
  String get reportsRunDialogTitle;

  /// Dialog title for retrying a report run.
  ///
  /// In en, this message translates to:
  /// **'Retry report run'**
  String get reportsRetryDialogTitle;

  /// Dialog title for scheduling a report.
  ///
  /// In en, this message translates to:
  /// **'Schedule report'**
  String get reportsScheduleDialogTitle;

  /// Output format field label.
  ///
  /// In en, this message translates to:
  /// **'Output format'**
  String get reportsFormatFieldLabel;

  /// Retention days field label.
  ///
  /// In en, this message translates to:
  /// **'Retention days'**
  String get reportsRetentionDaysFieldLabel;

  /// Schedule name field label.
  ///
  /// In en, this message translates to:
  /// **'Schedule name'**
  String get reportsScheduleNameFieldLabel;

  /// Frequency field label.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get reportsFrequencyFieldLabel;

  /// Time of day field label.
  ///
  /// In en, this message translates to:
  /// **'Time of day'**
  String get reportsTimeOfDayFieldLabel;

  /// Hint for report schedule time of day.
  ///
  /// In en, this message translates to:
  /// **'HH:mm'**
  String get reportsTimeOfDayHint;

  /// Action label to create a report schedule.
  ///
  /// In en, this message translates to:
  /// **'Create schedule'**
  String get reportsCreateScheduleAction;

  /// Daily report schedule frequency label.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get reportsFrequencyDaily;

  /// Weekly report schedule frequency label.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get reportsFrequencyWeekly;

  /// Monthly report schedule frequency label.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get reportsFrequencyMonthly;

  /// Dialog title for canceling a report run.
  ///
  /// In en, this message translates to:
  /// **'Cancel report run'**
  String get reportsCancelRunDialogTitle;

  /// Dialog body for canceling a report run.
  ///
  /// In en, this message translates to:
  /// **'Cancel this queued or processing report run? The run row will refresh after the backend confirms the change.'**
  String get reportsCancelRunDialogBody;

  /// Dialog title for exporting evidence.
  ///
  /// In en, this message translates to:
  /// **'Export evidence'**
  String get reportsExportEvidenceDialogTitle;

  /// Dialog body for exporting evidence.
  ///
  /// In en, this message translates to:
  /// **'Generate a facility-branded evidence document from this backend log record.'**
  String get reportsExportEvidenceDialogBody;

  /// Success message after reports workspace actions.
  ///
  /// In en, this message translates to:
  /// **'Reports workspace updated.'**
  String get reportsSavedMessage;

  /// Message after requesting report download.
  ///
  /// In en, this message translates to:
  /// **'Report download was requested from the backend.'**
  String get reportsDownloadRequestedMessage;

  /// Subtitle for printed report metadata.
  ///
  /// In en, this message translates to:
  /// **'Generated report metadata'**
  String get reportsPrintSubtitle;

  /// Subtitle for printed compliance evidence.
  ///
  /// In en, this message translates to:
  /// **'Compliance evidence'**
  String get reportsEvidenceSubtitle;

  /// Generated by metadata label.
  ///
  /// In en, this message translates to:
  /// **'Generated by'**
  String get reportsGeneratedByLabel;

  /// Footer for printed report documents.
  ///
  /// In en, this message translates to:
  /// **'Confidential report document generated from backend data.'**
  String get reportsPrintFooter;

  /// Footer for printed evidence documents.
  ///
  /// In en, this message translates to:
  /// **'Compliance evidence generated from backend audit data.'**
  String get reportsEvidenceFooter;

  /// Navigation label for the physiotherapy workspace.
  ///
  /// In en, this message translates to:
  /// **'Physiotherapy'**
  String get navigationPhysiotherapyLabel;

  /// Loading title for the communications workspace.
  ///
  /// In en, this message translates to:
  /// **'Loading communications'**
  String get communicationsLoadingTitle;

  /// Loading body for the communications workspace.
  ///
  /// In en, this message translates to:
  /// **'Loading notifications, conversations, delivery state, and templates.'**
  String get communicationsLoadingBody;

  /// Title for the communications workspace.
  ///
  /// In en, this message translates to:
  /// **'Communications'**
  String get communicationsWorkspaceTitle;

  /// Status label for synchronized communications data.
  ///
  /// In en, this message translates to:
  /// **'Live sync'**
  String get communicationsLiveStatus;

  /// Status label while communications changes are being saved.
  ///
  /// In en, this message translates to:
  /// **'Saving'**
  String get communicationsSavingStatus;

  /// Snackbar message after a communications action succeeds.
  ///
  /// In en, this message translates to:
  /// **'Communication action saved.'**
  String get communicationsActionSavedMessage;

  /// Snackbar message after a conversation message is sent.
  ///
  /// In en, this message translates to:
  /// **'Message sent.'**
  String get communicationsMessageSentMessage;

  /// Panel label for conversation inbox.
  ///
  /// In en, this message translates to:
  /// **'Inbox'**
  String get communicationsInboxPanelLabel;

  /// Panel label for notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get communicationsNotificationsPanelLabel;

  /// Panel label for notification deliveries.
  ///
  /// In en, this message translates to:
  /// **'Deliveries'**
  String get communicationsDeliveriesPanelLabel;

  /// Panel label for communication templates.
  ///
  /// In en, this message translates to:
  /// **'Templates'**
  String get communicationsTemplatesPanelLabel;

  /// Summary card label for unread conversation threads.
  ///
  /// In en, this message translates to:
  /// **'Unread threads'**
  String get communicationsUnreadThreadsSummaryLabel;

  /// Summary card label for unread notifications.
  ///
  /// In en, this message translates to:
  /// **'Unread alerts'**
  String get communicationsUnreadNotificationsSummaryLabel;

  /// Summary card label for failed notification deliveries.
  ///
  /// In en, this message translates to:
  /// **'Failed deliveries'**
  String get communicationsFailedDeliveriesSummaryLabel;

  /// Summary card label for communication templates.
  ///
  /// In en, this message translates to:
  /// **'Templates'**
  String get communicationsTemplatesSummaryLabel;

  /// Description for the communications worklist.
  ///
  /// In en, this message translates to:
  /// **'Find alerts, threads, delivery state, and message templates.'**
  String get communicationsListDescription;

  /// Accessibility label for communications search.
  ///
  /// In en, this message translates to:
  /// **'Search communications'**
  String get communicationsSearchSemanticLabel;

  /// Hint text for communications search.
  ///
  /// In en, this message translates to:
  /// **'Search alert, patient, source, sender, recipient, or message'**
  String get communicationsSearchHint;

  /// Action label for clearing communications search.
  ///
  /// In en, this message translates to:
  /// **'Clear communications search'**
  String get communicationsClearSearchAction;

  /// Action label for communications filters.
  ///
  /// In en, this message translates to:
  /// **'Communication filters'**
  String get communicationsAdvancedFiltersLabel;

  /// Dialog title for communications filters.
  ///
  /// In en, this message translates to:
  /// **'Communication filters'**
  String get communicationsAdvancedFiltersTitle;

  /// Action label for applying communications filters.
  ///
  /// In en, this message translates to:
  /// **'Apply filters'**
  String get communicationsApplyFiltersAction;

  /// Action label for resetting communications filters.
  ///
  /// In en, this message translates to:
  /// **'Reset filters'**
  String get communicationsResetFiltersAction;

  /// Filter group label for communications queues.
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get communicationsQueueFilterLabel;

  /// Filter group label for communications flags.
  ///
  /// In en, this message translates to:
  /// **'Flags'**
  String get communicationsFlagsFilterLabel;

  /// Filter option label for all communications.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get communicationsAllFilterLabel;

  /// Filter label for unread communications.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get communicationsUnreadFilterLabel;

  /// Filter label for sensitive communications.
  ///
  /// In en, this message translates to:
  /// **'Sensitive'**
  String get communicationsSensitiveFilterLabel;

  /// Pagination label for the previous communications page.
  ///
  /// In en, this message translates to:
  /// **'Previous communications page'**
  String get communicationsPreviousPageLabel;

  /// Pagination label for the next communications page.
  ///
  /// In en, this message translates to:
  /// **'Next communications page'**
  String get communicationsNextPageLabel;

  /// Pagination range label for communications tables.
  ///
  /// In en, this message translates to:
  /// **'{from}-{to} of {total}'**
  String communicationsPageLabel(int from, int to, int total);

  /// Conversation table thread column label.
  ///
  /// In en, this message translates to:
  /// **'Thread'**
  String get communicationsThreadColumnLabel;

  /// Conversation table participants column label.
  ///
  /// In en, this message translates to:
  /// **'Participants'**
  String get communicationsParticipantsColumnLabel;

  /// Communications table status column label.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get communicationsStatusColumnLabel;

  /// Conversation table last message column label.
  ///
  /// In en, this message translates to:
  /// **'Last message'**
  String get communicationsLastMessageColumnLabel;

  /// Communications table time column label.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get communicationsTimeColumnLabel;

  /// Notification table alert column label.
  ///
  /// In en, this message translates to:
  /// **'Alert'**
  String get communicationsAlertColumnLabel;

  /// Notification table type column label.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get communicationsTypeColumnLabel;

  /// Notification table priority column label.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get communicationsPriorityColumnLabel;

  /// Communications table state column label.
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get communicationsStateColumnLabel;

  /// Delivery table notification column label.
  ///
  /// In en, this message translates to:
  /// **'Notification'**
  String get communicationsNotificationColumnLabel;

  /// Communications table channel column label.
  ///
  /// In en, this message translates to:
  /// **'Channel'**
  String get communicationsChannelColumnLabel;

  /// Delivery table recipient column label.
  ///
  /// In en, this message translates to:
  /// **'Recipient'**
  String get communicationsRecipientColumnLabel;

  /// Delivery table attempts column label.
  ///
  /// In en, this message translates to:
  /// **'Attempts'**
  String get communicationsAttemptsColumnLabel;

  /// Template table template column label.
  ///
  /// In en, this message translates to:
  /// **'Template'**
  String get communicationsTemplateColumnLabel;

  /// Template table variables column label.
  ///
  /// In en, this message translates to:
  /// **'Variables'**
  String get communicationsVariablesColumnLabel;

  /// Empty title for conversations table.
  ///
  /// In en, this message translates to:
  /// **'No conversations'**
  String get communicationsNoConversationsTitle;

  /// Empty body for conversations table.
  ///
  /// In en, this message translates to:
  /// **'Matching conversation threads will appear here.'**
  String get communicationsNoConversationsBody;

  /// Empty title for notifications table.
  ///
  /// In en, this message translates to:
  /// **'No notifications'**
  String get communicationsNoNotificationsTitle;

  /// Empty body for notifications table.
  ///
  /// In en, this message translates to:
  /// **'Matching workflow alerts and reminders will appear here.'**
  String get communicationsNoNotificationsBody;

  /// Empty title for notification deliveries table.
  ///
  /// In en, this message translates to:
  /// **'No deliveries'**
  String get communicationsNoDeliveriesTitle;

  /// Empty body for notification deliveries table.
  ///
  /// In en, this message translates to:
  /// **'Notification channel delivery attempts will appear here.'**
  String get communicationsNoDeliveriesBody;

  /// Empty title for communication templates table.
  ///
  /// In en, this message translates to:
  /// **'No templates'**
  String get communicationsNoTemplatesTitle;

  /// Empty body for communication templates table.
  ///
  /// In en, this message translates to:
  /// **'Reusable communication templates will appear here.'**
  String get communicationsNoTemplatesBody;

  /// Title for conversation detail panel.
  ///
  /// In en, this message translates to:
  /// **'Conversation detail'**
  String get communicationsConversationDetailTitle;

  /// Title for notification detail panel.
  ///
  /// In en, this message translates to:
  /// **'Notification detail'**
  String get communicationsNotificationDetailTitle;

  /// Title for delivery detail panel.
  ///
  /// In en, this message translates to:
  /// **'Delivery detail'**
  String get communicationsDeliveryDetailTitle;

  /// Title for template detail panel.
  ///
  /// In en, this message translates to:
  /// **'Template detail'**
  String get communicationsTemplateDetailTitle;

  /// Empty title when no conversation is selected.
  ///
  /// In en, this message translates to:
  /// **'Select a conversation'**
  String get communicationsNoConversationSelectedTitle;

  /// Empty body when no conversation is selected.
  ///
  /// In en, this message translates to:
  /// **'Choose a thread to review messages, participants, and linked records.'**
  String get communicationsNoConversationSelectedBody;

  /// Empty title when no notification is selected.
  ///
  /// In en, this message translates to:
  /// **'Select a notification'**
  String get communicationsNoNotificationSelectedTitle;

  /// Empty body when no notification is selected.
  ///
  /// In en, this message translates to:
  /// **'Choose an alert to review delivery history and quick actions.'**
  String get communicationsNoNotificationSelectedBody;

  /// Empty title when no delivery is selected.
  ///
  /// In en, this message translates to:
  /// **'Select a delivery'**
  String get communicationsNoDeliverySelectedTitle;

  /// Empty body when no delivery is selected.
  ///
  /// In en, this message translates to:
  /// **'Choose a delivery attempt to review channel, recipient, and error details.'**
  String get communicationsNoDeliverySelectedBody;

  /// Empty title when no template is selected.
  ///
  /// In en, this message translates to:
  /// **'Select a template'**
  String get communicationsNoTemplateSelectedTitle;

  /// Empty body when no template is selected.
  ///
  /// In en, this message translates to:
  /// **'Choose a template to review channel, subject, variables, and preview.'**
  String get communicationsNoTemplateSelectedBody;

  /// Label for communication subject.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get communicationsSubjectLabel;

  /// Label for conversation participants.
  ///
  /// In en, this message translates to:
  /// **'Participants'**
  String get communicationsParticipantsLabel;

  /// Label for communication creation time.
  ///
  /// In en, this message translates to:
  /// **'Created at'**
  String get communicationsCreatedAtLabel;

  /// Label for communication update time.
  ///
  /// In en, this message translates to:
  /// **'Updated at'**
  String get communicationsUpdatedAtLabel;

  /// Label for notification read time.
  ///
  /// In en, this message translates to:
  /// **'Read at'**
  String get communicationsReadAtLabel;

  /// Label for communication type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get communicationsTypeLabel;

  /// Label for linked communication context.
  ///
  /// In en, this message translates to:
  /// **'Context'**
  String get communicationsContextLabel;

  /// Label for notification.
  ///
  /// In en, this message translates to:
  /// **'Notification'**
  String get communicationsNotificationLabel;

  /// Label for delivery channel.
  ///
  /// In en, this message translates to:
  /// **'Channel'**
  String get communicationsChannelLabel;

  /// Label for delivery recipient.
  ///
  /// In en, this message translates to:
  /// **'Recipient'**
  String get communicationsRecipientLabel;

  /// Label for delivery attempts.
  ///
  /// In en, this message translates to:
  /// **'Attempts'**
  String get communicationsAttemptsLabel;

  /// Label for delivery provider.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get communicationsProviderLabel;

  /// Label for sent time.
  ///
  /// In en, this message translates to:
  /// **'Sent at'**
  String get communicationsSentAtLabel;

  /// Label for delivered time.
  ///
  /// In en, this message translates to:
  /// **'Delivered at'**
  String get communicationsDeliveredAtLabel;

  /// Label for failed time.
  ///
  /// In en, this message translates to:
  /// **'Failed at'**
  String get communicationsFailedAtLabel;

  /// Label for status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get communicationsStatusLabel;

  /// Label for template variables.
  ///
  /// In en, this message translates to:
  /// **'Variables'**
  String get communicationsVariablesLabel;

  /// Title for template preview section.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get communicationsPreviewTitle;

  /// Title for conversation message thread.
  ///
  /// In en, this message translates to:
  /// **'Message thread'**
  String get communicationsMessageThreadTitle;

  /// Empty body for conversation messages.
  ///
  /// In en, this message translates to:
  /// **'No messages are available for this thread.'**
  String get communicationsNoMessagesBody;

  /// Title for notification delivery history.
  ///
  /// In en, this message translates to:
  /// **'Delivery history'**
  String get communicationsDeliveryHistoryTitle;

  /// Title for notification delivery error details.
  ///
  /// In en, this message translates to:
  /// **'Delivery error'**
  String get communicationsDeliveryErrorTitle;

  /// Action label for opening a linked workflow record.
  ///
  /// In en, this message translates to:
  /// **'Open linked record'**
  String get communicationsOpenLinkedRecordAction;

  /// Action label for marking a communication as read.
  ///
  /// In en, this message translates to:
  /// **'Mark read'**
  String get communicationsMarkReadAction;

  /// Action label for marking a notification as unread.
  ///
  /// In en, this message translates to:
  /// **'Mark unread'**
  String get communicationsMarkUnreadAction;

  /// Action label for archiving a communication.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get communicationsArchiveAction;

  /// Action label for unarchiving a communication.
  ///
  /// In en, this message translates to:
  /// **'Unarchive'**
  String get communicationsUnarchiveAction;

  /// Action label for sending a conversation message.
  ///
  /// In en, this message translates to:
  /// **'Send message'**
  String get communicationsSendMessageAction;

  /// Dialog title for sending a message.
  ///
  /// In en, this message translates to:
  /// **'Send message'**
  String get communicationsSendMessageDialogTitle;

  /// Field label for message body.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get communicationsMessageFieldLabel;

  /// Dialog title for marking a communication read.
  ///
  /// In en, this message translates to:
  /// **'Mark as read'**
  String get communicationsMarkReadDialogTitle;

  /// Dialog title for marking a notification unread.
  ///
  /// In en, this message translates to:
  /// **'Mark as unread'**
  String get communicationsMarkUnreadDialogTitle;

  /// Dialog title for archiving a communication.
  ///
  /// In en, this message translates to:
  /// **'Archive communication'**
  String get communicationsArchiveDialogTitle;

  /// Dialog title for unarchiving a conversation.
  ///
  /// In en, this message translates to:
  /// **'Unarchive conversation'**
  String get communicationsUnarchiveDialogTitle;

  /// Dialog body for marking a conversation read.
  ///
  /// In en, this message translates to:
  /// **'Mark this conversation read for your account.'**
  String get communicationsMarkConversationReadDialogBody;

  /// Dialog body for marking a notification read.
  ///
  /// In en, this message translates to:
  /// **'Mark this notification read for your account.'**
  String get communicationsMarkNotificationReadDialogBody;

  /// Dialog body for marking a notification unread.
  ///
  /// In en, this message translates to:
  /// **'Move this notification back to unread.'**
  String get communicationsMarkNotificationUnreadDialogBody;

  /// Dialog body for archiving a conversation.
  ///
  /// In en, this message translates to:
  /// **'Archive this conversation from your active inbox.'**
  String get communicationsArchiveConversationDialogBody;

  /// Dialog body for unarchiving a conversation.
  ///
  /// In en, this message translates to:
  /// **'Return this conversation to your active inbox.'**
  String get communicationsUnarchiveConversationDialogBody;

  /// Dialog body for archiving a notification.
  ///
  /// In en, this message translates to:
  /// **'Archive this notification from your active alerts.'**
  String get communicationsArchiveNotificationDialogBody;

  /// Status label for unread communications.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get communicationsUnreadStatus;

  /// Status label for read notifications.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get communicationsReadStatus;

  /// Status label for archived conversations.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get communicationsArchivedStatus;

  /// Status label for sensitive conversations.
  ///
  /// In en, this message translates to:
  /// **'Sensitive'**
  String get communicationsSensitiveStatus;

  /// Status label for active templates.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get communicationsActiveStatus;

  /// Status label for inactive templates.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get communicationsInactiveStatus;

  /// Localized text for housekeepingTitle.
  ///
  /// In en, this message translates to:
  /// **'Housekeeping'**
  String get housekeepingTitle;

  /// Localized text for housekeepingLoadingTitle.
  ///
  /// In en, this message translates to:
  /// **'Loading housekeeping'**
  String get housekeepingLoadingTitle;

  /// Localized text for housekeepingLoadingBody.
  ///
  /// In en, this message translates to:
  /// **'Preparing cleaning tasks, schedules, bed turnover, and readiness.'**
  String get housekeepingLoadingBody;

  /// Localized text for housekeepingLiveStatus.
  ///
  /// In en, this message translates to:
  /// **'Live sync'**
  String get housekeepingLiveStatus;

  /// Localized text for housekeepingSavingStatus.
  ///
  /// In en, this message translates to:
  /// **'Saving'**
  String get housekeepingSavingStatus;

  /// Localized text for housekeepingSavedMessage.
  ///
  /// In en, this message translates to:
  /// **'Housekeeping changes saved.'**
  String get housekeepingSavedMessage;

  /// Localized text for housekeepingCreateTaskAction.
  ///
  /// In en, this message translates to:
  /// **'Create task'**
  String get housekeepingCreateTaskAction;

  /// Localized text for housekeepingCreateScheduleAction.
  ///
  /// In en, this message translates to:
  /// **'Create schedule'**
  String get housekeepingCreateScheduleAction;

  /// Localized text for housekeepingRequestMaintenanceAction.
  ///
  /// In en, this message translates to:
  /// **'Request maintenance'**
  String get housekeepingRequestMaintenanceAction;

  /// Localized text for housekeepingReportSummaryAction.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get housekeepingReportSummaryAction;

  /// Localized text for housekeepingPendingTasksSummaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Pending tasks'**
  String get housekeepingPendingTasksSummaryLabel;

  /// Localized text for housekeepingCompletedTodaySummaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Completed today'**
  String get housekeepingCompletedTodaySummaryLabel;

  /// Localized text for housekeepingOpenRequestsSummaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Open requests'**
  String get housekeepingOpenRequestsSummaryLabel;

  /// Localized text for housekeepingOverdueRequestsSummaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Overdue requests'**
  String get housekeepingOverdueRequestsSummaryLabel;

  /// Localized text for housekeepingAssetsSummaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Assets'**
  String get housekeepingAssetsSummaryLabel;

  /// Localized text for housekeepingWorklistDescription.
  ///
  /// In en, this message translates to:
  /// **'Track cleaning tasks, schedules, bed turnover, and maintenance handoffs.'**
  String get housekeepingWorklistDescription;

  /// Localized text for housekeepingSearchLabel.
  ///
  /// In en, this message translates to:
  /// **'Search housekeeping'**
  String get housekeepingSearchLabel;

  /// Localized text for housekeepingSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search location, room, bed, assignee, status, priority, or date'**
  String get housekeepingSearchHint;

  /// Localized text for housekeepingClearSearchAction.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get housekeepingClearSearchAction;

  /// Localized text for housekeepingFiltersAction.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get housekeepingFiltersAction;

  /// Localized text for housekeepingFiltersTitle.
  ///
  /// In en, this message translates to:
  /// **'Housekeeping filters'**
  String get housekeepingFiltersTitle;

  /// Localized text for housekeepingApplyFiltersAction.
  ///
  /// In en, this message translates to:
  /// **'Apply filters'**
  String get housekeepingApplyFiltersAction;

  /// Localized text for housekeepingClearFiltersAction.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get housekeepingClearFiltersAction;

  /// Localized text for housekeepingPreviousPageLabel.
  ///
  /// In en, this message translates to:
  /// **'Previous page'**
  String get housekeepingPreviousPageLabel;

  /// Localized text for housekeepingNextPageLabel.
  ///
  /// In en, this message translates to:
  /// **'Next page'**
  String get housekeepingNextPageLabel;

  /// Pagination label for housekeeping items.
  ///
  /// In en, this message translates to:
  /// **'{first} - {last} of {total} items'**
  String housekeepingPageLabel(int first, int last, int total);

  /// Localized text for housekeepingEmptyQueueTitle.
  ///
  /// In en, this message translates to:
  /// **'No housekeeping items'**
  String get housekeepingEmptyQueueTitle;

  /// Localized text for housekeepingEmptyQueueBody.
  ///
  /// In en, this message translates to:
  /// **'No tasks, schedules, or maintenance handoffs match the current filters.'**
  String get housekeepingEmptyQueueBody;

  /// Localized text for housekeepingTaskColumnLabel.
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get housekeepingTaskColumnLabel;

  /// Localized text for housekeepingLocationColumnLabel.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get housekeepingLocationColumnLabel;

  /// Localized text for housekeepingAssigneeColumnLabel.
  ///
  /// In en, this message translates to:
  /// **'Assignee'**
  String get housekeepingAssigneeColumnLabel;

  /// Localized text for housekeepingDueColumnLabel.
  ///
  /// In en, this message translates to:
  /// **'Due time'**
  String get housekeepingDueColumnLabel;

  /// Localized text for housekeepingStatusColumnLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get housekeepingStatusColumnLabel;

  /// Localized text for housekeepingNextActionColumnLabel.
  ///
  /// In en, this message translates to:
  /// **'Next action'**
  String get housekeepingNextActionColumnLabel;

  /// Localized text for housekeepingNoSelectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Select a housekeeping item'**
  String get housekeepingNoSelectionTitle;

  /// Localized text for housekeepingNoSelectionBody.
  ///
  /// In en, this message translates to:
  /// **'Choose a task, schedule, or maintenance handoff to review readiness and available actions.'**
  String get housekeepingNoSelectionBody;

  /// Localized text for housekeepingDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Housekeeping detail'**
  String get housekeepingDetailTitle;

  /// Localized text for housekeepingReferenceLabel.
  ///
  /// In en, this message translates to:
  /// **'Reference'**
  String get housekeepingReferenceLabel;

  /// Localized text for housekeepingLocationLabel.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get housekeepingLocationLabel;

  /// Localized text for housekeepingAssigneeLabel.
  ///
  /// In en, this message translates to:
  /// **'Assignee'**
  String get housekeepingAssigneeLabel;

  /// Localized text for housekeepingDueLabel.
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get housekeepingDueLabel;

  /// Localized text for housekeepingReadinessTitle.
  ///
  /// In en, this message translates to:
  /// **'Readiness'**
  String get housekeepingReadinessTitle;

  /// Localized text for housekeepingAssignAction.
  ///
  /// In en, this message translates to:
  /// **'Assign'**
  String get housekeepingAssignAction;

  /// Localized text for housekeepingStartAction.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get housekeepingStartAction;

  /// Localized text for housekeepingStartDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Start cleaning'**
  String get housekeepingStartDialogTitle;

  /// Localized text for housekeepingStartDialogBody.
  ///
  /// In en, this message translates to:
  /// **'Mark this housekeeping task as in progress.'**
  String get housekeepingStartDialogBody;

  /// Localized text for housekeepingCompleteAction.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get housekeepingCompleteAction;

  /// Localized text for housekeepingCompleteDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Complete cleaning'**
  String get housekeepingCompleteDialogTitle;

  /// Localized text for housekeepingCompleteDialogBody.
  ///
  /// In en, this message translates to:
  /// **'Mark this cleaning task as completed and refresh readiness from the backend.'**
  String get housekeepingCompleteDialogBody;

  /// Localized text for housekeepingCancelAction.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get housekeepingCancelAction;

  /// Localized text for housekeepingCancelDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel task'**
  String get housekeepingCancelDialogTitle;

  /// Localized text for housekeepingCancelDialogBody.
  ///
  /// In en, this message translates to:
  /// **'Cancel this housekeeping task.'**
  String get housekeepingCancelDialogBody;

  /// Localized text for housekeepingMarkReadyAction.
  ///
  /// In en, this message translates to:
  /// **'Mark ready'**
  String get housekeepingMarkReadyAction;

  /// Localized text for housekeepingBackendGapTooltip.
  ///
  /// In en, this message translates to:
  /// **'Backend support is not available yet.'**
  String get housekeepingBackendGapTooltip;

  /// Localized text for housekeepingTriageAction.
  ///
  /// In en, this message translates to:
  /// **'Triage'**
  String get housekeepingTriageAction;

  /// Localized text for housekeepingCompleteRequestAction.
  ///
  /// In en, this message translates to:
  /// **'Complete request'**
  String get housekeepingCompleteRequestAction;

  /// Localized text for housekeepingCompleteRequestDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Complete maintenance request'**
  String get housekeepingCompleteRequestDialogTitle;

  /// Localized text for housekeepingCompleteRequestDialogBody.
  ///
  /// In en, this message translates to:
  /// **'Mark this maintenance handoff as completed.'**
  String get housekeepingCompleteRequestDialogBody;

  /// Localized text for housekeepingCancelRequestAction.
  ///
  /// In en, this message translates to:
  /// **'Cancel request'**
  String get housekeepingCancelRequestAction;

  /// Localized text for housekeepingCancelRequestDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel maintenance request'**
  String get housekeepingCancelRequestDialogTitle;

  /// Localized text for housekeepingCancelRequestDialogBody.
  ///
  /// In en, this message translates to:
  /// **'Cancel this maintenance handoff.'**
  String get housekeepingCancelRequestDialogBody;

  /// Localized text for housekeepingTaskReadinessBody.
  ///
  /// In en, this message translates to:
  /// **'Cleaning progress and readiness are refreshed from the housekeeping task record.'**
  String get housekeepingTaskReadinessBody;

  /// Localized text for housekeepingScheduleReadinessBody.
  ///
  /// In en, this message translates to:
  /// **'Scheduled cleaning keeps this location on a recurring readiness plan.'**
  String get housekeepingScheduleReadinessBody;

  /// Localized text for housekeepingMaintenanceReadinessBody.
  ///
  /// In en, this message translates to:
  /// **'Maintenance handoffs keep cleaning issues visible without losing location context.'**
  String get housekeepingMaintenanceReadinessBody;

  /// Localized text for housekeepingBackendGapsTitle.
  ///
  /// In en, this message translates to:
  /// **'Backend gaps'**
  String get housekeepingBackendGapsTitle;

  /// Localized text for housekeepingBackendGapsBody.
  ///
  /// In en, this message translates to:
  /// **'The workspace only exposes actions backed by confirmed API routes.'**
  String get housekeepingBackendGapsBody;

  /// Localized text for housekeepingFacilityFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Facility'**
  String get housekeepingFacilityFieldLabel;

  /// Localized text for housekeepingFacilityFieldHint.
  ///
  /// In en, this message translates to:
  /// **'Select a facility'**
  String get housekeepingFacilityFieldHint;

  /// Localized text for housekeepingRoomFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Room or bed'**
  String get housekeepingRoomFieldLabel;

  /// Localized text for housekeepingRoomFieldHint.
  ///
  /// In en, this message translates to:
  /// **'Select a room or bed'**
  String get housekeepingRoomFieldHint;

  /// Localized text for housekeepingAssigneeFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Assignee or team'**
  String get housekeepingAssigneeFieldLabel;

  /// Localized text for housekeepingAssigneeFieldHint.
  ///
  /// In en, this message translates to:
  /// **'Select staff or team'**
  String get housekeepingAssigneeFieldHint;

  /// Localized text for housekeepingStatusFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get housekeepingStatusFieldLabel;

  /// Localized text for housekeepingStatusRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'Select a status.'**
  String get housekeepingStatusRequiredMessage;

  /// Localized text for housekeepingScheduledDateFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Scheduled date'**
  String get housekeepingScheduledDateFieldLabel;

  /// Localized text for housekeepingCreateTaskSubmitAction.
  ///
  /// In en, this message translates to:
  /// **'Create task'**
  String get housekeepingCreateTaskSubmitAction;

  /// Localized text for housekeepingFrequencyFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get housekeepingFrequencyFieldLabel;

  /// Localized text for housekeepingFrequencyFieldHint.
  ///
  /// In en, this message translates to:
  /// **'Daily, weekly, terminal clean, or custom'**
  String get housekeepingFrequencyFieldHint;

  /// Localized text for housekeepingFrequencyRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter a cleaning frequency.'**
  String get housekeepingFrequencyRequiredMessage;

  /// Localized text for housekeepingStartDateFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get housekeepingStartDateFieldLabel;

  /// Localized text for housekeepingEndDateFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'End date'**
  String get housekeepingEndDateFieldLabel;

  /// Localized text for housekeepingCreateScheduleSubmitAction.
  ///
  /// In en, this message translates to:
  /// **'Create schedule'**
  String get housekeepingCreateScheduleSubmitAction;

  /// Localized text for housekeepingAssetFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Asset'**
  String get housekeepingAssetFieldLabel;

  /// Localized text for housekeepingAssetFieldHint.
  ///
  /// In en, this message translates to:
  /// **'Select asset or fixture'**
  String get housekeepingAssetFieldHint;

  /// Localized text for housekeepingDescriptionFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get housekeepingDescriptionFieldLabel;

  /// Localized text for housekeepingDescriptionFieldHint.
  ///
  /// In en, this message translates to:
  /// **'Describe the issue or cleaning concern'**
  String get housekeepingDescriptionFieldHint;

  /// Localized text for housekeepingDescriptionRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter a description.'**
  String get housekeepingDescriptionRequiredMessage;

  /// Localized text for housekeepingRequestMaintenanceSubmitAction.
  ///
  /// In en, this message translates to:
  /// **'Create request'**
  String get housekeepingRequestMaintenanceSubmitAction;

  /// Localized text for housekeepingAssignSubmitAction.
  ///
  /// In en, this message translates to:
  /// **'Save assignment'**
  String get housekeepingAssignSubmitAction;

  /// Localized text for housekeepingTriageSummaryFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Triage note'**
  String get housekeepingTriageSummaryFieldLabel;

  /// Localized text for housekeepingSlaHoursFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'SLA hours'**
  String get housekeepingSlaHoursFieldLabel;

  /// Localized text for housekeepingTriageSubmitAction.
  ///
  /// In en, this message translates to:
  /// **'Save triage'**
  String get housekeepingTriageSubmitAction;

  /// Localized text for housekeepingPickDateAction.
  ///
  /// In en, this message translates to:
  /// **'Pick date'**
  String get housekeepingPickDateAction;

  /// Localized text for housekeepingCreateTaskDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Create housekeeping task'**
  String get housekeepingCreateTaskDialogTitle;

  /// Localized text for housekeepingCreateScheduleDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Create cleaning schedule'**
  String get housekeepingCreateScheduleDialogTitle;

  /// Localized text for housekeepingRequestMaintenanceDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Request maintenance'**
  String get housekeepingRequestMaintenanceDialogTitle;

  /// Localized text for housekeepingAssignDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Assign housekeeping task'**
  String get housekeepingAssignDialogTitle;

  /// Localized text for housekeepingTriageDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Triage maintenance handoff'**
  String get housekeepingTriageDialogTitle;

  /// Localized text for housekeepingReportSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Housekeeping report'**
  String get housekeepingReportSummaryTitle;

  /// Localized text for housekeepingReportPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Report preview'**
  String get housekeepingReportPreviewTitle;

  /// Localized text for housekeepingReportPreviewBody.
  ///
  /// In en, this message translates to:
  /// **'Generated housekeeping report templates are pending backend report-run support.'**
  String get housekeepingReportPreviewBody;

  /// Localized text for housekeepingResourceFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Resource'**
  String get housekeepingResourceFilterLabel;

  /// Localized text for housekeepingResourceTasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get housekeepingResourceTasks;

  /// Localized text for housekeepingResourceSchedules.
  ///
  /// In en, this message translates to:
  /// **'Schedules'**
  String get housekeepingResourceSchedules;

  /// Localized text for housekeepingResourceMaintenanceRequests.
  ///
  /// In en, this message translates to:
  /// **'Maintenance requests'**
  String get housekeepingResourceMaintenanceRequests;

  /// Localized text for housekeepingQueueFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get housekeepingQueueFilterLabel;

  /// Localized text for housekeepingQueueAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get housekeepingQueueAll;

  /// Localized text for housekeepingQueueToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get housekeepingQueueToday;

  /// Localized text for housekeepingQueueOverdueTasks.
  ///
  /// In en, this message translates to:
  /// **'Overdue tasks'**
  String get housekeepingQueueOverdueTasks;

  /// Localized text for housekeepingQueueOpenRequests.
  ///
  /// In en, this message translates to:
  /// **'Open requests'**
  String get housekeepingQueueOpenRequests;

  /// Localized text for housekeepingQueueOverdueRequests.
  ///
  /// In en, this message translates to:
  /// **'Overdue requests'**
  String get housekeepingQueueOverdueRequests;

  /// Localized text for housekeepingStatusFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get housekeepingStatusFilterLabel;

  /// Localized text for housekeepingStatusAll.
  ///
  /// In en, this message translates to:
  /// **'All statuses'**
  String get housekeepingStatusAll;

  /// Localized text for housekeepingAllFacilities.
  ///
  /// In en, this message translates to:
  /// **'All facilities'**
  String get housekeepingAllFacilities;

  /// Localized text for housekeepingFacilityFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Facility'**
  String get housekeepingFacilityFilterLabel;

  /// Localized text for housekeepingRoomFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Room or bed'**
  String get housekeepingRoomFilterLabel;

  /// Localized text for housekeepingAllRooms.
  ///
  /// In en, this message translates to:
  /// **'All rooms and beds'**
  String get housekeepingAllRooms;

  /// Localized text for housekeepingAssigneeFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Assignee'**
  String get housekeepingAssigneeFilterLabel;

  /// Localized text for housekeepingAllAssignees.
  ///
  /// In en, this message translates to:
  /// **'All assignees'**
  String get housekeepingAllAssignees;

  /// Localized text for housekeepingDateFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get housekeepingDateFilterLabel;

  /// Localized text for housekeepingDateAll.
  ///
  /// In en, this message translates to:
  /// **'Any date'**
  String get housekeepingDateAll;

  /// Localized text for housekeepingDateToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get housekeepingDateToday;

  /// Localized text for housekeepingDateNextSevenDays.
  ///
  /// In en, this message translates to:
  /// **'Next 7 days'**
  String get housekeepingDateNextSevenDays;

  /// Localized text for housekeepingDateOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get housekeepingDateOverdue;

  /// Localized text for housekeepingDateThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get housekeepingDateThisMonth;

  /// Localized text for housekeepingStatusScheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get housekeepingStatusScheduled;

  /// Localized text for housekeepingStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get housekeepingStatusPending;

  /// Localized text for housekeepingStatusInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get housekeepingStatusInProgress;

  /// Localized text for housekeepingStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get housekeepingStatusCompleted;

  /// Localized text for housekeepingStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get housekeepingStatusCancelled;

  /// Localized text for housekeepingStatusUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get housekeepingStatusUnknown;

  /// Localized text for housekeepingStatusOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get housekeepingStatusOpen;

  /// Status option label for an open housekeeping task.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get housekeepingStatusOpenLabel;

  /// Status option label for an in-progress housekeeping task.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get housekeepingStatusInProgressLabel;

  /// Localized text for housekeepingNextActionAssign.
  ///
  /// In en, this message translates to:
  /// **'Assign staff or team'**
  String get housekeepingNextActionAssign;

  /// Localized text for housekeepingNextActionStart.
  ///
  /// In en, this message translates to:
  /// **'Start cleaning'**
  String get housekeepingNextActionStart;

  /// Localized text for housekeepingNextActionComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete cleaning'**
  String get housekeepingNextActionComplete;

  /// Localized text for housekeepingNextActionTriage.
  ///
  /// In en, this message translates to:
  /// **'Triage handoff'**
  String get housekeepingNextActionTriage;

  /// Localized text for housekeepingNextActionReviewSchedule.
  ///
  /// In en, this message translates to:
  /// **'Review schedule'**
  String get housekeepingNextActionReviewSchedule;

  /// Localized text for housekeepingNextActionNoAction.
  ///
  /// In en, this message translates to:
  /// **'No action needed'**
  String get housekeepingNextActionNoAction;

  /// Localized text for housekeepingNextActionView.
  ///
  /// In en, this message translates to:
  /// **'View details'**
  String get housekeepingNextActionView;

  /// Localized text for housekeepingLocationNotSet.
  ///
  /// In en, this message translates to:
  /// **'Location not set'**
  String get housekeepingLocationNotSet;

  /// Localized text for housekeepingNotRecorded.
  ///
  /// In en, this message translates to:
  /// **'Not recorded'**
  String get housekeepingNotRecorded;

  /// Localized text for housekeepingUnassigned.
  ///
  /// In en, this message translates to:
  /// **'Unassigned'**
  String get housekeepingUnassigned;

  /// Localized text for physiotherapyTitle.
  ///
  /// In en, this message translates to:
  /// **'Physiotherapy'**
  String get physiotherapyTitle;

  /// Localized text for physiotherapyLoadingTitle.
  ///
  /// In en, this message translates to:
  /// **'Loading physiotherapy workspace'**
  String get physiotherapyLoadingTitle;

  /// Localized text for physiotherapyLoadingBody.
  ///
  /// In en, this message translates to:
  /// **'Preparing referrals, sessions, care plans, notes, and follow-ups.'**
  String get physiotherapyLoadingBody;

  /// Localized text for physiotherapyLiveStatus.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get physiotherapyLiveStatus;

  /// Localized text for physiotherapySavingStatus.
  ///
  /// In en, this message translates to:
  /// **'Saving'**
  String get physiotherapySavingStatus;

  /// Localized text for physiotherapySavedMessage.
  ///
  /// In en, this message translates to:
  /// **'Physiotherapy record saved.'**
  String get physiotherapySavedMessage;

  /// Localized text for physiotherapyReferralsSummaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Referrals'**
  String get physiotherapyReferralsSummaryLabel;

  /// Localized text for physiotherapyTodaySummaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get physiotherapyTodaySummaryLabel;

  /// Localized text for physiotherapyMissedSummaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get physiotherapyMissedSummaryLabel;

  /// Localized text for physiotherapyActivePlansSummaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Active plans'**
  String get physiotherapyActivePlansSummaryLabel;

  /// Localized text for physiotherapyFollowUpDueSummaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Follow-up due'**
  String get physiotherapyFollowUpDueSummaryLabel;

  /// Localized text for physiotherapyCompletedSummaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get physiotherapyCompletedSummaryLabel;

  /// Localized text for physiotherapyWorklistTitle.
  ///
  /// In en, this message translates to:
  /// **'Therapy worklist'**
  String get physiotherapyWorklistTitle;

  /// Localized text for physiotherapyWorklistDescription.
  ///
  /// In en, this message translates to:
  /// **'Referrals, therapy sessions, plans, notes, and follow-up work from confirmed clinical endpoints.'**
  String get physiotherapyWorklistDescription;

  /// Localized text for physiotherapySearchLabel.
  ///
  /// In en, this message translates to:
  /// **'Search physiotherapy worklist'**
  String get physiotherapySearchLabel;

  /// Localized text for physiotherapySearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search patient, encounter, therapist, plan, or session'**
  String get physiotherapySearchHint;

  /// Localized text for physiotherapyFiltersLabel.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get physiotherapyFiltersLabel;

  /// Localized text for physiotherapyApplyFiltersAction.
  ///
  /// In en, this message translates to:
  /// **'Apply filters'**
  String get physiotherapyApplyFiltersAction;

  /// Localized text for physiotherapyClearFiltersAction.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get physiotherapyClearFiltersAction;

  /// Localized text for physiotherapySearchFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Search in'**
  String get physiotherapySearchFieldLabel;

  /// Localized text for physiotherapyAllFieldsLabel.
  ///
  /// In en, this message translates to:
  /// **'All fields'**
  String get physiotherapyAllFieldsLabel;

  /// Localized text for physiotherapyDateFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get physiotherapyDateFilterLabel;

  /// Localized text for physiotherapyDateFromLabel.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get physiotherapyDateFromLabel;

  /// Localized text for physiotherapyDateToLabel.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get physiotherapyDateToLabel;

  /// Localized text for physiotherapyTherapistFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Therapist'**
  String get physiotherapyTherapistFilterLabel;

  /// Localized text for physiotherapyTherapistFilterHint.
  ///
  /// In en, this message translates to:
  /// **'Therapist name or user ID'**
  String get physiotherapyTherapistFilterHint;

  /// Localized text for physiotherapyQueueFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get physiotherapyQueueFilterLabel;

  /// Localized text for physiotherapyFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get physiotherapyFilterAll;

  /// Localized text for physiotherapyScopeReferrals.
  ///
  /// In en, this message translates to:
  /// **'Referrals'**
  String get physiotherapyScopeReferrals;

  /// Localized text for physiotherapyScopeToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get physiotherapyScopeToday;

  /// Localized text for physiotherapyScopeMissed.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get physiotherapyScopeMissed;

  /// Localized text for physiotherapyScopeActivePlans.
  ///
  /// In en, this message translates to:
  /// **'Active plans'**
  String get physiotherapyScopeActivePlans;

  /// Localized text for physiotherapyScopeFollowUpDue.
  ///
  /// In en, this message translates to:
  /// **'Follow-up due'**
  String get physiotherapyScopeFollowUpDue;

  /// Localized text for physiotherapyScopeCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get physiotherapyScopeCompleted;

  /// Localized text for physiotherapyScopeAll.
  ///
  /// In en, this message translates to:
  /// **'All work'**
  String get physiotherapyScopeAll;

  /// Localized text for physiotherapyPatientColumnLabel.
  ///
  /// In en, this message translates to:
  /// **'Patient'**
  String get physiotherapyPatientColumnLabel;

  /// Localized text for physiotherapySourceColumnLabel.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get physiotherapySourceColumnLabel;

  /// Localized text for physiotherapySessionColumnLabel.
  ///
  /// In en, this message translates to:
  /// **'Session'**
  String get physiotherapySessionColumnLabel;

  /// Localized text for physiotherapyStatusColumnLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get physiotherapyStatusColumnLabel;

  /// Localized text for physiotherapyPlanColumnLabel.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get physiotherapyPlanColumnLabel;

  /// Localized text for physiotherapyAttendanceColumnLabel.
  ///
  /// In en, this message translates to:
  /// **'Attendance'**
  String get physiotherapyAttendanceColumnLabel;

  /// Localized text for physiotherapyBillingColumnLabel.
  ///
  /// In en, this message translates to:
  /// **'Billing'**
  String get physiotherapyBillingColumnLabel;

  /// Localized text for physiotherapyTherapistColumnLabel.
  ///
  /// In en, this message translates to:
  /// **'Therapist'**
  String get physiotherapyTherapistColumnLabel;

  /// Localized text for physiotherapyNextActionColumnLabel.
  ///
  /// In en, this message translates to:
  /// **'Next action'**
  String get physiotherapyNextActionColumnLabel;

  /// Localized text for physiotherapyTableColumnsTitle.
  ///
  /// In en, this message translates to:
  /// **'Therapy table columns'**
  String get physiotherapyTableColumnsTitle;

  /// Localized text for physiotherapyApplyColumnsAction.
  ///
  /// In en, this message translates to:
  /// **'Apply columns'**
  String get physiotherapyApplyColumnsAction;

  /// Localized text for physiotherapyResetColumnsAction.
  ///
  /// In en, this message translates to:
  /// **'Reset columns'**
  String get physiotherapyResetColumnsAction;

  /// Localized text for physiotherapyNoWorkTitle.
  ///
  /// In en, this message translates to:
  /// **'No physiotherapy work'**
  String get physiotherapyNoWorkTitle;

  /// Localized text for physiotherapyNoWorkBody.
  ///
  /// In en, this message translates to:
  /// **'No referrals, sessions, plans, or follow-ups match the current filters.'**
  String get physiotherapyNoWorkBody;

  /// Localized text for physiotherapyDetailLoadingTitle.
  ///
  /// In en, this message translates to:
  /// **'Loading therapy record'**
  String get physiotherapyDetailLoadingTitle;

  /// Localized text for physiotherapyDetailLoadingBody.
  ///
  /// In en, this message translates to:
  /// **'Fetching session history, plan, notes, and follow-up details.'**
  String get physiotherapyDetailLoadingBody;

  /// Localized text for physiotherapyNoSelectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Select a therapy item'**
  String get physiotherapyNoSelectionTitle;

  /// Localized text for physiotherapyNoSelectionBody.
  ///
  /// In en, this message translates to:
  /// **'Choose a referral or session to review assessment, plan, attendance, and follow-up actions.'**
  String get physiotherapyNoSelectionBody;

  /// Localized text for physiotherapyPatientNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Patient number'**
  String get physiotherapyPatientNumberLabel;

  /// Localized text for physiotherapyEncounterLabel.
  ///
  /// In en, this message translates to:
  /// **'Encounter'**
  String get physiotherapyEncounterLabel;

  /// Localized text for physiotherapySessionLabel.
  ///
  /// In en, this message translates to:
  /// **'Session'**
  String get physiotherapySessionLabel;

  /// Localized text for physiotherapyTherapistLabel.
  ///
  /// In en, this message translates to:
  /// **'Therapist'**
  String get physiotherapyTherapistLabel;

  /// Localized text for physiotherapyBillingAuthorizationLabel.
  ///
  /// In en, this message translates to:
  /// **'Billing authorization'**
  String get physiotherapyBillingAuthorizationLabel;

  /// Localized text for physiotherapyActionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Therapy actions'**
  String get physiotherapyActionsTitle;

  /// Localized text for physiotherapyReferralPanelTitle.
  ///
  /// In en, this message translates to:
  /// **'Referral and plan'**
  String get physiotherapyReferralPanelTitle;

  /// Localized text for physiotherapySourceLabel.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get physiotherapySourceLabel;

  /// Localized text for physiotherapyStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get physiotherapyStatusLabel;

  /// Localized text for physiotherapyAttendanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Attendance'**
  String get physiotherapyAttendanceLabel;

  /// Localized text for physiotherapyPlanLabel.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get physiotherapyPlanLabel;

  /// Localized text for physiotherapyGoalLabel.
  ///
  /// In en, this message translates to:
  /// **'Goal'**
  String get physiotherapyGoalLabel;

  /// Localized text for physiotherapyInstructionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Instructions'**
  String get physiotherapyInstructionsLabel;

  /// Localized text for physiotherapySessionsPanelTitle.
  ///
  /// In en, this message translates to:
  /// **'Session history'**
  String get physiotherapySessionsPanelTitle;

  /// Localized text for physiotherapyPlanPanelTitle.
  ///
  /// In en, this message translates to:
  /// **'Care plan'**
  String get physiotherapyPlanPanelTitle;

  /// Localized text for physiotherapyProgressNotesPanelTitle.
  ///
  /// In en, this message translates to:
  /// **'Progress notes'**
  String get physiotherapyProgressNotesPanelTitle;

  /// Localized text for physiotherapyFollowUpPanelTitle.
  ///
  /// In en, this message translates to:
  /// **'Follow-ups'**
  String get physiotherapyFollowUpPanelTitle;

  /// Localized text for physiotherapyBackendGapsPanelTitle.
  ///
  /// In en, this message translates to:
  /// **'Backend gaps'**
  String get physiotherapyBackendGapsPanelTitle;

  /// Localized text for physiotherapyBackendGapBody.
  ///
  /// In en, this message translates to:
  /// **'This workspace uses confirmed shared clinical endpoints and records unavailable dedicated physiotherapy contracts here.'**
  String get physiotherapyBackendGapBody;

  /// Localized text for physiotherapyNoRecordsLabel.
  ///
  /// In en, this message translates to:
  /// **'No records yet.'**
  String get physiotherapyNoRecordsLabel;

  /// Localized text for physiotherapyNoInstructionsLabel.
  ///
  /// In en, this message translates to:
  /// **'No therapy instructions recorded.'**
  String get physiotherapyNoInstructionsLabel;

  /// Localized text for physiotherapyAcceptReferralAction.
  ///
  /// In en, this message translates to:
  /// **'Accept referral'**
  String get physiotherapyAcceptReferralAction;

  /// Localized text for physiotherapyScheduleSessionAction.
  ///
  /// In en, this message translates to:
  /// **'Schedule session'**
  String get physiotherapyScheduleSessionAction;

  /// Localized text for physiotherapyRecordAssessmentAction.
  ///
  /// In en, this message translates to:
  /// **'Record assessment'**
  String get physiotherapyRecordAssessmentAction;

  /// Localized text for physiotherapyRecordSessionAction.
  ///
  /// In en, this message translates to:
  /// **'Record session'**
  String get physiotherapyRecordSessionAction;

  /// Localized text for physiotherapyMarkAttendanceAction.
  ///
  /// In en, this message translates to:
  /// **'Mark attendance'**
  String get physiotherapyMarkAttendanceAction;

  /// Localized text for physiotherapyUpdatePlanAction.
  ///
  /// In en, this message translates to:
  /// **'Update plan'**
  String get physiotherapyUpdatePlanAction;

  /// Localized text for physiotherapyAddProgressNoteAction.
  ///
  /// In en, this message translates to:
  /// **'Add progress note'**
  String get physiotherapyAddProgressNoteAction;

  /// Localized text for physiotherapyScheduleFollowUpAction.
  ///
  /// In en, this message translates to:
  /// **'Schedule follow-up'**
  String get physiotherapyScheduleFollowUpAction;

  /// Localized text for physiotherapyCloseEpisodeAction.
  ///
  /// In en, this message translates to:
  /// **'Close episode'**
  String get physiotherapyCloseEpisodeAction;

  /// Localized text for physiotherapyPrintInstructionsAction.
  ///
  /// In en, this message translates to:
  /// **'Print instructions'**
  String get physiotherapyPrintInstructionsAction;

  /// Localized text for physiotherapyAcceptReferralDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Accept physiotherapy referral'**
  String get physiotherapyAcceptReferralDialogTitle;

  /// Localized text for physiotherapyScheduleSessionDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Schedule therapy session'**
  String get physiotherapyScheduleSessionDialogTitle;

  /// Localized text for physiotherapyRecordAssessmentDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Record therapy assessment'**
  String get physiotherapyRecordAssessmentDialogTitle;

  /// Localized text for physiotherapyRecordSessionDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Record therapy session'**
  String get physiotherapyRecordSessionDialogTitle;

  /// Localized text for physiotherapyMarkAttendanceDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Mark session attendance'**
  String get physiotherapyMarkAttendanceDialogTitle;

  /// Localized text for physiotherapyUpdatePlanDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Update therapy plan'**
  String get physiotherapyUpdatePlanDialogTitle;

  /// Localized text for physiotherapyAddProgressNoteDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Add progress note'**
  String get physiotherapyAddProgressNoteDialogTitle;

  /// Localized text for physiotherapyScheduleFollowUpDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Schedule follow-up'**
  String get physiotherapyScheduleFollowUpDialogTitle;

  /// Localized text for physiotherapyCloseEpisodeDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Close therapy episode'**
  String get physiotherapyCloseEpisodeDialogTitle;

  /// Localized text for physiotherapyNoteFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get physiotherapyNoteFieldLabel;

  /// Localized text for physiotherapyReasonFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get physiotherapyReasonFieldLabel;

  /// Localized text for physiotherapyAssessmentFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Assessment'**
  String get physiotherapyAssessmentFieldLabel;

  /// Localized text for physiotherapyGoalsFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Goals'**
  String get physiotherapyGoalsFieldLabel;

  /// Localized text for physiotherapyPlanFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get physiotherapyPlanFieldLabel;

  /// Localized text for physiotherapyInstructionsFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Instructions'**
  String get physiotherapyInstructionsFieldLabel;

  /// Localized text for physiotherapySessionNoteFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Session note'**
  String get physiotherapySessionNoteFieldLabel;

  /// Localized text for physiotherapyAttendanceStatusFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Attendance status'**
  String get physiotherapyAttendanceStatusFieldLabel;

  /// Localized text for physiotherapySummaryFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get physiotherapySummaryFieldLabel;

  /// Localized text for physiotherapyStartDateFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get physiotherapyStartDateFieldLabel;

  /// Localized text for physiotherapyStartTimeFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Start time'**
  String get physiotherapyStartTimeFieldLabel;

  /// Localized text for physiotherapyEndDateFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'End date'**
  String get physiotherapyEndDateFieldLabel;

  /// Localized text for physiotherapyEndTimeFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'End time'**
  String get physiotherapyEndTimeFieldLabel;

  /// Localized text for physiotherapyDateFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get physiotherapyDateFieldLabel;

  /// Localized text for physiotherapyTimeFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get physiotherapyTimeFieldLabel;

  /// Localized text for physiotherapySaveAction.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get physiotherapySaveAction;

  /// Localized text for physiotherapyStatusReferral.
  ///
  /// In en, this message translates to:
  /// **'Referral'**
  String get physiotherapyStatusReferral;

  /// Localized text for physiotherapyStatusAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get physiotherapyStatusAccepted;

  /// Localized text for physiotherapyStatusAssessment.
  ///
  /// In en, this message translates to:
  /// **'Assessment'**
  String get physiotherapyStatusAssessment;

  /// Localized text for physiotherapyStatusToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get physiotherapyStatusToday;

  /// Localized text for physiotherapyStatusInTreatment.
  ///
  /// In en, this message translates to:
  /// **'In treatment'**
  String get physiotherapyStatusInTreatment;

  /// Localized text for physiotherapyStatusActivePlan.
  ///
  /// In en, this message translates to:
  /// **'Active plan'**
  String get physiotherapyStatusActivePlan;

  /// Localized text for physiotherapyStatusFollowUpDue.
  ///
  /// In en, this message translates to:
  /// **'Follow-up due'**
  String get physiotherapyStatusFollowUpDue;

  /// Localized text for physiotherapyStatusMissed.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get physiotherapyStatusMissed;

  /// Localized text for physiotherapyStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get physiotherapyStatusCompleted;

  /// Localized text for physiotherapyUnknownStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get physiotherapyUnknownStatusLabel;

  /// Localized text for physiotherapySourceReferral.
  ///
  /// In en, this message translates to:
  /// **'Referral'**
  String get physiotherapySourceReferral;

  /// Localized text for physiotherapySourceAppointment.
  ///
  /// In en, this message translates to:
  /// **'Appointment'**
  String get physiotherapySourceAppointment;

  /// Localized text for physiotherapySourceCarePlan.
  ///
  /// In en, this message translates to:
  /// **'Care plan'**
  String get physiotherapySourceCarePlan;

  /// Localized text for physiotherapySourceProcedure.
  ///
  /// In en, this message translates to:
  /// **'Procedure'**
  String get physiotherapySourceProcedure;

  /// Localized text for physiotherapySourceUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown source'**
  String get physiotherapySourceUnknown;

  /// Localized text for physiotherapyAttendanceScheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get physiotherapyAttendanceScheduled;

  /// Localized text for physiotherapyAttendanceConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get physiotherapyAttendanceConfirmed;

  /// Localized text for physiotherapyAttendanceInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get physiotherapyAttendanceInProgress;

  /// Localized text for physiotherapyAttendanceCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get physiotherapyAttendanceCompleted;

  /// Localized text for physiotherapyAttendanceCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get physiotherapyAttendanceCancelled;

  /// Localized text for physiotherapyAttendanceNoShow.
  ///
  /// In en, this message translates to:
  /// **'No-show'**
  String get physiotherapyAttendanceNoShow;

  /// Localized text for physiotherapyBillingBackendGap.
  ///
  /// In en, this message translates to:
  /// **'No confirmed billing gate'**
  String get physiotherapyBillingBackendGap;

  /// Localized text for physiotherapyMissingValueLabel.
  ///
  /// In en, this message translates to:
  /// **'Not recorded'**
  String get physiotherapyMissingValueLabel;

  /// Localized text for physiotherapyBackendGapStatusEndpoint.
  ///
  /// In en, this message translates to:
  /// **'Dedicated physiotherapy episode and therapy status endpoints are not available; status is derived from procedures, care plans, appointments, and follow-ups.'**
  String get physiotherapyBackendGapStatusEndpoint;

  /// Localized text for physiotherapyBackendGapBillingEndpoint.
  ///
  /// In en, this message translates to:
  /// **'A physiotherapy-specific billing authorization gate is not available; billing is shown as a documented backend gap.'**
  String get physiotherapyBackendGapBillingEndpoint;

  /// Localized text for physiotherapyBackendGapReportEndpoint.
  ///
  /// In en, this message translates to:
  /// **'Generated physiotherapy assessment and discharge report endpoints are not available; printing uses the shared report template.'**
  String get physiotherapyBackendGapReportEndpoint;

  /// Localized text for physiotherapyBackendGapUnknown.
  ///
  /// In en, this message translates to:
  /// **'An unavailable physiotherapy backend contract was recorded.'**
  String get physiotherapyBackendGapUnknown;

  /// Localized text for physiotherapyInstructionsReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Physiotherapy instructions'**
  String get physiotherapyInstructionsReportTitle;

  /// Localized text for physiotherapyReportPatientLabel.
  ///
  /// In en, this message translates to:
  /// **'Patient'**
  String get physiotherapyReportPatientLabel;

  /// Localized text for physiotherapyReportEncounterLabel.
  ///
  /// In en, this message translates to:
  /// **'Encounter'**
  String get physiotherapyReportEncounterLabel;

  /// Localized text for physiotherapyReportPlanLabel.
  ///
  /// In en, this message translates to:
  /// **'Plan and goals'**
  String get physiotherapyReportPlanLabel;

  /// Localized text for physiotherapyReportInstructionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Instructions'**
  String get physiotherapyReportInstructionsLabel;

  /// Localized text for physiotherapyReportSessionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get physiotherapyReportSessionsLabel;

  /// Localized text for physiotherapyReportFooterNote.
  ///
  /// In en, this message translates to:
  /// **'Generated from confirmed shared clinical workflow data.'**
  String get physiotherapyReportFooterNote;

  /// Title for the mortuary workspace.
  ///
  /// In en, this message translates to:
  /// **'Mortuary'**
  String get mortuaryTitle;

  /// Title shown when the mortuary workspace cannot load.
  ///
  /// In en, this message translates to:
  /// **'Mortuary workspace unavailable'**
  String get mortuaryLoadErrorTitle;

  /// Body shown when the mortuary workspace cannot load.
  ///
  /// In en, this message translates to:
  /// **'The mortuary workspace could not be loaded. Try again or contact an administrator if the issue continues.'**
  String get mortuaryLoadErrorBody;

  /// Title shown while loading the mortuary workspace.
  ///
  /// In en, this message translates to:
  /// **'Loading mortuary workspace'**
  String get mortuaryLoadingTitle;

  /// Body shown while loading the mortuary workspace.
  ///
  /// In en, this message translates to:
  /// **'Retrieving cases, storage, custody, release, and billing information.'**
  String get mortuaryLoadingBody;

  /// Operational status label for the mortuary workspace.
  ///
  /// In en, this message translates to:
  /// **'Operational'**
  String get mortuaryOperationalStatusLabel;

  /// Attention status label for the mortuary workspace.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get mortuaryAttentionStatusLabel;

  /// Action label for printing mortuary documents.
  ///
  /// In en, this message translates to:
  /// **'Print documents'**
  String get mortuaryPrintDocumentsAction;

  /// Action label for receiving a mortuary case.
  ///
  /// In en, this message translates to:
  /// **'Receive case'**
  String get mortuaryReceiveCaseAction;

  /// Action label for assigning mortuary storage.
  ///
  /// In en, this message translates to:
  /// **'Assign storage'**
  String get mortuaryAssignStorageAction;

  /// Action label for recording a custody event.
  ///
  /// In en, this message translates to:
  /// **'Record custody'**
  String get mortuaryRecordCustodyAction;

  /// Action label for scheduling a viewing.
  ///
  /// In en, this message translates to:
  /// **'Schedule viewing'**
  String get mortuaryScheduleViewingAction;

  /// Action label for post-mortem workflow steps.
  ///
  /// In en, this message translates to:
  /// **'Post-mortem step'**
  String get mortuaryPostMortemAction;

  /// Action label for requesting mortuary billing.
  ///
  /// In en, this message translates to:
  /// **'Request billing'**
  String get mortuaryRequestBillingAction;

  /// Action label for approving release.
  ///
  /// In en, this message translates to:
  /// **'Approve release'**
  String get mortuaryApproveReleaseAction;

  /// Action label for confirming release.
  ///
  /// In en, this message translates to:
  /// **'Confirm release'**
  String get mortuaryConfirmReleaseAction;

  /// Tooltip for mortuary actions that are not supported by the current backend.
  ///
  /// In en, this message translates to:
  /// **'This action is waiting for a backend action endpoint.'**
  String get mortuaryActionsUnavailableTooltip;

  /// Title for the mortuary worklist.
  ///
  /// In en, this message translates to:
  /// **'Mortuary worklist'**
  String get mortuaryWorklistTitle;

  /// Empty state title for the mortuary worklist.
  ///
  /// In en, this message translates to:
  /// **'No mortuary records found'**
  String get mortuaryWorklistEmptyTitle;

  /// Empty state body for the mortuary worklist.
  ///
  /// In en, this message translates to:
  /// **'Adjust the filters or search terms to view matching mortuary records.'**
  String get mortuaryWorklistEmptyBody;

  /// Column label for mortuary case reference.
  ///
  /// In en, this message translates to:
  /// **'Case'**
  String get mortuaryReferenceColumnLabel;

  /// Column label for deceased person context.
  ///
  /// In en, this message translates to:
  /// **'Deceased'**
  String get mortuaryDeceasedColumnLabel;

  /// Column label for source context.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get mortuarySourceColumnLabel;

  /// Column label for storage context.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get mortuaryStorageColumnLabel;

  /// Column label for mortuary status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get mortuaryStatusColumnLabel;

  /// Column label for mortuary dates.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get mortuaryDateColumnLabel;

  /// Column label for the next mortuary action.
  ///
  /// In en, this message translates to:
  /// **'Next action'**
  String get mortuaryNextActionColumnLabel;

  /// Label for previous page action in mortuary tables.
  ///
  /// In en, this message translates to:
  /// **'Previous page'**
  String get mortuaryPreviousPageLabel;

  /// Label for next page action in mortuary tables.
  ///
  /// In en, this message translates to:
  /// **'Next page'**
  String get mortuaryNextPageLabel;

  /// Pagination label for the mortuary worklist.
  ///
  /// In en, this message translates to:
  /// **'Showing {from}-{to} of {total}'**
  String mortuaryPageLabel(int from, int to, int total);

  /// Semantic label for mortuary search.
  ///
  /// In en, this message translates to:
  /// **'Search mortuary records'**
  String get mortuarySearchLabel;

  /// Hint text for mortuary search.
  ///
  /// In en, this message translates to:
  /// **'Search case, name, source, storage, or status'**
  String get mortuarySearchHint;

  /// Search field label for mortuary filters.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get mortuarySearchFieldLabel;

  /// Label for mortuary filters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get mortuaryFiltersLabel;

  /// Action label for applying mortuary filters.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get mortuaryApplyFiltersAction;

  /// Action label for resetting mortuary filters.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get mortuaryResetFiltersAction;

  /// All option label for mortuary filters.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get mortuaryAllFieldsLabel;

  /// Date filter label for mortuary search.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get mortuaryDateFilterLabel;

  /// Start date label for mortuary filters.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get mortuaryDateFromLabel;

  /// End date label for mortuary filters.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get mortuaryDateToLabel;

  /// Date picker button label for mortuary filters.
  ///
  /// In en, this message translates to:
  /// **'Choose date'**
  String get mortuaryDatePickerButtonLabel;

  /// Validation message for invalid mortuary filter dates.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid date.'**
  String get mortuaryInvalidDateMessage;

  /// Filter label for mortuary panels.
  ///
  /// In en, this message translates to:
  /// **'Panel'**
  String get mortuaryPanelFilterLabel;

  /// Filter label for mortuary resources.
  ///
  /// In en, this message translates to:
  /// **'Resource'**
  String get mortuaryResourceFilterLabel;

  /// Filter label for mortuary queues.
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get mortuaryQueueFilterLabel;

  /// Filter label for mortuary status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get mortuaryStatusFilterLabel;

  /// Filter label for mortuary identification status.
  ///
  /// In en, this message translates to:
  /// **'Identification'**
  String get mortuaryIdentificationFilterLabel;

  /// Filter label for mortuary facility.
  ///
  /// In en, this message translates to:
  /// **'Facility'**
  String get mortuaryFacilityFilterLabel;

  /// Filter label for mortuary storage units.
  ///
  /// In en, this message translates to:
  /// **'Storage unit'**
  String get mortuaryStorageUnitFilterLabel;

  /// Filter label for mortuary storage slots.
  ///
  /// In en, this message translates to:
  /// **'Storage slot'**
  String get mortuaryStorageSlotFilterLabel;

  /// Filter label for mortuary date presets.
  ///
  /// In en, this message translates to:
  /// **'Date preset'**
  String get mortuaryDatePresetFilterLabel;

  /// Mortuary date preset label for today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get mortuaryDatePresetTodayLabel;

  /// Mortuary date preset label for the next 7 days.
  ///
  /// In en, this message translates to:
  /// **'Next 7 days'**
  String get mortuaryDatePresetNext7DaysLabel;

  /// Mortuary date preset label for overdue items.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get mortuaryDatePresetOverdueLabel;

  /// Mortuary date preset label for this month.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get mortuaryDatePresetThisMonthLabel;

  /// Summary label for total mortuary cases.
  ///
  /// In en, this message translates to:
  /// **'Total cases'**
  String get mortuaryTotalCasesSummaryLabel;

  /// Summary label for cases pending identification.
  ///
  /// In en, this message translates to:
  /// **'Identification pending'**
  String get mortuaryIdentificationPendingSummaryLabel;

  /// Summary label for cases in storage.
  ///
  /// In en, this message translates to:
  /// **'In storage'**
  String get mortuaryInStorageSummaryLabel;

  /// Summary label for release-ready mortuary cases.
  ///
  /// In en, this message translates to:
  /// **'Release ready'**
  String get mortuaryReleaseReadySummaryLabel;

  /// Summary label for unsettled mortuary billing.
  ///
  /// In en, this message translates to:
  /// **'Unsettled billing'**
  String get mortuaryUnsettledBillingSummaryLabel;

  /// Mortuary overview panel label.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get mortuaryPanelOverviewLabel;

  /// Mortuary intake panel label.
  ///
  /// In en, this message translates to:
  /// **'Intake'**
  String get mortuaryPanelIntakeLabel;

  /// Mortuary storage panel label.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get mortuaryPanelStorageLabel;

  /// Mortuary custody panel label.
  ///
  /// In en, this message translates to:
  /// **'Custody'**
  String get mortuaryPanelCustodyLabel;

  /// Mortuary release panel label.
  ///
  /// In en, this message translates to:
  /// **'Release'**
  String get mortuaryPanelReleaseLabel;

  /// Mortuary reports panel label.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get mortuaryPanelReportingLabel;

  /// Mortuary cases resource label.
  ///
  /// In en, this message translates to:
  /// **'Cases'**
  String get mortuaryResourceCasesLabel;

  /// Mortuary storage units resource label.
  ///
  /// In en, this message translates to:
  /// **'Storage units'**
  String get mortuaryResourceStorageUnitsLabel;

  /// Mortuary storage slots resource label.
  ///
  /// In en, this message translates to:
  /// **'Storage slots'**
  String get mortuaryResourceStorageSlotsLabel;

  /// Mortuary storage assignments resource label.
  ///
  /// In en, this message translates to:
  /// **'Storage assignments'**
  String get mortuaryResourceStorageAssignmentsLabel;

  /// Mortuary custody events resource label.
  ///
  /// In en, this message translates to:
  /// **'Custody events'**
  String get mortuaryResourceCustodyEventsLabel;

  /// Mortuary viewings resource label.
  ///
  /// In en, this message translates to:
  /// **'Viewings'**
  String get mortuaryResourceViewingsLabel;

  /// Mortuary post-mortem requests resource label.
  ///
  /// In en, this message translates to:
  /// **'Post-mortem requests'**
  String get mortuaryResourcePostMortemRequestsLabel;

  /// Mortuary release authorisations resource label.
  ///
  /// In en, this message translates to:
  /// **'Release authorisations'**
  String get mortuaryResourceReleaseAuthorisationsLabel;

  /// Mortuary billable events resource label.
  ///
  /// In en, this message translates to:
  /// **'Billable events'**
  String get mortuaryResourceBillableEventsLabel;

  /// Mortuary identification pending queue label.
  ///
  /// In en, this message translates to:
  /// **'Identification pending'**
  String get mortuaryQueueIdentificationPendingLabel;

  /// Mortuary storage exceptions queue label.
  ///
  /// In en, this message translates to:
  /// **'Storage exceptions'**
  String get mortuaryQueueStorageExceptionsLabel;

  /// Mortuary release ready queue label.
  ///
  /// In en, this message translates to:
  /// **'Release ready'**
  String get mortuaryQueueReleaseReadyLabel;

  /// Mortuary unsettled billing queue label.
  ///
  /// In en, this message translates to:
  /// **'Unsettled billing'**
  String get mortuaryQueueUnsettledBillingLabel;

  /// Mortuary post-mortem pending queue label.
  ///
  /// In en, this message translates to:
  /// **'Post-mortem pending'**
  String get mortuaryQueuePostMortemPendingLabel;

  /// Title for the mortuary case detail panel.
  ///
  /// In en, this message translates to:
  /// **'Case detail'**
  String get mortuaryDetailTitle;

  /// Empty state title when no mortuary case is selected.
  ///
  /// In en, this message translates to:
  /// **'Select a case'**
  String get mortuaryNoSelectionTitle;

  /// Empty state body when no mortuary case is selected.
  ///
  /// In en, this message translates to:
  /// **'Choose a record from the worklist to review identity, storage, custody, release, billing, and documents.'**
  String get mortuaryNoSelectionBody;

  /// Fallback label when deceased name is unavailable.
  ///
  /// In en, this message translates to:
  /// **'Name not recorded'**
  String get mortuaryUnknownDeceasedLabel;

  /// Fallback label when mortuary field data is unavailable.
  ///
  /// In en, this message translates to:
  /// **'Not recorded'**
  String get mortuaryUnknownValueLabel;

  /// Label for mortuary case number.
  ///
  /// In en, this message translates to:
  /// **'Case number'**
  String get mortuaryCaseNumberLabel;

  /// Semantic label for deceased person context.
  ///
  /// In en, this message translates to:
  /// **'Deceased person context'**
  String get mortuaryDeceasedContextLabel;

  /// Field label for identification status.
  ///
  /// In en, this message translates to:
  /// **'Identification'**
  String get mortuaryIdentificationFieldLabel;

  /// Field label for billing status.
  ///
  /// In en, this message translates to:
  /// **'Billing'**
  String get mortuaryBillingFieldLabel;

  /// Field label for storage slot.
  ///
  /// In en, this message translates to:
  /// **'Storage slot'**
  String get mortuaryStorageSlotFieldLabel;

  /// Field label for facility.
  ///
  /// In en, this message translates to:
  /// **'Facility'**
  String get mortuaryFacilityFieldLabel;

  /// Title for unsupported mortuary action notice.
  ///
  /// In en, this message translates to:
  /// **'Backend actions pending'**
  String get mortuaryActionGapTitle;

  /// Body for unsupported mortuary action notice.
  ///
  /// In en, this message translates to:
  /// **'The current backend exposes mortuary workspace and lookup data only. Action buttons are shown for permissions and audit planning, but remain disabled until backend action endpoints are mounted.'**
  String get mortuaryActionGapBody;

  /// Section title for mortuary identity and source details.
  ///
  /// In en, this message translates to:
  /// **'Identity and source'**
  String get mortuaryIdentitySectionTitle;

  /// Section title for mortuary storage details.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get mortuaryStorageSectionTitle;

  /// Section title for mortuary custody log.
  ///
  /// In en, this message translates to:
  /// **'Custody log'**
  String get mortuaryCustodySectionTitle;

  /// Section title for mortuary viewing details.
  ///
  /// In en, this message translates to:
  /// **'Viewing'**
  String get mortuaryViewingSectionTitle;

  /// Section title for mortuary post-mortem details.
  ///
  /// In en, this message translates to:
  /// **'Post-mortem'**
  String get mortuaryPostMortemSectionTitle;

  /// Section title for mortuary release details.
  ///
  /// In en, this message translates to:
  /// **'Release'**
  String get mortuaryReleaseSectionTitle;

  /// Section title for mortuary billing details.
  ///
  /// In en, this message translates to:
  /// **'Billing'**
  String get mortuaryBillingSectionTitle;

  /// Section title for mortuary documents.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get mortuaryDocumentsSectionTitle;

  /// Field label for mortuary case.
  ///
  /// In en, this message translates to:
  /// **'Case'**
  String get mortuaryCaseFieldLabel;

  /// Field label for deceased person.
  ///
  /// In en, this message translates to:
  /// **'Deceased'**
  String get mortuaryDeceasedFieldLabel;

  /// Field label for linked patient.
  ///
  /// In en, this message translates to:
  /// **'Patient'**
  String get mortuaryPatientFieldLabel;

  /// Field label for status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get mortuaryStatusFieldLabel;

  /// Field label for received date.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get mortuaryReceivedAtFieldLabel;

  /// Field label for source workflow.
  ///
  /// In en, this message translates to:
  /// **'Source workflow'**
  String get mortuarySourceWorkflowFieldLabel;

  /// Field label for source department.
  ///
  /// In en, this message translates to:
  /// **'Source department'**
  String get mortuarySourceDepartmentFieldLabel;

  /// Field label for source reference.
  ///
  /// In en, this message translates to:
  /// **'Source reference'**
  String get mortuarySourceReferenceFieldLabel;

  /// Field label for received-from context.
  ///
  /// In en, this message translates to:
  /// **'Received from'**
  String get mortuaryReceivedFromFieldLabel;

  /// Field label for storage unit.
  ///
  /// In en, this message translates to:
  /// **'Storage unit'**
  String get mortuaryStorageUnitFieldLabel;

  /// Field label for storage status.
  ///
  /// In en, this message translates to:
  /// **'Storage status'**
  String get mortuaryStorageStatusFieldLabel;

  /// Field label for storage assignment date.
  ///
  /// In en, this message translates to:
  /// **'Assigned'**
  String get mortuaryAssignedAtFieldLabel;

  /// Field label for custody actor.
  ///
  /// In en, this message translates to:
  /// **'Actor'**
  String get mortuaryActorFieldLabel;

  /// Field label for custody location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get mortuaryLocationFieldLabel;

  /// Field label for notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get mortuaryNotesFieldLabel;

  /// Field label for release.
  ///
  /// In en, this message translates to:
  /// **'Release'**
  String get mortuaryReleaseFieldLabel;

  /// Field label for released date.
  ///
  /// In en, this message translates to:
  /// **'Released'**
  String get mortuaryReleasedAtFieldLabel;

  /// Empty label for custody events.
  ///
  /// In en, this message translates to:
  /// **'No custody events recorded'**
  String get mortuaryNoCustodyEventsLabel;

  /// Empty body for custody events.
  ///
  /// In en, this message translates to:
  /// **'Custody movements and handovers will appear here when recorded by the backend.'**
  String get mortuaryNoCustodyEventsBody;

  /// Empty label for mortuary viewings.
  ///
  /// In en, this message translates to:
  /// **'No viewings scheduled'**
  String get mortuaryNoViewingsLabel;

  /// Empty body for mortuary viewings.
  ///
  /// In en, this message translates to:
  /// **'Viewing appointments will appear here when scheduled.'**
  String get mortuaryNoViewingsBody;

  /// Empty label for post-mortem requests.
  ///
  /// In en, this message translates to:
  /// **'No post-mortem request recorded'**
  String get mortuaryNoPostMortemLabel;

  /// Empty body for post-mortem requests.
  ///
  /// In en, this message translates to:
  /// **'Post-mortem requests and reports will appear here when available.'**
  String get mortuaryNoPostMortemBody;

  /// Empty label for release authorisations.
  ///
  /// In en, this message translates to:
  /// **'No release recorded'**
  String get mortuaryNoReleaseLabel;

  /// Empty body for release authorisations.
  ///
  /// In en, this message translates to:
  /// **'Release authorisations and handover details will appear here when available.'**
  String get mortuaryNoReleaseBody;

  /// Empty label for mortuary billing events.
  ///
  /// In en, this message translates to:
  /// **'No billing events recorded'**
  String get mortuaryNoBillingLabel;

  /// Empty body for mortuary billing events.
  ///
  /// In en, this message translates to:
  /// **'Storage, post-mortem, and release billing events will appear here when available.'**
  String get mortuaryNoBillingBody;

  /// Body text for the mortuary documents section.
  ///
  /// In en, this message translates to:
  /// **'Generated intake, custody, release, and billing documents are available from the print action when case data is selected.'**
  String get mortuaryNoDocumentsBody;

  /// Document label for mortuary intake form.
  ///
  /// In en, this message translates to:
  /// **'Intake form'**
  String get mortuaryIntakeDocumentLabel;

  /// Document label for mortuary custody log.
  ///
  /// In en, this message translates to:
  /// **'Custody log'**
  String get mortuaryCustodyLogDocumentLabel;

  /// Document label for mortuary release authorisation.
  ///
  /// In en, this message translates to:
  /// **'Release authorisation'**
  String get mortuaryReleaseDocumentLabel;

  /// Next action label for identity verification.
  ///
  /// In en, this message translates to:
  /// **'Verify identity'**
  String get mortuaryNextActionVerifyIdentity;

  /// Next action label for storage assignment.
  ///
  /// In en, this message translates to:
  /// **'Assign storage'**
  String get mortuaryNextActionAssignStorage;

  /// Next action label for post-mortem review.
  ///
  /// In en, this message translates to:
  /// **'Review post-mortem'**
  String get mortuaryNextActionPostMortem;

  /// Next action label for billing clearance.
  ///
  /// In en, this message translates to:
  /// **'Clear billing'**
  String get mortuaryNextActionClearBilling;

  /// Next action label for release approval.
  ///
  /// In en, this message translates to:
  /// **'Approve release'**
  String get mortuaryNextActionApproveRelease;

  /// Next action label for released cases.
  ///
  /// In en, this message translates to:
  /// **'Released'**
  String get mortuaryNextActionReleased;

  /// Default next action label for mortuary cases.
  ///
  /// In en, this message translates to:
  /// **'Review case'**
  String get mortuaryNextActionReview;

  /// Title for generated mortuary case reports.
  ///
  /// In en, this message translates to:
  /// **'Mortuary case record'**
  String get mortuaryReportTitle;

  /// Footer text for generated mortuary documents.
  ///
  /// In en, this message translates to:
  /// **'Generated from confirmed mortuary workspace data.'**
  String get mortuaryReportFooter;

  /// Snackbar message after generating a mortuary document.
  ///
  /// In en, this message translates to:
  /// **'Mortuary document generated.'**
  String get mortuaryReportGeneratedMessage;

  /// Title for the rooms and beds workspace.
  ///
  /// In en, this message translates to:
  /// **'Rooms and beds'**
  String get roomsBedsTitle;

  /// Title shown while loading the rooms and beds workspace.
  ///
  /// In en, this message translates to:
  /// **'Loading rooms and beds'**
  String get roomsBedsLoadingTitle;

  /// Body shown while loading the rooms and beds workspace.
  ///
  /// In en, this message translates to:
  /// **'Retrieving wards, rooms, beds, assignments, and facility context.'**
  String get roomsBedsLoadingBody;

  /// Workspace status label while a rooms and beds mutation is saving.
  ///
  /// In en, this message translates to:
  /// **'Saving'**
  String get roomsBedsSavingStatus;

  /// Workspace status label when the rooms and beds board is loaded.
  ///
  /// In en, this message translates to:
  /// **'Live board'**
  String get roomsBedsLiveStatus;

  /// Summary card label for total beds.
  ///
  /// In en, this message translates to:
  /// **'Total beds'**
  String get roomsBedsTotalSummaryLabel;

  /// Title for the rooms and beds backend gap notice.
  ///
  /// In en, this message translates to:
  /// **'Backend status gaps'**
  String get roomsBedsBackendGapsTitle;

  /// Body for the rooms and beds backend gap notice.
  ///
  /// In en, this message translates to:
  /// **'Cleaning, maintenance, block, isolation, and detailed readiness states depend on backend support. Current actions use mounted ward, room, bed, bed assignment, and IPD flow endpoints only.'**
  String get roomsBedsBackendGapsBody;

  /// Title for the rooms and beds board panel.
  ///
  /// In en, this message translates to:
  /// **'Bed board'**
  String get roomsBedsBoardTitle;

  /// Description for the rooms and beds board panel.
  ///
  /// In en, this message translates to:
  /// **'Track availability, occupancy, reservations, and bed readiness by facility location.'**
  String get roomsBedsBoardDescription;

  /// Semantic label for rooms and beds search.
  ///
  /// In en, this message translates to:
  /// **'Search rooms and beds'**
  String get roomsBedsSearchLabel;

  /// Hint text for rooms and beds search.
  ///
  /// In en, this message translates to:
  /// **'Search bed, ward, room, patient admission, status, or facility'**
  String get roomsBedsSearchHint;

  /// Label for rooms and beds filters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get roomsBedsFiltersLabel;

  /// All-fields label for rooms and beds filtering.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get roomsBedsAllFilterLabel;

  /// Filter label for facility.
  ///
  /// In en, this message translates to:
  /// **'Facility'**
  String get roomsBedsFacilityFilterLabel;

  /// All option label for facilities.
  ///
  /// In en, this message translates to:
  /// **'All facilities'**
  String get roomsBedsAllFacilitiesLabel;

  /// Filter label for ward.
  ///
  /// In en, this message translates to:
  /// **'Ward'**
  String get roomsBedsWardFilterLabel;

  /// All option label for wards.
  ///
  /// In en, this message translates to:
  /// **'All wards'**
  String get roomsBedsAllWardsLabel;

  /// Filter label for room.
  ///
  /// In en, this message translates to:
  /// **'Room'**
  String get roomsBedsRoomFilterLabel;

  /// All option label for rooms.
  ///
  /// In en, this message translates to:
  /// **'All rooms'**
  String get roomsBedsAllRoomsLabel;

  /// Filter label for bed status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get roomsBedsStatusFilterLabel;

  /// All option label for bed statuses.
  ///
  /// In en, this message translates to:
  /// **'All statuses'**
  String get roomsBedsAllStatusesLabel;

  /// Label for the previous page action in the rooms and beds table.
  ///
  /// In en, this message translates to:
  /// **'Previous page'**
  String get roomsBedsPreviousPageLabel;

  /// Label for the next page action in the rooms and beds table.
  ///
  /// In en, this message translates to:
  /// **'Next page'**
  String get roomsBedsNextPageLabel;

  /// Pagination label for rooms and beds.
  ///
  /// In en, this message translates to:
  /// **'Showing {from}-{to} of {total}'**
  String roomsBedsPageLabel(int from, int to, int total);

  /// Empty state title for rooms and beds.
  ///
  /// In en, this message translates to:
  /// **'No beds found'**
  String get roomsBedsEmptyTitle;

  /// Empty state body for rooms and beds.
  ///
  /// In en, this message translates to:
  /// **'Adjust the filters or add beds from facility setup to start using the operational board.'**
  String get roomsBedsEmptyBody;

  /// Column label for bed identity.
  ///
  /// In en, this message translates to:
  /// **'Bed'**
  String get roomsBedsBedColumnLabel;

  /// Column label for bed location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get roomsBedsLocationColumnLabel;

  /// Column label for bed status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get roomsBedsStatusColumnLabel;

  /// Column label for bed assignment.
  ///
  /// In en, this message translates to:
  /// **'Assignment'**
  String get roomsBedsAssignmentColumnLabel;

  /// Column label for the next rooms and beds action.
  ///
  /// In en, this message translates to:
  /// **'Next action'**
  String get roomsBedsNextActionColumnLabel;

  /// Title for the bed detail dialog.
  ///
  /// In en, this message translates to:
  /// **'Bed detail'**
  String get roomsBedsDetailTitle;

  /// Field label for the active admission assigned to a bed.
  ///
  /// In en, this message translates to:
  /// **'Current admission'**
  String get roomsBedsCurrentAdmissionLabel;

  /// Field label for bed readiness.
  ///
  /// In en, this message translates to:
  /// **'Readiness'**
  String get roomsBedsReadinessLabel;

  /// Action label for reserving a bed.
  ///
  /// In en, this message translates to:
  /// **'Reserve'**
  String get roomsBedsReserveAction;

  /// Action label for marking a bed available.
  ///
  /// In en, this message translates to:
  /// **'Mark available'**
  String get roomsBedsMarkAvailableAction;

  /// Action label for marking a bed out of service.
  ///
  /// In en, this message translates to:
  /// **'Mark out of service'**
  String get roomsBedsMarkOutOfServiceAction;

  /// Action label for assigning a bed.
  ///
  /// In en, this message translates to:
  /// **'Assign bed'**
  String get roomsBedsAssignAction;

  /// Action label for releasing a bed.
  ///
  /// In en, this message translates to:
  /// **'Release bed'**
  String get roomsBedsReleaseAction;

  /// Action label for requesting an inpatient transfer.
  ///
  /// In en, this message translates to:
  /// **'Request transfer'**
  String get roomsBedsRequestTransferAction;

  /// Section title for bed assignment history.
  ///
  /// In en, this message translates to:
  /// **'Assignment history'**
  String get roomsBedsAssignmentHistoryTitle;

  /// Empty label for bed assignment history.
  ///
  /// In en, this message translates to:
  /// **'No assignment history recorded'**
  String get roomsBedsNoAssignmentsLabel;

  /// Status label for a current bed assignment.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get roomsBedsCurrentAssignmentLabel;

  /// Status label for a released bed assignment.
  ///
  /// In en, this message translates to:
  /// **'Released'**
  String get roomsBedsReleasedAssignmentLabel;

  /// Field label for admission ID in bed action dialogs.
  ///
  /// In en, this message translates to:
  /// **'Admission ID'**
  String get roomsBedsAdmissionFieldLabel;

  /// Hint text for admission ID in bed action dialogs.
  ///
  /// In en, this message translates to:
  /// **'Enter the admission ID'**
  String get roomsBedsAdmissionFieldHint;

  /// Field label for transfer destination ward.
  ///
  /// In en, this message translates to:
  /// **'Destination ward'**
  String get roomsBedsDestinationWardLabel;

  /// Dialog title for assigning a bed.
  ///
  /// In en, this message translates to:
  /// **'Assign bed'**
  String get roomsBedsAssignDialogTitle;

  /// Dialog title for releasing a bed.
  ///
  /// In en, this message translates to:
  /// **'Release bed'**
  String get roomsBedsReleaseDialogTitle;

  /// Body text for the release bed dialog.
  ///
  /// In en, this message translates to:
  /// **'Releasing the bed sends the admission through the backend bed release flow.'**
  String get roomsBedsReleaseDialogBody;

  /// Dialog title for requesting a bed transfer.
  ///
  /// In en, this message translates to:
  /// **'Request transfer'**
  String get roomsBedsTransferDialogTitle;

  /// Body text for the transfer request dialog.
  ///
  /// In en, this message translates to:
  /// **'Choose the destination ward. Bed selection is completed by the IPD transfer workflow when the backend approves and starts the transfer.'**
  String get roomsBedsTransferDialogBody;

  /// Display label for a bed assignment linked to an admission.
  ///
  /// In en, this message translates to:
  /// **'Admission {admissionId}'**
  String roomsBedsAdmissionAssignment(String admissionId);

  /// Fallback label when a bed status implies assignment but no active assignment is returned.
  ///
  /// In en, this message translates to:
  /// **'Assignment not linked'**
  String get roomsBedsAssignmentNotLinked;

  /// Next action label for available beds.
  ///
  /// In en, this message translates to:
  /// **'Assign next admission'**
  String get roomsBedsNextActionAssign;

  /// Next action label for occupied beds.
  ///
  /// In en, this message translates to:
  /// **'Release or transfer'**
  String get roomsBedsNextActionReleaseOrTransfer;

  /// Next action label for reserved beds.
  ///
  /// In en, this message translates to:
  /// **'Assign or release hold'**
  String get roomsBedsNextActionAssignOrReleaseHold;

  /// Next action label for out-of-service beds.
  ///
  /// In en, this message translates to:
  /// **'Resolve block'**
  String get roomsBedsNextActionResolveBlock;

  /// Readiness label for available beds.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get roomsBedsReadyLabel;

  /// Readiness label for unavailable beds.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get roomsBedsUnavailableLabel;

  /// Readiness fallback when the backend does not expose detailed readiness status.
  ///
  /// In en, this message translates to:
  /// **'Readiness pending backend status'**
  String get roomsBedsReadinessBackendGapLabel;

  /// Snackbar message after rooms and beds changes are saved.
  ///
  /// In en, this message translates to:
  /// **'Rooms and beds updated.'**
  String get roomsBedsSavedMessage;

  /// Validation message for required rooms and beds fields.
  ///
  /// In en, this message translates to:
  /// **'{field} is required.'**
  String roomsBedsRequiredMessage(String field);

  /// Human resources workspace text for hrActivityDescription.
  ///
  /// In en, this message translates to:
  /// **'Recent HR updates, approvals, and roster changes.'**
  String get hrActivityDescription;

  /// Human resources workspace text for hrActivityTitle.
  ///
  /// In en, this message translates to:
  /// **'HR activity'**
  String get hrActivityTitle;

  /// Human resources workspace text for hrAddStaffAction.
  ///
  /// In en, this message translates to:
  /// **'Add staff'**
  String get hrAddStaffAction;

  /// Human resources workspace text for hrAddStaffDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Add staff profile'**
  String get hrAddStaffDialogTitle;

  /// Human resources workspace text for hrAllowPartialPublishLabel.
  ///
  /// In en, this message translates to:
  /// **'Allow partial publish'**
  String get hrAllowPartialPublishLabel;

  /// Human resources workspace text for hrApproveLeaveAction.
  ///
  /// In en, this message translates to:
  /// **'Approve leave'**
  String get hrApproveLeaveAction;

  /// Human resources workspace text for hrApproveLeaveDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Approve leave'**
  String get hrApproveLeaveDialogTitle;

  /// Human resources workspace text for hrApproveSwapAction.
  ///
  /// In en, this message translates to:
  /// **'Approve swap'**
  String get hrApproveSwapAction;

  /// Human resources workspace text for hrApproveSwapDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Approve shift swap'**
  String get hrApproveSwapDialogTitle;

  /// Human resources workspace text for hrAssignDepartmentAction.
  ///
  /// In en, this message translates to:
  /// **'Assign department'**
  String get hrAssignDepartmentAction;

  /// Human resources workspace text for hrAssignDepartmentDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Assign department'**
  String get hrAssignDepartmentDialogTitle;

  /// Human resources workspace text for hrAssignmentLabel.
  ///
  /// In en, this message translates to:
  /// **'Assignment'**
  String get hrAssignmentLabel;

  /// Human resources workspace text for hrAssignmentsSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Assignments'**
  String get hrAssignmentsSectionTitle;

  /// Human resources workspace text for hrAssignPositionAction.
  ///
  /// In en, this message translates to:
  /// **'Assign position'**
  String get hrAssignPositionAction;

  /// Human resources workspace text for hrAssignPositionDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Assign position'**
  String get hrAssignPositionDialogTitle;

  /// Human resources workspace text for hrAssignShiftAction.
  ///
  /// In en, this message translates to:
  /// **'Assign shift'**
  String get hrAssignShiftAction;

  /// Human resources workspace text for hrAssignShiftDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Assign shift'**
  String get hrAssignShiftDialogTitle;

  /// Human resources workspace text for hrAvailabilityAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get hrAvailabilityAvailable;

  /// Human resources workspace text for hrAvailabilityDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Record availability'**
  String get hrAvailabilityDialogTitle;

  /// Human resources workspace text for hrAvailabilityPreferenceLabel.
  ///
  /// In en, this message translates to:
  /// **'Availability'**
  String get hrAvailabilityPreferenceLabel;

  /// Human resources workspace text for hrAvailabilityPreferred.
  ///
  /// In en, this message translates to:
  /// **'Preferred'**
  String get hrAvailabilityPreferred;

  /// Human resources workspace text for hrAvailabilitySectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Availability'**
  String get hrAvailabilitySectionTitle;

  /// Human resources workspace text for hrAvailabilityUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get hrAvailabilityUnavailable;

  /// Human resources workspace text for hrClearFiltersAction.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get hrClearFiltersAction;

  /// Human resources workspace text for hrConsultationCurrencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Consultation currency'**
  String get hrConsultationCurrencyLabel;

  /// Human resources workspace text for hrConsultationFeeLabel.
  ///
  /// In en, this message translates to:
  /// **'Consultation fee'**
  String get hrConsultationFeeLabel;

  /// Human resources workspace text for hrCreateStaffAction.
  ///
  /// In en, this message translates to:
  /// **'Create staff'**
  String get hrCreateStaffAction;

  /// Human resources workspace text for hrDayOfWeekLabel.
  ///
  /// In en, this message translates to:
  /// **'Day of week'**
  String get hrDayOfWeekLabel;

  /// Human resources workspace text for hrDepartmentColumnLabel.
  ///
  /// In en, this message translates to:
  /// **'Department'**
  String get hrDepartmentColumnLabel;

  /// Human resources workspace text for hrDepartmentFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Department'**
  String get hrDepartmentFilterLabel;

  /// Human resources workspace text for hrDepartmentLabel.
  ///
  /// In en, this message translates to:
  /// **'Department'**
  String get hrDepartmentLabel;

  /// Human resources workspace text for hrEditStaffAction.
  ///
  /// In en, this message translates to:
  /// **'Edit staff'**
  String get hrEditStaffAction;

  /// Human resources workspace text for hrEditStaffDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit staff profile'**
  String get hrEditStaffDialogTitle;

  /// Human resources workspace text for hrEffectiveFromLabel.
  ///
  /// In en, this message translates to:
  /// **'Effective from'**
  String get hrEffectiveFromLabel;

  /// Human resources workspace text for hrEffectiveToLabel.
  ///
  /// In en, this message translates to:
  /// **'Effective to'**
  String get hrEffectiveToLabel;

  /// Human resources workspace text for hrEndDateLabel.
  ///
  /// In en, this message translates to:
  /// **'End date'**
  String get hrEndDateLabel;

  /// Human resources workspace text for hrEndTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'End time'**
  String get hrEndTimeLabel;

  /// Human resources workspace text for hrFieldRequiredLabel.
  ///
  /// In en, this message translates to:
  /// **'{label} is required.'**
  String hrFieldRequiredLabel(String label);

  /// Human resources workspace text for hrFiltersLabel.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get hrFiltersLabel;

  /// Human resources workspace text for hrFridayLabel.
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get hrFridayLabel;

  /// Human resources workspace text for hrGenerateRosterAction.
  ///
  /// In en, this message translates to:
  /// **'Generate roster'**
  String get hrGenerateRosterAction;

  /// Human resources workspace text for hrHireDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Hire date'**
  String get hrHireDateLabel;

  /// Human resources workspace text for hrLeaveDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Request leave'**
  String get hrLeaveDialogTitle;

  /// Human resources workspace text for hrLeaveLabel.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get hrLeaveLabel;

  /// Human resources workspace text for hrLeaveReportLabel.
  ///
  /// In en, this message translates to:
  /// **'Leave summary'**
  String get hrLeaveReportLabel;

  /// Human resources workspace text for hrLeaveRequestsSummaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Leave requests'**
  String get hrLeaveRequestsSummaryLabel;

  /// Human resources workspace text for hrLeaveRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave request'**
  String get hrLeaveRequestTitle;

  /// Human resources workspace text for hrLeaveSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get hrLeaveSectionTitle;

  /// Human resources workspace text for hrLiveStatus.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get hrLiveStatus;

  /// Human resources workspace text for hrLoadingBody.
  ///
  /// In en, this message translates to:
  /// **'Loading staff records and rosters.'**
  String get hrLoadingBody;

  /// Human resources workspace text for hrLoadingTitle.
  ///
  /// In en, this message translates to:
  /// **'Loading HR workspace'**
  String get hrLoadingTitle;

  /// Human resources workspace text for hrMondayLabel.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get hrMondayLabel;

  /// Human resources workspace text for hrNextActionAssignDepartment.
  ///
  /// In en, this message translates to:
  /// **'Assign department'**
  String get hrNextActionAssignDepartment;

  /// Human resources workspace text for hrNextActionAssignPosition.
  ///
  /// In en, this message translates to:
  /// **'Assign position'**
  String get hrNextActionAssignPosition;

  /// Human resources workspace text for hrNextActionColumnLabel.
  ///
  /// In en, this message translates to:
  /// **'Next action'**
  String get hrNextActionColumnLabel;

  /// Human resources workspace text for hrNextActionReviewProfile.
  ///
  /// In en, this message translates to:
  /// **'Review profile'**
  String get hrNextActionReviewProfile;

  /// Human resources workspace text for hrNextPageLabel.
  ///
  /// In en, this message translates to:
  /// **'Next staff page'**
  String get hrNextPageLabel;

  /// Human resources workspace text for hrNextQueuePageLabel.
  ///
  /// In en, this message translates to:
  /// **'Next queue page'**
  String get hrNextQueuePageLabel;

  /// Human resources workspace text for hrNoActivityBody.
  ///
  /// In en, this message translates to:
  /// **'HR activity will appear here.'**
  String get hrNoActivityBody;

  /// Human resources workspace text for hrNoActivityTitle.
  ///
  /// In en, this message translates to:
  /// **'No activity yet'**
  String get hrNoActivityTitle;

  /// Human resources workspace text for hrNoAssignmentsLabel.
  ///
  /// In en, this message translates to:
  /// **'No assignments recorded.'**
  String get hrNoAssignmentsLabel;

  /// Human resources workspace text for hrNoAvailabilityLabel.
  ///
  /// In en, this message translates to:
  /// **'No availability recorded.'**
  String get hrNoAvailabilityLabel;

  /// Human resources workspace text for hrNoLeaveLabel.
  ///
  /// In en, this message translates to:
  /// **'No leave recorded.'**
  String get hrNoLeaveLabel;

  /// Human resources workspace text for hrNoQueueItemsBody.
  ///
  /// In en, this message translates to:
  /// **'No HR queue items match the current filter.'**
  String get hrNoQueueItemsBody;

  /// Human resources workspace text for hrNoQueueItemsTitle.
  ///
  /// In en, this message translates to:
  /// **'No queue items'**
  String get hrNoQueueItemsTitle;

  /// Human resources workspace text for hrNoShiftsLabel.
  ///
  /// In en, this message translates to:
  /// **'No shifts assigned.'**
  String get hrNoShiftsLabel;

  /// Human resources workspace text for hrNoStaffBody.
  ///
  /// In en, this message translates to:
  /// **'No staff profiles match the current filters.'**
  String get hrNoStaffBody;

  /// Human resources workspace text for hrNoStaffSelectedBody.
  ///
  /// In en, this message translates to:
  /// **'Select a staff member to review assignments, availability, leave, shifts, and payroll links.'**
  String get hrNoStaffSelectedBody;

  /// Human resources workspace text for hrNoStaffSelectedTitle.
  ///
  /// In en, this message translates to:
  /// **'No staff selected'**
  String get hrNoStaffSelectedTitle;

  /// Human resources workspace text for hrNoStaffTitle.
  ///
  /// In en, this message translates to:
  /// **'No staff found'**
  String get hrNoStaffTitle;

  /// Human resources workspace text for hrNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get hrNotesLabel;

  /// Human resources workspace text for hrNotifyStaffLabel.
  ///
  /// In en, this message translates to:
  /// **'Notify staff'**
  String get hrNotifyStaffLabel;

  /// Human resources workspace text for hrOverrideShiftAction.
  ///
  /// In en, this message translates to:
  /// **'Override shift'**
  String get hrOverrideShiftAction;

  /// Human resources workspace text for hrOverrideShiftDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Override shift'**
  String get hrOverrideShiftDialogTitle;

  /// Human resources workspace text for hrPageLabel.
  ///
  /// In en, this message translates to:
  /// **'{from}-{to} of {total}'**
  String hrPageLabel(int from, int to, int total);

  /// Human resources workspace text for hrPayrollDraftsSummaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Payroll drafts'**
  String get hrPayrollDraftsSummaryLabel;

  /// Human resources workspace text for hrPayrollDraftTitle.
  ///
  /// In en, this message translates to:
  /// **'Payroll draft'**
  String get hrPayrollDraftTitle;

  /// Human resources workspace text for hrPayrollReportLabel.
  ///
  /// In en, this message translates to:
  /// **'Payroll summary'**
  String get hrPayrollReportLabel;

  /// Human resources workspace text for hrPayrollRunDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Run payroll'**
  String get hrPayrollRunDialogTitle;

  /// Human resources workspace text for hrPeriodColumnLabel.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get hrPeriodColumnLabel;

  /// Human resources workspace text for hrPeriodEndLabel.
  ///
  /// In en, this message translates to:
  /// **'Period end'**
  String get hrPeriodEndLabel;

  /// Human resources workspace text for hrPeriodStartLabel.
  ///
  /// In en, this message translates to:
  /// **'Period start'**
  String get hrPeriodStartLabel;

  /// Human resources workspace text for hrPickDateAction.
  ///
  /// In en, this message translates to:
  /// **'Pick date'**
  String get hrPickDateAction;

  /// Human resources workspace text for hrPositionFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Position'**
  String get hrPositionFilterLabel;

  /// Human resources workspace text for hrPositionLabel.
  ///
  /// In en, this message translates to:
  /// **'Position'**
  String get hrPositionLabel;

  /// Human resources workspace text for hrPractitionerTypeFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'Practitioner type'**
  String get hrPractitionerTypeFilterLabel;

  /// Human resources workspace text for hrPractitionerTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Practitioner type'**
  String get hrPractitionerTypeLabel;

  /// Human resources workspace text for hrPreviewStaffProfileReportAction.
  ///
  /// In en, this message translates to:
  /// **'Preview staff profile'**
  String get hrPreviewStaffProfileReportAction;

  /// Human resources workspace text for hrPreviousPageLabel.
  ///
  /// In en, this message translates to:
  /// **'Previous staff page'**
  String get hrPreviousPageLabel;

  /// Human resources workspace text for hrPreviousQueuePageLabel.
  ///
  /// In en, this message translates to:
  /// **'Previous queue page'**
  String get hrPreviousQueuePageLabel;

  /// Human resources workspace text for hrProcessPayrollAction.
  ///
  /// In en, this message translates to:
  /// **'Process payroll'**
  String get hrProcessPayrollAction;

  /// Human resources workspace text for hrProcessPayrollDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Process payroll'**
  String get hrProcessPayrollDialogTitle;

  /// Human resources workspace text for hrPublishNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Publish note'**
  String get hrPublishNoteLabel;

  /// Human resources workspace text for hrPublishRosterAction.
  ///
  /// In en, this message translates to:
  /// **'Publish roster'**
  String get hrPublishRosterAction;

  /// Human resources workspace text for hrPublishRosterDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Publish roster'**
  String get hrPublishRosterDialogTitle;

  /// Human resources workspace text for hrQueueColumnLabel.
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get hrQueueColumnLabel;

  /// Human resources workspace text for hrQueueItemColumnLabel.
  ///
  /// In en, this message translates to:
  /// **'Item'**
  String get hrQueueItemColumnLabel;

  /// Human resources workspace text for hrQueueLeaveRequests.
  ///
  /// In en, this message translates to:
  /// **'Leave requests'**
  String get hrQueueLeaveRequests;

  /// Human resources workspace text for hrQueueOverdueShifts.
  ///
  /// In en, this message translates to:
  /// **'Overdue shifts'**
  String get hrQueueOverdueShifts;

  /// Human resources workspace text for hrQueuePayrollDrafts.
  ///
  /// In en, this message translates to:
  /// **'Payroll drafts'**
  String get hrQueuePayrollDrafts;

  /// Human resources workspace text for hrQueueRosterDrafts.
  ///
  /// In en, this message translates to:
  /// **'Roster drafts'**
  String get hrQueueRosterDrafts;

  /// Human resources workspace text for hrQueueSwapRequests.
  ///
  /// In en, this message translates to:
  /// **'Swap requests'**
  String get hrQueueSwapRequests;

  /// Human resources workspace text for hrQueueUnassignedShifts.
  ///
  /// In en, this message translates to:
  /// **'Unassigned shifts'**
  String get hrQueueUnassignedShifts;

  /// Human resources workspace text for hrReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get hrReasonLabel;

  /// Human resources workspace text for hrRecordAvailabilityAction.
  ///
  /// In en, this message translates to:
  /// **'Record availability'**
  String get hrRecordAvailabilityAction;

  /// Human resources workspace text for hrRejectLeaveAction.
  ///
  /// In en, this message translates to:
  /// **'Reject leave'**
  String get hrRejectLeaveAction;

  /// Human resources workspace text for hrRejectLeaveDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Reject leave'**
  String get hrRejectLeaveDialogTitle;

  /// Human resources workspace text for hrRejectSwapAction.
  ///
  /// In en, this message translates to:
  /// **'Reject swap'**
  String get hrRejectSwapAction;

  /// Human resources workspace text for hrRejectSwapDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Reject shift swap'**
  String get hrRejectSwapDialogTitle;

  /// Human resources workspace text for hrReplacePayrollItemsLabel.
  ///
  /// In en, this message translates to:
  /// **'Replace existing payroll items'**
  String get hrReplacePayrollItemsLabel;

  /// Human resources workspace text for hrReportsSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get hrReportsSectionTitle;

  /// Human resources workspace text for hrRequestLeaveAction.
  ///
  /// In en, this message translates to:
  /// **'Request leave'**
  String get hrRequestLeaveAction;

  /// Human resources workspace text for hrRolePositionColumnLabel.
  ///
  /// In en, this message translates to:
  /// **'Role / position'**
  String get hrRolePositionColumnLabel;

  /// Human resources workspace text for hrRosterDraftsSummaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Roster drafts'**
  String get hrRosterDraftsSummaryLabel;

  /// Human resources workspace text for hrRosterDraftTitle.
  ///
  /// In en, this message translates to:
  /// **'Roster draft'**
  String get hrRosterDraftTitle;

  /// Human resources workspace text for hrRosterReportLabel.
  ///
  /// In en, this message translates to:
  /// **'Roster report'**
  String get hrRosterReportLabel;

  /// Human resources workspace text for hrRunPayrollAction.
  ///
  /// In en, this message translates to:
  /// **'Run payroll'**
  String get hrRunPayrollAction;

  /// Human resources workspace text for hrSaturdayLabel.
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get hrSaturdayLabel;

  /// Human resources workspace text for hrSavedMessage.
  ///
  /// In en, this message translates to:
  /// **'HR changes saved.'**
  String get hrSavedMessage;

  /// Human resources workspace text for hrSaveStaffAction.
  ///
  /// In en, this message translates to:
  /// **'Save staff'**
  String get hrSaveStaffAction;

  /// Human resources workspace text for hrSavingStatus.
  ///
  /// In en, this message translates to:
  /// **'Saving'**
  String get hrSavingStatus;

  /// Human resources workspace text for hrSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search staff, department, role, shift, or status'**
  String get hrSearchHint;

  /// Human resources workspace text for hrSearchLabel.
  ///
  /// In en, this message translates to:
  /// **'Search HR records'**
  String get hrSearchLabel;

  /// Human resources workspace text for hrShiftIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Shift ID'**
  String get hrShiftIdLabel;

  /// Human resources workspace text for hrShiftLabel.
  ///
  /// In en, this message translates to:
  /// **'Shift'**
  String get hrShiftLabel;

  /// Human resources workspace text for hrShiftQueueTitle.
  ///
  /// In en, this message translates to:
  /// **'Shift queue item'**
  String get hrShiftQueueTitle;

  /// Human resources workspace text for hrShiftsSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Shifts'**
  String get hrShiftsSectionTitle;

  /// Human resources workspace text for hrStaffActionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Staff actions'**
  String get hrStaffActionsTitle;

  /// Human resources workspace text for hrStaffColumnLabel.
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get hrStaffColumnLabel;

  /// Human resources workspace text for hrStaffDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Staff detail'**
  String get hrStaffDetailTitle;

  /// Human resources workspace text for hrStaffDirectoryDescription.
  ///
  /// In en, this message translates to:
  /// **'Search staff by name, department, position, role, and status.'**
  String get hrStaffDirectoryDescription;

  /// Human resources workspace text for hrStaffDirectoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Staff directory'**
  String get hrStaffDirectoryTitle;

  /// Human resources workspace text for hrStaffLabel.
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get hrStaffLabel;

  /// Human resources workspace text for hrStaffListReportLabel.
  ///
  /// In en, this message translates to:
  /// **'Staff list'**
  String get hrStaffListReportLabel;

  /// Human resources workspace text for hrStaffNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Staff name'**
  String get hrStaffNameLabel;

  /// Human resources workspace text for hrStaffNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Staff number'**
  String get hrStaffNumberLabel;

  /// Human resources workspace text for hrStaffProfileReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Staff profile'**
  String get hrStaffProfileReportTitle;

  /// Human resources workspace text for hrStartDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get hrStartDateLabel;

  /// Human resources workspace text for hrStartTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Start time'**
  String get hrStartTimeLabel;

  /// Human resources workspace text for hrStatusColumnLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get hrStatusColumnLabel;

  /// Human resources workspace text for hrSundayLabel.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get hrSundayLabel;

  /// Human resources workspace text for hrSwapRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'Shift swap request'**
  String get hrSwapRequestTitle;

  /// Human resources workspace text for hrSwapShiftAction.
  ///
  /// In en, this message translates to:
  /// **'Swap shift'**
  String get hrSwapShiftAction;

  /// Human resources workspace text for hrSwapShiftDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Request shift swap'**
  String get hrSwapShiftDialogTitle;

  /// Human resources workspace text for hrTargetStaffLabel.
  ///
  /// In en, this message translates to:
  /// **'Target staff'**
  String get hrTargetStaffLabel;

  /// Human resources workspace text for hrTenantIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Tenant ID'**
  String get hrTenantIdLabel;

  /// Human resources workspace text for hrThursdayLabel.
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get hrThursdayLabel;

  /// Human resources workspace text for hrTimeHint.
  ///
  /// In en, this message translates to:
  /// **'HH:MM'**
  String get hrTimeHint;

  /// Human resources workspace text for hrTotalStaffSummaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Total staff'**
  String get hrTotalStaffSummaryLabel;

  /// Human resources workspace text for hrTuesdayLabel.
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get hrTuesdayLabel;

  /// Human resources workspace text for hrUnassignedShiftsSummaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Unassigned shifts'**
  String get hrUnassignedShiftsSummaryLabel;

  /// Human resources workspace text for hrUnitIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Unit ID'**
  String get hrUnitIdLabel;

  /// Human resources workspace text for hrUserIdLabel.
  ///
  /// In en, this message translates to:
  /// **'User ID'**
  String get hrUserIdLabel;

  /// Human resources workspace text for hrWednesdayLabel.
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get hrWednesdayLabel;

  /// Human resources workspace text for hrWorkQueuesTitle.
  ///
  /// In en, this message translates to:
  /// **'Work queues'**
  String get hrWorkQueuesTitle;
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
