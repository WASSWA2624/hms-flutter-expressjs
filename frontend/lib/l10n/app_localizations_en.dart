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
  String get appTimePickerAction => 'Select time';

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
  String get opdSearchFieldFilterLabel => 'Search in';

  @override
  String get opdAllFieldsFilterLabel => 'All fields';

  @override
  String get opdArrivalDateFilterLabel => 'Arrival date';

  @override
  String get opdDateFromLabel => 'From';

  @override
  String get opdDateToLabel => 'To';

  @override
  String get opdDatePickerButtonLabel => 'Choose date';

  @override
  String get opdInvalidDateMessage => 'Enter a valid date.';

  @override
  String get opdArrivalRangeFilterLabel => 'Arrival range';

  @override
  String get opdAnyArrivalDateOption => 'Any arrival date';

  @override
  String get opdDatePresetToday => 'Today';

  @override
  String get opdDatePresetYesterday => 'Yesterday';

  @override
  String get opdDatePresetLast7Days => 'Last 7 days';

  @override
  String get opdDatePresetLast30Days => 'Last 30 days';

  @override
  String get opdCategoryFilterLabel => 'Category';

  @override
  String get opdStatusFilterLabel => 'Status';

  @override
  String get opdVisitTypeFilterLabel => 'Visit type';

  @override
  String get opdQueueFilterLabel => 'Queue';

  @override
  String get opdProviderFilterLabel => 'Provider';

  @override
  String get opdBillingFilterLabel => 'Billing';

  @override
  String get opdNextActionFilterLabel => 'Next action';

  @override
  String get opdAllCategoriesOption => 'All categories';

  @override
  String get opdAllStatusesOption => 'All statuses';

  @override
  String get opdAllVisitTypesOption => 'All visit types';

  @override
  String get opdAllQueuesOption => 'All queues';

  @override
  String get opdAllProvidersOption => 'All providers';

  @override
  String get opdAllBillingStatesOption => 'All billing states';

  @override
  String get opdAllNextActionsOption => 'All next actions';

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
  String get opdVisitTypeColumnLabel => 'Visit type';

  @override
  String get opdQueueStatusColumnLabel => 'Queue / status';

  @override
  String get opdTimeColumnLabel => 'Arrival time';

  @override
  String get opdWaitingTimeColumnLabel => 'Wait time';

  @override
  String get opdProviderColumnLabel => 'Provider';

  @override
  String get opdPayerBillingColumnLabel => 'Payer / billing';

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
  String get opdEditVitalsAction => 'Edit vitals';

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
  String get patientsPatientNumberColumnLabel => 'Patient no.';

  @override
  String get patientsAgeSexColumnLabel => 'Age / sex';

  @override
  String get patientsPhoneIdentifierColumnLabel => 'Phone / ID';

  @override
  String get patientsAlertColumnLabel => 'Alerts';

  @override
  String get patientsVisitColumnLabel => 'Visit';

  @override
  String get patientsNextActionColumnLabel => 'Next action';

  @override
  String get patientsIdentifierColumnLabel => 'Identifier';

  @override
  String get patientsContactColumnLabel => 'Contact';

  @override
  String get patientsDobColumnLabel => 'DOB';

  @override
  String get patientsStatusColumnLabel => 'Status';

  @override
  String get patientsNoAlertsLabel => 'No alerts';

  @override
  String get patientsAllergyAlertLabel => 'Allergy';

  @override
  String get patientsNoVisitLabel => 'No visit';

  @override
  String get patientsCompleteRecordAction => 'Complete record';

  @override
  String get patientsOpenRecordAction => 'Open record';

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
    return 'Page $page of $total';
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

  @override
  String get navigationNursingLabel => 'Nursing';

  @override
  String get nursingTitle => 'Nursing';

  @override
  String get nursingDescription =>
      'Monitor ward queues, observations, medication administration, handovers, transfers, and escalation.';

  @override
  String get nursingLoadingTitle => 'Loading nursing workspace';

  @override
  String get nursingLoadingBody =>
      'Loading ward patients, observations, medications, and handovers.';

  @override
  String get nursingLiveStatus => 'Live sync';

  @override
  String get nursingSavingStatus => 'Saving';

  @override
  String get nursingSavedMessage => 'Nursing changes saved.';

  @override
  String get nursingAssignedWardSummaryLabel => 'Assigned ward';

  @override
  String get nursingUrgentSummaryLabel => 'Urgent';

  @override
  String get nursingMedicationDueSummaryLabel => 'Medication due';

  @override
  String get nursingHandoverPendingSummaryLabel => 'Handover pending';

  @override
  String get nursingTransferPendingSummaryLabel => 'Transfer pending';

  @override
  String get nursingDischargePendingSummaryLabel => 'Discharge pending';

  @override
  String get nursingFiltersLabel => 'Nursing filters';

  @override
  String get nursingSearchLabel => 'Search nursing worklist';

  @override
  String get nursingSearchHint =>
      'Patient, admission, encounter, ward, bed, or observation';

  @override
  String get nursingScopeFilterLabel => 'Queue scope';

  @override
  String get nursingWardFilterLabel => 'Ward or bed';

  @override
  String get nursingWardFilterHint => 'Filter by ward or bed';

  @override
  String get nursingScopeAssignedWardLabel => 'Assigned ward';

  @override
  String get nursingScopeUrgentLabel => 'Urgent';

  @override
  String get nursingScopeMedicationDueLabel => 'Medication due';

  @override
  String get nursingScopeHandoverPendingLabel => 'Handover pending';

  @override
  String get nursingScopeTransferPendingLabel => 'Transfer pending';

  @override
  String get nursingScopeDischargePendingLabel => 'Discharge pending';

  @override
  String get nursingScopeAllLabel => 'All';

  @override
  String get nursingWorklistTitle => 'Ward worklist';

  @override
  String get nursingWorklistDescription =>
      'Patients needing observations, medication, handover, transfer, or discharge coordination.';

  @override
  String get nursingNoWorklistTitle => 'No nursing work';

  @override
  String get nursingNoWorklistBody =>
      'No ward patients match the current search and queue scope.';

  @override
  String get nursingNoSelectionTitle => 'No ward patient selected';

  @override
  String get nursingNoSelectionBody =>
      'Open a patient from the worklist to review observations, medications, handovers, and ward activity.';

  @override
  String get nursingPatientContextLabel => 'Selected nursing patient context';

  @override
  String get nursingLocationColumnLabel => 'Location';

  @override
  String get nursingDueActionColumnLabel => 'Due action';

  @override
  String get nursingLastObservationColumnLabel => 'Last observation';

  @override
  String get nursingAdmissionLabel => 'Admission';

  @override
  String get nursingEncounterLabel => 'Encounter';

  @override
  String get nursingLocationLabel => 'Location';

  @override
  String get nursingFacilityLabel => 'Facility';

  @override
  String get nursingIcuLabel => 'ICU';

  @override
  String get nursingBedLabel => 'Bed';

  @override
  String get nursingActionsTitle => 'Nursing actions';

  @override
  String get nursingActionRecordVitals => 'Record vitals';

  @override
  String get nursingActionAddNote => 'Add note';

  @override
  String get nursingActionAdministerMedication => 'Administer medication';

  @override
  String get nursingActionCompleteTask => 'Complete task';

  @override
  String get nursingActionCreateHandover => 'Create handover';

  @override
  String get nursingActionEscalate => 'Escalate';

  @override
  String get nursingActionAcknowledgeTransfer => 'Acknowledge transfer';

  @override
  String get nursingActionAcceptHandover => 'Accept handover';

  @override
  String get nursingObservationsTitle => 'Observations';

  @override
  String get nursingMedicationsTitle => 'Medications';

  @override
  String get nursingNotesTitle => 'Nursing notes';

  @override
  String get nursingCarePlansTitle => 'Care plans';

  @override
  String get nursingHandoversTitle => 'Handovers';

  @override
  String get nursingWardActivityTitle => 'Ward activity';

  @override
  String get nursingNoRecordsLabel => 'No records yet';

  @override
  String get nursingVitalsTypeLabel => 'Vital type';

  @override
  String get nursingVitalValueLabel => 'Value';

  @override
  String get nursingVitalUnitLabel => 'Unit';

  @override
  String get nursingSystolicLabel => 'Systolic';

  @override
  String get nursingDiastolicLabel => 'Diastolic';

  @override
  String get nursingMapLabel => 'MAP';

  @override
  String get nursingRecordedAtLabel => 'Recorded at';

  @override
  String get nursingAdministeredAtLabel => 'Administered at';

  @override
  String get nursingDateTimeHint => 'YYYY-MM-DDTHH:mm:ssZ';

  @override
  String get nursingNoteLabel => 'Note';

  @override
  String get nursingTaskLabel => 'Task';

  @override
  String get nursingMedicationLabel => 'Medication';

  @override
  String get nursingDoseLabel => 'Dose';

  @override
  String get nursingRouteLabel => 'Route';

  @override
  String get nursingAdministrationStatusLabel => 'Administration status';

  @override
  String get nursingFrequencyLabel => 'Frequency';

  @override
  String get nursingAdministrationNoteLabel => 'Administration note';

  @override
  String get nursingScheduleRemindersLabel => 'Schedule reminders';

  @override
  String get nursingConfirmMedicationLabel =>
      'Confirm medication administration';

  @override
  String get nursingConfirmMedicationSubtitle =>
      'Verify the patient, medication, dose, route, and time before saving.';

  @override
  String get nursingHandoverToUserLabel => 'To user ID';

  @override
  String get nursingHandoverNotesLabel => 'Handover notes';

  @override
  String get nursingEscalationMessageLabel => 'Escalation message';

  @override
  String get nursingConfirmEscalationLabel => 'Confirm escalation';

  @override
  String get nursingTransferActionLabel => 'Transfer action';

  @override
  String get nursingToBedLabel => 'To bed ID';

  @override
  String get nursingConfirmTransferLabel => 'Confirm transfer update';

  @override
  String get navigationDischargeLabel => 'Discharge';

  @override
  String get dischargeWorkspaceTitle => 'Discharge workspace';

  @override
  String get dischargeWorkspaceDescription =>
      'Coordinate discharge plans, clearances, medicines, final billing, documents, and bed release.';

  @override
  String get dischargeOperationalStatusLabel => 'Discharge desk active';

  @override
  String get dischargePlannedSummaryLabel => 'Planned';

  @override
  String get dischargeSummaryPendingSummaryLabel => 'Summary pending';

  @override
  String get dischargeDocumentsReadySummaryLabel => 'Documents ready';

  @override
  String get dischargeCompletedSummaryLabel => 'Completed';

  @override
  String get dischargeQueueSearchLabel => 'Search discharge queue';

  @override
  String get dischargeQueueSearchHint => 'Search patient, admission, or ward';

  @override
  String get dischargeStatusFilterLabel => 'Discharge status';

  @override
  String get dischargeStatusAll => 'All discharges';

  @override
  String get dischargeStatusPlanned => 'Planned';

  @override
  String get dischargeStatusSummaryPending => 'Summary pending';

  @override
  String get dischargeStatusPharmacyPending => 'Pharmacy pending';

  @override
  String get dischargeStatusNursingPending => 'Nursing pending';

  @override
  String get dischargeStatusBillingPending => 'Billing pending';

  @override
  String get dischargeStatusInsurancePending => 'Insurance pending';

  @override
  String get dischargeStatusDocumentsReady => 'Documents ready';

  @override
  String get dischargeStatusCompleted => 'Completed';

  @override
  String get dischargeWorklistTitle => 'Discharge worklist';

  @override
  String get dischargeWorklistDescription =>
      'Patients with a discharge plan, pending clearance, or recent completion.';

  @override
  String get dischargePreviousPageLabel => 'Previous discharges';

  @override
  String get dischargeNextPageLabel => 'Next discharges';

  @override
  String dischargePageLabel(int from, int to, int total) {
    return '$from-$to of $total';
  }

  @override
  String get dischargeEmptyQueueTitle => 'No discharges in this view';

  @override
  String get dischargeEmptyQueueBody =>
      'Adjust the status filter or search term to find discharge work.';

  @override
  String get dischargePatientColumnLabel => 'Patient';

  @override
  String get dischargeLocationColumnLabel => 'Ward and bed';

  @override
  String get dischargeStatusColumnLabel => 'Status';

  @override
  String get dischargeNextActionColumnLabel => 'Next action';

  @override
  String get dischargeTargetColumnLabel => 'Target';

  @override
  String get dischargeDetailTitle => 'Discharge detail';

  @override
  String get dischargeDetailLoadingTitle => 'Loading discharge detail';

  @override
  String get dischargeDetailLoadingBody =>
      'Loading patient context, clearance, medicines, billing, and documents.';

  @override
  String get dischargeNoSelectionTitle => 'Select a discharge';

  @override
  String get dischargeNoSelectionBody =>
      'Choose a patient from the worklist to coordinate discharge.';

  @override
  String get dischargePrintSummaryAction => 'Print discharge summary';

  @override
  String get dischargePatientContextLabel => 'Patient discharge context';

  @override
  String get dischargeAdmissionFieldLabel => 'Admission';

  @override
  String get dischargeEncounterFieldLabel => 'Encounter';

  @override
  String get dischargeLocationFieldLabel => 'Location';

  @override
  String get dischargeTargetFieldLabel => 'Target discharge';

  @override
  String get dischargeStartPlanAction => 'Start discharge plan';

  @override
  String get dischargeEditSummaryAction => 'Edit summary';

  @override
  String get dischargeRequestBillingAction => 'Request final billing';

  @override
  String get dischargeRequestPharmacyAction => 'Request medicines';

  @override
  String get dischargeCompleteAction => 'Complete discharge';

  @override
  String get dischargeChecklistTitle => 'Clearance checklist';

  @override
  String get dischargeChecklistBody =>
      'Track clinical, nursing, pharmacy, billing, documents, and bed release readiness.';

  @override
  String get dischargeClearanceComplete => 'Complete';

  @override
  String get dischargeClearancePending => 'Pending';

  @override
  String get dischargeClearanceBackendGap => 'Backend gap';

  @override
  String get dischargeClearanceUnavailable => 'Unavailable';

  @override
  String get dischargeClearanceDoctor => 'Doctor summary';

  @override
  String get dischargeClearanceNursing => 'Nursing handover';

  @override
  String get dischargeClearancePharmacy => 'Pharmacy medicines';

  @override
  String get dischargeClearanceBilling => 'Final billing';

  @override
  String get dischargeClearanceInsurance => 'Insurance clearance';

  @override
  String get dischargeClearanceDocuments => 'Documents';

  @override
  String get dischargeClearanceBedRelease => 'Bed release';

  @override
  String get dischargeClearanceHousekeeping => 'Housekeeping';

  @override
  String get dischargeSummarySectionTitle => 'Clinical summary';

  @override
  String get dischargeSummarySectionBody =>
      'Capture diagnosis, treatment, medicines, advice, follow-up, warnings, and signature context.';

  @override
  String get dischargeEmptySummaryTitle => 'No summary recorded';

  @override
  String get dischargeEmptySummaryBody =>
      'Start a discharge plan to prepare the printable summary.';

  @override
  String get dischargeGeneratedDocumentsTitle => 'Generated document preview';

  @override
  String get dischargeMedicinesSectionTitle => 'Discharge medicines';

  @override
  String get dischargeNoMedicinesBody =>
      'No discharge medicine orders are linked to this admission.';

  @override
  String get dischargePharmacyUnavailableBody =>
      'Pharmacy orders could not be loaded. Refresh before completing discharge.';

  @override
  String get dischargeBillingSectionTitle => 'Billing clearance';

  @override
  String get dischargeNoInvoicesBody =>
      'No final invoices are linked to this admission.';

  @override
  String get dischargeBillingUnavailableBody =>
      'Billing records could not be loaded. Refresh before completing discharge.';

  @override
  String get dischargeNoRecordsTitle => 'No records';

  @override
  String get dischargeTimelineSectionTitle => 'Admission timeline';

  @override
  String get dischargeNoTimelineTitle => 'No timeline activity';

  @override
  String get dischargeNoTimelineBody =>
      'Admission timeline events will appear after activity is recorded.';

  @override
  String get dischargeBackendGapsTitle => 'Backend gaps';

  @override
  String get dischargeBackendGapsBody =>
      'These workflow actions are shown as gaps because no confirmed backend contract exists yet.';

  @override
  String get dischargeGapBackendSubtitle => 'Backend endpoint required';

  @override
  String get dischargeGapChecklistTitle => 'Persistent clearance checklist';

  @override
  String get dischargeGapChecklistBody =>
      'No confirmed endpoint persists individual doctor, nursing, pharmacy, billing, document, or exit checklist decisions.';

  @override
  String get dischargeGapInsuranceTitle => 'Insurance clearance workflow';

  @override
  String get dischargeGapInsuranceBody =>
      'No confirmed insurance clearance endpoint is tied to the discharge workflow.';

  @override
  String get dischargeGapDocumentsTitle => 'Document ready state';

  @override
  String get dischargeGapDocumentsBody =>
      'Discharge documents can be generated from the summary, but no confirmed endpoint marks handover documents ready.';

  @override
  String get dischargeGapHousekeepingTitle => 'Housekeeping task handoff';

  @override
  String get dischargeGapHousekeepingBody =>
      'Final discharge releases the bed, but no confirmed atomic housekeeping task creation is part of that workflow.';

  @override
  String get dischargePlanDialogTitle => 'Discharge plan';

  @override
  String get dischargePlanDialogBody =>
      'Prepare the clinical discharge summary and target discharge date.';

  @override
  String get dischargeSummaryFieldLabel => 'Discharge summary';

  @override
  String get dischargeSummaryHelperText =>
      'Include diagnosis, treatment, medicines, advice, follow-up, warning signs, and signature context.';

  @override
  String get dischargeSummaryRequiredMessage => 'Enter the discharge summary.';

  @override
  String get dischargeTargetDateLabel => 'Target discharge date';

  @override
  String get dischargeDatePickerLabel => 'Choose date';

  @override
  String get dischargeInvalidDateMessage => 'Enter a valid discharge date.';

  @override
  String get dischargeSavePlanAction => 'Save plan';

  @override
  String get dischargeBillingDialogTitle => 'Final billing request';

  @override
  String get dischargeBillingDialogBody =>
      'Create a final invoice request for billing clearance.';

  @override
  String get dischargeBillingAmountLabel => 'Amount';

  @override
  String get dischargeBillingAmountRequiredMessage =>
      'Enter the final billing amount.';

  @override
  String get dischargeBillingCurrencyLabel => 'Currency';

  @override
  String get dischargeBillingCurrencyRequiredMessage =>
      'Enter the billing currency.';

  @override
  String get dischargeRequestBillingSubmitAction => 'Create invoice request';

  @override
  String get dischargePharmacyDialogTitle => 'Discharge medicines';

  @override
  String get dischargePharmacyDialogBody =>
      'Send discharge medicines to pharmacy using the confirmed order route.';

  @override
  String get dischargeDrugFieldLabel => 'Medicine';

  @override
  String get dischargeDrugRequiredMessage => 'Select a medicine.';

  @override
  String get dischargePrescriptionFieldLabel => 'Prescription';

  @override
  String get dischargePrescriptionHelperText =>
      'State dose, duration, and any patient instructions.';

  @override
  String get dischargePrescriptionRequiredMessage =>
      'Enter the discharge prescription.';

  @override
  String get dischargeQuantityFieldLabel => 'Quantity';

  @override
  String get dischargeMedicationRouteLabel => 'Route';

  @override
  String get dischargeMedicationFrequencyLabel => 'Frequency';

  @override
  String get dischargeMedicineInstructionsLabel => 'Instructions';

  @override
  String get dischargeRequestPharmacySubmitAction => 'Send to pharmacy';

  @override
  String get dischargeCompleteDialogTitle => 'Complete discharge';

  @override
  String get dischargeCompleteDialogBody =>
      'Confirm the patient exit only after required clinical, nursing, pharmacy, billing, and document checks are complete.';

  @override
  String get dischargeCompletionBlockersTitle => 'Clearance still pending';

  @override
  String get dischargeCompletionBlockersBody =>
      'Resolve pending or unavailable clearance items before finalizing the admission.';

  @override
  String get dischargeCompleteConfirmLabel =>
      'I confirm the patient has exited and documents were handed over.';

  @override
  String get dischargeCompleteConfirmRequiredMessage =>
      'Confirm patient exit before completing discharge.';

  @override
  String get dischargeCompleteSubmitAction => 'Finalize discharge';

  @override
  String get dischargeNextActionCompleted => 'Discharge completed';

  @override
  String get dischargeNextActionClearance => 'Clear pending items';

  @override
  String get dischargeNextActionStartPlan => 'Start summary';

  @override
  String dischargePatientAgeSexLabel(String age, String sex) {
    return '$age / $sex';
  }

  @override
  String get dischargeSavedMessage => 'Discharge workflow updated.';

  @override
  String get dischargeReportTitle => 'Discharge summary';

  @override
  String get dischargeReportPatientLabel => 'Patient';

  @override
  String get dischargeReportPatientNoLabel => 'Patient number';

  @override
  String get dischargeReportAdmissionLabel => 'Admission';

  @override
  String get dischargeReportLocationLabel => 'Location';

  @override
  String get dischargeReportGeneratedLabel => 'Generated';

  @override
  String get dischargeDoctorSignatureLabel => 'Doctor signature';

  @override
  String get dischargeNurseSignatureLabel => 'Nurse signature';

  @override
  String get dischargeReportFooter =>
      'Generated from confirmed discharge workflow data.';

  @override
  String get dischargeLoadingTitle => 'Loading discharge workspace';

  @override
  String get dischargeLoadingBody =>
      'Loading discharge queue and reference data.';

  @override
  String get dischargeLoadErrorTitle => 'Discharge workspace unavailable';

  @override
  String get dischargeLoadErrorBody =>
      'The discharge queue could not be loaded. Refresh to try again.';

  @override
  String get radiologyTitle => 'Radiology';

  @override
  String get radiologyDescription =>
      'Manage imaging requests, modality worklists, study capture, PACS links, reporting, and release.';

  @override
  String get radiologyLoadingTitle => 'Loading radiology workspace';

  @override
  String get radiologyLoadingBody =>
      'Loading imaging orders, reports, studies, and reference data.';

  @override
  String get radiologyLiveStatus => 'Live sync';

  @override
  String get radiologySavingStatus => 'Saving';

  @override
  String get radiologySavedMessage => 'Radiology workflow updated.';

  @override
  String get radiologyRequestImagingAction => 'Request imaging';

  @override
  String get radiologyRefreshCatalogAction => 'Refresh catalog';

  @override
  String get radiologyTotalOrdersSummaryLabel => 'Total orders';

  @override
  String get radiologyWaitingImagingSummaryLabel => 'Waiting imaging';

  @override
  String get radiologyReportingSummaryLabel => 'Reporting';

  @override
  String get radiologyReleasedSummaryLabel => 'Released';

  @override
  String get radiologyUnsyncedSummaryLabel => 'PACS sync due';

  @override
  String get radiologyFiltersLabel => 'Radiology filters';

  @override
  String get radiologySearchLabel => 'Search radiology';

  @override
  String get radiologySearchHint =>
      'Search patient, order, encounter, study, report, or PACS text';

  @override
  String get radiologyOrderDateFilterLabel => 'Order date';

  @override
  String get radiologyPickOrderDateAction => 'Pick order date';

  @override
  String get radiologyStageFilterLabel => 'Stage';

  @override
  String get radiologyStatusFilterLabel => 'Status';

  @override
  String get radiologyModalityFilterLabel => 'Modality';

  @override
  String get radiologyClearFiltersAction => 'Clear filters';

  @override
  String get radiologyWorklistTitle => 'Imaging worklist';

  @override
  String get radiologyWorklistDescription =>
      'Backend-backed imaging orders with modality workflow and report status.';

  @override
  String get radiologyPreviousPageLabel => 'Previous orders';

  @override
  String get radiologyNextPageLabel => 'Next orders';

  @override
  String radiologyPageLabel(int from, int to, int total) {
    return 'Showing $from-$to of $total';
  }

  @override
  String get radiologyNoOrdersTitle => 'No radiology orders';

  @override
  String get radiologyNoOrdersBody =>
      'Orders matching this search and filter will appear here.';

  @override
  String get radiologyPatientColumnLabel => 'Patient';

  @override
  String get radiologyOrderColumnLabel => 'Order';

  @override
  String get radiologyStudyColumnLabel => 'Study';

  @override
  String get radiologyPriorityColumnLabel => 'Priority';

  @override
  String get radiologyPaymentAuthColumnLabel => 'Billing';

  @override
  String get radiologyStatusColumnLabel => 'Status';

  @override
  String get radiologyNextActionColumnLabel => 'Next action';

  @override
  String get radiologyDetailTitle => 'Radiology workflow';

  @override
  String get radiologyDetailLoadingTitle => 'Loading order';

  @override
  String get radiologyDetailLoadingBody => 'Loading selected imaging workflow.';

  @override
  String get radiologyNoSelectionTitle => 'Select an order';

  @override
  String get radiologyNoSelectionBody =>
      'Choose an imaging request to view study, report, and release details.';

  @override
  String get radiologyPatientContextLabel => 'Radiology patient context';

  @override
  String get radiologyBillingGateUnavailable => 'Billing gate unavailable';

  @override
  String get radiologyEncounterLabel => 'Encounter';

  @override
  String get radiologyOrderedAtLabel => 'Ordered';

  @override
  String get radiologyModalityLabel => 'Modality';

  @override
  String get radiologyPaymentLabel => 'Payment';

  @override
  String get radiologyAuthorizationLabel => 'Authorization';

  @override
  String get radiologyAssignAction => 'Assign';

  @override
  String get radiologyStartImagingAction => 'Start imaging';

  @override
  String get radiologyStartDialogTitle => 'Start imaging order';

  @override
  String get radiologyNotesLabel => 'Notes';

  @override
  String get radiologyPerformStudyAction => 'Perform study';

  @override
  String get radiologyCancelOrderAction => 'Cancel order';

  @override
  String get radiologyRequestDetailsTitle => 'Request details';

  @override
  String get radiologyStudyLabel => 'Study';

  @override
  String get radiologyPriorityLabel => 'Priority';

  @override
  String get radiologyBodyRegionLabel => 'Body region';

  @override
  String get radiologyLateralityLabel => 'Laterality';

  @override
  String get radiologyClinicalNotesLabel => 'Clinical notes';

  @override
  String get radiologyReportSectionTitle => 'Report';

  @override
  String get radiologyReportSectionBody =>
      'Draft, finalize, attest, and amend radiology reports using backend workflow actions.';

  @override
  String get radiologyDraftReportAction => 'Draft report';

  @override
  String get radiologyReleaseReportAction => 'Release report';

  @override
  String get radiologyRequestFinalizationAction => 'Request finalization';

  @override
  String get radiologyRequestFinalizationDialogTitle =>
      'Request report finalization';

  @override
  String get radiologyAttestFinalizationAction => 'Attest finalization';

  @override
  String get radiologyAttestFinalizationDialogTitle =>
      'Attest report finalization';

  @override
  String get radiologyAddendumAction => 'Add addendum';

  @override
  String get radiologyPendingAttestationLabel => 'Pending attestation';

  @override
  String get radiologyNoReportTitle => 'No report yet';

  @override
  String get radiologyNoReportBody =>
      'A draft or final report will appear after reporting begins.';

  @override
  String get radiologyReportedAtLabel => 'Reported';

  @override
  String get radiologyGeneratedReportPreviewTitle => 'Generated report preview';

  @override
  String get radiologyEmptyReportBody => 'No report text captured.';

  @override
  String get radiologyStudiesAssetsTitle => 'Studies and assets';

  @override
  String get radiologyStudiesAssetsBody =>
      'Track imaging studies, uploaded assets, and PACS synchronization state.';

  @override
  String get radiologyNoStudiesTitle => 'No imaging studies';

  @override
  String get radiologyNoStudiesBody =>
      'Studies will appear after imaging is performed.';

  @override
  String get radiologySyncPacsAction => 'Sync PACS';

  @override
  String get radiologyAssetsLabel => 'Assets';

  @override
  String get radiologyNoAssetsLabel => 'No assets recorded';

  @override
  String get radiologyPacsLinksLabel => 'PACS links';

  @override
  String get radiologyNoPacsLinksLabel => 'No PACS links recorded';

  @override
  String get radiologyDoctorReviewTitle => 'Doctor review';

  @override
  String get radiologyDoctorReviewReleasedBody =>
      'The latest report is released for clinical review.';

  @override
  String get radiologyDoctorReviewPendingBody =>
      'Clinical review becomes available after report release.';

  @override
  String get radiologyDoctorReviewReadyLabel => 'Ready for review';

  @override
  String get radiologyDoctorReviewPendingLabel => 'Pending release';

  @override
  String get radiologyTimelineTitle => 'Workflow timeline';

  @override
  String get radiologyNoTimelineTitle => 'No timeline events';

  @override
  String get radiologyNoTimelineBody =>
      'Workflow events will appear as the order progresses.';

  @override
  String get radiologyBackendGapsTitle => 'Backend gaps';

  @override
  String get radiologyBackendGapsBody =>
      'These controls are shown as unavailable until backend support is added.';

  @override
  String get radiologyGapSchedulingTitle => 'Room scheduling';

  @override
  String get radiologyGapBackendSubtitle => 'Not exposed by API';

  @override
  String get radiologyGapSchedulingBody =>
      'The current radiology API has no room or appointment assignment fields.';

  @override
  String get radiologyGapBillingTitle => 'Billing authorization';

  @override
  String get radiologyGapBillingBody =>
      'Payment and authorization status is displayed only when returned by the backend.';

  @override
  String get radiologyCreateOrderDialogTitle => 'Request imaging';

  @override
  String get radiologyReferenceSearchLabel => 'Catalog search';

  @override
  String get radiologyReferenceSearchHint =>
      'Search test code, name, modality, or body region';

  @override
  String get radiologySearchReferenceAction => 'Search catalog';

  @override
  String get radiologyPatientLabel => 'Patient';

  @override
  String radiologyFieldRequiredLabel(String label) {
    return '$label is required.';
  }

  @override
  String get radiologyAssignDialogTitle => 'Assign imaging order';

  @override
  String get radiologyAssigneeLabel => 'Assignee';

  @override
  String get radiologyPerformStudyDialogTitle => 'Perform imaging study';

  @override
  String get radiologyPerformedAtLabel => 'Performed at';

  @override
  String get radiologyDateTimeHint => 'YYYY-MM-DD HH:MM';

  @override
  String get radiologyReportDialogTitle => 'Draft radiology report';

  @override
  String get radiologyFindingsLabel => 'Findings';

  @override
  String get radiologyImpressionLabel => 'Impression';

  @override
  String get radiologyReportTextLabel => 'Report text';

  @override
  String get radiologyReportTextHelper =>
      'Leave blank to combine findings and impression.';

  @override
  String get radiologyReleaseReportDialogTitle => 'Release report';

  @override
  String get radiologyReleaseNotesLabel => 'Release notes';

  @override
  String get radiologyFinalizationStatementLabel => 'Finalization statement';

  @override
  String get radiologyFinalizationReasonLabel => 'Reason';

  @override
  String get radiologyAddendumDialogTitle => 'Add report addendum';

  @override
  String get radiologyAddendumTextLabel => 'Addendum text';

  @override
  String get radiologyCancelDialogTitle => 'Cancel radiology order';

  @override
  String get radiologyCancellationReasonLabel => 'Cancellation reason';

  @override
  String get radiologyPacsSyncDialogTitle => 'Sync study to PACS';

  @override
  String get radiologyStudyUidLabel => 'Study UID';

  @override
  String get radiologyStageAll => 'All';

  @override
  String get radiologyStageOrdered => 'Ordered';

  @override
  String get radiologyStageProcessing => 'Processing';

  @override
  String get radiologyStageReporting => 'Reporting';

  @override
  String get radiologyStageCompleted => 'Completed';

  @override
  String get radiologyStageCancelled => 'Cancelled';

  @override
  String get radiologyStatusOrdered => 'Ordered';

  @override
  String get radiologyStatusInProcess => 'In process';

  @override
  String get radiologyStatusCompleted => 'Completed';

  @override
  String get radiologyStatusCancelled => 'Cancelled';

  @override
  String get radiologyResultDraft => 'Draft';

  @override
  String get radiologyResultFinal => 'Final';

  @override
  String get radiologyResultAmended => 'Amended';

  @override
  String get radiologyModalityXray => 'X-ray';

  @override
  String get radiologyModalityCt => 'CT';

  @override
  String get radiologyModalityMri => 'MRI';

  @override
  String get radiologyModalityUltrasound => 'Ultrasound';

  @override
  String get radiologyModalityPet => 'PET';

  @override
  String get radiologyModalityEcg => 'ECG';

  @override
  String get radiologyModalityEcho => 'Echo';

  @override
  String get radiologyModalityEndo => 'Endoscopy';

  @override
  String get radiologyModalityGastro => 'Gastro';

  @override
  String get radiologyModalityOther => 'Other';

  @override
  String get radiologyNextActionConfirmBilling => 'Confirm billing';

  @override
  String get radiologyNextActionStartImaging => 'Start imaging';

  @override
  String get radiologyNextActionPerformStudy => 'Perform study';

  @override
  String get radiologyNextActionReleaseReport => 'Release report';

  @override
  String get radiologyNextActionDoctorReview => 'Doctor review';

  @override
  String get radiologyNextActionReportPending => 'Report pending';

  @override
  String get navigationPharmacyLabel => 'Pharmacy';

  @override
  String get navigationLabLabel => 'Lab';

  @override
  String get navigationRadiologyLabel => 'Radiology';

  @override
  String get pharmacyLoadingTitle => 'Loading pharmacy workspace';

  @override
  String get pharmacyLoadingBody =>
      'Loading pharmacy orders, dispense state, and stock visibility.';

  @override
  String get pharmacyTitle => 'Pharmacy';

  @override
  String get pharmacyDescription =>
      'Manage prescriptions, dispense handoff, returns, and drug stock visibility from one queue.';

  @override
  String get pharmacyStatusSaving => 'Saving';

  @override
  String get pharmacyStatusLiveSync => 'Live sync';

  @override
  String get pharmacyFiltersSemanticLabel => 'Pharmacy queue filters';

  @override
  String get pharmacySearchLabel => 'Search pharmacy';

  @override
  String get pharmacySearchHint =>
      'Search patient, order, encounter, medication, or batch';

  @override
  String get pharmacyQueueFilterLabel => 'Queue filter';

  @override
  String get pharmacySummaryReadyLabel => 'Ready';

  @override
  String get pharmacySummaryPartialLabel => 'Partial';

  @override
  String get pharmacySummaryAttestationLabel => 'Awaiting attest';

  @override
  String get pharmacySummaryCompletedLabel => 'Completed';

  @override
  String get pharmacyQueuePanelTitle => 'Order queue';

  @override
  String get pharmacyQueuePanelDescription =>
      'Backend-backed pharmacy orders with dispense and return actions.';

  @override
  String get pharmacyNoOrdersTitle => 'No pharmacy orders';

  @override
  String get pharmacyNoOrdersBody =>
      'Orders matching this search and filter will appear here.';

  @override
  String get pharmacyPatientColumnLabel => 'Patient';

  @override
  String get pharmacyOrderColumnLabel => 'Order';

  @override
  String get pharmacyItemsColumnLabel => 'Items';

  @override
  String get pharmacyDispenseColumnLabel => 'Dispense';

  @override
  String get pharmacyStatusColumnLabel => 'Status';

  @override
  String get pharmacyPendingBatchLabel => 'Pending batch';

  @override
  String get pharmacyDetailLoadingTitle => 'Loading prescription';

  @override
  String get pharmacyDetailLoadingBody =>
      'Loading medicines, dispense history, and workflow actions.';

  @override
  String get pharmacyNoSelectionTitle => 'No prescription selected';

  @override
  String get pharmacyNoSelectionBody =>
      'Select an order to review medicines, stock mapping, billing gate visibility, and dispense history.';

  @override
  String get pharmacyBillingGateUnavailableTitle => 'Billing gate unavailable';

  @override
  String get pharmacyOrderFieldLabel => 'Order';

  @override
  String get pharmacyEncounterFieldLabel => 'Encounter';

  @override
  String get pharmacySourceFieldLabel => 'Source';

  @override
  String get pharmacyOrderedFieldLabel => 'Ordered';

  @override
  String get pharmacyActionsPanelTitle => 'Actions';

  @override
  String get pharmacyDispenseAction => 'Dispense';

  @override
  String get pharmacyPrepareDispenseAction => 'Prepare dispense';

  @override
  String get pharmacyAttestAction => 'Attest';

  @override
  String get pharmacyReturnAction => 'Return';

  @override
  String get pharmacyCancelOrderAction => 'Cancel order';

  @override
  String get pharmacyPrintInstructionsAction => 'Print instructions';

  @override
  String get pharmacyMedicationPanelTitle => 'Medicines';

  @override
  String get pharmacyMedicationPanelDescription =>
      'Drug, dose, route, frequency, duration, quantity, instructions, and dispense state.';

  @override
  String get pharmacyNoMedicationTitle => 'No medicines';

  @override
  String get pharmacyNoMedicationBody =>
      'This order has no medicines exposed by the pharmacy workflow API.';

  @override
  String get pharmacyMedicationColumnLabel => 'Medication';

  @override
  String get pharmacyDoseColumnLabel => 'Dose';

  @override
  String get pharmacyQuantityColumnLabel => 'Quantity';

  @override
  String get pharmacyStockColumnLabel => 'Stock';

  @override
  String get pharmacyBackendGapsTitle => 'Backend sync gaps';

  @override
  String get pharmacyBackendGapsBody =>
      'The confirmed API does not yet expose every state requested by the pharmacy plan.';

  @override
  String get pharmacyGapPaymentAuthorization =>
      'Payment and authorization status is not present on pharmacy order workflow responses.';

  @override
  String get pharmacyGapBatchAvailability =>
      'Drug batch availability is not attached to order items; only inventory item mapping is available.';

  @override
  String get pharmacyGapHoldSubstitution =>
      'Hold and drug substitution actions do not have confirmed pharmacy workflow routes.';

  @override
  String get pharmacyGapReportTemplates =>
      'Medication printouts use local HTML until report-template routes expose pharmacy templates.';

  @override
  String get pharmacyTimelinePanelTitle => 'Dispense history';

  @override
  String get pharmacyTimelinePanelDescription =>
      'Order placement, prepare, attest, dispense, and return events from the workflow API.';

  @override
  String get pharmacyNoTimelineBody => 'No dispense history is available yet.';

  @override
  String get pharmacyDrugPanelTitle => 'Formulary and stock';

  @override
  String get pharmacyDrugPanelDescription =>
      'Search configured drugs and review aggregate stock visibility from the confirmed pharmacy API.';

  @override
  String get pharmacyDrugFiltersSemanticLabel => 'Drug stock filters';

  @override
  String get pharmacyDrugSearchLabel => 'Search drugs';

  @override
  String get pharmacyDrugSearchHint => 'Search drug, code, form, or strength';

  @override
  String get pharmacyStockStatusFilterLabel => 'Stock status';

  @override
  String get pharmacyNoDrugsTitle => 'No drugs found';

  @override
  String get pharmacyNoDrugsBody =>
      'Matching formulary drugs and stock rows will appear here.';

  @override
  String get pharmacyDrugColumnLabel => 'Drug';

  @override
  String get pharmacyAvailableColumnLabel => 'Available';

  @override
  String get pharmacyStockStatusColumnLabel => 'Stock status';

  @override
  String pharmacyAvailableQuantityLabel(String quantity) {
    return '$quantity available';
  }

  @override
  String get pharmacyDispenseDialogTitle => 'Prepare dispense';

  @override
  String get pharmacyAttestDialogTitle => 'Attest dispense';

  @override
  String get pharmacyAttestDialogBody =>
      'Confirm the prepared batch after physical medication handoff.';

  @override
  String get pharmacyReturnDialogTitle => 'Return medicines';

  @override
  String get pharmacyReturnDialogBody =>
      'Record returned quantities so order status and stock are synchronized.';

  @override
  String get pharmacyCancelDialogTitle => 'Cancel pharmacy order';

  @override
  String get pharmacyCancelDialogBody =>
      'Cancel only when the order should no longer be dispensed.';

  @override
  String get pharmacyBillingGateUnavailableBody =>
      'Payment clearance is visible as a backend gap because the pharmacy workflow response does not include invoice or payment state.';

  @override
  String get pharmacyBatchRefLabel => 'Batch reference';

  @override
  String get pharmacyStatementLabel => 'Statement';

  @override
  String get pharmacyReasonLabel => 'Reason';

  @override
  String get pharmacyNotesLabel => 'Notes';

  @override
  String get pharmacyQuantityFieldLabel => 'Quantity';

  @override
  String get pharmacyInventoryItemLabel => 'Inventory item';

  @override
  String pharmacyQuantityValidationLabel(String maximum) {
    return 'Enter a quantity from 0 to $maximum.';
  }

  @override
  String get pharmacySavedMessage => 'Pharmacy workflow updated.';

  @override
  String get pharmacyFilterAll => 'All orders';

  @override
  String get pharmacyFilterReady => 'Ready';

  @override
  String get pharmacyFilterPartial => 'Partial';

  @override
  String get pharmacyFilterCompleted => 'Completed';

  @override
  String get pharmacyFilterCancelled => 'Cancelled';

  @override
  String get pharmacyFilterPendingPayment => 'Pending payment - backend gap';

  @override
  String get pharmacyFilterPartialStock => 'Partial stock - backend gap';

  @override
  String get pharmacyFilterUrgent => 'Urgent - backend gap';

  @override
  String get pharmacyFilterDischarge => 'Discharge - backend gap';

  @override
  String get pharmacyStockInStock => 'In stock';

  @override
  String get pharmacyStockAlmostOut => 'Almost out';

  @override
  String get pharmacyStockLow => 'Low stock';

  @override
  String get pharmacyStockOut => 'Out of stock';

  @override
  String get pharmacyStockUnknown => 'Stock unknown';

  @override
  String get pharmacyUnknownStatusLabel => 'Unknown';

  @override
  String get pharmacyStockMappingUnavailable => 'Stock mapping unavailable';

  @override
  String pharmacyTimelineMedicationEvent(String medication, String status) {
    return '$medication $status';
  }

  @override
  String pharmacyTimelineBatchEvent(String type, String batch) {
    return '$type $batch';
  }

  @override
  String get pharmacyTimelineOrderPlaced => 'Order placed';

  @override
  String pharmacyDispenseProgressLabel(String dispensed, String prescribed) {
    return '$dispensed / $prescribed';
  }

  @override
  String get pharmacyReportTitle => 'Medication instructions';

  @override
  String get pharmacyReportPatientLabel => 'Patient';

  @override
  String get pharmacyReportOrderLabel => 'Order';

  @override
  String get pharmacyReportGeneratedLabel => 'Generated';

  @override
  String get pharmacyReportFooter =>
      'Generated from confirmed pharmacy workflow data.';

  @override
  String get navigationClaimsLabel => 'Claims';

  @override
  String get claimsWorkspaceTitle => 'Insurance and claims';

  @override
  String get claimsWorkspaceDescription =>
      'Manage authorizations, payer responses, claim submission, resubmission, and invoice follow-up.';

  @override
  String get claimsOperationalStatusLabel => 'Billing synced';

  @override
  String get claimsNeedsAttentionStatusLabel => 'Needs attention';

  @override
  String get claimsLoadingTitle => 'Loading claims';

  @override
  String get claimsLoadingBody => 'Fetching authorization and claim queues.';

  @override
  String get claimsLoadErrorTitle => 'Claims unavailable';

  @override
  String get claimsLoadErrorBody => 'The claims workspace could not be loaded.';

  @override
  String get claimsRequestAuthorizationAction => 'Request authorization';

  @override
  String get claimsPrepareClaimAction => 'Prepare claim';

  @override
  String get claimsAuthorizationPendingSummaryLabel => 'Auth pending';

  @override
  String get claimsAuthorizationApprovedSummaryLabel => 'Auth approved';

  @override
  String get claimsSubmittedSummaryLabel => 'Submitted';

  @override
  String get claimsRejectedSummaryLabel => 'Rejected';

  @override
  String get claimsApprovedSummaryLabel => 'Approved';

  @override
  String get claimsPaidClosedSummaryLabel => 'Paid/closed';

  @override
  String get claimsSearchSemanticLabel => 'Search claims and authorizations';

  @override
  String get claimsSearchHint =>
      'Search reference, coverage, invoice, or patient';

  @override
  String get claimsQueueFilterLabel => 'Queue';

  @override
  String get claimsWorklistTitle => 'Claims worklist';

  @override
  String get claimsWorklistDescription =>
      'Review pre-authorizations and claim records backed by the billing API.';

  @override
  String get claimsPreviousPageLabel => 'Previous claims page';

  @override
  String get claimsNextPageLabel => 'Next claims page';

  @override
  String claimsPageLabel(int start, int end, int total) {
    return '$start - $end of $total';
  }

  @override
  String get claimsEmptyQueueTitle => 'No claims found';

  @override
  String get claimsEmptyQueueBody =>
      'No authorization or claim records match the current queue.';

  @override
  String get claimsTypeColumnLabel => 'Type';

  @override
  String get claimsReferenceColumnLabel => 'Reference';

  @override
  String get claimsCoverageColumnLabel => 'Coverage';

  @override
  String get claimsInvoiceColumnLabel => 'Invoice';

  @override
  String get claimsStatusColumnLabel => 'Status';

  @override
  String get claimsTimelineColumnLabel => 'Updated';

  @override
  String claimsMobileQueueSubtitle(String coverage, String link) {
    return 'Coverage $coverage | Link $link';
  }

  @override
  String get claimsDetailTitle => 'Claim detail';

  @override
  String get claimsDetailLoadingTitle => 'Loading detail';

  @override
  String get claimsDetailLoadingBody =>
      'Fetching payer, invoice, and coverage context.';

  @override
  String get claimsNoSelectionTitle => 'Select a record';

  @override
  String get claimsNoSelectionBody =>
      'Choose a row to review coverage, billing impact, and next actions.';

  @override
  String get claimsPrintStatementAction => 'Print statement';

  @override
  String get claimsPatientContextLabel => 'Claim patient and coverage context';

  @override
  String get claimsCoverageFieldLabel => 'Coverage';

  @override
  String get claimsPayerFieldLabel => 'Payer';

  @override
  String get claimsUnknownPayerLabel => 'Payer not recorded';

  @override
  String get claimsInvoiceFieldLabel => 'Invoice';

  @override
  String get claimsAmountFieldLabel => 'Amount';

  @override
  String get claimsBillingImpactTitle => 'Billing impact';

  @override
  String get claimsAuthorizationBillingImpactBody =>
      'Service clearance should wait for payer response where authorization is required.';

  @override
  String get claimsCoveragePercentLabel => 'Coverage';

  @override
  String claimsCoveragePercentValue(String percent) {
    return '$percent%';
  }

  @override
  String get claimsInvoiceStatusLabel => 'Invoice status';

  @override
  String get claimsPatientBalanceLabel => 'Patient balance';

  @override
  String get claimsBillingInvoiceUnavailableBody =>
      'Invoice details are not available, so the patient balance cannot be confirmed here.';

  @override
  String get claimsBillingAuthorizedBody =>
      'Authorized by payer. Confirm any uncovered balance before final clearance.';

  @override
  String get claimsBillingPaidBody =>
      'Claim is paid or closed. Billing can use the latest invoice status for follow-up.';

  @override
  String get claimsBillingRejectedBody =>
      'Rejected by payer. Billing staff should prepare resubmission or patient balance follow-up.';

  @override
  String get claimsBillingPendingBody =>
      'Pending payer response. Keep billing clearance visible until the response is recorded.';

  @override
  String get claimsBillingNeutralBody =>
      'Review invoice and payer state before clearing the service.';

  @override
  String get claimsRequiredDocumentsTitle => 'Required documents';

  @override
  String get claimsRequiredDocumentsBody =>
      'Document readiness is shown from available claim, invoice, and coverage data.';

  @override
  String get claimsDocumentInvoiceSummary => 'Invoice summary';

  @override
  String get claimsDocumentCoveragePlan => 'Coverage plan';

  @override
  String get claimsDocumentPayerResponse => 'Payer response';

  @override
  String get claimsTimelineTitle => 'Activity';

  @override
  String get claimsTimelineDescription =>
      'Authorization, submission, and response timestamps from the backend.';

  @override
  String get claimsTimelineAuthorizationRequested => 'Authorization requested';

  @override
  String get claimsTimelineAuthorizationResponded => 'Authorization responded';

  @override
  String get claimsTimelineClaimSubmitted => 'Claim submitted';

  @override
  String get claimsTimelineCurrentStatus => 'Current status';

  @override
  String get claimsBackendGapTitle => 'Backend gaps';

  @override
  String get claimsBackendGapDescription =>
      'These items are shown as integration gaps because the current API does not expose dedicated endpoints for them.';

  @override
  String get claimsBackendGapDraftTitle => 'Claim draft queue';

  @override
  String get claimsBackendGapDraftBody =>
      'The claim API supports submitted, approved, rejected, paid, and cancelled states, but no draft status.';

  @override
  String get claimsBackendGapDocumentsTitle => 'Document upload and requests';

  @override
  String get claimsBackendGapDocumentsBody =>
      'Required document tracking is not yet backed by a document request endpoint.';

  @override
  String get claimsBackendGapReportsTitle => 'Generated payer packs';

  @override
  String get claimsBackendGapReportsBody =>
      'Printable payer packs should move to report templates when the reports plan is implemented.';

  @override
  String get claimsCoveragePlanFieldLabel => 'Coverage plan';

  @override
  String get claimsCoveragePlanHint => 'Select payer coverage';

  @override
  String get claimsCoveragePlanRequiredMessage => 'Select a coverage plan.';

  @override
  String get claimsCoverageUnavailableTitle => 'Coverage plans unavailable';

  @override
  String get claimsCoverageUnavailableBody =>
      'Coverage plans could not be loaded, so authorization cannot be requested yet.';

  @override
  String get claimsRequestAuthorizationSubmitAction => 'Request authorization';

  @override
  String get claimsPrepareClaimDialogTitle => 'Prepare claim';

  @override
  String get claimsPrepareClaimSubmitAction => 'Prepare and submit';

  @override
  String get claimsInvoiceHint => 'Select invoice';

  @override
  String get claimsInvoiceRequiredMessage => 'Select an invoice.';

  @override
  String get claimsPrepareClaimUnavailableTitle => 'Claim inputs unavailable';

  @override
  String get claimsPrepareClaimUnavailableBody =>
      'A coverage plan and invoice are required before a claim can be prepared.';

  @override
  String get claimsAuthorizationStatusFieldLabel => 'Authorization status';

  @override
  String get claimsStatusRequiredMessage => 'Select a status.';

  @override
  String get claimsUpdateStatusSubmitAction => 'Update status';

  @override
  String get claimsNotesFieldLabel => 'Notes';

  @override
  String get claimsSubmitClaimSubmitAction => 'Submit claim';

  @override
  String get claimsClaimResponseFieldLabel => 'Payer response';

  @override
  String get claimsSavedMessage => 'Claims workspace updated.';

  @override
  String get claimsRequestAuthorizationDialogTitle =>
      'Request pre-authorization';

  @override
  String get claimsUpdateAuthorizationDialogTitle =>
      'Update authorization status';

  @override
  String get claimsSubmitClaimDialogTitle => 'Submit claim';

  @override
  String get claimsRecordResponseDialogTitle => 'Record payer response';

  @override
  String get claimsRecordResponseSubmitAction => 'Record response';

  @override
  String get claimsCloseClaimDialogTitle => 'Close claim';

  @override
  String get claimsCloseClaimSubmitAction => 'Close as paid';

  @override
  String get claimsUpdateStatusAction => 'Update status';

  @override
  String get claimsSubmitClaimAction => 'Submit claim';

  @override
  String get claimsResubmitClaimAction => 'Resubmit claim';

  @override
  String get claimsRecordResponseAction => 'Record response';

  @override
  String get claimsCloseClaimAction => 'Close as paid';

  @override
  String get claimsFilterAll => 'All queues';

  @override
  String get claimsFilterAuthorizationPending => 'Authorization pending';

  @override
  String get claimsFilterAuthorizationApproved => 'Authorization approved';

  @override
  String get claimsFilterAuthorizationDenied => 'Authorization denied';

  @override
  String get claimsFilterAuthorizationExpired => 'Authorization expired';

  @override
  String get claimsFilterClaimSubmitted => 'Claim submitted';

  @override
  String get claimsFilterClaimApproved => 'Claim approved';

  @override
  String get claimsFilterClaimRejected => 'Claim rejected';

  @override
  String get claimsFilterClaimPaid => 'Claim paid';

  @override
  String get claimsFilterClaimCancelled => 'Claim cancelled';

  @override
  String get claimsStatusPending => 'Pending';

  @override
  String get claimsStatusApproved => 'Approved';

  @override
  String get claimsStatusDenied => 'Denied';

  @override
  String get claimsStatusExpired => 'Expired';

  @override
  String get claimsStatusSubmitted => 'Submitted';

  @override
  String get claimsStatusRejected => 'Rejected';

  @override
  String get claimsStatusPaid => 'Paid';

  @override
  String get claimsStatusCancelled => 'Cancelled';

  @override
  String get claimsAuthorizationTypeLabel => 'Authorization';

  @override
  String get claimsClaimTypeLabel => 'Claim';

  @override
  String get claimsAuthorizationTitle => 'Coverage authorization';

  @override
  String get claimsClaimPatientTitle => 'Claim patient';

  @override
  String get claimsAuthorizationSubtitle => 'Payer coverage request';

  @override
  String claimsClaimSubtitle(String claimId) {
    return 'Claim $claimId';
  }

  @override
  String get claimsAuthorizationStatementTitle => 'Pre-authorization statement';

  @override
  String get claimsClaimStatementTitle => 'Claim statement';

  @override
  String get claimsReportGeneratedLabel => 'Generated';

  @override
  String get claimsReportFooter =>
      'Generated from backend-backed claims and billing data.';

  @override
  String get labTitle => 'Laboratory';

  @override
  String get labDescription =>
      'Manage lab catalog, order queues, samples, result release, QC, and clinician review handoff.';

  @override
  String get labLoadingTitle => 'Loading laboratory';

  @override
  String get labLoadingBody =>
      'Loading lab queues, catalog, samples, results, and QC logs.';

  @override
  String get labLiveStatus => 'Live sync';

  @override
  String get labSavingStatus => 'Saving';

  @override
  String get labSavedMessage => 'Laboratory workflow updated.';

  @override
  String get labRequestOrderAction => 'Request lab';

  @override
  String get labRecordQcAction => 'Record QC';

  @override
  String get labTotalOrdersSummaryLabel => 'Total orders';

  @override
  String get labWaitingSampleSummaryLabel => 'Waiting sample';

  @override
  String get labProcessingSummaryLabel => 'Processing';

  @override
  String get labResultPendingSummaryLabel => 'Result pending';

  @override
  String get labCriticalSummaryLabel => 'Critical';

  @override
  String get labCompletedSummaryLabel => 'Released';

  @override
  String get labFiltersLabel => 'Laboratory filters';

  @override
  String get labSearchLabel => 'Search laboratory';

  @override
  String get labSearchHint =>
      'Search patient, order, sample, test, or encounter';

  @override
  String get labScopeFilterLabel => 'Queue';

  @override
  String get labScopeAll => 'All';

  @override
  String get labScopeCollection => 'Waiting sample';

  @override
  String get labScopeProcessing => 'Processing';

  @override
  String get labScopeResults => 'Result pending';

  @override
  String get labScopeCritical => 'Critical';

  @override
  String get labScopeCompleted => 'Released';

  @override
  String get labScopeCancelled => 'Cancelled';

  @override
  String get labWorklistTitle => 'Lab queue';

  @override
  String get labWorklistDescription =>
      'Actionable lab orders with sample, processing, result, and release state.';

  @override
  String get labNoOrdersTitle => 'No lab orders';

  @override
  String get labNoOrdersBody =>
      'Adjust the queue filter or search term to find laboratory work.';

  @override
  String get labPatientColumnLabel => 'Patient';

  @override
  String get labOrderColumnLabel => 'Order';

  @override
  String get labTestsColumnLabel => 'Tests';

  @override
  String get labSampleColumnLabel => 'Sample';

  @override
  String get labResultColumnLabel => 'Result';

  @override
  String get labNextActionColumnLabel => 'Next action';

  @override
  String labPageLabel(int from, int to, int total) {
    return '$from-$to of $total';
  }

  @override
  String get labPreviousPageLabel => 'Previous lab page';

  @override
  String get labNextPageLabel => 'Next lab page';

  @override
  String get labDetailTitle => 'Lab detail';

  @override
  String get labDetailLoadingTitle => 'Loading lab detail';

  @override
  String get labDetailLoadingBody =>
      'Loading samples, results, timeline, and available workflow actions.';

  @override
  String get labNoSelectionTitle => 'Select an order';

  @override
  String get labNoSelectionBody =>
      'Choose a lab order from the queue to collect samples, process results, and release reports.';

  @override
  String get labPatientContextLabel => 'Lab patient context';

  @override
  String get labOrderFieldLabel => 'Lab order';

  @override
  String get labEncounterFieldLabel => 'Encounter';

  @override
  String get labOrderedAtFieldLabel => 'Ordered at';

  @override
  String get labItemsSectionTitle => 'Order items';

  @override
  String get labSamplesSectionTitle => 'Samples';

  @override
  String get labResultsSectionTitle => 'Results';

  @override
  String get labTimelineSectionTitle => 'Timeline';

  @override
  String get labNoSamplesLabel => 'No samples recorded';

  @override
  String get labNoResultsLabel => 'No released results';

  @override
  String get labNoTimelineLabel => 'No timeline entries';

  @override
  String get labReferenceRangeLabel => 'Reference range';

  @override
  String get labReportedAtLabel => 'Reported';

  @override
  String get labCollectSampleAction => 'Collect sample';

  @override
  String get labReceiveSampleAction => 'Receive sample';

  @override
  String get labRejectSampleAction => 'Reject sample';

  @override
  String get labReleaseResultAction => 'Release result';

  @override
  String get labReverseWorkflowAction => 'Reverse step';

  @override
  String get labViewCatalogAction => 'View catalog';

  @override
  String get labCatalogQcTitle => 'Catalog and QC';

  @override
  String get labCatalogTitle => 'Lab catalog';

  @override
  String get labQcTitle => 'Quality control';

  @override
  String get labBackendGapsTitle => 'Backend gaps';

  @override
  String get labBackendGapsBody =>
      'No confirmed backend gaps are blocking the displayed lab queue.';

  @override
  String get labNoCatalogItemsLabel => 'No catalog items found';

  @override
  String get labNoQcLogsLabel => 'No QC logs recorded';

  @override
  String get labTestsTabLabel => 'Tests';

  @override
  String get labPanelsTabLabel => 'Panels';

  @override
  String get labRequestOrderDialogTitle => 'Request lab order';

  @override
  String get labPatientIdLabel => 'Patient ID';

  @override
  String get labEncounterIdLabel => 'Encounter ID';

  @override
  String get labCatalogSearchLabel => 'Search lab catalog';

  @override
  String get labCatalogSearchHint =>
      'Search tests, panels, codes, category, or specimen';

  @override
  String get labCreateOrderSubmitAction => 'Create lab order';

  @override
  String get labCollectDialogTitle => 'Collect sample';

  @override
  String get labCollectedAtLabel => 'Collected at';

  @override
  String get labDateTimeHint => 'YYYY-MM-DDTHH:MM:SS';

  @override
  String get labNotesLabel => 'Notes';

  @override
  String get labReceiveDialogTitle => 'Receive sample';

  @override
  String get labSampleFieldLabel => 'Sample';

  @override
  String get labReceivedAtLabel => 'Received at';

  @override
  String get labRejectDialogTitle => 'Reject sample';

  @override
  String get labRejectReasonLabel => 'Rejection reason';

  @override
  String get labReleaseDialogTitle => 'Release lab result';

  @override
  String get labOrderItemFieldLabel => 'Order item';

  @override
  String get labResultStatusLabel => 'Result status';

  @override
  String get labResultValueLabel => 'Result value';

  @override
  String get labResultUnitLabel => 'Result unit';

  @override
  String get labResultTextLabel => 'Result comments';

  @override
  String get labReportedAtInputLabel => 'Reported at';

  @override
  String get labReverseDialogTitle => 'Reverse lab workflow';

  @override
  String get labReverseReasonLabel => 'Reason';

  @override
  String get labRecordQcDialogTitle => 'Record quality control';

  @override
  String get labQcTestFieldLabel => 'Lab test';

  @override
  String get labQcStatusFieldLabel => 'QC status';

  @override
  String get labLoggedAtLabel => 'Logged at';

  @override
  String get labQcNotesLabel => 'QC notes';

  @override
  String get labStatusOrdered => 'Ordered';

  @override
  String get labStatusCollected => 'Collected';

  @override
  String get labStatusInProcess => 'In process';

  @override
  String get labStatusCompleted => 'Released';

  @override
  String get labStatusCancelled => 'Cancelled';

  @override
  String get labStatusPending => 'Pending';

  @override
  String get labStatusNormal => 'Normal';

  @override
  String get labStatusAbnormal => 'Abnormal';

  @override
  String get labStatusCritical => 'Critical';

  @override
  String get labStatusRejected => 'Rejected';

  @override
  String get labStatusReceived => 'Received';

  @override
  String get labNextActionCancelled => 'Order cancelled';

  @override
  String get labNextActionCollect => 'Collect sample';

  @override
  String get labNextActionReceive => 'Receive sample';

  @override
  String get labNextActionRelease => 'Enter and release result';

  @override
  String get labNextActionReviewCritical => 'Escalate critical result';

  @override
  String get labNextActionCompleted => 'Ready for doctor review';

  @override
  String get labNextActionWatch => 'Review order';

  @override
  String get labReportPreviewTitle => 'Result report preview';

  @override
  String get labReportTitle => 'Laboratory result report';

  @override
  String get labCopyReportAction => 'Copy report';

  @override
  String get labReportPatientLabel => 'Patient';

  @override
  String get labReportOrderLabel => 'Order';

  @override
  String get labReportResultLabel => 'Result';

  @override
  String get labReportRangeLabel => 'Reference range';

  @override
  String get labReportVerifiedLabel => 'Released';

  @override
  String get labReportFooter =>
      'Generated from confirmed laboratory workflow data.';

  @override
  String get labGapBillingTitle => 'Payment and authorization gate';

  @override
  String get labGapBillingBody =>
      'The current lab workbench contract does not expose payment or authorization blockers.';

  @override
  String get labGapVerificationTitle => 'Separate verification step';

  @override
  String get labGapVerificationBody =>
      'The confirmed workflow releases an order item result, but does not expose a separate verified-before-release state.';

  @override
  String get labGapReportGenerationTitle => 'Generated report endpoint';

  @override
  String get labGapReportGenerationBody =>
      'The frontend shows a shared report preview; no confirmed lab-specific generated PDF endpoint is exposed.';
}
