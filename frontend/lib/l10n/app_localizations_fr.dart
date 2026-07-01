// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'HOSSPI Système de gestion hospitalière';

  @override
  String get appShortTitle => 'HOSSPI HMS';

  @override
  String get startupLoadingTitle => 'Starting app';

  @override
  String get startupLoadingBody => 'Preparing local services.';

  @override
  String get startupErrorTitle => 'Le app n\'un pas pu start';

  @override
  String get startupErrorBody => 'Restart le app ou réessayer.';

  @override
  String get commonRetryActionLabel => 'Réessayer';

  @override
  String get commonRefreshActionLabel => 'Actualiser';

  @override
  String get workspaceToolbarOverflowLabel => 'More actions';

  @override
  String get workspaceNotificationsMenuLabel => 'Notifications';

  @override
  String workspaceToolbarOverflowAttentionTooltip(int count) {
    return 'More actions — $count éléments need attention';
  }

  @override
  String get workspaceToolbarSectionStaffAccess => 'Staff & accès';

  @override
  String get workspaceToolbarSectionScheduling => 'Scheduling & roster';

  @override
  String get workspaceToolbarSectionApprovals => 'Approvals & alerts';

  @override
  String get workspaceToolbarSectionActivity => 'Activity & audit';

  @override
  String get workspaceToolbarSectionWorkspace => 'Workspace';

  @override
  String get workspaceToolbarSectionFacilities => 'Facilities';

  @override
  String get workspaceNotificationsToolbarTooltip =>
      'Jump directly à queues cette need votre attention.';

  @override
  String get workspaceFullscreenEnterLabel => 'Full screen';

  @override
  String get workspaceFullscreenExitLabel => 'Exit full screen';

  @override
  String get workspaceGlobalFaultReportAction => 'Report équipement fault';

  @override
  String get workspaceGlobalHousekeepingRequestAction => 'Request maintenance';

  @override
  String get commonTableSettingsActionLabel => 'Table paramètres';

  @override
  String get emergencyCaseDialogTitle => 'Emergency case';

  @override
  String get icuStayDialogTitle => 'ICU stay';

  @override
  String get icuLoadingBoardTitle => 'Loading ICU board';

  @override
  String get icuLoadingBoardBody =>
      'Loading intensive soins patients et alert state.';

  @override
  String get icuLiveSyncLabel => 'Live synchronisation';

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
  String get icuTransferPendingLabel => 'Transfer en attente';

  @override
  String get icuBoardTitle => 'ICU board';

  @override
  String get icuBoardDescription => 'Grouped by lit state et alert level.';

  @override
  String get icuSearchHint => 'Search patient, admission, lit, ou alert';

  @override
  String get icuBoardScopeLabel => 'Board scope';

  @override
  String get icuBoardFiltersTitle => 'ICU board filtres';

  @override
  String get icuColumnBedLabel => 'Lit';

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
      'Active ICU admissions will appear here après IPD admission et ICU transfert.';

  @override
  String get icuNoAlertLabel => 'No alert';

  @override
  String get icuDetailEmptyTitle => 'No ICU stay selected';

  @override
  String get icuDetailEmptyBody =>
      'Select un ICU patient à review observations, commandes, alerts, et transfert readiness.';

  @override
  String get icuDetailLoadingTitle => 'Loading ICU stay';

  @override
  String get icuDetailLoadingBody =>
      'Loading observations, alerts, et transfert state.';

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
  String get icuNoActiveAlertsLabel => 'No actif ICU critique alerts.';

  @override
  String icuHighestSeverityLabel(String severity) {
    return 'Highest severity: $severity';
  }

  @override
  String get icuNoActiveAlertsListLabel => 'No actif alerts';

  @override
  String get icuObservationsPanelTitle => 'Observations';

  @override
  String get icuObservationsPanelDescription =>
      'Recent intensive observations pour ce ICU stay.';

  @override
  String get icuNoObservationsLabel => 'No ICU observations recorded';

  @override
  String get icuVitalsTrendTitle => 'Vitals trend';

  @override
  String get icuVitalsTrendDescription =>
      'Latest recorded vital valeurs pour le admission consultation.';

  @override
  String get icuNoVitalsLabel => 'No signes vitaux recorded';

  @override
  String get icuCarePanelTitle => 'Rounds, soins infirmiers, et commandes';

  @override
  String get icuCarePanelDescription =>
      'Recent soins notes et médicament tasks linked à IPD.';

  @override
  String get icuNoCareTasksLabel => 'No soins tasks recorded';

  @override
  String get icuTransferPanelTitle => 'Transfer et readiness';

  @override
  String get icuTransferPanelDescription =>
      'ICU stay movement, planned sortie, et passation state.';

  @override
  String get icuNoTransferRecordsLabel =>
      'No transfert ou sortie readiness dossiers';

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
  String get icuDischargeRecordLabel => 'Sortie';

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
  String get icuActionOrderLab => 'Order laboratoire';

  @override
  String get icuActionOrderImaging => 'Order imaging';

  @override
  String get icuActionPrescribe => 'Prescribe';

  @override
  String get icuActionRequestTransfer => 'Request transfert';

  @override
  String get icuActionManageTransfer => 'Manage transfert';

  @override
  String get icuActionAssignBed => 'Assign ICU lit';

  @override
  String get icuActionMarkReadiness => 'Discharge readiness';

  @override
  String get icuActionOpenIpd => 'Open in IPD';

  @override
  String get icuActionOpenDischargeClearance => 'Open sortie clearance';

  @override
  String get icuActionOpenBilling => 'Open billing';

  @override
  String get icuBillingDeferredLabel => 'Billing deferred';

  @override
  String get icuActionEndStay => 'End ICU stay';

  @override
  String get icuPrintSummaryLabel => 'Print résumé';

  @override
  String get icuObservationDialogTitle => 'Record ICU observation';

  @override
  String get icuObservationFieldLabel => 'Observation';

  @override
  String get icuRecordActionLabel => 'Record';

  @override
  String get icuVitalsDialogTitle => 'Update signes vitaux';

  @override
  String get icuVitalsUpdateActionLabel => 'Mettre à jour';

  @override
  String get icuAlertDialogTitle => 'Add critique alert';

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
  String get icuTransferDialogTitle => 'Request transfert';

  @override
  String get icuTransferTargetWardLabel => 'Target service';

  @override
  String get icuTransferTargetWardIdLabel => 'Target service ID';

  @override
  String get icuTransferRequestActionLabel => 'Request';

  @override
  String get icuReadinessDialogTitle => 'Mark sortie readiness';

  @override
  String get icuReadinessNoteLabel => 'Readiness note';

  @override
  String get icuReadinessDescription =>
      'Ce dossiers un planned sortie readiness note et keeps le patient in le IPD sortie workflow.';

  @override
  String get icuReadinessMarkActionLabel => 'Mark ready';

  @override
  String get icuStartStayTitle => 'Start ICU stay';

  @override
  String get icuStartStayBody =>
      'Ce opens un actif ICU stay on le IPD admission so critique-soins documentation can begin.';

  @override
  String get icuStartStayActionLabel => 'Start stay';

  @override
  String get icuAcknowledgeTitle => 'Acknowledge alert';

  @override
  String get icuAcknowledgeBody =>
      'Ce clears le selected critique alert de le actif ICU board.';

  @override
  String get icuEndStayTitle => 'End ICU stay';

  @override
  String get icuEndStayBody =>
      'Ce ends le actif ICU stay. Continue only après le receiving service ou sortie workflow is ready.';

  @override
  String get icuAssignBedDialogTitle => 'Assign ICU lit';

  @override
  String get icuManageTransferDialogTitle => 'Manage transfert';

  @override
  String get icuTransferActionApprove => 'Approve';

  @override
  String get icuTransferActionStart => 'Start';

  @override
  String get icuTransferActionComplete => 'Complete avec lit';

  @override
  String get icuTransferActionCancel => 'Cancel transfert';

  @override
  String get icuTransferSelectBedLabel => 'Target lit';

  @override
  String get icuTransferNoOpenLabel => 'No ouvrir transfert à manage.';

  @override
  String get icuStepDownPromptTitle => 'End ICU stay?';

  @override
  String get icuStepDownPromptBody =>
      'Le transfert is complete. End le actif ICU stay now cette le patient has stepped down à service soins.';

  @override
  String get icuChangesSavedMessage => 'ICU changes saved.';

  @override
  String get icuBedBoardTitle => 'ICU lit board';

  @override
  String get icuBedBoardDescription =>
      'ICU service lit occupation et lit operations.';

  @override
  String get icuBedBoardAllWards => 'All ICU services';

  @override
  String icuBedAvailableLabel(int count) {
    return '$count disponible';
  }

  @override
  String icuBedOccupiedLabel(int count) {
    return '$count occupé';
  }

  @override
  String get icuBedColumnWard => 'Service';

  @override
  String get icuBedColumnBed => 'Room / lit';

  @override
  String get icuBedColumnStatus => 'Statut';

  @override
  String get icuBedColumnPatient => 'Patient';

  @override
  String get icuBedNoBedsTitle => 'No ICU lits';

  @override
  String get icuBedNoBedsBody =>
      'No ICU lits are configured pour ce établissement.';

  @override
  String get icuBedVacantLabel => 'Vacant';

  @override
  String get icuPrintAlertsSection => 'Alerts';

  @override
  String get icuPrintObservationsSection => 'Observations';

  @override
  String get icuPrintVitalsSection => 'Vitals';

  @override
  String get icuPrintTransferSection => 'Transfer et readiness';

  @override
  String get ipdOpenIcuAction => 'Open in ICU';

  @override
  String get ipdOpenTheaterAction => 'Open in Theater';

  @override
  String get ipdStatusInProcedureOt => 'In procédure / OT';

  @override
  String get ipdNextCompleteTheatreHandover => 'Complete theatre handover';

  @override
  String get ipdTheatreHandoverTitle => 'Theatre post-op handover';

  @override
  String get ipdStartIcuStayAction => 'Start ICU stay';

  @override
  String get ipdStartIcuStayBody =>
      'Ce opens un actif ICU stay on ce admission so le ICU team can begin critique-soins documentation.';

  @override
  String get commonGoHomeActionLabel => 'Go à tableau de bord';

  @override
  String get commonCancelActionLabel => 'Annuler';

  @override
  String get commonCloseActionLabel => 'Fermer';

  @override
  String get appDateInvalidMessage => 'Enter un valid date.';

  @override
  String get appDateFormatHint => 'DD/MM/YYYY';

  @override
  String get appTimePickerAction => 'Select heure';

  @override
  String get appTimeInvalidMessage => 'Enter un valid heure.';

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
  String get appPhoneCountryNoResults => 'Aucun countries trouvé';

  @override
  String get appPhoneNumberLabel => 'Phone number';

  @override
  String get appPhoneNumberHint => 'Remaining number digits';

  @override
  String get appPhoneInvalidMessage => 'Enter un valid téléphone number.';

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
  String get appNavigationSearchNoResultsLabel => 'Aucun menu items trouvé';

  @override
  String get appAccountTooltip => 'Compte';

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
  String get appUserMenuProfileLabel => 'Profil';

  @override
  String get appUserMenuSettingsLabel => 'Paramètres';

  @override
  String get appUserMenuChangePasswordLabel => 'Change mot de passe';

  @override
  String get appUserMenuLogoutLabel => 'Déconnexion';

  @override
  String get appUserMenuSignedInLabel => 'Signed in';

  @override
  String get navigationHomeLabel => 'Tableau de bord';

  @override
  String get navigationHomeShortLabel => 'Tableau de bord';

  @override
  String get navigationSettingsLabel => 'Paramètres';

  @override
  String get navigationSettingsShortLabel => 'Paramètres';

  @override
  String get navigationSetupLabel => 'Tenant setup';

  @override
  String get navigationSetupShortLabel => 'Setup';

  @override
  String get navigationPatientsLabel => 'Patient registry';

  @override
  String get navigationPatientsShortLabel => 'Patients';

  @override
  String get navigationBillingLabel => 'Facturation';

  @override
  String get navigationBillingShortLabel => 'Facturation';

  @override
  String get billingWorkspaceTitle => 'Facturation';

  @override
  String get billingLoadingTitle => 'Loading billing espace de travail';

  @override
  String get billingLoadingBody =>
      'Fetching factures, paiements, refunds, et closeout queues.';

  @override
  String get billingStatusLive => 'Live';

  @override
  String get billingStatusPosting => 'Posting';

  @override
  String get billingWorklistDescription =>
      'Cashier worklist pour factures, paiements, réclamations, et approvals.';

  @override
  String get billingAllWorkItems => 'All billing work éléments';

  @override
  String get billingAwaitingPayment => 'Awaiting paiement';

  @override
  String get billingIssueQueue => 'Issue queue';

  @override
  String get billingClaimsPending => 'Claims en attente';

  @override
  String get billingApprovals => 'Approvals';

  @override
  String get billingOverdue => 'Overdue';

  @override
  String get billingNeedsIssue => 'Needs issue';

  @override
  String get billingApprovalRequired => 'Approval requis';

  @override
  String get billingQueueLabel => 'Queue';

  @override
  String get billingSearchHint => 'Invoice, patient, ou référence';

  @override
  String get billingSearchSemanticLabel => 'Search billing worklist';

  @override
  String get billingClearSearch => 'Clear billing recherche';

  @override
  String get billingFiltersTitle => 'Billing filtres';

  @override
  String get billingEmptyTitle => 'No billing éléments';

  @override
  String get billingEmptyBody =>
      'Ce queue has non factures ou billing actions right now.';

  @override
  String get billingPatientColumn => 'Patient';

  @override
  String get billingStatusColumn => 'Statut';

  @override
  String get billingAmountColumn => 'Amount';

  @override
  String get billingPaidColumn => 'Paid';

  @override
  String get billingBalanceColumn => 'Balance';

  @override
  String get billingUpdatedColumn => 'Updated';

  @override
  String get billingInvoiceLabel => 'Invoice';

  @override
  String get billingReceivePayment => 'Receive paiement';

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
  String get billingCloseShift => 'Close quart';

  @override
  String get billingCloseDay => 'Close day';

  @override
  String get billingIssueInvoice => 'Issue facture';

  @override
  String get billingSendInvoice => 'Send facture';

  @override
  String get billingVoidInvoice => 'Void facture';

  @override
  String get billingRequestAdjustment => 'Request adjustment';

  @override
  String get billingRequestRefund => 'Request refund';

  @override
  String get billingDueLabel => 'Due';

  @override
  String get billingNoLineItems => 'No line éléments returned pour ce facture.';

  @override
  String get billingNoPayments => 'No paiements recorded pour ce facture.';

  @override
  String get billingNoAdjustments => 'No billing adjustments recorded.';

  @override
  String get billingLineItemsTitle => 'Line éléments';

  @override
  String get billingPaymentsTitle => 'Payments';

  @override
  String get billingAdjustmentsTitle => 'Adjustments';

  @override
  String get billingFinancialSummaryTitle => 'Financial résumé';

  @override
  String get billingInvoiceDetailTitle => 'Invoice detail';

  @override
  String get billingItemDetailTitle => 'Billing élément';

  @override
  String get billingClaimDetailTitle => 'Insurance réclamation';

  @override
  String get billingApprovalDetailTitle => 'Approval demande';

  @override
  String get billingPreAuthDetailTitle => 'Pre-authorization';

  @override
  String get billingActionSaved => 'Billing action saved.';

  @override
  String get billingActionPendingApproval =>
      'Submitted. Pending approbation avant it takes effect.';

  @override
  String get billingDocumentDownloaded => 'Invoice document saved.';

  @override
  String get billingDocumentUnavailable =>
      'Invoice document n\'a pas pu être saved on this device.';

  @override
  String get billingDocumentTooltip => 'Download facture PDF';

  @override
  String get billingViewLedgerAction => 'View ledger';

  @override
  String get billingLedgerTitle => 'Patient ledger';

  @override
  String get billingLedgerEmpty =>
      'No ledger entries pour ce patient in le selected period.';

  @override
  String get billingApproveAction => 'Approve';

  @override
  String get billingRejectAction => 'Reject';

  @override
  String get billingSubmitClaimAction => 'Submit réclamation';

  @override
  String get billingReconcileClaimAction => 'Record insurer réponse';

  @override
  String get billingFinalizeEncounterAction => 'Finalize financial clearance';

  @override
  String get billingFinalizeEncounterBody =>
      'All linked charges are issued et settled. Confirm financial clearance pour ce consultation.';

  @override
  String get billingEncounterLabel => 'Encounter';

  @override
  String get billingCoveragePlanLabel => 'Coverage forfait';

  @override
  String get billingRequestTypeLabel => 'Request type';

  @override
  String get billingRequesterLabel => 'Requested by';

  @override
  String get billingReasonLabel => 'Reason';

  @override
  String get billingLinkedInvoiceLabel => 'Linked facture';

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
  String get billingUnknownValue => 'Inconnu';

  @override
  String get billingPreviousPageLabel => 'Previous page';

  @override
  String get billingNextPageLabel => 'Next page';

  @override
  String get billingClearFilters => 'Effacer';

  @override
  String get billingPaymentReferenceHint =>
      'Mobile money, card, ou bank référence';

  @override
  String get billingPayerHint => 'Patient, sponsor, insurer, ou contact';

  @override
  String get billingPdfFileTypeLabel => 'PDF document';

  @override
  String get billingClaimStatusApproved => 'Approuvé';

  @override
  String get billingClaimStatusRejected => 'Rejeté';

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
  String get billingGenerateReceiptLabel => 'Generate receipt après paiement';

  @override
  String get billingPaymentLabel => 'Payment';

  @override
  String get billingRefundAmountLabel => 'Refund montant';

  @override
  String get billingRefundReasonValidation => 'Enter un refund reason.';

  @override
  String get billingNotesLabel => 'Notes';

  @override
  String get billingAdjustmentAmountLabel => 'Adjustment montant (+/-)';

  @override
  String get billingAdjustmentAmountValidation =>
      'Enter un signed montant, pour example -10.00 ou 25.00.';

  @override
  String get billingAppliedStatusLabel => 'Applied statut';

  @override
  String get billingAdjustmentReasonValidation => 'Enter un adjustment reason.';

  @override
  String get billingReasonValidation => 'Enter un reason.';

  @override
  String get billingRecipientEmailLabel => 'Recipient e-mail';

  @override
  String get billingExpectedAmountLabel => 'Expected montant';

  @override
  String get billingActualAmountLabel => 'Actual montant';

  @override
  String get billingSubmitForApprovalLabel => 'Submit pour approbation';

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
  String get navigationSubscriptionsLabel => 'Subscription forfaits';

  @override
  String get navigationSubscriptionsShortLabel => 'Plans';

  @override
  String get subscriptionHeaderActiveLabel => 'Subscribed';

  @override
  String get subscriptionHeaderExpiringSoonLabel => 'Renew soon';

  @override
  String subscriptionHeaderExpiresInDaysLabel(int days) {
    return 'Expires in $days days';
  }

  @override
  String get subscriptionHeaderExpiredLabel => 'Subscription expiré';

  @override
  String get subscriptionHeaderUpgradeLabel => 'Upgrade';

  @override
  String get subscriptionHeaderTooltip => 'Manage abonnement et billing';

  @override
  String get subscriptionUpgradeDialogTitle => 'Upgrade abonnement';

  @override
  String get subscriptionRenewDialogTitle => 'Renew abonnement';

  @override
  String get subscriptionUpgradeDialogBody =>
      'Choose un forfait et soumettre paiement à keep full accès après votre trial ou renewal date.';

  @override
  String get subscriptionRenewDialogBody =>
      'Confirm votre actuel forfait et soumettre paiement à extend votre abonnement.';

  @override
  String get subscriptionUpgradeIntentBanner =>
      'You are upgrading à un higher forfait.';

  @override
  String subscriptionRenewIntentBanner(String plan) {
    return 'You are renewing votre $plan forfait.';
  }

  @override
  String get subscriptionUpgradePlanLabel => 'Plan';

  @override
  String get subscriptionUpgradePaymentMethodLabel => 'Payment method';

  @override
  String get subscriptionUpgradeAmountLabel => 'Amount paid';

  @override
  String get subscriptionUpgradeReferenceLabel => 'Payment référence';

  @override
  String get subscriptionUpgradeNotesLabel => 'Notes';

  @override
  String get subscriptionUpgradeProofLabel => 'Proof sur paiement';

  @override
  String get subscriptionUpgradeAttachProofAction => 'Attach proof';

  @override
  String get subscriptionUpgradeRemoveProofAction => 'Remove attachment';

  @override
  String get subscriptionUpgradeAdminContactTitle => 'Platform billing contact';

  @override
  String get subscriptionUpgradeAdminContactBody =>
      'If votre compte is not activated après paiement, contact our platform administrators en utilisant le détails below. Support is disponible at any heure.';

  @override
  String get subscriptionUpgradeAdminContactEmailLabel => 'E-mail';

  @override
  String get subscriptionUpgradeAdminContactPhoneLabel => 'Phone';

  @override
  String get subscriptionUpgradeSubmitAction => 'Submit paiement';

  @override
  String get subscriptionRenewSubmitAction => 'Submit renewal';

  @override
  String get subscriptionUpgradePaymentMethodSectionTitle =>
      'How would you like à pay?';

  @override
  String get subscriptionUpgradePaymentDetailsTitle => 'Payment détails';

  @override
  String get subscriptionMobileMoneyProviderLabel => 'Mobile money prestataire';

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
  String get subscriptionMobileMoneyGovernment => 'Government paiement portal';

  @override
  String get subscriptionBankNameLabel => 'Votre bank nom';

  @override
  String get subscriptionBankTransferDetailsTitle => 'Transfer à ce compte';

  @override
  String get subscriptionBankAccountNameLabel => 'Account nom';

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
      'Impossible de load exchange rate — montant shown in USD.';

  @override
  String get subscriptionCardHolderNameLabel => 'Name on card';

  @override
  String get subscriptionCardLastFourLabel => 'Last 4 digits';

  @override
  String get subscriptionPaymentReferenceHint =>
      'Transaction ID ou receipt number';

  @override
  String get subscriptionProofRequiredMessage =>
      'Attach proof sur paiement pour ce method.';

  @override
  String get subscriptionUpgradeSubmittedMessage =>
      'Payment submitted. Le platform team will review et activate votre abonnement.';

  @override
  String get subscriptionPaymentMethodBankTransfer => 'Bank transfert';

  @override
  String get subscriptionPaymentMethodMobileMoney => 'Mobile money';

  @override
  String get subscriptionPaymentMethodCreditCard => 'Credit card';

  @override
  String get subscriptionPaymentMethodDebitCard => 'Debit card';

  @override
  String get subscriptionPaymentMethodCash => 'Cash';

  @override
  String get subscriptionPaymentMethodOther => 'Autre';

  @override
  String get navigationEmergencyLabel => 'Urgences';

  @override
  String get navigationEmergencyShortLabel => 'Urgences';

  @override
  String get navigationIcuLabel => 'Intensive soins (ICU)';

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
  String get navigationGroupInpatientCareLabel => 'Inpatient soins';

  @override
  String get navigationGroupClinicalServicesLabel => 'Clinical soins';

  @override
  String get navigationGroupDiagnosticsMedicationLabel =>
      'Diagnostics & pharmacie';

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
  String get navigationTheaterLabel => 'Operating bloc opératoire';

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
  String get navigationRoomsBedsLabel => 'Rooms & lits';

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
      'Manage daily cases, readiness, chambre et team allocation, anesthesia, post-op notes, et handover.';

  @override
  String get theaterLoadingTitle => 'Loading bloc opératoire';

  @override
  String get theaterLoadingBody =>
      'Loading bloc opératoire cases et clinique dossiers.';

  @override
  String get theaterLiveStatus => 'Live synchronisation';

  @override
  String get theaterSavingStatus => 'Saving';

  @override
  String get theaterSavedMessage => 'Theater changes saved.';

  @override
  String get theaterScheduleCaseAction => 'Schedule case';

  @override
  String get theaterScheduledSummaryLabel => 'Scheduled';

  @override
  String get theaterInTheaterSummaryLabel => 'In bloc opératoire';

  @override
  String get theaterReadySummaryLabel => 'Ready';

  @override
  String get theaterCompletedSummaryLabel => 'Terminé';

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
  String get theaterSourceEmergency => 'Urgences';

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
  String get theaterHandoverToWard => 'Service';

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
  String get theaterFiltersLabel => 'Theater filtres';

  @override
  String get theaterSearchLabel => 'Search bloc opératoire';

  @override
  String get theaterSearchHint =>
      'Search patient, case, consultation, notes, ou dossier text';

  @override
  String get theaterScheduleDateFilterLabel => 'Schedule date';

  @override
  String get theaterPickScheduleDateAction => 'Pick planning date';

  @override
  String get theaterStatusFilterLabel => 'Statut';

  @override
  String get theaterStageFilterLabel => 'Stage';

  @override
  String get theaterResourceFiltersAction => 'Resource filtres';

  @override
  String get theaterClearFiltersAction => 'Clear filtres';

  @override
  String get theaterCasesTitle => 'Daily cases';

  @override
  String get theaterCasesDescription =>
      'Select un case à review readiness, dossiers, resources, et handover.';

  @override
  String get theaterNoCasesTitle => 'No bloc opératoire cases';

  @override
  String get theaterNoCasesBody =>
      'Scheduled et actif bloc opératoire cases will appear here.';

  @override
  String get theaterNoCaseSelectedTitle => 'No case selected';

  @override
  String get theaterNoCaseSelectedBody =>
      'Select un bloc opératoire case à review readiness, dossiers, et handover.';

  @override
  String get theaterPatientColumnLabel => 'Patient';

  @override
  String get theaterTimeColumnLabel => 'Heure';

  @override
  String get theaterRoomColumnLabel => 'Chambre';

  @override
  String get theaterStatusColumnLabel => 'Statut';

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
  String get theaterPatientSearchHint => 'Search by nom, MRN, ou téléphone';

  @override
  String get theaterEncounterSearchHint => 'Select un actif consultation';

  @override
  String get theaterEmergencyCaseLabel => 'Emergency case';

  @override
  String get theaterEmergencyCaseSearchHint => 'Link le actif urgence case';

  @override
  String get theaterEmergencyCaseSelectPatientFirstHint =>
      'Select un patient first';

  @override
  String get theaterScheduleEmergencyHint =>
      'Emergency cases require linking le actif ED case so bloc opératoire billing et passation context stay connected.';

  @override
  String get theaterScheduleEmergencyPanelTitle => 'Emergency scheduling';

  @override
  String get theaterScheduledTimeLabel => 'Scheduled heure';

  @override
  String get theaterOperatingRoomHint => 'Search operating theatre chambres';

  @override
  String get theaterSurgeonSearchHint =>
      'Search surgeons by nom ou personnel ID';

  @override
  String get theaterAnesthetistSearchHint =>
      'Search anesthetists by nom ou personnel ID';

  @override
  String get theaterProceduresSectionLabel => 'Procedures';

  @override
  String get theaterAddProcedureAction => 'Add procédure';

  @override
  String get theaterNoProceduresSelectedLabel =>
      'Add one ou more procedures à bill pour ce case.';

  @override
  String get theaterScheduledAtLabel => 'Scheduled at';

  @override
  String get theaterRoomLabel => 'Chambre';

  @override
  String get theaterReadinessLabel => 'Readiness';

  @override
  String get theaterTeamTitle => 'Team et flow';

  @override
  String get theaterSurgeonLabel => 'Surgeon';

  @override
  String get theaterAnesthetistLabel => 'Anesthetist';

  @override
  String get theaterStageLabel => 'Stage';

  @override
  String get theaterStatusLabel => 'Statut';

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
  String get theaterNoChecklistItemsLabel => 'No checklist éléments recorded';

  @override
  String get theaterRecordsTitle => 'Clinical dossiers';

  @override
  String get theaterAnesthesiaStatusLabel => 'Anesthesia statut';

  @override
  String get theaterPostOpStatusLabel => 'Post-op statut';

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
  String get theaterNoResourcesLabel => 'No resources assigné';

  @override
  String get theaterTimelineTitle => 'Timeline';

  @override
  String get theaterNoTimelineLabel => 'No timeline entries';

  @override
  String get theaterScheduleCaseDialogTitle => 'Schedule bloc opératoire case';

  @override
  String get theaterScheduleCaseDialogBody =>
      'Search pour le patient et their actif consultation, then set le planning, team, procedures, et billing.';

  @override
  String get theaterSchedulePatientContextSection => 'Patient context';

  @override
  String get theaterScheduleDetailsSection => 'Schedule et team';

  @override
  String get theaterScheduleBillingSection => 'Procedures et billing';

  @override
  String get theaterScheduleBillingSectionBody =>
      'Add catalog procedures à build line éléments. Bill later sends charges à le Billing espace de travail.';

  @override
  String get theaterEncounterSelectPatientFirstHint =>
      'Select un patient first';

  @override
  String get theaterRescheduleDialogTitle => 'Reschedule bloc opératoire case';

  @override
  String get theaterUpdateStageDialogTitle => 'Update bloc opératoire stage';

  @override
  String get theaterHandoverDialogTitle => 'Complete handover';

  @override
  String get theaterHandoverNotesLabel => 'Handover notes';

  @override
  String get theaterCancelCaseDialogTitle => 'Cancel bloc opératoire case';

  @override
  String get theaterCancellationReasonLabel => 'Cancellation reason';

  @override
  String get theaterAssignResourceDialogTitle =>
      'Assign bloc opératoire resource';

  @override
  String get theaterReadinessDialogTitle => 'Update readiness';

  @override
  String get theaterAnesthesiaDialogTitle => 'Anesthesia dossier';

  @override
  String get theaterPostOpDialogTitle => 'Post-op note';

  @override
  String get theaterFinalizeDialogTitle => 'Finalize dossiers';

  @override
  String get theaterResourceFiltersDialogTitle => 'Resource filtres';

  @override
  String get theaterEncounterIdLabel => 'Encounter ID';

  @override
  String get theaterEncounterIdHint =>
      'Encounter UUID ou case source identifiant';

  @override
  String get theaterDateTimeHint => 'YYYY-MM-DDTHH:MM:SS';

  @override
  String get theaterRoomIdLabel => 'Room ID';

  @override
  String get theaterSurgeonIdLabel => 'Surgeon utilisateur ID';

  @override
  String get theaterAnesthetistIdLabel => 'Anesthetist utilisateur ID';

  @override
  String get theaterResourceTypeLabel => 'Resource type';

  @override
  String get theaterResourceIdLabel => 'Resource ID';

  @override
  String get theaterStaffRoleLabel => 'Staff rôle';

  @override
  String get theaterNotesLabel => 'Notes';

  @override
  String get theaterChecklistPhaseLabel => 'Checklist phase';

  @override
  String get theaterChecklistItemCodeLabel => 'Item code';

  @override
  String get theaterChecklistItemLabel => 'Item libellé';

  @override
  String get theaterChecklistCheckedLabel => 'Terminé';

  @override
  String get theaterRecordStatusLabel => 'Record statut';

  @override
  String get theaterSaveRecordAction => 'Save dossier';

  @override
  String get theaterRecordTypeLabel => 'Record type';

  @override
  String get theaterApplyFiltersAction => 'Apply filtres';

  @override
  String theaterFieldRequiredLabel(String label) {
    return '$label est requis.';
  }

  @override
  String get theaterStatusScheduled => 'Scheduled';

  @override
  String get theaterStatusInTheater => 'In bloc opératoire';

  @override
  String get theaterStatusCompleted => 'Terminé';

  @override
  String get theaterStatusCancelled => 'Annulé';

  @override
  String get theaterStagePreOp => 'Pre-op';

  @override
  String get theaterStageSignIn => 'Se connecter';

  @override
  String get theaterStageTimeOut => 'Time out';

  @override
  String get theaterStageIntraOp => 'Intra-op';

  @override
  String get theaterStageSignOut => 'Se déconnecter';

  @override
  String get theaterStagePostOp => 'Post-op';

  @override
  String get theaterStagePacuHandoff => 'PACU handover';

  @override
  String get theaterStageCompleted => 'Terminé';

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
      'Manage arrivals, queues, personnel readiness, et ambulatoire clinique passations.';

  @override
  String get opdLoadingTitle => 'Loading OPD flow';

  @override
  String get opdLoadingBody =>
      'Loading ambulatoire queue et consultation data.';

  @override
  String get opdLiveStatus => 'Live synchronisation';

  @override
  String get opdSavingStatus => 'Saving';

  @override
  String get opdStartWalkInAction => 'Start OPD consultation';

  @override
  String get opdStartEncounterAction => 'Start consultation';

  @override
  String get opdOpenActiveEncounterAction => 'Update consultation';

  @override
  String get opdStartEncounterTooltip =>
      'Create ou continuer un OPD consultation pour ce patient';

  @override
  String get opdSavedMessage => 'OPD changes saved.';

  @override
  String get opdArrivalsSummaryLabel => 'Arrivals';

  @override
  String get opdQueueSummaryLabel => 'Queue';

  @override
  String get opdActiveFlowSummaryLabel => 'Active flows';

  @override
  String get opdCompletedFlowSummaryLabel => 'Terminé';

  @override
  String get opdFiltersLabel => 'OPD filtres';

  @override
  String get opdFilterAction => 'Filter OPD tableau';

  @override
  String get opdFilterDialogTitle => 'Filter OPD tableau';

  @override
  String get opdSearchFieldFilterLabel => 'Search in';

  @override
  String get opdAllFieldsFilterLabel => 'All champs';

  @override
  String get opdArrivalDateFilterLabel => 'Arrival date';

  @override
  String get opdDateFromLabel => 'From';

  @override
  String get opdDateToLabel => 'To';

  @override
  String get opdDatePickerButtonLabel => 'Choose date';

  @override
  String get opdInvalidDateMessage => 'Enter un valid date.';

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
  String get opdStatusFilterLabel => 'Statut';

  @override
  String get opdVisitTypeFilterLabel => 'Visit type';

  @override
  String get opdQueueFilterLabel => 'Queue';

  @override
  String get opdProviderFilterLabel => 'Assigned personnel';

  @override
  String get opdBillingFilterLabel => 'Facturation';

  @override
  String get opdNextActionFilterLabel => 'Next action';

  @override
  String get opdAllCategoriesOption => 'All catégories';

  @override
  String get opdAllStatusesOption => 'All statuses';

  @override
  String get opdAllVisitTypesOption => 'All visite types';

  @override
  String get opdAllQueuesOption => 'All queues';

  @override
  String get opdAllProvidersOption => 'All personnel';

  @override
  String get opdAllBillingStatesOption => 'All billing states';

  @override
  String get opdAllNextActionsOption => 'All suivant actions';

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
  String get opdSummaryLabPendingLabel => 'Lab en attente';

  @override
  String get opdSummaryImagingPendingLabel => 'Imaging en attente';

  @override
  String get opdSummaryPharmacyPendingLabel => 'Pharmacy en attente';

  @override
  String get opdSummaryDecisionNeededLabel => 'Decision needed';

  @override
  String get opdSummaryAdmissionPendingLabel => 'Admission en attente';

  @override
  String get opdSummaryDischargedTodayLabel => 'Discharged aujourd\'hui';

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
  String get opdStatusLabPendingLabel => 'Lab en attente';

  @override
  String get opdStatusSamplePendingLabel => 'Sample en attente';

  @override
  String get opdStatusInLabLabel => 'In laboratoire';

  @override
  String get opdStatusResultsReadyLabel => 'Results ready';

  @override
  String get opdStatusImagingPendingLabel => 'Imaging en attente';

  @override
  String get opdStatusReportPendingLabel => 'Report en attente';

  @override
  String get opdStatusReportReadyLabel => 'Report ready';

  @override
  String get opdStatusLabAndImagingPendingLabel => 'Lab & imaging en attente';

  @override
  String get opdStatusPharmacyPendingLabel => 'Pharmacy en attente';

  @override
  String get opdStatusDispensingLabel => 'Dispensing';

  @override
  String get opdStatusMedicinesDispensedLabel => 'Medicines dispensed';

  @override
  String get opdStatusDecisionNeededLabel => 'Decision needed';

  @override
  String get opdStatusAdmissionPendingLabel => 'Admission en attente';

  @override
  String get opdStatusAdmittedLabel => 'Admitted';

  @override
  String get opdStatusDischargedLabel => 'Discharged';

  @override
  String get opdNextCollectSampleLabel => 'Collect sample';

  @override
  String get opdNextProcessLabLabel => 'Process laboratoire';

  @override
  String get opdNextReviewResultsLabel => 'Review résultats';

  @override
  String get opdNextLabHandoffLabel => 'Lab passation';

  @override
  String get opdNextPerformImagingLabel => 'Perform imaging';

  @override
  String get opdNextCompleteImagingReportLabel => 'Complete imaging rapport';

  @override
  String get opdNextReviewReportLabel => 'Review rapport';

  @override
  String get opdNextImagingHandoffLabel => 'Imaging passation';

  @override
  String get opdNextDiagnosticsPendingLabel => 'Diagnostics en attente';

  @override
  String get opdNextDispenseMedicineLabel => 'Dispense medicine';

  @override
  String get opdNextPharmacyHandoffLabel => 'Pharmacy passation';

  @override
  String get opdNextDispositionLabel => 'Disposition';

  @override
  String get opdNextAdmissionHandoffLabel => 'Admission passation';

  @override
  String get opdOpenAdmissionAction => 'Open hospitalisé admission';

  @override
  String get opdAdmissionHandoffTitle => 'Patient admis';

  @override
  String get opdAdmissionHandoffBody =>
      'Ce ambulatoire visite has been admis à hospitalisé soins. Open le hospitalisé espace de travail à allocate un lit et continuer le admission. Le OPD consultation stays linked as le source visite.';

  @override
  String get opdAdmissionHandoffStayAction => 'Stay in OPD';

  @override
  String get opdPhysiotherapyHandoffTitle => 'Physiotherapy orientation placed';

  @override
  String get opdPhysiotherapyHandoffBody =>
      'Le patient has been referred à physiothérapie on ce visite. Open le physiothérapie espace de travail à accept le orientation et begin assessment.';

  @override
  String get opdOpenPhysiotherapyAction => 'Open physiothérapie';

  @override
  String get opdSearchLabel => 'Search OPD';

  @override
  String get opdSearchHint =>
      'Search patient, identifiant, ou assigné personnel';

  @override
  String get opdApplyFiltersAction => 'Apply filtres';

  @override
  String get opdClearFiltersAction => 'Clear filtres';

  @override
  String get opdAppointmentStatusFilterLabel => 'Appointment statut';

  @override
  String get opdQueueStatusFilterLabel => 'Queue statut';

  @override
  String get opdFlowStageFilterLabel => 'Flow stage';

  @override
  String get opdArrivalsTitle => 'Arrivals';

  @override
  String get opdQueueBoardTitle => 'Queue board';

  @override
  String get opdFlowsTitle => 'OPD consultations';

  @override
  String get opdTableDescription =>
      'Track arrivals, queue statut, billing state, assigné personnel, et suivant steps.';

  @override
  String get opdProviderReadinessTitle => 'Staff readiness';

  @override
  String get opdActivityTitle => 'Recent OPD activity';

  @override
  String get opdActivityDescription =>
      'Latest visible ambulatoire flow changes.';

  @override
  String get opdNoArrivalsTitle => 'No arrivals';

  @override
  String get opdNoArrivalsBody =>
      'Scheduled et checked-in patients will appear here.';

  @override
  String get opdNoQueueTitle => 'No queued patients';

  @override
  String get opdNoQueueBody =>
      'Reception queue entries will appear here as patients are routed.';

  @override
  String get opdNoFlowsTitle => 'No OPD consultations';

  @override
  String get opdNoFlowsBody =>
      'Started ambulatoire consultations will appear here.';

  @override
  String get opdNoFlowSelectedTitle => 'No consultation selected';

  @override
  String get opdNoFlowSelectedBody =>
      'Select un OPD consultation à review actions et related dossiers.';

  @override
  String get opdNoProvidersTitle => 'No personnel ready';

  @override
  String get opdNoProvidersBody =>
      'Staff schedules et disponible slots will appear here.';

  @override
  String get opdNoActivityTitle => 'No recent activity';

  @override
  String get opdNoActivityBody =>
      'OPD activity appears once consultations start moving.';

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
  String get opdStatusColumnLabel => 'Statut';

  @override
  String get opdVisitTypeColumnLabel => 'Visit type';

  @override
  String get opdQueueStatusColumnLabel => 'Queue / statut';

  @override
  String get opdTimeColumnLabel => 'Arrival heure';

  @override
  String get opdWaitingTimeColumnLabel => 'Wait heure';

  @override
  String get opdProviderColumnLabel => 'Assigned personnel';

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
  String get opdNoRelatedRecordsLabel => 'No related dossiers';

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
  String get opdPaymentRequiredLabel => 'Payment requis';

  @override
  String get opdPaymentNotRequiredLabel => 'Not requis';

  @override
  String get opdBillingRequiredAmountLabel => 'Required montant';

  @override
  String get opdBillingAmountPaidLabel => 'Amount paid';

  @override
  String get opdBillingRemainingBalanceLabel => 'Remaining balance';

  @override
  String get opdClinicalServicesTitle => 'Clinical services';

  @override
  String get opdClinicalServicesEmpty => 'No clinique services recorded yet.';

  @override
  String get clinicalReferralDetailsTitle => 'Referral détails';

  @override
  String get clinicalReferralNotesTitle => 'Additional notes';

  @override
  String get opdEncounterContextTitle => 'Encounter context';

  @override
  String get opdCopyPatientIdAction => 'Copy patient ID';

  @override
  String get opdCopyEncounterIdAction => 'Copy consultation ID';

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
      one: '1 ouvrir slot',
      zero: 'No ouvrir slots',
    );
    return '$_temp0';
  }

  @override
  String get opdWalkInDialogTitle => 'Start OPD consultation';

  @override
  String get opdPatientSectionTitle => 'Patient';

  @override
  String get opdRoutingSectionTitle => 'Routing';

  @override
  String get opdBillingSectionTitle => 'Facturation';

  @override
  String get opdExistingPatientModeLabel => 'Existing patient';

  @override
  String get opdAppointmentPatientModeLabel => 'Appointment patient';

  @override
  String get opdNewPatientModeLabel => 'New patient';

  @override
  String get opdSearchPatientLabel => 'Search patient';

  @override
  String get opdAppointmentPatientLabel => 'Search rendez-vous';

  @override
  String get opdAppointmentPatientHelper =>
      'Select un planifié rendez-vous à check le patient into OPD.';

  @override
  String get opdActiveEncounterCheckingLabel =>
      'Checking pour un actif OPD consultation...';

  @override
  String get opdActiveEncounterFoundTitle => 'Active OPD consultation found';

  @override
  String get opdActiveEncounterFoundBody =>
      'Ce patient already has un actif OPD consultation. Update le actif consultation instead sur creating un duplicate.';

  @override
  String get opdInactiveEncounterActionReason =>
      'Start ou mettre à jour un OPD consultation first.';

  @override
  String get opdSearchProviderLabel => 'Search doctor';

  @override
  String get opdSearchProviderHelper => 'Ce doctor will handle le patient.';

  @override
  String get opdNoProvidersHelper =>
      'No enregistré doctors were found. Check doctor setup ou personnel autorisations.';

  @override
  String get opdRegisterNewPatientLabel => 'Register un nouveau patient';

  @override
  String get opdPatientIdLabel => 'Patient ID';

  @override
  String get opdFirstNameLabel => 'First nom';

  @override
  String get opdLastNameLabel => 'Last nom';

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
  String get opdCancelAction => 'Annuler';

  @override
  String get opdCheckInAction => 'Start OPD consultation';

  @override
  String get opdAppointmentStartLabel => 'Start heure';

  @override
  String get opdAppointmentEndLabel => 'End heure';

  @override
  String get opdDateTimeHint => 'YYYY-MM-DDTHH:MM:SS';

  @override
  String get opdSaveAction => 'Enregistrer';

  @override
  String get opdCancellationReasonLabel => 'Cancellation reason';

  @override
  String get opdQueueStatusLabel => 'Queue statut';

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
  String get opdTransactionReferenceLabel => 'Transaction référence';

  @override
  String get opdStageLabel => 'Stage';

  @override
  String get opdCurrentStageLabel => 'Current stage';

  @override
  String get opdTargetStageLabel => 'Target stage';

  @override
  String get opdStageCorrectionReasonRequiredMessage =>
      'Enter un reason pour ce stage correction.';

  @override
  String get opdExternalFacilityLabel => 'External établissement';

  @override
  String get opdFollowUpDateLabel => 'Follow-up date';

  @override
  String get opdFollowUpTimeLabel => 'Follow-up heure';

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
  String get opdTriagePendingLabel => 'Triage en attente';

  @override
  String get opdChiefComplaintLabel => 'Chief complaint';

  @override
  String get opdEmergencyIndicatorsLabel => 'Emergency indicators';

  @override
  String get opdWorkflowReceptionTitle => 'Reception et queue';

  @override
  String get opdWorkflowTriageTitle => 'Triage';

  @override
  String get opdWorkflowDoctorTitle => 'Doctor consultation';

  @override
  String get opdWorkflowServicesTitle => 'Services';

  @override
  String get opdWorkflowPrintTitle => 'Printing';

  @override
  String get opdSendToTriageAction => 'Send à triage';

  @override
  String get opdSendToDoctorAction => 'Send à doctor';

  @override
  String get opdRecordVitalsAction => 'Record signes vitaux';

  @override
  String get opdEditVitalsAction => 'Edit signes vitaux';

  @override
  String get opdDoctorReviewAction => 'Doctor review';

  @override
  String get opdRouteLabAction => 'Send à laboratoire';

  @override
  String get opdRouteRadiologyAction => 'Send à radiologie';

  @override
  String get opdRoutePharmacyAction => 'Send à pharmacie';

  @override
  String get opdPrintSummaryAction => 'Print résumé';

  @override
  String get opdPrintAction => 'Imprimer';

  @override
  String get opdCopySummaryAction => 'Copy résumé';

  @override
  String get opdVitalsSummaryLabel => 'Vitals';

  @override
  String get opdAbnormalVitalsSummaryLabel => 'Abnormal signes vitaux';

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
  String get opdProcedureLabel => 'Procedure ou minor surgery';

  @override
  String get opdProcedureCodeLabel => 'Procedure code';

  @override
  String get opdLabTestIdsLabel => 'Lab test IDs';

  @override
  String get opdLabPanelIdsLabel => 'Lab panneau IDs';

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
  String get opdTriageScopeEmergency => 'Urgences';

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
      'Find, register, et maintain patient dossiers across front desk et soins workflows.';

  @override
  String get patientsTableTitle => 'Patient dossiers';

  @override
  String get patientsTableDescription =>
      'Browse enregistré patients, visite context, alerts, statut, et disponible suivant actions.';

  @override
  String get patientsLoadingTitle => 'Loading patients';

  @override
  String get patientsLoadingBody => 'Loading patient registry data.';

  @override
  String get patientsStatusReady => 'Registry ready';

  @override
  String get patientsAddAction => 'Add patient';

  @override
  String get patientsEmergencyRegisterAction => 'Emergency inscription';

  @override
  String get patientsEditAction => 'Modifier';

  @override
  String get patientsDeleteAction => 'Supprimer';

  @override
  String get patientsSaveAction => 'Enregistrer';

  @override
  String get patientsSaveAnywayAction => 'Save anyway';

  @override
  String get patientsSavedMessage => 'Patient registry changes saved.';

  @override
  String get patientsEmergencySavedMessage =>
      'Emergency patient enregistré pour completion.';

  @override
  String get patientsDeletedMessage => 'Patient registry dossier supprimé.';

  @override
  String get patientsMergedMessage => 'Patient dossiers merged.';

  @override
  String get patientsDuplicateDismissedMessage => 'Duplicate review dismissed.';

  @override
  String get patientsTotalSummaryLabel => 'Total patients';

  @override
  String get patientsTotalSummaryBody =>
      'All visible patient dossiers in scope.';

  @override
  String get patientsActiveSummaryLabel => 'Active patients';

  @override
  String get patientsActiveSummaryBody =>
      'Patients disponible pour actuel workflows.';

  @override
  String get patientsQueueSummaryLabel => 'Waiting queue';

  @override
  String get patientsQueueSummaryBody =>
      'Patients currently waiting pour service.';

  @override
  String get patientsDuplicateSummaryLabel => 'Duplicate review';

  @override
  String get patientsDuplicateSummaryBody =>
      'Potential matches needing review.';

  @override
  String get patientsFiltersLabel => 'Patient filtres';

  @override
  String get patientsSearchLabel => 'Rechercher';

  @override
  String get patientsSearchHint =>
      'Name, téléphone, e-mail, identifiant, ou contact';

  @override
  String get patientsPatientIdFilterLabel => 'Patient ID';

  @override
  String get patientsGenderFilterLabel => 'Gender';

  @override
  String get patientsStatusFilterLabel => 'Statut';

  @override
  String get patientsConsentFilterLabel => 'Consent';

  @override
  String get patientsContactFilterLabel => 'Contact';

  @override
  String get patientsVisitDateFilterLabel => 'Visit date';

  @override
  String get patientsVisitFromFilterLabel => 'Visit de';

  @override
  String get patientsVisitToFilterLabel => 'Visit à';

  @override
  String get patientsDobFromFilterLabel => 'DOB de';

  @override
  String get patientsDobToFilterLabel => 'DOB à';

  @override
  String get patientsCreatedFromFilterLabel => 'Registered de';

  @override
  String get patientsCreatedToFilterLabel => 'Registered à';

  @override
  String get patientsActiveAdmissionFilterLabel => 'Active admission';

  @override
  String get patientsOutstandingBalanceFilterLabel => 'Outstanding balance';

  @override
  String get patientsYesFilterLabel => 'Oui';

  @override
  String get patientsNoFilterLabel => 'Non';

  @override
  String get patientsFilterIdentitySectionTitle => 'Identity';

  @override
  String get patientsFilterVisitSectionTitle => 'Visits';

  @override
  String get patientsFilterRecordSectionTitle => 'Record state';

  @override
  String get patientsApplyFiltersAction => 'Apply';

  @override
  String get patientsClearFiltersAction => 'Effacer';

  @override
  String get patientsAdvancedFiltersAction => 'Advanced filtres';

  @override
  String get patientsAdvancedFiltersTitle => 'Advanced filtres';

  @override
  String get patientsSummaryLoadingTitle => 'Loading patients';

  @override
  String get patientsSummaryLoadingBody => 'Loading related patient dossiers.';

  @override
  String get patientsActiveFilter => 'Actif';

  @override
  String get patientsInactiveFilter => 'Inactif';

  @override
  String get patientsPatientColumnLabel => 'Patient';

  @override
  String get patientsPatientNumberColumnLabel => 'Patient non.';

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
  String get patientsStatusColumnLabel => 'Statut';

  @override
  String get patientsNoAlertsLabel => 'No alerts';

  @override
  String get patientsAllergyAlertLabel => 'Allergy';

  @override
  String get patientsNoVisitLabel => 'No visite';

  @override
  String get patientsCompleteRecordAction => 'Complete dossier';

  @override
  String get patientsOpenRecordAction => 'Open dossier';

  @override
  String patientsPageLabel(int from, int to, int total) {
    return '$from-$to of $total';
  }

  @override
  String get patientsPreviousPageLabel => 'Previous patients page';

  @override
  String get patientsNextPageLabel => 'Next patients page';

  @override
  String get patientsEmptyTitle => 'Aucun patients trouvé';

  @override
  String get patientsEmptyBody => 'Adjust le filtres ou register un patient.';

  @override
  String get patientsDetailTitle => 'Patient détails';

  @override
  String get patientsDetailLoadingTitle => 'Loading patient';

  @override
  String get patientsDetailLoadingBody =>
      'Loading demographics et related dossiers.';

  @override
  String get patientsNoSelectionTitle => 'Select un patient';

  @override
  String get patientsNoSelectionBody =>
      'Open un patient à review demographics, contacts, clinique flags, documents, et visites.';

  @override
  String get patientsNameLabel => 'Nom';

  @override
  String get patientsIdentifierLabel => 'Identifier';

  @override
  String get patientsDobLabel => 'Date sur naissance';

  @override
  String get patientsGenderLabel => 'Gender';

  @override
  String get patientsPhoneLabel => 'Phone';

  @override
  String get patientsEmailLabel => 'E-mail';

  @override
  String get patientsFacilityLabel => 'Facility';

  @override
  String get patientsRegistrationStatusLabel => 'Registration';

  @override
  String get patientsRegistrationIncompleteValue => 'Completion needed';

  @override
  String get patientsFirstNameLabel => 'First nom';

  @override
  String get patientsLastNameLabel => 'Last nom';

  @override
  String get patientsIdentifierTypeLabel => 'Identifier type';

  @override
  String get patientsIdentifierValueLabel => 'Identifier valeur';

  @override
  String get patientsActiveCheckboxLabel => 'Patient is actif';

  @override
  String get patientsDatePickerAction => 'Select date';

  @override
  String get patientsAddTitle => 'Add patient';

  @override
  String get patientsEmergencyRegisterTitle => 'Emergency inscription';

  @override
  String get patientsEmergencyRegisterBody =>
      'Create un minimal patient dossier now; demographics et documents can be terminé après urgent soins starts.';

  @override
  String get patientsEmergencyFirstNameLabel => 'Known first nom';

  @override
  String get patientsEmergencyLastNameLabel => 'Known last nom';

  @override
  String get patientsEmergencySaveAction => 'Register urgence patient';

  @override
  String get patientsEditTitle => 'Edit patient';

  @override
  String get patientsDeleteTitle => 'Delete patient';

  @override
  String patientsDeleteBody(String name) {
    return 'Delete $name de actif patient dossiers?';
  }

  @override
  String get patientsGenderMale => 'Homme';

  @override
  String get patientsGenderFemale => 'Femme';

  @override
  String get patientsGenderOther => 'Autre';

  @override
  String get patientsGenderUnknown => 'Inconnu';

  @override
  String get patientsQuickActionsTitle => 'Quick actions';

  @override
  String get patientsQuickAppointmentAction => 'Appointment';

  @override
  String get patientsQuickOpdCheckInAction => 'Start / Check in OPD';

  @override
  String get patientsQuickViewActiveOpdAction => 'Continue OPD flow';

  @override
  String get patientsQuickTriageAction => 'Triage';

  @override
  String get patientsQuickClinicalAction => 'Clinical visite';

  @override
  String get patientsQuickBillingAction => 'Facturation';

  @override
  String get patientsQuickAdmissionAction => 'Admission';

  @override
  String get patientsQuickReportAction => 'Patient rapport';

  @override
  String get patientsQuickActionQueuedMessage =>
      'Le patient context is ready pour le selected workflow.';

  @override
  String get patientsQuickActionSavedMessage => 'Patient workflow mis à jour.';

  @override
  String patientsWorkflowValidationMessage(String fields) {
    return 'Check these champs et réessayer: $fields.';
  }

  @override
  String get patientsAppointmentDialogTitle => 'Schedule rendez-vous';

  @override
  String get patientsAppointmentDateLabel => 'Appointment date';

  @override
  String get patientsAppointmentTimeLabel => 'Start heure';

  @override
  String get patientsAppointmentDurationLabel => 'Duration minutes';

  @override
  String get patientsAppointmentStatusLabel => 'Appointment statut';

  @override
  String get patientsAppointmentReasonLabel => 'Reason';

  @override
  String get patientsProviderLabel => 'Provider';

  @override
  String get patientsProviderOptionalHelper =>
      'Optional prestataire assignment.';

  @override
  String get patientsWorkflowSectionTitle => 'Workflow';

  @override
  String get patientsArrivalSectionTitle => 'Arrival';

  @override
  String get patientsTriagePrioritySectionTitle => 'Triage priorité';

  @override
  String get patientsVitalsSectionTitle => 'Vital signs';

  @override
  String get patientsClinicalAssessmentSectionTitle => 'Assessment';

  @override
  String get patientsBillingSectionTitle => 'Billing détails';

  @override
  String get patientsAdmissionClinicalSectionTitle => 'Clinical approbation';

  @override
  String get patientsAdmissionLocationSectionTitle => 'Admission location';

  @override
  String get patientsNotesSectionTitle => 'Notes';

  @override
  String get patientsOpdCheckInDialogTitle => 'Start OPD consultation';

  @override
  String get patientsTriageDialogTitle => 'Triage intake';

  @override
  String get patientsClinicalDialogTitle => 'Clinical visite';

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
      'Enter at least one vital sign avant completing triage.';

  @override
  String get patientsVitalUnitLabel => 'Unit';

  @override
  String get patientsVitalNormalLabel => 'Normal';

  @override
  String get patientsVitalAbnormalLabel => 'Abnormal';

  @override
  String get patientsVitalNumberInvalidMessage => 'Enter un valid number.';

  @override
  String patientsVitalRangeSuggestion(String profile, String range) {
    return 'Expected pour $profile: $range';
  }

  @override
  String patientsVitalLimitMessage(String range) {
    return 'Enter un valeur between $range.';
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
  String get patientsTransactionReferenceLabel => 'Transaction référence';

  @override
  String get patientsAdmissionReasonLabel => 'Admission reason';

  @override
  String get patientsWardLabel => 'Service';

  @override
  String get patientsRoomLabel => 'Chambre';

  @override
  String get patientsBedLabel => 'Lit';

  @override
  String get patientsReportDialogTitle => 'Patient rapport';

  @override
  String get patientsPrintReportAction => 'Print rapport';

  @override
  String get patientsAppointmentsSectionTitle => 'Rendez-vous';

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
  String get patientsReportPreviewDialogTitle => 'Print aperçu';

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
      'No dossiers disponible pour le selected period.';

  @override
  String get patientsReportPreparedOnLabel => 'Prepared on';

  @override
  String get patientsReportHospitalNameLabel => 'Hospital nom';

  @override
  String get patientsReportHospitalContactLabel => 'Contact information';

  @override
  String get patientsReportHospitalLocationLabel => 'Location';

  @override
  String get patientsReportHospitalAddressLabel => 'Address';

  @override
  String get patientsReportPrintNowAction => 'Imprimer';

  @override
  String get patientsReportDateRangeInvalidMessage =>
      'Start date doit être on or before end date.';

  @override
  String get patientsTimeInvalidMessage => 'Enter heure as HH:MM.';

  @override
  String get patientsTimeHint => 'HH:MM';

  @override
  String get patientsDurationInvalidMessage =>
      'Enter un duration between 1 et 720 minutes.';

  @override
  String get patientsIdentifiersSectionTitle => 'Identifiers';

  @override
  String get patientsContactsSectionTitle => 'Contacts';

  @override
  String get patientsGuardiansSectionTitle => 'Guardians';

  @override
  String get patientsAllergiesSectionTitle => 'Allergies';

  @override
  String get patientsMedicalHistorySectionTitle => 'Medical historique';

  @override
  String get patientsDocumentsSectionTitle => 'Documents';

  @override
  String get patientsConsentsSectionTitle => 'Consents';

  @override
  String get patientsTimelineSectionTitle => 'Timeline';

  @override
  String get patientsNoIdentifiers => 'No identifiants recorded.';

  @override
  String get patientsNoContacts => 'No contacts recorded.';

  @override
  String get patientsNoGuardians => 'No guardians recorded.';

  @override
  String get patientsNoAllergies => 'No allergies recorded.';

  @override
  String get patientsNoMedicalHistory => 'No médical historique recorded.';

  @override
  String get patientsNoDocuments => 'No documents recorded.';

  @override
  String get patientsNoConsents => 'No consents recorded.';

  @override
  String get patientsNoTimeline => 'No timeline entries recorded.';

  @override
  String get patientsAddRelatedAction => 'Add dossier';

  @override
  String get patientsAddRelatedTitle => 'Add patient dossier';

  @override
  String get patientsEditRelatedTitle => 'Edit patient dossier';

  @override
  String get patientsRelatedDeleteTitle => 'Delete patient dossier';

  @override
  String get patientsRelatedDeleteBody => 'Delete ce patient dossier?';

  @override
  String get patientsContactTypeLabel => 'Contact type';

  @override
  String get patientsContactValueLabel => 'Contact valeur';

  @override
  String get patientsContactInvalidMessage => 'Enter un valid contact valeur.';

  @override
  String get patientsPrimaryRecordLabel => 'Primary dossier';

  @override
  String get patientsGuardianNameLabel => 'Guardian nom';

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
      'Upload un file instead. Only enter ce lorsque referencing un existing stored document.';

  @override
  String get patientsDocumentUploadTitle => 'Document upload';

  @override
  String get patientsDocumentUploadEmpty =>
      'No file selected. PDF, JPG, et PNG files up à 10 MB are supported.';

  @override
  String get patientsChooseDocumentAction => 'Choose file';

  @override
  String get patientsFileNameLabel => 'File nom';

  @override
  String get patientsContentTypeLabel => 'Content type';

  @override
  String get patientsConsentTypeLabel => 'Consent type';

  @override
  String get patientsConsentStatusLabel => 'Consent statut';

  @override
  String get patientsConsentDateLabel => 'Consent date';

  @override
  String get patientsDuplicateWarningTitle => 'Potential duplicate found';

  @override
  String get patientsDuplicateWarningBody =>
      'Review le matches avant creating another patient dossier. Continue only lorsque ce is un different patient.';

  @override
  String get patientsDuplicateReviewTitle => 'Duplicate review';

  @override
  String get patientsNoDuplicateReviewsTitle => 'No duplicates à review';

  @override
  String get patientsNoDuplicateReviewsBody =>
      'Potential duplicate patient dossiers will appear here.';

  @override
  String get patientsMergePreviewLoadingTitle => 'Loading merge aperçu';

  @override
  String get patientsMergePreviewLoadingBody =>
      'Checking which dossiers will move à le retained patient.';

  @override
  String patientsDuplicateScoreLabel(int score) {
    return '$score% match';
  }

  @override
  String get patientsReviewMergeAction => 'Review merge';

  @override
  String get patientsDismissDuplicateAction => 'Dismiss';

  @override
  String get patientsMergePreviewTitle => 'Merge aperçu';

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
      'Patient dossier issues cette may need review.';

  @override
  String get patientsActivityEmptyTitle => 'No registry issues';

  @override
  String get patientsActivityEmptyBody =>
      'No duplicate, consent, ou document alerts are visible.';

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
      one: '1 patient has non documents',
    );
    return '$_temp0';
  }

  @override
  String get homeReadyTitle => 'Hospital operations espace de travail';

  @override
  String get homeReadyBody =>
      'Coordinate patient inscription, clinique soins, pharmacie, billing, diagnostics, operations, et compliance de one responsive HMS shell.';

  @override
  String get homeEntryPointsLabel => 'Core entry points';

  @override
  String get homeFeatureResponsiveTitle => 'Patient front desk';

  @override
  String get homeFeatureResponsiveBody =>
      'Register patients, book appointments, et manage queues pour OPD et urgence intake.';

  @override
  String get homeFeatureNavigationTitle => 'Clinical espace de travail';

  @override
  String get homeFeatureNavigationBody =>
      'Open consultations, clinique notes, diagnoses, soins forfaits, commandes, et hospitalisé handovers.';

  @override
  String get homeFeatureLocalizationTitle => 'Revenue cycle';

  @override
  String get homeFeatureLocalizationBody =>
      'Track factures, cashier paiements, refunds, coverage, pre-authorizations, et réclamations.';

  @override
  String get homeFeatureSettingsTitle => 'Facility operations';

  @override
  String get homeFeatureSettingsBody =>
      'Coordinate services, lits, départements, équipement, entretien, maintenance, et personnel rosters.';

  @override
  String get homeLoadingTitle => 'Preparing tableau de bord';

  @override
  String get homeLoadingBody => 'Loading readiness.';

  @override
  String get homeTodayAtAGlanceTitle => 'Today at un glance';

  @override
  String homeMetricCardSemantics(String label, String value) {
    return '$label: $value. View détails.';
  }

  @override
  String get homeOpenHrWorkspaceLink => 'Open HR espace de travail';

  @override
  String get homeMetricActiveStaffCompact => 'Active personnel';

  @override
  String get homeMetricShiftsTodayCompact => 'Shifts aujourd\'hui';

  @override
  String get homeMetricPendingLeavesCompact => 'Pending congé';

  @override
  String get homeMetricOnLeaveTodayCompact => 'On congé';

  @override
  String get homeMetricUnassignedShiftsCompact => 'Unassigned';

  @override
  String get homeMetricAttendedTodayCompact => 'Attended';

  @override
  String get homeMetricMissedShiftsTodayCompact => 'Missed shifts';

  @override
  String get homeMetricPayrollPendingCompact => 'Payroll en attente';

  @override
  String get homeViewAllAction => 'View tous';

  @override
  String get homeTrendLast7Days => 'Last 7 days';

  @override
  String get homeTrendDefaultSubtitle =>
      'Role-focused changes over le latest reporting window.';

  @override
  String get homeTrendEmptyMessage => 'No trend data is disponible yet.';

  @override
  String get homeDistributionWorkforceMix => 'Staff availability mix';

  @override
  String get homeDistributionDefaultSubtitle =>
      'Live mix sur le dossiers behind ce tableau de bord.';

  @override
  String get homeDistributionEmptyMessage =>
      'No distribution data is disponible yet.';

  @override
  String get homeLoadErrorTitle => 'Dashboard n\'un pas pu load';

  @override
  String get homeLoadErrorBody => 'Try le demande again.';

  @override
  String get homeServiceAreasLabel => 'Service areas';

  @override
  String get homeServiceAreaOutpatient =>
      'Outpatient, triage, urgence, et ambulance';

  @override
  String get homeServiceAreaInpatient =>
      'Inpatient, ICU, bloc opératoire, soins infirmiers, et sortie';

  @override
  String get homeServiceAreaDiagnostics =>
      'Laboratory, radiologie, pharmacie, et médicament dispensing';

  @override
  String get homeServiceAreaAdministration =>
      'Billing, réclamations, subscriptions, rapports, audit, et intégrations';

  @override
  String get profileTitle => 'Profil';

  @override
  String get profileBody =>
      'Review votre compte, rôle, et établissement détails.';

  @override
  String get profileAccountSectionTitle => 'Compte';

  @override
  String get profileAccountSectionBody => 'Core identity et login information.';

  @override
  String get profileProfessionalSectionTitle => 'Professional détails';

  @override
  String get profileProfessionalSectionBody =>
      'Role, titre, utilisateur type, et établissement context.';

  @override
  String get profileNameLabel => 'Nom';

  @override
  String get profileEmailLabel => 'E-mail';

  @override
  String get profilePhoneLabel => 'Phone';

  @override
  String get profileStatusLabel => 'Statut';

  @override
  String get profileTitleLabel => 'Title';

  @override
  String get profileOverallRoleLabel => 'Overall rôle';

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
      one: '1 direct autorisation',
      zero: 'No direct autorisations',
    );
    return '$_temp0';
  }

  @override
  String get profileUnavailableTitle => 'Profile indisponible';

  @override
  String get profileUnavailableBody =>
      'Sign in again à reload votre compte détails.';

  @override
  String get profileUnknownValue => 'Not disponible';

  @override
  String get profileLoadingTitle => 'Loading profil';

  @override
  String get profileLoadingBody =>
      'Refreshing compte, rôle, et autorisation détails.';

  @override
  String get profileRolesSectionTitle => 'Assigned rôles';

  @override
  String get profileRolesSectionBody =>
      'Roles currently linked à votre compte.';

  @override
  String get profileRolesEmpty => 'No rôles are assigné à ce compte.';

  @override
  String get profilePermissionsSectionTitle => 'Direct autorisations';

  @override
  String get profilePermissionsSectionBody =>
      'Permissions granted directly à votre compte.';

  @override
  String get profilePermissionsEmpty =>
      'No direct autorisations are assigné à ce compte.';

  @override
  String profileRoleCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count roles',
      one: '1 rôle',
      zero: 'No rôles',
    );
    return '$_temp0';
  }

  @override
  String get profileChangePasswordActionTitle => 'Change mot de passe';

  @override
  String get profileEditActionTitle => 'Edit profil';

  @override
  String get profileEditDialogTitle => 'Edit profil';

  @override
  String get profileEditDialogBody =>
      'Update le nom et demographic détails stored in votre utilisateur profil.';

  @override
  String get profileEditFirstNameLabel => 'First nom';

  @override
  String get profileEditMiddleNameLabel => 'Middle nom';

  @override
  String get profileEditLastNameLabel => 'Last nom';

  @override
  String get profileEditGenderLabel => 'Gender';

  @override
  String get profileGenderMale => 'Homme';

  @override
  String get profileGenderFemale => 'Femme';

  @override
  String get profileGenderOther => 'Autre';

  @override
  String get profileGenderUnknown => 'Inconnu';

  @override
  String get profileSaveSuccessMessage => 'Profil mis à jour.';

  @override
  String get profileSaveErrorMessage =>
      'Le profil n\'a pas pu être mis à jour.';

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get settingsBody => 'Définir les préférences HOSSPI HMS.';

  @override
  String get settingsPreferencesSectionTitle => 'Préférences';

  @override
  String get settingsPreferencesSectionBody =>
      'Thème, langue et choix d\'affichage locaux.';

  @override
  String get settingsLanguageSectionTitle => 'Langue';

  @override
  String get settingsLanguageSectionBody =>
      'Choisissez l\'anglais ou le français pour l\'interface de l\'application.';

  @override
  String get settingsLanguageFieldLabel => 'Langue de l\'application';

  @override
  String get settingsLanguageEnglish => 'Anglais';

  @override
  String get settingsLanguageFrench => 'Français';

  @override
  String get settingsThemeSectionTitle => 'Thème';

  @override
  String get settingsThemeSectionBody =>
      'Utiliser le mode système, clair ou sombre.';

  @override
  String get settingsThemeModeFieldLabel => 'App theme';

  @override
  String get settingsThemeModeSystem => 'Système';

  @override
  String get settingsThemeModeSystemDescription =>
      'Suivre le réglage de l\'appareil.';

  @override
  String get settingsThemeModeLight => 'Clair';

  @override
  String get settingsThemeModeLightDescription => 'Use le light color scheme.';

  @override
  String get settingsThemeModeDark => 'Sombre';

  @override
  String get settingsThemeModeDarkDescription => 'Use le dark color scheme.';

  @override
  String get settingsSaveErrorMessage =>
      'The preference n\'a pas pu être saved.';

  @override
  String get settingsAccessibilitySectionTitle => 'Accessibility';

  @override
  String get settingsAccessibilitySectionBody =>
      'Improve readability et reduce motion across clinique workspaces.';

  @override
  String get settingsReduceMotionLabel => 'Reduce motion';

  @override
  String get settingsReduceMotionDescription =>
      'Use simpler transitions et fewer animations.';

  @override
  String get settingsBoldTextLabel => 'Bold text';

  @override
  String get settingsBoldTextDescription =>
      'Increase text weight pour easier reading.';

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
      'Review forfaits, module entitlements, factures, licenses, et renewal state.';

  @override
  String get settingsAccountSectionTitle => 'Account et sécurité';

  @override
  String get settingsAccountSectionBody =>
      'Profile et sign-in controls stay avec le utilisateur compte.';

  @override
  String get settingsProfileActionTitle => 'Profil';

  @override
  String get settingsProfileActionBody =>
      'Review identity, rôle, et établissement context.';

  @override
  String get settingsChangePasswordActionTitle => 'Change mot de passe';

  @override
  String get settingsChangePasswordActionBody =>
      'Update votre mot de passe et restart le session.';

  @override
  String get settingsAdministrationSectionTitle => 'Administration boundaries';

  @override
  String get settingsAdministrationSectionBody =>
      'Workspace administration stays in dedicated modules.';

  @override
  String get settingsTenantBoundaryLabel => 'Tenant paramètres';

  @override
  String get settingsFacilityBoundaryLabel => 'Facility paramètres';

  @override
  String get settingsSecurityBoundaryLabel => 'User et sécurité paramètres';

  @override
  String get settingsSecurityBoundaryBody =>
      'Review administrator accès avant opening utilisateur management.';

  @override
  String get settingsTenantFacilitySetupActionTitle =>
      'Tenant et établissement setup';

  @override
  String get settingsTenantFacilitySetupActionBody =>
      'Configure organization identity, établissement profil, départements, unités, et physical locations.';

  @override
  String get tenantFacilitySetupTitle => 'Tenant et établissement setup';

  @override
  String get tenantFacilitySetupBody =>
      'Prepare le organization et établissement avant daily hôpital operations begin.';

  @override
  String get tenantFacilitySetupLoadingTitle => 'Loading setup';

  @override
  String get tenantFacilitySetupLoadingBody =>
      'Loading organization et établissement configuration.';

  @override
  String get tenantFacilityHrSetupTitle => 'Facility structure pour HR';

  @override
  String get tenantFacilityHrSetupBody =>
      'Maintain départements et unités pour le actuel établissement so personnel onboarding et assignments stay accurate.';

  @override
  String get tenantFacilityHrSetupDepartmentsBody =>
      'Departments group personnel et rosters by service area.';

  @override
  String get tenantFacilityHrSetupUnitsBody =>
      'Units refine département coverage pour quart et service assignments.';

  @override
  String get tenantFacilityHrSetupManageAction => 'Manage';

  @override
  String get tenantFacilitySummaryConfigured => 'Configured';

  @override
  String get tenantFacilitySummaryNeedsSetup => 'Needs setup';

  @override
  String get tenantFacilitySummaryNoTenant => 'No locataire profil';

  @override
  String get tenantFacilitySummaryNoFacility => 'No établissement selected';

  @override
  String tenantFacilitySummaryRecordCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count records',
      one: '1 dossier',
      zero: 'No dossiers',
    );
    return '$_temp0';
  }

  @override
  String tenantFacilitySummaryDepartmentUnitCount(int departments, int units) {
    String _temp0 = intl.Intl.pluralLogic(
      departments,
      locale: localeName,
      other: '$departments departments',
      one: '1 département',
      zero: 'No départements',
    );
    String _temp1 = intl.Intl.pluralLogic(
      units,
      locale: localeName,
      other: '$units units',
      one: '1 unité',
      zero: 'non unités',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String tenantFacilitySummaryLocationCount(int wards, int rooms, int beds) {
    String _temp0 = intl.Intl.pluralLogic(
      wards,
      locale: localeName,
      other: '$wards wards',
      one: '1 service',
      zero: 'No services',
    );
    String _temp1 = intl.Intl.pluralLogic(
      rooms,
      locale: localeName,
      other: '$rooms rooms',
      one: '1 chambre',
      zero: 'non chambres',
    );
    String _temp2 = intl.Intl.pluralLogic(
      beds,
      locale: localeName,
      other: '$beds beds',
      one: '1 lit',
      zero: 'non lits',
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
  String get tenantFacilityChecklistTenant => 'Tenant profil is configured';

  @override
  String get tenantFacilityChecklistIdentity =>
      'Facility identity et contacts are configured';

  @override
  String get tenantFacilityChecklistDepartments => 'Departments are configured';

  @override
  String get tenantFacilityChecklistBranches =>
      'Branches are configured (facultatif)';

  @override
  String get tenantFacilityChecklistUnits =>
      'Units are configured (facultatif)';

  @override
  String get tenantFacilityChecklistWards => 'Wards are configured';

  @override
  String get tenantFacilityChecklistRooms => 'Rooms are configured';

  @override
  String get tenantFacilityChecklistBeds => 'Beds are configured';

  @override
  String get tenantFacilityChecklistLocations =>
      'Rooms, services, ou lits are configured';

  @override
  String get tenantFacilityWizardTitle => 'Guided setup';

  @override
  String get tenantFacilityWizardBody =>
      'Complete le main setup flow in commande avant daily operations begin.';

  @override
  String get tenantFacilityWizardStepTenant => 'Tenant profil';

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
  String get tenantFacilityWizardStepOrganization => 'Departments et unités';

  @override
  String get tenantFacilityWizardStepCareSpaces => 'Wards, chambres, et lits';

  @override
  String get tenantFacilityWizardContinueAction => 'Continue setup';

  @override
  String get tenantFacilityBranchesOptionalHint =>
      'Branches are facultatif pour single-site établissements. Skip ce step lorsque le établissement acts as le only site.';

  @override
  String get tenantFacilityGateNeedFacility =>
      'Configure établissement identity avant adding départements.';

  @override
  String get tenantFacilityGateNeedDepartmentForUnits =>
      'Create at least one département avant adding unités.';

  @override
  String get tenantFacilityGateNeedDepartmentForWards =>
      'Create at least one département avant adding services.';

  @override
  String get tenantFacilityGateNeedWardOrDepartmentForRooms =>
      'Create at least one département ou service avant adding chambres.';

  @override
  String get tenantFacilityGateNeedWardsForBeds =>
      'Create at least one service avant adding lits.';

  @override
  String get tenantFacilityRoomWardOptionalHint =>
      'Leave non assigné pour ambulatoire ou département consult chambres.';

  @override
  String get tenantFacilityRoomOutpatientLabel =>
      'Outpatient / département area';

  @override
  String get tenantFacilityInvalidBranchSelection =>
      'Select un succursale cette belongs à ce établissement.';

  @override
  String get tenantFacilityInvalidDepartmentSelection =>
      'Select un département cette belongs à ce établissement.';

  @override
  String get tenantFacilityInvalidWardSelection =>
      'Select un service cette belongs à ce établissement.';

  @override
  String get tenantFacilityInvalidRoomSelection =>
      'Select un chambre cette belongs à ce établissement.';

  @override
  String get tenantFacilitySubscriptionSummaryTitle => 'Subscription statut';

  @override
  String get tenantFacilitySubscriptionNoPlan => 'No actif abonnement';

  @override
  String tenantFacilitySubscriptionModulesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count active modules',
      one: '1 actif module',
    );
    return '$_temp0';
  }

  @override
  String get tenantFacilityPermissionsTitle => 'Permission gates';

  @override
  String get tenantFacilityPermissionsBody =>
      'Write actions require locataire ou établissement administrator autorisations.';

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
      'Administrator autorisation est requis pour ce action.';

  @override
  String get tenantFacilityTenantSectionTitle => 'Tenant profil';

  @override
  String get tenantFacilityTenantSectionBody =>
      'Organization détails shared across établissements.';

  @override
  String get tenantFacilityTenantNameLabel => 'Tenant nom';

  @override
  String get tenantFacilityTenantSlugLabel => 'Tenant slug';

  @override
  String get tenantFacilityActiveLabel => 'Actif';

  @override
  String get tenantFacilitySaveTenantAction => 'Save locataire';

  @override
  String get tenantFacilityFacilitySectionTitle => 'Facility profil';

  @override
  String get tenantFacilityFacilitySectionBody =>
      'Facility nom, logo référence, contact détails, adresse, type, et actif state.';

  @override
  String get tenantFacilityLogoLabel => 'Facility logo';

  @override
  String get tenantFacilityLogoHelper =>
      'Upload un square image (JPG, PNG, ou WebP, up à 5 MB).';

  @override
  String get tenantFacilityChooseLogoAction => 'Choose image';

  @override
  String get tenantFacilityRemoveLogoAction => 'Retirer';

  @override
  String get tenantFacilityLogoUrlLabel => 'Logo storage URL';

  @override
  String get tenantFacilityLogoUrlHelper =>
      'Use un URL créé by le approuvé storage service.';

  @override
  String get tenantFacilityAddressLineLabel => 'Address line';

  @override
  String get tenantFacilityCityLabel => 'City';

  @override
  String get tenantFacilityCountryLabel => 'Country';

  @override
  String get tenantFacilitySaveFacilityAction => 'Save établissement';

  @override
  String get tenantFacilityFacilitySelectLabel => 'Facility';

  @override
  String get tenantFacilityCreateAction => 'Créer';

  @override
  String get tenantFacilitySaveAction => 'Enregistrer';

  @override
  String get tenantFacilityEditAction => 'Modifier';

  @override
  String get tenantFacilityDeleteAction => 'Supprimer';

  @override
  String get tenantFacilityDeleteConfirmAction => 'Supprimer';

  @override
  String get tenantFacilityDeleteConfirmationTitle => 'Delete dossier';

  @override
  String get tenantFacilityDeleteConfirmationBody =>
      'Ce setup dossier will be removed.';

  @override
  String get tenantFacilityNoSelectionLabel => 'Aucun';

  @override
  String get tenantFacilitySearchLabel => 'Rechercher';

  @override
  String get tenantFacilityClearSearchAction => 'Clear recherche';

  @override
  String get tenantFacilitySearchNoResults => 'No matching dossiers found.';

  @override
  String get tenantFacilityStatusActive => 'Actif';

  @override
  String get tenantFacilityStatusInactive => 'Inactif';

  @override
  String get tenantFacilityBranchesSectionTitle => 'Branches';

  @override
  String get tenantFacilityBranchesSectionBody =>
      'Add succursale entry points pour établissements cette operate across sites.';

  @override
  String get tenantFacilityNoBranches => 'No succursales have been added.';

  @override
  String get tenantFacilityBranchNameLabel => 'Branch nom';

  @override
  String get tenantFacilityBranchesListTitle => 'Branch dossiers';

  @override
  String get tenantFacilityBranchSearchHint =>
      'Search succursales by nom ou statut';

  @override
  String get tenantFacilityAddBranchAction => 'Add succursale';

  @override
  String get tenantFacilityAddBranchTitle => 'Add succursale';

  @override
  String get tenantFacilityEditBranchTitle => 'Edit succursale';

  @override
  String get tenantFacilityDepartmentsSectionTitle => 'Departments et unités';

  @override
  String get tenantFacilityDepartmentsSectionBody =>
      'Create départements first, then ajouter unités under le établissement.';

  @override
  String get tenantFacilityNoDepartments => 'No départements have been added.';

  @override
  String get tenantFacilityNoUnits => 'No unités have been added.';

  @override
  String get tenantFacilityDepartmentsListTitle => 'Departments';

  @override
  String get tenantFacilityDepartmentsModalBody =>
      'Manage département dossiers pour le selected établissement.';

  @override
  String get tenantFacilityDepartmentSearchHint =>
      'Search départements by nom, type, succursale, ou statut';

  @override
  String get tenantFacilityUnitsListTitle => 'Units';

  @override
  String get tenantFacilityUnitsModalBody =>
      'Manage unités under établissement départements.';

  @override
  String get tenantFacilityUnitSearchHint =>
      'Search unités by nom, département, ou statut';

  @override
  String get tenantFacilityDepartmentNameLabel => 'Department nom';

  @override
  String get tenantFacilityDepartmentShortNameLabel => 'Short nom';

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
  String get tenantFacilityDepartmentTypeOther => 'Autre';

  @override
  String get tenantFacilityAddDepartmentAction => 'Add département';

  @override
  String get tenantFacilityAddDepartmentTitle => 'Add département';

  @override
  String get tenantFacilityEditDepartmentTitle => 'Edit département';

  @override
  String get tenantFacilityUnitNameLabel => 'Unit nom';

  @override
  String get tenantFacilityUnitDepartmentLabel => 'Department';

  @override
  String get tenantFacilityAddUnitAction => 'Add unité';

  @override
  String get tenantFacilityAddUnitTitle => 'Add unité';

  @override
  String get tenantFacilityEditUnitTitle => 'Edit unité';

  @override
  String get tenantFacilityLocationsSectionTitle => 'Rooms, services, et lits';

  @override
  String get tenantFacilityLocationsSectionBody =>
      'Use le location setup entry points après établissement identity et départements are in place.';

  @override
  String get tenantFacilityRoomsLabel => 'Rooms';

  @override
  String get tenantFacilityWardsLabel => 'Wards';

  @override
  String get tenantFacilityBedsLabel => 'Beds';

  @override
  String get tenantFacilityNoWards => 'No services have been added.';

  @override
  String get tenantFacilityWardsModalBody =>
      'Manage service dossiers et département assignments.';

  @override
  String get tenantFacilityWardSearchHint =>
      'Search services by nom, type, département, ou statut';

  @override
  String get tenantFacilityNoRooms => 'No chambres have been added.';

  @override
  String get tenantFacilityRoomsModalBody =>
      'Manage chambres et their service assignments.';

  @override
  String get tenantFacilityRoomSearchHint =>
      'Search chambres by nom, service, floor, ou statut';

  @override
  String get tenantFacilityNoBeds => 'No lits have been added.';

  @override
  String get tenantFacilityBedsModalBody =>
      'Manage lit libellés, chambre links, et availability statut.';

  @override
  String get tenantFacilityBedSearchHint =>
      'Search lits by libellé, service, chambre, ou statut';

  @override
  String get tenantFacilityAddWardAction => 'Add service';

  @override
  String get tenantFacilityAddWardTitle => 'Add service';

  @override
  String get tenantFacilityEditWardTitle => 'Edit service';

  @override
  String get tenantFacilityWardNameLabel => 'Ward nom';

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
  String get tenantFacilityWardTypeOther => 'Autre';

  @override
  String get tenantFacilityAddRoomAction => 'Add chambre';

  @override
  String get tenantFacilityAddRoomTitle => 'Add chambre';

  @override
  String get tenantFacilityEditRoomTitle => 'Edit chambre';

  @override
  String get tenantFacilityRoomNameLabel => 'Room nom';

  @override
  String get tenantFacilityRoomWardLabel => 'Service';

  @override
  String get tenantFacilityRoomFloorLabel => 'Floor';

  @override
  String get tenantFacilityAddBedAction => 'Add lit';

  @override
  String get tenantFacilityAddBedTitle => 'Add lit';

  @override
  String get tenantFacilityEditBedTitle => 'Edit lit';

  @override
  String get tenantFacilityBedLabelLabel => 'Bed libellé';

  @override
  String get tenantFacilityBedWardLabel => 'Service';

  @override
  String get tenantFacilityBedRoomLabel => 'Chambre';

  @override
  String get tenantFacilityBedStatusLabel => 'Bed statut';

  @override
  String get tenantFacilityBedStatusAvailable => 'Available';

  @override
  String get tenantFacilityBedStatusOccupied => 'Occupied';

  @override
  String get tenantFacilityBedStatusReserved => 'Reserved';

  @override
  String get tenantFacilityBedStatusOutOfService => 'Out sur service';

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
  String get routeAuthRequiredTitle => 'Sign-in requis';

  @override
  String get routeAuthRequiredBody => 'Sign in à ouvrir ce page.';

  @override
  String get routeForbiddenTitle => 'Access denied';

  @override
  String get routeForbiddenBody => 'You do not have accès à ce page.';

  @override
  String get routeNotFoundTitle => 'Page introuvable';

  @override
  String get routeNotFoundBody => 'Ce route is not disponible.';

  @override
  String get authLoginTitle => 'Se connecter';

  @override
  String get authLoginBody =>
      'Use votre établissement compte à ouvrir le HMS espace de travail.';

  @override
  String get authIdentifierLabel => 'Email ou téléphone';

  @override
  String get authEmailLabel => 'E-mail';

  @override
  String get authPasswordLabel => 'Mot de passe';

  @override
  String get authShowPasswordLabel => 'Show mot de passe';

  @override
  String get authHidePasswordLabel => 'Hide mot de passe';

  @override
  String get authLoginActionLabel => 'Se connecter';

  @override
  String get authCreateAccountActionLabel => 'Create compte';

  @override
  String get authRegisterTitle => 'Create établissement compte';

  @override
  String get authRegisterBody =>
      'Register le first administrator pour un établissement espace de travail.';

  @override
  String get authRegisterActionLabel => 'Create compte';

  @override
  String get authBackToLoginActionLabel => 'Back à se connecter';

  @override
  String get authVerifyEmailActionLabel => 'Verify';

  @override
  String get authSendNewCodeActionLabel => 'Send nouveau code';

  @override
  String get authVerifyEmailTitle => 'Verify votre e-mail';

  @override
  String get authEmailVerifiedTitle => 'Email vérifié';

  @override
  String authVerifyEmailBody(String email) {
    return 'Enter le vérification code sent à $email.';
  }

  @override
  String authPendingVerificationBody(String email) {
    return 'This email est déjà registered but has not been verified. Enter the verification code sent to $email.';
  }

  @override
  String get authVerifyEmailBodyNoEmail =>
      'Enter le vérification code sent à votre e-mail.';

  @override
  String get authEmailVerifiedBody =>
      'Votre compte is vérifié. You can now se connecter.';

  @override
  String get authEmailVerifiedAwaitingApprovalBody =>
      'Votre e-mail is vérifié. Un platform administrator will review votre inscription avant you can se connecter.';

  @override
  String get authAccountPendingApprovalMessage =>
      'Votre e-mail is vérifié. Votre compte is en attente de platform approbation avant you can se connecter.';

  @override
  String get authTenantNameLabel => 'Organization nom';

  @override
  String get authPhoneLabel => 'Phone';

  @override
  String get authVerificationCodeResentMessage =>
      'Un nouveau vérification code has been sent.';

  @override
  String get authVerificationCodeLabel => 'Verification code';

  @override
  String get authVerificationCodeInvalidMessage =>
      'Enter le 6-digit vérification code.';

  @override
  String get authAccountPendingMessage =>
      'This email est déjà registered but has not been verified. Enter the email verification code we sent to continue.';

  @override
  String get authAdminNameLabel => 'Administrator nom';

  @override
  String get authFacilityNameLabel => 'Facility nom';

  @override
  String get authFacilityTypeLabel => 'Facility type';

  @override
  String get authFacilityTypeHospital => 'Hospital';

  @override
  String get authFacilityTypeClinic => 'Clinic';

  @override
  String get authFacilityTypeLab => 'Lab';

  @override
  String get authFacilityTypePharmacy => 'Pharmacie';

  @override
  String get authFacilityTypeOther => 'Autre';

  @override
  String get authPhoneOptionalLabel => 'Phone (facultatif)';

  @override
  String get authLocationOptionalLabel => 'Location (facultatif)';

  @override
  String get authRegistrationSubmittedTitle => 'Check votre e-mail';

  @override
  String get authRegistrationSubmittedBody =>
      'We sent un vérification code avant le espace de travail can be utilisé.';

  @override
  String get authChangePasswordTitle => 'Change mot de passe';

  @override
  String get authCurrentPasswordLabel => 'Current mot de passe';

  @override
  String get authNewPasswordLabel => 'New mot de passe';

  @override
  String get authConfirmPasswordLabel => 'Confirm mot de passe';

  @override
  String get authChangePasswordActionLabel => 'Change mot de passe';

  @override
  String get authPasswordChangedMessage => 'Password changed. Sign in again.';

  @override
  String get authInvalidCredentialsMessage =>
      'Le sign-in détails are not valid.';

  @override
  String get authAccountNotFoundMessage =>
      'No compte exists pour cette e-mail ou téléphone. Check le détails ou créer un compte.';

  @override
  String get authWrongPasswordMessage =>
      'Le mot de passe is incorrect pour ce compte.';

  @override
  String get authRateLimitedMessage =>
      'Too many sign-in attempts. Please wait un moment et réessayer.';

  @override
  String get authForbiddenMessage =>
      'Ce compte ne peut pas complete cette action.';

  @override
  String get authEmailInvalidMessage => 'Enter un valid e-mail adresse.';

  @override
  String get authPasswordMinLengthMessage => 'Use at least 8 characters.';

  @override
  String get authPasswordMismatchMessage => 'Passwords do not match.';

  @override
  String get authForgotPasswordTitle => 'Reset votre mot de passe';

  @override
  String get authForgotPasswordBody =>
      'Enter le e-mail on votre établissement compte. If it matches un compte, we will send reset instructions.';

  @override
  String get authForgotPasswordActionLabel => 'Forgot mot de passe?';

  @override
  String get authForgotPasswordSubmitLabel => 'Send reset instructions';

  @override
  String get authForgotPasswordTenantPrompt =>
      'Choose le espace de travail pour ce compte.';

  @override
  String get authForgotPasswordSubmittedTitle => 'Check votre e-mail';

  @override
  String get authForgotPasswordSubmittedBody =>
      'If un compte exists pour cette e-mail, reset instructions avec un secure link et un six-digit code have been sent.';

  @override
  String get authResetPasswordWithCodeActionLabel => 'Enter reset code';

  @override
  String get authResetPasswordTitle => 'Choose un nouveau mot de passe';

  @override
  String get authResetPasswordBody =>
      'Enter un nouveau mot de passe pour votre compte.';

  @override
  String get authResetPasswordCodeModeBody =>
      'Enter votre e-mail, le six-digit reset code de votre e-mail, et un nouveau mot de passe.';

  @override
  String get authResetPasswordCodeLabel => 'Reset code';

  @override
  String get authResetPasswordCodeInvalidMessage =>
      'Enter le six-digit reset code de votre e-mail.';

  @override
  String get authResetPasswordActionLabel => 'Reset mot de passe';

  @override
  String get authResetPasswordMissingTokenMessage =>
      'Ce reset link is missing ou invalide. Request un nouveau mot de passe reset de le sign-in page.';

  @override
  String get authResetPasswordCompletedTitle => 'Password mis à jour';

  @override
  String get authResetPasswordCompletedBody =>
      'Votre mot de passe has been changed. Sign in avec le nouveau mot de passe.';

  @override
  String get authResetPasswordInvalidTokenMessage =>
      'Ce reset link has expiré ou is invalide. Request un nouveau mot de passe reset.';

  @override
  String opdFieldRequiredLabel(String label) {
    return '$label (requis)';
  }

  @override
  String opdFieldOptionalLabel(String label) {
    return '$label (facultatif)';
  }

  @override
  String get opdVitalsAtLeastOneRequiredHelper =>
      'Enter at least one vital sign.';

  @override
  String get validationRequired => 'Ce champ est requis.';

  @override
  String get errorNetworkTitle => 'Connection problem';

  @override
  String get errorNetworkMessage => 'Check votre connexion et réessayer.';

  @override
  String get errorTimeoutTitle => 'Request timed out';

  @override
  String get errorTimeoutMessage => 'Le demande took too long. Try again.';

  @override
  String get errorOfflineTitle => 'No connexion';

  @override
  String get errorOfflineMessage => 'Connect à le internet et réessayer.';

  @override
  String get errorCancelledTitle => 'Request annulé';

  @override
  String get errorCancelledMessage => 'Le demande was annulé.';

  @override
  String get errorUnauthorizedTitle => 'Sign-in requis';

  @override
  String get errorUnauthorizedMessage => 'Sign in again à continuer.';

  @override
  String get errorForbiddenTitle => 'Access denied';

  @override
  String get errorForbiddenMessage => 'You do not have autorisation.';

  @override
  String get errorNotFoundTitle => 'Not found';

  @override
  String get errorNotFoundMessage => 'Le élément is not disponible.';

  @override
  String get errorValidationTitle => 'Check le détails';

  @override
  String get errorValidationMessage => 'Check le highlighted détails.';

  @override
  String get errorUnexpectedResponseTitle => 'Unexpected réponse';

  @override
  String get errorUnexpectedResponseMessage => 'Try again later.';

  @override
  String get errorStorageTitle => 'Storage indisponible';

  @override
  String get errorStorageMessage =>
      'Local data n\'a pas pu être accessed. Try again.';

  @override
  String get errorUnexpectedTitle => 'Something went wrong';

  @override
  String get errorUnexpectedMessage => 'Something went wrong. Try again.';

  @override
  String get navigationClinicalLabel => 'Clinical notes';

  @override
  String get navigationClinicalShortLabel => 'Clinical';

  @override
  String get clinicalTitle => 'Clinical espace de travail';

  @override
  String get clinicalDescription =>
      'Review clinique queues, document soins, commande services, prescribe, refer, admettre, et complete consultations.';

  @override
  String get clinicalLoadingTitle => 'Loading clinique espace de travail';

  @override
  String get clinicalLoadingBody =>
      'Loading prestataire worklist et consultation context.';

  @override
  String get clinicalLiveStatus => 'Live synchronisation';

  @override
  String get clinicalSavingStatus => 'Saving';

  @override
  String get clinicalSavedMessage => 'Clinical changes saved.';

  @override
  String get clinicalPatientIdCopiedMessage => 'Patient ID copied.';

  @override
  String get clinicalFiltersLabel => 'Clinical filtres';

  @override
  String get clinicalSearchLabel => 'Search clinique worklist';

  @override
  String get clinicalSearchHint =>
      'Patient, consultation, queue, prestataire, ou location';

  @override
  String get clinicalScopeFilterLabel => 'Queue scope';

  @override
  String get clinicalAllScopeLabel => 'All actif work';

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
  String get clinicalCompletedSummaryLabel => 'Terminé';

  @override
  String get clinicalWorklistTitle => 'Provider worklist';

  @override
  String get clinicalWorklistDescription =>
      'Open consultations, admissions, triage passations, et résultat-review queues.';

  @override
  String get clinicalNoWorklistTitle => 'No clinique work';

  @override
  String get clinicalNoWorklistBody =>
      'No consultations match le actuel recherche et queue scope.';

  @override
  String get clinicalNoSelectionTitle => 'No consultation selected';

  @override
  String get clinicalNoSelectionBody =>
      'Open un patient de le worklist à review context, document soins, et place commandes.';

  @override
  String get clinicalSourceQueueLabel => 'Queue';

  @override
  String get clinicalEncounterQueueLabel => 'Encounter queue';

  @override
  String get clinicalLastUpdatedLabel => 'Last mis à jour';

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
  String get clinicalAddNoteAction => 'Add clinique note';

  @override
  String get clinicalAddNoteTitle => 'Add patient clinique note';

  @override
  String get clinicalAddDiagnosisAction => 'Add diagnostic';

  @override
  String get clinicalDiagnosisSearchLabel => 'Search diagnostic';

  @override
  String get clinicalDiagnosisSearchHint =>
      'Search by diagnostic nom, code, type, statut, ou source';

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
      'Choose which diagnoses, procedures, laboratoire tests, radiologie tests, et prescriptions ce établissement offers.';

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
  String get clinicalDiagnosisNoCatalogOptions =>
      'No matching diagnostic terms';

  @override
  String get clinicalRequestLabAction => 'Request laboratoire';

  @override
  String get clinicalUpdateLabOrderAction => 'Update laboratoire commande';

  @override
  String get clinicalLabRequestTestsModeLabel => 'Individual tests';

  @override
  String get clinicalLabRequestPanelsModeLabel => 'Lab panels';

  @override
  String get clinicalLabRequestSearchLabel => 'Search laboratoire catalog';

  @override
  String get clinicalLabRequestSearchHint =>
      'Search by nom, code, catégorie, specimen, ou statut';

  @override
  String get clinicalLabRequestSelectedTitle => 'Selected laboratoire demandes';

  @override
  String clinicalLabRequestSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String get clinicalLabRequestNoSelection =>
      'No laboratoire demandes selected';

  @override
  String get clinicalLabRequestAddSelectionAction => 'Ajouter';

  @override
  String get clinicalLabRequestUpdateSelectionAction => 'Mettre à jour';

  @override
  String get clinicalLabRequestCancelEditAction => 'Cancel modifier';

  @override
  String get clinicalLabRequestEditSelectionAction => 'Modifier';

  @override
  String get clinicalLabRequestDeleteSelectionAction => 'Supprimer';

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
      'No matching laboratoire catalog éléments';

  @override
  String get clinicalLabOrdersTitle => 'Lab commandes';

  @override
  String get clinicalLabOrdersBody =>
      'Requested laboratoire commandes pour ce patient.';

  @override
  String get clinicalNoLabOrdersLabel =>
      'No laboratoire commandes have been requested pour ce patient.';

  @override
  String get clinicalLabOrderTestsLabel => 'Requested laboratoire tests';

  @override
  String get clinicalLabOrderPanelsLabel => 'Requested laboratoire panels';

  @override
  String get clinicalNoLabOrderTestsLabel =>
      'No requested laboratoire tests recorded.';

  @override
  String get clinicalNoLabOrderPanelsLabel =>
      'No requested laboratoire panels recorded.';

  @override
  String clinicalLabOrderItemCount(int count) {
    return '$count tests';
  }

  @override
  String clinicalLabOrderSampleCount(int count) {
    return '$count samples';
  }

  @override
  String get clinicalEditLabOrderAction => 'Edit commande';

  @override
  String get clinicalCancelLabOrderAction => 'Cancel commande';

  @override
  String get clinicalDeleteLabOrderAction => 'Delete commande';

  @override
  String get clinicalCancelLabOrderDialogTitle => 'Cancel laboratoire commande';

  @override
  String get clinicalCancelLabOrderDialogBody =>
      'Cancel ce laboratoire commande et mark its requested tests as annulé?';

  @override
  String get clinicalDeleteLabOrderDialogTitle => 'Delete laboratoire commande';

  @override
  String get clinicalDeleteLabOrderDialogBody =>
      'Delete ce laboratoire commande de le actif patient dossier?';

  @override
  String get clinicalRadiologyOrdersTitle => 'Radiology commandes';

  @override
  String get clinicalCancelRadiologyOrderAction => 'Cancel commande';

  @override
  String get clinicalDeleteRadiologyOrderAction => 'Delete commande';

  @override
  String get clinicalCancelRadiologyOrderDialogTitle =>
      'Cancel radiologie commande';

  @override
  String get clinicalCancelRadiologyOrderDialogBody =>
      'Cancel ce radiologie commande et mark it as annulé?';

  @override
  String get clinicalDeleteRadiologyOrderDialogTitle =>
      'Delete radiologie commande';

  @override
  String get clinicalDeleteRadiologyOrderDialogBody =>
      'Delete ce radiologie commande de le actif patient dossier?';

  @override
  String clinicalRadiologyOrderItemCount(int count) {
    return '$count tests';
  }

  @override
  String get clinicalPharmacyOrdersTitle => 'Pharmacy commandes';

  @override
  String clinicalPharmacyOrderItemCount(int count) {
    return '$count medicines';
  }

  @override
  String get clinicalCancelPharmacyOrderAction => 'Cancel commande';

  @override
  String get clinicalDeletePharmacyOrderAction => 'Delete commande';

  @override
  String get clinicalCancelPharmacyOrderDialogTitle =>
      'Cancel pharmacie commande';

  @override
  String get clinicalCancelPharmacyOrderDialogBody =>
      'Cancel ce pharmacie commande et mark it as annulé?';

  @override
  String get clinicalDeletePharmacyOrderDialogTitle =>
      'Delete pharmacie commande';

  @override
  String get clinicalDeletePharmacyOrderDialogBody =>
      'Delete ce pharmacie commande de le actif patient dossier?';

  @override
  String get clinicalRequestRadiologyAction => 'Request radiologie';

  @override
  String get clinicalRadiologyRequestSearchLabel => 'Search radiologie catalog';

  @override
  String get clinicalRadiologyRequestSearchHint =>
      'Search by test, intervention, modality, region, code, ou priorité';

  @override
  String get clinicalRadiologyRequestSelectedTitle =>
      'Selected radiologie demandes';

  @override
  String clinicalRadiologyRequestSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String get clinicalRadiologyRequestNoSelection =>
      'No radiologie demandes selected';

  @override
  String get clinicalRadiologyAddSelectionAction => 'Ajouter';

  @override
  String get clinicalRadiologyUpdateSelectionAction => 'Mettre à jour';

  @override
  String get clinicalRadiologyCancelEditAction => 'Cancel modifier';

  @override
  String get clinicalRadiologyEditSelectionAction => 'Modifier';

  @override
  String get clinicalRadiologyDeleteSelectionAction => 'Supprimer';

  @override
  String clinicalRadiologyRequestMatchesLabel(int shown, int total) {
    return 'Showing $shown of $total matches';
  }

  @override
  String get clinicalRadiologyRequestNoCatalogOptions =>
      'No matching radiologie catalog éléments';

  @override
  String get clinicalRadiologyCatalogSelectTitle => 'Radiology catalog';

  @override
  String get clinicalRadiologyCatalogSelectBody =>
      'Search et sélectionner one matching imaging test, then ajouter it à le demande liste.';

  @override
  String get clinicalRadiologyCatalogSelectLabel => 'Imaging test';

  @override
  String get clinicalRadiologyCatalogSelectHint =>
      'Search et sélectionner un imaging test';

  @override
  String get clinicalRadiologyDuplicateSelectionMessage =>
      'This imaging request est déjà selected.';

  @override
  String get clinicalRadiologyPriorityLabel => 'Priority';

  @override
  String get clinicalRadiologyLateralityLabel => 'Laterality';

  @override
  String get clinicalRadiologyBodyRegionLabel => 'Body region';

  @override
  String get clinicalPrescribeAction => 'Prescribe';

  @override
  String get clinicalPrescriptionHeaderTitle => 'Build ordonnance';

  @override
  String get clinicalPrescriptionHeaderBody =>
      'Add one ou more medicines, then send them together à pharmacie.';

  @override
  String get clinicalPrescriptionDrugLabel => 'Available drug';

  @override
  String get clinicalPrescriptionMedicineLabel => 'Medicine';

  @override
  String get clinicalPrescriptionItemDescription =>
      'Select un drug et complete le ordonnance détails.';

  @override
  String get clinicalPrescriptionQuantityUnitLabel => 'Quantity unité';

  @override
  String get clinicalPrescriptionAddMedicineAction => 'Add medicine';

  @override
  String get clinicalPrescriptionRemoveMedicineAction => 'Remove medicine';

  @override
  String get clinicalRequestProcedureAction => 'Record procédure';

  @override
  String get clinicalProcedureDialogHelp =>
      'Search le procédure catalog, ajouter one ou more procedures à le review liste, then enregistrer them together.';

  @override
  String get clinicalProcedureSearchLabel => 'Procedure ou minor surgery';

  @override
  String get clinicalProcedureSearchHint =>
      'Search by nom, corps area, ou minor surgery type';

  @override
  String get clinicalProcedureCodeSearchHint => 'Search by procédure code';

  @override
  String get clinicalProcedureSelectedTitle => 'Selected procedures';

  @override
  String clinicalProcedureSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String get clinicalProcedureNoSelection => 'No procedures selected';

  @override
  String get clinicalCarePlanAction => 'Care forfait';

  @override
  String get clinicalRequestAdmissionAction => 'Request admission';

  @override
  String get clinicalCompleteConsultationAction => 'Complete consultation';

  @override
  String get clinicalCompleteDispositionAction => 'Complete disposition';

  @override
  String get clinicalPrintSummaryAction => 'Print résumé';

  @override
  String get clinicalResultReviewTitle => 'Result review';

  @override
  String get clinicalResultReviewBody =>
      'Released diagnostic résultats are ready pour clinique review.';

  @override
  String get clinicalNoResultsReadyBody =>
      'No released laboratoire ou radiologie résultats are ready pour review.';

  @override
  String get clinicalPatientNotesTitle => 'Patient clinique notes';

  @override
  String get clinicalNoPatientNotesLabel =>
      'No patient clinique notes have been recorded yet.';

  @override
  String get clinicalDiagnosesTitle => 'Diagnoses';

  @override
  String get clinicalPatientDiagnosesTitle => 'Patient diagnoses';

  @override
  String get clinicalNoPatientDiagnosesLabel =>
      'No diagnoses have been recorded pour ce patient yet.';

  @override
  String get clinicalDiagnosisFormTitle => 'Diagnosis détails';

  @override
  String get clinicalCarePlansTitle => 'Care forfaits';

  @override
  String get clinicalOrdersTitle => 'Orders';

  @override
  String get clinicalHandoffsTitle => 'Handoffs';

  @override
  String get clinicalTermSearchLabel => 'Clinical term';

  @override
  String get clinicalCarePlanLabel => 'Care forfait';

  @override
  String get clinicalDoseAmountLabel => 'Dose montant';

  @override
  String get clinicalDoseUnitLabel => 'Dose unité';

  @override
  String get clinicalDurationValueLabel => 'Duration';

  @override
  String get clinicalDurationUnitLabel => 'Duration unité';

  @override
  String get clinicalInstructionsLabel => 'Instructions';

  @override
  String get clinicalAvailableBedLabel => 'Available lit';

  @override
  String get clinicalAdmissionDetailsTitle => 'Admission détails';

  @override
  String get clinicalAdmissionWardLabel => 'Service';

  @override
  String get clinicalAdmissionRoomLabel => 'Chambre';

  @override
  String get clinicalAdmissionBedLabel => 'Lit';

  @override
  String get clinicalAdmissionAvailabilityLabel => 'Bed availability';

  @override
  String get clinicalAdmissionNoBedsTitle => 'No disponible lits';

  @override
  String get clinicalAdmissionNoBedsMessage =>
      'No disponible lits found. Refresh lit availability avant requesting admission.';

  @override
  String get clinicalAdmissionNoRoomsMessage =>
      'No chambres avec disponible lits match ce service.';

  @override
  String get clinicalAdmissionNoBedsForRoomMessage =>
      'No disponible lits match ce chambre.';

  @override
  String get clinicalAdmissionBedUnavailableMessage =>
      'Ce lit is non longer disponible. Please choose another lit.';

  @override
  String get clinicalDispositionReasonLabel => 'Disposition reason';

  @override
  String get clinicalConsultationSummaryTitle => 'Consultation résumé';

  @override
  String get navigationIpdLabel => 'Inpatient (IPD)';

  @override
  String get navigationIpdShortLabel => 'IPD';

  @override
  String get ipdTitle => 'Inpatient espace de travail';

  @override
  String get ipdDescription =>
      'Manage admission queues, lits, transferts, service rounds, soins infirmiers passations, médicament dossiers, et sortie readiness.';

  @override
  String get ipdLoadingTitle => 'Loading hospitalisé espace de travail';

  @override
  String get ipdLoadingBody => 'Loading admissions, lits, et service context.';

  @override
  String get ipdLiveStatus => 'Live synchronisation';

  @override
  String get ipdSavingStatus => 'Saving';

  @override
  String get ipdSavedMessage => 'Inpatient changes saved.';

  @override
  String get ipdAdmissionQueueSummaryLabel => 'Waiting lit';

  @override
  String get ipdActivePatientsSummaryLabel => 'In lits';

  @override
  String get ipdTransferPendingSummaryLabel => 'Transfers';

  @override
  String get ipdDischargePlannedSummaryLabel => 'Discharge planned';

  @override
  String get ipdCriticalAlertsSummaryLabel => 'Critical alerts';

  @override
  String get ipdFiltersLabel => 'Inpatient filtres';

  @override
  String get ipdSearchLabel => 'Search admissions';

  @override
  String get ipdSearchHint =>
      'Patient, admission, consultation, service, ou lit';

  @override
  String get ipdScopeFilterLabel => 'Board scope';

  @override
  String get ipdWardFilterLabel => 'Service';

  @override
  String get ipdAllWardsOption => 'All services';

  @override
  String get ipdBoardTitle => 'Inpatient board';

  @override
  String get ipdBoardDescription =>
      'Track waiting admissions, bedded patients, transferts, service activity, et sortie forfaits.';

  @override
  String get ipdNoAdmissionsTitle => 'No admissions';

  @override
  String get ipdNoAdmissionsBody =>
      'No hospitalisé admissions match le actuel filtres.';

  @override
  String get ipdLocationColumnLabel => 'Ward et lit';

  @override
  String get ipdPendingActionColumnLabel => 'Next action';

  @override
  String get ipdAdmittedAtColumnLabel => 'Admitted';

  @override
  String get ipdAdmissionDetailTitle => 'Admission detail';

  @override
  String get ipdAdmissionDetailDescription =>
      'Review lit statut, transferts, service rounds, médicament dossiers, soins infirmiers notes, et sortie state.';

  @override
  String get ipdNoSelectionTitle => 'No admission selected';

  @override
  String get ipdNoSelectionBody =>
      'Open un admission de le board à manage hospitalisé soins.';

  @override
  String get ipdPatientContextLabel => 'Patient context';

  @override
  String get ipdAdmissionIdLabel => 'Admission';

  @override
  String get ipdEncounterIdLabel => 'Encounter';

  @override
  String get ipdWardBedLabel => 'Ward et lit';

  @override
  String get ipdFacilityLabel => 'Facility';

  @override
  String get ipdIcuStatusLabel => 'ICU statut';

  @override
  String get ipdAssignBedAction => 'Assign lit';

  @override
  String get ipdReleaseBedAction => 'Release lit';

  @override
  String get ipdRejectAdmissionAction => 'Reject admission';

  @override
  String get ipdRequestTransferAction => 'Request transfert';

  @override
  String get ipdRequestTherapyAction => 'Request physiothérapie';

  @override
  String get ipdOpenPhysiotherapyAction => 'Open physiothérapie';

  @override
  String get ipdManageTransferAction => 'Manage transfert';

  @override
  String get ipdAddWardRoundAction => 'Add service round';

  @override
  String get ipdAddNursingNoteAction => 'Add soins infirmiers note';

  @override
  String get ipdRecordMedicationAction => 'Record médicament';

  @override
  String get ipdPlanDischargeAction => 'Plan sortie';

  @override
  String get ipdFinalizeDischargeAction => 'Finalize sortie';

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
  String get ipdDischargeSectionTitle => 'Sortie';

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
      one: '1 ouvrir commande',
    );
    return '$_temp0';
  }

  @override
  String get ipdTimelineSectionTitle => 'Timeline';

  @override
  String get ipdNoTransfersTitle => 'No transferts';

  @override
  String get ipdNoTransfersBody =>
      'No transfert demandes are recorded pour ce admission.';

  @override
  String get ipdNoRoundsTitle => 'No service rounds';

  @override
  String get ipdNoRoundsBody => 'No service rounds have been documented yet.';

  @override
  String get ipdNoNursingNotesTitle => 'No soins infirmiers notes';

  @override
  String get ipdNoNursingNotesBody =>
      'No soins infirmiers notes have been documented yet.';

  @override
  String get ipdNoMedicationTitle => 'No médicament dossiers';

  @override
  String get ipdNoMedicationBody =>
      'No médicament administrations are recorded pour ce admission.';

  @override
  String get ipdNoTimelineTitle => 'No timeline entries';

  @override
  String get ipdNoTimelineBody => 'No soins activity has been recorded yet.';

  @override
  String get ipdBedFieldLabel => 'Lit';

  @override
  String get ipdSelectBedHint => 'Select un lit';

  @override
  String get ipdReleaseBedConfirmationBody =>
      'Release le actuel lit assignment pour ce admission?';

  @override
  String get ipdTargetWardFieldLabel => 'Target service';

  @override
  String get ipdSelectWardHint => 'Select un service';

  @override
  String get ipdTransferActionFieldLabel => 'Transfer action';

  @override
  String get ipdDestinationBedFieldLabel => 'Destination lit';

  @override
  String get ipdNotesFieldLabel => 'Notes';

  @override
  String get ipdSummaryFieldLabel => 'Summary';

  @override
  String get ipdReasonFieldLabel => 'Reason';

  @override
  String get ipdMedicationOrderFieldLabel => 'Medication commande';

  @override
  String get ipdMedicationOrderHint => 'Select un suggested commande';

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
  String get ipdMedicationStatusFieldLabel => 'Statut';

  @override
  String get ipdDischargedAtLabel => 'Discharged';

  @override
  String get ipdScopeAdmissionQueue => 'Waiting lit';

  @override
  String get ipdScopeActivePatients => 'In lits';

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
  String get ipdStatusAdmittedPendingBed => 'Waiting lit';

  @override
  String get ipdStatusAdmittedInBed => 'In lit';

  @override
  String get ipdStatusTransferRequested => 'Transfer requested';

  @override
  String get ipdStatusTransferInProgress => 'Transfer in progress';

  @override
  String get ipdStatusDischargePlanned => 'Discharge planned';

  @override
  String get ipdStatusDischarged => 'Discharged';

  @override
  String get ipdStatusCancelled => 'Annulé';

  @override
  String get ipdNextAssignBed => 'Assign lit';

  @override
  String get ipdNextRecordNursingNote => 'Record soins infirmiers note';

  @override
  String get ipdNextApproveTransfer => 'Approve transfert';

  @override
  String get ipdNextStartTransfer => 'Start transfert';

  @override
  String get ipdNextCompleteTransfer => 'Complete transfert';

  @override
  String get ipdNextFinalizeDischarge => 'Finalize sortie';

  @override
  String get ipdNextContinueCare => 'Continue soins';

  @override
  String get ipdBedStatusAvailable => 'Available';

  @override
  String get ipdBedStatusOccupied => 'Occupied';

  @override
  String get ipdBedStatusReserved => 'Reserved';

  @override
  String get ipdBedStatusOutOfService => 'Out sur service';

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
      'Live service lit occupation et lit operations.';

  @override
  String get ipdBedBoardSearchLabel => 'Search lits';

  @override
  String get ipdBedBoardSearchHint =>
      'Search by lit, service, chambre, ou patient';

  @override
  String get ipdBedBoardEmptyTitle => 'No lits match';

  @override
  String get ipdBedBoardEmptyBody =>
      'Adjust le service ou statut filtre à see more lits.';

  @override
  String get ipdBedColumnLabel => 'Lit';

  @override
  String get ipdWardColumnLabel => 'Service';

  @override
  String get ipdRoomColumnLabel => 'Chambre';

  @override
  String get ipdCurrentPatientColumnLabel => 'Current patient';

  @override
  String get ipdNextActionColumnLabel => 'Next action';

  @override
  String get ipdBedStatusFilterLabel => 'Bed statut';

  @override
  String get ipdBedBoardManageBedsAction => 'Manage lits';

  @override
  String get ipdBedActionReserve => 'Reserve lit';

  @override
  String get ipdBedActionMarkAvailable => 'Mark disponible';

  @override
  String get ipdBedActionMarkCleaning => 'Send pour cleaning';

  @override
  String get ipdBedActionBlock => 'Block lit';

  @override
  String get ipdBedActionMaintenance => 'Mark maintenance';

  @override
  String get ipdBedActionReturnToService => 'Return à service';

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
  String get ipdStartAdmissionPatientHint => 'Search patient by nom ou ID';

  @override
  String get ipdStartAdmissionNoPatients => 'No matching patients';

  @override
  String get ipdStartAdmissionWardLabel => 'Recommended service (facultatif)';

  @override
  String get ipdStartAdmissionBedLabel => 'Bed (facultatif)';

  @override
  String get ipdLengthOfStayColumnLabel => 'Length sur stay';

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
  String get ipdDischargeStatusCompleted => 'Terminé';

  @override
  String get ipdManageDischargeTitle => 'Manage sortie';

  @override
  String get ipdDischargeClearanceTitle => 'Discharge clearance';

  @override
  String get ipdDischargeClearancePhaseLabel => 'Clearance phase';

  @override
  String get ipdPendingOrdersTitle => 'Pending commandes';

  @override
  String get ipdClearancePendingOrders => 'Pending commandes reviewed';

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
      'Required only lorsque clearing avec incomplete steps';

  @override
  String get ipdSaveClearanceAction => 'Save clearance';

  @override
  String get ipdClearancePhaseSummaryPending => 'Summary en attente';

  @override
  String get ipdClearancePhasePendingOrders => 'Pending commandes review';

  @override
  String get ipdClearancePhaseMedication => 'Medication en attente';

  @override
  String get ipdClearancePhaseBilling => 'Billing en attente';

  @override
  String get ipdClearancePhaseNursing => 'Nursing clearance en attente';

  @override
  String get ipdClearancePhaseDocuments => 'Documents en attente';

  @override
  String get ipdClearancePhasePatientExit => 'Patient exit en attente';

  @override
  String get ipdClearancePhaseReadyForExit => 'Ready pour exit';

  @override
  String get ipdOrderLabAction => 'Order laboratoire';

  @override
  String get ipdOrderRadiologyAction => 'Order radiologie';

  @override
  String get ipdOrderPrescriptionAction => 'Prescribe médicament';

  @override
  String get ipdOpenNursingAction => 'Open soins infirmiers espace de travail';

  @override
  String get ipdSourceContextTitle => 'Admission source';

  @override
  String get ipdSourceKindLabel => 'Source';

  @override
  String get ipdEncounterTypeLabel => 'Encounter type';

  @override
  String get ipdSourceKindOpd => 'OPD passation';

  @override
  String get ipdSourceKindEmergency => 'Emergency admission';

  @override
  String get ipdSourceKindReferral => 'Referral';

  @override
  String get ipdSourceKindDirect => 'Direct admission';

  @override
  String get ipdIcuStatusActive => 'Actif';

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
  String get ipdTransferStartAction => 'Start transfert';

  @override
  String get ipdTransferCompleteAction => 'Complete transfert';

  @override
  String get ipdTransferCancelAction => 'Cancel transfert';

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
  String get ipdRouteOther => 'Autre';

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
  String get navigationNursingLabel => 'Soins infirmiers';

  @override
  String get navigationNursingShortLabel => 'Soins infirmiers';

  @override
  String get nursingTitle => 'Soins infirmiers';

  @override
  String get nursingDescription =>
      'Monitor service queues, observations, médicament administration, handovers, transferts, et escalation.';

  @override
  String get nursingLoadingTitle =>
      'Loading soins infirmiers espace de travail';

  @override
  String get nursingLoadingBody =>
      'Loading service patients, observations, médicaments, et handovers.';

  @override
  String get nursingLiveStatus => 'Live synchronisation';

  @override
  String get nursingSavingStatus => 'Saving';

  @override
  String get nursingSavedMessage => 'Nursing changes saved.';

  @override
  String get nursingAssignedWardSummaryLabel => 'Assigned service';

  @override
  String get nursingUrgentSummaryLabel => 'Urgent';

  @override
  String get nursingMedicationDueSummaryLabel => 'Medication due';

  @override
  String get nursingHandoverPendingSummaryLabel => 'Handover en attente';

  @override
  String get nursingTransferPendingSummaryLabel => 'Transfer en attente';

  @override
  String get nursingDischargePendingSummaryLabel => 'Discharge en attente';

  @override
  String get nursingFiltersLabel => 'Nursing filtres';

  @override
  String get nursingSearchLabel => 'Search soins infirmiers worklist';

  @override
  String get nursingSearchHint =>
      'Patient, admission, consultation, service, lit, ou observation';

  @override
  String get nursingScopeFilterLabel => 'Queue scope';

  @override
  String get nursingWardFilterLabel => 'Ward ou lit';

  @override
  String get nursingWardFilterHint => 'Filter by service ou lit';

  @override
  String get nursingScopeAssignedWardLabel => 'Assigned service';

  @override
  String get nursingScopeUrgentLabel => 'Urgent';

  @override
  String get nursingScopeMedicationDueLabel => 'Medication due';

  @override
  String get nursingScopeHandoverPendingLabel => 'Handover en attente';

  @override
  String get nursingScopeTransferPendingLabel => 'Transfer en attente';

  @override
  String get nursingScopeDischargePendingLabel => 'Discharge en attente';

  @override
  String get nursingScopeAllLabel => 'Tous';

  @override
  String get nursingWorklistTitle => 'Ward worklist';

  @override
  String get nursingWorklistDescription =>
      'Patients needing observations, médicament, handover, transfert, ou sortie coordination.';

  @override
  String get nursingNoWorklistTitle => 'No soins infirmiers work';

  @override
  String get nursingNoWorklistBody =>
      'No service patients match le actuel recherche et queue scope.';

  @override
  String get nursingNoSelectionTitle => 'No service patient selected';

  @override
  String get nursingNoSelectionBody =>
      'Open un patient de le worklist à review observations, médicaments, handovers, et service activity.';

  @override
  String get nursingPatientContextLabel =>
      'Selected soins infirmiers patient context';

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
  String get nursingBedLabel => 'Lit';

  @override
  String get nursingActionsTitle => 'Nursing actions';

  @override
  String get nursingActionRecordVitals => 'Record signes vitaux';

  @override
  String get nursingActionAddNote => 'Add note';

  @override
  String get nursingActionAdministerMedication => 'Administer médicament';

  @override
  String get nursingActionCompleteTask => 'Complete task';

  @override
  String get nursingActionCreateHandover => 'Create handover';

  @override
  String get nursingActionEscalate => 'Escalate';

  @override
  String get nursingActionAcknowledgeTransfer => 'Acknowledge transfert';

  @override
  String get nursingActionAcceptHandover => 'Accept handover';

  @override
  String get nursingActionPrintSummary => 'Print soins infirmiers résumé';

  @override
  String get nursingReportTitle => 'Nursing soins résumé';

  @override
  String get nursingReportFooter =>
      'Generated de le soins infirmiers rapport modèle pour clinique audit.';

  @override
  String get nursingObservationsTitle => 'Observations';

  @override
  String get nursingMedicationsTitle => 'Medications';

  @override
  String get nursingNotesTitle => 'Nursing notes';

  @override
  String get nursingCarePlansTitle => 'Care forfaits';

  @override
  String get nursingHandoversTitle => 'Handovers';

  @override
  String get nursingWardActivityTitle => 'Ward activity';

  @override
  String get nursingNoRecordsLabel => 'No dossiers yet';

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
  String get nursingAdministrationStatusLabel => 'Administration statut';

  @override
  String get nursingFrequencyLabel => 'Frequency';

  @override
  String get nursingAdministrationNoteLabel => 'Administration note';

  @override
  String get nursingScheduleRemindersLabel => 'Schedule reminders';

  @override
  String get nursingConfirmMedicationLabel =>
      'Confirm médicament administration';

  @override
  String get nursingConfirmMedicationSubtitle =>
      'Verify le patient, médicament, dose, route, et heure avant saving.';

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
  String get nursingToBedLabel => 'To lit ID';

  @override
  String get nursingConfirmTransferLabel => 'Confirm transfert mettre à jour';

  @override
  String get nursingAdvancedFiltersLabel => 'Filtres';

  @override
  String get nursingAdvancedFiltersTitle => 'Nursing worklist filtres';

  @override
  String get nursingApplyFiltersLabel => 'Apply filtres';

  @override
  String get nursingResetFiltersLabel => 'Reset filtres';

  @override
  String get nursingSearchFieldLabel => 'Search champs';

  @override
  String get nursingAllFieldsLabel => 'Tous';

  @override
  String get nursingDateFilterLabel => 'Due ou observation date';

  @override
  String get nursingDateFromLabel => 'From';

  @override
  String get nursingDateToLabel => 'To';

  @override
  String get nursingDatePickerLabel => 'Choose date';

  @override
  String get nursingInvalidDateMessage => 'Enter un valid date.';

  @override
  String get nursingPatientFilterLabel => 'Patient';

  @override
  String get nursingPatientFilterHint =>
      'Name, number, admission, ou consultation';

  @override
  String get nursingUnitFilterLabel => 'Unit';

  @override
  String get nursingUnitFilterHint => 'Ward, ICU, recovery, ou unité';

  @override
  String get nursingShiftFilterLabel => 'Shift';

  @override
  String get nursingShiftFilterHint =>
      'Morning, evening, night, ou actuel quart';

  @override
  String get nursingCareTaskFilterLabel => 'Care task';

  @override
  String get nursingCareTaskFilterHint =>
      'Vitals, médicament, handover, transfert, ou sortie';

  @override
  String get nursingAdmissionStatusFilterLabel => 'Admission statut';

  @override
  String get nursingAdmissionStatusFilterHint =>
      'Active, admis, transfert, ou sortie statut';

  @override
  String get nursingDischargeReadinessFilterLabel => 'Discharge readiness';

  @override
  String get nursingDischargeReadinessFilterHint =>
      'Planned, en attente, ready, ou blocked';

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
  String get nursingDueTimeColumnLabel => 'Due heure';

  @override
  String get nursingResponsibleNurseColumnLabel => 'Responsible nurse';

  @override
  String get nursingDueNowLabel => 'Now';

  @override
  String get nursingAssignedShiftLabel => 'Assigned quart';

  @override
  String get nursingWardAdmissionChecklistTitle => 'Ward admission checklist';

  @override
  String get nursingWardAdmissionChecklistDescription =>
      'Checks tied à lit location, admission handover, observations, soins forfait, médicament, et sortie readiness.';

  @override
  String get nursingChecklistCompleteStatus => 'Complete';

  @override
  String get nursingChecklistPendingStatus => 'En attente';

  @override
  String get nursingChecklistLocationTitle => 'Location confirmed';

  @override
  String get nursingChecklistLocationReadyBody =>
      'Patient location is disponible.';

  @override
  String get nursingChecklistLocationPendingBody =>
      'Waiting pour lit allocation ou authorized holding area.';

  @override
  String get nursingChecklistHandoverTitle => 'Admission handover';

  @override
  String get nursingChecklistHandoverReadyBody =>
      'Un soins infirmiers handover is linked à ce admission.';

  @override
  String get nursingChecklistHandoverPendingBody =>
      'Record ou accept le admission handover avant service soins continues.';

  @override
  String get nursingChecklistVitalsTitle => 'Initial observations';

  @override
  String get nursingChecklistVitalsPendingBody =>
      'Record baseline vital signs pour le admission.';

  @override
  String get nursingChecklistCarePlanTitle => 'Care forfait started';

  @override
  String get nursingChecklistCarePlanReadyBody =>
      'At least one soins task ou forfait is recorded.';

  @override
  String get nursingChecklistCarePlanPendingBody =>
      'Add un soins task ou forfait pour service follow-up.';

  @override
  String get nursingChecklistMedicationTitle => 'Medication queue clear';

  @override
  String get nursingChecklistMedicationReadyBody =>
      'No médicament administration is currently due.';

  @override
  String get nursingChecklistMedicationPendingBody =>
      'Medication administration remains due pour ce patient.';

  @override
  String get nursingChecklistDischargeTitle =>
      'Discharge soins infirmiers readiness';

  @override
  String get nursingChecklistDischargeReadyBody =>
      'No sortie soins infirmiers checklist is en attente.';

  @override
  String get nursingChecklistDischargePendingBody =>
      'Discharge soins infirmiers checks are en attente; do not fermer le admission here.';

  @override
  String get nursingChecklistIdentityTitle => 'Identity confirmed';

  @override
  String get nursingChecklistIdentityReadyBody =>
      'Patient identity has been confirmed.';

  @override
  String get nursingChecklistIdentityPendingBody =>
      'Confirm patient nom, admission number, et service/lit.';

  @override
  String get nursingChecklistAllergiesTitle => 'Allergies et risk flags';

  @override
  String get nursingChecklistAllergiesReadyBody =>
      'Allergies et risk flags have been reviewed.';

  @override
  String get nursingChecklistAllergiesPendingBody =>
      'Review et dossier patient allergies et risk flags.';

  @override
  String get nursingChecklistBelongingsTitle => 'Belongings';

  @override
  String get nursingChecklistBelongingsReadyBody =>
      'Patient belongings have been recorded.';

  @override
  String get nursingChecklistBelongingsPendingBody =>
      'Record patient belongings per hôpital policy.';

  @override
  String get nursingChecklistDoctorTitle => 'Doctor notified';

  @override
  String get nursingChecklistDoctorReadyBody =>
      'Le responsible doctor has been notified.';

  @override
  String get nursingChecklistDoctorPendingBody =>
      'Notify le responsible doctor sur le service admission.';

  @override
  String get nursingActionOrderLab => 'Order laboratoire tests';

  @override
  String get nursingActionOrderRadiology => 'Order imaging';

  @override
  String get nursingActionDischargeClearance => 'Discharge clearance';

  @override
  String get nursingActionOpenIcu => 'Open ICU espace de travail';

  @override
  String get nursingActionConfirmIdentity => 'Confirm identity';

  @override
  String get nursingActionRecordAllergies => 'Record allergies & risks';

  @override
  String get nursingActionRecordBelongings => 'Record belongings';

  @override
  String get nursingActionNotifyDoctor => 'Notify doctor';

  @override
  String get nursingAllergiesLabel => 'Allergies et risk flags';

  @override
  String get nursingBelongingsLabel => 'Belongings';

  @override
  String get nursingNotifyDoctorLabel => 'Notification détails';

  @override
  String get nursingCarePlanLabel => 'Care forfait';

  @override
  String get nursingDischargeClearanceTitle =>
      'Discharge soins infirmiers clearance';

  @override
  String get nursingDischargeClearanceDescription =>
      'Complete service checks et patient education avant IPD finalizes sortie.';

  @override
  String get nursingDischargeClearanceNotesLabel => 'Additional notes';

  @override
  String get nursingDischargeClearanceConfirmLabel =>
      'I confirmer soins infirmiers clearance is complete';

  @override
  String get nursingClearanceMedicationEducationLabel =>
      'Medication education provided';

  @override
  String get nursingClearanceWoundCareLabel => 'Wound soins instructions given';

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
      'Current roster et handover éléments stay visible sans opening another module.';

  @override
  String get nursingRosterTitle => 'Roster assignments';

  @override
  String get nursingPendingHandoverTitle => 'Pending handovers';

  @override
  String get nursingNoRosterLabel =>
      'No roster assignments found pour ce quart.';

  @override
  String get navigationDischargeLabel => 'Discharge planning';

  @override
  String get navigationDischargeShortLabel => 'Sortie';

  @override
  String get dischargeWorkspaceTitle => 'Discharge espace de travail';

  @override
  String get dischargeWorkspaceDescription =>
      'Coordinate sortie forfaits, clearances, medicines, final billing, documents, et lit release.';

  @override
  String get dischargeOperationalStatusLabel => 'Discharge desk actif';

  @override
  String get dischargePlannedSummaryLabel => 'Planned';

  @override
  String get dischargeSummaryPendingSummaryLabel => 'Summary en attente';

  @override
  String get dischargeDocumentsReadySummaryLabel => 'Documents ready';

  @override
  String get dischargeCompletedSummaryLabel => 'Terminé';

  @override
  String get dischargeQueueSearchLabel => 'Search sortie queue';

  @override
  String get dischargeQueueSearchHint =>
      'Search patient, admission, ou service';

  @override
  String get dischargeStatusFilterLabel => 'Discharge statut';

  @override
  String get dischargeStatusAll => 'All discharges';

  @override
  String get dischargeStatusPlanned => 'Planned';

  @override
  String get dischargeStatusSummaryPending => 'Summary en attente';

  @override
  String get dischargeStatusPharmacyPending => 'Pharmacy en attente';

  @override
  String get dischargeStatusNursingPending => 'Nursing en attente';

  @override
  String get dischargeStatusBillingPending => 'Billing en attente';

  @override
  String get dischargeStatusInsurancePending => 'Insurance en attente';

  @override
  String get dischargeStatusDocumentsReady => 'Documents ready';

  @override
  String get dischargeStatusCompleted => 'Terminé';

  @override
  String get dischargeWorklistTitle => 'Discharge worklist';

  @override
  String get dischargeWorklistDescription =>
      'Patients avec un sortie forfait, en attente clearance, ou recent completion.';

  @override
  String get dischargePreviousPageLabel => 'Previous discharges';

  @override
  String get dischargeNextPageLabel => 'Next discharges';

  @override
  String dischargePageLabel(int from, int to, int total) {
    return '$from-$to of $total';
  }

  @override
  String get dischargeEmptyQueueTitle => 'No discharges in ce voir';

  @override
  String get dischargeEmptyQueueBody =>
      'Adjust le statut filtre ou recherche term à find sortie work.';

  @override
  String get dischargePatientColumnLabel => 'Patient';

  @override
  String get dischargeLocationColumnLabel => 'Ward et lit';

  @override
  String get dischargeStatusColumnLabel => 'Statut';

  @override
  String get dischargeNextActionColumnLabel => 'Next action';

  @override
  String get dischargeTargetColumnLabel => 'Target';

  @override
  String get dischargeDetailTitle => 'Discharge detail';

  @override
  String get dischargeDetailLoadingTitle => 'Loading sortie detail';

  @override
  String get dischargeDetailLoadingBody =>
      'Loading patient context, clearance, medicines, billing, et documents.';

  @override
  String get dischargeNoSelectionTitle => 'Select un sortie';

  @override
  String get dischargeNoSelectionBody =>
      'Choose un patient de le worklist à coordinate sortie.';

  @override
  String get dischargePrintSummaryAction => 'Print sortie résumé';

  @override
  String get dischargePatientContextLabel => 'Patient sortie context';

  @override
  String get dischargeAdmissionFieldLabel => 'Admission';

  @override
  String get dischargeEncounterFieldLabel => 'Encounter';

  @override
  String get dischargeLocationFieldLabel => 'Location';

  @override
  String get dischargeTargetFieldLabel => 'Target sortie';

  @override
  String get dischargeStartPlanAction => 'Start sortie forfait';

  @override
  String get dischargeEditSummaryAction => 'Edit résumé';

  @override
  String get dischargeRequestBillingAction => 'Request final billing';

  @override
  String get dischargeRequestPharmacyAction => 'Request medicines';

  @override
  String get dischargeCompleteAction => 'Complete sortie';

  @override
  String get dischargeChecklistTitle => 'Clearance checklist';

  @override
  String get dischargeChecklistBody =>
      'Track clinique, soins infirmiers, pharmacie, billing, documents, et lit release readiness.';

  @override
  String get dischargeClearanceComplete => 'Complete';

  @override
  String get dischargeClearancePending => 'En attente';

  @override
  String get dischargeClearanceBackendGap => 'Unavailable';

  @override
  String get dischargeClearanceUnavailable => 'Unavailable';

  @override
  String get dischargeClearanceDoctor => 'Doctor résumé';

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
  String get dischargeSummarySectionTitle => 'Clinical résumé';

  @override
  String get dischargeSummarySectionBody =>
      'Capture diagnostic, traitement, medicines, advice, follow-up, warnings, et signature context.';

  @override
  String get dischargeEmptySummaryTitle => 'No résumé recorded';

  @override
  String get dischargeEmptySummaryBody =>
      'Start un sortie forfait à prepare le printable résumé.';

  @override
  String get dischargeGeneratedDocumentsTitle => 'Generated document aperçu';

  @override
  String get dischargeMedicinesSectionTitle => 'Discharge medicines';

  @override
  String get dischargeNoMedicinesBody =>
      'No sortie medicine commandes are linked à ce admission.';

  @override
  String get dischargePharmacyUnavailableBody =>
      'Pharmacy orders n\'a pas pu être loaded. Refresh before completing discharge.';

  @override
  String get dischargeBillingSectionTitle => 'Billing clearance';

  @override
  String get dischargeNoInvoicesBody =>
      'No final factures are linked à ce admission.';

  @override
  String get dischargeBillingUnavailableBody =>
      'Billing records n\'a pas pu être loaded. Refresh before completing discharge.';

  @override
  String get dischargeNoRecordsTitle => 'No dossiers';

  @override
  String get dischargeTimelineSectionTitle => 'Admission timeline';

  @override
  String get dischargeNoTimelineTitle => 'No timeline activity';

  @override
  String get dischargeNoTimelineBody =>
      'Admission timeline events will appear après activity is recorded.';

  @override
  String get dischargeBackendGapsTitle => 'Unavailable workflows';

  @override
  String get dischargeBackendGapsBody =>
      'These workflow actions are indisponible until system support is activé pour ce établissement.';

  @override
  String get dischargeGapBackendSubtitle => 'Workflow support indisponible';

  @override
  String get dischargeGapChecklistTitle => 'Persistent clearance checklist';

  @override
  String get dischargeGapChecklistBody =>
      'Individual doctor, soins infirmiers, pharmacie, billing, document, et exit checklist decisions are not disponible in ce workflow yet.';

  @override
  String get dischargeGapInsuranceTitle => 'Insurance clearance workflow';

  @override
  String get dischargeGapInsuranceBody =>
      'Insurance clearance is not connected à ce sortie workflow yet.';

  @override
  String get dischargeGapDocumentsTitle => 'Document ready state';

  @override
  String get dischargeGapDocumentsBody =>
      'Discharge documents can be generated de le résumé. Handover readiness is not disponible yet.';

  @override
  String get dischargeGapHousekeepingTitle => 'Housekeeping task passation';

  @override
  String get dischargeGapHousekeepingBody =>
      'Final sortie releases le lit. Housekeeping passation is indisponible pour ce workflow.';

  @override
  String get dischargePlanDialogTitle => 'Discharge forfait';

  @override
  String get dischargePlanDialogBody =>
      'Prepare le clinique sortie résumé et target sortie date.';

  @override
  String get dischargeSummaryFieldLabel => 'Discharge résumé';

  @override
  String get dischargeSummaryHelperText =>
      'Include diagnostic, traitement, medicines, advice, follow-up, avertissement signs, et signature context.';

  @override
  String get dischargeSummaryRequiredMessage => 'Enter le sortie résumé.';

  @override
  String get dischargeTargetDateLabel => 'Target sortie date';

  @override
  String get dischargeDatePickerLabel => 'Choose date';

  @override
  String get dischargeInvalidDateMessage => 'Enter un valid sortie date.';

  @override
  String get dischargeSavePlanAction => 'Save forfait';

  @override
  String get dischargeBillingDialogTitle => 'Final billing demande';

  @override
  String get dischargeBillingDialogBody =>
      'Create un final facture demande pour billing clearance.';

  @override
  String get dischargeBillingAmountLabel => 'Amount';

  @override
  String get dischargeBillingAmountRequiredMessage =>
      'Enter le final billing montant.';

  @override
  String get dischargeBillingCurrencyLabel => 'Currency';

  @override
  String get dischargeBillingCurrencyRequiredMessage =>
      'Enter le billing devise.';

  @override
  String get dischargeRequestBillingSubmitAction => 'Create facture demande';

  @override
  String get dischargePharmacyDialogTitle => 'Discharge medicines';

  @override
  String get dischargePharmacyDialogBody =>
      'Send sortie medicines à pharmacie.';

  @override
  String get dischargeDrugFieldLabel => 'Medicine';

  @override
  String get dischargeDrugRequiredMessage => 'Select un medicine.';

  @override
  String get dischargePrescriptionFieldLabel => 'Prescription';

  @override
  String get dischargePrescriptionHelperText =>
      'State dose, duration, et any patient instructions.';

  @override
  String get dischargePrescriptionRequiredMessage =>
      'Enter le sortie ordonnance.';

  @override
  String get dischargeQuantityFieldLabel => 'Quantity';

  @override
  String get dischargeMedicationRouteLabel => 'Route';

  @override
  String get dischargeMedicationFrequencyLabel => 'Frequency';

  @override
  String get dischargeMedicineInstructionsLabel => 'Instructions';

  @override
  String get dischargeRequestPharmacySubmitAction => 'Send à pharmacie';

  @override
  String get dischargeCompleteDialogTitle => 'Complete sortie';

  @override
  String get dischargeCompleteDialogBody =>
      'Confirm le patient exit only après requis clinique, soins infirmiers, pharmacie, billing, et document checks are complete.';

  @override
  String get dischargeCompletionBlockersTitle => 'Clearance still en attente';

  @override
  String get dischargeCompletionBlockersBody =>
      'Resolve en attente ou indisponible clearance éléments avant finalizing le admission.';

  @override
  String get dischargeCompleteConfirmLabel =>
      'I confirmer le patient has exited et documents were handed over.';

  @override
  String get dischargeCompleteConfirmRequiredMessage =>
      'Confirm patient exit avant completing sortie.';

  @override
  String get dischargeCompleteSubmitAction => 'Finalize sortie';

  @override
  String get dischargeNextActionCompleted => 'Discharge terminé';

  @override
  String get dischargeNextActionClearance => 'Clear en attente éléments';

  @override
  String get dischargeNextActionStartPlan => 'Start résumé';

  @override
  String dischargePatientAgeSexLabel(String age, String sex) {
    return '$age / $sex';
  }

  @override
  String get dischargeSavedMessage => 'Discharge workflow mis à jour.';

  @override
  String get dischargeManageClearanceAction => 'Manage clearance';

  @override
  String get dischargeManageClearanceTitle => 'Discharge clearance';

  @override
  String get dischargeSaveClearanceAction => 'Save clearance';

  @override
  String get dischargePendingOrdersTitle => 'Pending clinique commandes';

  @override
  String get dischargePendingOrdersBody =>
      'Review laboratoire, radiologie, médicament, et soins infirmiers commandes avant finalizing sortie.';

  @override
  String get dischargeCrossModuleLinksTitle => 'Related workspaces';

  @override
  String get dischargeCrossModuleLinksBody =>
      'Open billing, pharmacie, soins infirmiers, IPD, ou entretien avec ce admission context.';

  @override
  String get dischargeOpenIpdAction => 'Open IPD';

  @override
  String get dischargeOpenNursingAction => 'Open soins infirmiers';

  @override
  String get dischargeOpenPharmacyAction => 'Open pharmacie';

  @override
  String get dischargeOpenBillingAction => 'Open billing';

  @override
  String get dischargeOpenHousekeepingAction => 'Open entretien';

  @override
  String get dischargeReportTitle => 'Discharge résumé';

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
  String get dischargeReportFooter => 'Generated de sortie workflow data.';

  @override
  String get dischargeLoadingTitle => 'Loading sortie espace de travail';

  @override
  String get dischargeLoadingBody => 'Loading sortie queue et référence data.';

  @override
  String get dischargeLoadErrorTitle =>
      'Discharge espace de travail indisponible';

  @override
  String get dischargeLoadErrorBody =>
      'The discharge queue n\'a pas pu être loaded. Refresh to try again.';

  @override
  String get radiologyTitle => 'Radiologie';

  @override
  String get radiologyDescription =>
      'Manage imaging demandes, modality worklists, study capture, PACS links, reporting, et release.';

  @override
  String get radiologyLoadingTitle => 'Loading radiologie espace de travail';

  @override
  String get radiologyLoadingBody =>
      'Loading imaging commandes, rapports, studies, et référence data.';

  @override
  String get radiologyLiveStatus => 'Live synchronisation';

  @override
  String get radiologySavingStatus => 'Saving';

  @override
  String get radiologySavedMessage => 'Radiology workflow mis à jour.';

  @override
  String get radiologyRequestImagingAction => 'Request imaging';

  @override
  String get radiologyRefreshCatalogAction => 'Refresh catalog';

  @override
  String get radiologyTotalOrdersSummaryLabel => 'Total commandes';

  @override
  String get radiologyWaitingImagingSummaryLabel => 'Waiting imaging';

  @override
  String get radiologyReportingSummaryLabel => 'Reporting';

  @override
  String get radiologyReleasedSummaryLabel => 'Released';

  @override
  String get radiologyUnsyncedSummaryLabel => 'PACS synchronisation due';

  @override
  String get radiologyFiltersLabel => 'Radiology filtres';

  @override
  String get radiologySearchLabel => 'Search radiologie';

  @override
  String get radiologySearchHint =>
      'Search patient, commande, consultation, study, rapport, ou PACS text';

  @override
  String get radiologyOrderDateFilterLabel => 'Order date';

  @override
  String get radiologyPickOrderDateAction => 'Pick commande date';

  @override
  String get radiologyStageFilterLabel => 'Stage';

  @override
  String get radiologyStatusFilterLabel => 'Statut';

  @override
  String get radiologyModalityFilterLabel => 'Modality';

  @override
  String get radiologyClearFiltersAction => 'Clear filtres';

  @override
  String get radiologyWorklistTitle => 'Imaging worklist';

  @override
  String get radiologyWorklistDescription =>
      'System imaging commandes avec modality workflow et rapport statut.';

  @override
  String get radiologyPreviousPageLabel => 'Previous commandes';

  @override
  String get radiologyNextPageLabel => 'Next commandes';

  @override
  String radiologyPageLabel(int from, int to, int total) {
    return 'Showing $from-$to of $total';
  }

  @override
  String get radiologyNoOrdersTitle => 'No radiologie commandes';

  @override
  String get radiologyNoOrdersBody =>
      'Orders matching ce recherche et filtre will appear here.';

  @override
  String get radiologyPatientColumnLabel => 'Patient';

  @override
  String get radiologyOrderColumnLabel => 'Order';

  @override
  String get radiologyStudyColumnLabel => 'Study';

  @override
  String get radiologyPriorityColumnLabel => 'Priority';

  @override
  String get radiologyPaymentAuthColumnLabel => 'Facturation';

  @override
  String get radiologyStatusColumnLabel => 'Statut';

  @override
  String get radiologyNextActionColumnLabel => 'Next action';

  @override
  String get radiologyDetailTitle => 'Radiology workflow';

  @override
  String get radiologyDetailLoadingTitle => 'Loading commande';

  @override
  String get radiologyDetailLoadingBody => 'Loading selected imaging workflow.';

  @override
  String get radiologyNoSelectionTitle => 'Select un commande';

  @override
  String get radiologyNoSelectionBody =>
      'Choose un imaging demande à voir study, rapport, et release détails.';

  @override
  String get radiologyPatientContextLabel => 'Radiology patient context';

  @override
  String get radiologyBillingGateUnavailable => 'Billing gate indisponible';

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
  String get radiologyStartDialogTitle => 'Start imaging commande';

  @override
  String get radiologyNotesLabel => 'Notes';

  @override
  String get radiologyPerformStudyAction => 'Perform study';

  @override
  String get radiologyCancelOrderAction => 'Cancel commande';

  @override
  String get radiologyRequestDetailsTitle => 'Request détails';

  @override
  String get radiologyWorkflowSummaryTitle => 'Workflow résumé';

  @override
  String get radiologyEditRequestDetailsAction => 'Edit demande détails';

  @override
  String get radiologyEditRequestDetailsDialogTitle => 'Edit demande détails';

  @override
  String get radiologySaveRequestDetailsAction => 'Save demande détails';

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
      'Select un corps region à filtre le imaging catalog.';

  @override
  String get radiologyWorkflowProgressTitle => 'Workflow progress';

  @override
  String get radiologyWorkflowStepReceive => 'Receive imaging demande';

  @override
  String get radiologyWorkflowStepReview => 'Review study détails';

  @override
  String get radiologyWorkflowStepPerform => 'Perform imaging study';

  @override
  String get radiologyWorkflowStepUpload => 'Upload study actifs';

  @override
  String get radiologyWorkflowStepReport => 'Enter findings et conclusions';

  @override
  String get radiologyWorkflowStepRelease => 'Finalize et release rapport';

  @override
  String get radiologyReportSectionTitle => 'Report';

  @override
  String get radiologyReportSectionBody =>
      'Draft, finalize, attest, et amend radiologie rapports avec clear findings, impression, narrative, et references.';

  @override
  String get radiologyDraftReportAction => 'Draft rapport';

  @override
  String get radiologyReleaseReportAction => 'Release rapport';

  @override
  String get radiologyRequestFinalizationAction => 'Request finalization';

  @override
  String get radiologyRequestFinalizationDialogTitle =>
      'Request rapport finalization';

  @override
  String get radiologyAttestFinalizationAction => 'Attest finalization';

  @override
  String get radiologyAttestFinalizationDialogTitle =>
      'Attest rapport finalization';

  @override
  String get radiologyAddendumAction => 'Add addendum';

  @override
  String get radiologyPendingAttestationLabel => 'Pending attestation';

  @override
  String get radiologyNoReportTitle => 'No rapport yet';

  @override
  String get radiologyNoReportBody =>
      'Un brouillon ou final rapport will appear après reporting begins.';

  @override
  String get radiologyReportedAtLabel => 'Reported';

  @override
  String get radiologyGeneratedReportPreviewTitle => 'Report aperçu';

  @override
  String get radiologyEmptyReportBody => 'No rapport text captured.';

  @override
  String get radiologyStudiesAssetsTitle => 'Studies et actifs';

  @override
  String get radiologyStudiesAssetsBody =>
      'Track performed imaging studies, disponible actifs, et PACS synchronization state.';

  @override
  String get radiologyNoStudiesTitle => 'No imaging studies';

  @override
  String get radiologyNoStudiesBody =>
      'Studies et actifs will appear après imaging is performed et saved.';

  @override
  String get radiologySyncPacsAction => 'Sync PACS';

  @override
  String get radiologyAssetsLabel => 'Assets';

  @override
  String get radiologyNoAssetsLabel => 'No actifs recorded';

  @override
  String get radiologyPacsLinksLabel => 'PACS links';

  @override
  String get radiologyNoPacsLinksLabel => 'No PACS links recorded';

  @override
  String get radiologyDoctorReviewTitle => 'Doctor review';

  @override
  String get radiologyDoctorReviewReleasedBody =>
      'Le final radiologie rapport is ready pour le requesting clinician ou doctor à review.';

  @override
  String get radiologyDoctorReviewPendingBody =>
      'No final radiologie rapport is disponible pour doctor review yet.';

  @override
  String get radiologyDoctorReviewReadyLabel => 'Ready pour review';

  @override
  String get radiologyDoctorReviewPendingLabel => 'Pending release';

  @override
  String get radiologyTimelineTitle => 'Workflow timeline';

  @override
  String get radiologyNoTimelineTitle => 'No timeline events';

  @override
  String get radiologyNoTimelineBody =>
      'Workflow events will appear as le commande progresses.';

  @override
  String get radiologyBackendGapsTitle => 'Unavailable workflows';

  @override
  String get radiologyBackendGapsBody =>
      'These controls are indisponible until system support is activé pour ce établissement.';

  @override
  String get radiologyGapSchedulingTitle => 'Room scheduling';

  @override
  String get radiologyGapBackendSubtitle => 'Action indisponible';

  @override
  String get radiologyGapSchedulingBody =>
      'Room et rendez-vous assignment is not disponible pour actuel imaging commandes.';

  @override
  String get radiologyGapBillingTitle => 'Billing authorization';

  @override
  String get radiologyGapBillingBody =>
      'Payment et authorization statut appears lorsque disponible pour ce commande.';

  @override
  String get radiologyCreateOrderDialogTitle => 'Request imaging';

  @override
  String get radiologyReferenceSearchLabel => 'Catalog recherche';

  @override
  String get radiologyReferenceSearchHint =>
      'Search test code, nom, modality, ou corps region';

  @override
  String get radiologySearchReferenceAction => 'Search catalog';

  @override
  String get radiologyPatientLabel => 'Patient';

  @override
  String radiologyFieldRequiredLabel(String label) {
    return '$label est requis.';
  }

  @override
  String get radiologyAssignDialogTitle => 'Assign imaging commande';

  @override
  String get radiologyAssigneeLabel => 'Assignee';

  @override
  String get radiologyPerformStudyDialogTitle => 'Perform imaging study';

  @override
  String get radiologyPerformedAtLabel => 'Performed at';

  @override
  String get radiologyDateTimeHint => 'YYYY-MM-DD HH:MM';

  @override
  String get radiologyReportDialogTitle => 'Draft radiologie rapport';

  @override
  String get radiologyFindingsLabel => 'Findings';

  @override
  String get radiologyImpressionLabel => 'Impression/Conclusion';

  @override
  String get radiologyReportTextLabel => 'Report narrative';

  @override
  String get radiologyReportTextHelper =>
      'Leave blank à combine findings et impression.';

  @override
  String get radiologyReleaseReportDialogTitle => 'Release rapport';

  @override
  String get radiologyReleaseNotesLabel => 'Release notes';

  @override
  String get radiologyFinalizationStatementLabel => 'Finalization statement';

  @override
  String get radiologyFinalizationReasonLabel => 'Reason';

  @override
  String get radiologyAddendumDialogTitle => 'Add rapport addendum';

  @override
  String get radiologyAddendumTextLabel => 'Addendum text';

  @override
  String get radiologyCancelDialogTitle => 'Cancel radiologie commande';

  @override
  String get radiologyCancellationReasonLabel => 'Cancellation reason';

  @override
  String get radiologyPacsSyncDialogTitle => 'Sync study à PACS';

  @override
  String get radiologyStudyUidLabel => 'Study UID';

  @override
  String get radiologyStageAll => 'Tous';

  @override
  String get radiologyStageOrdered => 'Ordered';

  @override
  String get radiologyStageProcessing => 'Processing';

  @override
  String get radiologyStageReporting => 'Reporting';

  @override
  String get radiologyStageCompleted => 'Terminé';

  @override
  String get radiologyStageCancelled => 'Annulé';

  @override
  String get radiologyStatusOrdered => 'Ordered';

  @override
  String get radiologyStatusInProcess => 'In process';

  @override
  String get radiologyStatusCompleted => 'Terminé';

  @override
  String get radiologyStatusCancelled => 'Annulé';

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
  String get radiologyNextActionReleaseReport => 'Release rapport';

  @override
  String get radiologyNextActionDoctorReview => 'Doctor review';

  @override
  String get radiologyNextActionReportPending => 'Report en attente';

  @override
  String get navigationPharmacyLabel => 'Pharmacie';

  @override
  String get navigationPharmacyShortLabel => 'Pharmacie';

  @override
  String get navigationLabLabel => 'Laboratoire';

  @override
  String get navigationLabShortLabel => 'Lab';

  @override
  String get navigationRadiologyLabel => 'Radiologie';

  @override
  String get navigationRadiologyShortLabel => 'Imaging';

  @override
  String get pharmacyLoadingTitle => 'Loading pharmacie espace de travail';

  @override
  String get pharmacyLoadingBody =>
      'Loading pharmacie commandes, dispense state, et stock visibility.';

  @override
  String get pharmacyTitle => 'Pharmacie';

  @override
  String get pharmacyDescription =>
      'Manage prescriptions, dispense passation, returns, et drug stock visibility de one queue.';

  @override
  String get pharmacyStatusSaving => 'Saving';

  @override
  String get pharmacyStatusLiveSync => 'Live synchronisation';

  @override
  String get pharmacyFiltersSemanticLabel => 'Pharmacy queue filtres';

  @override
  String get pharmacySearchLabel => 'Search pharmacie';

  @override
  String get pharmacySearchHint =>
      'Search patient, commande, consultation, médicament, ou batch';

  @override
  String get pharmacyQueueFilterLabel => 'Queue filtre';

  @override
  String get pharmacySummaryReadyLabel => 'Ready';

  @override
  String get pharmacySummaryPartialLabel => 'Partial';

  @override
  String get pharmacySummaryAttestationLabel => 'Awaiting attest';

  @override
  String get pharmacySummaryCompletedLabel => 'Terminé';

  @override
  String get pharmacyQueuePanelTitle => 'Order queue';

  @override
  String get pharmacyQueuePanelDescription =>
      'System pharmacie commandes avec dispense et return actions.';

  @override
  String get pharmacyNoOrdersTitle => 'No pharmacie commandes';

  @override
  String get pharmacyNoOrdersBody =>
      'Orders matching ce recherche et filtre will appear here.';

  @override
  String get pharmacyPatientColumnLabel => 'Patient';

  @override
  String get pharmacyOrderColumnLabel => 'Order';

  @override
  String get pharmacyItemsColumnLabel => 'Items';

  @override
  String get pharmacyDispenseColumnLabel => 'Dispense';

  @override
  String get pharmacyStatusColumnLabel => 'Statut';

  @override
  String get pharmacyPendingBatchLabel => 'Pending batch';

  @override
  String get pharmacyDetailLoadingTitle => 'Loading ordonnance';

  @override
  String get pharmacyDetailLoadingBody =>
      'Loading medicines, dispense historique, et workflow actions.';

  @override
  String get pharmacyPrescriptionDetailTitle => 'Prescription detail';

  @override
  String get pharmacyNoSelectionTitle => 'No ordonnance selected';

  @override
  String get pharmacyNoSelectionBody =>
      'Select un commande à review medicines, stock mapping, billing gate visibility, et dispense historique.';

  @override
  String get pharmacyBillingGateUnavailableTitle =>
      'Payment clearance indisponible';

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
  String get pharmacyCancelOrderAction => 'Cancel commande';

  @override
  String get pharmacyPrintInstructionsAction => 'Print instructions';

  @override
  String get pharmacyMedicationPanelTitle => 'Medicines';

  @override
  String get pharmacyMedicationPanelDescription =>
      'Drug, dose, route, frequency, duration, quantity, instructions, et dispense state.';

  @override
  String get pharmacyNoMedicationTitle => 'No medicines';

  @override
  String get pharmacyNoMedicationBody =>
      'Ce commande has non medicines disponible in le pharmacie workflow.';

  @override
  String get pharmacyMedicationColumnLabel => 'Medication';

  @override
  String get pharmacyDoseColumnLabel => 'Dose';

  @override
  String get pharmacyQuantityColumnLabel => 'Quantity';

  @override
  String get pharmacyStockColumnLabel => 'Stock';

  @override
  String get pharmacyBackendGapsTitle => 'Pharmacy workflow readiness';

  @override
  String get pharmacyBackendGapsBody =>
      'Ce commande uses le actuel pharmacie workflow state à determine safe actions.';

  @override
  String get pharmacyGapPaymentAuthorization =>
      'Payment et authorization are checked avant dispense actions are activé.';

  @override
  String get pharmacyGapBatchAvailability =>
      'Stock mapping is checked avant dispense actions are activé.';

  @override
  String get pharmacyGapHoldSubstitution =>
      'Hold et substitution decisions follow le actuel pharmacie commande statut.';

  @override
  String get pharmacyGapReportTemplates =>
      'Medication printouts utiliser le configured print workflow.';

  @override
  String get pharmacyTimelinePanelTitle => 'Dispense historique';

  @override
  String get pharmacyTimelinePanelDescription =>
      'Order placement, prepare, attest, dispense, et return events de le workflow.';

  @override
  String get pharmacyNoTimelineBody =>
      'No dispense historique is disponible yet.';

  @override
  String get pharmacyDrugPanelTitle => 'Formulary et stock';

  @override
  String get pharmacyDrugPanelDescription =>
      'Search configured drugs et review aggregate stock visibility.';

  @override
  String get pharmacyDrugFiltersSemanticLabel => 'Drug stock filtres';

  @override
  String get pharmacyDrugSearchLabel => 'Search drugs';

  @override
  String get pharmacyDrugSearchHint => 'Search drug, code, form, ou strength';

  @override
  String get pharmacyStockStatusFilterLabel => 'Stock statut';

  @override
  String get pharmacyNoDrugsTitle => 'Aucun drugs trouvé';

  @override
  String get pharmacyNoDrugsBody =>
      'Matching formulary drugs et stock lignes will appear here.';

  @override
  String get pharmacyDrugColumnLabel => 'Drug';

  @override
  String get pharmacyAvailableColumnLabel => 'Available';

  @override
  String get pharmacyStockStatusColumnLabel => 'Stock statut';

  @override
  String pharmacyAvailableQuantityLabel(String quantity) {
    return '$quantity disponible';
  }

  @override
  String get pharmacyDispenseDialogTitle => 'Prepare dispense';

  @override
  String get pharmacyAttestDialogTitle => 'Attest dispense';

  @override
  String get pharmacyAttestDialogBody =>
      'Confirm le prepared batch après physical médicament passation.';

  @override
  String get pharmacyReturnDialogTitle => 'Return medicines';

  @override
  String get pharmacyReturnDialogBody =>
      'Record returned quantities so commande statut et stock are synchronisé.';

  @override
  String get pharmacyCancelDialogTitle => 'Cancel pharmacie commande';

  @override
  String get pharmacyCancelDialogBody =>
      'Cancel only lorsque le commande should non longer be dispensed.';

  @override
  String get pharmacyBillingGateUnavailableBody =>
      'Payment clearance is indisponible pour ce commande.';

  @override
  String get pharmacyPaymentColumnLabel => 'Payment';

  @override
  String get pharmacyPaymentLabel => 'Payment';

  @override
  String get pharmacyPaymentAmountLabel => 'Amount due';

  @override
  String get pharmacyRecordPaymentAction => 'Record paiement';

  @override
  String get pharmacyNextActionConfirmBilling => 'Confirm billing';

  @override
  String get pharmacyDispenseBlockedPaymentBody =>
      'Collect ou confirmer paiement avant dispensing ce commande.';

  @override
  String get pharmacyPriorityFieldLabel => 'Priority';

  @override
  String get pharmacyCatalogTabDrugs => 'Drugs';

  @override
  String get pharmacyCatalogTabFormulary => 'Formulary';

  @override
  String get pharmacyCatalogTabInventory => 'Inventory';

  @override
  String get pharmacyCatalogPanelTitle => 'Catalog et stock';

  @override
  String get pharmacyAddDrugAction => 'Add drug';

  @override
  String get pharmacyEditDrugAction => 'Edit drug';

  @override
  String get pharmacyDeleteDrugAction => 'Delete drug';

  @override
  String get pharmacyDrugNameLabel => 'Drug nom';

  @override
  String get pharmacyDrugCodeLabel => 'Drug code';

  @override
  String get pharmacyDrugFormLabel => 'Form';

  @override
  String get pharmacyDrugStrengthLabel => 'Strength';

  @override
  String get pharmacyAddFormularyAction => 'Add formulary élément';

  @override
  String get pharmacyFormularyDrugLabel => 'Drug';

  @override
  String get pharmacyFormularyActiveLabel => 'Actif';

  @override
  String get pharmacyNoFormularyTitle => 'No formulary éléments';

  @override
  String get pharmacyNoFormularyBody =>
      'Formulary entries linking drugs à prescribing will appear here.';

  @override
  String get pharmacyInventoryPanelTitle => 'Inventory stock';

  @override
  String get pharmacyInventoryPanelDescription =>
      'Review on-hand quantities et post controlled adjustments.';

  @override
  String get pharmacyNoInventoryTitle => 'No inventaire lignes';

  @override
  String get pharmacyNoInventoryBody =>
      'Matching inventaire stock lignes will appear here.';

  @override
  String get pharmacyInventoryQuantityColumnLabel => 'On hand';

  @override
  String get pharmacyInventoryFacilityColumnLabel => 'Facility';

  @override
  String get pharmacyAdjustStockAction => 'Adjust stock';

  @override
  String get pharmacyAdjustStockDialogTitle => 'Adjust inventaire';

  @override
  String get pharmacyQuantityDeltaLabel => 'Quantity change';

  @override
  String get pharmacyStockReasonLabel => 'Reason';

  @override
  String get pharmacyLowStockOnlyFilterLabel => 'Low stock only';

  @override
  String get pharmacyDeleteDrugDialogTitle => 'Delete drug';

  @override
  String get pharmacyDeleteDrugDialogBody => 'Remove ce drug de le catalog?';

  @override
  String get pharmacyDispenseDialogBody =>
      'Enter dispense quantities et facultatif stock mapping pour each medicine line.';

  @override
  String get pharmacyBatchRefLabel => 'Batch référence';

  @override
  String get pharmacyStatementLabel => 'Statement';

  @override
  String get pharmacyReasonLabel => 'Reason';

  @override
  String get pharmacyNotesLabel => 'Notes';

  @override
  String get pharmacyQuantityFieldLabel => 'Quantity';

  @override
  String get pharmacyInventoryItemLabel => 'Inventory élément';

  @override
  String pharmacyQuantityValidationLabel(String maximum) {
    return 'Enter un quantity de 0 à $maximum.';
  }

  @override
  String get pharmacySavedMessage => 'Pharmacy workflow mis à jour.';

  @override
  String get pharmacyFilterAll => 'All commandes';

  @override
  String get pharmacyFilterReady => 'Ready';

  @override
  String get pharmacyFilterPartial => 'Partial';

  @override
  String get pharmacyFilterCompleted => 'Terminé';

  @override
  String get pharmacyFilterCancelled => 'Annulé';

  @override
  String get pharmacyFilterPendingPayment => 'Pending paiement';

  @override
  String get pharmacyFilterPartialStock => 'Partial stock';

  @override
  String get pharmacyFilterUrgent => 'Urgent';

  @override
  String get pharmacyFilterDischarge => 'Discharge meds';

  @override
  String get pharmacyFilterOutpatient => 'Outpatient';

  @override
  String get pharmacyFilterWard => 'Service';

  @override
  String get pharmacyLocationFieldLabel => 'Care location';

  @override
  String get pharmacyStockInStock => 'In stock';

  @override
  String get pharmacyStockAlmostOut => 'Almost out';

  @override
  String get pharmacyStockLow => 'Low stock';

  @override
  String get pharmacyStockOut => 'Out sur stock';

  @override
  String get pharmacyStockUnknown => 'Stock inconnu';

  @override
  String get pharmacyUnknownStatusLabel => 'Inconnu';

  @override
  String get pharmacyStockMappingUnavailable => 'Stock mapping indisponible';

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
  String get pharmacyReportFooter => 'Generated de pharmacie workflow data.';

  @override
  String get navigationClaimsLabel => 'Insurance réclamations';

  @override
  String get navigationClaimsShortLabel => 'Claims';

  @override
  String get claimsWorkspaceTitle => 'Insurance et réclamations';

  @override
  String get claimsWorkspaceDescription =>
      'Manage authorizations, payer responses, réclamation submission, resubmission, et facture follow-up.';

  @override
  String get claimsOperationalStatusLabel => 'Billing synced';

  @override
  String get claimsNeedsAttentionStatusLabel => 'Needs attention';

  @override
  String get claimsLoadingTitle => 'Loading réclamations';

  @override
  String get claimsLoadingBody =>
      'Fetching authorization et réclamation queues.';

  @override
  String get claimsLoadErrorTitle => 'Claims indisponible';

  @override
  String get claimsLoadErrorBody =>
      'The claims workspace n\'a pas pu être loaded.';

  @override
  String get claimsRequestAuthorizationAction => 'Request authorization';

  @override
  String get claimsPrepareClaimAction => 'Prepare réclamation';

  @override
  String get claimsAuthorizationPendingSummaryLabel => 'Auth en attente';

  @override
  String get claimsAuthorizationApprovedSummaryLabel => 'Auth approuvé';

  @override
  String get claimsSubmittedSummaryLabel => 'Submitted';

  @override
  String get claimsRejectedSummaryLabel => 'Rejeté';

  @override
  String get claimsApprovedSummaryLabel => 'Approuvé';

  @override
  String get claimsPaidClosedSummaryLabel => 'Paid/fermé';

  @override
  String get claimsSearchSemanticLabel =>
      'Search réclamations et authorizations';

  @override
  String get claimsSearchHint =>
      'Search référence, coverage, facture, ou patient';

  @override
  String get claimsQueueFilterLabel => 'Queue';

  @override
  String get claimsWorklistTitle => 'Claims worklist';

  @override
  String get claimsWorklistDescription =>
      'Review pre-authorizations et réclamation dossiers backed by billing data.';

  @override
  String get claimsPreviousPageLabel => 'Previous réclamations page';

  @override
  String get claimsNextPageLabel => 'Next réclamations page';

  @override
  String claimsPageLabel(int start, int end, int total) {
    return '$start - $end of $total';
  }

  @override
  String get claimsEmptyQueueTitle => 'Aucun claims trouvé';

  @override
  String get claimsEmptyQueueBody =>
      'No authorization ou réclamation dossiers match le actuel queue.';

  @override
  String get claimsTypeColumnLabel => 'Type';

  @override
  String get claimsReferenceColumnLabel => 'Reference';

  @override
  String get claimsCoverageColumnLabel => 'Coverage';

  @override
  String get claimsInvoiceColumnLabel => 'Invoice';

  @override
  String get claimsStatusColumnLabel => 'Statut';

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
      'Fetching payer, facture, et coverage context.';

  @override
  String get claimsNoSelectionTitle => 'Select un dossier';

  @override
  String get claimsNoSelectionBody =>
      'Choose un ligne à review coverage, billing impact, et suivant actions.';

  @override
  String get claimsPrintStatementAction => 'Print statement';

  @override
  String get claimsPatientContextLabel => 'Claim patient et coverage context';

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
      'Service clearance should wait pour payer réponse where authorization est requis.';

  @override
  String get claimsCoveragePercentLabel => 'Coverage';

  @override
  String claimsCoveragePercentValue(String percent) {
    return '$percent%';
  }

  @override
  String get claimsInvoiceStatusLabel => 'Invoice statut';

  @override
  String get claimsPatientBalanceLabel => 'Patient balance';

  @override
  String get claimsBillingInvoiceUnavailableBody =>
      'Invoice détails are not disponible, so le patient balance ne peut pas be confirmed here.';

  @override
  String get claimsBillingAuthorizedBody =>
      'Authorized by payer. Confirm any uncovered balance avant final clearance.';

  @override
  String get claimsBillingPaidBody =>
      'Claim is paid ou fermé. Billing can utiliser le latest facture statut pour follow-up.';

  @override
  String get claimsBillingRejectedBody =>
      'Rejected by payer. Billing personnel should prepare resubmission ou patient balance follow-up.';

  @override
  String get claimsBillingPendingBody =>
      'Pending payer réponse. Keep billing clearance visible until le réponse is recorded.';

  @override
  String get claimsBillingNeutralBody =>
      'Review facture et payer state avant clearing le service.';

  @override
  String get claimsRequiredDocumentsTitle => 'Required documents';

  @override
  String get claimsRequiredDocumentsBody =>
      'Document readiness is shown de disponible réclamation, facture, et coverage data.';

  @override
  String get claimsDocumentInvoiceSummary => 'Invoice résumé';

  @override
  String get claimsDocumentCoveragePlan => 'Coverage forfait';

  @override
  String get claimsDocumentPayerResponse => 'Payer réponse';

  @override
  String get claimsTimelineTitle => 'Activity';

  @override
  String get claimsTimelineDescription =>
      'Authorization, submission, et réponse timestamps de le réclamations workflow.';

  @override
  String get claimsTimelineAuthorizationRequested => 'Authorization requested';

  @override
  String get claimsTimelineAuthorizationResponded => 'Authorization responded';

  @override
  String get claimsTimelineClaimSubmitted => 'Claim submitted';

  @override
  String get claimsTimelineCurrentStatus => 'Current statut';

  @override
  String get claimsBackendGapTitle => 'Unavailable workflows';

  @override
  String get claimsBackendGapDescription =>
      'These éléments are indisponible in le actuel réclamations workflow.';

  @override
  String get claimsBackendGapDraftTitle => 'Claim brouillon queue';

  @override
  String get claimsBackendGapDraftBody =>
      'Le brouillon queue is not disponible in le actuel réclamations workflow.';

  @override
  String get claimsBackendGapDocumentsTitle => 'Document upload et demandes';

  @override
  String get claimsBackendGapDocumentsBody =>
      'Required document tracking is not disponible yet.';

  @override
  String get claimsBackendGapReportsTitle => 'Generated payer packs';

  @override
  String get claimsBackendGapReportsBody =>
      'Printable payer packs are indisponible until rapport modèles are activé.';

  @override
  String get claimsCoveragePlanFieldLabel => 'Coverage forfait';

  @override
  String get claimsCoveragePlanHint => 'Select payer coverage';

  @override
  String get claimsCoveragePlanRequiredMessage => 'Select un coverage forfait.';

  @override
  String get claimsCoverageUnavailableTitle => 'Coverage forfaits indisponible';

  @override
  String get claimsCoverageUnavailableBody =>
      'Coverage plans n\'a pas pu être loaded, so authorization cannot be requested yet.';

  @override
  String get claimsRequestAuthorizationSubmitAction => 'Request authorization';

  @override
  String get claimsPrepareClaimDialogTitle => 'Prepare réclamation';

  @override
  String get claimsPrepareClaimSubmitAction => 'Prepare et soumettre';

  @override
  String get claimsInvoiceHint => 'Select facture';

  @override
  String get claimsInvoiceRequiredMessage => 'Select un facture.';

  @override
  String get claimsPrepareClaimUnavailableTitle => 'Claim inputs indisponible';

  @override
  String get claimsPrepareClaimUnavailableBody =>
      'Un coverage forfait et facture sont requis avant un réclamation can be prepared.';

  @override
  String get claimsAuthorizationStatusFieldLabel => 'Authorization statut';

  @override
  String get claimsStatusRequiredMessage => 'Select un statut.';

  @override
  String get claimsUpdateStatusSubmitAction => 'Update statut';

  @override
  String get claimsNotesFieldLabel => 'Notes';

  @override
  String get claimsSubmitClaimSubmitAction => 'Submit réclamation';

  @override
  String get claimsClaimResponseFieldLabel => 'Payer réponse';

  @override
  String get claimsSavedMessage => 'Claims espace de travail mis à jour.';

  @override
  String get claimsRequestAuthorizationDialogTitle =>
      'Request pre-authorization';

  @override
  String get claimsUpdateAuthorizationDialogTitle =>
      'Update authorization statut';

  @override
  String get claimsSubmitClaimDialogTitle => 'Submit réclamation';

  @override
  String get claimsRecordResponseDialogTitle => 'Record payer réponse';

  @override
  String get claimsRecordResponseSubmitAction => 'Record réponse';

  @override
  String get claimsCloseClaimDialogTitle => 'Close réclamation';

  @override
  String get claimsCloseClaimSubmitAction => 'Close as paid';

  @override
  String get claimsUpdateStatusAction => 'Update statut';

  @override
  String get claimsSubmitClaimAction => 'Submit réclamation';

  @override
  String get claimsResubmitClaimAction => 'Resubmit réclamation';

  @override
  String get claimsRecordResponseAction => 'Record réponse';

  @override
  String get claimsCloseClaimAction => 'Close as paid';

  @override
  String get claimsInsuranceAuthorizationTitle => 'Insurance authorization';

  @override
  String get claimsInsuranceAuthorizationEmpty =>
      'No authorization on file. Request pre-authorization avant élevé-cost commandes ou elective admission.';

  @override
  String get claimsApprovedAmountLabel => 'Approuvé';

  @override
  String get claimsConsumedAmountLabel => 'Consumed';

  @override
  String get claimsRemainingAmountLabel => 'Remaining';

  @override
  String get claimsAuthorizationReasonLabel => 'Reason';

  @override
  String get claimsCoveragePlansUnavailable =>
      'Coverage forfaits are indisponible. Verify insurance setup avant proceeding.';

  @override
  String get opdCoverageVerificationTitle => 'Coverage vérification';

  @override
  String get opdCoverageVerificationBody =>
      'Confirm le patient\'s actif coverage forfait avant recording un insurance consultation paiement.';

  @override
  String get opdCoverageVerifiedLabel => 'Coverage vérifié pour ce visite';

  @override
  String get opdCoverageVerificationRequiredMessage =>
      'Verify coverage avant paying avec insurance.';

  @override
  String get billingPreAuthApproveAction => 'Approve authorization';

  @override
  String get billingPreAuthDenyAction => 'Deny authorization';

  @override
  String get billingPreAuthApprovedAmountLabel => 'Approved montant';

  @override
  String get billingPreAuthConsumedAmountLabel => 'Consumed montant';

  @override
  String get claimsFilterAll => 'All queues';

  @override
  String get claimsFilterAuthorizationPending => 'Authorization en attente';

  @override
  String get claimsFilterAuthorizationApproved => 'Authorization approuvé';

  @override
  String get claimsFilterAuthorizationDenied => 'Authorization denied';

  @override
  String get claimsFilterAuthorizationExpired => 'Authorization expiré';

  @override
  String get claimsFilterClaimSubmitted => 'Claim submitted';

  @override
  String get claimsFilterClaimApproved => 'Claim approuvé';

  @override
  String get claimsFilterClaimRejected => 'Claim rejeté';

  @override
  String get claimsFilterClaimPaid => 'Claim paid';

  @override
  String get claimsFilterClaimCancelled => 'Claim annulé';

  @override
  String get claimsStatusPending => 'En attente';

  @override
  String get claimsStatusApproved => 'Approuvé';

  @override
  String get claimsStatusDenied => 'Denied';

  @override
  String get claimsStatusExpired => 'Expired';

  @override
  String get claimsStatusSubmitted => 'Submitted';

  @override
  String get claimsStatusRejected => 'Rejeté';

  @override
  String get claimsStatusPaid => 'Paid';

  @override
  String get claimsStatusCancelled => 'Annulé';

  @override
  String get claimsAuthorizationTypeLabel => 'Authorization';

  @override
  String get claimsClaimTypeLabel => 'Claim';

  @override
  String get claimsAuthorizationTitle => 'Coverage authorization';

  @override
  String get claimsClaimPatientTitle => 'Claim patient';

  @override
  String get claimsAuthorizationSubtitle => 'Payer coverage demande';

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
  String get claimsReportFooter => 'Generated de réclamations et billing data.';

  @override
  String get labTitle => 'Laboratoire';

  @override
  String get labDescription =>
      'Manage laboratoire demandes, résultat entry, backend interpretation, vérification, référence ranges, rapports, et clinician passation.';

  @override
  String get labLoadingTitle => 'Loading laboratory';

  @override
  String get labLoadingBody =>
      'Loading laboratoire queues, catalog configuration, résultats, et QC logs.';

  @override
  String get labLiveStatus => 'Live synchronisation';

  @override
  String get labSavingStatus => 'Saving';

  @override
  String get labSavedMessage => 'Laboratory workflow mis à jour.';

  @override
  String get labRequestOrderAction => 'Request laboratoire';

  @override
  String get labRecordQcAction => 'Record QC';

  @override
  String get labTotalOrdersSummaryLabel => 'Total commandes';

  @override
  String get labWaitingSampleSummaryLabel => 'Awaiting résultats';

  @override
  String get labProcessingSummaryLabel => 'Processing';

  @override
  String get labResultPendingSummaryLabel => 'Pending vérification';

  @override
  String get labCriticalSummaryLabel => 'Critical';

  @override
  String get labCompletedSummaryLabel => 'Verified';

  @override
  String get labFiltersLabel => 'Laboratory filtres';

  @override
  String get labSearchLabel => 'Search laboratory';

  @override
  String get labSearchHint => 'Search patient, commande, test, ou consultation';

  @override
  String get labScopeFilterLabel => 'Queue';

  @override
  String get labScopeAll => 'Tous';

  @override
  String get labScopeCollection => 'Awaiting résultats';

  @override
  String get labScopeProcessing => 'Processing';

  @override
  String get labScopeResults => 'Pending vérification';

  @override
  String get labScopeCritical => 'Critical';

  @override
  String get labScopeCompleted => 'Verified';

  @override
  String get labScopeCancelled => 'Annulé';

  @override
  String get labWorklistTitle => 'Lab queue';

  @override
  String get labWorklistDescription =>
      'Actionable laboratoire commandes avec requested tests, résultat entry state, vérification state, et rapport readiness.';

  @override
  String get labNoOrdersTitle => 'No laboratoire commandes';

  @override
  String get labNoOrdersBody =>
      'Adjust le queue filtre ou recherche term à find laboratory work.';

  @override
  String get labPatientColumnLabel => 'Patient';

  @override
  String get labOrderColumnLabel => 'Order';

  @override
  String get labTestsColumnLabel => 'Tests';

  @override
  String get labSampleColumnLabel => 'Entry statut';

  @override
  String get labResultColumnLabel => 'Result';

  @override
  String get labNextActionColumnLabel => 'Next action';

  @override
  String labPageLabel(int from, int to, int total) {
    return '$from-$to of $total';
  }

  @override
  String get labPreviousPageLabel => 'Previous laboratoire page';

  @override
  String get labNextPageLabel => 'Next laboratoire page';

  @override
  String get labDetailTitle => 'Lab detail';

  @override
  String get labDetailLoadingTitle => 'Loading laboratoire detail';

  @override
  String get labDetailLoadingBody =>
      'Loading commande détails, ordered tests, résultats, timeline, et disponible actions.';

  @override
  String get labResultEntryDialogTitle => 'Lab résultat entry';

  @override
  String labResultEntryDialogSubtitle(String patientName, String orderId) {
    return '$patientName · Order $orderId';
  }

  @override
  String get labSaveDraftAction => 'Save brouillon';

  @override
  String get labSubmitResultsAction => 'Submit résultats';

  @override
  String get labDraftSavedMessage => 'Draft résultats saved.';

  @override
  String labBatchPartialSaveMessage(int savedCount, int skippedCount) {
    return 'Saved $savedCount résultats. $skippedCount entries need attention.';
  }

  @override
  String labBatchPartialSubmitMessage(int savedCount, int skippedCount) {
    return 'Submitted $savedCount résultats. $skippedCount entries need attention.';
  }

  @override
  String labBatchPartialVerifyMessage(int savedCount, int skippedCount) {
    return 'Verified $savedCount résultats. $skippedCount entries need attention.';
  }

  @override
  String get labBatchEntryValidationMessage =>
      'Correct le highlighted valeur avant continuing.';

  @override
  String get labResultEntryRequiredMessage =>
      'Enter un résultat valeur avant saving, submitting, ou verifying.';

  @override
  String labBatchValidationSummaryMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count selected tests need attention before this action can continue.',
      one: '1 selected test needs attention avant ce action can continuer.',
    );
    return '$_temp0';
  }

  @override
  String get labBatchValidationSummaryHint =>
      'Check le highlighted tests below et complete any missing ou invalide valeurs.';

  @override
  String labBatchActionFailedMessage(String actionLabel) {
    return '$actionLabel n\'a pas pu être completed.';
  }

  @override
  String labBatchActionValidationMessage(String actionLabel) {
    return '$actionLabel n\'un pas pu run because some selected tests still need attention.';
  }

  @override
  String labBatchActionFailedDetailMessage(String actionLabel, String detail) {
    return '$actionLabel échoué: $detail';
  }

  @override
  String get labBatchInvalidTransitionMessage =>
      'Some selected tests ne peut pas be vérifié yet. Enter et soumettre résultats pour le highlighted tests first, ou retirer rejeté tests de le selection.';

  @override
  String get labBatchItemNotFoundMessage =>
      'One ou more selected tests are non longer disponible. Refresh le commande et réessayer.';

  @override
  String get labBatchOrderNotSelectedMessage =>
      'The lab order n\'a pas pu être found. Close this dialog, reopen the order, and try again.';

  @override
  String get labApplyingResultChangesMessage => 'Updating résultats…';

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
  String get labWorkflowNextEnterResults => 'Enter résultats';

  @override
  String get labWorkflowNextVerifyResults => 'Verify résultats';

  @override
  String get labWorkflowNextReviewItems => 'Review en attente éléments';

  @override
  String get labReferenceRangeOverrideLabel => 'Reference range override';

  @override
  String get labInterpretationOverrideLabel => 'Manual interpretation';

  @override
  String get labResultFlagOverrideLabel => 'Result flag override';

  @override
  String clinicalLabResultReadyNotice(String patientName) {
    return 'Lab résultats are ready pour $patientName.';
  }

  @override
  String clinicalLabResultUpdatedNotice(String patientName) {
    return 'Lab résultats mis à jour pour $patientName.';
  }

  @override
  String clinicalLabResultCriticalNotice(String patientName) {
    return 'Critical laboratoire résultat pour $patientName needs review.';
  }

  @override
  String get labOrderFavoriteTestsLabel => 'Frequently utilisé tests';

  @override
  String get labBulkResultActionsTitle => 'Bulk actions';

  @override
  String get labSubmitResultAction => 'Submit résultat';

  @override
  String get labResultsSubmittedMessage => 'Results submitted.';

  @override
  String get labResultsVerifiedMessage => 'Results vérifié.';

  @override
  String get labSelectAllTestsAction => 'Select tous';

  @override
  String get labClearSelectionAction => 'Clear selection';

  @override
  String labSelectedTestCount(int selected, int total) {
    return '$selected of $total selected';
  }

  @override
  String get labRejectAllTestsAction => 'Reject tous tests';

  @override
  String get labRemoveAllDraftsAction => 'Remove drafts';

  @override
  String get labSaveAllDraftsAction => 'Save tous drafts';

  @override
  String get labSubmitAllResultsAction => 'Submit tous';

  @override
  String get labRemoveAllDraftsDialogTitle => 'Remove brouillon résultats?';

  @override
  String get labRemoveAllDraftsDialogBody =>
      'Ce will retirer tous saved ou entered brouillon résultats cette have not been vérifié.';

  @override
  String get labOrderStatusFieldLabel => 'Order statut';

  @override
  String get labTestStatusColumnLabel => 'Test statut';

  @override
  String get labReferenceRangeColumnLabel => 'Reference range';

  @override
  String get labResultInputColumnLabel => 'Result';

  @override
  String get labNoOrderItemsEntryTitle => 'No tests on ce commande';

  @override
  String get labNoOrderItemsEntryBody =>
      'Ce commande does not have any requested tests à enter résultats pour.';

  @override
  String get labNoSelectionTitle => 'Select un commande';

  @override
  String get labNoSelectionBody =>
      'Choose un laboratoire commande de le queue à enter, verify, et rapport résultats.';

  @override
  String get labPatientContextLabel => 'Lab patient context';

  @override
  String get labOrderFieldLabel => 'Lab commande';

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
  String get labNoResultsLabel => 'No vérifié résultats';

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
  String get labReleaseResultAction => 'Verify résultat';

  @override
  String get labReverseWorkflowAction => 'Reverse step';

  @override
  String get labViewCatalogAction => 'View catalog';

  @override
  String get labCatalogQcTitle => 'Catalog et QC';

  @override
  String get labCatalogTitle => 'Lab catalog';

  @override
  String get labQcTitle => 'Quality control';

  @override
  String get labBackendGapsTitle => 'Unavailable workflows';

  @override
  String get labBackendGapsBody =>
      'No indisponible workflow is blocking le displayed laboratoire queue.';

  @override
  String get labNoCatalogItemsLabel => 'Aucun catalog items trouvé';

  @override
  String get labNoQcLogsLabel => 'No QC logs recorded';

  @override
  String get labTestsTabLabel => 'Tests';

  @override
  String get labPanelsTabLabel => 'Panels';

  @override
  String get labRequestOrderDialogTitle => 'Request laboratoire commande';

  @override
  String get labPatientIdLabel => 'Patient ID';

  @override
  String get labEncounterIdLabel => 'Encounter ID';

  @override
  String get labOrderContextDialogBody =>
      'Search et sélectionner un existing patient. Encounter et existing commande context are facultatif where disponible.';

  @override
  String get labPatientSearchLabel => 'Patient';

  @override
  String get labPatientSearchHint =>
      'Search patient nom, ID, téléphone, ou identifiant';

  @override
  String get labEncounterContextLabel => 'Encounter';

  @override
  String get labEncounterContextHint => 'Search ou sélectionner consultation';

  @override
  String get labExistingOrderContextLabel =>
      'Existing laboratoire commande context';

  @override
  String get labExistingOrderContextHint =>
      'Search ou sélectionner commande context';

  @override
  String get labCatalogSearchLabel => 'Search laboratoire catalog';

  @override
  String get labCatalogSearchHint =>
      'Search tests, panels, codes, catégorie, ou specimen';

  @override
  String get labCreateOrderSubmitAction => 'Create laboratoire commande';

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
  String get labReleaseDialogTitle => 'Verify laboratoire résultat';

  @override
  String get labOrderItemFieldLabel => 'Order élément';

  @override
  String get labResultStatusLabel => 'Result statut';

  @override
  String get labResultValueLabel => 'Result valeur';

  @override
  String get labResultUnitLabel => 'Result unité';

  @override
  String get labResultTextLabel => 'Result text';

  @override
  String get labReportedAtInputLabel => 'Reported at';

  @override
  String get labReverseDialogTitle => 'Reverse laboratoire workflow';

  @override
  String get labReverseReasonLabel => 'Reason';

  @override
  String get labRecordQcDialogTitle => 'Record quality control';

  @override
  String get labQcTestFieldLabel => 'Lab test';

  @override
  String get labQcStatusFieldLabel => 'QC statut';

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
  String get labStatusCancelled => 'Annulé';

  @override
  String get labStatusPending => 'En attente';

  @override
  String get labStatusNormal => 'Normal';

  @override
  String get labStatusAbnormal => 'Abnormal';

  @override
  String get labStatusCritical => 'Critical';

  @override
  String get labStatusRejected => 'Rejeté';

  @override
  String get labStatusReceived => 'Received';

  @override
  String get labNextActionCancelled => 'Order annulé';

  @override
  String get labNextActionCollect => 'Enter résultat';

  @override
  String get labNextActionReceive => 'Enter résultat';

  @override
  String get labNextActionRelease => 'Verify résultat';

  @override
  String get labNextActionReviewCritical => 'Escalate critique résultat';

  @override
  String get labNextActionCompleted => 'Ready pour doctor review';

  @override
  String get labNextActionWatch => 'Review commande';

  @override
  String get labReportPreviewTitle => 'Result rapport aperçu';

  @override
  String get labReportTitle => 'Laboratory résultat rapport';

  @override
  String get labCopyReportAction => 'Copy rapport';

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
  String get labReportFooter => 'Generated de laboratory workflow data.';

  @override
  String get labGapBillingTitle => 'Payment et authorization gate';

  @override
  String get labGapBillingBody =>
      'Payment ou authorization blockers are not disponible pour ce laboratoire workbench.';

  @override
  String get labGapVerificationTitle => 'Separate vérification step';

  @override
  String get labGapVerificationBody =>
      'Order élément résultats can be released. Un separate vérifié-avant-release state is not disponible.';

  @override
  String get labGapReportGenerationTitle => 'Generated rapport';

  @override
  String get labGapReportGenerationBody =>
      'Le shared rapport aperçu is disponible. Un laboratoire-specific generated document is not disponible yet.';

  @override
  String get navigationOperationsLabel => 'Operations';

  @override
  String get navigationOperationsShortLabel => 'Operations';

  @override
  String get operationsTitle => 'Operations';

  @override
  String get operationsLoadingTitle => 'Loading operations';

  @override
  String get operationsLoadingBody =>
      'Loading maintenance demandes, actifs, et service logs.';

  @override
  String get operationsLiveStatus => 'Live synchronisation';

  @override
  String get operationsSavingStatus => 'Saving';

  @override
  String get operationsSavedMessage => 'Operations changes saved.';

  @override
  String get operationsCreateRequestAction => 'Create demande';

  @override
  String get operationsOpenReportAction => 'Report';

  @override
  String get operationsAllRequestsSummaryLabel => 'All demandes';

  @override
  String get operationsOpenSummaryLabel => 'Ouvrir';

  @override
  String get operationsInProgressSummaryLabel => 'In progress';

  @override
  String get operationsCompletedSummaryLabel => 'Terminé';

  @override
  String get operationsCancelledSummaryLabel => 'Annulé';

  @override
  String get operationsAssetsSummaryLabel => 'Assets';

  @override
  String get operationsQueueTitle => 'Maintenance queue';

  @override
  String get operationsQueueDescription =>
      'Track établissement repairs, actifs, safety notes, et readiness work.';

  @override
  String get operationsSearchLabel => 'Search operations';

  @override
  String get operationsSearchHint =>
      'Search demande, location, system, priorité, statut, assignee, ou notes';

  @override
  String get operationsClearFiltersAction => 'Clear filtres';

  @override
  String get operationsFiltersLabel => 'Operations filtres';

  @override
  String get operationsSearchFieldsLabel => 'Search champs';

  @override
  String get operationsAllFilterOption => 'Tous';

  @override
  String get operationsReportedDateFilterLabel => 'Reported date';

  @override
  String get operationsReportedFromLabel => 'Reported de';

  @override
  String get operationsReportedToLabel => 'Reported à';

  @override
  String get operationsPickReportedDateAction => 'Pick signalé date';

  @override
  String get operationsStatusFilterLabel => 'Statut';

  @override
  String get operationsPriorityFilterLabel => 'Priority';

  @override
  String get operationsFacilityFilterLabel => 'Facility';

  @override
  String get operationsAssetFilterLabel => 'Asset';

  @override
  String operationsPageLabel(int first, int last, int total) {
    return '$first - $last of $total demandes';
  }

  @override
  String get operationsNoRequestsTitle => 'No maintenance demandes';

  @override
  String get operationsNoRequestsBody =>
      'Create un demande ou adjust le filtres.';

  @override
  String get operationsDetailTitle => 'Request detail';

  @override
  String get operationsNoSelectionTitle => 'Select un demande';

  @override
  String get operationsNoSelectionBody =>
      'Choose un queue ligne à review assignments, service logs, et readiness notes.';

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
  String get operationsStatusColumnLabel => 'Statut';

  @override
  String get operationsDueColumnLabel => 'Due heure';

  @override
  String get operationsNextActionColumnLabel => 'Next action';

  @override
  String get operationsCategoryLabel => 'Category';

  @override
  String get operationsIssueTitle => 'Issue et notes';

  @override
  String get operationsActionsTitle => 'Actions';

  @override
  String get operationsAssignAction => 'Assign';

  @override
  String get operationsUpdateStatusAction => 'Update statut';

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
  String get operationsPartsVendorNoteLabel => 'Parts ou vendor note';

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
      'Service logs appear après un actif-backed repair is recorded.';

  @override
  String get operationsUnknownValue => 'Inconnu';

  @override
  String get operationsUnassignedValue => 'Unassigned';

  @override
  String get operationsNoDueTimeValue => 'No due heure';

  @override
  String get operationsNoNotesValue => 'No notes recorded.';

  @override
  String get operationsLocationNoteLabel => 'Location note';

  @override
  String get operationsIssueFieldLabel => 'Issue';

  @override
  String get operationsNotesLabel => 'Notes';

  @override
  String get operationsCreateRequestSubmitAction => 'Create demande';

  @override
  String get operationsAssigneeFieldLabel => 'Technician ou team';

  @override
  String get operationsSlaHoursFieldLabel => 'SLA hours';

  @override
  String get operationsTriageSummaryFieldLabel => 'Assignment note';

  @override
  String get operationsAssignSubmitAction => 'Save assignment';

  @override
  String get operationsStatusNoteLabel => 'Status note';

  @override
  String get operationsUpdateStatusSubmitAction => 'Save statut';

  @override
  String get operationsServiceNotesLabel => 'Service notes';

  @override
  String get operationsAddServiceLogSubmitAction => 'Save service log';

  @override
  String get operationsNoConfiguredAssetsOption => 'No configured actifs';

  @override
  String get operationsStatusOpen => 'Ouvrir';

  @override
  String get operationsStatusInProgress => 'In progress';

  @override
  String get operationsStatusCompleted => 'Terminé';

  @override
  String get operationsStatusCancelled => 'Annulé';

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
  String get operationsCategoryGeneralAsset => 'General actif';

  @override
  String get operationsCategorySafety => 'Safety';

  @override
  String get operationsCategoryOther => 'Autre';

  @override
  String get operationsNextActionAssign => 'Assign technician ou team';

  @override
  String get operationsNextActionServiceLog => 'Record service work';

  @override
  String get operationsNextActionUpdateStatus => 'Update repair statut';

  @override
  String get operationsNextActionCloseout => 'Add closeout note if needed';

  @override
  String get operationsNextActionCancelled => 'Request annulé';

  @override
  String get operationsNextActionReview => 'Review demande';

  @override
  String get operationsReportTitle => 'Operations rapport';

  @override
  String get operationsReportPreviewTitle => 'Report aperçu';

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
    return '$total demandes: $open ouvrir, $inProgress in progress, $completed terminé.';
  }

  @override
  String get navigationBiomedicalLabel => 'Biomedical engineering';

  @override
  String get navigationBiomedicalShortLabel => 'Biomedical';

  @override
  String get biomedicalTitle => 'Biomedical';

  @override
  String get biomedicalLoadingTitle => 'Loading biomédical';

  @override
  String get biomedicalLoadingBody =>
      'Loading équipement registry, work commandes, et compliance dossiers.';

  @override
  String get biomedicalLiveStatus => 'Live synchronisation';

  @override
  String get biomedicalSavingStatus => 'Saving';

  @override
  String get biomedicalSavedMessage => 'Biomedical changes saved.';

  @override
  String get biomedicalRegisterAssetAction => 'Register actif';

  @override
  String get biomedicalReportFaultAction => 'Report fault';

  @override
  String get biomedicalTotalEquipmentSummaryLabel => 'Total équipement';

  @override
  String get biomedicalOverduePmSummaryLabel => 'Overdue PM';

  @override
  String get biomedicalOpenWorkOrdersSummaryLabel => 'Open work commandes';

  @override
  String get biomedicalCriticalDowntimeSummaryLabel => 'Critical downtime';

  @override
  String get biomedicalActiveRecallsSummaryLabel => 'Active recalls';

  @override
  String get biomedicalAssetListTitle => 'Equipment worklist';

  @override
  String get biomedicalAssetListDescription =>
      'Search équipement, schedules, work commandes, downtime, recalls, et lifecycle dossiers.';

  @override
  String get biomedicalSearchLabel => 'Search biomédical';

  @override
  String get biomedicalSearchHint =>
      'Search actif tag, équipement, catégorie, location, statut, date, ou prestataire';

  @override
  String get biomedicalFiltersLabel => 'Biomedical filtres';

  @override
  String get biomedicalPanelFilterLabel => 'Panel';

  @override
  String get biomedicalStatusFilterLabel => 'Statut';

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
  String get biomedicalStatusColumnLabel => 'Statut';

  @override
  String get biomedicalOwnerColumnLabel => 'Owner';

  @override
  String get biomedicalNextActionColumnLabel => 'Next action';

  @override
  String get biomedicalPreviousPageLabel => 'Previous équipement';

  @override
  String get biomedicalNextPageLabel => 'Next équipement';

  @override
  String biomedicalPageLabel(int from, int to, int total) {
    return 'Showing $from-$to of $total';
  }

  @override
  String get biomedicalNoAssetsTitle => 'No équipement dossiers';

  @override
  String get biomedicalNoAssetsBody =>
      'Equipment dossiers matching ce recherche et filtre will appear here.';

  @override
  String get biomedicalDetailTitle => 'Equipment detail';

  @override
  String get biomedicalNoSelectionTitle => 'Select équipement';

  @override
  String get biomedicalNoSelectionBody =>
      'Choose équipement ou un related dossier à review readiness, work commandes, compliance, et lifecycle actions.';

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
  String get biomedicalReportsSectionTitle => 'Report aperçu';

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
  String get biomedicalStatusLabel => 'Statut';

  @override
  String get biomedicalPriorityLabel => 'Priority';

  @override
  String get biomedicalNextDueLabel => 'Next due';

  @override
  String get biomedicalLastUpdatedLabel => 'Last mis à jour';

  @override
  String get biomedicalTargetPathLabel => 'Audit path';

  @override
  String get biomedicalEditAssetAction => 'Edit actif';

  @override
  String get biomedicalTransferLocationAction => 'Transfer location';

  @override
  String get biomedicalScheduleMaintenanceAction => 'Schedule maintenance';

  @override
  String get biomedicalCreateWorkOrderAction => 'Create work commande';

  @override
  String get biomedicalUpdateWorkOrderAction => 'Update work commande';

  @override
  String get biomedicalStartWorkOrderAction => 'Start work commande';

  @override
  String get biomedicalReturnToServiceAction => 'Return à service';

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
  String get biomedicalDisposeTransferAction => 'Dispose ou transfert';

  @override
  String get biomedicalPrintReportAction => 'Preview rapport';

  @override
  String get biomedicalRegisterAssetDialogTitle => 'Register équipement';

  @override
  String get biomedicalEditAssetDialogTitle => 'Edit équipement';

  @override
  String get biomedicalTransferLocationDialogTitle =>
      'Transfer équipement location';

  @override
  String get biomedicalScheduleMaintenanceDialogTitle => 'Schedule maintenance';

  @override
  String get biomedicalWorkOrderDialogTitle => 'Create work commande';

  @override
  String get biomedicalUpdateWorkOrderDialogTitle => 'Update work commande';

  @override
  String get biomedicalStartWorkOrderDialogTitle => 'Start work commande';

  @override
  String get biomedicalReturnToServiceDialogTitle =>
      'Return équipement à service';

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
  String get biomedicalDisposalDialogTitle => 'Dispose ou transfert équipement';

  @override
  String get biomedicalFaultDialogTitle => 'Report équipement fault';

  @override
  String get biomedicalPrintReportDialogTitle => 'Biomedical rapport';

  @override
  String get biomedicalAssetNameLabel => 'Equipment nom';

  @override
  String get biomedicalAssetCodeLabel => 'Asset code';

  @override
  String get biomedicalSerialNumberLabel => 'Serial number';

  @override
  String get biomedicalRoomLabel => 'Chambre';

  @override
  String get biomedicalNotesLabel => 'Notes';

  @override
  String get biomedicalDescriptionLabel => 'Description';

  @override
  String get biomedicalWorkOrderTitleLabel => 'Work commande titre';

  @override
  String get biomedicalEngineerLabel => 'Engineer';

  @override
  String get biomedicalPlanNameLabel => 'Plan nom';

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
  String get biomedicalReportedEquipmentNameLabel => 'Temporary équipement nom';

  @override
  String get biomedicalPatientSafetyRiskLabel => 'Patient safety risk';

  @override
  String get biomedicalDateTimeHint => 'YYYY-MM-DDTHH:MM';

  @override
  String get biomedicalSubmitAction => 'Soumettre';

  @override
  String get biomedicalSaveAction => 'Enregistrer';

  @override
  String get biomedicalCreateAction => 'Créer';

  @override
  String biomedicalFieldRequiredLabel(String label) {
    return '$label est requis.';
  }

  @override
  String get biomedicalPanelOverview => 'Overview';

  @override
  String get biomedicalPanelRegistry => 'Registry';

  @override
  String get biomedicalPanelPreventive => 'Preventive';

  @override
  String get biomedicalPanelWorkOrders => 'Work commandes';

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
  String get biomedicalDatePresetThisMonth => 'Ce month';

  @override
  String get biomedicalNextActionMaintain => 'Perform maintenance';

  @override
  String get biomedicalNextActionCalibrate => 'Review compliance';

  @override
  String get biomedicalNextActionReturnService => 'Return à service';

  @override
  String get biomedicalNextActionReviewRecall => 'Review recall';

  @override
  String get biomedicalNextActionWorkOrder => 'Work commande follow-up';

  @override
  String get biomedicalNextActionReview => 'Review dossier';

  @override
  String get biomedicalPrintReportBody =>
      'Generated de biomédical registry, readiness, compliance, et lifecycle data.';

  @override
  String get integrationsLoadErrorTitle => 'Integrations n\'un pas pu load';

  @override
  String get integrationsLoadErrorBody =>
      'Refresh le espace de travail ou check service availability.';

  @override
  String get integrationsLoadingTitle => 'Loading intégrations';

  @override
  String get integrationsLoadingBody =>
      'Preparing intégrations, API keys, webhooks, et logs.';

  @override
  String get integrationsFailedStatusLabel => 'Failed';

  @override
  String get integrationsWarningStatusLabel => 'Avertissement';

  @override
  String get integrationsOperationalStatusLabel => 'Operational';

  @override
  String get integrationsWorkspaceTitle => 'Integrations';

  @override
  String get integrationsCreateIntegrationAction => 'Create intégration';

  @override
  String get integrationsCreateApiKeyAction => 'Create API key';

  @override
  String get integrationsCreateWebhookAction => 'Create webhook';

  @override
  String get integrationsAllSummaryLabel => 'Total éléments';

  @override
  String get integrationsActiveSummaryLabel => 'Actif';

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
      'Review intégrations, API keys, webhooks, sanitized logs, et interoperability readiness.';

  @override
  String get integrationsSearchLabel => 'Search intégrations';

  @override
  String get integrationsSearchHint =>
      'Search by nom, type, statut, owner, ou référence';

  @override
  String get integrationsFiltersLabel => 'Filtres';

  @override
  String get integrationsFilterAll => 'Tous';

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
  String get integrationsEmptyTitle => 'No intégration éléments';

  @override
  String get integrationsEmptyBody =>
      'Create un intégration, API key, ou webhook à populate ce espace de travail.';

  @override
  String get integrationsTypeColumnLabel => 'Type';

  @override
  String get integrationsNameColumnLabel => 'Nom';

  @override
  String get integrationsStatusColumnLabel => 'Statut';

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
  String get integrationsNoSelectionTitle => 'Select un intégration élément';

  @override
  String get integrationsNoSelectionBody =>
      'Choose un ligne à review configuration, keys, webhooks, logs, et disponible actions.';

  @override
  String get integrationsConfigureAction => 'Configure';

  @override
  String get integrationsTestConnectionAction => 'Test connexion';

  @override
  String get integrationsSyncNowAction => 'Sync now';

  @override
  String get integrationsDisableAction => 'Disable';

  @override
  String get integrationsEnableAction => 'Enable';

  @override
  String get integrationsManagePermissionsAction => 'Manage autorisations';

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
  String get integrationsActionResultTitle => 'Latest action résultat';

  @override
  String get integrationsMaskedSecretTitle => 'Masked key';

  @override
  String get integrationsRotationGapTitle => 'Key rotation indisponible';

  @override
  String get integrationsRotationGapBody =>
      'Create un replacement key, mettre à jour downstream systems, then revoke le ancien key.';

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
      'Interoperability actions are disponible.';

  @override
  String get integrationsConfigurationTitle => 'Configuration';

  @override
  String get integrationsConfigurationMaskedBody =>
      'Sensitive valeurs are masked in ce réponse.';

  @override
  String get integrationsConfigurationEmptyBody =>
      'No configuration valeurs are disponible pour ce intégration.';

  @override
  String get integrationsNoConfigurationRows => 'No configuration lignes';

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
  String get integrationsNoPermissions => 'No autorisations granted';

  @override
  String get integrationsRemovePermissionDialogTitle => 'Remove autorisation?';

  @override
  String get integrationsRemovePermissionDialogBody =>
      'Ce API key will immediately lose le selected autorisation.';

  @override
  String get integrationsRemovePermissionAction => 'Remove autorisation';

  @override
  String get integrationsNameFieldLabel => 'Nom';

  @override
  String get integrationsNameRequiredMessage => 'Enter un nom.';

  @override
  String get integrationsTypeFieldLabel => 'Type';

  @override
  String get integrationsConfigFieldLabel => 'Configuration';

  @override
  String get integrationsConfigCreateHelper =>
      'Enter one key=valeur setting per line. Sensitive keys are accepted but are not shown again.';

  @override
  String get integrationsConfigUpdateHelper =>
      'Enter only paramètres à change. Existing sensitive valeurs are not shown here.';

  @override
  String get integrationsCreateIntegrationSubmitAction => 'Create intégration';

  @override
  String get integrationsSaveIntegrationAction => 'Save intégration';

  @override
  String get integrationsApiKeyNameFieldLabel => 'Key nom';

  @override
  String get integrationsApiKeyNameRequiredMessage => 'Enter un key nom.';

  @override
  String get integrationsExpiresAtFieldLabel => 'Expires at';

  @override
  String get integrationsIsoDateHint => 'YYYY-MM-DD ou ISO timestamp';

  @override
  String get integrationsCreateApiKeySubmitAction => 'Create API key';

  @override
  String get integrationsIntegrationFieldLabel => 'Integration';

  @override
  String get integrationsEventFieldLabel => 'Event';

  @override
  String get integrationsEventRequiredMessage => 'Enter un event nom.';

  @override
  String get integrationsTargetUrlFieldLabel => 'Target URL';

  @override
  String get integrationsTargetUrlRequiredMessage => 'Enter un target URL.';

  @override
  String get integrationsWebhookActiveFieldLabel => 'Webhook actif';

  @override
  String get integrationsCreateWebhookSubmitAction => 'Create webhook';

  @override
  String get integrationsSaveWebhookAction => 'Save webhook';

  @override
  String get integrationsApiKeyFieldLabel => 'API key';

  @override
  String get integrationsApiKeyRequiredMessage => 'Choose un API key.';

  @override
  String get integrationsPermissionFieldLabel => 'Permission';

  @override
  String get integrationsPermissionRequiredMessage => 'Choose un autorisation.';

  @override
  String get integrationsAddPermissionAction => 'Add autorisation';

  @override
  String get integrationsCreateIntegrationDialogTitle => 'Create intégration';

  @override
  String get integrationsConfigureIntegrationDialogTitle =>
      'Configure intégration';

  @override
  String get integrationsCreateApiKeyDialogTitle => 'Create API key';

  @override
  String get integrationsCreateWebhookDialogTitle => 'Create webhook';

  @override
  String get integrationsEditWebhookDialogTitle => 'Edit webhook';

  @override
  String get integrationsManagePermissionsDialogTitle =>
      'Manage API key autorisations';

  @override
  String get integrationsSecretMissing => 'Secret not returned';

  @override
  String get integrationsApiKeyCreatedDialogTitle => 'API key créé';

  @override
  String get integrationsApiKeyCreatedSecretTitle => 'One-heure secret';

  @override
  String get integrationsApiKeyCreatedSecretBody =>
      'Ce valeur is shown once. Store it securely avant closing ce dialog.';

  @override
  String get integrationsCopySecretAction => 'Copy secret';

  @override
  String get integrationsTestConnectionDialogTitle => 'Test connexion?';

  @override
  String get integrationsTestConnectionDialogBody =>
      'Le system will run le intégration connexion test.';

  @override
  String get integrationsSyncNowDialogTitle => 'Sync now?';

  @override
  String get integrationsSyncNowDialogBody =>
      'Le system will enqueue un immediate intégration synchronisation.';

  @override
  String get integrationsEnableIntegrationDialogTitle => 'Enable intégration?';

  @override
  String get integrationsDisableIntegrationDialogTitle =>
      'Disable intégration?';

  @override
  String get integrationsEnableIntegrationDialogBody =>
      'Ce intégration will become disponible pour downstream workflows.';

  @override
  String get integrationsDisableIntegrationDialogBody =>
      'Ce intégration will stop participating in downstream workflows.';

  @override
  String get integrationsEnableApiKeyDialogTitle => 'Enable API key?';

  @override
  String get integrationsDisableApiKeyDialogTitle => 'Disable API key?';

  @override
  String get integrationsEnableApiKeyDialogBody =>
      'Ce API key can authenticate demandes again.';

  @override
  String get integrationsDisableApiKeyDialogBody =>
      'Ce API key will stop authenticating demandes.';

  @override
  String get integrationsEnableWebhookDialogTitle => 'Enable webhook?';

  @override
  String get integrationsDisableWebhookDialogTitle => 'Disable webhook?';

  @override
  String get integrationsEnableWebhookDialogBody =>
      'Ce webhook will receive matching events again.';

  @override
  String get integrationsDisableWebhookDialogBody =>
      'Ce webhook will stop receiving matching events.';

  @override
  String get integrationsRevokeApiKeyDialogTitle => 'Revoke API key?';

  @override
  String get integrationsRevokeApiKeyDialogBody =>
      'Ce permanently deletes le API key et its local autorisation grants.';

  @override
  String get integrationsReplayWebhookDialogTitle => 'Replay webhook?';

  @override
  String get integrationsReplayWebhookDialogBody =>
      'Le system will replay le webhook delivery.';

  @override
  String get integrationsReplayLogDialogTitle => 'Replay log?';

  @override
  String get integrationsReplayLogDialogBody =>
      'Le system will réessayer le logged intégration event.';

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
  String get integrationsFilterActive => 'Actif';

  @override
  String get integrationsFilterWarning => 'Avertissement';

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
  String get integrationsTypeRadiology => 'Radiologie';

  @override
  String get integrationsTypeBilling => 'Facturation';

  @override
  String get integrationsTypeOther => 'Autre';

  @override
  String get integrationsStatusActive => 'Actif';

  @override
  String get integrationsStatusInactive => 'Inactif';

  @override
  String get integrationsStatusError => 'Erreur';

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
  String get integrationsInteropMigrationScope => 'Migration import et export';

  @override
  String get integrationsInteropStatusScope => 'Readiness statut';

  @override
  String integrationsManyScopesLabel(String count) {
    return '$count scopes';
  }

  @override
  String get integrationsNextActionReviewFailure => 'Review échec';

  @override
  String get integrationsNextActionEnable => 'Enable élément';

  @override
  String get integrationsNextActionMonitor => 'Monitor';

  @override
  String get integrationsNextActionReviewKey => 'Review key';

  @override
  String get integrationsNextActionRotateOrMonitor => 'Rotate ou monitor';

  @override
  String get integrationsNextActionEnableWebhook => 'Enable webhook';

  @override
  String get integrationsNextActionMonitorDelivery => 'Monitor delivery';

  @override
  String get integrationsNextActionReplayOrEscalate => 'Replay ou escalate';

  @override
  String get integrationsNextActionReview => 'Review';

  @override
  String get integrationsNextActionRunEndpoint => 'Run action';

  @override
  String get integrationsNextActionUseStatusLogs => 'Use statut logs';

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
      'No dedicated interoperability readiness signal is disponible. Use intégration statut et sanitized logs.';

  @override
  String get integrationsSavedMessage => 'Integration changes saved.';

  @override
  String get reportsTitle => 'Reports et audit';

  @override
  String get reportsLoadingTitle => 'Loading rapports espace de travail';

  @override
  String get reportsLoadingBody =>
      'Fetching rapport definitions, runs, schedules, dashboards, et audit evidence.';

  @override
  String get reportsLiveStatus => 'Live';

  @override
  String get reportsSavingStatus => 'Saving';

  @override
  String get reportsRunAction => 'Run rapport';

  @override
  String get reportsScheduleAction => 'Schedule';

  @override
  String get reportsRetryAction => 'Retry';

  @override
  String get reportsCancelRunAction => 'Cancel run';

  @override
  String get reportsDownloadAction => 'Télécharger';

  @override
  String get reportsPrintAction => 'Imprimer';

  @override
  String get reportsExportEvidenceAction => 'Export evidence';

  @override
  String get reportsSearchLabel => 'Search rapports et logs';

  @override
  String get reportsSearchHint =>
      'Search rapport nom, module, owner, statut, ou dossier';

  @override
  String get reportsComplianceSearchHint =>
      'Search utilisateur, action, dossier, patient, purpose, ou reason';

  @override
  String get reportsClearSearchLabel => 'Clear rapports recherche';

  @override
  String get reportsFiltersLabel => 'Report filtres';

  @override
  String get reportsPanelFilterLabel => 'Workspace panneau';

  @override
  String get reportsStatusFilterLabel => 'Statut';

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
  String get reportsInvalidDateMessage => 'Enter un valid date.';

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
  String get reportsPanelDelivery => 'Runs et delivery';

  @override
  String get reportsPanelDashboards => 'Dashboards';

  @override
  String get reportsPanelMonitor => 'KPI monitor';

  @override
  String get reportsPanelActivity => 'Analytics activity';

  @override
  String get reportsPanelAudit => 'Audit logs';

  @override
  String get reportsPanelPhi => 'PHI accès';

  @override
  String get reportsPanelProcessing => 'Processing logs';

  @override
  String get reportsWorklistDescription =>
      'Search, filtre, aperçu, run, planning, print, et export rapport dossiers.';

  @override
  String get reportsComplianceDescription =>
      'Search et review audit, PHI accès, et data traitement logs within permitted scope.';

  @override
  String get reportsSchedulesTitle => 'Schedules';

  @override
  String get reportsSchedulesDescription =>
      'Saved schedules actualiser independently de rapport runs.';

  @override
  String get reportsNoItemsTitle => 'No rapport dossiers';

  @override
  String get reportsNoItemsBody =>
      'No rapport dossiers match le actuel filtres.';

  @override
  String get reportsNoSchedulesTitle => 'No schedules';

  @override
  String get reportsNoSchedulesBody =>
      'No saved rapport schedules match ce voir.';

  @override
  String get reportsNoComplianceLogsTitle => 'No compliance logs';

  @override
  String get reportsNoComplianceLogsBody =>
      'No audit ou compliance evidence matches le actuel filtres.';

  @override
  String get reportsPreviewTitle => 'Report aperçu';

  @override
  String get reportsComplianceDetailTitle => 'Evidence detail';

  @override
  String get reportsNoSelectionTitle => 'No selection';

  @override
  String get reportsNoSelectionBody =>
      'Choose un rapport definition, run, widget, KPI, event, ou planning à aperçu generated détails.';

  @override
  String get reportsNoComplianceSelectionBody =>
      'Choose un audit, PHI accès, ou traitement log à review evidence détails.';

  @override
  String get reportsNameColumnLabel => 'Nom';

  @override
  String get reportsStatusColumnLabel => 'Statut';

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
  String get reportsErrorLabel => 'Erreur';

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
  String get reportsIpAddressLabel => 'IP adresse';

  @override
  String get reportsDetailsLabel => 'Détails';

  @override
  String get reportsPreviousPageLabel => 'Previous page';

  @override
  String get reportsNextPageLabel => 'Next page';

  @override
  String reportsPageLabel(int first, int last, int total) {
    return '$first-$last of $total';
  }

  @override
  String get reportsTimelineTitle => 'Recent rapport activity';

  @override
  String get reportsTimelineDescription =>
      'Latest rapport runs, schedules, KPI snapshots, et analytics events.';

  @override
  String get reportsRunDialogTitle => 'Run rapport';

  @override
  String get reportsRetryDialogTitle => 'Retry rapport run';

  @override
  String get reportsScheduleDialogTitle => 'Schedule rapport';

  @override
  String get reportsFormatFieldLabel => 'Output format';

  @override
  String get reportsRetentionDaysFieldLabel => 'Retention days';

  @override
  String get reportsScheduleNameFieldLabel => 'Schedule nom';

  @override
  String get reportsFrequencyFieldLabel => 'Frequency';

  @override
  String get reportsTimeOfDayFieldLabel => 'Time sur day';

  @override
  String get reportsTimeOfDayHint => 'HH:mm';

  @override
  String get reportsCreateScheduleAction => 'Create planning';

  @override
  String get reportsFrequencyDaily => 'Daily';

  @override
  String get reportsFrequencyWeekly => 'Weekly';

  @override
  String get reportsFrequencyMonthly => 'Monthly';

  @override
  String get reportsCancelRunDialogTitle => 'Cancel rapport run';

  @override
  String get reportsCancelRunDialogBody =>
      'Cancel ce queued ou traitement rapport run? Le run ligne will actualiser après le system confirms le change.';

  @override
  String get reportsExportEvidenceDialogTitle => 'Export evidence';

  @override
  String get reportsExportEvidenceDialogBody =>
      'Generate un établissement-branded evidence document de ce audit dossier.';

  @override
  String get reportsSavedMessage => 'Reports espace de travail mis à jour.';

  @override
  String get reportsDownloadRequestedMessage =>
      'Report download was requested.';

  @override
  String get reportsPrintSubtitle => 'Generated rapport metadata';

  @override
  String get reportsEvidenceSubtitle => 'Compliance evidence';

  @override
  String get reportsGeneratedByLabel => 'Generated by';

  @override
  String get reportsPrintFooter =>
      'Confidential rapport document generated de system data.';

  @override
  String get reportsEvidenceFooter =>
      'Compliance evidence generated de audit data.';

  @override
  String get navigationPhysiotherapyLabel => 'Physiotherapy';

  @override
  String get navigationPhysiotherapyShortLabel => 'Physio';

  @override
  String get communicationsLoadingTitle => 'Loading communications';

  @override
  String get communicationsLoadingBody =>
      'Loading notifications, conversations, delivery state, et modèles.';

  @override
  String get communicationsWorkspaceTitle => 'Communications';

  @override
  String get communicationsLiveStatus => 'Live synchronisation';

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
      'Find alerts, threads, delivery state, et message modèles.';

  @override
  String get communicationsSearchSemanticLabel => 'Search communications';

  @override
  String get communicationsSearchHint =>
      'Search alert, patient, source, sender, recipient, ou message';

  @override
  String get communicationsClearSearchAction =>
      'Clear communications recherche';

  @override
  String get communicationsAdvancedFiltersLabel => 'Communication filtres';

  @override
  String get communicationsAdvancedFiltersTitle => 'Communication filtres';

  @override
  String get communicationsApplyFiltersAction => 'Apply filtres';

  @override
  String get communicationsResetFiltersAction => 'Reset filtres';

  @override
  String get communicationsQueueFilterLabel => 'Queue';

  @override
  String get communicationsFlagsFilterLabel => 'Flags';

  @override
  String get communicationsAllFilterLabel => 'Tous';

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
  String get communicationsStatusColumnLabel => 'Statut';

  @override
  String get communicationsLastMessageColumnLabel => 'Last message';

  @override
  String get communicationsTimeColumnLabel => 'Heure';

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
      'Matching workflow alerts et reminders will appear here.';

  @override
  String get communicationsNoDeliveriesTitle => 'No deliveries';

  @override
  String get communicationsNoDeliveriesBody =>
      'Notification channel delivery attempts will appear here.';

  @override
  String get communicationsNoTemplatesTitle => 'No modèles';

  @override
  String get communicationsNoTemplatesBody =>
      'Reusable communication modèles will appear here.';

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
      'Select un conversation';

  @override
  String get communicationsNoConversationSelectedBody =>
      'Choose un thread à review messages, participants, et linked dossiers.';

  @override
  String get communicationsNoNotificationSelectedTitle =>
      'Select un notification';

  @override
  String get communicationsNoNotificationSelectedBody =>
      'Choose un alert à review delivery historique et quick actions.';

  @override
  String get communicationsNoDeliverySelectedTitle => 'Select un delivery';

  @override
  String get communicationsNoDeliverySelectedBody =>
      'Choose un delivery attempt à review channel, recipient, et erreur détails.';

  @override
  String get communicationsNoTemplateSelectedTitle => 'Select un modèle';

  @override
  String get communicationsNoTemplateSelectedBody =>
      'Choose un modèle à review channel, subject, variables, et aperçu.';

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
  String get communicationsStatusLabel => 'Statut';

  @override
  String get communicationsVariablesLabel => 'Variables';

  @override
  String get communicationsPreviewTitle => 'Preview';

  @override
  String get communicationsMessageThreadTitle => 'Message thread';

  @override
  String get communicationsNoMessagesBody =>
      'No messages are disponible pour ce thread.';

  @override
  String get communicationsDeliveryHistoryTitle => 'Delivery historique';

  @override
  String get communicationsDeliveryErrorTitle => 'Delivery erreur';

  @override
  String get communicationsOpenLinkedRecordAction => 'Open linked dossier';

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
      'Mark ce conversation read pour votre compte.';

  @override
  String get communicationsMarkNotificationReadDialogBody =>
      'Mark ce notification read pour votre compte.';

  @override
  String get communicationsMarkNotificationUnreadDialogBody =>
      'Move ce notification retour à unread.';

  @override
  String get communicationsArchiveConversationDialogBody =>
      'Archive ce conversation de votre actif inbox.';

  @override
  String get communicationsUnarchiveConversationDialogBody =>
      'Return ce conversation à votre actif inbox.';

  @override
  String get communicationsArchiveNotificationDialogBody =>
      'Archive ce notification de votre actif alerts.';

  @override
  String get communicationsUnreadStatus => 'Unread';

  @override
  String get communicationsReadStatus => 'Read';

  @override
  String get communicationsArchivedStatus => 'Archived';

  @override
  String get communicationsSensitiveStatus => 'Sensitive';

  @override
  String get communicationsActiveStatus => 'Actif';

  @override
  String get communicationsInactiveStatus => 'Inactif';

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
      'You can voir ce thread but ne peut pas send messages.';

  @override
  String get communicationsFirstMessageHint =>
      'Send le first message à start ce conversation.';

  @override
  String get communicationsGroupMembersRequiredHelper =>
      'Add at least one member à créer le group.';

  @override
  String get communicationsConversationStartedMessage =>
      'Conversation started — send votre first message.';

  @override
  String get communicationsClientFilterNotice =>
      'Some filtres are applied locally until server support is disponible.';

  @override
  String get communicationsLoadMoreAction => 'Load more';

  @override
  String get communicationsBackToInboxAction => 'Back à inbox';

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
  String get communicationsGroupNameLabel => 'Group nom';

  @override
  String get communicationsSensitiveConversationLabel =>
      'Sensitive conversation';

  @override
  String get communicationsCreateGroupAction => 'Create group';

  @override
  String get housekeepingTitle => 'Housekeeping';

  @override
  String get housekeepingLoadingTitle => 'Loading entretien';

  @override
  String get housekeepingLoadingBody =>
      'Preparing cleaning tasks, schedules, lit turnover, et readiness.';

  @override
  String get housekeepingLiveStatus => 'Live synchronisation';

  @override
  String get housekeepingSavingStatus => 'Saving';

  @override
  String get housekeepingSavedMessage => 'Housekeeping changes saved.';

  @override
  String get housekeepingCreateTaskAction => 'Create task';

  @override
  String get housekeepingCreateScheduleAction => 'Create planning';

  @override
  String get housekeepingRequestMaintenanceAction => 'Request maintenance';

  @override
  String get housekeepingReportSummaryAction => 'Report';

  @override
  String get housekeepingPendingTasksSummaryLabel => 'Pending tasks';

  @override
  String get housekeepingCompletedTodaySummaryLabel => 'Completed aujourd\'hui';

  @override
  String get housekeepingOpenRequestsSummaryLabel => 'Open demandes';

  @override
  String get housekeepingOverdueRequestsSummaryLabel => 'Overdue demandes';

  @override
  String get housekeepingAssetsSummaryLabel => 'Assets';

  @override
  String get housekeepingWorklistDescription =>
      'Track cleaning tasks, schedules, lit turnover, et maintenance passations.';

  @override
  String get housekeepingSearchLabel => 'Search entretien';

  @override
  String get housekeepingSearchHint =>
      'Search location, chambre, lit, assignee, statut, priorité, ou date';

  @override
  String get housekeepingClearSearchAction => 'Clear recherche';

  @override
  String get housekeepingFiltersAction => 'Filtres';

  @override
  String get housekeepingFiltersTitle => 'Housekeeping filtres';

  @override
  String get housekeepingApplyFiltersAction => 'Apply filtres';

  @override
  String get housekeepingClearFiltersAction => 'Clear filtres';

  @override
  String get housekeepingPreviousPageLabel => 'Previous page';

  @override
  String get housekeepingNextPageLabel => 'Next page';

  @override
  String housekeepingPageLabel(int first, int last, int total) {
    return '$first - $last of $total éléments';
  }

  @override
  String get housekeepingEmptyQueueTitle => 'No entretien éléments';

  @override
  String get housekeepingEmptyQueueBody =>
      'No tasks, schedules, ou maintenance passations match le actuel filtres.';

  @override
  String get housekeepingTaskColumnLabel => 'Task';

  @override
  String get housekeepingLocationColumnLabel => 'Location';

  @override
  String get housekeepingAssigneeColumnLabel => 'Assignee';

  @override
  String get housekeepingDueColumnLabel => 'Due heure';

  @override
  String get housekeepingStatusColumnLabel => 'Statut';

  @override
  String get housekeepingNextActionColumnLabel => 'Next action';

  @override
  String get housekeepingNoSelectionTitle => 'Select un entretien élément';

  @override
  String get housekeepingNoSelectionBody =>
      'Choose un task, planning, ou maintenance passation à review readiness et disponible actions.';

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
      'Mark ce entretien task as in progress.';

  @override
  String get housekeepingCompleteAction => 'Complete';

  @override
  String get housekeepingCompleteDialogTitle => 'Complete cleaning';

  @override
  String get housekeepingCompleteDialogBody =>
      'Mark ce cleaning task as terminé et actualiser readiness.';

  @override
  String get housekeepingCancelAction => 'Annuler';

  @override
  String get housekeepingCancelDialogTitle => 'Cancel task';

  @override
  String get housekeepingCancelDialogBody => 'Cancel ce entretien task.';

  @override
  String get housekeepingMarkReadyAction => 'Mark ready';

  @override
  String get housekeepingBackendGapTooltip =>
      'Ce workflow is not disponible yet.';

  @override
  String get housekeepingTriageAction => 'Triage';

  @override
  String get housekeepingCompleteRequestAction => 'Complete demande';

  @override
  String get housekeepingCompleteRequestDialogTitle =>
      'Complete maintenance demande';

  @override
  String get housekeepingCompleteRequestDialogBody =>
      'Mark ce maintenance passation as terminé.';

  @override
  String get housekeepingCancelRequestAction => 'Cancel demande';

  @override
  String get housekeepingCancelRequestDialogTitle =>
      'Cancel maintenance demande';

  @override
  String get housekeepingCancelRequestDialogBody =>
      'Cancel ce maintenance passation.';

  @override
  String get housekeepingTaskReadinessBody =>
      'Cleaning progress et readiness are refreshed de le entretien task dossier.';

  @override
  String get housekeepingScheduleReadinessBody =>
      'Scheduled cleaning keeps ce location on un recurring readiness forfait.';

  @override
  String get housekeepingMaintenanceReadinessBody =>
      'Maintenance passations keep cleaning issues visible sans losing location context.';

  @override
  String get housekeepingUnavailableWorkflowsTitle => 'Unavailable workflows';

  @override
  String get housekeepingUnavailableWorkflowsBody =>
      'Ce espace de travail only exposes actions disponible pour le actuel établissement.';

  @override
  String get housekeepingFacilityFieldLabel => 'Facility';

  @override
  String get housekeepingFacilityFieldHint => 'Select un établissement';

  @override
  String get housekeepingRoomFieldLabel => 'Room ou lit';

  @override
  String get housekeepingRoomFieldHint => 'Select un chambre ou lit';

  @override
  String get housekeepingAssigneeFieldLabel => 'Assignee ou team';

  @override
  String get housekeepingAssigneeFieldHint => 'Select personnel ou team';

  @override
  String get housekeepingStatusFieldLabel => 'Statut';

  @override
  String get housekeepingStatusRequiredMessage => 'Select un statut.';

  @override
  String get housekeepingScheduledDateFieldLabel => 'Scheduled date';

  @override
  String get housekeepingCreateTaskSubmitAction => 'Create task';

  @override
  String get housekeepingFrequencyFieldLabel => 'Frequency';

  @override
  String get housekeepingFrequencyFieldHint =>
      'Daily, weekly, terminal clean, ou personnalisé';

  @override
  String get housekeepingFrequencyRequiredMessage =>
      'Enter un cleaning frequency.';

  @override
  String get housekeepingStartDateFieldLabel => 'Start date';

  @override
  String get housekeepingEndDateFieldLabel => 'End date';

  @override
  String get housekeepingCreateScheduleSubmitAction => 'Create planning';

  @override
  String get housekeepingAssetFieldLabel => 'Asset';

  @override
  String get housekeepingAssetFieldHint => 'Select actif ou fixture';

  @override
  String get housekeepingDescriptionFieldLabel => 'Description';

  @override
  String get housekeepingDescriptionFieldHint =>
      'Describe le issue ou cleaning concern';

  @override
  String get housekeepingDescriptionRequiredMessage => 'Enter un description.';

  @override
  String get housekeepingRequestMaintenanceSubmitAction => 'Create demande';

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
  String get housekeepingCreateTaskDialogTitle => 'Create entretien task';

  @override
  String get housekeepingCreateScheduleDialogTitle =>
      'Create cleaning planning';

  @override
  String get housekeepingRequestMaintenanceDialogTitle => 'Request maintenance';

  @override
  String get housekeepingAssignDialogTitle => 'Assign entretien task';

  @override
  String get housekeepingTriageDialogTitle => 'Triage maintenance passation';

  @override
  String get housekeepingReportSummaryTitle => 'Housekeeping rapport';

  @override
  String get housekeepingReportPreviewTitle => 'Report aperçu';

  @override
  String get housekeepingReportPreviewBody =>
      'Generated entretien rapport modèles are not disponible yet.';

  @override
  String get housekeepingResourceFilterLabel => 'Resource';

  @override
  String get housekeepingResourceTasks => 'Tasks';

  @override
  String get housekeepingResourceSchedules => 'Schedules';

  @override
  String get housekeepingResourceMaintenanceRequests => 'Maintenance demandes';

  @override
  String get housekeepingQueueFilterLabel => 'Queue';

  @override
  String get housekeepingQueueAll => 'Tous';

  @override
  String get housekeepingQueueToday => 'Today';

  @override
  String get housekeepingQueueOverdueTasks => 'Overdue tasks';

  @override
  String get housekeepingQueueOpenRequests => 'Open demandes';

  @override
  String get housekeepingQueueOverdueRequests => 'Overdue demandes';

  @override
  String get housekeepingStatusFilterLabel => 'Statut';

  @override
  String get housekeepingStatusAll => 'All statuses';

  @override
  String get housekeepingAllFacilities => 'All établissements';

  @override
  String get housekeepingFacilityFilterLabel => 'Facility';

  @override
  String get housekeepingRoomFilterLabel => 'Room ou lit';

  @override
  String get housekeepingAllRooms => 'All chambres et lits';

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
  String get housekeepingDateThisMonth => 'Ce month';

  @override
  String get housekeepingStatusScheduled => 'Scheduled';

  @override
  String get housekeepingStatusPending => 'En attente';

  @override
  String get housekeepingStatusInProgress => 'In progress';

  @override
  String get housekeepingStatusCompleted => 'Terminé';

  @override
  String get housekeepingStatusCancelled => 'Annulé';

  @override
  String get housekeepingStatusUnknown => 'Inconnu';

  @override
  String get housekeepingStatusOpen => 'Ouvrir';

  @override
  String get housekeepingStatusOpenLabel => 'Ouvrir';

  @override
  String get housekeepingStatusInProgressLabel => 'In progress';

  @override
  String get housekeepingNextActionAssign => 'Assign personnel ou team';

  @override
  String get housekeepingNextActionStart => 'Start cleaning';

  @override
  String get housekeepingNextActionComplete => 'Complete cleaning';

  @override
  String get housekeepingNextActionTriage => 'Triage passation';

  @override
  String get housekeepingNextActionReviewSchedule => 'Review planning';

  @override
  String get housekeepingNextActionNoAction => 'No action needed';

  @override
  String get housekeepingNextActionView => 'View détails';

  @override
  String get housekeepingLocationNotSet => 'Location not set';

  @override
  String get housekeepingNotRecorded => 'Not recorded';

  @override
  String get housekeepingUnassigned => 'Unassigned';

  @override
  String get physiotherapyTitle => 'Physiotherapy';

  @override
  String get physiotherapyLoadingTitle =>
      'Loading physiothérapie espace de travail';

  @override
  String get physiotherapyLoadingBody =>
      'Preparing orientations, sessions, soins forfaits, notes, et follow-ups.';

  @override
  String get physiotherapyLiveStatus => 'Live';

  @override
  String get physiotherapySavingStatus => 'Saving';

  @override
  String get physiotherapySavedMessage => 'Physiotherapy dossier saved.';

  @override
  String get physiotherapyReferralsSummaryLabel => 'Referrals';

  @override
  String get physiotherapyTodaySummaryLabel => 'Today';

  @override
  String get physiotherapyMissedSummaryLabel => 'Missed';

  @override
  String get physiotherapyActivePlansSummaryLabel => 'Active forfaits';

  @override
  String get physiotherapyFollowUpDueSummaryLabel => 'Follow-up due';

  @override
  String get physiotherapyCompletedSummaryLabel => 'Terminé';

  @override
  String get physiotherapyWorklistTitle => 'Therapy worklist';

  @override
  String get physiotherapyWorklistDescription =>
      'Referrals, therapy sessions, forfaits, notes, et follow-up work de disponible clinique dossiers.';

  @override
  String get physiotherapySearchLabel => 'Search physiothérapie worklist';

  @override
  String get physiotherapySearchHint =>
      'Search patient, consultation, therapist, forfait, ou session';

  @override
  String get physiotherapyFiltersLabel => 'Filtres';

  @override
  String get physiotherapyApplyFiltersAction => 'Apply filtres';

  @override
  String get physiotherapyClearFiltersAction => 'Clear filtres';

  @override
  String get physiotherapySearchFieldLabel => 'Search in';

  @override
  String get physiotherapyAllFieldsLabel => 'All champs';

  @override
  String get physiotherapyDateFilterLabel => 'Date';

  @override
  String get physiotherapyDateFromLabel => 'From';

  @override
  String get physiotherapyDateToLabel => 'To';

  @override
  String get physiotherapyTherapistFilterLabel => 'Therapist';

  @override
  String get physiotherapyTherapistFilterHint =>
      'Therapist nom ou utilisateur ID';

  @override
  String get physiotherapyQueueFilterLabel => 'Queue';

  @override
  String get physiotherapyFilterAll => 'Tous';

  @override
  String get physiotherapyScopeReferrals => 'Referrals';

  @override
  String get physiotherapyScopeToday => 'Today';

  @override
  String get physiotherapyScopeMissed => 'Missed';

  @override
  String get physiotherapyScopeActivePlans => 'Active forfaits';

  @override
  String get physiotherapyScopeFollowUpDue => 'Follow-up due';

  @override
  String get physiotherapyScopeCompleted => 'Terminé';

  @override
  String get physiotherapyScopeAll => 'All work';

  @override
  String get physiotherapyPatientColumnLabel => 'Patient';

  @override
  String get physiotherapySourceColumnLabel => 'Source';

  @override
  String get physiotherapySessionColumnLabel => 'Session';

  @override
  String get physiotherapyStatusColumnLabel => 'Statut';

  @override
  String get physiotherapyPlanColumnLabel => 'Plan';

  @override
  String get physiotherapyAttendanceColumnLabel => 'Attendance';

  @override
  String get physiotherapyBillingColumnLabel => 'Facturation';

  @override
  String get physiotherapyTherapistColumnLabel => 'Therapist';

  @override
  String get physiotherapyNextActionColumnLabel => 'Next action';

  @override
  String get physiotherapyTableColumnsTitle => 'Therapy tableau colonnes';

  @override
  String get physiotherapyApplyColumnsAction => 'Apply colonnes';

  @override
  String get physiotherapyResetColumnsAction => 'Reset colonnes';

  @override
  String get physiotherapyNoWorkTitle => 'No physiothérapie work';

  @override
  String get physiotherapyNoWorkBody =>
      'No orientations, sessions, forfaits, ou follow-ups match le actuel filtres.';

  @override
  String get physiotherapyDetailLoadingTitle => 'Loading therapy dossier';

  @override
  String get physiotherapyDetailLoadingBody =>
      'Fetching session historique, forfait, notes, et follow-up détails.';

  @override
  String get physiotherapyNoSelectionTitle => 'Select un therapy élément';

  @override
  String get physiotherapyNoSelectionBody =>
      'Choose un orientation ou session à review assessment, forfait, attendance, et follow-up actions.';

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
  String get physiotherapyReferralPanelTitle => 'Referral et forfait';

  @override
  String get physiotherapySourceLabel => 'Source';

  @override
  String get physiotherapyStatusLabel => 'Statut';

  @override
  String get physiotherapyAttendanceLabel => 'Attendance';

  @override
  String get physiotherapyPlanLabel => 'Plan';

  @override
  String get physiotherapyGoalLabel => 'Goal';

  @override
  String get physiotherapyInstructionsLabel => 'Instructions';

  @override
  String get physiotherapySessionsPanelTitle => 'Session historique';

  @override
  String get physiotherapyPlanPanelTitle => 'Care forfait';

  @override
  String get physiotherapyProgressNotesPanelTitle => 'Progress notes';

  @override
  String get physiotherapyFollowUpPanelTitle => 'Follow-ups';

  @override
  String get physiotherapyBackendGapsPanelTitle => 'Unavailable workflows';

  @override
  String get physiotherapyBackendGapBody =>
      'Ce espace de travail uses disponible shared clinique dossiers et lists indisponible dedicated physiothérapie workflows here.';

  @override
  String get physiotherapyNoRecordsLabel => 'No dossiers yet.';

  @override
  String get physiotherapyNoInstructionsLabel =>
      'No therapy instructions recorded.';

  @override
  String get physiotherapyAcceptReferralAction => 'Accept orientation';

  @override
  String get physiotherapyScheduleSessionAction => 'Schedule session';

  @override
  String get physiotherapyRecordAssessmentAction => 'Record assessment';

  @override
  String get physiotherapyRecordSessionAction => 'Record session';

  @override
  String get physiotherapyMarkAttendanceAction => 'Mark attendance';

  @override
  String get physiotherapyUpdatePlanAction => 'Update forfait';

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
      'Accept physiothérapie orientation';

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
  String get physiotherapyUpdatePlanDialogTitle => 'Update therapy forfait';

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
  String get physiotherapyAttendanceStatusFieldLabel => 'Attendance statut';

  @override
  String get physiotherapySummaryFieldLabel => 'Summary';

  @override
  String get physiotherapyStartDateFieldLabel => 'Start date';

  @override
  String get physiotherapyStartTimeFieldLabel => 'Start heure';

  @override
  String get physiotherapyEndDateFieldLabel => 'End date';

  @override
  String get physiotherapyEndTimeFieldLabel => 'End heure';

  @override
  String get physiotherapyDateFieldLabel => 'Date';

  @override
  String get physiotherapyTimeFieldLabel => 'Heure';

  @override
  String get physiotherapySaveAction => 'Enregistrer';

  @override
  String get physiotherapyStatusReferral => 'Referral';

  @override
  String get physiotherapyStatusAccepted => 'Accepted';

  @override
  String get physiotherapyStatusAssessment => 'Assessment';

  @override
  String get physiotherapyStatusToday => 'Today';

  @override
  String get physiotherapyStatusInTreatment => 'In traitement';

  @override
  String get physiotherapyStatusActivePlan => 'Active forfait';

  @override
  String get physiotherapyStatusFollowUpDue => 'Follow-up due';

  @override
  String get physiotherapyStatusMissed => 'Missed';

  @override
  String get physiotherapyStatusCompleted => 'Terminé';

  @override
  String get physiotherapyUnknownStatusLabel => 'Inconnu';

  @override
  String get physiotherapySourceReferral => 'Referral';

  @override
  String get physiotherapySourceAppointment => 'Appointment';

  @override
  String get physiotherapySourceCarePlan => 'Care forfait';

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
  String get physiotherapyAttendanceCompleted => 'Terminé';

  @override
  String get physiotherapyAttendanceCancelled => 'Annulé';

  @override
  String get physiotherapyAttendanceNoShow => 'No-afficher';

  @override
  String get physiotherapyBillingBackendGap =>
      'Billing authorization indisponible';

  @override
  String get physiotherapyMissingValueLabel => 'Not recorded';

  @override
  String get physiotherapyBackendGapStatusEndpoint =>
      'Dedicated physiothérapie episode et therapy statut are not disponible. Status is derived de procedures, soins forfaits, appointments, et follow-ups.';

  @override
  String get physiotherapyBackendGapBillingEndpoint =>
      'Billing authorization is indisponible pour ce physiothérapie context.';

  @override
  String get physiotherapyBackendGapReportEndpoint =>
      'Generated physiothérapie assessment et sortie rapports are not disponible. Printing uses le shared rapport modèle.';

  @override
  String get physiotherapyBackendGapUnknown =>
      'Un indisponible physiothérapie workflow was recorded.';

  @override
  String get physiotherapyInstructionsReportTitle =>
      'Physiotherapy instructions';

  @override
  String get physiotherapyReportPatientLabel => 'Patient';

  @override
  String get physiotherapyReportEncounterLabel => 'Encounter';

  @override
  String get physiotherapyReportPlanLabel => 'Plan et goals';

  @override
  String get physiotherapyReportInstructionsLabel => 'Instructions';

  @override
  String get physiotherapyReportSessionsLabel => 'Sessions';

  @override
  String get physiotherapyReportFooterNote =>
      'Generated de shared clinique workflow data.';

  @override
  String get mortuaryTitle => 'Mortuary';

  @override
  String get mortuaryLoadErrorTitle =>
      'Mortuary espace de travail indisponible';

  @override
  String get mortuaryLoadErrorBody =>
      'The mortuary workspace n\'a pas pu être loaded. Try again or contact an administrator if the issue continues.';

  @override
  String get mortuaryLoadingTitle => 'Loading morgue espace de travail';

  @override
  String get mortuaryLoadingBody =>
      'Retrieving cases, storage, custody, release, et billing information.';

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
  String get mortuaryActionsUnavailableTooltip =>
      'Ce action is not disponible yet.';

  @override
  String get mortuaryWorklistTitle => 'Mortuary worklist';

  @override
  String get mortuaryWorklistEmptyTitle => 'Aucun mortuary records trouvé';

  @override
  String get mortuaryWorklistEmptyBody =>
      'Adjust le filtres ou recherche terms à voir matching morgue dossiers.';

  @override
  String get mortuaryReferenceColumnLabel => 'Case';

  @override
  String get mortuaryDeceasedColumnLabel => 'Deceased';

  @override
  String get mortuarySourceColumnLabel => 'Source';

  @override
  String get mortuaryStorageColumnLabel => 'Storage';

  @override
  String get mortuaryStatusColumnLabel => 'Statut';

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
  String get mortuarySearchLabel => 'Search morgue dossiers';

  @override
  String get mortuarySearchHint =>
      'Search case, nom, source, storage, ou statut';

  @override
  String get mortuarySearchFieldLabel => 'Rechercher';

  @override
  String get mortuaryFiltersLabel => 'Filtres';

  @override
  String get mortuaryApplyFiltersAction => 'Apply';

  @override
  String get mortuaryResetFiltersAction => 'Réinitialiser';

  @override
  String get mortuaryAllFieldsLabel => 'Tous';

  @override
  String get mortuaryDateFilterLabel => 'Date';

  @override
  String get mortuaryDateFromLabel => 'From';

  @override
  String get mortuaryDateToLabel => 'To';

  @override
  String get mortuaryDatePickerButtonLabel => 'Choose date';

  @override
  String get mortuaryInvalidDateMessage => 'Enter un valid date.';

  @override
  String get mortuaryPanelFilterLabel => 'Panel';

  @override
  String get mortuaryResourceFilterLabel => 'Resource';

  @override
  String get mortuaryQueueFilterLabel => 'Queue';

  @override
  String get mortuaryStatusFilterLabel => 'Statut';

  @override
  String get mortuaryIdentificationFilterLabel => 'Identification';

  @override
  String get mortuaryFacilityFilterLabel => 'Facility';

  @override
  String get mortuaryStorageUnitFilterLabel => 'Storage unité';

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
  String get mortuaryDatePresetThisMonthLabel => 'Ce month';

  @override
  String get mortuaryTotalCasesSummaryLabel => 'Total cases';

  @override
  String get mortuaryIdentificationPendingSummaryLabel =>
      'Identification en attente';

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
  String get mortuaryResourceStorageUnitsLabel => 'Storage unités';

  @override
  String get mortuaryResourceStorageSlotsLabel => 'Storage slots';

  @override
  String get mortuaryResourceStorageAssignmentsLabel => 'Storage assignments';

  @override
  String get mortuaryResourceCustodyEventsLabel => 'Custody events';

  @override
  String get mortuaryResourceViewingsLabel => 'Viewings';

  @override
  String get mortuaryResourcePostMortemRequestsLabel => 'Post-mortem demandes';

  @override
  String get mortuaryResourceReleaseAuthorisationsLabel =>
      'Release authorisations';

  @override
  String get mortuaryResourceBillableEventsLabel => 'Billable events';

  @override
  String get mortuaryQueueIdentificationPendingLabel =>
      'Identification en attente';

  @override
  String get mortuaryQueueStorageExceptionsLabel => 'Storage exceptions';

  @override
  String get mortuaryQueueReleaseReadyLabel => 'Release ready';

  @override
  String get mortuaryQueueUnsettledBillingLabel => 'Unsettled billing';

  @override
  String get mortuaryQueuePostMortemPendingLabel => 'Post-mortem en attente';

  @override
  String get mortuaryDetailTitle => 'Case detail';

  @override
  String get mortuaryNoSelectionTitle => 'Select un case';

  @override
  String get mortuaryNoSelectionBody =>
      'Choose un dossier de le worklist à review identity, storage, custody, release, billing, et documents.';

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
  String get mortuaryBillingFieldLabel => 'Facturation';

  @override
  String get mortuaryStorageSlotFieldLabel => 'Storage slot';

  @override
  String get mortuaryFacilityFieldLabel => 'Facility';

  @override
  String get mortuaryActionGapTitle => 'Actions indisponible';

  @override
  String get mortuaryActionGapBody =>
      'Mortuary lookup data is disponible. Action buttons remain désactivé until le workflow is activé pour ce établissement.';

  @override
  String get mortuaryIdentitySectionTitle => 'Identity et source';

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
  String get mortuaryBillingSectionTitle => 'Facturation';

  @override
  String get mortuaryDocumentsSectionTitle => 'Documents';

  @override
  String get mortuaryCaseFieldLabel => 'Case';

  @override
  String get mortuaryDeceasedFieldLabel => 'Deceased';

  @override
  String get mortuaryPatientFieldLabel => 'Patient';

  @override
  String get mortuaryStatusFieldLabel => 'Statut';

  @override
  String get mortuaryReceivedAtFieldLabel => 'Received';

  @override
  String get mortuarySourceWorkflowFieldLabel => 'Source workflow';

  @override
  String get mortuarySourceDepartmentFieldLabel => 'Source département';

  @override
  String get mortuarySourceReferenceFieldLabel => 'Source référence';

  @override
  String get mortuaryReceivedFromFieldLabel => 'Received de';

  @override
  String get mortuaryStorageUnitFieldLabel => 'Storage unité';

  @override
  String get mortuaryStorageStatusFieldLabel => 'Storage statut';

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
      'Custody movements et handovers will appear here lorsque recorded.';

  @override
  String get mortuaryNoViewingsLabel => 'No viewings planifié';

  @override
  String get mortuaryNoViewingsBody =>
      'Viewing appointments will appear here lorsque planifié.';

  @override
  String get mortuaryNoPostMortemLabel => 'No post-mortem demande recorded';

  @override
  String get mortuaryNoPostMortemBody =>
      'Post-mortem demandes et rapports will appear here lorsque disponible.';

  @override
  String get mortuaryNoReleaseLabel => 'No release recorded';

  @override
  String get mortuaryNoReleaseBody =>
      'Release authorisations et handover détails will appear here lorsque disponible.';

  @override
  String get mortuaryNoBillingLabel => 'No billing events recorded';

  @override
  String get mortuaryNoBillingBody =>
      'Storage, post-mortem, et release billing events will appear here lorsque disponible.';

  @override
  String get mortuaryNoDocumentsBody =>
      'Generated intake, custody, release, et billing documents are disponible de le print action lorsque case data is selected.';

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
  String get mortuaryReportTitle => 'Mortuary case dossier';

  @override
  String get mortuaryReportFooter =>
      'Generated de morgue espace de travail data.';

  @override
  String get mortuaryReportGeneratedMessage => 'Mortuary document generated.';

  @override
  String get roomsBedsTitle => 'Rooms et lits';

  @override
  String get roomsBedsLoadingTitle => 'Loading chambres et lits';

  @override
  String get roomsBedsLoadingBody =>
      'Retrieving services, chambres, lits, assignments, et établissement context.';

  @override
  String get roomsBedsSavingStatus => 'Saving';

  @override
  String get roomsBedsLiveStatus => 'Live board';

  @override
  String get roomsBedsTotalSummaryLabel => 'Total lits';

  @override
  String get roomsBedsBackendGapsTitle => 'Bed readiness statut indisponible';

  @override
  String get roomsBedsBackendGapsBody =>
      'Cleaning, maintenance, block, isolation, et detailed readiness states are not disponible pour ce établissement. Current actions utiliser disponible service, chambre, lit, lit assignment, et IPD flow workflows only.';

  @override
  String get roomsBedsManageCatalogAction => 'Manage catalog';

  @override
  String get roomsBedsOpenIpdAdmissionAction => 'Open IPD admission';

  @override
  String get roomsBedsManageTransferAction => 'Manage transfert';

  @override
  String get roomsBedsTransferUpdateDialogTitle => 'Update transfert';

  @override
  String get roomsBedsOpenHousekeepingAction => 'Open entretien';

  @override
  String get roomsBedsOpenOperationsAction => 'Open operations';

  @override
  String get roomsBedsMarkCleaningAction => 'Mark cleaning';

  @override
  String get roomsBedsMarkMaintenanceAction => 'Mark maintenance';

  @override
  String get roomsBedsMarkBlockedAction => 'Mark blocked';

  @override
  String get roomsBedsNextActionCompleteTransfer => 'Complete transfert';

  @override
  String get roomsBedsNextActionMarkAvailable => 'Mark disponible';

  @override
  String get roomsBedsNextActionResolveMaintenance => 'Resolve maintenance';

  @override
  String get roomsBedsCleaningReadinessLabel => 'Awaiting turnover';

  @override
  String get roomsBedsMaintenanceReadinessLabel => 'Under maintenance';

  @override
  String get roomsBedsBlockedReadinessLabel => 'Blocked';

  @override
  String get roomsBedsOccupiedReadinessLabel => 'In utiliser';

  @override
  String get roomsBedsReservedReadinessLabel => 'Held';

  @override
  String get roomsBedsBoardTitle => 'Bed board';

  @override
  String get roomsBedsBoardDescription =>
      'Track availability, occupation, reservations, et lit readiness by établissement location.';

  @override
  String get roomsBedsSearchLabel => 'Search chambres et lits';

  @override
  String get roomsBedsSearchHint =>
      'Search lit, service, chambre, patient admission, statut, ou établissement';

  @override
  String get roomsBedsFiltersLabel => 'Filtres';

  @override
  String get roomsBedsAllFilterLabel => 'Tous';

  @override
  String get roomsBedsFacilityFilterLabel => 'Facility';

  @override
  String get roomsBedsAllFacilitiesLabel => 'All établissements';

  @override
  String get roomsBedsWardFilterLabel => 'Service';

  @override
  String get roomsBedsAllWardsLabel => 'All services';

  @override
  String get roomsBedsRoomFilterLabel => 'Chambre';

  @override
  String get roomsBedsAllRoomsLabel => 'All chambres';

  @override
  String get roomsBedsStatusFilterLabel => 'Statut';

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
  String get roomsBedsEmptyTitle => 'Aucun beds trouvé';

  @override
  String get roomsBedsEmptyBody =>
      'Adjust le filtres ou ajouter lits de établissement setup à start en utilisant le operational board.';

  @override
  String get roomsBedsBedColumnLabel => 'Lit';

  @override
  String get roomsBedsLocationColumnLabel => 'Location';

  @override
  String get roomsBedsStatusColumnLabel => 'Statut';

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
  String get roomsBedsMarkAvailableAction => 'Mark disponible';

  @override
  String get roomsBedsMarkOutOfServiceAction => 'Mark out sur service';

  @override
  String get roomsBedsAssignAction => 'Assign lit';

  @override
  String get roomsBedsReleaseAction => 'Release lit';

  @override
  String get roomsBedsRequestTransferAction => 'Request transfert';

  @override
  String get roomsBedsAssignmentHistoryTitle => 'Assignment historique';

  @override
  String get roomsBedsNoAssignmentsLabel => 'No assignment historique recorded';

  @override
  String get roomsBedsCurrentAssignmentLabel => 'Current';

  @override
  String get roomsBedsReleasedAssignmentLabel => 'Released';

  @override
  String get roomsBedsAdmissionFieldLabel => 'Admission number';

  @override
  String get roomsBedsAdmissionFieldHint => 'Enter le admission number';

  @override
  String get roomsBedsDestinationWardLabel => 'Destination service';

  @override
  String get roomsBedsAssignDialogTitle => 'Assign lit';

  @override
  String roomsBedsAssignWardSuitabilityHint(String wardType) {
    return 'Confirm patient suitability pour $wardType avant assigning ce lit.';
  }

  @override
  String get roomsBedsReleaseDialogTitle => 'Release lit';

  @override
  String get roomsBedsReleaseDialogBody =>
      'Releasing le lit sends le admission through le lit release flow.';

  @override
  String get roomsBedsTransferDialogTitle => 'Request transfert';

  @override
  String get roomsBedsTransferDialogBody =>
      'Choose le destination service. Bed selection is terminé by le IPD transfert workflow après approbation.';

  @override
  String roomsBedsAdmissionAssignment(String admissionId) {
    return 'Admission $admissionId';
  }

  @override
  String get roomsBedsAssignmentNotLinked => 'Assignment not linked';

  @override
  String get roomsBedsNextActionAssign => 'Assign suivant admission';

  @override
  String get roomsBedsNextActionReleaseOrTransfer => 'Release ou transfert';

  @override
  String get roomsBedsNextActionAssignOrReleaseHold => 'Assign ou release hold';

  @override
  String get roomsBedsNextActionResolveBlock => 'Resolve block';

  @override
  String get roomsBedsReadyLabel => 'Ready';

  @override
  String get roomsBedsUnavailableLabel => 'Unavailable';

  @override
  String get roomsBedsReadinessBackendGapLabel =>
      'Readiness statut indisponible';

  @override
  String get roomsBedsSavedMessage => 'Rooms et lits mis à jour.';

  @override
  String roomsBedsRequiredMessage(String field) {
    return '$field est requis.';
  }

  @override
  String get hrActivityDescription =>
      'Audit-style feed sur recent HR updates, roster publishes, et quart changes.';

  @override
  String get hrActivityTitle => 'HR activity';

  @override
  String get hrAddStaffAction => 'Add personnel';

  @override
  String get hrAddStaffDialogTitle => 'Add personnel profil';

  @override
  String get hrStaffOnboardingPersonSectionTitle => 'Staff détails et accès';

  @override
  String get hrStaffFirstNameLabel => 'Staff first nom';

  @override
  String get hrStaffLastNameLabel => 'Staff last nom';

  @override
  String get hrStaffEmailLabel => 'Staff e-mail';

  @override
  String get hrStaffPhoneLabel => 'Staff téléphone';

  @override
  String get hrStaffTemporaryPasswordLabel =>
      'Temporary mot de passe (facultatif)';

  @override
  String get hrStaffPasswordOptionalHint =>
      'Leave blank à auto-generate un secure mot de passe.';

  @override
  String get hrStaffNumberGenerateLabel => 'Generate';

  @override
  String get hrStaffNumberManualLabel => 'Enter manually';

  @override
  String get hrStaffNumberAutoGenerateLabel =>
      'Automatically generate personnel number';

  @override
  String get hrStaffNumberManualEntryLabel => 'Enter personnel number manually';

  @override
  String get hrStaffGenerateNumberAction => 'Generate';

  @override
  String get hrStaffOnboardingRolesSectionTitle => 'Roles et accès';

  @override
  String get hrStaffOnboardingCompensationEditHint =>
      'Update rémunération pour ce personnel member. New personnel can set pay later de personnel detail.';

  @override
  String get hrRoleAssignmentSearchLabel => 'Search rôles';

  @override
  String get hrRoleAssignmentAddRoleLabel => 'Add rôle';

  @override
  String get hrRoleAssignmentEmptySelectedLabel => 'No rôles selected yet.';

  @override
  String get hrRoleAssignmentRemoveRoleAction => 'Remove rôle';

  @override
  String get hrStaffOnboardingEmploymentSectionTitle => 'Employment';

  @override
  String get hrStaffOnboardingCreateNewUserLabel =>
      'Create nouveau utilisateur';

  @override
  String get hrStaffOnboardingLinkExistingUserLabel =>
      'Link existing utilisateur';

  @override
  String get hrStaffOnboardingSelectUserHint =>
      'Search personnel by nom ou e-mail';

  @override
  String get hrStaffOnboardingNoRolesWarning =>
      'No rôles assigné yet. Ce personnel member will have limited accès until rôles are assigné.';

  @override
  String get hrStaffOnboardingPayTypeLabel => 'Pay type';

  @override
  String get hrStaffOnboardingDailyRateLabel => 'Daily rate';

  @override
  String get hrStaffOnboardingAddressLabel => 'Address (facultatif)';

  @override
  String get hrStaffOnboardingPermissionsPreviewEmpty =>
      'Select rôles above à aperçu effective autorisations.';

  @override
  String get hrStaffOnboardingCompensationSectionTitle => 'Compensation';

  @override
  String get hrStaffOnboardingCompensationCreateHint =>
      'Optional. Set pay rate et effective date lorsque onboarding ce personnel member.';

  @override
  String get hrStaffOnboardingConsultationSectionTitle =>
      'Consultation billing';

  @override
  String get hrAllowPartialPublishLabel => 'Allow partial publish';

  @override
  String get hrApproveLeaveAction => 'Approve congé';

  @override
  String get hrApproveLeaveDialogTitle => 'Approve congé';

  @override
  String get hrApproveSwapAction => 'Approve swap';

  @override
  String get hrApproveSwapDialogTitle => 'Approve quart swap';

  @override
  String get hrAssignDepartmentAction => 'Assign département';

  @override
  String get hrAssignDepartmentDialogTitle => 'Assign département';

  @override
  String get hrAssignmentLabel => 'Assignment';

  @override
  String get hrAssignmentsSectionTitle => 'Assignments';

  @override
  String get hrAssignPositionAction => 'Assign position';

  @override
  String get hrAssignPositionDialogTitle => 'Assign position';

  @override
  String get hrAssignShiftAction => 'Assign quart';

  @override
  String get hrAssignShiftDialogTitle => 'Assign quart';

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
  String get hrDuplicateScheduleToAction => 'Duplicate à…';

  @override
  String get hrScheduleDuplicateToDialogTitle => 'Duplicate planning';

  @override
  String hrScheduleDuplicateToDialogDescription(String dayName) {
    return 'Replace le selected days avec $dayName\'s heure slots.';
  }

  @override
  String get hrWeeklyScheduleSectionTitle => 'Weekly planning';

  @override
  String get hrAvailabilityScheduleSourceLabel => 'Schedule source';

  @override
  String get hrAvailabilitySourceManual => 'Manual';

  @override
  String get hrAvailabilitySourceFromStaff => 'From personnel';

  @override
  String get hrAvailabilitySourceFromTemplate => 'From modèle';

  @override
  String get hrAvailabilityCopyFromStaffAction => 'Copy de personnel';

  @override
  String get hrAvailabilityCopyFromStaffLabel => 'Source personnel';

  @override
  String get hrAvailabilityCopyFromTemplateAction => 'Apply modèle';

  @override
  String get hrAvailabilityCopyFromTemplateLabel => 'Schedule modèle';

  @override
  String get hrAvailabilityDuplicateToAction => 'Duplicate à…';

  @override
  String get hrAvailabilityDuplicateToDialogTitle => 'Duplicate planning';

  @override
  String hrAvailabilityDuplicateToDialogDescription(String dayName) {
    return 'Replace le selected days avec $dayName\'s heure slots.';
  }

  @override
  String get hrAvailabilityEndAfterStartError =>
      'End time doit être after start time';

  @override
  String get hrAvailabilityNoDaysSelectedError =>
      'Add at least one heure slot on any day';

  @override
  String get hrAvailabilitySlotOverlapError =>
      'Time slots on le same day ne doit pas overlap';

  @override
  String get hrAvailabilityWeekScheduleTitle => 'Weekly planning';

  @override
  String get hrRemoveAvailabilitySlotAction => 'Remove slot';

  @override
  String get hrClearFiltersAction => 'Clear filtres';

  @override
  String get hrConsultationCurrencyLabel => 'Consultation devise';

  @override
  String get hrConsultationFeeLabel => 'Consultation fee';

  @override
  String get hrCreateStaffAction => 'Create personnel';

  @override
  String get hrDayOfWeekLabel => 'Day sur week';

  @override
  String get hrDepartmentColumnLabel => 'Department';

  @override
  String get hrDepartmentFilterLabel => 'Department';

  @override
  String get hrDepartmentLabel => 'Department';

  @override
  String get hrEditStaffAction => 'Edit personnel';

  @override
  String get hrEditStaffDialogTitle => 'Edit personnel profil';

  @override
  String get hrEffectiveFromLabel => 'Effective de';

  @override
  String get hrEffectiveToLabel => 'Effective à';

  @override
  String get hrEndDateLabel => 'End date';

  @override
  String get hrEndTimeLabel => 'End heure';

  @override
  String hrFieldRequiredLabel(String label) {
    return '$label est requis.';
  }

  @override
  String get hrFiltersLabel => 'Filtres';

  @override
  String get hrFridayLabel => 'Friday';

  @override
  String get hrGenerateRosterAction => 'Generate roster';

  @override
  String get hrHireDateLabel => 'Hire date';

  @override
  String get hrLeaveDialogTitle => 'Request congé';

  @override
  String get hrLeaveLabel => 'Leave';

  @override
  String get hrLeaveDaysLabel => 'Number sur days';

  @override
  String get hrLeaveDaysHelper =>
      'Auto-calculates le end date de le start date.';

  @override
  String get hrLeaveTypeLabel => 'Leave type';

  @override
  String get hrLeaveHalfDayLabel => 'Half-day congé';

  @override
  String get hrLeaveHalfDayHelper =>
      'Use pour un single morning ou afternoon away de work.';

  @override
  String get hrLeaveHalfDayPeriodLabel => 'Half-day period';

  @override
  String get hrLeaveHalfDaySingleDayError =>
      'Half-day congé must start et end on le same day.';

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
      'Tasks, patients, ou quart détails le covering colleague should know.';

  @override
  String get hrAddNewPositionLabel => 'Add un nouveau position';

  @override
  String get hrNewPositionLabel => 'New position nom';

  @override
  String get hrSelectShiftLabel => 'Shift';

  @override
  String get hrSelectShiftHint => 'Search shifts by nom, heure, ou département';

  @override
  String get hrStaffOverviewSectionTitle => 'Overview';

  @override
  String get hrRoomLabel => 'Chambre';

  @override
  String get hrCompensationAction => 'Compensation';

  @override
  String get hrCompensationDialogTitle => 'Update rémunération';

  @override
  String get hrCompensationSectionTitle => 'Compensation';

  @override
  String get hrCompensationLabel => 'Compensation';

  @override
  String get hrNoCompensationLabel => 'No rémunération dossiers';

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
  String get hrLeaveReportLabel => 'Leave résumé';

  @override
  String get hrLeaveRequestsSummaryLabel => 'Leave demandes';

  @override
  String get hrLeaveRequestTitle => 'Leave demande';

  @override
  String get hrLeaveSectionTitle => 'Leave';

  @override
  String get hrLiveStatus => 'Live';

  @override
  String get hrLoadingBody => 'Loading personnel dossiers et rosters.';

  @override
  String get hrLoadingTitle => 'Loading HR espace de travail';

  @override
  String get hrMondayLabel => 'Monday';

  @override
  String get hrNextActionAssignDepartment => 'Assign département';

  @override
  String get hrNextActionAssignPosition => 'Assign position';

  @override
  String get hrNextActionColumnLabel => 'Next action';

  @override
  String get hrNextActionReviewProfile => 'Review profil';

  @override
  String get hrNextPageLabel => 'Next personnel page';

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
  String get hrNoLeaveLabel => 'No congé recorded.';

  @override
  String get hrNoQueueItemsBody =>
      'No HR queue éléments match le actuel filtre.';

  @override
  String get hrNoQueueItemsTitle => 'No queue éléments';

  @override
  String get hrNoShiftsLabel => 'No shifts assigné.';

  @override
  String get hrNoStaffBody => 'No personnel profiles match le actuel filtres.';

  @override
  String get hrNoStaffSelectedBody =>
      'Select un personnel member à review assignments, availability, congé, shifts, et paie links.';

  @override
  String get hrNoStaffSelectedTitle => 'No personnel selected';

  @override
  String get hrNoStaffTitle => 'Aucun staff trouvé';

  @override
  String get hrNotesLabel => 'Notes';

  @override
  String get hrNotifyStaffLabel => 'Notify personnel';

  @override
  String get hrOverrideShiftAction => 'Override quart';

  @override
  String get hrOverrideShiftDialogTitle => 'Override quart';

  @override
  String hrPageLabel(int from, int to, int total) {
    return '$from-$to of $total';
  }

  @override
  String get hrPayrollDraftsSummaryLabel => 'Payroll drafts';

  @override
  String get hrPayrollDraftTitle => 'Payroll brouillon';

  @override
  String get hrPayrollReportLabel => 'Payroll résumé';

  @override
  String get hrPayrollRunDialogTitle => 'Run paie';

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
  String get hrPreviewStaffProfileReportAction => 'Preview personnel profil';

  @override
  String get hrPreviousPageLabel => 'Previous personnel page';

  @override
  String get hrPreviousQueuePageLabel => 'Previous queue page';

  @override
  String get hrProcessPayrollAction => 'Process paie';

  @override
  String get hrProcessPayrollDialogTitle => 'Process paie';

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
  String get hrQueueLeaveRequests => 'Leave demandes';

  @override
  String get hrQueueOverdueShifts => 'Overdue shifts';

  @override
  String get hrQueuePayrollDrafts => 'Payroll drafts';

  @override
  String get hrQueueRosterDrafts => 'Roster drafts';

  @override
  String get hrQueueSwapRequests => 'Swap demandes';

  @override
  String get hrQueueUnassignedShifts => 'Unassigned shifts';

  @override
  String get hrReasonLabel => 'Reason';

  @override
  String get hrRecordAvailabilityAction => 'Record availability';

  @override
  String get hrRejectLeaveAction => 'Reject congé';

  @override
  String get hrRejectLeaveDialogTitle => 'Reject congé';

  @override
  String get hrRejectSwapAction => 'Reject swap';

  @override
  String get hrRejectSwapDialogTitle => 'Reject quart swap';

  @override
  String get hrReplacePayrollItemsLabel => 'Replace existing paie éléments';

  @override
  String get hrReportsSectionTitle => 'Reports';

  @override
  String get hrRequestLeaveAction => 'Request congé';

  @override
  String get hrRolePositionColumnLabel => 'Role / position';

  @override
  String get hrRosterDraftsSummaryLabel => 'Roster drafts';

  @override
  String get hrRosterDraftTitle => 'Roster brouillon';

  @override
  String get hrRosterReportLabel => 'Roster rapport';

  @override
  String get hrRunPayrollAction => 'Run paie';

  @override
  String get hrSaturdayLabel => 'Saturday';

  @override
  String get hrSavedMessage => 'HR changes saved.';

  @override
  String get hrSaveStaffAction => 'Save personnel';

  @override
  String get hrSavingStatus => 'Saving';

  @override
  String get hrSearchHint =>
      'Search personnel, département, rôle, quart, ou statut';

  @override
  String get hrSearchLabel => 'Search HR dossiers';

  @override
  String get hrShiftIdLabel => 'Shift ID';

  @override
  String get hrShiftLabel => 'Shift';

  @override
  String get hrShiftQueueTitle => 'Shift queue élément';

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
  String get hrManageScheduleTemplatesTitle => 'Schedule modèles';

  @override
  String get hrManageScheduleTemplatesDescription =>
      'Reusable quart patterns pour roster generation et personnel scheduling.';

  @override
  String get hrNoShiftTemplatesLabel =>
      'No planning modèles yet. Create one à reuse quart patterns.';

  @override
  String get hrStaffColumnLabel => 'Staff';

  @override
  String get hrStaffDetailTitle => 'Staff detail';

  @override
  String get hrStaffDirectoryDescription =>
      'Search personnel by nom, département, position, rôle, et statut.';

  @override
  String get hrStaffDirectoryTitle => 'Staff directory';

  @override
  String get hrStaffLabel => 'Staff';

  @override
  String get hrStaffListReportLabel => 'Staff liste';

  @override
  String get hrStaffNameLabel => 'Staff nom';

  @override
  String get hrStaffNumberLabel => 'Staff number';

  @override
  String get hrStaffProfileReportTitle => 'Staff profil';

  @override
  String get hrStartDateLabel => 'Start date';

  @override
  String get hrStartTimeLabel => 'Start heure';

  @override
  String get hrStatusColumnLabel => 'Statut';

  @override
  String get hrSundayLabel => 'Sunday';

  @override
  String get hrSwapRequestTitle => 'Shift swap demande';

  @override
  String get hrSwapShiftAction => 'Swap quart';

  @override
  String get hrSwapShiftDialogTitle => 'Request quart swap';

  @override
  String get hrTargetStaffLabel => 'Target personnel';

  @override
  String get hrTenantIdLabel => 'Tenant ID';

  @override
  String get hrThursdayLabel => 'Thursday';

  @override
  String get hrTimeHint => 'HH:MM';

  @override
  String get hrTotalStaffSummaryLabel => 'Total personnel';

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
  String get hrSelectAllRoomsAction => 'Select tous';

  @override
  String get hrClearRoomsAction => 'Effacer';

  @override
  String get hrUserIdLabel => 'User ID';

  @override
  String get hrLinkedUserLabel => 'Linked utilisateur';

  @override
  String get hrSelectUserLabel => 'Link utilisateur compte';

  @override
  String get hrCreateUserAction => 'Create personnel';

  @override
  String get hrCreateUserDialogTitle => 'Create utilisateur compte';

  @override
  String get hrAssignRoleAction => 'Assign rôle';

  @override
  String get hrAssignRoleDialogTitle => 'Assign rôle';

  @override
  String get hrRevokeRoleAction => 'Revoke rôle';

  @override
  String get hrRevokeRoleDialogTitle => 'Revoke rôle';

  @override
  String get hrRolesSectionTitle => 'Roles et accès';

  @override
  String get hrNoRolesLabel => 'No rôles assigné.';

  @override
  String get hrModuleAccessAction => 'View module accès';

  @override
  String get hrModuleAccessDialogTitle => 'Module accès';

  @override
  String get hrModuleAccessSectionTitle => 'Subscribed modules';

  @override
  String get hrEffectivePermissionsTitle => 'Effective autorisations';

  @override
  String get hrNoModuleAccessLabel => 'No actif module entitlements.';

  @override
  String get hrOpenAccessAdminAction => 'Open in Users/Roles';

  @override
  String get hrManageAccessAction => 'Manage utilisateurs et rôles';

  @override
  String get hrAccessWorkspaceTitle => 'Staff accès';

  @override
  String get hrAccessWorkspaceDescription =>
      'Manage personnel utilisateur accounts, rôles, et autorisations pour votre organization.';

  @override
  String get hrAccessPanelUsers => 'Staff';

  @override
  String get hrAccessPanelRoles => 'Roles';

  @override
  String get hrAccessPanelPermissions => 'Permissions';

  @override
  String get hrAccessSearchLabel => 'Rechercher';

  @override
  String get hrAccessSearchHint => 'Search personnel, rôles, ou autorisations';

  @override
  String get hrPermissionAssignmentAddPermissionLabel => 'Add autorisation';

  @override
  String get hrPermissionAssignmentEmptySelectedLabel =>
      'No autorisations selected.';

  @override
  String get hrPermissionAssignmentRemovePermissionAction =>
      'Remove autorisation';

  @override
  String get hrPermissionAssignmentAvailableByModuleLabel =>
      'Available by module';

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
      'Mortuary — Post-mortem demande';

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
  String get hrAccessEmptyUsersLabel =>
      'No personnel accounts match votre recherche.';

  @override
  String get hrAccessEmptyRolesLabel => 'No rôles match votre recherche.';

  @override
  String get hrAccessEmptyPermissionsLabel =>
      'No autorisations match votre recherche.';

  @override
  String get hrAccessCreateRoleAction => 'Create rôle';

  @override
  String get hrAccessCreatePermissionAction => 'Create autorisation';

  @override
  String get hrAccessEditUserAction => 'Edit utilisateur';

  @override
  String get hrAccessEditRoleAction => 'Edit rôle';

  @override
  String get hrAccessEditPermissionAction => 'Edit autorisation';

  @override
  String get hrAccessAssignPermissionsAction => 'Assign autorisations';

  @override
  String get hrAccessRoleNameLabel => 'Role nom';

  @override
  String get hrAccessRoleDescriptionLabel => 'Description';

  @override
  String get hrAccessPermissionNameLabel => 'Permission nom';

  @override
  String get hrAccessPermissionDescriptionLabel => 'Description';

  @override
  String get hrAccessPositionTitleLabel => 'Position titre';

  @override
  String get hrAccessInitialRolesLabel => 'Initial rôles';

  @override
  String hrAccessPermissionCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count permissions',
      zero: 'No autorisations',
    );
    return '$_temp0';
  }

  @override
  String hrAccessStaffAssignmentCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count staff',
      zero: 'No personnel',
    );
    return '$_temp0';
  }

  @override
  String get hrAccessSystemColumnLabel => 'Système';

  @override
  String hrAccessRoleSummary(int permissionCount, int userCount) {
    String _temp0 = intl.Intl.pluralLogic(
      permissionCount,
      locale: localeName,
      other: '$permissionCount permissions',
      zero: 'No autorisations',
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
      zero: 'non rôles',
    );
    return 'Used by $_temp0';
  }

  @override
  String get hrAccessUserDetailTitle => 'User compte';

  @override
  String get hrAccessViewUserAction => 'Voir';

  @override
  String get hrAccessManageRolesPermissionsAction =>
      'Manage rôles & autorisations';

  @override
  String get hrAccessDirectPermissionsLabel => 'Direct autorisations';

  @override
  String get hrAccessAssignedRolesLabel => 'Assigned rôles';

  @override
  String get hrAccessEffectivePermissionsLabel => 'Effective autorisations';

  @override
  String get hrAccessOpenStaffProfileAction => 'Open personnel profil';

  @override
  String get hrAccessLinkedStaffLabel => 'Linked personnel';

  @override
  String get hrAccessTenantContextRequiredTitle => 'Tenant context requis';

  @override
  String get hrAccessTenantContextRequiredBody =>
      'Select un personnel member ou se connecter avec un locataire compte avant managing utilisateurs, rôles, et autorisations.';

  @override
  String get hrAccessRoleSyncSuccessMessage => 'Role autorisations mis à jour.';

  @override
  String get hrAccessSystemCriticalRoleBadge => 'System critique';

  @override
  String get hrAccessNonSystemRoleLabel => 'Non-system';

  @override
  String get hrAccessSelectAllRolesAction => 'Select tous rôles';

  @override
  String get hrAccessClearRolesAction => 'Clear rôles';

  @override
  String get hrAccessSelectAllPermissionsAction => 'Select tous autorisations';

  @override
  String get hrAccessClearPermissionsAction => 'Clear autorisations';

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
  String get hrAssignmentDetailDialogTitle => 'Assignment détails';

  @override
  String get hrAssignmentIdLabel => 'Assignment ID';

  @override
  String get hrEditAssignmentAction => 'Edit assignment';

  @override
  String get hrAssignmentActiveLabel => 'Actif';

  @override
  String get hrAssignmentEndedLabel => 'Ended';

  @override
  String get hrDateRangeOngoingLabel => 'Ongoing';

  @override
  String get hrAvailabilityWeekViewLabel => 'Week voir';

  @override
  String get hrAvailabilityMonthViewLabel => 'Month voir';

  @override
  String get hrAvailabilityCalendarEmptyBody =>
      'Record weekly availability à see le calendar.';

  @override
  String get hrAvailabilityLegendAvailableLabel => 'Available';

  @override
  String get hrAvailabilityLegendUnavailableLabel => 'Unavailable';

  @override
  String get hrAvailabilityLegendLeaveLabel => 'Approved congé';

  @override
  String get hrAvailabilityDayEmptyLabel =>
      'No heure slots recorded pour ce day.';

  @override
  String get hrAvailabilityAddSlotAction => 'Add slot';

  @override
  String get hrAvailabilityEditDayAction => 'Edit day';

  @override
  String get hrCompensationActionTooltip =>
      'Define ou mettre à jour pay structure pour ce personnel member.';

  @override
  String get hrRunPayrollActionTooltip =>
      'Calculate et process pay pour un pay period. Requires Financial Approve autorisation.';

  @override
  String get hrPayrollMissingCompensationTooltip =>
      'Add rémunération avant running paie.';

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
  String get hrCompensationDetailDialogTitle => 'Compensation détails';

  @override
  String get hrCompensationAddNewRateAction => 'Add nouveau rate';

  @override
  String get hrCompensationAddPayLineAction => 'Add pay line';

  @override
  String get hrCompensationRemovePayLineAction => 'Remove pay line';

  @override
  String get hrCompensationActiveStatusLabel => 'Actif';

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
    return 'No recorded activity pour $payType in ce period.';
  }

  @override
  String get hrPayrollMixedCurrencyWarning =>
      'Some rémunération lines utiliser un different devise et were excluded de le total.';

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
      'No paie line éléments pour ce personnel member in le selected period.';

  @override
  String get hrPayrollStaffCountLabel => 'Staff nombre';

  @override
  String get hrGrossPayLabel => 'Gross pay';

  @override
  String get hrNetPayLabel => 'Net pay';

  @override
  String get hrDeductionsLabel => 'Deductions';

  @override
  String get hrPayrollWizardProcessStepBody =>
      'Process will créer paie éléments et advance le run toward paid statut.';

  @override
  String get hrPayrollWizardPreviewAction => 'Preview';

  @override
  String get hrPayrollWizardReviewAction => 'Review';

  @override
  String get hrLeaveDetailDialogTitle => 'Leave détails';

  @override
  String get hrLeaveCoveringStaffLabel => 'Covering personnel';

  @override
  String get hrLeaveHandoverNotesLabel => 'Handover notes';

  @override
  String get hrLeaveReasonLabel => 'Reason';

  @override
  String get hrShiftDetailDialogTitle => 'Shift détails';

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
      'Record separation et optionally end assignments et revoke accès.';

  @override
  String get hrOffboardStaffDialogTitle => 'End employment';

  @override
  String get hrOffboardStaffDialogHint =>
      'Ce ends employment pour le personnel member. Active assignments can be fermé on le last working day.';

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
  String get hrOffboardEndAssignmentsLabel => 'End tous actif assignments';

  @override
  String get hrOffboardRevokeAccessLabel => 'Revoke system accès';

  @override
  String get hrOffboardFinalPayrollLabel => 'Schedule final paie';

  @override
  String hrSeparationBannerMessage(String separationType, String lastDay) {
    return '$separationType · Last day $lastDay';
  }

  @override
  String get hrShiftTemplateAction => 'Schedule modèles';

  @override
  String get hrShiftTemplateDialogTitle => 'Schedule pattern';

  @override
  String get hrSchedulePatternCreateTitle => 'Schedule pattern';

  @override
  String get hrSchedulePatternEditTitle => 'Edit planning pattern';

  @override
  String get hrCreateShiftTemplateAction => 'Create planning';

  @override
  String get hrEditShiftTemplateAction => 'Modifier';

  @override
  String get hrDeleteShiftTemplateAction => 'Supprimer';

  @override
  String get hrSchedulePatternEditAction => 'Modifier';

  @override
  String get hrSchedulePatternDeleteAction => 'Supprimer';

  @override
  String get hrScheduleTemplateIdLabel => 'Template ID';

  @override
  String get hrScheduleTemplateActiveLabel => 'Actif';

  @override
  String get hrScheduleTemplateInactiveLabel => 'Inactif';

  @override
  String get hrStatusLabel => 'Statut';

  @override
  String get hrCreatedAtLabel => 'Created';

  @override
  String get hrUpdatedAtLabel => 'Updated';

  @override
  String get hrShiftTypeDay => 'Day quart';

  @override
  String get hrShiftTypeNight => 'Night quart';

  @override
  String get hrShiftTypeSwing => 'Swing quart';

  @override
  String get hrShiftTypeOnCall => 'On call';

  @override
  String get hrShiftTemplateNameLabel => 'Template nom';

  @override
  String get hrPreviewPayrollAction => 'Preview paie';

  @override
  String get hrPreviewPayrollDialogTitle => 'Payroll aperçu';

  @override
  String get hrPreviewRosterAction => 'Preview roster generation';

  @override
  String get hrPreviewRosterDialogTitle => 'Roster generation aperçu';

  @override
  String get hrRosterCoverageLabel => 'Coverage';

  @override
  String get hrRosterGapsLabel => 'Staffing gaps';

  @override
  String get hrPasswordLabel => 'Temporary mot de passe';

  @override
  String get hrEmailLabel => 'E-mail';

  @override
  String get hrOnboardingModeExistingUser => 'Link existing utilisateur';

  @override
  String get hrOnboardingModeCreateUser => 'Create nouveau utilisateur';

  @override
  String get hrWednesdayLabel => 'Wednesday';

  @override
  String get hrWorkQueuesTitle => 'Work queues';

  @override
  String get hrWorkQueuesToolbarTooltip =>
      'Browse et act on tous queue types in one dialog.';

  @override
  String get copyAdmissionIdAction => 'Copy admission ID';

  @override
  String get copyUserIdAction => 'Copy utilisateur ID';

  @override
  String get copyIdentifierAction => 'Copy identifiant';

  @override
  String get admissionIdCopiedMessage => 'Admission ID copied.';

  @override
  String get userIdCopiedMessage => 'User ID copied.';

  @override
  String get identifierCopiedMessage => 'Identifier copied.';

  @override
  String get settingsWorkspaceSectionTitle =>
      'Administrative setup espace de travail';

  @override
  String get settingsWorkspaceSectionBody =>
      'Review locataire, établissement, accès, et sécurité setup readiness.';

  @override
  String get settingsWorkspaceLoadingTitle =>
      'Loading paramètres espace de travail';

  @override
  String get settingsWorkspaceLoadingBody =>
      'Loading setup readiness, actions, et référence data.';

  @override
  String get settingsWorkspaceErrorTitle =>
      'Settings espace de travail indisponible';

  @override
  String get settingsWorkspaceEmptyTitle => 'Aucun setup modules trouvé';

  @override
  String get settingsWorkspaceEmptyBody =>
      'No setup modules match le actuel filtres.';

  @override
  String get settingsWorkspaceContextTitle => 'Context résumé';

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
  String get settingsWorkspaceTotalRecordsLabel => 'Total dossiers';

  @override
  String get settingsWorkspaceChecklistTitle => 'Setup checklist';

  @override
  String get settingsWorkspaceQuickActionsTitle => 'Quick actions';

  @override
  String get settingsWorkspaceModuleGroupsTitle => 'Module groups';

  @override
  String get settingsWorkspaceSearchLabel => 'Search setup modules';

  @override
  String get settingsWorkspaceSearchHint => 'Search by module, group, ou route';

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
  String get settingsWorkspaceOpenAction => 'Ouvrir';

  @override
  String get settingsWorkspaceCreateAction => 'Créer';

  @override
  String get settingsWorkspaceRouteUnavailableLabel => 'Unavailable';

  @override
  String get settingsWorkspaceRouteUnavailableBody =>
      'Ce setup action is not disponible de ce page yet.';

  @override
  String get settingsWorkspaceTenantContextRequiredTitle =>
      'Tenant context requis';

  @override
  String get settingsWorkspaceTenantContextRequiredBody =>
      'Select un locataire à load administrative setup readiness.';

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
  String get settingsWorkspaceUsersAndAccessGroup => 'Users et accès';

  @override
  String get settingsWorkspaceSecurityGroup => 'Security';

  @override
  String get settingsWorkspaceUnknownLabel => 'Unavailable';

  @override
  String get settingsWorkspaceDependencyBlockedLabel =>
      'Waiting pour requis setup';

  @override
  String get settingsWorkspaceRequiredSetupLabel => 'Required setup';

  @override
  String get settingsWorkspaceOptionalSetupLabel => 'Optional setup';

  @override
  String get settingsWorkspaceNoQuickActionsBody =>
      'No setup action is currently disponible pour le selected context.';

  @override
  String get settingsWorkspaceNoModulesBody =>
      'No modules match le selected filtres.';

  @override
  String get settingsWorkspaceSelectTenantAction => 'Select locataire';

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
  String get settingsWorkspaceModuleRoom => 'Chambre';

  @override
  String get settingsWorkspaceModuleWard => 'Service';

  @override
  String get settingsWorkspaceModuleBed => 'Lit';

  @override
  String get settingsWorkspaceModuleAddress => 'Address';

  @override
  String get settingsWorkspaceModuleContact => 'Contact';

  @override
  String get settingsWorkspaceModuleUser => 'User';

  @override
  String get settingsWorkspaceModuleUserProfile => 'User profil';

  @override
  String get settingsWorkspaceModuleRole => 'Role';

  @override
  String get settingsWorkspaceModulePermission => 'Permission';

  @override
  String get settingsWorkspaceModuleRolePermission => 'Role autorisation';

  @override
  String get settingsWorkspaceModuleUserRole => 'User rôle';

  @override
  String get settingsWorkspaceModuleUserSession => 'User session';

  @override
  String get settingsWorkspaceModuleApiKey => 'API key';

  @override
  String get settingsWorkspaceModuleApiKeyPermission => 'API key autorisation';

  @override
  String get settingsWorkspaceModuleUserMfa => 'User MFA';

  @override
  String get settingsWorkspaceModuleOauthAccount => 'OAuth compte';

  @override
  String get pharmacyWorkflowReadinessTitle => 'Pharmacy workflow readiness';

  @override
  String get pharmacyWorkflowReadinessBody =>
      'Actions below follow le actuel commande, stock, batch, et attestation state.';

  @override
  String get pharmacyReadinessDispenseAvailable =>
      'Dispense is disponible pour le actuel commande state.';

  @override
  String get pharmacyReadinessDispenseBlocked =>
      'Dispense is blocked by le actuel commande, paiement, stock, ou authorization state.';

  @override
  String get pharmacyReadinessStockMapped =>
      'Medication éléments have stock mapping disponible.';

  @override
  String get pharmacyReadinessStockMissing =>
      'Some médicament éléments need stock mapping avant dispense.';

  @override
  String get pharmacyReadinessAttestationRequired =>
      'Prepared batches require attestation avant completion.';

  @override
  String get pharmacyReadinessAttestationClear =>
      'No prepared batch attestation is en attente.';

  @override
  String get pharmacyReadinessPrintReady =>
      'Medication printouts utiliser le configured print workflow.';

  @override
  String get commonSelectActionLabel => 'Sélectionner';

  @override
  String get commonSaveActionLabel => 'Enregistrer';

  @override
  String get commonNextActionLabel => 'Suivant';

  @override
  String get commonRemoveActionLabel => 'Retirer';

  @override
  String get labOrdersViewAction => 'Orders voir';

  @override
  String get labPatientsViewAction => 'Patients voir';

  @override
  String get labReferenceRangesAction => 'Lab Configurations';

  @override
  String get labTableColumnsTitle => 'Lab tableau colonnes';

  @override
  String get labApplyColumnsAction => 'Apply colonnes';

  @override
  String get labResetColumnsAction => 'Reset colonnes';

  @override
  String get labPatientsSummaryLabel => 'Patients';

  @override
  String get labPatientsAwaitingResultsSummaryLabel =>
      'Patients en attente de résultats';

  @override
  String get labPatientsProcessingSummaryLabel => 'Patients in traitement';

  @override
  String get labPatientsPendingVerificationSummaryLabel =>
      'Patients en attente vérification';

  @override
  String get labPatientsCriticalSummaryLabel =>
      'Patients avec critique résultats';

  @override
  String get labPatientsCompletedSummaryLabel => 'Patients terminé';

  @override
  String get labPatientsWorklistTitle => 'Patient laboratoire worklist';

  @override
  String get labPatientsWorklistDescription =>
      'Patients avec actif laboratoire commandes et résultat-entry work.';

  @override
  String get labNoPatientsTitle => 'No patients in laboratoire worklist';

  @override
  String get labNoPatientsBody =>
      'Adjust le queue filtre ou recherche term à find patient laboratoire work.';

  @override
  String get labOrdersColumnLabel => 'Orders';

  @override
  String get labPatientIdFieldLabel => 'Patient ID';

  @override
  String get labVerifyAllAction => 'Verify tous';

  @override
  String get labEntryStatusColumnLabel => 'Entry statut';

  @override
  String get labSelectOrderDialogTitle => 'Select laboratoire commande';

  @override
  String get labSelectOrderDialogBody =>
      'Ce patient has multiple actif laboratoire commandes. Select le commande à review.';

  @override
  String get labNoOrderItemsLabel => 'Aucun ordered tests trouvé';

  @override
  String get labTestCodeLabel => 'Test code';

  @override
  String get labVerifyResultAction => 'Verify résultat';

  @override
  String get labEditVerifiedResultAction => 'Edit vérifié résultat';

  @override
  String get labReopenVerifiedResultDialogTitle => 'Edit vérifié résultat';

  @override
  String get labReopenVerifiedResultDialogBody =>
      'Update le résultat valeur et provide un reason pour changing un vérifié résultat. Le corrected valeur is re-vérifié lorsque you enregistrer.';

  @override
  String get labReopenVerifiedReasonLabel => 'Reason pour modifier';

  @override
  String get labVerifiedResultReopenedMessage =>
      'Result reopened pour editing.';

  @override
  String get labRestoreOrderItemAction => 'Restore test';

  @override
  String get labRestoreOrderItemDialogTitle => 'Restore annulé test';

  @override
  String labRestoreOrderItemDialogBody(String testName) {
    return 'Restore \"$testName\"? It was annulé et will return à le actif worklist pour traitement.';
  }

  @override
  String get labDeleteOrderItemAction => 'Delete demande';

  @override
  String get labDeleteOrderItemDialogTitle => 'Delete test demande';

  @override
  String labDeleteOrderItemDialogBody(String testName) {
    return 'Delete \"$testName\" de ce commande? Ce removes le requested test entirely et ne peut pas be undone.';
  }

  @override
  String get labDeletePanelAction => 'Delete panneau';

  @override
  String get labDeletePanelDialogTitle => 'Delete laboratoire panneau';

  @override
  String labDeletePanelDialogBody(String panelName) {
    return 'Ce will retirer $panelName de le configurable laboratoire catalog. Un reason est requis pour le audit trail.';
  }

  @override
  String get labRejectOrderItemAction => 'Reject test';

  @override
  String get labResultFlagLabel => 'Flag';

  @override
  String get labVerifyResultDialogTitle => 'Enter et verify résultat';

  @override
  String get labNumericRangeValidationMessage => 'Enter un valid number.';

  @override
  String get labVerifyAllDialogTitle => 'Verify entered résultats';

  @override
  String get labRejectOrderItemDialogTitle => 'Reject requested test';

  @override
  String get labRejectReasonNotPerformedHere => 'Test not performed here';

  @override
  String get labRejectReasonInsufficientInfo => 'Insufficient information';

  @override
  String get labRejectReasonInvalidRequest => 'request invalide';

  @override
  String get labRejectReasonOther => 'Other reason';

  @override
  String get labRejectCustomReasonLabel => 'Custom reason';

  @override
  String get labReferenceRangesDialogTitle => 'Lab Configurations';

  @override
  String get labReferenceRangesDialogBody =>
      'Manage laboratoire tests, panels, unités, qualitative options, et référence ranges utilisé by backend résultat interpretation.';

  @override
  String get labConfigureTestAction => 'Configure test';

  @override
  String get labQcLogsAction => 'QC logs';

  @override
  String get labConfigureTestDialogTitle => 'Configure laboratoire test';

  @override
  String get labTestNameLabel => 'Test nom';

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
  String get labDefaultUnitLabel => 'Default unité';

  @override
  String get labUnitOptionsLabel => 'Unit options';

  @override
  String get labCommaSeparatedHelper =>
      'Separate multiple valeurs avec commas.';

  @override
  String get labQualitativeOptionsLabel => 'Qualitative résultat options';

  @override
  String get labGenderApplicabilityLabel => 'Gender applicability';

  @override
  String get labGenderAnyLabel => 'Any';

  @override
  String get labGenderMaleLabel => 'Homme';

  @override
  String get labGenderFemaleLabel => 'Femme';

  @override
  String get labAgeMinLabel => 'Age min';

  @override
  String get labAgeMaxLabel => 'Age max';

  @override
  String get labAgeUnitLabel => 'Age unité';

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
  String get labStatusPendingResults => 'Pending résultats';

  @override
  String get labStatusVerified => 'Verified';

  @override
  String get labStatusLow => 'Low';

  @override
  String get labStatusHigh => 'High';

  @override
  String get labNextActionVerify => 'Verify résultat';

  @override
  String get labNextActionEnterResult => 'Enter résultat';

  @override
  String get labCreateAction => 'Create Lab Order';

  @override
  String get labCreateChoiceDialogTitle => 'Create laboratory élément';

  @override
  String get labCreateChoiceDialogBody =>
      'Choose le laboratory dossier you want à créer.';

  @override
  String get labCreateOrderAction => 'Create laboratoire commande';

  @override
  String get labCreateOrderChoiceBody =>
      'Request tests ou panels pour un patient.';

  @override
  String get labCreateOrderDialogTitle => 'Create laboratoire commande';

  @override
  String get labCreateTestAction => 'Add test';

  @override
  String get labCreateTestChoiceBody =>
      'Add un configurable test à le laboratoire catalog.';

  @override
  String get labCreateTestDialogTitle => 'Create laboratoire test';

  @override
  String get labCreatePanelAction => 'Add panneau';

  @override
  String get labCreatePanelChoiceBody =>
      'Group existing tests into un reusable panneau.';

  @override
  String get labCreatePanelDialogTitle => 'Create laboratoire panneau';

  @override
  String get labPanelNameLabel => 'Panel nom';

  @override
  String get labPanelCodeLabel => 'Panel code';

  @override
  String get labPanelDescriptionLabel => 'Description';

  @override
  String get labReferenceRangesSearchHint =>
      'Search test, panneau, code, catégorie, specimen, unité, ou range';

  @override
  String get labActionColumnLabel => 'Action';

  @override
  String get labUnitRangeCountColumnLabel => 'Unit / ranges';

  @override
  String get labGenderOtherLabel => 'Autre';

  @override
  String get labGenderUnknownLabel => 'Inconnu';

  @override
  String get labAgeUnitWeeks => 'Weeks';

  @override
  String get labAddValueAction => 'Add valeur';

  @override
  String get labAddValueFieldHint => 'Type un valeur, then ajouter it';

  @override
  String get labEditOrderAction => 'Edit commande';

  @override
  String get labEditOrderDialogTitle => 'Edit laboratoire commande context';

  @override
  String get labUpdateOrderSubmitAction => 'Update laboratoire commande';

  @override
  String get labDeleteOrderAction => 'Delete commande';

  @override
  String get labDeleteTestAction => 'Delete test';

  @override
  String get labDeleteReasonLabel => 'Deletion reason';

  @override
  String get labDeleteReasonHint =>
      'Explain why ce laboratoire dossier should be supprimé';

  @override
  String get labDeleteReasonValidationMessage => 'Enter un deletion reason.';

  @override
  String get labDeleteOrderDialogTitle => 'Delete laboratoire commande';

  @override
  String labDeleteOrderDialogBody(String orderId) {
    return 'Ce will retirer laboratoire commande $orderId de le actif laboratory queue. Un reason est requis pour le audit trail.';
  }

  @override
  String get labDeleteTestDialogTitle => 'Delete laboratoire test';

  @override
  String labDeleteTestDialogBody(String testName) {
    return 'Ce will retirer $testName de le configurable laboratoire catalog. Un reason est requis pour le audit trail.';
  }

  @override
  String get labDeletedMessage => 'Laboratory dossier supprimé.';

  @override
  String get labDuplicateTestNameMessage =>
      'Un laboratoire test avec ce nom existe déjà.';

  @override
  String get labDuplicateTestCodeMessage =>
      'Un laboratoire test avec ce code existe déjà.';

  @override
  String get labDuplicatePanelNameMessage =>
      'Un laboratoire panneau avec ce nom existe déjà.';

  @override
  String get labDuplicatePanelCodeMessage =>
      'Un laboratoire panneau avec ce code existe déjà.';

  @override
  String get labUpdatePanelDialogTitle => 'Edit laboratoire panneau';

  @override
  String get labUpdatePanelAction => 'Edit panneau';

  @override
  String get labPanelTestsLabel => 'Panel tests';

  @override
  String get labPanelTestSelectLabel => 'Lab test';

  @override
  String get labPanelAddTestAction => 'Add test';

  @override
  String get labPanelSelectedTestsTitle => 'Selected tests';

  @override
  String get labPanelNoSelectedTests => 'No tests selected pour ce panneau.';

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
      one: '1 actif commande',
    );
    return '$_temp0';
  }

  @override
  String get labPreviewReportAction => 'Preview rapport';

  @override
  String get labPrintReportAction => 'Print rapport';

  @override
  String get labResetReportSelectionAction => 'Reset selection';

  @override
  String get labReportSelectionTitle => 'Select tests pour le rapport';

  @override
  String get labReportSelectionHint =>
      'Use le checkboxes on each résultat ligne below à choose what à print.';

  @override
  String get labReportOrderDetailsToggleLabel => 'Include commande détails';

  @override
  String get labReportOrderDetailsToggleHint =>
      'Show commande identifiants et dates above each résultats tableau.';

  @override
  String labReportSelectedTestCount(int selectedCount, int totalCount) {
    return '$selectedCount of $totalCount tests selected';
  }

  @override
  String get labReportIncludeColumnLabel => 'Include';

  @override
  String get labReportNoSelectionLabel => 'No rapport éléments selected';

  @override
  String get labOrdersIncludedLabel => 'Orders included';

  @override
  String get labRemoveDraftResultAction => 'Remove résultat';

  @override
  String get labRemoveDraftResultDialogTitle => 'Remove laboratoire résultat?';

  @override
  String get labRemoveDraftResultDialogBody =>
      'Ce brouillon résultat will be removed de le selected test.';

  @override
  String get labDraftRemovedMessage => 'Result removed.';

  @override
  String get labStatusFilled => 'Filled';

  @override
  String get labStatusPartiallyEntered => 'Partially entered';

  @override
  String get labStatusPartiallyFilled => 'Partially filled';

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
  String get commonYesLabel => 'Oui';

  @override
  String get commonNoLabel => 'Non';

  @override
  String get radiologyOrdersViewAction => 'Orders voir';

  @override
  String get radiologyPatientsViewAction => 'Patients voir';

  @override
  String get radiologyConfigurationsAction => 'Configurations';

  @override
  String get radiologyConfigurationsDialogTitle => 'Radiology configurations';

  @override
  String get radiologyConfigurationsDialogBody =>
      'Manage persisted imaging tests et customize standard catalog tests pour radiologie workflows.';

  @override
  String get radiologyConfigurationsLoadingTitle => 'Loading configurations';

  @override
  String get radiologyConfigurationsLoadingBody =>
      'Loading imaging tests et standard catalog entries.';

  @override
  String get radiologyPatientsSummaryLabel => 'Radiology patients';

  @override
  String get radiologyPatientsWaitingImagingSummaryLabel =>
      'Patients waiting imaging';

  @override
  String get radiologyPatientsWorklistTitle => 'Radiology patients';

  @override
  String get radiologyPatientsWorklistDescription =>
      'Patients grouped by actif imaging commandes, reporting statut, et suivant action.';

  @override
  String get radiologyNoPatientsTitle => 'No radiologie patients';

  @override
  String get radiologyNoPatientsBody =>
      'Patients avec imaging demandes matching ce recherche et filtre will appear here.';

  @override
  String get radiologyTableColumnsTitle => 'Radiology colonnes';

  @override
  String get radiologyApplyColumnsAction => 'Apply colonnes';

  @override
  String get radiologyResetColumnsAction => 'Reset colonnes';

  @override
  String get radiologyOrdersColumnLabel => 'Order(s)';

  @override
  String get radiologyOneActiveOrderLabel => '1 actif commande';

  @override
  String get radiologyReferenceSearchOptionalLabel =>
      'Catalog recherche (facultatif)';

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
      'Search radiologie configurations';

  @override
  String get radiologyConfigurationSearchHint =>
      'Search tests, modality, code, source, ou statut';

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
  String get radiologyTestNameLabel => 'Nom';

  @override
  String get radiologyTestCodeLabel => 'Code';

  @override
  String get radiologyTestCodeOptionalLabel => 'Code (facultatif)';

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
      'Create un personnalisé imaging test ou actualiser le standard catalog.';

  @override
  String get radiologyReadOnlyStandardTestTitle => 'Standard test is read-only';

  @override
  String get radiologyReadOnlyStandardTestMessage =>
      'Standard catalog lignes ne peut pas be edited directly. Copy one à enregistrer un personnalisé test.';

  @override
  String get radiologyDeleteImagingTestDialogTitle => 'Delete imaging test?';

  @override
  String get radiologyTenantRequiredForConfigMessage =>
      'Tenant context est requis avant un personnalisé imaging test can be saved.';

  @override
  String get radiologyEquipmentRecordsTitle => 'Equipment dossiers';

  @override
  String get radiologyEquipmentRecordsBody =>
      'Equipment is managed through le existing équipement registry.';

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
      'Search équipement nom, code, serial, manufacturer, model, catégorie, ou statut';

  @override
  String get radiologyNoEquipmentTitle => 'No équipement dossiers';

  @override
  String get radiologyNoEquipmentBody =>
      'Equipment registry dossiers matching ce recherche will appear here.';

  @override
  String get radiologyEquipmentLinkGapTitle =>
      'Test équipement mapping indisponible';

  @override
  String get radiologyEquipmentLinkGapBody =>
      'Le actuel backend schema does not persist un direct imaging-test-à-équipement relationship, so ce espace de travail does not enregistrer local-only mappings.';

  @override
  String get radiologySaveConfigurationAction => 'Save configuration';

  @override
  String get radiologyAttachImagesTitle => 'Attach images';

  @override
  String get radiologyAttachImagesBody =>
      'Choose one ou more images, ajouter captions, then upload à attach them à ce study.';

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
      'Insert un existing actif ou PACS référence into le rapport text.';

  @override
  String get radiologyNoReportReferencesLabel =>
      'No actif ou PACS references disponible.';

  @override
  String get radiologyAssetReferencePrefix => 'Asset référence';

  @override
  String get radiologyPacsReferencePrefix => 'PACS référence';

  @override
  String get radiologyPrintReportAction => 'Print rapport';

  @override
  String get radiologyPrintReportDialogTitle => 'Print radiologie rapport';

  @override
  String get radiologyPrintReportDialogBody =>
      'Choose clinique rapport sections à include. Patient context, test détails, findings, impression, et signer are selected by par défaut; metadata is facultatif.';

  @override
  String get radiologyPrintPreviewTitle => 'Print aperçu';

  @override
  String get radiologyPrintAction => 'Imprimer';

  @override
  String get radiologyPrintIncludeHeaderLabel => 'Facility/app en-tête';

  @override
  String get radiologyPrintIncludePatientLabel => 'Patient détails';

  @override
  String get radiologyPrintIncludeOrderLabel => 'Encounter/commande détails';

  @override
  String get radiologyPrintIncludeStudiesLabel => 'Imaging tests/studies';

  @override
  String get radiologyPrintIncludeReportLabel => 'Findings et rapport text';

  @override
  String get radiologyPrintIncludeReferencesLabel => 'Image/PACS references';

  @override
  String get radiologyPrintIncludeSignerLabel => 'Signer/reporter';

  @override
  String get radiologyPrintIncludeMetadataLabel => 'Technical metadata';

  @override
  String get radiologyPrintFooterNote =>
      'Generated de HMS Radiology espace de travail.';

  @override
  String get radiologyPrintReportTitle => 'Radiology rapport';

  @override
  String get radiologyPrintPatientSectionTitle => 'Patient détails';

  @override
  String get radiologyPrintOrderSectionTitle => 'Encounter et commande détails';

  @override
  String get radiologyPrintStudiesSectionTitle => 'Imaging tests et studies';

  @override
  String get radiologyPrintReportSectionTitle => 'Findings et rapport';

  @override
  String get radiologyPrintReferencesSectionTitle => 'Image et PACS references';

  @override
  String get radiologyPrintSignerSectionTitle => 'Signer et reporter';

  @override
  String get radiologyPrintNoSectionsSelected =>
      'No rapport sections selected.';

  @override
  String get radiologyPatientIdLabel => 'Patient ID';

  @override
  String get radiologyFinalizationRequestedLabel => 'Finalization requested';

  @override
  String get radiologyFinalizationAttestedLabel => 'Finalization attested';

  @override
  String radiologyActiveOrdersLabel(int count) {
    return '$count actif commandes';
  }

  @override
  String radiologyDeleteImagingTestDialogBody(String name) {
    return 'Delete $name? Ce personnalisé imaging test will non longer be disponible pour nouveau demandes.';
  }

  @override
  String radiologyInsertAssetReferenceAction(String label) {
    return 'Insert actif: $label';
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
  String get clinicalRequestAddCatalogItemsAction => 'Add éléments';

  @override
  String get clinicalRequestReviewBillingAction => 'Review billing';

  @override
  String get clinicalRequestCatalogPickerDoneAction => 'Done';

  @override
  String get clinicalRequestMainPanelHelp =>
      'Review votre selection below. Use Add éléments à browse le catalog, then review billing avant submitting.';

  @override
  String clinicalRequestFlowItemCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 élément',
      zero: 'No éléments',
    );
    return '$_temp0';
  }

  @override
  String get clinicalLabRequestCatalogPickerTitle => 'Choose laboratoire tests';

  @override
  String get clinicalRadiologyCatalogPickerTitle => 'Choose imaging study';

  @override
  String get clinicalRadiologyAddStudyAction => 'Add study';

  @override
  String get clinicalProcedureCatalogPickerTitle => 'Choose procedures';

  @override
  String get clinicalPrescriptionLineDialogTitle => 'Add medicine';

  @override
  String get clinicalPrescriptionEditLineDialogTitle => 'Edit medicine';

  @override
  String get clinicalPrescriptionNoMedicinesLabel => 'No medicines added yet';

  @override
  String get clinicalRequestBillingNoItemsLabel =>
      'Add éléments à see pricing.';

  @override
  String get clinicalRequestBillingTotalLabel => 'Total';

  @override
  String get clinicalRequestPriceNotSetLabel => 'Price not set';

  @override
  String get clinicalRequestPriceWarningLabel =>
      'Some éléments have non prix set';

  @override
  String get clinicalRequestUnitPriceLabel => 'Unit prix';

  @override
  String get clinicalRequestQuantityLabel => 'Qty';

  @override
  String get clinicalRequestEditPricesHint =>
      'Set ou adjust prices per élément, ou charge un single montant.';

  @override
  String get ipdWardRoundFeeLabel => 'Doctor review fee';

  @override
  String get theaterCaseFeeLabel => 'Operation / procédure fee';

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
      'Timing, modality, et paiement context';

  @override
  String get radiologyViewModeImagingFloorLabel => 'Imaging floor';

  @override
  String get radiologyViewModeReportingLabel => 'Reporting';

  @override
  String get radiologyViewModeToggleLabel => 'View mode';

  @override
  String get radiologyWorkflowStepReceiveDescription =>
      'Acknowledge le incoming imaging demande';

  @override
  String get radiologyWorkflowStepReviewDescription =>
      'Review study détails et clinique notes';

  @override
  String get radiologyWorkflowStepPerformDescription =>
      'Mark le imaging study as performed';

  @override
  String get radiologyWorkflowStepUploadDescription =>
      'Upload images et synchronisation actifs';

  @override
  String get radiologyWorkflowStepReportDescription =>
      'Draft et modifier le radiologie rapport';

  @override
  String get radiologyWorkflowStepReleaseDescription =>
      'Release le finalized rapport';

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
      'Perform le study avant uploading images.';

  @override
  String get radiologyStudiesReportPreviewTitle => 'Report aperçu';

  @override
  String get radiologyDoctorReviewOpenReportAction => 'Open rapport';

  @override
  String get radiologyDoctorReviewAcknowledgeAction => 'Acknowledge review';

  @override
  String get radiologyReportInlineEditHelper =>
      'Edit le brouillon below ou ouvrir le full editor.';

  @override
  String get radiologyReportLivePreviewTitle => 'Live aperçu';

  @override
  String get radiologyStudyFormHelper =>
      'Optional détails can be adjusted avant saving.';

  @override
  String get radiologyReleaseReportSummaryTitle => 'Report résumé';

  @override
  String get radiologyReleaseEmptyDraftMessage =>
      'Add rapport content avant releasing.';

  @override
  String get radiologyPrescriptionBillOnDispenseLabel => 'Bill on dispense';

  @override
  String get radiologyPrescriptionPayAtPrescribeLabel => 'Pay at prescribe';

  @override
  String get accessAdminTitle => 'Users et accès';

  @override
  String get accessAdminLoadingTitle => 'Loading accès espace de travail';

  @override
  String get accessAdminLoadingBody =>
      'Fetching utilisateurs, rôles, autorisations, et entitlements.';

  @override
  String get accessAdminSavingStatus => 'Saving accès changes';

  @override
  String get accessAdminLiveStatus => 'Access espace de travail en direct';

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
  String get accessAdminActivateRegistrationAction => 'Activate compte';

  @override
  String get accessAdminRejectRegistrationAction => 'Reject';

  @override
  String get accessAdminActiveUsersLabel => 'Active utilisateurs';

  @override
  String get accessAdminRolesLabel => 'Roles';

  @override
  String get accessAdminPermissionsLabel => 'Permissions';

  @override
  String get accessAdminModulesLabel => 'Active modules';

  @override
  String get accessAdminSearchLabel => 'Search accès dossiers';

  @override
  String get accessAdminSearchHint =>
      'Search by nom, e-mail, rôle, ou autorisation';

  @override
  String get accessAdminStatusLabel => 'Statut';

  @override
  String get accessAdminAllStatusesLabel => 'All statuses';

  @override
  String get accessAdminEmptyTitle => 'Aucun access records trouvé';

  @override
  String get accessAdminEmptyBody =>
      'Adjust filtres ou créer utilisateurs et rôles à populate ce espace de travail.';

  @override
  String get accessAdminColumnId => 'ID';

  @override
  String get accessAdminColumnName => 'Nom';

  @override
  String get accessAdminColumnDetails => 'Détails';

  @override
  String get accessAdminColumnStatus => 'Statut';

  @override
  String get accessAdminDetailTitle => 'Access dossier';

  @override
  String get accessAdminCreateUserAction => 'Create utilisateur';

  @override
  String get accessAdminCreateRoleAction => 'Create rôle';

  @override
  String get accessAdminEmailLabel => 'E-mail';

  @override
  String get accessAdminPositionLabel => 'Position titre';

  @override
  String get accessAdminPasswordLabel => 'Mot de passe';

  @override
  String get accessAdminPasswordHint =>
      'Password doit être at least 8 characters.';

  @override
  String get accessAdminRoleNameLabel => 'Role nom';

  @override
  String get accessAdminRoleDescriptionLabel => 'Description';

  @override
  String get accessAdminAssignedRolesLabel => 'Assigned rôles';

  @override
  String get accessAdminEffectivePermissionsLabel => 'Effective autorisations';

  @override
  String get accessAdminOpenHrProfileAction => 'Open HR profil';

  @override
  String get accessAdminClinicalRoleHint =>
      'Ce rôle unlocks OPD/IPD clinique workflow actions.';

  @override
  String get accessAdminDeactivateAction => 'Deactivate utilisateur';

  @override
  String get accessAdminActivateAction => 'Activate utilisateur';

  @override
  String get accessAdminResetDemoPasswordAction => 'Reset démo mot de passe';

  @override
  String get accessAdminDeleteRoleAction => 'Delete rôle';

  @override
  String get accessAdminTenantContextRequiredTitle => 'Tenant context requis';

  @override
  String get accessAdminTenantContextRequiredBody =>
      'Select un locataire et établissement avant managing utilisateurs et rôles.';

  @override
  String get settingsAccessAdminActionTitle => 'Users et accès';

  @override
  String get settingsAccessAdminActionBody =>
      'Manage personnel accounts, rôle assignments, autorisations, et démo utilisateurs.';

  @override
  String get hrReferenceStaffPositionNurse => 'Infirmier';

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
  String get hrReferenceStaffPositionDoctor => 'Médecin';

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
      'Per procédure / per task';

  @override
  String get hrReferenceLeaveTypeAnnual => 'Annual congé';

  @override
  String get hrReferenceLeaveTypeSick => 'Sick congé';

  @override
  String get hrReferenceLeaveTypeMaternity => 'Maternity congé';

  @override
  String get hrReferenceLeaveTypePaternity => 'Paternity congé';

  @override
  String get hrReferenceLeaveTypeCompassionate =>
      'Compassionate / bereavement congé';

  @override
  String get hrReferenceLeaveTypeUnpaid => 'Unpaid congé';

  @override
  String get hrReferenceLeaveTypeStudy => 'Study / training congé';

  @override
  String get hrReferenceLeaveTypeEmergency => 'Emergency congé';

  @override
  String get hrReferenceLeaveTypeOther => 'Other congé';

  @override
  String get hrReferenceLeaveHalfDayPeriodMorning => 'Morning';

  @override
  String get hrReferenceLeaveHalfDayPeriodAfternoon => 'Afternoon';
}
