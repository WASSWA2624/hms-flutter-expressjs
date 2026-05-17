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
  String get commonRefreshActionLabel => 'Refresh';

  @override
  String get commonGoHomeActionLabel => 'Go home';

  @override
  String get commonCancelActionLabel => 'Cancel';

  @override
  String get commonCloseActionLabel => 'Close';

  @override
  String get appDateInvalidMessage => 'Enter a valid date.';

  @override
  String get appDateFormatHint => 'DD/MM/YYYY';

  @override
  String get appPhoneCountryLabel => 'Country code';

  @override
  String get appPhoneCountrySearchLabel => 'Search country';

  @override
  String get appPhoneCountryNoResults => 'No countries found';

  @override
  String get appPhoneNumberLabel => 'Phone number';

  @override
  String get appPhoneNumberHint => 'Remaining number digits';

  @override
  String get appPhoneInvalidMessage => 'Enter a valid phone number.';

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
  String get appUserMenuSignedInLabel => 'Signed in';

  @override
  String get navigationHomeLabel => 'Home';

  @override
  String get navigationSettingsLabel => 'Settings';

  @override
  String get navigationSetupLabel => 'Setup';

  @override
  String get navigationPatientsLabel => 'Patients';

  @override
  String get navigationOpdLabel => 'OPD';

  @override
  String get navigationTheaterLabel => 'Theater';

  @override
  String get theaterTitle => 'Theater';

  @override
  String get theaterDescription =>
      'Manage daily cases, readiness, room and team allocation, anesthesia, post-op notes, and handover.';

  @override
  String get theaterLoadingTitle => 'Loading theater';

  @override
  String get theaterLoadingBody =>
      'Loading theater cases and clinical records.';

  @override
  String get theaterLiveStatus => 'Live sync';

  @override
  String get theaterSavingStatus => 'Saving';

  @override
  String get theaterSavedMessage => 'Theater changes saved.';

  @override
  String get theaterScheduleCaseAction => 'Schedule case';

  @override
  String get theaterScheduledSummaryLabel => 'Scheduled';

  @override
  String get theaterInTheaterSummaryLabel => 'In theater';

  @override
  String get theaterReadySummaryLabel => 'Ready';

  @override
  String get theaterCompletedSummaryLabel => 'Completed';

  @override
  String get theaterFiltersLabel => 'Theater filters';

  @override
  String get theaterSearchLabel => 'Search theater';

  @override
  String get theaterSearchHint =>
      'Search patient, case, encounter, notes, or record text';

  @override
  String get theaterScheduleDateFilterLabel => 'Schedule date';

  @override
  String get theaterPickScheduleDateAction => 'Pick schedule date';

  @override
  String get theaterStatusFilterLabel => 'Status';

  @override
  String get theaterStageFilterLabel => 'Stage';

  @override
  String get theaterResourceFiltersAction => 'Resource filters';

  @override
  String get theaterClearFiltersAction => 'Clear filters';

  @override
  String get theaterCasesTitle => 'Daily cases';

  @override
  String get theaterCasesDescription =>
      'Select a case to review readiness, records, resources, and handover.';

  @override
  String get theaterNoCasesTitle => 'No theater cases';

  @override
  String get theaterNoCasesBody =>
      'Scheduled and active theater cases will appear here.';

  @override
  String get theaterNoCaseSelectedTitle => 'No case selected';

  @override
  String get theaterNoCaseSelectedBody =>
      'Select a theater case to review readiness, records, and handover.';

  @override
  String get theaterPatientColumnLabel => 'Patient';

  @override
  String get theaterTimeColumnLabel => 'Time';

  @override
  String get theaterRoomColumnLabel => 'Room';

  @override
  String get theaterStatusColumnLabel => 'Status';

  @override
  String get theaterReadinessColumnLabel => 'Readiness';

  @override
  String get theaterNextActionColumnLabel => 'Next action';

  @override
  String theaterPageLabel(int from, int to, int total) {
    return '$from-$to of $total';
  }

  @override
  String get theaterCaseDetailTitle => 'Case detail';

  @override
  String get theaterRescheduleAction => 'Reschedule';

  @override
  String get theaterUpdateStageAction => 'Update stage';

  @override
  String get theaterEncounterLabel => 'Encounter';

  @override
  String get theaterScheduledAtLabel => 'Scheduled at';

  @override
  String get theaterRoomLabel => 'Room';

  @override
  String get theaterReadinessLabel => 'Readiness';

  @override
  String get theaterTeamTitle => 'Team and flow';

  @override
  String get theaterSurgeonLabel => 'Surgeon';

  @override
  String get theaterAnesthetistLabel => 'Anesthetist';

  @override
  String get theaterStageLabel => 'Stage';

  @override
  String get theaterStatusLabel => 'Status';

  @override
  String get theaterStageNotesLabel => 'Stage notes';

  @override
  String get theaterAssignResourceAction => 'Assign resource';

  @override
  String get theaterUpdateReadinessAction => 'Update readiness';

  @override
  String get theaterAnesthesiaAction => 'Anesthesia';

  @override
  String get theaterPostOpAction => 'Post-op';

  @override
  String get theaterHandoverAction => 'Handover';

  @override
  String get theaterFinalizeAction => 'Finalize';

  @override
  String get theaterCancelCaseAction => 'Cancel case';

  @override
  String get theaterStartCaseAction => 'Start case';

  @override
  String get theaterChecklistTitle => 'Readiness checklist';

  @override
  String get theaterNoChecklistItemsLabel => 'No checklist items recorded';

  @override
  String get theaterRecordsTitle => 'Clinical records';

  @override
  String get theaterAnesthesiaStatusLabel => 'Anesthesia status';

  @override
  String get theaterPostOpStatusLabel => 'Post-op status';

  @override
  String get theaterAnesthesiaNotesLabel => 'Anesthesia notes';

  @override
  String get theaterPostOpNoteLabel => 'Post-op note';

  @override
  String get theaterNoObservationsLabel =>
      'No anesthesia observations recorded';

  @override
  String get theaterResourcesTitle => 'Resources';

  @override
  String get theaterNoResourcesLabel => 'No resources assigned';

  @override
  String get theaterTimelineTitle => 'Timeline';

  @override
  String get theaterNoTimelineLabel => 'No timeline entries';

  @override
  String get theaterScheduleCaseDialogTitle => 'Schedule theater case';

  @override
  String get theaterRescheduleDialogTitle => 'Reschedule theater case';

  @override
  String get theaterUpdateStageDialogTitle => 'Update theater stage';

  @override
  String get theaterHandoverDialogTitle => 'Complete handover';

  @override
  String get theaterHandoverNotesLabel => 'Handover notes';

  @override
  String get theaterCancelCaseDialogTitle => 'Cancel theater case';

  @override
  String get theaterCancellationReasonLabel => 'Cancellation reason';

  @override
  String get theaterAssignResourceDialogTitle => 'Assign theater resource';

  @override
  String get theaterReadinessDialogTitle => 'Update readiness';

  @override
  String get theaterAnesthesiaDialogTitle => 'Anesthesia record';

  @override
  String get theaterPostOpDialogTitle => 'Post-op note';

  @override
  String get theaterFinalizeDialogTitle => 'Finalize records';

  @override
  String get theaterResourceFiltersDialogTitle => 'Resource filters';

  @override
  String get theaterEncounterIdLabel => 'Encounter ID';

  @override
  String get theaterEncounterIdHint =>
      'Encounter UUID or case source identifier';

  @override
  String get theaterDateTimeHint => 'YYYY-MM-DDTHH:MM:SS';

  @override
  String get theaterRoomIdLabel => 'Room ID';

  @override
  String get theaterSurgeonIdLabel => 'Surgeon user ID';

  @override
  String get theaterAnesthetistIdLabel => 'Anesthetist user ID';

  @override
  String get theaterResourceTypeLabel => 'Resource type';

  @override
  String get theaterResourceIdLabel => 'Resource ID';

  @override
  String get theaterStaffRoleLabel => 'Staff role';

  @override
  String get theaterNotesLabel => 'Notes';

  @override
  String get theaterChecklistPhaseLabel => 'Checklist phase';

  @override
  String get theaterChecklistItemCodeLabel => 'Item code';

  @override
  String get theaterChecklistItemLabel => 'Item label';

  @override
  String get theaterChecklistCheckedLabel => 'Completed';

  @override
  String get theaterRecordStatusLabel => 'Record status';

  @override
  String get theaterSaveRecordAction => 'Save record';

  @override
  String get theaterRecordTypeLabel => 'Record type';

  @override
  String get theaterApplyFiltersAction => 'Apply filters';

  @override
  String theaterFieldRequiredLabel(String label) {
    return '$label is required.';
  }

  @override
  String get theaterStatusScheduled => 'Scheduled';

  @override
  String get theaterStatusInTheater => 'In theater';

  @override
  String get theaterStatusCompleted => 'Completed';

  @override
  String get theaterStatusCancelled => 'Cancelled';

  @override
  String get theaterStagePreOp => 'Pre-op';

  @override
  String get theaterStageSignIn => 'Sign in';

  @override
  String get theaterStageTimeOut => 'Time out';

  @override
  String get theaterStageIntraOp => 'Intra-op';

  @override
  String get theaterStageSignOut => 'Sign out';

  @override
  String get theaterStagePostOp => 'Post-op';

  @override
  String get theaterStagePacuHandoff => 'PACU handover';

  @override
  String get theaterStageCompleted => 'Completed';

  @override
  String get theaterRecordDraft => 'Draft';

  @override
  String get theaterRecordFinal => 'Final';

  @override
  String get theaterReadinessNotStarted => 'Not started';

  @override
  String theaterReadinessProgress(int completed, int total) {
    return '$completed/$total complete';
  }

  @override
  String get opdTitle => 'OPD flow';

  @override
  String get opdDescription =>
      'Manage arrivals, queues, provider readiness, and outpatient clinical handoffs.';

  @override
  String get opdLoadingTitle => 'Loading OPD flow';

  @override
  String get opdLoadingBody => 'Loading outpatient queue and encounter data.';

  @override
  String get opdLiveStatus => 'Live sync';

  @override
  String get opdSavingStatus => 'Saving';

  @override
  String get opdStartWalkInAction => 'Start walk-in';

  @override
  String get opdSavedMessage => 'OPD changes saved.';

  @override
  String get opdArrivalsSummaryLabel => 'Arrivals';

  @override
  String get opdQueueSummaryLabel => 'Queue';

  @override
  String get opdActiveFlowSummaryLabel => 'Active flows';

  @override
  String get opdCompletedFlowSummaryLabel => 'Completed';

  @override
  String get opdFiltersLabel => 'OPD filters';

  @override
  String get opdFilterAction => 'Filter OPD table';

  @override
  String get opdFilterDialogTitle => 'Filter OPD table';

  @override
  String get opdCategoryFilterLabel => 'Category';

  @override
  String get opdStatusFilterLabel => 'Status';

  @override
  String get opdAllCategoriesOption => 'All categories';

  @override
  String get opdAllStatusesOption => 'All statuses';

  @override
  String get opdSearchLabel => 'Search OPD';

  @override
  String get opdSearchHint => 'Search patient, identifier, or provider';

  @override
  String get opdApplyFiltersAction => 'Apply filters';

  @override
  String get opdClearFiltersAction => 'Clear filters';

  @override
  String get opdAppointmentStatusFilterLabel => 'Appointment status';

  @override
  String get opdQueueStatusFilterLabel => 'Queue status';

  @override
  String get opdFlowStageFilterLabel => 'Flow stage';

  @override
  String get opdArrivalsTitle => 'Arrivals';

  @override
  String get opdQueueBoardTitle => 'Queue board';

  @override
  String get opdFlowsTitle => 'OPD encounters';

  @override
  String get opdProviderReadinessTitle => 'Provider readiness';

  @override
  String get opdActivityTitle => 'Recent OPD activity';

  @override
  String get opdActivityDescription =>
      'Latest visible outpatient flow changes.';

  @override
  String get opdNoArrivalsTitle => 'No arrivals';

  @override
  String get opdNoArrivalsBody =>
      'Scheduled and checked-in patients will appear here.';

  @override
  String get opdNoQueueTitle => 'No queued patients';

  @override
  String get opdNoQueueBody =>
      'Reception queue entries will appear here as patients are routed.';

  @override
  String get opdNoFlowsTitle => 'No OPD encounters';

  @override
  String get opdNoFlowsBody =>
      'Started outpatient encounters will appear here.';

  @override
  String get opdNoFlowSelectedTitle => 'No encounter selected';

  @override
  String get opdNoFlowSelectedBody =>
      'Select an OPD encounter to review actions and related records.';

  @override
  String get opdNoProvidersTitle => 'No providers ready';

  @override
  String get opdNoProvidersBody =>
      'Provider schedules and available slots will appear here.';

  @override
  String get opdNoActivityTitle => 'No recent activity';

  @override
  String get opdNoActivityBody =>
      'OPD activity appears once encounters start moving.';

  @override
  String get opdNoSummaryPatientsTitle => 'No patients';

  @override
  String get opdNoSummaryPatientsBody =>
      'Matching OPD patients will appear here.';

  @override
  String get opdPatientColumnLabel => 'Patient';

  @override
  String get opdCategoryColumnLabel => 'Category';

  @override
  String get opdStatusColumnLabel => 'Status';

  @override
  String get opdTimeColumnLabel => 'Arrival time';

  @override
  String get opdProviderColumnLabel => 'Provider';

  @override
  String get opdActionsColumnLabel => 'Actions';

  @override
  String get opdStageColumnLabel => 'Stage';

  @override
  String get opdNextStepColumnLabel => 'Next step';

  @override
  String get opdOpenActions => 'Open actions';

  @override
  String get opdQueueEmptyColumnLabel => 'No patients';

  @override
  String get opdNoRelatedRecordsLabel => 'No related records';

  @override
  String get opdNoTimelineLabel => 'No timeline entries';

  @override
  String get opdTimelineTitle => 'Timeline';

  @override
  String get opdReferralsTitle => 'Referrals';

  @override
  String get opdFollowUpsTitle => 'Follow-ups';

  @override
  String get opdPaymentStatusLabel => 'Payment';

  @override
  String get opdPaymentPaidLabel => 'Paid';

  @override
  String get opdPaymentRequiredLabel => 'Payment required';

  @override
  String get opdPaymentNotRequiredLabel => 'Not required';

  @override
  String opdPageLabel(int from, int to, int total) {
    return '$from-$to of $total';
  }

  @override
  String get opdPreviousPageLabel => 'Previous page';

  @override
  String get opdNextPageLabel => 'Next page';

  @override
  String opdAvailableSlotsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count open slots',
      one: '1 open slot',
      zero: 'No open slots',
    );
    return '$_temp0';
  }

  @override
  String get opdWalkInDialogTitle => 'Start OPD walk-in';

  @override
  String get opdPatientSectionTitle => 'Patient';

  @override
  String get opdRoutingSectionTitle => 'Routing';

  @override
  String get opdBillingSectionTitle => 'Billing';

  @override
  String get opdExistingPatientModeLabel => 'Existing patient';

  @override
  String get opdAppointmentPatientModeLabel => 'Appointment patient';

  @override
  String get opdNewPatientModeLabel => 'New patient';

  @override
  String get opdSearchPatientLabel => 'Search patient';

  @override
  String get opdAppointmentPatientLabel => 'Search appointment';

  @override
  String get opdAppointmentPatientHelper =>
      'Select a scheduled appointment to check the patient into OPD.';

  @override
  String get opdSearchProviderLabel => 'Search provider';

  @override
  String get opdSearchProviderHelper =>
      'This provider will handle the patient.';

  @override
  String get opdNoProvidersHelper =>
      'No registered providers were found. Check doctor setup or provider permissions.';

  @override
  String get opdRegisterNewPatientLabel => 'Register a new patient';

  @override
  String get opdPatientIdLabel => 'Patient ID';

  @override
  String get opdFirstNameLabel => 'First name';

  @override
  String get opdLastNameLabel => 'Last name';

  @override
  String get opdGenderLabel => 'Gender';

  @override
  String get opdProviderIdLabel => 'Provider ID';

  @override
  String get opdConsultationFeeLabel => 'Consultation fee';

  @override
  String get opdCurrencyLabel => 'Currency';

  @override
  String get opdNotesLabel => 'Notes';

  @override
  String get opdQueueAction => 'Queue';

  @override
  String get opdRescheduleAction => 'Reschedule';

  @override
  String get opdCancelAction => 'Cancel';

  @override
  String get opdCheckInAction => 'Check in';

  @override
  String get opdAppointmentStartLabel => 'Start time';

  @override
  String get opdAppointmentEndLabel => 'End time';

  @override
  String get opdDateTimeHint => 'YYYY-MM-DDTHH:MM:SS';

  @override
  String get opdSaveAction => 'Save';

  @override
  String get opdCancellationReasonLabel => 'Cancellation reason';

  @override
  String get opdQueueStatusLabel => 'Queue status';

  @override
  String get opdReasonLabel => 'Reason';

  @override
  String get opdPrioritizeAction => 'Prioritize';

  @override
  String get opdMoveQueueAction => 'Move';

  @override
  String get opdStartConsultationAction => 'Start consultation';

  @override
  String get opdAssignDoctorAction => 'Assign doctor';

  @override
  String get opdPayConsultationAction => 'Pay consultation';

  @override
  String get opdCorrectStageAction => 'Correct stage';

  @override
  String get opdReferAction => 'Refer';

  @override
  String get opdFollowUpAction => 'Follow up';

  @override
  String get opdDispositionAction => 'Disposition';

  @override
  String get opdAmountLabel => 'Amount';

  @override
  String get opdPaymentMethodLabel => 'Payment method';

  @override
  String get opdTransactionReferenceLabel => 'Transaction reference';

  @override
  String get opdStageLabel => 'Stage';

  @override
  String get opdExternalFacilityLabel => 'External facility';

  @override
  String get opdFollowUpDateLabel => 'Follow-up date';

  @override
  String get opdDecisionLabel => 'Decision';

  @override
  String get opdRouteDecisionLabel => 'Route decision';

  @override
  String get opdArrivalModeLabel => 'Arrival mode';

  @override
  String get opdEmergencySeverityLabel => 'Emergency severity';

  @override
  String get opdTriageLevelLabel => 'Triage level';

  @override
  String get opdChiefComplaintLabel => 'Chief complaint';

  @override
  String get opdEmergencyIndicatorsLabel => 'Emergency indicators';

  @override
  String get opdWorkflowReceptionTitle => 'Reception and queue';

  @override
  String get opdWorkflowTriageTitle => 'Triage';

  @override
  String get opdWorkflowDoctorTitle => 'Doctor consultation';

  @override
  String get opdWorkflowServicesTitle => 'Services';

  @override
  String get opdWorkflowPrintTitle => 'Printing';

  @override
  String get opdSendToTriageAction => 'Send to triage';

  @override
  String get opdSendToDoctorAction => 'Send to doctor';

  @override
  String get opdRecordVitalsAction => 'Record vitals';

  @override
  String get opdDoctorReviewAction => 'Doctor review';

  @override
  String get opdRouteLabAction => 'Send to lab';

  @override
  String get opdRouteRadiologyAction => 'Send to radiology';

  @override
  String get opdRoutePharmacyAction => 'Send to pharmacy';

  @override
  String get opdPrintSummaryAction => 'Print summary';

  @override
  String get opdPrintAction => 'Print';

  @override
  String get opdCopySummaryAction => 'Copy summary';

  @override
  String get opdVitalsSummaryLabel => 'Vitals';

  @override
  String get opdAbnormalVitalsSummaryLabel => 'Abnormal vitals';

  @override
  String get opdClinicalAlertsSummaryLabel => 'Clinical alerts';

  @override
  String get opdServicesSummaryLabel => 'Services';

  @override
  String get opdClinicalNotesSummaryLabel => 'Clinical notes';

  @override
  String get opdProceduresSummaryLabel => 'Procedures';

  @override
  String get opdClinicalNoteLabel => 'Clinical note';

  @override
  String get opdDiagnosisTypeLabel => 'Diagnosis type';

  @override
  String get opdDiagnosisLabel => 'Diagnosis';

  @override
  String get opdDiagnosisCodeLabel => 'Diagnosis code';

  @override
  String get opdProcedureLabel => 'Procedure or minor surgery';

  @override
  String get opdProcedureCodeLabel => 'Procedure code';

  @override
  String get opdLabTestIdsLabel => 'Lab test IDs';

  @override
  String get opdLabPanelIdsLabel => 'Lab panel IDs';

  @override
  String get opdRadiologyTestIdsLabel => 'Radiology test IDs';

  @override
  String get opdDrugLabel => 'Available drug';

  @override
  String get opdDrugQuantityLabel => 'Quantity';

  @override
  String get opdDosageLabel => 'Dosage';

  @override
  String get opdFrequencyLabel => 'Frequency';

  @override
  String get opdMedicationRouteLabel => 'Medication route';

  @override
  String get opdPrescriptionNotesLabel => 'Prescription notes';

  @override
  String get opdTemperatureLabel => 'Temperature';

  @override
  String get opdSystolicLabel => 'Systolic';

  @override
  String get opdDiastolicLabel => 'Diastolic';

  @override
  String get opdHeartRateLabel => 'Heart rate';

  @override
  String get opdRespiratoryRateLabel => 'Respiratory rate';

  @override
  String get opdOxygenSaturationLabel => 'Oxygen saturation';

  @override
  String get opdWeightLabel => 'Weight';

  @override
  String get opdTriageNotesLabel => 'Triage notes';

  @override
  String get opdTriageScopeFilterLabel => 'Triage scope';

  @override
  String get opdAllTriageScopesOption => 'All triage scopes';

  @override
  String get opdTriageScopeWaiting => 'Waiting';

  @override
  String get opdTriageScopeUrgent => 'Urgent';

  @override
  String get opdTriageScopeEmergency => 'Emergency';

  @override
  String get opdTriageScopeRoutine => 'Routine';

  @override
  String get opdTriageScopeServiceOnly => 'Service-only';

  @override
  String opdWaitDurationShort(String duration) {
    return 'Wait $duration';
  }

  @override
  String get opdSymptomsLabel => 'Symptoms';

  @override
  String get opdPainSeverityLabel => 'Pain severity';

  @override
  String get opdAllergiesLabel => 'Allergies';

  @override
  String get opdRiskFlagsLabel => 'Risk flags';

  @override
  String get opdRiskFlagFall => 'Fall risk';

  @override
  String get opdRiskFlagPregnancy => 'Pregnancy';

  @override
  String get opdRiskFlagInfection => 'Infection risk';

  @override
  String get opdRiskFlagAlteredMentalState => 'Altered mental state';

  @override
  String get opdRiskFlagBleeding => 'Bleeding';

  @override
  String get opdNoRouteDecisionLabel => 'Do not route yet';

  @override
  String get patientsTitle => 'Patient registry';

  @override
  String get patientsBody =>
      'Find, register, and maintain patient records across front desk and care workflows.';

  @override
  String get patientsLoadingTitle => 'Loading patients';

  @override
  String get patientsLoadingBody => 'Loading patient registry data.';

  @override
  String get patientsStatusReady => 'Registry ready';

  @override
  String get patientsAddAction => 'Add patient';

  @override
  String get patientsEmergencyRegisterAction => 'Emergency registration';

  @override
  String get patientsEditAction => 'Edit';

  @override
  String get patientsDeleteAction => 'Delete';

  @override
  String get patientsSaveAction => 'Save';

  @override
  String get patientsSaveAnywayAction => 'Save anyway';

  @override
  String get patientsSavedMessage => 'Patient registry changes saved.';

  @override
  String get patientsEmergencySavedMessage =>
      'Emergency patient registered for completion.';

  @override
  String get patientsDeletedMessage => 'Patient registry record deleted.';

  @override
  String get patientsMergedMessage => 'Patient records merged.';

  @override
  String get patientsDuplicateDismissedMessage => 'Duplicate review dismissed.';

  @override
  String get patientsTotalSummaryLabel => 'Total patients';

  @override
  String get patientsTotalSummaryBody =>
      'All visible patient records in scope.';

  @override
  String get patientsActiveSummaryLabel => 'Active patients';

  @override
  String get patientsActiveSummaryBody =>
      'Patients available for current workflows.';

  @override
  String get patientsQueueSummaryLabel => 'Waiting queue';

  @override
  String get patientsQueueSummaryBody =>
      'Patients currently waiting for service.';

  @override
  String get patientsDuplicateSummaryLabel => 'Duplicate review';

  @override
  String get patientsDuplicateSummaryBody =>
      'Potential matches needing review.';

  @override
  String get patientsFiltersLabel => 'Patient filters';

  @override
  String get patientsSearchLabel => 'Search';

  @override
  String get patientsSearchHint => 'Name, phone, email, identifier, or contact';

  @override
  String get patientsPatientIdFilterLabel => 'Patient ID';

  @override
  String get patientsGenderFilterLabel => 'Gender';

  @override
  String get patientsStatusFilterLabel => 'Status';

  @override
  String get patientsConsentFilterLabel => 'Consent';

  @override
  String get patientsContactFilterLabel => 'Contact';

  @override
  String get patientsVisitDateFilterLabel => 'Visit date';

  @override
  String get patientsVisitFromFilterLabel => 'Visit from';

  @override
  String get patientsVisitToFilterLabel => 'Visit to';

  @override
  String get patientsDobFromFilterLabel => 'DOB from';

  @override
  String get patientsDobToFilterLabel => 'DOB to';

  @override
  String get patientsCreatedFromFilterLabel => 'Registered from';

  @override
  String get patientsCreatedToFilterLabel => 'Registered to';

  @override
  String get patientsActiveAdmissionFilterLabel => 'Active admission';

  @override
  String get patientsOutstandingBalanceFilterLabel => 'Outstanding balance';

  @override
  String get patientsYesFilterLabel => 'Yes';

  @override
  String get patientsNoFilterLabel => 'No';

  @override
  String get patientsFilterIdentitySectionTitle => 'Identity';

  @override
  String get patientsFilterVisitSectionTitle => 'Visits';

  @override
  String get patientsFilterRecordSectionTitle => 'Record state';

  @override
  String get patientsApplyFiltersAction => 'Apply';

  @override
  String get patientsClearFiltersAction => 'Clear';

  @override
  String get patientsAdvancedFiltersAction => 'Advanced filters';

  @override
  String get patientsAdvancedFiltersTitle => 'Advanced filters';

  @override
  String get patientsSummaryLoadingTitle => 'Loading patients';

  @override
  String get patientsSummaryLoadingBody => 'Loading related patient records.';

  @override
  String get patientsActiveFilter => 'Active';

  @override
  String get patientsInactiveFilter => 'Inactive';

  @override
  String get patientsPatientColumnLabel => 'Patient';

  @override
  String get patientsIdentifierColumnLabel => 'Identifier';

  @override
  String get patientsContactColumnLabel => 'Contact';

  @override
  String get patientsDobColumnLabel => 'DOB';

  @override
  String get patientsStatusColumnLabel => 'Status';

  @override
  String patientsPageLabel(int from, int to, int total) {
    return '$from-$to of $total';
  }

  @override
  String get patientsPreviousPageLabel => 'Previous patients page';

  @override
  String get patientsNextPageLabel => 'Next patients page';

  @override
  String get patientsEmptyTitle => 'No patients found';

  @override
  String get patientsEmptyBody => 'Adjust the filters or register a patient.';

  @override
  String get patientsDetailTitle => 'Patient details';

  @override
  String get patientsDetailLoadingTitle => 'Loading patient';

  @override
  String get patientsDetailLoadingBody =>
      'Loading demographics and related records.';

  @override
  String get patientsNoSelectionTitle => 'Select a patient';

  @override
  String get patientsNoSelectionBody =>
      'Open a patient to review demographics, contacts, clinical flags, documents, and visits.';

  @override
  String get patientsNameLabel => 'Name';

  @override
  String get patientsIdentifierLabel => 'Identifier';

  @override
  String get patientsDobLabel => 'Date of birth';

  @override
  String get patientsGenderLabel => 'Gender';

  @override
  String get patientsPhoneLabel => 'Phone';

  @override
  String get patientsEmailLabel => 'Email';

  @override
  String get patientsFacilityLabel => 'Facility';

  @override
  String get patientsRegistrationStatusLabel => 'Registration';

  @override
  String get patientsRegistrationIncompleteValue => 'Completion needed';

  @override
  String get patientsFirstNameLabel => 'First name';

  @override
  String get patientsLastNameLabel => 'Last name';

  @override
  String get patientsIdentifierTypeLabel => 'Identifier type';

  @override
  String get patientsIdentifierValueLabel => 'Identifier value';

  @override
  String get patientsActiveCheckboxLabel => 'Patient is active';

  @override
  String get patientsDatePickerAction => 'Select date';

  @override
  String get patientsAddTitle => 'Add patient';

  @override
  String get patientsEmergencyRegisterTitle => 'Emergency registration';

  @override
  String get patientsEmergencyRegisterBody =>
      'Create a minimal patient record now; demographics and documents can be completed after urgent care starts.';

  @override
  String get patientsEmergencyFirstNameLabel => 'Known first name';

  @override
  String get patientsEmergencyLastNameLabel => 'Known last name';

  @override
  String get patientsEmergencySaveAction => 'Register emergency patient';

  @override
  String get patientsEditTitle => 'Edit patient';

  @override
  String get patientsDeleteTitle => 'Delete patient';

  @override
  String patientsDeleteBody(String name) {
    return 'Delete $name from active patient records?';
  }

  @override
  String get patientsGenderMale => 'Male';

  @override
  String get patientsGenderFemale => 'Female';

  @override
  String get patientsGenderOther => 'Other';

  @override
  String get patientsGenderUnknown => 'Unknown';

  @override
  String get patientsQuickActionsTitle => 'Quick actions';

  @override
  String get patientsQuickAppointmentAction => 'Appointment';

  @override
  String get patientsQuickOpdCheckInAction => 'OPD check-in';

  @override
  String get patientsQuickTriageAction => 'Triage';

  @override
  String get patientsQuickClinicalAction => 'Clinical visit';

  @override
  String get patientsQuickBillingAction => 'Billing';

  @override
  String get patientsQuickAdmissionAction => 'Admission';

  @override
  String get patientsQuickReportAction => 'Patient report';

  @override
  String get patientsQuickActionQueuedMessage =>
      'The patient context is ready for the selected workflow.';

  @override
  String get patientsQuickActionSavedMessage => 'Patient workflow updated.';

  @override
  String patientsWorkflowValidationMessage(String fields) {
    return 'Check these fields and try again: $fields.';
  }

  @override
  String get patientsAppointmentDialogTitle => 'Schedule appointment';

  @override
  String get patientsAppointmentDateLabel => 'Appointment date';

  @override
  String get patientsAppointmentTimeLabel => 'Start time';

  @override
  String get patientsAppointmentDurationLabel => 'Duration minutes';

  @override
  String get patientsAppointmentStatusLabel => 'Appointment status';

  @override
  String get patientsAppointmentReasonLabel => 'Reason';

  @override
  String get patientsProviderLabel => 'Provider';

  @override
  String get patientsProviderOptionalHelper => 'Optional provider assignment.';

  @override
  String get patientsWorkflowSectionTitle => 'Workflow';

  @override
  String get patientsArrivalSectionTitle => 'Arrival';

  @override
  String get patientsTriagePrioritySectionTitle => 'Triage priority';

  @override
  String get patientsVitalsSectionTitle => 'Vital signs';

  @override
  String get patientsClinicalAssessmentSectionTitle => 'Assessment';

  @override
  String get patientsBillingSectionTitle => 'Billing details';

  @override
  String get patientsAdmissionClinicalSectionTitle => 'Clinical approval';

  @override
  String get patientsAdmissionLocationSectionTitle => 'Admission location';

  @override
  String get patientsNotesSectionTitle => 'Notes';

  @override
  String get patientsOpdCheckInDialogTitle => 'OPD check-in';

  @override
  String get patientsTriageDialogTitle => 'Triage intake';

  @override
  String get patientsClinicalDialogTitle => 'Clinical visit';

  @override
  String get patientsBillingDialogTitle => 'Consultation billing';

  @override
  String get patientsAdmissionDialogTitle => 'Admit patient';

  @override
  String get patientsArrivalModeLabel => 'Arrival mode';

  @override
  String get patientsEmergencySeverityLabel => 'Emergency severity';

  @override
  String get patientsTriageLevelLabel => 'Triage level';

  @override
  String get patientsSystolicLabel => 'Systolic';

  @override
  String get patientsBloodPressureLabel => 'Blood pressure';

  @override
  String get patientsDiastolicLabel => 'Diastolic';

  @override
  String get patientsTemperatureLabel => 'Temperature';

  @override
  String get patientsHeartRateLabel => 'Heart rate';

  @override
  String get patientsRespiratoryRateLabel => 'Respiratory rate';

  @override
  String get patientsOxygenSaturationLabel => 'Oxygen saturation';

  @override
  String get patientsWeightLabel => 'Weight';

  @override
  String get patientsHeightLabel => 'Height';

  @override
  String get patientsVitalsRequiredMessage =>
      'Enter at least one vital sign before completing triage.';

  @override
  String get patientsVitalUnitLabel => 'Unit';

  @override
  String get patientsVitalNormalLabel => 'Normal';

  @override
  String get patientsVitalAbnormalLabel => 'Abnormal';

  @override
  String get patientsVitalNumberInvalidMessage => 'Enter a valid number.';

  @override
  String patientsVitalRangeSuggestion(String profile, String range) {
    return 'Expected for $profile: $range';
  }

  @override
  String patientsVitalLimitMessage(String range) {
    return 'Enter a value between $range.';
  }

  @override
  String get patientsChiefComplaintLabel => 'Chief complaint';

  @override
  String get patientsClinicalNoteLabel => 'Clinical note';

  @override
  String get patientsDiagnosisLabel => 'Diagnosis';

  @override
  String get patientsConsultationFeeLabel => 'Consultation fee';

  @override
  String get patientsCurrencyLabel => 'Currency';

  @override
  String get patientsMarkPaymentReceivedLabel => 'Payment received';

  @override
  String get patientsPaymentMethodLabel => 'Payment method';

  @override
  String get patientsTransactionReferenceLabel => 'Transaction reference';

  @override
  String get patientsAdmissionReasonLabel => 'Admission reason';

  @override
  String get patientsWardLabel => 'Ward';

  @override
  String get patientsRoomLabel => 'Room';

  @override
  String get patientsBedLabel => 'Bed';

  @override
  String get patientsReportDialogTitle => 'Patient report';

  @override
  String get patientsPrintReportAction => 'Print report';

  @override
  String get patientsAppointmentsSectionTitle => 'Appointments';

  @override
  String get patientsEncountersSectionTitle => 'Encounters';

  @override
  String get patientsAdmissionsSectionTitle => 'Admissions';

  @override
  String get patientsInvoicesSectionTitle => 'Invoices';

  @override
  String get patientsReportSummarySectionTitle => 'Summary';

  @override
  String get patientsReportGeneratedSectionTitle => 'Generated';

  @override
  String get patientsReportPreviewDialogTitle => 'Print preview';

  @override
  String get patientsReportPeriodLabel => 'Report period';

  @override
  String get patientsReportAllDatesOption => 'All dates';

  @override
  String get patientsReportSingleDateOption => 'Single date';

  @override
  String get patientsReportDateRangeOption => 'Date range';

  @override
  String get patientsReportDateLabel => 'Report date';

  @override
  String get patientsReportStartDateLabel => 'Start date';

  @override
  String get patientsReportEndDateLabel => 'End date';

  @override
  String get patientsReportSectionsLabel => 'Report sections';

  @override
  String get patientsReportPreviewSectionTitle => 'Preview';

  @override
  String get patientsReportPatientInfoSectionTitle => 'Patient information';

  @override
  String get patientsReportHospitalInfoSectionTitle => 'Hospital information';

  @override
  String get patientsReportVitalsSectionTitle => 'Vital signs';

  @override
  String get patientsReportPaymentsSectionTitle => 'Payments';

  @override
  String patientsReportPageNumberLabel(int page, int total) {
    return '$page of $total';
  }

  @override
  String get patientsReportNoRecordsForSection =>
      'No records available for the selected period.';

  @override
  String get patientsReportPreparedOnLabel => 'Prepared on';

  @override
  String get patientsReportHospitalNameLabel => 'Hospital name';

  @override
  String get patientsReportHospitalContactLabel => 'Contact information';

  @override
  String get patientsReportHospitalLocationLabel => 'Location';

  @override
  String get patientsReportHospitalAddressLabel => 'Address';

  @override
  String get patientsReportPrintNowAction => 'Print';

  @override
  String get patientsReportDateRangeInvalidMessage =>
      'Start date must be on or before end date.';

  @override
  String get patientsTimeInvalidMessage => 'Enter time as HH:MM.';

  @override
  String get patientsTimeHint => 'HH:MM';

  @override
  String get patientsDurationInvalidMessage =>
      'Enter a duration between 1 and 720 minutes.';

  @override
  String get patientsIdentifiersSectionTitle => 'Identifiers';

  @override
  String get patientsContactsSectionTitle => 'Contacts';

  @override
  String get patientsGuardiansSectionTitle => 'Guardians';

  @override
  String get patientsAllergiesSectionTitle => 'Allergies';

  @override
  String get patientsMedicalHistorySectionTitle => 'Medical history';

  @override
  String get patientsDocumentsSectionTitle => 'Documents';

  @override
  String get patientsConsentsSectionTitle => 'Consents';

  @override
  String get patientsTimelineSectionTitle => 'Timeline';

  @override
  String get patientsNoIdentifiers => 'No identifiers recorded.';

  @override
  String get patientsNoContacts => 'No contacts recorded.';

  @override
  String get patientsNoGuardians => 'No guardians recorded.';

  @override
  String get patientsNoAllergies => 'No allergies recorded.';

  @override
  String get patientsNoMedicalHistory => 'No medical history recorded.';

  @override
  String get patientsNoDocuments => 'No documents recorded.';

  @override
  String get patientsNoConsents => 'No consents recorded.';

  @override
  String get patientsNoTimeline => 'No timeline entries recorded.';

  @override
  String get patientsAddRelatedAction => 'Add record';

  @override
  String get patientsAddRelatedTitle => 'Add patient record';

  @override
  String get patientsEditRelatedTitle => 'Edit patient record';

  @override
  String get patientsRelatedDeleteTitle => 'Delete patient record';

  @override
  String get patientsRelatedDeleteBody => 'Delete this patient record?';

  @override
  String get patientsContactTypeLabel => 'Contact type';

  @override
  String get patientsContactValueLabel => 'Contact value';

  @override
  String get patientsContactInvalidMessage => 'Enter a valid contact value.';

  @override
  String get patientsPrimaryRecordLabel => 'Primary record';

  @override
  String get patientsGuardianNameLabel => 'Guardian name';

  @override
  String get patientsGuardianRelationshipLabel => 'Relationship';

  @override
  String get patientsAllergenLabel => 'Allergen';

  @override
  String get patientsSeverityLabel => 'Severity';

  @override
  String get patientsReactionLabel => 'Reaction';

  @override
  String get patientsNotesLabel => 'Notes';

  @override
  String get patientsConditionLabel => 'Condition';

  @override
  String get patientsDiagnosisDateLabel => 'Diagnosis date';

  @override
  String get patientsDocumentTypeLabel => 'Document type';

  @override
  String get patientsStorageKeyLabel => 'Storage key';

  @override
  String get patientsStorageKeyAdvancedLabel => 'Storage key (advanced)';

  @override
  String get patientsStorageKeyAdvancedHelper =>
      'Upload a file instead. Only enter this when referencing an existing stored document.';

  @override
  String get patientsDocumentUploadTitle => 'Document upload';

  @override
  String get patientsDocumentUploadEmpty =>
      'No file selected. PDF, JPG, and PNG files up to 10 MB are supported.';

  @override
  String get patientsChooseDocumentAction => 'Choose file';

  @override
  String get patientsFileNameLabel => 'File name';

  @override
  String get patientsContentTypeLabel => 'Content type';

  @override
  String get patientsConsentTypeLabel => 'Consent type';

  @override
  String get patientsConsentStatusLabel => 'Consent status';

  @override
  String get patientsConsentDateLabel => 'Consent date';

  @override
  String get patientsDuplicateWarningTitle => 'Potential duplicate found';

  @override
  String get patientsDuplicateWarningBody =>
      'Review the matches before creating another patient record. Continue only when this is a different patient.';

  @override
  String get patientsDuplicateReviewTitle => 'Duplicate review';

  @override
  String get patientsNoDuplicateReviewsTitle => 'No duplicates to review';

  @override
  String get patientsNoDuplicateReviewsBody =>
      'Potential duplicate patient records will appear here.';

  @override
  String get patientsMergePreviewLoadingTitle => 'Loading merge preview';

  @override
  String get patientsMergePreviewLoadingBody =>
      'Checking which records will move to the retained patient.';

  @override
  String patientsDuplicateScoreLabel(int score) {
    return '$score% match';
  }

  @override
  String get patientsReviewMergeAction => 'Review merge';

  @override
  String get patientsDismissDuplicateAction => 'Dismiss';

  @override
  String get patientsMergePreviewTitle => 'Merge preview';

  @override
  String patientsMergeTransferCountLabel(String resource, int count) {
    return '$resource: $count';
  }

  @override
  String get patientsMergePatientsAction => 'Merge patients';

  @override
  String get patientsActivityTitle => 'Registry attention';

  @override
  String get patientsActivityBody =>
      'Patient record issues that may need review.';

  @override
  String get patientsActivityEmptyTitle => 'No registry issues';

  @override
  String get patientsActivityEmptyBody =>
      'No duplicate, consent, or document alerts are visible.';

  @override
  String get patientsDuplicateActivityTitle => 'Possible duplicate';

  @override
  String patientsDuplicateActivitySubtitle(int score) {
    return '$score% match confidence';
  }

  @override
  String get patientsConsentActivityTitle => 'Consent review';

  @override
  String patientsConsentActivitySubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count consents need review',
      one: '1 consent needs review',
    );
    return '$_temp0';
  }

  @override
  String get patientsDocumentsActivityTitle => 'Missing documents';

  @override
  String patientsDocumentsActivitySubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count patients have no documents',
      one: '1 patient has no documents',
    );
    return '$_temp0';
  }

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
  String get profileTitle => 'Profile';

  @override
  String get profileBody => 'Review your account, role, and facility details.';

  @override
  String get profileAccountSectionTitle => 'Account';

  @override
  String get profileAccountSectionBody =>
      'Core identity and login information.';

  @override
  String get profileProfessionalSectionTitle => 'Professional details';

  @override
  String get profileProfessionalSectionBody =>
      'Role, title, user type, and facility context.';

  @override
  String get profileNameLabel => 'Name';

  @override
  String get profileEmailLabel => 'Email';

  @override
  String get profilePhoneLabel => 'Phone';

  @override
  String get profileStatusLabel => 'Status';

  @override
  String get profileTitleLabel => 'Title';

  @override
  String get profileOverallRoleLabel => 'Overall role';

  @override
  String get profileUserTypeLabel => 'User type';

  @override
  String get profileTenantLabel => 'Tenant';

  @override
  String get profileFacilityLabel => 'Facility';

  @override
  String get profileFacilityTypeLabel => 'Facility type';

  @override
  String get profileStaffNumberLabel => 'Staff number';

  @override
  String get profileUserIdLabel => 'User ID';

  @override
  String profilePermissionCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count direct permissions',
      one: '1 direct permission',
      zero: 'No direct permissions',
    );
    return '$_temp0';
  }

  @override
  String get profileUnavailableTitle => 'Profile unavailable';

  @override
  String get profileUnavailableBody =>
      'Sign in again to reload your account details.';

  @override
  String get profileUnknownValue => 'Not available';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsBody => 'Set HOSSPI HMS preferences.';

  @override
  String get settingsPreferencesSectionTitle => 'Preferences';

  @override
  String get settingsPreferencesSectionBody =>
      'Theme, language, and local display choices.';

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
  String get settingsAccountSectionTitle => 'Account and security';

  @override
  String get settingsAccountSectionBody =>
      'Profile and sign-in controls stay with the user account.';

  @override
  String get settingsProfileActionTitle => 'Profile';

  @override
  String get settingsProfileActionBody =>
      'Review identity, role, and facility context.';

  @override
  String get settingsChangePasswordActionTitle => 'Change password';

  @override
  String get settingsChangePasswordActionBody =>
      'Update your password and restart the session.';

  @override
  String get settingsAdministrationSectionTitle => 'Administration boundaries';

  @override
  String get settingsAdministrationSectionBody =>
      'Workspace administration stays in dedicated modules.';

  @override
  String get settingsTenantBoundaryLabel => 'Tenant settings';

  @override
  String get settingsFacilityBoundaryLabel => 'Facility settings';

  @override
  String get settingsSecurityBoundaryLabel => 'User and security settings';

  @override
  String get settingsSecurityBoundaryBody =>
      'Review administrator access before opening user management.';

  @override
  String get settingsTenantFacilitySetupActionTitle =>
      'Tenant and facility setup';

  @override
  String get settingsTenantFacilitySetupActionBody =>
      'Configure organization identity, facility profile, departments, units, and physical locations.';

  @override
  String get tenantFacilitySetupTitle => 'Tenant and facility setup';

  @override
  String get tenantFacilitySetupBody =>
      'Prepare the organization and facility before daily hospital operations begin.';

  @override
  String get tenantFacilitySetupLoadingTitle => 'Loading setup';

  @override
  String get tenantFacilitySetupLoadingBody =>
      'Loading organization and facility configuration.';

  @override
  String get tenantFacilitySummaryConfigured => 'Configured';

  @override
  String get tenantFacilitySummaryNeedsSetup => 'Needs setup';

  @override
  String get tenantFacilitySummaryNoTenant => 'No tenant profile';

  @override
  String get tenantFacilitySummaryNoFacility => 'No facility selected';

  @override
  String tenantFacilitySummaryRecordCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count records',
      one: '1 record',
      zero: 'No records',
    );
    return '$_temp0';
  }

  @override
  String tenantFacilitySummaryDepartmentUnitCount(int departments, int units) {
    String _temp0 = intl.Intl.pluralLogic(
      departments,
      locale: localeName,
      other: '$departments departments',
      one: '1 department',
      zero: 'No departments',
    );
    String _temp1 = intl.Intl.pluralLogic(
      units,
      locale: localeName,
      other: '$units units',
      one: '1 unit',
      zero: 'no units',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String tenantFacilitySummaryLocationCount(int wards, int rooms, int beds) {
    String _temp0 = intl.Intl.pluralLogic(
      wards,
      locale: localeName,
      other: '$wards wards',
      one: '1 ward',
      zero: 'No wards',
    );
    String _temp1 = intl.Intl.pluralLogic(
      rooms,
      locale: localeName,
      other: '$rooms rooms',
      one: '1 room',
      zero: 'no rooms',
    );
    String _temp2 = intl.Intl.pluralLogic(
      beds,
      locale: localeName,
      other: '$beds beds',
      one: '1 bed',
      zero: 'no beds',
    );
    return '$_temp0, $_temp1, $_temp2';
  }

  @override
  String get tenantFacilityChecklistTitle => 'First-run checklist';

  @override
  String tenantFacilityChecklistBody(int completed, int total) {
    return '$completed of $total setup areas complete.';
  }

  @override
  String get tenantFacilityChecklistTenant => 'Tenant profile is configured';

  @override
  String get tenantFacilityChecklistIdentity =>
      'Facility identity and contacts are configured';

  @override
  String get tenantFacilityChecklistDepartments =>
      'Departments and units are configured';

  @override
  String get tenantFacilityChecklistLocations =>
      'Rooms, wards, or beds are configured';

  @override
  String get tenantFacilityPermissionsTitle => 'Permission gates';

  @override
  String get tenantFacilityPermissionsBody =>
      'Write actions require tenant or facility administrator permissions.';

  @override
  String get tenantFacilityTenantAdminPermission => 'Tenant administrator';

  @override
  String get tenantFacilityFacilityAdminPermission => 'Facility administrator';

  @override
  String get tenantFacilityPermissionAllowed => 'Allowed';

  @override
  String get tenantFacilityPermissionDenied => 'Denied';

  @override
  String get tenantFacilityPermissionRequired =>
      'Administrator permission is required for this action.';

  @override
  String get tenantFacilityTenantSectionTitle => 'Tenant profile';

  @override
  String get tenantFacilityTenantSectionBody =>
      'Organization details shared across facilities.';

  @override
  String get tenantFacilityTenantNameLabel => 'Tenant name';

  @override
  String get tenantFacilityTenantSlugLabel => 'Tenant slug';

  @override
  String get tenantFacilityActiveLabel => 'Active';

  @override
  String get tenantFacilitySaveTenantAction => 'Save tenant';

  @override
  String get tenantFacilityFacilitySectionTitle => 'Facility profile';

  @override
  String get tenantFacilityFacilitySectionBody =>
      'Facility name, logo reference, contact details, address, type, and active state.';

  @override
  String get tenantFacilityLogoUrlLabel => 'Logo storage URL';

  @override
  String get tenantFacilityLogoUrlHelper =>
      'Use a URL created by the approved storage service.';

  @override
  String get tenantFacilityAddressLineLabel => 'Address line';

  @override
  String get tenantFacilityCityLabel => 'City';

  @override
  String get tenantFacilityCountryLabel => 'Country';

  @override
  String get tenantFacilitySaveFacilityAction => 'Save facility';

  @override
  String get tenantFacilityFacilitySelectLabel => 'Facility';

  @override
  String get tenantFacilityCreateAction => 'Create';

  @override
  String get tenantFacilitySaveAction => 'Save';

  @override
  String get tenantFacilityEditAction => 'Edit';

  @override
  String get tenantFacilityDeleteAction => 'Delete';

  @override
  String get tenantFacilityDeleteConfirmAction => 'Delete';

  @override
  String get tenantFacilityDeleteConfirmationTitle => 'Delete record';

  @override
  String get tenantFacilityDeleteConfirmationBody =>
      'This setup record will be removed.';

  @override
  String get tenantFacilityNoSelectionLabel => 'None';

  @override
  String get tenantFacilitySearchLabel => 'Search';

  @override
  String get tenantFacilityClearSearchAction => 'Clear search';

  @override
  String get tenantFacilitySearchNoResults => 'No matching records found.';

  @override
  String get tenantFacilityStatusActive => 'Active';

  @override
  String get tenantFacilityStatusInactive => 'Inactive';

  @override
  String get tenantFacilityBranchesSectionTitle => 'Branches';

  @override
  String get tenantFacilityBranchesSectionBody =>
      'Add branch entry points for facilities that operate across sites.';

  @override
  String get tenantFacilityNoBranches => 'No branches have been added.';

  @override
  String get tenantFacilityBranchNameLabel => 'Branch name';

  @override
  String get tenantFacilityBranchesListTitle => 'Branch records';

  @override
  String get tenantFacilityBranchSearchHint =>
      'Search branches by name or status';

  @override
  String get tenantFacilityAddBranchAction => 'Add branch';

  @override
  String get tenantFacilityAddBranchTitle => 'Add branch';

  @override
  String get tenantFacilityEditBranchTitle => 'Edit branch';

  @override
  String get tenantFacilityDepartmentsSectionTitle => 'Departments and units';

  @override
  String get tenantFacilityDepartmentsSectionBody =>
      'Create departments first, then add units under the facility.';

  @override
  String get tenantFacilityNoDepartments => 'No departments have been added.';

  @override
  String get tenantFacilityNoUnits => 'No units have been added.';

  @override
  String get tenantFacilityDepartmentsListTitle => 'Departments';

  @override
  String get tenantFacilityDepartmentsModalBody =>
      'Manage department records for the selected facility.';

  @override
  String get tenantFacilityDepartmentSearchHint =>
      'Search departments by name, type, branch, or status';

  @override
  String get tenantFacilityUnitsListTitle => 'Units';

  @override
  String get tenantFacilityUnitsModalBody =>
      'Manage units under facility departments.';

  @override
  String get tenantFacilityUnitSearchHint =>
      'Search units by name, department, or status';

  @override
  String get tenantFacilityDepartmentNameLabel => 'Department name';

  @override
  String get tenantFacilityDepartmentShortNameLabel => 'Short name';

  @override
  String get tenantFacilityDepartmentTypeLabel => 'Department type';

  @override
  String get tenantFacilityDepartmentBranchLabel => 'Branch';

  @override
  String get tenantFacilityDepartmentTypeClinical => 'Clinical';

  @override
  String get tenantFacilityDepartmentTypeAdministrative => 'Administrative';

  @override
  String get tenantFacilityDepartmentTypeSupport => 'Support';

  @override
  String get tenantFacilityDepartmentTypeDiagnostics => 'Diagnostics';

  @override
  String get tenantFacilityDepartmentTypeOther => 'Other';

  @override
  String get tenantFacilityAddDepartmentAction => 'Add department';

  @override
  String get tenantFacilityAddDepartmentTitle => 'Add department';

  @override
  String get tenantFacilityEditDepartmentTitle => 'Edit department';

  @override
  String get tenantFacilityUnitNameLabel => 'Unit name';

  @override
  String get tenantFacilityUnitDepartmentLabel => 'Department';

  @override
  String get tenantFacilityAddUnitAction => 'Add unit';

  @override
  String get tenantFacilityAddUnitTitle => 'Add unit';

  @override
  String get tenantFacilityEditUnitTitle => 'Edit unit';

  @override
  String get tenantFacilityLocationsSectionTitle => 'Rooms, wards, and beds';

  @override
  String get tenantFacilityLocationsSectionBody =>
      'Use the location setup entry points after facility identity and departments are in place.';

  @override
  String get tenantFacilityRoomsLabel => 'Rooms';

  @override
  String get tenantFacilityWardsLabel => 'Wards';

  @override
  String get tenantFacilityBedsLabel => 'Beds';

  @override
  String get tenantFacilityNoWards => 'No wards have been added.';

  @override
  String get tenantFacilityWardsModalBody =>
      'Manage ward records and department assignments.';

  @override
  String get tenantFacilityWardSearchHint =>
      'Search wards by name, type, department, or status';

  @override
  String get tenantFacilityNoRooms => 'No rooms have been added.';

  @override
  String get tenantFacilityRoomsModalBody =>
      'Manage rooms and their ward assignments.';

  @override
  String get tenantFacilityRoomSearchHint =>
      'Search rooms by name, ward, floor, or status';

  @override
  String get tenantFacilityNoBeds => 'No beds have been added.';

  @override
  String get tenantFacilityBedsModalBody =>
      'Manage bed labels, room links, and availability status.';

  @override
  String get tenantFacilityBedSearchHint =>
      'Search beds by label, ward, room, or status';

  @override
  String get tenantFacilityAddWardAction => 'Add ward';

  @override
  String get tenantFacilityAddWardTitle => 'Add ward';

  @override
  String get tenantFacilityEditWardTitle => 'Edit ward';

  @override
  String get tenantFacilityWardNameLabel => 'Ward name';

  @override
  String get tenantFacilityWardTypeLabel => 'Ward type';

  @override
  String get tenantFacilityWardDepartmentLabel => 'Department';

  @override
  String get tenantFacilityWardTypeGeneral => 'General';

  @override
  String get tenantFacilityWardTypeIcu => 'ICU';

  @override
  String get tenantFacilityWardTypeMaternity => 'Maternity';

  @override
  String get tenantFacilityWardTypePediatric => 'Pediatric';

  @override
  String get tenantFacilityWardTypeSurgical => 'Surgical';

  @override
  String get tenantFacilityWardTypeOther => 'Other';

  @override
  String get tenantFacilityAddRoomAction => 'Add room';

  @override
  String get tenantFacilityAddRoomTitle => 'Add room';

  @override
  String get tenantFacilityEditRoomTitle => 'Edit room';

  @override
  String get tenantFacilityRoomNameLabel => 'Room name';

  @override
  String get tenantFacilityRoomWardLabel => 'Ward';

  @override
  String get tenantFacilityRoomFloorLabel => 'Floor';

  @override
  String get tenantFacilityAddBedAction => 'Add bed';

  @override
  String get tenantFacilityAddBedTitle => 'Add bed';

  @override
  String get tenantFacilityEditBedTitle => 'Edit bed';

  @override
  String get tenantFacilityBedLabelLabel => 'Bed label';

  @override
  String get tenantFacilityBedWardLabel => 'Ward';

  @override
  String get tenantFacilityBedRoomLabel => 'Room';

  @override
  String get tenantFacilityBedStatusLabel => 'Bed status';

  @override
  String get tenantFacilityBedStatusAvailable => 'Available';

  @override
  String get tenantFacilityBedStatusOccupied => 'Occupied';

  @override
  String get tenantFacilityBedStatusReserved => 'Reserved';

  @override
  String get tenantFacilityBedStatusOutOfService => 'Out of service';

  @override
  String get tenantFacilitySavedMessage => 'Setup changes saved.';

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
  String get authAccountNotFoundMessage =>
      'No account exists for that email or phone. Check the details or create an account.';

  @override
  String get authWrongPasswordMessage =>
      'The password is incorrect for this account.';

  @override
  String get authRateLimitedMessage =>
      'Too many sign-in attempts. Please wait a moment and try again.';

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
  String opdFieldRequiredLabel(String label) {
    return '$label (required)';
  }

  @override
  String opdFieldOptionalLabel(String label) {
    return '$label (optional)';
  }

  @override
  String get opdVitalsAtLeastOneRequiredHelper =>
      'Enter at least one vital sign.';

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

  @override
  String get navigationClinicalLabel => 'Clinical';

  @override
  String get clinicalTitle => 'Clinical workspace';

  @override
  String get clinicalDescription =>
      'Review clinical queues, document care, order services, prescribe, refer, admit, and complete encounters.';

  @override
  String get clinicalLoadingTitle => 'Loading clinical workspace';

  @override
  String get clinicalLoadingBody =>
      'Loading provider worklist and encounter context.';

  @override
  String get clinicalLiveStatus => 'Live sync';

  @override
  String get clinicalSavingStatus => 'Saving';

  @override
  String get clinicalSavedMessage => 'Clinical changes saved.';

  @override
  String get clinicalFiltersLabel => 'Clinical filters';

  @override
  String get clinicalSearchLabel => 'Search clinical worklist';

  @override
  String get clinicalSearchHint =>
      'Patient, encounter, queue, provider, or location';

  @override
  String get clinicalScopeFilterLabel => 'Queue scope';

  @override
  String get clinicalTodayScopeLabel => 'Today';

  @override
  String get clinicalWaitingReviewSummaryLabel => 'Waiting review';

  @override
  String get clinicalUrgentSummaryLabel => 'Urgent';

  @override
  String get clinicalResultsReadySummaryLabel => 'Results ready';

  @override
  String get clinicalInConsultationSummaryLabel => 'In consultation';

  @override
  String get clinicalCompletedSummaryLabel => 'Completed';

  @override
  String get clinicalWorklistTitle => 'Provider worklist';

  @override
  String get clinicalWorklistDescription =>
      'Open consultations, admissions, triage handoffs, and result-review queues.';

  @override
  String get clinicalNoWorklistTitle => 'No clinical work';

  @override
  String get clinicalNoWorklistBody =>
      'No encounters match the current search and queue scope.';

  @override
  String get clinicalNoSelectionTitle => 'No encounter selected';

  @override
  String get clinicalNoSelectionBody =>
      'Open a patient from the worklist to review context, document care, and place orders.';

  @override
  String get clinicalSourceQueueLabel => 'Queue';

  @override
  String get clinicalLastUpdatedLabel => 'Last updated';

  @override
  String get clinicalEncounterNumberLabel => 'Encounter';

  @override
  String get clinicalLocationLabel => 'Location';

  @override
  String get clinicalActionsTitle => 'Clinical actions';

  @override
  String get clinicalAddNoteAction => 'Add note';

  @override
  String get clinicalAddDiagnosisAction => 'Add diagnosis';

  @override
  String get clinicalRequestLabAction => 'Request lab';

  @override
  String get clinicalRequestRadiologyAction => 'Request radiology';

  @override
  String get clinicalPrescribeAction => 'Prescribe';

  @override
  String get clinicalRequestProcedureAction => 'Add procedure';

  @override
  String get clinicalCarePlanAction => 'Care plan';

  @override
  String get clinicalRequestAdmissionAction => 'Request admission';

  @override
  String get clinicalCompleteConsultationAction => 'Complete consultation';

  @override
  String get clinicalPrintSummaryAction => 'Print summary';

  @override
  String get clinicalResultReviewTitle => 'Result review';

  @override
  String get clinicalResultReviewBody =>
      'Released diagnostic results are ready for clinical review.';

  @override
  String get clinicalNoResultsReadyBody =>
      'No released lab or radiology results are ready for review.';

  @override
  String get clinicalDiagnosesTitle => 'Diagnoses';

  @override
  String get clinicalCarePlansTitle => 'Care plans';

  @override
  String get clinicalOrdersTitle => 'Orders';

  @override
  String get clinicalHandoffsTitle => 'Handoffs';

  @override
  String get clinicalTermSearchLabel => 'Clinical term';

  @override
  String get clinicalCarePlanLabel => 'Care plan';

  @override
  String get clinicalDoseAmountLabel => 'Dose amount';

  @override
  String get clinicalDoseUnitLabel => 'Dose unit';

  @override
  String get clinicalDurationValueLabel => 'Duration';

  @override
  String get clinicalDurationUnitLabel => 'Duration unit';

  @override
  String get clinicalInstructionsLabel => 'Instructions';

  @override
  String get clinicalAvailableBedLabel => 'Available bed';

  @override
  String get clinicalConsultationSummaryTitle => 'Consultation summary';

  @override
  String get navigationIpdLabel => 'IPD';

  @override
  String get ipdTitle => 'Inpatient workspace';

  @override
  String get ipdDescription =>
      'Manage admission queues, beds, transfers, ward rounds, nursing handoffs, medication records, and discharge readiness.';

  @override
  String get ipdLoadingTitle => 'Loading inpatient workspace';

  @override
  String get ipdLoadingBody => 'Loading admissions, beds, and ward context.';

  @override
  String get ipdLiveStatus => 'Live sync';

  @override
  String get ipdSavingStatus => 'Saving';

  @override
  String get ipdSavedMessage => 'Inpatient changes saved.';

  @override
  String get ipdAdmissionQueueSummaryLabel => 'Waiting bed';

  @override
  String get ipdActivePatientsSummaryLabel => 'In beds';

  @override
  String get ipdTransferPendingSummaryLabel => 'Transfers';

  @override
  String get ipdDischargePlannedSummaryLabel => 'Discharge planned';

  @override
  String get ipdCriticalAlertsSummaryLabel => 'Critical alerts';

  @override
  String get ipdFiltersLabel => 'Inpatient filters';

  @override
  String get ipdSearchLabel => 'Search admissions';

  @override
  String get ipdSearchHint => 'Patient, admission, encounter, ward, or bed';

  @override
  String get ipdScopeFilterLabel => 'Board scope';

  @override
  String get ipdWardFilterLabel => 'Ward';

  @override
  String get ipdAllWardsOption => 'All wards';

  @override
  String get ipdBoardTitle => 'Inpatient board';

  @override
  String get ipdBoardDescription =>
      'Track waiting admissions, bedded patients, transfers, ward activity, and discharge plans.';

  @override
  String get ipdNoAdmissionsTitle => 'No admissions';

  @override
  String get ipdNoAdmissionsBody =>
      'No inpatient admissions match the current filters.';

  @override
  String get ipdLocationColumnLabel => 'Ward and bed';

  @override
  String get ipdPendingActionColumnLabel => 'Next action';

  @override
  String get ipdAdmittedAtColumnLabel => 'Admitted';

  @override
  String get ipdAdmissionDetailTitle => 'Admission detail';

  @override
  String get ipdAdmissionDetailDescription =>
      'Review bed status, transfers, ward rounds, medication records, nursing notes, and discharge state.';

  @override
  String get ipdNoSelectionTitle => 'No admission selected';

  @override
  String get ipdNoSelectionBody =>
      'Open an admission from the board to manage inpatient care.';

  @override
  String get ipdPatientContextLabel => 'Patient context';

  @override
  String get ipdAdmissionIdLabel => 'Admission';

  @override
  String get ipdEncounterIdLabel => 'Encounter';

  @override
  String get ipdWardBedLabel => 'Ward and bed';

  @override
  String get ipdFacilityLabel => 'Facility';

  @override
  String get ipdIcuStatusLabel => 'ICU status';

  @override
  String get ipdAssignBedAction => 'Assign bed';

  @override
  String get ipdReleaseBedAction => 'Release bed';

  @override
  String get ipdRejectAdmissionAction => 'Reject admission';

  @override
  String get ipdRequestTransferAction => 'Request transfer';

  @override
  String get ipdManageTransferAction => 'Manage transfer';

  @override
  String get ipdAddWardRoundAction => 'Add ward round';

  @override
  String get ipdAddNursingNoteAction => 'Add nursing note';

  @override
  String get ipdRecordMedicationAction => 'Record medication';

  @override
  String get ipdPlanDischargeAction => 'Plan discharge';

  @override
  String get ipdFinalizeDischargeAction => 'Finalize discharge';

  @override
  String get ipdTransfersSectionTitle => 'Transfers';

  @override
  String get ipdRoundsSectionTitle => 'Ward rounds';

  @override
  String get ipdNursingSectionTitle => 'Nursing notes';

  @override
  String get ipdMedicationSectionTitle => 'Medication';

  @override
  String get ipdBedSectionTitle => 'Bed allocation';

  @override
  String get ipdDischargeSectionTitle => 'Discharge';

  @override
  String get ipdTimelineSectionTitle => 'Timeline';

  @override
  String get ipdNoTransfersTitle => 'No transfers';

  @override
  String get ipdNoTransfersBody =>
      'No transfer requests are recorded for this admission.';

  @override
  String get ipdNoRoundsTitle => 'No ward rounds';

  @override
  String get ipdNoRoundsBody => 'No ward rounds have been documented yet.';

  @override
  String get ipdNoNursingNotesTitle => 'No nursing notes';

  @override
  String get ipdNoNursingNotesBody =>
      'No nursing notes have been documented yet.';

  @override
  String get ipdNoMedicationTitle => 'No medication records';

  @override
  String get ipdNoMedicationBody =>
      'No medication administrations are recorded for this admission.';

  @override
  String get ipdNoTimelineTitle => 'No timeline entries';

  @override
  String get ipdNoTimelineBody => 'No care activity has been recorded yet.';

  @override
  String get ipdBedFieldLabel => 'Bed';

  @override
  String get ipdSelectBedHint => 'Select a bed';

  @override
  String get ipdReleaseBedConfirmationBody =>
      'Release the current bed assignment for this admission?';

  @override
  String get ipdTargetWardFieldLabel => 'Target ward';

  @override
  String get ipdSelectWardHint => 'Select a ward';

  @override
  String get ipdTransferActionFieldLabel => 'Transfer action';

  @override
  String get ipdDestinationBedFieldLabel => 'Destination bed';

  @override
  String get ipdNotesFieldLabel => 'Notes';

  @override
  String get ipdSummaryFieldLabel => 'Summary';

  @override
  String get ipdReasonFieldLabel => 'Reason';

  @override
  String get ipdMedicationOrderFieldLabel => 'Medication order';

  @override
  String get ipdMedicationOrderHint => 'Select a suggested order';

  @override
  String get ipdMedicationFieldLabel => 'Medication';

  @override
  String get ipdDoseFieldLabel => 'Dose';

  @override
  String get ipdUnitFieldLabel => 'Unit';

  @override
  String get ipdRouteFieldLabel => 'Route';

  @override
  String get ipdFrequencyFieldLabel => 'Frequency';

  @override
  String get ipdMedicationStatusFieldLabel => 'Status';

  @override
  String get ipdDischargedAtLabel => 'Discharged';

  @override
  String get ipdScopeAdmissionQueue => 'Waiting bed';

  @override
  String get ipdScopeActivePatients => 'In beds';

  @override
  String get ipdScopeTransferPending => 'Transfers';

  @override
  String get ipdScopeDischargePlanned => 'Discharge planned';

  @override
  String get ipdScopeAwaitingClearance => 'Awaiting clearance';

  @override
  String get ipdScopeDischarged => 'Discharged';

  @override
  String get ipdScopeAll => 'All admissions';

  @override
  String get ipdStatusAdmittedPendingBed => 'Waiting bed';

  @override
  String get ipdStatusAdmittedInBed => 'In bed';

  @override
  String get ipdStatusTransferRequested => 'Transfer requested';

  @override
  String get ipdStatusTransferInProgress => 'Transfer in progress';

  @override
  String get ipdStatusDischargePlanned => 'Discharge planned';

  @override
  String get ipdStatusDischarged => 'Discharged';

  @override
  String get ipdStatusCancelled => 'Cancelled';

  @override
  String get ipdNextAssignBed => 'Assign bed';

  @override
  String get ipdNextRecordNursingNote => 'Record nursing note';

  @override
  String get ipdNextApproveTransfer => 'Approve transfer';

  @override
  String get ipdNextStartTransfer => 'Start transfer';

  @override
  String get ipdNextCompleteTransfer => 'Complete transfer';

  @override
  String get ipdNextFinalizeDischarge => 'Finalize discharge';

  @override
  String get ipdNextContinueCare => 'Continue care';

  @override
  String get ipdBedStatusAvailable => 'Available';

  @override
  String get ipdBedStatusOccupied => 'Occupied';

  @override
  String get ipdBedStatusReserved => 'Reserved';

  @override
  String get ipdBedStatusOutOfService => 'Out of service';

  @override
  String get ipdDischargeStatusPlanned => 'Planned';

  @override
  String get ipdDischargeStatusCompleted => 'Completed';

  @override
  String get ipdIcuStatusActive => 'Active';

  @override
  String get ipdIcuStatusEnded => 'Ended';

  @override
  String get ipdIcuStatusNone => 'No ICU stay';

  @override
  String get ipdCriticalAlertLabel => 'Critical alert';

  @override
  String ipdCriticalSeverityLabel(String severity) {
    return 'Critical: $severity';
  }

  @override
  String get ipdTimelineWardRound => 'Ward round';

  @override
  String get ipdTimelineNursingNote => 'Nursing note';

  @override
  String get ipdTimelineMedication => 'Medication';

  @override
  String get ipdTimelineMedicationReminder => 'Medication reminder';

  @override
  String get ipdTimelineTransfer => 'Transfer';

  @override
  String get ipdTimelineIcuObservation => 'ICU observation';

  @override
  String get ipdTimelineCriticalAlert => 'Critical alert';

  @override
  String get ipdTimelineCareEvent => 'Care event';

  @override
  String get ipdTransferApproveAction => 'Approve';

  @override
  String get ipdTransferStartAction => 'Start transfer';

  @override
  String get ipdTransferCompleteAction => 'Complete transfer';

  @override
  String get ipdTransferCancelAction => 'Cancel transfer';

  @override
  String get ipdRouteOral => 'Oral';

  @override
  String get ipdRouteIv => 'IV';

  @override
  String get ipdRouteIm => 'IM';

  @override
  String get ipdRouteTopical => 'Topical';

  @override
  String get ipdRouteInhalation => 'Inhalation';

  @override
  String get ipdRouteOther => 'Other';

  @override
  String get ipdFrequencyOnce => 'Once';

  @override
  String get ipdFrequencyBid => 'BID';

  @override
  String get ipdFrequencyTid => 'TID';

  @override
  String get ipdFrequencyQid => 'QID';

  @override
  String get ipdFrequencyPrn => 'PRN';

  @override
  String get ipdFrequencyStat => 'STAT';

  @override
  String get ipdFrequencyCustom => 'Custom';

  @override
  String get ipdMedicationGiven => 'Given';

  @override
  String get ipdMedicationMissed => 'Missed';

  @override
  String get ipdMedicationDelayed => 'Delayed';

  @override
  String get ipdMedicationRefused => 'Refused';
}
