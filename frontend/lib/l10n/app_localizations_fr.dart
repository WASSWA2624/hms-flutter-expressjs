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
  String get startupLoadingTitle => 'Démarrage de l\'application';

  @override
  String get startupLoadingBody => 'Préparation des services locaux.';

  @override
  String get startupErrorTitle => 'L\'application n\'a pas pu démarrer';

  @override
  String get startupErrorBody => 'Redémarrez l\'application ou réessayez.';

  @override
  String get commonRetryActionLabel => 'Réessayer';

  @override
  String get commonRefreshActionLabel => 'Actualiser';

  @override
  String get workspaceToolbarOverflowLabel => 'Plus d\'actions';

  @override
  String get workspaceNotificationsMenuLabel => 'Notifications';

  @override
  String workspaceToolbarOverflowAttentionTooltip(int count) {
    return 'More actions — $count éléments need attention';
  }

  @override
  String get workspaceToolbarSectionStaffAccess => 'Staff & accès';

  @override
  String get workspaceToolbarSectionScheduling => 'Planification et roulement';

  @override
  String get workspaceToolbarSectionApprovals => 'Approbations et alertes';

  @override
  String get workspaceToolbarSectionActivity => 'Activité et audit';

  @override
  String get workspaceToolbarSectionWorkspace => 'Espace de travail';

  @override
  String get workspaceToolbarSectionFacilities => 'Établissements';

  @override
  String get workspaceNotificationsToolbarTooltip =>
      'Jump directly à queues cette need votre attention.';

  @override
  String get workspaceFullscreenEnterLabel => 'Plein écran';

  @override
  String get workspaceFullscreenExitLabel => 'Quitter le plein écran';

  @override
  String get workspaceGlobalFaultReportAction => 'Report équipement fault';

  @override
  String get workspaceGlobalHousekeepingRequestAction =>
      'Demander une maintenance';

  @override
  String get commonTableSettingsActionLabel => 'Table paramètres';

  @override
  String get emergencyCaseDialogTitle => 'Cas d\'urgence';

  @override
  String get icuStayDialogTitle => 'Séjour en soins intensifs';

  @override
  String get icuLoadingBoardTitle => 'Chargement du tableau de soins intensifs';

  @override
  String get icuLoadingBoardBody =>
      'Loading intensive soins patients et alert state.';

  @override
  String get icuLiveSyncLabel => 'Live synchronisation';

  @override
  String get icuSavingLabel => 'Enregistrement';

  @override
  String get icuViewPatientBoard => 'Tableau des patients';

  @override
  String get icuViewBedBoard => 'Tableau des lits';

  @override
  String get icuAllIcuLabel => 'Tous les soins intensifs';

  @override
  String get icuActiveIcuLabel => 'Soins intensifs actifs';

  @override
  String get icuCriticalAlertsLabel => 'Alertes critiques';

  @override
  String get icuTransfersLabel => 'Transferts';

  @override
  String get icuDischargeReadyLabel => 'Prêt pour la sortie';

  @override
  String get icuEndedStaysLabel => 'Séjours terminés';

  @override
  String get icuTransferPendingLabel => 'Transfer en attente';

  @override
  String get icuBoardTitle => 'Tableau des soins intensifs';

  @override
  String get icuBoardDescription => 'Grouped by lit state et alert level.';

  @override
  String get icuSearchHint => 'Search patient, admission, lit, ou alert';

  @override
  String get icuBoardScopeLabel => 'Portée du tableau';

  @override
  String get icuBoardFiltersTitle => 'ICU board filtres';

  @override
  String get icuColumnBedLabel => 'Lit';

  @override
  String get icuColumnAlertLabel => 'Alerte';

  @override
  String get icuColumnTransferLabel => 'Transfert';

  @override
  String get icuColumnStartLabel => 'Début des soins intensifs';

  @override
  String get icuColumnSourceLabel => 'Source';

  @override
  String get icuNoPatientsTitle => 'Aucun patient en soins intensifs';

  @override
  String get icuNoPatientsBody =>
      'Les admissions actives aux soins intensifs apparaîtront ici après l’admission IPD et le transfert aux soins intensifs.';

  @override
  String get icuNoAlertLabel => 'Aucune alerte';

  @override
  String get icuDetailEmptyTitle =>
      'Aucun séjour en soins intensifs sélectionné';

  @override
  String get icuDetailEmptyBody =>
      'Select un ICU patient à review observations, commandes, alerts, et transfert readiness.';

  @override
  String get icuDetailLoadingTitle => 'Chargement du séjour en soins intensifs';

  @override
  String get icuDetailLoadingBody =>
      'Loading observations, alerts, et transfert state.';

  @override
  String get icuAdmissionLabel => 'Admission';

  @override
  String get icuLocationLabel => 'Emplacement';

  @override
  String get icuFacilityLabel => 'Établissement';

  @override
  String get icuAdmittedLabel => 'Admis';

  @override
  String get icuSourceLabel => 'Source';

  @override
  String get icuStayStartedLabel => 'Séjour en soins intensifs commencé';

  @override
  String get icuActionsTitle => 'Actes';

  @override
  String get icuCriticalAlertsPanelTitle => 'Alertes critiques';

  @override
  String get icuNoActiveAlertsLabel => 'No actif ICU critique alerts.';

  @override
  String icuHighestSeverityLabel(String severity) {
    return 'Gravité la plus élevée :$severity';
  }

  @override
  String get icuNoActiveAlertsListLabel => 'No actif alerts';

  @override
  String get icuObservationsPanelTitle => 'Observations';

  @override
  String get icuObservationsPanelDescription =>
      'Recent intensive observations pour ce ICU stay.';

  @override
  String get icuNoObservationsLabel =>
      'Aucune observation en soins intensifs enregistrée';

  @override
  String get icuVitalsTrendTitle => 'Tendance des signes vitaux';

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
  String get icuRoundNoteFallback => 'Note de ronde';

  @override
  String get icuNursingNoteFallback => 'Note infirmière';

  @override
  String get icuMedicationTaskFallback => 'Tâche médicamenteuse';

  @override
  String get icuDoseLabel => 'Dose';

  @override
  String get icuActiveStayLabel => 'Séjour actif en soins intensifs';

  @override
  String get icuPreviousStayLabel => 'Séjour précédent en soins intensifs';

  @override
  String icuEndedAtLabel(String time) {
    return 'Terminé$time';
  }

  @override
  String get icuTransferRecordLabel => 'Transfert';

  @override
  String get icuDischargeRecordLabel => 'Sortie';

  @override
  String get icuActionStartStay => 'Commencer un séjour en soins intensifs';

  @override
  String get icuActionRecordObservation => 'Observation';

  @override
  String get icuActionRecordVitals => 'Signes vitaux';

  @override
  String get icuActionRaiseAlert => 'Alerte critique';

  @override
  String get icuActionAcknowledgeAlert => 'Accuser réception de l\'alerte';

  @override
  String get icuActionRound => 'Ronde de soins intensifs';

  @override
  String get icuActionOrderLab => 'Order laboratoire';

  @override
  String get icuActionOrderImaging => 'Prescrire une imagerie';

  @override
  String get icuActionPrescribe => 'Prescrire';

  @override
  String get icuActionRequestTransfer => 'Demander un transfert';

  @override
  String get icuActionManageTransfer => 'Manage transfert';

  @override
  String get icuActionAssignBed => 'Assign ICU lit';

  @override
  String get icuActionMarkReadiness => 'Préparation à la sortie';

  @override
  String get icuActionOpenIpd => 'Ouvrir en hospitalisation';

  @override
  String get icuActionOpenDischargeClearance => 'Dégagement de décharge ouvert';

  @override
  String get icuActionOpenBilling => 'Ouvrir la facturation';

  @override
  String get icuBillingDeferredLabel => 'Facturation différée';

  @override
  String get icuActionEndStay => 'Terminer le séjour en soins intensifs';

  @override
  String get icuPrintSummaryLabel => 'Print résumé';

  @override
  String get icuObservationDialogTitle =>
      'Enregistrer une observation en soins intensifs';

  @override
  String get icuObservationFieldLabel => 'Observation';

  @override
  String get icuRecordActionLabel => 'Enregistrer';

  @override
  String get icuVitalsDialogTitle => 'Update signes vitaux';

  @override
  String get icuVitalsUpdateActionLabel => 'Mettre à jour';

  @override
  String get icuAlertDialogTitle => 'Add critique alert';

  @override
  String get icuAlertSeverityLabel => 'Gravité';

  @override
  String get icuAlertMessageLabel => 'Message d\'alerte';

  @override
  String get icuAlertAddActionLabel => 'Ajouter une alerte';

  @override
  String get icuRoundDialogTitle =>
      'Ajouter une note de ronde en soins intensifs';

  @override
  String get icuRoundNoteLabel => 'Note de ronde';

  @override
  String get icuRoundAddActionLabel => 'Ajouter une note';

  @override
  String get icuTransferDialogTitle => 'Demander un transfert';

  @override
  String get icuTransferTargetWardLabel => 'Target service';

  @override
  String get icuTransferTargetWardIdLabel => 'Target service ID';

  @override
  String get icuTransferRequestActionLabel => 'Demande';

  @override
  String get icuReadinessDialogTitle => 'Mark sortie readiness';

  @override
  String get icuReadinessNoteLabel => 'Note de préparation';

  @override
  String get icuReadinessDescription =>
      'Cela enregistre une note de préparation à la sortie planifiée et maintient le patient dans le flux de travail de sortie IPD.';

  @override
  String get icuReadinessMarkActionLabel => 'Marquer comme prêt';

  @override
  String get icuStartStayTitle => 'Commencer un séjour en soins intensifs';

  @override
  String get icuStartStayBody =>
      'Cela ouvre un séjour actif aux soins intensifs lors de l\'admission IPD afin que la documentation des soins intensifs puisse commencer.';

  @override
  String get icuStartStayActionLabel => 'Commencer le séjour';

  @override
  String get icuAcknowledgeTitle => 'Accuser réception de l\'alerte';

  @override
  String get icuAcknowledgeBody =>
      'Ce clears le selected critique alert de le actif ICU board.';

  @override
  String get icuEndStayTitle => 'Terminer le séjour en soins intensifs';

  @override
  String get icuEndStayBody =>
      'Cela met fin au séjour actif en soins intensifs. Continuez seulement une fois que le flux de travail du service de réception ou de sortie est prêt.';

  @override
  String get icuAssignBedDialogTitle => 'Assign ICU lit';

  @override
  String get icuManageTransferDialogTitle => 'Manage transfert';

  @override
  String get icuTransferActionApprove => 'Approuver';

  @override
  String get icuTransferActionStart => 'Commencer';

  @override
  String get icuTransferActionComplete => 'Complete avec lit';

  @override
  String get icuTransferActionCancel => 'Cancel transfert';

  @override
  String get icuTransferSelectBedLabel => 'Target lit';

  @override
  String get icuTransferNoOpenLabel => 'No ouvrir transfert à manage.';

  @override
  String get icuStepDownPromptTitle =>
      'Terminer le séjour en soins intensifs ?';

  @override
  String get icuStepDownPromptBody =>
      'Le transfert est terminé. Mettez fin au séjour actif en soins intensifs maintenant que le patient a quitté le service de soins.';

  @override
  String get icuChangesSavedMessage =>
      'Modifications des soins intensifs enregistrées.';

  @override
  String get icuBedBoardTitle => 'ICU lit board';

  @override
  String get icuBedBoardDescription =>
      'ICU service lit occupation et lit operations.';

  @override
  String get icuBedBoardAllWards => 'All ICU services';

  @override
  String icuBedAvailableLabel(int count) {
    return '${count}disponible';
  }

  @override
  String icuBedOccupiedLabel(int count) {
    return '${count}occupé';
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
      'Aucun lit de soins intensifs n\'est configuré pour cet établissement.';

  @override
  String get icuBedVacantLabel => 'Vacant';

  @override
  String get icuPrintAlertsSection => 'Alertes';

  @override
  String get icuPrintObservationsSection => 'Observations';

  @override
  String get icuPrintVitalsSection => 'Signes vitaux';

  @override
  String get icuPrintTransferSection => 'Transfer et readiness';

  @override
  String get ipdOpenIcuAction => 'Ouvrir en unité de soins intensifs';

  @override
  String get ipdOpenTheaterAction => 'Dans le théâtre';

  @override
  String get ipdStatusInProcedureOt => 'In procédure / OT';

  @override
  String get ipdNextCompleteTheatreHandover => 'Remise complète du théâtre';

  @override
  String get ipdTheatreHandoverTitle => 'Remise post-opératoire du théâtre';

  @override
  String get ipdStartIcuStayAction => 'Commencer un séjour en soins intensifs';

  @override
  String get ipdStartIcuStayBody =>
      'Cela ouvre un séjour actif en soins intensifs pour cette admission afin que l\'équipe de soins intensifs puisse commencer la documentation des soins intensifs.';

  @override
  String get commonGoHomeActionLabel => 'Go à tableau de bord';

  @override
  String get commonCancelActionLabel => 'Annuler';

  @override
  String get commonCloseActionLabel => 'Fermer';

  @override
  String get appDateInvalidMessage => 'Enter un valid date.';

  @override
  String get appDateFormatHint => 'JJ/MM/AAAA';

  @override
  String get appTimePickerAction => 'Select heure';

  @override
  String get appTimeInvalidMessage => 'Enter un valid heure.';

  @override
  String get appTimeFormatHint => 'HH : MM';

  @override
  String get appTimeHourLabel => 'HH';

  @override
  String get appTimeMinuteLabel => 'MM';

  @override
  String get appTimeSecondLabel => 'SS';

  @override
  String get appTimeAmLabel => 'Le matin';

  @override
  String get appTimePmLabel => 'L\'apres-midi';

  @override
  String get appTime12HourLabel => '12H';

  @override
  String get appTime24HourLabel => '24H';

  @override
  String get appPhoneCountryLabel => 'Code pays';

  @override
  String get appPhoneCountrySearchLabel => 'Rechercher un pays';

  @override
  String get appPhoneCountryNoResults => 'Aucun countries trouvé';

  @override
  String get appPhoneNumberLabel => 'Numéro de téléphone';

  @override
  String get appPhoneNumberHint => 'Chiffres restants';

  @override
  String get appPhoneInvalidMessage => 'Enter un valid téléphone number.';

  @override
  String get appStatusOnlineLabel => 'En ligne';

  @override
  String get appStatusOfflineLabel => 'Hors ligne';

  @override
  String get appOpenNavigationMenuTooltip => 'Ouvrir le menu de navigation';

  @override
  String get appCloseNavigationMenuTooltip => 'Fermer le menu de navigation';

  @override
  String get appToggleSidebarTooltip => 'Basculer la barre latérale';

  @override
  String get appNavigationSearchLabel => 'Recherche Menu';

  @override
  String get appNavigationSearchHint => 'Recherche Menu';

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
  String get appUserMenuSignedInLabel => 'Fait à……….';

  @override
  String get navigationHomeLabel => 'Tableau de bord';

  @override
  String get navigationHomeShortLabel => 'Tableau de bord';

  @override
  String get navigationSettingsLabel => 'Paramètres';

  @override
  String get navigationSettingsShortLabel => 'Paramètres';

  @override
  String get navigationSetupLabel => 'Configuration du locataire';

  @override
  String get navigationSetupShortLabel => 'Réglages';

  @override
  String get navigationPatientsLabel => 'Registre des patients';

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
  String get billingStatusLive => 'Direct';

  @override
  String get billingStatusPosting => 'Publication';

  @override
  String get billingWorklistDescription =>
      'Cashier worklist pour factures, paiements, réclamations, et approvals.';

  @override
  String get billingAllWorkItems => 'All billing work éléments';

  @override
  String get billingAwaitingPayment => 'Awaiting paiement';

  @override
  String get billingIssueQueue => 'File d\'attente d\'émission';

  @override
  String get billingClaimsPending => 'Claims en attente';

  @override
  String get billingApprovals => 'Approbations';

  @override
  String get billingOverdue => 'Impayé';

  @override
  String get billingNeedsIssue => 'Problème de besoins';

  @override
  String get billingApprovalRequired => 'Approval requis';

  @override
  String get billingQueueLabel => 'File d’attente';

  @override
  String get billingSearchHint => 'Invoice, patient, ou référence';

  @override
  String get billingSearchSemanticLabel =>
      'Rechercher dans la liste de travail de facturation';

  @override
  String get billingClearSearch => 'Clear billing recherche';

  @override
  String get billingFiltersTitle => 'Billing filtres';

  @override
  String get billingEmptyTitle => 'No billing éléments';

  @override
  String get billingEmptyBody =>
      'Cette file d\'attente ne contient actuellement aucune facture ni action de facturation.';

  @override
  String get billingPatientColumn => 'Patient';

  @override
  String get billingStatusColumn => 'Statut';

  @override
  String get billingAmountColumn => 'Montant';

  @override
  String get billingPaidColumn => 'Payant';

  @override
  String get billingBalanceColumn => 'Solde';

  @override
  String get billingUpdatedColumn => 'Mis à jour';

  @override
  String get billingInvoiceLabel => 'Facture';

  @override
  String get billingReceivePayment => 'Receive paiement';

  @override
  String get billingIssueAction => 'Émettre';

  @override
  String get billingRefundAction => 'Remboursement';

  @override
  String get billingAdjustAction => 'Régler';

  @override
  String get billingVoidAction => 'Vide';

  @override
  String get billingSendAction => 'Envoyer';

  @override
  String get billingCloseShift => 'Close quart';

  @override
  String get billingCloseDay => 'Fermée la journée';

  @override
  String get billingIssueInvoice => 'Issue facture';

  @override
  String get billingSendInvoice => 'Send facture';

  @override
  String get billingVoidInvoice => 'Void facture';

  @override
  String get billingRequestAdjustment => 'Demander un ajustement';

  @override
  String get billingRequestRefund => 'DEMANDE REMBOURSEMENT KOL';

  @override
  String get billingDueLabel => 'Echéance';

  @override
  String get billingNoLineItems => 'No line éléments returned pour ce facture.';

  @override
  String get billingNoPayments => 'No paiements recorded pour ce facture.';

  @override
  String get billingNoAdjustments =>
      'Aucun ajustement de facturation enregistré.';

  @override
  String get billingLineItemsTitle => 'Line éléments';

  @override
  String get billingPaymentsTitle => 'Paiements';

  @override
  String get billingAdjustmentsTitle => 'Réglages';

  @override
  String get billingFinancialSummaryTitle => 'Financial résumé';

  @override
  String get billingInvoiceDetailTitle => 'Détail de la facture';

  @override
  String get billingItemDetailTitle => 'Billing élément';

  @override
  String get billingClaimDetailTitle => 'Insurance réclamation';

  @override
  String get billingApprovalDetailTitle => 'Approval demande';

  @override
  String get billingPreAuthDetailTitle => 'Pré-autorisation';

  @override
  String get billingActionSaved => 'Action de facturation enregistrée.';

  @override
  String get billingActionPendingApproval =>
      'Submitted. Pending approbation avant it takes effect.';

  @override
  String get billingDocumentDownloaded => 'Document de facture enregistré.';

  @override
  String get billingDocumentUnavailable =>
      'La facture n\'a pas pu être enregistrée sur cet appareil.';

  @override
  String get billingDocumentTooltip => 'Download facture PDF';

  @override
  String get billingViewLedgerAction => 'Afficher le grand livre';

  @override
  String get billingLedgerTitle => 'Registre des patients';

  @override
  String get billingLedgerEmpty =>
      'No ledger entries pour ce patient in le selected period.';

  @override
  String get billingApproveAction => 'Approuver';

  @override
  String get billingRejectAction => 'Rejeter';

  @override
  String get billingSubmitClaimAction => 'Submit réclamation';

  @override
  String get billingReconcileClaimAction => 'Record insurer réponse';

  @override
  String get billingFinalizeEncounterAction =>
      'Finaliser l\'apurement financier';

  @override
  String get billingFinalizeEncounterBody =>
      'Tous les frais liés sont émis et réglés. Confirmez l’autorisation financière pour cette rencontre.';

  @override
  String get billingEncounterLabel => 'Rencontre';

  @override
  String get billingCoveragePlanLabel => 'Coverage forfait';

  @override
  String get billingRequestTypeLabel => 'Type de demande';

  @override
  String get billingRequesterLabel => 'Demandé par';

  @override
  String get billingReasonLabel => 'Raison';

  @override
  String get billingLinkedInvoiceLabel => 'Linked facture';

  @override
  String get billingClearanceCleared => 'Effacé';

  @override
  String get billingClearancePartiallyPaid => 'Partiellement payée';

  @override
  String get billingClearanceDeferred => 'AJ';

  @override
  String get billingClearanceInsured => 'Assuré';

  @override
  String get billingClearancePendingAuth => 'Autorisation en attente';

  @override
  String get billingClearanceBlocked => 'Bloqué';

  @override
  String get billingNotRecorded => 'Non enregistré';

  @override
  String get billingUnknownValue => 'Inconnu';

  @override
  String get billingPreviousPageLabel => 'Page précédente';

  @override
  String get billingNextPageLabel => 'Page suivante';

  @override
  String get billingClearFilters => 'Effacer';

  @override
  String get billingPaymentReferenceHint =>
      'Mobile money, card, ou bank référence';

  @override
  String get billingPayerHint => 'Patient, sponsor, insurer, ou contact';

  @override
  String get billingPdfFileTypeLabel => 'Document PDF';

  @override
  String get billingClaimStatusApproved => 'Approuvé';

  @override
  String get billingClaimStatusRejected => 'Rejeté';

  @override
  String get billingClaimStatusPaid => 'Payant';

  @override
  String get billingStatusDraft => 'Projet';

  @override
  String get billingStatusIssued => 'Émis';

  @override
  String get billingStatusPartial => 'Partiel';

  @override
  String get billingStatusPaid => 'Payant';

  @override
  String get billingAmountReceivedLabel => 'Montant';

  @override
  String get billingCurrencyLabel => 'Devise';

  @override
  String get billingPaymentMethodLabel => 'Mode de paiement';

  @override
  String get billingReferenceLabel => 'Référence';

  @override
  String get billingPayerLabel => 'Payeur ';

  @override
  String get billingGenerateReceiptLabel => 'Generate receipt après paiement';

  @override
  String get billingPaymentLabel => 'Paiement';

  @override
  String get billingRefundAmountLabel => 'Refund montant';

  @override
  String get billingRefundReasonValidation => 'Enter un refund reason.';

  @override
  String get billingNotesLabel => 'Remarques';

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
  String get billingRequestVoidAction => 'Demande annulée';

  @override
  String get billingVoidReasonLabel => 'Motif nul';

  @override
  String get billingUnknownPatient => 'Patient inconnu';

  @override
  String billingQuantityLabel(int quantity) {
    return 'Qté $quantity';
  }

  @override
  String get navigationSubscriptionsLabel => 'Subscription forfaits';

  @override
  String get navigationSubscriptionsShortLabel => 'Forfaits';

  @override
  String get subscriptionHeaderActiveLabel => 'Abonné';

  @override
  String get subscriptionHeaderExpiringSoonLabel => 'Renouveler bientôt';

  @override
  String subscriptionHeaderExpiresInDaysLabel(int days) {
    return 'Expire dans (jours) $days jours';
  }

  @override
  String get subscriptionHeaderExpiredLabel => 'Subscription expiré';

  @override
  String get subscriptionHeaderUpgradeLabel => 'Mise à niveau';

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
      'Vous passez à un forfait supérieur.';

  @override
  String subscriptionRenewIntentBanner(String plan) {
    return 'Vous renouvellez votre${plan}plan.';
  }

  @override
  String get subscriptionUpgradePlanLabel => 'Forfait';

  @override
  String get subscriptionUpgradePaymentMethodLabel => 'Mode de paiement';

  @override
  String get subscriptionUpgradeAmountLabel => 'Montant payé';

  @override
  String get subscriptionUpgradeReferenceLabel => 'Payment référence';

  @override
  String get subscriptionUpgradeNotesLabel => 'Remarques';

  @override
  String get subscriptionUpgradeProofLabel => 'Proof sur paiement';

  @override
  String get subscriptionUpgradeAttachProofAction => 'Joindre une preuve';

  @override
  String get subscriptionUpgradeRemoveProofAction => 'Retirer le média';

  @override
  String get subscriptionUpgradeAdminContactTitle =>
      'Contact de facturation de la plateforme';

  @override
  String get subscriptionUpgradeAdminContactBody =>
      'Si votre compte n\'est pas activé après le paiement, contactez nos administrateurs de plateforme en utilisant les coordonnées ci-dessous. L’assistance est disponible à tout moment.';

  @override
  String get subscriptionUpgradeAdminContactEmailLabel => 'E-mail';

  @override
  String get subscriptionUpgradeAdminContactPhoneLabel => 'Téléphone';

  @override
  String get subscriptionUpgradeSubmitAction => 'Submit paiement';

  @override
  String get subscriptionRenewSubmitAction => 'Soumettre le renouvellement';

  @override
  String get subscriptionUpgradePaymentMethodSectionTitle =>
      'Comment souhaiteriez-vous payer ?';

  @override
  String get subscriptionUpgradePaymentDetailsTitle => 'Payment détails';

  @override
  String get subscriptionMobileMoneyProviderLabel => 'Mobile money prestataire';

  @override
  String get subscriptionMobileMoneyPhoneLabel =>
      'Numéro de compte Mobile Money';

  @override
  String get subscriptionMobileMoneyMtn => 'MTN Mobile Money ';

  @override
  String get subscriptionMobileMoneyAirtel => 'Airtel Money ';

  @override
  String get subscriptionMobileMoneyMpesa => 'M-Pesa';

  @override
  String get subscriptionMobileMoneyVodacom => 'Vodacom M-Pesa';

  @override
  String get subscriptionMobileMoneyTigo => 'Tigo / Mixx par Yas';

  @override
  String get subscriptionMobileMoneyOrange => 'Argent Orange';

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
  String get subscriptionPlatformBankNameLabel => 'Banque';

  @override
  String get subscriptionBankBranchLabel => 'Agence';

  @override
  String get subscriptionBankAccountNumberLabel => 'Numéro de compte';

  @override
  String get subscriptionBankSwiftLabel => 'SWIFT BIC';

  @override
  String get subscriptionBankIbanLabel => 'IBAN';

  @override
  String get subscriptionFxRateErrorMessage =>
      'Impossible de load exchange rate — montant shown in USD.';

  @override
  String get subscriptionCardHolderNameLabel => 'Nom sur la carte';

  @override
  String get subscriptionCardLastFourLabel => '4 derniers chiffres';

  @override
  String get subscriptionPaymentReferenceHint =>
      'Transaction ID ou receipt number';

  @override
  String get subscriptionProofRequiredMessage =>
      'Attach proof sur paiement pour ce method.';

  @override
  String get subscriptionUpgradeSubmittedMessage =>
      'Paiement soumis. L’équipe de la plateforme examinera et activera votre abonnement.';

  @override
  String get subscriptionPaymentMethodBankTransfer => 'Bank transfert';

  @override
  String get subscriptionPaymentMethodMobileMoney => 'Argent mobile';

  @override
  String get subscriptionPaymentMethodCreditCard => 'Carte bancaire';

  @override
  String get subscriptionPaymentMethodDebitCard => 'Carte de débit';

  @override
  String get subscriptionPaymentMethodCash => 'L\'argent liquide';

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
  String get navigationHrLabel => 'Ressources humaines';

  @override
  String get navigationHrShortLabel => 'HR';

  @override
  String get navigationGroupOverviewLabel => 'Présentation';

  @override
  String get navigationGroupPatientAccessLabel => 'IAO';

  @override
  String get navigationGroupInpatientCareLabel => 'Inpatient soins';

  @override
  String get navigationGroupClinicalServicesLabel => 'Clinical soins';

  @override
  String get navigationGroupDiagnosticsMedicationLabel =>
      'Diagnostics & pharmacie';

  @override
  String get navigationGroupRevenueCycleLabel => 'Facturation et revenus';

  @override
  String get navigationGroupFacilityOperationsLabel =>
      'Services aux établissements';

  @override
  String get navigationGroupAdministrationLabel => 'Administration';

  @override
  String get navigationOpdLabel => 'Patients externes (OPD)';

  @override
  String get navigationOpdShortLabel => 'OPD';

  @override
  String get navigationTheaterLabel => 'Operating bloc opératoire';

  @override
  String get navigationTheaterShortLabel => 'Mode Cinéma';

  @override
  String get navigationCommunicationsLabel => 'Communications';

  @override
  String get navigationCommunicationsShortLabel => 'Communications';

  @override
  String get hrTitle => 'Ressources humaines';

  @override
  String get navigationIntegrationsLabel => 'Intégrations';

  @override
  String get navigationIntegrationsShortLabel => 'Intégrations';

  @override
  String get navigationMortuaryLabel => 'Morgue';

  @override
  String get navigationMortuaryShortLabel => 'Morgue';

  @override
  String get navigationReportsLabel => 'Rapports';

  @override
  String get navigationReportsShortLabel => 'Rapports';

  @override
  String get navigationRoomsBedsLabel => 'Rooms & lits';

  @override
  String get navigationRoomsBedsShortLabel => 'Lits';

  @override
  String get navigationHousekeepingLabel => 'Ménage';

  @override
  String get navigationHousekeepingShortLabel => 'Hong Kong';

  @override
  String get theaterTitle => 'Mode Cinéma';

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
  String get theaterSavingStatus => 'Enregistrement';

  @override
  String get theaterSavedMessage => 'Modifications théâtrales enregistrées.';

  @override
  String get theaterScheduleCaseAction => 'Cas de planification';

  @override
  String get theaterScheduledSummaryLabel => 'Planifié';

  @override
  String get theaterInTheaterSummaryLabel => 'In bloc opératoire';

  @override
  String get theaterReadySummaryLabel => 'Prêt';

  @override
  String get theaterCompletedSummaryLabel => 'Terminé';

  @override
  String get theaterAllCasesSummaryLabel => 'Tous les cas';

  @override
  String get theaterCaseIdColumnLabel => 'Affaire';

  @override
  String get theaterProcedureColumnLabel => 'Procédure';

  @override
  String get theaterResponsibleRoleColumnLabel => 'Responsable';

  @override
  String get theaterSourceContextLabel => 'Source';

  @override
  String get theaterSourceEmergency => 'Urgences';

  @override
  String get theaterSourceOpd => 'OPD optionnel';

  @override
  String get theaterSourceIpd => 'Chirurgie en milieu hospitalier';

  @override
  String get theaterOpenInIpdAction => 'Ouvrir en hospitalisation';

  @override
  String get theaterOpenInEmergencyAction => 'Ouvrir en cas d\'urgence';

  @override
  String get theaterHandoverDestinationLabel => 'Destination de récupération';

  @override
  String get theaterHandoverToWard => 'Service';

  @override
  String get theaterHandoverToIcu => 'ICU';

  @override
  String get theaterHandoverToOpd => 'Suivi du cas à la journée/ OPD';

  @override
  String get theaterRoleNurse => 'Infirmière de théâtre';

  @override
  String get theaterRoleSurgeon => 'Chirurgien';

  @override
  String get theaterRoleAnesthetist => 'ANESTHESISTE:';

  @override
  String get theaterRoleTeam => 'Équipe théâtrale';

  @override
  String get theaterRoleCoordinator => 'Coordinateur de théâtre';

  @override
  String get theaterFiltersLabel => 'Theater filtres';

  @override
  String get theaterSearchLabel => 'Search bloc opératoire';

  @override
  String get theaterSearchHint =>
      'Search patient, case, consultation, notes, ou dossier text';

  @override
  String get theaterScheduleDateFilterLabel => 'Période';

  @override
  String get theaterPickScheduleDateAction => 'Pick planning date';

  @override
  String get theaterStatusFilterLabel => 'Statut';

  @override
  String get theaterStageFilterLabel => 'Étape';

  @override
  String get theaterResourceFiltersAction => 'Resource filtres';

  @override
  String get theaterClearFiltersAction => 'Clear filtres';

  @override
  String get theaterCasesTitle => 'Nouveaux cas quotidiens';

  @override
  String get theaterCasesDescription =>
      'Select un case à review readiness, dossiers, resources, et handover.';

  @override
  String get theaterNoCasesTitle => 'No bloc opératoire cases';

  @override
  String get theaterNoCasesBody =>
      'Les cas de théâtre programmés et actifs apparaîtront ici.';

  @override
  String get theaterNoCaseSelectedTitle => 'Aucun cas sélectionné';

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
  String get theaterReadinessColumnLabel => 'Préparation';

  @override
  String get theaterNextActionColumnLabel => 'Prochaine action';

  @override
  String theaterPageLabel(int from, int to, int total) {
    return '$from-$to sur $total';
  }

  @override
  String get theaterCaseDetailTitle => 'Détail du cas';

  @override
  String get theaterRescheduleAction => 'Planification';

  @override
  String get theaterUpdateStageAction => 'Mettre à jour l’étape';

  @override
  String get theaterEncounterLabel => 'Rencontre';

  @override
  String get theaterPatientLabel => 'Patient';

  @override
  String get theaterPatientSearchHint => 'Search by nom, MRN, ou téléphone';

  @override
  String get theaterEncounterSearchHint => 'Select un actif consultation';

  @override
  String get theaterEmergencyCaseLabel => 'Cas d\'urgence';

  @override
  String get theaterEmergencyCaseSearchHint => 'Link le actif urgence case';

  @override
  String get theaterEmergencyCaseSelectPatientFirstHint =>
      'Select un patient first';

  @override
  String get theaterScheduleEmergencyHint =>
      'Emergency cases require linking le actif ED case so bloc opératoire billing et passation context stay connected.';

  @override
  String get theaterScheduleEmergencyPanelTitle => 'Planification d\'urgence';

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
  String get theaterProceduresSectionLabel => 'Procédures';

  @override
  String get theaterAddProcedureAction => 'Add procédure';

  @override
  String get theaterNoProceduresSelectedLabel =>
      'Add one ou more procedures à bill pour ce case.';

  @override
  String get theaterScheduledAtLabel => 'Programmée pour ';

  @override
  String get theaterRoomLabel => 'Chambre';

  @override
  String get theaterReadinessLabel => 'Préparation';

  @override
  String get theaterTeamTitle => 'Team et flow';

  @override
  String get theaterSurgeonLabel => 'Chirurgien';

  @override
  String get theaterAnesthetistLabel => 'ANESTHESISTE:';

  @override
  String get theaterStageLabel => 'Étape';

  @override
  String get theaterStatusLabel => 'Statut';

  @override
  String get theaterStageNotesLabel => 'Notes de scène';

  @override
  String get theaterAssignResourceAction => 'Affecter une ressource';

  @override
  String get theaterUpdateReadinessAction => 'Mise à jour de l\'état de';

  @override
  String get theaterAnesthesiaAction => 'Anesthésie';

  @override
  String get theaterPostOpAction => 'SSPI';

  @override
  String get theaterHandoverAction => 'Remettre';

  @override
  String get theaterFinalizeAction => 'Finaliser';

  @override
  String get theaterCancelCaseAction => 'Annuler le cas';

  @override
  String get theaterStartCaseAction => 'Commencer un cas';

  @override
  String get theaterChecklistTitle =>
      'Liste de vérification de la préparation du site';

  @override
  String get theaterNoChecklistItemsLabel => 'No checklist éléments recorded';

  @override
  String get theaterRecordsTitle => 'Clinical dossiers';

  @override
  String get theaterAnesthesiaStatusLabel => 'Anesthesia statut';

  @override
  String get theaterPostOpStatusLabel => 'Post-op statut';

  @override
  String get theaterAnesthesiaNotesLabel => 'Notes d\'anesthésie';

  @override
  String get theaterPostOpNoteLabel => 'Note post-op';

  @override
  String get theaterNoObservationsLabel =>
      'Aucune observation d\'anesthésie enregistrée';

  @override
  String get theaterResourcesTitle => 'Ressources';

  @override
  String get theaterNoResourcesLabel => 'No resources assigné';

  @override
  String get theaterTimelineTitle => 'Calendrier';

  @override
  String get theaterNoTimelineLabel => 'Aucune entrée de chronologie';

  @override
  String get theaterScheduleCaseDialogTitle => 'Schedule bloc opératoire case';

  @override
  String get theaterScheduleCaseDialogBody =>
      'Search pour le patient et their actif consultation, then set le planning, team, procedures, et billing.';

  @override
  String get theaterSchedulePatientContextSection => 'Contexte du patient';

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
  String get theaterHandoverDialogTitle => 'Remise complète du site ';

  @override
  String get theaterHandoverNotesLabel => 'Notes de passation';

  @override
  String get theaterCancelCaseDialogTitle => 'Cancel bloc opératoire case';

  @override
  String get theaterCancellationReasonLabel => 'Motif d\'annulation';

  @override
  String get theaterAssignResourceDialogTitle =>
      'Assign bloc opératoire resource';

  @override
  String get theaterReadinessDialogTitle => 'Mise à jour de l\'état de';

  @override
  String get theaterAnesthesiaDialogTitle => 'Anesthesia dossier';

  @override
  String get theaterPostOpDialogTitle => 'Note post-op';

  @override
  String get theaterFinalizeDialogTitle => 'Finalize dossiers';

  @override
  String get theaterResourceFiltersDialogTitle => 'Resource filtres';

  @override
  String get theaterEncounterIdLabel => 'Identifiant de la rencontre';

  @override
  String get theaterEncounterIdHint =>
      'Encounter UUID ou case source identifiant';

  @override
  String get theaterDateTimeHint => 'AAAA-MM-JJTHH :MM :SS';

  @override
  String get theaterRoomIdLabel => 'ID de la chambre';

  @override
  String get theaterSurgeonIdLabel => 'Surgeon utilisateur ID';

  @override
  String get theaterAnesthetistIdLabel => 'Anesthetist utilisateur ID';

  @override
  String get theaterResourceTypeLabel => 'Type de ressource';

  @override
  String get theaterResourceIdLabel => 'ID de la ressource';

  @override
  String get theaterStaffRoleLabel => 'Staff rôle';

  @override
  String get theaterNotesLabel => 'Remarques';

  @override
  String get theaterChecklistPhaseLabel => 'Phase de la liste de contrôle';

  @override
  String get theaterChecklistItemCodeLabel => 'Code Article';

  @override
  String get theaterChecklistItemLabel => 'Item libellé';

  @override
  String get theaterChecklistCheckedLabel => 'Terminé';

  @override
  String get theaterRecordStatusLabel => 'Record statut';

  @override
  String get theaterSaveRecordAction => 'Save dossier';

  @override
  String get theaterRecordTypeLabel => 'Type de record';

  @override
  String get theaterApplyFiltersAction => 'Apply filtres';

  @override
  String theaterFieldRequiredLabel(String label) {
    return '${label}est requis.';
  }

  @override
  String get theaterStatusScheduled => 'Planifié';

  @override
  String get theaterStatusInTheater => 'In bloc opératoire';

  @override
  String get theaterStatusCompleted => 'Terminé';

  @override
  String get theaterStatusCancelled => 'Annulé';

  @override
  String get theaterStagePreOp => 'Pré-op :';

  @override
  String get theaterStageSignIn => 'Se connecter';

  @override
  String get theaterStageTimeOut => 'Temps de fin';

  @override
  String get theaterStageIntraOp => 'Intra-opératoire';

  @override
  String get theaterStageSignOut => 'Se déconnecter';

  @override
  String get theaterStagePostOp => 'SSPI';

  @override
  String get theaterStagePacuHandoff => 'Remise PACU';

  @override
  String get theaterStageCompleted => 'Terminé';

  @override
  String get theaterRecordDraft => 'Projet';

  @override
  String get theaterRecordFinal => 'Étape finale';

  @override
  String get theaterReadinessNotStarted => 'Non démarrée.';

  @override
  String theaterReadinessProgress(int completed, int total) {
    return '$completed/$total complétéer';
  }

  @override
  String get opdTitle => 'Flux OPD';

  @override
  String get opdDescription =>
      'Manage arrivals, queues, personnel readiness, et ambulatoire clinique passations.';

  @override
  String get opdLoadingTitle => 'Chargement du flux OPD';

  @override
  String get opdLoadingBody =>
      'Loading ambulatoire queue et consultation data.';

  @override
  String get opdLiveStatus => 'Live synchronisation';

  @override
  String get opdSavingStatus => 'Enregistrement';

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
  String get opdSavedMessage => 'Modifications enregistrées.';

  @override
  String get opdArrivalsSummaryLabel => 'Arrivées';

  @override
  String get opdQueueSummaryLabel => 'File d’attente';

  @override
  String get opdActiveFlowSummaryLabel => 'Flux actifs';

  @override
  String get opdCompletedFlowSummaryLabel => 'Terminé';

  @override
  String get opdFiltersLabel => 'OPD filtres';

  @override
  String get opdFilterAction => 'Filter OPD tableau';

  @override
  String get opdFilterDialogTitle => 'Filter OPD tableau';

  @override
  String get opdSearchFieldFilterLabel => 'Rechercher dans';

  @override
  String get opdAllFieldsFilterLabel => 'All champs';

  @override
  String get opdArrivalDateFilterLabel => 'date d’arrivée ;';

  @override
  String get opdDateFromLabel => 'Du';

  @override
  String get opdDateToLabel => 'A';

  @override
  String get opdDatePickerButtonLabel => 'Choisissez une date';

  @override
  String get opdInvalidDateMessage => 'Enter un valid date.';

  @override
  String get opdArrivalRangeFilterLabel => 'Plage d\'arrivée';

  @override
  String get opdAnyArrivalDateOption => 'date d\'arrivée';

  @override
  String get opdDatePresetToday => 'Aujourdh’ui';

  @override
  String get opdDatePresetYesterday => 'Hier';

  @override
  String get opdDatePresetLast7Days => '7 derniers jours';

  @override
  String get opdDatePresetLast30Days => 'Les 30 derniers jours';

  @override
  String get opdCategoryFilterLabel => 'Catégorie';

  @override
  String get opdStatusFilterLabel => 'Statut';

  @override
  String get opdVisitTypeFilterLabel => 'Type de visite';

  @override
  String get opdQueueFilterLabel => 'File d’attente';

  @override
  String get opdProviderFilterLabel => 'Assigned personnel';

  @override
  String get opdBillingFilterLabel => 'Facturation';

  @override
  String get opdNextActionFilterLabel => 'Prochaine action';

  @override
  String get opdAllCategoriesOption => 'All catégories';

  @override
  String get opdAllStatusesOption => 'Tous les statuts';

  @override
  String get opdAllVisitTypesOption => 'All visite types';

  @override
  String get opdAllQueuesOption => 'Toutes les files d\'attente';

  @override
  String get opdAllProvidersOption => 'All personnel';

  @override
  String get opdAllBillingStatesOption => 'Tous les états de facturation';

  @override
  String get opdAllNextActionsOption => 'All suivant actions';

  @override
  String get opdSummaryAllPatientsLabel => 'Tous les patients';

  @override
  String get opdSummaryAllOpdPatientsLabel =>
      'Tous les patients atteints d\'OPH';

  @override
  String get opdSummaryActiveOpdLabel => 'OPD actif';

  @override
  String get opdSummaryVitalsNeededLabel => 'Vitaux nécessaires';

  @override
  String get opdSummaryDoctorNeededLabel => 'Médecin en cas de besoin';

  @override
  String get opdSummaryWithDoctorLabel => 'Avec médecin';

  @override
  String get opdSummaryLabPendingLabel => 'Lab en attente';

  @override
  String get opdSummaryImagingPendingLabel => 'Imaging en attente';

  @override
  String get opdSummaryPharmacyPendingLabel => 'Pharmacy en attente';

  @override
  String get opdSummaryDecisionNeededLabel =>
      '1987 pas de décision nécessai re';

  @override
  String get opdSummaryAdmissionPendingLabel => 'Admission en attente';

  @override
  String get opdSummaryDischargedTodayLabel => 'Discharged aujourd\'hui';

  @override
  String get opdStatusPaymentDueLabel => 'Montant à payer&#xA0;:';

  @override
  String get opdStatusVitalsNeededLabel => 'Vitaux nécessaires';

  @override
  String get opdStatusDoctorNeededLabel => 'Médecin en cas de besoin';

  @override
  String get opdStatusWithDoctorLabel => 'Avec médecin';

  @override
  String get opdStatusDoctorReviewLabel => 'L’avis du docteur';

  @override
  String get opdStatusLabPendingLabel => 'Lab en attente';

  @override
  String get opdStatusSamplePendingLabel => 'Sample en attente';

  @override
  String get opdStatusInLabLabel => 'In laboratoire';

  @override
  String get opdStatusResultsReadyLabel => 'RÉSULTATS PRÊTS';

  @override
  String get opdStatusImagingPendingLabel => 'Imaging en attente';

  @override
  String get opdStatusReportPendingLabel => 'Report en attente';

  @override
  String get opdStatusReportReadyLabel => 'Rapport prêt';

  @override
  String get opdStatusLabAndImagingPendingLabel => 'Lab & imaging en attente';

  @override
  String get opdStatusPharmacyPendingLabel => 'Pharmacy en attente';

  @override
  String get opdStatusDispensingLabel => 'Distribution';

  @override
  String get opdStatusMedicinesDispensedLabel => 'Médicaments distribués';

  @override
  String get opdStatusDecisionNeededLabel => '1987 pas de décision nécessai re';

  @override
  String get opdStatusAdmissionPendingLabel => 'Admission en attente';

  @override
  String get opdStatusAdmittedLabel => 'Admis';

  @override
  String get opdStatusDischargedLabel => 'Sortie d&apos;hôpital du malade';

  @override
  String get opdNextCollectSampleLabel => 'Prélever échantillon';

  @override
  String get opdNextProcessLabLabel => 'Process laboratoire';

  @override
  String get opdNextReviewResultsLabel => 'Review résultats';

  @override
  String get opdNextLabHandoffLabel => 'Lab passation';

  @override
  String get opdNextPerformImagingLabel =>
      'Effectuer des examens d\'imagerie:&#10;';

  @override
  String get opdNextCompleteImagingReportLabel => 'Complete imaging rapport';

  @override
  String get opdNextReviewReportLabel => 'Review rapport';

  @override
  String get opdNextImagingHandoffLabel => 'Imaging passation';

  @override
  String get opdNextDiagnosticsPendingLabel => 'Diagnostics en attente';

  @override
  String get opdNextDispenseMedicineLabel => 'Distribuer des médicaments';

  @override
  String get opdNextPharmacyHandoffLabel => 'Pharmacy passation';

  @override
  String get opdNextDispositionLabel => 'Disposition';

  @override
  String get opdNextAdmissionHandoffLabel => 'Admission passation';

  @override
  String get opdOpenAdmissionAction =>
      'Admission ouverte aux patients hospitalisés';

  @override
  String get opdAdmissionHandoffTitle => 'Patient admis';

  @override
  String get opdAdmissionHandoffBody =>
      'Cette visite ambulatoire a été admise en soins hospitaliers. Ouvrez l\'espace de travail des patients hospitalisés pour attribuer un lit et poursuivre l\'admission. La rencontre OPD reste liée en tant que visite source.';

  @override
  String get opdAdmissionHandoffStayAction => 'Rester dans l\'OPD';

  @override
  String get opdPhysiotherapyHandoffTitle => 'Physiotherapy orientation placed';

  @override
  String get opdPhysiotherapyHandoffBody =>
      'Le patient a été référé en physiothérapie lors de cette visite. Ouvrez l’espace de travail de physiothérapie pour accepter la référence et commencer l’évaluation.';

  @override
  String get opdOpenPhysiotherapyAction => 'Physiothérapie ouverte';

  @override
  String get opdSearchLabel => 'Rechercher un OPD';

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
  String get opdFlowStageFilterLabel => 'Étape d\'écoulement';

  @override
  String get opdArrivalsTitle => 'Arrivées';

  @override
  String get opdQueueBoardTitle => 'Tableau de file d\'attente';

  @override
  String get opdFlowsTitle => 'OPD consultations';

  @override
  String get opdTableDescription =>
      'Track arrivals, queue statut, billing state, assigné personnel, et suivant steps.';

  @override
  String get opdProviderReadinessTitle => 'Préparation du personnel';

  @override
  String get opdActivityTitle => 'Activité récente de l\'OPD';

  @override
  String get opdActivityDescription =>
      'Latest visible ambulatoire flow changes.';

  @override
  String get opdNoArrivalsTitle => 'Aucune arrivée';

  @override
  String get opdNoArrivalsBody =>
      'Les patients programmés et enregistrés apparaîtront ici.';

  @override
  String get opdNoQueueTitle => 'Pas de patients en file d\'attente';

  @override
  String get opdNoQueueBody =>
      'Les entrées de la file d’attente de réception apparaîtront ici au fur et à mesure que les patients sont acheminés.';

  @override
  String get opdNoFlowsTitle => 'No OPD consultations';

  @override
  String get opdNoFlowsBody =>
      'Les consultations ambulatoires commencées apparaîtront ici.';

  @override
  String get opdNoFlowSelectedTitle => 'No consultation selected';

  @override
  String get opdNoFlowSelectedBody =>
      'Select un OPD consultation à review actions et related dossiers.';

  @override
  String get opdNoProvidersTitle => 'Aucun personnel prêt';

  @override
  String get opdNoProvidersBody =>
      'Les horaires du personnel et les créneaux disponibles apparaîtront ici.';

  @override
  String get opdNoActivityTitle => 'Aucune activité récente';

  @override
  String get opdNoActivityBody =>
      'OPD activity appears once consultations start moving.';

  @override
  String get opdNoSummaryPatientsTitle => 'Aucun patient';

  @override
  String get opdNoSummaryPatientsBody =>
      'Les patients OPD correspondants apparaîtront ici.';

  @override
  String get opdPatientColumnLabel => 'Patient';

  @override
  String get opdCategoryColumnLabel => 'Catégorie';

  @override
  String get opdStatusColumnLabel => 'Statut';

  @override
  String get opdVisitTypeColumnLabel => 'Type de visite';

  @override
  String get opdQueueStatusColumnLabel => 'Queue / statut';

  @override
  String get opdTimeColumnLabel => 'Arrival heure';

  @override
  String get opdWaitingTimeColumnLabel => 'Wait heure';

  @override
  String get opdProviderColumnLabel => 'Assigned personnel';

  @override
  String get opdPayerBillingColumnLabel => 'Payeur / facturation';

  @override
  String get opdActionsColumnLabel => 'Actes';

  @override
  String get opdStageColumnLabel => 'Étape';

  @override
  String get opdNextStepColumnLabel => 'Étape suivante';

  @override
  String get opdOpenActions => 'Actions ouvertes';

  @override
  String get opdQueueEmptyColumnLabel => 'Aucun patient';

  @override
  String get opdNoRelatedRecordsLabel => 'No related dossiers';

  @override
  String get opdNoTimelineLabel => 'Aucune entrée de chronologie';

  @override
  String get opdTimelineTitle => 'Calendrier';

  @override
  String get opdReferralsTitle => 'Références';

  @override
  String get opdFollowUpsTitle => 'Suivis';

  @override
  String get opdPaymentStatusLabel => 'Paiement';

  @override
  String get opdPaymentPaidLabel => 'Payant';

  @override
  String get opdPaymentRequiredLabel => 'Payment requis';

  @override
  String get opdPaymentNotRequiredLabel => 'Non requis';

  @override
  String get opdBillingRequiredAmountLabel => 'Required montant';

  @override
  String get opdBillingAmountPaidLabel => 'Montant payé';

  @override
  String get opdBillingRemainingBalanceLabel => 'Solde restant';

  @override
  String get opdClinicalServicesTitle => 'Services cliniques';

  @override
  String get opdClinicalServicesEmpty => 'No clinique services recorded yet.';

  @override
  String get clinicalReferralDetailsTitle => 'Referral détails';

  @override
  String get clinicalReferralNotesTitle => 'Notes complémentaires';

  @override
  String get opdEncounterContextTitle => 'Contexte de rencontre';

  @override
  String get opdCopyPatientIdAction => 'Copier l\'identifiant du patient';

  @override
  String get opdCopyEncounterIdAction => 'Copy consultation ID';

  @override
  String get opdEncounterIdCopiedMessage => 'ID de rencontre copié.';

  @override
  String opdPageLabel(int from, int to, int total) {
    return '$from-$to sur $total';
  }

  @override
  String get opdPreviousPageLabel => 'Page précédente';

  @override
  String get opdNextPageLabel => 'Page suivante';

  @override
  String opdAvailableSlotsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count créneaux ouverts',
      one: '1 créneau ouvert',
      zero: 'Aucun créneau ouvert',
    );
    return '$_temp0';
  }

  @override
  String get opdWalkInDialogTitle => 'Start OPD consultation';

  @override
  String get opdPatientSectionTitle => 'Patient';

  @override
  String get opdRoutingSectionTitle => 'Routage';

  @override
  String get opdBillingSectionTitle => 'Facturation';

  @override
  String get opdExistingPatientModeLabel => 'Patient existant';

  @override
  String get opdAppointmentPatientModeLabel => 'Patient sur rendez-vous';

  @override
  String get opdNewPatientModeLabel => 'Nouveau patient';

  @override
  String get opdSearchPatientLabel => 'Rechercher un patient';

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
      'Ce patient a déjà une rencontre active avec un OPD. Mettez à jour la rencontre active au lieu de créer un doublon.';

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
      'Arrival mode is fixed while updating an active encounter.';

  @override
  String get opdInactiveEncounterActionReason =>
      'Start ou mettre à jour un OPD consultation first.';

  @override
  String get opdSearchProviderLabel => 'Rechercher un médecin';

  @override
  String get opdSearchProviderHelper => 'Ce médecin s\'occupera du patient.';

  @override
  String get opdNoProvidersHelper =>
      'Aucun médecin agréé n\'a été trouvé. Vérifiez la configuration du médecin ou les autorisations du personnel.';

  @override
  String get opdRegisterNewPatientLabel => 'Register un nouveau patient';

  @override
  String get opdPatientIdLabel => 'ID du patient';

  @override
  String get opdFirstNameLabel => 'First nom';

  @override
  String get opdLastNameLabel => 'Last nom';

  @override
  String get opdGenderLabel => 'Genre';

  @override
  String get opdProviderIdLabel => 'ID du personnel';

  @override
  String get opdConsultationFeeLabel => 'Frais de consultation';

  @override
  String get opdCurrencyLabel => 'Devise';

  @override
  String get opdNotesLabel => 'Remarques';

  @override
  String get opdQueueAction => 'File d’attente';

  @override
  String get opdRescheduleAction => 'Planification';

  @override
  String get opdCancelAction => 'Annuler';

  @override
  String get opdCheckInAction => 'Start OPD consultation';

  @override
  String get opdAppointmentStartLabel => 'Start heure';

  @override
  String get opdAppointmentEndLabel => 'End heure';

  @override
  String get opdDateTimeHint => 'AAAA-MM-JJTHH :MM :SS';

  @override
  String get opdSaveAction => 'Enregistrer';

  @override
  String get opdCancellationReasonLabel => 'Motif d\'annulation';

  @override
  String get opdQueueStatusLabel => 'Queue statut';

  @override
  String get opdReasonLabel => 'Raison';

  @override
  String get opdPrioritizeAction => 'Prioriser';

  @override
  String get opdMoveQueueAction => 'Se déplacer';

  @override
  String get opdStartConsultationAction => 'Commencer la consultation';

  @override
  String get opdAssignDoctorAction => 'Attribuer un médecin';

  @override
  String get opdChangeDoctorAction => 'Changer de médecin';

  @override
  String get opdPayConsultationAction => 'Consultation payante';

  @override
  String get opdManageConsultationBillingAction =>
      'Gérer la facturation des consultations';

  @override
  String get opdUpdateConsultationBillingAction =>
      'Mettre à jour la facturation des consultations';

  @override
  String get opdCorrectStageAction => 'Étape correcte';

  @override
  String get opdReferAction => 'Référer';

  @override
  String get opdFollowUpAction => 'Suivi';

  @override
  String get opdDispositionAction => 'Disposition';

  @override
  String get opdAmountLabel => 'Montant';

  @override
  String get opdPaymentMethodLabel => 'Mode de paiement';

  @override
  String get opdTransactionReferenceLabel => 'Transaction référence';

  @override
  String get opdStageLabel => 'Étape';

  @override
  String get opdCurrentStageLabel => 'Stade actuel';

  @override
  String get opdTargetStageLabel => 'Étape cible';

  @override
  String get opdStageCorrectionReasonRequiredMessage =>
      'Enter un reason pour ce stage correction.';

  @override
  String get opdExternalFacilityLabel => 'External établissement';

  @override
  String get opdFollowUpDateLabel => 'Date de suivi';

  @override
  String get opdFollowUpTimeLabel => 'Follow-up heure';

  @override
  String get opdDecisionLabel => 'Décision';

  @override
  String get opdRouteDecisionLabel => 'Décision d\'itinéraire';

  @override
  String get opdArrivalModeLabel => 'Mode d\'arrivée';

  @override
  String get opdArrivalModeColumnLabel => 'Mode d\'arrivée';

  @override
  String get opdArrivalModeWalkInLabel => 'Sans rendez-vous';

  @override
  String get opdArrivalModeAppointmentLabel => 'Rendez-vous';

  @override
  String get opdArrivalModeEmergencyLabel => 'Urgence';

  @override
  String get opdArrivalModeFollowUpLabel => 'Suivi';

  @override
  String get opdEncounterColumnLabel => 'Rencontre OPD';

  @override
  String get opdEncounterIdLabel => 'Identifiant de la rencontre';

  @override
  String get opdEmergencySeverityLabel => 'Gravité de l\'urgence';

  @override
  String get opdTriageLevelLabel => 'Niveau de tri';

  @override
  String get opdTriageLevel1Label => 'Niveau 1 · Immédiat';

  @override
  String get opdTriageLevel2Label => 'Niveau 2 · Urgent';

  @override
  String get opdTriageLevel3Label => 'Niveau 3 · Moins urgent';

  @override
  String get opdTriageLevel4Label => 'Niveau 4 · Non urgent';

  @override
  String get opdTriageLevel5Label => 'Niveau 5 · Routine';

  @override
  String get opdTriagePendingLabel => 'Triage en attente';

  @override
  String get opdChiefComplaintLabel => 'Plainte principale';

  @override
  String get opdEmergencyIndicatorsLabel => 'Indicateurs d\'urgence';

  @override
  String get opdWorkflowReceptionTitle => 'Reception et queue';

  @override
  String get opdWorkflowTriageTitle => 'Triage';

  @override
  String get opdWorkflowDoctorTitle => 'Consultation de médecin';

  @override
  String get opdWorkflowServicesTitle => 'Services';

  @override
  String get opdWorkflowPrintTitle => 'Impression';

  @override
  String get opdSendToTriageAction => 'Send à triage';

  @override
  String get opdSendToDoctorAction => 'Send à doctor';

  @override
  String get opdRecordVitalsAction => 'Record signes vitaux';

  @override
  String get opdEditVitalsAction => 'Edit signes vitaux';

  @override
  String get opdDoctorReviewAction => 'L’avis du docteur';

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
  String get opdVitalsSummaryLabel => 'Signes vitaux';

  @override
  String get opdAbnormalVitalsSummaryLabel => 'Abnormal signes vitaux';

  @override
  String get opdClinicalAlertsSummaryLabel => 'Alertes cliniques';

  @override
  String get opdServicesSummaryLabel => 'Services';

  @override
  String get opdClinicalNotesSummaryLabel => 'Notes cliniques';

  @override
  String get opdProceduresSummaryLabel => 'Procédures';

  @override
  String get opdClinicalNoteLabel => 'Note clinique';

  @override
  String get opdDiagnosisTypeLabel => 'Type de diagnostic';

  @override
  String get opdDiagnosisLabel => 'Diagnostic';

  @override
  String get opdDiagnosisCodeLabel => 'Code de diagnostic';

  @override
  String get opdProcedureLabel => 'Procedure ou minor surgery';

  @override
  String get opdProcedureCodeLabel => 'Code de procédure';

  @override
  String get opdLabTestIdsLabel => 'ID de test de laboratoire';

  @override
  String get opdLabPanelIdsLabel => 'Lab panneau IDs';

  @override
  String get opdRadiologyTestIdsLabel => 'ID de test de radiologie';

  @override
  String get opdDrugLabel => 'Médicament disponible';

  @override
  String get opdDrugQuantityLabel => 'Quantité';

  @override
  String get opdDosageLabel => 'Dosage';

  @override
  String get opdFrequencyLabel => 'Fréquence';

  @override
  String get opdMedicationRouteLabel => 'Itinéraire des médicaments';

  @override
  String get opdPrescriptionNotesLabel => 'Notes de prescription';

  @override
  String get opdTemperatureLabel => 'Température';

  @override
  String get opdSystolicLabel => 'Systolique';

  @override
  String get opdDiastolicLabel => 'Diastolique';

  @override
  String get opdHeartRateLabel => 'Fréquence cardiaque';

  @override
  String get opdRespiratoryRateLabel => 'Fréquence respiratoire';

  @override
  String get opdOxygenSaturationLabel => 'Saturation en oxygène';

  @override
  String get opdWeightLabel => 'Poids';

  @override
  String get opdTriageNotesLabel => 'Notes de tri';

  @override
  String get opdTriageScopeFilterLabel => 'Portée du tri';

  @override
  String get opdAllTriageScopesOption => 'Toutes les portées de tri';

  @override
  String get opdTriageScopeWaiting => 'En attendant';

  @override
  String get opdTriageScopeUrgent => 'Urgent';

  @override
  String get opdTriageScopeEmergency => 'Urgences';

  @override
  String get opdTriageScopeRoutine => 'Routine';

  @override
  String get opdTriageScopeServiceOnly => 'Service uniquement';

  @override
  String opdWaitDurationShort(String duration) {
    return 'Wait$duration';
  }

  @override
  String get opdSymptomsLabel => 'Symptômes';

  @override
  String get opdPainSeverityLabel => 'Gravité de la douleur';

  @override
  String get opdAllergiesLabel => 'Allergies';

  @override
  String get opdRiskFlagsLabel => 'Indicateurs de risque';

  @override
  String get opdRiskFlagFall => 'Risque de chute';

  @override
  String get opdRiskFlagPregnancy => 'Grossesse';

  @override
  String get opdRiskFlagInfection => 'Risque d\'infection';

  @override
  String get opdRiskFlagAlteredMentalState => 'État mental altéré';

  @override
  String get opdRiskFlagBleeding => 'Saignement';

  @override
  String get opdNoRouteDecisionLabel => 'Ne pas encore acheminer';

  @override
  String get patientsTitle => 'Registre des patients';

  @override
  String get patientsBody =>
      'Find, register, et maintain patient dossiers across front desk et soins workflows.';

  @override
  String get patientsTableTitle => 'Patient dossiers';

  @override
  String get patientsTableDescription =>
      'Browse enregistré patients, visite context, alerts, statut, et disponible suivant actions.';

  @override
  String get patientsLoadingTitle => 'Chargement des patients';

  @override
  String get patientsLoadingBody =>
      'Chargement des données du registre des patients.';

  @override
  String get patientsStatusReady => 'Registre prêt';

  @override
  String get patientsAddAction => 'Ajouter un patient';

  @override
  String get patientsRegisterPatientAction => 'Enregistrer un patient';

  @override
  String get patientsRegisterNewPatientTitle =>
      'Enregistrer un nouveau patient';

  @override
  String get patientsRegisterNewPatientAction => 'Enregistrer le patient';

  @override
  String get patientsEmergencyRegisterAction => 'Emergency inscription';

  @override
  String get patientsEditAction => 'Modifier';

  @override
  String get patientsDeleteAction => 'Supprimer';

  @override
  String get patientsSaveAction => 'Enregistrer';

  @override
  String get patientsSaveAnywayAction => 'Enregistrer quand même';

  @override
  String get patientsSavedMessage =>
      'Modifications du registre des patients enregistrées.';

  @override
  String get patientsEmergencySavedMessage =>
      'Emergency patient enregistré pour completion.';

  @override
  String get patientsDeletedMessage => 'Patient registry dossier supprimé.';

  @override
  String get patientsMergedMessage => 'Patient dossiers merged.';

  @override
  String get patientsDuplicateDismissedMessage => 'Examen en double rejeté.';

  @override
  String get patientsTotalSummaryLabel => 'Nombre total de patients';

  @override
  String get patientsTotalSummaryBody =>
      'All visible patient dossiers in scope.';

  @override
  String get patientsActiveSummaryLabel => 'Patients actifs';

  @override
  String get patientsActiveSummaryBody =>
      'Patients disponible pour actuel workflows.';

  @override
  String get patientsQueueSummaryLabel => 'File d\'attente';

  @override
  String get patientsQueueSummaryBody =>
      'Patients currently waiting pour service.';

  @override
  String get patientsDuplicateSummaryLabel => 'Avis en double';

  @override
  String get patientsDuplicateSummaryBody =>
      'Correspondances potentielles nécessitant un examen.';

  @override
  String get patientsFiltersLabel => 'Patient filtres';

  @override
  String get patientsSearchLabel => 'Rechercher';

  @override
  String get patientsSearchHint =>
      'Name, téléphone, e-mail, identifiant, ou contact';

  @override
  String get patientsPatientIdFilterLabel => 'ID du patient';

  @override
  String get patientsGenderFilterLabel => 'Genre';

  @override
  String get patientsStatusFilterLabel => 'Statut';

  @override
  String get patientsConsentFilterLabel => 'Consentement';

  @override
  String get patientsContactFilterLabel => 'Contact';

  @override
  String get patientsVisitDateFilterLabel => 'Date de visite';

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
  String get patientsActiveAdmissionFilterLabel => 'Admission active';

  @override
  String get patientsOutstandingBalanceFilterLabel => 'Solde impayé';

  @override
  String get patientsYesFilterLabel => 'Oui';

  @override
  String get patientsNoFilterLabel => 'Non';

  @override
  String get patientsFilterIdentitySectionTitle => 'Identité';

  @override
  String get patientsFilterVisitSectionTitle => 'Visites';

  @override
  String get patientsFilterRecordSectionTitle => 'État d\'enregistrement';

  @override
  String get patientsApplyFiltersAction => 'Appliquer';

  @override
  String get patientsClearFiltersAction => 'Effacer';

  @override
  String get patientsAdvancedFiltersAction => 'Advanced filtres';

  @override
  String get patientsAdvancedFiltersTitle => 'Advanced filtres';

  @override
  String get patientsSummaryLoadingTitle => 'Chargement des patients';

  @override
  String get patientsSummaryLoadingBody => 'Loading related patient dossiers.';

  @override
  String get patientsActiveFilter => 'Actif';

  @override
  String get patientsInactiveFilter => 'Inactif';

  @override
  String get patientsPatientColumnLabel => 'Nom du patient';

  @override
  String get patientsPatientNumberColumnLabel => 'Patient non.';

  @override
  String get patientsAgeSexColumnLabel => 'Âge / sexe';

  @override
  String get patientsPhoneIdentifierColumnLabel => 'Téléphone';

  @override
  String get patientsAlertColumnLabel => 'Alertes';

  @override
  String get patientsVisitColumnLabel => 'Visite';

  @override
  String get patientsVisitIdLabel => 'ID de visite';

  @override
  String get patientsNextActionColumnLabel => 'Prochaine action';

  @override
  String get patientsIdentifierColumnLabel => 'Identifiant';

  @override
  String get patientsContactColumnLabel => 'Contact';

  @override
  String get patientsDobColumnLabel => 'Date de naissance';

  @override
  String get patientsStatusColumnLabel => 'Statut';

  @override
  String get patientsNoAlertsLabel => 'Aucune alerte';

  @override
  String get patientsAllergyAlertLabel => 'Allergie';

  @override
  String get patientsNoVisitLabel => 'No visite';

  @override
  String get patientsCompleteRecordAction => 'Complete dossier';

  @override
  String get patientsOpenRecordAction => 'Ouvrir le dossier';

  @override
  String patientsPageLabel(int from, int to, int total) {
    return '$from-$to sur $total';
  }

  @override
  String get patientsPreviousPageLabel => 'Page des patients précédents';

  @override
  String get patientsNextPageLabel => 'Page des patients suivants';

  @override
  String get patientsEmptyTitle => 'Aucun patients trouvé';

  @override
  String get patientsEmptyBody => 'Adjust le filtres ou register un patient.';

  @override
  String get patientsDetailTitle => 'Patient détails';

  @override
  String get patientsDetailLoadingTitle => 'Chargement du patient';

  @override
  String get patientsDetailLoadingBody =>
      'Loading demographics et related dossiers.';

  @override
  String get patientsNoSelectionTitle => 'Select un patient';

  @override
  String get patientsNoSelectionBody =>
      'Ouvrez un patient pour consulter les données démographiques, les contacts, les indicateurs cliniques, les documents et les visites.';

  @override
  String get patientsNameLabel => 'Nom';

  @override
  String get patientsIdentifierLabel => 'Identifiant';

  @override
  String get patientsDobLabel => 'Date sur naissance';

  @override
  String get patientsGenderLabel => 'Genre';

  @override
  String get patientsPhoneLabel => 'Téléphone';

  @override
  String get patientsEmailLabel => 'E-mail';

  @override
  String get patientsFacilityLabel => 'Établissement';

  @override
  String get patientsFacilitySelectTenantFirstTooltip =>
      'Veuillez d\'abord sélectionner un locataire.';

  @override
  String get patientsRegistrationStatusLabel => 'Inscription';

  @override
  String get patientsRegistrationIncompleteValue => 'Achèvement nécessaire';

  @override
  String get patientsFirstNameLabel => 'First nom';

  @override
  String get patientsLastNameLabel => 'Last nom';

  @override
  String get patientsIdentifierTypeLabel => 'Type d\'identifiant';

  @override
  String get patientsIdentifierValueLabel => 'Identifier valeur';

  @override
  String get patientsIdentifierValueSelectTypeFirstTooltip =>
      'Sélectionnez d\'abord un type d\'identifiant.';

  @override
  String get patientsIdentifierTypeMrnLabel =>
      'Numéro de dossier médical (MRN)';

  @override
  String get patientsIdentifierTypeNationalIdLabel =>
      'Carte d\'identité nationale (NATIONAL_ID)';

  @override
  String get patientsIdentifierTypePassportLabel => 'Passeport (PASSPORT)';

  @override
  String get patientsIdentifierTypeInsuranceLabel => 'Assurance (INSURANCE)';

  @override
  String get patientsIdentifierTypeDriverLicenseLabel =>
      'Permis de conduire (DRIVER_LICENSE)';

  @override
  String get patientsIdentifierTypeBirthCertificateLabel =>
      'Acte de naissance (BIRTH_CERTIFICATE)';

  @override
  String get patientsIdentifierTypeOtherLabel => 'Autre (OTHER)';

  @override
  String get patientsActiveCheckboxLabel => 'Le patient est actif';

  @override
  String get patientsDatePickerAction => 'Sélectionnez une date';

  @override
  String get patientsAddTitle => 'Ajouter un patient';

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
  String get patientsEditTitle => 'Modifier le patient';

  @override
  String get patientsDeleteTitle => 'Supprimer un patient';

  @override
  String patientsDeleteBody(String name) {
    return 'Supprimer${name}de actif patient dossiers?';
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
  String get patientsQuickActionsTitle => 'Actions rapides';

  @override
  String get patientsQuickAppointmentAction => 'Planifier un rendez-vous';

  @override
  String get patientsQuickOpdCheckInAction => 'Démarrer une consultation OPD';

  @override
  String get patientsQuickViewActiveOpdAction => 'Continuer le flux OPD';

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
  String get patientsQuickLabOrderAction => 'Demander un laboratoire';

  @override
  String get patientsQuickRadiologyOrderAction => 'Demander une radiologie';

  @override
  String get patientsQuickTheaterScheduleAction => 'Planifier une intervention';

  @override
  String get patientsQuickPhysiotherapyAction => 'Demander une physiothérapie';

  @override
  String get patientsQuickAdmitPatientAction => 'Admettre le patient';

  @override
  String get patientsActiveWorkTitle => 'Travaux en cours';

  @override
  String get patientsActiveWorkContinueAction => 'Continuer';

  @override
  String patientsAgeYears(int years) {
    return '$years ans';
  }

  @override
  String patientsAgeYearsMonths(int years, int months) {
    return '$years ans, $months mois';
  }

  @override
  String patientsAgeMonths(int months) {
    return '$months mois';
  }

  @override
  String patientsAgeDays(int days) {
    return '$days jours';
  }

  @override
  String get patientsQuickActionQueuedMessage =>
      'Le contexte patient est prêt pour le flux de travail sélectionné.';

  @override
  String get patientsQuickActionSavedMessage =>
      'Flux de travail du patient mis à jour.';

  @override
  String patientsWorkflowValidationMessage(String fields) {
    return 'Check these champs et réessayer:$fields.';
  }

  @override
  String get patientsAppointmentDialogTitle => 'Schedule rendez-vous';

  @override
  String get patientsAppointmentDateLabel => 'Date de rendez-vous';

  @override
  String get patientsAppointmentTimeLabel => 'Start heure';

  @override
  String get patientsAppointmentDurationLabel => 'Durée minutes';

  @override
  String get patientsAppointmentStatusLabel => 'Appointment statut';

  @override
  String get patientsAppointmentReasonLabel => 'Raison';

  @override
  String get patientsProviderLabel => 'Fournisseur';

  @override
  String get patientsProviderOptionalHelper =>
      'Optional prestataire assignment.';

  @override
  String get patientsWorkflowSectionTitle => 'Flux de travail';

  @override
  String get patientsArrivalSectionTitle => 'Arrivée';

  @override
  String get patientsTriagePrioritySectionTitle => 'Triage priorité';

  @override
  String get patientsVitalsSectionTitle => 'Signes vitaux';

  @override
  String get patientsClinicalAssessmentSectionTitle => 'Évaluation';

  @override
  String get patientsBillingSectionTitle => 'Billing détails';

  @override
  String get patientsAdmissionClinicalSectionTitle => 'Clinical approbation';

  @override
  String get patientsAdmissionLocationSectionTitle => 'Lieu d\'admission';

  @override
  String get patientsNotesSectionTitle => 'Remarques';

  @override
  String get patientsOpdCheckInDialogTitle => 'Start OPD consultation';

  @override
  String get patientsTriageDialogTitle => 'Admission au triage';

  @override
  String get patientsClinicalDialogTitle => 'Clinical visite';

  @override
  String get patientsBillingDialogTitle => 'Facturation des consultations';

  @override
  String get patientsAdmissionDialogTitle => 'Admettre le patient';

  @override
  String get patientsArrivalModeLabel => 'Mode d\'arrivée';

  @override
  String get patientsEmergencySeverityLabel => 'Gravité de l\'urgence';

  @override
  String get patientsTriageLevelLabel => 'Niveau de tri';

  @override
  String get patientsSystolicLabel => 'Systolique';

  @override
  String get patientsBloodPressureLabel => 'Pression artérielle';

  @override
  String get patientsDiastolicLabel => 'Diastolique';

  @override
  String get patientsTemperatureLabel => 'Température';

  @override
  String get patientsHeartRateLabel => 'Fréquence cardiaque';

  @override
  String get patientsRespiratoryRateLabel => 'Fréquence respiratoire';

  @override
  String get patientsOxygenSaturationLabel => 'Saturation en oxygène';

  @override
  String get patientsWeightLabel => 'Poids';

  @override
  String get patientsHeightLabel => 'Hauteur';

  @override
  String get patientsVitalsRequiredMessage =>
      'Enter at least one vital sign avant completing triage.';

  @override
  String get patientsVitalUnitLabel => 'Unité';

  @override
  String get patientsVitalNormalLabel => 'Normale';

  @override
  String get patientsVitalAbnormalLabel => 'Anormal';

  @override
  String get patientsVitalNumberInvalidMessage => 'Enter un valid number.';

  @override
  String patientsVitalRangeSuggestion(String profile, String range) {
    return 'Expected pour$profile:$range';
  }

  @override
  String patientsVitalLimitMessage(String range) {
    return 'Enter un valeur between$range.';
  }

  @override
  String get patientsChiefComplaintLabel => 'Plainte principale';

  @override
  String get patientsClinicalNoteLabel => 'Note clinique';

  @override
  String get patientsDiagnosisLabel => 'Diagnostic';

  @override
  String get patientsConsultationFeeLabel => 'Frais de consultation';

  @override
  String get patientsCurrencyLabel => 'Devise';

  @override
  String get patientsMarkPaymentReceivedLabel => 'Paiement reçu';

  @override
  String get patientsPaymentMethodLabel => 'Mode de paiement';

  @override
  String get patientsTransactionReferenceLabel => 'Transaction référence';

  @override
  String get patientsAdmissionReasonLabel => 'Motif d\'admission';

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
  String get patientsEncountersSectionTitle => 'Rencontres';

  @override
  String get patientsAdmissionsSectionTitle => 'Admissions';

  @override
  String get patientsInvoicesSectionTitle => 'Factures';

  @override
  String get patientsReportSummarySectionTitle => 'Résumé';

  @override
  String get patientsReportGeneratedSectionTitle => 'Généré';

  @override
  String get patientsReportPreviewDialogTitle => 'Print aperçu';

  @override
  String get patientsReportPeriodLabel => 'Période de déclaration';

  @override
  String get patientsReportAllDatesOption => 'Toutes les dates';

  @override
  String get patientsReportSingleDateOption => 'Rendez-vous unique';

  @override
  String get patientsReportDateRangeOption => 'Plage de dates';

  @override
  String get patientsReportDateLabel => 'Date du rapport';

  @override
  String get patientsReportStartDateLabel => 'Date de début';

  @override
  String get patientsReportEndDateLabel => 'Date de fin';

  @override
  String get patientsReportSectionsLabel => 'Sections du rapport';

  @override
  String get patientsReportPreviewSectionTitle => 'Aperçu';

  @override
  String get patientsReportPatientInfoSectionTitle =>
      'Informations sur les patients';

  @override
  String get patientsReportHospitalInfoSectionTitle =>
      'Informations sur l\'hôpital';

  @override
  String get patientsReportVitalsSectionTitle => 'Signes vitaux';

  @override
  String get patientsReportPaymentsSectionTitle => 'Paiements';

  @override
  String patientsReportPageNumberLabel(int page, int total) {
    return 'Page $page sur $total';
  }

  @override
  String get patientsReportNoRecordsForSection =>
      'No dossiers disponible pour le selected period.';

  @override
  String get patientsReportPreparedOnLabel => 'Préparé le';

  @override
  String get patientsReportHospitalNameLabel => 'Hospital nom';

  @override
  String get patientsReportHospitalContactLabel => 'Coordonnées';

  @override
  String get patientsReportHospitalLocationLabel => 'Emplacement';

  @override
  String get patientsReportHospitalAddressLabel => 'Adresse';

  @override
  String get patientsReportPrintNowAction => 'Imprimer';

  @override
  String get patientsReportDateRangeInvalidMessage =>
      'La date de début doit être égale ou antérieure à la date de fin.';

  @override
  String get patientsTimeInvalidMessage => 'Enter heure as HH:MM.';

  @override
  String get patientsTimeHint => 'HH : MM';

  @override
  String get patientsDurationInvalidMessage =>
      'Enter un duration between 1 et 720 minutes.';

  @override
  String get patientsIdentifiersSectionTitle => 'Identifiants';

  @override
  String get patientsContactsSectionTitle => 'Contacts';

  @override
  String get patientsGuardiansSectionTitle => 'Gardiens';

  @override
  String get patientsAllergiesSectionTitle => 'Allergies';

  @override
  String get patientsMedicalHistorySectionTitle => 'Medical historique';

  @override
  String get patientsDocumentsSectionTitle => 'Documents';

  @override
  String get patientsConsentsSectionTitle => 'Consentements';

  @override
  String get patientsTimelineSectionTitle => 'Calendrier';

  @override
  String get patientsNoIdentifiers => 'No identifiants recorded.';

  @override
  String get patientsNoContacts => 'Aucun contact enregistré.';

  @override
  String get patientsNoGuardians => 'Aucun tuteur enregistré.';

  @override
  String get patientsNoAllergies => 'Aucune allergie enregistrée.';

  @override
  String get patientsNoMedicalHistory => 'No médical historique recorded.';

  @override
  String get patientsNoDocuments => 'Aucun document enregistré.';

  @override
  String get patientsNoConsents => 'Aucun consentement enregistré.';

  @override
  String get patientsNoTimeline => 'Aucune entrée de chronologie enregistrée.';

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
  String get patientsContactTypeLabel => 'Type de contact';

  @override
  String get patientsContactValueLabel => 'Contact valeur';

  @override
  String get patientsContactInvalidMessage => 'Enter un valid contact valeur.';

  @override
  String get patientsPrimaryRecordLabel => 'Primary dossier';

  @override
  String get patientsGuardianNameLabel => 'Guardian nom';

  @override
  String get patientsGuardianRelationshipLabel => 'Relation';

  @override
  String get patientsAllergenLabel => 'Allergène';

  @override
  String get patientsSeverityLabel => 'Gravité';

  @override
  String get patientsReactionLabel => 'Réaction';

  @override
  String get patientsNotesLabel => 'Remarques';

  @override
  String get patientsConditionLabel => 'Condition';

  @override
  String get patientsDiagnosisDateLabel => 'Date du diagnostic';

  @override
  String get patientsDocumentTypeLabel => 'Type de document';

  @override
  String get patientsStorageKeyLabel => 'Clé de stockage';

  @override
  String get patientsStorageKeyAdvancedLabel => 'Clé de stockage (avancé)';

  @override
  String get patientsStorageKeyAdvancedHelper =>
      'Upload un file instead. Only enter ce lorsque referencing un existing stored document.';

  @override
  String get patientsDocumentUploadTitle => 'Téléchargement de documents';

  @override
  String get patientsDocumentUploadEmpty =>
      'Aucun fichier sélectionné. Les fichiers PDF, JPG et PNG jusqu\'à 10 Mo sont pris en charge.';

  @override
  String get patientsChooseDocumentAction => 'Choisir un fichier';

  @override
  String get patientsFileNameLabel => 'File nom';

  @override
  String get patientsContentTypeLabel => 'Type de contenu';

  @override
  String get patientsConsentTypeLabel => 'Type de consentement';

  @override
  String get patientsConsentStatusLabel => 'Consent statut';

  @override
  String get patientsConsentDateLabel => 'Date de consentement';

  @override
  String get patientsDuplicateWarningTitle => 'Double potentiel trouvé';

  @override
  String get patientsDuplicateWarningBody =>
      'Examinez les correspondances avant de créer un autre dossier patient. Continuez uniquement s’il s’agit d’un autre patient.';

  @override
  String get patientsDuplicateReviewTitle => 'Avis en double';

  @override
  String get patientsNoDuplicateReviewsTitle => 'No duplicates à review';

  @override
  String get patientsNoDuplicateReviewsBody =>
      'Les dossiers de patients en double potentiels apparaîtront ici.';

  @override
  String get patientsMergePreviewLoadingTitle => 'Loading merge aperçu';

  @override
  String get patientsMergePreviewLoadingBody =>
      'Vérifier quels enregistrements seront transférés au patient retenu.';

  @override
  String patientsDuplicateScoreLabel(int score) {
    return '$score% correspondre';
  }

  @override
  String get patientsReviewMergeAction => 'Fusionner les avis';

  @override
  String get patientsDismissDuplicateAction => 'Rejeter';

  @override
  String get patientsMergePreviewTitle => 'Merge aperçu';

  @override
  String patientsMergeTransferCountLabel(String resource, int count) {
    return '$resource:$count';
  }

  @override
  String get patientsMergePatientsAction => 'Fusionner les patients';

  @override
  String get patientsActivityTitle => 'Attention au registre';

  @override
  String get patientsActivityBody =>
      'Patient dossier issues cette may need review.';

  @override
  String get patientsActivityEmptyTitle => 'Aucun problème de registre';

  @override
  String get patientsActivityEmptyBody =>
      'Aucune alerte de doublon, de consentement ou de document n’est visible.';

  @override
  String get patientsDuplicateActivityTitle => 'Duplicata possible';

  @override
  String patientsDuplicateActivitySubtitle(int score) {
    return '$score% de confiance de correspondance';
  }

  @override
  String get patientsConsentActivityTitle => 'Examen du consentement';

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
  String get patientsDocumentsActivityTitle => 'Documents manquants';

  @override
  String patientsDocumentsActivitySubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count patients n\'ont pas de documents',
      one: '1 patient n\'a pas de documents',
    );
    return '$_temp0';
  }

  @override
  String get homeReadyTitle => 'Hospital operations espace de travail';

  @override
  String get homeReadyBody =>
      'Coordinate patient inscription, clinique soins, pharmacie, billing, diagnostics, operations, et compliance de one responsive HMS shell.';

  @override
  String get homeEntryPointsLabel => 'Points d\'entrée principaux';

  @override
  String get homeFeatureResponsiveTitle => 'Accueil des patients';

  @override
  String get homeFeatureResponsiveBody =>
      'Register patients, book appointments, et manage queues pour OPD et urgence intake.';

  @override
  String get homeFeatureNavigationTitle => 'Clinical espace de travail';

  @override
  String get homeFeatureNavigationBody =>
      'Rencontres ouvertes, notes cliniques, diagnostics, plans de soins, commandes et transferts de patients hospitalisés.';

  @override
  String get homeFeatureLocalizationTitle => 'Cycle de revenus';

  @override
  String get homeFeatureLocalizationBody =>
      'Track factures, cashier paiements, refunds, coverage, pre-authorizations, et réclamations.';

  @override
  String get homeFeatureSettingsTitle => 'Exploitation des installations';

  @override
  String get homeFeatureSettingsBody =>
      'Coordinate services, lits, départements, équipement, entretien, maintenance, et personnel rosters.';

  @override
  String get homeLoadingTitle => 'Preparing tableau de bord';

  @override
  String get homeLoadingBody => 'Préparation au chargement.';

  @override
  String get homeTodayAtAGlanceTitle => 'Today at un glance';

  @override
  String homeMetricCardSemantics(String label, String value) {
    return '$label:$value. View détails.';
  }

  @override
  String get homeOpenHrWorkspaceLink => 'Espace de travail RH ouvert';

  @override
  String get homeMetricActiveStaffCompact => 'Active personnel';

  @override
  String get homeMetricShiftsTodayCompact => 'Shifts aujourd\'hui';

  @override
  String get homeMetricPendingLeavesCompact => 'Pending congé';

  @override
  String get homeMetricOnLeaveTodayCompact => 'On congé';

  @override
  String get homeMetricUnassignedShiftsCompact => 'Non attribué';

  @override
  String get homeMetricAttendedTodayCompact => 'Participé';

  @override
  String get homeMetricMissedShiftsTodayCompact => 'Quarts de travail manqués';

  @override
  String get homeMetricPayrollPendingCompact => 'Payroll en attente';

  @override
  String get homeViewAllAction => 'View tous';

  @override
  String get homeTrendLast7Days => '7 derniers jours';

  @override
  String get homeTrendDefaultSubtitle =>
      'Role-focused changes over le latest reporting window.';

  @override
  String get homeTrendEmptyMessage =>
      'Aucune donnée de tendance n’est encore disponible.';

  @override
  String get homeDistributionWorkforceMix =>
      'Composition de la disponibilité du personnel';

  @override
  String get homeDistributionDefaultSubtitle =>
      'Live mix sur le dossiers behind ce tableau de bord.';

  @override
  String get homeDistributionEmptyMessage =>
      'Aucune donnée de distribution n’est encore disponible.';

  @override
  String get homeLoadErrorTitle => 'Dashboard n\'un pas pu load';

  @override
  String get homeLoadErrorBody => 'Try le demande again.';

  @override
  String get homeServiceAreasLabel => 'Zones de services';

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
  String get profilePhoneLabel => 'Téléphone';

  @override
  String get profileStatusLabel => 'Statut';

  @override
  String get profileTitleLabel => 'Titre';

  @override
  String get profileOverallRoleLabel => 'Overall rôle';

  @override
  String get profileUserTypeLabel => 'Type d\'utilisateur';

  @override
  String get profileTenantLabel => 'Locataire';

  @override
  String get profileFacilityLabel => 'Établissement';

  @override
  String get profileFacilityTypeLabel => 'Type d\'installation';

  @override
  String get profileStaffNumberLabel => 'Numéro d\'employé';

  @override
  String get profileUserIdLabel => 'ID de l\'utilisateur';

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
  String get profileUnknownValue => 'Pas disponible';

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
  String get profileRolesEmpty => 'Aucun rôle n\'est attribué à ce compte.';

  @override
  String get profilePermissionsSectionTitle => 'Direct autorisations';

  @override
  String get profilePermissionsSectionBody =>
      'Permissions granted directly à votre compte.';

  @override
  String get profilePermissionsEmpty =>
      'Aucune autorisation directe n\'est attribuée à ce compte.';

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
  String get profileEditGenderLabel => 'Genre';

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
  String get settingsThemeModeFieldLabel => 'Thème de l\'application';

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
      'La préférence n\'a pas pu être enregistrée.';

  @override
  String get settingsAccessibilitySectionTitle => 'Accessibilité';

  @override
  String get settingsAccessibilitySectionBody =>
      'Improve readability et reduce motion across clinique workspaces.';

  @override
  String get settingsReduceMotionLabel => 'Réduire les mouvements';

  @override
  String get settingsReduceMotionDescription =>
      'Use simpler transitions et fewer animations.';

  @override
  String get settingsBoldTextLabel => 'Texte en gras';

  @override
  String get settingsBoldTextDescription =>
      'Increase text weight pour easier reading.';

  @override
  String get settingsTextScaleFieldLabel => 'Taille du texte';

  @override
  String get settingsTextScaleNormal => 'Normale';

  @override
  String get settingsTextScaleLarge => 'Grand';

  @override
  String get settingsTextScaleExtraLarge => 'Très grand';

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
  String get settingsAdministrationSectionTitle => 'Limites administratives';

  @override
  String get settingsAdministrationSectionBody =>
      'L\'administration de l\'espace de travail reste dans des modules dédiés.';

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
      'Préparer l’organisation et les installations avant le début des opérations quotidiennes de l’hôpital.';

  @override
  String get tenantFacilitySetupLoadingTitle =>
      'Chargement de la configuration';

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
  String get tenantFacilityHrSetupManageAction => 'Gérer';

  @override
  String get tenantFacilitySummaryConfigured => 'Configuré';

  @override
  String get tenantFacilitySummaryNeedsSetup => 'Nécessite une configuration';

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
    return '$_temp0,$_temp1';
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
    return '$_temp0,$_temp1,$_temp2';
  }

  @override
  String get tenantFacilityChecklistTitle =>
      'Liste de contrôle de première exécution';

  @override
  String tenantFacilityChecklistBody(int completed, int total) {
    return '$completed sur $total setup areas complete.';
  }

  @override
  String get tenantFacilityChecklistTenant =>
      'Le profil du locataire est configuré';

  @override
  String get tenantFacilityChecklistIdentity =>
      'L\'identité et les contacts de l\'établissement sont configurés';

  @override
  String get tenantFacilityChecklistDepartments =>
      'Les départements sont configurés';

  @override
  String get tenantFacilityChecklistBranches =>
      'Les branches sont configurées (facultatif)';

  @override
  String get tenantFacilityChecklistUnits =>
      'Les unités sont configurées (facultatif)';

  @override
  String get tenantFacilityChecklistWards => 'Les quartiers sont configurés';

  @override
  String get tenantFacilityChecklistRooms => 'Les chambres sont configurées';

  @override
  String get tenantFacilityChecklistBeds => 'Les lits sont configurés';

  @override
  String get tenantFacilityChecklistLocations =>
      'Les chambres, les services ou les lits sont configurés';

  @override
  String get tenantFacilityWizardTitle => 'Configuration guidée';

  @override
  String get tenantFacilityWizardBody =>
      'Effectuez le flux de configuration principal dans l’ordre avant le début des opérations quotidiennes.';

  @override
  String get tenantFacilityWizardStepTenant => 'Tenant profil';

  @override
  String get tenantFacilityWizardStepFacility => 'Identité de l\'établissement';

  @override
  String get tenantFacilityWizardStepBranches => 'Succursales';

  @override
  String get tenantFacilityWizardStepDepartments => 'Départements';

  @override
  String get tenantFacilityWizardStepUnits => 'Unités';

  @override
  String get tenantFacilityWizardStepWards => 'Quartiers';

  @override
  String get tenantFacilityWizardStepRooms => 'Chambres';

  @override
  String get tenantFacilityWizardStepBeds => 'Lits';

  @override
  String get tenantFacilityWizardStepOrganization => 'Departments et unités';

  @override
  String get tenantFacilityWizardStepCareSpaces => 'Wards, chambres, et lits';

  @override
  String get tenantFacilityWizardContinueAction => 'Continuer la configuration';

  @override
  String get tenantFacilityBranchesOptionalHint =>
      'Les succursales sont facultatives pour les installations à site unique. Ignorez cette étape lorsque l\'établissement fait office de seul site.';

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
  String get tenantFacilityPermissionsTitle => 'Portes d\'autorisation';

  @override
  String get tenantFacilityPermissionsBody =>
      'Write actions require locataire ou établissement administrator autorisations.';

  @override
  String get tenantFacilityTenantAdminPermission =>
      'Administrateur de locataire';

  @override
  String get tenantFacilityFacilityAdminPermission =>
      'Administrateur d\'établissement';

  @override
  String get tenantFacilityPermissionAllowed => 'Autorisé';

  @override
  String get tenantFacilityPermissionDenied => 'Refusé';

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
  String get tenantFacilityTenantSlugLabel => 'Limace de locataire';

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
  String get tenantFacilityLogoLabel => 'Logo de l\'établissement';

  @override
  String get tenantFacilityLogoHelper =>
      'Upload un square image (JPG, PNG, ou WebP, up à 5 MB).';

  @override
  String get tenantFacilityChooseLogoAction => 'Choisir une image';

  @override
  String get tenantFacilityRemoveLogoAction => 'Retirer';

  @override
  String get tenantFacilityLogoUrlLabel => 'URL de stockage du logo';

  @override
  String get tenantFacilityLogoUrlHelper =>
      'Use un URL créé by le approuvé storage service.';

  @override
  String get tenantFacilityAddressLineLabel => 'Ligne d\'adresse';

  @override
  String get tenantFacilityCityLabel => 'Ville';

  @override
  String get tenantFacilityCountryLabel => 'Pays';

  @override
  String get tenantFacilitySaveFacilityAction => 'Save établissement';

  @override
  String get tenantFacilityFacilitySelectLabel => 'Établissement';

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
      'Cet enregistrement de configuration sera supprimé.';

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
  String get tenantFacilityBranchesSectionTitle => 'Succursales';

  @override
  String get tenantFacilityBranchesSectionBody =>
      'Add succursale entry points pour établissements cette operate across sites.';

  @override
  String get tenantFacilityNoBranches => 'Aucune branche n\'a été ajoutée.';

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
  String get tenantFacilityNoDepartments =>
      'Aucun département n\'a été ajouté.';

  @override
  String get tenantFacilityNoUnits => 'Aucune unité n\'a été ajoutée.';

  @override
  String get tenantFacilityDepartmentsListTitle => 'Départements';

  @override
  String get tenantFacilityDepartmentsModalBody =>
      'Manage département dossiers pour le selected établissement.';

  @override
  String get tenantFacilityDepartmentSearchHint =>
      'Search départements by nom, type, succursale, ou statut';

  @override
  String get tenantFacilityUnitsListTitle => 'Unités';

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
  String get tenantFacilityDepartmentTypeLabel => 'Type de département';

  @override
  String get tenantFacilityDepartmentBranchLabel => 'Agence';

  @override
  String get tenantFacilityDepartmentTypeClinical => 'Clinique';

  @override
  String get tenantFacilityDepartmentTypeAdministrative => 'Administratif';

  @override
  String get tenantFacilityDepartmentTypeSupport => 'Soutien';

  @override
  String get tenantFacilityDepartmentTypeDiagnostics => 'Diagnostic';

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
  String get tenantFacilityUnitDepartmentLabel => 'Département';

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
      'Utilisez les points d’entrée de configuration de l’emplacement une fois que l’identité de l’établissement et les services sont en place.';

  @override
  String get tenantFacilityRoomsLabel => 'Chambres';

  @override
  String get tenantFacilityWardsLabel => 'Quartiers';

  @override
  String get tenantFacilityBedsLabel => 'Lits';

  @override
  String get tenantFacilityNoWards => 'Aucune salle n\'a été ajoutée.';

  @override
  String get tenantFacilityWardsModalBody =>
      'Manage service dossiers et département assignments.';

  @override
  String get tenantFacilityWardSearchHint =>
      'Search services by nom, type, département, ou statut';

  @override
  String get tenantFacilityNoRooms => 'Aucune salle n\'a été ajoutée.';

  @override
  String get tenantFacilityRoomsModalBody =>
      'Manage chambres et their service assignments.';

  @override
  String get tenantFacilityRoomSearchHint =>
      'Search chambres by nom, service, floor, ou statut';

  @override
  String get tenantFacilityNoBeds => 'Aucun lit n\'a été ajouté.';

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
  String get tenantFacilityWardTypeLabel => 'Type de service';

  @override
  String get tenantFacilityWardDepartmentLabel => 'Département';

  @override
  String get tenantFacilityWardTypeGeneral => 'Général';

  @override
  String get tenantFacilityWardTypeIcu => 'ICU';

  @override
  String get tenantFacilityWardTypeMaternity => 'Maternité';

  @override
  String get tenantFacilityWardTypePediatric => 'Pédiatrique';

  @override
  String get tenantFacilityWardTypeSurgical => 'Chirurgical';

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
  String get tenantFacilityRoomFloorLabel => 'Sol';

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
  String get tenantFacilityBedStatusAvailable => 'Disponible';

  @override
  String get tenantFacilityBedStatusOccupied => 'Occupé';

  @override
  String get tenantFacilityBedStatusReserved => 'Réservé';

  @override
  String get tenantFacilityBedStatusOutOfService => 'Out sur service';

  @override
  String get tenantFacilityBedStatusCleaning => 'Nettoyage';

  @override
  String get tenantFacilityBedStatusMaintenance => 'Entretien';

  @override
  String get tenantFacilityBedStatusBlocked => 'Bloqué';

  @override
  String get tenantFacilitySavedMessage =>
      'Modifications de configuration enregistrées.';

  @override
  String get routeSessionRestoringTitle => 'Séance de vérification';

  @override
  String get routeSessionRestoringBody =>
      'Terminez d\'abord la restauration de la session.';

  @override
  String get routeAuthRequiredTitle => 'Sign-in requis';

  @override
  String get routeAuthRequiredBody => 'Sign in à ouvrir ce page.';

  @override
  String get routeForbiddenTitle => 'Accès refusé';

  @override
  String get routeForbiddenBody => 'Vous n\'avez pas accès à cette page.';

  @override
  String get routeNotFoundTitle => 'Page introuvable';

  @override
  String get routeNotFoundBody => 'Cet itinéraire n\'est pas disponible.';

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
  String get authVerifyEmailActionLabel => 'Vérifier';

  @override
  String get authSendNewCodeActionLabel => 'Send nouveau code';

  @override
  String get authVerifyEmailTitle => 'Verify votre e-mail';

  @override
  String get authEmailVerifiedTitle => 'Email vérifié';

  @override
  String authVerifyEmailBody(String email) {
    return 'Enter le vérification code sent à$email.';
  }

  @override
  String authPendingVerificationBody(String email) {
    return 'Cet email est déjà enregistré mais n\'a pas été vérifié. Entrez le code de vérification envoyé à$email.';
  }

  @override
  String get authVerifyEmailBodyNoEmail =>
      'Enter le vérification code sent à votre e-mail.';

  @override
  String get authEmailVerifiedBody =>
      'Votre compte est vérifié. Vous pouvez maintenant vous connecter.';

  @override
  String get authEmailVerifiedAwaitingApprovalBody =>
      'Votre email est vérifié. Un administrateur de la plateforme examinera votre inscription avant que vous puissiez vous connecter.';

  @override
  String get authAccountPendingApprovalMessage =>
      'Votre email est vérifié. Votre compte est en attente d\'approbation par la plateforme avant de pouvoir vous connecter.';

  @override
  String get authTenantNameLabel => 'Organization nom';

  @override
  String get authPhoneLabel => 'Téléphone';

  @override
  String get authVerificationCodeResentMessage =>
      'Un nouveau code de vérification a été envoyé.';

  @override
  String get authVerificationCodeLabel => 'Le code de vérification';

  @override
  String get authVerificationCodeInvalidMessage =>
      'Enter le 6-digit vérification code.';

  @override
  String get authAccountPendingMessage =>
      'Cet email est déjà enregistré mais n\'a pas été vérifié. Entrez le code de vérification par e-mail que nous avons envoyé pour continuer.';

  @override
  String get authAdminNameLabel => 'Administrator nom';

  @override
  String get authFacilityNameLabel => 'Facility nom';

  @override
  String get authFacilityTypeLabel => 'Type d\'installation';

  @override
  String get authFacilityTypeHospital => 'Hôpital';

  @override
  String get authFacilityTypeClinic => 'Clinique';

  @override
  String get authFacilityTypeLab => 'Laboratoire';

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
  String get authPasswordChangedMessage =>
      'Mot de passe modifié. Connectez-vous à nouveau.';

  @override
  String get authInvalidCredentialsMessage =>
      'Les informations de connexion ne sont pas valides.';

  @override
  String get authAccountNotFoundMessage =>
      'No compte exists pour cette e-mail ou téléphone. Check le détails ou créer un compte.';

  @override
  String get authWrongPasswordMessage =>
      'Le mot de passe est incorrect pour ce compte.';

  @override
  String get authRateLimitedMessage =>
      'Trop de tentatives de connexion. Veuillez patienter un moment et réessayer.';

  @override
  String get authForbiddenMessage =>
      'Ce compte ne peut pas complete cette action.';

  @override
  String get authEmailInvalidMessage => 'Enter un valid e-mail adresse.';

  @override
  String get authPasswordMinLengthMessage => 'Utilisez au moins 8 caractères.';

  @override
  String get authPasswordMismatchMessage =>
      'Les mots de passe ne correspondent pas.';

  @override
  String get authForgotPasswordTitle => 'Reset votre mot de passe';

  @override
  String get authForgotPasswordBody =>
      'Entrez l\'e-mail sur votre compte d\'établissement. S\'il correspond à un compte, nous vous enverrons des instructions de réinitialisation.';

  @override
  String get authForgotPasswordActionLabel => 'Forgot mot de passe?';

  @override
  String get authForgotPasswordSubmitLabel =>
      'Envoyer les instructions de réinitialisation';

  @override
  String get authForgotPasswordTenantPrompt =>
      'Choose le espace de travail pour ce compte.';

  @override
  String get authForgotPasswordSubmittedTitle => 'Check votre e-mail';

  @override
  String get authForgotPasswordSubmittedBody =>
      'S\'il existe un compte pour cet e-mail, des instructions de réinitialisation avec un lien sécurisé et un code à six chiffres ont été envoyées.';

  @override
  String get authResetPasswordWithCodeActionLabel =>
      'Entrez le code de réinitialisation';

  @override
  String get authResetPasswordTitle => 'Choose un nouveau mot de passe';

  @override
  String get authResetPasswordBody =>
      'Enter un nouveau mot de passe pour votre compte.';

  @override
  String get authResetPasswordCodeModeBody =>
      'Enter votre e-mail, le six-digit reset code de votre e-mail, et un nouveau mot de passe.';

  @override
  String get authResetPasswordCodeLabel => 'Réinitialiser le code';

  @override
  String get authResetPasswordCodeInvalidMessage =>
      'Enter le six-digit reset code de votre e-mail.';

  @override
  String get authResetPasswordActionLabel => 'Reset mot de passe';

  @override
  String get authResetPasswordMissingTokenMessage =>
      'Ce lien de réinitialisation est manquant ou invalide. Demandez une nouvelle réinitialisation de mot de passe depuis la page de connexion.';

  @override
  String get authResetPasswordCompletedTitle => 'Password mis à jour';

  @override
  String get authResetPasswordCompletedBody =>
      'Votre mot de passe a été modifié. Connectez-vous avec le nouveau mot de passe.';

  @override
  String get authResetPasswordInvalidTokenMessage =>
      'Ce lien de réinitialisation a expiré ou n\'est pas valide. Demandez une nouvelle réinitialisation du mot de passe.';

  @override
  String opdFieldRequiredLabel(String label) {
    return '$label(requis)';
  }

  @override
  String opdFieldOptionalLabel(String label) {
    return '$label(facultatif)';
  }

  @override
  String get opdVitalsAtLeastOneRequiredHelper =>
      'Entrez au moins un signe vital.';

  @override
  String get validationRequired => 'Ce champ est requis.';

  @override
  String validationFieldRequiredMessage(String field) {
    return '$field est requis.';
  }

  @override
  String validationFieldInvalidMessage(String field) {
    return 'Saisissez un(e) $field valide.';
  }

  @override
  String validationFieldInvalidFormatMessage(String field) {
    return 'Utilisez un format $field valide.';
  }

  @override
  String validationFieldAlreadyInUseMessage(String field) {
    return '$field est déjà utilisé.';
  }

  @override
  String get errorNetworkTitle => 'Problème de connexion';

  @override
  String get errorNetworkMessage => 'Check votre connexion et réessayer.';

  @override
  String get errorTimeoutTitle => 'La demande a expiré';

  @override
  String get errorTimeoutMessage =>
      'La demande a pris trop de temps. Essayer à nouveau.';

  @override
  String get errorOfflineTitle => 'No connexion';

  @override
  String get errorOfflineMessage => 'Connect à le internet et réessayer.';

  @override
  String get errorCancelledTitle => 'Demande annulée';

  @override
  String get errorCancelledMessage => 'La demande a été annulée.';

  @override
  String get errorUnauthorizedTitle => 'Sign-in requis';

  @override
  String get errorUnauthorizedMessage => 'Sign in again à continuer.';

  @override
  String get errorForbiddenTitle => 'Accès refusé';

  @override
  String get errorForbiddenMessage => 'Vous n\'avez pas l\'autorisation.';

  @override
  String get errorNotFoundTitle => 'Pas trouvé';

  @override
  String get errorNotFoundMessage => 'L\'article n\'est pas disponible.';

  @override
  String get errorValidationTitle => 'Check le détails';

  @override
  String get errorValidationMessage => 'Check le highlighted détails.';

  @override
  String get errorUnexpectedResponseTitle => 'Unexpected réponse';

  @override
  String get errorUnexpectedResponseMessage => 'Réessayez plus tard.';

  @override
  String get errorStorageTitle => 'Storage indisponible';

  @override
  String get errorStorageMessage =>
      'Local data n\'a pas pu être accessed. Try again.';

  @override
  String get errorUnexpectedTitle => 'Quelque chose s\'est mal passé';

  @override
  String get errorUnexpectedMessage =>
      'Quelque chose s\'est mal passé. Essayer à nouveau.';

  @override
  String get navigationClinicalLabel => 'Notes cliniques';

  @override
  String get navigationClinicalShortLabel => 'Clinique';

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
  String get clinicalSavingStatus => 'Enregistrement';

  @override
  String get clinicalSavedMessage => 'Modifications cliniques enregistrées.';

  @override
  String get clinicalPatientIdCopiedMessage => 'ID du patient copié.';

  @override
  String get clinicalFiltersLabel => 'Clinical filtres';

  @override
  String get clinicalSearchLabel => 'Search clinique worklist';

  @override
  String get clinicalSearchHint =>
      'Patient, consultation, queue, prestataire, ou location';

  @override
  String get clinicalScopeFilterLabel => 'Portée de la file d\'attente';

  @override
  String get clinicalAllScopeLabel => 'All actif work';

  @override
  String get clinicalTodayScopeLabel => 'Aujourdh’ui';

  @override
  String get clinicalWaitingReviewSummaryLabel => 'En attente d\'examen';

  @override
  String get clinicalUrgentSummaryLabel => 'Urgent';

  @override
  String get clinicalResultsReadySummaryLabel => 'RÉSULTATS PRÊTS';

  @override
  String get clinicalInConsultationSummaryLabel => 'En consultation';

  @override
  String get clinicalCompletedSummaryLabel => 'Terminé';

  @override
  String get clinicalWorklistTitle => 'Liste de travail du fournisseur';

  @override
  String get clinicalWorklistDescription =>
      'Consultations ouvertes, admissions, transferts de triage et files d’attente d’examen des résultats.';

  @override
  String get clinicalNoWorklistTitle => 'No clinique work';

  @override
  String get clinicalNoWorklistBody =>
      'No consultations match le actuel recherche et queue scope.';

  @override
  String get clinicalNoSelectionTitle => 'No consultation selected';

  @override
  String get clinicalNoSelectionBody =>
      'Ouvrez un patient dans la liste de travail pour examiner le contexte, documenter les soins et passer des commandes.';

  @override
  String get clinicalSourceQueueLabel => 'File d’attente';

  @override
  String get clinicalEncounterQueueLabel => 'File d\'attente de rencontre';

  @override
  String get clinicalLastUpdatedLabel => 'Last mis à jour';

  @override
  String get clinicalEncounterNumberLabel => 'Rencontre';

  @override
  String get clinicalAdmissionNumberLabel => 'Admission';

  @override
  String get clinicalEncounterTypeLabel => 'Type de rencontre';

  @override
  String get clinicalAgeLabel => 'Âge';

  @override
  String get clinicalLocationLabel => 'Emplacement';

  @override
  String get clinicalActionsTitle => 'Actions cliniques';

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
  String get clinicalCatalogSourceAll => 'Toutes les sources';

  @override
  String get clinicalCatalogSourceFavorites => 'Favoris';

  @override
  String get clinicalCatalogSourceFacility => 'Établissement';

  @override
  String get clinicalCatalogSourceGlobal => 'Catalogue global';

  @override
  String get clinicalCatalogConfigurationTitle =>
      'Catalogue de services cliniques';

  @override
  String get clinicalCatalogConfigurationBody =>
      'Choose which diagnoses, procedures, laboratoire tests, radiologie tests, et prescriptions ce établissement offers.';

  @override
  String get clinicalDiagnosisSelectedTitle => 'Diagnostics sélectionnés';

  @override
  String clinicalDiagnosisSelectedCount(int count) {
    return '${count}selected';
  }

  @override
  String get clinicalDiagnosisNoSelection => 'Aucun diagnostic sélectionné';

  @override
  String clinicalDiagnosisMatchesLabel(int shown, int total) {
    return 'Showing $shown sur $total matches';
  }

  @override
  String get clinicalDiagnosisNoCatalogOptions =>
      'No matching diagnostic terms';

  @override
  String get clinicalRequestLabAction => 'Demander un laboratoire';

  @override
  String get clinicalUpdateLabOrderAction => 'Update laboratoire commande';

  @override
  String get clinicalLabRequestTestsModeLabel => 'Tests individuels';

  @override
  String get clinicalLabRequestPanelsModeLabel => 'Panneaux de laboratoire';

  @override
  String get clinicalLabRequestSearchLabel => 'Search laboratoire catalog';

  @override
  String get clinicalLabRequestSearchHint =>
      'Search by nom, code, catégorie, specimen, ou statut';

  @override
  String get clinicalLabRequestSelectedTitle => 'Selected laboratoire demandes';

  @override
  String clinicalLabRequestSelectedCount(int count) {
    return '${count}selected';
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
  String get clinicalLabRequestPanelTypeLabel => 'Panneau';

  @override
  String clinicalLabRequestMatchesLabel(int shown, int total) {
    return 'Showing $shown sur $total matches';
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
      'Aucune ordonnance de laboratoire n’a été demandée pour ce patient.';

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
    return '${count}tests';
  }

  @override
  String clinicalLabOrderSampleCount(int count) {
    return '${count}samples';
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
    return '${count}tests';
  }

  @override
  String get clinicalPharmacyOrdersTitle => 'Pharmacy commandes';

  @override
  String clinicalPharmacyOrderItemCount(int count) {
    return '${count}medicines';
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
  String get clinicalRequestRadiologyAction => 'Demander une radiologie';

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
    return '${count}selected';
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
    return 'Showing $shown sur $total matches';
  }

  @override
  String get clinicalRadiologyRequestNoCatalogOptions =>
      'No matching radiologie catalog éléments';

  @override
  String get clinicalRadiologyCatalogSelectTitle => 'Catalogue de radiologie';

  @override
  String get clinicalRadiologyCatalogSelectBody =>
      'Search et sélectionner one matching imaging test, then ajouter it à le demande liste.';

  @override
  String get clinicalRadiologyCatalogSelectLabel => 'Test d\'imagerie';

  @override
  String get clinicalRadiologyCatalogSelectHint =>
      'Search et sélectionner un imaging test';

  @override
  String get clinicalRadiologyDuplicateSelectionMessage =>
      'Cette demande d\'imagerie est déjà sélectionnée.';

  @override
  String get clinicalRadiologyPriorityLabel => 'Priorité';

  @override
  String get clinicalRadiologyLateralityLabel => 'Latéralité';

  @override
  String get clinicalRadiologyBodyRegionLabel => 'Région du corps';

  @override
  String get clinicalPrescribeAction => 'Prescrire';

  @override
  String get clinicalPrescriptionHeaderTitle => 'Build ordonnance';

  @override
  String get clinicalPrescriptionHeaderBody =>
      'Add one ou more medicines, then send them together à pharmacie.';

  @override
  String get clinicalPrescriptionDrugLabel => 'Médicament disponible';

  @override
  String get clinicalPrescriptionMedicineLabel => 'Médecine';

  @override
  String get clinicalPrescriptionItemDescription =>
      'Select un drug et complete le ordonnance détails.';

  @override
  String get clinicalPrescriptionQuantityUnitLabel => 'Quantity unité';

  @override
  String get clinicalPrescriptionAddMedicineAction => 'Ajouter un médicament';

  @override
  String get clinicalPrescriptionRemoveMedicineAction =>
      'Supprimer le médicament';

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
  String get clinicalProcedureSelectedTitle => 'Procédures sélectionnées';

  @override
  String clinicalProcedureSelectedCount(int count) {
    return '${count}selected';
  }

  @override
  String get clinicalProcedureNoSelection => 'Aucune procédure sélectionnée';

  @override
  String get clinicalCarePlanAction => 'Care forfait';

  @override
  String get clinicalRequestAdmissionAction => 'Demander l\'admission';

  @override
  String get clinicalCompleteConsultationAction => 'Consultation complète';

  @override
  String get clinicalCompleteDispositionAction => 'Disposition complète';

  @override
  String get clinicalPrintSummaryAction => 'Print résumé';

  @override
  String get clinicalResultReviewTitle => 'Examen des résultats';

  @override
  String get clinicalResultReviewBody =>
      'Les résultats de diagnostic publiés sont prêts pour un examen clinique.';

  @override
  String get clinicalNoResultsReadyBody =>
      'Aucun résultat de laboratoire ou de radiologie publié n’est prêt à être examiné.';

  @override
  String get clinicalPatientNotesTitle => 'Patient clinique notes';

  @override
  String get clinicalNoPatientNotesLabel =>
      'Aucune note clinique du patient n’a encore été enregistrée.';

  @override
  String get clinicalDiagnosesTitle => 'Diagnostics';

  @override
  String get clinicalPatientDiagnosesTitle => 'Diagnostics des patients';

  @override
  String get clinicalNoPatientDiagnosesLabel =>
      'Aucun diagnostic n’a encore été enregistré pour ce patient.';

  @override
  String get clinicalDiagnosisFormTitle => 'Diagnosis détails';

  @override
  String get clinicalCarePlansTitle => 'Care forfaits';

  @override
  String get clinicalOrdersTitle => 'Ordres';

  @override
  String get clinicalHandoffsTitle => 'Transferts';

  @override
  String get clinicalTermSearchLabel => 'Terme clinique';

  @override
  String get clinicalCarePlanLabel => 'Care forfait';

  @override
  String get clinicalDoseAmountLabel => 'Dose montant';

  @override
  String get clinicalDoseUnitLabel => 'Dose unité';

  @override
  String get clinicalDurationValueLabel => 'Durée';

  @override
  String get clinicalDurationUnitLabel => 'Duration unité';

  @override
  String get clinicalInstructionsLabel => 'Consignes';

  @override
  String get clinicalAvailableBedLabel => 'Lit disponible';

  @override
  String get clinicalAdmissionDetailsTitle => 'Admission détails';

  @override
  String get clinicalAdmissionWardLabel => 'Service';

  @override
  String get clinicalAdmissionRoomLabel => 'Chambre';

  @override
  String get clinicalAdmissionBedLabel => 'Lit';

  @override
  String get clinicalAdmissionAvailabilityLabel => 'Disponibilité des lits';

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
      'Ce lit n\'est plus disponible. Veuillez choisir un autre lit.';

  @override
  String get clinicalDispositionReasonLabel => 'Motif de la décision';

  @override
  String get clinicalConsultationSummaryTitle => 'Consultation résumé';

  @override
  String get navigationIpdLabel => 'Patient hospitalisé (IPD)';

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
  String get ipdSavingStatus => 'Enregistrement';

  @override
  String get ipdSavedMessage =>
      'Modifications pour les patients hospitalisés enregistrées.';

  @override
  String get ipdAdmissionQueueSummaryLabel => 'Waiting lit';

  @override
  String get ipdActivePatientsSummaryLabel => 'In lits';

  @override
  String get ipdTransferPendingSummaryLabel => 'Transferts';

  @override
  String get ipdDischargePlannedSummaryLabel => 'Décharge prévue';

  @override
  String get ipdCriticalAlertsSummaryLabel => 'Alertes critiques';

  @override
  String get ipdFiltersLabel => 'Inpatient filtres';

  @override
  String get ipdSearchLabel => 'Rechercher des admissions';

  @override
  String get ipdSearchHint =>
      'Patient, admission, consultation, service, ou lit';

  @override
  String get ipdScopeFilterLabel => 'Portée du tableau';

  @override
  String get ipdWardFilterLabel => 'Service';

  @override
  String get ipdAllWardsOption => 'All services';

  @override
  String get ipdBoardTitle => 'Conseil des patients hospitalisés';

  @override
  String get ipdBoardDescription =>
      'Track waiting admissions, bedded patients, transferts, service activity, et sortie forfaits.';

  @override
  String get ipdNoAdmissionsTitle => 'Aucune admission';

  @override
  String get ipdNoAdmissionsBody =>
      'No hospitalisé admissions match le actuel filtres.';

  @override
  String get ipdLocationColumnLabel => 'Ward et lit';

  @override
  String get ipdPendingActionColumnLabel => 'Prochaine action';

  @override
  String get ipdAdmittedAtColumnLabel => 'Admis';

  @override
  String get ipdAdmissionDetailTitle => 'Détails d\'admission';

  @override
  String get ipdAdmissionDetailDescription =>
      'Review lit statut, transferts, service rounds, médicament dossiers, soins infirmiers notes, et sortie state.';

  @override
  String get ipdNoSelectionTitle => 'Aucune admission sélectionnée';

  @override
  String get ipdNoSelectionBody =>
      'Ouvrir une admission auprès du conseil d’administration pour gérer les soins hospitaliers.';

  @override
  String get ipdPatientContextLabel => 'Contexte du patient';

  @override
  String get ipdAdmissionIdLabel => 'Admission';

  @override
  String get ipdEncounterIdLabel => 'Rencontre';

  @override
  String get ipdWardBedLabel => 'Ward et lit';

  @override
  String get ipdFacilityLabel => 'Établissement';

  @override
  String get ipdIcuStatusLabel => 'ICU statut';

  @override
  String get ipdAssignBedAction => 'Assign lit';

  @override
  String get ipdReleaseBedAction => 'Release lit';

  @override
  String get ipdRejectAdmissionAction => 'Rejeter l\'admission';

  @override
  String get ipdRequestTransferAction => 'Demander un transfert';

  @override
  String get ipdRequestTherapyAction => 'Demander une physiothérapie';

  @override
  String get ipdOpenPhysiotherapyAction => 'Physiothérapie ouverte';

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
  String get ipdTransfersSectionTitle => 'Transferts';

  @override
  String get ipdRoundsSectionTitle => 'Rondes de quartier';

  @override
  String get ipdNursingSectionTitle => 'Notes de soins infirmiers';

  @override
  String get ipdMedicationSectionTitle => 'Médicament';

  @override
  String get ipdBedSectionTitle => 'Attribution des lits';

  @override
  String get ipdDischargeSectionTitle => 'Sortie';

  @override
  String get ipdPharmacyClearanceLabel => 'Dégagement en pharmacie';

  @override
  String get ipdPharmacyClearanceCleared => 'Effacé';

  @override
  String ipdPharmacyClearancePending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count commandes ouvertes',
      one: '1 commande ouverte',
    );
    return '$_temp0';
  }

  @override
  String get ipdTimelineSectionTitle => 'Calendrier';

  @override
  String get ipdNoTransfersTitle => 'No transferts';

  @override
  String get ipdNoTransfersBody =>
      'Aucune demande de transfert n\'est enregistrée pour cette admission.';

  @override
  String get ipdNoRoundsTitle => 'No service rounds';

  @override
  String get ipdNoRoundsBody =>
      'Aucune tournée de quartier n’a encore été documentée.';

  @override
  String get ipdNoNursingNotesTitle => 'No soins infirmiers notes';

  @override
  String get ipdNoNursingNotesBody =>
      'Aucune note infirmière n’a encore été documentée.';

  @override
  String get ipdNoMedicationTitle => 'No médicament dossiers';

  @override
  String get ipdNoMedicationBody =>
      'Aucune administration de médicament n\'est enregistrée pour cette admission.';

  @override
  String get ipdNoTimelineTitle => 'Aucune entrée de chronologie';

  @override
  String get ipdNoTimelineBody =>
      'Aucune activité de soins n’a encore été enregistrée.';

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
  String get ipdTransferActionFieldLabel => 'Action de transfert';

  @override
  String get ipdDestinationBedFieldLabel => 'Destination lit';

  @override
  String get ipdNotesFieldLabel => 'Remarques';

  @override
  String get ipdSummaryFieldLabel => 'Résumé';

  @override
  String get ipdReasonFieldLabel => 'Raison';

  @override
  String get ipdMedicationOrderFieldLabel => 'Medication commande';

  @override
  String get ipdMedicationOrderHint => 'Select un suggested commande';

  @override
  String get ipdMedicationFieldLabel => 'Médicament';

  @override
  String get ipdDoseFieldLabel => 'Dose';

  @override
  String get ipdUnitFieldLabel => 'Unité';

  @override
  String get ipdRouteFieldLabel => 'Itinéraire';

  @override
  String get ipdFrequencyFieldLabel => 'Fréquence';

  @override
  String get ipdMedicationStatusFieldLabel => 'Statut';

  @override
  String get ipdDischargedAtLabel => 'Sortie d&apos;hôpital du malade';

  @override
  String get ipdScopeAdmissionQueue => 'Waiting lit';

  @override
  String get ipdScopeActivePatients => 'In lits';

  @override
  String get ipdScopeTransferPending => 'Transferts';

  @override
  String get ipdScopeDischargePlanned => 'Décharge prévue';

  @override
  String get ipdScopeAwaitingClearance => 'En attente d\'autorisation';

  @override
  String get ipdScopeDischarged => 'Sortie d&apos;hôpital du malade';

  @override
  String get ipdScopeAll => 'Toutes les admissions';

  @override
  String get ipdStatusAdmittedPendingBed => 'Waiting lit';

  @override
  String get ipdStatusAdmittedInBed => 'In lit';

  @override
  String get ipdStatusTransferRequested => 'Transfert demandé';

  @override
  String get ipdStatusTransferInProgress => 'Transfert en cours';

  @override
  String get ipdStatusDischargePlanned => 'Décharge prévue';

  @override
  String get ipdStatusDischarged => 'Sortie d&apos;hôpital du malade';

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
  String get ipdBedStatusAvailable => 'Disponible';

  @override
  String get ipdBedStatusOccupied => 'Occupé';

  @override
  String get ipdBedStatusReserved => 'Réservé';

  @override
  String get ipdBedStatusOutOfService => 'Out sur service';

  @override
  String get ipdBedStatusCleaning => 'Nettoyage';

  @override
  String get ipdBedStatusMaintenance => 'Entretien';

  @override
  String get ipdBedStatusBlocked => 'Bloqué';

  @override
  String get ipdPatientBoardTab => 'Tableau des patients';

  @override
  String get ipdBedBoardTab => 'Tableau des lits';

  @override
  String get ipdBedBoardTitle => 'Tableau des lits';

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
  String get ipdCurrentPatientColumnLabel => 'Patient actuel';

  @override
  String get ipdNextActionColumnLabel => 'Prochaine action';

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
  String get ipdBedActionMaintenance => 'Entretien des marques';

  @override
  String get ipdBedActionReturnToService => 'Return à service';

  @override
  String get ipdBedActionOpenAdmission => 'Entrée libre';

  @override
  String get ipdBedNoActionLabel => 'Aucune action';

  @override
  String get ipdStartAdmissionAction => 'Commencer l\'admission';

  @override
  String get ipdStartAdmissionTitle => 'Commencer l\'admission';

  @override
  String get ipdStartAdmissionPatientLabel => 'Patient';

  @override
  String get ipdStartAdmissionPatientHint => 'Search patient by nom ou ID';

  @override
  String get ipdStartAdmissionNoPatients => 'Aucun patient correspondant';

  @override
  String get ipdStartAdmissionWardLabel => 'Recommended service (facultatif)';

  @override
  String get ipdStartAdmissionBedLabel => 'Bed (facultatif)';

  @override
  String get ipdLengthOfStayColumnLabel => 'Length sur stay';

  @override
  String ipdLengthOfStayDays(int count) {
    return '$count j';
  }

  @override
  String ipdLengthOfStayHours(int count) {
    return '$count h';
  }

  @override
  String get ipdDischargeStatusPlanned => 'Prévu';

  @override
  String get ipdDischargeStatusCompleted => 'Terminé';

  @override
  String get ipdManageDischargeTitle => 'Manage sortie';

  @override
  String get ipdDischargeClearanceTitle => 'Autorisation de décharge';

  @override
  String get ipdDischargeClearancePhaseLabel => 'Phase de dédouanement';

  @override
  String get ipdPendingOrdersTitle => 'Pending commandes';

  @override
  String get ipdClearancePendingOrders => 'Pending commandes reviewed';

  @override
  String get ipdClearancePharmacy => 'Dégagement en pharmacie';

  @override
  String get ipdClearanceBilling => 'Autorisation de facturation';

  @override
  String get ipdClearanceNursing => 'Autorisation de soins infirmiers';

  @override
  String get ipdClearanceDocuments => 'Documents prêts';

  @override
  String get ipdClearancePatientExit => 'Le patient est sorti';

  @override
  String get ipdDischargeOverrideLabel => 'Raison de dérogation autorisée';

  @override
  String get ipdDischargeOverrideHint =>
      'Required only lorsque clearing avec incomplete steps';

  @override
  String get ipdSaveClearanceAction => 'Enregistrer la liquidation';

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
  String get ipdClearancePhaseReadyForExit => 'Prêt pour la sortie';

  @override
  String get ipdOrderLabAction => 'Order laboratoire';

  @override
  String get ipdOrderRadiologyAction => 'Order radiologie';

  @override
  String get ipdOrderPrescriptionAction => 'Prescribe médicament';

  @override
  String get ipdOpenNursingAction =>
      'Espace de travail ouvert pour les soins infirmiers';

  @override
  String get ipdSourceContextTitle => 'Source d\'admission';

  @override
  String get ipdSourceKindLabel => 'Source';

  @override
  String get ipdEncounterTypeLabel => 'Type de rencontre';

  @override
  String get ipdSourceKindOpd => 'OPD passation';

  @override
  String get ipdSourceKindEmergency => 'Admission d\'urgence';

  @override
  String get ipdSourceKindReferral => 'Référence';

  @override
  String get ipdSourceKindDirect => 'Entrée directe';

  @override
  String get ipdIcuStatusActive => 'Actif';

  @override
  String get ipdIcuStatusEnded => 'Terminé';

  @override
  String get ipdIcuStatusNone => 'Pas de séjour aux soins intensifs';

  @override
  String get ipdCriticalAlertLabel => 'Alerte critique';

  @override
  String ipdCriticalSeverityLabel(String severity) {
    return 'Critical:$severity';
  }

  @override
  String get ipdTimelineWardRound => 'Tour de quartier';

  @override
  String get ipdTimelineNursingNote => 'Note infirmière';

  @override
  String get ipdTimelineMedication => 'Médicament';

  @override
  String get ipdTimelineMedicationReminder => 'Rappel de médicaments';

  @override
  String get ipdTimelineTransfer => 'Transfert';

  @override
  String get ipdTimelineIcuObservation => 'Observation en soins intensifs';

  @override
  String get ipdTimelineCriticalAlert => 'Alerte critique';

  @override
  String get ipdTimelineCareEvent => 'Événement de soins';

  @override
  String get ipdTransferApproveAction => 'Approuver';

  @override
  String get ipdTransferStartAction => 'Start transfert';

  @override
  String get ipdTransferCompleteAction => 'Complete transfert';

  @override
  String get ipdTransferCancelAction => 'Cancel transfert';

  @override
  String get ipdRouteOral => 'Voie orale';

  @override
  String get ipdRouteIv => 'IV';

  @override
  String get ipdRouteIm => 'JE SUIS';

  @override
  String get ipdRouteTopical => 'Topique';

  @override
  String get ipdRouteInhalation => 'Inhalation';

  @override
  String get ipdRouteOther => 'Autre';

  @override
  String get ipdFrequencyOnce => 'Une fois';

  @override
  String get ipdFrequencyBid => 'OFFRE';

  @override
  String get ipdFrequencyTid => 'TID';

  @override
  String get ipdFrequencyQid => 'QID';

  @override
  String get ipdFrequencyPrn => 'PNR';

  @override
  String get ipdFrequencyStat => 'STATUT';

  @override
  String get ipdFrequencyCustom => 'Coutume';

  @override
  String get ipdMedicationGiven => 'Donné';

  @override
  String get ipdMedicationMissed => 'Manqué';

  @override
  String get ipdMedicationDelayed => 'Retardé';

  @override
  String get ipdMedicationRefused => 'Refusé';

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
  String get nursingSavingStatus => 'Enregistrement';

  @override
  String get nursingSavedMessage => 'Modifications infirmières enregistrées.';

  @override
  String get nursingAssignedWardSummaryLabel => 'Assigned service';

  @override
  String get nursingUrgentSummaryLabel => 'Urgent';

  @override
  String get nursingMedicationDueSummaryLabel => 'Médicaments à payer';

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
  String get nursingScopeFilterLabel => 'Portée de la file d\'attente';

  @override
  String get nursingWardFilterLabel => 'Ward ou lit';

  @override
  String get nursingWardFilterHint => 'Filter by service ou lit';

  @override
  String get nursingScopeAssignedWardLabel => 'Assigned service';

  @override
  String get nursingScopeUrgentLabel => 'Urgent';

  @override
  String get nursingScopeMedicationDueLabel => 'Médicaments à payer';

  @override
  String get nursingScopeHandoverPendingLabel => 'Handover en attente';

  @override
  String get nursingScopeTransferPendingLabel => 'Transfer en attente';

  @override
  String get nursingScopeDischargePendingLabel => 'Discharge en attente';

  @override
  String get nursingScopeAllLabel => 'Tous';

  @override
  String get nursingWorklistTitle => 'Liste de travail du service';

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
      'Ouvrez un patient dans la liste de travail pour consulter les observations, les médicaments, les transferts et l\'activité du service.';

  @override
  String get nursingPatientContextLabel =>
      'Selected soins infirmiers patient context';

  @override
  String get nursingLocationColumnLabel => 'Emplacement';

  @override
  String get nursingDueActionColumnLabel => 'Action due';

  @override
  String get nursingLastObservationColumnLabel => 'Dernière observation';

  @override
  String get nursingAdmissionLabel => 'Admission';

  @override
  String get nursingEncounterLabel => 'Rencontre';

  @override
  String get nursingLocationLabel => 'Emplacement';

  @override
  String get nursingFacilityLabel => 'Établissement';

  @override
  String get nursingIcuLabel => 'ICU';

  @override
  String get nursingBedLabel => 'Lit';

  @override
  String get nursingActionsTitle => 'Actions infirmières';

  @override
  String get nursingActionRecordVitals => 'Record signes vitaux';

  @override
  String get nursingActionAddNote => 'Ajouter une note';

  @override
  String get nursingActionAdministerMedication => 'Administer médicament';

  @override
  String get nursingActionCompleteTask => 'Tâche terminée';

  @override
  String get nursingActionCreateHandover => 'Créer un transfert';

  @override
  String get nursingActionEscalate => 'Intensifier';

  @override
  String get nursingActionAcknowledgeTransfer => 'Acknowledge transfert';

  @override
  String get nursingActionAcceptHandover => 'Accepter le transfert';

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
  String get nursingMedicationsTitle => 'Médicaments';

  @override
  String get nursingNotesTitle => 'Notes de soins infirmiers';

  @override
  String get nursingCarePlansTitle => 'Care forfaits';

  @override
  String get nursingHandoversTitle => 'Remises';

  @override
  String get nursingWardActivityTitle => 'Activité de la paroisse';

  @override
  String get nursingNoRecordsLabel => 'No dossiers yet';

  @override
  String get nursingVitalsTypeLabel => 'Type vital';

  @override
  String get nursingVitalValueLabel => 'Valeur';

  @override
  String get nursingVitalUnitLabel => 'Unité';

  @override
  String get nursingSystolicLabel => 'Systolique';

  @override
  String get nursingDiastolicLabel => 'Diastolique';

  @override
  String get nursingMapLabel => 'CARTE';

  @override
  String get nursingRecordedAtLabel => 'Enregistré à';

  @override
  String get nursingAdministeredAtLabel => 'Administré à';

  @override
  String get nursingDateTimeHint => 'AAAA-MM-JJTHH:mm:ssZ';

  @override
  String get nursingNoteLabel => 'Note';

  @override
  String get nursingTaskLabel => 'Tâche';

  @override
  String get nursingMedicationLabel => 'Médicament';

  @override
  String get nursingDoseLabel => 'Dose';

  @override
  String get nursingRouteLabel => 'Itinéraire';

  @override
  String get nursingAdministrationStatusLabel => 'Administration statut';

  @override
  String get nursingFrequencyLabel => 'Fréquence';

  @override
  String get nursingAdministrationNoteLabel => 'Note administrative';

  @override
  String get nursingScheduleRemindersLabel => 'Programmer des rappels';

  @override
  String get nursingConfirmMedicationLabel =>
      'Confirm médicament administration';

  @override
  String get nursingConfirmMedicationSubtitle =>
      'Verify le patient, médicament, dose, route, et heure avant saving.';

  @override
  String get nursingHandoverToUserLabel => 'Destinataire';

  @override
  String get nursingHandoverNotesLabel => 'Notes de passation';

  @override
  String get nursingEscalationMessageLabel => 'Message d\'escalade';

  @override
  String get nursingConfirmEscalationLabel => 'Confirmer l\'escalade';

  @override
  String get nursingTransferActionLabel => 'Action de transfert';

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
  String get nursingDateFromLabel => 'Du';

  @override
  String get nursingDateToLabel => 'A';

  @override
  String get nursingDatePickerLabel => 'Choisissez une date';

  @override
  String get nursingInvalidDateMessage => 'Enter un valid date.';

  @override
  String get nursingPatientFilterLabel => 'Patient';

  @override
  String get nursingPatientFilterHint =>
      'Name, number, admission, ou consultation';

  @override
  String get nursingUnitFilterLabel => 'Unité';

  @override
  String get nursingUnitFilterHint => 'Ward, ICU, recovery, ou unité';

  @override
  String get nursingShiftFilterLabel => 'Changement';

  @override
  String get nursingShiftFilterHint =>
      'Morning, evening, night, ou actuel quart';

  @override
  String get nursingCareTaskFilterLabel => 'Tâche de soins';

  @override
  String get nursingCareTaskFilterHint =>
      'Vitals, médicament, handover, transfert, ou sortie';

  @override
  String get nursingAdmissionStatusFilterLabel => 'Admission statut';

  @override
  String get nursingAdmissionStatusFilterHint =>
      'Active, admis, transfert, ou sortie statut';

  @override
  String get nursingDischargeReadinessFilterLabel => 'Préparation à la sortie';

  @override
  String get nursingDischargeReadinessFilterHint =>
      'Planifié, en attente, prêt ou bloqué';

  @override
  String get nursingPriorityFilterLabel => 'Priorité';

  @override
  String get nursingPriorityHighLabel => 'Haut';

  @override
  String get nursingPriorityMediumLabel => 'Moyen';

  @override
  String get nursingPriorityRoutineLabel => 'Routine';

  @override
  String get nursingAdmissionColumnLabel => 'Admission';

  @override
  String get nursingTaskTypeColumnLabel => 'Type de tâche';

  @override
  String get nursingPriorityColumnLabel => 'Priorité';

  @override
  String get nursingDueTimeColumnLabel => 'Due heure';

  @override
  String get nursingResponsibleNurseColumnLabel => 'Infirmière responsable';

  @override
  String get nursingDueNowLabel => 'Maintenant';

  @override
  String get nursingAssignedShiftLabel => 'Assigned quart';

  @override
  String get nursingWardAdmissionChecklistTitle =>
      'Liste de contrôle d\'admission en salle';

  @override
  String get nursingWardAdmissionChecklistDescription =>
      'Checks tied à lit location, admission handover, observations, soins forfait, médicament, et sortie readiness.';

  @override
  String get nursingChecklistCompleteStatus => 'Complet';

  @override
  String get nursingChecklistPendingStatus => 'En attente';

  @override
  String get nursingChecklistLocationTitle => 'Localisation confirmée';

  @override
  String get nursingChecklistLocationReadyBody =>
      'La localisation du patient est disponible.';

  @override
  String get nursingChecklistLocationPendingBody =>
      'Waiting pour lit allocation ou authorized holding area.';

  @override
  String get nursingChecklistHandoverTitle => 'Remise des admissions';

  @override
  String get nursingChecklistHandoverReadyBody =>
      'Une relève infirmière est liée à cette admission.';

  @override
  String get nursingChecklistHandoverPendingBody =>
      'Enregistrez ou acceptez le transfert d’admission avant la poursuite des soins en salle.';

  @override
  String get nursingChecklistVitalsTitle => 'Premières observations';

  @override
  String get nursingChecklistVitalsPendingBody =>
      'Record baseline vital signs pour le admission.';

  @override
  String get nursingChecklistCarePlanTitle => 'Care forfait started';

  @override
  String get nursingChecklistCarePlanReadyBody =>
      'Au moins une tâche ou un plan de soins est enregistré.';

  @override
  String get nursingChecklistCarePlanPendingBody =>
      'Add un soins task ou forfait pour service follow-up.';

  @override
  String get nursingChecklistMedicationTitle =>
      'La file d\'attente des médicaments est supprimée';

  @override
  String get nursingChecklistMedicationReadyBody =>
      'Aucune administration de médicament n’est actuellement prévue.';

  @override
  String get nursingChecklistMedicationPendingBody =>
      'Medication administration remains due pour ce patient.';

  @override
  String get nursingChecklistDischargeTitle =>
      'Discharge soins infirmiers readiness';

  @override
  String get nursingChecklistDischargeReadyBody =>
      'Aucune liste de contrôle des soins infirmiers à la sortie n’est en attente.';

  @override
  String get nursingChecklistDischargePendingBody =>
      'Les contrôles infirmiers de sortie sont en attente ; ne fermez pas l\'admission ici.';

  @override
  String get nursingChecklistIdentityTitle => 'Identité confirmée';

  @override
  String get nursingChecklistIdentityReadyBody =>
      'L\'identité du patient a été confirmée.';

  @override
  String get nursingChecklistIdentityPendingBody =>
      'Confirm patient nom, admission number, et service/lit.';

  @override
  String get nursingChecklistAllergiesTitle => 'Allergies et risk flags';

  @override
  String get nursingChecklistAllergiesReadyBody =>
      'Les allergies et les indicateurs de risque ont été examinés.';

  @override
  String get nursingChecklistAllergiesPendingBody =>
      'Review et dossier patient allergies et risk flags.';

  @override
  String get nursingChecklistBelongingsTitle => 'Affaires';

  @override
  String get nursingChecklistBelongingsReadyBody =>
      'Les effets personnels des patients ont été enregistrés.';

  @override
  String get nursingChecklistBelongingsPendingBody =>
      'Record patient belongings per hôpital policy.';

  @override
  String get nursingChecklistDoctorTitle => 'Médecin prévenu';

  @override
  String get nursingChecklistDoctorReadyBody =>
      'Le médecin responsable a été prévenu.';

  @override
  String get nursingChecklistDoctorPendingBody =>
      'Notify le responsible doctor sur le service admission.';

  @override
  String get nursingActionOrderLab => 'Order laboratoire tests';

  @override
  String get nursingActionOrderRadiology => 'Prescrire une imagerie';

  @override
  String get nursingActionDischargeClearance => 'Autorisation de décharge';

  @override
  String get nursingActionOpenIcu => 'Ouvrir l’espace de travail ICU';

  @override
  String get nursingActionConfirmIdentity => 'Confirmer l\'identité';

  @override
  String get nursingActionRecordAllergies =>
      'Enregistrer les allergies et les risques';

  @override
  String get nursingActionRecordBelongings =>
      'Enregistrer les effets personnels';

  @override
  String get nursingActionNotifyDoctor => 'Avertir le médecin';

  @override
  String get nursingAllergiesLabel => 'Allergies et risk flags';

  @override
  String get nursingBelongingsLabel => 'Affaires';

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
  String get nursingDischargeClearanceNotesLabel => 'Notes complémentaires';

  @override
  String get nursingDischargeClearanceConfirmLabel =>
      'Je confirme que l\'autorisation infirmière est complète';

  @override
  String get nursingClearanceMedicationEducationLabel =>
      'Éducation sur les médicaments assurée';

  @override
  String get nursingClearanceWoundCareLabel => 'Wound soins instructions given';

  @override
  String get nursingClearanceFollowUpLabel => 'Rendez-vous de suivi organisés';

  @override
  String get nursingClearanceBelongingsReturnedLabel =>
      'Les effets personnels restitués';

  @override
  String get nursingClearanceIdentityBandLabel => 'Bande d\'identité supprimée';

  @override
  String get nursingShiftContextTitle => 'Changer de contexte';

  @override
  String get nursingShiftContextDescription =>
      'Current roster et handover éléments stay visible sans opening another module.';

  @override
  String get nursingRosterTitle => 'Affectations de la liste';

  @override
  String get nursingPendingHandoverTitle => 'Remises en attente';

  @override
  String get nursingNoRosterLabel =>
      'No roster assignments found pour ce quart.';

  @override
  String get navigationDischargeLabel => 'Planification des sorties';

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
  String get dischargePlannedSummaryLabel => 'Prévu';

  @override
  String get dischargeSummaryPendingSummaryLabel => 'Summary en attente';

  @override
  String get dischargeDocumentsReadySummaryLabel => 'Documents prêts';

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
  String get dischargeStatusAll => 'Toutes les décharges';

  @override
  String get dischargeStatusPlanned => 'Prévu';

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
  String get dischargeStatusDocumentsReady => 'Documents prêts';

  @override
  String get dischargeStatusCompleted => 'Terminé';

  @override
  String get dischargeWorklistTitle => 'Liste de travail de sortie';

  @override
  String get dischargeWorklistDescription =>
      'Patients avec un sortie forfait, en attente clearance, ou recent completion.';

  @override
  String get dischargePreviousPageLabel => 'Décharges antérieures';

  @override
  String get dischargeNextPageLabel => 'Prochaines décharges';

  @override
  String dischargePageLabel(int from, int to, int total) {
    return '$from-$to sur $total';
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
  String get dischargeNextActionColumnLabel => 'Prochaine action';

  @override
  String get dischargeTargetColumnLabel => 'Cible';

  @override
  String get dischargeDetailTitle => 'Détail de la décharge';

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
  String get dischargeEncounterFieldLabel => 'Rencontre';

  @override
  String get dischargeLocationFieldLabel => 'Emplacement';

  @override
  String get dischargeTargetFieldLabel => 'Target sortie';

  @override
  String get dischargeStartPlanAction => 'Start sortie forfait';

  @override
  String get dischargeEditSummaryAction => 'Edit résumé';

  @override
  String get dischargeRequestBillingAction => 'Demander la facturation finale';

  @override
  String get dischargeRequestPharmacyAction => 'Demander des médicaments';

  @override
  String get dischargeCompleteAction => 'Complete sortie';

  @override
  String get dischargeChecklistTitle => 'Liste de contrôle de dédouanement';

  @override
  String get dischargeChecklistBody =>
      'Track clinique, soins infirmiers, pharmacie, billing, documents, et lit release readiness.';

  @override
  String get dischargeClearanceComplete => 'Complet';

  @override
  String get dischargeClearancePending => 'En attente';

  @override
  String get dischargeClearanceBackendGap => 'Indisponible';

  @override
  String get dischargeClearanceUnavailable => 'Indisponible';

  @override
  String get dischargeClearanceDoctor => 'Doctor résumé';

  @override
  String get dischargeClearanceNursing => 'Transfert des soins infirmiers';

  @override
  String get dischargeClearancePharmacy => 'Médicaments en pharmacie';

  @override
  String get dischargeClearanceBilling => 'Facturation finale';

  @override
  String get dischargeClearanceInsurance => 'Autorisation d\'assurance';

  @override
  String get dischargeClearanceDocuments => 'Documents';

  @override
  String get dischargeClearanceBedRelease => 'Libération du lit';

  @override
  String get dischargeClearanceHousekeeping => 'Ménage';

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
  String get dischargeMedicinesSectionTitle => 'Médicaments de décharge';

  @override
  String get dischargeNoMedicinesBody =>
      'Aucune ordonnance de sortie de médicament n’est liée à cette admission.';

  @override
  String get dischargePharmacyUnavailableBody =>
      'Pharmacy orders n\'a pas pu être loaded. Refresh before completing discharge.';

  @override
  String get dischargeBillingSectionTitle => 'Autorisation de facturation';

  @override
  String get dischargeNoInvoicesBody =>
      'Aucune facture définitive n\'est liée à cette admission.';

  @override
  String get dischargeBillingUnavailableBody =>
      'Billing records n\'a pas pu être loaded. Refresh before completing discharge.';

  @override
  String get dischargeNoRecordsTitle => 'No dossiers';

  @override
  String get dischargeTimelineSectionTitle => 'Calendrier d\'admission';

  @override
  String get dischargeNoTimelineTitle => 'Aucune activité de chronologie';

  @override
  String get dischargeNoTimelineBody =>
      'Les événements de la chronologie d’admission apparaîtront une fois l’activité enregistrée.';

  @override
  String get dischargeBackendGapsTitle => 'Flux de travail indisponibles';

  @override
  String get dischargeBackendGapsBody =>
      'Ces actions de flux de travail ne sont pas disponibles tant que la prise en charge du système n\'est pas activée pour cette fonctionnalité.';

  @override
  String get dischargeGapBackendSubtitle =>
      'Prise en charge du flux de travail indisponible';

  @override
  String get dischargeGapChecklistTitle =>
      'Liste de contrôle d\'autorisation persistante';

  @override
  String get dischargeGapChecklistBody =>
      'Les décisions individuelles concernant les médecins, les infirmières, les pharmacies, la facturation, les documents et les listes de contrôle de sortie ne sont pas encore disponibles dans ce flux de travail.';

  @override
  String get dischargeGapInsuranceTitle =>
      'Flux de travail de dédouanement d\'assurance';

  @override
  String get dischargeGapInsuranceBody =>
      'La validation d\'assurance n\'est pas encore connectée à ce flux de sortie.';

  @override
  String get dischargeGapDocumentsTitle => 'État du document prêt';

  @override
  String get dischargeGapDocumentsBody =>
      'Les documents de décharge peuvent être générés à partir du résumé. La préparation au transfert n’est pas encore disponible.';

  @override
  String get dischargeGapHousekeepingTitle => 'Housekeeping task passation';

  @override
  String get dischargeGapHousekeepingBody =>
      'La décharge finale libère le lit. Le transfert de maintenance n\'est pas disponible pour ce flux de travail.';

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
  String get dischargeDatePickerLabel => 'Choisissez une date';

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
  String get dischargeBillingAmountLabel => 'Montant';

  @override
  String get dischargeBillingAmountRequiredMessage =>
      'Enter le final billing montant.';

  @override
  String get dischargeBillingCurrencyLabel => 'Devise';

  @override
  String get dischargeBillingCurrencyRequiredMessage =>
      'Enter le billing devise.';

  @override
  String get dischargeRequestBillingSubmitAction => 'Create facture demande';

  @override
  String get dischargePharmacyDialogTitle => 'Médicaments de décharge';

  @override
  String get dischargePharmacyDialogBody =>
      'Send sortie medicines à pharmacie.';

  @override
  String get dischargeDrugFieldLabel => 'Médecine';

  @override
  String get dischargeDrugRequiredMessage => 'Select un medicine.';

  @override
  String get dischargePrescriptionFieldLabel => 'Ordonnance';

  @override
  String get dischargePrescriptionHelperText =>
      'State dose, duration, et any patient instructions.';

  @override
  String get dischargePrescriptionRequiredMessage =>
      'Enter le sortie ordonnance.';

  @override
  String get dischargeQuantityFieldLabel => 'Quantité';

  @override
  String get dischargeMedicationRouteLabel => 'Itinéraire';

  @override
  String get dischargeMedicationFrequencyLabel => 'Fréquence';

  @override
  String get dischargeMedicineInstructionsLabel => 'Consignes';

  @override
  String get dischargeRequestPharmacySubmitAction => 'Send à pharmacie';

  @override
  String get dischargeCompleteDialogTitle => 'Complete sortie';

  @override
  String get dischargeCompleteDialogBody =>
      'Confirmez la sortie du patient seulement une fois les vérifications cliniques, infirmières, pharmaceutiques, de facturation et de documents requises terminées.';

  @override
  String get dischargeCompletionBlockersTitle => 'Clearance still en attente';

  @override
  String get dischargeCompletionBlockersBody =>
      'Resolve en attente ou indisponible clearance éléments avant finalizing le admission.';

  @override
  String get dischargeCompleteConfirmLabel =>
      'Je confirme que le patient est sorti et que les documents ont été remis.';

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
    return '$age/$sex';
  }

  @override
  String get dischargeSavedMessage => 'Flux de travail de sortie mis à jour.';

  @override
  String get dischargeManageClearanceAction => 'Gérer le dédouanement';

  @override
  String get dischargeManageClearanceTitle => 'Autorisation de décharge';

  @override
  String get dischargeSaveClearanceAction => 'Enregistrer la liquidation';

  @override
  String get dischargePendingOrdersTitle => 'Pending clinique commandes';

  @override
  String get dischargePendingOrdersBody =>
      'Review laboratoire, radiologie, médicament, et soins infirmiers commandes avant finalizing sortie.';

  @override
  String get dischargeCrossModuleLinksTitle => 'Espaces de travail associés';

  @override
  String get dischargeCrossModuleLinksBody =>
      'Facturation ouverte, pharmacie, soins infirmiers, IPD ou entretien ménager avec ce contexte d\'admission.';

  @override
  String get dischargeOpenIpdAction => 'Ouvrir l\'IPD';

  @override
  String get dischargeOpenNursingAction => 'Soins infirmiers ouverts';

  @override
  String get dischargeOpenPharmacyAction => 'Pharmacie ouverte';

  @override
  String get dischargeOpenBillingAction => 'Ouvrir la facturation';

  @override
  String get dischargeOpenHousekeepingAction => 'Entretien ménager ouvert';

  @override
  String get dischargeReportTitle => 'Discharge résumé';

  @override
  String get dischargeReportPatientLabel => 'Patient';

  @override
  String get dischargeReportPatientNoLabel => 'Numéro de patient';

  @override
  String get dischargeReportAdmissionLabel => 'Admission';

  @override
  String get dischargeReportLocationLabel => 'Emplacement';

  @override
  String get dischargeReportGeneratedLabel => 'Généré';

  @override
  String get dischargeDoctorSignatureLabel => 'Signature du médecin';

  @override
  String get dischargeNurseSignatureLabel => 'Signature de l\'infirmière';

  @override
  String get dischargeReportFooter =>
      'Généré à partir des données du flux de travail de sortie.';

  @override
  String get dischargeLoadingTitle => 'Loading sortie espace de travail';

  @override
  String get dischargeLoadingBody => 'Loading sortie queue et référence data.';

  @override
  String get dischargeLoadErrorTitle =>
      'Discharge espace de travail indisponible';

  @override
  String get dischargeLoadErrorBody =>
      'La file d\'attente de déchargement n\'a pas pu être chargée. Actualisez pour réessayer.';

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
  String get radiologySavingStatus => 'Enregistrement';

  @override
  String get radiologySavedMessage =>
      'Flux de travail de radiologie mis à jour.';

  @override
  String get radiologyRequestImagingAction => 'Demander une imagerie';

  @override
  String get radiologyRefreshCatalogAction => 'Actualiser le catalogue';

  @override
  String get radiologyTotalOrdersSummaryLabel => 'Total commandes';

  @override
  String get radiologyWaitingImagingSummaryLabel => 'Imagerie en attente';

  @override
  String get radiologyReportingSummaryLabel => 'Rapports';

  @override
  String get radiologyReleasedSummaryLabel => 'Libéré';

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
  String get radiologyOrderDateFilterLabel => 'Date de commande';

  @override
  String get radiologyPickOrderDateAction => 'Pick commande date';

  @override
  String get radiologyStageFilterLabel => 'Étape';

  @override
  String get radiologyStatusFilterLabel => 'Statut';

  @override
  String get radiologyModalityFilterLabel => 'Modalité';

  @override
  String get radiologyClearFiltersAction => 'Clear filtres';

  @override
  String get radiologyWorklistTitle => 'Liste de travail d\'imagerie';

  @override
  String get radiologyWorklistDescription =>
      'Commandes d\'imagerie système avec flux de travail de modalité et état du rapport.';

  @override
  String get radiologyPreviousPageLabel => 'Previous commandes';

  @override
  String get radiologyNextPageLabel => 'Next commandes';

  @override
  String radiologyPageLabel(int from, int to, int total) {
    return 'Affichage de $from-$to sur $total';
  }

  @override
  String get radiologyNoOrdersTitle => 'No radiologie commandes';

  @override
  String get radiologyNoOrdersBody =>
      'Les commandes correspondant à cette recherche et à ce filtre apparaîtront ici.';

  @override
  String get radiologyPatientColumnLabel => 'Patient';

  @override
  String get radiologyOrderColumnLabel => 'Commande';

  @override
  String get radiologyStudyColumnLabel => 'Étude';

  @override
  String get radiologyPriorityColumnLabel => 'Priorité';

  @override
  String get radiologyPaymentAuthColumnLabel => 'Facturation';

  @override
  String get radiologyStatusColumnLabel => 'Statut';

  @override
  String get radiologyNextActionColumnLabel => 'Prochaine action';

  @override
  String get radiologyDetailTitle => 'Flux de travail de radiologie';

  @override
  String get radiologyDetailLoadingTitle => 'Loading commande';

  @override
  String get radiologyDetailLoadingBody =>
      'Chargement du flux de travail d\'imagerie sélectionné.';

  @override
  String get radiologyNoSelectionTitle => 'Select un commande';

  @override
  String get radiologyNoSelectionBody =>
      'Choose un imaging demande à voir study, rapport, et release détails.';

  @override
  String get radiologyPatientContextLabel =>
      'Contexte du patient en radiologie';

  @override
  String get radiologyBillingGateUnavailable => 'Billing gate indisponible';

  @override
  String get radiologyEncounterLabel => 'Rencontre';

  @override
  String get radiologyOrderedAtLabel => 'Ordonné';

  @override
  String get radiologyModalityLabel => 'Modalité';

  @override
  String get radiologyPaymentLabel => 'Paiement';

  @override
  String get radiologyAuthorizationLabel => 'Autorisation';

  @override
  String get radiologyAssignAction => 'Attribuer';

  @override
  String get radiologyStartImagingAction => 'Commencer l\'imagerie';

  @override
  String get radiologyStartDialogTitle => 'Start imaging commande';

  @override
  String get radiologyNotesLabel => 'Remarques';

  @override
  String get radiologyPerformStudyAction => 'Effectuer une étude';

  @override
  String get radiologyCancelOrderAction => 'Cancel commande';

  @override
  String get radiologyRequestDetailsTitle => 'Demander des détails';

  @override
  String get radiologyWorkflowSummaryTitle => 'Résumé du flux de travail';

  @override
  String get radiologyEditRequestDetailsAction => 'Edit demande détails';

  @override
  String get radiologyEditRequestDetailsDialogTitle => 'Edit demande détails';

  @override
  String get radiologySaveRequestDetailsAction => 'Save demande détails';

  @override
  String get radiologyStudyLabel => 'Étude';

  @override
  String get radiologyPriorityLabel => 'Priorité';

  @override
  String get radiologyBodyRegionLabel => 'Région du corps';

  @override
  String get radiologyLateralityLabel => 'Latéralité';

  @override
  String get radiologyClinicalNotesLabel => 'Notes cliniques';

  @override
  String get radiologyPriorityRoutineLabel => 'Routine';

  @override
  String get radiologyPriorityUrgentLabel => 'Urgent';

  @override
  String get radiologyPriorityStatLabel => 'STAT (immédiatement)';

  @override
  String get radiologyPriorityStatHint => 'Statim — effectuez immédiatement';

  @override
  String get radiologyLateralityLeft => 'GAUCHE';

  @override
  String get radiologyLateralityRight => 'DROITE';

  @override
  String get radiologyLateralityBilateral => 'BILATÉRAL';

  @override
  String get radiologyLateralityOblique => 'OBLIQUE';

  @override
  String get clinicalRadiologyBodyRegionPickerHint =>
      'Select un corps region à filtre le imaging catalog.';

  @override
  String get radiologyWorkflowProgressTitle => 'Progression du flux de travail';

  @override
  String get radiologyWorkflowStepReceive => 'Receive imaging demande';

  @override
  String get radiologyWorkflowStepReview => 'Review study détails';

  @override
  String get radiologyWorkflowStepPerform => 'Réaliser une étude d\'imagerie';

  @override
  String get radiologyWorkflowStepUpload => 'Upload study actifs';

  @override
  String get radiologyWorkflowStepReport => 'Enter findings et conclusions';

  @override
  String get radiologyWorkflowStepRelease => 'Finalize et release rapport';

  @override
  String get radiologyReportSectionTitle => 'Rapport';

  @override
  String get radiologyReportSectionBody =>
      'Draft, finalize, attest, et amend radiologie rapports avec clear findings, impression, narrative, et references.';

  @override
  String get radiologyDraftReportAction => 'Draft rapport';

  @override
  String get radiologyReleaseReportAction => 'Release rapport';

  @override
  String get radiologyRequestFinalizationAction => 'Finalisation de la demande';

  @override
  String get radiologyRequestFinalizationDialogTitle =>
      'Demander la finalisation du rapport';

  @override
  String get radiologyAttestFinalizationAction => 'Attestation de finalisation';

  @override
  String get radiologyAttestFinalizationDialogTitle =>
      'Attest rapport finalization';

  @override
  String get radiologyAddendumAction => 'Ajouter un addenda';

  @override
  String get radiologyPendingAttestationLabel => 'Attestation en attente';

  @override
  String get radiologyNoReportTitle => 'No rapport yet';

  @override
  String get radiologyNoReportBody =>
      'Une ébauche ou un rapport final apparaîtra après le début du rapport.';

  @override
  String get radiologyReportedAtLabel => 'Signalé';

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
  String get radiologyNoStudiesTitle => 'Aucune étude d\'imagerie';

  @override
  String get radiologyNoStudiesBody =>
      'Les études et les ressources apparaîtront une fois l’imagerie réalisée et enregistrée.';

  @override
  String get radiologySyncPacsAction => 'Synchroniser le PACS';

  @override
  String get radiologyAssetsLabel => 'Actifs';

  @override
  String get radiologyNoAssetsLabel => 'No actifs recorded';

  @override
  String get radiologyPacsLinksLabel => 'Liens PACS';

  @override
  String get radiologyNoPacsLinksLabel => 'Aucun lien PACS enregistré';

  @override
  String get radiologyDoctorReviewTitle => 'L’avis du docteur';

  @override
  String get radiologyDoctorReviewReleasedBody =>
      'Le rapport de radiologie final est prêt à être examiné par le clinicien ou le médecin demandeur.';

  @override
  String get radiologyDoctorReviewPendingBody =>
      'Aucun rapport radiologique final n’est encore disponible pour examen par le médecin.';

  @override
  String get radiologyDoctorReviewReadyLabel => 'Prêt pour l\'examen';

  @override
  String get radiologyDoctorReviewPendingLabel => 'En attente de publication';

  @override
  String get radiologyTimelineTitle => 'Chronologie du flux de travail';

  @override
  String get radiologyNoTimelineTitle => 'Aucun événement dans la chronologie';

  @override
  String get radiologyNoTimelineBody =>
      'Les événements du flux de travail apparaîtront au fur et à mesure de la progression de la commande.';

  @override
  String get radiologyBackendGapsTitle => 'Flux de travail indisponibles';

  @override
  String get radiologyBackendGapsBody =>
      'Ces contrôles ne sont pas disponibles tant que la prise en charge du système n\'est pas activée pour cette installation.';

  @override
  String get radiologyGapSchedulingTitle => 'Planification des salles';

  @override
  String get radiologyGapBackendSubtitle => 'Action indisponible';

  @override
  String get radiologyGapSchedulingBody =>
      'L’attribution de salle et de rendez-vous n’est pas disponible pour les commandes d’imagerie en cours.';

  @override
  String get radiologyGapBillingTitle => 'Autorisation de facturation';

  @override
  String get radiologyGapBillingBody =>
      'Payment et authorization statut appears lorsque disponible pour ce commande.';

  @override
  String get radiologyCreateOrderDialogTitle => 'Demander une imagerie';

  @override
  String get radiologyReferenceSearchLabel => 'Catalog recherche';

  @override
  String get radiologyReferenceSearchHint =>
      'Search test code, nom, modality, ou corps region';

  @override
  String get radiologySearchReferenceAction => 'Rechercher dans le catalogue';

  @override
  String get radiologyPatientLabel => 'Patient';

  @override
  String radiologyFieldRequiredLabel(String label) {
    return '${label}est requis.';
  }

  @override
  String get radiologyAssignDialogTitle => 'Assign imaging commande';

  @override
  String get radiologyAssigneeLabel => 'Cessionnaire';

  @override
  String get radiologyPerformStudyDialogTitle =>
      'Réaliser une étude d\'imagerie';

  @override
  String get radiologyPerformedAtLabel => 'Effectué à';

  @override
  String get radiologyDateTimeHint => 'AAAA-MM-JJ HH:MM';

  @override
  String get radiologyReportDialogTitle => 'Draft radiologie rapport';

  @override
  String get radiologyFindingsLabel => 'Résultats';

  @override
  String get radiologyImpressionLabel => 'Impression / Conclusion';

  @override
  String get radiologyReportTextLabel => 'Description du rapport';

  @override
  String get radiologyReportTextHelper =>
      'Leave blank à combine findings et impression.';

  @override
  String get radiologyReleaseReportDialogTitle => 'Release rapport';

  @override
  String get radiologyReleaseNotesLabel => 'Notes de version';

  @override
  String get radiologyFinalizationStatementLabel =>
      'Déclaration de finalisation';

  @override
  String get radiologyFinalizationReasonLabel => 'Raison';

  @override
  String get radiologyAddendumDialogTitle => 'Add rapport addendum';

  @override
  String get radiologyAddendumTextLabel => 'Texte de l\'addendum';

  @override
  String get radiologyCancelDialogTitle => 'Cancel radiologie commande';

  @override
  String get radiologyCancellationReasonLabel => 'Motif d\'annulation';

  @override
  String get radiologyPacsSyncDialogTitle => 'Sync study à PACS';

  @override
  String get radiologyStudyUidLabel => 'UID de l’étude';

  @override
  String get radiologyStageAll => 'Tous';

  @override
  String get radiologyStageOrdered => 'Ordonné';

  @override
  String get radiologyStageProcessing => 'Traitement';

  @override
  String get radiologyStageReporting => 'Rapports';

  @override
  String get radiologyStageCompleted => 'Terminé';

  @override
  String get radiologyStageCancelled => 'Annulé';

  @override
  String get radiologyStatusOrdered => 'Ordonné';

  @override
  String get radiologyStatusInProcess => 'En cours';

  @override
  String get radiologyStatusCompleted => 'Terminé';

  @override
  String get radiologyStatusCancelled => 'Annulé';

  @override
  String get radiologyResultDraft => 'Projet';

  @override
  String get radiologyResultFinal => 'Étape finale';

  @override
  String get radiologyResultAmended => 'Modifié';

  @override
  String get radiologyModalityXray => 'RADIOGRAPHIE';

  @override
  String get radiologyModalityCt => 'CT';

  @override
  String get radiologyModalityMri => 'IRM';

  @override
  String get radiologyModalityUltrasound => 'ULTRASON';

  @override
  String get radiologyModalityPet => 'ANIMAL DE COMPAGNIE';

  @override
  String get radiologyModalityEcg => 'ECG';

  @override
  String get radiologyModalityEcho => 'ÉCHO';

  @override
  String get radiologyModalityEndo => 'ENDO';

  @override
  String get radiologyModalityGastro => 'GASTRO';

  @override
  String get radiologyModalityOther => 'Autre';

  @override
  String get radiologyNextActionConfirmBilling => 'Confirmer la facturation';

  @override
  String get radiologyNextActionStartImaging => 'Commencer l\'imagerie';

  @override
  String get radiologyNextActionPerformStudy => 'Effectuer une étude';

  @override
  String get radiologyNextActionReleaseReport => 'Release rapport';

  @override
  String get radiologyNextActionDoctorReview => 'L’avis du docteur';

  @override
  String get radiologyNextActionReportPending => 'Report en attente';

  @override
  String get navigationPharmacyLabel => 'Pharmacie';

  @override
  String get navigationPharmacyShortLabel => 'Pharmacie';

  @override
  String get navigationLabLabel => 'Laboratoire';

  @override
  String get navigationLabShortLabel => 'Laboratoire';

  @override
  String get navigationRadiologyLabel => 'Radiologie';

  @override
  String get navigationRadiologyShortLabel => 'Imagerie';

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
  String get pharmacyStatusSaving => 'Enregistrement';

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
  String get pharmacySummaryReadyLabel => 'Prêt';

  @override
  String get pharmacySummaryPartialLabel => 'Partiel';

  @override
  String get pharmacySummaryAttestationLabel => 'En attente d\'attestation';

  @override
  String get pharmacySummaryCompletedLabel => 'Terminé';

  @override
  String get pharmacyQueuePanelTitle => 'File d\'attente des commandes';

  @override
  String get pharmacyQueuePanelDescription =>
      'System pharmacie commandes avec dispense et return actions.';

  @override
  String get pharmacyNoOrdersTitle => 'No pharmacie commandes';

  @override
  String get pharmacyNoOrdersBody =>
      'Les commandes correspondant à cette recherche et à ce filtre apparaîtront ici.';

  @override
  String get pharmacyPatientColumnLabel => 'Patient';

  @override
  String get pharmacyOrderColumnLabel => 'Commande';

  @override
  String get pharmacyItemsColumnLabel => 'Articles';

  @override
  String get pharmacyDispenseColumnLabel => 'Dispenser';

  @override
  String get pharmacyStatusColumnLabel => 'Statut';

  @override
  String get pharmacyPendingBatchLabel => 'Lot en attente';

  @override
  String get pharmacyDetailLoadingTitle => 'Loading ordonnance';

  @override
  String get pharmacyDetailLoadingBody =>
      'Chargement de médicaments, historique de distribution et actions de flux de travail.';

  @override
  String get pharmacyPrescriptionDetailTitle => 'Détail de la prescription';

  @override
  String get pharmacyNoSelectionTitle => 'No ordonnance selected';

  @override
  String get pharmacyNoSelectionBody =>
      'Select un commande à review medicines, stock mapping, billing gate visibility, et dispense historique.';

  @override
  String get pharmacyBillingGateUnavailableTitle =>
      'Payment clearance indisponible';

  @override
  String get pharmacyOrderFieldLabel => 'Commande';

  @override
  String get pharmacyEncounterFieldLabel => 'Rencontre';

  @override
  String get pharmacySourceFieldLabel => 'Source';

  @override
  String get pharmacyOrderedFieldLabel => 'Ordonné';

  @override
  String get pharmacyActionsPanelTitle => 'Actes';

  @override
  String get pharmacyDispenseAction => 'Dispenser';

  @override
  String get pharmacyPrepareDispenseAction => 'Préparer la distribution';

  @override
  String get pharmacyAttestAction => 'Attester';

  @override
  String get pharmacyReturnAction => 'Retour';

  @override
  String get pharmacyCancelOrderAction => 'Cancel commande';

  @override
  String get pharmacyPrintInstructionsAction => 'Imprimer les instructions';

  @override
  String get pharmacyMedicationPanelTitle => 'Médicaments';

  @override
  String get pharmacyMedicationPanelDescription =>
      'Drug, dose, route, frequency, duration, quantity, instructions, et dispense state.';

  @override
  String get pharmacyNoMedicationTitle => 'Pas de médicaments';

  @override
  String get pharmacyNoMedicationBody =>
      'Cette commande n\'a aucun médicament disponible dans le flux pharmacie.';

  @override
  String get pharmacyMedicationColumnLabel => 'Médicament';

  @override
  String get pharmacyDoseColumnLabel => 'Dose';

  @override
  String get pharmacyQuantityColumnLabel => 'Quantité';

  @override
  String get pharmacyStockColumnLabel => 'Action';

  @override
  String get pharmacyBackendGapsTitle =>
      'Préparation du flux de travail en pharmacie';

  @override
  String get pharmacyBackendGapsBody =>
      'Cette commande utilise l’état actuel du flux de travail de la pharmacie pour déterminer les actions sûres.';

  @override
  String get pharmacyGapPaymentAuthorization =>
      'Le paiement et l\'autorisation sont vérifiés avant que les actions de distribution ne soient activées.';

  @override
  String get pharmacyGapBatchAvailability =>
      'La cartographie des stocks est vérifiée avant que les actions de distribution ne soient activées.';

  @override
  String get pharmacyGapHoldSubstitution =>
      'Hold et substitution decisions follow le actuel pharmacie commande statut.';

  @override
  String get pharmacyGapReportTemplates =>
      'Les impressions de médicaments utilisent le flux de travail d\'impression configuré.';

  @override
  String get pharmacyTimelinePanelTitle => 'Dispense historique';

  @override
  String get pharmacyTimelinePanelDescription =>
      'Commandez, préparez, attestez, distribuez et renvoyez les événements à partir du flux de travail.';

  @override
  String get pharmacyNoTimelineBody =>
      'Aucun historique de distribution n’est encore disponible.';

  @override
  String get pharmacyDrugPanelTitle => 'Formulary et stock';

  @override
  String get pharmacyDrugPanelDescription =>
      'Search configured drugs et review aggregate stock visibility.';

  @override
  String get pharmacyDrugFiltersSemanticLabel => 'Drug stock filtres';

  @override
  String get pharmacyDrugSearchLabel => 'Rechercher des médicaments';

  @override
  String get pharmacyDrugSearchHint => 'Search drug, code, form, ou strength';

  @override
  String get pharmacyStockStatusFilterLabel => 'Stock statut';

  @override
  String get pharmacyNoDrugsTitle => 'Aucun drugs trouvé';

  @override
  String get pharmacyNoDrugsBody =>
      'Les médicaments du formulaire et les lignes de stock correspondants apparaîtront ici.';

  @override
  String get pharmacyDrugColumnLabel => 'Médicament';

  @override
  String get pharmacyAvailableColumnLabel => 'Disponible';

  @override
  String get pharmacyStockStatusColumnLabel => 'Stock statut';

  @override
  String pharmacyAvailableQuantityLabel(String quantity) {
    return '${quantity}disponible';
  }

  @override
  String get pharmacyDispenseDialogTitle => 'Préparer la distribution';

  @override
  String get pharmacyAttestDialogTitle => 'Attestation de distribution';

  @override
  String get pharmacyAttestDialogBody =>
      'Confirm le prepared batch après physical médicament passation.';

  @override
  String get pharmacyReturnDialogTitle => 'Retourner les médicaments';

  @override
  String get pharmacyReturnDialogBody =>
      'Enregistrez les quantités retournées afin que le statut de la commande et le stock soient synchronisés.';

  @override
  String get pharmacyCancelDialogTitle => 'Cancel pharmacie commande';

  @override
  String get pharmacyCancelDialogBody =>
      'Annulez uniquement lorsque la commande ne doit plus être distribuée.';

  @override
  String get pharmacyBillingGateUnavailableBody =>
      'L\'autorisation de paiement n\'est pas disponible pour cette commande.';

  @override
  String get pharmacyPaymentColumnLabel => 'Paiement';

  @override
  String get pharmacyPaymentLabel => 'Paiement';

  @override
  String get pharmacyPaymentAmountLabel => 'Montant dû';

  @override
  String get pharmacyRecordPaymentAction => 'Record paiement';

  @override
  String get pharmacyNextActionConfirmBilling => 'Confirmer la facturation';

  @override
  String get pharmacyDispenseBlockedPaymentBody =>
      'Collect ou confirmer paiement avant dispensing ce commande.';

  @override
  String get pharmacyPriorityFieldLabel => 'Priorité';

  @override
  String get pharmacyCatalogTabDrugs => 'Drogues';

  @override
  String get pharmacyCatalogTabFormulary => 'Formulaire';

  @override
  String get pharmacyCatalogTabInventory => 'Inventaire';

  @override
  String get pharmacyCatalogPanelTitle => 'Catalog et stock';

  @override
  String get pharmacyAddDrugAction => 'Ajouter un médicament';

  @override
  String get pharmacyEditDrugAction => 'Modifier le médicament';

  @override
  String get pharmacyDeleteDrugAction => 'Supprimer le médicament';

  @override
  String get pharmacyDrugNameLabel => 'Drug nom';

  @override
  String get pharmacyDrugCodeLabel => 'Code du médicament';

  @override
  String get pharmacyDrugFormLabel => 'Formulaire';

  @override
  String get pharmacyDrugStrengthLabel => 'Force';

  @override
  String get pharmacyAddFormularyAction => 'Add formulary élément';

  @override
  String get pharmacyFormularyDrugLabel => 'Médicament';

  @override
  String get pharmacyFormularyActiveLabel => 'Actif';

  @override
  String get pharmacyNoFormularyTitle => 'No formulary éléments';

  @override
  String get pharmacyNoFormularyBody =>
      'Les entrées du formulaire reliant les médicaments à la prescription apparaîtront ici.';

  @override
  String get pharmacyInventoryPanelTitle => 'Stock d\'inventaire';

  @override
  String get pharmacyInventoryPanelDescription =>
      'Review on-hand quantities et post controlled adjustments.';

  @override
  String get pharmacyNoInventoryTitle => 'No inventaire lignes';

  @override
  String get pharmacyNoInventoryBody =>
      'Les lignes de stock correspondantes apparaîtront ici.';

  @override
  String get pharmacyInventoryQuantityColumnLabel => 'À portée de main';

  @override
  String get pharmacyInventoryFacilityColumnLabel => 'Établissement';

  @override
  String get pharmacyAdjustStockAction => 'Ajuster le stock';

  @override
  String get pharmacyAdjustStockDialogTitle => 'Adjust inventaire';

  @override
  String get pharmacyQuantityDeltaLabel => 'Changement de quantité';

  @override
  String get pharmacyStockReasonLabel => 'Raison';

  @override
  String get pharmacyLowStockOnlyFilterLabel => 'Stock faible uniquement';

  @override
  String get pharmacyDeleteDrugDialogTitle => 'Supprimer le médicament';

  @override
  String get pharmacyDeleteDrugDialogBody => 'Remove ce drug de le catalog?';

  @override
  String get pharmacyDispenseDialogBody =>
      'Enter dispense quantities et facultatif stock mapping pour each medicine line.';

  @override
  String get pharmacyBatchRefLabel => 'Batch référence';

  @override
  String get pharmacyStatementLabel => 'Déclaration';

  @override
  String get pharmacyReasonLabel => 'Raison';

  @override
  String get pharmacyNotesLabel => 'Remarques';

  @override
  String get pharmacyQuantityFieldLabel => 'Quantité';

  @override
  String get pharmacyInventoryItemLabel => 'Inventory élément';

  @override
  String pharmacyQuantityValidationLabel(String maximum) {
    return 'Enter un quantity de 0 à$maximum.';
  }

  @override
  String get pharmacySavedMessage => 'Flux de travail en pharmacie mis à jour.';

  @override
  String get pharmacyFilterAll => 'All commandes';

  @override
  String get pharmacyFilterReady => 'Prêt';

  @override
  String get pharmacyFilterPartial => 'Partiel';

  @override
  String get pharmacyFilterCompleted => 'Terminé';

  @override
  String get pharmacyFilterCancelled => 'Annulé';

  @override
  String get pharmacyFilterPendingPayment => 'Pending paiement';

  @override
  String get pharmacyFilterPartialStock => 'Stock partiel';

  @override
  String get pharmacyFilterUrgent => 'Urgent';

  @override
  String get pharmacyFilterDischarge => 'Médicaments de décharge';

  @override
  String get pharmacyFilterOutpatient => 'Ambulatoire';

  @override
  String get pharmacyFilterWard => 'Service';

  @override
  String get pharmacyLocationFieldLabel => 'Lieu de soins';

  @override
  String get pharmacyStockInStock => 'En stock';

  @override
  String get pharmacyStockAlmostOut => 'Presque sorti';

  @override
  String get pharmacyStockLow => 'Stock faible';

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
  String get pharmacyTimelineOrderPlaced => 'Commande passée';

  @override
  String pharmacyDispenseProgressLabel(String dispensed, String prescribed) {
    return '$dispensed/$prescribed';
  }

  @override
  String get pharmacyReportTitle => 'Instructions pour les médicaments';

  @override
  String get pharmacyReportPatientLabel => 'Patient';

  @override
  String get pharmacyReportOrderLabel => 'Commande';

  @override
  String get pharmacyReportGeneratedLabel => 'Généré';

  @override
  String get pharmacyReportFooter =>
      'Généré à partir des données de flux de travail de la pharmacie.';

  @override
  String get navigationClaimsLabel => 'Insurance réclamations';

  @override
  String get navigationClaimsShortLabel => 'Réclamations';

  @override
  String get claimsWorkspaceTitle => 'Insurance et réclamations';

  @override
  String get claimsWorkspaceDescription =>
      'Manage authorizations, payer responses, réclamation submission, resubmission, et facture follow-up.';

  @override
  String get claimsOperationalStatusLabel => 'Facturation synchronisée';

  @override
  String get claimsNeedsAttentionStatusLabel => 'A besoin d\'attention';

  @override
  String get claimsLoadingTitle => 'Loading réclamations';

  @override
  String get claimsLoadingBody =>
      'Fetching authorization et réclamation queues.';

  @override
  String get claimsLoadErrorTitle => 'Claims indisponible';

  @override
  String get claimsLoadErrorBody =>
      'L\'espace de travail des revendications n\'a pas pu être chargé.';

  @override
  String get claimsRequestAuthorizationAction => 'Demander une autorisation';

  @override
  String get claimsPrepareClaimAction => 'Prepare réclamation';

  @override
  String get claimsAuthorizationPendingSummaryLabel => 'Auth en attente';

  @override
  String get claimsAuthorizationApprovedSummaryLabel => 'Auth approuvé';

  @override
  String get claimsSubmittedSummaryLabel => 'Soumis';

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
  String get claimsQueueFilterLabel => 'File d’attente';

  @override
  String get claimsWorklistTitle => 'Liste de travail pour les réclamations';

  @override
  String get claimsWorklistDescription =>
      'Review pre-authorizations et réclamation dossiers backed by billing data.';

  @override
  String get claimsPreviousPageLabel => 'Previous réclamations page';

  @override
  String get claimsNextPageLabel => 'Next réclamations page';

  @override
  String claimsPageLabel(int start, int end, int total) {
    return '${start}J${end}sur$total';
  }

  @override
  String get claimsEmptyQueueTitle => 'Aucun claims trouvé';

  @override
  String get claimsEmptyQueueBody =>
      'No authorization ou réclamation dossiers match le actuel queue.';

  @override
  String get claimsTypeColumnLabel => 'Taper';

  @override
  String get claimsReferenceColumnLabel => 'Référence';

  @override
  String get claimsCoverageColumnLabel => 'Couverture';

  @override
  String get claimsInvoiceColumnLabel => 'Facture';

  @override
  String get claimsStatusColumnLabel => 'Statut';

  @override
  String get claimsTimelineColumnLabel => 'Mis à jour';

  @override
  String claimsMobileQueueSubtitle(String coverage, String link) {
    return 'Coverage$coverage| Link$link';
  }

  @override
  String get claimsDetailTitle => 'Détails de la réclamation';

  @override
  String get claimsDetailLoadingTitle => 'Chargement des détails';

  @override
  String get claimsDetailLoadingBody =>
      'Fetching payer, facture, et coverage context.';

  @override
  String get claimsNoSelectionTitle => 'Select un dossier';

  @override
  String get claimsNoSelectionBody =>
      'Choose un ligne à review coverage, billing impact, et suivant actions.';

  @override
  String get claimsPrintStatementAction => 'Imprimer le relevé';

  @override
  String get claimsPatientContextLabel => 'Claim patient et coverage context';

  @override
  String get claimsCoverageFieldLabel => 'Couverture';

  @override
  String get claimsPayerFieldLabel => 'Payeur ';

  @override
  String get claimsUnknownPayerLabel => 'Payeur non enregistré';

  @override
  String get claimsInvoiceFieldLabel => 'Facture';

  @override
  String get claimsAmountFieldLabel => 'Montant';

  @override
  String get claimsBillingImpactTitle => 'Impact sur la facturation';

  @override
  String get claimsAuthorizationBillingImpactBody =>
      'L\'autorisation de service doit attendre la réponse du payeur lorsqu\'une autorisation est requise.';

  @override
  String get claimsCoveragePercentLabel => 'Couverture';

  @override
  String claimsCoveragePercentValue(String percent) {
    return '$percent %';
  }

  @override
  String get claimsInvoiceStatusLabel => 'Invoice statut';

  @override
  String get claimsPatientBalanceLabel => 'Solde des patients';

  @override
  String get claimsBillingInvoiceUnavailableBody =>
      'Les détails de la facture ne sont pas disponibles, le solde du patient ne peut donc pas être confirmé ici.';

  @override
  String get claimsBillingAuthorizedBody =>
      'Authorized by payer. Confirm any uncovered balance avant final clearance.';

  @override
  String get claimsBillingPaidBody =>
      'La réclamation est payée ou fermée. La facturation peut utiliser le dernier statut de la facture pour le suivi.';

  @override
  String get claimsBillingRejectedBody =>
      'Rejeté par le payeur. Le personnel de facturation doit préparer une nouvelle soumission ou un suivi du solde du patient.';

  @override
  String get claimsBillingPendingBody =>
      'En attente de réponse du payeur. Gardez l\'autorisation de facturation visible jusqu\'à ce que la réponse soit enregistrée.';

  @override
  String get claimsBillingNeutralBody =>
      'Review facture et payer state avant clearing le service.';

  @override
  String get claimsRequiredDocumentsTitle => 'Documents requis';

  @override
  String get claimsRequiredDocumentsBody =>
      'L’état de préparation des documents est indiqué à partir des données disponibles sur les réclamations, les factures et les couvertures.';

  @override
  String get claimsDocumentInvoiceSummary => 'Invoice résumé';

  @override
  String get claimsDocumentCoveragePlan => 'Coverage forfait';

  @override
  String get claimsDocumentPayerResponse => 'Payer réponse';

  @override
  String get claimsTimelineTitle => 'Activité';

  @override
  String get claimsTimelineDescription =>
      'Horodatages d’autorisation, de soumission et de réponse du flux de travail des réclamations.';

  @override
  String get claimsTimelineAuthorizationRequested => 'Autorisation demandée';

  @override
  String get claimsTimelineAuthorizationResponded => 'Autorisation répondue';

  @override
  String get claimsTimelineClaimSubmitted => 'Réclamation soumise';

  @override
  String get claimsTimelineCurrentStatus => 'Current statut';

  @override
  String get claimsBackendGapTitle => 'Flux de travail indisponibles';

  @override
  String get claimsBackendGapDescription =>
      'Ces éléments sont indisponibles dans le flux de réclamations actuel.';

  @override
  String get claimsBackendGapDraftTitle => 'Claim brouillon queue';

  @override
  String get claimsBackendGapDraftBody =>
      'La file d\'attente des brouillons n\'est pas disponible dans le flux de réclamations actuel.';

  @override
  String get claimsBackendGapDocumentsTitle => 'Document upload et demandes';

  @override
  String get claimsBackendGapDocumentsBody =>
      'Le suivi des documents requis n’est pas encore disponible.';

  @override
  String get claimsBackendGapReportsTitle => 'Packs payeurs générés';

  @override
  String get claimsBackendGapReportsBody =>
      'Les packs de payeurs imprimables ne sont pas disponibles tant que les modèles de rapport ne sont pas activés.';

  @override
  String get claimsCoveragePlanFieldLabel => 'Coverage forfait';

  @override
  String get claimsCoveragePlanHint => 'Sélectionnez la couverture du payeur';

  @override
  String get claimsCoveragePlanRequiredMessage => 'Select un coverage forfait.';

  @override
  String get claimsCoverageUnavailableTitle => 'Coverage forfaits indisponible';

  @override
  String get claimsCoverageUnavailableBody =>
      'Les plans de couverture n\'ont pas pu être chargés, l\'autorisation ne peut donc pas encore être demandée.';

  @override
  String get claimsRequestAuthorizationSubmitAction =>
      'Demander une autorisation';

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
  String get claimsNotesFieldLabel => 'Remarques';

  @override
  String get claimsSubmitClaimSubmitAction => 'Submit réclamation';

  @override
  String get claimsClaimResponseFieldLabel => 'Payer réponse';

  @override
  String get claimsSavedMessage => 'Claims espace de travail mis à jour.';

  @override
  String get claimsRequestAuthorizationDialogTitle =>
      'Demander une préautorisation';

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
  String get claimsCloseClaimSubmitAction => 'Fermer comme payé';

  @override
  String get claimsUpdateStatusAction => 'Update statut';

  @override
  String get claimsSubmitClaimAction => 'Submit réclamation';

  @override
  String get claimsResubmitClaimAction => 'Resubmit réclamation';

  @override
  String get claimsRecordResponseAction => 'Record réponse';

  @override
  String get claimsCloseClaimAction => 'Fermer comme payé';

  @override
  String get claimsInsuranceAuthorizationTitle => 'Autorisation d\'assurance';

  @override
  String get claimsInsuranceAuthorizationEmpty =>
      'Aucune autorisation au dossier. Demandez une préautorisation avant les commandes coûteuses ou l’admission facultative.';

  @override
  String get claimsApprovedAmountLabel => 'Approuvé';

  @override
  String get claimsConsumedAmountLabel => 'Consommé';

  @override
  String get claimsRemainingAmountLabel => 'Restant';

  @override
  String get claimsAuthorizationReasonLabel => 'Raison';

  @override
  String get claimsCoveragePlansUnavailable =>
      'Les plans de couverture ne sont pas disponibles. Vérifiez la configuration de l’assurance avant de continuer.';

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
  String get billingPreAuthApproveAction => 'Approuver l\'autorisation';

  @override
  String get billingPreAuthDenyAction => 'Refuser l\'autorisation';

  @override
  String get billingPreAuthApprovedAmountLabel => 'Approved montant';

  @override
  String get billingPreAuthConsumedAmountLabel => 'Consumed montant';

  @override
  String get claimsFilterAll => 'Toutes les files d\'attente';

  @override
  String get claimsFilterAuthorizationPending => 'Authorization en attente';

  @override
  String get claimsFilterAuthorizationApproved => 'Authorization approuvé';

  @override
  String get claimsFilterAuthorizationDenied => 'Autorisation refusée';

  @override
  String get claimsFilterAuthorizationExpired => 'Authorization expiré';

  @override
  String get claimsFilterClaimSubmitted => 'Réclamation soumise';

  @override
  String get claimsFilterClaimApproved => 'Claim approuvé';

  @override
  String get claimsFilterClaimRejected => 'Claim rejeté';

  @override
  String get claimsFilterClaimPaid => 'Réclamation payée';

  @override
  String get claimsFilterClaimCancelled => 'Claim annulé';

  @override
  String get claimsStatusPending => 'En attente';

  @override
  String get claimsStatusApproved => 'Approuvé';

  @override
  String get claimsStatusDenied => 'Refusé';

  @override
  String get claimsStatusExpired => 'Expiré';

  @override
  String get claimsStatusSubmitted => 'Soumis';

  @override
  String get claimsStatusRejected => 'Rejeté';

  @override
  String get claimsStatusPaid => 'Payant';

  @override
  String get claimsStatusCancelled => 'Annulé';

  @override
  String get claimsAuthorizationTypeLabel => 'Autorisation';

  @override
  String get claimsClaimTypeLabel => 'Réclamer';

  @override
  String get claimsAuthorizationTitle => 'Autorisation de couverture';

  @override
  String get claimsClaimPatientTitle => 'Réclamation patient';

  @override
  String get claimsAuthorizationSubtitle => 'Payer coverage demande';

  @override
  String claimsClaimSubtitle(String claimId) {
    return 'Claim$claimId';
  }

  @override
  String get claimsAuthorizationStatementTitle =>
      'Déclaration de préautorisation';

  @override
  String get claimsClaimStatementTitle => 'Déclaration de réclamation';

  @override
  String get claimsReportGeneratedLabel => 'Généré';

  @override
  String get claimsReportFooter => 'Generated de réclamations et billing data.';

  @override
  String get labTitle => 'Laboratoire';

  @override
  String get labDescription =>
      'Manage laboratoire demandes, résultat entry, backend interpretation, vérification, référence ranges, rapports, et clinician passation.';

  @override
  String get labLoadingTitle => 'Chargement du laboratoire';

  @override
  String get labLoadingBody =>
      'Loading laboratoire queues, catalog configuration, résultats, et QC logs.';

  @override
  String get labLiveStatus => 'Live synchronisation';

  @override
  String get labSavingStatus => 'Enregistrement';

  @override
  String get labSavedMessage => 'Flux de travail du laboratoire mis à jour.';

  @override
  String get labRequestOrderAction => 'Demander un laboratoire';

  @override
  String get labRecordQcAction => 'Enregistrer le CQ';

  @override
  String get labTotalOrdersSummaryLabel => 'Total commandes';

  @override
  String get labWaitingSampleSummaryLabel => 'Awaiting résultats';

  @override
  String get labProcessingSummaryLabel => 'Traitement';

  @override
  String get labResultPendingSummaryLabel => 'Pending vérification';

  @override
  String get labCriticalSummaryLabel => 'Critique';

  @override
  String get labCompletedSummaryLabel => 'Vérifié';

  @override
  String get labFiltersLabel => 'Laboratory filtres';

  @override
  String get labSearchLabel => 'Recherche laboratoire';

  @override
  String get labSearchHint => 'Search patient, commande, test, ou consultation';

  @override
  String get labScopeFilterLabel => 'File d’attente';

  @override
  String get labScopeAll => 'Tous';

  @override
  String get labScopeCollection => 'Awaiting résultats';

  @override
  String get labScopeProcessing => 'Traitement';

  @override
  String get labScopeResults => 'Pending vérification';

  @override
  String get labScopeCritical => 'Critique';

  @override
  String get labScopeCompleted => 'Vérifié';

  @override
  String get labScopeCancelled => 'Annulé';

  @override
  String get labWorklistTitle => 'File d\'attente du laboratoire';

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
  String get labOrderColumnLabel => 'Commande';

  @override
  String get labTestsColumnLabel => 'Essais';

  @override
  String get labSampleColumnLabel => 'Entry statut';

  @override
  String get labResultColumnLabel => 'Résultat';

  @override
  String get labNextActionColumnLabel => 'Prochaine action';

  @override
  String labPageLabel(int from, int to, int total) {
    return '$from-$to sur $total';
  }

  @override
  String get labPreviousPageLabel => 'Previous laboratoire page';

  @override
  String get labNextPageLabel => 'Next laboratoire page';

  @override
  String get labDetailTitle => 'Détail du laboratoire';

  @override
  String get labDetailLoadingTitle => 'Loading laboratoire detail';

  @override
  String get labDetailLoadingBody =>
      'Loading commande détails, ordered tests, résultats, timeline, et disponible actions.';

  @override
  String get labResultEntryDialogTitle => 'Lab résultat entry';

  @override
  String labResultEntryDialogSubtitle(String patientName, String orderId) {
    return '$patientName· Order$orderId';
  }

  @override
  String get labSaveDraftAction => 'Save brouillon';

  @override
  String get labSubmitResultsAction => 'Submit résultats';

  @override
  String get labDraftSavedMessage => 'Draft résultats saved.';

  @override
  String labBatchPartialSaveMessage(int savedCount, int skippedCount) {
    return 'Saved${savedCount}résultats.${skippedCount}entries need attention.';
  }

  @override
  String labBatchPartialSubmitMessage(int savedCount, int skippedCount) {
    return 'Submitted${savedCount}résultats.${skippedCount}entries need attention.';
  }

  @override
  String labBatchPartialVerifyMessage(int savedCount, int skippedCount) {
    return 'Verified${savedCount}résultats.${skippedCount}entries need attention.';
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
          '$count tests sélectionnés nécessitent une attention avant de poursuivre cette action.',
      one:
          '1 test sélectionné nécessite une attention avant de poursuivre cette action.',
    );
    return '$_temp0';
  }

  @override
  String get labBatchValidationSummaryHint =>
      'Check le highlighted tests below et complete any missing ou invalide valeurs.';

  @override
  String labBatchActionFailedMessage(String actionLabel) {
    return '${actionLabel}n\'un pas pu be terminé.';
  }

  @override
  String labBatchActionValidationMessage(String actionLabel) {
    return '${actionLabel}n\'un pas pu run because some selected tests still need attention.';
  }

  @override
  String labBatchActionFailedDetailMessage(String actionLabel, String detail) {
    return '$actionLabeléchoué:$detail';
  }

  @override
  String get labBatchInvalidTransitionMessage =>
      'Some selected tests ne peut pas be vérifié yet. Enter et soumettre résultats pour le highlighted tests first, ou retirer rejeté tests de le selection.';

  @override
  String get labBatchItemNotFoundMessage =>
      'Un ou plusieurs tests sélectionnés ne sont plus disponibles. Actualisez la commande et réessayez.';

  @override
  String get labBatchOrderNotSelectedMessage =>
      'L\'ordre de laboratoire est introuvable. Fermez cette boîte de dialogue, rouvrez la commande et réessayez.';

  @override
  String get labApplyingResultChangesMessage => 'Updating résultats…';

  @override
  String get labResultLifecycleDraft => 'Projet';

  @override
  String get labResultLifecycleSubmitted => 'Soumis';

  @override
  String get labResultLifecycleBlank => 'Non saisi';

  @override
  String get labWorkflowCurrentStepLabel => 'Étape actuelle';

  @override
  String get labWorkflowNextStepLabel => 'Étape suivante';

  @override
  String get labWorkflowStepOrdered => 'Ordonné';

  @override
  String get labWorkflowStepInProcess => 'En cours';

  @override
  String get labWorkflowStepResultsEntered => 'Résultats saisis';

  @override
  String get labWorkflowStepVerified => 'Vérifié';

  @override
  String get labWorkflowNextCollectSample => 'Prélever échantillon';

  @override
  String get labWorkflowNextReceiveSample => 'Recevoir un échantillon';

  @override
  String get labWorkflowNextEnterResults => 'Enter résultats';

  @override
  String get labWorkflowNextVerifyResults => 'Verify résultats';

  @override
  String get labWorkflowNextReviewItems => 'Review en attente éléments';

  @override
  String get labReferenceRangeOverrideLabel =>
      'Remplacement de la plage de référence';

  @override
  String get labInterpretationOverrideLabel => 'Interprétation manuelle';

  @override
  String get labResultFlagOverrideLabel =>
      'Remplacement de l\'indicateur de résultat';

  @override
  String clinicalLabResultReadyNotice(String patientName) {
    return 'Les résultats du laboratoire sont prêts$patientName.';
  }

  @override
  String clinicalLabResultUpdatedNotice(String patientName) {
    return 'Lab résultats mis à jour pour$patientName.';
  }

  @override
  String clinicalLabResultCriticalNotice(String patientName) {
    return 'Critical laboratoire résultat pour${patientName}needs review.';
  }

  @override
  String get labOrderFavoriteTestsLabel => 'Frequently utilisé tests';

  @override
  String get labBulkResultActionsTitle => 'Actions groupées';

  @override
  String get labSubmitResultAction => 'Submit résultat';

  @override
  String get labResultsSubmittedMessage => 'Résultats soumis.';

  @override
  String get labResultsVerifiedMessage => 'Results vérifié.';

  @override
  String get labSelectAllTestsAction => 'Select tous';

  @override
  String get labClearSelectionAction => 'Effacer la sélection';

  @override
  String labSelectedTestCount(int selected, int total) {
    return '${selected}sur${total}selected';
  }

  @override
  String get labRejectAllTestsAction => 'Reject tous tests';

  @override
  String get labRemoveAllDraftsAction => 'Supprimer les brouillons';

  @override
  String get labSaveAllDraftsAction => 'Save tous drafts';

  @override
  String get labSubmitAllResultsAction => 'Submit tous';

  @override
  String get labRemoveAllDraftsDialogTitle => 'Remove brouillon résultats?';

  @override
  String get labRemoveAllDraftsDialogBody =>
      'Cela supprimera tous les brouillons de résultats enregistrés ou saisis qui n’ont pas été vérifiés.';

  @override
  String get labOrderStatusFieldLabel => 'Order statut';

  @override
  String get labTestStatusColumnLabel => 'Test statut';

  @override
  String get labReferenceRangeColumnLabel => 'Plage de référence';

  @override
  String get labResultInputColumnLabel => 'Résultat';

  @override
  String get labNoOrderItemsEntryTitle => 'No tests on ce commande';

  @override
  String get labNoOrderItemsEntryBody =>
      'Cette commande ne comporte aucun test demandé pour lequel saisir des résultats.';

  @override
  String get labNoSelectionTitle => 'Select un commande';

  @override
  String get labNoSelectionBody =>
      'Choose un laboratoire commande de le queue à enter, verify, et rapport résultats.';

  @override
  String get labPatientContextLabel => 'Contexte du patient en laboratoire';

  @override
  String get labOrderFieldLabel => 'Lab commande';

  @override
  String get labEncounterFieldLabel => 'Rencontre';

  @override
  String get labOrderedAtFieldLabel => 'Commandé à';

  @override
  String get labItemsSectionTitle => 'Tests commandés';

  @override
  String get labSamplesSectionTitle => 'Échantillons';

  @override
  String get labResultsSectionTitle => 'Résultats';

  @override
  String get labTimelineSectionTitle => 'Calendrier';

  @override
  String get labNoSamplesLabel => 'Aucun échantillon enregistré';

  @override
  String get labNoResultsLabel => 'No vérifié résultats';

  @override
  String get labNoTimelineLabel => 'Aucune entrée de chronologie';

  @override
  String get labReferenceRangeLabel => 'Plage de référence';

  @override
  String get labReportedAtLabel => 'Signalé';

  @override
  String get labCollectSampleAction => 'Prélever échantillon';

  @override
  String get labReceiveSampleAction => 'Recevoir un échantillon';

  @override
  String get labRejectSampleAction => 'Rejeter l\'échantillon';

  @override
  String get labReleaseResultAction => 'Verify résultat';

  @override
  String get labReverseWorkflowAction => 'Étape inverse';

  @override
  String get labViewCatalogAction => 'Voir le catalogue';

  @override
  String get labCatalogQcTitle => 'Catalog et QC';

  @override
  String get labCatalogTitle => 'Catalogue de laboratoire';

  @override
  String get labQcTitle => 'Contrôle de qualité';

  @override
  String get labBackendGapsTitle => 'Flux de travail indisponibles';

  @override
  String get labBackendGapsBody =>
      'Aucun flux de travail indisponible ne bloque la file d\'attente de laboratoire affichée.';

  @override
  String get labNoCatalogItemsLabel => 'Aucun catalog items trouvé';

  @override
  String get labNoQcLogsLabel => 'Aucun journal CQ enregistré';

  @override
  String get labTestsTabLabel => 'Essais';

  @override
  String get labPanelsTabLabel => 'Panneaux';

  @override
  String get labRequestOrderDialogTitle =>
      'Demander une ordonnance de laboratoire';

  @override
  String get labPatientIdLabel => 'ID du patient';

  @override
  String get labEncounterIdLabel => 'Identifiant de la rencontre';

  @override
  String get labOrderContextDialogBody =>
      'Recherchez et sélectionnez un patient existant. La rencontre et le contexte de commande existant sont facultatifs lorsqu’ils sont disponibles.';

  @override
  String get labPatientSearchLabel => 'Patient';

  @override
  String get labPatientSearchHint =>
      'Search patient nom, ID, téléphone, ou identifiant';

  @override
  String get labEncounterContextLabel => 'Rencontre';

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
  String get labCollectDialogTitle => 'Prélever échantillon';

  @override
  String get labCollectedAtLabel => 'Recueilli à';

  @override
  String get labDateTimeHint => 'AAAA-MM-JJTHH :MM :SS';

  @override
  String get labNotesLabel => 'Remarques';

  @override
  String get labReceiveDialogTitle => 'Recevoir un échantillon';

  @override
  String get labSampleFieldLabel => 'Échantillon';

  @override
  String get labReceivedAtLabel => 'Reçu à';

  @override
  String get labRejectDialogTitle => 'Rejeter l\'échantillon';

  @override
  String get labRejectReasonLabel => 'Motif du refus';

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
  String get labResultTextLabel => 'Texte du résultat';

  @override
  String get labReportedAtInputLabel => 'Signalé à';

  @override
  String get labReverseDialogTitle => 'Flux de travail de laboratoire inversé';

  @override
  String get labReverseReasonLabel => 'Raison';

  @override
  String get labRecordQcDialogTitle => 'Contrôle qualité des enregistrements';

  @override
  String get labQcTestFieldLabel => 'Test en laboratoire';

  @override
  String get labQcStatusFieldLabel => 'QC statut';

  @override
  String get labLoggedAtLabel => 'Connecté à';

  @override
  String get labQcNotesLabel => 'Remarques sur le contrôle qualité';

  @override
  String get labStatusOrdered => 'Ordonné';

  @override
  String get labStatusCollected => 'Collecté';

  @override
  String get labStatusInProcess => 'En cours';

  @override
  String get labStatusCompleted => 'Vérifié';

  @override
  String get labStatusCancelled => 'Annulé';

  @override
  String get labStatusPending => 'En attente';

  @override
  String get labStatusNormal => 'Normale';

  @override
  String get labStatusAbnormal => 'Anormal';

  @override
  String get labStatusCritical => 'Critique';

  @override
  String get labStatusRejected => 'Rejeté';

  @override
  String get labStatusReceived => 'Reçu';

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
  String get labNextActionCompleted => 'Prêt pour l\'examen du médecin';

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
  String get labReportOrderLabel => 'Commande';

  @override
  String get labReportResultLabel => 'Résultat';

  @override
  String get labReportRangeLabel => 'Plage de référence';

  @override
  String get labReportVerifiedLabel => 'Vérifié';

  @override
  String get labReportFooter =>
      'Généré à partir des données de flux de travail du laboratoire.';

  @override
  String get labGapBillingTitle => 'Payment et authorization gate';

  @override
  String get labGapBillingBody =>
      'Les bloqueurs de paiement ou d’autorisation ne sont pas disponibles pour cet atelier de laboratoire.';

  @override
  String get labGapVerificationTitle => 'Separate vérification step';

  @override
  String get labGapVerificationBody =>
      'Les résultats des articles de commande peuvent être publiés. Un état distinct de vérification avant publication n’est pas disponible.';

  @override
  String get labGapReportGenerationTitle => 'Generated rapport';

  @override
  String get labGapReportGenerationBody =>
      'L\'aperçu du rapport partagé est disponible. Un document généré spécifique au laboratoire n’est pas encore disponible.';

  @override
  String get navigationOperationsLabel => 'Opérations';

  @override
  String get navigationOperationsShortLabel => 'Opérations';

  @override
  String get operationsTitle => 'Opérations';

  @override
  String get operationsLoadingTitle => 'Opérations de chargement';

  @override
  String get operationsLoadingBody =>
      'Loading maintenance demandes, actifs, et service logs.';

  @override
  String get operationsLiveStatus => 'Live synchronisation';

  @override
  String get operationsSavingStatus => 'Enregistrement';

  @override
  String get operationsSavedMessage =>
      'Modifications des opérations enregistrées.';

  @override
  String get operationsCreateRequestAction => 'Create demande';

  @override
  String get operationsOpenReportAction => 'Rapport';

  @override
  String get operationsAllRequestsSummaryLabel => 'All demandes';

  @override
  String get operationsOpenSummaryLabel => 'Ouvrir';

  @override
  String get operationsInProgressSummaryLabel => 'En cours';

  @override
  String get operationsCompletedSummaryLabel => 'Terminé';

  @override
  String get operationsCancelledSummaryLabel => 'Annulé';

  @override
  String get operationsAssetsSummaryLabel => 'Actifs';

  @override
  String get operationsQueueTitle => 'File d\'attente de maintenance';

  @override
  String get operationsQueueDescription =>
      'Track établissement repairs, actifs, safety notes, et readiness work.';

  @override
  String get operationsSearchLabel => 'Opérations de recherche';

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
  String get operationsReportedDateFilterLabel => 'Date signalée';

  @override
  String get operationsReportedFromLabel => 'Reported de';

  @override
  String get operationsReportedToLabel => 'Reported à';

  @override
  String get operationsPickReportedDateAction => 'Pick signalé date';

  @override
  String get operationsStatusFilterLabel => 'Statut';

  @override
  String get operationsPriorityFilterLabel => 'Priorité';

  @override
  String get operationsFacilityFilterLabel => 'Établissement';

  @override
  String get operationsAssetFilterLabel => 'Actif';

  @override
  String operationsPageLabel(int first, int last, int total) {
    return '${first}J${last}sur${total}demandes';
  }

  @override
  String get operationsNoRequestsTitle => 'No maintenance demandes';

  @override
  String get operationsNoRequestsBody =>
      'Create un demande ou adjust le filtres.';

  @override
  String get operationsDetailTitle => 'Demander des détails';

  @override
  String get operationsNoSelectionTitle => 'Select un demande';

  @override
  String get operationsNoSelectionBody =>
      'Choose un queue ligne à review assignments, service logs, et readiness notes.';

  @override
  String get operationsRequestColumnLabel => 'Demande';

  @override
  String get operationsAreaColumnLabel => 'Zone/système';

  @override
  String get operationsPriorityColumnLabel => 'Priorité';

  @override
  String get operationsLocationColumnLabel => 'Emplacement';

  @override
  String get operationsAssigneeColumnLabel => 'Responsable/équipe';

  @override
  String get operationsStatusColumnLabel => 'Statut';

  @override
  String get operationsDueColumnLabel => 'Due heure';

  @override
  String get operationsNextActionColumnLabel => 'Prochaine action';

  @override
  String get operationsCategoryLabel => 'Catégorie';

  @override
  String get operationsIssueTitle => 'Issue et notes';

  @override
  String get operationsActionsTitle => 'Actes';

  @override
  String get operationsAssignAction => 'Attribuer';

  @override
  String get operationsUpdateStatusAction => 'Update statut';

  @override
  String get operationsAddServiceLogAction => 'Ajouter un journal de service';

  @override
  String get operationsPartsVendorAction => 'Pièces/note du fournisseur';

  @override
  String get operationsSafetyNoteAction => 'Note de sécurité';

  @override
  String get operationsEvidenceNoteAction => 'Note de preuve';

  @override
  String get operationsHandoverNoteAction => 'Note de remise';

  @override
  String get operationsCloseoutNoteAction => 'Note de clôture';

  @override
  String get operationsPartsVendorNoteLabel => 'Parts ou vendor note';

  @override
  String get operationsSafetyNoteLabel => 'Note de sécurité';

  @override
  String get operationsEvidenceNoteLabel => 'Note de preuve';

  @override
  String get operationsHandoverNoteLabel => 'Note de remise';

  @override
  String get operationsCloseoutNoteLabel => 'Note de clôture';

  @override
  String get operationsSaveNoteAction => 'Enregistrer la note';

  @override
  String get operationsServiceLogsTitle => 'Journaux de service';

  @override
  String get operationsNoServiceLogsTitle => 'Aucun journal de service';

  @override
  String get operationsNoServiceLogsBody =>
      'Les journaux de service apparaissent après l\'enregistrement d\'une réparation basée sur des actifs.';

  @override
  String get operationsUnknownValue => 'Inconnu';

  @override
  String get operationsUnassignedValue => 'Non attribué';

  @override
  String get operationsNoDueTimeValue => 'No due heure';

  @override
  String get operationsNoNotesValue => 'Aucune note enregistrée.';

  @override
  String get operationsLocationNoteLabel => 'Remarque sur l\'emplacement';

  @override
  String get operationsIssueFieldLabel => 'Émettre';

  @override
  String get operationsNotesLabel => 'Remarques';

  @override
  String get operationsCreateRequestSubmitAction => 'Create demande';

  @override
  String get operationsAssigneeFieldLabel => 'Technician ou team';

  @override
  String get operationsSlaHoursFieldLabel => 'Horaires SLA';

  @override
  String get operationsTriageSummaryFieldLabel => 'Note de mission';

  @override
  String get operationsAssignSubmitAction => 'Enregistrer le devoir';

  @override
  String get operationsStatusNoteLabel => 'Remarque sur l\'état';

  @override
  String get operationsUpdateStatusSubmitAction => 'Save statut';

  @override
  String get operationsServiceNotesLabel => 'Notes d\'entretien';

  @override
  String get operationsAddServiceLogSubmitAction =>
      'Enregistrer le journal de service';

  @override
  String get operationsNoConfiguredAssetsOption => 'No configured actifs';

  @override
  String get operationsStatusOpen => 'Ouvrir';

  @override
  String get operationsStatusInProgress => 'En cours';

  @override
  String get operationsStatusCompleted => 'Terminé';

  @override
  String get operationsStatusCancelled => 'Annulé';

  @override
  String get operationsPriorityUrgent => 'Urgent';

  @override
  String get operationsPriorityHigh => 'Haut';

  @override
  String get operationsPriorityNormal => 'Normale';

  @override
  String get operationsPriorityLow => 'Faible';

  @override
  String get operationsCategoryElectrical => 'Électrique';

  @override
  String get operationsCategoryPlumbing => 'Plomberie';

  @override
  String get operationsCategoryWater => 'Eau';

  @override
  String get operationsCategoryPowerBackup => 'Alimentation de secours';

  @override
  String get operationsCategoryHvac => 'CVC';

  @override
  String get operationsCategoryGeneralAsset => 'General actif';

  @override
  String get operationsCategorySafety => 'Sécurité';

  @override
  String get operationsCategoryOther => 'Autre';

  @override
  String get operationsNextActionAssign => 'Assign technician ou team';

  @override
  String get operationsNextActionServiceLog =>
      'Enregistrer le travail de service';

  @override
  String get operationsNextActionUpdateStatus => 'Update repair statut';

  @override
  String get operationsNextActionCloseout =>
      'Ajouter une note de clôture si nécessaire';

  @override
  String get operationsNextActionCancelled => 'Demande annulée';

  @override
  String get operationsNextActionReview => 'Review demande';

  @override
  String get operationsReportTitle => 'Operations rapport';

  @override
  String get operationsReportPreviewTitle => 'Report aperçu';

  @override
  String operationsGeneratedAtLabel(String generatedAt) {
    return 'Generated$generatedAt';
  }

  @override
  String operationsReportSummaryLine(
    int total,
    int open,
    int inProgress,
    int completed,
  ) {
    return '$total demandes : $open ouvertes, $inProgress en cours, $completed terminées.';
  }

  @override
  String get navigationBiomedicalLabel => 'Génie biomédical';

  @override
  String get navigationBiomedicalShortLabel => 'Biomédical';

  @override
  String get biomedicalTitle => 'Biomédical';

  @override
  String get biomedicalLoadingTitle => 'Loading biomédical';

  @override
  String get biomedicalLoadingBody =>
      'Loading équipement registry, work commandes, et compliance dossiers.';

  @override
  String get biomedicalLiveStatus => 'Live synchronisation';

  @override
  String get biomedicalSavingStatus => 'Enregistrement';

  @override
  String get biomedicalSavedMessage =>
      'Modifications biomédicales enregistrées.';

  @override
  String get biomedicalRegisterAssetAction => 'Register actif';

  @override
  String get biomedicalReportFaultAction => 'Signaler un défaut';

  @override
  String get biomedicalTotalEquipmentSummaryLabel => 'Total équipement';

  @override
  String get biomedicalOverduePmSummaryLabel => 'MP en retard';

  @override
  String get biomedicalOpenWorkOrdersSummaryLabel => 'Bons de travail ouverts';

  @override
  String get biomedicalCriticalDowntimeSummaryLabel =>
      'Temps d\'arrêt critique';

  @override
  String get biomedicalActiveRecallsSummaryLabel => 'Rappels actifs';

  @override
  String get biomedicalAssetListTitle => 'Liste de travail d\'équipement';

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
  String get biomedicalPanelFilterLabel => 'Panneau';

  @override
  String get biomedicalStatusFilterLabel => 'Statut';

  @override
  String get biomedicalPriorityFilterLabel => 'Priorité';

  @override
  String get biomedicalFacilityFilterLabel => 'Établissement';

  @override
  String get biomedicalDatePresetFilterLabel => 'Date d\'échéance';

  @override
  String get biomedicalAssetTagColumnLabel => 'Étiquette d\'actif';

  @override
  String get biomedicalEquipmentColumnLabel => 'Équipement';

  @override
  String get biomedicalCategoryColumnLabel => 'Catégorie';

  @override
  String get biomedicalLocationColumnLabel => 'Emplacement';

  @override
  String get biomedicalRiskColumnLabel => 'Risque';

  @override
  String get biomedicalStatusColumnLabel => 'Statut';

  @override
  String get biomedicalOwnerColumnLabel => 'Responsable';

  @override
  String get biomedicalNextActionColumnLabel => 'Prochaine action';

  @override
  String get biomedicalPreviousPageLabel => 'Previous équipement';

  @override
  String get biomedicalNextPageLabel => 'Next équipement';

  @override
  String biomedicalPageLabel(int from, int to, int total) {
    return 'Affichage de $from-$to sur $total';
  }

  @override
  String get biomedicalNoAssetsTitle => 'No équipement dossiers';

  @override
  String get biomedicalNoAssetsBody =>
      'Les enregistrements d\'équipement correspondant à cette recherche et à ce filtre apparaîtront ici.';

  @override
  String get biomedicalDetailTitle => 'Détail de l\'équipement';

  @override
  String get biomedicalNoSelectionTitle => 'Select équipement';

  @override
  String get biomedicalNoSelectionBody =>
      'Choose équipement ou un related dossier à review readiness, work commandes, compliance, et lifecycle actions.';

  @override
  String get biomedicalRegistrySectionTitle => 'Enregistrement';

  @override
  String get biomedicalReadinessSectionTitle => 'Préparation';

  @override
  String get biomedicalMaintenanceSectionTitle => 'Entretien';

  @override
  String get biomedicalComplianceSectionTitle => 'Conformité';

  @override
  String get biomedicalLifecycleSectionTitle => 'Cycle de vie';

  @override
  String get biomedicalReportsSectionTitle => 'Report aperçu';

  @override
  String get biomedicalNotAvailableLabel => 'J';

  @override
  String get biomedicalAssetTagLabel => 'Étiquette d\'actif';

  @override
  String get biomedicalResourceLabel => 'Type de record';

  @override
  String get biomedicalEquipmentLabel => 'Équipement';

  @override
  String get biomedicalCategoryLabel => 'Catégorie';

  @override
  String get biomedicalFacilityLabel => 'Établissement';

  @override
  String get biomedicalOwnerLabel => 'Responsable';

  @override
  String get biomedicalStatusLabel => 'Statut';

  @override
  String get biomedicalPriorityLabel => 'Priorité';

  @override
  String get biomedicalNextDueLabel => 'Prochaine échéance';

  @override
  String get biomedicalLastUpdatedLabel => 'Last mis à jour';

  @override
  String get biomedicalTargetPathLabel => 'Chemin d\'audit';

  @override
  String get biomedicalEditAssetAction => 'Edit actif';

  @override
  String get biomedicalTransferLocationAction => 'Lieu de transfert';

  @override
  String get biomedicalScheduleMaintenanceAction => 'Planifier l\'entretien';

  @override
  String get biomedicalCreateWorkOrderAction => 'Create work commande';

  @override
  String get biomedicalUpdateWorkOrderAction => 'Update work commande';

  @override
  String get biomedicalStartWorkOrderAction => 'Start work commande';

  @override
  String get biomedicalReturnToServiceAction => 'Return à service';

  @override
  String get biomedicalRecordCalibrationAction => 'Enregistrer l\'étalonnage';

  @override
  String get biomedicalRecordSafetyTestAction =>
      'Enregistrer le test de sécurité';

  @override
  String get biomedicalReportDowntimeAction => 'Signaler les temps d\'arrêt';

  @override
  String get biomedicalCloseDowntimeAction => 'Fermeture des temps d\'arrêt';

  @override
  String get biomedicalLogIncidentAction => 'Consigner l\'incident';

  @override
  String get biomedicalAcknowledgeRecallAction => 'Accuser réception du rappel';

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
  String get biomedicalScheduleMaintenanceDialogTitle =>
      'Planifier l\'entretien';

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
  String get biomedicalCalibrationDialogTitle => 'Enregistrer l\'étalonnage';

  @override
  String get biomedicalSafetyTestDialogTitle =>
      'Enregistrer le test de sécurité';

  @override
  String get biomedicalDowntimeDialogTitle => 'Signaler les temps d\'arrêt';

  @override
  String get biomedicalCloseDowntimeDialogTitle =>
      'Fermeture des temps d\'arrêt';

  @override
  String get biomedicalIncidentDialogTitle => 'Consigner l\'incident';

  @override
  String get biomedicalRecallDialogTitle => 'Accuser réception du rappel';

  @override
  String get biomedicalDisposalDialogTitle => 'Dispose ou transfert équipement';

  @override
  String get biomedicalFaultDialogTitle => 'Report équipement fault';

  @override
  String get biomedicalPrintReportDialogTitle => 'Biomedical rapport';

  @override
  String get biomedicalAssetNameLabel => 'Equipment nom';

  @override
  String get biomedicalAssetCodeLabel => 'Code de l\'actif';

  @override
  String get biomedicalSerialNumberLabel => 'Numéro de série';

  @override
  String get biomedicalRoomLabel => 'Chambre';

  @override
  String get biomedicalNotesLabel => 'Remarques';

  @override
  String get biomedicalDescriptionLabel => 'Description';

  @override
  String get biomedicalWorkOrderTitleLabel => 'Work commande titre';

  @override
  String get biomedicalEngineerLabel => 'Ingénieur';

  @override
  String get biomedicalPlanNameLabel => 'Plan nom';

  @override
  String get biomedicalMaintenanceTypeLabel => 'Type d\'entretien';

  @override
  String get biomedicalFrequencyDaysLabel => 'Jours de fréquence';

  @override
  String get biomedicalNextDueAtLabel => 'Prochaine échéance à';

  @override
  String get biomedicalResultLabel => 'Résultat';

  @override
  String get biomedicalCalibratedAtLabel => 'Calibré à';

  @override
  String get biomedicalTestedAtLabel => 'Testé à';

  @override
  String get biomedicalDowntimeStartedAtLabel => 'Le temps d\'arrêt a commencé';

  @override
  String get biomedicalDowntimeEndedAtLabel => 'Temps d\'arrêt terminé';

  @override
  String get biomedicalReasonLabel => 'Raison';

  @override
  String get biomedicalSeverityLabel => 'Gravité';

  @override
  String get biomedicalStartedAtLabel => 'Commencé à';

  @override
  String get biomedicalRecordedAtLabel => 'Enregistré à';

  @override
  String get biomedicalEffectiveAtLabel => 'Efficace à';

  @override
  String get biomedicalReportedEquipmentNameLabel => 'Temporary équipement nom';

  @override
  String get biomedicalPatientSafetyRiskLabel =>
      'Risque pour la sécurité des patients';

  @override
  String get biomedicalDateTimeHint => 'AAAA-MM-JJTHH : MM';

  @override
  String get biomedicalSubmitAction => 'Soumettre';

  @override
  String get biomedicalSaveAction => 'Enregistrer';

  @override
  String get biomedicalCreateAction => 'Créer';

  @override
  String biomedicalFieldRequiredLabel(String label) {
    return '${label}est requis.';
  }

  @override
  String get biomedicalPanelOverview => 'Présentation';

  @override
  String get biomedicalPanelRegistry => 'Enregistrement';

  @override
  String get biomedicalPanelPreventive => 'Préventif';

  @override
  String get biomedicalPanelWorkOrders => 'Work commandes';

  @override
  String get biomedicalPanelCompliance => 'Conformité';

  @override
  String get biomedicalPanelSupport => 'Soutien';

  @override
  String get biomedicalPanelAnalytics => 'Analytique';

  @override
  String get biomedicalDatePresetToday => 'Aujourdh’ui';

  @override
  String get biomedicalDatePresetNext7Days => '7 prochains jours';

  @override
  String get biomedicalDatePresetOverdue => 'Impayé';

  @override
  String get biomedicalDatePresetThisMonth => 'Ce month';

  @override
  String get biomedicalNextActionMaintain => 'Effectuer l\'entretien';

  @override
  String get biomedicalNextActionCalibrate => 'Vérifier la conformité';

  @override
  String get biomedicalNextActionReturnService => 'Return à service';

  @override
  String get biomedicalNextActionReviewRecall => 'Rappel d\'avis';

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
  String get integrationsFailedStatusLabel => 'Échoué';

  @override
  String get integrationsWarningStatusLabel => 'Avertissement';

  @override
  String get integrationsOperationalStatusLabel => 'Opérationnel';

  @override
  String get integrationsWorkspaceTitle => 'Intégrations';

  @override
  String get integrationsCreateIntegrationAction => 'Create intégration';

  @override
  String get integrationsCreateApiKeyAction => 'Créer une clé API';

  @override
  String get integrationsCreateWebhookAction => 'Créer un webhook';

  @override
  String get integrationsAllSummaryLabel => 'Total éléments';

  @override
  String get integrationsActiveSummaryLabel => 'Actif';

  @override
  String get integrationsWarningsSummaryLabel => 'Avertissements';

  @override
  String get integrationsFailedSummaryLabel => 'Échoué';

  @override
  String get integrationsApiKeysSummaryLabel => 'Clés API';

  @override
  String get integrationsWebhooksSummaryLabel => 'Points de terminaison Web';

  @override
  String get integrationsWorklistTitle => 'Liste de travail d\'intégration';

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
  String get integrationsFilterGroupLabel => 'Groupe';

  @override
  String get integrationsPreviousPageLabel => 'Page précédente';

  @override
  String get integrationsNextPageLabel => 'Page suivante';

  @override
  String integrationsPageLabel(int from, int to, int total) {
    return '$from-$to sur $total';
  }

  @override
  String get integrationsEmptyTitle => 'No intégration éléments';

  @override
  String get integrationsEmptyBody =>
      'Create un intégration, API key, ou webhook à populate ce espace de travail.';

  @override
  String get integrationsTypeColumnLabel => 'Taper';

  @override
  String get integrationsNameColumnLabel => 'Nom';

  @override
  String get integrationsStatusColumnLabel => 'Statut';

  @override
  String get integrationsOwnerColumnLabel => 'Responsable';

  @override
  String get integrationsScopeColumnLabel => 'Portée';

  @override
  String get integrationsLastEventColumnLabel => 'Dernier événement';

  @override
  String get integrationsNextActionColumnLabel => 'Prochaine action';

  @override
  String integrationsMobileSubtitle(String kind, String scope) {
    return '$kind|$scope';
  }

  @override
  String get integrationsNoSelectionTitle => 'Select un intégration élément';

  @override
  String get integrationsNoSelectionBody =>
      'Choose un ligne à review configuration, keys, webhooks, logs, et disponible actions.';

  @override
  String get integrationsConfigureAction => 'Configurer';

  @override
  String get integrationsTestConnectionAction => 'Test connexion';

  @override
  String get integrationsSyncNowAction => 'Synchronisez maintenant';

  @override
  String get integrationsDisableAction => 'Désactiver';

  @override
  String get integrationsEnableAction => 'Activer';

  @override
  String get integrationsManagePermissionsAction => 'Manage autorisations';

  @override
  String get integrationsRevokeApiKeyAction => 'Révoquer la clé';

  @override
  String get integrationsEditWebhookAction => 'Modifier le webhook';

  @override
  String get integrationsReplayWebhookAction => 'Rejouer le webhook';

  @override
  String get integrationsReplayLogAction => 'Journal de relecture';

  @override
  String get integrationsReferenceLabel => 'Référence';

  @override
  String get integrationsActionResultTitle => 'Latest action résultat';

  @override
  String get integrationsMaskedSecretTitle => 'Clé masquée';

  @override
  String get integrationsRotationGapTitle => 'Key rotation indisponible';

  @override
  String get integrationsRotationGapBody =>
      'Create un replacement key, mettre à jour downstream systems, then revoke le ancien key.';

  @override
  String get integrationsEventLabel => 'Événement';

  @override
  String get integrationsTargetHostLabel => 'Hôte cible';

  @override
  String get integrationsIntegrationLabel => 'Intégration';

  @override
  String get integrationsSanitizedLogTitle => 'Message de journal nettoyé';

  @override
  String get integrationsInteropReadyBody =>
      'Des actions d\'interopérabilité sont disponibles.';

  @override
  String get integrationsConfigurationTitle => 'Configuration';

  @override
  String get integrationsConfigurationMaskedBody =>
      'Les valeurs sensibles sont masquées dans cette réponse.';

  @override
  String get integrationsConfigurationEmptyBody =>
      'Aucune valeur de configuration n\'est disponible pour cette intégration.';

  @override
  String get integrationsNoConfigurationRows => 'No configuration lignes';

  @override
  String get integrationsRelatedWebhooksTitle => 'Webhooks associés';

  @override
  String get integrationsNoRelatedWebhooks => 'Aucun webhook associé';

  @override
  String get integrationsRelatedLogsTitle => 'Journaux associés';

  @override
  String get integrationsNoRelatedLogs => 'Aucun journal associé';

  @override
  String get integrationsPermissionsTitle => 'Autorisations';

  @override
  String get integrationsNoPermissions => 'No autorisations granted';

  @override
  String get integrationsRemovePermissionDialogTitle => 'Remove autorisation?';

  @override
  String get integrationsRemovePermissionDialogBody =>
      'Cette clé API perdra immédiatement l\'autorisation sélectionnée.';

  @override
  String get integrationsRemovePermissionAction => 'Remove autorisation';

  @override
  String get integrationsNameFieldLabel => 'Nom';

  @override
  String get integrationsNameRequiredMessage => 'Enter un nom.';

  @override
  String get integrationsTypeFieldLabel => 'Taper';

  @override
  String get integrationsConfigFieldLabel => 'Configuration';

  @override
  String get integrationsConfigCreateHelper =>
      'Saisissez un paramètre clé=valeur par ligne. Les clés sensibles sont acceptées mais ne seront plus affichées.';

  @override
  String get integrationsConfigUpdateHelper =>
      'Entrez uniquement les paramètres à modifier. Les valeurs sensibles existantes ne sont pas affichées ici.';

  @override
  String get integrationsCreateIntegrationSubmitAction => 'Create intégration';

  @override
  String get integrationsSaveIntegrationAction => 'Save intégration';

  @override
  String get integrationsApiKeyNameFieldLabel => 'Key nom';

  @override
  String get integrationsApiKeyNameRequiredMessage => 'Enter un key nom.';

  @override
  String get integrationsExpiresAtFieldLabel => 'Expire à';

  @override
  String get integrationsIsoDateHint => 'YYYY-MM-DD ou ISO timestamp';

  @override
  String get integrationsCreateApiKeySubmitAction => 'Créer une clé API';

  @override
  String get integrationsIntegrationFieldLabel => 'Intégration';

  @override
  String get integrationsEventFieldLabel => 'Événement';

  @override
  String get integrationsEventRequiredMessage => 'Enter un event nom.';

  @override
  String get integrationsTargetUrlFieldLabel => 'URL cible';

  @override
  String get integrationsTargetUrlRequiredMessage => 'Enter un target URL.';

  @override
  String get integrationsWebhookActiveFieldLabel => 'Webhook actif';

  @override
  String get integrationsCreateWebhookSubmitAction => 'Créer un webhook';

  @override
  String get integrationsSaveWebhookAction => 'Enregistrer le webhook';

  @override
  String get integrationsApiKeyFieldLabel => 'Clé API';

  @override
  String get integrationsApiKeyRequiredMessage => 'Choose un API key.';

  @override
  String get integrationsPermissionFieldLabel => 'Autorisation';

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
  String get integrationsCreateApiKeyDialogTitle => 'Créer une clé API';

  @override
  String get integrationsCreateWebhookDialogTitle => 'Créer un webhook';

  @override
  String get integrationsEditWebhookDialogTitle => 'Modifier le webhook';

  @override
  String get integrationsManagePermissionsDialogTitle =>
      'Manage API key autorisations';

  @override
  String get integrationsSecretMissing => 'Secret non rendu';

  @override
  String get integrationsApiKeyCreatedDialogTitle => 'API key créé';

  @override
  String get integrationsApiKeyCreatedSecretTitle => 'One-heure secret';

  @override
  String get integrationsApiKeyCreatedSecretBody =>
      'Cette valeur est affichée une fois. Conservez-le en toute sécurité avant de fermer cette boîte de dialogue.';

  @override
  String get integrationsCopySecretAction => 'Copier le secret';

  @override
  String get integrationsTestConnectionDialogTitle => 'Test connexion?';

  @override
  String get integrationsTestConnectionDialogBody =>
      'Le système exécutera le test de connexion d’intégration.';

  @override
  String get integrationsSyncNowDialogTitle => 'Synchroniser maintenant ?';

  @override
  String get integrationsSyncNowDialogBody =>
      'Le système mettra en file d’attente une synchronisation d’intégration immédiate.';

  @override
  String get integrationsEnableIntegrationDialogTitle => 'Enable intégration?';

  @override
  String get integrationsDisableIntegrationDialogTitle =>
      'Disable intégration?';

  @override
  String get integrationsEnableIntegrationDialogBody =>
      'Cette intégration deviendra disponible pour les flux de travail en aval.';

  @override
  String get integrationsDisableIntegrationDialogBody =>
      'Cette intégration cessera de participer aux flux de travail en aval.';

  @override
  String get integrationsEnableApiKeyDialogTitle => 'Activer la clé API ?';

  @override
  String get integrationsDisableApiKeyDialogTitle => 'Désactiver la clé API ?';

  @override
  String get integrationsEnableApiKeyDialogBody =>
      'Ce API key can authenticate demandes again.';

  @override
  String get integrationsDisableApiKeyDialogBody =>
      'Cette clé API cessera d\'authentifier les demandes.';

  @override
  String get integrationsEnableWebhookDialogTitle => 'Activer le webhook ?';

  @override
  String get integrationsDisableWebhookDialogTitle => 'Désactiver le webhook ?';

  @override
  String get integrationsEnableWebhookDialogBody =>
      'Ce webhook recevra à nouveau les événements correspondants.';

  @override
  String get integrationsDisableWebhookDialogBody =>
      'Ce webhook cessera de recevoir les événements correspondants.';

  @override
  String get integrationsRevokeApiKeyDialogTitle => 'Révoquer la clé API ?';

  @override
  String get integrationsRevokeApiKeyDialogBody =>
      'Ce permanently deletes le API key et its local autorisation grants.';

  @override
  String get integrationsReplayWebhookDialogTitle => 'Rejouer le webhook ?';

  @override
  String get integrationsReplayWebhookDialogBody =>
      'Le système rejouera la livraison du webhook.';

  @override
  String get integrationsReplayLogDialogTitle => 'Rejouer le journal ?';

  @override
  String get integrationsReplayLogDialogBody =>
      'Le système réessayera l\'événement d\'intégration enregistré.';

  @override
  String get integrationsFilterIntegrations => 'Intégrations';

  @override
  String get integrationsFilterApiKeys => 'Clés API';

  @override
  String get integrationsFilterWebhooks => 'Points de terminaison Web';

  @override
  String get integrationsFilterLogs => 'Journaux';

  @override
  String get integrationsFilterInterop => 'Interopérabilité';

  @override
  String get integrationsFilterActive => 'Actif';

  @override
  String get integrationsFilterWarning => 'Avertissement';

  @override
  String get integrationsFilterFailed => 'Échoué';

  @override
  String get integrationsFilterDisabled => 'Désactivé';

  @override
  String get integrationsTypeHl7 => 'HL7';

  @override
  String get integrationsTypeFhir => 'FHIR';

  @override
  String get integrationsTypeLab => 'Laboratoire';

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
  String get integrationsStatusFailed => 'Échoué';

  @override
  String get integrationsStatusReady => 'Prêt';

  @override
  String get integrationsStatusBackendGap => 'Indisponible';

  @override
  String get integrationsStatusQueued => 'En file d\'attente';

  @override
  String get integrationsStatusConnected => 'Connecté';

  @override
  String get integrationsKindIntegration => 'Intégration';

  @override
  String get integrationsKindApiKey => 'Clé API';

  @override
  String get integrationsKindWebhook => 'Point de terminaison Web';

  @override
  String get integrationsKindLog => 'Enregistrer';

  @override
  String get integrationsKindInterop => 'Interopérabilité';

  @override
  String get integrationsNoScopesLabel => 'Aucune portée';

  @override
  String get integrationsOneScopeLabel => '1 portée';

  @override
  String get integrationsInteropFhirScope => 'FHIR échange';

  @override
  String get integrationsInteropHl7Scope => 'Messagerie HL7';

  @override
  String get integrationsInteropDicomScope => 'Liaison DICOM';

  @override
  String get integrationsInteropMigrationScope => 'Migration import et export';

  @override
  String get integrationsInteropStatusScope => 'Readiness statut';

  @override
  String integrationsManyScopesLabel(String count) {
    return '${count}scopes';
  }

  @override
  String get integrationsNextActionReviewFailure => 'Review échec';

  @override
  String get integrationsNextActionEnable => 'Enable élément';

  @override
  String get integrationsNextActionMonitor => 'Moniteur';

  @override
  String get integrationsNextActionReviewKey => 'Clé de révision';

  @override
  String get integrationsNextActionRotateOrMonitor => 'Rotate ou monitor';

  @override
  String get integrationsNextActionEnableWebhook => 'Activer le webhook';

  @override
  String get integrationsNextActionMonitorDelivery => 'Surveiller la livraison';

  @override
  String get integrationsNextActionReplayOrEscalate => 'Replay ou escalate';

  @override
  String get integrationsNextActionReview => 'Revoir';

  @override
  String get integrationsNextActionRunEndpoint => 'Exécuter une action';

  @override
  String get integrationsNextActionUseStatusLogs => 'Use statut logs';

  @override
  String get integrationsInteropFhirTitle => 'FHIR échange';

  @override
  String get integrationsInteropHl7Title => 'Messages HL7';

  @override
  String get integrationsInteropDicomTitle => 'Liaison d\'étude DICOM';

  @override
  String get integrationsInteropMigrationTitle => 'Outils de migration';

  @override
  String get integrationsInteropReadinessTitle =>
      'Préparation à l\'interopérabilité';

  @override
  String get integrationsInteropReadinessGapBody =>
      'Aucun signal de préparation à l’interopérabilité dédié n’est disponible. Utilisez l’état d’intégration et les journaux nettoyés.';

  @override
  String get integrationsSavedMessage =>
      'Modifications d\'intégration enregistrées.';

  @override
  String get reportsTitle => 'Reports et audit';

  @override
  String get reportsLoadingTitle => 'Loading rapports espace de travail';

  @override
  String get reportsLoadingBody =>
      'Fetching rapport definitions, runs, schedules, dashboards, et audit evidence.';

  @override
  String get reportsLiveStatus => 'Direct';

  @override
  String get reportsSavingStatus => 'Enregistrement';

  @override
  String get reportsRunAction => 'Run rapport';

  @override
  String get reportsScheduleAction => 'Calendrier';

  @override
  String get reportsRetryAction => 'Réessayer';

  @override
  String get reportsCancelRunAction => 'Annuler l\'exécution';

  @override
  String get reportsDownloadAction => 'Télécharger';

  @override
  String get reportsPrintAction => 'Imprimer';

  @override
  String get reportsExportEvidenceAction => 'Exporter des preuves';

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
  String get reportsPanelFilterLabel => 'Panneau Espace de travail';

  @override
  String get reportsStatusFilterLabel => 'Statut';

  @override
  String get reportsFormatFilterLabel => 'Format';

  @override
  String get reportsDatasetFilterLabel => 'Ensemble de données';

  @override
  String get reportsDateFilterLabel => 'Plage de dates';

  @override
  String get reportsDateFromLabel => 'Du';

  @override
  String get reportsDateToLabel => 'A';

  @override
  String get reportsDatePickerLabel => 'Choisissez une date';

  @override
  String get reportsInvalidDateMessage => 'Enter un valid date.';

  @override
  String get reportsComplianceTypeFilterLabel => 'Type d\'événement';

  @override
  String get reportsAllStatusesLabel => 'Tous les statuts';

  @override
  String get reportsAllFormatsLabel => 'Tous les formats';

  @override
  String get reportsAllDatasetsLabel => 'Tous les ensembles de données';

  @override
  String get reportsPanelOverview => 'Présentation';

  @override
  String get reportsPanelCatalog => 'Catalogue';

  @override
  String get reportsPanelDelivery => 'Runs et delivery';

  @override
  String get reportsPanelDashboards => 'Tableaux de bord';

  @override
  String get reportsPanelMonitor => 'Moniteur KPI';

  @override
  String get reportsPanelActivity => 'Activité d\'analyse';

  @override
  String get reportsPanelAudit => 'Journaux d\'audit';

  @override
  String get reportsPanelPhi => 'PHI accès';

  @override
  String get reportsPanelProcessing => 'Journaux de traitement';

  @override
  String get reportsWorklistDescription =>
      'Search, filtre, aperçu, run, planning, print, et export rapport dossiers.';

  @override
  String get reportsComplianceDescription =>
      'Search et review audit, PHI accès, et data traitement logs within permitted scope.';

  @override
  String get reportsSchedulesTitle => 'Horaires';

  @override
  String get reportsSchedulesDescription =>
      'Saved schedules actualiser independently de rapport runs.';

  @override
  String get reportsNoItemsTitle => 'No rapport dossiers';

  @override
  String get reportsNoItemsBody =>
      'No rapport dossiers match le actuel filtres.';

  @override
  String get reportsNoSchedulesTitle => 'Pas d\'horaires';

  @override
  String get reportsNoSchedulesBody =>
      'No saved rapport schedules match ce voir.';

  @override
  String get reportsNoComplianceLogsTitle => 'Aucun journal de conformité';

  @override
  String get reportsNoComplianceLogsBody =>
      'No audit ou compliance evidence matches le actuel filtres.';

  @override
  String get reportsPreviewTitle => 'Report aperçu';

  @override
  String get reportsComplianceDetailTitle => 'Détail des preuves';

  @override
  String get reportsNoSelectionTitle => 'Aucune sélection';

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
  String get reportsReferenceLabel => 'Référence';

  @override
  String get reportsOwnerLabel => 'Responsable';

  @override
  String get reportsUpdatedColumnLabel => 'Mis à jour';

  @override
  String get reportsFormatColumnLabel => 'Format';

  @override
  String get reportsCategoryLabel => 'Catégorie';

  @override
  String get reportsDatasetLabel => 'Ensemble de données';

  @override
  String get reportsFacilityLabel => 'Établissement';

  @override
  String get reportsValueLabel => 'Valeur';

  @override
  String get reportsErrorLabel => 'Erreur';

  @override
  String get reportsEventColumnLabel => 'Événement';

  @override
  String get reportsUserColumnLabel => 'Utilisateur';

  @override
  String get reportsRecordColumnLabel => 'Enregistrer';

  @override
  String get reportsTimestampColumnLabel => 'Horodatage';

  @override
  String get reportsPatientLabel => 'Patient';

  @override
  String get reportsActionLabel => 'Action';

  @override
  String get reportsEntityLabel => 'Entité';

  @override
  String get reportsScopeLabel => 'Portée';

  @override
  String get reportsPurposeLabel => 'But';

  @override
  String get reportsLegalBasisLabel => 'Base juridique';

  @override
  String get reportsIpAddressLabel => 'IP adresse';

  @override
  String get reportsDetailsLabel => 'Détails';

  @override
  String get reportsPreviousPageLabel => 'Page précédente';

  @override
  String get reportsNextPageLabel => 'Page suivante';

  @override
  String reportsPageLabel(int first, int last, int total) {
    return '${first}J${last}sur$total';
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
  String get reportsFormatFieldLabel => 'Format de sortie';

  @override
  String get reportsRetentionDaysFieldLabel => 'Jours de rétention';

  @override
  String get reportsScheduleNameFieldLabel => 'Schedule nom';

  @override
  String get reportsFrequencyFieldLabel => 'Fréquence';

  @override
  String get reportsTimeOfDayFieldLabel => 'Time sur day';

  @override
  String get reportsTimeOfDayHint => 'HH : mm';

  @override
  String get reportsCreateScheduleAction => 'Create planning';

  @override
  String get reportsFrequencyDaily => 'Tous les jours';

  @override
  String get reportsFrequencyWeekly => 'Hebdomadaire';

  @override
  String get reportsFrequencyMonthly => 'Mensuel';

  @override
  String get reportsCancelRunDialogTitle => 'Cancel rapport run';

  @override
  String get reportsCancelRunDialogBody =>
      'Annuler cette exécution de rapport en file d\'attente ou en cours de traitement ? La ligne d\'exécution sera actualisée une fois que le système aura confirmé la modification.';

  @override
  String get reportsExportEvidenceDialogTitle => 'Exporter des preuves';

  @override
  String get reportsExportEvidenceDialogBody =>
      'Generate un établissement-branded evidence document de ce audit dossier.';

  @override
  String get reportsSavedMessage => 'Reports espace de travail mis à jour.';

  @override
  String get reportsDownloadRequestedMessage =>
      'Le téléchargement du rapport a été demandé.';

  @override
  String get reportsPrintSubtitle => 'Generated rapport metadata';

  @override
  String get reportsEvidenceSubtitle => 'Preuve de conformité';

  @override
  String get reportsGeneratedByLabel => 'Généré par';

  @override
  String get reportsPrintFooter =>
      'Confidential rapport document generated de system data.';

  @override
  String get reportsEvidenceFooter =>
      'Compliance evidence generated de audit data.';

  @override
  String get navigationPhysiotherapyLabel => 'Physiothérapie';

  @override
  String get navigationPhysiotherapyShortLabel => 'Physiothérapie';

  @override
  String get communicationsLoadingTitle => 'Chargement des communications';

  @override
  String get communicationsLoadingBody =>
      'Loading notifications, conversations, delivery state, et modèles.';

  @override
  String get communicationsWorkspaceTitle => 'Communications';

  @override
  String get communicationsLiveStatus => 'Live synchronisation';

  @override
  String get communicationsSavingStatus => 'Enregistrement';

  @override
  String get communicationsActionSavedMessage =>
      'Action de communication enregistrée.';

  @override
  String get communicationsMessageSentMessage => 'Message envoyé.';

  @override
  String get communicationsInboxPanelLabel => 'Messages';

  @override
  String get communicationsMessagesPanelLabel => 'Messages';

  @override
  String get communicationsNotificationsPanelLabel => 'Notifications';

  @override
  String get communicationsDeliveriesPanelLabel => 'Livraisons';

  @override
  String get communicationsTemplatesPanelLabel => 'Modèles';

  @override
  String get communicationsUnreadThreadsSummaryLabel => 'Sujets non lus';

  @override
  String get communicationsUnreadNotificationsSummaryLabel =>
      'Alertes non lues';

  @override
  String get communicationsFailedDeliveriesSummaryLabel =>
      'Livraisons échouées';

  @override
  String get communicationsTemplatesSummaryLabel => 'Modèles';

  @override
  String get communicationsListDescription =>
      'Find alerts, threads, delivery state, et message modèles.';

  @override
  String get communicationsSearchSemanticLabel =>
      'Rechercher des communications';

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
  String get communicationsQueueFilterLabel => 'File d’attente';

  @override
  String get communicationsFlagsFilterLabel => 'Drapeaux';

  @override
  String get communicationsAllFilterLabel => 'Tous';

  @override
  String get communicationsUnreadFilterLabel => 'Non lu';

  @override
  String get communicationsSensitiveFilterLabel => 'Sensible';

  @override
  String get communicationsPreviousPageLabel =>
      'Page de communication précédente';

  @override
  String get communicationsNextPageLabel => 'Page de communication suivante';

  @override
  String communicationsPageLabel(int from, int to, int total) {
    return '$from-$to sur $total';
  }

  @override
  String get communicationsThreadColumnLabel => 'Fil';

  @override
  String get communicationsParticipantsColumnLabel => 'Participants';

  @override
  String get communicationsStatusColumnLabel => 'Statut';

  @override
  String get communicationsLastMessageColumnLabel => 'Dernier message';

  @override
  String get communicationsTimeColumnLabel => 'Heure';

  @override
  String get communicationsAlertColumnLabel => 'Alerte';

  @override
  String get communicationsTypeColumnLabel => 'Taper';

  @override
  String get communicationsPriorityColumnLabel => 'Priorité';

  @override
  String get communicationsStateColumnLabel => 'État';

  @override
  String get communicationsNotificationColumnLabel => 'Notification';

  @override
  String get communicationsChannelColumnLabel => 'Canal';

  @override
  String get communicationsRecipientColumnLabel => 'Destinataire';

  @override
  String get communicationsAttemptsColumnLabel => 'Tentatives';

  @override
  String get communicationsTemplateColumnLabel => 'Modèle';

  @override
  String get communicationsVariablesColumnLabel => 'Variables';

  @override
  String get communicationsNoConversationsTitle => 'Aucune conversation';

  @override
  String get communicationsNoConversationsBody =>
      'Les fils de conversation correspondants apparaîtront ici.';

  @override
  String get communicationsNoNotificationsTitle => 'Aucune notification';

  @override
  String get communicationsNoNotificationsBody =>
      'Les alertes et rappels de flux de travail correspondants apparaîtront ici.';

  @override
  String get communicationsNoDeliveriesTitle => 'Aucune livraison';

  @override
  String get communicationsNoDeliveriesBody =>
      'Les tentatives de livraison par le canal de notification apparaîtront ici.';

  @override
  String get communicationsNoTemplatesTitle => 'No modèles';

  @override
  String get communicationsNoTemplatesBody =>
      'Des modèles de communication réutilisables apparaîtront ici.';

  @override
  String get communicationsConversationDetailTitle =>
      'Détail de la conversation';

  @override
  String get communicationsNotificationDetailTitle =>
      'Détails des notifications';

  @override
  String get communicationsDeliveryDetailTitle => 'Détail de la livraison';

  @override
  String get communicationsTemplateDetailTitle => 'Détail du modèle';

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
  String get communicationsSubjectLabel => 'Sujet';

  @override
  String get communicationsParticipantsLabel => 'Participants';

  @override
  String get communicationsCreatedAtLabel => 'Créé à';

  @override
  String get communicationsUpdatedAtLabel => 'Mis à jour à';

  @override
  String get communicationsReadAtLabel => 'Lire à';

  @override
  String get communicationsTypeLabel => 'Taper';

  @override
  String get communicationsContextLabel => 'Contexte';

  @override
  String get communicationsNotificationLabel => 'Notification';

  @override
  String get communicationsChannelLabel => 'Canal';

  @override
  String get communicationsRecipientLabel => 'Destinataire';

  @override
  String get communicationsAttemptsLabel => 'Tentatives';

  @override
  String get communicationsProviderLabel => 'Fournisseur';

  @override
  String get communicationsSentAtLabel => 'Envoyé à';

  @override
  String get communicationsDeliveredAtLabel => 'Livré à';

  @override
  String get communicationsFailedAtLabel => 'Échec à';

  @override
  String get communicationsStatusLabel => 'Statut';

  @override
  String get communicationsVariablesLabel => 'Variables';

  @override
  String get communicationsPreviewTitle => 'Aperçu';

  @override
  String get communicationsMessageThreadTitle => 'Fil de discussion';

  @override
  String get communicationsNoMessagesBody =>
      'Aucun message n\'est disponible pour ce fil.';

  @override
  String get communicationsDeliveryHistoryTitle => 'Delivery historique';

  @override
  String get communicationsDeliveryErrorTitle => 'Delivery erreur';

  @override
  String get communicationsOpenLinkedRecordAction =>
      'Ouvrir l\'enregistrement lié';

  @override
  String get communicationsMarkReadAction => 'Marquer comme lu';

  @override
  String get communicationsMarkUnreadAction => 'Marquer comme non lu';

  @override
  String get communicationsArchiveAction => 'Archiver';

  @override
  String get communicationsUnarchiveAction => 'Désarchiver';

  @override
  String get communicationsSendMessageAction => 'Envoyer un message';

  @override
  String get communicationsSendMessageDialogTitle => 'Envoyer un message';

  @override
  String get communicationsMessageFieldLabel => 'Message';

  @override
  String get communicationsMarkReadDialogTitle => 'Marquer comme lu';

  @override
  String get communicationsMarkUnreadDialogTitle => 'Marquer comme non lu';

  @override
  String get communicationsArchiveDialogTitle => 'Communication d\'archives';

  @override
  String get communicationsUnarchiveDialogTitle =>
      'Désarchiver la conversation';

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
  String get communicationsUnreadStatus => 'Non lu';

  @override
  String get communicationsReadStatus => 'Lire';

  @override
  String get communicationsArchivedStatus => 'Archivé';

  @override
  String get communicationsSensitiveStatus => 'Sensible';

  @override
  String get communicationsActiveStatus => 'Actif';

  @override
  String get communicationsInactiveStatus => 'Inactif';

  @override
  String get communicationsJustNowLabel => 'Tout à l\' heure';

  @override
  String communicationsMinutesAgoLabel(int minutes) {
    return '${minutes}il y a m';
  }

  @override
  String communicationsHoursAgoLabel(int hours) {
    return '${hours}il y a h';
  }

  @override
  String communicationsDaysAgoLabel(int days) {
    return '${days}il y a';
  }

  @override
  String get communicationsAttachFileAction => 'Joindre un fichier';

  @override
  String get communicationsNewMessageAction => 'Nouveau message';

  @override
  String get communicationsNewGroupAction => 'Nouveau groupe';

  @override
  String get communicationsFavoritesFilterLabel => 'Favoris';

  @override
  String get communicationsFlaggedFilterLabel => 'Marqué';

  @override
  String get communicationsArchivedFilterLabel => 'Archivé';

  @override
  String get communicationsSentFilterLabel => 'Envoyé';

  @override
  String get communicationsReadFilterLabel => 'Lire';

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
      'Certains filtres sont appliqués localement jusqu\'à ce que la prise en charge du serveur soit disponible.';

  @override
  String get communicationsLoadMoreAction => 'Charger plus';

  @override
  String get communicationsBackToInboxAction => 'Back à inbox';

  @override
  String communicationsGroupMembersLabel(int count) {
    return '${count}members';
  }

  @override
  String get communicationsThreadMenuAction => 'Actions de conversation';

  @override
  String get communicationsFavoriteAction => 'Préféré';

  @override
  String get communicationsUnfavoriteAction => 'Supprimer le favori';

  @override
  String get communicationsFlagAction => 'Drapeau';

  @override
  String get communicationsUnflagAction => 'Supprimer le drapeau';

  @override
  String get communicationsManageMembersAction => 'Gérer les membres';

  @override
  String get communicationsManageMembersTitle => 'Gérer les membres';

  @override
  String get communicationsAddMemberLabel => 'Ajouter un membre';

  @override
  String get communicationsAddMemberAction => 'Ajouter un membre';

  @override
  String communicationsLastReadLabel(String timestamp) {
    return 'Last read$timestamp';
  }

  @override
  String get communicationsStartConversationAction =>
      'Démarrer une conversation';

  @override
  String get communicationsGroupNameLabel => 'Group nom';

  @override
  String get communicationsSensitiveConversationLabel =>
      'Conversation sensible';

  @override
  String get communicationsCreateGroupAction => 'Créer un groupe';

  @override
  String get housekeepingTitle => 'Ménage';

  @override
  String get housekeepingLoadingTitle => 'Loading entretien';

  @override
  String get housekeepingLoadingBody =>
      'Preparing cleaning tasks, schedules, lit turnover, et readiness.';

  @override
  String get housekeepingLiveStatus => 'Live synchronisation';

  @override
  String get housekeepingSavingStatus => 'Enregistrement';

  @override
  String get housekeepingSavedMessage =>
      'Modifications d\'entretien enregistrées.';

  @override
  String get housekeepingCreateTaskAction => 'Créer une tâche';

  @override
  String get housekeepingCreateScheduleAction => 'Create planning';

  @override
  String get housekeepingRequestMaintenanceAction => 'Demander une maintenance';

  @override
  String get housekeepingReportSummaryAction => 'Rapport';

  @override
  String get housekeepingPendingTasksSummaryLabel => 'Tâches en attente';

  @override
  String get housekeepingCompletedTodaySummaryLabel => 'Completed aujourd\'hui';

  @override
  String get housekeepingOpenRequestsSummaryLabel => 'Demandes ouvertes';

  @override
  String get housekeepingOverdueRequestsSummaryLabel => 'Overdue demandes';

  @override
  String get housekeepingAssetsSummaryLabel => 'Actifs';

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
  String get housekeepingPreviousPageLabel => 'Page précédente';

  @override
  String get housekeepingNextPageLabel => 'Page suivante';

  @override
  String housekeepingPageLabel(int first, int last, int total) {
    return '${first}J${last}sur$totaléléments';
  }

  @override
  String get housekeepingEmptyQueueTitle => 'No entretien éléments';

  @override
  String get housekeepingEmptyQueueBody =>
      'No tasks, schedules, ou maintenance passations match le actuel filtres.';

  @override
  String get housekeepingTaskColumnLabel => 'Tâche';

  @override
  String get housekeepingLocationColumnLabel => 'Emplacement';

  @override
  String get housekeepingAssigneeColumnLabel => 'Cessionnaire';

  @override
  String get housekeepingDueColumnLabel => 'Due heure';

  @override
  String get housekeepingStatusColumnLabel => 'Statut';

  @override
  String get housekeepingNextActionColumnLabel => 'Prochaine action';

  @override
  String get housekeepingNoSelectionTitle => 'Select un entretien élément';

  @override
  String get housekeepingNoSelectionBody =>
      'Choose un task, planning, ou maintenance passation à review readiness et disponible actions.';

  @override
  String get housekeepingDetailTitle => 'Détail du ménage';

  @override
  String get housekeepingReferenceLabel => 'Référence';

  @override
  String get housekeepingLocationLabel => 'Emplacement';

  @override
  String get housekeepingAssigneeLabel => 'Cessionnaire';

  @override
  String get housekeepingDueLabel => 'Echéance';

  @override
  String get housekeepingReadinessTitle => 'Préparation';

  @override
  String get housekeepingAssignAction => 'Attribuer';

  @override
  String get housekeepingStartAction => 'Commencer';

  @override
  String get housekeepingStartDialogTitle => 'Commencer le nettoyage';

  @override
  String get housekeepingStartDialogBody =>
      'Mark ce entretien task as in progress.';

  @override
  String get housekeepingCompleteAction => 'Complet';

  @override
  String get housekeepingCompleteDialogTitle => 'Nettoyage complet';

  @override
  String get housekeepingCompleteDialogBody =>
      'Mark ce cleaning task as terminé et actualiser readiness.';

  @override
  String get housekeepingCancelAction => 'Annuler';

  @override
  String get housekeepingCancelDialogTitle => 'Annuler la tâche';

  @override
  String get housekeepingCancelDialogBody => 'Cancel ce entretien task.';

  @override
  String get housekeepingMarkReadyAction => 'Marquer comme prêt';

  @override
  String get housekeepingBackendGapTooltip =>
      'Ce flux de travail n\'est pas encore disponible.';

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
      'La progression et l\'état de préparation du nettoyage sont actualisés à partir de l\'enregistrement des tâches d\'entretien ménager.';

  @override
  String get housekeepingScheduleReadinessBody =>
      'Scheduled cleaning keeps ce location on un recurring readiness forfait.';

  @override
  String get housekeepingMaintenanceReadinessBody =>
      'Maintenance passations keep cleaning issues visible sans losing location context.';

  @override
  String get housekeepingUnavailableWorkflowsTitle =>
      'Flux de travail indisponibles';

  @override
  String get housekeepingUnavailableWorkflowsBody =>
      'Ce espace de travail only exposes actions disponible pour le actuel établissement.';

  @override
  String get housekeepingFacilityFieldLabel => 'Établissement';

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
  String get housekeepingScheduledDateFieldLabel => 'Date prévue';

  @override
  String get housekeepingCreateTaskSubmitAction => 'Créer une tâche';

  @override
  String get housekeepingFrequencyFieldLabel => 'Fréquence';

  @override
  String get housekeepingFrequencyFieldHint =>
      'Daily, weekly, terminal clean, ou personnalisé';

  @override
  String get housekeepingFrequencyRequiredMessage =>
      'Enter un cleaning frequency.';

  @override
  String get housekeepingStartDateFieldLabel => 'Date de début';

  @override
  String get housekeepingEndDateFieldLabel => 'Date de fin';

  @override
  String get housekeepingCreateScheduleSubmitAction => 'Create planning';

  @override
  String get housekeepingAssetFieldLabel => 'Actif';

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
  String get housekeepingAssignSubmitAction => 'Enregistrer le devoir';

  @override
  String get housekeepingTriageSummaryFieldLabel => 'Note de tri';

  @override
  String get housekeepingSlaHoursFieldLabel => 'Horaires SLA';

  @override
  String get housekeepingTriageSubmitAction => 'Enregistrer le tri';

  @override
  String get housekeepingPickDateAction => 'Choisir la date';

  @override
  String get housekeepingCreateTaskDialogTitle => 'Create entretien task';

  @override
  String get housekeepingCreateScheduleDialogTitle =>
      'Create cleaning planning';

  @override
  String get housekeepingRequestMaintenanceDialogTitle =>
      'Demander une maintenance';

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
      'Les modèles de rapports d’entretien générés ne sont pas encore disponibles.';

  @override
  String get housekeepingResourceFilterLabel => 'Ressource';

  @override
  String get housekeepingResourceTasks => 'Tâches';

  @override
  String get housekeepingResourceSchedules => 'Horaires';

  @override
  String get housekeepingResourceMaintenanceRequests => 'Maintenance demandes';

  @override
  String get housekeepingQueueFilterLabel => 'File d’attente';

  @override
  String get housekeepingQueueAll => 'Tous';

  @override
  String get housekeepingQueueToday => 'Aujourdh’ui';

  @override
  String get housekeepingQueueOverdueTasks => 'Tâches en retard';

  @override
  String get housekeepingQueueOpenRequests => 'Demandes ouvertes';

  @override
  String get housekeepingQueueOverdueRequests => 'Overdue demandes';

  @override
  String get housekeepingStatusFilterLabel => 'Statut';

  @override
  String get housekeepingStatusAll => 'Tous les statuts';

  @override
  String get housekeepingAllFacilities => 'All établissements';

  @override
  String get housekeepingFacilityFilterLabel => 'Établissement';

  @override
  String get housekeepingRoomFilterLabel => 'Room ou lit';

  @override
  String get housekeepingAllRooms => 'All chambres et lits';

  @override
  String get housekeepingAssigneeFilterLabel => 'Cessionnaire';

  @override
  String get housekeepingAllAssignees => 'Tous les assignés';

  @override
  String get housekeepingDateFilterLabel => 'Date';

  @override
  String get housekeepingDateAll => 'N\'importe quelle date';

  @override
  String get housekeepingDateToday => 'Aujourdh’ui';

  @override
  String get housekeepingDateNextSevenDays => '7 prochains jours';

  @override
  String get housekeepingDateOverdue => 'Impayé';

  @override
  String get housekeepingDateThisMonth => 'Ce month';

  @override
  String get housekeepingStatusScheduled => 'Planifié';

  @override
  String get housekeepingStatusPending => 'En attente';

  @override
  String get housekeepingStatusInProgress => 'En cours';

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
  String get housekeepingStatusInProgressLabel => 'En cours';

  @override
  String get housekeepingNextActionAssign => 'Assign personnel ou team';

  @override
  String get housekeepingNextActionStart => 'Commencer le nettoyage';

  @override
  String get housekeepingNextActionComplete => 'Nettoyage complet';

  @override
  String get housekeepingNextActionTriage => 'Triage passation';

  @override
  String get housekeepingNextActionReviewSchedule => 'Review planning';

  @override
  String get housekeepingNextActionNoAction => 'Aucune action nécessaire';

  @override
  String get housekeepingNextActionView => 'View détails';

  @override
  String get housekeepingLocationNotSet => 'Emplacement non défini';

  @override
  String get housekeepingNotRecorded => 'Non enregistré';

  @override
  String get housekeepingUnassigned => 'Non attribué';

  @override
  String get physiotherapyTitle => 'Physiothérapie';

  @override
  String get physiotherapyLoadingTitle =>
      'Loading physiothérapie espace de travail';

  @override
  String get physiotherapyLoadingBody =>
      'Preparing orientations, sessions, soins forfaits, notes, et follow-ups.';

  @override
  String get physiotherapyLiveStatus => 'Direct';

  @override
  String get physiotherapySavingStatus => 'Enregistrement';

  @override
  String get physiotherapySavedMessage => 'Physiotherapy dossier saved.';

  @override
  String get physiotherapyReferralsSummaryLabel => 'Références';

  @override
  String get physiotherapyTodaySummaryLabel => 'Aujourdh’ui';

  @override
  String get physiotherapyMissedSummaryLabel => 'Manqué';

  @override
  String get physiotherapyActivePlansSummaryLabel => 'Active forfaits';

  @override
  String get physiotherapyFollowUpDueSummaryLabel => 'Suivi à prévoir';

  @override
  String get physiotherapyCompletedSummaryLabel => 'Terminé';

  @override
  String get physiotherapyWorklistTitle => 'Liste de travail thérapeutique';

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
  String get physiotherapySearchFieldLabel => 'Rechercher dans';

  @override
  String get physiotherapyAllFieldsLabel => 'All champs';

  @override
  String get physiotherapyDateFilterLabel => 'Date';

  @override
  String get physiotherapyDateFromLabel => 'Du';

  @override
  String get physiotherapyDateToLabel => 'A';

  @override
  String get physiotherapyTherapistFilterLabel => 'Thérapeute';

  @override
  String get physiotherapyTherapistFilterHint =>
      'Therapist nom ou utilisateur ID';

  @override
  String get physiotherapyQueueFilterLabel => 'File d’attente';

  @override
  String get physiotherapyFilterAll => 'Tous';

  @override
  String get physiotherapyScopeReferrals => 'Références';

  @override
  String get physiotherapyScopeToday => 'Aujourdh’ui';

  @override
  String get physiotherapyScopeMissed => 'Manqué';

  @override
  String get physiotherapyScopeActivePlans => 'Active forfaits';

  @override
  String get physiotherapyScopeFollowUpDue => 'Suivi à prévoir';

  @override
  String get physiotherapyScopeCompleted => 'Terminé';

  @override
  String get physiotherapyScopeAll => 'Tous les travaux';

  @override
  String get physiotherapyPatientColumnLabel => 'Patient';

  @override
  String get physiotherapySourceColumnLabel => 'Source';

  @override
  String get physiotherapySessionColumnLabel => 'Session';

  @override
  String get physiotherapyStatusColumnLabel => 'Statut';

  @override
  String get physiotherapyPlanColumnLabel => 'Forfait';

  @override
  String get physiotherapyAttendanceColumnLabel => 'Présence';

  @override
  String get physiotherapyBillingColumnLabel => 'Facturation';

  @override
  String get physiotherapyTherapistColumnLabel => 'Thérapeute';

  @override
  String get physiotherapyNextActionColumnLabel => 'Prochaine action';

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
  String get physiotherapyPatientNumberLabel => 'Numéro de patient';

  @override
  String get physiotherapyEncounterLabel => 'Rencontre';

  @override
  String get physiotherapySessionLabel => 'Session';

  @override
  String get physiotherapyTherapistLabel => 'Thérapeute';

  @override
  String get physiotherapyBillingAuthorizationLabel =>
      'Autorisation de facturation';

  @override
  String get physiotherapyActionsTitle => 'Actions thérapeutiques';

  @override
  String get physiotherapyReferralPanelTitle => 'Referral et forfait';

  @override
  String get physiotherapySourceLabel => 'Source';

  @override
  String get physiotherapyStatusLabel => 'Statut';

  @override
  String get physiotherapyAttendanceLabel => 'Présence';

  @override
  String get physiotherapyPlanLabel => 'Forfait';

  @override
  String get physiotherapyGoalLabel => 'But';

  @override
  String get physiotherapyInstructionsLabel => 'Consignes';

  @override
  String get physiotherapySessionsPanelTitle => 'Session historique';

  @override
  String get physiotherapyPlanPanelTitle => 'Care forfait';

  @override
  String get physiotherapyProgressNotesPanelTitle => 'Notes d\'avancement';

  @override
  String get physiotherapyFollowUpPanelTitle => 'Suivis';

  @override
  String get physiotherapyBackendGapsPanelTitle =>
      'Flux de travail indisponibles';

  @override
  String get physiotherapyBackendGapBody =>
      'Ce espace de travail uses disponible shared clinique dossiers et lists indisponible dedicated physiothérapie workflows here.';

  @override
  String get physiotherapyNoRecordsLabel => 'No dossiers yet.';

  @override
  String get physiotherapyNoInstructionsLabel =>
      'Aucune instruction thérapeutique enregistrée.';

  @override
  String get physiotherapyAcceptReferralAction => 'Accepter la référence';

  @override
  String get physiotherapyScheduleSessionAction => 'Planifier une séance';

  @override
  String get physiotherapyRecordAssessmentAction => 'Évaluation du dossier';

  @override
  String get physiotherapyRecordSessionAction => 'Session d\'enregistrement';

  @override
  String get physiotherapyMarkAttendanceAction => 'Marquer la présence';

  @override
  String get physiotherapyUpdatePlanAction => 'Update forfait';

  @override
  String get physiotherapyAddProgressNoteAction =>
      'Ajouter une note de progression';

  @override
  String get physiotherapyScheduleFollowUpAction => 'Suivi du calendrier';

  @override
  String get physiotherapyCloseEpisodeAction => 'Fermer l\'épisode';

  @override
  String get physiotherapyPrintInstructionsAction =>
      'Imprimer les instructions';

  @override
  String get physiotherapyAcceptReferralDialogTitle =>
      'Accepter une référence en physiothérapie';

  @override
  String get physiotherapyScheduleSessionDialogTitle =>
      'Programmer une séance de thérapie';

  @override
  String get physiotherapyRecordAssessmentDialogTitle =>
      'Évaluation de la thérapie par dossiers';

  @override
  String get physiotherapyRecordSessionDialogTitle =>
      'Séance de thérapie par disques';

  @override
  String get physiotherapyMarkAttendanceDialogTitle =>
      'Marquer la participation à la session';

  @override
  String get physiotherapyUpdatePlanDialogTitle => 'Update therapy forfait';

  @override
  String get physiotherapyAddProgressNoteDialogTitle =>
      'Ajouter une note de progression';

  @override
  String get physiotherapyScheduleFollowUpDialogTitle => 'Suivi du calendrier';

  @override
  String get physiotherapyCloseEpisodeDialogTitle =>
      'Épisode de thérapie rapprochée';

  @override
  String get physiotherapyNoteFieldLabel => 'Note';

  @override
  String get physiotherapyReasonFieldLabel => 'Raison';

  @override
  String get physiotherapyAssessmentFieldLabel => 'Évaluation';

  @override
  String get physiotherapyGoalsFieldLabel => 'Objectifs';

  @override
  String get physiotherapyPlanFieldLabel => 'Forfait';

  @override
  String get physiotherapyInstructionsFieldLabel => 'Consignes';

  @override
  String get physiotherapySessionNoteFieldLabel => 'Note de séance';

  @override
  String get physiotherapyAttendanceStatusFieldLabel => 'Attendance statut';

  @override
  String get physiotherapySummaryFieldLabel => 'Résumé';

  @override
  String get physiotherapyStartDateFieldLabel => 'Date de début';

  @override
  String get physiotherapyStartTimeFieldLabel => 'Start heure';

  @override
  String get physiotherapyEndDateFieldLabel => 'Date de fin';

  @override
  String get physiotherapyEndTimeFieldLabel => 'End heure';

  @override
  String get physiotherapyDateFieldLabel => 'Date';

  @override
  String get physiotherapyTimeFieldLabel => 'Heure';

  @override
  String get physiotherapySaveAction => 'Enregistrer';

  @override
  String get physiotherapyStatusReferral => 'Référence';

  @override
  String get physiotherapyStatusAccepted => 'Accepted';

  @override
  String get physiotherapyStatusAssessment => 'Évaluation';

  @override
  String get physiotherapyStatusToday => 'Aujourdh’ui';

  @override
  String get physiotherapyStatusInTreatment => 'In traitement';

  @override
  String get physiotherapyStatusActivePlan => 'Active forfait';

  @override
  String get physiotherapyStatusFollowUpDue => 'Suivi à prévoir';

  @override
  String get physiotherapyStatusMissed => 'Manqué';

  @override
  String get physiotherapyStatusCompleted => 'Terminé';

  @override
  String get physiotherapyUnknownStatusLabel => 'Inconnu';

  @override
  String get physiotherapySourceReferral => 'Référence';

  @override
  String get physiotherapySourceAppointment => 'Rendez-vous';

  @override
  String get physiotherapySourceCarePlan => 'Care forfait';

  @override
  String get physiotherapySourceProcedure => 'Procédure';

  @override
  String get physiotherapySourceUnknown => 'Source inconnue';

  @override
  String get physiotherapyAttendanceScheduled => 'Planifié';

  @override
  String get physiotherapyAttendanceConfirmed => 'Confirmé';

  @override
  String get physiotherapyAttendanceInProgress => 'En cours';

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
  String get physiotherapyMissingValueLabel => 'Non enregistré';

  @override
  String get physiotherapyBackendGapStatusEndpoint =>
      'L\'épisode de physiothérapie dédié et le statut thérapeutique ne sont pas disponibles. Le statut découle des procédures, des plans de soins, des rendez-vous et des suivis.';

  @override
  String get physiotherapyBackendGapBillingEndpoint =>
      'L\'autorisation de facturation n\'est pas disponible pour ce contexte de physiothérapie.';

  @override
  String get physiotherapyBackendGapReportEndpoint =>
      'Les rapports d’évaluation de physiothérapie et de sortie générés ne sont pas disponibles. L\'impression utilise le modèle de rapport partagé.';

  @override
  String get physiotherapyBackendGapUnknown =>
      'Un flux de travail de physiothérapie indisponible a été enregistré.';

  @override
  String get physiotherapyInstructionsReportTitle =>
      'Instructions de physiothérapie';

  @override
  String get physiotherapyReportPatientLabel => 'Patient';

  @override
  String get physiotherapyReportEncounterLabel => 'Rencontre';

  @override
  String get physiotherapyReportPlanLabel => 'Plan et goals';

  @override
  String get physiotherapyReportInstructionsLabel => 'Consignes';

  @override
  String get physiotherapyReportSessionsLabel => 'Séances';

  @override
  String get physiotherapyReportFooterNote =>
      'Généré à partir de données de flux de travail cliniques partagées.';

  @override
  String get mortuaryTitle => 'Morgue';

  @override
  String get mortuaryLoadErrorTitle =>
      'Mortuary espace de travail indisponible';

  @override
  String get mortuaryLoadErrorBody =>
      'L\'espace de travail mortuaire n\'a pas pu être chargé. Réessayez ou contactez un administrateur si le problème persiste.';

  @override
  String get mortuaryLoadingTitle => 'Loading morgue espace de travail';

  @override
  String get mortuaryLoadingBody =>
      'Retrieving cases, storage, custody, release, et billing information.';

  @override
  String get mortuaryOperationalStatusLabel => 'Opérationnel';

  @override
  String get mortuaryAttentionStatusLabel => 'A besoin d\'attention';

  @override
  String get mortuaryPrintDocumentsAction => 'Imprimer des documents';

  @override
  String get mortuaryReceiveCaseAction => 'Recevoir le dossier';

  @override
  String get mortuaryAssignStorageAction => 'Attribuer du stockage';

  @override
  String get mortuaryRecordCustodyAction => 'Garde des dossiers';

  @override
  String get mortuaryScheduleViewingAction => 'Planifier la visualisation';

  @override
  String get mortuaryPostMortemAction => 'Étape post-mortem';

  @override
  String get mortuaryRequestBillingAction => 'Demander une facturation';

  @override
  String get mortuaryApproveReleaseAction => 'Approuver la version';

  @override
  String get mortuaryConfirmReleaseAction => 'Confirmer la sortie';

  @override
  String get mortuaryActionsUnavailableTooltip =>
      'Cette action n\'est pas encore disponible.';

  @override
  String get mortuaryWorklistTitle => 'Liste de travail mortuaire';

  @override
  String get mortuaryWorklistEmptyTitle => 'Aucun mortuary records trouvé';

  @override
  String get mortuaryWorklistEmptyBody =>
      'Adjust le filtres ou recherche terms à voir matching morgue dossiers.';

  @override
  String get mortuaryReferenceColumnLabel => 'Affaire';

  @override
  String get mortuaryDeceasedColumnLabel => 'Décédé';

  @override
  String get mortuarySourceColumnLabel => 'Source';

  @override
  String get mortuaryStorageColumnLabel => 'Stockage';

  @override
  String get mortuaryStatusColumnLabel => 'Statut';

  @override
  String get mortuaryDateColumnLabel => 'Date';

  @override
  String get mortuaryNextActionColumnLabel => 'Prochaine action';

  @override
  String get mortuaryPreviousPageLabel => 'Page précédente';

  @override
  String get mortuaryNextPageLabel => 'Page suivante';

  @override
  String mortuaryPageLabel(int from, int to, int total) {
    return 'Affichage de $from-$to sur $total';
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
  String get mortuaryApplyFiltersAction => 'Appliquer';

  @override
  String get mortuaryResetFiltersAction => 'Réinitialiser';

  @override
  String get mortuaryAllFieldsLabel => 'Tous';

  @override
  String get mortuaryDateFilterLabel => 'Date';

  @override
  String get mortuaryDateFromLabel => 'Du';

  @override
  String get mortuaryDateToLabel => 'A';

  @override
  String get mortuaryDatePickerButtonLabel => 'Choisissez une date';

  @override
  String get mortuaryInvalidDateMessage => 'Enter un valid date.';

  @override
  String get mortuaryPanelFilterLabel => 'Panneau';

  @override
  String get mortuaryResourceFilterLabel => 'Ressource';

  @override
  String get mortuaryQueueFilterLabel => 'File d’attente';

  @override
  String get mortuaryStatusFilterLabel => 'Statut';

  @override
  String get mortuaryIdentificationFilterLabel => 'Identification';

  @override
  String get mortuaryFacilityFilterLabel => 'Établissement';

  @override
  String get mortuaryStorageUnitFilterLabel => 'Storage unité';

  @override
  String get mortuaryStorageSlotFilterLabel => 'Emplacement de stockage';

  @override
  String get mortuaryDatePresetFilterLabel => 'Date prédéfinie';

  @override
  String get mortuaryDatePresetTodayLabel => 'Aujourdh’ui';

  @override
  String get mortuaryDatePresetNext7DaysLabel => '7 prochains jours';

  @override
  String get mortuaryDatePresetOverdueLabel => 'Impayé';

  @override
  String get mortuaryDatePresetThisMonthLabel => 'Ce month';

  @override
  String get mortuaryTotalCasesSummaryLabel => 'Total des cas';

  @override
  String get mortuaryIdentificationPendingSummaryLabel =>
      'Identification en attente';

  @override
  String get mortuaryInStorageSummaryLabel => 'En stockage';

  @override
  String get mortuaryReleaseReadySummaryLabel => 'Sortie prête';

  @override
  String get mortuaryUnsettledBillingSummaryLabel => 'Facturation non réglée';

  @override
  String get mortuaryPanelOverviewLabel => 'Présentation';

  @override
  String get mortuaryPanelIntakeLabel => 'Admission';

  @override
  String get mortuaryPanelStorageLabel => 'Stockage';

  @override
  String get mortuaryPanelCustodyLabel => 'Garde à vue';

  @override
  String get mortuaryPanelReleaseLabel => 'Libérer';

  @override
  String get mortuaryPanelReportingLabel => 'Rapports';

  @override
  String get mortuaryResourceCasesLabel => 'Cas';

  @override
  String get mortuaryResourceStorageUnitsLabel => 'Storage unités';

  @override
  String get mortuaryResourceStorageSlotsLabel => 'Emplacements de stockage';

  @override
  String get mortuaryResourceStorageAssignmentsLabel => 'Missions de stockage';

  @override
  String get mortuaryResourceCustodyEventsLabel => 'Événements de garde';

  @override
  String get mortuaryResourceViewingsLabel => 'Visites';

  @override
  String get mortuaryResourcePostMortemRequestsLabel => 'Post-mortem demandes';

  @override
  String get mortuaryResourceReleaseAuthorisationsLabel =>
      'Autorisations de libération';

  @override
  String get mortuaryResourceBillableEventsLabel => 'Événements facturables';

  @override
  String get mortuaryQueueIdentificationPendingLabel =>
      'Identification en attente';

  @override
  String get mortuaryQueueStorageExceptionsLabel => 'Exceptions de stockage';

  @override
  String get mortuaryQueueReleaseReadyLabel => 'Sortie prête';

  @override
  String get mortuaryQueueUnsettledBillingLabel => 'Facturation non réglée';

  @override
  String get mortuaryQueuePostMortemPendingLabel => 'Post-mortem en attente';

  @override
  String get mortuaryDetailTitle => 'Détail du cas';

  @override
  String get mortuaryNoSelectionTitle => 'Select un case';

  @override
  String get mortuaryNoSelectionBody =>
      'Choose un dossier de le worklist à review identity, storage, custody, release, billing, et documents.';

  @override
  String get mortuaryUnknownDeceasedLabel => 'Nom non enregistré';

  @override
  String get mortuaryUnknownValueLabel => 'Non enregistré';

  @override
  String get mortuaryCaseNumberLabel => 'Numéro de dossier';

  @override
  String get mortuaryDeceasedContextLabel => 'Contexte de la personne décédée';

  @override
  String get mortuaryIdentificationFieldLabel => 'Identification';

  @override
  String get mortuaryBillingFieldLabel => 'Facturation';

  @override
  String get mortuaryStorageSlotFieldLabel => 'Emplacement de stockage';

  @override
  String get mortuaryFacilityFieldLabel => 'Établissement';

  @override
  String get mortuaryActionGapTitle => 'Actions indisponible';

  @override
  String get mortuaryActionGapBody =>
      'Des données de recherche mortuaire sont disponibles. Les boutons d\'action restent désactivés jusqu\'à ce que le flux de travail soit activé pour cette fonction.';

  @override
  String get mortuaryIdentitySectionTitle => 'Identity et source';

  @override
  String get mortuaryStorageSectionTitle => 'Stockage';

  @override
  String get mortuaryCustodySectionTitle => 'Journal de garde';

  @override
  String get mortuaryViewingSectionTitle => 'Affichage';

  @override
  String get mortuaryPostMortemSectionTitle => 'Autopsie';

  @override
  String get mortuaryReleaseSectionTitle => 'Libérer';

  @override
  String get mortuaryBillingSectionTitle => 'Facturation';

  @override
  String get mortuaryDocumentsSectionTitle => 'Documents';

  @override
  String get mortuaryCaseFieldLabel => 'Affaire';

  @override
  String get mortuaryDeceasedFieldLabel => 'Décédé';

  @override
  String get mortuaryPatientFieldLabel => 'Patient';

  @override
  String get mortuaryStatusFieldLabel => 'Statut';

  @override
  String get mortuaryReceivedAtFieldLabel => 'Reçu';

  @override
  String get mortuarySourceWorkflowFieldLabel => 'Flux de travail source';

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
  String get mortuaryAssignedAtFieldLabel => 'Attribué';

  @override
  String get mortuaryActorFieldLabel => 'Acteur';

  @override
  String get mortuaryLocationFieldLabel => 'Emplacement';

  @override
  String get mortuaryNotesFieldLabel => 'Remarques';

  @override
  String get mortuaryReleaseFieldLabel => 'Libérer';

  @override
  String get mortuaryReleasedAtFieldLabel => 'Libéré';

  @override
  String get mortuaryNoCustodyEventsLabel =>
      'Aucun événement de garde enregistré';

  @override
  String get mortuaryNoCustodyEventsBody =>
      'Les mouvements de garde et les transferts apparaîtront ici une fois enregistrés.';

  @override
  String get mortuaryNoViewingsLabel => 'No viewings planifié';

  @override
  String get mortuaryNoViewingsBody =>
      'Les rendez-vous de visualisation apparaîtront ici lorsqu\'ils seront planifiés.';

  @override
  String get mortuaryNoPostMortemLabel => 'No post-mortem demande recorded';

  @override
  String get mortuaryNoPostMortemBody =>
      'Les demandes et rapports post-mortem apparaîtront ici lorsqu’ils seront disponibles.';

  @override
  String get mortuaryNoReleaseLabel => 'Aucune sortie enregistrée';

  @override
  String get mortuaryNoReleaseBody =>
      'Les autorisations de libération et les détails du transfert apparaîtront ici lorsqu’ils seront disponibles.';

  @override
  String get mortuaryNoBillingLabel =>
      'Aucun événement de facturation enregistré';

  @override
  String get mortuaryNoBillingBody =>
      'Les événements de facturation de stockage, post-mortem et de mise en production apparaîtront ici lorsqu\'ils seront disponibles.';

  @override
  String get mortuaryNoDocumentsBody =>
      'Les documents d\'admission, de garde, de libération et de facturation générés sont disponibles à partir de l\'action d\'impression lorsque les données du dossier sont sélectionnées.';

  @override
  String get mortuaryIntakeDocumentLabel => 'Formulaire d\'admission';

  @override
  String get mortuaryCustodyLogDocumentLabel => 'Journal de garde';

  @override
  String get mortuaryReleaseDocumentLabel => 'Autorisation de libération';

  @override
  String get mortuaryNextActionVerifyIdentity => 'Vérifier l\'identité';

  @override
  String get mortuaryNextActionAssignStorage => 'Attribuer du stockage';

  @override
  String get mortuaryNextActionPostMortem => 'Examen post-mortem';

  @override
  String get mortuaryNextActionClearBilling => 'Facturation claire';

  @override
  String get mortuaryNextActionApproveRelease => 'Approuver la version';

  @override
  String get mortuaryNextActionReleased => 'Libéré';

  @override
  String get mortuaryNextActionReview => 'Cas de révision';

  @override
  String get mortuaryReportTitle => 'Mortuary case dossier';

  @override
  String get mortuaryReportFooter =>
      'Generated de morgue espace de travail data.';

  @override
  String get mortuaryReportGeneratedMessage => 'Document mortuaire généré.';

  @override
  String get roomsBedsTitle => 'Rooms et lits';

  @override
  String get roomsBedsLoadingTitle => 'Loading chambres et lits';

  @override
  String get roomsBedsLoadingBody =>
      'Retrieving services, chambres, lits, assignments, et établissement context.';

  @override
  String get roomsBedsSavingStatus => 'Enregistrement';

  @override
  String get roomsBedsLiveStatus => 'Tableau en direct';

  @override
  String get roomsBedsTotalSummaryLabel => 'Total lits';

  @override
  String get roomsBedsBackendGapsTitle => 'Bed readiness statut indisponible';

  @override
  String get roomsBedsBackendGapsBody =>
      'Les états de nettoyage, de maintenance, de blocage, d’isolement et de préparation détaillés ne sont pas disponibles pour cette installation. Les actions actuelles utilisent uniquement les workflows de salle, de chambre, de lit, d\'attribution de lit et de flux IPD disponibles.';

  @override
  String get roomsBedsManageCatalogAction => 'Gérer le catalogue';

  @override
  String get roomsBedsOpenIpdAdmissionAction => 'Admission ouverte à l\'IPD';

  @override
  String get roomsBedsManageTransferAction => 'Manage transfert';

  @override
  String get roomsBedsTransferUpdateDialogTitle => 'Update transfert';

  @override
  String get roomsBedsOpenHousekeepingAction => 'Entretien ménager ouvert';

  @override
  String get roomsBedsOpenOperationsAction => 'Opérations ouvertes';

  @override
  String get roomsBedsMarkCleaningAction => 'Nettoyage des marques';

  @override
  String get roomsBedsMarkMaintenanceAction => 'Entretien des marques';

  @override
  String get roomsBedsMarkBlockedAction => 'Marquer bloqué';

  @override
  String get roomsBedsNextActionCompleteTransfer => 'Complete transfert';

  @override
  String get roomsBedsNextActionMarkAvailable => 'Mark disponible';

  @override
  String get roomsBedsNextActionResolveMaintenance => 'Résoudre la maintenance';

  @override
  String get roomsBedsCleaningReadinessLabel =>
      'En attente de chiffre d\'affaires';

  @override
  String get roomsBedsMaintenanceReadinessLabel => 'En maintenance';

  @override
  String get roomsBedsBlockedReadinessLabel => 'Bloqué';

  @override
  String get roomsBedsOccupiedReadinessLabel => 'In utiliser';

  @override
  String get roomsBedsReservedReadinessLabel => 'Détenu';

  @override
  String get roomsBedsBoardTitle => 'Tableau des lits';

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
  String get roomsBedsFacilityFilterLabel => 'Établissement';

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
  String get roomsBedsAllStatusesLabel => 'Tous les statuts';

  @override
  String get roomsBedsPreviousPageLabel => 'Page précédente';

  @override
  String get roomsBedsNextPageLabel => 'Page suivante';

  @override
  String roomsBedsPageLabel(int from, int to, int total) {
    return 'Affichage de $from-$to sur $total';
  }

  @override
  String get roomsBedsEmptyTitle => 'Aucun beds trouvé';

  @override
  String get roomsBedsEmptyBody =>
      'Adjust le filtres ou ajouter lits de établissement setup à start en utilisant le operational board.';

  @override
  String get roomsBedsBedColumnLabel => 'Lit';

  @override
  String get roomsBedsLocationColumnLabel => 'Emplacement';

  @override
  String get roomsBedsStatusColumnLabel => 'Statut';

  @override
  String get roomsBedsAssignmentColumnLabel => 'Affectation';

  @override
  String get roomsBedsNextActionColumnLabel => 'Prochaine action';

  @override
  String get roomsBedsDetailTitle => 'Détail du lit';

  @override
  String get roomsBedsCurrentAdmissionLabel => 'Admission actuelle';

  @override
  String get roomsBedsReadinessLabel => 'Préparation';

  @override
  String get roomsBedsReserveAction => 'Réserve';

  @override
  String get roomsBedsMarkAvailableAction => 'Mark disponible';

  @override
  String get roomsBedsMarkOutOfServiceAction => 'Mark out sur service';

  @override
  String get roomsBedsAssignAction => 'Assign lit';

  @override
  String get roomsBedsReleaseAction => 'Release lit';

  @override
  String get roomsBedsRequestTransferAction => 'Demander un transfert';

  @override
  String get roomsBedsAssignmentHistoryTitle => 'Assignment historique';

  @override
  String get roomsBedsNoAssignmentsLabel => 'No assignment historique recorded';

  @override
  String get roomsBedsCurrentAssignmentLabel => 'Actuel';

  @override
  String get roomsBedsReleasedAssignmentLabel => 'Libéré';

  @override
  String get roomsBedsAdmissionFieldLabel => 'Numéro d\'admission';

  @override
  String get roomsBedsAdmissionFieldHint => 'Enter le admission number';

  @override
  String get roomsBedsDestinationWardLabel => 'Destination service';

  @override
  String get roomsBedsAssignDialogTitle => 'Assign lit';

  @override
  String roomsBedsAssignWardSuitabilityHint(String wardType) {
    return 'Confirm patient suitability pour${wardType}avant assigning ce lit.';
  }

  @override
  String get roomsBedsReleaseDialogTitle => 'Release lit';

  @override
  String get roomsBedsReleaseDialogBody =>
      'Releasing le lit sends le admission through le lit release flow.';

  @override
  String get roomsBedsTransferDialogTitle => 'Demander un transfert';

  @override
  String get roomsBedsTransferDialogBody =>
      'Choisissez le service de destination. La sélection du lit est effectuée par le flux de transfert IPD après approbation.';

  @override
  String roomsBedsAdmissionAssignment(String admissionId) {
    return 'Admission$admissionId';
  }

  @override
  String get roomsBedsAssignmentNotLinked => 'Devoir non lié';

  @override
  String get roomsBedsNextActionAssign => 'Assign suivant admission';

  @override
  String get roomsBedsNextActionReleaseOrTransfer => 'Release ou transfert';

  @override
  String get roomsBedsNextActionAssignOrReleaseHold => 'Assign ou release hold';

  @override
  String get roomsBedsNextActionResolveBlock => 'Résoudre le bloc';

  @override
  String get roomsBedsReadyLabel => 'Prêt';

  @override
  String get roomsBedsUnavailableLabel => 'Indisponible';

  @override
  String get roomsBedsReadinessBackendGapLabel =>
      'Readiness statut indisponible';

  @override
  String get roomsBedsSavedMessage => 'Rooms et lits mis à jour.';

  @override
  String roomsBedsRequiredMessage(String field) {
    return '${field}est requis.';
  }

  @override
  String get hrActivityDescription =>
      'Audit-style feed sur recent HR updates, roster publishes, et quart changes.';

  @override
  String get hrActivityTitle => 'Activité RH';

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
  String get hrStaffNumberGenerateLabel => 'Générer';

  @override
  String get hrStaffNumberManualLabel => 'Entrez manuellement';

  @override
  String get hrStaffNumberAutoGenerateLabel =>
      'Automatically generate personnel number';

  @override
  String get hrStaffNumberManualEntryLabel => 'Enter personnel number manually';

  @override
  String get hrStaffGenerateNumberAction => 'Générer';

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
  String get hrStaffOnboardingEmploymentSectionTitle => 'Emploi';

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
      'Aucun rôle attribué pour l\'instant. Ce membre du personnel aura un accès limité jusqu\'à ce que les rôles soient attribués.';

  @override
  String get hrStaffOnboardingPayTypeLabel => 'Type de paie';

  @override
  String get hrStaffOnboardingDailyRateLabel => 'Tarif journalier';

  @override
  String get hrStaffOnboardingAddressLabel => 'Address (facultatif)';

  @override
  String get hrStaffOnboardingPermissionsPreviewEmpty =>
      'Select rôles above à aperçu effective autorisations.';

  @override
  String get hrStaffOnboardingCompensationSectionTitle => 'Rémunération';

  @override
  String get hrStaffOnboardingCompensationCreateHint =>
      'Optional. Set pay rate et effective date lorsque onboarding ce personnel member.';

  @override
  String get hrStaffOnboardingConsultationSectionTitle =>
      'Facturation des consultations';

  @override
  String get hrAllowPartialPublishLabel => 'Autoriser la publication partielle';

  @override
  String get hrApproveLeaveAction => 'Approve congé';

  @override
  String get hrApproveLeaveDialogTitle => 'Approve congé';

  @override
  String get hrApproveSwapAction => 'Approuver l\'échange';

  @override
  String get hrApproveSwapDialogTitle => 'Approve quart swap';

  @override
  String get hrAssignDepartmentAction => 'Assign département';

  @override
  String get hrAssignDepartmentDialogTitle => 'Assign département';

  @override
  String get hrAssignmentLabel => 'Affectation';

  @override
  String get hrAssignmentsSectionTitle => 'Missions';

  @override
  String get hrAssignPositionAction => 'Attribuer un poste';

  @override
  String get hrAssignPositionDialogTitle => 'Attribuer un poste';

  @override
  String get hrAssignShiftAction => 'Assign quart';

  @override
  String get hrAssignShiftDialogTitle => 'Assign quart';

  @override
  String get hrAvailabilityAvailable => 'Disponible';

  @override
  String get hrAvailabilityDialogTitle => 'Disponibilité record';

  @override
  String get hrAvailabilityPreferenceLabel => 'Disponibilité';

  @override
  String get hrAvailabilityPreferred => 'Préféré';

  @override
  String get hrAvailabilitySectionTitle => 'Disponibilité';

  @override
  String get hrAvailabilityUnavailable => 'Indisponible';

  @override
  String get hrAddAvailabilitySlotAction => 'Ajouter un emplacement';

  @override
  String get hrAddScheduleSlotAction => 'Ajouter un emplacement';

  @override
  String get hrRemoveScheduleSlotAction => 'Supprimer l\'emplacement';

  @override
  String get hrDuplicateScheduleToAction => 'Duplicate à…';

  @override
  String get hrScheduleDuplicateToDialogTitle => 'Duplicate planning';

  @override
  String hrScheduleDuplicateToDialogDescription(String dayName) {
    return 'Replace le selected days avec$dayName\'s heure slots.';
  }

  @override
  String get hrWeeklyScheduleSectionTitle => 'Weekly planning';

  @override
  String get hrAvailabilityScheduleSourceLabel => 'Source de planification';

  @override
  String get hrAvailabilitySourceManual => 'Manuel';

  @override
  String get hrAvailabilitySourceFromStaff => 'Du personnel';

  @override
  String get hrAvailabilitySourceFromTemplate => 'À partir du modèle';

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
    return 'Replace le selected days avec$dayName\'s heure slots.';
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
  String get hrRemoveAvailabilitySlotAction => 'Supprimer l\'emplacement';

  @override
  String get hrClearFiltersAction => 'Clear filtres';

  @override
  String get hrConsultationCurrencyLabel => 'Consultation devise';

  @override
  String get hrConsultationFeeLabel => 'Frais de consultation';

  @override
  String get hrCreateStaffAction => 'Create personnel';

  @override
  String get hrDayOfWeekLabel => 'Day sur week';

  @override
  String get hrDepartmentColumnLabel => 'Département';

  @override
  String get hrDepartmentFilterLabel => 'Département';

  @override
  String get hrDepartmentLabel => 'Département';

  @override
  String get hrEditStaffAction => 'Edit personnel';

  @override
  String get hrEditStaffDialogTitle => 'Edit personnel profil';

  @override
  String get hrEffectiveFromLabel => 'Effective de';

  @override
  String get hrEffectiveToLabel => 'Effective à';

  @override
  String get hrEndDateLabel => 'Date de fin';

  @override
  String get hrEndTimeLabel => 'End heure';

  @override
  String hrFieldRequiredLabel(String label) {
    return '${label}est requis.';
  }

  @override
  String get hrFiltersLabel => 'Filtres';

  @override
  String get hrFridayLabel => 'Vendredi';

  @override
  String get hrGenerateRosterAction => 'Générer une liste';

  @override
  String get hrHireDateLabel => 'Date d\'embauche';

  @override
  String get hrLeaveDialogTitle => 'Demander un congé';

  @override
  String get hrLeaveLabel => 'Partir';

  @override
  String get hrLeaveDaysLabel => 'Number sur days';

  @override
  String get hrLeaveDaysHelper =>
      'Auto-calculates le end date de le start date.';

  @override
  String get hrLeaveTypeLabel => 'Type de congé';

  @override
  String get hrLeaveHalfDayLabel => 'Half-day congé';

  @override
  String get hrLeaveHalfDayHelper =>
      'Use pour un single morning ou afternoon away de work.';

  @override
  String get hrLeaveHalfDayPeriodLabel => 'Période d\'une demi-journée';

  @override
  String get hrLeaveHalfDaySingleDayError =>
      'Half-day congé must start et end on le same day.';

  @override
  String hrLeaveHalfDaySummary(String period) {
    return 'Demi-journée ($period)';
  }

  @override
  String get hrCoveringStaffLabel => 'Collègue de couverture';

  @override
  String hrCoveringStaffSummary(String name) {
    return 'Cover:$name';
  }

  @override
  String get hrHandoverNotesLabel => 'Notes de passation';

  @override
  String get hrHandoverNotesHelper =>
      'Tâches, patients ou détails de quart de travail que le collègue qui assure la couverture doit connaître.';

  @override
  String get hrAddNewPositionLabel => 'Add un nouveau position';

  @override
  String get hrNewPositionLabel => 'New position nom';

  @override
  String get hrSelectShiftLabel => 'Changement';

  @override
  String get hrSelectShiftHint => 'Search shifts by nom, heure, ou département';

  @override
  String get hrStaffOverviewSectionTitle => 'Présentation';

  @override
  String get hrRoomLabel => 'Chambre';

  @override
  String get hrCompensationAction => 'Rémunération';

  @override
  String get hrCompensationDialogTitle => 'Update rémunération';

  @override
  String get hrCompensationSectionTitle => 'Rémunération';

  @override
  String get hrCompensationLabel => 'Rémunération';

  @override
  String get hrNoCompensationLabel => 'No rémunération dossiers';

  @override
  String get hrCompensationHourlyRateLabel => 'Taux Horaire';

  @override
  String get hrCompensationMonthlyRateLabel => 'Tarif mensuel';

  @override
  String get hrCompensationProcedureRateLabel => 'Taux de procédure';

  @override
  String get hrCompensationConsultationRateLabel =>
      'Tarif des honoraires de consultation';

  @override
  String get hrCompensationCurrencyLabel => 'Devise';

  @override
  String get hrLeaveReportLabel => 'Leave résumé';

  @override
  String get hrLeaveRequestsSummaryLabel => 'Leave demandes';

  @override
  String get hrLeaveRequestTitle => 'Leave demande';

  @override
  String get hrLeaveSectionTitle => 'Partir';

  @override
  String get hrLiveStatus => 'Direct';

  @override
  String get hrLoadingBody => 'Loading personnel dossiers et rosters.';

  @override
  String get hrLoadingTitle => 'Loading HR espace de travail';

  @override
  String get hrMondayLabel => 'Lundi';

  @override
  String get hrNextActionAssignDepartment => 'Assign département';

  @override
  String get hrNextActionAssignPosition => 'Attribuer un poste';

  @override
  String get hrNextActionColumnLabel => 'Prochaine action';

  @override
  String get hrNextActionReviewProfile => 'Review profil';

  @override
  String get hrNextPageLabel => 'Next personnel page';

  @override
  String get hrNextQueuePageLabel => 'Page de file d\'attente suivante';

  @override
  String get hrNoActivityBody => 'L\'activité RH apparaîtra ici.';

  @override
  String get hrNoActivityTitle => 'Aucune activité pour le moment';

  @override
  String get hrNoAssignmentsLabel => 'Aucune mission enregistrée.';

  @override
  String get hrNoAvailabilityLabel => 'Aucune disponibilité enregistrée.';

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
  String get hrNotesLabel => 'Remarques';

  @override
  String get hrNotifyStaffLabel => 'Notify personnel';

  @override
  String get hrOverrideShiftAction => 'Override quart';

  @override
  String get hrOverrideShiftDialogTitle => 'Override quart';

  @override
  String hrPageLabel(int from, int to, int total) {
    return '$from-$to sur $total';
  }

  @override
  String get hrPayrollDraftsSummaryLabel => 'Brouillons de paie';

  @override
  String get hrPayrollDraftTitle => 'Payroll brouillon';

  @override
  String get hrPayrollReportLabel => 'Payroll résumé';

  @override
  String get hrPayrollRunDialogTitle => 'Run paie';

  @override
  String get hrPeriodColumnLabel => 'Période';

  @override
  String get hrPeriodEndLabel => 'Fin de période';

  @override
  String get hrPeriodStartLabel => 'Début des règles';

  @override
  String get hrPickDateAction => 'Choisir la date';

  @override
  String get hrPositionFilterLabel => 'Poste';

  @override
  String get hrPositionLabel => 'Poste';

  @override
  String get hrPractitionerTypeFilterLabel => 'Type de praticien';

  @override
  String get hrPractitionerTypeLabel => 'Type de praticien';

  @override
  String get hrPreviewStaffProfileReportAction => 'Preview personnel profil';

  @override
  String get hrPreviousPageLabel => 'Previous personnel page';

  @override
  String get hrPreviousQueuePageLabel => 'Page de file d\'attente précédente';

  @override
  String get hrProcessPayrollAction => 'Process paie';

  @override
  String get hrProcessPayrollDialogTitle => 'Process paie';

  @override
  String get hrPublishNoteLabel => 'Publier une note';

  @override
  String get hrPublishRosterAction => 'Publier la liste';

  @override
  String get hrPublishRosterDialogTitle => 'Publier la liste';

  @override
  String get hrQueueColumnLabel => 'File d’attente';

  @override
  String get hrQueueItemColumnLabel => 'Article';

  @override
  String get hrQueueLeaveRequests => 'Leave demandes';

  @override
  String get hrQueueOverdueShifts => 'Quarts de travail en retard';

  @override
  String get hrQueuePayrollDrafts => 'Brouillons de paie';

  @override
  String get hrQueueRosterDrafts => 'Projets de liste';

  @override
  String get hrQueueSwapRequests => 'Swap demandes';

  @override
  String get hrQueueUnassignedShifts => 'Quarts de travail non attribués';

  @override
  String get hrReasonLabel => 'Raison';

  @override
  String get hrRecordAvailabilityAction => 'Disponibilité record';

  @override
  String get hrRejectLeaveAction => 'Reject congé';

  @override
  String get hrRejectLeaveDialogTitle => 'Reject congé';

  @override
  String get hrRejectSwapAction => 'Rejeter l\'échange';

  @override
  String get hrRejectSwapDialogTitle => 'Reject quart swap';

  @override
  String get hrReplacePayrollItemsLabel => 'Replace existing paie éléments';

  @override
  String get hrReportsSectionTitle => 'Rapports';

  @override
  String get hrRequestLeaveAction => 'Demander un congé';

  @override
  String get hrRolePositionColumnLabel => 'Rôle/poste';

  @override
  String get hrRosterDraftsSummaryLabel => 'Projets de liste';

  @override
  String get hrRosterDraftTitle => 'Roster brouillon';

  @override
  String get hrRosterReportLabel => 'Roster rapport';

  @override
  String get hrRunPayrollAction => 'Run paie';

  @override
  String get hrSaturdayLabel => 'Samedi';

  @override
  String get hrSavedMessage => 'Modifications RH enregistrées.';

  @override
  String get hrSaveStaffAction => 'Save personnel';

  @override
  String get hrSavingStatus => 'Enregistrement';

  @override
  String get hrSearchHint =>
      'Search personnel, département, rôle, quart, ou statut';

  @override
  String get hrSearchLabel => 'Search HR dossiers';

  @override
  String get hrShiftIdLabel => 'ID d\'équipe';

  @override
  String get hrShiftLabel => 'Changement';

  @override
  String get hrShiftQueueTitle => 'Shift queue élément';

  @override
  String get hrShiftsSectionTitle => 'Changements';

  @override
  String get hrStaffActionsTitle => 'Actions du personnel';

  @override
  String get hrStaffActionsPlacementTitle => 'Affectation';

  @override
  String get hrStaffActionsSchedulingTitle => 'Planification';

  @override
  String get hrStaffActionsPayrollTitle => 'Paie';

  @override
  String get hrStaffActionsAccessTitle => 'Accéder';

  @override
  String get hrManageScheduleTemplatesTitle => 'Schedule modèles';

  @override
  String get hrManageScheduleTemplatesDescription =>
      'Reusable quart patterns pour roster generation et personnel scheduling.';

  @override
  String get hrNoShiftTemplatesLabel =>
      'No planning modèles yet. Create one à reuse quart patterns.';

  @override
  String get hrStaffColumnLabel => 'Personnel';

  @override
  String get hrStaffDetailTitle => 'Détail du personnel';

  @override
  String get hrStaffDirectoryDescription =>
      'Search personnel by nom, département, position, rôle, et statut.';

  @override
  String get hrStaffDirectoryTitle => 'Annuaire du personnel';

  @override
  String get hrStaffLabel => 'Personnel';

  @override
  String get hrStaffListReportLabel => 'Staff liste';

  @override
  String get hrStaffNameLabel => 'Staff nom';

  @override
  String get hrStaffNumberLabel => 'Numéro d\'employé';

  @override
  String get hrStaffProfileReportTitle => 'Staff profil';

  @override
  String get hrStartDateLabel => 'Date de début';

  @override
  String get hrStartTimeLabel => 'Start heure';

  @override
  String get hrStatusColumnLabel => 'Statut';

  @override
  String get hrSundayLabel => 'Dimanche';

  @override
  String get hrSwapRequestTitle => 'Shift swap demande';

  @override
  String get hrSwapShiftAction => 'Swap quart';

  @override
  String get hrSwapShiftDialogTitle => 'Demander un échange d\'équipe';

  @override
  String get hrTargetStaffLabel => 'Target personnel';

  @override
  String get hrTenantIdLabel => 'ID du locataire';

  @override
  String get hrThursdayLabel => 'Jeudi';

  @override
  String get hrTimeHint => 'HH : MM';

  @override
  String get hrTotalStaffSummaryLabel => 'Total personnel';

  @override
  String get hrTuesdayLabel => 'Mardi';

  @override
  String get hrUnassignedShiftsSummaryLabel =>
      'Quarts de travail non attribués';

  @override
  String get hrUnitIdLabel => 'ID de l\'unité';

  @override
  String get hrUnitLabel => 'Unité';

  @override
  String get hrRoomsLabel => 'Chambres';

  @override
  String get hrSelectAllRoomsAction => 'Select tous';

  @override
  String get hrClearRoomsAction => 'Effacer';

  @override
  String get hrUserIdLabel => 'ID de l\'utilisateur';

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
  String get hrModuleAccessSectionTitle => 'Modules souscrits';

  @override
  String get hrEffectivePermissionsTitle => 'Effective autorisations';

  @override
  String get hrNoModuleAccessLabel => 'No actif module entitlements.';

  @override
  String get hrOpenAccessAdminAction => 'Ouvrir dans Utilisateurs/Rôles';

  @override
  String get hrManageAccessAction => 'Manage utilisateurs et rôles';

  @override
  String get hrAccessWorkspaceTitle => 'Staff accès';

  @override
  String get hrAccessWorkspaceDescription =>
      'Manage personnel utilisateur accounts, rôles, et autorisations pour votre organization.';

  @override
  String get hrAccessPanelUsers => 'Personnel';

  @override
  String get hrAccessPanelRoles => 'Rôles';

  @override
  String get hrAccessPanelPermissions => 'Autorisations';

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
      'Disponible par module';

  @override
  String get hrAccessPermissionCatalogSelectLabel => 'Autorisation';

  @override
  String get permissionCatalogProfileRead => 'Profil — Lire';

  @override
  String get permissionCatalogProfileUpdate => 'Profil — Mise à jour';

  @override
  String get permissionCatalogPatientRead => 'Patient — Lire';

  @override
  String get permissionCatalogPatientWrite => 'Patient — Écrire';

  @override
  String get permissionCatalogPatientDelete => 'Patient — Supprimer';

  @override
  String get permissionCatalogClinicalRead => 'Clinique — Lire';

  @override
  String get permissionCatalogClinicalWrite => 'Clinique — Écrire';

  @override
  String get permissionCatalogEmergencyRead => 'Urgence — Lire';

  @override
  String get permissionCatalogEmergencyWrite => 'Urgence – Écrire';

  @override
  String get permissionCatalogEmergencyDelete => 'Urgence — Supprimer';

  @override
  String get permissionCatalogLabRead => 'Laboratoire — Lire';

  @override
  String get permissionCatalogLabWrite => 'Laboratoire — Écrire';

  @override
  String get permissionCatalogRadiologyRead => 'Radiologie — Lire';

  @override
  String get permissionCatalogRadiologyWrite => 'Radiologie — Écrire';

  @override
  String get permissionCatalogPharmacyRead => 'Pharmacie — Lire';

  @override
  String get permissionCatalogPharmacyWrite => 'Pharmacie — Écrire';

  @override
  String get permissionCatalogBillingRead => 'Facturation — Lire';

  @override
  String get permissionCatalogBillingWrite => 'Facturation — Écrire';

  @override
  String get permissionCatalogOperationsRead => 'Opérations — Lire';

  @override
  String get permissionCatalogOperationsWrite => 'Opérations — Écrire';

  @override
  String get permissionCatalogHrRead => 'RH — Lire';

  @override
  String get permissionCatalogHrWrite => 'RH — Rédiger';

  @override
  String get permissionCatalogUnitRead => 'Unité — Lire';

  @override
  String get permissionCatalogUnitManage => 'Unité — Gérer';

  @override
  String get permissionCatalogRosterRead => 'Liste — Lire';

  @override
  String get permissionCatalogRosterWrite => 'Liste - Écrire';

  @override
  String get permissionCatalogRosterPublish => 'Liste — Publier';

  @override
  String get permissionCatalogRosterApprove => 'Liste – Approuver';

  @override
  String get permissionCatalogBiomedRead => 'Bioméde — Lire';

  @override
  String get permissionCatalogBiomedWrite => 'Biomed — Écrire';

  @override
  String get permissionCatalogMortuaryRead => 'Morgue — Lire';

  @override
  String get permissionCatalogMortuaryWrite => 'Morgue — Écrire';

  @override
  String get permissionCatalogMortuaryRelease => 'Morgue – Libération';

  @override
  String get permissionCatalogMortuaryManageStorage =>
      'Morgue — Gérer le stockage';

  @override
  String get permissionCatalogMortuaryPostMortemRequest =>
      'Mortuary — Post-mortem demande';

  @override
  String get permissionCatalogMortuaryApprove => 'Morgue — Approuver';

  @override
  String get permissionCatalogMortuaryBillingEvent =>
      'Morgue — Événement de facturation';

  @override
  String get permissionCatalogMortuaryExport => 'Morgue — Exportation';

  @override
  String get permissionCatalogMortuaryAudit => 'Morgue — Vérification';

  @override
  String get permissionCatalogCommunicationsRead => 'Communications — Lire';

  @override
  String get permissionCatalogCommunicationsWrite => 'Communications — Écrire';

  @override
  String get permissionCatalogCommunicationsDelete =>
      'Communications — Supprimer';

  @override
  String get permissionCatalogIntegrationRead => 'Intégration — Lire';

  @override
  String get permissionCatalogIntegrationWrite => 'Intégration — Écrire';

  @override
  String get permissionCatalogIntegrationDelete => 'Intégration — Supprimer';

  @override
  String get permissionCatalogReportsRead => 'Rapports — Lire';

  @override
  String get permissionCatalogReportsWrite => 'Rapports - Rédiger';

  @override
  String get permissionCatalogReportsDelete => 'Rapports — Supprimer';

  @override
  String get permissionCatalogSubscriptionsRead => 'Abonnements — Lire';

  @override
  String get permissionCatalogSubscriptionsWrite => 'Abonnements — Écrire';

  @override
  String get permissionCatalogSubscriptionsDelete => 'Abonnements – Supprimer';

  @override
  String get permissionCatalogLastOfficeRead => 'Dernier mandat — Lire';

  @override
  String get permissionCatalogLastOfficeWrite => 'Dernier bureau — Écrire';

  @override
  String get permissionCatalogLastOfficeApprove => 'Dernier bureau — Approuver';

  @override
  String get permissionCatalogComplianceRead => 'Conformité — Lire';

  @override
  String get permissionCatalogComplianceReview => 'Conformité — Examen';

  @override
  String get permissionCatalogBreakGlassRequest => 'Briser le verre — Demande';

  @override
  String get permissionCatalogBreakGlassReview => 'Briser le verre — Bilan';

  @override
  String get permissionCatalogBreakGlassApprove =>
      'Briser le verre – Approuver';

  @override
  String get permissionCatalogEvidenceExport => 'Preuve — Exportation';

  @override
  String get permissionCatalogFinancialApprove => 'Financier — Approuver';

  @override
  String get permissionCatalogFacilityAdmin => 'Installation — Administrateur';

  @override
  String get permissionCatalogTenantAdmin => 'Locataire — Administrateur';

  @override
  String get permissionCatalogSystemAdmin => 'Système — Administrateur';

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
      zero: 'No permissions',
    );
    String _temp1 = intl.Intl.pluralLogic(
      userCount,
      locale: localeName,
      other: '$userCount assignments',
      zero: 'No assignments',
    );
    return '$_temp0·$_temp1';
  }

  @override
  String hrAccessPermissionRoleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count roles',
      zero: 'no roles',
    );
    return 'Used by$_temp0';
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
  String get hrAccessOpenStaffProfileAction => 'Profil du personnel ouvert';

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
  String get hrAccessNonSystemRoleLabel => 'Non-système';

  @override
  String get hrAccessSelectAllRolesAction => 'Select tous rôles';

  @override
  String get hrAccessClearRolesAction => 'Clear rôles';

  @override
  String get hrAccessSelectAllPermissionsAction => 'Select tous autorisations';

  @override
  String get hrAccessClearPermissionsAction => 'Clear autorisations';

  @override
  String get hrAccessLoadMoreAction => 'Charger plus';

  @override
  String get hrPrimaryAssignmentLabel => 'Primaire';

  @override
  String get hrEndAssignmentAction => 'Fin de l\'affectation';

  @override
  String get hrEndAssignmentDialogTitle => 'Fin de l\'affectation';

  @override
  String get hrEndAssignmentDateLabel => 'Date de fin';

  @override
  String get hrAssignmentDetailDialogTitle => 'Assignment détails';

  @override
  String get hrAssignmentIdLabel => 'ID d\'affectation';

  @override
  String get hrEditAssignmentAction => 'Modifier le devoir';

  @override
  String get hrAssignmentActiveLabel => 'Actif';

  @override
  String get hrAssignmentEndedLabel => 'Terminé';

  @override
  String get hrDateRangeOngoingLabel => 'En cours';

  @override
  String get hrAvailabilityWeekViewLabel => 'Week voir';

  @override
  String get hrAvailabilityMonthViewLabel => 'Month voir';

  @override
  String get hrAvailabilityCalendarEmptyBody =>
      'Record weekly availability à see le calendar.';

  @override
  String get hrAvailabilityLegendAvailableLabel => 'Disponible';

  @override
  String get hrAvailabilityLegendUnavailableLabel => 'Indisponible';

  @override
  String get hrAvailabilityLegendLeaveLabel => 'Approved congé';

  @override
  String get hrAvailabilityDayEmptyLabel =>
      'No heure slots recorded pour ce day.';

  @override
  String get hrAvailabilityAddSlotAction => 'Ajouter un emplacement';

  @override
  String get hrAvailabilityEditDayAction => 'Modifier le jour';

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
  String get hrCompensationPayStructureTabLabel => 'Structure de rémunération';

  @override
  String get hrCompensationHistoryTabLabel => 'Histoire';

  @override
  String get hrCompensationBaseRateLabel => 'Tarif de base';

  @override
  String get hrCompensationPayFrequencyLabel => 'Fréquence de paie';

  @override
  String get hrCompensationFrequencyMonthlyLabel => 'Mensuel';

  @override
  String get hrCompensationFrequencyBiweeklyLabel => 'Bihebdomadaire';

  @override
  String get hrCompensationFrequencyWeeklyLabel => 'Hebdomadaire';

  @override
  String get hrCompensationDailyRateLabel => 'Tarif journalier';

  @override
  String get hrCompensationDetailDialogTitle => 'Compensation détails';

  @override
  String get hrCompensationAddNewRateAction => 'Add nouveau rate';

  @override
  String get hrCompensationAddPayLineAction => 'Ajouter une ligne de paiement';

  @override
  String get hrCompensationRemovePayLineAction =>
      'Supprimer la ligne de paiement';

  @override
  String get hrCompensationActiveStatusLabel => 'Actif';

  @override
  String get hrCompensationEndedStatusLabel => 'Terminé';

  @override
  String hrPayrollComponentBreakdownLabel(
    String quantity,
    String unit,
    String rate,
    String currency,
    String subtotal,
  ) {
    return '$quantity $unit×$rate $currency=$subtotal';
  }

  @override
  String hrPayrollZeroQuantityWarning(String payType) {
    return 'No recorded activity pour${payType}in ce period.';
  }

  @override
  String get hrPayrollMixedCurrencyWarning =>
      'Certaines lignes de rémunération utilisent une devise différente et ont été exclues du total.';

  @override
  String get hrPayrollWizardTitle => 'Exécution de la paie';

  @override
  String get hrPayrollWizardPeriodStepTitle =>
      'Sélectionnez la période de paie';

  @override
  String get hrPayPeriodStartLabel => 'Début de la période de paie';

  @override
  String get hrPayPeriodEndLabel => 'Fin de la période de paie';

  @override
  String get hrPayrollWizardPreviewStepTitle => 'Aperçu des fiches de paie';

  @override
  String get hrPayrollWizardNoStaffItemsLabel =>
      'No paie line éléments pour ce personnel member in le selected period.';

  @override
  String get hrPayrollStaffCountLabel => 'Staff nombre';

  @override
  String get hrGrossPayLabel => 'Salaire brut';

  @override
  String get hrNetPayLabel => 'Salaire net';

  @override
  String get hrDeductionsLabel => 'Déductions';

  @override
  String get hrPayrollWizardProcessStepBody =>
      'Le processus créera des éléments de paie et fera progresser l\'exécution vers le statut payé.';

  @override
  String get hrPayrollWizardPreviewAction => 'Aperçu';

  @override
  String get hrPayrollWizardReviewAction => 'Revoir';

  @override
  String get hrLeaveDetailDialogTitle => 'Leave détails';

  @override
  String get hrLeaveCoveringStaffLabel => 'Covering personnel';

  @override
  String get hrLeaveHandoverNotesLabel => 'Notes de passation';

  @override
  String get hrLeaveReasonLabel => 'Raison';

  @override
  String get hrShiftDetailDialogTitle => 'Shift détails';

  @override
  String get hrShiftTypeLabel => 'Type de quart de travail';

  @override
  String get hrAssignedAtLabel => 'Attribué à';

  @override
  String get hrRosterPeriodLabel => 'Période d\'inscription';

  @override
  String get hrRemoveShiftAssignmentAction => 'Supprimer l\'affectation';

  @override
  String get hrOffboardStaffAction => 'Mettre fin à l\'emploi';

  @override
  String get hrOffboardStaffActionTooltip =>
      'Record separation et optionally end assignments et revoke accès.';

  @override
  String get hrOffboardStaffDialogTitle => 'Mettre fin à l\'emploi';

  @override
  String get hrOffboardStaffDialogHint =>
      'Ce ends employment pour le personnel member. Active assignments can be fermé on le last working day.';

  @override
  String get hrSeparationTypeLabel => 'Type de séparation';

  @override
  String get hrSeparationTypeResignationLabel => 'Démission';

  @override
  String get hrSeparationTypeTerminationLabel => 'Terminaison';

  @override
  String get hrSeparationTypeRetirementLabel => 'Retraite';

  @override
  String get hrSeparationTypeContractEndLabel => 'Fin du contrat';

  @override
  String get hrSeparationTypeDeceasedLabel => 'Décédé';

  @override
  String get hrSeparationTypeOtherLabel => 'Séparation';

  @override
  String get hrLastWorkingDayLabel => 'Dernier jour ouvrable';

  @override
  String get hrSeparationNotesLabel => 'Raison / remarques';

  @override
  String get hrOffboardEndAssignmentsLabel => 'End tous actif assignments';

  @override
  String get hrOffboardRevokeAccessLabel => 'Revoke system accès';

  @override
  String get hrOffboardFinalPayrollLabel => 'Schedule final paie';

  @override
  String hrSeparationBannerMessage(String separationType, String lastDay) {
    return '$separationType· Last day$lastDay';
  }

  @override
  String get hrShiftTemplateAction => 'Schedule modèles';

  @override
  String get hrShiftTemplateDialogTitle => 'Modèle de planification';

  @override
  String get hrSchedulePatternCreateTitle => 'Modèle de planification';

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
  String get hrScheduleTemplateIdLabel => 'ID du modèle';

  @override
  String get hrScheduleTemplateActiveLabel => 'Actif';

  @override
  String get hrScheduleTemplateInactiveLabel => 'Inactif';

  @override
  String get hrStatusLabel => 'Statut';

  @override
  String get hrCreatedAtLabel => 'Créé';

  @override
  String get hrUpdatedAtLabel => 'Mis à jour';

  @override
  String get hrShiftTypeDay => 'Day quart';

  @override
  String get hrShiftTypeNight => 'Night quart';

  @override
  String get hrShiftTypeSwing => 'Swing quart';

  @override
  String get hrShiftTypeOnCall => 'De garde';

  @override
  String get hrShiftTemplateNameLabel => 'Template nom';

  @override
  String get hrPreviewPayrollAction => 'Preview paie';

  @override
  String get hrPreviewPayrollDialogTitle => 'Payroll aperçu';

  @override
  String get hrPreviewRosterAction => 'Génération de liste d’aperçu';

  @override
  String get hrPreviewRosterDialogTitle => 'Roster generation aperçu';

  @override
  String get hrRosterCoverageLabel => 'Couverture';

  @override
  String get hrRosterGapsLabel => 'Lacunes en matière de personnel';

  @override
  String get hrPasswordLabel => 'Temporary mot de passe';

  @override
  String get hrEmailLabel => 'E-mail';

  @override
  String get hrOnboardingModeExistingUser => 'Link existing utilisateur';

  @override
  String get hrOnboardingModeCreateUser => 'Create nouveau utilisateur';

  @override
  String get hrWednesdayLabel => 'Mercredi';

  @override
  String get hrWorkQueuesTitle => 'Files d\'attente de travail';

  @override
  String get hrWorkQueuesToolbarTooltip =>
      'Browse et act on tous queue types in one dialog.';

  @override
  String get copyAdmissionIdAction => 'Copier la pièce d\'identité';

  @override
  String get copyUserIdAction => 'Copy utilisateur ID';

  @override
  String get copyIdentifierAction => 'Copy identifiant';

  @override
  String get admissionIdCopiedMessage => 'ID d’admission copié.';

  @override
  String get userIdCopiedMessage => 'ID utilisateur copié.';

  @override
  String get identifierCopiedMessage => 'Identifiant copié.';

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
  String get settingsWorkspaceTenantLabel => 'Locataire';

  @override
  String get settingsWorkspaceFacilityLabel => 'Établissement';

  @override
  String get settingsWorkspaceFacilityTypeLabel => 'Type d\'installation';

  @override
  String get settingsWorkspaceRolesLabel => 'Rôles';

  @override
  String get settingsWorkspaceGeneratedAtLabel => 'Généré';

  @override
  String get settingsWorkspaceRecordsLabel => 'Enregistrements';

  @override
  String get settingsWorkspaceAttentionLabel => 'A besoin d\'attention';

  @override
  String get settingsWorkspaceConfiguredLabel => 'Configuré';

  @override
  String get settingsWorkspaceTotalRecordsLabel => 'Total dossiers';

  @override
  String get settingsWorkspaceChecklistTitle =>
      'Liste de contrôle de configuration';

  @override
  String get settingsWorkspaceQuickActionsTitle => 'Actions rapides';

  @override
  String get settingsWorkspaceModuleGroupsTitle => 'Groupes de modules';

  @override
  String get settingsWorkspaceSearchLabel =>
      'Modules de configuration de recherche';

  @override
  String get settingsWorkspaceSearchHint => 'Search by module, group, ou route';

  @override
  String get settingsWorkspaceGroupFilterLabel => 'Groupe';

  @override
  String get settingsWorkspaceStateFilterLabel => 'État';

  @override
  String get settingsWorkspaceAllGroupsLabel => 'Tous les groupes';

  @override
  String get settingsWorkspaceAllStatesLabel => 'Tous les états';

  @override
  String get settingsWorkspaceActionableOnlyLabel => 'Actionnable uniquement';

  @override
  String get settingsWorkspaceTenantSelectorLabel => 'Contexte du locataire';

  @override
  String get settingsWorkspaceFacilitySelectorLabel =>
      'Contexte de l\'établissement';

  @override
  String get settingsWorkspaceApplyContextAction => 'Appliquer le contexte';

  @override
  String get settingsWorkspaceOpenAction => 'Ouvrir';

  @override
  String get settingsWorkspaceCreateAction => 'Créer';

  @override
  String get settingsWorkspaceRouteUnavailableLabel => 'Indisponible';

  @override
  String get settingsWorkspaceRouteUnavailableBody =>
      'Cette action de configuration n\'est pas encore disponible sur cette page.';

  @override
  String get settingsWorkspaceTenantContextRequiredTitle =>
      'Tenant context requis';

  @override
  String get settingsWorkspaceTenantContextRequiredBody =>
      'Select un locataire à load administrative setup readiness.';

  @override
  String get settingsWorkspaceReadyStatus => 'Prêt';

  @override
  String get settingsWorkspaceInProgressStatus => 'En cours';

  @override
  String get settingsWorkspaceAttentionStatus => 'Attention';

  @override
  String get settingsWorkspaceEmptyStatus => 'Vide';

  @override
  String get settingsWorkspaceConfiguredStatus => 'Configuré';

  @override
  String get settingsWorkspaceOrganizationGroup => 'Organisation';

  @override
  String get settingsWorkspaceUsersAndAccessGroup => 'Users et accès';

  @override
  String get settingsWorkspaceSecurityGroup => 'Sécurité';

  @override
  String get settingsWorkspaceUnknownLabel => 'Indisponible';

  @override
  String get settingsWorkspaceDependencyBlockedLabel =>
      'Waiting pour requis setup';

  @override
  String get settingsWorkspaceRequiredSetupLabel => 'Configuration requise';

  @override
  String get settingsWorkspaceOptionalSetupLabel => 'Configuration facultative';

  @override
  String get settingsWorkspaceNoQuickActionsBody =>
      'Aucune action de configuration n\'est actuellement disponible pour le contexte sélectionné.';

  @override
  String get settingsWorkspaceNoModulesBody =>
      'No modules match le selected filtres.';

  @override
  String get settingsWorkspaceSelectTenantAction => 'Select locataire';

  @override
  String get settingsWorkspaceModuleTenant => 'Locataire';

  @override
  String get settingsWorkspaceModuleFacility => 'Établissement';

  @override
  String get settingsWorkspaceModuleBranch => 'Agence';

  @override
  String get settingsWorkspaceModuleDepartment => 'Département';

  @override
  String get settingsWorkspaceModuleUnit => 'Unité';

  @override
  String get settingsWorkspaceModuleRoom => 'Chambre';

  @override
  String get settingsWorkspaceModuleWard => 'Service';

  @override
  String get settingsWorkspaceModuleBed => 'Lit';

  @override
  String get settingsWorkspaceModuleAddress => 'Adresse';

  @override
  String get settingsWorkspaceModuleContact => 'Contact';

  @override
  String get settingsWorkspaceModuleUser => 'Utilisateur';

  @override
  String get settingsWorkspaceModuleUserProfile => 'User profil';

  @override
  String get settingsWorkspaceModuleRole => 'Rôle';

  @override
  String get settingsWorkspaceModulePermission => 'Autorisation';

  @override
  String get settingsWorkspaceModuleRolePermission => 'Role autorisation';

  @override
  String get settingsWorkspaceModuleUserRole => 'User rôle';

  @override
  String get settingsWorkspaceModuleUserSession => 'Session utilisateur';

  @override
  String get settingsWorkspaceModuleApiKey => 'Clé API';

  @override
  String get settingsWorkspaceModuleApiKeyPermission => 'API key autorisation';

  @override
  String get settingsWorkspaceModuleUserMfa => 'MFA utilisateur';

  @override
  String get settingsWorkspaceModuleOauthAccount => 'OAuth compte';

  @override
  String get pharmacyWorkflowReadinessTitle =>
      'Préparation du flux de travail en pharmacie';

  @override
  String get pharmacyWorkflowReadinessBody =>
      'Actions below follow le actuel commande, stock, batch, et attestation state.';

  @override
  String get pharmacyReadinessDispenseAvailable =>
      'La distribution est disponible pour l’état actuel de la commande.';

  @override
  String get pharmacyReadinessDispenseBlocked =>
      'La distribution est bloquée par l\'état actuel de la commande, du paiement, du stock ou de l\'autorisation.';

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
      'Aucune attestation de lot préparé n’est en attente.';

  @override
  String get pharmacyReadinessPrintReady =>
      'Les impressions de médicaments utilisent le flux de travail d\'impression configuré.';

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
  String get labReferenceRangesAction => 'Configurations de laboratoire';

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
  String get labOrdersColumnLabel => 'Ordres';

  @override
  String get labPatientIdFieldLabel => 'ID du patient';

  @override
  String get labVerifyAllAction => 'Verify tous';

  @override
  String get labEntryStatusColumnLabel => 'Entry statut';

  @override
  String get labSelectOrderDialogTitle => 'Select laboratoire commande';

  @override
  String get labSelectOrderDialogBody =>
      'Ce patient a plusieurs ordonnances de laboratoire actives. Sélectionnez la commande à examiner.';

  @override
  String get labNoOrderItemsLabel => 'Aucun ordered tests trouvé';

  @override
  String get labTestCodeLabel => 'Code d\'essai';

  @override
  String get labVerifyResultAction => 'Verify résultat';

  @override
  String get labEditVerifiedResultAction => 'Edit vérifié résultat';

  @override
  String get labReopenVerifiedResultDialogTitle => 'Edit vérifié résultat';

  @override
  String get labReopenVerifiedResultDialogBody =>
      'Mettez à jour la valeur du résultat et indiquez la raison de la modification d\'un résultat vérifié. La valeur corrigée est revérifiée lorsque vous enregistrez.';

  @override
  String get labReopenVerifiedReasonLabel => 'Reason pour modifier';

  @override
  String get labVerifiedResultReopenedMessage =>
      'Result reopened pour editing.';

  @override
  String get labRestoreOrderItemAction => 'Test de restauration';

  @override
  String get labRestoreOrderItemDialogTitle => 'Restore annulé test';

  @override
  String labRestoreOrderItemDialogBody(String testName) {
    return 'Restaurer \"$testName\" ? Il a été annulé et reviendra à la liste de travail active pour traitement.';
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
    return 'Cela supprimera$panelNameà partir du catalogue de laboratoire configurable. Une raison est requise pour la piste d’audit.';
  }

  @override
  String get labRejectOrderItemAction => 'Rejeter le test';

  @override
  String get labResultFlagLabel => 'Drapeau';

  @override
  String get labVerifyResultDialogTitle => 'Enter et verify résultat';

  @override
  String get labNumericRangeValidationMessage => 'Enter un valid number.';

  @override
  String get labVerifyAllDialogTitle => 'Verify entered résultats';

  @override
  String get labRejectOrderItemDialogTitle => 'Rejeter le test demandé';

  @override
  String get labRejectReasonNotPerformedHere => 'Test non effectué ici';

  @override
  String get labRejectReasonInsufficientInfo => 'Informations insuffisantes';

  @override
  String get labRejectReasonInvalidRequest => 'Requête invalide';

  @override
  String get labRejectReasonOther => 'Autre raison';

  @override
  String get labRejectCustomReasonLabel => 'Raison personnalisée';

  @override
  String get labReferenceRangesDialogTitle => 'Configurations de laboratoire';

  @override
  String get labReferenceRangesDialogBody =>
      'Manage laboratoire tests, panels, unités, qualitative options, et référence ranges utilisé by backend résultat interpretation.';

  @override
  String get labConfigureTestAction => 'Configurer le test';

  @override
  String get labQcLogsAction => 'Journaux de CQ';

  @override
  String get labConfigureTestDialogTitle => 'Configure laboratoire test';

  @override
  String get labTestNameLabel => 'Test nom';

  @override
  String get labCategoryLabel => 'Catégorie';

  @override
  String get labSpecimenTypeLabel => 'Type d\'échantillon';

  @override
  String get labResultKindLabel => 'Type de résultat';

  @override
  String get labResultKindNumeric => 'Numérique';

  @override
  String get labResultKindQualitative => 'Qualitatif';

  @override
  String get labResultKindText => 'Texte';

  @override
  String get labDefaultUnitLabel => 'Default unité';

  @override
  String get labUnitOptionsLabel => 'Options d\'unité';

  @override
  String get labCommaSeparatedHelper =>
      'Separate multiple valeurs avec commas.';

  @override
  String get labQualitativeOptionsLabel => 'Qualitative résultat options';

  @override
  String get labGenderApplicabilityLabel => 'Applicabilité selon le genre';

  @override
  String get labGenderAnyLabel => 'N\'importe lequel';

  @override
  String get labGenderMaleLabel => 'Homme';

  @override
  String get labGenderFemaleLabel => 'Femme';

  @override
  String get labAgeMinLabel => 'Âge minimum';

  @override
  String get labAgeMaxLabel => 'Âge maximum';

  @override
  String get labAgeUnitLabel => 'Age unité';

  @override
  String get labAgeUnitDays => 'Jours';

  @override
  String get labAgeUnitMonths => 'Mois';

  @override
  String get labAgeUnitYears => 'Années';

  @override
  String get labNormalMinLabel => 'Normale min';

  @override
  String get labNormalMaxLabel => 'Normale maximum';

  @override
  String get labCriticalMinLabel => 'Min critique';

  @override
  String get labCriticalMaxLabel => 'Maximum critique';

  @override
  String get labReferenceTextLabel => 'Texte de référence';

  @override
  String get labStatusPendingResults => 'Pending résultats';

  @override
  String get labStatusVerified => 'Vérifié';

  @override
  String get labStatusLow => 'Faible';

  @override
  String get labStatusHigh => 'Haut';

  @override
  String get labNextActionVerify => 'Verify résultat';

  @override
  String get labNextActionEnterResult => 'Enter résultat';

  @override
  String get labCreateAction => 'Créer une commande de laboratoire';

  @override
  String get labCreateChoiceDialogTitle => 'Create laboratory élément';

  @override
  String get labCreateChoiceDialogBody =>
      'Choose le laboratory dossier you want à créer.';

  @override
  String get labCreateOrderAction => 'Create laboratoire commande';

  @override
  String get labCreateOrderChoiceBody =>
      'Demandez des tests ou des panels pour un patient.';

  @override
  String get labCreateOrderDialogTitle => 'Create laboratoire commande';

  @override
  String get labCreateTestAction => 'Ajouter un test';

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
  String get labPanelCodeLabel => 'Code du panneau';

  @override
  String get labPanelDescriptionLabel => 'Description';

  @override
  String get labReferenceRangesSearchHint =>
      'Search test, panneau, code, catégorie, specimen, unité, ou range';

  @override
  String get labActionColumnLabel => 'Action';

  @override
  String get labUnitRangeCountColumnLabel => 'Unité / plages';

  @override
  String get labGenderOtherLabel => 'Autre';

  @override
  String get labGenderUnknownLabel => 'Inconnu';

  @override
  String get labAgeUnitWeeks => 'Semaines';

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
  String get labDeleteTestAction => 'Supprimer l\'essai';

  @override
  String get labDeleteReasonLabel => 'Motif de suppression';

  @override
  String get labDeleteReasonHint =>
      'Expliquez pourquoi ce dossier de laboratoire doit être supprimé';

  @override
  String get labDeleteReasonValidationMessage => 'Enter un deletion reason.';

  @override
  String get labDeleteOrderDialogTitle => 'Delete laboratoire commande';

  @override
  String labDeleteOrderDialogBody(String orderId) {
    return 'Cela supprimera l\'ordre du laboratoire${orderId}de la file d\'attente active du laboratoire. Une raison est requise pour la piste d’audit.';
  }

  @override
  String get labDeleteTestDialogTitle => 'Delete laboratoire test';

  @override
  String labDeleteTestDialogBody(String testName) {
    return 'Cela supprimera$testNameà partir du catalogue de laboratoire configurable. Une raison est requise pour la piste d’audit.';
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
  String get labPanelTestsLabel => 'Tests sur panel';

  @override
  String get labPanelTestSelectLabel => 'Test en laboratoire';

  @override
  String get labPanelAddTestAction => 'Ajouter un test';

  @override
  String get labPanelSelectedTestsTitle => 'Tests sélectionnés';

  @override
  String get labPanelNoSelectedTests => 'No tests selected pour ce panneau.';

  @override
  String get labTestDescriptionLabel => 'Description de l\'essai';

  @override
  String get labReferenceNotesLabel => 'Notes de référence';

  @override
  String get labPositiveOption => 'Positif';

  @override
  String get labNegativeOption => 'Négatif';

  @override
  String get labAdultRangeLabel => 'Adulte';

  @override
  String get labPediatricRangeLabel => 'Pédiatrique';

  @override
  String get labNeonateRangeLabel => 'Nouveau-né';

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
  String get labResetReportSelectionAction => 'Réinitialiser la sélection';

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
    return '${selectedCount}sur${totalCount}tests selected';
  }

  @override
  String get labReportIncludeColumnLabel => 'Inclure';

  @override
  String get labReportNoSelectionLabel => 'No rapport éléments selected';

  @override
  String get labOrdersIncludedLabel => 'Commandes incluses';

  @override
  String get labRemoveDraftResultAction => 'Remove résultat';

  @override
  String get labRemoveDraftResultDialogTitle => 'Remove laboratoire résultat?';

  @override
  String get labRemoveDraftResultDialogBody =>
      'Ce brouillon de résultat sera supprimé du test sélectionné.';

  @override
  String get labDraftRemovedMessage => 'Résultat supprimé.';

  @override
  String get labStatusFilled => 'Rempli';

  @override
  String get labStatusPartiallyEntered => 'Partiellement entré';

  @override
  String get labStatusPartiallyFilled => 'Partiellement rempli';

  @override
  String get labReportSignatureLabel => 'Signature/cachet';

  @override
  String labReferenceRangeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ranges',
      one: '1 gamme',
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
  String get radiologyConfigurationsDialogTitle =>
      'Configurations de radiologie';

  @override
  String get radiologyConfigurationsDialogBody =>
      'Manage persisted imaging tests et customize standard catalog tests pour radiologie workflows.';

  @override
  String get radiologyConfigurationsLoadingTitle =>
      'Chargement des configurations';

  @override
  String get radiologyConfigurationsLoadingBody =>
      'Loading imaging tests et standard catalog entries.';

  @override
  String get radiologyPatientsSummaryLabel => 'Patients en radiologie';

  @override
  String get radiologyPatientsWaitingImagingSummaryLabel =>
      'Patients en attente d’imagerie';

  @override
  String get radiologyPatientsWorklistTitle => 'Patients en radiologie';

  @override
  String get radiologyPatientsWorklistDescription =>
      'Patients grouped by actif imaging commandes, reporting statut, et suivant action.';

  @override
  String get radiologyNoPatientsTitle => 'No radiologie patients';

  @override
  String get radiologyNoPatientsBody =>
      'Les patients dont les demandes d’imagerie correspondent à cette recherche et à ce filtre apparaîtront ici.';

  @override
  String get radiologyTableColumnsTitle => 'Radiology colonnes';

  @override
  String get radiologyApplyColumnsAction => 'Apply colonnes';

  @override
  String get radiologyResetColumnsAction => 'Reset colonnes';

  @override
  String get radiologyOrdersColumnLabel => 'Ordres)';

  @override
  String get radiologyOneActiveOrderLabel => '1 actif commande';

  @override
  String get radiologyReferenceSearchOptionalLabel =>
      'Catalog recherche (facultatif)';

  @override
  String get radiologySelectImagingTestsAction =>
      'Sélectionnez des tests d\'imagerie';

  @override
  String get radiologyClearSelectedTestsAction =>
      'Effacer les tests sélectionnés';

  @override
  String get radiologySelectAtLeastOneTestMessage =>
      'Sélectionnez au moins un test d\'imagerie.';

  @override
  String get radiologyModalityFluoroscopy => 'FLUOROSCOPIE';

  @override
  String get radiologyModalityMammography => 'MAMMOGRAPHIE';

  @override
  String get radiologyModalityNuclearMedicine => 'MÉDECINE NUCLÉAIRE';

  @override
  String get radiologyModalityInterventionalRadiology =>
      'RADIOLOGIE INTERVENTIONNELLE';

  @override
  String get radiologyImagingTestsTabLabel => 'Tests d\'imagerie';

  @override
  String get radiologyEquipmentTabLabel => 'Équipement';

  @override
  String get radiologyConfigurationSearchLabel =>
      'Search radiologie configurations';

  @override
  String get radiologyConfigurationSearchHint =>
      'Search tests, modality, code, source, ou statut';

  @override
  String get radiologyCreateImagingTestAction => 'Créer un test d\'imagerie';

  @override
  String get radiologyEditImagingTestAction => 'Modifier le test d\'imagerie';

  @override
  String get radiologyDeleteImagingTestAction =>
      'Supprimer le test d\'imagerie';

  @override
  String get radiologyCopyStandardTestAction => 'Copier le test standard';

  @override
  String get radiologyStandardCatalogBadge => 'Catalogue standard';

  @override
  String get radiologyCustomCatalogBadge => 'Coutume';

  @override
  String get radiologyTestNameLabel => 'Nom';

  @override
  String get radiologyTestCodeLabel => 'Code';

  @override
  String get radiologyTestCodeOptionalLabel => 'Code (facultatif)';

  @override
  String get radiologySourceColumnLabel => 'Source';

  @override
  String get radiologyEquipmentColumnLabel => 'Équipement';

  @override
  String get radiologyActionColumnLabel => 'Action';

  @override
  String get radiologyNoImagingTestsTitle => 'Aucun test d\'imagerie';

  @override
  String get radiologyNoImagingTestsBody =>
      'Create un personnalisé imaging test ou actualiser le standard catalog.';

  @override
  String get radiologyReadOnlyStandardTestTitle =>
      'Le test standard est en lecture seule';

  @override
  String get radiologyReadOnlyStandardTestMessage =>
      'Standard catalog lignes ne peut pas be edited directly. Copy one à enregistrer un personnalisé test.';

  @override
  String get radiologyDeleteImagingTestDialogTitle =>
      'Supprimer le test d\'imagerie ?';

  @override
  String get radiologyTenantRequiredForConfigMessage =>
      'Tenant context est requis avant un personnalisé imaging test can be saved.';

  @override
  String get radiologyEquipmentRecordsTitle => 'Equipment dossiers';

  @override
  String get radiologyEquipmentRecordsBody =>
      'L\'équipement est géré via le registre d\'équipement existant.';

  @override
  String get radiologyEquipmentNameColumnLabel => 'Équipement';

  @override
  String get radiologyEquipmentCodeColumnLabel =>
      'Identifiant de l\'équipement';

  @override
  String get radiologyManufacturerModelLabel => 'Fabricant / modèle';

  @override
  String get radiologyEquipmentCategoryLabel => 'Catégorie';

  @override
  String get radiologyFacilityColumnLabel => 'Établissement';

  @override
  String get radiologyEquipmentSearchHint =>
      'Search équipement nom, code, serial, manufacturer, model, catégorie, ou statut';

  @override
  String get radiologyNoEquipmentTitle => 'No équipement dossiers';

  @override
  String get radiologyNoEquipmentBody =>
      'Les enregistrements du registre des équipements correspondant à cette recherche apparaîtront ici.';

  @override
  String get radiologyEquipmentLinkGapTitle =>
      'Test équipement mapping indisponible';

  @override
  String get radiologyEquipmentLinkGapBody =>
      'Le schéma back-end actuel ne conserve pas de relation directe entre le test d\'imagerie et l\'équipement. Cet espace de travail n\'enregistre donc pas les mappages locaux uniquement.';

  @override
  String get radiologySaveConfigurationAction => 'Enregistrer la configuration';

  @override
  String get radiologyAttachImagesTitle => 'Joindre des images';

  @override
  String get radiologyAttachImagesBody =>
      'Choose one ou more images, ajouter captions, then upload à attach them à ce study.';

  @override
  String get radiologyUploadImagesAction => 'Télécharger des images';

  @override
  String get radiologyAssetCaptionLabel => 'Légende';

  @override
  String get radiologyRemoveAssetAction => 'Supprimer l\'image';

  @override
  String get radiologyPrintIncludeImagesLabel => 'Inclure des images d\'étude';

  @override
  String get radiologyChooseImagesAction => 'Choisissez des images';

  @override
  String get radiologyClearSelectedImagesAction => 'Images claires';

  @override
  String get radiologyReportReferencesTitle => 'Références du rapport';

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
      'Choisissez les sections du rapport clinique à inclure. Le contexte du patient, les détails du test, les résultats, l\'impression et le signataire sont sélectionnés par défaut ; les métadonnées sont facultatives.';

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
  String get radiologyPrintIncludeStudiesLabel => 'Tests/études d\'imagerie';

  @override
  String get radiologyPrintIncludeReportLabel => 'Findings et rapport text';

  @override
  String get radiologyPrintIncludeReferencesLabel => 'Références images/PACS';

  @override
  String get radiologyPrintIncludeSignerLabel => 'Signataire/journaliste';

  @override
  String get radiologyPrintIncludeMetadataLabel => 'Métadonnées techniques';

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
  String get radiologyPatientIdLabel => 'ID du patient';

  @override
  String get radiologyFinalizationRequestedLabel => 'Finalisation demandée';

  @override
  String get radiologyFinalizationAttestedLabel => 'Finalisation attestée';

  @override
  String radiologyActiveOrdersLabel(int count) {
    return '${count}actif commandes';
  }

  @override
  String radiologyDeleteImagingTestDialogBody(String name) {
    return 'Supprimer$name? Ce test d\'imagerie personnalisé ne sera plus disponible pour les nouvelles demandes.';
  }

  @override
  String radiologyInsertAssetReferenceAction(String label) {
    return 'Insert actif:$label';
  }

  @override
  String radiologyInsertPacsReferenceAction(String label) {
    return 'Insert PACS:$label';
  }

  @override
  String radiologyPrintStudyCount(int count) {
    return '${count}studies';
  }

  @override
  String get clinicalRequestBillingSectionTitle => 'Demander une facturation';

  @override
  String get clinicalRequestAddCatalogItemsAction => 'Add éléments';

  @override
  String get clinicalRequestReviewBillingAction => 'Vérifier la facturation';

  @override
  String get clinicalRequestCatalogPickerDoneAction => 'Fait';

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
  String get clinicalRadiologyCatalogPickerTitle =>
      'Choisir une étude d\'imagerie';

  @override
  String get clinicalRadiologyAddStudyAction => 'Ajouter une étude';

  @override
  String get clinicalProcedureCatalogPickerTitle => 'Choisir les procédures';

  @override
  String get clinicalPrescriptionLineDialogTitle => 'Ajouter un médicament';

  @override
  String get clinicalPrescriptionEditLineDialogTitle =>
      'Modifier le médicament';

  @override
  String get clinicalPrescriptionNoMedicinesLabel =>
      'Aucun médicament ajouté pour l\'instant';

  @override
  String get clinicalRequestBillingNoItemsLabel =>
      'Add éléments à see pricing.';

  @override
  String get clinicalRequestBillingTotalLabel => 'Total';

  @override
  String get clinicalRequestPriceNotSetLabel => 'Prix ​​non fixé';

  @override
  String get clinicalRequestPriceWarningLabel =>
      'Some éléments have non prix set';

  @override
  String get clinicalRequestUnitPriceLabel => 'Unit prix';

  @override
  String get clinicalRequestQuantityLabel => 'Qté';

  @override
  String get clinicalRequestEditPricesHint =>
      'Set ou adjust prices per élément, ou charge un single montant.';

  @override
  String get ipdWardRoundFeeLabel => 'Frais d\'examen par le médecin';

  @override
  String get theaterCaseFeeLabel => 'Operation / procédure fee';

  @override
  String get clinicalProcedureFeeLabel => 'Frais de procédure';

  @override
  String get clinicalRequestBillLaterAction => 'Bill plus tard';

  @override
  String get clinicalRequestPayNowAction => 'Payez maintenant';

  @override
  String get clinicalRequestPaymentPaidLabel => 'Payant';

  @override
  String get clinicalRequestPaymentPartialLabel => 'Partiel';

  @override
  String get clinicalRequestPaymentUnpaidLabel => 'Non rémunéré';

  @override
  String get clinicalRequestPaymentNotBilledLabel => 'Non facturé';

  @override
  String get radiologyOrderMetadataTitle => 'Métadonnées de commande';

  @override
  String get radiologyOrderMetadataSubtitle =>
      'Timing, modality, et paiement context';

  @override
  String get radiologyViewModeImagingFloorLabel => 'Étage d\'imagerie';

  @override
  String get radiologyViewModeReportingLabel => 'Rapports';

  @override
  String get radiologyViewModeToggleLabel => 'Mode d\'affichage';

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
    return '${completed}sur${total}steps complete';
  }

  @override
  String get radiologyStudiesPerformStudyCta => 'Effectuer une étude';

  @override
  String get radiologyStudiesUploadImagesCta => 'Télécharger des images';

  @override
  String get radiologyStudiesPerformFirstHint =>
      'Perform le study avant uploading images.';

  @override
  String get radiologyStudiesReportPreviewTitle => 'Report aperçu';

  @override
  String get radiologyDoctorReviewOpenReportAction => 'Ouvrir le rapport';

  @override
  String get radiologyDoctorReviewAcknowledgeAction =>
      'Accuser réception de l\'avis';

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
  String get radiologyPrescriptionBillOnDispenseLabel =>
      'Facture à la distribution';

  @override
  String get radiologyPrescriptionPayAtPrescribeLabel =>
      'Payer à la prescription';

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
  String get accessAdminPanelOverview => 'Présentation';

  @override
  String get accessAdminPanelDirectory => 'Annuaire des utilisateurs';

  @override
  String get accessAdminPanelRoles => 'Rôles';

  @override
  String get accessAdminPanelPermissions => 'Autorisations';

  @override
  String get accessAdminPanelEntitlements => 'Droits des modules';

  @override
  String get accessAdminPanelDemo => 'Comptes démo';

  @override
  String get accessAdminPanelRegistrations => 'Inscriptions en attente';

  @override
  String get accessAdminPhoneLabel => 'Téléphone';

  @override
  String get accessAdminActivateRegistrationAction => 'Activate compte';

  @override
  String get accessAdminRejectRegistrationAction => 'Rejeter';

  @override
  String get accessAdminActiveUsersLabel => 'Active utilisateurs';

  @override
  String get accessAdminRolesLabel => 'Rôles';

  @override
  String get accessAdminPermissionsLabel => 'Autorisations';

  @override
  String get accessAdminModulesLabel => 'Modules actifs';

  @override
  String get accessAdminSearchLabel => 'Search accès dossiers';

  @override
  String get accessAdminSearchHint =>
      'Search by nom, e-mail, rôle, ou autorisation';

  @override
  String get accessAdminStatusLabel => 'Statut';

  @override
  String get accessAdminAllStatusesLabel => 'Tous les statuts';

  @override
  String get accessAdminEmptyTitle => 'Aucun access records trouvé';

  @override
  String get accessAdminEmptyBody =>
      'Adjust filtres ou créer utilisateurs et rôles à populate ce espace de travail.';

  @override
  String get accessAdminColumnId => 'IDENTIFIANT';

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
  String get accessAdminOpenHrProfileAction => 'Ouvrir un profil RH';

  @override
  String get accessAdminClinicalRoleHint =>
      'Ce rôle débloque les actions de flux de travail clinique OPD/IPD.';

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
  String get hrReferenceStaffPositionNurse => 'IInfirmier/nfirmière';

  @override
  String get hrReferenceStaffPositionSeniorNurse => 'Infirmière principale';

  @override
  String get hrReferenceStaffPositionStaffNurse => 'Infirmier';

  @override
  String get hrReferenceStaffPositionTheatreNurse => 'Infirmière de théâtre';

  @override
  String get hrReferenceStaffPositionScrubNurse => 'instrumentiste';

  @override
  String get hrReferenceStaffPositionWardManager => 'Cadre de Proximité';

  @override
  String get hrReferenceStaffPositionMidwife => 'Sage-femme';

  @override
  String get hrReferenceStaffPositionNursingAssistant => 'Aides-infirmiers';

  @override
  String get hrReferenceStaffPositionDoctor => 'Doctorat';

  @override
  String get hrReferenceStaffPositionConsultantPhysician =>
      'médecin consultant';

  @override
  String get hrReferenceStaffPositionMedicalOfficer => 'Médecin chef';

  @override
  String get hrReferenceStaffPositionResidentDoctor => 'Médecin résidant ';

  @override
  String get hrReferenceStaffPositionIntern => 'Stagiaire';

  @override
  String get hrReferenceStaffPositionGeneralPractitioner =>
      'Médecin généraliste';

  @override
  String get hrReferenceStaffPositionSurgeon => 'Chirurgien';

  @override
  String get hrReferenceStaffPositionAnaesthetist => 'Médecin anesthésiste :.';

  @override
  String get hrReferenceStaffPositionPaediatrician => 'Pédiatre';

  @override
  String get hrReferenceStaffPositionObgyn => 'Obstétricien/Gynécologue';

  @override
  String get hrReferenceStaffPositionPsychiatrist => 'Psychiatre';

  @override
  String get hrReferenceStaffPositionEmergencyPhysician => 'Médecin urgentiste';

  @override
  String get hrReferenceStaffPositionFamilyMedicinePhysician =>
      'Médecin de famille';

  @override
  String get hrReferenceStaffPositionDentalSurgeon => 'Chirurgien-dentiste';

  @override
  String get hrReferenceStaffPositionNursePractitioner =>
      'Infirmière praticienne';

  @override
  String get hrReferenceStaffPositionPhysiotherapist => 'Kinésithérapeute';

  @override
  String get hrReferenceStaffPositionOccupationalTherapist => 'Ergothérapeute';

  @override
  String get hrReferenceStaffPositionSpeechTherapist => 'Orthophoniste';

  @override
  String get hrReferenceStaffPositionDietitian => 'Diététique';

  @override
  String get hrReferenceStaffPositionClinicalPsychologist =>
      'Psychologue-Clinicienne';

  @override
  String get hrReferenceStaffPositionSocialWorker => 'Assistant social ';

  @override
  String get hrReferenceStaffPositionRespiratoryTherapist => 'Inhalothérapeute';

  @override
  String get hrReferenceStaffPositionLabTechnologist =>
      'Technologue de laboratoire';

  @override
  String get hrReferenceStaffPositionMedicalLaboratoryScientist =>
      'Scientifiques de laboratoire d&apos;analyses médicales';

  @override
  String get hrReferenceStaffPositionPhlebotomist => 'Phlébotomiste';

  @override
  String get hrReferenceStaffPositionRadiologist => 'Radiologue';

  @override
  String get hrReferenceStaffPositionSonographer => 'Échographiste';

  @override
  String get hrReferenceStaffPositionEcgTechnician => 'Techniciens ECG';

  @override
  String get hrReferenceStaffPositionPharmacist => 'Pharmacien';

  @override
  String get hrReferenceStaffPositionPharmacyTechnician =>
      'Technicien en pharmacie';

  @override
  String get hrReferenceStaffPositionPharmacyAssistant =>
      'assistant en pharmacie;';

  @override
  String get hrReferenceStaffPositionAdministrator => 'Administrateur';

  @override
  String get hrReferenceStaffPositionHrOfficer => 'Responsable RH';

  @override
  String get hrReferenceStaffPositionReceptionist => 'Réceptionniste';

  @override
  String get hrReferenceStaffPositionMedicalRecordsOfficer =>
      'Responsable des dossiers médicaux';

  @override
  String get hrReferenceStaffPositionHealthInformationOfficer =>
      'Responsable de l\'information sur la santé';

  @override
  String get hrReferenceStaffPositionPatientRelationsOfficer =>
      'Responsable des relations avec les patients';

  @override
  String get hrReferenceStaffPositionBillingClerk => 'Commis à la facturation';

  @override
  String get hrReferenceStaffPositionAccountsOfficer =>
      '<g id=\"1\"> </g>Agent des comptes/';

  @override
  String get hrReferenceStaffPositionInsuranceOfficer => 'Agent d\'assurance';

  @override
  String get hrReferenceStaffPositionCashier => 'Caissier';

  @override
  String get hrReferenceStaffPositionHousekeeper => 'Femme (homme) de ménage';

  @override
  String get hrReferenceStaffPositionPorter => 'Brancardier';

  @override
  String get hrReferenceStaffPositionSecurityOfficer =>
      'Responsable de la sécurité';

  @override
  String get hrReferenceStaffPositionLaundryAttendant =>
      'Préposé à la blanchisserie';

  @override
  String get hrReferenceStaffPositionKitchenStaff => 'Personnel de cuisine';

  @override
  String get hrReferenceStaffPositionMortuaryAttendant => 'Préposé à la morgue';

  @override
  String get hrReferenceStaffPositionAmbulanceDriver =>
      'Chauffeur d&apos;ambulance';

  @override
  String get hrReferenceStaffPositionAmbulanceOperator => 'ambulancier';

  @override
  String get hrReferenceStaffPositionBiomedicalEngineer =>
      'Ingénieur Biomédical';

  @override
  String get hrReferenceStaffPositionItSupportOfficer =>
      'Chargé de support informatique';

  @override
  String get hrReferenceStaffPositionMaintenanceTechnician =>
      'Technicien de maintenance';

  @override
  String get hrReferenceStaffPositionHospitalAdministrator =>
      'Administrateur de l\'hôpital';

  @override
  String get hrReferenceStaffPositionDepartmentHead => 'Chef de service';

  @override
  String get hrReferenceStaffPositionChiefNursingOfficer =>
      'ONC (infirmière en chef)';

  @override
  String get hrReferenceStaffPositionOperationsManager =>
      'Directeur des Opérations';

  @override
  String get hrReferenceStaffPositionFacilityManager =>
      'Directeur de l\'établissement';

  @override
  String get hrReferenceRoleTenantAdmin => 'Administrateur de l\'organisation';

  @override
  String get hrReferenceRoleFacilityAdmin => 'Administrateur d’établissement';

  @override
  String get hrReferenceRoleHr => 'Responsable RH / Effectif';

  @override
  String get hrReferenceRoleOperations => 'Directeur des Opérations';

  @override
  String get hrReferenceRoleItSupport => 'SPÉCIALISTE DU SUPPORT';

  @override
  String get hrReferenceRoleDoctor => 'Médecin / Clinicien';

  @override
  String get hrReferenceRoleAttendingPhysician => 'Médecin Traitant: ';

  @override
  String get hrReferenceRoleResidentPhysician => 'Médecin interne';

  @override
  String get hrReferenceRoleSurgeon => 'Chirurgien';

  @override
  String get hrReferenceRoleAnesthesiologist =>
      '     - Médecin anesthésiste :.';

  @override
  String get hrReferenceRolePhysicianAssistant => 'Médecin assistant';

  @override
  String get hrReferenceRoleEmergencyPhysician => 'Médecin urgentiste';

  @override
  String get hrReferenceRoleNurse => 'Infirmière autorisée (IA)';

  @override
  String get hrReferenceRoleLicensedPracticalNurse =>
      'Infirmière auxiliaire agréée';

  @override
  String get hrReferenceRoleNursePractitioner => 'Infirmière praticienne';

  @override
  String get hrReferenceRoleTriageNurse => 'IAO:';

  @override
  String get hrReferenceRoleMidwife => 'Sage-femme';

  @override
  String get hrReferenceRoleChargeNurse => 'Cadres infirmiers';

  @override
  String get hrReferenceRolePhysiotherapist =>
      '• Physiothérapeute ou kinésithérapeute';

  @override
  String get hrReferenceRoleOccupationalTherapist => 'Ergothérapeute';

  @override
  String get hrReferenceRoleRespiratoryTherapist => 'Inhalothérapeute';

  @override
  String get hrReferenceRoleDietitian => 'Diététicien / Nutritionniste';

  @override
  String get hrReferenceRoleSocialWorker =>
      'travailleur social - secteur médical';

  @override
  String get hrReferenceRoleClinicalPsychologist => 'Psychologue-Clinicienne';

  @override
  String get hrReferenceRoleLabTech => 'Technologue de laboratoire';

  @override
  String get hrReferenceRoleMedicalLaboratoryScientist =>
      'Scientifiques de laboratoire d&apos;analyses médicales';

  @override
  String get hrReferenceRolePathologist => 'Pathologiste';

  @override
  String get hrReferenceRoleRadiologyTech =>
      'Technologue en radiologie / imagerie';

  @override
  String get hrReferenceRoleSonographer => 'Sonographe /Technologue échographe';

  @override
  String get hrReferenceRolePharmacist => 'Pharmacien';

  @override
  String get hrReferenceRolePharmacyTechnician => 'Technicien en pharmacie';

  @override
  String get hrReferenceRoleReceptionist => 'Réceptionniste / Réception';

  @override
  String get hrReferenceRoleAdmissionsCoordinator =>
      'Coordonnateur des admissions';

  @override
  String get hrReferenceRoleMedicalRecordsClerk =>
      'Commis aux dossiers médicaux';

  @override
  String get hrReferenceRoleBilling => 'Facturation / Caisse';

  @override
  String get hrReferenceRoleMedicalCoder =>
      'Codeur médical/Spécialiste du codage';

  @override
  String get hrReferenceRoleAmbulanceOperator => 'ambulancier';

  @override
  String get hrReferenceRoleParamedic => 'Personnel paramédical';

  @override
  String get hrReferenceRoleEmt => 'Auxiliaire médical d&apos;urgence';

  @override
  String get hrReferenceRoleHouseKeeper => 'Les hommes ou femmes de ménage';

  @override
  String get hrReferenceRoleHousekeepingManager =>
      'Responsable de l\'entretien ménager';

  @override
  String get hrReferenceRoleFoodServiceWorker =>
      'Préposé aux services alimentaires de café';

  @override
  String get hrReferenceRolePorter => 'Porteur / Infirmier';

  @override
  String get hrReferenceRoleSecurityOfficer => 'Responsable de la sécurité';

  @override
  String get hrReferenceRoleMaintenanceEngineer => 'Ingénieur Maintenance';

  @override
  String get hrReferenceRoleChaplain => 'aumônier de l\'hopital';

  @override
  String get hrReferenceRoleBiomed => 'Ingénieur / technicien biomédical';

  @override
  String get hrReferenceRoleBiomedManager => 'Responsable biomédical';

  @override
  String get hrReferenceRoleUnitManager => 'Responsable unite';

  @override
  String get hrReferenceRoleWardManager =>
      'Responsable de service /Infirmière de charge';

  @override
  String get hrReferenceRoleIcuManager =>
      'Responsable de l\'unité de soins inten';

  @override
  String get hrReferenceRoleTheatreManager =>
      'Responsable Théâtre / Périopératoire';

  @override
  String get hrReferenceRoleMortuaryStaff => 'Préposé à la morgue';

  @override
  String get hrReferenceRoleMortuaryManager => 'Responsable de la morgue';

  @override
  String get hrReferencePractitionerTypeMo => 'Médecin Officier (MO)';

  @override
  String get hrReferencePractitionerTypeSpecialist =>
      'Spécialiste / Consultant';

  @override
  String get hrReferencePractitionerTypeResident =>
      'Résident / Officier de l\'état civil';

  @override
  String get hrReferencePractitionerTypeIntern =>
      'Stagiaire /Officier de maison';

  @override
  String get hrReferencePractitionerTypeGp => 'Médecin généraliste/généraliste';

  @override
  String get hrReferencePractitionerTypeSurgeon => 'Chirurgien';

  @override
  String get hrReferencePractitionerTypeAnaesthetist =>
      'Médecin anesthésiste :.';

  @override
  String get hrReferencePractitionerTypePaediatrician => 'Pédiatre';

  @override
  String get hrReferencePractitionerTypeObgyn => 'Obstétricien/Gynécologue';

  @override
  String get hrReferencePractitionerTypeNursePractitioner =>
      'Infirmière praticienne';

  @override
  String get hrReferencePractitionerTypeDentist => 'Dentiste';

  @override
  String get hrReferencePractitionerTypePsychiatrist => 'Psychiatre';

  @override
  String get hrReferencePractitionerTypeEmergencyMedicine =>
      'Médecin urgentiste';

  @override
  String get hrReferencePractitionerTypeFamilyMedicine => 'Médecin de famille';

  @override
  String get hrReferencePractitionerTypePathologist => 'Pathologiste';

  @override
  String get hrReferencePractitionerTypeRadiologist => 'Radiologue';

  @override
  String get hrReferencePractitionerTypeDermatologist => 'Dermatologue';

  @override
  String get hrReferencePractitionerTypeCardiologist => 'Cardiologie';

  @override
  String get hrReferencePractitionerTypeOphthalmologist => 'Ophtalmologiste';

  @override
  String get hrReferencePractitionerTypeOrthopaedicSurgeon => 'Orthopédie';

  @override
  String get hrReferenceCompensationPayTypePerConsultation =>
      'Frais de consultation';

  @override
  String get hrReferenceCompensationPayTypePerMonth => 'Salaire mensuel';

  @override
  String get hrReferenceCompensationPayTypePerDay => 'Salaire journalier';

  @override
  String get hrReferenceCompensationPayTypePerHour => 'Taux Horaire';

  @override
  String get hrReferenceCompensationPayTypePerProcedure =>
      'Par procédure / par tâche';

  @override
  String get hrReferenceLeaveTypeAnnual => 'Congé annuel';

  @override
  String get hrReferenceLeaveTypeSick => 'Congés maladie';

  @override
  String get hrReferenceLeaveTypeMaternity => 'Congé de maternité';

  @override
  String get hrReferenceLeaveTypePaternity => 'Congé de paternité';

  @override
  String get hrReferenceLeaveTypeCompassionate => 'Congé de compassion / deuil';

  @override
  String get hrReferenceLeaveTypeUnpaid => 'Congés sans solde';

  @override
  String get hrReferenceLeaveTypeStudy => 'Congé d\'études / de formation';

  @override
  String get hrReferenceLeaveTypeEmergency =>
      'congé pour une situation d’urgence;';

  @override
  String get hrReferenceLeaveTypeOther => 'Autres congés';

  @override
  String get hrReferenceLeaveHalfDayPeriodMorning => 'Matin';

  @override
  String get hrReferenceLeaveHalfDayPeriodAfternoon => 'Après-midi';
}
