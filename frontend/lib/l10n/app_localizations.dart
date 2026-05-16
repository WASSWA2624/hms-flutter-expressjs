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

  /// Validation message for manually typed date fields.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid date.'**
  String get appDateInvalidMessage;

  /// Hint text showing the supported manual date entry format.
  ///
  /// In en, this message translates to:
  /// **'YYYY-MM-DD'**
  String get appDateFormatHint;

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

  /// Navigation label for the OPD workflow destination.
  ///
  /// In en, this message translates to:
  /// **'OPD'**
  String get navigationOpdLabel;

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

  /// Action label to start a walk-in OPD encounter.
  ///
  /// In en, this message translates to:
  /// **'Start walk-in'**
  String get opdStartWalkInAction;

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

  /// Arrival time column label.
  ///
  /// In en, this message translates to:
  /// **'Arrival time'**
  String get opdTimeColumnLabel;

  /// Provider column label.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get opdProviderColumnLabel;

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

  /// Walk-in dialog title.
  ///
  /// In en, this message translates to:
  /// **'Start OPD walk-in'**
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
  /// **'Check in'**
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

  /// Action label to record consultation payment.
  ///
  /// In en, this message translates to:
  /// **'Pay consultation'**
  String get opdPayConsultationAction;

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

  /// Snackbar shown after a patient registry change is saved.
  ///
  /// In en, this message translates to:
  /// **'Patient registry changes saved.'**
  String get patientsSavedMessage;

  /// Snackbar shown after a patient registry record is deleted.
  ///
  /// In en, this message translates to:
  /// **'Patient registry record deleted.'**
  String get patientsDeletedMessage;

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

  /// Snackbar shown when a patient quick action is selected.
  ///
  /// In en, this message translates to:
  /// **'The patient context is ready for the selected workflow.'**
  String get patientsQuickActionQueuedMessage;

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
