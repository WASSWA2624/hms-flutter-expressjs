import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/utils/app_display.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/presentation/controllers/opd_encounter_dialog_controller.dart';
import 'package:hosspi_hms/features/opd/presentation/controllers/opd_workspace_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';
import 'package:hosspi_hms/shared/layout/app_workspace_feedback.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_action_context.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_admission_handoff_dialog.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_billing_state.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_consultation_payment_dialog.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_disposition_dialog.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_encounter_clinical_services.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_follow_up_dialog.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_print_summary_dialog.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_provider_options.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_referral_dialog.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_routing_decision_dialog.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_status_display.dart';
import 'package:hosspi_hms/shared/opd_actions/record_vitals_dialog.dart';

const List<AppRole> _opdAdminActionRoles = <AppRole>[
  AppRole.superAdmin,
  AppRole.tenantAdmin,
  AppRole.facilityAdmin,
];

/// Appointment/queue front-desk mutations (queue, check-in, reschedule, cancel).
///
/// Matches roles that may start or advance OPD patient-flow work from Reception
/// and OPD, not only the receptionist title.
const AccessRequirement opdFrontDeskActionRequirement = AccessRequirement(
  anyRoles: <AppRole>[
    ..._opdAdminActionRoles,
    AppRole.receptionist,
    AppRole.nurse,
    AppRole.doctor,
    AppRole.operations,
    AppRole.ambulanceOperator,
  ],
  activeModules: <String>['scheduling-queue'],
);

const AccessRequirement opdReceptionActionRequirement = AccessRequirement(
  anyRoles: <AppRole>[
    ..._opdAdminActionRoles,
    AppRole.receptionist,
    AppRole.nurse,
  ],
  activeModules: <String>['scheduling-queue'],
);

const AccessRequirement opdVitalsActionRequirement = AccessRequirement(
  anyRoles: <AppRole>[..._opdAdminActionRoles, AppRole.doctor, AppRole.nurse],
  activeModules: <String>['scheduling-queue'],
);

const AccessRequirement opdDoctorActionRequirement = AccessRequirement(
  anyRoles: <AppRole>[..._opdAdminActionRoles, AppRole.doctor],
  activeModules: <String>['scheduling-queue'],
);

const AccessRequirement opdBillingActionRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[AppPermissions.billingWrite],
  activeModules: <String>['billing-payments'],
);

/// Gate for the OPD→IPD admission handoff action.
///
/// Mirrors the IPD workspace access rules (inpatient bed management module plus
/// inpatient-facing roles) so the handoff button only appears for staff who can
/// actually work the inpatient queue.
const AccessRequirement opdAdmissionHandoffRequirement = AccessRequirement(
  anyRoles: <AppRole>[
    ..._opdAdminActionRoles,
    AppRole.doctor,
    AppRole.nurse,
    AppRole.billing,
    AppRole.operations,
    AppRole.wardManager,
    AppRole.icuManager,
  ],
  activeModules: <String>['inpatient-bed-management'],
);

/// Shared OPD queue/flow stage actions hub for OPD, Reception, and Patients.
Future<bool?> showFlowActionsDialog({
  required BuildContext context,
  required OpdFlowSummary flow,
  bool allowBillingActions = true,
  bool allowVitalsActions = true,
  bool allowClinicalActions = true,
}) {
  return showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => FlowActionsDialog(
      flow: flow,
      allowBillingActions: allowBillingActions,
      allowVitalsActions: allowVitalsActions,
      allowClinicalActions: allowClinicalActions,
    ),
  );
}

class FlowActionsDialog extends ConsumerStatefulWidget {
  const FlowActionsDialog({
    required this.flow,
    this.allowBillingActions = true,
    this.allowVitalsActions = true,
    this.allowClinicalActions = true,
    super.key,
  });

  final OpdFlowSummary flow;
  final bool allowBillingActions;

  /// When false, Record/Edit vitals quick actions are omitted (Reception).
  final bool allowVitalsActions;

  /// When false (Reception), clinician write actions and the clinical-services
  /// panel are omitted while Follow up, Correct stage, and Print summary remain.
  /// The workflow stepper stays read-only guidance.
  final bool allowClinicalActions;

  @override
  ConsumerState<FlowActionsDialog> createState() => _FlowActionsDialogState();
}

class _FlowActionsDialogState extends ConsumerState<FlowActionsDialog> {
  @override
  void initState() {
    super.initState();
    unawaited(
      Future<void>.microtask(
        () => ref
            .read(opdWorkspaceControllerProvider.notifier)
            .selectFlow(widget.flow),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<Result<OpdWorkspaceState>> workspace = ref.watch(
      opdWorkspaceControllerProvider,
    );
    final OpdWorkspaceState? workspaceState = _workspaceState(ref);
    final OpdFlowDetail? selected = workspaceState?.selectedFlow;
    final bool isRefreshingDetail = workspaceState?.isRefreshingDetail ?? false;
    final bool isSaving = workspaceState?.isSaving ?? false;
    final bool isWorkspaceBootstrapping =
        workspace.isLoading && workspaceState == null;
    final bool isBusy =
        isSaving || isRefreshingDetail || isWorkspaceBootstrapping;
    final Object? rawFailure = workspaceState?.lastFailure;
    final AppFailure? failure = rawFailure is AppFailure ? rawFailure : null;
    final OpdFlowDetail? detail =
        selected == null || !_isSameFlow(selected.summary, widget.flow)
        ? null
        : selected;
    final OpdFlowSummary flow = detail?.summary ?? widget.flow;
    final bool isInitialLoad =
        detail == null && (isRefreshingDetail || isWorkspaceBootstrapping);

    return AppDialog(
      title: Text(l10n.opdFlowActionsTitle),
      icon: const Icon(Icons.medical_services_outlined),
      maxWidth: 860,
      scrollable: true,
      pinActionsToBottom: true,
      closeEnabled: !isBusy,
      content: AppFormSection(
        density: AppFormSectionDensity.compact,
        children: <Widget>[
          if (failure != null)
            AppFormInformationBanner.failure(
              context: context,
              failure: failure,
            ),
          OpdActionContextPanel(flow: flow, detail: detail),
          if (isBusy)
            AppLoadingIndicator.compact(
              title: l10n.opdLoadingTitle,
              body: l10n.opdLoadingBody,
              semanticLabel: l10n.opdLoadingTitle,
            ),
          if (widget.allowClinicalActions &&
              detail != null &&
              opdDetailHasClinicalRecords(detail))
            OpdEncounterClinicalServicesPanel(
              detail: detail,
              flow: flow,
            ),
          if (!isInitialLoad)
            _actionGrid(context, flow, detail, actionsEnabled: !isBusy),
        ],
      ),
      actions: <Widget>[
        AppButton.secondary(
          label: l10n.commonCancelActionLabel,
          leadingIcon: AppActionIcons.cancel,
          enabled: !isBusy,
          onPressed: isBusy ? null : () => Navigator.of(context).pop(false),
        ),
      ],
    );
  }

  Widget _actionGrid(
    BuildContext context,
    OpdFlowSummary flow,
    OpdFlowDetail? detail, {
    required bool actionsEnabled,
  }) {
    final AppLocalizations l10n = context.l10n;
    final String stage = _normalizedStage(flow.stage);
    final bool terminal = flow.isTerminal;
    final bool consultationPaid =
        detail?.consultationPaid ?? flow.consultationPaid;
    final bool consultationPaymentRequired =
        detail?.consultationPaymentRequired ??
        flow.consultationPaymentRequired ||
            stage == 'WAITING_CONSULTATION_PAYMENT';
    final bool canPayNow =
        !consultationPaid &&
        (stage == 'WAITING_CONSULTATION_PAYMENT' ||
            consultationPaymentRequired);
    final bool hasVitals =
        (detail?.vitalMeasurements.isNotEmpty ?? false) ||
        (detail?.vitalSigns.isNotEmpty ?? false);
    final List<AppPermissionActionItem> actions = <AppPermissionActionItem>[];
    final Set<String> actionKeys = <String>{};

    void addAction(String key, AppPermissionActionItem action) {
      if (actionKeys.add(key)) {
        actions.add(action);
      }
    }

    AppPermissionActionItem primaryAction(AppPermissionActionItem action) {
      return AppPermissionActionItem(
        requirement: action.requirement,
        label: l10n.opdFlowNextActionButtonLabel(action.label),
        icon: action.icon,
        onPressed: actionsEnabled ? action.onPressed : null,
        variant: AppButtonVariant.primary,
        enabled: actionsEnabled && action.enabled,
        isLoading: action.isLoading,
        fullWidth: action.fullWidth,
        hideWhenDenied: action.hideWhenDenied,
        tooltip: action.tooltip ?? action.label,
        semanticLabel: action.semanticLabel ?? action.label,
      );
    }

    AppPermissionActionItem billingAction() => AppPermissionActionItem(
      requirement: opdBillingActionRequirement,
      label: canPayNow
          ? l10n.opdPayConsultationAction
          : consultationPaid
          ? l10n.opdUpdateConsultationBillingAction
          : l10n.opdManageConsultationBillingAction,
      icon: AppActionIcons.payment,
      fullWidth: true,
      hideWhenDenied: true,
      enabled: actionsEnabled && !terminal,
      onPressed: terminal
          ? null
          : () => _openNestedOpener(
              context,
              () => showConsultationPaymentDialog(context: context, flow: flow),
            ),
    );

    AppPermissionActionItem vitalsAction() => AppPermissionActionItem(
      requirement: opdVitalsActionRequirement,
      label: hasVitals ? l10n.opdEditVitalsAction : l10n.opdRecordVitalsAction,
      icon: Icons.monitor_heart_outlined,
      fullWidth: true,
      hideWhenDenied: true,
      enabled: actionsEnabled && !terminal,
      onPressed: terminal
          ? null
          : () => _openNested(
              context,
              RecordVitalsDialog(
                flow: flow,
                detail: detail,
                editing: hasVitals,
              ),
            ),
    );

    AppPermissionActionItem routeDecisionAction() => AppPermissionActionItem(
      requirement: opdVitalsActionRequirement,
      label: l10n.opdRouteDecisionLabel,
      icon: AppActionIcons.route,
      fullWidth: true,
      hideWhenDenied: true,
      enabled: actionsEnabled && !terminal,
      onPressed: terminal
          ? null
          : () => _openNestedOpener(
              context,
              () => showRoutingDecisionDialog(context: context, flow: flow),
            ),
    );

    AppPermissionActionItem assignDoctorAction() => AppPermissionActionItem(
      requirement: opdReceptionActionRequirement,
      label: _isNonEmpty(flow.providerUserId)
          ? l10n.opdChangeDoctorAction
          : l10n.opdAssignDoctorAction,
      icon: AppActionIcons.assignDoctor,
      fullWidth: true,
      hideWhenDenied: true,
      enabled: actionsEnabled && !terminal,
      onPressed: terminal
          ? null
          : () => _openNestedOpener(
              context,
              () => showAssignDoctorDialog(context: context, flow: flow),
            ),
    );

    AppPermissionActionItem doctorReviewAction() => AppPermissionActionItem(
      requirement: opdDoctorActionRequirement,
      label: l10n.opdDoctorReviewAction,
      icon: Icons.edit_note_outlined,
      fullWidth: true,
      hideWhenDenied: true,
      enabled: actionsEnabled && !terminal,
      onPressed: terminal
          ? null
          : () => _openNested(context, _doctorReviewDialog(context, flow)),
    );

    AppPermissionActionItem dispositionAction() {
      final String label = clinicalDispositionActionLabel(
        l10n,
        sourceQueue: 'OPD',
        status: flow.status,
        stage: flow.stage,
        isOpdContext: true,
      );
      final String normalizedDisplayCode = (flow.displayCode ?? '')
          .trim()
          .toUpperCase();
      final bool canDispose =
          stage == 'WAITING_DISPOSITION' ||
          <String>{
            'DECISION_NEEDED',
            'RESULTS_READY',
            'REPORT_READY',
            'MEDICINES_DISPENSED',
          }.contains(normalizedDisplayCode);
      return AppPermissionActionItem(
        requirement: opdDoctorActionRequirement,
        label: label,
        icon: AppActionIcons.complete,
        fullWidth: true,
        hideWhenDenied: true,
        enabled: actionsEnabled && !terminal && canDispose,
        tooltip: canDispose ? null : opdStageDisplayLabel(l10n, stage),
        onPressed: terminal || !canDispose || !actionsEnabled
            ? null
            : () => _openDisposition(
                context,
                flow,
                detail,
                hasPharmacyOrder:
                    detail?.pharmacyOrders.isNotEmpty ??
                    stage == 'PHARMACY_REQUESTED',
              ),
      );
    }

    AppPermissionActionItem admissionHandoffAction() => AppPermissionActionItem(
      requirement: opdAdmissionHandoffRequirement,
      label: l10n.opdOpenAdmissionAction,
      icon: AppActionIcons.bed,
      fullWidth: true,
      hideWhenDenied: true,
      enabled: actionsEnabled,
      onPressed: actionsEnabled
          ? () => _navigateToIpdHandoff(context, flow, detail)
          : null,
    );

    AppPermissionActionItem departmentHandoffAction() {
      final String label = opdNextStepDisplayLabel(
        l10n,
        flow.displayNextStep ?? flow.nextStep,
      );
      return AppPermissionActionItem(
        requirement: opdReceptionActionRequirement,
        label: label.isNotEmpty ? label : l10n.opdNextDiagnosticsPendingLabel,
        icon: _departmentHandoffIcon(stage),
        fullWidth: true,
        hideWhenDenied: true,
        enabled: actionsEnabled && !terminal,
        onPressed: actionsEnabled && !terminal
            ? () => _navigateToDepartmentHandoff(context, flow)
            : null,
      );
    }

    final bool hasAssignedProvider =
        _isNonEmpty(flow.providerUserId) ||
        _isNonEmpty(flow.providerDisplayName) ||
        _isNonEmpty(flow.assignedStaffDisplayName);
    final bool hasPendingAdmission = _flowHasPendingAdmission(flow, detail);
    final String displayCode = (flow.displayCode ?? '').trim().toUpperCase();
    final bool clinicalStage = _isClinicalReviewStage(stage);
    final bool servicePendingStage = _isServicePendingStage(stage);
    final bool canDispose =
        stage == 'WAITING_DISPOSITION' ||
        <String>{
          'DECISION_NEEDED',
          'RESULTS_READY',
          'REPORT_READY',
          'MEDICINES_DISPENSED',
        }.contains(displayCode);
    final bool canAdjustBilling =
        consultationPaid || consultationPaymentRequired;
    final String nextActionKey = switch (displayCode) {
      'PAYMENT_DUE' => canPayNow ? 'billing' : 'correct_stage',
      'VITALS_NEEDED' => 'vitals',
      'DOCTOR_NEEDED' => 'assign_doctor',
      'WITH_DOCTOR' => 'doctor_review',
      'LAB_PENDING' ||
      'SAMPLE_PENDING' ||
      'IN_LAB' ||
      'IMAGING_PENDING' ||
      'REPORT_PENDING' ||
      'PHARMACY_PENDING' => 'handoff',
      'RESULTS_READY' ||
      'REPORT_READY' ||
      'MEDICINES_DISPENSED' ||
      'DECISION_NEEDED' => 'disposition',
      'ADMISSION_PENDING' => 'admission_handoff',
      _ => switch (stage) {
        'WAITING_CONSULTATION_PAYMENT' =>
          canPayNow ? 'billing' : 'correct_stage',
        'WAITING_VITALS' => 'vitals',
        'WAITING_DOCTOR_ASSIGNMENT' =>
          hasAssignedProvider ? 'doctor_review' : 'assign_doctor',
        'WAITING_DOCTOR_REVIEW' => 'doctor_review',
        'WAITING_DISPOSITION' =>
          hasPendingAdmission ? 'admission_handoff' : 'disposition',
        'LAB_REQUESTED' ||
        'RADIOLOGY_REQUESTED' ||
        'LAB_AND_RADIOLOGY_REQUESTED' ||
        'PHARMACY_REQUESTED' => 'handoff',
        _ => 'correct_stage',
      },
    };

    final Map<String, AppPermissionActionItem Function()> actionFactories =
        <String, AppPermissionActionItem Function()>{
          'billing': billingAction,
          'vitals': vitalsAction,
          'route_decision': routeDecisionAction,
          'assign_doctor': assignDoctorAction,
          'doctor_review': doctorReviewAction,
          'handoff': departmentHandoffAction,
          'diagnosis': () => AppPermissionActionItem(
            requirement: opdDoctorActionRequirement,
            label: l10n.clinicalAddDiagnosisAction,
            icon: AppActionIcons.triage,
            fullWidth: true,
            hideWhenDenied: true,
            enabled: actionsEnabled,
            onPressed: actionsEnabled
                ? () => _openDiagnosisDialog(context, flow)
                : null,
          ),
          'lab': () => AppPermissionActionItem(
            requirement: opdDoctorActionRequirement,
            label: l10n.clinicalRequestLabAction,
            icon: Icons.science_outlined,
            fullWidth: true,
            hideWhenDenied: true,
            enabled: actionsEnabled,
            onPressed: actionsEnabled
                ? () => _openLabOrderDialog(context, flow)
                : null,
          ),
          'radiology': () => AppPermissionActionItem(
            requirement: opdDoctorActionRequirement,
            label: l10n.clinicalRequestRadiologyAction,
            icon: Icons.biotech_outlined,
            fullWidth: true,
            hideWhenDenied: true,
            enabled: actionsEnabled,
            onPressed: actionsEnabled
                ? () => _openRadiologyOrderDialog(context, flow)
                : null,
          ),
          'prescription': () => AppPermissionActionItem(
            requirement: opdDoctorActionRequirement,
            label: l10n.clinicalPrescribeAction,
            icon: Icons.medication_outlined,
            fullWidth: true,
            hideWhenDenied: true,
            enabled: actionsEnabled,
            onPressed: actionsEnabled
                ? () => _openPrescriptionDialog(context, flow)
                : null,
          ),
          'procedure': () => AppPermissionActionItem(
            requirement: opdDoctorActionRequirement,
            label: l10n.clinicalRequestProcedureAction,
            icon: Icons.healing_outlined,
            fullWidth: true,
            hideWhenDenied: true,
            enabled: actionsEnabled,
            onPressed: actionsEnabled
                ? () => _openProcedureDialog(context, flow)
                : null,
          ),
          'referral': () => AppPermissionActionItem(
            requirement: opdDoctorActionRequirement,
            label: l10n.opdReferAction,
            icon: AppActionIcons.referral,
            fullWidth: true,
            hideWhenDenied: true,
            enabled: actionsEnabled,
            onPressed: actionsEnabled
                ? () => _openNestedOpener(
                    context,
                    () => showReferralDialog(context: context, flow: flow),
                  )
                : null,
          ),
          'follow_up': () => AppPermissionActionItem(
            // Front-desk and clinical roles may schedule follow-ups; Reception
            // keeps this when clinician write actions are otherwise hidden.
            requirement: opdFrontDeskActionRequirement,
            label: l10n.opdFollowUpAction,
            icon: AppActionIcons.followUp,
            fullWidth: true,
            hideWhenDenied: true,
            enabled: actionsEnabled,
            onPressed: actionsEnabled
                ? () => _openNestedOpener(
                    context,
                    () => showFollowUpDialog(context: context, flow: flow),
                  )
                : null,
          ),
          'disposition': dispositionAction,
          'admission_handoff': admissionHandoffAction,
          'correct_stage': () => _correctStageAction(
            context,
            flow,
            actionsEnabled: actionsEnabled,
          ),
          'print': () => AppPermissionActionItem(
            requirement: opdFrontDeskActionRequirement,
            label: l10n.opdPrintSummaryAction,
            icon: AppActionIcons.print,
            fullWidth: true,
            hideWhenDenied: true,
            enabled: actionsEnabled,
            onPressed: actionsEnabled
                ? () => _openNestedOpener(
                    context,
                    () => showPrintOpdSummaryDialog(
                      context: context,
                      flow: flow,
                      detail: detail,
                    ),
                  )
                : null,
          ),
        };

    bool shouldIncludeAction(String key) {
      return switch (key) {
        'billing' =>
          widget.allowBillingActions &&
              !terminal &&
              (canPayNow || canAdjustBilling || nextActionKey == 'billing'),
        'vitals' =>
          widget.allowVitalsActions &&
              !terminal &&
              (nextActionKey == 'vitals' ||
                  <String>{'WAITING_VITALS', 'VITALS_NEEDED'}.contains(stage) ||
                  displayCode == 'VITALS_NEEDED' ||
                  hasVitals),
        'route_decision' => !terminal && hasVitals,
        // Keep Assign/Change doctor available for the whole active encounter so
        // front-desk users still have actions after a provider is assigned.
        'assign_doctor' => !terminal,
        'doctor_review' =>
          widget.allowClinicalActions &&
              !terminal &&
              (nextActionKey == 'doctor_review' ||
                  <String>{
                    'WAITING_DOCTOR_REVIEW',
                    'WITH_DOCTOR',
                    'WAITING_DISPOSITION',
                  }.contains(stage) ||
                  displayCode == 'WITH_DOCTOR' ||
                  clinicalStage),
        // Department handoff navigates into lab/imaging/pharmacy work — omit
        // for Reception; progress remains visible via status labels.
        'handoff' =>
          widget.allowClinicalActions && !terminal && servicePendingStage,
        'diagnosis' ||
        'lab' ||
        'radiology' ||
        'prescription' ||
        'procedure' ||
        'referral' =>
          widget.allowClinicalActions && !terminal && clinicalStage,
        // Follow up stays available on Reception (and clinical) surfaces.
        'follow_up' => !terminal && clinicalStage,
        'disposition' =>
          widget.allowClinicalActions &&
              !terminal &&
              (canDispose || nextActionKey == 'disposition'),
        'admission_handoff' =>
          widget.allowClinicalActions && hasPendingAdmission,
        'correct_stage' => true,
        'print' => true,
        _ => false,
      };
    }

    const List<String> chronologicalOrder = <String>[
      'billing',
      'vitals',
      'assign_doctor',
      'doctor_review',
      'handoff',
      'diagnosis',
      'lab',
      'radiology',
      'prescription',
      'procedure',
      'referral',
      'follow_up',
      'disposition',
      'admission_handoff',
      'correct_stage',
      'print',
    ];

    for (final String key in chronologicalOrder) {
      if (!shouldIncludeAction(key)) {
        continue;
      }
      final AppPermissionActionItem Function()? factory = actionFactories[key];
      if (factory == null) {
        continue;
      }
      final AppPermissionActionItem action = factory();
      addAction(key, key == nextActionKey ? primaryAction(action) : action);
    }

    return AppQuickActions(
      title: l10n.patientsQuickActionsTitle,
      permissionActions: actions,
    );
  }

  AppPermissionActionItem _correctStageAction(
    BuildContext context,
    OpdFlowSummary flow, {
    required bool actionsEnabled,
  }) {
    return AppPermissionActionItem(
      // Reception and nursing may correct stage; clinician writes stay separate.
      requirement: opdReceptionActionRequirement,
      label: context.l10n.opdCorrectStageAction,
      icon: AppActionIcons.move,
      fullWidth: true,
      hideWhenDenied: true,
      enabled: actionsEnabled,
      onPressed: actionsEnabled
          ? () => _openNestedOpener(
              context,
              () => showCorrectStageDialog(context: context, flow: flow),
            )
          : null,
    );
  }

  Future<void> _openNested(
    BuildContext context,
    Widget dialog, {
    bool closeParentOnChange = false,
  }) {
    return _openNestedOpener(
      context,
      () => showAppDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => dialog,
      ),
      closeParentOnChange: closeParentOnChange,
    );
  }

  Future<void> _openNestedOpener(
    BuildContext context,
    Future<bool?> Function() open, {
    bool closeParentOnChange = false,
  }) async {
    final bool? changed = await open();
    if (!context.mounted || changed != true) {
      return;
    }

    final OpdWorkspaceState? workspaceState = _workspaceState(ref);
    final OpdFlowSummary? updatedFlow = workspaceState?.selectedFlow?.summary;
    final bool isTerminal = updatedFlow == null || updatedFlow.isTerminal;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.opdSavedMessage)));

    if (closeParentOnChange || isTerminal) {
      Navigator.of(context).pop(true);
    }
  }

  /// Runs the disposition dialog and, when the doctor admits the patient,
  /// offers an immediate handoff to the inpatient (IPD) workspace while keeping
  /// the source OPD encounter linked (opd-flow §7, ipd-flow §2.2).
  Future<void> _openDisposition(
    BuildContext context,
    OpdFlowSummary flow,
    OpdFlowDetail? detail, {
    required bool hasPharmacyOrder,
  }) async {
    String? submittedDisposition;
    final bool? changed = await showOpdDispositionDialog(
      context: context,
      flow: flow,
      hasPharmacyOrder: hasPharmacyOrder,
      onDispositionSubmitted: (String decision) {
        submittedDisposition = decision;
      },
    );
    if (!context.mounted || changed != true) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.opdSavedMessage)));

    final OpdFlowDetail? updatedDetail = _workspaceState(ref)?.selectedFlow;
    final OpdFlowSummary updatedFlow = updatedDetail?.summary ?? flow;
    final bool admissionPending = _flowHasPendingAdmission(
      updatedFlow,
      updatedDetail,
    );

    if (admissionPending) {
      await _promptIpdHandoff(context, updatedFlow, updatedDetail);
      return;
    }

    final String? dispositionDecision = submittedDisposition;
    if (dispositionDecision?.toUpperCase() == 'REFER_PHYSIOTHERAPY') {
      await _promptPhysiotherapyHandoff(context, updatedFlow);
      return;
    }

    if (updatedFlow.isTerminal) {
      await _promptFollowUpAfterDisposition(context, updatedFlow);
      if (context.mounted) {
        Navigator.of(context).pop(true);
      }
    }
  }

  Future<void> _promptFollowUpAfterDisposition(
    BuildContext context,
    OpdFlowSummary flow,
  ) async {
    final bool canSchedule = opdFrontDeskActionRequirement.isAllowed(
      ref.read(appAccessPolicyProvider),
    );
    if (!canSchedule || !context.mounted) {
      return;
    }
    await showFollowUpDialog(
      context: context,
      flow: flow,
      offerSkip: true,
    );
  }

  Future<void> _promptIpdHandoff(
    BuildContext context,
    OpdFlowSummary flow,
    OpdFlowDetail? detail,
  ) async {
    final bool? openIpd = await showOpdAdmissionHandoffDialog(
      context: context,
      flow: flow,
    );
    if (!context.mounted) {
      return;
    }
    if (openIpd == true) {
      _navigateToIpdHandoff(context, flow, detail);
    }
  }

  Future<void> _promptPhysiotherapyHandoff(
    BuildContext context,
    OpdFlowSummary flow,
  ) async {
    final AppLocalizations l10n = context.l10n;
    final bool? openPhysio = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => AppDialog(
        title: Text(l10n.opdPhysiotherapyHandoffTitle),
        icon: const Icon(Icons.accessibility_new_outlined),
        maxWidth: 560,
        content: Text(
          l10n.opdPhysiotherapyHandoffBody,
          style: Theme.of(dialogContext).textTheme.bodyMedium,
        ),
        actions: <Widget>[
          AppButton.secondary(
            label: l10n.commonCancelActionLabel,
            leadingIcon: AppActionIcons.cancel,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          AppButton.primary(
            label: l10n.opdOpenPhysiotherapyAction,
            leadingIcon: Icons.accessibility_new_outlined,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    if (!context.mounted || openPhysio != true) {
      return;
    }
    Navigator.of(context).pop(true);
    final String encounterTarget = flow.publicId?.trim().isNotEmpty == true
        ? flow.publicId!
        : flow.id;
    context.go(
      AppRoutes.physiotherapy.location(
        queryParameters: <String, String>{'encounterId': encounterTarget},
      ),
    );
  }

  void _navigateToIpdHandoff(
    BuildContext context,
    OpdFlowSummary flow,
    OpdFlowDetail? detail,
  ) {
    final String target = _admissionHandoffTarget(flow, detail);
    // Close the OPD action dialog before routing to the inpatient workspace.
    Navigator.of(context).pop(true);
    context.go(
      AppRoutes.ipd.location(
        queryParameters: target.isEmpty
            ? const <String, String>{}
            : <String, String>{'admission': target},
      ),
    );
  }

  Widget _doctorReviewDialog(BuildContext context, OpdFlowSummary flow) {
    final AppLocalizations l10n = context.l10n;
    final OpdWorkspaceState? workspaceState = _workspaceState(ref);
    final OpdFlowDetail? selected = workspaceState?.selectedFlow;
    final OpdFlowDetail? detail =
        selected == null || !_isSameFlow(selected.summary, flow)
        ? null
        : selected;
    final OpdFlowSummary currentFlow = detail?.summary ?? flow;

    return ClinicalFreeTextActionDialog(
      title: l10n.opdDoctorReviewAction,
      label: _opdRequiredFieldLabel(l10n, l10n.opdClinicalNoteLabel),
      submitLabel: l10n.opdDoctorReviewAction,
      minLines: 3,
      maxLines: 4,
      leadingContent: <Widget>[
        OpdActionContextPanel(flow: currentFlow, showTitle: false),
        _OpdWorkflowStatusSummary(flow: currentFlow, detail: detail),
      ],
      onSubmit: (String note) {
        return ref.read(opdWorkspaceControllerProvider.notifier).doctorReview(
          flow,
          <String, Object?>{'note': note},
        );
      },
    );
  }

  Future<ClinicalActionReferenceData?> _loadClinicalReferenceData(
    BuildContext context,
  ) async {
    final Result<ClinicalActionReferenceData> result = await ref
        .read(opdEncounterDialogControllerProvider)
        .loadClinicalReferenceData();
    if (!mounted) {
      return null;
    }
    return result.when(
      success: (ClinicalActionReferenceData value) => value,
      failure: (AppFailure failure) {
        _showFailureIfNeeded(context, failure);
        return null;
      },
    );
  }

  Future<void> _openDiagnosisDialog(
    BuildContext context,
    OpdFlowSummary flow,
  ) async {
    final OpdEncounterDialogController dialogController = ref.read(
      opdEncounterDialogControllerProvider,
    );
    await _openNested(
      context,
      ClinicalDiagnosisActionDialog(
        onSearchClinicalTerms:
            ({
              int? limit,
              String? query,
              required String termType,
              String source = 'ALL',
            }) {
              return dialogController.searchClinicalTerms(
                termType: termType,
                query: query,
                limit: limit ?? 20,
                source: source,
              );
            },
        onSubmit:
            ({
              required String diagnosisType,
              required List<ClinicalActionCatalogOption> diagnoses,
            }) {
              final List<Map<String, Object?>> payload =
                  <Map<String, Object?>>[
                        for (final ClinicalActionCatalogOption diagnosis
                            in diagnoses)
                          <String, Object?>{
                            'diagnosis_type': diagnosisType,
                            'code': _trimmedOrNull(diagnosis.code),
                            'description':
                                _trimmedOrNull(diagnosis.name) ??
                                diagnosis.displayTitle,
                          },
                      ]
                      .where((Map<String, Object?> item) {
                        return _isNonEmpty(item['description']?.toString());
                      })
                      .toList(growable: false);
              return ref
                  .read(opdWorkspaceControllerProvider.notifier)
                  .doctorReview(flow, <String, Object?>{
                    'note': payload
                        .map(
                          (Map<String, Object?> item) =>
                              item['description']?.toString() ?? '',
                        )
                        .where(_isNonEmpty)
                        .join(', '),
                    'diagnoses': payload,
                  });
            },
      ),
    );
  }

  Future<void> _openProcedureDialog(
    BuildContext context,
    OpdFlowSummary flow,
  ) async {
    final OpdEncounterDialogController dialogController = ref.read(
      opdEncounterDialogControllerProvider,
    );
    await _openNested(
      context,
      ClinicalProcedureActionDialog(
        onSearchClinicalTerms:
            ({
              int? limit,
              String? query,
              required String termType,
              String source = 'ALL',
            }) {
              return dialogController.searchClinicalTerms(
                termType: termType,
                query: query,
                limit: limit ?? 20,
                source: source,
              );
            },
        onSubmit:
            ({
              required List<ClinicalActionCatalogOption> procedures,
              DateTime? performedAt,
            }) {
              final String performedAtIso = (performedAt ?? DateTime.now())
                  .toUtc()
                  .toIso8601String();
              return ref
                  .read(opdWorkspaceControllerProvider.notifier)
                  .doctorReview(flow, <String, Object?>{
                    'note': context.l10n.clinicalRequestProcedureAction,
                    'procedures': <Map<String, Object?>>[
                      for (final ClinicalActionCatalogOption procedure
                          in procedures)
                        <String, Object?>{
                          'code': procedure.code,
                          'description':
                              procedure.name ?? procedure.displayTitle,
                          'performed_at': performedAtIso,
                        },
                    ],
                  });
            },
      ),
    );
  }

  Future<void> _openLabOrderDialog(
    BuildContext context,
    OpdFlowSummary flow,
  ) async {
    final String actionLabel = context.l10n.clinicalRequestLabAction;
    final OpdEncounterDialogController dialogController = ref.read(
      opdEncounterDialogControllerProvider,
    );
    final ClinicalActionReferenceData? referenceData =
        await _loadClinicalReferenceData(context);
    if (!mounted || !context.mounted || referenceData == null) {
      return;
    }
    final ClinicalRequestPayerContext? payerContext = await dialogController
        .resolvePayerContextForPatient(flow.patientDisplayId ?? flow.patientId);
    if (!mounted || !context.mounted) {
      return;
    }
    await _openNested(
      context,
      ClinicalLabOrderActionDialog(
        referenceData: referenceData,
        payerContext: payerContext,
        patientContext: ClinicalRequestPatientContext(
          patientName: flow.patientDisplayName ?? flow.displayTitle,
          patientId: flow.patientDisplayId,
          encounterId: flow.publicId,
        ),
        onSearchLabTests:
            ({
              required String termType,
              String? query,
              int? limit,
              String source = 'ALL',
            }) {
              return dialogController.searchClinicalTerms(
                termType: termType,
                query: query,
                limit: limit ?? 80,
                source: source,
                facilityId: flow.facilityId,
              );
            },
        onRequest:
            ({
              required List<String> labTestIds,
              required List<String> labPanelIds,
              ClinicalRequestBillingSubmit? billing,
            }) {
              return ref
                  .read(opdWorkspaceControllerProvider.notifier)
                  .doctorReview(flow, <String, Object?>{
                    'note': actionLabel,
                    'lab_requests': <Map<String, Object?>>[
                      for (final String id in labTestIds)
                        <String, Object?>{
                          'lab_test_id': id,
                          'status': 'ORDERED',
                        },
                      for (final String id in labPanelIds)
                        <String, Object?>{
                          'lab_panel_id': id,
                          'status': 'ORDERED',
                        },
                    ],
                  });
            },
        onUpdate:
            ({
              required String labOrderId,
              required List<String> labTestIds,
              required List<String> labPanelIds,
              ClinicalRequestBillingSubmit? billing,
            }) {
              return ref
                  .read(opdWorkspaceControllerProvider.notifier)
                  .updateLabOrder(
                    flow: flow,
                    labOrderId: labOrderId,
                    labTestIds: labTestIds,
                    labPanelIds: labPanelIds,
                  );
            },
      ),
    );
  }

  Future<void> _openRadiologyOrderDialog(
    BuildContext context,
    OpdFlowSummary flow,
  ) async {
    final String actionLabel = context.l10n.clinicalRequestRadiologyAction;
    final OpdEncounterDialogController dialogController = ref.read(
      opdEncounterDialogControllerProvider,
    );
    final ClinicalActionReferenceData? referenceData =
        await _loadClinicalReferenceData(context);
    if (!mounted || !context.mounted || referenceData == null) {
      return;
    }
    final ClinicalRequestPayerContext? payerContext = await dialogController
        .resolvePayerContextForPatient(flow.patientDisplayId ?? flow.patientId);
    if (!mounted || !context.mounted) {
      return;
    }
    await _openNested(
      context,
      ClinicalRadiologyOrderActionDialog(
        referenceData: referenceData,
        payerContext: payerContext,
        patientContext: ClinicalRequestPatientContext(
          patientName: flow.patientDisplayName ?? flow.displayTitle,
          patientId: flow.patientDisplayId,
          encounterId: flow.publicId,
        ),
        onSearchRadiologyTests:
            ({
              required String termType,
              String? query,
              int? limit,
              String source = 'ALL',
            }) {
              return dialogController.searchClinicalTerms(
                termType: termType,
                query: query,
                limit: limit ?? 80,
                source: source,
                facilityId: flow.facilityId,
              );
            },
        onSubmit:
            ({
              required List<ClinicalActionRadiologyRequest> requests,
              ClinicalRequestBillingSubmit? billing,
            }) {
              return ref
                  .read(opdWorkspaceControllerProvider.notifier)
                  .doctorReview(flow, <String, Object?>{
                    'note': actionLabel,
                    'radiology_requests': <Map<String, Object?>>[
                      for (final ClinicalActionRadiologyRequest request
                          in requests)
                        <String, Object?>{
                          'radiology_test_id': request.radiologyTestId,
                          'clinical_note': request.clinicalNote,
                          'status': 'ORDERED',
                          'request_details': <String, Object?>{
                            'modality': request.modality,
                            'body_region': request.bodyRegion,
                            'laterality': request.laterality,
                            'priority': request.priority,
                          },
                        },
                    ],
                  });
            },
      ),
    );
  }

  Future<void> _openPrescriptionDialog(
    BuildContext context,
    OpdFlowSummary flow,
  ) async {
    final String actionLabel = context.l10n.clinicalPrescribeAction;
    final OpdEncounterDialogController dialogController = ref.read(
      opdEncounterDialogControllerProvider,
    );
    final ClinicalActionReferenceData? referenceData =
        await _loadClinicalReferenceData(context);
    if (!mounted || !context.mounted || referenceData == null) {
      return;
    }
    final ClinicalRequestPayerContext? payerContext = await dialogController
        .resolvePayerContextForPatient(flow.patientDisplayId ?? flow.patientId);
    if (!mounted || !context.mounted) {
      return;
    }
    await _openNested(
      context,
      ClinicalPrescriptionActionDialog(
        referenceData: referenceData,
        payerContext: payerContext,
        onSubmit:
            ({
              required List<Map<String, Object?>> items,
              ClinicalRequestBillingSubmit? billing,
            }) {
              return ref
                  .read(opdWorkspaceControllerProvider.notifier)
                  .doctorReview(flow, <String, Object?>{
                    'note': actionLabel,
                    'medications': <Map<String, Object?>>[
                      for (final Map<String, Object?> item in items)
                        <String, Object?>{...item, 'status': 'ACTIVE'},
                    ],
                  });
            },
      ),
    );
  }
}

/// Opens [CorrectStageDialog] with mutating-dialog dismiss rules.
Future<bool?> showCorrectStageDialog({
  required BuildContext context,
  required OpdFlowSummary flow,
}) {
  return showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => CorrectStageDialog(flow: flow),
  );
}

class CorrectStageDialog extends ConsumerStatefulWidget {
  const CorrectStageDialog({required this.flow, super.key});

  final OpdFlowSummary flow;

  @override
  ConsumerState<CorrectStageDialog> createState() => _CorrectStageDialogState();
}

class _CorrectStageDialogState extends ConsumerState<CorrectStageDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _reasonController;
  String _stage = _flowStages.first;
  bool _isSaving = false;
  AppFailure? _failure;

  OpdFlowSummary get _currentFlow {
    final OpdWorkspaceState? workspaceState = _workspaceState(ref);
    final OpdFlowDetail? selected = workspaceState?.selectedFlow;
    if (selected != null && _isSameFlow(selected.summary, widget.flow)) {
      return selected.summary;
    }
    return widget.flow;
  }

  OpdFlowDetail? get _currentDetail {
    final OpdWorkspaceState? workspaceState = _workspaceState(ref);
    final OpdFlowDetail? selected = workspaceState?.selectedFlow;
    if (selected != null && _isSameFlow(selected.summary, widget.flow)) {
      return selected;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _reasonController = TextEditingController();
    _stage = _firstSelectableStage(widget.flow.stage);
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final OpdFlowSummary flow = _currentFlow;
    final OpdFlowDetail? detail = _currentDetail;
    final String currentStage = _normalizedStage(flow.stage);
    final bool reasonRequired = _stageCorrectionRequiresReason(
      currentStage,
      _stage,
    );
    return AppDialog(
      title: Text(l10n.opdCorrectStageAction),
      icon: const Icon(AppActionIcons.move),
      scrollable: true,
      closeEnabled: !_isSaving,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null)
              AppFormInformationBanner.failure(
                context: context,
                failure: _failure!,
              ),
            OpdActionContextPanel(flow: flow, detail: detail, showTitle: false),
            AppInfoTileGrid(
              minItemWidth: 150,
              borderedTiles: false,
              emptyValue: l10n.profileUnknownValue,
              items: <AppInfoTileData>[
                AppInfoTileData(
                  label: l10n.opdCurrentStageLabel,
                  value: opdStageDisplayLabel(l10n, currentStage),
                ),
                AppInfoTileData(
                  label: l10n.opdTargetStageLabel,
                  value: opdStageDisplayLabel(l10n, _stage),
                ),
              ],
            ),
            AppSelectField<String>(
              value: _stage,
              labelText: _opdRequiredFieldLabel(l10n, l10n.opdTargetStageLabel),
              enabled: !_isSaving,
              onChanged: (String? value) =>
                  setState(() => _stage = value ?? _stage),
              options: _flowStageOptions(context.l10n, exclude: currentStage),
            ),
            AppTextField(
              controller: _reasonController,
              labelText: reasonRequired
                  ? _opdRequiredFieldLabel(l10n, l10n.opdReasonLabel)
                  : _opdOptionalFieldLabel(l10n, l10n.opdReasonLabel),
              enabled: !_isSaving,
              maxLines: 3,
              validator: (String? value) {
                if (!reasonRequired) {
                  return null;
                }
                return (value ?? '').trim().isEmpty
                    ? l10n.opdStageCorrectionReasonRequiredMessage
                    : null;
              },
            ),
          ],
        ),
      ),
      actions: clinicalActionDialogActions(
        context,
        l10n.opdCorrectStageAction,
        _isSaving,
        _isSaving ? null : _submit,
        submitLeadingIcon: AppActionIcons.move,
      ),
    );
  }

  Future<void> _submit() async {
    if (_isSaving) {
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final OpdFlowSummary flow = _currentFlow;
    if (_normalizedStage(flow.stage) == _stage) {
      setState(() => _failure = AppFailure.validation());
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(opdWorkspaceControllerProvider.notifier)
        .correctStage(flow, _stage, _reasonController.text.trim());
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _failure = failure;
      _isSaving = false;
    });
  }
}

/// Opens [AssignDoctorDialog] with mutating-dialog dismiss rules.
Future<bool?> showAssignDoctorDialog({
  required BuildContext context,
  required OpdFlowSummary flow,
}) {
  return showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AssignDoctorDialog(flow: flow),
  );
}

class AssignDoctorDialog extends ConsumerStatefulWidget {
  const AssignDoctorDialog({required this.flow, super.key});

  final OpdFlowSummary flow;

  @override
  ConsumerState<AssignDoctorDialog> createState() => _AssignDoctorDialogState();
}

class _AssignDoctorDialogState extends ConsumerState<AssignDoctorDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  List<OpdProviderOption> _providerOptions = const <OpdProviderOption>[];
  List<OpdProviderSchedule> _providerSchedules = const <OpdProviderSchedule>[];
  String? _providerId;
  bool _isLoadingProviders = false;
  bool _isSaving = false;
  AppFailure? _failure;

  OpdFlowSummary get _currentFlow {
    final OpdWorkspaceState? workspaceState = _workspaceState(ref);
    final OpdFlowDetail? selected = workspaceState?.selectedFlow;
    if (selected != null && _isSameFlow(selected.summary, widget.flow)) {
      return selected.summary;
    }
    return widget.flow;
  }

  OpdFlowDetail? get _currentDetail {
    final OpdWorkspaceState? workspaceState = _workspaceState(ref);
    final OpdFlowDetail? selected = workspaceState?.selectedFlow;
    if (selected != null && _isSameFlow(selected.summary, widget.flow)) {
      return selected;
    }
    return null;
  }

  bool get _isBusy => _isSaving || _isLoadingProviders;

  @override
  void initState() {
    super.initState();
    _providerId = widget.flow.providerUserId;
    unawaited(_loadProviderOptions());
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final OpdFlowSummary flow = _currentFlow;
    final String actionLabel = _isNonEmpty(flow.providerUserId)
        ? l10n.opdChangeDoctorAction
        : l10n.opdAssignDoctorAction;
    final bool isBusy = _isBusy;
    return AppDialog(
      title: Text(actionLabel),
      icon: const Icon(AppActionIcons.assignDoctor),
      scrollable: true,
      pinActionsToBottom: true,
      closeEnabled: !isBusy,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null)
              AppFormInformationBanner.failure(
                context: context,
                failure: _failure!,
              ),
            OpdActionContextPanel(
              flow: flow,
              detail: _currentDetail,
              showTitle: false,
              showJourneyStepper: false,
              showPayment: false,
            ),
            _ProviderSelectField(
              value: _providerId,
              providers: _providerOptions,
              schedules: _providerSchedules,
              labelText: _opdRequiredFieldLabel(
                l10n,
                l10n.opdSearchProviderLabel,
              ),
              helperText: l10n.opdSearchProviderHelper,
              emptyHelperText: l10n.opdNoProvidersHelper,
              emptyResultsText: l10n.appSelectNoResults,
              enabled: !_isSaving,
              isLoading: _isLoadingProviders,
              onChanged: (String? value) {
                setState(() {
                  _providerId = value;
                });
              },
            ),
          ],
        ),
      ),
      actions: clinicalActionDialogActions(
        context,
        actionLabel,
        _isSaving,
        _isBusy ? null : _submit,
        submitLeadingIcon: AppActionIcons.assignDoctor,
        enabled: !_isLoadingProviders,
      ),
    );
  }

  Future<void> _loadProviderOptions() async {
    setState(() {
      _isLoadingProviders = true;
      _failure = null;
    });
    final OpdEncounterDialogController dialogController = ref.read(
      opdEncounterDialogControllerProvider,
    );
    final List<Object> results = await Future.wait(<Future<Object>>[
      dialogController.listProviders(),
      dialogController.listProviderSchedules(),
    ]);
    if (!mounted) {
      return;
    }

    final Result<List<OpdProviderOption>> providerResult =
        results[0] as Result<List<OpdProviderOption>>;
    final Result<List<OpdProviderSchedule>> scheduleResult =
        results[1] as Result<List<OpdProviderSchedule>>;

    AppFailure? loadFailure;
    providerResult.when(
      success: (List<OpdProviderOption> providers) {
        _providerOptions = dedupeOpdProviderOptions(providers);
      },
      failure: (AppFailure failure) {
        loadFailure = failure;
      },
    );
    scheduleResult.when(
      success: (List<OpdProviderSchedule> schedules) {
        _providerSchedules = schedules;
      },
      failure: (AppFailure failure) {
        loadFailure ??= failure;
      },
    );
    setState(() {
      _failure = loadFailure;
      _isLoadingProviders = false;
    });
  }

  Future<void> _submit() async {
    if (_isBusy) {
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final String? providerId = _providerId;
    if (!_isNonEmpty(providerId)) {
      setState(() => _failure = AppFailure.validation());
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(opdWorkspaceControllerProvider.notifier)
        .assignDoctor(_currentFlow, providerId!.trim());
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _failure = failure;
      _isSaving = false;
    });
  }
}

/// Disposition / referral / print summary live in extracted dialog files.

bool _isClinicalReviewStage(String? stage) {
  return <String>{
    'WAITING_DOCTOR_REVIEW',
    'WAITING_DISPOSITION',
    'LAB_REQUESTED',
    'RADIOLOGY_REQUESTED',
    'LAB_AND_RADIOLOGY_REQUESTED',
    'PHARMACY_REQUESTED',
    'DECISION_NEEDED',
    'RESULTS_READY',
    'REPORT_READY',
    'MEDICINES_DISPENSED',
  }.contains(_normalizedStage(stage));
}

bool _isServicePendingStage(String stage) {
  return <String>{
    'LAB_REQUESTED',
    'LAB_PENDING',
    'SAMPLE_PENDING',
    'IN_LAB',
    'RADIOLOGY_REQUESTED',
    'IMAGING_PENDING',
    'REPORT_PENDING',
    'PHARMACY_REQUESTED',
    'PHARMACY_PENDING',
    'LAB_AND_RADIOLOGY_REQUESTED',
  }.contains(stage);
}

IconData _departmentHandoffIcon(String stage) {
  return switch (stage) {
    'RADIOLOGY_REQUESTED' ||
    'IMAGING_PENDING' ||
    'REPORT_PENDING' => Icons.biotech_outlined,
    'PHARMACY_REQUESTED' || 'PHARMACY_PENDING' => Icons.medication_outlined,
    _ => Icons.science_outlined,
  };
}

void _navigateToDepartmentHandoff(BuildContext context, OpdFlowSummary flow) {
  final String encounterTarget = flow.apiId.trim();
  final String stage = _normalizedStage(flow.stage);
  final Map<String, String> queryParameters = encounterTarget.isEmpty
      ? const <String, String>{}
      : <String, String>{'encounterId': encounterTarget};
  final String location = switch (stage) {
    'RADIOLOGY_REQUESTED' || 'IMAGING_PENDING' || 'REPORT_PENDING' =>
      AppRoutes.radiology.location(queryParameters: queryParameters),
    'PHARMACY_REQUESTED' || 'PHARMACY_PENDING' => AppRoutes.pharmacy.location(
      queryParameters: queryParameters,
    ),
    _ => AppRoutes.lab.location(queryParameters: queryParameters),
  };
  Navigator.of(context).pop(true);
  context.go(location);
}

class _OpdWorkflowStatusSummary extends StatelessWidget {
  const _OpdWorkflowStatusSummary({required this.flow, required this.detail});

  final OpdFlowSummary flow;
  final OpdFlowDetail? detail;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<AppInfoTileData> items = <AppInfoTileData>[
      AppInfoTileData(
        label: l10n.opdArrivalModeLabel,
        value: _flowVisitTypeLabel(context, flow),
      ),
      AppInfoTileData(
        label: l10n.opdStageLabel,
        value: opdStageDisplayLabel(l10n, flow.displayCode ?? flow.stage),
      ),
      AppInfoTileData(
        label: l10n.opdQueueSummaryLabel,
        value: _flowQueueLabel(context, flow),
      ),
      AppInfoTileData(
        label: l10n.opdNextStepColumnLabel,
        value: opdNextStepDisplayLabel(
          l10n,
          flow.displayNextStep ?? flow.nextStep,
        ),
      ),
      AppInfoTileData(
        label: l10n.opdPaymentStatusLabel,
        value: opdFlowBillingDisplay(context, flow).label,
      ),
      AppInfoTileData(
        label: l10n.opdProviderColumnLabel,
        value: flow.providerDisplayName ?? l10n.profileUnknownValue,
      ),
      AppInfoTileData(
        label: l10n.opdTriageLevelLabel,
        value: triageLevelDisplayLabel(
          l10n,
          flow.triageLevel,
          emptyAsPending: false,
        ),
      ),
      AppInfoTileData(
        label: l10n.opdRouteDecisionLabel,
        value: _apiLabel(flow.lastRouteTo ?? ''),
      ),
      if (_isNonEmpty(flow.chiefComplaint))
        AppInfoTileData(
          label: l10n.opdChiefComplaintLabel,
          value: flow.chiefComplaint!,
        ),
    ];

    return AppTriageSummaryPanel(
      items: items,
      statuses: <AppWorkspaceStatus>[
        if (_isNonEmpty(flow.triageLevel))
          AppWorkspaceStatus(
            label: triageLevelDisplayLabel(l10n, flow.triageLevel),
            tone: appTriageToneForValue(flow.triageLevel),
            icon: appTriageIconForValue(flow.triageLevel),
          ),
      ],
      notesLabel: l10n.opdTriageNotesLabel,
      notes: flow.triageNotes,
      emptyValue: l10n.profileUnknownValue,
    );
  }
}

class _ProviderSelectField extends StatelessWidget {
  const _ProviderSelectField({
    required this.value,
    required this.providers,
    required this.schedules,
    required this.labelText,
    required this.helperText,
    required this.emptyHelperText,
    required this.enabled,
    required this.isLoading,
    required this.onChanged,
    this.emptyResultsText,
  });

  final String? value;
  final List<OpdProviderOption> providers;
  final List<OpdProviderSchedule> schedules;
  final String labelText;
  final String helperText;
  final String emptyHelperText;
  final String? emptyResultsText;
  final bool enabled;
  final bool isLoading;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final List<AppSelectOption<String>> options = _providerSelectOptions(
      providers: providers,
      schedules: schedules,
    );

    return AppSelectField<String>.searchable(
      value: value,
      options: options,
      labelText: labelText,
      helperText: options.isEmpty && !isLoading ? emptyHelperText : helperText,
      emptyResultsText: emptyResultsText,
      semanticLabel: labelText,
      enabled: enabled,
      isLoading: isLoading,
      onChanged: onChanged,
    );
  }
}

OpdWorkspaceState? _workspaceState(WidgetRef ref) {
  final Result<OpdWorkspaceState>? workspaceResult = ref
      .watch(opdWorkspaceControllerProvider)
      .asData
      ?.value;
  return workspaceResult?.when(
    success: (OpdWorkspaceState state) => state,
    failure: (_) => null,
  );
}

String _firstSelectableStage(String? currentStage) {
  final String normalizedCurrent = _normalizedStage(currentStage);
  return _flowStages.firstWhere(
    (String stage) => stage != normalizedCurrent,
    orElse: () => _flowStages.first,
  );
}

bool _stageCorrectionRequiresReason(String currentStage, String targetStage) {
  final int currentIndex = _flowStages.indexOf(currentStage);
  final int targetIndex = _flowStages.indexOf(targetStage);
  if (_terminalFlowStages.contains(targetStage)) {
    return true;
  }
  if (currentIndex < 0 || targetIndex < 0) {
    return true;
  }
  return targetIndex < currentIndex || (targetIndex - currentIndex).abs() > 1;
}

List<AppSelectOption<String>> _flowStageOptions(
  AppLocalizations l10n, {
  String? exclude,
}) {
  final String normalizedExclude = _normalizedStage(exclude);
  return <AppSelectOption<String>>[
    for (final String value in _flowStages)
      if (value != normalizedExclude)
        AppSelectOption<String>(
          value: value,
          label: opdStageDisplayLabel(l10n, value),
          leadingIcon: Icon(_flowStageIcon(value)),
        ),
  ];
}

List<AppSelectOption<String>> _providerSelectOptions({
  required List<OpdProviderOption> providers,
  required List<OpdProviderSchedule> schedules,
}) {
  return opdProviderSelectOptions(providers: providers, schedules: schedules);
}

String? _flowVisitTypeLabel(BuildContext context, OpdFlowSummary flow) {
  if (_isEmergencyFlow(flow)) {
    return context.l10n.opdTriageScopeEmergency;
  }
  final String arrivalMode = _apiLabel(flow.arrivalMode ?? '');
  if (arrivalMode.isNotEmpty) {
    return arrivalMode;
  }
  final String encounterType = _apiLabel(flow.encounterType ?? '');
  return encounterType.isEmpty ? null : encounterType;
}

String _flowQueueLabel(BuildContext context, OpdFlowSummary flow) {
  final String route = _apiLabel(flow.lastRouteTo ?? '');
  if (route.isNotEmpty && !_isCompletedStatus(flow.stage)) {
    return route;
  }

  final String stage = opdStageDisplayLabel(
    context.l10n,
    flow.displayCode ?? flow.stage,
  );
  return stage.isEmpty ? context.l10n.profileUnknownValue : stage;
}

bool _isEmergencyFlow(OpdFlowSummary flow) {
  return flow.emergencyIndicator ||
      (flow.encounterType ?? '').toUpperCase() == 'EMERGENCY' ||
      (flow.triageLevel ?? '').toUpperCase() == 'LEVEL_1' ||
      (flow.triageLevel ?? '').toUpperCase() == 'IMMEDIATE';
}

bool _isCompletedStatus(String? status) {
  return switch ((status ?? '').toUpperCase()) {
    'COMPLETED' ||
    'CANCELLED' ||
    'NO_SHOW' ||
    'DISCHARGED' ||
    'ADMITTED' ||
    'CLOSED' => true,
    _ => false,
  };
}

bool _isSameFlow(OpdFlowSummary left, OpdFlowSummary right) {
  return left.id == right.id ||
      (left.publicId != null && left.publicId == right.publicId);
}

String _normalizedStage(String? stage) {
  return (stage ?? '').trim().toUpperCase();
}

/// Whether the OPD encounter has a live inpatient admission attached.
///
/// True for the `ADMISSION_PENDING` display code, the terminal `ADMITTED`
/// stage, or any linked admission record that has not been discharged or
/// cancelled. Used to surface the OPD→IPD handoff action.
bool _flowHasPendingAdmission(OpdFlowSummary? flow, OpdFlowDetail? detail) {
  final String displayCode = (flow?.displayCode ?? '').trim().toUpperCase();
  if (displayCode == 'ADMISSION_PENDING') {
    return true;
  }
  if (_normalizedStage(flow?.stage) == 'ADMITTED') {
    return true;
  }
  final List<OpdRelatedRecord> admissions =
      detail?.admissions ?? const <OpdRelatedRecord>[];
  return admissions.any((OpdRelatedRecord record) {
    final String status = (record.status ?? '').trim().toUpperCase();
    return status != 'DISCHARGED' && status != 'CANCELLED';
  });
}

/// Resolves the best identifier to deep-link the inpatient workspace to the
/// admission created from this OPD encounter. Prefers the admission's display
/// id, then the patient identifier so IPD search can still locate the row.
String _admissionHandoffTarget(OpdFlowSummary flow, OpdFlowDetail? detail) {
  final List<OpdRelatedRecord> admissions =
      detail?.admissions ?? const <OpdRelatedRecord>[];
  for (final OpdRelatedRecord record in admissions) {
    final String status = (record.status ?? '').trim().toUpperCase();
    if (status == 'DISCHARGED' || status == 'CANCELLED') {
      continue;
    }
    if (record.id.trim().isNotEmpty) {
      return record.id.trim();
    }
  }
  for (final OpdRelatedRecord record in admissions) {
    if (record.id.trim().isNotEmpty) {
      return record.id.trim();
    }
  }
  return flow.patientIdentifier?.trim() ?? '';
}

String? _trimmedOrNull(String? value) {
  final String normalized = value?.trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}

bool _isNonEmpty(String? value) {
  return value != null && value.trim().isNotEmpty;
}

String _apiLabel(String value) {
  return AppDisplay.apiLabel(value);
}

String _opdRequiredFieldLabel(AppLocalizations l10n, String label) {
  return l10n.opdFieldRequiredLabel(label);
}

String _opdOptionalFieldLabel(AppLocalizations l10n, String label) {
  return l10n.opdFieldOptionalLabel(label);
}

IconData _flowStageIcon(String value) {
  return switch (value.toUpperCase()) {
    'WAITING_CONSULTATION_PAYMENT' => AppActionIcons.payment,
    'WAITING_VITALS' => Icons.monitor_heart_outlined,
    'WAITING_DOCTOR_ASSIGNMENT' => Icons.assignment_ind_outlined,
    'WAITING_DOCTOR_REVIEW' => Icons.medical_services_outlined,
    'LAB_REQUESTED' => Icons.science_outlined,
    'RADIOLOGY_REQUESTED' => Icons.biotech_outlined,
    'LAB_AND_RADIOLOGY_REQUESTED' => Icons.hub_outlined,
    'PHARMACY_REQUESTED' => Icons.local_pharmacy_outlined,
    'WAITING_DISPOSITION' => AppActionIcons.complete,
    'ADMITTED' => AppActionIcons.bed,
    'DISCHARGED' => AppActionIcons.logout,
    _ => AppActionIcons.move,
  };
}

void _showFailureIfNeeded(BuildContext context, AppFailure? failure) {
  showAppFailureSnackBar(context, failure);
}

const List<String> _flowStages = <String>[
  'WAITING_CONSULTATION_PAYMENT',
  'WAITING_VITALS',
  'WAITING_DOCTOR_ASSIGNMENT',
  'WAITING_DOCTOR_REVIEW',
  'LAB_REQUESTED',
  'RADIOLOGY_REQUESTED',
  'LAB_AND_RADIOLOGY_REQUESTED',
  'PHARMACY_REQUESTED',
  'WAITING_DISPOSITION',
  'ADMITTED',
  'DISCHARGED',
];

const Set<String> _terminalFlowStages = <String>{'ADMITTED', 'DISCHARGED'};
