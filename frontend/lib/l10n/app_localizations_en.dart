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
  String get startupLoadingTitle => 'Starting HOSSPI';

  @override
  String get startupLoadingBody => 'Preparing your workspace...';

  @override
  String get startupErrorTitle => 'The app could not start';

  @override
  String get startupErrorBody => 'Restart the app or try again.';

  @override
  String get commonRetryActionLabel => 'Try again';

  @override
  String get commonRefreshActionLabel => 'Refresh';

  @override
  String get workspaceToolbarOverflowLabel => 'More actions';

  @override
  String get workspaceNotificationsMenuLabel => 'Notifications';

  @override
  String workspaceToolbarOverflowAttentionTooltip(int count) {
    return 'More actions — $count need attention';
  }

  @override
  String get workspaceToolbarSectionStaffAccess => 'Staff & access';

  @override
  String get workspaceToolbarSectionScheduling => 'Scheduling';

  @override
  String get workspaceToolbarSectionApprovals => 'Approvals';

  @override
  String get workspaceToolbarSectionActivity => 'Activity';

  @override
  String get workspaceToolbarSectionWorkspace => 'Workspace';

  @override
  String get workspaceToolbarSectionFacilities => 'Facilities';

  @override
  String get workspaceNotificationsToolbarTooltip =>
      'Open queues that need attention.';

  @override
  String get workspaceFullscreenEnterLabel => 'Full screen';

  @override
  String get workspaceFullscreenExitLabel => 'Exit full screen';

  @override
  String get workspaceGlobalFaultReportAction => 'Report equipment fault';

  @override
  String get workspaceGlobalHousekeepingRequestAction => 'Request maintenance';

  @override
  String get commonTableSettingsActionLabel => 'Table settings';

  @override
  String get emergencyCaseDialogTitle => 'Emergency case';

  @override
  String get icuStayDialogTitle => 'ICU stay';

  @override
  String get icuLoadingBoardTitle => 'Loading ICU board';

  @override
  String get icuLoadingBoardBody => 'Loading ICU patients and alerts...';

  @override
  String get icuLiveSyncLabel => 'Live sync';

  @override
  String get icuSavingLabel => 'Saving';

  @override
  String get icuViewPatientBoard => 'Patient board';

  @override
  String get icuViewBedBoard => 'Bed board';

  @override
  String get icuAllIcuLabel => 'All ICU';

  @override
  String get icuActiveIcuLabel => 'Active ICU';

  @override
  String get icuCriticalAlertsLabel => 'Critical alerts';

  @override
  String get icuTransfersLabel => 'Transfers';

  @override
  String get icuDischargeReadyLabel => 'Discharge ready';

  @override
  String get icuEndedStaysLabel => 'Ended stays';

  @override
  String get icuTransferPendingLabel => 'Transfer pending';

  @override
  String get icuBoardTitle => 'ICU board';

  @override
  String get icuBoardDescription => 'Grouped by bed state and alert level.';

  @override
  String get icuSearchHint => 'Search patient, admission, bed, or alert';

  @override
  String get icuBoardScopeLabel => 'Board scope';

  @override
  String get icuBoardFiltersTitle => 'ICU board filters';

  @override
  String get icuColumnBedLabel => 'Bed';

  @override
  String get icuColumnAlertLabel => 'Alert';

  @override
  String get icuColumnTransferLabel => 'Transfer';

  @override
  String get icuColumnStartLabel => 'ICU start';

  @override
  String get icuColumnSourceLabel => 'Source';

  @override
  String get icuNoPatientsTitle => 'No ICU patients';

  @override
  String get icuNoPatientsBody =>
      'Active ICU admissions will appear here after IPD admission and ICU transfer.';

  @override
  String get icuNoAlertLabel => 'No alert';

  @override
  String get icuDetailEmptyTitle => 'No ICU stay selected';

  @override
  String get icuDetailEmptyBody =>
      'Select an ICU patient for observations and alerts.';

  @override
  String get icuDetailLoadingTitle => 'Loading ICU stay';

  @override
  String get icuDetailLoadingBody =>
      'Loading observations and transfer state...';

  @override
  String get icuAdmissionLabel => 'Admission';

  @override
  String get icuLocationLabel => 'Location';

  @override
  String get icuFacilityLabel => 'Facility';

  @override
  String get icuAdmittedLabel => 'Admitted';

  @override
  String get icuSourceLabel => 'Source';

  @override
  String get icuStayStartedLabel => 'ICU stay started';

  @override
  String get icuActionsTitle => 'Actions';

  @override
  String get icuCriticalAlertsPanelTitle => 'Critical alerts';

  @override
  String get icuNoActiveAlertsLabel => 'No active ICU critical alerts.';

  @override
  String icuHighestSeverityLabel(String severity) {
    return 'Highest severity: $severity';
  }

  @override
  String get icuNoActiveAlertsListLabel => 'No active alerts';

  @override
  String get icuObservationsPanelTitle => 'Observations';

  @override
  String get icuObservationsPanelDescription =>
      'Recent intensive observations for this stay.';

  @override
  String get icuNoObservationsLabel => 'No ICU observations recorded';

  @override
  String get icuVitalsTrendTitle => 'Vitals trend';

  @override
  String get icuVitalsTrendDescription => 'Latest vitals for this admission.';

  @override
  String get icuNoVitalsLabel => 'No vitals recorded';

  @override
  String get icuCarePanelTitle => 'Rounds, nursing, and orders';

  @override
  String get icuCarePanelDescription =>
      'Care notes and medication tasks linked to IPD.';

  @override
  String get icuNoCareTasksLabel => 'No care tasks recorded';

  @override
  String get icuTransferPanelTitle => 'Transfer and readiness';

  @override
  String get icuTransferPanelDescription =>
      'Stay movement, planned discharge, and handoff.';

  @override
  String get icuNoTransferRecordsLabel =>
      'No transfer or discharge readiness records';

  @override
  String get icuRoundNoteFallback => 'Round note';

  @override
  String get icuNursingNoteFallback => 'Nursing note';

  @override
  String get icuMedicationTaskFallback => 'Medication task';

  @override
  String get icuDoseLabel => 'Dose';

  @override
  String get icuActiveStayLabel => 'Active ICU stay';

  @override
  String get icuPreviousStayLabel => 'Previous ICU stay';

  @override
  String icuEndedAtLabel(String time) {
    return 'Ended $time';
  }

  @override
  String get icuTransferRecordLabel => 'Transfer';

  @override
  String get icuDischargeRecordLabel => 'Discharge';

  @override
  String get icuActionStartStay => 'Start ICU stay';

  @override
  String get icuActionRecordObservation => 'Observation';

  @override
  String get icuActionRecordVitals => 'Vitals';

  @override
  String get icuActionRaiseAlert => 'Critical alert';

  @override
  String get icuActionAcknowledgeAlert => 'Acknowledge alert';

  @override
  String get icuActionRound => 'ICU round';

  @override
  String get icuActionOrderLab => 'Order lab';

  @override
  String get icuActionOrderImaging => 'Order imaging';

  @override
  String get icuActionPrescribe => 'Prescribe';

  @override
  String get icuActionRequestTransfer => 'Request transfer';

  @override
  String get icuActionManageTransfer => 'Manage transfer';

  @override
  String get icuActionAssignBed => 'Assign ICU bed';

  @override
  String get icuActionMarkReadiness => 'Discharge readiness';

  @override
  String get icuActionOpenIpd => 'Open in IPD';

  @override
  String get icuActionOpenDischargeClearance => 'Open discharge clearance';

  @override
  String get icuActionOpenBilling => 'Open billing';

  @override
  String get icuBillingDeferredLabel => 'Billing deferred';

  @override
  String get icuActionEndStay => 'End ICU stay';

  @override
  String get icuPrintSummaryLabel => 'Print summary';

  @override
  String get icuObservationDialogTitle => 'Record ICU observation';

  @override
  String get icuObservationFieldLabel => 'Observation';

  @override
  String get icuRecordActionLabel => 'Record';

  @override
  String get icuVitalsDialogTitle => 'Update vitals';

  @override
  String get icuVitalsUpdateActionLabel => 'Update';

  @override
  String get icuAlertDialogTitle => 'Add critical alert';

  @override
  String get icuAlertSeverityLabel => 'Severity';

  @override
  String get icuAlertMessageLabel => 'Alert message';

  @override
  String get icuAlertAddActionLabel => 'Add alert';

  @override
  String get icuRoundDialogTitle => 'Add ICU round note';

  @override
  String get icuRoundNoteLabel => 'Round note';

  @override
  String get icuRoundAddActionLabel => 'Add note';

  @override
  String get icuTransferDialogTitle => 'Request transfer';

  @override
  String get icuTransferTargetWardLabel => 'Target ward';

  @override
  String get icuTransferTargetWardIdLabel => 'Target ward ID';

  @override
  String get icuTransferRequestActionLabel => 'Request';

  @override
  String get icuReadinessDialogTitle => 'Mark discharge readiness';

  @override
  String get icuReadinessNoteLabel => 'Readiness note';

  @override
  String get icuReadinessDescription =>
      'Records discharge readiness; patient stays in IPD discharge.';

  @override
  String get icuReadinessMarkActionLabel => 'Mark ready';

  @override
  String get icuStartStayTitle => 'Start ICU stay';

  @override
  String get icuStartStayBody =>
      'Opens an ICU stay on this IPD admission for critical-care notes.';

  @override
  String get icuStartStayActionLabel => 'Start stay';

  @override
  String get icuAcknowledgeTitle => 'Acknowledge alert';

  @override
  String get icuAcknowledgeBody =>
      'This clears the selected critical alert from the active ICU board.';

  @override
  String get icuEndStayTitle => 'End ICU stay';

  @override
  String get icuEndStayBody =>
      'Ends the ICU stay. Confirm receiving ward or discharge is ready.';

  @override
  String get icuAssignBedDialogTitle => 'Assign ICU bed';

  @override
  String get icuManageTransferDialogTitle => 'Manage transfer';

  @override
  String get icuTransferActionApprove => 'Approve';

  @override
  String get icuTransferActionStart => 'Start';

  @override
  String get icuTransferActionComplete => 'Complete with bed';

  @override
  String get icuTransferActionCancel => 'Cancel transfer';

  @override
  String get icuTransferSelectBedLabel => 'Target bed';

  @override
  String get icuTransferNoOpenLabel => 'No open transfer to manage.';

  @override
  String get icuStepDownPromptTitle => 'End ICU stay?';

  @override
  String get icuStepDownPromptBody =>
      'Transfer complete. End the ICU stay — patient is on the ward.';

  @override
  String get icuChangesSavedMessage => 'ICU changes saved.';

  @override
  String get icuBedBoardTitle => 'ICU bed board';

  @override
  String get icuBedBoardDescription => 'ICU bed occupancy and operations.';

  @override
  String get icuBedBoardAllWards => 'All ICU wards';

  @override
  String icuBedAvailableLabel(int count) {
    return '$count available';
  }

  @override
  String icuBedOccupiedLabel(int count) {
    return '$count occupied';
  }

  @override
  String get icuBedColumnWard => 'Ward';

  @override
  String get icuBedColumnBed => 'Room / bed';

  @override
  String get icuBedColumnStatus => 'Status';

  @override
  String get icuBedColumnPatient => 'Patient';

  @override
  String get icuBedNoBedsTitle => 'No ICU beds';

  @override
  String get icuBedNoBedsBody =>
      'No ICU beds are configured for this facility.';

  @override
  String get icuBedVacantLabel => 'Vacant';

  @override
  String get icuPrintAlertsSection => 'Alerts';

  @override
  String get icuPrintObservationsSection => 'Observations';

  @override
  String get icuPrintVitalsSection => 'Vitals';

  @override
  String get icuPrintTransferSection => 'Transfer and readiness';

  @override
  String get ipdOpenIcuAction => 'Open in ICU';

  @override
  String get ipdOpenTheaterAction => 'Open in Theater';

  @override
  String get ipdStatusInProcedureOt => 'In procedure / OT';

  @override
  String get ipdNextCompleteTheatreHandover => 'Complete theatre handover';

  @override
  String get ipdTheatreHandoverTitle => 'Theatre post-op handover';

  @override
  String get ipdStartIcuStayAction => 'Start ICU stay';

  @override
  String get ipdStartIcuStayBody =>
      'Opens an ICU stay so critical-care documentation can begin.';

  @override
  String get commonGoHomeActionLabel => 'Go to dashboard';

  @override
  String get commonCancelActionLabel => 'Cancel';

  @override
  String get commonCloseActionLabel => 'Close';

  @override
  String get appImageCropTitle => 'Crop image';

  @override
  String get appImageCropBody => 'Drag and resize the crop box, then apply.';

  @override
  String get appImageCropFreeformBody =>
      'Drag and resize freely to any aspect ratio, then apply.';

  @override
  String get appImageCropAspectFree => 'Free';

  @override
  String get appImageCropAspectSquare => '1:1';

  @override
  String get appImageCropAspectFourThree => '4:3';

  @override
  String get appImageCropAspectSixteenNine => '16:9';

  @override
  String get appImageCropApplyAction => 'Apply crop';

  @override
  String get appImageCropPreviewTitle => 'Preview crop';

  @override
  String get appImageCropPreviewBody =>
      'Confirm the crop, or go back to adjust.';

  @override
  String get appImageCropRecropAction => 'Adjust crop';

  @override
  String get appImageCropConfirmAction => 'Use image';

  @override
  String get appImageUploadPreviewTitle => 'Image preview';

  @override
  String get appImageUploadEmptyLabel => 'No images yet.';

  @override
  String get appDateInvalidMessage => 'Enter a valid date.';

  @override
  String get appDateFormatHint => 'DD/MM/YYYY';

  @override
  String get appTimePickerAction => 'Select time';

  @override
  String get appTimeInvalidMessage => 'Enter a valid time.';

  @override
  String get appTimeFormatHint => 'HH:MM';

  @override
  String get appTimeHourLabel => 'HH';

  @override
  String get appTimeMinuteLabel => 'MM';

  @override
  String get appTimeSecondLabel => 'SS';

  @override
  String get appTimeAmLabel => 'AM';

  @override
  String get appTimePmLabel => 'PM';

  @override
  String get appTime12HourLabel => '12H';

  @override
  String get appTime24HourLabel => '24H';

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
  String get appNavigationSearchLabel => 'Search menu';

  @override
  String get appNavigationSearchHint => 'Search menu';

  @override
  String get appNavigationSearchNoResultsLabel => 'No menu items found';

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
  String get navigationHomeLabel => 'Dashboard';

  @override
  String get navigationHomeShortLabel => 'Dashboard';

  @override
  String get navigationSettingsLabel => 'Settings';

  @override
  String get navigationSettingsShortLabel => 'Settings';

  @override
  String get navigationSetupLabel => 'Tenant setup';

  @override
  String get navigationSetupShortLabel => 'Setup';

  @override
  String get navigationPatientsLabel => 'Patient registry';

  @override
  String get navigationPatientsShortLabel => 'Patients';

  @override
  String get navigationBillingLabel => 'Billing';

  @override
  String get navigationBillingShortLabel => 'Billing';

  @override
  String get billingWorkspaceTitle => 'Billing';

  @override
  String get billingLoadingTitle => 'Loading billing workspace';

  @override
  String get billingLoadingBody => 'Loading invoices and payment queues...';

  @override
  String get billingStatusLive => 'Live';

  @override
  String get billingStatusPosting => 'Posting';

  @override
  String get billingWorklistDescription =>
      'Invoices, payments, claims, and approvals.';

  @override
  String get billingAllWorkItems => 'All billing work items';

  @override
  String get billingAwaitingPayment => 'Awaiting payment';

  @override
  String get billingIssueQueue => 'Issue queue';

  @override
  String get billingClaimsPending => 'Claims pending';

  @override
  String get billingApprovals => 'Approvals';

  @override
  String get billingOverdue => 'Overdue';

  @override
  String get billingNeedsIssue => 'Needs issue';

  @override
  String get billingApprovalRequired => 'Approval required';

  @override
  String get billingQueueLabel => 'Queue';

  @override
  String get billingSearchHint =>
      'Patient, ID, invoice, encounter, email, or phone';

  @override
  String get billingPatientNameColumn => 'Patient name';

  @override
  String get billingPatientIdColumn => 'Patient ID';

  @override
  String get billingInvoiceColumn => 'Invoice';

  @override
  String get billingSourceColumn => 'Source';

  @override
  String get billingAmountDueColumn => 'Amount due';

  @override
  String get billingSourceFilterLabel => 'Source';

  @override
  String get billingAnySourceOption => 'Any source';

  @override
  String get billingStatusFilterLabel => 'Status';

  @override
  String get billingAnyStatusOption => 'Any status';

  @override
  String get billingSourceLaboratory => 'Laboratory';

  @override
  String get billingSourceRadiology => 'Radiology';

  @override
  String get billingSourcePharmacy => 'Pharmacy';

  @override
  String get billingStatusDraftOption => 'Draft';

  @override
  String get billingStatusIssuedOption => 'Issued';

  @override
  String get billingStatusPartialOption => 'Partially paid';

  @override
  String get billingStatusPaidOption => 'Paid';

  @override
  String get billingStatusOverdueOption => 'Overdue';

  @override
  String get billingIssuedDateFilterLabel => 'Issued date';

  @override
  String get billingSearchSemanticLabel => 'Search billing worklist';

  @override
  String get billingClearSearch => 'Clear billing search';

  @override
  String get billingFiltersTitle => 'Billing filters';

  @override
  String get billingEmptyTitle => 'No billing items';

  @override
  String get billingEmptyBody =>
      'No invoices or billing actions in this queue.';

  @override
  String get billingPatientColumn => 'Patient';

  @override
  String get billingStatusColumn => 'Status';

  @override
  String get billingAmountColumn => 'Amount';

  @override
  String get billingPaidColumn => 'Paid';

  @override
  String get billingBalanceColumn => 'Balance';

  @override
  String get billingTotalAmountLabel => 'Total amount';

  @override
  String get billingAmountPaidLabel => 'Amount paid';

  @override
  String get billingPaymentStatusLabel => 'Payment status';

  @override
  String get billingInvoiceStatusLabel => 'Invoice status';

  @override
  String get billingAgeLabel => 'Age';

  @override
  String get billingLineItemDescriptionColumn => 'Description';

  @override
  String get billingLineItemQtyColumn => 'Qty';

  @override
  String get billingLineItemUnitPriceColumn => 'Unit price';

  @override
  String get billingLineItemDepartmentColumn => 'Department';

  @override
  String get billingLineItemAmountColumn => 'Amount';

  @override
  String get billingUpdatedColumn => 'Updated';

  @override
  String get billingInvoiceLabel => 'Invoice';

  @override
  String get billingReceivePayment => 'Receive payment';

  @override
  String get billingIssueAction => 'Issue';

  @override
  String get billingRefundAction => 'Refund';

  @override
  String get billingAdjustAction => 'Adjust';

  @override
  String get billingVoidAction => 'Void';

  @override
  String get billingSendAction => 'Send';

  @override
  String get billingCloseShift => 'Close shift';

  @override
  String get billingCloseDay => 'Close day';

  @override
  String get billingIssueInvoice => 'Issue invoice';

  @override
  String get billingSendInvoice => 'Send invoice';

  @override
  String get billingVoidInvoice => 'Void invoice';

  @override
  String get billingRequestAdjustment => 'Request adjustment';

  @override
  String get billingRequestRefund => 'Request refund';

  @override
  String get billingDueLabel => 'Due';

  @override
  String get billingNoLineItems => 'No line items returned for this invoice.';

  @override
  String get billingNoPayments => 'No payments recorded for this invoice.';

  @override
  String get billingNoAdjustments => 'No billing adjustments recorded.';

  @override
  String get billingLineItemsTitle => 'Line items';

  @override
  String get billingPaymentsTitle => 'Payments';

  @override
  String get billingAdjustmentsTitle => 'Adjustments';

  @override
  String get billingFinancialSummaryTitle => 'Financial summary';

  @override
  String get billingInvoiceDetailTitle => 'Invoice detail';

  @override
  String get billingItemDetailTitle => 'Billing item';

  @override
  String get billingClaimDetailTitle => 'Insurance claim';

  @override
  String get billingApprovalDetailTitle => 'Approval request';

  @override
  String get billingPreAuthDetailTitle => 'Pre-authorization';

  @override
  String get billingActionSaved => 'Billing action saved.';

  @override
  String get billingActionPendingApproval =>
      'Submitted. Pending approval before it takes effect.';

  @override
  String get billingDocumentDownloaded => 'Invoice document saved.';

  @override
  String get billingDocumentUnavailable =>
      'Invoice document could not be saved on this device.';

  @override
  String get billingDocumentTooltip => 'Download invoice PDF';

  @override
  String get billingPrintInvoiceAction => 'Print invoice';

  @override
  String get billingPrintInvoiceTooltip =>
      'Print invoice with line items and payments';

  @override
  String get billingInvoiceReportFooter =>
      'This invoice was generated by the HMS billing workspace.';

  @override
  String get billingEffectiveTotalLabel => 'Effective total';

  @override
  String get billingGrossPaymentsLabel => 'Payments received';

  @override
  String get billingNetPaidLabel => 'Net paid';

  @override
  String get billingRefundsLabel => 'Refunds';

  @override
  String get billingViewLedgerAction => 'View ledger';

  @override
  String get billingLedgerTitle => 'Patient ledger';

  @override
  String get billingLedgerEmpty =>
      'No ledger entries for this patient in the selected period.';

  @override
  String get billingApproveAction => 'Approve';

  @override
  String get billingRejectAction => 'Reject';

  @override
  String get billingSubmitClaimAction => 'Submit claim';

  @override
  String get billingReconcileClaimAction => 'Record insurer response';

  @override
  String get billingFinalizeEncounterAction => 'Finalize financial clearance';

  @override
  String get billingFinalizeEncounterBody =>
      'Linked charges are settled. Confirm financial clearance for this encounter.';

  @override
  String get billingEncounterLabel => 'Encounter';

  @override
  String get billingCoveragePlanLabel => 'Coverage plan';

  @override
  String get billingRequestTypeLabel => 'Request type';

  @override
  String get billingRequesterLabel => 'Requested by';

  @override
  String get billingReasonLabel => 'Reason';

  @override
  String get billingLinkedInvoiceLabel => 'Linked invoice';

  @override
  String get billingClearanceCleared => 'Cleared';

  @override
  String get billingClearancePartiallyPaid => 'Partially paid';

  @override
  String get billingClearanceDeferred => 'Deferred';

  @override
  String get billingClearanceInsured => 'Insured';

  @override
  String get billingClearancePendingAuth => 'Pending authorization';

  @override
  String get billingClearanceBlocked => 'Blocked';

  @override
  String get billingNotRecorded => 'Not recorded';

  @override
  String get billingUnknownValue => 'Unknown';

  @override
  String get billingPreviousPageLabel => 'Previous page';

  @override
  String get billingNextPageLabel => 'Next page';

  @override
  String get billingClearFilters => 'Clear';

  @override
  String get billingPaymentReferenceHint =>
      'Mobile money, card, or bank reference';

  @override
  String get billingPayerHint => 'Patient, sponsor, insurer, or contact';

  @override
  String get billingPdfFileTypeLabel => 'PDF document';

  @override
  String get billingClaimStatusApproved => 'Approved';

  @override
  String get billingClaimStatusRejected => 'Rejected';

  @override
  String get billingClaimStatusPaid => 'Paid';

  @override
  String get billingStatusDraft => 'Draft';

  @override
  String get billingStatusIssued => 'Issued';

  @override
  String get billingStatusPartial => 'Partial';

  @override
  String get billingStatusPaid => 'Paid';

  @override
  String get billingAmountReceivedLabel => 'Amount received';

  @override
  String get billingCurrencyLabel => 'Currency';

  @override
  String get billingPaymentMethodLabel => 'Payment method';

  @override
  String get billingReferenceLabel => 'Reference';

  @override
  String get billingPayerLabel => 'Payer';

  @override
  String get billingGenerateReceiptLabel => 'Generate receipt after payment';

  @override
  String get billingPaymentLabel => 'Payment';

  @override
  String get billingRefundAmountLabel => 'Refund amount';

  @override
  String get billingRefundReasonValidation => 'Enter a refund reason.';

  @override
  String get billingNotesLabel => 'Notes';

  @override
  String get billingAdjustmentAmountLabel => 'Adjustment amount (+/-)';

  @override
  String get billingAdjustmentAmountValidation =>
      'Enter a signed amount, for example -10.00 or 25.00.';

  @override
  String get billingAppliedStatusLabel => 'Applied status';

  @override
  String get billingAdjustmentReasonValidation => 'Enter an adjustment reason.';

  @override
  String get billingReasonValidation => 'Enter a reason.';

  @override
  String get billingRecipientEmailLabel => 'Recipient email';

  @override
  String get billingExpectedAmountLabel => 'Expected amount';

  @override
  String get billingActualAmountLabel => 'Actual amount';

  @override
  String get billingSubmitForApprovalLabel => 'Submit for approval';

  @override
  String get billingRequestVoidAction => 'Request void';

  @override
  String get billingVoidReasonLabel => 'Void reason';

  @override
  String get billingUnknownPatient => 'Unknown patient';

  @override
  String billingQuantityLabel(int quantity) {
    return 'Qty $quantity';
  }

  @override
  String get navigationSubscriptionsLabel => 'Subscription plans';

  @override
  String get navigationSubscriptionsShortLabel => 'Plans';

  @override
  String get subscriptionHeaderActiveLabel => 'Subscribed';

  @override
  String get subscriptionHeaderFreeLabel => 'Free';

  @override
  String get subscriptionHeaderExpiringSoonLabel => 'Renew soon';

  @override
  String subscriptionHeaderExpiresInDaysLabel(int days) {
    return 'Expires in $days days';
  }

  @override
  String get subscriptionHeaderExpiredLabel => 'Limited access';

  @override
  String get subscriptionHeaderUpgradeLabel => 'Upgrade';

  @override
  String subscriptionHeaderUpgradeToLabel(String plan) {
    return 'Upgrade to $plan';
  }

  @override
  String subscriptionHeaderPlanWithUpgradeLabel(String plan, String nextPlan) {
    return '$plan · Upgrade to $nextPlan';
  }

  @override
  String get subscriptionHeaderTooltip => 'Manage subscription and billing';

  @override
  String get subscriptionExpiredPromptTitle => 'Subscription expired';

  @override
  String get subscriptionExpiredPromptBody =>
      'Some features are limited — not fully blocked. Renew to restore full access.';

  @override
  String get subscriptionExpiredPromptRenewAction => 'Renew now';

  @override
  String get subscriptionExpiredPromptLaterAction => 'Later';

  @override
  String get subscriptionExpiredPromptContactAdminBody =>
      'Some features are limited — not fully blocked. Ask an admin below to renew.';

  @override
  String get subscriptionExpiredRiskTitle => 'Action needed';

  @override
  String get subscriptionReportRiskTitle => 'Renewal needed';

  @override
  String get subscriptionExpiredPromptContactAdminAction => 'Got it';

  @override
  String get subscriptionReportAdminsDialogTitle => 'Who can renew?';

  @override
  String get subscriptionReportAdminsDialogBody =>
      'Some features are limited. Ask an admin below to renew or upgrade.';

  @override
  String get subscriptionReportFacilityAdminsLabel => 'Facility administrators';

  @override
  String get subscriptionReportTenantAdminsLabel => 'Tenant administrators';

  @override
  String get subscriptionReportFacilityAdminRoleLabel =>
      'Facility administrator';

  @override
  String get subscriptionReportTenantAdminRoleLabel => 'Tenant administrator';

  @override
  String get subscriptionReportPlatformSupportLabel => 'Platform support';

  @override
  String get subscriptionReportPlatformSupportName => 'Hosspi platform support';

  @override
  String get subscriptionReportPlatformSupportRoleLabel =>
      'Platform administrator';

  @override
  String get subscriptionReportAdminsEmptyMessage =>
      'No admin contacts listed. Ask who manages renewals.';

  @override
  String get subscriptionUpgradeAccessDeniedMessage =>
      'Only admins or users with subscription access can manage billing.';

  @override
  String get subscriptionUpgradeDialogTitle => 'Upgrade subscription';

  @override
  String get subscriptionRenewDialogTitle => 'Renew subscription';

  @override
  String get subscriptionUpgradeDialogBody =>
      'Choose a plan and submit payment to keep full access.';

  @override
  String get subscriptionRenewDialogBody =>
      'Confirm your current plan and submit payment to extend your subscription.';

  @override
  String get subscriptionUpgradeIntentBanner =>
      'You are upgrading to a higher plan.';

  @override
  String subscriptionRenewIntentBanner(String plan) {
    return 'You are renewing your $plan plan.';
  }

  @override
  String get subscriptionUpgradeStepPlanTitle => 'Choose plan';

  @override
  String get subscriptionUpgradeStepPaymentMethodTitle => 'Payment method';

  @override
  String get subscriptionUpgradeStepPaymentDetailsTitle => 'Payment details';

  @override
  String get subscriptionUpgradeStepProofTitle => 'Proof of payment';

  @override
  String get subscriptionUpgradeStepContactTitle => 'Billing contact';

  @override
  String get subscriptionUpgradeStepConfirmTitle => 'Confirm';

  @override
  String get subscriptionUpgradeFreePlanStepBody =>
      'No payment needed. Confirm to request this free plan.';

  @override
  String get subscriptionUpgradeConfirmFreeAction => 'Confirm free plan';

  @override
  String get subscriptionUpgradePlansEmptyTitle => 'No plans available';

  @override
  String get subscriptionUpgradePlansEmptyMessage =>
      'Plans could not be loaded. Refresh or contact support.';

  @override
  String get subscriptionUpgradeBillingCycleHint => 'Billing cycle';

  @override
  String get subscriptionUpgradeBillingMonthlyLabel => 'Monthly';

  @override
  String get subscriptionUpgradeBillingAnnualLabel => 'Annual';

  @override
  String get subscriptionUpgradeCurrentPlanBadge => 'Current plan';

  @override
  String get subscriptionUpgradeInvoiceEmailLabel => 'Invoice email';

  @override
  String get subscriptionUpgradeInvoiceEmailHelper =>
      'Invoice will be sent to this email.';

  @override
  String get subscriptionUpgradeProofStepBody =>
      'Attach a screenshot or file that confirms your payment.';

  @override
  String get commonBackActionLabel => 'Back';

  @override
  String get subscriptionUpgradePlanLabel => 'Plan';

  @override
  String get subscriptionUpgradePaymentMethodLabel => 'Payment method';

  @override
  String get subscriptionUpgradeAmountLabel => 'Amount paid';

  @override
  String get subscriptionUpgradeReferenceLabel => 'Payment reference';

  @override
  String get subscriptionUpgradeNotesLabel => 'Notes';

  @override
  String get subscriptionUpgradeProofLabel => 'Proof of payment';

  @override
  String get subscriptionUpgradeAttachProofAction => 'Attach proof';

  @override
  String get subscriptionUpgradeRemoveProofAction => 'Remove attachment';

  @override
  String get subscriptionUpgradeAdminContactTitle => 'Platform billing contact';

  @override
  String get subscriptionUpgradeAdminContactBody =>
      'If access is not restored after payment, contact platform admins below.';

  @override
  String get subscriptionUpgradeAdminContactEmailLabel => 'Email';

  @override
  String get subscriptionUpgradeAdminContactPhoneLabel => 'Phone';

  @override
  String get subscriptionUpgradeSubmitAction => 'Submit payment';

  @override
  String get subscriptionRenewSubmitAction => 'Submit renewal';

  @override
  String get subscriptionUpgradePaymentMethodSectionTitle =>
      'How would you like to pay?';

  @override
  String get subscriptionUpgradePaymentDetailsTitle => 'Payment details';

  @override
  String get subscriptionMobileMoneyProviderLabel => 'Mobile money provider';

  @override
  String get subscriptionMobileMoneyPhoneLabel => 'Mobile money number';

  @override
  String get subscriptionMobileMoneyMtn => 'MTN Mobile Money';

  @override
  String get subscriptionMobileMoneyAirtel => 'Airtel Money';

  @override
  String get subscriptionMobileMoneyMpesa => 'M-Pesa';

  @override
  String get subscriptionMobileMoneyVodacom => 'Vodacom M-Pesa';

  @override
  String get subscriptionMobileMoneyTigo => 'Tigo / Mixx by Yas';

  @override
  String get subscriptionMobileMoneyOrange => 'Orange Money';

  @override
  String get subscriptionMobileMoneyZamtel => 'Zamtel Kwacha';

  @override
  String get subscriptionMobileMoneyGovernment => 'Government payment portal';

  @override
  String get subscriptionBankNameLabel => 'Your bank name';

  @override
  String get subscriptionBankTransferDetailsTitle => 'Transfer to this account';

  @override
  String get subscriptionBankAccountNameLabel => 'Account name';

  @override
  String get subscriptionPlatformBankNameLabel => 'Bank';

  @override
  String get subscriptionBankBranchLabel => 'Branch';

  @override
  String get subscriptionBankAccountNumberLabel => 'Account number';

  @override
  String get subscriptionBankSwiftLabel => 'SWIFT / BIC';

  @override
  String get subscriptionBankIbanLabel => 'IBAN';

  @override
  String get subscriptionFxRateErrorMessage =>
      'Could not load exchange rate — amount shown in USD.';

  @override
  String get subscriptionCardHolderNameLabel => 'Name on card';

  @override
  String get subscriptionCardLastFourLabel => 'Last 4 digits';

  @override
  String get subscriptionPaymentReferenceHint =>
      'Transaction ID or receipt number';

  @override
  String get subscriptionProofRequiredMessage =>
      'Attach proof of payment for this method.';

  @override
  String get subscriptionUpgradeSubmittedMessage =>
      'Payment submitted. The platform team will review and activate your subscription.';

  @override
  String get subscriptionPaymentMethodBankTransfer => 'Bank transfer';

  @override
  String get subscriptionPaymentMethodMobileMoney => 'Mobile money';

  @override
  String get subscriptionPaymentMethodCreditCard => 'Credit card';

  @override
  String get subscriptionPaymentMethodDebitCard => 'Debit card';

  @override
  String get subscriptionPaymentMethodCash => 'Cash';

  @override
  String get subscriptionPaymentMethodOther => 'Other';

  @override
  String get navigationEmergencyLabel => 'Emergency';

  @override
  String get navigationEmergencyShortLabel => 'Emergency';

  @override
  String get navigationIcuLabel => 'Intensive care (ICU)';

  @override
  String get navigationIcuShortLabel => 'ICU';

  @override
  String get navigationHrLabel => 'Human resources';

  @override
  String get navigationHrShortLabel => 'HR';

  @override
  String get navigationGroupOverviewLabel => 'Overview';

  @override
  String get navigationGroupPatientAccessLabel => 'Patient intake';

  @override
  String get navigationGroupInpatientCareLabel => 'Inpatient care';

  @override
  String get navigationGroupClinicalServicesLabel => 'Clinical care';

  @override
  String get navigationGroupDiagnosticsMedicationLabel =>
      'Diagnostics & pharmacy';

  @override
  String get navigationGroupRevenueCycleLabel => 'Billing & revenue';

  @override
  String get navigationGroupFacilityOperationsLabel => 'Facility services';

  @override
  String get navigationGroupAdministrationLabel => 'Administration';

  @override
  String get navigationOpdLabel => 'Outpatient (OPD)';

  @override
  String get navigationOpdShortLabel => 'OPD';

  @override
  String get navigationTheaterLabel => 'Operating theater';

  @override
  String get navigationTheaterShortLabel => 'Theater';

  @override
  String get navigationCommunicationsLabel => 'Communications';

  @override
  String get navigationCommunicationsShortLabel => 'Comms';

  @override
  String get hrTitle => 'Human resources';

  @override
  String get navigationIntegrationsLabel => 'Integrations';

  @override
  String get navigationIntegrationsShortLabel => 'Integrations';

  @override
  String get navigationMortuaryLabel => 'Mortuary';

  @override
  String get navigationMortuaryShortLabel => 'Mortuary';

  @override
  String get navigationReportsLabel => 'Reports';

  @override
  String get navigationReportsShortLabel => 'Reports';

  @override
  String get navigationRoomsBedsLabel => 'Rooms & beds';

  @override
  String get navigationRoomsBedsShortLabel => 'Beds';

  @override
  String get navigationHousekeepingLabel => 'Housekeeping';

  @override
  String get navigationHousekeepingShortLabel => 'HK';

  @override
  String get theaterTitle => 'Theater';

  @override
  String get theaterDescription =>
      'Cases, readiness, room/team, anesthesia, and post-op handover.';

  @override
  String get theaterLoadingTitle => 'Loading theater';

  @override
  String get theaterLoadingBody => 'Loading theater cases...';

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
  String get theaterAllCasesSummaryLabel => 'All cases';

  @override
  String get theaterCaseIdColumnLabel => 'Case';

  @override
  String get theaterProcedureColumnLabel => 'Procedure';

  @override
  String get theaterResponsibleRoleColumnLabel => 'Owner';

  @override
  String get theaterSourceContextLabel => 'Source';

  @override
  String get theaterSourceEmergency => 'Emergency';

  @override
  String get theaterSourceOpd => 'OPD elective';

  @override
  String get theaterSourceIpd => 'Inpatient surgery';

  @override
  String get theaterOpenInIpdAction => 'Open in IPD';

  @override
  String get theaterOpenInEmergencyAction => 'Open in Emergency';

  @override
  String get theaterHandoverDestinationLabel => 'Recovery destination';

  @override
  String get theaterHandoverToWard => 'Ward';

  @override
  String get theaterHandoverToIcu => 'ICU';

  @override
  String get theaterHandoverToOpd => 'Day-case / OPD follow-up';

  @override
  String get theaterRoleNurse => 'Theater nurse';

  @override
  String get theaterRoleSurgeon => 'Surgeon';

  @override
  String get theaterRoleAnesthetist => 'Anesthetist';

  @override
  String get theaterRoleTeam => 'Theater team';

  @override
  String get theaterRoleCoordinator => 'Theater coordinator';

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
      'Case readiness, records, resources, and handover.';

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
  String get theaterPatientLabel => 'Patient';

  @override
  String get theaterPatientSearchHint => 'Search by name, MRN, or phone';

  @override
  String get theaterEncounterSearchHint => 'Select an active encounter';

  @override
  String get theaterEmergencyCaseLabel => 'Emergency case';

  @override
  String get theaterEmergencyCaseSearchHint => 'Link the active emergency case';

  @override
  String get theaterEmergencyCaseSelectPatientFirstHint =>
      'Select a patient first';

  @override
  String get theaterScheduleEmergencyHint =>
      'Link the active ED case for billing and handoff context.';

  @override
  String get theaterScheduleEmergencyPanelTitle => 'Emergency scheduling';

  @override
  String get theaterScheduledTimeLabel => 'Scheduled time';

  @override
  String get theaterOperatingRoomHint => 'Search operating theatre rooms';

  @override
  String get theaterSurgeonSearchHint => 'Search surgeons by name or staff ID';

  @override
  String get theaterAnesthetistSearchHint =>
      'Search anesthetists by name or staff ID';

  @override
  String get theaterProceduresSectionLabel => 'Procedures';

  @override
  String get theaterAddProcedureAction => 'Add procedure';

  @override
  String get theaterNoProceduresSelectedLabel =>
      'Add one or more procedures to bill for this case.';

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
  String get theaterScheduleCaseDialogBody =>
      'Select patient and encounter, then set schedule, team, and procedures.';

  @override
  String get theaterSchedulePatientContextSection => 'Patient context';

  @override
  String get theaterScheduleDetailsSection => 'Schedule and team';

  @override
  String get theaterScheduleBillingSection => 'Procedures and billing';

  @override
  String get theaterScheduleBillingSectionBody =>
      'Add procedures for line items. Bill later sends charges to Billing.';

  @override
  String get theaterEncounterSelectPatientFirstHint => 'Select a patient first';

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
  String get opdDescription => 'Arrivals, queues, and OPD clinical handoffs.';

  @override
  String get opdLoadingTitle => 'Loading OPD flow';

  @override
  String get opdLoadingBody => 'Loading OPD queue and encounters...';

  @override
  String get opdLiveStatus => 'Live sync';

  @override
  String get opdSavingStatus => 'Saving';

  @override
  String get opdStartWalkInAction => 'Start OPD encounter';

  @override
  String get opdStartEncounterAction => 'Start encounter';

  @override
  String get opdOpenActiveEncounterAction => 'Update encounter';

  @override
  String get opdStartEncounterTooltip => 'Create or continue an OPD encounter';

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
  String get opdProviderFilterLabel => 'Assigned staff';

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
  String get opdAllProvidersOption => 'All staff';

  @override
  String get opdAllBillingStatesOption => 'All billing states';

  @override
  String get opdAllNextActionsOption => 'All next actions';

  @override
  String get opdSummaryAllPatientsLabel => 'All Patients';

  @override
  String get opdSummaryAllOpdPatientsLabel => 'All OPD Patients';

  @override
  String get opdSummaryActiveOpdLabel => 'Active OPD';

  @override
  String get opdSummaryVitalsNeededLabel => 'Vitals needed';

  @override
  String get opdSummaryDoctorNeededLabel => 'Doctor needed';

  @override
  String get opdSummaryWithDoctorLabel => 'With doctor';

  @override
  String get opdSummaryLabPendingLabel => 'Lab pending';

  @override
  String get opdSummaryImagingPendingLabel => 'Imaging pending';

  @override
  String get opdSummaryPharmacyPendingLabel => 'Pharmacy pending';

  @override
  String get opdSummaryDecisionNeededLabel => 'Decision needed';

  @override
  String get opdSummaryAdmissionPendingLabel => 'Admission pending';

  @override
  String get opdSummaryDischargedTodayLabel => 'Discharged today';

  @override
  String get opdStatusPaymentDueLabel => 'Payment due';

  @override
  String get opdStatusVitalsNeededLabel => 'Vitals needed';

  @override
  String get opdStatusDoctorNeededLabel => 'Doctor needed';

  @override
  String get opdStatusWithDoctorLabel => 'With doctor';

  @override
  String get opdStatusDoctorReviewLabel => 'Doctor review';

  @override
  String get opdStatusLabPendingLabel => 'Lab pending';

  @override
  String get opdStatusSamplePendingLabel => 'Sample pending';

  @override
  String get opdStatusInLabLabel => 'In lab';

  @override
  String get opdStatusResultsReadyLabel => 'Results ready';

  @override
  String get opdStatusImagingPendingLabel => 'Imaging pending';

  @override
  String get opdStatusReportPendingLabel => 'Report pending';

  @override
  String get opdStatusReportReadyLabel => 'Report ready';

  @override
  String get opdStatusLabAndImagingPendingLabel => 'Lab & imaging pending';

  @override
  String get opdStatusPharmacyPendingLabel => 'Pharmacy pending';

  @override
  String get opdStatusDispensingLabel => 'Dispensing';

  @override
  String get opdStatusMedicinesDispensedLabel => 'Medicines dispensed';

  @override
  String get opdStatusDecisionNeededLabel => 'Decision needed';

  @override
  String get opdStatusAdmissionPendingLabel => 'Admission pending';

  @override
  String get opdStatusAdmittedLabel => 'Admitted';

  @override
  String get opdStatusDischargedLabel => 'Discharged';

  @override
  String get opdNextCollectSampleLabel => 'Collect sample';

  @override
  String get opdNextProcessLabLabel => 'Process lab';

  @override
  String get opdNextReviewResultsLabel => 'Review results';

  @override
  String get opdNextLabHandoffLabel => 'Lab handoff';

  @override
  String get opdNextPerformImagingLabel => 'Perform imaging';

  @override
  String get opdNextCompleteImagingReportLabel => 'Complete imaging report';

  @override
  String get opdNextReviewReportLabel => 'Review report';

  @override
  String get opdNextImagingHandoffLabel => 'Imaging handoff';

  @override
  String get opdNextDiagnosticsPendingLabel => 'Diagnostics pending';

  @override
  String get opdNextDispenseMedicineLabel => 'Dispense medicine';

  @override
  String get opdNextPharmacyHandoffLabel => 'Pharmacy handoff';

  @override
  String get opdNextDispositionLabel => 'Disposition';

  @override
  String get opdNextAdmissionHandoffLabel => 'Admission handoff';

  @override
  String get opdOpenAdmissionAction => 'Open inpatient admission';

  @override
  String get opdAdmissionHandoffTitle => 'Patient admitted';

  @override
  String get opdAdmissionHandoffBody =>
      'Admitted to IPD. Open inpatient care to assign a bed. OPD visit stays linked.';

  @override
  String get opdAdmissionHandoffStayAction => 'Stay in OPD';

  @override
  String get opdPhysiotherapyHandoffTitle => 'Physiotherapy referral placed';

  @override
  String get opdPhysiotherapyHandoffBody =>
      'Referred to physiotherapy. Open that workspace to accept and assess.';

  @override
  String get opdOpenPhysiotherapyAction => 'Open physiotherapy';

  @override
  String get opdSearchLabel => 'Search OPD';

  @override
  String get opdSearchHint => 'Search patient, identifier, or assigned staff';

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
  String get opdTableDescription =>
      'Arrivals, queue status, billing, and next steps.';

  @override
  String get opdProviderReadinessTitle => 'Staff readiness';

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
  String get opdNoProvidersTitle => 'No staff ready';

  @override
  String get opdNoProvidersBody =>
      'Staff schedules and available slots will appear here.';

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
  String get opdPatientColumnLabel => 'Patient name';

  @override
  String get opdCategoryColumnLabel => 'Category';

  @override
  String get opdStatusColumnLabel => 'Status';

  @override
  String get opdVisitTypeColumnLabel => 'Visit type';

  @override
  String get opdQueueStatusColumnLabel => 'Queue status';

  @override
  String get opdTimeColumnLabel => 'Arrival time';

  @override
  String get opdWaitingTimeColumnLabel => 'Wait time';

  @override
  String get opdProviderColumnLabel => 'Assigned staff';

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
  String get opdBillingRequiredAmountLabel => 'Required amount';

  @override
  String get opdBillingAmountPaidLabel => 'Amount paid';

  @override
  String get opdBillingRemainingBalanceLabel => 'Remaining balance';

  @override
  String get opdClinicalServicesTitle => 'Clinical services';

  @override
  String get opdClinicalServicesEmpty => 'No clinical services recorded yet.';

  @override
  String get opdEncounterDialogTitle => 'OPD Encounter';

  @override
  String get opdVisitJourneyLabel => 'Journey';

  @override
  String get opdClinicalServiceColumnLabel => 'Service';

  @override
  String get opdClinicalServiceRequestedColumnLabel => 'Requested';

  @override
  String get opdClinicalServiceStatusColumnLabel => 'Status';

  @override
  String get opdClinicalServiceLocationColumnLabel => 'Location';

  @override
  String get opdClinicalServiceResultColumnLabel => 'Result';

  @override
  String get opdClinicalServiceStatusPendingLabel => 'Pending';

  @override
  String get opdClinicalServiceStatusCompletedLabel => 'Completed';

  @override
  String get opdServiceLocationWaitingLabel => 'Waiting';

  @override
  String get opdServiceLocationInLabLabel => 'In lab';

  @override
  String get opdServiceLocationInRadiologyLabel => 'In radiology';

  @override
  String get opdServiceLocationAtPharmacyLabel => 'At pharmacy';

  @override
  String get opdServiceLocationLabQueueLabel => 'Lab queue';

  @override
  String get opdServiceLocationRadiologyQueueLabel => 'Radiology queue';

  @override
  String get opdServiceLocationPharmacyQueueLabel => 'Pharmacy queue';

  @override
  String get opdServiceLocationTriageLabel => 'Triage';

  @override
  String get opdServiceLocationConsultationLabel => 'Consultation';

  @override
  String get opdServiceLocationProcedureLabel => 'Procedure area';

  @override
  String get opdServiceLocationCompletedLabel => 'Completed';

  @override
  String get clinicalReferralDetailsTitle => 'Referral details';

  @override
  String get clinicalReferralNotesTitle => 'Additional notes';

  @override
  String get opdEncounterContextTitle => 'Encounter context';

  @override
  String get opdCopyPatientIdAction => 'Copy patient ID';

  @override
  String get opdCopyEncounterIdAction => 'Copy encounter ID';

  @override
  String get opdEncounterIdCopiedMessage => 'Encounter ID copied.';

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
  String get opdWalkInDialogTitle => 'Start OPD encounter';

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
      'Select an appointment to check the patient into OPD.';

  @override
  String get opdActiveEncounterCheckingLabel =>
      'Checking for an active OPD encounter...';

  @override
  String get opdActiveEncounterFoundTitle => 'Active OPD encounter found';

  @override
  String get opdActiveEncounterFoundBody =>
      'Active OPD encounter exists. Update it instead of creating a duplicate.';

  @override
  String get opdContinueEncounterAction => 'Continue encounter';

  @override
  String get opdCloseEncounterAction => 'Close encounter';

  @override
  String get opdCancelEncounterAction => 'Cancel encounter';

  @override
  String get opdCreatePatientAction => 'Create patient';

  @override
  String get opdEncounterCancelReasonPatientLeft =>
      'Patient left before consultation';

  @override
  String get opdEncounterCancelReasonDuplicate => 'Duplicate encounter';

  @override
  String get opdEncounterCancelReasonEnteredInError => 'Entered in error';

  @override
  String get opdEncounterCancelReasonAlreadySeen => 'Patient already seen';

  @override
  String get opdEncounterCancelReasonOther => 'Other';

  @override
  String get opdEncounterCloseReasonLabel => 'Close reason (optional)';

  @override
  String get opdEncounterCancelReasonCodeLabel => 'Cancellation reason';

  @override
  String get opdEncounterCancelReasonNotesLabel => 'Additional details';

  @override
  String get opdEncounterCancelReasonNotesRequiredMessage =>
      'Enter details when selecting Other.';

  @override
  String get opdEncounterBillingPaidBanner =>
      'Consultation payment is already recorded for this encounter.';

  @override
  String get opdEncounterArrivalModeLockedHelper =>
      'Arrival mode is fixed on an active encounter.';

  @override
  String get opdInactiveEncounterActionReason =>
      'Start or update an OPD encounter first.';

  @override
  String get opdSearchProviderLabel => 'Search doctor';

  @override
  String get opdSearchProviderHelper => 'This doctor will handle the patient.';

  @override
  String get opdNoProvidersHelper =>
      'No doctors found. Check doctor setup or permissions.';

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
  String get opdProviderIdLabel => 'Staff ID';

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
  String get opdCheckInAction => 'Start OPD encounter';

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
  String get opdChangeDoctorAction => 'Change doctor';

  @override
  String get opdPayConsultationAction => 'Pay consultation';

  @override
  String get opdManageConsultationBillingAction =>
      'Manage consultation billing';

  @override
  String get opdUpdateConsultationBillingAction =>
      'Update consultation billing';

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
  String get opdCurrentStageLabel => 'Current stage';

  @override
  String get opdTargetStageLabel => 'Target stage';

  @override
  String get opdStageCorrectionReasonRequiredMessage =>
      'Enter a reason for this stage correction.';

  @override
  String get opdExternalFacilityLabel => 'External facility';

  @override
  String get opdFollowUpDateLabel => 'Follow-up date';

  @override
  String get opdFollowUpTimeLabel => 'Follow-up time';

  @override
  String get opdDecisionLabel => 'Decision';

  @override
  String get opdRouteDecisionLabel => 'Route decision';

  @override
  String get opdArrivalModeLabel => 'Arrival mode';

  @override
  String get opdArrivalModeColumnLabel => 'Arrival mode';

  @override
  String get opdArrivalModeWalkInLabel => 'Walk-in';

  @override
  String get opdArrivalModeAppointmentLabel => 'Appointment';

  @override
  String get opdArrivalModeEmergencyLabel => 'Emergency';

  @override
  String get opdArrivalModeFollowUpLabel => 'Follow-up';

  @override
  String get opdEncounterColumnLabel => 'OPD encounter';

  @override
  String get opdEncounterIdLabel => 'Encounter ID';

  @override
  String get opdEmergencySeverityLabel => 'Emergency severity';

  @override
  String get opdTriageLevelLabel => 'Triage level';

  @override
  String get opdTriageLevel1Label => 'Level 1 · Immediate';

  @override
  String get opdTriageLevel2Label => 'Level 2 · Urgent';

  @override
  String get opdTriageLevel3Label => 'Level 3 · Less urgent';

  @override
  String get opdTriageLevel4Label => 'Level 4 · Non-urgent';

  @override
  String get opdTriageLevel5Label => 'Level 5 · Routine';

  @override
  String get opdTriagePendingLabel => 'Triage pending';

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
  String get patientsTableTitle => 'Patient records';

  @override
  String get patientsTableDescription =>
      'Registered patients, visit context, alerts, and actions.';

  @override
  String get patientsLoadingTitle => 'Loading patients';

  @override
  String get patientsLoadingBody => 'Loading patient registry data.';

  @override
  String get patientsStatusReady => 'Registry ready';

  @override
  String get patientsAddAction => 'Add patient';

  @override
  String get patientsRegisterPatientAction => 'Register patient';

  @override
  String get patientsRegisterNewPatientTitle => 'Register new patient';

  @override
  String get patientsRegisterNewPatientAction => 'Register patient';

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
  String get patientsPatientColumnLabel => 'Patient name';

  @override
  String get patientsPatientNumberColumnLabel => 'Patient no.';

  @override
  String get patientsAgeSexColumnLabel => 'Age / sex';

  @override
  String get patientsPhoneIdentifierColumnLabel => 'Phone';

  @override
  String get patientsAlertColumnLabel => 'Alerts';

  @override
  String get patientsVisitColumnLabel => 'Visit';

  @override
  String get patientsVisitIdLabel => 'Visit ID';

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
  String get patientsEmptyBody => 'Adjust filters or register a patient.';

  @override
  String get patientsDetailTitle => 'Patient details';

  @override
  String get patientsDetailLoadingTitle => 'Loading patient';

  @override
  String get patientsDetailLoadingBody =>
      'Loading demographics and related records...';

  @override
  String get patientsNoSelectionTitle => 'Select a patient';

  @override
  String get patientsNoSelectionBody =>
      'Open a patient for demographics and visits.';

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
  String get patientsFacilitySelectTenantFirstTooltip =>
      'Please select a tenant first.';

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
  String get patientsIdentifierValueSelectTypeFirstTooltip =>
      'Select an identifier type first.';

  @override
  String get patientsIdentifierTypeMrnLabel => 'Medical Record Number (MRN)';

  @override
  String get patientsIdentifierTypeNationalIdLabel =>
      'National ID (NATIONAL_ID)';

  @override
  String get patientsIdentifierTypePassportLabel => 'Passport (PASSPORT)';

  @override
  String get patientsIdentifierTypeInsuranceLabel => 'Insurance (INSURANCE)';

  @override
  String get patientsIdentifierTypeDriverLicenseLabel =>
      'Driver License (DRIVER_LICENSE)';

  @override
  String get patientsIdentifierTypeBirthCertificateLabel =>
      'Birth Certificate (BIRTH_CERTIFICATE)';

  @override
  String get patientsIdentifierTypeOtherLabel => 'Other (OTHER)';

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
      'Create a minimal record now; complete demographics after urgent care.';

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
  String get patientsQuickAppointmentAction => 'Schedule appointment';

  @override
  String get patientsQuickOpdCheckInAction => 'Start OPD encounter';

  @override
  String get patientsQuickViewActiveOpdAction => 'Continue OPD flow';

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
  String get patientsQuickLabOrderAction => 'Request lab';

  @override
  String get patientsQuickRadiologyOrderAction => 'Request radiology';

  @override
  String get patientsQuickTheaterScheduleAction => 'Schedule theater procedure';

  @override
  String get patientsQuickPhysiotherapyAction => 'Request physiotherapy';

  @override
  String get patientsQuickAdmitPatientAction => 'Request admission';

  @override
  String get patientsActiveWorkTitle => 'Active work';

  @override
  String get patientsActiveWorkContinueAction => 'Continue';

  @override
  String get patientsActiveWorkKindAppointment => 'Appointment';

  @override
  String get patientsActiveWorkKindEncounter => 'OPD encounter';

  @override
  String get patientsActiveWorkKindQueue => 'Visit queue';

  @override
  String get patientsActiveWorkKindAdmission => 'Inpatient admission';

  @override
  String get patientsActiveWorkKindAdmissionRequest => 'Admission request';

  @override
  String get patientsActiveWorkKindLabOrder => 'Lab order';

  @override
  String get patientsActiveWorkKindRadiologyOrder => 'Radiology order';

  @override
  String get patientsActiveWorkKindTherapy => 'Physiotherapy';

  @override
  String get patientsActiveWorkKindTheater => 'Theater case';

  @override
  String get patientsActiveWorkStatusEncounterOpen => 'Encounter open';

  @override
  String get patientsActiveWorkStatusEncounterInProgress =>
      'Encounter in progress';

  @override
  String get patientsActiveWorkStatusQueueWaiting => 'Waiting in queue';

  @override
  String get patientsActiveWorkStatusQueueInProgress => 'In queue';

  @override
  String get patientsActiveWorkStatusAppointmentScheduled => 'Scheduled';

  @override
  String get patientsActiveWorkStatusAppointmentInProgress =>
      'Check-in in progress';

  @override
  String get patientsActiveWorkStatusAdmissionActive => 'Admitted';

  @override
  String get patientsActiveWorkStatusAdmissionPendingBed => 'Bed pending';

  @override
  String get patientsActiveWorkStatusAdmissionTransfer =>
      'Transfer in progress';

  @override
  String get patientsActiveWorkStatusAdmissionDischargePlanned =>
      'Discharge planned';

  @override
  String get patientsQuickAppointmentTooltip => 'Schedule an appointment';

  @override
  String get patientsQuickOpdCheckInTooltip => 'Start a new OPD encounter';

  @override
  String get patientsQuickViewActiveOpdTooltip =>
      'Continue the active OPD encounter';

  @override
  String get patientsQuickAdmitPatientTooltip => 'Request IPD admission';

  @override
  String get patientsQuickDischargeTooltip =>
      'Continue discharge for the active admission';

  @override
  String get patientsQuickLabOrderTooltip => 'Request a lab order';

  @override
  String get patientsQuickRadiologyOrderTooltip => 'Request an imaging order';

  @override
  String get patientsQuickTheaterScheduleTooltip =>
      'Schedule a theater procedure';

  @override
  String get patientsQuickPhysiotherapyTooltip =>
      'Refer this patient to physiotherapy.';

  @override
  String get patientsQuickReportTooltip => 'Open patient summary report';

  @override
  String get accessDeniedPermissionRequired =>
      'You do not have permission to perform this action.';

  @override
  String get accessDeniedRoleRequired =>
      'Your role cannot perform this action.';

  @override
  String get accessDeniedTenantContextRequired =>
      'Select a tenant before using this action.';

  @override
  String get accessDeniedFacilityContextRequired =>
      'Select a facility before using this action.';

  @override
  String accessDeniedModuleRequired(String moduleName) {
    return 'The $moduleName module is not enabled for this facility.';
  }

  @override
  String get accessDeniedModuleInpatientLabel => 'Inpatient';

  @override
  String get accessDeniedModuleLabLabel => 'Laboratory';

  @override
  String get accessDeniedModuleRadiologyLabel => 'Radiology';

  @override
  String get accessDeniedModuleTheaterLabel => 'Theater';

  @override
  String get accessDeniedModulePhysiotherapyLabel => 'Physiotherapy';

  @override
  String patientsAgeYears(int years) {
    return '$years years';
  }

  @override
  String patientsAgeYearsMonths(int years, int months) {
    return '$years years, $months months';
  }

  @override
  String patientsAgeMonths(int months) {
    return '$months months';
  }

  @override
  String patientsAgeDays(int days) {
    return '$days days';
  }

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
  String get patientsOpdCheckInDialogTitle => 'Start OPD encounter';

  @override
  String get patientsTriageDialogTitle => 'Triage intake';

  @override
  String get patientsClinicalDialogTitle => 'Clinical visit';

  @override
  String get patientsBillingDialogTitle => 'Consultation billing';

  @override
  String get patientsAdmissionDialogTitle => 'Request admission';

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
  String get patientsPharmacyOrdersSectionTitle => 'Pharmacy orders';

  @override
  String get patientsNoPharmacyOrders =>
      'No pharmacy orders recorded for this patient.';

  @override
  String get patientsOpenPharmacyWorkbenchAction => 'Open pharmacy';

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
      'Prefer file upload. Use only for an existing stored document.';

  @override
  String get patientsDocumentUploadTitle => 'Document upload';

  @override
  String get patientsDocumentUploadEmpty =>
      'No file selected. PDF, JPG, or PNG up to 10 MB.';

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
      'Review matches before creating another record.';

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
      'Checking records for the retained patient...';

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
      'No duplicate, consent, or document alerts.';

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
      'Patient care, pharmacy, billing, diagnostics, and operations in one place.';

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
  String get homeLoadingTitle => 'Preparing dashboard';

  @override
  String get homeLoadingBody => 'Loading readiness.';

  @override
  String get homeTodayAtAGlanceTitle => 'Today at a glance';

  @override
  String homeMetricCardSemantics(String label, String value) {
    return '$label: $value. View details.';
  }

  @override
  String get homeOpenHrWorkspaceLink => 'Open HR workspace';

  @override
  String get homeMetricActiveStaffCompact => 'Active staff';

  @override
  String get homeMetricShiftsTodayCompact => 'Shifts today';

  @override
  String get homeMetricPendingLeavesCompact => 'Pending leave';

  @override
  String get homeMetricOnLeaveTodayCompact => 'On leave';

  @override
  String get homeMetricUnassignedShiftsCompact => 'Unassigned';

  @override
  String get homeMetricAttendedTodayCompact => 'Attended';

  @override
  String get homeMetricMissedShiftsTodayCompact => 'Missed shifts';

  @override
  String get homeMetricPayrollPendingCompact => 'Payroll pending';

  @override
  String get homeViewAllAction => 'View all';

  @override
  String get homeDashboardNextStepsTitle => 'Quick actions';

  @override
  String get homeDashboardQuickLinksTitle => 'Quick links';

  @override
  String get homePlatformManagementTitle => 'Platform management';

  @override
  String get homePlatformManagementDescription =>
      'Manage tenants, facilities, roles, and users.';

  @override
  String get homeManageUsersTitle => 'Manage users';

  @override
  String get homeManageRolesPermissionsTitle => 'Manage roles and permissions';

  @override
  String tenantFacilityDeleteTenantConfirmationBody(String name) {
    return 'Soft-delete tenant \"$name\"? Its facilities are soft-deleted too. You can restore later.';
  }

  @override
  String tenantFacilityDeleteFacilityConfirmationBody(String name) {
    return 'Soft-delete facility \"$name\"? Data is hidden in the app. You can restore later.';
  }

  @override
  String get homeTrendLast7Days => 'Last 7 days';

  @override
  String get homeTrendDefaultSubtitle =>
      'Role-focused changes over the latest reporting window.';

  @override
  String get homeTrendEmptyMessage => 'No trend data yet.';

  @override
  String get homeDistributionWorkforceMix => 'Staff availability mix';

  @override
  String get homeDistributionDefaultSubtitle =>
      'Live mix of the records behind this dashboard.';

  @override
  String get homeDistributionEmptyMessage => 'No distribution data yet.';

  @override
  String get homeLoadErrorTitle => 'Dashboard could not load';

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
  String get profileLoadingTitle => 'Loading profile';

  @override
  String get profileLoadingBody => 'Refreshing account and permissions...';

  @override
  String get profileRolesSectionTitle => 'Assigned roles';

  @override
  String get profileRolesSectionBody =>
      'Roles currently linked to your account.';

  @override
  String get profileRolesEmpty => 'No roles are assigned to this account.';

  @override
  String get profilePermissionsSectionTitle => 'Direct permissions';

  @override
  String get profilePermissionsSectionBody =>
      'Permissions granted directly to your account.';

  @override
  String get profilePermissionsEmpty =>
      'No direct permissions are assigned to this account.';

  @override
  String profileRoleCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count roles',
      one: '1 role',
      zero: 'No roles',
    );
    return '$_temp0';
  }

  @override
  String get profileChangePasswordActionTitle => 'Change password';

  @override
  String get profileEditActionTitle => 'Edit profile';

  @override
  String get profileEditDialogTitle => 'Edit profile';

  @override
  String get profileEditDialogBody =>
      'Update the name and demographic details stored in your user profile.';

  @override
  String get profileEditFirstNameLabel => 'First name';

  @override
  String get profileEditMiddleNameLabel => 'Middle name';

  @override
  String get profileEditLastNameLabel => 'Last name';

  @override
  String get profileEditGenderLabel => 'Gender';

  @override
  String get profileGenderMale => 'Male';

  @override
  String get profileGenderFemale => 'Female';

  @override
  String get profileGenderOther => 'Other';

  @override
  String get profileGenderUnknown => 'Unknown';

  @override
  String get profileSaveSuccessMessage => 'Profile updated.';

  @override
  String get profileSaveErrorMessage => 'Profile could not be updated.';

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
      'Choose English or French for the app interface.';

  @override
  String get settingsLanguageFieldLabel => 'App language';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageFrench => 'French';

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
  String get settingsAccessibilitySectionTitle => 'Accessibility';

  @override
  String get settingsAccessibilitySectionBody =>
      'Improve readability and reduce motion across clinical workspaces.';

  @override
  String get settingsReduceMotionLabel => 'Reduce motion';

  @override
  String get settingsReduceMotionDescription =>
      'Simpler transitions and fewer animations.';

  @override
  String get settingsBoldTextLabel => 'Bold text';

  @override
  String get settingsBoldTextDescription =>
      'Increase text weight for easier reading.';

  @override
  String get settingsTextScaleFieldLabel => 'Text size';

  @override
  String get settingsTextScaleNormal => 'Normal';

  @override
  String get settingsTextScaleLarge => 'Large';

  @override
  String get settingsTextScaleExtraLarge => 'Extra large';

  @override
  String get settingsSubscriptionsActionBody =>
      'Review plans, module entitlements, invoices, licenses, and renewal state.';

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
      'Loading organization and facility setup...';

  @override
  String get tenantFacilityHrSetupTitle => 'Facility structure for HR';

  @override
  String get tenantFacilityHrSetupBody =>
      'Maintain departments and units for staff onboarding and assignments.';

  @override
  String get tenantFacilityHrSetupDepartmentsBody =>
      'Departments group staff and rosters by service area.';

  @override
  String get tenantFacilityHrSetupUnitsBody =>
      'Units refine department coverage for shift and ward assignments.';

  @override
  String get tenantFacilityHrSetupManageAction => 'Manage';

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
  String get tenantFacilityChecklistDepartments => 'Departments are configured';

  @override
  String get tenantFacilityChecklistBranches =>
      'Branches are configured (optional)';

  @override
  String get tenantFacilityChecklistUnits => 'Units are configured (optional)';

  @override
  String get tenantFacilityChecklistWards => 'Wards are configured';

  @override
  String get tenantFacilityChecklistRooms => 'Rooms are configured';

  @override
  String get tenantFacilityChecklistBeds => 'Beds are configured';

  @override
  String get tenantFacilityChecklistLocations =>
      'Rooms, wards, or beds are configured';

  @override
  String get tenantFacilityWizardTitle => 'Guided setup';

  @override
  String get tenantFacilityWizardBody =>
      'Complete the main setup flow in order before daily operations begin.';

  @override
  String get tenantFacilityWizardStepTenant => 'Tenant profile';

  @override
  String get tenantFacilityWizardStepFacility => 'Facility identity';

  @override
  String get tenantFacilityWizardStepBranches => 'Branches';

  @override
  String get tenantFacilityWizardStepDepartments => 'Departments';

  @override
  String get tenantFacilityWizardStepUnits => 'Units';

  @override
  String get tenantFacilityWizardStepWards => 'Wards';

  @override
  String get tenantFacilityWizardStepRooms => 'Rooms';

  @override
  String get tenantFacilityWizardStepBeds => 'Beds';

  @override
  String get tenantFacilityWizardStepOrganization => 'Departments and units';

  @override
  String get tenantFacilityWizardStepCareSpaces => 'Wards, rooms, and beds';

  @override
  String get tenantFacilityWizardContinueAction => 'Continue setup';

  @override
  String get tenantFacilitySkipOptionalAction => 'Skip for now';

  @override
  String tenantFacilityContinueToStepAction(String step) {
    return 'Continue to $step';
  }

  @override
  String get tenantFacilityCreateBranchAction => 'Create branch';

  @override
  String get tenantFacilityManageBranchesAction => 'Manage branches';

  @override
  String get tenantFacilityCreateDepartmentAction => 'Create department';

  @override
  String get tenantFacilityManageDepartmentsAction => 'Manage departments';

  @override
  String get tenantFacilityCreateUnitAction => 'Create unit';

  @override
  String get tenantFacilityManageUnitsAction => 'Manage units';

  @override
  String get tenantFacilityCreateWardAction => 'Create ward';

  @override
  String get tenantFacilityManageWardsAction => 'Manage wards';

  @override
  String get tenantFacilityCreateRoomAction => 'Create room';

  @override
  String get tenantFacilityManageRoomsAction => 'Manage rooms';

  @override
  String get tenantFacilityCreateBedAction => 'Create bed';

  @override
  String get tenantFacilityManageBedsAction => 'Manage beds';

  @override
  String get tenantFacilityBranchesOptionalHint =>
      'Optional for single-site facilities. Skip when there is only one site.';

  @override
  String get tenantFacilityGateNeedFacility =>
      'Configure facility identity before adding departments.';

  @override
  String get tenantFacilityGateNeedTenant =>
      'Create or select a tenant before continuing setup.';

  @override
  String get tenantFacilityCatalogShortAction => 'Catalog';

  @override
  String get tenantFacilityDefaultCurrencyLabel => 'Default currency';

  @override
  String get tenantFacilityDefaultCurrencyHelper =>
      'Overrides the tenant default for prices and amount fields at this facility.';

  @override
  String get tenantFacilityTenantDefaultCurrencyHelper =>
      'Used as the default for facilities that do not set their own currency.';

  @override
  String get tenantFacilityGateNeedDepartmentForUnits =>
      'Create at least one department before adding units.';

  @override
  String get tenantFacilityGateNeedDepartmentForWards =>
      'Create at least one department before adding wards.';

  @override
  String get tenantFacilityGateNeedWardOrDepartmentForRooms =>
      'Create at least one department or ward before adding rooms.';

  @override
  String get tenantFacilityGateNeedWardsForBeds =>
      'Create at least one ward before adding beds.';

  @override
  String get tenantFacilityRoomWardOptionalHint =>
      'Leave unassigned for outpatient or department consult rooms.';

  @override
  String get tenantFacilityRoomOutpatientLabel =>
      'Outpatient / department area';

  @override
  String get tenantFacilityInvalidBranchSelection =>
      'Select a branch that belongs to this facility.';

  @override
  String get tenantFacilityInvalidDepartmentSelection =>
      'Select a department that belongs to this facility.';

  @override
  String get tenantFacilityInvalidWardSelection =>
      'Select a ward that belongs to this facility.';

  @override
  String get tenantFacilityInvalidRoomSelection =>
      'Select a room that belongs to this facility.';

  @override
  String get tenantFacilitySubscriptionSummaryTitle => 'Subscription status';

  @override
  String get tenantFacilitySubscriptionNoPlan => 'No active subscription';

  @override
  String tenantFacilitySubscriptionModulesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count active modules',
      one: '1 active module',
    );
    return '$_temp0';
  }

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
  String get tenantFacilitySaveTenantAction => 'Edit tenant';

  @override
  String get tenantFacilityCreateTenantTitle => 'Create tenant';

  @override
  String get tenantFacilityCreateTenantBody =>
      'Register a new organization on the platform.';

  @override
  String get tenantFacilityEditTenantTitle => 'Edit tenant';

  @override
  String get tenantFacilityCreateTenantAction => 'Create tenant';

  @override
  String get tenantFacilityCreateTenantPermissionRequired =>
      'You do not have permission to create tenants.';

  @override
  String get tenantFacilityTenantNameAlreadyInUse =>
      'Tenant name is already in use.';

  @override
  String get tenantFacilityTenantSlugAlreadyInUse =>
      'Tenant slug is already in use.';

  @override
  String get tenantFacilitySimilarTenantDialogTitle => 'Similar tenant found';

  @override
  String get tenantFacilitySimilarTenantDialogBody =>
      'Similar organizations exist. Review matches before continuing.';

  @override
  String get tenantFacilitySimilarTenantWarningTitle =>
      'Potential duplicate tenant';

  @override
  String get tenantFacilitySimilarTenantWarningBody =>
      'Review the similar tenants below before saving.';

  @override
  String tenantFacilitySimilarTenantScoreLabel(int score) {
    return '$score% match';
  }

  @override
  String get tenantFacilityProceedCreateTenantAction => 'Proceed anyway';

  @override
  String get tenantFacilityCreateFacilityTitle => 'Create facility';

  @override
  String get tenantFacilityEditFacilityTitle => 'Edit facility';

  @override
  String get tenantFacilityConfirmFacilityUpdateTitle =>
      'Confirm facility changes';

  @override
  String get tenantFacilityConfirmFacilityUpdateBody =>
      'Review the changes below, then confirm to update this facility.';

  @override
  String get tenantFacilityConfirmFacilityUpdateAction => 'Update facility';

  @override
  String get tenantFacilityFieldPreviousLabel => 'Previous';

  @override
  String get tenantFacilityFieldNewLabel => 'New';

  @override
  String get tenantFacilityLogoRemovedLabel => 'Logo removed';

  @override
  String get tenantFacilityLogoAddedLabel => 'New logo';

  @override
  String get tenantFacilityNoFacilityChangesMessage => 'No changes to save.';

  @override
  String get tenantFacilityFacilityNameAlreadyInUse =>
      'Facility name is already in use for this tenant.';

  @override
  String get tenantFacilitySimilarFacilityDialogTitle =>
      'Similar facility found';

  @override
  String get tenantFacilitySimilarFacilityDialogBody =>
      'Similar facilities exist for this tenant. Review matches before continuing.';

  @override
  String get tenantFacilitySimilarFacilityWarningTitle =>
      'Potential duplicate facility';

  @override
  String get tenantFacilitySimilarFacilityWarningBody =>
      'Review the similar facilities below before saving.';

  @override
  String tenantFacilitySimilarFacilityScoreLabel(int score) {
    return '$score% match';
  }

  @override
  String get tenantFacilityProceedCreateFacilityAction => 'Proceed anyway';

  @override
  String get tenantFacilitySelectTenantLoadError =>
      'Unable to load tenants. Check your connection and try again.';

  @override
  String get tenantFacilityFacilitySectionTitle => 'Facility profile';

  @override
  String get tenantFacilityFacilitySectionBody =>
      'Facility name, logo reference, contact details, address, type, and active state.';

  @override
  String get tenantFacilityLogoLabel => 'Facility logo';

  @override
  String get tenantFacilityLogoHelper =>
      'JPG, PNG, or WebP up to 5 MB. Crop, then save.';

  @override
  String get tenantFacilityChooseLogoAction => 'Choose image';

  @override
  String get tenantFacilityRemoveLogoAction => 'Remove';

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
  String get tenantFacilityEditFacilityAction => 'Edit facility';

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
  String get tenantFacilityManageTenantsTitle => 'Manage tenants';

  @override
  String get tenantFacilityTenantDetailsTitle => 'Tenant details';

  @override
  String get tenantFacilityTenantDetailsFacilitiesHeading => 'Facilities';

  @override
  String get tenantFacilityTenantDetailsNoFacilities =>
      'No facilities under this tenant.';

  @override
  String get tenantFacilityEditTenantAction => 'Edit tenant';

  @override
  String get tenantFacilityDeleteTenantAction => 'Delete tenant';

  @override
  String get tenantFacilityTenantDetailsIdLabel => 'ID';

  @override
  String get tenantFacilityTenantStatusLabel => 'Status';

  @override
  String get tenantFacilityTenantStatusActive => 'Active';

  @override
  String get tenantFacilityTenantStatusDeleted => 'Deleted';

  @override
  String get tenantFacilityRestoreTenantAction => 'Restore';

  @override
  String get tenantFacilityRestoreConfirmationTitle => 'Restore tenant';

  @override
  String tenantFacilityRestoreTenantConfirmationBody(String name) {
    return 'Restore tenant \"$name\"?';
  }

  @override
  String get tenantFacilityPermanentDeleteAction => 'Permanent delete';

  @override
  String get tenantFacilityPermanentDeleteConfirmationTitle =>
      'Permanent delete — irreversible';

  @override
  String tenantFacilityPermanentDeleteWarningBody(String name) {
    return 'WARNING: Permanently deleting \"$name\" will erase this tenant, all of its facilities, and all related data forever. This cannot be recovered.';
  }

  @override
  String tenantFacilityPermanentDeleteConfirmationBody(String name) {
    return 'Final confirmation: permanently delete tenant \"$name\", all facilities under it, and all related data? This action is irreversible and the data can never be recovered.';
  }

  @override
  String tenantFacilityPermanentDeleteConfirmFieldLabel(String name) {
    return 'Type \"$name\" to confirm permanent delete';
  }

  @override
  String get tenantFacilityPermanentDeleteConfirmAction => 'Permanent delete';

  @override
  String get tenantFacilityRestoreFacilityConfirmationTitle =>
      'Restore facility';

  @override
  String tenantFacilityRestoreFacilityConfirmationBody(String name) {
    return 'Restore facility \"$name\"?';
  }

  @override
  String get tenantFacilityRestoreStructureAction => 'Restore';

  @override
  String get tenantFacilityRestoreStructureTitle => 'Restore record';

  @override
  String tenantFacilityRestoreStructureBody(String name) {
    return 'Restore \"$name\"?';
  }

  @override
  String get tenantFacilityStructureDeletedStatus => 'Deleted';

  @override
  String get tenantFacilityStructureActiveStatus => 'Active';

  @override
  String get tenantFacilitySoftDeleteStructureTitle => 'Delete record';

  @override
  String tenantFacilitySoftDeleteStructureBody(String name) {
    return 'Soft-delete \"$name\"? Child records are hidden from pickers; still visible here to restore.';
  }

  @override
  String get tenantFacilitySoftDeleteUserTitle => 'Delete user';

  @override
  String tenantFacilitySoftDeleteUserBody(String name) {
    return 'Soft-delete user \"$name\"? Hidden from pickers; still visible here to restore.';
  }

  @override
  String get tenantFacilityRestoreUserTitle => 'Restore user';

  @override
  String tenantFacilityRestoreUserBody(String name) {
    return 'Restore user \"$name\"?';
  }

  @override
  String get accessAdminRestoreUserAction => 'Restore user';

  @override
  String get tenantFacilityPermanentDeleteFacilityConfirmationTitle =>
      'Permanent delete facility — irreversible';

  @override
  String tenantFacilityPermanentDeleteFacilityWarningBody(String name) {
    return 'WARNING: Permanently deleting \"$name\" will erase this facility and all related data forever. This cannot be recovered.';
  }

  @override
  String tenantFacilityPermanentDeleteFacilityConfirmationBody(String name) {
    return 'Final confirmation: permanently delete facility \"$name\" and all related data? This action is irreversible and the data can never be recovered.';
  }

  @override
  String get tenantFacilityManageFacilitiesTitle => 'Manage facilities';

  @override
  String get tenantFacilityFacilityDetailsTitle => 'Facility details';

  @override
  String get tenantFacilityFacilityDetailsUsersHeading => 'Users';

  @override
  String get tenantFacilityFacilityDetailsNoUsers =>
      'No users are assigned to this facility.';

  @override
  String get tenantFacilityFacilityDetailsNoLogo => 'No logo uploaded';

  @override
  String get tenantFacilityDetailsAddLogoAction => 'Add logo';

  @override
  String get tenantFacilityDetailsChangeLogoAction => 'Change logo';

  @override
  String get tenantFacilityDetailsRemoveLogoAction => 'Remove logo';

  @override
  String get tenantFacilityDetailsRemoveLogoTitle => 'Remove facility logo';

  @override
  String tenantFacilityDetailsRemoveLogoBody(String facilityName) {
    return 'Remove the logo for $facilityName? The image file will be deleted.';
  }

  @override
  String get tenantFacilityDetailsLogoUpdatedMessage =>
      'Facility logo updated.';

  @override
  String get tenantFacilityDetailsLogoRemovedMessage =>
      'Facility logo removed.';

  @override
  String get tenantFacilityFacilityDetailsStructureHeading => 'Structure';

  @override
  String get tenantFacilityFacilityDetailsContactHeading => 'Contact';

  @override
  String get tenantFacilityEditFacilityDetailsAction => 'Edit facility';

  @override
  String get tenantFacilityDeleteFacilityDetailsAction => 'Delete facility';

  @override
  String get tenantFacilityNoTenants => 'No tenants have been added.';

  @override
  String get tenantFacilityNoFacilities => 'No facilities have been added.';

  @override
  String get tenantFacilityAddTenantAction => 'Add tenant';

  @override
  String get tenantFacilityAddFacilityAction => 'Add facility';

  @override
  String get tenantFacilitySelectTenantLabel => 'Select tenant';

  @override
  String get commonAllLabel => 'All';

  @override
  String get commonTableEmptyLabel => 'No records';

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
      'Set up locations after facility identity and departments.';

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
  String get tenantFacilityBedStatusCleaning => 'Cleaning';

  @override
  String get tenantFacilityBedStatusMaintenance => 'Maintenance';

  @override
  String get tenantFacilityBedStatusBlocked => 'Blocked';

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
    return 'Email registered but not verified. Enter the code sent to $email.';
  }

  @override
  String get authVerifyEmailBodyNoEmail =>
      'Enter the verification code sent to your email.';

  @override
  String get authEmailVerifiedBody =>
      'Your account is verified. You can now sign in.';

  @override
  String get authEmailVerifiedAwaitingApprovalBody =>
      'Email verified. A platform admin will approve before you can sign in.';

  @override
  String get authAccountPendingApprovalMessage =>
      'Email verified. Awaiting platform approval before sign-in.';

  @override
  String get authTenantNameLabel => 'Organization name';

  @override
  String get authPhoneLabel => 'Phone';

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
      'Email registered but not verified. Enter the verification code to continue.';

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
      'No account for that email or phone. Check details or register.';

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
  String get authForgotPasswordTitle => 'Reset your password';

  @override
  String get authForgotPasswordBody =>
      'Enter your facility account email. We send reset instructions if it matches.';

  @override
  String get authForgotPasswordActionLabel => 'Forgot password?';

  @override
  String get authForgotPasswordSubmitLabel => 'Send reset instructions';

  @override
  String get authForgotPasswordTenantPrompt =>
      'Choose the workspace for this account.';

  @override
  String get authForgotPasswordSubmittedTitle => 'Check your email';

  @override
  String get authForgotPasswordSubmittedBody =>
      'If an account exists, we sent a reset link and six-digit code.';

  @override
  String get authResetPasswordWithCodeActionLabel => 'Enter reset code';

  @override
  String get authResetPasswordTitle => 'Choose a new password';

  @override
  String get authResetPasswordBody => 'Enter a new password for your account.';

  @override
  String get authResetPasswordCodeModeBody =>
      'Enter email, the six-digit code, and a new password.';

  @override
  String get authResetPasswordCodeLabel => 'Reset code';

  @override
  String get authResetPasswordCodeInvalidMessage =>
      'Enter the six-digit reset code from your email.';

  @override
  String get authResetPasswordActionLabel => 'Reset password';

  @override
  String get authResetPasswordMissingTokenMessage =>
      'Reset link missing or invalid. Request a new one from sign-in.';

  @override
  String get authResetPasswordCompletedTitle => 'Password updated';

  @override
  String get authResetPasswordCompletedBody =>
      'Your password has been changed. Sign in with the new password.';

  @override
  String get authResetPasswordInvalidTokenMessage =>
      'Reset link expired or invalid. Request a new one.';

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
  String validationFieldRequiredMessage(String field) {
    return '$field is required.';
  }

  @override
  String validationFieldInvalidMessage(String field) {
    return 'Enter a valid $field.';
  }

  @override
  String validationFieldInvalidFormatMessage(String field) {
    return 'Use a valid $field format.';
  }

  @override
  String validationFieldAlreadyInUseMessage(String field) {
    return '$field is already in use.';
  }

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
  String get navigationClinicalLabel => 'Clinical (Doctors)';

  @override
  String get navigationClinicalShortLabel => 'Clinical';

  @override
  String get clinicalTitle => 'Clinical workspace';

  @override
  String get clinicalDescription =>
      'Document care, order services, prescribe, refer, and admit.';

  @override
  String get clinicalLoadingTitle => 'Loading clinical workspace';

  @override
  String get clinicalLoadingBody => 'Loading clinical worklist...';

  @override
  String get clinicalLiveStatus => 'Live sync';

  @override
  String get clinicalSavingStatus => 'Saving';

  @override
  String get clinicalSavedMessage => 'Clinical changes saved.';

  @override
  String get clinicalPatientIdCopiedMessage => 'Patient ID copied.';

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
  String get clinicalAllScopeLabel => 'All active work';

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
      'Consultations, admissions, triage, and result review.';

  @override
  String get clinicalStepColumnLabel => 'Current step';

  @override
  String get clinicalNotAssignedLabel => 'Not assigned';

  @override
  String get clinicalNoWorklistTitle => 'No clinical work';

  @override
  String get clinicalNoWorklistBody =>
      'No encounters match the current search and queue scope.';

  @override
  String get clinicalNoSelectionTitle => 'No encounter selected';

  @override
  String get clinicalNoSelectionBody =>
      'Open a patient to document care and place orders.';

  @override
  String get clinicalSourceQueueLabel => 'Queue';

  @override
  String get clinicalEncounterQueueLabel => 'Encounter queue';

  @override
  String get clinicalLastUpdatedLabel => 'Last updated';

  @override
  String get clinicalEncounterNumberLabel => 'Encounter';

  @override
  String get clinicalAdmissionNumberLabel => 'Admission';

  @override
  String get clinicalEncounterTypeLabel => 'Encounter type';

  @override
  String get clinicalAgeLabel => 'Age';

  @override
  String get clinicalLocationLabel => 'Location';

  @override
  String get clinicalActionsTitle => 'Clinical actions';

  @override
  String get clinicalAddNoteAction => 'Add clinical note';

  @override
  String get clinicalAddNoteTitle => 'Add patient clinical note';

  @override
  String get clinicalAddDiagnosisAction => 'Add diagnosis';

  @override
  String get clinicalDiagnosisSearchLabel => 'Search diagnosis';

  @override
  String get clinicalDiagnosisSearchHint =>
      'Search by diagnosis name, code, type, status, or source';

  @override
  String get clinicalCatalogSourceAll => 'All sources';

  @override
  String get clinicalCatalogSourceFavorites => 'Favorites';

  @override
  String get clinicalCatalogSourceFacility => 'Facility';

  @override
  String get clinicalCatalogSourceGlobal => 'Global catalog';

  @override
  String get clinicalCatalogConfigurationTitle => 'Clinical service catalog';

  @override
  String get clinicalCatalogConfigurationBody =>
      'Choose diagnoses, procedures, lab, imaging, and prescriptions for this facility.';

  @override
  String get clinicalDiagnosisSelectedTitle => 'Selected diagnoses';

  @override
  String clinicalDiagnosisSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String get clinicalDiagnosisNoSelection => 'No diagnoses selected';

  @override
  String clinicalDiagnosisMatchesLabel(int shown, int total) {
    return 'Showing $shown of $total matches';
  }

  @override
  String get clinicalDiagnosisNoCatalogOptions => 'No matching diagnosis terms';

  @override
  String get clinicalRequestLabAction => 'Request lab';

  @override
  String get clinicalUpdateLabOrderAction => 'Update lab order';

  @override
  String get clinicalLabRequestTestsModeLabel => 'Individual tests';

  @override
  String get clinicalLabRequestPanelsModeLabel => 'Lab panels';

  @override
  String get clinicalLabRequestSearchLabel => 'Search lab catalog';

  @override
  String get clinicalLabRequestSearchHint =>
      'Search by name, code, category, specimen, or status';

  @override
  String get clinicalLabRequestSelectedTitle => 'Selected lab requests';

  @override
  String clinicalLabRequestSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String get clinicalLabRequestNoSelection => 'No lab requests selected';

  @override
  String get clinicalLabRequestAddSelectionAction => 'Add';

  @override
  String get clinicalLabRequestUpdateSelectionAction => 'Update';

  @override
  String get clinicalLabRequestCancelEditAction => 'Cancel edit';

  @override
  String get clinicalLabRequestEditSelectionAction => 'Edit';

  @override
  String get clinicalLabRequestDeleteSelectionAction => 'Delete';

  @override
  String get clinicalLabRequestTestTypeLabel => 'Test';

  @override
  String get clinicalLabRequestPanelTypeLabel => 'Panel';

  @override
  String clinicalLabRequestMatchesLabel(int shown, int total) {
    return 'Showing $shown of $total matches';
  }

  @override
  String get clinicalLabRequestNoCatalogOptions =>
      'No matching lab catalog items';

  @override
  String get clinicalLabOrdersTitle => 'Lab orders';

  @override
  String get clinicalLabOrdersBody => 'Requested lab orders for this patient.';

  @override
  String get clinicalNoLabOrdersLabel =>
      'No lab orders have been requested for this patient.';

  @override
  String get clinicalLabOrderTestsLabel => 'Requested lab tests';

  @override
  String get clinicalLabOrderPanelsLabel => 'Requested lab panels';

  @override
  String get clinicalNoLabOrderTestsLabel => 'No requested lab tests recorded.';

  @override
  String get clinicalNoLabOrderPanelsLabel =>
      'No requested lab panels recorded.';

  @override
  String clinicalLabOrderItemCount(int count) {
    return '$count tests';
  }

  @override
  String clinicalLabOrderSampleCount(int count) {
    return '$count samples';
  }

  @override
  String get clinicalEditLabOrderAction => 'Edit order';

  @override
  String get clinicalCancelLabOrderAction => 'Cancel order';

  @override
  String get clinicalDeleteLabOrderAction => 'Delete order';

  @override
  String get clinicalCancelLabOrderDialogTitle => 'Cancel lab order';

  @override
  String get clinicalCancelLabOrderDialogBody =>
      'Cancel this lab order and mark its requested tests as cancelled?';

  @override
  String get clinicalDeleteLabOrderDialogTitle => 'Delete lab order';

  @override
  String get clinicalDeleteLabOrderDialogBody =>
      'Delete this lab order from the active patient record?';

  @override
  String get clinicalRadiologyOrdersTitle => 'Radiology orders';

  @override
  String get clinicalCancelRadiologyOrderAction => 'Cancel order';

  @override
  String get clinicalDeleteRadiologyOrderAction => 'Delete order';

  @override
  String get clinicalCancelRadiologyOrderDialogTitle =>
      'Cancel radiology order';

  @override
  String get clinicalCancelRadiologyOrderDialogBody =>
      'Cancel this radiology order and mark it as cancelled?';

  @override
  String get clinicalDeleteRadiologyOrderDialogTitle =>
      'Delete radiology order';

  @override
  String get clinicalDeleteRadiologyOrderDialogBody =>
      'Delete this radiology order from the active patient record?';

  @override
  String clinicalRadiologyOrderItemCount(int count) {
    return '$count tests';
  }

  @override
  String get clinicalPharmacyOrdersTitle => 'Pharmacy orders';

  @override
  String clinicalPharmacyOrderItemCount(int count) {
    return '$count medicines';
  }

  @override
  String get clinicalCancelPharmacyOrderAction => 'Cancel order';

  @override
  String get clinicalDeletePharmacyOrderAction => 'Delete order';

  @override
  String get clinicalCancelPharmacyOrderDialogTitle => 'Cancel pharmacy order';

  @override
  String get clinicalCancelPharmacyOrderDialogBody =>
      'Cancel this pharmacy order and mark it as cancelled?';

  @override
  String get clinicalDeletePharmacyOrderDialogTitle => 'Delete pharmacy order';

  @override
  String get clinicalDeletePharmacyOrderDialogBody =>
      'Delete this pharmacy order from the active patient record?';

  @override
  String get clinicalRequestRadiologyAction => 'Request radiology';

  @override
  String get clinicalRadiologyRequestSearchLabel => 'Search radiology catalog';

  @override
  String get clinicalRadiologyRequestSearchHint =>
      'Search by test, intervention, modality, region, code, or priority';

  @override
  String get clinicalRadiologyRequestSelectedTitle =>
      'Selected radiology requests';

  @override
  String clinicalRadiologyRequestSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String get clinicalRadiologyRequestNoSelection =>
      'No radiology requests selected';

  @override
  String get clinicalRadiologyAddSelectionAction => 'Add';

  @override
  String get clinicalRadiologyUpdateSelectionAction => 'Update';

  @override
  String get clinicalRadiologyCancelEditAction => 'Cancel edit';

  @override
  String get clinicalRadiologyEditSelectionAction => 'Edit';

  @override
  String get clinicalRadiologyDeleteSelectionAction => 'Delete';

  @override
  String clinicalRadiologyRequestMatchesLabel(int shown, int total) {
    return 'Showing $shown of $total matches';
  }

  @override
  String get clinicalRadiologyRequestNoCatalogOptions =>
      'No matching radiology catalog items';

  @override
  String get clinicalRadiologyCatalogSelectTitle => 'Radiology catalog';

  @override
  String get clinicalRadiologyCatalogSelectBody =>
      'Select an imaging test, then add it to the request.';

  @override
  String get clinicalRadiologyCatalogSelectLabel => 'Imaging test';

  @override
  String get clinicalRadiologyCatalogSelectHint =>
      'Search and select an imaging test';

  @override
  String get clinicalRadiologyDuplicateSelectionMessage =>
      'This imaging request is already selected.';

  @override
  String get clinicalRadiologyPriorityLabel => 'Priority';

  @override
  String get clinicalRadiologyLateralityLabel => 'Laterality';

  @override
  String get clinicalRadiologyBodyRegionLabel => 'Body region';

  @override
  String get clinicalPrescribeAction => 'Prescribe';

  @override
  String get clinicalPrescriptionHeaderTitle => 'Build prescription';

  @override
  String get clinicalPrescriptionHeaderBody =>
      'Add one or more medicines, then send them together to pharmacy.';

  @override
  String get clinicalPrescriptionDrugLabel => 'Available drug';

  @override
  String get clinicalPrescriptionMedicineLabel => 'Medicine';

  @override
  String get clinicalPrescriptionItemDescription =>
      'Select a drug and complete prescription details.';

  @override
  String get clinicalPrescriptionQuantityUnitLabel => 'Quantity unit';

  @override
  String get clinicalPrescriptionAddMedicineAction => 'Add medicine';

  @override
  String get clinicalPrescriptionRemoveMedicineAction => 'Remove medicine';

  @override
  String get clinicalRequestProcedureAction => 'Record procedure';

  @override
  String get clinicalProcedureDialogHelp =>
      'Search the catalog, add procedures, then save together.';

  @override
  String get clinicalProcedureSearchLabel => 'Procedure or minor surgery';

  @override
  String get clinicalProcedureSearchHint =>
      'Search by name, body area, or minor surgery type';

  @override
  String get clinicalProcedureCodeSearchHint => 'Search by procedure code';

  @override
  String get clinicalProcedureSelectedTitle => 'Selected procedures';

  @override
  String clinicalProcedureSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String get clinicalProcedureNoSelection => 'No procedures selected';

  @override
  String get clinicalCarePlanAction => 'Care plan';

  @override
  String get clinicalRequestAdmissionAction => 'Request admission';

  @override
  String get clinicalCompleteConsultationAction => 'Complete consultation';

  @override
  String get clinicalCompleteDispositionAction => 'Complete disposition';

  @override
  String get clinicalPrintSummaryAction => 'Print summary';

  @override
  String clinicalEncounterDetailsTitle(String patientName) {
    return '$patientName — Clinical details';
  }

  @override
  String clinicalEncounterDetailsSubtitle(String encounterId, String queue) {
    return '$encounterId · $queue';
  }

  @override
  String get clinicalCurrentStageLabel => 'Current stage';

  @override
  String get clinicalWorkflowProgressLabel => 'Workflow progress';

  @override
  String get clinicalOrderTestColumnLabel => 'Order / test';

  @override
  String get clinicalOrderValueColumnLabel => 'Value';

  @override
  String get clinicalResultFlagColumnLabel => 'Result';

  @override
  String get clinicalOrderCategoryColumnLabel => 'Category / specimen';

  @override
  String get clinicalOrderStudyColumnLabel => 'Study';

  @override
  String get clinicalOrderEmptyValueLabel => '—';

  @override
  String get clinicalResultReviewTitle => 'Result review';

  @override
  String get clinicalResultReviewBody =>
      'Released diagnostic results are ready for clinical review.';

  @override
  String get clinicalNoResultsReadyBody =>
      'No released lab or radiology results are ready for review.';

  @override
  String get clinicalPatientNotesTitle => 'Patient clinical notes';

  @override
  String get clinicalNoPatientNotesLabel =>
      'No patient clinical notes have been recorded yet.';

  @override
  String get clinicalDiagnosesTitle => 'Diagnoses';

  @override
  String get clinicalPatientDiagnosesTitle => 'Patient diagnoses';

  @override
  String get clinicalNoPatientDiagnosesLabel =>
      'No diagnoses have been recorded for this patient yet.';

  @override
  String get clinicalDiagnosisFormTitle => 'Diagnosis details';

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
  String get clinicalAdmissionDetailsTitle => 'Admission details';

  @override
  String get clinicalAdmissionWardLabel => 'Ward';

  @override
  String get clinicalAdmissionRoomLabel => 'Room';

  @override
  String get clinicalAdmissionBedLabel => 'Bed';

  @override
  String get clinicalAdmissionAvailabilityLabel => 'Bed availability';

  @override
  String get clinicalAdmissionNoBedsTitle => 'No available beds';

  @override
  String get clinicalAdmissionNoBedsMessage =>
      'No available beds found. Refresh bed availability before requesting admission.';

  @override
  String get clinicalAdmissionNoRoomsMessage =>
      'No rooms with available beds match this ward.';

  @override
  String get clinicalAdmissionNoBedsForRoomMessage =>
      'No available beds match this room.';

  @override
  String get clinicalAdmissionNoWardsHelper =>
      'No wards with available beds for this facility.';

  @override
  String get clinicalAdmissionSelectWardFirstHint => 'Select a ward first.';

  @override
  String get clinicalAdmissionSelectRoomFirstHint => 'Select a room first.';

  @override
  String get clinicalAdmissionBedUnavailableMessage =>
      'This bed is no longer available. Please choose another bed.';

  @override
  String get clinicalDispositionReasonLabel => 'Disposition reason';

  @override
  String get clinicalConsultationSummaryTitle => 'Consultation summary';

  @override
  String get navigationIpdLabel => 'Inpatient (IPD)';

  @override
  String get navigationIpdShortLabel => 'IPD';

  @override
  String get ipdTitle => 'Inpatient workspace';

  @override
  String get ipdDescription =>
      'Admissions, beds, transfers, rounds, and discharge readiness.';

  @override
  String get ipdLoadingTitle => 'Loading inpatient workspace';

  @override
  String get ipdLoadingBody => 'Loading admissions, beds, and wards...';

  @override
  String get ipdLiveStatus => 'Live sync';

  @override
  String get ipdSavingStatus => 'Saving';

  @override
  String get ipdSavedMessage => 'Inpatient changes saved.';

  @override
  String get ipdAdmissionQueueSummaryLabel => 'Pending admissions';

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
      'Waiting admissions, bedded patients, transfers, and discharge.';

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
      'Bed, transfers, rounds, meds, nursing notes, and discharge.';

  @override
  String get ipdNoSelectionTitle => 'No admission selected';

  @override
  String get ipdNoSelectionBody => 'Open an admission to manage IPD care.';

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
  String get ipdApproveAdmissionAction => 'Approve admission';

  @override
  String get ipdApproveAdmissionBody =>
      'Approve admission? Patient moves to IPD; assign a bed next.';

  @override
  String get ipdReleaseBedAction => 'Release bed';

  @override
  String get ipdRejectAdmissionAction => 'Reject admission';

  @override
  String get ipdRequestTransferAction => 'Request transfer';

  @override
  String get ipdRequestTherapyAction => 'Request physiotherapy';

  @override
  String get ipdOpenPhysiotherapyAction => 'Open physiotherapy';

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
  String get ipdPharmacyClearanceLabel => 'Pharmacy clearance';

  @override
  String get ipdPharmacyClearanceCleared => 'Cleared';

  @override
  String ipdPharmacyClearancePending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count open orders',
      one: '1 open order',
    );
    return '$_temp0';
  }

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
  String get ipdScopeAdmissionQueue => 'Pending admissions';

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
  String get ipdStatusAdmissionRequested => 'Admission requested';

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
  String get ipdBedStatusCleaning => 'Cleaning';

  @override
  String get ipdBedStatusMaintenance => 'Maintenance';

  @override
  String get ipdBedStatusBlocked => 'Blocked';

  @override
  String get ipdPatientBoardTab => 'Patient board';

  @override
  String get ipdBedBoardTab => 'Bed board';

  @override
  String get ipdBedBoardTitle => 'Bed board';

  @override
  String get ipdBedBoardDescription =>
      'Live ward bed occupancy and operations.';

  @override
  String get ipdBedBoardSearchLabel => 'Search beds';

  @override
  String get ipdBedBoardSearchHint => 'Search by bed, ward, room, or patient';

  @override
  String get ipdBedBoardEmptyTitle => 'No beds match';

  @override
  String get ipdBedBoardEmptyBody =>
      'Adjust ward or status filters to see beds.';

  @override
  String get ipdBedColumnLabel => 'Bed';

  @override
  String get ipdWardColumnLabel => 'Ward';

  @override
  String get ipdRoomColumnLabel => 'Room';

  @override
  String get ipdCurrentPatientColumnLabel => 'Current patient';

  @override
  String get ipdNextActionColumnLabel => 'Next action';

  @override
  String get ipdBedStatusFilterLabel => 'Bed status';

  @override
  String get ipdBedBoardManageBedsAction => 'Manage beds';

  @override
  String get ipdBedActionReserve => 'Reserve bed';

  @override
  String get ipdBedActionMarkAvailable => 'Mark available';

  @override
  String get ipdBedActionMarkCleaning => 'Send for cleaning';

  @override
  String get ipdBedActionBlock => 'Block bed';

  @override
  String get ipdBedActionMaintenance => 'Mark maintenance';

  @override
  String get ipdBedActionReturnToService => 'Return to service';

  @override
  String get ipdBedActionOpenAdmission => 'Open admission';

  @override
  String get ipdBedNoActionLabel => 'No action';

  @override
  String get ipdStartAdmissionAction => 'Start admission';

  @override
  String get ipdStartAdmissionTitle => 'Start admission';

  @override
  String get ipdStartAdmissionPatientLabel => 'Patient';

  @override
  String get ipdStartAdmissionPatientHint => 'Search patient by name or ID';

  @override
  String get ipdStartAdmissionNoPatients => 'No matching patients';

  @override
  String get ipdStartAdmissionWardLabel => 'Recommended ward (optional)';

  @override
  String get ipdStartAdmissionBedLabel => 'Bed (optional)';

  @override
  String get ipdLengthOfStayColumnLabel => 'Length of stay';

  @override
  String ipdLengthOfStayDays(int count) {
    return '${count}d';
  }

  @override
  String ipdLengthOfStayHours(int count) {
    return '${count}h';
  }

  @override
  String get ipdDischargeStatusPlanned => 'Planned';

  @override
  String get ipdDischargeStatusCompleted => 'Completed';

  @override
  String get ipdManageDischargeTitle => 'Manage discharge';

  @override
  String get ipdDischargeClearanceTitle => 'Discharge clearance';

  @override
  String get ipdDischargeClearancePhaseLabel => 'Clearance phase';

  @override
  String get ipdPendingOrdersTitle => 'Pending orders';

  @override
  String get ipdClearancePendingOrders => 'Pending orders reviewed';

  @override
  String get ipdClearancePharmacy => 'Pharmacy clearance';

  @override
  String get ipdClearanceBilling => 'Billing clearance';

  @override
  String get ipdClearanceNursing => 'Nursing clearance';

  @override
  String get ipdClearanceDocuments => 'Documents ready';

  @override
  String get ipdClearancePatientExit => 'Patient exited';

  @override
  String get ipdDischargeOverrideLabel => 'Authorized override reason';

  @override
  String get ipdDischargeOverrideHint =>
      'Required only when clearing with incomplete steps';

  @override
  String get ipdSaveClearanceAction => 'Save clearance';

  @override
  String get ipdClearancePhaseSummaryPending => 'Summary pending';

  @override
  String get ipdClearancePhasePendingOrders => 'Pending orders review';

  @override
  String get ipdClearancePhaseMedication => 'Medication pending';

  @override
  String get ipdClearancePhaseBilling => 'Billing pending';

  @override
  String get ipdClearancePhaseNursing => 'Nursing clearance pending';

  @override
  String get ipdClearancePhaseDocuments => 'Documents pending';

  @override
  String get ipdClearancePhasePatientExit => 'Patient exit pending';

  @override
  String get ipdClearancePhaseReadyForExit => 'Ready for exit';

  @override
  String get ipdOrderLabAction => 'Order lab';

  @override
  String get ipdOrderRadiologyAction => 'Order radiology';

  @override
  String get ipdOrderPrescriptionAction => 'Prescribe medication';

  @override
  String get ipdOpenNursingAction => 'Open nursing workspace';

  @override
  String get ipdSourceContextTitle => 'Admission source';

  @override
  String get ipdSourceKindLabel => 'Source';

  @override
  String get ipdEncounterTypeLabel => 'Encounter type';

  @override
  String get ipdSourceKindOpd => 'OPD handoff';

  @override
  String get ipdSourceKindEmergency => 'Emergency admission';

  @override
  String get ipdSourceKindReferral => 'Referral';

  @override
  String get ipdSourceKindDirect => 'Direct admission';

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
  String get navigationNursingShortLabel => 'Nursing';

  @override
  String get nursingTitle => 'Nursing';

  @override
  String get nursingDescription =>
      'Ward queues, observations, MAR, handovers, and escalation.';

  @override
  String get nursingLoadingTitle => 'Loading nursing workspace';

  @override
  String get nursingLoadingBody => 'Loading ward patients and handovers...';

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
      'Observations, medication, handover, transfer, or discharge.';

  @override
  String get nursingNoWorklistTitle => 'No nursing work';

  @override
  String get nursingNoWorklistBody =>
      'No ward patients match the current search and queue scope.';

  @override
  String get nursingNoSelectionTitle => 'No ward patient selected';

  @override
  String get nursingNoSelectionBody =>
      'Open a patient for observations, MAR, and handovers.';

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
  String get nursingActionPrintSummary => 'Print nursing summary';

  @override
  String get nursingReportTitle => 'Nursing care summary';

  @override
  String get nursingReportFooter =>
      'Generated from the nursing report template for clinical audit.';

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
      'Verify patient, medication, dose, route, and time.';

  @override
  String get nursingHandoverToUserLabel => 'Recipient';

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
  String get nursingAdvancedFiltersLabel => 'Filters';

  @override
  String get nursingAdvancedFiltersTitle => 'Nursing worklist filters';

  @override
  String get nursingApplyFiltersLabel => 'Apply filters';

  @override
  String get nursingResetFiltersLabel => 'Reset filters';

  @override
  String get nursingSearchFieldLabel => 'Search fields';

  @override
  String get nursingAllFieldsLabel => 'All';

  @override
  String get nursingDateFilterLabel => 'Due or observation date';

  @override
  String get nursingDateFromLabel => 'From';

  @override
  String get nursingDateToLabel => 'To';

  @override
  String get nursingDatePickerLabel => 'Choose date';

  @override
  String get nursingInvalidDateMessage => 'Enter a valid date.';

  @override
  String get nursingPatientFilterLabel => 'Patient';

  @override
  String get nursingPatientFilterHint =>
      'Name, number, admission, or encounter';

  @override
  String get nursingUnitFilterLabel => 'Unit';

  @override
  String get nursingUnitFilterHint => 'Ward, ICU, recovery, or unit';

  @override
  String get nursingShiftFilterLabel => 'Shift';

  @override
  String get nursingShiftFilterHint =>
      'Morning, evening, night, or current shift';

  @override
  String get nursingCareTaskFilterLabel => 'Care task';

  @override
  String get nursingCareTaskFilterHint =>
      'Vitals, medication, handover, transfer, or discharge';

  @override
  String get nursingAdmissionStatusFilterLabel => 'Admission status';

  @override
  String get nursingAdmissionStatusFilterHint =>
      'Active, admitted, transfer, or discharge status';

  @override
  String get nursingDischargeReadinessFilterLabel => 'Discharge readiness';

  @override
  String get nursingDischargeReadinessFilterHint =>
      'Planned, pending, ready, or blocked';

  @override
  String get nursingPriorityFilterLabel => 'Priority';

  @override
  String get nursingPriorityHighLabel => 'High';

  @override
  String get nursingPriorityMediumLabel => 'Medium';

  @override
  String get nursingPriorityRoutineLabel => 'Routine';

  @override
  String get nursingAdmissionColumnLabel => 'Admission';

  @override
  String get nursingTaskTypeColumnLabel => 'Task type';

  @override
  String get nursingPriorityColumnLabel => 'Priority';

  @override
  String get nursingDueTimeColumnLabel => 'Due time';

  @override
  String get nursingResponsibleNurseColumnLabel => 'Responsible nurse';

  @override
  String get nursingDueNowLabel => 'Now';

  @override
  String get nursingAssignedShiftLabel => 'Assigned shift';

  @override
  String get nursingWardAdmissionChecklistTitle => 'Ward admission checklist';

  @override
  String get nursingWardAdmissionChecklistDescription =>
      'Bed, handover, observations, care plan, meds, and discharge.';

  @override
  String get nursingChecklistCompleteStatus => 'Complete';

  @override
  String get nursingChecklistPendingStatus => 'Pending';

  @override
  String get nursingChecklistLocationTitle => 'Location confirmed';

  @override
  String get nursingChecklistLocationReadyBody =>
      'Patient location is available.';

  @override
  String get nursingChecklistLocationPendingBody =>
      'Waiting for bed allocation or authorized holding area.';

  @override
  String get nursingChecklistHandoverTitle => 'Admission handover';

  @override
  String get nursingChecklistHandoverReadyBody =>
      'A nursing handover is linked to this admission.';

  @override
  String get nursingChecklistHandoverPendingBody =>
      'Record or accept the admission handover before ward care continues.';

  @override
  String get nursingChecklistVitalsTitle => 'Initial observations';

  @override
  String get nursingChecklistVitalsPendingBody =>
      'Record baseline vital signs for the admission.';

  @override
  String get nursingChecklistCarePlanTitle => 'Care plan started';

  @override
  String get nursingChecklistCarePlanReadyBody =>
      'At least one care task or plan is recorded.';

  @override
  String get nursingChecklistCarePlanPendingBody =>
      'Add a care task or plan for ward follow-up.';

  @override
  String get nursingChecklistMedicationTitle => 'Medication queue clear';

  @override
  String get nursingChecklistMedicationReadyBody =>
      'No medication administration is currently due.';

  @override
  String get nursingChecklistMedicationPendingBody =>
      'Medication administration remains due for this patient.';

  @override
  String get nursingChecklistDischargeTitle => 'Discharge nursing readiness';

  @override
  String get nursingChecklistDischargeReadyBody =>
      'No discharge nursing checklist is pending.';

  @override
  String get nursingChecklistDischargePendingBody =>
      'Discharge nursing checks are pending; do not close the admission here.';

  @override
  String get nursingChecklistIdentityTitle => 'Identity confirmed';

  @override
  String get nursingChecklistIdentityReadyBody =>
      'Patient identity has been confirmed.';

  @override
  String get nursingChecklistIdentityPendingBody =>
      'Confirm patient name, admission number, and ward/bed.';

  @override
  String get nursingChecklistAllergiesTitle => 'Allergies and risk flags';

  @override
  String get nursingChecklistAllergiesReadyBody =>
      'Allergies and risk flags have been reviewed.';

  @override
  String get nursingChecklistAllergiesPendingBody =>
      'Review and record patient allergies and risk flags.';

  @override
  String get nursingChecklistBelongingsTitle => 'Belongings';

  @override
  String get nursingChecklistBelongingsReadyBody =>
      'Patient belongings have been recorded.';

  @override
  String get nursingChecklistBelongingsPendingBody =>
      'Record patient belongings per hospital policy.';

  @override
  String get nursingChecklistDoctorTitle => 'Doctor notified';

  @override
  String get nursingChecklistDoctorReadyBody =>
      'The responsible doctor has been notified.';

  @override
  String get nursingChecklistDoctorPendingBody =>
      'Notify the responsible doctor of the ward admission.';

  @override
  String get nursingActionOrderLab => 'Order lab tests';

  @override
  String get nursingActionOrderRadiology => 'Order imaging';

  @override
  String get nursingActionDischargeClearance => 'Discharge clearance';

  @override
  String get nursingActionOpenIcu => 'Open ICU workspace';

  @override
  String get nursingActionConfirmIdentity => 'Confirm identity';

  @override
  String get nursingActionRecordAllergies => 'Record allergies & risks';

  @override
  String get nursingActionRecordBelongings => 'Record belongings';

  @override
  String get nursingActionNotifyDoctor => 'Notify doctor';

  @override
  String get nursingAllergiesLabel => 'Allergies and risk flags';

  @override
  String get nursingBelongingsLabel => 'Belongings';

  @override
  String get nursingNotifyDoctorLabel => 'Notification details';

  @override
  String get nursingCarePlanLabel => 'Care plan';

  @override
  String get nursingDischargeClearanceTitle => 'Discharge nursing clearance';

  @override
  String get nursingDischargeClearanceDescription =>
      'Ward checks and patient education before discharge.';

  @override
  String get nursingDischargeClearanceNotesLabel => 'Additional notes';

  @override
  String get nursingDischargeClearanceConfirmLabel =>
      'I confirm nursing clearance is complete';

  @override
  String get nursingClearanceMedicationEducationLabel =>
      'Medication education provided';

  @override
  String get nursingClearanceWoundCareLabel => 'Wound care instructions given';

  @override
  String get nursingClearanceFollowUpLabel => 'Follow-up appointments arranged';

  @override
  String get nursingClearanceBelongingsReturnedLabel => 'Belongings returned';

  @override
  String get nursingClearanceIdentityBandLabel => 'Identity band removed';

  @override
  String get nursingShiftContextTitle => 'Shift context';

  @override
  String get nursingShiftContextDescription =>
      'Roster and handover items for this shift.';

  @override
  String get nursingRosterTitle => 'Roster assignments';

  @override
  String get nursingPendingHandoverTitle => 'Pending handovers';

  @override
  String get nursingNoRosterLabel =>
      'No roster assignments found for this shift.';

  @override
  String get navigationDischargeLabel => 'Discharge planning';

  @override
  String get navigationDischargeShortLabel => 'Discharge';

  @override
  String get dischargeWorkspaceTitle => 'Discharge workspace';

  @override
  String get dischargeWorkspaceDescription =>
      'Plans, clearances, meds, billing, documents, and bed release.';

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
      'Planned, pending clearance, or recently completed discharges.';

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
      'Adjust filters to find discharge work.';

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
      'Loading clearance, meds, and billing...';

  @override
  String get dischargeNoSelectionTitle => 'Select a discharge';

  @override
  String get dischargeNoSelectionBody =>
      'Select a patient to coordinate discharge.';

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
  String get dischargeClearanceBackendGap => 'Unavailable';

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
      'Start a discharge plan for the summary.';

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
  String get dischargeBackendGapsTitle => 'Unavailable workflows';

  @override
  String get dischargeBackendGapsBody =>
      'These actions are unavailable until enabled for this facility.';

  @override
  String get dischargeGapBackendSubtitle => 'Workflow support unavailable';

  @override
  String get dischargeGapChecklistTitle => 'Persistent clearance checklist';

  @override
  String get dischargeGapChecklistBody =>
      'Per-role checklist decisions are not available in this workflow yet.';

  @override
  String get dischargeGapInsuranceTitle => 'Insurance clearance workflow';

  @override
  String get dischargeGapInsuranceBody =>
      'Insurance clearance is not connected to this discharge workflow yet.';

  @override
  String get dischargeGapDocumentsTitle => 'Document ready state';

  @override
  String get dischargeGapDocumentsBody =>
      'Documents can be generated. Handover readiness is not available yet.';

  @override
  String get dischargeGapHousekeepingTitle => 'Housekeeping task handoff';

  @override
  String get dischargeGapHousekeepingBody =>
      'Final discharge releases the bed. Housekeeping handoff is unavailable for this workflow.';

  @override
  String get dischargePlanDialogTitle => 'Discharge plan';

  @override
  String get dischargePlanDialogBody =>
      'Prepare the clinical discharge summary and target discharge date.';

  @override
  String get dischargeSummaryFieldLabel => 'Discharge summary';

  @override
  String get dischargeSummaryHelperText =>
      'Include diagnosis, treatment, meds, advice, follow-up, and warnings.';

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
      'Send discharge medicines to pharmacy.';

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
      'Confirm exit after clinical, nursing, pharmacy, billing, and document checks.';

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
  String get dischargeManageClearanceAction => 'Manage clearance';

  @override
  String get dischargeManageClearanceTitle => 'Discharge clearance';

  @override
  String get dischargeSaveClearanceAction => 'Save clearance';

  @override
  String get dischargePendingOrdersTitle => 'Pending clinical orders';

  @override
  String get dischargePendingOrdersBody =>
      'Review lab, radiology, medication, and nursing orders before finalizing discharge.';

  @override
  String get dischargeCrossModuleLinksTitle => 'Related workspaces';

  @override
  String get dischargeCrossModuleLinksBody =>
      'Open billing, pharmacy, nursing, IPD, or housekeeping with this admission context.';

  @override
  String get dischargeOpenIpdAction => 'Open IPD';

  @override
  String get dischargeOpenNursingAction => 'Open nursing';

  @override
  String get dischargeOpenPharmacyAction => 'Open pharmacy';

  @override
  String get dischargeOpenBillingAction => 'Open billing';

  @override
  String get dischargeOpenHousekeepingAction => 'Open housekeeping';

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
  String get dischargeReportFooter => 'Generated from discharge workflow data.';

  @override
  String get dischargeLoadingTitle => 'Loading discharge workspace';

  @override
  String get dischargeLoadingBody => 'Loading discharge queue...';

  @override
  String get dischargeLoadErrorTitle => 'Discharge workspace unavailable';

  @override
  String get dischargeLoadErrorBody =>
      'The discharge queue could not be loaded. Refresh to try again.';

  @override
  String get radiologyTitle => 'Radiology';

  @override
  String get radiologyDescription =>
      'Imaging requests, studies, PACS, reporting, and release.';

  @override
  String get radiologyLoadingTitle => 'Loading radiology workspace';

  @override
  String get radiologyLoadingBody => 'Loading imaging orders and reports...';

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
  String get radiologyPriorityFilterLabel => 'Priority';

  @override
  String get radiologyBillingGateFilterLabel => 'Billing gate';

  @override
  String get radiologyBillingGateAwaitingLabel => 'Awaiting confirmation';

  @override
  String get radiologyBillingGateConfirmedLabel => 'Billing confirmed';

  @override
  String get radiologyEncounterColumnLabel => 'Encounter';

  @override
  String get radiologyClearFiltersAction => 'Clear filters';

  @override
  String get radiologyWorklistTitle => 'Imaging worklist';

  @override
  String get radiologyWorklistDescription =>
      'Imaging orders by modality and report status.';

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
      'Select an imaging request for study and report.';

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
  String get radiologyWorkflowSummaryTitle => 'Workflow summary';

  @override
  String get radiologyEditRequestDetailsAction => 'Edit request details';

  @override
  String get radiologyEditRequestDetailsDialogTitle => 'Edit request details';

  @override
  String get radiologySaveRequestDetailsAction => 'Save request details';

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
  String get radiologyPriorityRoutineLabel => 'Routine';

  @override
  String get radiologyPriorityUrgentLabel => 'Urgent';

  @override
  String get radiologyPriorityStatLabel => 'STAT (Immediately)';

  @override
  String get radiologyPriorityStatHint => 'Statim — perform immediately';

  @override
  String get radiologyLateralityLeft => 'LEFT';

  @override
  String get radiologyLateralityRight => 'RIGHT';

  @override
  String get radiologyLateralityBilateral => 'BILATERAL';

  @override
  String get radiologyLateralityOblique => 'OBLIQUE';

  @override
  String get clinicalRadiologyBodyRegionPickerHint =>
      'Select a body region to filter imaging tests.';

  @override
  String get radiologyWorkflowProgressTitle => 'Workflow progress';

  @override
  String get radiologyWorkflowStepReceive => 'Receive imaging request';

  @override
  String get radiologyWorkflowStepReview => 'Review study details';

  @override
  String get radiologyWorkflowStepPerform => 'Perform imaging study';

  @override
  String get radiologyWorkflowStepUpload => 'Upload study assets';

  @override
  String get radiologyWorkflowStepReport => 'Enter findings and conclusions';

  @override
  String get radiologyWorkflowStepRelease => 'Finalize and release report';

  @override
  String get radiologyReportSectionTitle => 'Report';

  @override
  String get radiologyReportSectionBody =>
      'Draft, finalize, and release the radiology report.';

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
  String get radiologyNoReportReadyTitle => 'Ready to report';

  @override
  String get radiologyNoReportReadyBody =>
      'Imaging is complete. Start a draft report to continue.';

  @override
  String get radiologyNoReportImagingFloorBody =>
      'Switch to Reporting view to draft and release the report.';

  @override
  String get radiologyReportedAtLabel => 'Reported';

  @override
  String get radiologyGeneratedReportPreviewTitle => 'Report preview';

  @override
  String get radiologyEmptyReportBody => 'No report text captured.';

  @override
  String get radiologyStudiesAssetsTitle => 'Studies and assets';

  @override
  String get radiologyStudiesAssetsBody =>
      'Performed studies, images, and PACS sync.';

  @override
  String get radiologyNoStudiesTitle => 'No imaging studies';

  @override
  String get radiologyNoStudiesBody =>
      'Perform the study to begin acquiring images.';

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
      'Final report ready for the requesting clinician.';

  @override
  String get radiologyDoctorReviewPendingBody =>
      'No final radiology report is available for doctor review yet.';

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
  String get radiologyBackendGapsTitle => 'Unavailable workflows';

  @override
  String get radiologyBackendGapsBody =>
      'These controls are unavailable until system support is enabled for this facility.';

  @override
  String get radiologyGapSchedulingTitle => 'Room scheduling';

  @override
  String get radiologyGapBackendSubtitle => 'Action unavailable';

  @override
  String get radiologyGapSchedulingBody =>
      'Room and appointment assignment is not available for current imaging orders.';

  @override
  String get radiologyGapBillingTitle => 'Billing authorization';

  @override
  String get radiologyGapBillingBody =>
      'Payment and authorization status appears when available for this order.';

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
  String get radiologyImpressionLabel => 'Impression/Conclusion';

  @override
  String get radiologyReportTextLabel => 'Report narrative';

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
  String get radiologyModalityXray => 'X-RAY';

  @override
  String get radiologyModalityCt => 'CT';

  @override
  String get radiologyModalityMri => 'MRI';

  @override
  String get radiologyModalityUltrasound => 'ULTRASOUND';

  @override
  String get radiologyModalityPet => 'PET';

  @override
  String get radiologyModalityEcg => 'ECG';

  @override
  String get radiologyModalityEcho => 'ECHO';

  @override
  String get radiologyModalityEndo => 'ENDO';

  @override
  String get radiologyModalityGastro => 'GASTRO';

  @override
  String get radiologyModalityOther => 'OTHER';

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
  String get navigationPharmacyShortLabel => 'Pharmacy';

  @override
  String get navigationLabLabel => 'Laboratory';

  @override
  String get navigationLabShortLabel => 'Lab';

  @override
  String get navigationRadiologyLabel => 'Radiology';

  @override
  String get navigationRadiologyShortLabel => 'Imaging';

  @override
  String get pharmacyLoadingTitle => 'Loading pharmacy workspace';

  @override
  String get pharmacyLoadingBody => 'Loading pharmacy orders and stock...';

  @override
  String get pharmacyTitle => 'Pharmacy';

  @override
  String get pharmacyDescription =>
      'Prescriptions, dispense, returns, and stock visibility.';

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
      'Pharmacy orders with dispense and return actions.';

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
      'Loading medicines and dispense history...';

  @override
  String get pharmacyPrescriptionDetailTitle => 'Prescription detail';

  @override
  String get pharmacyNoSelectionTitle => 'No prescription selected';

  @override
  String get pharmacyNoSelectionBody =>
      'Select an order to review meds and dispense.';

  @override
  String get pharmacyBillingGateUnavailableTitle =>
      'Payment clearance unavailable';

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
      'Drug, dose, route, frequency, quantity, and status.';

  @override
  String get pharmacyNoMedicationTitle => 'No medicines';

  @override
  String get pharmacyNoMedicationBody =>
      'This order has no medicines available in the pharmacy workflow.';

  @override
  String get pharmacyMedicationColumnLabel => 'Medication';

  @override
  String get pharmacyDoseColumnLabel => 'Dose';

  @override
  String get pharmacyQuantityColumnLabel => 'Quantity';

  @override
  String get pharmacyStockColumnLabel => 'Stock';

  @override
  String get pharmacyLinePriceColumnLabel => 'Price';

  @override
  String get pharmacyLineActionsColumnLabel => 'Actions';

  @override
  String get pharmacyLineTotalLabel => 'Line total';

  @override
  String get pharmacyPaymentClearanceFieldLabel => 'Payment clearance';

  @override
  String get pharmacyUsePharmacyPriceAction => 'Pharmacy price';

  @override
  String get pharmacyUseFacilityPriceAction => 'Facility price';

  @override
  String get pharmacyMapStockAction => 'Map stock';

  @override
  String get pharmacyItemCancelledLabel => 'Cancelled';

  @override
  String get pharmacyPriceUnavailableLabel => 'Price unavailable';

  @override
  String get pharmacyBackendGapsTitle => 'Pharmacy workflow readiness';

  @override
  String get pharmacyBackendGapsBody =>
      'This order uses the current pharmacy workflow state to determine safe actions.';

  @override
  String get pharmacyGapPaymentAuthorization =>
      'Payment and authorization are checked before dispense actions are enabled.';

  @override
  String get pharmacyGapBatchAvailability =>
      'Stock mapping is checked before dispense actions are enabled.';

  @override
  String get pharmacyGapHoldSubstitution =>
      'Hold and substitution decisions follow the current pharmacy order status.';

  @override
  String get pharmacyGapReportTemplates =>
      'Medication printouts use the configured print workflow.';

  @override
  String get pharmacyTimelinePanelTitle => 'Dispense history';

  @override
  String get pharmacyTimelinePanelDescription =>
      'Prepare, attest, dispense, and return events.';

  @override
  String get pharmacyNoTimelineBody => 'No dispense history is available yet.';

  @override
  String get pharmacyDrugPanelTitle => 'Formulary and stock';

  @override
  String get pharmacyDrugPanelDescription =>
      'Configured drugs and aggregate stock.';

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
  String get pharmacyReturnQuantityColumnLabel => 'Return qty';

  @override
  String get pharmacyReturnEditLineAction => 'Edit';

  @override
  String get pharmacyReturnEditLineDialogTitle => 'Edit return line';

  @override
  String get pharmacyCancelDialogTitle => 'Cancel pharmacy order';

  @override
  String get pharmacyCancelDialogBody =>
      'Cancel only when the order should no longer be dispensed.';

  @override
  String get pharmacyBillingGateUnavailableBody =>
      'Payment clearance is unavailable for this order.';

  @override
  String get pharmacyPaymentColumnLabel => 'Payment';

  @override
  String get pharmacyPaymentLabel => 'Payment';

  @override
  String get pharmacyPaymentAmountLabel => 'Amount due';

  @override
  String get pharmacyRecordPaymentAction => 'Record payment';

  @override
  String get pharmacyNextActionConfirmBilling => 'Confirm billing';

  @override
  String get pharmacyDispenseBlockedPaymentBody =>
      'Collect or confirm payment before dispensing this order.';

  @override
  String get pharmacyPriorityFieldLabel => 'Priority';

  @override
  String get pharmacyCatalogTabDrugs => 'Drugs';

  @override
  String get pharmacyCatalogTabFormulary => 'Formulary';

  @override
  String get pharmacyCatalogTabInventory => 'Inventory';

  @override
  String get pharmacyCatalogTabStorage => 'Storage layout';

  @override
  String get pharmacyCatalogPanelTitle => 'Catalog and stock';

  @override
  String get pharmacyAddDrugAction => 'Add drug';

  @override
  String get pharmacyEditDrugAction => 'Edit drug';

  @override
  String get pharmacyDeleteDrugAction => 'Delete drug';

  @override
  String get pharmacyDrugNameLabel => 'Drug name';

  @override
  String get pharmacyDrugCodeLabel => 'Drug code';

  @override
  String get pharmacyDrugFormLabel => 'Form';

  @override
  String get pharmacyDrugStrengthLabel => 'Strength';

  @override
  String get pharmacyDrugIdentitySectionTitle => 'Drug identity';

  @override
  String get pharmacyDrugFormulationSectionTitle => 'Formulation';

  @override
  String get pharmacyDrugPricingSectionTitle => 'Pricing';

  @override
  String get pharmacyDrugInitialStockSectionTitle => 'Initial stock';

  @override
  String get pharmacyDrugBatchSectionTitle => 'Batch and shelf life';

  @override
  String get pharmacyManufacturingDateLabel => 'Manufacturing date';

  @override
  String get pharmacyExpiryAlertLeadLabel => 'Expiry alert lead';

  @override
  String get pharmacyExpiryAlertLeadHelper =>
      'Alert when a batch is within this window of expiry.';

  @override
  String get pharmacyReorderLevelHelper =>
      'Alert when on-hand quantity is at or below this level.';

  @override
  String get pharmacyReorderLevelHelperWithUnit =>
      'Threshold in the selected unit. Alerts at or below this level.';

  @override
  String get pharmacyReorderLevelSelectUnitHelper =>
      'Select an inventory unit first.';

  @override
  String pharmacyReorderLevelLabelWithUnit(String unit) {
    return 'Reorder alert at ($unit)';
  }

  @override
  String get pharmacyConfigureStorageAction => 'Configure storage';

  @override
  String pharmacyDrugFormWithShortLabel(String full, String short) {
    return '$full ($short)';
  }

  @override
  String pharmacyInventoryUnitWithShortLabel(String full, String short) {
    return '$full ($short)';
  }

  @override
  String pharmacyExpiryAlertLeadDays(int count) {
    return '$count days';
  }

  @override
  String pharmacyExpiryAlertLeadMonths(int count) {
    return '$count months';
  }

  @override
  String get pharmacyAddFormularyAction => 'Add formulary item';

  @override
  String get pharmacyFormularyDrugLabel => 'Drug';

  @override
  String get pharmacyFormularyActiveLabel => 'Active';

  @override
  String get pharmacyFormularyIdLabel => 'Formulary ID';

  @override
  String get pharmacyNoFormularyTitle => 'No formulary items';

  @override
  String get pharmacyNoFormularyBody =>
      'Formulary entries linking drugs to prescribing will appear here.';

  @override
  String get pharmacyStoragePanelTitle => 'Storage layout';

  @override
  String get pharmacyStoragePanelDescription =>
      'Storage rooms and shelf codes for medication stock.';

  @override
  String get pharmacyAddStorageRoomAction => 'Add room';

  @override
  String get pharmacyEditStorageRoomAction => 'Edit room';

  @override
  String get pharmacyAddStorageShelfAction => 'Add shelf';

  @override
  String get pharmacyEditStorageShelfAction => 'Edit shelf';

  @override
  String get pharmacyDeleteStorageRoomAction => 'Delete room';

  @override
  String get pharmacyDeleteStorageShelfAction => 'Delete shelf';

  @override
  String get pharmacyDeleteStorageRoomDialogTitle => 'Delete room';

  @override
  String get pharmacyDeleteStorageRoomDialogBody =>
      'Remove this storage room and shelves? Drugs will lose this location.';

  @override
  String get pharmacyDeleteStorageShelfDialogTitle => 'Delete shelf';

  @override
  String get pharmacyDeleteStorageShelfDialogBody =>
      'Remove this shelf? Drugs stored here will lose this location.';

  @override
  String get pharmacyStorageRoomNameLabel => 'Room name';

  @override
  String get pharmacyStorageRoomCodeLabel => 'Room code';

  @override
  String get pharmacyStorageShelfCodeLabel => 'Shelf code';

  @override
  String get pharmacyStorageShelfLabelField => 'Shelf label';

  @override
  String get pharmacyStorageRoomLabel => 'Storage room';

  @override
  String get pharmacyStorageShelfLabel => 'Shelf';

  @override
  String get pharmacyStorageLocationColumnLabel => 'Location';

  @override
  String get pharmacyDrugStorageSectionTitle => 'Storage location';

  @override
  String get pharmacyDrugStorageSectionHelper =>
      'Optional — helps staff locate this drug.';

  @override
  String get pharmacyNoStorageRoomsTitle => 'No storage rooms';

  @override
  String get pharmacyNoStorageRoomsBody =>
      'Add a storage room to assign shelf locations when receiving stock.';

  @override
  String get pharmacyNoStorageShelvesBody => 'No shelves in this room yet.';

  @override
  String get pharmacyStorageActiveLabel => 'Active';

  @override
  String get pharmacyStorageInactiveLabel => 'Inactive';

  @override
  String get pharmacyStorageFilterAll => 'All locations';

  @override
  String get pharmacyInventoryPanelTitle => 'Inventory stock';

  @override
  String get pharmacyInventoryPanelDescription =>
      'On-hand quantities and controlled adjustments.';

  @override
  String get pharmacyNoInventoryTitle => 'No inventory rows';

  @override
  String get pharmacyNoInventoryBody =>
      'Matching inventory stock rows will appear here.';

  @override
  String get pharmacyInventoryQuantityColumnLabel => 'On hand';

  @override
  String get pharmacyInventoryFacilityColumnLabel => 'Facility';

  @override
  String get pharmacyAdjustStockAction => 'Adjust stock';

  @override
  String get pharmacyAdjustStockDialogTitle => 'Adjust inventory';

  @override
  String get pharmacyQuantityDeltaLabel => 'Quantity change';

  @override
  String get pharmacyStockReasonLabel => 'Reason';

  @override
  String get pharmacyLowStockOnlyFilterLabel => 'Low stock only';

  @override
  String get pharmacyExpiredOnlyFilterLabel => 'Expired batches';

  @override
  String get pharmacyExpiringSoonFilterLabel => 'Expiring soon';

  @override
  String get pharmacyInventoryFiltersSemanticLabel => 'Inventory stock filters';

  @override
  String get pharmacyReorderLevelLabel => 'Reorder alert at';

  @override
  String get pharmacyReorderLevelColumnLabel => 'Reorder at';

  @override
  String get pharmacyNextExpiryColumnLabel => 'Next expiry';

  @override
  String get pharmacyBatchCountColumnLabel => 'Batches';

  @override
  String get pharmacyBatchNumberLabel => 'Batch number';

  @override
  String get pharmacyExpiryDateLabel => 'Expiry date';

  @override
  String get pharmacyInventoryUnitLabel => 'Inventory unit';

  @override
  String get pharmacyInitialStockLabel => 'Initial stock';

  @override
  String get pharmacySummaryLowStockLabel => 'Low stock';

  @override
  String get pharmacySummaryAlmostOutLabel => 'Almost out';

  @override
  String get pharmacySummaryExpiringSoonLabel => 'Expiring soon';

  @override
  String get pharmacyStockExpiredLabel => 'Expired';

  @override
  String get pharmacyStockExpiringSoonLabel => 'Expiring soon';

  @override
  String get pharmacyDeleteDrugDialogTitle => 'Delete drug';

  @override
  String get pharmacyDeleteDrugDialogBody =>
      'Remove this drug from the catalog?';

  @override
  String get pharmacyEditFormularyAction => 'Edit formulary item';

  @override
  String get pharmacyDeleteFormularyAction => 'Delete formulary item';

  @override
  String get pharmacyDeleteFormularyDialogTitle => 'Delete formulary item';

  @override
  String get pharmacyDeleteFormularyDialogBody =>
      'Remove this drug from the facility formulary?';

  @override
  String get pharmacyDeleteSelectedDrugsAction => 'Delete selected';

  @override
  String get pharmacyDeleteSelectedDrugsDialogTitle => 'Delete selected drugs?';

  @override
  String pharmacyDeleteSelectedDrugsDialogBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count drugs',
      one: '1 drug',
    );
    return 'Remove $_temp0 from the catalog?';
  }

  @override
  String get pharmacyDeleteSelectedFormularyAction => 'Delete selected';

  @override
  String get pharmacyDeleteSelectedFormularyDialogTitle =>
      'Delete selected formulary items?';

  @override
  String pharmacyDeleteSelectedFormularyDialogBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count formulary items',
      one: '1 formulary item',
    );
    return 'Remove $_temp0?';
  }

  @override
  String get pharmacyClearSelectedInventoryAction => 'Clear selected stock';

  @override
  String get pharmacyClearSelectedInventoryDialogTitle =>
      'Clear selected stock?';

  @override
  String pharmacyClearSelectedInventoryDialogBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stock rows',
      one: '1 stock row',
    );
    return 'Set quantity to zero for $_temp0?';
  }

  @override
  String get pharmacyDeleteInventoryStockAction => 'Clear stock';

  @override
  String get pharmacyDeleteInventoryStockDialogTitle => 'Clear stock';

  @override
  String get pharmacyDeleteInventoryStockDialogBody =>
      'Set this stock quantity to zero?';

  @override
  String get pharmacyCatalogDeleteFailedMessage => 'Unable to complete delete.';

  @override
  String get pharmacyDispenseDialogBody =>
      'Enter dispense quantities and optional stock mapping for each medicine line.';

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
  String get pharmacyFilterPendingPayment => 'Pending payment';

  @override
  String get pharmacyFilterPartialStock => 'Partial stock';

  @override
  String get pharmacyFilterUrgent => 'Urgent';

  @override
  String get pharmacyFilterDischarge => 'Discharge meds';

  @override
  String get pharmacyFilterOutpatient => 'Outpatient';

  @override
  String get pharmacyFilterWard => 'Ward';

  @override
  String get pharmacyLocationFieldLabel => 'Care location';

  @override
  String get pharmacyStatusFilterLabel => 'Queue status';

  @override
  String get pharmacyOrderDateFilterLabel => 'Order date';

  @override
  String get pharmacyPickOrderDateAction => 'Pick order date';

  @override
  String get pharmacyOrderedAtColumnLabel => 'Ordered at';

  @override
  String get pharmacyPrescriberFieldLabel => 'Prescriber';

  @override
  String get pharmacyOrderSourceFieldLabel => 'Order source';

  @override
  String get pharmacyOrderSourceClinicalLabel => 'Clinical';

  @override
  String get pharmacyOrderSourcePharmacyLabel => 'Walk-in pharmacy';

  @override
  String get pharmacyRemainingQtyColumnLabel => 'Remaining qty';

  @override
  String get pharmacyPharmacyPriceLabel => 'Pharmacy price';

  @override
  String get pharmacyFacilityPriceLabel => 'Facility price';

  @override
  String get pharmacyPriceTierPharmacyLabel => 'Pharmacy retail';

  @override
  String get pharmacyPriceTierFacilityLabel => 'Facility billing';

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
  String get pharmacyReportFooter => 'Generated from pharmacy workflow data.';

  @override
  String get pharmacyReportGrandTotalLabel => 'Grand total';

  @override
  String get pharmacyReportTotalAmountSoldLabel => 'Total amount sold';

  @override
  String get pharmacyPrintAmountColumnLabel => 'Amount';

  @override
  String get pharmacyPrintRowNumberColumnLabel => '#';

  @override
  String get navigationClaimsLabel => 'Insurance claims';

  @override
  String get navigationClaimsShortLabel => 'Claims';

  @override
  String get claimsWorkspaceTitle => 'Insurance and claims';

  @override
  String get claimsWorkspaceDescription =>
      'Authorizations, submissions, payer responses, and invoices.';

  @override
  String get claimsOperationalStatusLabel => 'Billing synced';

  @override
  String get claimsNeedsAttentionStatusLabel => 'Needs attention';

  @override
  String get claimsLoadingTitle => 'Loading claims';

  @override
  String get claimsLoadingBody => 'Loading authorization and claim queues...';

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
      'Pre-authorizations and claims linked to billing.';

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
      'No authorizations or claims in this queue.';

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
  String get claimsDetailLoadingBody => 'Loading payer and coverage context...';

  @override
  String get claimsNoSelectionTitle => 'Select a record';

  @override
  String get claimsNoSelectionBody =>
      'Select a row for coverage and next actions.';

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
      'Invoice details unavailable; patient balance cannot be confirmed here.';

  @override
  String get claimsBillingAuthorizedBody =>
      'Authorized by payer. Confirm any uncovered balance before final clearance.';

  @override
  String get claimsBillingPaidBody =>
      'Claim paid or closed. Use latest invoice status for follow-up.';

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
      'Authorization, submission, and response timestamps.';

  @override
  String get claimsTimelineAuthorizationRequested => 'Authorization requested';

  @override
  String get claimsTimelineAuthorizationResponded => 'Authorization responded';

  @override
  String get claimsTimelineClaimSubmitted => 'Claim submitted';

  @override
  String get claimsTimelineCurrentStatus => 'Current status';

  @override
  String get claimsBackendGapTitle => 'Unavailable workflows';

  @override
  String get claimsBackendGapDescription =>
      'Unavailable in the current claims workflow.';

  @override
  String get claimsBackendGapDraftTitle => 'Claim draft queue';

  @override
  String get claimsBackendGapDraftBody =>
      'The draft queue is not available in the current claims workflow.';

  @override
  String get claimsBackendGapDocumentsTitle => 'Document upload and requests';

  @override
  String get claimsBackendGapDocumentsBody =>
      'Required document tracking is not available yet.';

  @override
  String get claimsBackendGapReportsTitle => 'Generated payer packs';

  @override
  String get claimsBackendGapReportsBody =>
      'Printable payer packs are unavailable until report templates are enabled.';

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
      'Coverage plan and invoice are required before preparing a claim.';

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
  String get claimsInsuranceAuthorizationTitle => 'Insurance authorization';

  @override
  String get claimsInsuranceAuthorizationEmpty =>
      'No authorization on file. Request pre-auth before high-cost orders or elective admission.';

  @override
  String get claimsApprovedAmountLabel => 'Approved';

  @override
  String get claimsConsumedAmountLabel => 'Consumed';

  @override
  String get claimsRemainingAmountLabel => 'Remaining';

  @override
  String get claimsAuthorizationReasonLabel => 'Reason';

  @override
  String get claimsCoveragePlansUnavailable =>
      'Coverage plans are unavailable. Verify insurance setup before proceeding.';

  @override
  String get opdCoverageVerificationTitle => 'Coverage verification';

  @override
  String get opdCoverageVerificationBody =>
      'Confirm the patient\'s active coverage plan before recording an insurance consultation payment.';

  @override
  String get opdCoverageVerifiedLabel => 'Coverage verified for this visit';

  @override
  String get opdCoverageVerificationRequiredMessage =>
      'Verify coverage before paying with insurance.';

  @override
  String get billingPreAuthApproveAction => 'Approve authorization';

  @override
  String get billingPreAuthDenyAction => 'Deny authorization';

  @override
  String get billingPreAuthApprovedAmountLabel => 'Approved amount';

  @override
  String get billingPreAuthConsumedAmountLabel => 'Consumed amount';

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
  String get claimsReportFooter => 'Generated from claims and billing data.';

  @override
  String get labTitle => 'Laboratory';

  @override
  String get labDescription =>
      'Lab requests, results, verification, ranges, and reports.';

  @override
  String get labLoadingTitle => 'Loading laboratory';

  @override
  String get labLoadingBody => 'Loading lab queues and results...';

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
  String get labWaitingSampleSummaryLabel => 'Awaiting results';

  @override
  String get labProcessingSummaryLabel => 'Processing';

  @override
  String get labResultPendingSummaryLabel => 'Pending verification';

  @override
  String get labCriticalSummaryLabel => 'Critical';

  @override
  String get labCompletedSummaryLabel => 'Verified';

  @override
  String get labFiltersLabel => 'Laboratory filters';

  @override
  String get labSearchLabel => 'Search laboratory';

  @override
  String get labSearchHint => 'Search patient, order, test, or encounter';

  @override
  String get labScopeFilterLabel => 'Queue';

  @override
  String get labScopeAll => 'All';

  @override
  String get labScopeCollection => 'Awaiting results';

  @override
  String get labScopeProcessing => 'Processing';

  @override
  String get labScopeResults => 'Pending verification';

  @override
  String get labScopeCritical => 'Critical';

  @override
  String get labScopeCompleted => 'Verified';

  @override
  String get labScopeCancelled => 'Cancelled';

  @override
  String get labWorklistTitle => 'Lab queue';

  @override
  String get labWorklistDescription =>
      'Orders awaiting entry, verification, or report release.';

  @override
  String get labNoOrdersTitle => 'No lab orders';

  @override
  String get labNoOrdersBody =>
      'Adjust the queue filter or search term to find laboratory work.';

  @override
  String get labPatientColumnLabel => 'Patient';

  @override
  String get labPatientIdColumnLabel => 'Patient ID';

  @override
  String get labEncounterColumnLabel => 'Encounter';

  @override
  String get labLabEncounterColumnLabel => 'Lab ID';

  @override
  String get labSourceLocationColumnLabel => 'Source / location';

  @override
  String get labOrderColumnLabel => 'Order';

  @override
  String get labTestsColumnLabel => 'Tests';

  @override
  String get labSampleColumnLabel => 'Entry status';

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
  String get labDetailLoadingBody => 'Loading order details and results...';

  @override
  String get labResultEntryDialogTitle => 'Lab Result Entry';

  @override
  String labResultEntryDialogSubtitle(String patientName, String orderId) {
    return '$patientName · Order $orderId';
  }

  @override
  String get labSaveDraftAction => 'Save draft';

  @override
  String get labSubmitResultsAction => 'Submit results';

  @override
  String get labDraftSavedMessage => 'Draft results saved.';

  @override
  String labBatchPartialSaveMessage(int savedCount, int skippedCount) {
    return 'Saved $savedCount results. $skippedCount entries need attention.';
  }

  @override
  String labBatchPartialSubmitMessage(int savedCount, int skippedCount) {
    return 'Submitted $savedCount results. $skippedCount entries need attention.';
  }

  @override
  String labBatchPartialVerifyMessage(int savedCount, int skippedCount) {
    return 'Verified $savedCount results. $skippedCount entries need attention.';
  }

  @override
  String get labBatchEntryValidationMessage =>
      'Correct the highlighted value before continuing.';

  @override
  String get labResultEntryRequiredMessage =>
      'Enter a result value before saving, submitting, or verifying.';

  @override
  String labBatchValidationSummaryMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected tests need attention before continuing.',
      one: '1 selected test needs attention before continuing.',
    );
    return '$_temp0';
  }

  @override
  String get labBatchValidationSummaryHint =>
      'Check the highlighted tests below and complete any missing or invalid values.';

  @override
  String labBatchActionFailedMessage(String actionLabel) {
    return '$actionLabel could not be completed.';
  }

  @override
  String labBatchActionValidationMessage(String actionLabel) {
    return '$actionLabel could not run because some selected tests still need attention.';
  }

  @override
  String labBatchActionFailedDetailMessage(String actionLabel, String detail) {
    return '$actionLabel failed: $detail';
  }

  @override
  String get labBatchInvalidTransitionMessage =>
      'Some tests cannot be verified yet. Submit results first, or remove rejected tests.';

  @override
  String get labBatchItemNotFoundMessage =>
      'Selected tests are no longer available. Refresh and try again.';

  @override
  String get labBatchOrderNotSelectedMessage =>
      'Lab order not found. Close, reopen the order, and try again.';

  @override
  String get labApplyingResultChangesMessage => 'Updating results...';

  @override
  String get labResultLifecycleDraft => 'Draft';

  @override
  String get labResultLifecycleSubmitted => 'Submitted';

  @override
  String get labResultLifecycleBlank => 'Not entered';

  @override
  String get labWorkflowCurrentStepLabel => 'Current step';

  @override
  String get labWorkflowNextStepLabel => 'Next step';

  @override
  String get labWorkflowStepOrdered => 'Ordered';

  @override
  String get labWorkflowStepInProcess => 'In process';

  @override
  String get labWorkflowStepResultsEntered => 'Results entered';

  @override
  String get labWorkflowStepVerified => 'Verified';

  @override
  String get labWorkflowNextCollectSample => 'Collect sample';

  @override
  String get labWorkflowNextReceiveSample => 'Receive sample';

  @override
  String get labWorkflowNextEnterResults => 'Enter results';

  @override
  String get labWorkflowNextVerifyResults => 'Verify results';

  @override
  String get labWorkflowNextReviewItems => 'Review pending items';

  @override
  String get labReferenceRangeOverrideLabel => 'Reference range override';

  @override
  String get labInterpretationOverrideLabel => 'Manual interpretation';

  @override
  String get labResultFlagOverrideLabel => 'Result flag override';

  @override
  String clinicalLabResultReadyNotice(String patientName) {
    return 'Lab results are ready for $patientName.';
  }

  @override
  String clinicalLabResultUpdatedNotice(String patientName) {
    return 'Lab results updated for $patientName.';
  }

  @override
  String clinicalLabResultCriticalNotice(String patientName) {
    return 'Critical lab result for $patientName needs review.';
  }

  @override
  String get labOrderFavoriteTestsLabel => 'Frequently used tests';

  @override
  String get labBulkResultActionsTitle => 'Bulk actions';

  @override
  String get labSubmitResultAction => 'Submit result';

  @override
  String get labResultsSubmittedMessage => 'Results submitted.';

  @override
  String get labResultsVerifiedMessage => 'Results verified.';

  @override
  String get labSelectAllTestsAction => 'Select all';

  @override
  String get labClearSelectionAction => 'Clear selection';

  @override
  String labSelectedTestCount(int selected, int total) {
    return '$selected of $total selected';
  }

  @override
  String get labRejectAllTestsAction => 'Reject all tests';

  @override
  String get labRemoveAllDraftsAction => 'Remove drafts';

  @override
  String get labSaveAllDraftsAction => 'Save all drafts';

  @override
  String get labSubmitAllResultsAction => 'Submit all';

  @override
  String get labRemoveAllDraftsDialogTitle => 'Remove Draft Results?';

  @override
  String get labRemoveAllDraftsDialogBody =>
      'Remove all unverified draft results?';

  @override
  String get labOrderStatusFieldLabel => 'Order status';

  @override
  String get labTestStatusColumnLabel => 'Test status';

  @override
  String get labReferenceRangeColumnLabel => 'Reference range';

  @override
  String get labResultInputColumnLabel => 'Result';

  @override
  String get labNoOrderItemsEntryTitle => 'No tests on this order';

  @override
  String get labNoOrderItemsEntryBody =>
      'This order does not have any requested tests to enter results for.';

  @override
  String get labNoSelectionTitle => 'Select an order';

  @override
  String get labNoSelectionBody =>
      'Select a lab order to enter, verify, or report.';

  @override
  String get labPatientContextLabel => 'Lab patient context';

  @override
  String get labOrderFieldLabel => 'Lab order';

  @override
  String get labEncounterFieldLabel => 'Encounter';

  @override
  String get labOrderedAtFieldLabel => 'Ordered at';

  @override
  String get labItemsSectionTitle => 'Ordered tests';

  @override
  String get labSamplesSectionTitle => 'Samples';

  @override
  String get labResultsSectionTitle => 'Results';

  @override
  String get labTimelineSectionTitle => 'Timeline';

  @override
  String get labNoSamplesLabel => 'No samples recorded';

  @override
  String get labNoResultsLabel => 'No verified results';

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
  String get labReleaseResultAction => 'Verify result';

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
  String get labBackendGapsTitle => 'Unavailable workflows';

  @override
  String get labBackendGapsBody =>
      'No unavailable workflow is blocking the displayed lab queue.';

  @override
  String get labNoCatalogItemsLabel => 'No catalog items found';

  @override
  String get labNoOfferedTestsLabel =>
      'No tests are offered at this facility. Use Enable test to add one.';

  @override
  String get labNoOfferedPanelsLabel =>
      'No panels are offered at this facility. Use Enable panel to add one.';

  @override
  String get labNoQcLogsLabel => 'No QC logs recorded';

  @override
  String get labTestsTabLabel => 'Tests';

  @override
  String get labPanelsTabLabel => 'Panels';

  @override
  String get labRequestOrderDialogTitle => 'Request Lab Order';

  @override
  String get labPatientIdLabel => 'Patient ID';

  @override
  String get labEncounterIdLabel => 'Encounter ID';

  @override
  String get labOrderContextDialogBody =>
      'Select a patient. Encounter and existing order are optional.';

  @override
  String get labPatientSearchLabel => 'Patient';

  @override
  String get labPatientSearchHint =>
      'Search patient name, ID, phone, or identifier';

  @override
  String get labEncounterContextLabel => 'Encounter';

  @override
  String get labEncounterContextHint => 'Search or select encounter';

  @override
  String get labExistingOrderContextLabel => 'Existing lab order context';

  @override
  String get labExistingOrderContextHint => 'Search or select order context';

  @override
  String get labCatalogSearchLabel => 'Search lab catalog';

  @override
  String get labCatalogSearchHint =>
      'Search tests, panels, codes, category, or specimen';

  @override
  String get labCreateOrderSubmitAction => 'Create lab order';

  @override
  String get labCollectDialogTitle => 'Collect Sample';

  @override
  String get labCollectedAtLabel => 'Collected at';

  @override
  String get labDateTimeHint => 'YYYY-MM-DDTHH:MM:SS';

  @override
  String get labNotesLabel => 'Notes';

  @override
  String get labReceiveDialogTitle => 'Receive Sample';

  @override
  String get labSampleFieldLabel => 'Sample';

  @override
  String get labReceivedAtLabel => 'Received at';

  @override
  String get labRejectDialogTitle => 'Reject Sample';

  @override
  String get labRejectReasonLabel => 'Rejection reason';

  @override
  String get labReleaseDialogTitle => 'Verify Lab Result';

  @override
  String get labOrderItemFieldLabel => 'Order item';

  @override
  String get labResultStatusLabel => 'Result status';

  @override
  String get labResultValueLabel => 'Result value';

  @override
  String get labResultUnitLabel => 'Result unit';

  @override
  String get labResultTextLabel => 'Result text';

  @override
  String get labReportedAtInputLabel => 'Reported at';

  @override
  String get labReverseDialogTitle => 'Reverse Lab Workflow';

  @override
  String get labReverseReasonLabel => 'Reason';

  @override
  String get labRecordQcDialogTitle => 'Record Quality Control';

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
  String get labStatusCompleted => 'Verified';

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
  String get labNextActionCollect => 'Enter result';

  @override
  String get labNextActionReceive => 'Enter result';

  @override
  String get labNextActionRelease => 'Verify result';

  @override
  String get labNextActionReviewCritical => 'Escalate critical result';

  @override
  String get labNextActionCompleted => 'Ready for doctor review';

  @override
  String get labNextActionWatch => 'Review order';

  @override
  String get labReportPreviewTitle => 'Result Report Preview';

  @override
  String get labReportSearchLabel => 'Search report tests';

  @override
  String get labReportSearchHint =>
      'Search test, result, reference range, or flag';

  @override
  String get labReportFiltersLabel => 'Report filters';

  @override
  String get labReportFlagFilterLabel => 'Result flag';

  @override
  String get labReportAllFlagsLabel => 'All flags';

  @override
  String get labReportSelectionFilterLabel => 'Selection';

  @override
  String get labReportSelectionAllLabel => 'All tests';

  @override
  String get labReportSelectionSelectedLabel => 'Selected';

  @override
  String get labReportSelectionUnselectedLabel => 'Unselected';

  @override
  String get labReportTableColumnsTitle => 'Report table columns';

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
  String get labReportVerifiedLabel => 'Verified';

  @override
  String get labReportFooter => 'Generated from laboratory workflow data.';

  @override
  String get printFormPrintedLabel => 'Printed';

  @override
  String get printFormPrintedOnLabel => 'Printed on';

  @override
  String get printFormPrintedAtLabel => 'Printed at';

  @override
  String get printFormPrintedByLabel => 'Printed by';

  @override
  String get printFormVerifiedByLabel => 'Verified by';

  @override
  String get printFormSignatureStampLabel => 'Signature / stamp';

  @override
  String get printFormPatientNameLabel => 'Patient name';

  @override
  String get printFormPatientIdLabel => 'Patient ID';

  @override
  String get printFormEncounterIdLabel => 'Encounter ID';

  @override
  String get labGapBillingTitle => 'Payment and authorization gate';

  @override
  String get labGapBillingBody =>
      'Payment or authorization blockers are not available for this lab workbench.';

  @override
  String get labGapVerificationTitle => 'Separate verification step';

  @override
  String get labGapVerificationBody =>
      'Results can be released. Separate verified-before-release is not available.';

  @override
  String get labGapReportGenerationTitle => 'Generated report';

  @override
  String get labGapReportGenerationBody =>
      'Shared report preview available. Lab-specific document not yet.';

  @override
  String get navigationOperationsLabel => 'Operations';

  @override
  String get navigationOperationsShortLabel => 'Operations';

  @override
  String get operationsTitle => 'Operations';

  @override
  String get operationsLoadingTitle => 'Loading operations';

  @override
  String get operationsLoadingBody => 'Loading maintenance requests...';

  @override
  String get operationsLiveStatus => 'Live sync';

  @override
  String get operationsSavingStatus => 'Saving';

  @override
  String get operationsSavedMessage => 'Operations changes saved.';

  @override
  String get operationsCreateRequestAction => 'Create request';

  @override
  String get operationsOpenReportAction => 'Report';

  @override
  String get operationsAllRequestsSummaryLabel => 'All requests';

  @override
  String get operationsOpenSummaryLabel => 'Open';

  @override
  String get operationsInProgressSummaryLabel => 'In progress';

  @override
  String get operationsCompletedSummaryLabel => 'Completed';

  @override
  String get operationsCancelledSummaryLabel => 'Cancelled';

  @override
  String get operationsAssetsSummaryLabel => 'Assets';

  @override
  String get operationsQueueTitle => 'Maintenance queue';

  @override
  String get operationsQueueDescription =>
      'Facility repairs, assets, safety, and readiness.';

  @override
  String get operationsSearchLabel => 'Search operations';

  @override
  String get operationsSearchHint =>
      'Search request, location, system, priority, status, assignee, or notes';

  @override
  String get operationsClearFiltersAction => 'Clear filters';

  @override
  String get operationsFiltersLabel => 'Operations filters';

  @override
  String get operationsSearchFieldsLabel => 'Search fields';

  @override
  String get operationsAllFilterOption => 'All';

  @override
  String get operationsReportedDateFilterLabel => 'Reported date';

  @override
  String get operationsReportedFromLabel => 'Reported from';

  @override
  String get operationsReportedToLabel => 'Reported to';

  @override
  String get operationsPickReportedDateAction => 'Pick reported date';

  @override
  String get operationsStatusFilterLabel => 'Status';

  @override
  String get operationsPriorityFilterLabel => 'Priority';

  @override
  String get operationsFacilityFilterLabel => 'Facility';

  @override
  String get operationsAssetFilterLabel => 'Asset';

  @override
  String operationsPageLabel(int first, int last, int total) {
    return '$first - $last of $total requests';
  }

  @override
  String get operationsNoRequestsTitle => 'No maintenance requests';

  @override
  String get operationsNoRequestsBody =>
      'Create a request or adjust the filters.';

  @override
  String get operationsDetailTitle => 'Request detail';

  @override
  String get operationsNoSelectionTitle => 'Select a request';

  @override
  String get operationsNoSelectionBody =>
      'Select a request for assignment and service logs.';

  @override
  String get operationsRequestColumnLabel => 'Request';

  @override
  String get operationsAreaColumnLabel => 'Area/system';

  @override
  String get operationsPriorityColumnLabel => 'Priority';

  @override
  String get operationsLocationColumnLabel => 'Location';

  @override
  String get operationsAssigneeColumnLabel => 'Assignee/team';

  @override
  String get operationsStatusColumnLabel => 'Status';

  @override
  String get operationsDueColumnLabel => 'Due time';

  @override
  String get operationsNextActionColumnLabel => 'Next action';

  @override
  String get operationsCategoryLabel => 'Category';

  @override
  String get operationsIssueTitle => 'Issue and notes';

  @override
  String get operationsActionsTitle => 'Actions';

  @override
  String get operationsAssignAction => 'Assign';

  @override
  String get operationsUpdateStatusAction => 'Update status';

  @override
  String get operationsAddServiceLogAction => 'Add service log';

  @override
  String get operationsPartsVendorAction => 'Parts/vendor note';

  @override
  String get operationsSafetyNoteAction => 'Safety note';

  @override
  String get operationsEvidenceNoteAction => 'Evidence note';

  @override
  String get operationsHandoverNoteAction => 'Handover note';

  @override
  String get operationsCloseoutNoteAction => 'Closeout note';

  @override
  String get operationsPartsVendorNoteLabel => 'Parts or vendor note';

  @override
  String get operationsSafetyNoteLabel => 'Safety note';

  @override
  String get operationsEvidenceNoteLabel => 'Evidence note';

  @override
  String get operationsHandoverNoteLabel => 'Handover note';

  @override
  String get operationsCloseoutNoteLabel => 'Closeout note';

  @override
  String get operationsSaveNoteAction => 'Save note';

  @override
  String get operationsServiceLogsTitle => 'Service logs';

  @override
  String get operationsNoServiceLogsTitle => 'No service logs';

  @override
  String get operationsNoServiceLogsBody =>
      'Service logs appear after an asset-backed repair is recorded.';

  @override
  String get operationsUnknownValue => 'Unknown';

  @override
  String get operationsUnassignedValue => 'Unassigned';

  @override
  String get operationsNoDueTimeValue => 'No due time';

  @override
  String get operationsNoNotesValue => 'No notes recorded.';

  @override
  String get operationsLocationNoteLabel => 'Location note';

  @override
  String get operationsIssueFieldLabel => 'Issue';

  @override
  String get operationsNotesLabel => 'Notes';

  @override
  String get operationsCreateRequestSubmitAction => 'Create request';

  @override
  String get operationsAssigneeFieldLabel => 'Technician or team';

  @override
  String get operationsSlaHoursFieldLabel => 'SLA hours';

  @override
  String get operationsTriageSummaryFieldLabel => 'Assignment note';

  @override
  String get operationsAssignSubmitAction => 'Save assignment';

  @override
  String get operationsStatusNoteLabel => 'Status note';

  @override
  String get operationsUpdateStatusSubmitAction => 'Save status';

  @override
  String get operationsServiceNotesLabel => 'Service notes';

  @override
  String get operationsAddServiceLogSubmitAction => 'Save service log';

  @override
  String get operationsNoConfiguredAssetsOption => 'No configured assets';

  @override
  String get operationsStatusOpen => 'Open';

  @override
  String get operationsStatusInProgress => 'In progress';

  @override
  String get operationsStatusCompleted => 'Completed';

  @override
  String get operationsStatusCancelled => 'Cancelled';

  @override
  String get operationsPriorityUrgent => 'Urgent';

  @override
  String get operationsPriorityHigh => 'High';

  @override
  String get operationsPriorityNormal => 'Normal';

  @override
  String get operationsPriorityLow => 'Low';

  @override
  String get operationsCategoryElectrical => 'Electrical';

  @override
  String get operationsCategoryPlumbing => 'Plumbing';

  @override
  String get operationsCategoryWater => 'Water';

  @override
  String get operationsCategoryPowerBackup => 'Power backup';

  @override
  String get operationsCategoryHvac => 'HVAC';

  @override
  String get operationsCategoryGeneralAsset => 'General asset';

  @override
  String get operationsCategorySafety => 'Safety';

  @override
  String get operationsCategoryOther => 'Other';

  @override
  String get operationsNextActionAssign => 'Assign technician or team';

  @override
  String get operationsNextActionServiceLog => 'Record service work';

  @override
  String get operationsNextActionUpdateStatus => 'Update repair status';

  @override
  String get operationsNextActionCloseout => 'Add closeout note if needed';

  @override
  String get operationsNextActionCancelled => 'Request cancelled';

  @override
  String get operationsNextActionReview => 'Review request';

  @override
  String get operationsReportTitle => 'Operations report';

  @override
  String get operationsReportPreviewTitle => 'Report preview';

  @override
  String operationsGeneratedAtLabel(String generatedAt) {
    return 'Generated $generatedAt';
  }

  @override
  String operationsReportSummaryLine(
    int total,
    int open,
    int inProgress,
    int completed,
  ) {
    return '$total requests: $open open, $inProgress in progress, $completed completed.';
  }

  @override
  String get navigationBiomedicalLabel => 'Biomedical engineering';

  @override
  String get navigationBiomedicalShortLabel => 'Biomedical';

  @override
  String get biomedicalTitle => 'Biomedical';

  @override
  String get biomedicalLoadingTitle => 'Loading biomedical';

  @override
  String get biomedicalLoadingBody => 'Loading equipment and work orders...';

  @override
  String get biomedicalLiveStatus => 'Live sync';

  @override
  String get biomedicalSavingStatus => 'Saving';

  @override
  String get biomedicalSavedMessage => 'Biomedical changes saved.';

  @override
  String get biomedicalRegisterAssetAction => 'Register asset';

  @override
  String get biomedicalReportFaultAction => 'Report fault';

  @override
  String get biomedicalTotalEquipmentSummaryLabel => 'Total equipment';

  @override
  String get biomedicalOverduePmSummaryLabel => 'Overdue PM';

  @override
  String get biomedicalOpenWorkOrdersSummaryLabel => 'Open work orders';

  @override
  String get biomedicalCriticalDowntimeSummaryLabel => 'Critical downtime';

  @override
  String get biomedicalActiveRecallsSummaryLabel => 'Active recalls';

  @override
  String get biomedicalAssetListTitle => 'Equipment worklist';

  @override
  String get biomedicalAssetListDescription =>
      'Equipment, schedules, work orders, downtime, and recalls.';

  @override
  String get biomedicalSearchLabel => 'Search biomedical';

  @override
  String get biomedicalSearchHint =>
      'Search asset tag, equipment, category, location, status, date, or provider';

  @override
  String get biomedicalFiltersLabel => 'Biomedical filters';

  @override
  String get biomedicalPanelFilterLabel => 'Panel';

  @override
  String get biomedicalStatusFilterLabel => 'Status';

  @override
  String get biomedicalPriorityFilterLabel => 'Priority';

  @override
  String get biomedicalFacilityFilterLabel => 'Facility';

  @override
  String get biomedicalDatePresetFilterLabel => 'Due date';

  @override
  String get biomedicalAssetTagColumnLabel => 'Asset tag';

  @override
  String get biomedicalEquipmentColumnLabel => 'Equipment';

  @override
  String get biomedicalCategoryColumnLabel => 'Category';

  @override
  String get biomedicalLocationColumnLabel => 'Location';

  @override
  String get biomedicalRiskColumnLabel => 'Risk';

  @override
  String get biomedicalStatusColumnLabel => 'Status';

  @override
  String get biomedicalOwnerColumnLabel => 'Owner';

  @override
  String get biomedicalNextActionColumnLabel => 'Next action';

  @override
  String get biomedicalPreviousPageLabel => 'Previous equipment';

  @override
  String get biomedicalNextPageLabel => 'Next equipment';

  @override
  String biomedicalPageLabel(int from, int to, int total) {
    return 'Showing $from-$to of $total';
  }

  @override
  String get biomedicalNoAssetsTitle => 'No equipment records';

  @override
  String get biomedicalNoAssetsBody =>
      'Equipment records matching this search and filter will appear here.';

  @override
  String get biomedicalDetailTitle => 'Equipment detail';

  @override
  String get biomedicalNoSelectionTitle => 'Select equipment';

  @override
  String get biomedicalNoSelectionBody =>
      'Select equipment to review work orders and status.';

  @override
  String get biomedicalRegistrySectionTitle => 'Registry';

  @override
  String get biomedicalReadinessSectionTitle => 'Readiness';

  @override
  String get biomedicalMaintenanceSectionTitle => 'Maintenance';

  @override
  String get biomedicalComplianceSectionTitle => 'Compliance';

  @override
  String get biomedicalLifecycleSectionTitle => 'Lifecycle';

  @override
  String get biomedicalReportsSectionTitle => 'Report preview';

  @override
  String get biomedicalNotAvailableLabel => '-';

  @override
  String get biomedicalAssetTagLabel => 'Asset tag';

  @override
  String get biomedicalResourceLabel => 'Record type';

  @override
  String get biomedicalEquipmentLabel => 'Equipment';

  @override
  String get biomedicalCategoryLabel => 'Category';

  @override
  String get biomedicalFacilityLabel => 'Facility';

  @override
  String get biomedicalOwnerLabel => 'Owner';

  @override
  String get biomedicalStatusLabel => 'Status';

  @override
  String get biomedicalPriorityLabel => 'Priority';

  @override
  String get biomedicalNextDueLabel => 'Next due';

  @override
  String get biomedicalLastUpdatedLabel => 'Last updated';

  @override
  String get biomedicalTargetPathLabel => 'Audit path';

  @override
  String get biomedicalEditAssetAction => 'Edit asset';

  @override
  String get biomedicalTransferLocationAction => 'Transfer location';

  @override
  String get biomedicalScheduleMaintenanceAction => 'Schedule maintenance';

  @override
  String get biomedicalCreateWorkOrderAction => 'Create work order';

  @override
  String get biomedicalUpdateWorkOrderAction => 'Update work order';

  @override
  String get biomedicalStartWorkOrderAction => 'Start work order';

  @override
  String get biomedicalReturnToServiceAction => 'Return to service';

  @override
  String get biomedicalRecordCalibrationAction => 'Record calibration';

  @override
  String get biomedicalRecordSafetyTestAction => 'Record safety test';

  @override
  String get biomedicalReportDowntimeAction => 'Report downtime';

  @override
  String get biomedicalCloseDowntimeAction => 'Close downtime';

  @override
  String get biomedicalLogIncidentAction => 'Log incident';

  @override
  String get biomedicalAcknowledgeRecallAction => 'Acknowledge recall';

  @override
  String get biomedicalDisposeTransferAction => 'Dispose or transfer';

  @override
  String get biomedicalPrintReportAction => 'Preview report';

  @override
  String get biomedicalRegisterAssetDialogTitle => 'Register equipment';

  @override
  String get biomedicalEditAssetDialogTitle => 'Edit equipment';

  @override
  String get biomedicalTransferLocationDialogTitle =>
      'Transfer equipment location';

  @override
  String get biomedicalScheduleMaintenanceDialogTitle => 'Schedule maintenance';

  @override
  String get biomedicalWorkOrderDialogTitle => 'Create work order';

  @override
  String get biomedicalUpdateWorkOrderDialogTitle => 'Update work order';

  @override
  String get biomedicalStartWorkOrderDialogTitle => 'Start work order';

  @override
  String get biomedicalReturnToServiceDialogTitle =>
      'Return equipment to service';

  @override
  String get biomedicalCalibrationDialogTitle => 'Record calibration';

  @override
  String get biomedicalSafetyTestDialogTitle => 'Record safety test';

  @override
  String get biomedicalDowntimeDialogTitle => 'Report downtime';

  @override
  String get biomedicalCloseDowntimeDialogTitle => 'Close downtime';

  @override
  String get biomedicalIncidentDialogTitle => 'Log incident';

  @override
  String get biomedicalRecallDialogTitle => 'Acknowledge recall';

  @override
  String get biomedicalDisposalDialogTitle => 'Dispose or transfer equipment';

  @override
  String get biomedicalFaultDialogTitle => 'Report equipment fault';

  @override
  String get biomedicalPrintReportDialogTitle => 'Biomedical report';

  @override
  String get biomedicalAssetNameLabel => 'Equipment name';

  @override
  String get biomedicalAssetCodeLabel => 'Asset code';

  @override
  String get biomedicalSerialNumberLabel => 'Serial number';

  @override
  String get biomedicalRoomLabel => 'Room';

  @override
  String get biomedicalNotesLabel => 'Notes';

  @override
  String get biomedicalDescriptionLabel => 'Description';

  @override
  String get biomedicalWorkOrderTitleLabel => 'Work order title';

  @override
  String get biomedicalEngineerLabel => 'Engineer';

  @override
  String get biomedicalPlanNameLabel => 'Plan name';

  @override
  String get biomedicalMaintenanceTypeLabel => 'Maintenance type';

  @override
  String get biomedicalFrequencyDaysLabel => 'Frequency days';

  @override
  String get biomedicalNextDueAtLabel => 'Next due at';

  @override
  String get biomedicalResultLabel => 'Result';

  @override
  String get biomedicalCalibratedAtLabel => 'Calibrated at';

  @override
  String get biomedicalTestedAtLabel => 'Tested at';

  @override
  String get biomedicalDowntimeStartedAtLabel => 'Downtime started';

  @override
  String get biomedicalDowntimeEndedAtLabel => 'Downtime ended';

  @override
  String get biomedicalReasonLabel => 'Reason';

  @override
  String get biomedicalSeverityLabel => 'Severity';

  @override
  String get biomedicalStartedAtLabel => 'Started at';

  @override
  String get biomedicalRecordedAtLabel => 'Recorded at';

  @override
  String get biomedicalEffectiveAtLabel => 'Effective at';

  @override
  String get biomedicalReportedEquipmentNameLabel => 'Temporary equipment name';

  @override
  String get biomedicalPatientSafetyRiskLabel => 'Patient safety risk';

  @override
  String get biomedicalDateTimeHint => 'YYYY-MM-DDTHH:MM';

  @override
  String get biomedicalSubmitAction => 'Submit';

  @override
  String get biomedicalSaveAction => 'Save';

  @override
  String get biomedicalCreateAction => 'Create';

  @override
  String biomedicalFieldRequiredLabel(String label) {
    return '$label is required.';
  }

  @override
  String get biomedicalPanelOverview => 'Overview';

  @override
  String get biomedicalPanelRegistry => 'Registry';

  @override
  String get biomedicalPanelPreventive => 'Preventive';

  @override
  String get biomedicalPanelWorkOrders => 'Work orders';

  @override
  String get biomedicalPanelCompliance => 'Compliance';

  @override
  String get biomedicalPanelSupport => 'Support';

  @override
  String get biomedicalPanelAnalytics => 'Analytics';

  @override
  String get biomedicalDatePresetToday => 'Today';

  @override
  String get biomedicalDatePresetNext7Days => 'Next 7 days';

  @override
  String get biomedicalDatePresetOverdue => 'Overdue';

  @override
  String get biomedicalDatePresetThisMonth => 'This month';

  @override
  String get biomedicalNextActionMaintain => 'Perform maintenance';

  @override
  String get biomedicalNextActionCalibrate => 'Review compliance';

  @override
  String get biomedicalNextActionReturnService => 'Return to service';

  @override
  String get biomedicalNextActionReviewRecall => 'Review recall';

  @override
  String get biomedicalNextActionWorkOrder => 'Work order follow-up';

  @override
  String get biomedicalNextActionReview => 'Review record';

  @override
  String get biomedicalPrintReportBody =>
      'Generated from biomedical registry, readiness, compliance, and lifecycle data.';

  @override
  String get integrationsLoadErrorTitle => 'Integrations could not load';

  @override
  String get integrationsLoadErrorBody =>
      'Refresh the workspace or check service availability.';

  @override
  String get integrationsLoadingTitle => 'Loading integrations';

  @override
  String get integrationsLoadingBody => 'Loading integrations and logs...';

  @override
  String get integrationsFailedStatusLabel => 'Failed';

  @override
  String get integrationsWarningStatusLabel => 'Warning';

  @override
  String get integrationsOperationalStatusLabel => 'Operational';

  @override
  String get integrationsWorkspaceTitle => 'Integrations';

  @override
  String get integrationsCreateIntegrationAction => 'Create integration';

  @override
  String get integrationsCreateApiKeyAction => 'Create API key';

  @override
  String get integrationsCreateWebhookAction => 'Create webhook';

  @override
  String get integrationsAllSummaryLabel => 'Total items';

  @override
  String get integrationsActiveSummaryLabel => 'Active';

  @override
  String get integrationsWarningsSummaryLabel => 'Warnings';

  @override
  String get integrationsFailedSummaryLabel => 'Failed';

  @override
  String get integrationsApiKeysSummaryLabel => 'API keys';

  @override
  String get integrationsWebhooksSummaryLabel => 'Webhooks';

  @override
  String get integrationsWorklistTitle => 'Integration worklist';

  @override
  String get integrationsWorklistDescription =>
      'Integrations, API keys, webhooks, and logs.';

  @override
  String get integrationsSearchLabel => 'Search integrations';

  @override
  String get integrationsSearchHint =>
      'Search by name, type, status, owner, or reference';

  @override
  String get integrationsFiltersLabel => 'Filters';

  @override
  String get integrationsFilterAll => 'All';

  @override
  String get integrationsFilterGroupLabel => 'Group';

  @override
  String get integrationsPreviousPageLabel => 'Previous page';

  @override
  String get integrationsNextPageLabel => 'Next page';

  @override
  String integrationsPageLabel(int from, int to, int total) {
    return '$from-$to of $total';
  }

  @override
  String get integrationsEmptyTitle => 'No integration items';

  @override
  String get integrationsEmptyBody =>
      'Create an integration, API key, or webhook.';

  @override
  String get integrationsTypeColumnLabel => 'Type';

  @override
  String get integrationsNameColumnLabel => 'Name';

  @override
  String get integrationsStatusColumnLabel => 'Status';

  @override
  String get integrationsOwnerColumnLabel => 'Owner';

  @override
  String get integrationsScopeColumnLabel => 'Scope';

  @override
  String get integrationsLastEventColumnLabel => 'Last event';

  @override
  String get integrationsNextActionColumnLabel => 'Next action';

  @override
  String integrationsMobileSubtitle(String kind, String scope) {
    return '$kind | $scope';
  }

  @override
  String get integrationsNoSelectionTitle => 'Select an integration item';

  @override
  String get integrationsNoSelectionBody =>
      'Select a row for config, keys, and logs.';

  @override
  String get integrationsConfigureAction => 'Configure';

  @override
  String get integrationsTestConnectionAction => 'Test connection';

  @override
  String get integrationsSyncNowAction => 'Sync now';

  @override
  String get integrationsDisableAction => 'Disable';

  @override
  String get integrationsEnableAction => 'Enable';

  @override
  String get integrationsManagePermissionsAction => 'Manage permissions';

  @override
  String get integrationsRevokeApiKeyAction => 'Revoke key';

  @override
  String get integrationsEditWebhookAction => 'Edit webhook';

  @override
  String get integrationsReplayWebhookAction => 'Replay webhook';

  @override
  String get integrationsReplayLogAction => 'Replay log';

  @override
  String get integrationsReferenceLabel => 'Reference';

  @override
  String get integrationsActionResultTitle => 'Latest action result';

  @override
  String get integrationsMaskedSecretTitle => 'Masked key';

  @override
  String get integrationsRotationGapTitle => 'Key rotation unavailable';

  @override
  String get integrationsRotationGapBody =>
      'Create a new key, update systems, then revoke the old key.';

  @override
  String get integrationsEventLabel => 'Event';

  @override
  String get integrationsTargetHostLabel => 'Target host';

  @override
  String get integrationsIntegrationLabel => 'Integration';

  @override
  String get integrationsSanitizedLogTitle => 'Sanitized log message';

  @override
  String get integrationsInteropReadyBody =>
      'Interoperability actions are available.';

  @override
  String get integrationsConfigurationTitle => 'Configuration';

  @override
  String get integrationsConfigurationMaskedBody =>
      'Sensitive values are masked in this response.';

  @override
  String get integrationsConfigurationEmptyBody =>
      'No configuration values for this integration.';

  @override
  String get integrationsNoConfigurationRows => 'No configuration rows';

  @override
  String get integrationsRelatedWebhooksTitle => 'Related webhooks';

  @override
  String get integrationsNoRelatedWebhooks => 'No related webhooks';

  @override
  String get integrationsRelatedLogsTitle => 'Related logs';

  @override
  String get integrationsNoRelatedLogs => 'No related logs';

  @override
  String get integrationsPermissionsTitle => 'Permissions';

  @override
  String get integrationsNoPermissions => 'No permissions granted';

  @override
  String get integrationsRemovePermissionDialogTitle => 'Remove permission?';

  @override
  String get integrationsRemovePermissionDialogBody =>
      'This API key will immediately lose the selected permission.';

  @override
  String get integrationsRemovePermissionAction => 'Remove permission';

  @override
  String get integrationsNameFieldLabel => 'Name';

  @override
  String get integrationsNameRequiredMessage => 'Enter a name.';

  @override
  String get integrationsTypeFieldLabel => 'Type';

  @override
  String get integrationsConfigFieldLabel => 'Configuration';

  @override
  String get integrationsConfigCreateHelper =>
      'One key=value per line. Sensitive keys are not shown again.';

  @override
  String get integrationsConfigUpdateHelper =>
      'Enter only settings to change. Sensitive values stay hidden.';

  @override
  String get integrationsCreateIntegrationSubmitAction => 'Create integration';

  @override
  String get integrationsSaveIntegrationAction => 'Save integration';

  @override
  String get integrationsApiKeyNameFieldLabel => 'Key name';

  @override
  String get integrationsApiKeyNameRequiredMessage => 'Enter a key name.';

  @override
  String get integrationsExpiresAtFieldLabel => 'Expires at';

  @override
  String get integrationsIsoDateHint => 'YYYY-MM-DD or ISO timestamp';

  @override
  String get integrationsCreateApiKeySubmitAction => 'Create API key';

  @override
  String get integrationsIntegrationFieldLabel => 'Integration';

  @override
  String get integrationsEventFieldLabel => 'Event';

  @override
  String get integrationsEventRequiredMessage => 'Enter an event name.';

  @override
  String get integrationsTargetUrlFieldLabel => 'Target URL';

  @override
  String get integrationsTargetUrlRequiredMessage => 'Enter a target URL.';

  @override
  String get integrationsWebhookActiveFieldLabel => 'Webhook active';

  @override
  String get integrationsCreateWebhookSubmitAction => 'Create webhook';

  @override
  String get integrationsSaveWebhookAction => 'Save webhook';

  @override
  String get integrationsApiKeyFieldLabel => 'API key';

  @override
  String get integrationsApiKeyRequiredMessage => 'Choose an API key.';

  @override
  String get integrationsPermissionFieldLabel => 'Permission';

  @override
  String get integrationsPermissionRequiredMessage => 'Choose a permission.';

  @override
  String get integrationsAddPermissionAction => 'Add permission';

  @override
  String get integrationsCreateIntegrationDialogTitle => 'Create integration';

  @override
  String get integrationsConfigureIntegrationDialogTitle =>
      'Configure integration';

  @override
  String get integrationsCreateApiKeyDialogTitle => 'Create API key';

  @override
  String get integrationsCreateWebhookDialogTitle => 'Create webhook';

  @override
  String get integrationsEditWebhookDialogTitle => 'Edit webhook';

  @override
  String get integrationsManagePermissionsDialogTitle =>
      'Manage API key permissions';

  @override
  String get integrationsSecretMissing => 'Secret not returned';

  @override
  String get integrationsApiKeyCreatedDialogTitle => 'API key created';

  @override
  String get integrationsApiKeyCreatedSecretTitle => 'One-time secret';

  @override
  String get integrationsApiKeyCreatedSecretBody =>
      'This value is shown once. Store it securely before closing this dialog.';

  @override
  String get integrationsCopySecretAction => 'Copy secret';

  @override
  String get integrationsTestConnectionDialogTitle => 'Test connection?';

  @override
  String get integrationsTestConnectionDialogBody =>
      'The system will run the integration connection test.';

  @override
  String get integrationsSyncNowDialogTitle => 'Sync now?';

  @override
  String get integrationsSyncNowDialogBody =>
      'The system will enqueue an immediate integration sync.';

  @override
  String get integrationsEnableIntegrationDialogTitle => 'Enable integration?';

  @override
  String get integrationsDisableIntegrationDialogTitle =>
      'Disable integration?';

  @override
  String get integrationsEnableIntegrationDialogBody =>
      'This integration will become available for downstream workflows.';

  @override
  String get integrationsDisableIntegrationDialogBody =>
      'This integration will stop participating in downstream workflows.';

  @override
  String get integrationsEnableApiKeyDialogTitle => 'Enable API key?';

  @override
  String get integrationsDisableApiKeyDialogTitle => 'Disable API key?';

  @override
  String get integrationsEnableApiKeyDialogBody =>
      'This API key can authenticate requests again.';

  @override
  String get integrationsDisableApiKeyDialogBody =>
      'This API key will stop authenticating requests.';

  @override
  String get integrationsEnableWebhookDialogTitle => 'Enable webhook?';

  @override
  String get integrationsDisableWebhookDialogTitle => 'Disable webhook?';

  @override
  String get integrationsEnableWebhookDialogBody =>
      'This webhook will receive matching events again.';

  @override
  String get integrationsDisableWebhookDialogBody =>
      'This webhook will stop receiving matching events.';

  @override
  String get integrationsRevokeApiKeyDialogTitle => 'Revoke API key?';

  @override
  String get integrationsRevokeApiKeyDialogBody =>
      'This permanently deletes the API key and its local permission grants.';

  @override
  String get integrationsReplayWebhookDialogTitle => 'Replay webhook?';

  @override
  String get integrationsReplayWebhookDialogBody =>
      'The system will replay the webhook delivery.';

  @override
  String get integrationsReplayLogDialogTitle => 'Replay log?';

  @override
  String get integrationsReplayLogDialogBody =>
      'The system will retry the logged integration event.';

  @override
  String get integrationsFilterIntegrations => 'Integrations';

  @override
  String get integrationsFilterApiKeys => 'API keys';

  @override
  String get integrationsFilterWebhooks => 'Webhooks';

  @override
  String get integrationsFilterLogs => 'Logs';

  @override
  String get integrationsFilterInterop => 'Interop';

  @override
  String get integrationsFilterActive => 'Active';

  @override
  String get integrationsFilterWarning => 'Warning';

  @override
  String get integrationsFilterFailed => 'Failed';

  @override
  String get integrationsFilterDisabled => 'Disabled';

  @override
  String get integrationsTypeHl7 => 'HL7';

  @override
  String get integrationsTypeFhir => 'FHIR';

  @override
  String get integrationsTypeLab => 'Lab';

  @override
  String get integrationsTypeRadiology => 'Radiology';

  @override
  String get integrationsTypeBilling => 'Billing';

  @override
  String get integrationsTypeOther => 'Other';

  @override
  String get integrationsStatusActive => 'Active';

  @override
  String get integrationsStatusInactive => 'Inactive';

  @override
  String get integrationsStatusError => 'Error';

  @override
  String get integrationsStatusFailed => 'Failed';

  @override
  String get integrationsStatusReady => 'Ready';

  @override
  String get integrationsStatusBackendGap => 'Unavailable';

  @override
  String get integrationsStatusQueued => 'Queued';

  @override
  String get integrationsStatusConnected => 'Connected';

  @override
  String get integrationsKindIntegration => 'Integration';

  @override
  String get integrationsKindApiKey => 'API key';

  @override
  String get integrationsKindWebhook => 'Webhook';

  @override
  String get integrationsKindLog => 'Log';

  @override
  String get integrationsKindInterop => 'Interop';

  @override
  String get integrationsNoScopesLabel => 'No scopes';

  @override
  String get integrationsOneScopeLabel => '1 scope';

  @override
  String get integrationsInteropFhirScope => 'FHIR exchange';

  @override
  String get integrationsInteropHl7Scope => 'HL7 messaging';

  @override
  String get integrationsInteropDicomScope => 'DICOM linking';

  @override
  String get integrationsInteropMigrationScope => 'Migration import and export';

  @override
  String get integrationsInteropStatusScope => 'Readiness status';

  @override
  String integrationsManyScopesLabel(String count) {
    return '$count scopes';
  }

  @override
  String get integrationsNextActionReviewFailure => 'Review failure';

  @override
  String get integrationsNextActionEnable => 'Enable item';

  @override
  String get integrationsNextActionMonitor => 'Monitor';

  @override
  String get integrationsNextActionReviewKey => 'Review key';

  @override
  String get integrationsNextActionRotateOrMonitor => 'Rotate or monitor';

  @override
  String get integrationsNextActionEnableWebhook => 'Enable webhook';

  @override
  String get integrationsNextActionMonitorDelivery => 'Monitor delivery';

  @override
  String get integrationsNextActionReplayOrEscalate => 'Replay or escalate';

  @override
  String get integrationsNextActionReview => 'Review';

  @override
  String get integrationsNextActionRunEndpoint => 'Run action';

  @override
  String get integrationsNextActionUseStatusLogs => 'Use status logs';

  @override
  String get integrationsInteropFhirTitle => 'FHIR exchange';

  @override
  String get integrationsInteropHl7Title => 'HL7 messages';

  @override
  String get integrationsInteropDicomTitle => 'DICOM study linking';

  @override
  String get integrationsInteropMigrationTitle => 'Migration tools';

  @override
  String get integrationsInteropReadinessTitle => 'Interop readiness';

  @override
  String get integrationsInteropReadinessGapBody =>
      'No dedicated readiness signal. Use integration status and logs.';

  @override
  String get integrationsSavedMessage => 'Integration changes saved.';

  @override
  String get reportsTitle => 'Reports and audit';

  @override
  String get reportsLoadingTitle => 'Loading reports workspace';

  @override
  String get reportsLoadingBody =>
      'Loading reports, schedules, and dashboards...';

  @override
  String get reportsLiveStatus => 'Live';

  @override
  String get reportsSavingStatus => 'Saving';

  @override
  String get reportsRunAction => 'Run report';

  @override
  String get reportsScheduleAction => 'Schedule';

  @override
  String get reportsRetryAction => 'Retry';

  @override
  String get reportsCancelRunAction => 'Cancel run';

  @override
  String get reportsDownloadAction => 'Download';

  @override
  String get reportsPrintAction => 'Print';

  @override
  String get reportsExportEvidenceAction => 'Export evidence';

  @override
  String get reportsSearchLabel => 'Search reports and logs';

  @override
  String get reportsSearchHint =>
      'Search report name, module, owner, status, or record';

  @override
  String get reportsComplianceSearchHint =>
      'Search user, action, record, patient, purpose, or reason';

  @override
  String get reportsClearSearchLabel => 'Clear reports search';

  @override
  String get reportsFiltersLabel => 'Report filters';

  @override
  String get reportsPanelFilterLabel => 'Workspace panel';

  @override
  String get reportsStatusFilterLabel => 'Status';

  @override
  String get reportsFormatFilterLabel => 'Format';

  @override
  String get reportsDatasetFilterLabel => 'Dataset';

  @override
  String get reportsDateFilterLabel => 'Date range';

  @override
  String get reportsDateFromLabel => 'From';

  @override
  String get reportsDateToLabel => 'To';

  @override
  String get reportsDatePickerLabel => 'Choose date';

  @override
  String get reportsInvalidDateMessage => 'Enter a valid date.';

  @override
  String get reportsComplianceTypeFilterLabel => 'Event type';

  @override
  String get reportsAllStatusesLabel => 'All statuses';

  @override
  String get reportsAllFormatsLabel => 'All formats';

  @override
  String get reportsAllDatasetsLabel => 'All datasets';

  @override
  String get reportsPanelOverview => 'Overview';

  @override
  String get reportsPanelCatalog => 'Catalog';

  @override
  String get reportsPanelDelivery => 'Runs and delivery';

  @override
  String get reportsPanelDashboards => 'Dashboards';

  @override
  String get reportsPanelMonitor => 'KPI monitor';

  @override
  String get reportsPanelActivity => 'Analytics activity';

  @override
  String get reportsPanelAudit => 'Audit logs';

  @override
  String get reportsPanelPhi => 'PHI access';

  @override
  String get reportsPanelProcessing => 'Processing logs';

  @override
  String get reportsWorklistDescription =>
      'Search, run, schedule, print, and export reports.';

  @override
  String get reportsComplianceDescription =>
      'Audit, PHI access, and data-processing logs.';

  @override
  String get reportsSchedulesTitle => 'Schedules';

  @override
  String get reportsSchedulesDescription =>
      'Saved schedules refresh independently of runs.';

  @override
  String get reportsNoItemsTitle => 'No report records';

  @override
  String get reportsNoItemsBody =>
      'No report records match the current filters.';

  @override
  String get reportsNoSchedulesTitle => 'No schedules';

  @override
  String get reportsNoSchedulesBody =>
      'No saved report schedules match this view.';

  @override
  String get reportsNoComplianceLogsTitle => 'No compliance logs';

  @override
  String get reportsNoComplianceLogsBody =>
      'No audit or compliance evidence matches the current filters.';

  @override
  String get reportsPreviewTitle => 'Report preview';

  @override
  String get reportsComplianceDetailTitle => 'Evidence detail';

  @override
  String get reportsNoSelectionTitle => 'No selection';

  @override
  String get reportsNoSelectionBody =>
      'Select a report, run, KPI, or schedule.';

  @override
  String get reportsNoComplianceSelectionBody =>
      'Select an audit, PHI access, or processing log.';

  @override
  String get reportsNameColumnLabel => 'Name';

  @override
  String get reportsStatusColumnLabel => 'Status';

  @override
  String get reportsReferenceLabel => 'Reference';

  @override
  String get reportsOwnerLabel => 'Owner';

  @override
  String get reportsUpdatedColumnLabel => 'Updated';

  @override
  String get reportsFormatColumnLabel => 'Format';

  @override
  String get reportsCategoryLabel => 'Category';

  @override
  String get reportsDatasetLabel => 'Dataset';

  @override
  String get reportsFacilityLabel => 'Facility';

  @override
  String get reportsValueLabel => 'Value';

  @override
  String get reportsErrorLabel => 'Error';

  @override
  String get reportsEventColumnLabel => 'Event';

  @override
  String get reportsUserColumnLabel => 'User';

  @override
  String get reportsRecordColumnLabel => 'Record';

  @override
  String get reportsTimestampColumnLabel => 'Timestamp';

  @override
  String get reportsPatientLabel => 'Patient';

  @override
  String get reportsActionLabel => 'Action';

  @override
  String get reportsEntityLabel => 'Entity';

  @override
  String get reportsScopeLabel => 'Scope';

  @override
  String get reportsPurposeLabel => 'Purpose';

  @override
  String get reportsLegalBasisLabel => 'Legal basis';

  @override
  String get reportsIpAddressLabel => 'IP address';

  @override
  String get reportsDetailsLabel => 'Details';

  @override
  String get reportsPreviousPageLabel => 'Previous page';

  @override
  String get reportsNextPageLabel => 'Next page';

  @override
  String reportsPageLabel(int first, int last, int total) {
    return '$first-$last of $total';
  }

  @override
  String get reportsTimelineTitle => 'Recent report activity';

  @override
  String get reportsTimelineDescription =>
      'Recent runs, schedules, KPIs, and analytics events.';

  @override
  String get reportsRunDialogTitle => 'Run report';

  @override
  String get reportsRetryDialogTitle => 'Retry report run';

  @override
  String get reportsScheduleDialogTitle => 'Schedule report';

  @override
  String get reportsFormatFieldLabel => 'Output format';

  @override
  String get reportsRetentionDaysFieldLabel => 'Retention days';

  @override
  String get reportsScheduleNameFieldLabel => 'Schedule name';

  @override
  String get reportsFrequencyFieldLabel => 'Frequency';

  @override
  String get reportsTimeOfDayFieldLabel => 'Time of day';

  @override
  String get reportsTimeOfDayHint => 'HH:mm';

  @override
  String get reportsCreateScheduleAction => 'Create schedule';

  @override
  String get reportsFrequencyDaily => 'Daily';

  @override
  String get reportsFrequencyWeekly => 'Weekly';

  @override
  String get reportsFrequencyMonthly => 'Monthly';

  @override
  String get reportsCancelRunDialogTitle => 'Cancel report run';

  @override
  String get reportsCancelRunDialogBody =>
      'Cancel this queued or processing report run?';

  @override
  String get reportsExportEvidenceDialogTitle => 'Export evidence';

  @override
  String get reportsExportEvidenceDialogBody =>
      'Generate a facility-branded evidence document from this audit record.';

  @override
  String get reportsSavedMessage => 'Reports workspace updated.';

  @override
  String get reportsDownloadRequestedMessage =>
      'Report download was requested.';

  @override
  String get reportsPrintSubtitle => 'Generated report metadata';

  @override
  String get reportsEvidenceSubtitle => 'Compliance evidence';

  @override
  String get reportsGeneratedByLabel => 'Generated by';

  @override
  String get reportsPrintFooter =>
      'Confidential report document generated from system data.';

  @override
  String get reportsEvidenceFooter =>
      'Compliance evidence generated from audit data.';

  @override
  String get navigationPhysiotherapyLabel => 'Physiotherapy';

  @override
  String get navigationPhysiotherapyShortLabel => 'Physio';

  @override
  String get communicationsLoadingTitle => 'Loading communications';

  @override
  String get communicationsLoadingBody =>
      'Loading notifications and threads...';

  @override
  String get communicationsWorkspaceTitle => 'Communications';

  @override
  String get communicationsLiveStatus => 'Live sync';

  @override
  String get communicationsSavingStatus => 'Saving';

  @override
  String get communicationsActionSavedMessage => 'Communication action saved.';

  @override
  String get communicationsMessageSentMessage => 'Message sent.';

  @override
  String get communicationsInboxPanelLabel => 'Messages';

  @override
  String get communicationsMessagesPanelLabel => 'Messages';

  @override
  String get communicationsNotificationsPanelLabel => 'Notifications';

  @override
  String get communicationsDeliveriesPanelLabel => 'Deliveries';

  @override
  String get communicationsTemplatesPanelLabel => 'Templates';

  @override
  String get communicationsUnreadThreadsSummaryLabel => 'Unread threads';

  @override
  String get communicationsUnreadNotificationsSummaryLabel => 'Unread alerts';

  @override
  String get communicationsFailedDeliveriesSummaryLabel => 'Failed deliveries';

  @override
  String get communicationsTemplatesSummaryLabel => 'Templates';

  @override
  String get communicationsListDescription =>
      'Alerts, threads, delivery state, and templates.';

  @override
  String get communicationsSearchSemanticLabel => 'Search communications';

  @override
  String get communicationsSearchHint =>
      'Search alert, patient, source, sender, recipient, or message';

  @override
  String get communicationsClearSearchAction => 'Clear communications search';

  @override
  String get communicationsAdvancedFiltersLabel => 'Communication filters';

  @override
  String get communicationsAdvancedFiltersTitle => 'Communication filters';

  @override
  String get communicationsApplyFiltersAction => 'Apply filters';

  @override
  String get communicationsResetFiltersAction => 'Reset filters';

  @override
  String get communicationsQueueFilterLabel => 'Queue';

  @override
  String get communicationsFlagsFilterLabel => 'Flags';

  @override
  String get communicationsAllFilterLabel => 'All';

  @override
  String get communicationsUnreadFilterLabel => 'Unread';

  @override
  String get communicationsSensitiveFilterLabel => 'Sensitive';

  @override
  String get communicationsPreviousPageLabel => 'Previous communications page';

  @override
  String get communicationsNextPageLabel => 'Next communications page';

  @override
  String communicationsPageLabel(int from, int to, int total) {
    return '$from-$to of $total';
  }

  @override
  String get communicationsThreadColumnLabel => 'Thread';

  @override
  String get communicationsParticipantsColumnLabel => 'Participants';

  @override
  String get communicationsStatusColumnLabel => 'Status';

  @override
  String get communicationsLastMessageColumnLabel => 'Last message';

  @override
  String get communicationsTimeColumnLabel => 'Time';

  @override
  String get communicationsAlertColumnLabel => 'Alert';

  @override
  String get communicationsTypeColumnLabel => 'Type';

  @override
  String get communicationsPriorityColumnLabel => 'Priority';

  @override
  String get communicationsStateColumnLabel => 'State';

  @override
  String get communicationsNotificationColumnLabel => 'Notification';

  @override
  String get communicationsChannelColumnLabel => 'Channel';

  @override
  String get communicationsRecipientColumnLabel => 'Recipient';

  @override
  String get communicationsAttemptsColumnLabel => 'Attempts';

  @override
  String get communicationsTemplateColumnLabel => 'Template';

  @override
  String get communicationsVariablesColumnLabel => 'Variables';

  @override
  String get communicationsNoConversationsTitle => 'No conversations';

  @override
  String get communicationsNoConversationsBody =>
      'Matching conversation threads will appear here.';

  @override
  String get communicationsNoNotificationsTitle => 'No notifications';

  @override
  String get communicationsNoNotificationsBody =>
      'Matching workflow alerts and reminders will appear here.';

  @override
  String get communicationsNoDeliveriesTitle => 'No deliveries';

  @override
  String get communicationsNoDeliveriesBody =>
      'Notification channel delivery attempts will appear here.';

  @override
  String get communicationsNoTemplatesTitle => 'No templates';

  @override
  String get communicationsNoTemplatesBody =>
      'Reusable communication templates will appear here.';

  @override
  String get communicationsConversationDetailTitle => 'Conversation detail';

  @override
  String get communicationsNotificationDetailTitle => 'Notification detail';

  @override
  String get communicationsDeliveryDetailTitle => 'Delivery detail';

  @override
  String get communicationsTemplateDetailTitle => 'Template detail';

  @override
  String get communicationsNoConversationSelectedTitle =>
      'Select a conversation';

  @override
  String get communicationsNoConversationSelectedBody =>
      'Choose a thread to review messages, participants, and linked records.';

  @override
  String get communicationsNoNotificationSelectedTitle =>
      'Select a notification';

  @override
  String get communicationsNoNotificationSelectedBody =>
      'Choose an alert to review delivery history and quick actions.';

  @override
  String get communicationsNoDeliverySelectedTitle => 'Select a delivery';

  @override
  String get communicationsNoDeliverySelectedBody =>
      'Choose a delivery attempt to review channel, recipient, and error details.';

  @override
  String get communicationsNoTemplateSelectedTitle => 'Select a template';

  @override
  String get communicationsNoTemplateSelectedBody =>
      'Choose a template to review channel, subject, variables, and preview.';

  @override
  String get communicationsSubjectLabel => 'Subject';

  @override
  String get communicationsParticipantsLabel => 'Participants';

  @override
  String get communicationsCreatedAtLabel => 'Created at';

  @override
  String get communicationsUpdatedAtLabel => 'Updated at';

  @override
  String get communicationsReadAtLabel => 'Read at';

  @override
  String get communicationsTypeLabel => 'Type';

  @override
  String get communicationsContextLabel => 'Context';

  @override
  String get communicationsNotificationLabel => 'Notification';

  @override
  String get communicationsChannelLabel => 'Channel';

  @override
  String get communicationsRecipientLabel => 'Recipient';

  @override
  String get communicationsAttemptsLabel => 'Attempts';

  @override
  String get communicationsProviderLabel => 'Provider';

  @override
  String get communicationsSentAtLabel => 'Sent at';

  @override
  String get communicationsDeliveredAtLabel => 'Delivered at';

  @override
  String get communicationsFailedAtLabel => 'Failed at';

  @override
  String get communicationsStatusLabel => 'Status';

  @override
  String get communicationsVariablesLabel => 'Variables';

  @override
  String get communicationsPreviewTitle => 'Preview';

  @override
  String get communicationsMessageThreadTitle => 'Message thread';

  @override
  String get communicationsNoMessagesBody =>
      'No messages are available for this thread.';

  @override
  String get communicationsDeliveryHistoryTitle => 'Delivery history';

  @override
  String get communicationsDeliveryErrorTitle => 'Delivery error';

  @override
  String get communicationsOpenLinkedRecordAction => 'Open linked record';

  @override
  String get communicationsMarkReadAction => 'Mark read';

  @override
  String get communicationsMarkUnreadAction => 'Mark unread';

  @override
  String get communicationsArchiveAction => 'Archive';

  @override
  String get communicationsUnarchiveAction => 'Unarchive';

  @override
  String get communicationsSendMessageAction => 'Send message';

  @override
  String get communicationsSendMessageDialogTitle => 'Send message';

  @override
  String get communicationsMessageFieldLabel => 'Message';

  @override
  String get communicationsMarkReadDialogTitle => 'Mark as read';

  @override
  String get communicationsMarkUnreadDialogTitle => 'Mark as unread';

  @override
  String get communicationsArchiveDialogTitle => 'Archive communication';

  @override
  String get communicationsUnarchiveDialogTitle => 'Unarchive conversation';

  @override
  String get communicationsMarkConversationReadDialogBody =>
      'Mark this conversation read for your account.';

  @override
  String get communicationsMarkNotificationReadDialogBody =>
      'Mark this notification read for your account.';

  @override
  String get communicationsMarkNotificationUnreadDialogBody =>
      'Move this notification back to unread.';

  @override
  String get communicationsArchiveConversationDialogBody =>
      'Archive this conversation from your active inbox.';

  @override
  String get communicationsUnarchiveConversationDialogBody =>
      'Return this conversation to your active inbox.';

  @override
  String get communicationsArchiveNotificationDialogBody =>
      'Archive this notification from your active alerts.';

  @override
  String get communicationsUnreadStatus => 'Unread';

  @override
  String get communicationsReadStatus => 'Read';

  @override
  String get communicationsArchivedStatus => 'Archived';

  @override
  String get communicationsSensitiveStatus => 'Sensitive';

  @override
  String get communicationsActiveStatus => 'Active';

  @override
  String get communicationsInactiveStatus => 'Inactive';

  @override
  String get communicationsJustNowLabel => 'Just now';

  @override
  String communicationsMinutesAgoLabel(int minutes) {
    return '${minutes}m ago';
  }

  @override
  String communicationsHoursAgoLabel(int hours) {
    return '${hours}h ago';
  }

  @override
  String communicationsDaysAgoLabel(int days) {
    return '${days}d ago';
  }

  @override
  String get communicationsAttachFileAction => 'Attach file';

  @override
  String get communicationsNewMessageAction => 'New message';

  @override
  String get communicationsNewGroupAction => 'New group';

  @override
  String get communicationsFavoritesFilterLabel => 'Favorites';

  @override
  String get communicationsFlaggedFilterLabel => 'Flagged';

  @override
  String get communicationsArchivedFilterLabel => 'Archived';

  @override
  String get communicationsSentFilterLabel => 'Sent';

  @override
  String get communicationsReadFilterLabel => 'Read';

  @override
  String get communicationsComposeReadOnlyBody =>
      'You can view this thread but cannot send messages.';

  @override
  String get communicationsFirstMessageHint =>
      'Send the first message to start this conversation.';

  @override
  String get communicationsGroupMembersRequiredHelper =>
      'Add at least one member to create the group.';

  @override
  String get communicationsConversationStartedMessage =>
      'Conversation started — send your first message.';

  @override
  String get communicationsClientFilterNotice =>
      'Some filters are applied locally until server support is available.';

  @override
  String get communicationsLoadMoreAction => 'Load more';

  @override
  String get communicationsBackToInboxAction => 'Back to inbox';

  @override
  String communicationsGroupMembersLabel(int count) {
    return '$count members';
  }

  @override
  String get communicationsThreadMenuAction => 'Conversation actions';

  @override
  String get communicationsFavoriteAction => 'Favorite';

  @override
  String get communicationsUnfavoriteAction => 'Remove favorite';

  @override
  String get communicationsFlagAction => 'Flag';

  @override
  String get communicationsUnflagAction => 'Remove flag';

  @override
  String get communicationsManageMembersAction => 'Manage members';

  @override
  String get communicationsManageMembersTitle => 'Manage members';

  @override
  String get communicationsAddMemberLabel => 'Add member';

  @override
  String get communicationsAddMemberAction => 'Add member';

  @override
  String communicationsLastReadLabel(String timestamp) {
    return 'Last read $timestamp';
  }

  @override
  String get communicationsStartConversationAction => 'Start conversation';

  @override
  String get communicationsGroupNameLabel => 'Group name';

  @override
  String get communicationsSensitiveConversationLabel =>
      'Sensitive conversation';

  @override
  String get communicationsCreateGroupAction => 'Create group';

  @override
  String get housekeepingTitle => 'Housekeeping';

  @override
  String get housekeepingLoadingTitle => 'Loading housekeeping';

  @override
  String get housekeepingLoadingBody =>
      'Loading cleaning tasks and schedules...';

  @override
  String get housekeepingLiveStatus => 'Live sync';

  @override
  String get housekeepingSavingStatus => 'Saving';

  @override
  String get housekeepingSavedMessage => 'Housekeeping changes saved.';

  @override
  String get housekeepingCreateTaskAction => 'Create task';

  @override
  String get housekeepingCreateScheduleAction => 'Create schedule';

  @override
  String get housekeepingRequestMaintenanceAction => 'Request maintenance';

  @override
  String get housekeepingReportSummaryAction => 'Report';

  @override
  String get housekeepingPendingTasksSummaryLabel => 'Pending tasks';

  @override
  String get housekeepingCompletedTodaySummaryLabel => 'Completed today';

  @override
  String get housekeepingOpenRequestsSummaryLabel => 'Open requests';

  @override
  String get housekeepingOverdueRequestsSummaryLabel => 'Overdue requests';

  @override
  String get housekeepingAssetsSummaryLabel => 'Assets';

  @override
  String get housekeepingWorklistDescription =>
      'Cleaning, schedules, bed turnover, and maintenance.';

  @override
  String get housekeepingSearchLabel => 'Search housekeeping';

  @override
  String get housekeepingSearchHint =>
      'Search location, room, bed, assignee, status, priority, or date';

  @override
  String get housekeepingClearSearchAction => 'Clear search';

  @override
  String get housekeepingFiltersAction => 'Filters';

  @override
  String get housekeepingFiltersTitle => 'Housekeeping filters';

  @override
  String get housekeepingApplyFiltersAction => 'Apply filters';

  @override
  String get housekeepingClearFiltersAction => 'Clear filters';

  @override
  String get housekeepingPreviousPageLabel => 'Previous page';

  @override
  String get housekeepingNextPageLabel => 'Next page';

  @override
  String housekeepingPageLabel(int first, int last, int total) {
    return '$first - $last of $total items';
  }

  @override
  String get housekeepingEmptyQueueTitle => 'No housekeeping items';

  @override
  String get housekeepingEmptyQueueBody =>
      'No tasks match the current filters.';

  @override
  String get housekeepingTaskColumnLabel => 'Task';

  @override
  String get housekeepingLocationColumnLabel => 'Location';

  @override
  String get housekeepingAssigneeColumnLabel => 'Assignee';

  @override
  String get housekeepingDueColumnLabel => 'Due time';

  @override
  String get housekeepingStatusColumnLabel => 'Status';

  @override
  String get housekeepingNextActionColumnLabel => 'Next action';

  @override
  String get housekeepingNoSelectionTitle => 'Select a housekeeping item';

  @override
  String get housekeepingNoSelectionBody =>
      'Select a task or schedule to review actions.';

  @override
  String get housekeepingDetailTitle => 'Housekeeping detail';

  @override
  String get housekeepingReferenceLabel => 'Reference';

  @override
  String get housekeepingLocationLabel => 'Location';

  @override
  String get housekeepingAssigneeLabel => 'Assignee';

  @override
  String get housekeepingDueLabel => 'Due';

  @override
  String get housekeepingReadinessTitle => 'Readiness';

  @override
  String get housekeepingAssignAction => 'Assign';

  @override
  String get housekeepingStartAction => 'Start';

  @override
  String get housekeepingStartDialogTitle => 'Start cleaning';

  @override
  String get housekeepingStartDialogBody =>
      'Mark this housekeeping task as in progress.';

  @override
  String get housekeepingCompleteAction => 'Complete';

  @override
  String get housekeepingCompleteDialogTitle => 'Complete cleaning';

  @override
  String get housekeepingCompleteDialogBody =>
      'Mark this cleaning task as completed and refresh readiness.';

  @override
  String get housekeepingCancelAction => 'Cancel';

  @override
  String get housekeepingCancelDialogTitle => 'Cancel task';

  @override
  String get housekeepingCancelDialogBody => 'Cancel this housekeeping task.';

  @override
  String get housekeepingMarkReadyAction => 'Mark ready';

  @override
  String get housekeepingBackendGapTooltip => 'Workflow not available yet';

  @override
  String get housekeepingTriageAction => 'Triage';

  @override
  String get housekeepingCompleteRequestAction => 'Complete request';

  @override
  String get housekeepingCompleteRequestDialogTitle =>
      'Complete maintenance request';

  @override
  String get housekeepingCompleteRequestDialogBody =>
      'Mark this maintenance handoff as completed.';

  @override
  String get housekeepingCancelRequestAction => 'Cancel request';

  @override
  String get housekeepingCancelRequestDialogTitle =>
      'Cancel maintenance request';

  @override
  String get housekeepingCancelRequestDialogBody =>
      'Cancel this maintenance handoff.';

  @override
  String get housekeepingTaskReadinessBody =>
      'Cleaning progress and readiness are refreshed from the housekeeping task record.';

  @override
  String get housekeepingScheduleReadinessBody =>
      'Scheduled cleaning keeps this location on a recurring readiness plan.';

  @override
  String get housekeepingMaintenanceReadinessBody =>
      'Maintenance handoffs keep cleaning issues visible without losing location context.';

  @override
  String get housekeepingUnavailableWorkflowsTitle => 'Unavailable workflows';

  @override
  String get housekeepingUnavailableWorkflowsBody =>
      'This workspace only exposes actions available for the current facility.';

  @override
  String get housekeepingFacilityFieldLabel => 'Facility';

  @override
  String get housekeepingFacilityFieldHint => 'Select a facility';

  @override
  String get housekeepingRoomFieldLabel => 'Room or bed';

  @override
  String get housekeepingRoomFieldHint => 'Select a room or bed';

  @override
  String get housekeepingAssigneeFieldLabel => 'Assignee or team';

  @override
  String get housekeepingAssigneeFieldHint => 'Select staff or team';

  @override
  String get housekeepingStatusFieldLabel => 'Status';

  @override
  String get housekeepingStatusRequiredMessage => 'Select a status.';

  @override
  String get housekeepingScheduledDateFieldLabel => 'Scheduled date';

  @override
  String get housekeepingCreateTaskSubmitAction => 'Create task';

  @override
  String get housekeepingFrequencyFieldLabel => 'Frequency';

  @override
  String get housekeepingFrequencyFieldHint =>
      'Daily, weekly, terminal clean, or custom';

  @override
  String get housekeepingFrequencyRequiredMessage =>
      'Enter a cleaning frequency.';

  @override
  String get housekeepingStartDateFieldLabel => 'Start date';

  @override
  String get housekeepingEndDateFieldLabel => 'End date';

  @override
  String get housekeepingCreateScheduleSubmitAction => 'Create schedule';

  @override
  String get housekeepingAssetFieldLabel => 'Asset';

  @override
  String get housekeepingAssetFieldHint => 'Select asset or fixture';

  @override
  String get housekeepingDescriptionFieldLabel => 'Description';

  @override
  String get housekeepingDescriptionFieldHint =>
      'Describe the issue or cleaning concern';

  @override
  String get housekeepingDescriptionRequiredMessage => 'Enter a description.';

  @override
  String get housekeepingRequestMaintenanceSubmitAction => 'Create request';

  @override
  String get housekeepingAssignSubmitAction => 'Save assignment';

  @override
  String get housekeepingTriageSummaryFieldLabel => 'Triage note';

  @override
  String get housekeepingSlaHoursFieldLabel => 'SLA hours';

  @override
  String get housekeepingTriageSubmitAction => 'Save triage';

  @override
  String get housekeepingPickDateAction => 'Pick date';

  @override
  String get housekeepingCreateTaskDialogTitle => 'Create housekeeping task';

  @override
  String get housekeepingCreateScheduleDialogTitle =>
      'Create cleaning schedule';

  @override
  String get housekeepingRequestMaintenanceDialogTitle => 'Request maintenance';

  @override
  String get housekeepingAssignDialogTitle => 'Assign housekeeping task';

  @override
  String get housekeepingTriageDialogTitle => 'Triage maintenance handoff';

  @override
  String get housekeepingReportSummaryTitle => 'Housekeeping report';

  @override
  String get housekeepingReportPreviewTitle => 'Report preview';

  @override
  String get housekeepingReportPreviewBody =>
      'Generated housekeeping report templates are not available yet.';

  @override
  String get housekeepingResourceFilterLabel => 'Resource';

  @override
  String get housekeepingResourceTasks => 'Tasks';

  @override
  String get housekeepingResourceSchedules => 'Schedules';

  @override
  String get housekeepingResourceMaintenanceRequests => 'Maintenance requests';

  @override
  String get housekeepingQueueFilterLabel => 'Queue';

  @override
  String get housekeepingQueueAll => 'All';

  @override
  String get housekeepingQueueToday => 'Today';

  @override
  String get housekeepingQueueOverdueTasks => 'Overdue tasks';

  @override
  String get housekeepingQueueOpenRequests => 'Open requests';

  @override
  String get housekeepingQueueOverdueRequests => 'Overdue requests';

  @override
  String get housekeepingStatusFilterLabel => 'Status';

  @override
  String get housekeepingStatusAll => 'All statuses';

  @override
  String get housekeepingAllFacilities => 'All facilities';

  @override
  String get housekeepingFacilityFilterLabel => 'Facility';

  @override
  String get housekeepingRoomFilterLabel => 'Room or bed';

  @override
  String get housekeepingAllRooms => 'All rooms and beds';

  @override
  String get housekeepingAssigneeFilterLabel => 'Assignee';

  @override
  String get housekeepingAllAssignees => 'All assignees';

  @override
  String get housekeepingDateFilterLabel => 'Date';

  @override
  String get housekeepingDateAll => 'Any date';

  @override
  String get housekeepingDateToday => 'Today';

  @override
  String get housekeepingDateNextSevenDays => 'Next 7 days';

  @override
  String get housekeepingDateOverdue => 'Overdue';

  @override
  String get housekeepingDateThisMonth => 'This month';

  @override
  String get housekeepingStatusScheduled => 'Scheduled';

  @override
  String get housekeepingStatusPending => 'Pending';

  @override
  String get housekeepingStatusInProgress => 'In progress';

  @override
  String get housekeepingStatusCompleted => 'Completed';

  @override
  String get housekeepingStatusCancelled => 'Cancelled';

  @override
  String get housekeepingStatusUnknown => 'Unknown';

  @override
  String get housekeepingStatusOpen => 'Open';

  @override
  String get housekeepingStatusOpenLabel => 'Open';

  @override
  String get housekeepingStatusInProgressLabel => 'In progress';

  @override
  String get housekeepingNextActionAssign => 'Assign staff or team';

  @override
  String get housekeepingNextActionStart => 'Start cleaning';

  @override
  String get housekeepingNextActionComplete => 'Complete cleaning';

  @override
  String get housekeepingNextActionTriage => 'Triage handoff';

  @override
  String get housekeepingNextActionReviewSchedule => 'Review schedule';

  @override
  String get housekeepingNextActionNoAction => 'No action needed';

  @override
  String get housekeepingNextActionView => 'View details';

  @override
  String get housekeepingLocationNotSet => 'Location not set';

  @override
  String get housekeepingNotRecorded => 'Not recorded';

  @override
  String get housekeepingUnassigned => 'Unassigned';

  @override
  String get physiotherapyTitle => 'Physiotherapy';

  @override
  String get physiotherapyLoadingTitle => 'Loading physiotherapy workspace';

  @override
  String get physiotherapyLoadingBody => 'Loading referrals and sessions...';

  @override
  String get physiotherapyLiveStatus => 'Live';

  @override
  String get physiotherapySavingStatus => 'Saving';

  @override
  String get physiotherapySavedMessage => 'Physiotherapy record saved.';

  @override
  String get physiotherapyReferralsSummaryLabel => 'Referrals';

  @override
  String get physiotherapyTodaySummaryLabel => 'Today';

  @override
  String get physiotherapyMissedSummaryLabel => 'Missed';

  @override
  String get physiotherapyActivePlansSummaryLabel => 'Active plans';

  @override
  String get physiotherapyFollowUpDueSummaryLabel => 'Follow-up due';

  @override
  String get physiotherapyCompletedSummaryLabel => 'Completed';

  @override
  String get physiotherapyWorklistTitle => 'Therapy worklist';

  @override
  String get physiotherapyWorklistDescription =>
      'Referrals, sessions, plans, notes, and follow-up.';

  @override
  String get physiotherapySearchLabel => 'Search physiotherapy worklist';

  @override
  String get physiotherapySearchHint =>
      'Search patient, encounter, therapist, plan, or session';

  @override
  String get physiotherapyFiltersLabel => 'Filters';

  @override
  String get physiotherapyApplyFiltersAction => 'Apply filters';

  @override
  String get physiotherapyClearFiltersAction => 'Clear filters';

  @override
  String get physiotherapySearchFieldLabel => 'Search in';

  @override
  String get physiotherapyAllFieldsLabel => 'All fields';

  @override
  String get physiotherapyDateFilterLabel => 'Date';

  @override
  String get physiotherapyDateFromLabel => 'From';

  @override
  String get physiotherapyDateToLabel => 'To';

  @override
  String get physiotherapyTherapistFilterLabel => 'Therapist';

  @override
  String get physiotherapyTherapistFilterHint => 'Therapist name or user ID';

  @override
  String get physiotherapyQueueFilterLabel => 'Queue';

  @override
  String get physiotherapyFilterAll => 'All';

  @override
  String get physiotherapyScopeReferrals => 'Referrals';

  @override
  String get physiotherapyScopeToday => 'Today';

  @override
  String get physiotherapyScopeMissed => 'Missed';

  @override
  String get physiotherapyScopeActivePlans => 'Active plans';

  @override
  String get physiotherapyScopeFollowUpDue => 'Follow-up due';

  @override
  String get physiotherapyScopeCompleted => 'Completed';

  @override
  String get physiotherapyScopeAll => 'All work';

  @override
  String get physiotherapyPatientColumnLabel => 'Patient';

  @override
  String get physiotherapySourceColumnLabel => 'Source';

  @override
  String get physiotherapySessionColumnLabel => 'Session';

  @override
  String get physiotherapyStatusColumnLabel => 'Status';

  @override
  String get physiotherapyPlanColumnLabel => 'Plan';

  @override
  String get physiotherapyAttendanceColumnLabel => 'Attendance';

  @override
  String get physiotherapyBillingColumnLabel => 'Billing';

  @override
  String get physiotherapyTherapistColumnLabel => 'Therapist';

  @override
  String get physiotherapyNextActionColumnLabel => 'Next action';

  @override
  String get physiotherapyTableColumnsTitle => 'Therapy table columns';

  @override
  String get physiotherapyApplyColumnsAction => 'Apply columns';

  @override
  String get physiotherapyResetColumnsAction => 'Reset columns';

  @override
  String get physiotherapyNoWorkTitle => 'No physiotherapy work';

  @override
  String get physiotherapyNoWorkBody =>
      'No referrals, sessions, plans, or follow-ups match the current filters.';

  @override
  String get physiotherapyDetailLoadingTitle => 'Loading therapy record';

  @override
  String get physiotherapyDetailLoadingBody =>
      'Loading session, plan, and notes...';

  @override
  String get physiotherapyNoSelectionTitle => 'Select a therapy item';

  @override
  String get physiotherapyNoSelectionBody =>
      'Select a referral or session to continue.';

  @override
  String get physiotherapyPatientNumberLabel => 'Patient number';

  @override
  String get physiotherapyEncounterLabel => 'Encounter';

  @override
  String get physiotherapySessionLabel => 'Session';

  @override
  String get physiotherapyTherapistLabel => 'Therapist';

  @override
  String get physiotherapyBillingAuthorizationLabel => 'Billing authorization';

  @override
  String get physiotherapyActionsTitle => 'Therapy actions';

  @override
  String get physiotherapyReferralPanelTitle => 'Referral and plan';

  @override
  String get physiotherapySourceLabel => 'Source';

  @override
  String get physiotherapyStatusLabel => 'Status';

  @override
  String get physiotherapyAttendanceLabel => 'Attendance';

  @override
  String get physiotherapyPlanLabel => 'Plan';

  @override
  String get physiotherapyGoalLabel => 'Goal';

  @override
  String get physiotherapyInstructionsLabel => 'Instructions';

  @override
  String get physiotherapySessionsPanelTitle => 'Session history';

  @override
  String get physiotherapyPlanPanelTitle => 'Care plan';

  @override
  String get physiotherapyProgressNotesPanelTitle => 'Progress notes';

  @override
  String get physiotherapyFollowUpPanelTitle => 'Follow-ups';

  @override
  String get physiotherapyBackendGapsPanelTitle => 'Unavailable workflows';

  @override
  String get physiotherapyBackendGapBody =>
      'Uses shared clinical records. Dedicated physio workflows are listed as unavailable.';

  @override
  String get physiotherapyNoRecordsLabel => 'No records yet.';

  @override
  String get physiotherapyNoInstructionsLabel =>
      'No therapy instructions recorded.';

  @override
  String get physiotherapyAcceptReferralAction => 'Accept referral';

  @override
  String get physiotherapyScheduleSessionAction => 'Schedule session';

  @override
  String get physiotherapyRecordAssessmentAction => 'Record assessment';

  @override
  String get physiotherapyRecordSessionAction => 'Record session';

  @override
  String get physiotherapyMarkAttendanceAction => 'Mark attendance';

  @override
  String get physiotherapyUpdatePlanAction => 'Update plan';

  @override
  String get physiotherapyAddProgressNoteAction => 'Add progress note';

  @override
  String get physiotherapyScheduleFollowUpAction => 'Schedule follow-up';

  @override
  String get physiotherapyCloseEpisodeAction => 'Close episode';

  @override
  String get physiotherapyPrintInstructionsAction => 'Print instructions';

  @override
  String get physiotherapyAcceptReferralDialogTitle =>
      'Accept physiotherapy referral';

  @override
  String get physiotherapyScheduleSessionDialogTitle =>
      'Schedule therapy session';

  @override
  String get physiotherapyRecordAssessmentDialogTitle =>
      'Record therapy assessment';

  @override
  String get physiotherapyRecordSessionDialogTitle => 'Record therapy session';

  @override
  String get physiotherapyMarkAttendanceDialogTitle =>
      'Mark session attendance';

  @override
  String get physiotherapyUpdatePlanDialogTitle => 'Update therapy plan';

  @override
  String get physiotherapyAddProgressNoteDialogTitle => 'Add progress note';

  @override
  String get physiotherapyScheduleFollowUpDialogTitle => 'Schedule follow-up';

  @override
  String get physiotherapyCloseEpisodeDialogTitle => 'Close therapy episode';

  @override
  String get physiotherapyNoteFieldLabel => 'Note';

  @override
  String get physiotherapyReasonFieldLabel => 'Reason';

  @override
  String get physiotherapyAssessmentFieldLabel => 'Assessment';

  @override
  String get physiotherapyGoalsFieldLabel => 'Goals';

  @override
  String get physiotherapyPlanFieldLabel => 'Plan';

  @override
  String get physiotherapyInstructionsFieldLabel => 'Instructions';

  @override
  String get physiotherapySessionNoteFieldLabel => 'Session note';

  @override
  String get physiotherapyAttendanceStatusFieldLabel => 'Attendance status';

  @override
  String get physiotherapySummaryFieldLabel => 'Summary';

  @override
  String get physiotherapyStartDateFieldLabel => 'Start date';

  @override
  String get physiotherapyStartTimeFieldLabel => 'Start time';

  @override
  String get physiotherapyEndDateFieldLabel => 'End date';

  @override
  String get physiotherapyEndTimeFieldLabel => 'End time';

  @override
  String get physiotherapyDateFieldLabel => 'Date';

  @override
  String get physiotherapyTimeFieldLabel => 'Time';

  @override
  String get physiotherapySaveAction => 'Save';

  @override
  String get physiotherapyStatusReferral => 'Referral';

  @override
  String get physiotherapyStatusAccepted => 'Accepted';

  @override
  String get physiotherapyStatusAssessment => 'Assessment';

  @override
  String get physiotherapyStatusToday => 'Today';

  @override
  String get physiotherapyStatusInTreatment => 'In treatment';

  @override
  String get physiotherapyStatusActivePlan => 'Active plan';

  @override
  String get physiotherapyStatusFollowUpDue => 'Follow-up due';

  @override
  String get physiotherapyStatusMissed => 'Missed';

  @override
  String get physiotherapyStatusCompleted => 'Completed';

  @override
  String get physiotherapyUnknownStatusLabel => 'Unknown';

  @override
  String get physiotherapySourceReferral => 'Referral';

  @override
  String get physiotherapySourceAppointment => 'Appointment';

  @override
  String get physiotherapySourceCarePlan => 'Care plan';

  @override
  String get physiotherapySourceProcedure => 'Procedure';

  @override
  String get physiotherapySourceUnknown => 'Unknown source';

  @override
  String get physiotherapyAttendanceScheduled => 'Scheduled';

  @override
  String get physiotherapyAttendanceConfirmed => 'Confirmed';

  @override
  String get physiotherapyAttendanceInProgress => 'In progress';

  @override
  String get physiotherapyAttendanceCompleted => 'Completed';

  @override
  String get physiotherapyAttendanceCancelled => 'Cancelled';

  @override
  String get physiotherapyAttendanceNoShow => 'No-show';

  @override
  String get physiotherapyBillingBackendGap =>
      'Billing authorization unavailable';

  @override
  String get physiotherapyMissingValueLabel => 'Not recorded';

  @override
  String get physiotherapyBackendGapStatusEndpoint =>
      'Episode status unavailable. Derived from procedures, plans, and follow-ups.';

  @override
  String get physiotherapyBackendGapBillingEndpoint =>
      'Billing authorization is unavailable for this physiotherapy context.';

  @override
  String get physiotherapyBackendGapReportEndpoint =>
      'Generated physiotherapy assessment and discharge reports are not available. Printing uses the shared report template.';

  @override
  String get physiotherapyBackendGapUnknown =>
      'An unavailable physiotherapy workflow was recorded.';

  @override
  String get physiotherapyInstructionsReportTitle =>
      'Physiotherapy instructions';

  @override
  String get physiotherapyReportPatientLabel => 'Patient';

  @override
  String get physiotherapyReportEncounterLabel => 'Encounter';

  @override
  String get physiotherapyReportPlanLabel => 'Plan and goals';

  @override
  String get physiotherapyReportInstructionsLabel => 'Instructions';

  @override
  String get physiotherapyReportSessionsLabel => 'Sessions';

  @override
  String get physiotherapyReportFooterNote =>
      'Generated from shared clinical workflow data.';

  @override
  String get mortuaryTitle => 'Mortuary';

  @override
  String get mortuaryLoadErrorTitle => 'Mortuary workspace unavailable';

  @override
  String get mortuaryLoadErrorBody =>
      'Mortuary workspace could not load. Try again or contact an admin.';

  @override
  String get mortuaryLoadingTitle => 'Loading mortuary workspace';

  @override
  String get mortuaryLoadingBody => 'Loading cases, storage, and release...';

  @override
  String get mortuaryOperationalStatusLabel => 'Operational';

  @override
  String get mortuaryAttentionStatusLabel => 'Needs attention';

  @override
  String get mortuaryPrintDocumentsAction => 'Print documents';

  @override
  String get mortuaryReceiveCaseAction => 'Receive case';

  @override
  String get mortuaryAssignStorageAction => 'Assign storage';

  @override
  String get mortuaryRecordCustodyAction => 'Record custody';

  @override
  String get mortuaryScheduleViewingAction => 'Schedule viewing';

  @override
  String get mortuaryPostMortemAction => 'Post-mortem step';

  @override
  String get mortuaryRequestBillingAction => 'Request billing';

  @override
  String get mortuaryApproveReleaseAction => 'Approve release';

  @override
  String get mortuaryConfirmReleaseAction => 'Confirm release';

  @override
  String get mortuaryActionsUnavailableTooltip => 'Action not available yet';

  @override
  String get mortuaryWorklistTitle => 'Mortuary worklist';

  @override
  String get mortuaryWorklistEmptyTitle => 'No mortuary records found';

  @override
  String get mortuaryWorklistEmptyBody =>
      'Adjust filters to view matching records.';

  @override
  String get mortuaryReferenceColumnLabel => 'Case';

  @override
  String get mortuaryDeceasedColumnLabel => 'Deceased';

  @override
  String get mortuarySourceColumnLabel => 'Source';

  @override
  String get mortuaryStorageColumnLabel => 'Storage';

  @override
  String get mortuaryStatusColumnLabel => 'Status';

  @override
  String get mortuaryDateColumnLabel => 'Date';

  @override
  String get mortuaryNextActionColumnLabel => 'Next action';

  @override
  String get mortuaryPreviousPageLabel => 'Previous page';

  @override
  String get mortuaryNextPageLabel => 'Next page';

  @override
  String mortuaryPageLabel(int from, int to, int total) {
    return 'Showing $from-$to of $total';
  }

  @override
  String get mortuarySearchLabel => 'Search mortuary records';

  @override
  String get mortuarySearchHint =>
      'Search case, name, source, storage, or status';

  @override
  String get mortuarySearchFieldLabel => 'Search';

  @override
  String get mortuaryFiltersLabel => 'Filters';

  @override
  String get mortuaryApplyFiltersAction => 'Apply';

  @override
  String get mortuaryResetFiltersAction => 'Reset';

  @override
  String get mortuaryAllFieldsLabel => 'All';

  @override
  String get mortuaryDateFilterLabel => 'Date';

  @override
  String get mortuaryDateFromLabel => 'From';

  @override
  String get mortuaryDateToLabel => 'To';

  @override
  String get mortuaryDatePickerButtonLabel => 'Choose date';

  @override
  String get mortuaryInvalidDateMessage => 'Enter a valid date.';

  @override
  String get mortuaryPanelFilterLabel => 'Panel';

  @override
  String get mortuaryResourceFilterLabel => 'Resource';

  @override
  String get mortuaryQueueFilterLabel => 'Queue';

  @override
  String get mortuaryStatusFilterLabel => 'Status';

  @override
  String get mortuaryIdentificationFilterLabel => 'Identification';

  @override
  String get mortuaryFacilityFilterLabel => 'Facility';

  @override
  String get mortuaryStorageUnitFilterLabel => 'Storage unit';

  @override
  String get mortuaryStorageSlotFilterLabel => 'Storage slot';

  @override
  String get mortuaryDatePresetFilterLabel => 'Date preset';

  @override
  String get mortuaryDatePresetTodayLabel => 'Today';

  @override
  String get mortuaryDatePresetNext7DaysLabel => 'Next 7 days';

  @override
  String get mortuaryDatePresetOverdueLabel => 'Overdue';

  @override
  String get mortuaryDatePresetThisMonthLabel => 'This month';

  @override
  String get mortuaryTotalCasesSummaryLabel => 'Total cases';

  @override
  String get mortuaryIdentificationPendingSummaryLabel =>
      'Identification pending';

  @override
  String get mortuaryInStorageSummaryLabel => 'In storage';

  @override
  String get mortuaryReleaseReadySummaryLabel => 'Release ready';

  @override
  String get mortuaryUnsettledBillingSummaryLabel => 'Unsettled billing';

  @override
  String get mortuaryPanelOverviewLabel => 'Overview';

  @override
  String get mortuaryPanelIntakeLabel => 'Intake';

  @override
  String get mortuaryPanelStorageLabel => 'Storage';

  @override
  String get mortuaryPanelCustodyLabel => 'Custody';

  @override
  String get mortuaryPanelReleaseLabel => 'Release';

  @override
  String get mortuaryPanelReportingLabel => 'Reports';

  @override
  String get mortuaryResourceCasesLabel => 'Cases';

  @override
  String get mortuaryResourceStorageUnitsLabel => 'Storage units';

  @override
  String get mortuaryResourceStorageSlotsLabel => 'Storage slots';

  @override
  String get mortuaryResourceStorageAssignmentsLabel => 'Storage assignments';

  @override
  String get mortuaryResourceCustodyEventsLabel => 'Custody events';

  @override
  String get mortuaryResourceViewingsLabel => 'Viewings';

  @override
  String get mortuaryResourcePostMortemRequestsLabel => 'Post-mortem requests';

  @override
  String get mortuaryResourceReleaseAuthorisationsLabel =>
      'Release authorisations';

  @override
  String get mortuaryResourceBillableEventsLabel => 'Billable events';

  @override
  String get mortuaryQueueIdentificationPendingLabel =>
      'Identification pending';

  @override
  String get mortuaryQueueStorageExceptionsLabel => 'Storage exceptions';

  @override
  String get mortuaryQueueReleaseReadyLabel => 'Release ready';

  @override
  String get mortuaryQueueUnsettledBillingLabel => 'Unsettled billing';

  @override
  String get mortuaryQueuePostMortemPendingLabel => 'Post-mortem pending';

  @override
  String get mortuaryDetailTitle => 'Case detail';

  @override
  String get mortuaryNoSelectionTitle => 'Select a case';

  @override
  String get mortuaryNoSelectionBody =>
      'Select a case for identity, storage, and release.';

  @override
  String get mortuaryUnknownDeceasedLabel => 'Name not recorded';

  @override
  String get mortuaryUnknownValueLabel => 'Not recorded';

  @override
  String get mortuaryCaseNumberLabel => 'Case number';

  @override
  String get mortuaryDeceasedContextLabel => 'Deceased person context';

  @override
  String get mortuaryIdentificationFieldLabel => 'Identification';

  @override
  String get mortuaryBillingFieldLabel => 'Billing';

  @override
  String get mortuaryStorageSlotFieldLabel => 'Storage slot';

  @override
  String get mortuaryFacilityFieldLabel => 'Facility';

  @override
  String get mortuaryActionGapTitle => 'Actions unavailable';

  @override
  String get mortuaryActionGapBody =>
      'Lookups available. Actions disabled until this workflow is enabled.';

  @override
  String get mortuaryIdentitySectionTitle => 'Identity and source';

  @override
  String get mortuaryStorageSectionTitle => 'Storage';

  @override
  String get mortuaryCustodySectionTitle => 'Custody log';

  @override
  String get mortuaryViewingSectionTitle => 'Viewing';

  @override
  String get mortuaryPostMortemSectionTitle => 'Post-mortem';

  @override
  String get mortuaryReleaseSectionTitle => 'Release';

  @override
  String get mortuaryBillingSectionTitle => 'Billing';

  @override
  String get mortuaryDocumentsSectionTitle => 'Documents';

  @override
  String get mortuaryCaseFieldLabel => 'Case';

  @override
  String get mortuaryDeceasedFieldLabel => 'Deceased';

  @override
  String get mortuaryPatientFieldLabel => 'Patient';

  @override
  String get mortuaryStatusFieldLabel => 'Status';

  @override
  String get mortuaryReceivedAtFieldLabel => 'Received';

  @override
  String get mortuarySourceWorkflowFieldLabel => 'Source workflow';

  @override
  String get mortuarySourceDepartmentFieldLabel => 'Source department';

  @override
  String get mortuarySourceReferenceFieldLabel => 'Source reference';

  @override
  String get mortuaryReceivedFromFieldLabel => 'Received from';

  @override
  String get mortuaryStorageUnitFieldLabel => 'Storage unit';

  @override
  String get mortuaryStorageStatusFieldLabel => 'Storage status';

  @override
  String get mortuaryAssignedAtFieldLabel => 'Assigned';

  @override
  String get mortuaryActorFieldLabel => 'Actor';

  @override
  String get mortuaryLocationFieldLabel => 'Location';

  @override
  String get mortuaryNotesFieldLabel => 'Notes';

  @override
  String get mortuaryReleaseFieldLabel => 'Release';

  @override
  String get mortuaryReleasedAtFieldLabel => 'Released';

  @override
  String get mortuaryNoCustodyEventsLabel => 'No custody events recorded';

  @override
  String get mortuaryNoCustodyEventsBody =>
      'Custody movements and handovers will appear here when recorded.';

  @override
  String get mortuaryNoViewingsLabel => 'No viewings scheduled';

  @override
  String get mortuaryNoViewingsBody =>
      'Viewing appointments will appear here when scheduled.';

  @override
  String get mortuaryNoPostMortemLabel => 'No post-mortem request recorded';

  @override
  String get mortuaryNoPostMortemBody =>
      'Post-mortem requests and reports will appear here when available.';

  @override
  String get mortuaryNoReleaseLabel => 'No release recorded';

  @override
  String get mortuaryNoReleaseBody =>
      'Release authorisations and handover details will appear here when available.';

  @override
  String get mortuaryNoBillingLabel => 'No billing events recorded';

  @override
  String get mortuaryNoBillingBody =>
      'Storage, post-mortem, and release billing events will appear here when available.';

  @override
  String get mortuaryNoDocumentsBody =>
      'Intake, custody, release, and billing docs are available from Print.';

  @override
  String get mortuaryIntakeDocumentLabel => 'Intake form';

  @override
  String get mortuaryCustodyLogDocumentLabel => 'Custody log';

  @override
  String get mortuaryReleaseDocumentLabel => 'Release authorisation';

  @override
  String get mortuaryNextActionVerifyIdentity => 'Verify identity';

  @override
  String get mortuaryNextActionAssignStorage => 'Assign storage';

  @override
  String get mortuaryNextActionPostMortem => 'Review post-mortem';

  @override
  String get mortuaryNextActionClearBilling => 'Clear billing';

  @override
  String get mortuaryNextActionApproveRelease => 'Approve release';

  @override
  String get mortuaryNextActionReleased => 'Released';

  @override
  String get mortuaryNextActionReview => 'Review case';

  @override
  String get mortuaryReportTitle => 'Mortuary case record';

  @override
  String get mortuaryReportFooter => 'Generated from mortuary workspace data.';

  @override
  String get mortuaryReportGeneratedMessage => 'Mortuary document generated.';

  @override
  String get roomsBedsTitle => 'Rooms and beds';

  @override
  String get roomsBedsLoadingTitle => 'Loading rooms and beds';

  @override
  String get roomsBedsLoadingBody => 'Loading wards, rooms, and beds...';

  @override
  String get roomsBedsSavingStatus => 'Saving';

  @override
  String get roomsBedsLiveStatus => 'Live board';

  @override
  String get roomsBedsTotalSummaryLabel => 'Total beds';

  @override
  String get roomsBedsBackendGapsTitle => 'Bed readiness status unavailable';

  @override
  String get roomsBedsBackendGapsBody =>
      'Cleaning, block, isolation, and full readiness states are limited for this facility.';

  @override
  String get roomsBedsManageCatalogAction => 'Manage catalog';

  @override
  String get roomsBedsOpenIpdAdmissionAction => 'Open IPD admission';

  @override
  String get roomsBedsManageTransferAction => 'Manage transfer';

  @override
  String get roomsBedsTransferUpdateDialogTitle => 'Update transfer';

  @override
  String get roomsBedsOpenHousekeepingAction => 'Open housekeeping';

  @override
  String get roomsBedsOpenOperationsAction => 'Open operations';

  @override
  String get roomsBedsMarkCleaningAction => 'Mark cleaning';

  @override
  String get roomsBedsMarkMaintenanceAction => 'Mark maintenance';

  @override
  String get roomsBedsMarkBlockedAction => 'Mark blocked';

  @override
  String get roomsBedsNextActionCompleteTransfer => 'Complete transfer';

  @override
  String get roomsBedsNextActionMarkAvailable => 'Mark available';

  @override
  String get roomsBedsNextActionResolveMaintenance => 'Resolve maintenance';

  @override
  String get roomsBedsCleaningReadinessLabel => 'Awaiting turnover';

  @override
  String get roomsBedsMaintenanceReadinessLabel => 'Under maintenance';

  @override
  String get roomsBedsBlockedReadinessLabel => 'Blocked';

  @override
  String get roomsBedsOccupiedReadinessLabel => 'In use';

  @override
  String get roomsBedsReservedReadinessLabel => 'Held';

  @override
  String get roomsBedsBoardTitle => 'Bed board';

  @override
  String get roomsBedsBoardDescription =>
      'Availability, occupancy, reservations, and readiness.';

  @override
  String get roomsBedsSearchLabel => 'Search rooms and beds';

  @override
  String get roomsBedsSearchHint =>
      'Search bed, ward, room, patient admission, status, or facility';

  @override
  String get roomsBedsFiltersLabel => 'Filters';

  @override
  String get roomsBedsAllFilterLabel => 'All';

  @override
  String get roomsBedsFacilityFilterLabel => 'Facility';

  @override
  String get roomsBedsAllFacilitiesLabel => 'All facilities';

  @override
  String get roomsBedsWardFilterLabel => 'Ward';

  @override
  String get roomsBedsAllWardsLabel => 'All wards';

  @override
  String get roomsBedsRoomFilterLabel => 'Room';

  @override
  String get roomsBedsAllRoomsLabel => 'All rooms';

  @override
  String get roomsBedsStatusFilterLabel => 'Status';

  @override
  String get roomsBedsAllStatusesLabel => 'All statuses';

  @override
  String get roomsBedsPreviousPageLabel => 'Previous page';

  @override
  String get roomsBedsNextPageLabel => 'Next page';

  @override
  String roomsBedsPageLabel(int from, int to, int total) {
    return 'Showing $from-$to of $total';
  }

  @override
  String get roomsBedsEmptyTitle => 'No beds found';

  @override
  String get roomsBedsEmptyBody =>
      'Adjust filters or add beds in facility setup.';

  @override
  String get roomsBedsBedColumnLabel => 'Bed';

  @override
  String get roomsBedsLocationColumnLabel => 'Location';

  @override
  String get roomsBedsStatusColumnLabel => 'Status';

  @override
  String get roomsBedsAssignmentColumnLabel => 'Assignment';

  @override
  String get roomsBedsNextActionColumnLabel => 'Next action';

  @override
  String get roomsBedsDetailTitle => 'Bed detail';

  @override
  String get roomsBedsCurrentAdmissionLabel => 'Current admission';

  @override
  String get roomsBedsReadinessLabel => 'Readiness';

  @override
  String get roomsBedsReserveAction => 'Reserve';

  @override
  String get roomsBedsMarkAvailableAction => 'Mark available';

  @override
  String get roomsBedsMarkOutOfServiceAction => 'Mark out of service';

  @override
  String get roomsBedsAssignAction => 'Assign bed';

  @override
  String get roomsBedsReleaseAction => 'Release bed';

  @override
  String get roomsBedsRequestTransferAction => 'Request transfer';

  @override
  String get roomsBedsAssignmentHistoryTitle => 'Assignment history';

  @override
  String get roomsBedsNoAssignmentsLabel => 'No assignment history recorded';

  @override
  String get roomsBedsCurrentAssignmentLabel => 'Current';

  @override
  String get roomsBedsReleasedAssignmentLabel => 'Released';

  @override
  String get roomsBedsAdmissionFieldLabel => 'Admission number';

  @override
  String get roomsBedsAdmissionFieldHint => 'Enter the admission number';

  @override
  String get roomsBedsDestinationWardLabel => 'Destination ward';

  @override
  String get roomsBedsAssignDialogTitle => 'Assign bed';

  @override
  String roomsBedsAssignWardSuitabilityHint(String wardType) {
    return 'Confirm patient suitability for $wardType before assigning this bed.';
  }

  @override
  String get roomsBedsReleaseDialogTitle => 'Release bed';

  @override
  String get roomsBedsReleaseDialogBody =>
      'Releasing the bed sends the admission through the bed release flow.';

  @override
  String get roomsBedsTransferDialogTitle => 'Request transfer';

  @override
  String get roomsBedsTransferDialogBody =>
      'Choose destination ward. Bed assignment follows in the IPD transfer workflow.';

  @override
  String roomsBedsAdmissionAssignment(String admissionId) {
    return 'Admission $admissionId';
  }

  @override
  String get roomsBedsAssignmentNotLinked => 'Assignment not linked';

  @override
  String get roomsBedsNextActionAssign => 'Assign next admission';

  @override
  String get roomsBedsNextActionReleaseOrTransfer => 'Release or transfer';

  @override
  String get roomsBedsNextActionAssignOrReleaseHold => 'Assign or release hold';

  @override
  String get roomsBedsNextActionResolveBlock => 'Resolve block';

  @override
  String get roomsBedsReadyLabel => 'Ready';

  @override
  String get roomsBedsUnavailableLabel => 'Unavailable';

  @override
  String get roomsBedsReadinessBackendGapLabel =>
      'Readiness status unavailable';

  @override
  String get roomsBedsSavedMessage => 'Rooms and beds updated.';

  @override
  String roomsBedsRequiredMessage(String field) {
    return '$field is required.';
  }

  @override
  String get hrActivityDescription =>
      'Recent HR updates, roster publishes, and shift changes.';

  @override
  String get hrActivityTitle => 'HR activity';

  @override
  String get hrAddStaffAction => 'Add staff';

  @override
  String get hrAddStaffDialogTitle => 'Add staff profile';

  @override
  String get hrStaffOnboardingPersonSectionTitle => 'Staff details and access';

  @override
  String get hrStaffFirstNameLabel => 'Staff first name';

  @override
  String get hrStaffLastNameLabel => 'Staff last name';

  @override
  String get hrStaffEmailLabel => 'Staff email';

  @override
  String get hrStaffPhoneLabel => 'Staff phone';

  @override
  String get hrStaffTemporaryPasswordLabel => 'Temporary password (optional)';

  @override
  String get hrStaffPasswordOptionalHint =>
      'Leave blank to auto-generate a secure password.';

  @override
  String get hrStaffNumberGenerateLabel => 'Generate';

  @override
  String get hrStaffNumberManualLabel => 'Enter manually';

  @override
  String get hrStaffNumberAutoGenerateLabel =>
      'Automatically generate staff number';

  @override
  String get hrStaffNumberManualEntryLabel => 'Enter staff number manually';

  @override
  String get hrStaffGenerateNumberAction => 'Generate';

  @override
  String get hrStaffOnboardingRolesSectionTitle => 'Roles and access';

  @override
  String get hrStaffOnboardingCompensationEditHint =>
      'Update pay. New staff can set compensation later from staff detail.';

  @override
  String get hrRoleAssignmentSearchLabel => 'Search roles';

  @override
  String get hrRoleAssignmentAddRoleLabel => 'Add role';

  @override
  String get hrRoleAssignmentEmptySelectedLabel => 'No roles selected yet.';

  @override
  String get hrRoleAssignmentRemoveRoleAction => 'Remove role';

  @override
  String get hrRoleAssignmentGroupAdministrationLabel => 'Administration';

  @override
  String get hrRoleAssignmentGroupClinicalLabel => 'Clinical care';

  @override
  String get hrRoleAssignmentGroupDiagnosticsLabel => 'Diagnostics & pharmacy';

  @override
  String get hrRoleAssignmentGroupFrontOfficeLabel => 'Front office & billing';

  @override
  String get hrRoleAssignmentGroupOperationsLabel => 'Operations & support';

  @override
  String get hrRoleAssignmentGroupCustomLabel => 'Custom roles';

  @override
  String get hrStaffOnboardingEmploymentSectionTitle => 'Employment';

  @override
  String get hrStaffOnboardingCreateNewUserLabel => 'Create new user';

  @override
  String get hrStaffOnboardingLinkExistingUserLabel => 'Link existing user';

  @override
  String get hrStaffOnboardingSelectUserHint => 'Search staff by name or email';

  @override
  String get hrStaffOnboardingNoRolesWarning =>
      'No roles assigned yet. This staff member will have limited access until roles are assigned.';

  @override
  String get hrStaffOnboardingPayTypeLabel => 'Pay type';

  @override
  String get hrStaffOnboardingDailyRateLabel => 'Daily rate';

  @override
  String get hrStaffOnboardingAddressLabel => 'Address (optional)';

  @override
  String get hrStaffOnboardingPermissionsPreviewEmpty =>
      'Select roles above to preview effective permissions.';

  @override
  String get hrStaffOnboardingCompensationSectionTitle => 'Compensation';

  @override
  String get hrStaffOnboardingCompensationCreateHint =>
      'Optional. Set pay rate and effective date when onboarding this staff member.';

  @override
  String get hrStaffOnboardingConsultationSectionTitle =>
      'Consultation billing';

  @override
  String get hrAllowPartialPublishLabel => 'Allow partial publish';

  @override
  String get hrApproveLeaveAction => 'Approve leave';

  @override
  String get hrApproveLeaveDialogTitle => 'Approve leave';

  @override
  String get hrApproveSwapAction => 'Approve swap';

  @override
  String get hrApproveSwapDialogTitle => 'Approve shift swap';

  @override
  String get hrAssignDepartmentAction => 'Assign department';

  @override
  String get hrAssignDepartmentDialogTitle => 'Assign department';

  @override
  String get hrAssignmentLabel => 'Assignment';

  @override
  String get hrAssignmentsSectionTitle => 'Assignments';

  @override
  String get hrAssignPositionAction => 'Assign position';

  @override
  String get hrAssignPositionDialogTitle => 'Assign position';

  @override
  String get hrAssignShiftAction => 'Assign shift';

  @override
  String get hrAssignShiftDialogTitle => 'Assign shift';

  @override
  String get hrAvailabilityAvailable => 'Available';

  @override
  String get hrAvailabilityDialogTitle => 'Record availability';

  @override
  String get hrAvailabilityPreferenceLabel => 'Availability';

  @override
  String get hrAvailabilityPreferred => 'Preferred';

  @override
  String get hrAvailabilitySectionTitle => 'Availability';

  @override
  String get hrAvailabilityUnavailable => 'Unavailable';

  @override
  String get hrAddAvailabilitySlotAction => 'Add slot';

  @override
  String get hrAddScheduleSlotAction => 'Add slot';

  @override
  String get hrRemoveScheduleSlotAction => 'Remove slot';

  @override
  String get hrDuplicateScheduleToAction => 'Duplicate to...';

  @override
  String get hrScheduleDuplicateToDialogTitle => 'Duplicate schedule';

  @override
  String hrScheduleDuplicateToDialogDescription(String dayName) {
    return 'Replace selected days with $dayName\'s slots.';
  }

  @override
  String get hrWeeklyScheduleSectionTitle => 'Weekly schedule';

  @override
  String get hrAvailabilityScheduleSourceLabel => 'Schedule source';

  @override
  String get hrAvailabilitySourceManual => 'Manual';

  @override
  String get hrAvailabilitySourceFromStaff => 'From staff';

  @override
  String get hrAvailabilitySourceFromTemplate => 'From template';

  @override
  String get hrAvailabilityCopyFromStaffAction => 'Copy from staff';

  @override
  String get hrAvailabilityCopyFromStaffLabel => 'Source staff';

  @override
  String get hrAvailabilityCopyFromTemplateAction => 'Apply template';

  @override
  String get hrAvailabilityCopyFromTemplateLabel => 'Schedule template';

  @override
  String get hrAvailabilityDuplicateToAction => 'Duplicate to...';

  @override
  String get hrAvailabilityDuplicateToDialogTitle => 'Duplicate schedule';

  @override
  String hrAvailabilityDuplicateToDialogDescription(String dayName) {
    return 'Replace selected days with $dayName\'s slots.';
  }

  @override
  String get hrAvailabilityEndAfterStartError =>
      'End time must be after start time';

  @override
  String get hrAvailabilityNoDaysSelectedError =>
      'Add at least one time slot on any day';

  @override
  String get hrAvailabilitySlotOverlapError =>
      'Time slots on the same day must not overlap';

  @override
  String get hrAvailabilityWeekScheduleTitle => 'Weekly schedule';

  @override
  String get hrRemoveAvailabilitySlotAction => 'Remove slot';

  @override
  String get hrClearFiltersAction => 'Clear filters';

  @override
  String get hrConsultationCurrencyLabel => 'Consultation currency';

  @override
  String get hrConsultationFeeLabel => 'Consultation fee';

  @override
  String get hrCreateStaffAction => 'Create staff';

  @override
  String get hrDayOfWeekLabel => 'Day of week';

  @override
  String get hrDepartmentColumnLabel => 'Department';

  @override
  String get hrDepartmentFilterLabel => 'Department';

  @override
  String get hrDepartmentLabel => 'Department';

  @override
  String get hrEditStaffAction => 'Edit staff';

  @override
  String get hrEditStaffDialogTitle => 'Edit staff profile';

  @override
  String get hrEffectiveFromLabel => 'Effective from';

  @override
  String get hrEffectiveToLabel => 'Effective to';

  @override
  String get hrEndDateLabel => 'End date';

  @override
  String get hrEndTimeLabel => 'End time';

  @override
  String hrFieldRequiredLabel(String label) {
    return '$label is required.';
  }

  @override
  String get hrFiltersLabel => 'Filters';

  @override
  String get hrFridayLabel => 'Friday';

  @override
  String get hrGenerateRosterAction => 'Generate roster';

  @override
  String get hrHireDateLabel => 'Hire date';

  @override
  String get hrLeaveDialogTitle => 'Request leave';

  @override
  String get hrLeaveLabel => 'Leave';

  @override
  String get hrLeaveDaysLabel => 'Number of days';

  @override
  String get hrLeaveDaysHelper =>
      'Auto-calculates the end date from the start date.';

  @override
  String get hrLeaveTypeLabel => 'Leave type';

  @override
  String get hrLeaveHalfDayLabel => 'Half-day leave';

  @override
  String get hrLeaveHalfDayHelper =>
      'For a single morning or afternoon absence.';

  @override
  String get hrLeaveHalfDayPeriodLabel => 'Half-day period';

  @override
  String get hrLeaveHalfDaySingleDayError =>
      'Half-day leave must start and end on the same day.';

  @override
  String hrLeaveHalfDaySummary(String period) {
    return 'Half day ($period)';
  }

  @override
  String get hrCoveringStaffLabel => 'Covering colleague';

  @override
  String hrCoveringStaffSummary(String name) {
    return 'Cover: $name';
  }

  @override
  String get hrHandoverNotesLabel => 'Handover notes';

  @override
  String get hrHandoverNotesHelper =>
      'Tasks or patients the covering colleague should know.';

  @override
  String get hrAddNewPositionLabel => 'Add a new position';

  @override
  String get hrNewPositionLabel => 'New position name';

  @override
  String get hrSelectShiftLabel => 'Shift';

  @override
  String get hrSelectShiftHint => 'Search shifts by name, time, or department';

  @override
  String get hrStaffOverviewSectionTitle => 'Overview';

  @override
  String get hrRoomLabel => 'Room';

  @override
  String get hrCompensationAction => 'Compensation';

  @override
  String get hrCompensationDialogTitle => 'Update compensation';

  @override
  String get hrCompensationSectionTitle => 'Compensation';

  @override
  String get hrCompensationLabel => 'Compensation';

  @override
  String get hrNoCompensationLabel => 'No compensation records';

  @override
  String get hrCompensationHourlyRateLabel => 'Hourly rate';

  @override
  String get hrCompensationMonthlyRateLabel => 'Monthly rate';

  @override
  String get hrCompensationProcedureRateLabel => 'Procedure rate';

  @override
  String get hrCompensationConsultationRateLabel => 'Consultation fee rate';

  @override
  String get hrCompensationCurrencyLabel => 'Currency';

  @override
  String get hrLeaveReportLabel => 'Leave summary';

  @override
  String get hrLeaveRequestsSummaryLabel => 'Leave requests';

  @override
  String get hrLeaveRequestTitle => 'Leave request';

  @override
  String get hrLeaveSectionTitle => 'Leave';

  @override
  String get hrLiveStatus => 'Live';

  @override
  String get hrLoadingBody => 'Loading staff and rosters...';

  @override
  String get hrLoadingTitle => 'Loading HR workspace';

  @override
  String get hrMondayLabel => 'Monday';

  @override
  String get hrNextActionAssignDepartment => 'Assign department';

  @override
  String get hrNextActionAssignPosition => 'Assign position';

  @override
  String get hrNextActionColumnLabel => 'Next action';

  @override
  String get hrNextActionReviewProfile => 'Review profile';

  @override
  String get hrNextPageLabel => 'Next staff page';

  @override
  String get hrNextQueuePageLabel => 'Next queue page';

  @override
  String get hrNoActivityBody => 'HR activity will appear here.';

  @override
  String get hrNoActivityTitle => 'No activity yet';

  @override
  String get hrNoAssignmentsLabel => 'No assignments recorded.';

  @override
  String get hrNoAvailabilityLabel => 'No availability recorded.';

  @override
  String get hrNoLeaveLabel => 'No leave recorded.';

  @override
  String get hrNoQueueItemsBody =>
      'No HR queue items match the current filter.';

  @override
  String get hrNoQueueItemsTitle => 'No queue items';

  @override
  String get hrNoShiftsLabel => 'No shifts assigned.';

  @override
  String get hrNoStaffBody => 'No staff profiles match the current filters.';

  @override
  String get hrNoStaffSelectedBody =>
      'Select a staff member for assignments, leave, shifts, and payroll.';

  @override
  String get hrNoStaffSelectedTitle => 'No staff selected';

  @override
  String get hrNoStaffTitle => 'No staff found';

  @override
  String get hrNotesLabel => 'Notes';

  @override
  String get hrNotifyStaffLabel => 'Notify staff';

  @override
  String get hrOverrideShiftAction => 'Override shift';

  @override
  String get hrOverrideShiftDialogTitle => 'Override shift';

  @override
  String hrPageLabel(int from, int to, int total) {
    return '$from-$to of $total';
  }

  @override
  String get hrPayrollDraftsSummaryLabel => 'Payroll drafts';

  @override
  String get hrPayrollDraftTitle => 'Payroll draft';

  @override
  String get hrPayrollReportLabel => 'Payroll summary';

  @override
  String get hrPayrollRunDialogTitle => 'Run payroll';

  @override
  String get hrPeriodColumnLabel => 'Period';

  @override
  String get hrPeriodEndLabel => 'Period end';

  @override
  String get hrPeriodStartLabel => 'Period start';

  @override
  String get hrPickDateAction => 'Pick date';

  @override
  String get hrPositionFilterLabel => 'Position';

  @override
  String get hrPositionLabel => 'Position';

  @override
  String get hrPractitionerTypeFilterLabel => 'Practitioner type';

  @override
  String get hrPractitionerTypeLabel => 'Practitioner type';

  @override
  String get hrPreviewStaffProfileReportAction => 'Preview staff profile';

  @override
  String get hrPreviousPageLabel => 'Previous staff page';

  @override
  String get hrPreviousQueuePageLabel => 'Previous queue page';

  @override
  String get hrProcessPayrollAction => 'Process payroll';

  @override
  String get hrProcessPayrollDialogTitle => 'Process payroll';

  @override
  String get hrPublishNoteLabel => 'Publish note';

  @override
  String get hrPublishRosterAction => 'Publish roster';

  @override
  String get hrPublishRosterDialogTitle => 'Publish roster';

  @override
  String get hrQueueColumnLabel => 'Queue';

  @override
  String get hrQueueItemColumnLabel => 'Item';

  @override
  String get hrQueueLeaveRequests => 'Leave requests';

  @override
  String get hrQueueOverdueShifts => 'Overdue shifts';

  @override
  String get hrQueuePayrollDrafts => 'Payroll drafts';

  @override
  String get hrQueueRosterDrafts => 'Roster drafts';

  @override
  String get hrQueueSwapRequests => 'Swap requests';

  @override
  String get hrQueueUnassignedShifts => 'Unassigned shifts';

  @override
  String get hrReasonLabel => 'Reason';

  @override
  String get hrRecordAvailabilityAction => 'Record availability';

  @override
  String get hrRejectLeaveAction => 'Reject leave';

  @override
  String get hrRejectLeaveDialogTitle => 'Reject leave';

  @override
  String get hrRejectSwapAction => 'Reject swap';

  @override
  String get hrRejectSwapDialogTitle => 'Reject shift swap';

  @override
  String get hrReplacePayrollItemsLabel => 'Replace existing payroll items';

  @override
  String get hrReportsSectionTitle => 'Reports';

  @override
  String get hrRequestLeaveAction => 'Request leave';

  @override
  String get hrRolePositionColumnLabel => 'Role / position';

  @override
  String get hrRosterDraftsSummaryLabel => 'Roster drafts';

  @override
  String get hrRosterDraftTitle => 'Roster draft';

  @override
  String get hrRosterReportLabel => 'Roster report';

  @override
  String get hrRunPayrollAction => 'Run payroll';

  @override
  String get hrSaturdayLabel => 'Saturday';

  @override
  String get hrSavedMessage => 'HR changes saved.';

  @override
  String get hrSaveStaffAction => 'Save staff';

  @override
  String get hrSavingStatus => 'Saving';

  @override
  String get hrSearchHint => 'Search staff, department, role, shift, or status';

  @override
  String get hrSearchLabel => 'Search HR records';

  @override
  String get hrShiftIdLabel => 'Shift ID';

  @override
  String get hrShiftLabel => 'Shift';

  @override
  String get hrShiftQueueTitle => 'Shift queue item';

  @override
  String get hrShiftsSectionTitle => 'Shifts';

  @override
  String get hrStaffActionsTitle => 'Staff actions';

  @override
  String get hrStaffActionsPlacementTitle => 'Placement';

  @override
  String get hrStaffActionsSchedulingTitle => 'Scheduling';

  @override
  String get hrStaffActionsPayrollTitle => 'Payroll';

  @override
  String get hrStaffActionsAccessTitle => 'Access';

  @override
  String get hrManageScheduleTemplatesTitle => 'Schedule templates';

  @override
  String get hrManageScheduleTemplatesDescription =>
      'Reusable shift patterns for roster generation.';

  @override
  String get hrNoShiftTemplatesLabel =>
      'No schedule templates yet. Create one to reuse shift patterns.';

  @override
  String get hrStaffColumnLabel => 'Staff';

  @override
  String get hrStaffDetailTitle => 'Staff detail';

  @override
  String get hrStaffDirectoryDescription =>
      'Search staff by name, department, position, or status.';

  @override
  String get hrStaffDirectoryTitle => 'Staff directory';

  @override
  String get hrStaffLabel => 'Staff';

  @override
  String get hrStaffListReportLabel => 'Staff list';

  @override
  String get hrStaffNameLabel => 'Staff name';

  @override
  String get hrStaffNumberLabel => 'Staff number';

  @override
  String get hrStaffProfileReportTitle => 'Staff profile';

  @override
  String get hrStartDateLabel => 'Start date';

  @override
  String get hrStartTimeLabel => 'Start time';

  @override
  String get hrStatusColumnLabel => 'Status';

  @override
  String get hrSundayLabel => 'Sunday';

  @override
  String get hrSwapRequestTitle => 'Shift swap request';

  @override
  String get hrSwapShiftAction => 'Swap shift';

  @override
  String get hrSwapShiftDialogTitle => 'Request shift swap';

  @override
  String get hrTargetStaffLabel => 'Target staff';

  @override
  String get hrTenantIdLabel => 'Tenant ID';

  @override
  String get hrThursdayLabel => 'Thursday';

  @override
  String get hrTimeHint => 'HH:MM';

  @override
  String get hrTotalStaffSummaryLabel => 'Total staff';

  @override
  String get hrTuesdayLabel => 'Tuesday';

  @override
  String get hrUnassignedShiftsSummaryLabel => 'Unassigned shifts';

  @override
  String get hrUnitIdLabel => 'Unit ID';

  @override
  String get hrUnitLabel => 'Unit';

  @override
  String get hrRoomsLabel => 'Rooms';

  @override
  String get hrSelectAllRoomsAction => 'Select all';

  @override
  String get hrClearRoomsAction => 'Clear';

  @override
  String get hrUserIdLabel => 'User ID';

  @override
  String get hrLinkedUserLabel => 'Linked user';

  @override
  String get hrSelectUserLabel => 'Link user account';

  @override
  String get hrCreateUserAction => 'Create staff';

  @override
  String get hrCreateUserDialogTitle => 'Create user account';

  @override
  String get hrAssignRoleAction => 'Assign role';

  @override
  String get hrAssignRoleDialogTitle => 'Assign role';

  @override
  String get hrRevokeRoleAction => 'Revoke role';

  @override
  String get hrRevokeRoleDialogTitle => 'Revoke role';

  @override
  String get hrRolesSectionTitle => 'Roles and access';

  @override
  String get hrNoRolesLabel => 'No roles assigned.';

  @override
  String get hrModuleAccessAction => 'View module access';

  @override
  String get hrModuleAccessDialogTitle => 'Module access';

  @override
  String get hrModuleAccessSectionTitle => 'Subscribed modules';

  @override
  String get hrEffectivePermissionsTitle => 'Effective permissions';

  @override
  String get hrNoModuleAccessLabel => 'No active module entitlements.';

  @override
  String get hrOpenAccessAdminAction => 'Open in Users/Roles';

  @override
  String get hrManageAccessAction => 'Manage users and roles';

  @override
  String get hrAccessWorkspaceTitle => 'Staff access';

  @override
  String get hrAccessWorkspaceDescription =>
      'Staff accounts, roles, and permissions.';

  @override
  String get hrAccessPanelUsers => 'Staff';

  @override
  String get hrAccessPanelRoles => 'Roles';

  @override
  String get hrAccessPanelPermissions => 'Permissions';

  @override
  String get hrAccessSearchLabel => 'Search';

  @override
  String get hrAccessSearchHint => 'Search staff, roles, or permissions';

  @override
  String get hrPermissionAssignmentSearchLabel => 'Search permissions';

  @override
  String hrPermissionAssignmentSelectedCount(int selected, int total) {
    return '$selected of $total selected';
  }

  @override
  String get hrPermissionAssignmentNoSearchResultsLabel =>
      'No permissions match your search.';

  @override
  String get hrPermissionAssignmentEmptySelectedLabel =>
      'No permissions selected.';

  @override
  String get hrPermissionAssignmentSelectAllMatchingAction =>
      'Select all matching permissions';

  @override
  String get hrPermissionAssignmentClearMatchingAction =>
      'Clear matching permissions';

  @override
  String get hrAccessPermissionCatalogSelectLabel => 'Permission';

  @override
  String get permissionCatalogProfileRead => 'Profile — Read';

  @override
  String get permissionCatalogProfileUpdate => 'Profile — Update';

  @override
  String get permissionCatalogPatientRead => 'Patient — Read';

  @override
  String get permissionCatalogPatientWrite => 'Patient — Write';

  @override
  String get permissionCatalogPatientDelete => 'Patient — Delete';

  @override
  String get permissionCatalogClinicalRead => 'Clinical — Read';

  @override
  String get permissionCatalogClinicalWrite => 'Clinical — Write';

  @override
  String get permissionCatalogEmergencyRead => 'Emergency — Read';

  @override
  String get permissionCatalogEmergencyWrite => 'Emergency — Write';

  @override
  String get permissionCatalogEmergencyDelete => 'Emergency — Delete';

  @override
  String get permissionCatalogLabRead => 'Lab — Read';

  @override
  String get permissionCatalogLabWrite => 'Lab — Write';

  @override
  String get permissionCatalogRadiologyRead => 'Radiology — Read';

  @override
  String get permissionCatalogRadiologyWrite => 'Radiology — Write';

  @override
  String get permissionCatalogPharmacyRead => 'Pharmacy — Read';

  @override
  String get permissionCatalogPharmacyWrite => 'Pharmacy — Write';

  @override
  String get permissionCatalogBillingRead => 'Billing — Read';

  @override
  String get permissionCatalogBillingWrite => 'Billing — Write';

  @override
  String get permissionCatalogOperationsRead => 'Operations — Read';

  @override
  String get permissionCatalogOperationsWrite => 'Operations — Write';

  @override
  String get permissionCatalogHrRead => 'HR — Read';

  @override
  String get permissionCatalogHrWrite => 'HR — Write';

  @override
  String get permissionCatalogUnitRead => 'Unit — Read';

  @override
  String get permissionCatalogUnitManage => 'Unit — Manage';

  @override
  String get permissionCatalogRosterRead => 'Roster — Read';

  @override
  String get permissionCatalogRosterWrite => 'Roster — Write';

  @override
  String get permissionCatalogRosterPublish => 'Roster — Publish';

  @override
  String get permissionCatalogRosterApprove => 'Roster — Approve';

  @override
  String get permissionCatalogBiomedRead => 'Biomed — Read';

  @override
  String get permissionCatalogBiomedWrite => 'Biomed — Write';

  @override
  String get permissionCatalogMortuaryRead => 'Mortuary — Read';

  @override
  String get permissionCatalogMortuaryWrite => 'Mortuary — Write';

  @override
  String get permissionCatalogMortuaryRelease => 'Mortuary — Release';

  @override
  String get permissionCatalogMortuaryManageStorage =>
      'Mortuary — Manage storage';

  @override
  String get permissionCatalogMortuaryPostMortemRequest =>
      'Mortuary — Post-mortem request';

  @override
  String get permissionCatalogMortuaryApprove => 'Mortuary — Approve';

  @override
  String get permissionCatalogMortuaryBillingEvent =>
      'Mortuary — Billing event';

  @override
  String get permissionCatalogMortuaryExport => 'Mortuary — Export';

  @override
  String get permissionCatalogMortuaryAudit => 'Mortuary — Audit';

  @override
  String get permissionCatalogCommunicationsRead => 'Communications — Read';

  @override
  String get permissionCatalogCommunicationsWrite => 'Communications — Write';

  @override
  String get permissionCatalogCommunicationsDelete => 'Communications — Delete';

  @override
  String get permissionCatalogIntegrationRead => 'Integration — Read';

  @override
  String get permissionCatalogIntegrationWrite => 'Integration — Write';

  @override
  String get permissionCatalogIntegrationDelete => 'Integration — Delete';

  @override
  String get permissionCatalogReportsRead => 'Reports — Read';

  @override
  String get permissionCatalogReportsWrite => 'Reports — Write';

  @override
  String get permissionCatalogReportsDelete => 'Reports — Delete';

  @override
  String get permissionCatalogSubscriptionsRead => 'Subscriptions — Read';

  @override
  String get permissionCatalogSubscriptionsWrite => 'Subscriptions — Write';

  @override
  String get permissionCatalogSubscriptionsDelete => 'Subscriptions — Delete';

  @override
  String get permissionCatalogLastOfficeRead => 'Last office — Read';

  @override
  String get permissionCatalogLastOfficeWrite => 'Last office — Write';

  @override
  String get permissionCatalogLastOfficeApprove => 'Last office — Approve';

  @override
  String get permissionCatalogComplianceRead => 'Compliance — Read';

  @override
  String get permissionCatalogComplianceReview => 'Compliance — Review';

  @override
  String get permissionCatalogBreakGlassRequest => 'Break glass — Request';

  @override
  String get permissionCatalogBreakGlassReview => 'Break glass — Review';

  @override
  String get permissionCatalogBreakGlassApprove => 'Break glass — Approve';

  @override
  String get permissionCatalogEvidenceExport => 'Evidence — Export';

  @override
  String get permissionCatalogFinancialApprove => 'Financial — Approve';

  @override
  String get permissionCatalogFacilityAdmin => 'Facility — Admin';

  @override
  String get permissionCatalogTenantAdmin => 'Tenant — Admin';

  @override
  String get permissionCatalogSystemAdmin => 'System — Admin';

  @override
  String get hrAccessEmptyUsersLabel => 'No staff accounts match your search.';

  @override
  String get hrAccessEmptyRolesLabel => 'No roles match your search.';

  @override
  String get hrAccessEmptyPermissionsLabel =>
      'No permissions match your search.';

  @override
  String get hrAccessCreateRoleAction => 'Create role';

  @override
  String get hrAccessCreatePermissionAction => 'Create permission';

  @override
  String get hrAccessEditUserAction => 'Edit user';

  @override
  String get hrAccessEditRoleAction => 'Edit role';

  @override
  String get hrAccessEditPermissionAction => 'Edit permission';

  @override
  String get hrAccessAssignPermissionsAction => 'Assign permissions';

  @override
  String get hrAccessRoleNameLabel => 'Role name';

  @override
  String get hrAccessRoleDisplayNameLabel => 'Display name';

  @override
  String get hrAccessRoleDescriptionLabel => 'Description';

  @override
  String get hrAccessPermissionNameLabel => 'Permission name';

  @override
  String get hrAccessPermissionDescriptionLabel => 'Description';

  @override
  String get hrAccessPositionTitleLabel => 'Position title';

  @override
  String get hrAccessInitialRolesLabel => 'Initial roles';

  @override
  String hrAccessPermissionCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count permissions',
      zero: 'No permissions',
    );
    return '$_temp0';
  }

  @override
  String hrAccessStaffAssignmentCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count staff',
      zero: 'No staff',
    );
    return '$_temp0';
  }

  @override
  String get hrAccessSystemColumnLabel => 'System';

  @override
  String hrAccessRoleSummary(int permissionCount, int userCount) {
    String _temp0 = intl.Intl.pluralLogic(
      permissionCount,
      locale: localeName,
      other: '$permissionCount permissions',
      zero: 'No permissions',
    );
    String _temp1 = intl.Intl.pluralLogic(
      userCount,
      locale: localeName,
      other: '$userCount assignments',
      zero: 'No assignments',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String hrAccessPermissionRoleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count roles',
      zero: 'no roles',
    );
    return 'Used by $_temp0';
  }

  @override
  String get hrAccessUserDetailTitle => 'User account';

  @override
  String get hrAccessViewUserAction => 'View';

  @override
  String get hrAccessManageRolesPermissionsAction =>
      'Manage roles & permissions';

  @override
  String get hrAccessDirectPermissionsLabel => 'Direct permissions';

  @override
  String get hrAccessAssignedRolesLabel => 'Assigned roles';

  @override
  String get hrAccessEffectivePermissionsLabel => 'Effective permissions';

  @override
  String get hrAccessOpenStaffProfileAction => 'Open staff profile';

  @override
  String get hrAccessLinkedStaffLabel => 'Linked staff';

  @override
  String get hrAccessTenantContextRequiredTitle => 'Tenant context required';

  @override
  String get hrAccessTenantContextRequiredBody =>
      'Select a staff member or sign in with a tenant account first.';

  @override
  String get hrAccessRoleSyncSuccessMessage => 'Role permissions updated.';

  @override
  String get hrAccessSystemCriticalRoleBadge => 'System critical';

  @override
  String get hrAccessNonSystemRoleLabel => 'Non-system';

  @override
  String get hrAccessSelectAllRolesAction => 'Select all roles';

  @override
  String get hrAccessClearRolesAction => 'Clear roles';

  @override
  String get hrAccessSelectAllPermissionsAction => 'Select all permissions';

  @override
  String get hrAccessClearPermissionsAction => 'Clear permissions';

  @override
  String get hrAccessLoadMoreAction => 'Load more';

  @override
  String get hrPrimaryAssignmentLabel => 'Primary';

  @override
  String get hrEndAssignmentAction => 'End assignment';

  @override
  String get hrEndAssignmentDialogTitle => 'End assignment';

  @override
  String get hrEndAssignmentDateLabel => 'End date';

  @override
  String get hrAssignmentDetailDialogTitle => 'Assignment details';

  @override
  String get hrAssignmentIdLabel => 'Assignment ID';

  @override
  String get hrEditAssignmentAction => 'Edit assignment';

  @override
  String get hrAssignmentActiveLabel => 'Active';

  @override
  String get hrAssignmentEndedLabel => 'Ended';

  @override
  String get hrDateRangeOngoingLabel => 'Ongoing';

  @override
  String get hrAvailabilityWeekViewLabel => 'Week view';

  @override
  String get hrAvailabilityMonthViewLabel => 'Month view';

  @override
  String get hrAvailabilityCalendarEmptyBody =>
      'Record weekly availability to see the calendar.';

  @override
  String get hrAvailabilityLegendAvailableLabel => 'Available';

  @override
  String get hrAvailabilityLegendUnavailableLabel => 'Unavailable';

  @override
  String get hrAvailabilityLegendLeaveLabel => 'Approved leave';

  @override
  String get hrAvailabilityDayEmptyLabel =>
      'No time slots recorded for this day.';

  @override
  String get hrAvailabilityAddSlotAction => 'Add slot';

  @override
  String get hrAvailabilityEditDayAction => 'Edit day';

  @override
  String get hrCompensationActionTooltip => 'Define or update pay structure';

  @override
  String get hrRunPayrollActionTooltip =>
      'Process pay for a period (Financial Approve required)';

  @override
  String get hrPayrollMissingCompensationTooltip =>
      'Add compensation before running payroll.';

  @override
  String get hrCompensationPayStructureTabLabel => 'Pay structure';

  @override
  String get hrCompensationHistoryTabLabel => 'History';

  @override
  String get hrCompensationBaseRateLabel => 'Base rate';

  @override
  String get hrCompensationPayFrequencyLabel => 'Pay frequency';

  @override
  String get hrCompensationFrequencyMonthlyLabel => 'Monthly';

  @override
  String get hrCompensationFrequencyBiweeklyLabel => 'Bi-weekly';

  @override
  String get hrCompensationFrequencyWeeklyLabel => 'Weekly';

  @override
  String get hrCompensationDailyRateLabel => 'Daily rate';

  @override
  String get hrCompensationDetailDialogTitle => 'Compensation details';

  @override
  String get hrCompensationAddNewRateAction => 'Add new rate';

  @override
  String get hrCompensationAddPayLineAction => 'Add pay line';

  @override
  String get hrCompensationRemovePayLineAction => 'Remove pay line';

  @override
  String get hrCompensationActiveStatusLabel => 'Active';

  @override
  String get hrCompensationEndedStatusLabel => 'Ended';

  @override
  String hrPayrollComponentBreakdownLabel(
    String quantity,
    String unit,
    String rate,
    String currency,
    String subtotal,
  ) {
    return '$quantity $unit × $rate $currency = $subtotal';
  }

  @override
  String hrPayrollZeroQuantityWarning(String payType) {
    return 'No recorded activity for $payType in this period.';
  }

  @override
  String get hrPayrollMixedCurrencyWarning =>
      'Some compensation lines use a different currency and were excluded from the total.';

  @override
  String get hrPayrollWizardTitle => 'Payroll run';

  @override
  String get hrPayrollWizardPeriodStepTitle => 'Select pay period';

  @override
  String get hrPayPeriodStartLabel => 'Pay period start';

  @override
  String get hrPayPeriodEndLabel => 'Pay period end';

  @override
  String get hrPayrollWizardPreviewStepTitle => 'Preview payslips';

  @override
  String get hrPayrollWizardNoStaffItemsLabel =>
      'No payroll line items for this staff member in the selected period.';

  @override
  String get hrPayrollStaffCountLabel => 'Staff count';

  @override
  String get hrGrossPayLabel => 'Gross pay';

  @override
  String get hrNetPayLabel => 'Net pay';

  @override
  String get hrDeductionsLabel => 'Deductions';

  @override
  String get hrPayrollWizardProcessStepBody =>
      'Process will create payroll items and advance the run toward paid status.';

  @override
  String get hrPayrollWizardPreviewAction => 'Preview';

  @override
  String get hrPayrollWizardReviewAction => 'Review';

  @override
  String get hrLeaveDetailDialogTitle => 'Leave details';

  @override
  String get hrLeaveCoveringStaffLabel => 'Covering staff';

  @override
  String get hrLeaveHandoverNotesLabel => 'Handover notes';

  @override
  String get hrLeaveReasonLabel => 'Reason';

  @override
  String get hrShiftDetailDialogTitle => 'Shift details';

  @override
  String get hrShiftTypeLabel => 'Shift type';

  @override
  String get hrAssignedAtLabel => 'Assigned at';

  @override
  String get hrRosterPeriodLabel => 'Roster period';

  @override
  String get hrRemoveShiftAssignmentAction => 'Remove assignment';

  @override
  String get hrOffboardStaffAction => 'End employment';

  @override
  String get hrOffboardStaffActionTooltip =>
      'Record separation; optionally end access';

  @override
  String get hrOffboardStaffDialogTitle => 'End employment';

  @override
  String get hrOffboardStaffDialogHint =>
      'Ends employment. Active assignments can close on the last working day.';

  @override
  String get hrSeparationTypeLabel => 'Separation type';

  @override
  String get hrSeparationTypeResignationLabel => 'Resignation';

  @override
  String get hrSeparationTypeTerminationLabel => 'Termination';

  @override
  String get hrSeparationTypeRetirementLabel => 'Retirement';

  @override
  String get hrSeparationTypeContractEndLabel => 'Contract end';

  @override
  String get hrSeparationTypeDeceasedLabel => 'Deceased';

  @override
  String get hrSeparationTypeOtherLabel => 'Separation';

  @override
  String get hrLastWorkingDayLabel => 'Last working day';

  @override
  String get hrSeparationNotesLabel => 'Reason / notes';

  @override
  String get hrOffboardEndAssignmentsLabel => 'End all active assignments';

  @override
  String get hrOffboardRevokeAccessLabel => 'Revoke system access';

  @override
  String get hrOffboardFinalPayrollLabel => 'Schedule final payroll';

  @override
  String hrSeparationBannerMessage(String separationType, String lastDay) {
    return '$separationType · Last day $lastDay';
  }

  @override
  String get hrShiftTemplateAction => 'Schedule templates';

  @override
  String get hrShiftTemplateDialogTitle => 'Schedule pattern';

  @override
  String get hrSchedulePatternCreateTitle => 'Schedule pattern';

  @override
  String get hrSchedulePatternEditTitle => 'Edit schedule pattern';

  @override
  String get hrCreateShiftTemplateAction => 'Create schedule';

  @override
  String get hrEditShiftTemplateAction => 'Edit';

  @override
  String get hrDeleteShiftTemplateAction => 'Delete';

  @override
  String get hrSchedulePatternEditAction => 'Edit';

  @override
  String get hrSchedulePatternDeleteAction => 'Delete';

  @override
  String get hrScheduleTemplateIdLabel => 'Template ID';

  @override
  String get hrScheduleTemplateActiveLabel => 'Active';

  @override
  String get hrScheduleTemplateInactiveLabel => 'Inactive';

  @override
  String get hrStatusLabel => 'Status';

  @override
  String get hrCreatedAtLabel => 'Created';

  @override
  String get hrUpdatedAtLabel => 'Updated';

  @override
  String get hrShiftTypeDay => 'Day shift';

  @override
  String get hrShiftTypeNight => 'Night shift';

  @override
  String get hrShiftTypeSwing => 'Swing shift';

  @override
  String get hrShiftTypeOnCall => 'On call';

  @override
  String get hrShiftTemplateNameLabel => 'Template name';

  @override
  String get hrPreviewPayrollAction => 'Preview payroll';

  @override
  String get hrPreviewPayrollDialogTitle => 'Payroll preview';

  @override
  String get hrPreviewRosterAction => 'Preview roster generation';

  @override
  String get hrPreviewRosterDialogTitle => 'Roster generation preview';

  @override
  String get hrRosterCoverageLabel => 'Coverage';

  @override
  String get hrRosterGapsLabel => 'Staffing gaps';

  @override
  String get hrPasswordLabel => 'Temporary password';

  @override
  String get hrEmailLabel => 'Email';

  @override
  String get hrOnboardingModeExistingUser => 'Link existing user';

  @override
  String get hrOnboardingModeCreateUser => 'Create new user';

  @override
  String get hrWednesdayLabel => 'Wednesday';

  @override
  String get hrWorkQueuesTitle => 'Work queues';

  @override
  String get hrWorkQueuesToolbarTooltip => 'Browse and act on all queue types';

  @override
  String get copyAdmissionIdAction => 'Copy admission ID';

  @override
  String get copyUserIdAction => 'Copy user ID';

  @override
  String get copyIdentifierAction => 'Copy identifier';

  @override
  String get admissionIdCopiedMessage => 'Admission ID copied.';

  @override
  String get userIdCopiedMessage => 'User ID copied.';

  @override
  String get identifierCopiedMessage => 'Identifier copied.';

  @override
  String get settingsWorkspaceSectionTitle => 'Administrative setup workspace';

  @override
  String get settingsWorkspaceSectionBody =>
      'Review tenant, facility, access, and security setup readiness.';

  @override
  String get settingsWorkspaceLoadingTitle => 'Loading settings workspace';

  @override
  String get settingsWorkspaceLoadingBody => 'Loading setup readiness...';

  @override
  String get settingsWorkspaceErrorTitle => 'Settings workspace unavailable';

  @override
  String get settingsWorkspaceEmptyTitle => 'No setup modules found';

  @override
  String get settingsWorkspaceEmptyBody =>
      'No setup modules match the filters.';

  @override
  String get settingsWorkspaceContextTitle => 'Context summary';

  @override
  String get settingsWorkspaceTenantLabel => 'Tenant';

  @override
  String get settingsWorkspaceFacilityLabel => 'Facility';

  @override
  String get settingsWorkspaceFacilityTypeLabel => 'Facility type';

  @override
  String get settingsWorkspaceRolesLabel => 'Roles';

  @override
  String get settingsWorkspaceGeneratedAtLabel => 'Generated';

  @override
  String get settingsWorkspaceRecordsLabel => 'Records';

  @override
  String get settingsWorkspaceAttentionLabel => 'Needs attention';

  @override
  String get settingsWorkspaceConfiguredLabel => 'Configured';

  @override
  String get settingsWorkspaceTotalRecordsLabel => 'Total records';

  @override
  String get settingsWorkspaceChecklistTitle => 'Setup checklist';

  @override
  String get settingsWorkspaceQuickActionsTitle => 'Quick actions';

  @override
  String get settingsWorkspaceModuleGroupsTitle => 'Module groups';

  @override
  String get settingsWorkspaceSearchLabel => 'Search setup modules';

  @override
  String get settingsWorkspaceSearchHint => 'Search by module, group, or route';

  @override
  String get settingsWorkspaceGroupFilterLabel => 'Group';

  @override
  String get settingsWorkspaceStateFilterLabel => 'State';

  @override
  String get settingsWorkspaceAllGroupsLabel => 'All groups';

  @override
  String get settingsWorkspaceAllStatesLabel => 'All states';

  @override
  String get settingsWorkspaceActionableOnlyLabel => 'Actionable only';

  @override
  String get settingsWorkspaceTenantSelectorLabel => 'Tenant context';

  @override
  String get settingsWorkspaceFacilitySelectorLabel => 'Facility context';

  @override
  String get settingsWorkspaceApplyContextAction => 'Apply context';

  @override
  String get settingsWorkspaceOpenAction => 'Open';

  @override
  String get settingsWorkspaceCreateAction => 'Create';

  @override
  String get settingsWorkspaceRouteUnavailableLabel => 'Unavailable';

  @override
  String get settingsWorkspaceRouteUnavailableBody =>
      'This setup action is not available from this page yet.';

  @override
  String get settingsWorkspaceTenantContextRequiredTitle =>
      'Tenant context required';

  @override
  String get settingsWorkspaceTenantContextRequiredBody =>
      'Select a tenant to load administrative setup readiness.';

  @override
  String get settingsWorkspaceReadyStatus => 'Ready';

  @override
  String get settingsWorkspaceInProgressStatus => 'In progress';

  @override
  String get settingsWorkspaceAttentionStatus => 'Attention';

  @override
  String get settingsWorkspaceEmptyStatus => 'Empty';

  @override
  String get settingsWorkspaceConfiguredStatus => 'Configured';

  @override
  String get settingsWorkspaceOrganizationGroup => 'Organization';

  @override
  String get settingsWorkspaceUsersAndAccessGroup => 'Users and access';

  @override
  String get settingsWorkspaceSecurityGroup => 'Security';

  @override
  String get settingsWorkspaceUnknownLabel => 'Unavailable';

  @override
  String get settingsWorkspaceDependencyBlockedLabel =>
      'Waiting for required setup';

  @override
  String get settingsWorkspaceRequiredSetupLabel => 'Required setup';

  @override
  String get settingsWorkspaceOptionalSetupLabel => 'Optional setup';

  @override
  String get settingsWorkspaceNoQuickActionsBody =>
      'No setup action is currently available for the selected context.';

  @override
  String get settingsWorkspaceNoModulesBody =>
      'No modules match the selected filters.';

  @override
  String get settingsWorkspaceSelectTenantAction => 'Select tenant';

  @override
  String get settingsWorkspaceModuleTenant => 'Tenant';

  @override
  String get settingsWorkspaceModuleFacility => 'Facility';

  @override
  String get settingsWorkspaceModuleBranch => 'Branch';

  @override
  String get settingsWorkspaceModuleDepartment => 'Department';

  @override
  String get settingsWorkspaceModuleUnit => 'Unit';

  @override
  String get settingsWorkspaceModuleRoom => 'Room';

  @override
  String get settingsWorkspaceModuleWard => 'Ward';

  @override
  String get settingsWorkspaceModuleBed => 'Bed';

  @override
  String get settingsWorkspaceModuleAddress => 'Address';

  @override
  String get settingsWorkspaceModuleContact => 'Contact';

  @override
  String get settingsWorkspaceModuleUser => 'User';

  @override
  String get settingsWorkspaceModuleUserProfile => 'User profile';

  @override
  String get settingsWorkspaceModuleRole => 'Role';

  @override
  String get settingsWorkspaceModulePermission => 'Permission';

  @override
  String get settingsWorkspaceModuleRolePermission => 'Role permission';

  @override
  String get settingsWorkspaceModuleUserRole => 'User role';

  @override
  String get settingsWorkspaceModuleUserSession => 'User session';

  @override
  String get settingsWorkspaceModuleApiKey => 'API key';

  @override
  String get settingsWorkspaceModuleApiKeyPermission => 'API key permission';

  @override
  String get settingsWorkspaceModuleUserMfa => 'User MFA';

  @override
  String get settingsWorkspaceModuleOauthAccount => 'OAuth account';

  @override
  String get pharmacyWorkflowReadinessTitle => 'Pharmacy workflow readiness';

  @override
  String get pharmacyWorkflowReadinessBody =>
      'Actions below follow the current order, stock, batch, and attestation state.';

  @override
  String get pharmacyReadinessDispenseAvailable =>
      'Dispense is available for the current order state.';

  @override
  String get pharmacyReadinessDispenseBlocked =>
      'Dispense is blocked by the current order, payment, stock, or authorization state.';

  @override
  String get pharmacyReadinessStockMapped =>
      'Medication items have stock mapping available.';

  @override
  String get pharmacyReadinessStockMissing =>
      'Some medication items need stock mapping before dispense.';

  @override
  String get pharmacyReadinessAttestationRequired =>
      'Prepared batches require attestation before completion.';

  @override
  String get pharmacyReadinessAttestationClear =>
      'No prepared batch attestation is pending.';

  @override
  String get pharmacyReadinessPrintReady =>
      'Medication printouts use the configured print workflow.';

  @override
  String get commonSelectActionLabel => 'Select';

  @override
  String get commonSaveActionLabel => 'Save';

  @override
  String get commonNextActionLabel => 'Next';

  @override
  String get commonRemoveActionLabel => 'Remove';

  @override
  String get labOrdersViewAction => 'Orders view';

  @override
  String get labPatientsViewAction => 'Patients view';

  @override
  String get labReferenceRangesAction => 'Lab Configurations';

  @override
  String get labTableColumnsTitle => 'Lab table columns';

  @override
  String get labApplyColumnsAction => 'Apply columns';

  @override
  String get labResetColumnsAction => 'Reset columns';

  @override
  String get labPatientsSummaryLabel => 'Patients';

  @override
  String get labPatientsAwaitingResultsSummaryLabel =>
      'Patients awaiting results';

  @override
  String get labPatientsProcessingSummaryLabel => 'Patients in processing';

  @override
  String get labPatientsPendingVerificationSummaryLabel =>
      'Patients pending verification';

  @override
  String get labPatientsCriticalSummaryLabel =>
      'Patients with critical results';

  @override
  String get labPatientsCompletedSummaryLabel => 'Patients completed';

  @override
  String get labPatientsWorklistTitle => 'Patient lab worklist';

  @override
  String get labPatientsWorklistDescription =>
      'Patients with active lab orders.';

  @override
  String get labNoPatientsTitle => 'No patients in lab worklist';

  @override
  String get labNoPatientsBody =>
      'Patients with matching lab orders will appear here.';

  @override
  String get labOrdersColumnLabel => 'Orders';

  @override
  String get labPatientIdFieldLabel => 'Patient ID';

  @override
  String get labVerifyAllAction => 'Verify all';

  @override
  String get labEntryStatusColumnLabel => 'Entry status';

  @override
  String get labPaymentColumnLabel => 'Payment';

  @override
  String get labSelectOrderDialogTitle => 'Select Lab Order';

  @override
  String get labSelectOrderDialogBody =>
      'This patient has multiple active lab orders. Select the order to review.';

  @override
  String get labNoOrderItemsLabel => 'No ordered tests found';

  @override
  String get labTestCodeLabel => 'Test code';

  @override
  String get labVerifyResultAction => 'Verify result';

  @override
  String get labEditVerifiedResultAction => 'Edit';

  @override
  String get labReopenVerifiedResultDialogTitle => 'Edit Verified Result';

  @override
  String get labReopenVerifiedResultDialogBody =>
      'Update the value and reason. Saving re-verifies the corrected result.';

  @override
  String get labReopenVerifiedReasonLabel => 'Reason for edit';

  @override
  String get labVerifiedResultReopenedMessage => 'Result reopened for editing.';

  @override
  String get labRestoreOrderItemAction => 'Restore test';

  @override
  String get labRestoreOrderItemDialogTitle => 'Restore Cancelled Test';

  @override
  String labRestoreOrderItemDialogBody(String testName) {
    return 'Restore \"$testName\"? It returns to the active worklist.';
  }

  @override
  String get labDeleteOrderItemAction => 'Delete request';

  @override
  String get labDeleteOrderItemDialogTitle => 'Delete Test Request';

  @override
  String labDeleteOrderItemDialogBody(String testName) {
    return 'Delete \"$testName\" from this order? This cannot be undone.';
  }

  @override
  String get labDeletePanelAction => 'Delete panel';

  @override
  String get labDeletePanelDialogTitle => 'Delete Lab Panel';

  @override
  String labDeletePanelDialogBody(String panelName) {
    return 'Remove $panelName from the lab catalog? A reason is required for audit.';
  }

  @override
  String get labRejectOrderItemAction => 'Reject test';

  @override
  String get labResultFlagLabel => 'Flag';

  @override
  String get labVerifyResultDialogTitle => 'Enter and Verify Result';

  @override
  String get labNumericRangeValidationMessage => 'Enter a valid number.';

  @override
  String get labVerifyAllDialogTitle => 'Verify Entered Results';

  @override
  String get labRejectOrderItemDialogTitle => 'Reject Requested Test';

  @override
  String get labRejectReasonNotPerformedHere => 'Test not performed here';

  @override
  String get labRejectReasonInsufficientInfo => 'Insufficient information';

  @override
  String get labRejectReasonInvalidRequest => 'Invalid request';

  @override
  String get labRejectReasonOther => 'Other reason';

  @override
  String get labRejectCustomReasonLabel => 'Custom reason';

  @override
  String get labReferenceRangesDialogTitle => 'Lab Configurations';

  @override
  String get labReferenceRangesDialogBody =>
      'Enable tests and panels, set prices, and customize ranges and result options.';

  @override
  String get labConfigurationsLoadingTitle => 'Loading lab catalog';

  @override
  String get labConfigurationsLoadingBody => 'Loading facility lab offerings.';

  @override
  String get labEnableTestAction => 'Enable test';

  @override
  String get labEnablePanelAction => 'Enable panel';

  @override
  String get labEnableOfferingDialogTitle => 'Enable Lab Offering';

  @override
  String get labEnableOfferingDialogBody =>
      'Select a catalog item and set the facility price for ordering.';

  @override
  String get labEnableOfferingCatalogLabel => 'Platform catalog item';

  @override
  String get labEnableOfferingNoItemsLabel =>
      'All platform items are already offered at this facility.';

  @override
  String get labEnableOfferingNoPlatformItemsLabel =>
      'No platform lab catalog items are available for this tenant.';

  @override
  String get labEnableOfferingAlreadyOfferedLabel => 'Already offered';

  @override
  String get labConfigurationsSelectScopeBody =>
      'Select a tenant and facility to load and configure the lab catalog.';

  @override
  String labConfigurationsSelectFacilityOnlyBody(String tenantName) {
    return 'Select a facility for $tenantName to load and configure the lab catalog.';
  }

  @override
  String get labConfigurationsSelectTenantFirstTooltip =>
      'Select a tenant first';

  @override
  String labConfigurationsFacilityContextLabel(String facilityName) {
    return 'Configuring lab catalog for $facilityName.';
  }

  @override
  String get labConfigureTestAction => 'Configure test';

  @override
  String get labQcLogsAction => 'QC logs';

  @override
  String get labQcLogsSectionBody =>
      'Record quality-control runs for tests offered at this facility.';

  @override
  String get labConfigureTestDialogTitle => 'Configure Lab Test';

  @override
  String get labOfferAtFacilityLabel => 'Offer at this facility';

  @override
  String get labPlatformDefaultsHint =>
      'Platform default — editable for this facility';

  @override
  String get labAddReferenceRangeAction => 'Add reference range';

  @override
  String get labCatalogReadOnlyHint =>
      'Contact your lab administrator to change catalog settings.';

  @override
  String get labOfferedStatusLabel => 'Offered';

  @override
  String get labNotOfferedStatusLabel => 'Not offered';

  @override
  String get labTestNameLabel => 'Test name';

  @override
  String get labCategoryLabel => 'Category';

  @override
  String get labSpecimenTypeLabel => 'Specimen type';

  @override
  String get labResultKindLabel => 'Result kind';

  @override
  String get labResultKindNumeric => 'Numeric';

  @override
  String get labResultKindQualitative => 'Qualitative';

  @override
  String get labResultKindText => 'Text';

  @override
  String get labDefaultUnitLabel => 'Default unit';

  @override
  String get labUnitOptionsLabel => 'Unit options';

  @override
  String get labCommaSeparatedHelper => 'Separate multiple values with commas.';

  @override
  String get labQualitativeOptionsLabel => 'Qualitative result options';

  @override
  String get labGenderApplicabilityLabel => 'Gender applicability';

  @override
  String get labGenderAnyLabel => 'Any';

  @override
  String get labGenderMaleLabel => 'Male';

  @override
  String get labGenderFemaleLabel => 'Female';

  @override
  String get labAgeMinLabel => 'Age min';

  @override
  String get labAgeMaxLabel => 'Age max';

  @override
  String get labAgeUnitLabel => 'Age unit';

  @override
  String get labAgeUnitDays => 'Days';

  @override
  String get labAgeUnitMonths => 'Months';

  @override
  String get labAgeUnitYears => 'Years';

  @override
  String get labNormalMinLabel => 'Normal min';

  @override
  String get labNormalMaxLabel => 'Normal max';

  @override
  String get labCriticalMinLabel => 'Critical min';

  @override
  String get labCriticalMaxLabel => 'Critical max';

  @override
  String get labReferenceTextLabel => 'Reference text';

  @override
  String get labStatusPendingResults => 'Pending results';

  @override
  String get labStatusVerified => 'Verified';

  @override
  String get labStatusLow => 'Low';

  @override
  String get labStatusHigh => 'High';

  @override
  String get labNextActionVerify => 'Verify result';

  @override
  String get labNextActionEnterResult => 'Enter result';

  @override
  String get labCreateAction => 'Create Lab Order';

  @override
  String get labCreateChoiceDialogTitle => 'Create Laboratory Item';

  @override
  String get labCreateChoiceDialogBody =>
      'Choose the laboratory record you want to create.';

  @override
  String get labCreateOrderAction => 'Create lab order';

  @override
  String get labCreateOrderChoiceBody =>
      'Request tests or panels for a patient.';

  @override
  String get labCreateOrderDialogTitle => 'Create Lab Order';

  @override
  String get labCreateTestAction => 'Add test';

  @override
  String get labCreateTestChoiceBody =>
      'Add a configurable test to the lab catalog.';

  @override
  String get labCreateTestDialogTitle => 'Create Lab Test';

  @override
  String get labCreatePanelAction => 'Add panel';

  @override
  String get labCreatePanelChoiceBody =>
      'Group existing tests into a reusable panel.';

  @override
  String get labCreatePanelDialogTitle => 'Create Lab Panel';

  @override
  String get labPanelNameLabel => 'Panel name';

  @override
  String get labPanelCodeLabel => 'Panel code';

  @override
  String get labPanelDescriptionLabel => 'Description';

  @override
  String get labReferenceRangesSearchHint =>
      'Search test, panel, code, category, specimen, unit, or range';

  @override
  String get labActionColumnLabel => 'Action';

  @override
  String get labUnitRangeCountColumnLabel => 'Unit / ranges';

  @override
  String get labGenderOtherLabel => 'Other';

  @override
  String get labGenderUnknownLabel => 'Unknown';

  @override
  String get labAgeUnitWeeks => 'Weeks';

  @override
  String get labAddValueAction => 'Add value';

  @override
  String get labAddValueFieldHint => 'Type a value, then add it';

  @override
  String get labEditOrderAction => 'Edit order';

  @override
  String get labEditOrderDialogTitle => 'Edit Lab Order Context';

  @override
  String get labUpdateOrderSubmitAction => 'Update lab order';

  @override
  String get labDeleteOrderAction => 'Delete order';

  @override
  String get labDeleteTestAction => 'Delete test';

  @override
  String get labDeleteReasonLabel => 'Deletion reason';

  @override
  String get labDeleteReasonHint =>
      'Explain why this lab record should be deleted';

  @override
  String get labDeleteReasonValidationMessage => 'Enter a deletion reason.';

  @override
  String get labDeleteOrderDialogTitle => 'Delete Lab Order';

  @override
  String labDeleteOrderDialogBody(String orderId) {
    return 'Remove lab order $orderId from the queue? A reason is required for audit.';
  }

  @override
  String get labDeleteTestDialogTitle => 'Delete Lab Test';

  @override
  String labDeleteTestDialogBody(String testName) {
    return 'Remove $testName from the lab catalog? A reason is required for audit.';
  }

  @override
  String get labDeletedMessage => 'Laboratory record deleted.';

  @override
  String get labDuplicateTestNameMessage =>
      'A lab test with this name already exists.';

  @override
  String get labDuplicateTestCodeMessage =>
      'A lab test with this code already exists.';

  @override
  String get labDuplicatePanelNameMessage =>
      'A lab panel with this name already exists.';

  @override
  String get labDuplicatePanelCodeMessage =>
      'A lab panel with this code already exists.';

  @override
  String get labUpdatePanelDialogTitle => 'Edit Lab Panel';

  @override
  String get labUpdatePanelAction => 'Edit panel';

  @override
  String get labPanelTestsLabel => 'Panel tests';

  @override
  String get labPanelTestSelectLabel => 'Lab test';

  @override
  String get labPanelAddTestAction => 'Add test';

  @override
  String get labPanelSelectedTestsTitle => 'Selected tests';

  @override
  String get labPanelNoSelectedTests => 'No tests selected for this panel.';

  @override
  String get labTestDescriptionLabel => 'Test description';

  @override
  String get labReferenceNotesLabel => 'Reference notes';

  @override
  String get labPositiveOption => 'Positive';

  @override
  String get labNegativeOption => 'Negative';

  @override
  String get labAdultRangeLabel => 'Adult';

  @override
  String get labPediatricRangeLabel => 'Pediatric';

  @override
  String get labNeonateRangeLabel => 'Neonate';

  @override
  String labActiveOrderCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count active orders',
      one: '1 active order',
    );
    return '$_temp0';
  }

  @override
  String get labPreviewReportAction => 'Preview report';

  @override
  String get labPrintReportAction => 'Print report';

  @override
  String get labResetReportSelectionAction => 'Reset selection';

  @override
  String get labReportSelectionTitle => 'Select tests for the report';

  @override
  String get labReportSelectionHint =>
      'Use checkboxes on each result row to choose what to print.';

  @override
  String get labReportOrderDetailsToggleLabel => 'Include order details';

  @override
  String get labReportOrderDetailsToggleHint =>
      'Show order identifiers and dates above each results table.';

  @override
  String labReportSelectedTestCount(int selectedCount, int totalCount) {
    return '$selectedCount of $totalCount tests selected';
  }

  @override
  String get labReportIncludeColumnLabel => 'Include';

  @override
  String get labReportNoSelectionLabel => 'No report items selected';

  @override
  String get labOrdersIncludedLabel => 'Orders included';

  @override
  String get labRemoveDraftResultAction => 'Remove result';

  @override
  String get labRemoveDraftResultDialogTitle => 'Remove Lab Result?';

  @override
  String get labRemoveDraftResultDialogBody =>
      'This draft result will be removed from the selected test.';

  @override
  String get labDraftRemovedMessage => 'Result removed.';

  @override
  String get labStatusFilled => 'Filled';

  @override
  String get labStatusPartiallyEntered => 'Partially entered';

  @override
  String get labStatusPartiallyFilled => 'Partially filled';

  @override
  String get labStatusPartiallyRejected => 'Partially rejected';

  @override
  String get labStatusPartiallyVerified => 'Partially verified';

  @override
  String labRejectedItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rejected',
      one: '1 rejected',
    );
    return '$_temp0';
  }

  @override
  String get labReportSignatureLabel => 'Signature / stamp';

  @override
  String labReferenceRangeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ranges',
      one: '1 range',
    );
    return '$_temp0';
  }

  @override
  String get commonYesLabel => 'Yes';

  @override
  String get commonNoLabel => 'No';

  @override
  String get radiologyOrdersViewAction => 'Orders view';

  @override
  String get radiologyPatientsViewAction => 'Patients view';

  @override
  String get radiologyConfigurationsAction => 'Configurations';

  @override
  String get radiologyConfigurationsDialogTitle => 'Radiology configurations';

  @override
  String get radiologyConfigurationsLoadingTitle => 'Loading radiology catalog';

  @override
  String get radiologyConfigurationsLoadingBody =>
      'Loading facility radiology offerings.';

  @override
  String get radiologyConfigurationsSelectScopeBody =>
      'Select tenant and facility to configure the radiology catalog.';

  @override
  String radiologyConfigurationsSelectFacilityOnlyBody(String tenantName) {
    return 'Select a facility for $tenantName to configure the radiology catalog.';
  }

  @override
  String get radiologyConfigurationsSelectTenantFirstTooltip =>
      'Select a tenant first';

  @override
  String radiologyConfigurationsFacilityContextLabel(String facilityName) {
    return 'Configuring radiology catalog for $facilityName.';
  }

  @override
  String get radiologyEnableOfferingDialogTitle => 'Enable Radiology Offering';

  @override
  String get radiologyEnableOfferingDialogBody =>
      'Select a catalog procedure and set the facility price.';

  @override
  String get radiologyEnableOfferingNoItemsLabel =>
      'All platform procedures are already offered at this facility.';

  @override
  String get radiologyEnableOfferingNoPlatformItemsLabel =>
      'No platform radiology catalog items are available for this tenant.';

  @override
  String get radiologyEnableOfferingAlreadyOfferedLabel => 'Already offered';

  @override
  String get radiologyEnableOfferingAvailableLabel => 'Available';

  @override
  String get radiologyDeleteSelectedOfferingsAction => 'Delete selected';

  @override
  String get radiologyDeleteSelectedOfferingsDialogTitle =>
      'Remove selected procedures?';

  @override
  String radiologyDeleteSelectedOfferingsDialogBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count procedures',
      one: '1 procedure',
    );
    return 'Remove $_temp0 from this catalog? Clinicians cannot order them here.';
  }

  @override
  String get radiologyOfferingDisabledMessage =>
      'Radiology procedure removed from facility catalog.';

  @override
  String get radiologyDisableOfferingDialogTitle =>
      'Remove procedure from facility?';

  @override
  String radiologyDisableOfferingDialogBody(String name) {
    return 'Remove $name from this catalog? Clinicians cannot order it here.';
  }

  @override
  String get radiologyEnableProcedureAction => 'Enable procedure';

  @override
  String get radiologyEditOfferingDialogTitle => 'Edit facility offering';

  @override
  String get radiologyPatientsSummaryLabel => 'Radiology patients';

  @override
  String get radiologyPatientsWaitingImagingSummaryLabel =>
      'Patients waiting imaging';

  @override
  String get radiologyPatientsWorklistTitle => 'Radiology patients';

  @override
  String get radiologyPatientsWorklistDescription =>
      'Patients with active imaging orders.';

  @override
  String get radiologyNoPatientsTitle => 'No radiology patients';

  @override
  String get radiologyNoPatientsBody =>
      'Patients with matching imaging requests will appear here.';

  @override
  String get radiologyTableColumnsTitle => 'Radiology columns';

  @override
  String get radiologyApplyColumnsAction => 'Apply columns';

  @override
  String get radiologyResetColumnsAction => 'Reset columns';

  @override
  String get radiologyOrdersColumnLabel => 'Order(s)';

  @override
  String get radiologyOneActiveOrderLabel => '1 active order';

  @override
  String get radiologyReferenceSearchOptionalLabel =>
      'Catalog search (optional)';

  @override
  String get radiologySelectImagingTestsAction => 'Select imaging tests';

  @override
  String get radiologyClearSelectedTestsAction => 'Clear selected tests';

  @override
  String get radiologySelectAtLeastOneTestMessage =>
      'Select at least one imaging test.';

  @override
  String get radiologyModalityFluoroscopy => 'FLUOROSCOPY';

  @override
  String get radiologyModalityMammography => 'MAMMOGRAPHY';

  @override
  String get radiologyModalityNuclearMedicine => 'NUCLEAR MEDICINE';

  @override
  String get radiologyModalityInterventionalRadiology =>
      'INTERVENTIONAL RADIOLOGY';

  @override
  String get radiologyImagingTestsTabLabel => 'Imaging tests';

  @override
  String get radiologyEquipmentTabLabel => 'Equipment';

  @override
  String get radiologyConfigurationSearchLabel =>
      'Search radiology configurations';

  @override
  String get radiologyConfigurationSearchHint =>
      'Search tests, modality, code, source, or status';

  @override
  String get radiologyCreateImagingTestAction => 'Create imaging test';

  @override
  String get radiologyEditImagingTestAction => 'Edit imaging test';

  @override
  String get radiologyDeleteImagingTestAction => 'Delete imaging test';

  @override
  String get radiologyCopyStandardTestAction => 'Copy standard test';

  @override
  String get radiologyStandardCatalogBadge => 'Standard catalog';

  @override
  String get radiologyCustomCatalogBadge => 'Custom';

  @override
  String get radiologyTestNameLabel => 'Name';

  @override
  String get radiologyTestCodeLabel => 'Code';

  @override
  String get radiologyTestCodeOptionalLabel => 'Code (optional)';

  @override
  String get radiologySourceColumnLabel => 'Source';

  @override
  String get radiologyEquipmentColumnLabel => 'Equipment';

  @override
  String get radiologyActionColumnLabel => 'Action';

  @override
  String get radiologyNoImagingTestsTitle => 'No imaging tests';

  @override
  String get radiologyNoImagingTestsBody =>
      'Create a custom imaging test or refresh the standard catalog.';

  @override
  String get radiologyReadOnlyStandardTestTitle => 'Standard test is read-only';

  @override
  String get radiologyReadOnlyStandardTestMessage =>
      'Standard catalog rows are read-only. Copy one to create a custom test.';

  @override
  String get radiologyDeleteImagingTestDialogTitle => 'Delete imaging test?';

  @override
  String get radiologyTenantRequiredForConfigMessage =>
      'Tenant context is required to save a custom imaging test.';

  @override
  String get radiologyEquipmentRecordsTitle => 'Equipment records';

  @override
  String get radiologyEquipmentRecordsBody =>
      'Equipment is managed through the existing equipment registry.';

  @override
  String get radiologyEquipmentNameColumnLabel => 'Equipment';

  @override
  String get radiologyEquipmentCodeColumnLabel => 'Equipment ID';

  @override
  String get radiologyManufacturerModelLabel => 'Manufacturer / model';

  @override
  String get radiologyEquipmentCategoryLabel => 'Category';

  @override
  String get radiologyFacilityColumnLabel => 'Facility';

  @override
  String get radiologyEquipmentSearchHint =>
      'Search equipment name, code, serial, manufacturer, model, category, or status';

  @override
  String get radiologyNoEquipmentTitle => 'No equipment records';

  @override
  String get radiologyNoEquipmentBody =>
      'Equipment registry records matching this search will appear here.';

  @override
  String get radiologyEquipmentLinkGapTitle =>
      'Test equipment mapping unavailable';

  @override
  String get radiologyEquipmentLinkGapBody =>
      'Imaging-to-equipment links are not persisted; local mappings are not saved.';

  @override
  String get radiologySaveConfigurationAction => 'Save configuration';

  @override
  String get radiologyAttachImagesTitle => 'Attach images';

  @override
  String get radiologyAttachImagesBody =>
      'Select images, add captions, then upload to this study.';

  @override
  String get radiologyUploadImagesAction => 'Upload images';

  @override
  String get radiologyAssetCaptionLabel => 'Caption';

  @override
  String get radiologyRemoveAssetAction => 'Remove image';

  @override
  String get radiologyPrintIncludeImagesLabel => 'Include study images';

  @override
  String get radiologyChooseImagesAction => 'Choose images';

  @override
  String get radiologyClearSelectedImagesAction => 'Clear images';

  @override
  String get radiologyReportReferencesTitle => 'Report references';

  @override
  String get radiologyReportReferencesBody =>
      'Insert an existing asset or PACS reference into the report text.';

  @override
  String get radiologyNoReportReferencesLabel =>
      'No asset or PACS references available.';

  @override
  String get radiologyAssetReferencePrefix => 'Asset reference';

  @override
  String get radiologyPacsReferencePrefix => 'PACS reference';

  @override
  String get radiologyPrintReportAction => 'Print report';

  @override
  String get radiologyPrintReportDialogTitle => 'Print radiology report';

  @override
  String get radiologyPrintReportDialogBody =>
      'Choose report sections. Patient, findings, impression, and signer are included by default.';

  @override
  String get radiologyPrintPreviewTitle => 'Print preview';

  @override
  String get radiologyPrintAction => 'Print';

  @override
  String get radiologyPrintIncludeHeaderLabel => 'Facility/app header';

  @override
  String get radiologyPrintIncludePatientLabel => 'Patient details';

  @override
  String get radiologyPrintIncludeOrderLabel => 'Encounter/order details';

  @override
  String get radiologyPrintIncludeStudiesLabel => 'Imaging tests/studies';

  @override
  String get radiologyPrintIncludeReportLabel => 'Findings and report text';

  @override
  String get radiologyPrintIncludeReferencesLabel => 'Image/PACS references';

  @override
  String get radiologyPrintIncludeSignerLabel => 'Signer/reporter';

  @override
  String get radiologyPrintIncludeMetadataLabel => 'Technical metadata';

  @override
  String get radiologyPrintFooterNote =>
      'Generated from HMS Radiology workspace.';

  @override
  String get radiologyPrintReportTitle => 'Radiology report';

  @override
  String get radiologyPrintPatientSectionTitle => 'Patient details';

  @override
  String get radiologyPrintOrderSectionTitle => 'Encounter and order details';

  @override
  String get radiologyPrintStudiesSectionTitle => 'Imaging tests and studies';

  @override
  String get radiologyPrintReportSectionTitle => 'Findings and report';

  @override
  String get radiologyPrintReferencesSectionTitle =>
      'Image and PACS references';

  @override
  String get radiologyPrintSignerSectionTitle => 'Signer and reporter';

  @override
  String get radiologyPrintNoSectionsSelected => 'No report sections selected.';

  @override
  String get radiologyPatientIdLabel => 'Patient ID';

  @override
  String get radiologyFinalizationRequestedLabel => 'Finalization requested';

  @override
  String get radiologyFinalizationAttestedLabel => 'Finalization attested';

  @override
  String radiologyActiveOrdersLabel(int count) {
    return '$count active orders';
  }

  @override
  String radiologyDeleteImagingTestDialogBody(String name) {
    return 'Delete $name? It will no longer be available for new requests.';
  }

  @override
  String radiologyInsertAssetReferenceAction(String label) {
    return 'Insert asset: $label';
  }

  @override
  String radiologyInsertPacsReferenceAction(String label) {
    return 'Insert PACS: $label';
  }

  @override
  String radiologyPrintStudyCount(int count) {
    return '$count studies';
  }

  @override
  String get clinicalRequestBillingSectionTitle => 'Request billing';

  @override
  String get clinicalRequestAddCatalogItemsAction => 'Add items';

  @override
  String get clinicalRequestReviewBillingAction => 'Review billing';

  @override
  String get clinicalRequestCatalogPickerDoneAction => 'Done';

  @override
  String get clinicalRequestMainPanelHelp =>
      'Review selection, add catalog items, then confirm billing.';

  @override
  String get clinicalRequestRemoveSelectedAction => 'Remove selected';

  @override
  String get clinicalRequestPatientNameLabel => 'Patient name';

  @override
  String get clinicalRequestPatientIdLabel => 'Patient ID';

  @override
  String get clinicalRequestPatientEncounterIdLabel => 'Encounter ID';

  @override
  String get clinicalRequestRemoveItemAction => 'Remove item';

  @override
  String get clinicalLabRequestRemoveConfirmTitle => 'Remove lab request?';

  @override
  String clinicalLabRequestRemoveConfirmTitleMultiple(int count) {
    return 'Remove $count lab requests?';
  }

  @override
  String get clinicalLabRequestRemoveConfirmBody =>
      'The following will be removed from this request:';

  @override
  String get clinicalLabRequestRemoveConfirmAction => 'Remove';

  @override
  String get clinicalRequestSelectedNameColumnLabel => 'Test name';

  @override
  String get clinicalRequestSelectedTypeColumnLabel => 'Type';

  @override
  String get clinicalRequestSelectedPriceColumnLabel => 'Price';

  @override
  String get clinicalRequestSelectedActionsColumnLabel => 'Actions';

  @override
  String get clinicalLabRequestSelectedTableEmptyLabel =>
      'No lab requests selected. Use Add items.';

  @override
  String clinicalRequestFlowItemCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
      zero: 'No items',
    );
    return '$_temp0';
  }

  @override
  String get clinicalLabRequestCatalogPickerTitle =>
      'Choose lab tests or panels';

  @override
  String get clinicalLabRequestCatalogPickerConfirmAction =>
      'Confirm selected tests or panels';

  @override
  String get clinicalLabRequestCatalogColumnsTitle =>
      'Lab catalog table columns';

  @override
  String get clinicalRadiologyCatalogPickerTitle => 'Choose imaging study';

  @override
  String get clinicalRadiologyAddStudyAction => 'Add study';

  @override
  String get clinicalRadiologyRequestSelectedTableEmptyLabel =>
      'No imaging requests selected. Use Add study.';

  @override
  String get clinicalRadiologyRequestCatalogPickerConfirmAction =>
      'Confirm selected studies';

  @override
  String get clinicalRadiologyRequestCatalogColumnsTitle =>
      'Imaging catalog table columns';

  @override
  String get clinicalProcedureCatalogPickerTitle => 'Choose procedures';

  @override
  String get clinicalPrescriptionLineDialogTitle => 'Add medicine';

  @override
  String get clinicalPrescriptionEditLineDialogTitle => 'Edit medicine';

  @override
  String get clinicalPrescriptionNoMedicinesLabel => 'No medicines added yet';

  @override
  String get clinicalRequestBillingNoItemsLabel => 'Add items to see pricing.';

  @override
  String get clinicalRequestBillingTotalLabel => 'Total';

  @override
  String get clinicalRequestPriceNotSetLabel => 'Price not set';

  @override
  String get clinicalRequestPriceWarningLabel => 'Some items have no price set';

  @override
  String get clinicalRequestUnitPriceLabel => 'Unit price';

  @override
  String get clinicalRequestQuantityLabel => 'Qty';

  @override
  String get clinicalRequestEditPricesHint =>
      'Set or adjust prices per item, or charge a single amount.';

  @override
  String get ipdWardRoundFeeLabel => 'Doctor review fee';

  @override
  String get theaterCaseFeeLabel => 'Operation / procedure fee';

  @override
  String get clinicalProcedureFeeLabel => 'Procedure fee';

  @override
  String get clinicalRequestBillLaterAction => 'Bill later';

  @override
  String get clinicalRequestPayNowAction => 'Pay now';

  @override
  String get clinicalRequestPaymentPaidLabel => 'Paid';

  @override
  String get clinicalRequestPaymentPartialLabel => 'Partial';

  @override
  String get clinicalRequestPaymentUnpaidLabel => 'Unpaid';

  @override
  String get clinicalRequestPaymentNotBilledLabel => 'Not billed';

  @override
  String get radiologyOrderMetadataTitle => 'Order metadata';

  @override
  String get radiologyOrderMetadataSubtitle =>
      'Timing, modality, and payment context';

  @override
  String get radiologyViewModeImagingFloorLabel => 'Imaging floor';

  @override
  String get radiologyViewModeReportingLabel => 'Reporting';

  @override
  String get radiologyViewModeToggleLabel => 'View mode';

  @override
  String get radiologyViewModeImagingFloorHelper =>
      'Perform studies, acquire images, and sync to PACS.';

  @override
  String get radiologyViewModeReportingHelper =>
      'Draft, finalize, and release the radiology report.';

  @override
  String get radiologyWorkflowStepReceiveDescription =>
      'Acknowledge the incoming imaging request';

  @override
  String get radiologyWorkflowStepReviewDescription =>
      'Review study details and clinical notes.';

  @override
  String get radiologyWorkflowStepPerformDescription =>
      'Mark the imaging study as performed.';

  @override
  String get radiologyWorkflowStepUploadDescription =>
      'Upload images and sync assets';

  @override
  String get radiologyWorkflowStepReportDescription =>
      'Draft and edit the radiology report.';

  @override
  String get radiologyWorkflowStepReleaseDescription =>
      'Release the finalized report';

  @override
  String radiologyWorkflowProgressCollapsedSummary(int completed, int total) {
    return '$completed of $total steps complete';
  }

  @override
  String get radiologyStudiesPerformStudyCta => 'Perform study';

  @override
  String get radiologyStudiesUploadImagesCta => 'Upload images';

  @override
  String get radiologyStudiesPerformFirstHint =>
      'Perform the study before uploading images.';

  @override
  String get radiologyStudiesCapturePhotoCta => 'Capture photo';

  @override
  String get radiologyPacsSyncStatusSynced => 'PACS synced';

  @override
  String get radiologyPacsSyncStatusPending => 'PACS not synced';

  @override
  String radiologyStudyAssetCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count images',
      one: '1 image',
    );
    return '$_temp0';
  }

  @override
  String get radiologyStudiesReportPreviewTitle => 'Report preview';

  @override
  String get radiologyDoctorReviewOpenReportAction => 'Open report';

  @override
  String get radiologyDoctorReviewAcknowledgeAction => 'Acknowledge review';

  @override
  String get radiologyReportInlineEditHelper =>
      'Edit the draft below or open the full editor.';

  @override
  String get radiologyReportLivePreviewTitle => 'Live preview';

  @override
  String get radiologyStudyFormHelper =>
      'Optional details can be adjusted before saving.';

  @override
  String get radiologyReleaseReportSummaryTitle => 'Report summary';

  @override
  String get radiologyReleaseEmptyDraftMessage =>
      'Add report content before releasing.';

  @override
  String get radiologyPrescriptionBillOnDispenseLabel => 'Bill on dispense';

  @override
  String get radiologyPrescriptionPayAtPrescribeLabel => 'Pay at prescribe';

  @override
  String get accessAdminTitle => 'Users and access';

  @override
  String get accessAdminLoadingTitle => 'Loading access workspace';

  @override
  String get accessAdminLoadingBody =>
      'Loading users, roles, and permissions...';

  @override
  String get accessAdminSavingStatus => 'Saving access changes';

  @override
  String get accessAdminLiveStatus => 'Access workspace live';

  @override
  String get accessAdminPanelOverview => 'Overview';

  @override
  String get accessAdminPanelDirectory => 'User directory';

  @override
  String get accessAdminPanelRoles => 'Roles';

  @override
  String get accessAdminPanelPermissions => 'Permissions';

  @override
  String get accessAdminPanelEntitlements => 'Module entitlements';

  @override
  String get accessAdminPanelDemo => 'Demo accounts';

  @override
  String get accessAdminPanelRegistrations => 'Pending registrations';

  @override
  String get accessAdminPhoneLabel => 'Phone';

  @override
  String get accessAdminActivateRegistrationAction => 'Activate account';

  @override
  String get accessAdminRejectRegistrationAction => 'Reject';

  @override
  String get accessAdminActiveUsersLabel => 'Active users';

  @override
  String get accessAdminRolesLabel => 'Roles';

  @override
  String get accessAdminPermissionsLabel => 'Permissions';

  @override
  String get accessAdminModulesLabel => 'Active modules';

  @override
  String get accessAdminSearchLabel => 'Search access records';

  @override
  String get accessAdminSearchHint =>
      'Search by name, email, role, or permission';

  @override
  String get accessAdminStatusLabel => 'Status';

  @override
  String get accessAdminAllStatusesLabel => 'All statuses';

  @override
  String get accessAdminEmptyTitle => 'No access records found';

  @override
  String get accessAdminEmptyBody =>
      'Adjust filters or create users and roles.';

  @override
  String get accessAdminColumnId => 'ID';

  @override
  String get accessAdminColumnName => 'Name';

  @override
  String get accessAdminColumnDetails => 'Details';

  @override
  String get accessAdminColumnScope => 'Scope';

  @override
  String get accessAdminRoleScopeTenantBadge => 'Organization';

  @override
  String get accessAdminRoleScopeFacilityBadge => 'Facility';

  @override
  String get accessAdminRoleScopeFilterAll => 'All scopes';

  @override
  String get accessAdminRoleScopeFilterTenant => 'Organization';

  @override
  String get accessAdminRoleScopeFilterFacility => 'Facility';

  @override
  String get accessAdminFiltersAction => 'Filters';

  @override
  String get accessAdminFiltersTitle => 'Role filters';

  @override
  String get accessAdminUsersFiltersTitle => 'User filters';

  @override
  String get accessAdminAllFacilitiesFilterLabel => 'All facilities';

  @override
  String get accessAdminAllTenantsFilterLabel => 'All tenants';

  @override
  String get accessAdminAllRolesFilterLabel => 'All roles';

  @override
  String get accessAdminFilterRoleLabel => 'Role';

  @override
  String get accessAdminColumnFacility => 'Facility';

  @override
  String get accessAdminColumnRoles => 'Roles';

  @override
  String get accessAdminColumnActions => 'Actions';

  @override
  String get accessAdminColumnStatus => 'Status';

  @override
  String get accessAdminDetailTitle => 'Access record';

  @override
  String get accessAdminCreateUserAction => 'Create user';

  @override
  String get accessAdminEditUserAction => 'Edit user';

  @override
  String get accessAdminDeleteUserAction => 'Delete user';

  @override
  String get accessAdminViewUserAction => 'View';

  @override
  String get accessAdminCreateUserIntro =>
      'Create a staff account. Select tenant and facility, then profile and roles.';

  @override
  String get accessAdminCreateUserScopeSectionDescription =>
      'Select tenant and facility. Roles load from that org.';

  @override
  String get accessAdminCreateUserDetailsSectionTitle => 'User details';

  @override
  String get accessAdminCreateUserDetailsSectionDescription =>
      'Contact details, position, and account status.';

  @override
  String get accessAdminCreateUserRolesSectionDescription =>
      'Assign roles. Effective access includes role and direct grants.';

  @override
  String get accessAdminCreateUserPermissionsSectionDescription =>
      'Grant extra permissions beyond assigned roles.';

  @override
  String get accessAdminCreateUserLoadingFacilities => 'Loading facilities...';

  @override
  String get accessAdminCreateUserSelectScopeTitle =>
      'Select tenant and facility';

  @override
  String get accessAdminCreateUserSelectScopeMessage =>
      'Choose tenant and facility above to continue.';

  @override
  String get accessAdminCreateUserNoFacilitiesTitle =>
      'No facilities available';

  @override
  String get accessAdminCreateUserNoFacilitiesMessage =>
      'Create a facility for this tenant before adding users.';

  @override
  String get accessAdminCreateUserNoRolesTitle => 'No roles available';

  @override
  String get accessAdminCreateUserNoRolesMessage =>
      'Create roles for this organization before assigning them to users.';

  @override
  String get accessAdminPasswordOptionalLabel => 'New password (optional)';

  @override
  String get accessAdminPasswordOptionalHint =>
      'Leave blank to keep the current password.';

  @override
  String get accessAdminUserDetailProfileSectionTitle => 'Account';

  @override
  String get accessAdminUserDetailProfileSectionDescription =>
      'Identifiers and contact information.';

  @override
  String get accessAdminUserDetailRolesSectionDescription =>
      'Roles set the baseline permissions for this user.';

  @override
  String get accessAdminUserDetailPermissionsSectionDescription =>
      'Effective access from roles plus direct grants.';

  @override
  String get accessAdminUserDetailRolePermissionsLabel => 'From roles';

  @override
  String get accessAdminUserDetailNoRolesMessage =>
      'No roles are assigned to this user yet.';

  @override
  String get accessAdminUserDetailNoPermissionsMessage =>
      'No permissions are currently effective for this user.';

  @override
  String get accessAdminUserAccessAddRoleAction => 'Add role';

  @override
  String get accessAdminUserAccessRemoveRoleAction => 'Remove role';

  @override
  String get accessAdminUserAccessRemoveRoleConfirmTitle => 'Remove role?';

  @override
  String accessAdminUserAccessRemoveRoleConfirmMessage(String roleName) {
    return 'Removing $roleName also removes its permissions. Direct grants stay.';
  }

  @override
  String get accessAdminUserAccessAddRoleDialogTitle => 'Assign role';

  @override
  String get accessAdminUserAccessAddRoleDialogDescription =>
      'Select roles. Expand to review granted permissions.';

  @override
  String get accessAdminUserAccessNoAssignableRolesMessage =>
      'No additional roles are available to assign.';

  @override
  String get accessAdminUserAccessRolePermissionsHint =>
      'Role permissions cannot be removed individually. Remove the role to revoke.';

  @override
  String get accessAdminUserAccessDirectPermissionsDescription =>
      'Direct permissions can be removed one at a time.';

  @override
  String get accessAdminUserAccessAddDirectPermissionAction => 'Add permission';

  @override
  String get accessAdminUserAccessRemoveDirectPermissionAction =>
      'Remove permission';

  @override
  String get accessAdminUserAccessAddDirectPermissionDialogTitle =>
      'Add direct permission';

  @override
  String get accessAdminUserAccessAddDirectPermissionDialogDescription =>
      'Prefer roles; use direct grants for one-off exceptions.';

  @override
  String get accessAdminUserAccessNoDirectPermissionsMessage =>
      'No direct permissions. Prefer assigning a role.';

  @override
  String accessAdminUserAccessPermissionCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count permissions',
      one: '1 permission',
      zero: 'No permissions',
    );
    return '$_temp0';
  }

  @override
  String get accessAdminUserDetailDemoAccountTitle => 'Demo account';

  @override
  String get accessAdminUserDetailDemoAccountMessage =>
      'This is a demo account. Some destructive actions may be restricted.';

  @override
  String get accessAdminUserDetailSystemAccountTitle => 'Protected account';

  @override
  String get accessAdminUserDetailSystemAccountMessage =>
      'This account is system-critical and cannot be deleted.';

  @override
  String get accessAdminCreateRoleAction => 'Create role';

  @override
  String get accessAdminCreateRoleIntro =>
      'Define a role, then choose the permissions it grants.';

  @override
  String get accessAdminCreateRoleScopeSectionTitle => 'Organization';

  @override
  String get accessAdminCreateRoleScopeSectionDescription =>
      'Choose where this role applies.';

  @override
  String get accessAdminCreateRoleDetailsSectionTitle => 'Role details';

  @override
  String get accessAdminCreateRoleDetailsSectionDescription =>
      'Short name and optional description.';

  @override
  String get accessAdminCreateRolePermissionsSectionDescription =>
      'Select the permissions this role grants.';

  @override
  String get accessAdminCreateRoleLoadingPermissions =>
      'Loading permissions...';

  @override
  String get accessAdminCreateRoleLoadingTenants => 'Loading tenants...';

  @override
  String get accessAdminCreateRoleLoadingFacilities => 'Loading facilities...';

  @override
  String get accessAdminRoleScopeLabel => 'Scope';

  @override
  String get accessAdminRoleScopeTenantLabel => 'Entire organization';

  @override
  String get accessAdminRoleScopeFacilityLabel => 'One facility';

  @override
  String get accessAdminRoleFacilityRequiredTitle => 'Facility required';

  @override
  String get accessAdminRoleFacilityRequiredMessage =>
      'Select a facility for this role, or retry loading facilities.';

  @override
  String get accessAdminRoleSelectFacilityMessage =>
      'Select a facility to load assignable permissions.';

  @override
  String get accessAdminEditRoleAction => 'Edit role';

  @override
  String get accessAdminRolePermissionsLabel => 'Permissions';

  @override
  String get accessAdminRoleDetailPermissionsDescription =>
      'Permissions granted by this role.';

  @override
  String get accessAdminRoleDetailNoPermissionsMessage =>
      'This role has no permissions assigned yet.';

  @override
  String get accessAdminRoleDetailUsersLabel => 'Assigned users';

  @override
  String get accessAdminRolePermissionsRequired =>
      'Select at least one permission for this role.';

  @override
  String get accessAdminPermissionCatalogUnavailableTitle =>
      'Permission catalog unavailable';

  @override
  String get accessAdminPermissionCatalogUnavailableMessage =>
      'Permissions could not load. Contact an admin or refresh.';

  @override
  String get accessAdminPermissionCatalogSelectTenantTitle => 'Select a tenant';

  @override
  String get accessAdminPermissionCatalogSelectTenantMessage =>
      'Choose a tenant above to load the available permissions for that organization.';

  @override
  String get accessAdminEmailLabel => 'Email';

  @override
  String get accessAdminPositionLabel => 'Position title';

  @override
  String get accessAdminPasswordLabel => 'Password';

  @override
  String get accessAdminPasswordHint =>
      'Password must be at least 8 characters.';

  @override
  String get accessAdminRoleNameLabel => 'Role name';

  @override
  String get accessAdminRoleDisplayNameLabel => 'Display name';

  @override
  String get accessAdminRoleDescriptionLabel => 'Description';

  @override
  String get accessAdminAssignedRolesLabel => 'Assigned roles';

  @override
  String get accessAdminEffectivePermissionsLabel => 'Effective permissions';

  @override
  String get accessAdminOpenHrProfileAction => 'Open HR profile';

  @override
  String get accessAdminClinicalRoleHint =>
      'This role unlocks OPD/IPD clinical workflow actions.';

  @override
  String get accessAdminDeactivateAction => 'Deactivate user';

  @override
  String get accessAdminActivateAction => 'Activate user';

  @override
  String get accessAdminResetDemoPasswordAction => 'Reset demo password';

  @override
  String get accessAdminDeleteRoleAction => 'Delete role';

  @override
  String accessAdminDeleteRoleBody(String name) {
    return 'Delete role \"$name\"? Related permissions on this role will also be removed.';
  }

  @override
  String accessAdminDeleteRoleAssignedBody(String name, int userCount) {
    String _temp0 = intl.Intl.pluralLogic(
      userCount,
      locale: localeName,
      other: '$userCount users',
      one: '1 user',
    );
    String _temp1 = intl.Intl.pluralLogic(
      userCount,
      locale: localeName,
      other: 'those users',
      one: 'that user',
    );
    return 'Role \"$name\" is assigned to $_temp0. Deleting removes it from $_temp1.';
  }

  @override
  String get accessAdminTenantContextRequiredTitle => 'Tenant context required';

  @override
  String get accessAdminTenantContextRequiredBody =>
      'Select a tenant and facility before managing users and roles.';

  @override
  String get settingsAccessAdminActionTitle => 'Users and access';

  @override
  String get settingsAccessAdminActionBody =>
      'Manage staff accounts, role assignments, permissions, and demo users.';

  @override
  String get hrReferenceStaffPositionNurse => 'Nurse';

  @override
  String get hrReferenceStaffPositionSeniorNurse => 'Senior Nurse';

  @override
  String get hrReferenceStaffPositionStaffNurse => 'Staff Nurse';

  @override
  String get hrReferenceStaffPositionTheatreNurse => 'Theatre Nurse';

  @override
  String get hrReferenceStaffPositionScrubNurse => 'Scrub Nurse';

  @override
  String get hrReferenceStaffPositionWardManager => 'Ward Manager';

  @override
  String get hrReferenceStaffPositionMidwife => 'Midwife';

  @override
  String get hrReferenceStaffPositionNursingAssistant => 'Nursing Assistant';

  @override
  String get hrReferenceStaffPositionDoctor => 'Doctor';

  @override
  String get hrReferenceStaffPositionConsultantPhysician =>
      'Consultant Physician';

  @override
  String get hrReferenceStaffPositionMedicalOfficer => 'Medical Officer';

  @override
  String get hrReferenceStaffPositionResidentDoctor => 'Resident Doctor';

  @override
  String get hrReferenceStaffPositionIntern => 'Intern';

  @override
  String get hrReferenceStaffPositionGeneralPractitioner =>
      'General Practitioner';

  @override
  String get hrReferenceStaffPositionSurgeon => 'Surgeon';

  @override
  String get hrReferenceStaffPositionAnaesthetist => 'Anaesthetist';

  @override
  String get hrReferenceStaffPositionPaediatrician => 'Paediatrician';

  @override
  String get hrReferenceStaffPositionObgyn => 'Obstetrician/Gynaecologist';

  @override
  String get hrReferenceStaffPositionPsychiatrist => 'Psychiatrist';

  @override
  String get hrReferenceStaffPositionEmergencyPhysician =>
      'Emergency Physician';

  @override
  String get hrReferenceStaffPositionFamilyMedicinePhysician =>
      'Family Medicine Physician';

  @override
  String get hrReferenceStaffPositionDentalSurgeon => 'Dental Surgeon';

  @override
  String get hrReferenceStaffPositionNursePractitioner => 'Nurse Practitioner';

  @override
  String get hrReferenceStaffPositionPhysiotherapist => 'Physiotherapist';

  @override
  String get hrReferenceStaffPositionOccupationalTherapist =>
      'Occupational Therapist';

  @override
  String get hrReferenceStaffPositionSpeechTherapist => 'Speech Therapist';

  @override
  String get hrReferenceStaffPositionDietitian => 'Dietitian';

  @override
  String get hrReferenceStaffPositionClinicalPsychologist =>
      'Clinical Psychologist';

  @override
  String get hrReferenceStaffPositionSocialWorker => 'Social Worker';

  @override
  String get hrReferenceStaffPositionRespiratoryTherapist =>
      'Respiratory Therapist';

  @override
  String get hrReferenceStaffPositionLabTechnologist => 'Lab Technologist';

  @override
  String get hrReferenceStaffPositionMedicalLaboratoryScientist =>
      'Medical Laboratory Scientist';

  @override
  String get hrReferenceStaffPositionPhlebotomist => 'Phlebotomist';

  @override
  String get hrReferenceStaffPositionRadiologist => 'Radiologist';

  @override
  String get hrReferenceStaffPositionSonographer => 'Sonographer';

  @override
  String get hrReferenceStaffPositionEcgTechnician => 'ECG Technician';

  @override
  String get hrReferenceStaffPositionPharmacist => 'Pharmacist';

  @override
  String get hrReferenceStaffPositionPharmacyTechnician =>
      'Pharmacy Technician';

  @override
  String get hrReferenceStaffPositionPharmacyAssistant => 'Pharmacy Assistant';

  @override
  String get hrReferenceStaffPositionAdministrator => 'Administrator';

  @override
  String get hrReferenceStaffPositionHrOfficer => 'HR Officer';

  @override
  String get hrReferenceStaffPositionReceptionist => 'Receptionist';

  @override
  String get hrReferenceStaffPositionMedicalRecordsOfficer =>
      'Medical Records Officer';

  @override
  String get hrReferenceStaffPositionHealthInformationOfficer =>
      'Health Information Officer';

  @override
  String get hrReferenceStaffPositionPatientRelationsOfficer =>
      'Patient Relations Officer';

  @override
  String get hrReferenceStaffPositionBillingClerk => 'Billing Clerk';

  @override
  String get hrReferenceStaffPositionAccountsOfficer => 'Accounts Officer';

  @override
  String get hrReferenceStaffPositionInsuranceOfficer => 'Insurance Officer';

  @override
  String get hrReferenceStaffPositionCashier => 'Cashier';

  @override
  String get hrReferenceStaffPositionHousekeeper => 'Housekeeper';

  @override
  String get hrReferenceStaffPositionPorter => 'Porter';

  @override
  String get hrReferenceStaffPositionSecurityOfficer => 'Security Officer';

  @override
  String get hrReferenceStaffPositionLaundryAttendant => 'Laundry Attendant';

  @override
  String get hrReferenceStaffPositionKitchenStaff => 'Kitchen Staff';

  @override
  String get hrReferenceStaffPositionMortuaryAttendant => 'Mortuary Attendant';

  @override
  String get hrReferenceStaffPositionAmbulanceDriver => 'Ambulance Driver';

  @override
  String get hrReferenceStaffPositionAmbulanceOperator => 'Ambulance Operator';

  @override
  String get hrReferenceStaffPositionBiomedicalEngineer =>
      'Biomedical Engineer';

  @override
  String get hrReferenceStaffPositionItSupportOfficer => 'IT Support Officer';

  @override
  String get hrReferenceStaffPositionMaintenanceTechnician =>
      'Maintenance Technician';

  @override
  String get hrReferenceStaffPositionHospitalAdministrator =>
      'Hospital Administrator';

  @override
  String get hrReferenceStaffPositionDepartmentHead => 'Department Head';

  @override
  String get hrReferenceStaffPositionChiefNursingOfficer =>
      'Chief Nursing Officer';

  @override
  String get hrReferenceStaffPositionOperationsManager => 'Operations Manager';

  @override
  String get hrReferenceStaffPositionFacilityManager => 'Facility Manager';

  @override
  String get hrReferenceRoleTenantAdmin => 'Organization Administrator';

  @override
  String get hrReferenceRoleFacilityAdmin => 'Facility Administrator';

  @override
  String get hrReferenceRoleHr => 'HR / Workforce Manager';

  @override
  String get hrReferenceRoleOperations => 'Operations Manager';

  @override
  String get hrReferenceRoleItSupport => 'IT Support Specialist';

  @override
  String get hrReferenceRoleDoctor => 'Doctor / Clinician';

  @override
  String get hrReferenceRoleAttendingPhysician => 'Attending Physician';

  @override
  String get hrReferenceRoleResidentPhysician => 'Resident Physician';

  @override
  String get hrReferenceRoleSurgeon => 'Surgeon';

  @override
  String get hrReferenceRoleAnesthesiologist => 'Anesthesiologist';

  @override
  String get hrReferenceRolePhysicianAssistant => 'Physician Assistant (PA)';

  @override
  String get hrReferenceRoleEmergencyPhysician =>
      'Emergency Medicine Physician';

  @override
  String get hrReferenceRoleNurse => 'Registered Nurse (RN)';

  @override
  String get hrReferenceRoleLicensedPracticalNurse =>
      'Licensed Practical Nurse (LPN)';

  @override
  String get hrReferenceRoleNursePractitioner => 'Nurse Practitioner (NP)';

  @override
  String get hrReferenceRoleTriageNurse => 'Triage Nurse';

  @override
  String get hrReferenceRoleMidwife => 'Midwife';

  @override
  String get hrReferenceRoleChargeNurse => 'Charge Nurse';

  @override
  String get hrReferenceRolePhysiotherapist =>
      'Physiotherapist / Physical Therapist';

  @override
  String get hrReferenceRoleOccupationalTherapist => 'Occupational Therapist';

  @override
  String get hrReferenceRoleRespiratoryTherapist => 'Respiratory Therapist';

  @override
  String get hrReferenceRoleDietitian => 'Dietitian / Nutritionist';

  @override
  String get hrReferenceRoleSocialWorker => 'Medical Social Worker';

  @override
  String get hrReferenceRoleClinicalPsychologist => 'Clinical Psychologist';

  @override
  String get hrReferenceRoleLabTech => 'Laboratory Technologist';

  @override
  String get hrReferenceRoleMedicalLaboratoryScientist =>
      'Medical Laboratory Scientist';

  @override
  String get hrReferenceRolePathologist => 'Pathologist';

  @override
  String get hrReferenceRoleRadiologyTech => 'Radiology / Imaging Technologist';

  @override
  String get hrReferenceRoleSonographer =>
      'Sonographer / Ultrasound Technologist';

  @override
  String get hrReferenceRolePharmacist => 'Pharmacist';

  @override
  String get hrReferenceRolePharmacyTechnician => 'Pharmacy Technician';

  @override
  String get hrReferenceRoleReceptionist => 'Receptionist / Front Desk';

  @override
  String get hrReferenceRoleAdmissionsCoordinator => 'Admissions Coordinator';

  @override
  String get hrReferenceRoleMedicalRecordsClerk => 'Medical Records Clerk';

  @override
  String get hrReferenceRoleBilling => 'Billing / Cashier';

  @override
  String get hrReferenceRoleMedicalCoder => 'Medical Coder / Coding Specialist';

  @override
  String get hrReferenceRoleAmbulanceOperator => 'Ambulance Operator';

  @override
  String get hrReferenceRoleParamedic => 'Paramedic';

  @override
  String get hrReferenceRoleEmt => 'Emergency Medical Technician (EMT)';

  @override
  String get hrReferenceRoleHouseKeeper => 'Housekeeping Staff';

  @override
  String get hrReferenceRoleHousekeepingManager => 'Housekeeping Manager';

  @override
  String get hrReferenceRoleFoodServiceWorker => 'Food Service Worker';

  @override
  String get hrReferenceRolePorter => 'Porter / Orderly';

  @override
  String get hrReferenceRoleSecurityOfficer => 'Security Officer';

  @override
  String get hrReferenceRoleMaintenanceEngineer => 'Maintenance Engineer';

  @override
  String get hrReferenceRoleChaplain => 'Hospital Chaplain';

  @override
  String get hrReferenceRoleBiomed => 'Biomedical Engineer / Technician';

  @override
  String get hrReferenceRoleBiomedManager => 'Biomedical Manager';

  @override
  String get hrReferenceRoleUnitManager => 'Unit Manager';

  @override
  String get hrReferenceRoleWardManager => 'Ward Manager / Charge Nurse';

  @override
  String get hrReferenceRoleIcuManager => 'ICU Manager';

  @override
  String get hrReferenceRoleTheatreManager => 'Theatre / Perioperative Manager';

  @override
  String get hrReferenceRoleMortuaryStaff => 'Mortuary Attendant';

  @override
  String get hrReferenceRoleMortuaryManager => 'Mortuary Manager';

  @override
  String get hrReferencePractitionerTypeMo => 'Medical Officer (MO)';

  @override
  String get hrReferencePractitionerTypeSpecialist => 'Specialist / Consultant';

  @override
  String get hrReferencePractitionerTypeResident => 'Resident / Registrar';

  @override
  String get hrReferencePractitionerTypeIntern => 'Intern / House Officer';

  @override
  String get hrReferencePractitionerTypeGp => 'General Practitioner (GP)';

  @override
  String get hrReferencePractitionerTypeSurgeon => 'Surgeon';

  @override
  String get hrReferencePractitionerTypeAnaesthetist => 'Anaesthetist';

  @override
  String get hrReferencePractitionerTypePaediatrician => 'Paediatrician';

  @override
  String get hrReferencePractitionerTypeObgyn => 'Obstetrician/Gynaecologist';

  @override
  String get hrReferencePractitionerTypeNursePractitioner =>
      'Nurse Practitioner';

  @override
  String get hrReferencePractitionerTypeDentist => 'Dentist';

  @override
  String get hrReferencePractitionerTypePsychiatrist => 'Psychiatrist';

  @override
  String get hrReferencePractitionerTypeEmergencyMedicine =>
      'Emergency Medicine Physician';

  @override
  String get hrReferencePractitionerTypeFamilyMedicine =>
      'Family Medicine Physician';

  @override
  String get hrReferencePractitionerTypePathologist => 'Pathologist';

  @override
  String get hrReferencePractitionerTypeRadiologist => 'Radiologist';

  @override
  String get hrReferencePractitionerTypeDermatologist => 'Dermatologist';

  @override
  String get hrReferencePractitionerTypeCardiologist => 'Cardiologist';

  @override
  String get hrReferencePractitionerTypeOphthalmologist => 'Ophthalmologist';

  @override
  String get hrReferencePractitionerTypeOrthopaedicSurgeon =>
      'Orthopaedic Surgeon';

  @override
  String get hrReferenceCompensationPayTypePerConsultation =>
      'Consultation fee';

  @override
  String get hrReferenceCompensationPayTypePerMonth => 'Monthly salary';

  @override
  String get hrReferenceCompensationPayTypePerDay => 'Daily wage';

  @override
  String get hrReferenceCompensationPayTypePerHour => 'Hourly rate';

  @override
  String get hrReferenceCompensationPayTypePerProcedure =>
      'Per procedure / per task';

  @override
  String get hrReferenceLeaveTypeAnnual => 'Annual leave';

  @override
  String get hrReferenceLeaveTypeSick => 'Sick leave';

  @override
  String get hrReferenceLeaveTypeMaternity => 'Maternity leave';

  @override
  String get hrReferenceLeaveTypePaternity => 'Paternity leave';

  @override
  String get hrReferenceLeaveTypeCompassionate =>
      'Compassionate / bereavement leave';

  @override
  String get hrReferenceLeaveTypeUnpaid => 'Unpaid leave';

  @override
  String get hrReferenceLeaveTypeStudy => 'Study / training leave';

  @override
  String get hrReferenceLeaveTypeEmergency => 'Emergency leave';

  @override
  String get hrReferenceLeaveTypeOther => 'Other leave';

  @override
  String get hrReferenceLeaveHalfDayPeriodMorning => 'Morning';

  @override
  String get hrReferenceLeaveHalfDayPeriodAfternoon => 'Afternoon';
}
