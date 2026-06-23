import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/printing/print_form_template_context.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/utils/app_display.dart';
import 'package:hosspi_hms/features/clinical/data/repositories/clinical_repository_impl.dart';
import 'package:hosspi_hms/features/clinical/domain/repositories/clinical_repository.dart';
import 'package:hosspi_hms/features/opd/data/repositories/opd_repository_impl.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/presentation/controllers/opd_workspace_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_action_context.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_billing_state.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_consultation_billing_breakdown.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_provider_options.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_status_display.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';

const List<AppRole> _opdAdminActionRoles = <AppRole>[
  AppRole.superAdmin,
  AppRole.tenantAdmin,
  AppRole.facilityAdmin,
];

const AccessRequirement opdFrontDeskActionRequirement = AccessRequirement(
  anyRoles: <AppRole>[..._opdAdminActionRoles, AppRole.receptionist],
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
  anyRoles: <AppRole>[
    ..._opdAdminActionRoles,
    AppRole.receptionist,
    AppRole.billing,
  ],
  activeModules: <String>['scheduling-queue'],
);

const AccessRequirement opdStageCorrectionRequirement = AccessRequirement(
  anyRoles: _opdAdminActionRoles,
  activeModules: <String>['scheduling-queue'],
);

class FlowActionsDialog extends ConsumerStatefulWidget {
  const FlowActionsDialog({required this.flow, super.key});

  final OpdFlowSummary flow;

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
    final OpdWorkspaceState? workspaceState = _workspaceState(ref);
    final OpdFlowDetail? selected = workspaceState?.selectedFlow;
    final bool isRefreshingDetail = workspaceState?.isRefreshingDetail ?? false;
    final bool isSaving = workspaceState?.isSaving ?? false;
    final OpdFlowDetail? detail =
        selected == null || !_isSameFlow(selected.summary, widget.flow)
        ? null
        : selected;
    final OpdFlowSummary flow = detail?.summary ?? widget.flow;
    final bool isLoadingDetail = detail == null && !isSaving;

    return AppDialog(
        title: Text(flow.displayTitle),
        icon: const Icon(Icons.medical_services_outlined),
        maxWidth: 860,
        scrollable: true,
        closeEnabled: !isSaving,
        content: AppFormSection(
          density: AppFormSectionDensity.compact,
          children: <Widget>[
            OpdActionContextPanel(flow: flow, detail: detail),
            if (isSaving || isRefreshingDetail || isLoadingDetail)
              const LinearProgressIndicator(),
            if (detail != null && _isClinicalReviewStage(flow.stage))
              _OpdClinicalServicesPanel(detail: detail),
            _actionGrid(
              context,
              flow,
              detail,
              actionsEnabled: !isSaving && !isRefreshingDetail,
            ),
          ],
        ),
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
        label: action.label,
        icon: action.icon,
        onPressed: actionsEnabled ? action.onPressed : null,
        variant: AppButtonVariant.primary,
        enabled: actionsEnabled && action.enabled,
        isLoading: action.isLoading,
        fullWidth: action.fullWidth,
        hideWhenDenied: action.hideWhenDenied,
        tooltip: action.tooltip,
        semanticLabel: action.semanticLabel,
      );
    }

    AppPermissionActionItem billingAction() => AppPermissionActionItem(
      requirement: opdBillingActionRequirement,
      label: canPayNow
          ? l10n.opdPayConsultationAction
          : consultationPaid
          ? l10n.opdUpdateConsultationBillingAction
          : l10n.opdManageConsultationBillingAction,
      icon: Icons.payments_outlined,
      fullWidth: true,
      hideWhenDenied: true,
      enabled: actionsEnabled && !terminal,
      onPressed: terminal
          ? null
          : () => _openNested(context, ConsultationPaymentDialog(flow: flow)),
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

    AppPermissionActionItem assignDoctorAction() => AppPermissionActionItem(
      requirement: opdReceptionActionRequirement,
      label: _isNonEmpty(flow.providerUserId)
          ? l10n.opdChangeDoctorAction
          : l10n.opdAssignDoctorAction,
      icon: Icons.assignment_ind_outlined,
      fullWidth: true,
      hideWhenDenied: true,
      enabled: actionsEnabled && !terminal,
      onPressed: terminal
          ? null
          : () => _openNested(context, AssignDoctorDialog(flow: flow)),
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
        icon: Icons.task_alt_outlined,
        fullWidth: true,
        hideWhenDenied: true,
        enabled: actionsEnabled && !terminal && canDispose,
        tooltip: canDispose ? null : opdStageDisplayLabel(l10n, stage),
        onPressed: terminal || !canDispose || !actionsEnabled
            ? null
            : () => _openNested(
                context,
                OpdDispositionDialog(
                  flow: flow,
                  hasPharmacyOrder:
                      detail?.pharmacyOrders.isNotEmpty ??
                      stage == 'PHARMACY_REQUESTED',
                ),
              ),
      );
    }

    final bool hasAssignedProvider =
        _isNonEmpty(flow.providerUserId) ||
        _isNonEmpty(flow.providerDisplayName) ||
        _isNonEmpty(flow.assignedStaffDisplayName);
    final String displayCode = (flow.displayCode ?? '').trim().toUpperCase();
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
      'ADMISSION_PENDING' => 'handoff',
      _ => switch (stage) {
        'WAITING_CONSULTATION_PAYMENT' =>
          canPayNow ? 'billing' : 'correct_stage',
        'WAITING_VITALS' => 'vitals',
        'WAITING_DOCTOR_ASSIGNMENT' =>
          hasAssignedProvider ? 'doctor_review' : 'assign_doctor',
        'WAITING_DOCTOR_REVIEW' => 'doctor_review',
        'WAITING_DISPOSITION' => 'disposition',
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
          'assign_doctor': assignDoctorAction,
          'doctor_review': doctorReviewAction,
          'disposition': dispositionAction,
        };
    final AppPermissionActionItem Function()? nextFactory =
        actionFactories[nextActionKey];
    if (nextFactory != null) {
      addAction(nextActionKey, primaryAction(nextFactory()));
    }

    if (!terminal) {
      final bool clinicalStage = <String>{
        'WAITING_DOCTOR_REVIEW',
        'WAITING_DISPOSITION',
      }.contains(stage);
      final bool canAdjustBilling =
          nextActionKey != 'billing' &&
          (consultationPaid || consultationPaymentRequired);

      if (canAdjustBilling) {
        addAction('billing', billingAction());
      }

      if (clinicalStage) {
        addAction(
          'diagnosis',
          AppPermissionActionItem(
            requirement: opdDoctorActionRequirement,
            label: l10n.clinicalAddDiagnosisAction,
            icon: Icons.rule_outlined,
            fullWidth: true,
            hideWhenDenied: true,
            enabled: actionsEnabled,
            onPressed: actionsEnabled
                ? () => _openDiagnosisDialog(context, flow)
                : null,
          ),
        );
        addAction(
          'lab',
          AppPermissionActionItem(
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
        );
        addAction(
          'radiology',
          AppPermissionActionItem(
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
        );
        addAction(
          'prescription',
          AppPermissionActionItem(
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
        );
        addAction(
          'procedure',
          AppPermissionActionItem(
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
        );
        addAction(
          'referral',
          AppPermissionActionItem(
            requirement: opdDoctorActionRequirement,
            label: l10n.opdReferAction,
            icon: Icons.alt_route_outlined,
            fullWidth: true,
            hideWhenDenied: true,
            enabled: actionsEnabled,
            onPressed: actionsEnabled
                ? () => _openNested(context, ReferralDialog(flow: flow))
                : null,
          ),
        );
        addAction(
          'follow_up',
          AppPermissionActionItem(
            requirement: opdDoctorActionRequirement,
            label: l10n.opdFollowUpAction,
            icon: Icons.event_repeat_outlined,
            fullWidth: true,
            hideWhenDenied: true,
            enabled: actionsEnabled,
            onPressed: actionsEnabled
                ? () => _openNested(context, FollowUpDialog(flow: flow))
                : null,
          ),
        );
      }
      addAction('correct_stage', _correctStageAction(context, flow, actionsEnabled: actionsEnabled));
    } else {
      addAction('correct_stage', _correctStageAction(context, flow, actionsEnabled: actionsEnabled));
    }
    addAction(
      'print',
      AppPermissionActionItem(
        requirement: opdVitalsActionRequirement,
        label: l10n.opdPrintSummaryAction,
        icon: Icons.print_outlined,
        fullWidth: true,
        hideWhenDenied: true,
        enabled: actionsEnabled,
        onPressed: actionsEnabled
            ? () => _openNested(
                context,
                PrintOpdSummaryDialog(flow: flow, detail: detail),
              )
            : null,
      ),
    );

    return AppActionSection(
      title: l10n.opdActionsColumnLabel,
      minItemWidth: 170,
      maxColumns: 4,
      permissionActions: actions,
    );
  }

  AppPermissionActionItem _correctStageAction(
    BuildContext context,
    OpdFlowSummary flow, {
    required bool actionsEnabled,
  }) {
    return AppPermissionActionItem(
      requirement: opdStageCorrectionRequirement,
      label: context.l10n.opdCorrectStageAction,
      icon: Icons.sync_alt_outlined,
      fullWidth: true,
      hideWhenDenied: true,
      enabled: actionsEnabled,
      onPressed: actionsEnabled
          ? () => _openNested(context, CorrectStageDialog(flow: flow))
          : null,
    );
  }

  Future<void> _openNested(
    BuildContext context,
    Widget dialog, {
    bool closeParentOnChange = false,
  }) async {
    final bool? changed = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => dialog,
    );
    if (!context.mounted || changed != true) {
      return;
    }

    final OpdWorkspaceState? workspaceState = _workspaceState(ref);
    final OpdFlowSummary? updatedFlow = workspaceState?.selectedFlow?.summary;
    final bool isTerminal = updatedFlow?.isTerminal ?? false;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.opdSavedMessage)),
    );

    if (closeParentOnChange || isTerminal) {
      Navigator.of(context).pop(true);
    }
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
        .read(clinicalRepositoryProvider)
        .loadReferenceData();
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
    final ClinicalRepository repository = ref.read(clinicalRepositoryProvider);
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
              return repository.searchClinicalTerms(
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
    final ClinicalRepository repository = ref.read(clinicalRepositoryProvider);
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
              return repository.searchClinicalTerms(
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
    final ClinicalActionReferenceData? referenceData =
        await _loadClinicalReferenceData(context);
    if (!mounted || !context.mounted || referenceData == null) {
      return;
    }
    final ClinicalRepository repository = ref.read(clinicalRepositoryProvider);
    await _openNested(
      context,
      ClinicalLabOrderActionDialog(
        referenceData: referenceData,
        onSearchLabTests:
            ({
              required String termType,
              String? query,
              int? limit,
              String source = 'ALL',
            }) {
              return repository.searchClinicalTerms(
                termType: termType,
                query: query,
                limit: limit ?? 80,
                source: source,
              );
            },
        onRequest:
            ({
              required List<String> labTestIds,
              required List<String> labPanelIds,
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
    final ClinicalActionReferenceData? referenceData =
        await _loadClinicalReferenceData(context);
    if (!mounted || !context.mounted || referenceData == null) {
      return;
    }
    await _openNested(
      context,
      ClinicalRadiologyOrderActionDialog(
        referenceData: referenceData,
        onSubmit: ({required List<ClinicalActionRadiologyRequest> requests}) {
          return ref.read(opdWorkspaceControllerProvider.notifier).doctorReview(
            flow,
            <String, Object?>{
              'note': actionLabel,
              'radiology_requests': <Map<String, Object?>>[
                for (final ClinicalActionRadiologyRequest request in requests)
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
            },
          );
        },
      ),
    );
  }

  Future<void> _openPrescriptionDialog(
    BuildContext context,
    OpdFlowSummary flow,
  ) async {
    final String actionLabel = context.l10n.clinicalPrescribeAction;
    final ClinicalActionReferenceData? referenceData =
        await _loadClinicalReferenceData(context);
    if (!mounted || !context.mounted || referenceData == null) {
      return;
    }
    await _openNested(
      context,
      ClinicalPrescriptionActionDialog(
        referenceData: referenceData,
        onSubmit: ({required List<Map<String, Object?>> items}) {
          return ref.read(opdWorkspaceControllerProvider.notifier).doctorReview(
            flow,
            <String, Object?>{
              'note': actionLabel,
              'medications': <Map<String, Object?>>[
                for (final Map<String, Object?> item in items)
                  <String, Object?>{...item, 'status': 'ACTIVE'},
              ],
            },
          );
        },
      ),
    );
  }
}

class ConsultationPaymentDialog extends ConsumerStatefulWidget {
  const ConsultationPaymentDialog({required this.flow, super.key});

  final OpdFlowSummary flow;

  @override
  ConsumerState<ConsultationPaymentDialog> createState() =>
      _ConsultationPaymentDialogState();
}

class _ConsultationPaymentDialogState
    extends ConsumerState<ConsultationPaymentDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _referenceController;
  late final TextEditingController _notesController;
  String _currency = appDefaultCurrencyCode;
  String _method = 'CASH';
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
    final OpdFlowSummary flow = widget.flow;
    final OpdBillingState billingState = opdFlowBillingState(flow);
    _amountController = TextEditingController(
      text: opdCurrencyAmountInput(
        billingState == OpdBillingState.paid
            ? flow.consultationPaidAmount ?? flow.consultationFee
            : flow.consultationFee,
      ),
    );
    _referenceController = TextEditingController();
    _notesController = TextEditingController();
    _currency =
        flow.consultationCurrency?.trim().toUpperCase() ??
        appDefaultCurrencyCode;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final OpdFlowSummary flow = _currentFlow;
    final OpdFlowDetail? detail = _currentDetail;
    final bool alreadyPaid = opdFlowBillingState(flow) == OpdBillingState.paid;
    final String actionLabel = alreadyPaid
        ? l10n.opdUpdateConsultationBillingAction
        : l10n.opdPayConsultationAction;
    return AppDialog(
      title: Text(actionLabel),
      icon: const Icon(Icons.payments_outlined),
      scrollable: true,
      closeEnabled: !_isSaving,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            OpdActionContextPanel(flow: flow, detail: detail, showTitle: false),
            OpdConsultationBillingBreakdownPanel(flow: flow, detail: detail),
            AppCurrencyAmountField(
              amountController: _amountController,
              currency: _currency,
              amountLabelText: _opdRequiredFieldLabel(
                l10n,
                l10n.opdAmountLabel,
              ),
              currencyLabelText: _opdRequiredFieldLabel(
                l10n,
                l10n.opdCurrencyLabel,
              ),
              enabled: !_isSaving,
              validator: AppValidators.requiredText(l10n.validationRequired),
              onCurrencyChanged: (String? value) {
                setState(() {
                  _currency = value ?? appDefaultCurrencyCode;
                });
              },
            ),
            AppSelectField<String>(
              value: _method,
              labelText: _opdRequiredFieldLabel(
                l10n,
                l10n.opdPaymentMethodLabel,
              ),
              enabled: !_isSaving,
              onChanged: (String? value) {
                setState(() => _method = value ?? _method);
              },
              options: _statusOptions(_paymentMethods),
            ),
            AppTextField(
              controller: _referenceController,
              labelText: _opdOptionalFieldLabel(
                l10n,
                l10n.opdTransactionReferenceLabel,
              ),
              enabled: !_isSaving,
            ),
            AppTextField(
              controller: _notesController,
              labelText: _opdOptionalFieldLabel(l10n, l10n.opdNotesLabel),
              enabled: !_isSaving,
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: <Widget>[
        AppButton.primary(
          label: actionLabel,
          leadingIcon: Icons.payments_outlined,
          isLoading: _isSaving,
          onPressed: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(opdWorkspaceControllerProvider.notifier)
        .payConsultation(_currentFlow, <String, Object?>{
          'amount': normalizeCurrencyAmount(_amountController.text),
          'currency': _currency,
          'method': _method,
          'status': 'COMPLETED',
          'transaction_ref': _referenceController.text.trim(),
          'notes': _notesController.text.trim(),
          if (opdFlowBillingState(_currentFlow) == OpdBillingState.paid)
            'correction': true,
          'paid_at': DateTime.now().toUtc().toIso8601String(),
        });
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
    final String currentStage = _normalizedStage(widget.flow.stage);
    final bool reasonRequired = _stageCorrectionRequiresReason(
      currentStage,
      _stage,
    );
    return AppDialog(
      title: Text(l10n.opdCorrectStageAction),
      icon: const Icon(Icons.edit_note_outlined),
      scrollable: true,
      closeEnabled: !_isSaving,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            OpdActionContextPanel(flow: widget.flow, showTitle: false),
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
      actions: <Widget>[
        AppButton.primary(
          label: l10n.opdSaveAction,
          leadingIcon: Icons.save_outlined,
          isLoading: _isSaving,
          onPressed: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_normalizedStage(widget.flow.stage) == _stage) {
      setState(() => _failure = AppFailure.validation());
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(opdWorkspaceControllerProvider.notifier)
        .correctStage(widget.flow, _stage, _reasonController.text.trim());
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

class AssignDoctorDialog extends ConsumerStatefulWidget {
  const AssignDoctorDialog({required this.flow, super.key});

  final OpdFlowSummary flow;

  @override
  ConsumerState<AssignDoctorDialog> createState() => _AssignDoctorDialogState();
}

class _AssignDoctorDialogState extends ConsumerState<AssignDoctorDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  List<OpdProviderOption> _providerOptions = const <OpdProviderOption>[];
  String? _providerId;
  bool _isLoadingProviders = false;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _providerId = widget.flow.providerUserId;
    unawaited(_loadProviderOptions());
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String actionLabel = _isNonEmpty(widget.flow.providerUserId)
        ? l10n.opdChangeDoctorAction
        : l10n.opdAssignDoctorAction;
    return AppDialog(
      title: Text(actionLabel),
      icon: const Icon(Icons.assignment_ind_outlined),
      scrollable: true,
      closeEnabled: !_isSaving,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
            OpdActionContextPanel(flow: widget.flow, showTitle: false),
            _ProviderSelectField(
              value: _providerId,
              providers: _providerOptions,
              schedules: const <OpdProviderSchedule>[],
              labelText: _opdRequiredFieldLabel(
                l10n,
                l10n.opdSearchProviderLabel,
              ),
              helperText: l10n.opdSearchProviderHelper,
              emptyHelperText: l10n.opdNoProvidersHelper,
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
      actions: <Widget>[
        AppButton.primary(
          label: actionLabel,
          leadingIcon: Icons.assignment_ind_outlined,
          isLoading: _isSaving,
          onPressed: _submit,
        ),
      ],
    );
  }

  Future<void> _loadProviderOptions() async {
    setState(() {
      _isLoadingProviders = true;
    });
    final Result<List<OpdProviderOption>> result = await ref
        .read(opdRepositoryProvider)
        .listProviders();
    if (!mounted) {
      return;
    }

    result.when(
      success: (List<OpdProviderOption> providers) {
        setState(() {
          _providerOptions = dedupeOpdProviderOptions(providers);
          _isLoadingProviders = false;
        });
      },
      failure: (AppFailure failure) {
        setState(() {
          _failure = failure;
          _isLoadingProviders = false;
        });
      },
    );
  }

  Future<void> _submit() async {
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
        .assignDoctor(widget.flow, providerId!.trim());
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

class RoutingDecisionDialog extends ConsumerStatefulWidget {
  const RoutingDecisionDialog({required this.flow, super.key});

  final OpdFlowSummary flow;

  @override
  ConsumerState<RoutingDecisionDialog> createState() =>
      _RoutingDecisionDialogState();
}

class _RoutingDecisionDialogState extends ConsumerState<RoutingDecisionDialog> {
  late final TextEditingController _notesController;
  String _decision = 'CONSULTATION';
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.opdRouteDecisionLabel),
      icon: const Icon(Icons.alt_route_outlined),
      closeEnabled: !_isSaving,
      content: AppFormSection(
        children: <Widget>[
          if (_failure != null) AppFailureStateView(failure: _failure!),
          OpdActionContextPanel(flow: widget.flow, showTitle: false),
          AppTriageDecisionField(
            value: _decision,
            labelText: _opdRequiredFieldLabel(l10n, l10n.opdRouteDecisionLabel),
            enabled: !_isSaving,
            searchable: false,
            isRequired: true,
            onChanged: (String? value) =>
                setState(() => _decision = value ?? _decision),
            options: _triageRouteFieldOptions(),
          ),
          AppTextField(
            controller: _notesController,
            labelText: _opdOptionalFieldLabel(l10n, l10n.opdNotesLabel),
            enabled: !_isSaving,
            maxLines: 3,
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.primary(
          label: l10n.opdRouteDecisionLabel,
          leadingIcon: Icons.alt_route_outlined,
          isLoading: _isSaving,
          onPressed: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(opdWorkspaceControllerProvider.notifier)
        .disposeFlow(widget.flow, _decision, _notesController.text.trim());
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

class OpdDispositionDialog extends ConsumerWidget {
  const OpdDispositionDialog({
    required this.flow,
    required this.hasPharmacyOrder,
    super.key,
  });

  final OpdFlowSummary flow;
  final bool hasPharmacyOrder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String actionLabel = clinicalDispositionActionLabel(
      l10n,
      sourceQueue: 'OPD',
      status: flow.status,
      stage: flow.stage,
      isOpdContext: true,
    );
    return ClinicalDispositionActionDialog(
      title: actionLabel,
      reasonLabel: _opdRequiredFieldLabel(l10n, l10n.opdDecisionLabel),
      notesLabel: _opdOptionalFieldLabel(l10n, l10n.opdNotesLabel),
      submitLabel: actionLabel,
      initialReason: hasPharmacyOrder ? 'SEND_TO_PHARMACY' : 'DISCHARGE',
      reasons: _opdDispositionOptions(hasPharmacyOrder: hasPharmacyOrder),
      leadingContent: <Widget>[
        OpdActionContextPanel(flow: flow, showTitle: false),
      ],
      onSubmit: ({required String reason, required String notes}) {
        return ref
            .read(opdWorkspaceControllerProvider.notifier)
            .completeDisposition(flow, <String, Object?>{
              'decision': reason,
              'notes': notes,
            });
      },
    );
  }
}

class ReferralDialog extends ConsumerWidget {
  const ReferralDialog({required this.flow, super.key});

  final OpdFlowSummary flow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ClinicalReferralActionDialog(
      leadingContent: <Widget>[
        OpdActionContextPanel(flow: flow, showTitle: false),
      ],
      onSubmit:
          ({
            required String externalFacilityName,
            required String reason,
            required String notes,
          }) {
            return ref
                .read(opdWorkspaceControllerProvider.notifier)
                .createReferral(
                  flow: flow,
                  externalFacilityName: externalFacilityName,
                  reason: reason,
                  notes: notes,
                );
          },
    );
  }
}

class FollowUpDialog extends ConsumerWidget {
  const FollowUpDialog({required this.flow, super.key});

  final OpdFlowSummary flow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ClinicalFollowUpActionDialog(
      leadingContent: <Widget>[
        OpdActionContextPanel(flow: flow, showTitle: false),
      ],
      onSubmit: ({required DateTime scheduledAt, required String notes}) {
        return ref
            .read(opdWorkspaceControllerProvider.notifier)
            .createFollowUp(flow: flow, scheduledAt: scheduledAt, notes: notes);
      },
    );
  }
}

class PrintOpdSummaryDialog extends ConsumerWidget {
  const PrintOpdSummaryDialog({
    required this.flow,
    required this.detail,
    super.key,
  });

  final OpdFlowSummary flow;
  final OpdFlowDetail? detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String summary = _printSummary(context);
    return AppDialog(
      title: Text(l10n.opdPrintSummaryAction),
      icon: const Icon(Icons.print_outlined),
      maxWidth: 720,
      scrollable: true,
      content: AppFormSection(
        density: AppFormSectionDensity.compact,
        children: <Widget>[
          OpdActionContextPanel(flow: flow, showTitle: false),
          AppReportPreviewPanel(
            selectable: true,
            child: Text(summary, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
      actions: <Widget>[
        AppReportActionButton.copy(
          label: l10n.opdCopySummaryAction,
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: summary));
            if (context.mounted) {
              Navigator.of(context).pop(false);
            }
          },
        ),
        AppReportActionButton.print(
          label: l10n.opdPrintAction,
          onPressed: () async {
            await printFormTemplateDocument(
              ref: ref,
              context: context,
              title: l10n.opdPrintSummaryAction,
              subtitle: flow.displayTitle,
              metadata: <PrintFormMetadataItem>[
                PrintFormMetadataItem(
                  label: l10n.patientsIdentifierLabel,
                  value: flow.patientIdentifier ?? '',
                ),
                PrintFormMetadataItem(
                  label: l10n.opdStageLabel,
                  value: opdStageDisplayLabel(
                    l10n,
                    flow.displayCode ?? flow.stage,
                  ),
                ),
                PrintFormMetadataItem(
                  label: l10n.opdNextStepColumnLabel,
                  value: opdNextStepDisplayLabel(
                    l10n,
                    flow.displayNextStep ?? flow.nextStep,
                  ),
                ),
                PrintFormMetadataItem(
                  label: l10n.opdPaymentStatusLabel,
                  value: opdFlowBillingDisplay(context, flow).label,
                ),
              ],
              bodyHtml:
                  '<div class="print-template-note">${printHtmlEscape(summary)}</div>',
            );
            if (!context.mounted) {
              return;
            }
            Navigator.of(context).pop(false);
          },
        ),
      ],
    );
  }

  String _printSummary(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final OpdFlowDetail? value = detail;
    final List<String> lines = <String>[
      flow.displayTitle,
      _joinDisplay(<String?>[
        flow.patientIdentifier,
        flow.patientPhone,
        flow.assignedStaffLabel ?? flow.providerDisplayName,
      ]),
      '${l10n.opdStageLabel}: '
          '${opdStageDisplayLabel(l10n, flow.displayCode ?? flow.stage)}',
      '${l10n.opdNextStepColumnLabel}: '
          '${opdNextStepDisplayLabel(l10n, flow.displayNextStep ?? flow.nextStep)}',
      '${l10n.opdTriageLevelLabel}: ${_apiLabel(flow.triageLevel ?? '')}',
      '${l10n.opdRouteDecisionLabel}: ${_apiLabel(flow.lastRouteTo ?? '')}',
      if (_isNonEmpty(flow.chiefComplaint))
        '${l10n.opdChiefComplaintLabel}: ${flow.chiefComplaint}',
      if (_isNonEmpty(flow.triageNotes))
        '${l10n.opdTriageNotesLabel}: ${flow.triageNotes}',
      '${l10n.opdPaymentStatusLabel}: ${opdFlowBillingDisplay(context, flow).label}',
      '${l10n.opdVitalsSummaryLabel}: ${value?.vitalSigns.length ?? 0}',
      '${l10n.opdClinicalNotesSummaryLabel}: ${value?.clinicalNotes.length ?? 0}',
      '${l10n.opdServicesSummaryLabel}: ${(value?.labOrders.length ?? 0) + (value?.radiologyOrders.length ?? 0) + (value?.pharmacyOrders.length ?? 0)}',
      if (value != null && value.vitalSigns.isNotEmpty) '',
      if (value != null && value.vitalSigns.isNotEmpty)
        l10n.opdVitalsSummaryLabel,
      if (value != null)
        for (final OpdRelatedRecord vital in value.vitalSigns)
          _joinDisplay(<String?>[vital.title, vital.subtitle]),
      if (value != null && value.timeline.isNotEmpty) '',
      if (value != null && value.timeline.isNotEmpty) l10n.opdTimelineTitle,
      if (value != null)
        for (final OpdTimelineItem item in value.timeline)
          _joinDisplay(<String?>[
            _apiLabel(item.action),
            opdStageDisplayLabel(l10n, item.stage),
            item.notes,
          ]),
    ];
    return lines.where((String line) => line.trim().isNotEmpty).join('\n');
  }
}

class RecordVitalsDialog extends ConsumerStatefulWidget {
  const RecordVitalsDialog({
    required this.flow,
    this.detail,
    this.editing = false,
    super.key,
  });

  final OpdFlowSummary flow;
  final OpdFlowDetail? detail;
  final bool editing;

  @override
  ConsumerState<RecordVitalsDialog> createState() => _RecordVitalsDialogState();
}

class _RecordVitalsDialogState extends ConsumerState<RecordVitalsDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _chiefComplaintController;
  late final TextEditingController _symptomsController;
  late final TextEditingController _allergiesController;
  late final TextEditingController _temperatureController;
  late final TextEditingController _systolicController;
  late final TextEditingController _diastolicController;
  late final TextEditingController _heartRateController;
  late final TextEditingController _respiratoryRateController;
  late final TextEditingController _oxygenSaturationController;
  late final TextEditingController _weightController;
  late final TextEditingController _heightController;
  late final TextEditingController _notesController;
  String? _triageLevel;
  String? _painSeverity;
  String? _routeDecision;
  String? _providerId;
  String _bloodPressureUnit = AppVitalsUnits.bloodPressureMmHg;
  String _selectedTemperatureUnit = AppVitalsUnits.temperatureCelsius;
  String _selectedWeightUnit = AppVitalsUnits.weightKilograms;
  String _selectedHeightUnit = AppVitalsUnits.heightCentimeters;
  final Set<String> _riskFlags = <String>{};
  List<OpdProviderOption> _providerOptions = const <OpdProviderOption>[];
  bool _emergencyIndicator = false;
  bool _isLoadingProviders = false;
  bool _isSaving = false;
  AppFailure? _failure;
  String? _formErrorText;

  @override
  void initState() {
    super.initState();
    _chiefComplaintController = TextEditingController(
      text: widget.flow.chiefComplaint ?? '',
    );
    _symptomsController = TextEditingController();
    _allergiesController = TextEditingController();
    _temperatureController = TextEditingController(
      text: _initialVitalValue('TEMPERATURE'),
    );
    _systolicController = TextEditingController(text: _initialSystolicValue());
    _diastolicController = TextEditingController(
      text: _initialDiastolicValue(),
    );
    _heartRateController = TextEditingController(
      text: _initialVitalValue('HEART_RATE'),
    );
    _respiratoryRateController = TextEditingController(
      text: _initialVitalValue('RESPIRATORY_RATE'),
    );
    _oxygenSaturationController = TextEditingController(
      text: _initialVitalValue('OXYGEN_SATURATION'),
    );
    _weightController = TextEditingController(
      text: _initialVitalValue('WEIGHT'),
    );
    _heightController = TextEditingController(
      text: _initialVitalValue('HEIGHT'),
    );
    _notesController = TextEditingController();
    _triageLevel = widget.flow.triageLevel;
    _providerId = widget.flow.providerUserId;
    _bloodPressureUnit = _initialVitalUnit(
      'BLOOD_PRESSURE',
      AppVitalsUnits.bloodPressureMmHg,
    );
    _selectedTemperatureUnit = _initialVitalUnit(
      'TEMPERATURE',
      AppVitalsUnits.temperatureCelsius,
    );
    _selectedWeightUnit = _initialVitalUnit(
      'WEIGHT',
      AppVitalsUnits.weightKilograms,
    );
    _selectedHeightUnit = _initialVitalUnit(
      'HEIGHT',
      AppVitalsUnits.heightCentimeters,
    );
    unawaited(_loadProviderOptions());
  }

  @override
  void dispose() {
    _chiefComplaintController.dispose();
    _symptomsController.dispose();
    _allergiesController.dispose();
    _temperatureController.dispose();
    _systolicController.dispose();
    _diastolicController.dispose();
    _heartRateController.dispose();
    _respiratoryRateController.dispose();
    _oxygenSaturationController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool editingVitals = widget.editing && widget.detail != null;
    final String actionLabel = editingVitals
        ? l10n.opdEditVitalsAction
        : l10n.opdRecordVitalsAction;
    return AppDialog(
      title: Text(actionLabel),
      icon: const Icon(Icons.monitor_heart_outlined),
      scrollable: true,
      closeEnabled: !_isSaving,
      maxWidth: 780,
      content: AppFormShell(
        formKey: _formKey,
        enabled: !_isSaving,
        density: AppFormSectionDensity.compact,
        formStatus: _failure == null
            ? null
            : AppFailureStateView(failure: _failure!, body: _formErrorText),
        children: <Widget>[
          OpdActionContextPanel(flow: widget.flow, showTitle: false),
          if (!editingVitals) _triagePrioritySection(context),
          _vitalsSection(context),
          _notesSection(context),
        ],
      ),
      actions: <Widget>[
        AppButton.primary(
          label: actionLabel,
          leadingIcon: Icons.save_outlined,
          isLoading: _isSaving,
          onPressed: _submit,
        ),
      ],
    );
  }

  Widget _triagePrioritySection(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppFormSection(
      title: l10n.patientsTriagePrioritySectionTitle,
      density: AppFormSectionDensity.compact,
      children: <Widget>[
        AppTextField(
          controller: _chiefComplaintController,
          labelText: _opdOptionalFieldLabel(l10n, l10n.opdChiefComplaintLabel),
          enabled: !_isSaving,
          maxLines: 2,
        ),
        AppTextField(
          controller: _symptomsController,
          labelText: _opdOptionalFieldLabel(l10n, l10n.opdSymptomsLabel),
          enabled: !_isSaving,
          maxLines: 2,
        ),
        AppResponsiveFieldRow(
          gap: AppResponsiveFieldRowGap.form,
          children: <Widget>[
            AppSelectField<String>.searchable(
              value: _painSeverity,
              labelText: _opdOptionalFieldLabel(
                l10n,
                l10n.opdPainSeverityLabel,
              ),
              semanticLabel: _opdOptionalFieldLabel(
                l10n,
                l10n.opdPainSeverityLabel,
              ),
              enabled: !_isSaving,
              onChanged: (String? value) {
                setState(() => _painSeverity = value);
              },
              options: _painSeverityOptions,
            ),
            AppTextField(
              controller: _allergiesController,
              labelText: _opdOptionalFieldLabel(l10n, l10n.opdAllergiesLabel),
              enabled: !_isSaving,
            ),
          ],
        ),
        AppSwitchField(
          title: l10n.opdEmergencyIndicatorsLabel,
          value: _emergencyIndicator,
          enabled: !_isSaving,
          secondary: const Icon(Icons.emergency_outlined),
          onChanged: (bool value) {
            setState(() {
              _emergencyIndicator = value;
              if (value && _triageLevel == null) {
                _triageLevel = 'LEVEL_1';
              }
              if (value && _routeDecision == null) {
                _routeDecision = 'EMERGENCY';
              }
            });
          },
        ),
        AppTriageRiskFlagSelector(
          title: l10n.opdRiskFlagsLabel,
          options: _triageRiskFlagFieldOptions(l10n),
          selected: _riskFlags,
          enabled: !_isSaving,
          onChanged: _setRiskFlag,
        ),
        AppTriageUrgencyField(
          value: _triageLevel,
          labelText: _opdOptionalFieldLabel(l10n, l10n.opdTriageLevelLabel),
          semanticLabel: _opdOptionalFieldLabel(l10n, l10n.opdTriageLevelLabel),
          enabled: !_isSaving,
          onChanged: (String? value) => setState(() => _triageLevel = value),
          options: _triageLevelFieldOptions(),
        ),
        AppTriageDecisionField(
          value: _routeDecision ?? _opdNoRouteDecisionValue,
          labelText: _opdOptionalFieldLabel(l10n, l10n.opdRouteDecisionLabel),
          semanticLabel: _opdOptionalFieldLabel(
            l10n,
            l10n.opdRouteDecisionLabel,
          ),
          enabled: !_isSaving,
          onChanged: (String? value) {
            setState(() {
              _routeDecision =
                  value == null || value == _opdNoRouteDecisionValue
                  ? null
                  : value;
            });
          },
          options: _routeDecisionOptions(context),
        ),
        if (_routeDecision == 'CONSULTATION')
          _ProviderSelectField(
            value: _providerId,
            providers: _providerOptions,
            schedules: const <OpdProviderSchedule>[],
            labelText: _opdOptionalFieldLabel(
              l10n,
              l10n.opdSearchProviderLabel,
            ),
            helperText: l10n.opdSearchProviderHelper,
            emptyHelperText: l10n.opdNoProvidersHelper,
            enabled: !_isSaving,
            isLoading: _isLoadingProviders,
            onChanged: (String? value) {
              setState(() => _providerId = value);
            },
          ),
      ],
    );
  }

  Widget _vitalsSection(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppFormSection(
      title: l10n.patientsVitalsSectionTitle,
      density: AppFormSectionDensity.compact,
      children: <Widget>[
        Text(
          l10n.opdVitalsAtLeastOneRequiredHelper,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        AppVitalsForm(
          temperatureController: _temperatureController,
          systolicController: _systolicController,
          diastolicController: _diastolicController,
          heartRateController: _heartRateController,
          respiratoryRateController: _respiratoryRateController,
          oxygenSaturationController: _oxygenSaturationController,
          weightController: _weightController,
          heightController: _heightController,
          bloodPressureLabel: l10n.patientsBloodPressureLabel,
          temperatureLabel: l10n.patientsTemperatureLabel,
          systolicLabel: l10n.patientsSystolicLabel,
          diastolicLabel: l10n.patientsDiastolicLabel,
          heartRateLabel: l10n.patientsHeartRateLabel,
          respiratoryRateLabel: l10n.patientsRespiratoryRateLabel,
          oxygenSaturationLabel: l10n.patientsOxygenSaturationLabel,
          weightLabel: l10n.patientsWeightLabel,
          heightLabel: l10n.patientsHeightLabel,
          unitLabel: l10n.patientsVitalUnitLabel,
          bloodPressureUnit: _bloodPressureUnit,
          temperatureUnit: _selectedTemperatureUnit,
          weightUnit: _selectedWeightUnit,
          heightUnit: _selectedHeightUnit,
          enabled: !_isSaving,
          onBloodPressureUnitChanged: (String? value) {
            setState(() {
              _bloodPressureUnit = value ?? AppVitalsUnits.bloodPressureMmHg;
            });
          },
          onTemperatureUnitChanged: (String? value) {
            setState(() {
              _selectedTemperatureUnit =
                  value ?? AppVitalsUnits.temperatureCelsius;
            });
          },
          onWeightUnitChanged: (String? value) {
            setState(() {
              _selectedWeightUnit = value ?? AppVitalsUnits.weightKilograms;
            });
          },
          onHeightUnitChanged: (String? value) {
            setState(() {
              _selectedHeightUnit = value ?? AppVitalsUnits.heightCentimeters;
            });
          },
        ),
      ],
    );
  }

  Widget _notesSection(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppFormSection(
      title: l10n.patientsNotesSectionTitle,
      density: AppFormSectionDensity.compact,
      children: <Widget>[
        AppTextField(
          controller: _notesController,
          labelText: _opdOptionalFieldLabel(l10n, l10n.opdTriageNotesLabel),
          enabled: !_isSaving,
          maxLines: 3,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final AppLocalizations l10n = context.l10n;
    if (!validateAndSaveAppForm(_formKey)) {
      setState(() {
        _failure = AppFailure.validation();
        _formErrorText = l10n.errorValidationMessage;
      });
      return;
    }
    final List<Map<String, Object?>> vitals = _vitalsPayload();
    if (vitals.isEmpty) {
      setState(() {
        _failure = AppFailure.validation(
          validationFields: const <String>{'vitals'},
        );
        _formErrorText = l10n.opdVitalsAtLeastOneRequiredHelper;
      });
      return;
    }
    if (!_hasCompleteBloodPressureInput()) {
      setState(() {
        _failure = AppFailure.validation(
          validationFields: const <String>{'blood_pressure'},
        );
        _formErrorText = l10n.errorValidationMessage;
      });
      return;
    }
    final bool editingVitals = widget.editing && widget.detail != null;
    if (!editingVitals &&
        _routeDecision == 'CONSULTATION' &&
        !_isNonEmpty(_providerId ?? widget.flow.providerUserId)) {
      setState(() {
        _failure = AppFailure.validation(
          validationFields: const <String>{'provider_user_id'},
        );
        _formErrorText = l10n.validationRequired;
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _failure = null;
      _formErrorText = null;
    });
    final String triageNotes = _triageNotesPayload(l10n);
    final AppFailure? failure = editingVitals
        ? await ref
              .read(opdWorkspaceControllerProvider.notifier)
              .updateVitals(widget.detail!, vitals)
        : await ref
              .read(opdWorkspaceControllerProvider.notifier)
              .recordVitals(widget.flow, <String, Object?>{
                'vitals': vitals,
                'triage_level': _triageLevel,
                'triage_priority': _triageLevel,
                'chief_complaint': _chiefComplaintController.text.trim(),
                'emergency': _emergencyIndicator,
                'triage_notes': triageNotes,
              });
    if (!mounted) {
      return;
    }
    if (failure != null) {
      setState(() {
        _failure = failure;
        _formErrorText = null;
        _isSaving = false;
      });
      return;
    }

    final String? routeDecision = editingVitals ? null : _routeDecision;
    if (_isNonEmpty(routeDecision)) {
      final AppFailure? routeFailure = await ref
          .read(opdWorkspaceControllerProvider.notifier)
          .disposeFlow(
            widget.flow,
            routeDecision!.trim(),
            triageNotes,
            providerUserId: _providerId,
            triageLevel: _triageLevel,
            emergency: _emergencyIndicator,
          );
      if (!mounted) {
        return;
      }
      if (routeFailure != null) {
        setState(() {
          _failure = routeFailure;
          _formErrorText = null;
          _isSaving = false;
        });
        return;
      }
    }

    Navigator.of(context).pop(true);
  }

  List<Map<String, Object?>> _vitalsPayload() {
    final List<Map<String, Object?>> vitals = <Map<String, Object?>>[];
    void addSimpleVital(
      TextEditingController controller,
      String type,
      String unit,
    ) {
      final String value = normalizeCurrencyAmount(controller.text);
      if (value.isEmpty) {
        return;
      }
      vitals.add(<String, Object?>{
        'vital_type': type,
        'value': value,
        'unit': unit,
        'recorded_at': DateTime.now().toUtc().toIso8601String(),
      });
    }

    addSimpleVital(
      _temperatureController,
      'TEMPERATURE',
      _selectedTemperatureUnit,
    );
    final String systolic = normalizeCurrencyAmount(_systolicController.text);
    final String diastolic = normalizeCurrencyAmount(_diastolicController.text);
    if (systolic.isNotEmpty && diastolic.isNotEmpty) {
      final String systolicValue = _bloodPressurePayloadValue(
        _systolicController,
      );
      final String diastolicValue = _bloodPressurePayloadValue(
        _diastolicController,
      );
      vitals.add(<String, Object?>{
        'vital_type': 'BLOOD_PRESSURE',
        'value': '$systolicValue/$diastolicValue',
        'unit': AppVitalsUnits.bloodPressureMmHg,
        'systolic_value': systolicValue,
        'diastolic_value': diastolicValue,
        'recorded_at': DateTime.now().toUtc().toIso8601String(),
      });
    }
    addSimpleVital(
      _heartRateController,
      'HEART_RATE',
      AppVitalsUnits.heartRate,
    );
    addSimpleVital(
      _respiratoryRateController,
      'RESPIRATORY_RATE',
      AppVitalsUnits.respiratoryRate,
    );
    addSimpleVital(
      _oxygenSaturationController,
      'OXYGEN_SATURATION',
      AppVitalsUnits.oxygenSaturation,
    );
    addSimpleVital(_weightController, 'WEIGHT', _selectedWeightUnit);
    addSimpleVital(_heightController, 'HEIGHT', _selectedHeightUnit);
    return vitals;
  }

  String _initialVitalValue(String type) {
    final OpdVitalSign? vital = _initialVital(type);
    return _formatOpdVitalInput(vital?.value);
  }

  String _initialSystolicValue() {
    final OpdVitalSign? vital = _initialVital('BLOOD_PRESSURE');
    final String value = _formatOpdVitalNumber(vital?.systolicValue);
    return value.isEmpty ? _legacyBloodPressurePart(vital?.value, 0) : value;
  }

  String _initialDiastolicValue() {
    final OpdVitalSign? vital = _initialVital('BLOOD_PRESSURE');
    final String value = _formatOpdVitalNumber(vital?.diastolicValue);
    return value.isEmpty ? _legacyBloodPressurePart(vital?.value, 1) : value;
  }

  String _initialVitalUnit(String type, String fallback) {
    final String normalized = _initialVital(type)?.unit?.trim() ?? '';
    return switch (normalized) {
      AppVitalsUnits.bloodPressureKpa => AppVitalsUnits.bloodPressureKpa,
      AppVitalsUnits.bloodPressureMmHg => AppVitalsUnits.bloodPressureMmHg,
      AppVitalsUnits.temperatureFahrenheit ||
      'F' => AppVitalsUnits.temperatureFahrenheit,
      AppVitalsUnits.temperatureCelsius ||
      'C' => AppVitalsUnits.temperatureCelsius,
      AppVitalsUnits.weightPounds => AppVitalsUnits.weightPounds,
      AppVitalsUnits.weightKilograms => AppVitalsUnits.weightKilograms,
      AppVitalsUnits.heightMeters => AppVitalsUnits.heightMeters,
      AppVitalsUnits.heightCentimeters => AppVitalsUnits.heightCentimeters,
      _ => fallback,
    };
  }

  String _bloodPressurePayloadValue(TextEditingController controller) {
    final double? value = parseAppVitalInput(controller.text);
    if (value == null) {
      return '';
    }
    final double mmHg = _bloodPressureUnit == AppVitalsUnits.bloodPressureKpa
        ? value / AppVitalsUnits.bloodPressureKpaFactor
        : value;
    return formatAppVitalNumber(mmHg, decimals: 2);
  }

  OpdVitalSign? _initialVital(String type) {
    OpdVitalSign? latest;
    for (final OpdVitalSign vital
        in widget.detail?.vitalMeasurements ?? const <OpdVitalSign>[]) {
      if (vital.vitalType != type) {
        continue;
      }
      if (latest == null) {
        latest = vital;
        continue;
      }
      final DateTime? recordedAt = vital.recordedAt;
      final DateTime? latestRecordedAt = latest.recordedAt;
      if (recordedAt != null &&
          (latestRecordedAt == null || recordedAt.isAfter(latestRecordedAt))) {
        latest = vital;
      }
    }
    return latest;
  }

  String _formatOpdVitalInput(String? value) {
    final num? parsed = value == null ? null : num.tryParse(value.trim());
    if (parsed == null) {
      return value?.trim() ?? '';
    }
    return formatAppVitalNumber(parsed);
  }

  String _formatOpdVitalNumber(num? value) {
    return value == null ? '' : formatAppVitalNumber(value);
  }

  String _legacyBloodPressurePart(String? value, int index) {
    final List<String> parts = (value ?? '').split('/');
    if (parts.length <= index) {
      return '';
    }
    return _formatOpdVitalInput(parts[index]);
  }

  bool _hasCompleteBloodPressureInput() {
    final bool hasSystolic = normalizeCurrencyAmount(
      _systolicController.text,
    ).isNotEmpty;
    final bool hasDiastolic = normalizeCurrencyAmount(
      _diastolicController.text,
    ).isNotEmpty;
    return hasSystolic == hasDiastolic;
  }

  void _setRiskFlag(String flag, bool selected) {
    setState(() {
      if (selected) {
        _riskFlags.add(flag);
      } else {
        _riskFlags.remove(flag);
      }
    });
  }

  Future<void> _loadProviderOptions() async {
    setState(() {
      _isLoadingProviders = true;
    });
    final Result<List<OpdProviderOption>> result = await ref
        .read(opdRepositoryProvider)
        .listProviders();
    if (!mounted) {
      return;
    }

    result.when(
      success: (List<OpdProviderOption> providers) {
        setState(() {
          _providerOptions = dedupeOpdProviderOptions(providers);
          _isLoadingProviders = false;
        });
      },
      failure: (_) {
        setState(() {
          _isLoadingProviders = false;
        });
      },
    );
  }

  String _triageNotesPayload(AppLocalizations l10n) {
    final List<String> lines = <String>[];
    void add(String label, String value) {
      final String normalized = value.trim();
      if (normalized.isNotEmpty) {
        lines.add('$label: $normalized');
      }
    }

    add(l10n.opdSymptomsLabel, _symptomsController.text);
    add(l10n.opdPainSeverityLabel, _painSeverity ?? '');
    add(l10n.opdAllergiesLabel, _allergiesController.text);
    if (_riskFlags.isNotEmpty) {
      lines.add(
        '${l10n.opdRiskFlagsLabel}: ${_riskFlags.map((String flag) => _riskFlagLabel(l10n, flag)).join(', ')}',
      );
    }
    add(l10n.opdTriageNotesLabel, _notesController.text);
    return lines.join('\n');
  }
}

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

class _OpdClinicalServicesPanel extends StatelessWidget {
  const _OpdClinicalServicesPanel({required this.detail});

  final OpdFlowDetail detail;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final List<_OpdClinicalServiceEntry> entries = <_OpdClinicalServiceEntry>[
      for (final OpdRelatedRecord record in detail.diagnoses)
        _OpdClinicalServiceEntry(
          icon: Icons.rule_outlined,
          title: record.title ?? record.id,
          subtitle: record.subtitle,
        ),
      for (final OpdRelatedRecord record in detail.labOrders)
        _OpdClinicalServiceEntry(
          icon: Icons.science_outlined,
          title: record.title ?? record.id,
          subtitle: record.subtitle,
        ),
      for (final OpdRelatedRecord record in detail.radiologyOrders)
        _OpdClinicalServiceEntry(
          icon: Icons.biotech_outlined,
          title: record.title ?? record.id,
          subtitle: record.subtitle,
        ),
      for (final OpdRelatedRecord record in detail.pharmacyOrders)
        _OpdClinicalServiceEntry(
          icon: Icons.medication_outlined,
          title: record.title ?? record.id,
          subtitle: record.subtitle,
        ),
      for (final OpdRelatedRecord record in detail.procedures)
        _OpdClinicalServiceEntry(
          icon: Icons.healing_outlined,
          title: record.title ?? record.id,
          subtitle: record.subtitle,
        ),
    ];

    return AppSectionPanel(
      title: l10n.opdClinicalServicesTitle,
      density: AppContentPanelDensity.compact,
      children: <Widget>[
        if (entries.isEmpty)
          Text(
            l10n.opdClinicalServicesEmpty,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          )
        else
          for (final _OpdClinicalServiceEntry entry in entries)
            Padding(
              padding: EdgeInsets.only(bottom: theme.spacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    entry.icon,
                    size: theme.appTokens.listIconSize,
                    color: colorScheme.primary,
                  ),
                  SizedBox(width: theme.spacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          entry.title,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if ((entry.subtitle ?? '').trim().isNotEmpty)
                          Text(
                            entry.subtitle!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

final class _OpdClinicalServiceEntry {
  const _OpdClinicalServiceEntry({
    required this.icon,
    required this.title,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
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
        value: _apiLabel(flow.triageLevel ?? ''),
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
            label: _apiLabel(flow.triageLevel!),
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
  });

  final String? value;
  final List<OpdProviderOption> providers;
  final List<OpdProviderSchedule> schedules;
  final String labelText;
  final String helperText;
  final String emptyHelperText;
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

List<AppSelectOption<String>> _statusOptions(List<String> values) {
  return <AppSelectOption<String>>[
    for (final String value in values)
      AppSelectOption<String>(value: value, label: _apiLabel(value)),
  ];
}

List<AppTriageOption> _triageLevelFieldOptions() {
  return <AppTriageOption>[
    for (final String value in _triageLevelOptions)
      AppTriageOption(
        value: value,
        label: _apiLabel(value),
        tone: appTriageToneForValue(value),
        icon: appTriageIconForValue(value),
      ),
  ];
}

List<AppTriageOption> _triageRouteFieldOptions() {
  return <AppTriageOption>[
    for (final String value in _triageRouteOptions)
      AppTriageOption(
        value: value,
        label: _apiLabel(value),
        tone: appTriageToneForValue(value),
        icon: appTriageIconForValue(value),
      ),
  ];
}

List<AppTriageRiskFlagOption> _triageRiskFlagFieldOptions(
  AppLocalizations l10n,
) {
  return <AppTriageRiskFlagOption>[
    for (final String value in _triageRiskFlagOptions)
      AppTriageRiskFlagOption(
        value: value,
        label: _riskFlagLabel(l10n, value),
        icon: _riskFlagIcon(value),
      ),
  ];
}

List<AppTriageOption> _routeDecisionOptions(BuildContext context) {
  return <AppTriageOption>[
    AppTriageOption(
      value: _opdNoRouteDecisionValue,
      label: context.l10n.opdNoRouteDecisionLabel,
      tone: AppWorkspaceStatusTone.neutral,
      icon: Icons.remove_circle_outline,
    ),
    ..._triageRouteFieldOptions(),
  ];
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

String _riskFlagLabel(AppLocalizations l10n, String flag) {
  return switch (flag) {
    _riskFlagFall => l10n.opdRiskFlagFall,
    _riskFlagPregnancy => l10n.opdRiskFlagPregnancy,
    _riskFlagInfection => l10n.opdRiskFlagInfection,
    _riskFlagAlteredMentalState => l10n.opdRiskFlagAlteredMentalState,
    _riskFlagBleeding => l10n.opdRiskFlagBleeding,
    _ => _apiLabel(flag),
  };
}

IconData _riskFlagIcon(String flag) {
  return switch (flag) {
    _riskFlagFall => Icons.personal_injury_outlined,
    _riskFlagPregnancy => Icons.pregnant_woman_outlined,
    _riskFlagInfection => Icons.coronavirus_outlined,
    _riskFlagAlteredMentalState => Icons.psychology_alt_outlined,
    _riskFlagBleeding => Icons.bloodtype_outlined,
    _ => Icons.warning_amber_outlined,
  };
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

String _joinDisplay(Iterable<String?> values) {
  return AppDisplay.joinNonEmpty(values, separator: ' | ');
}

String _opdRequiredFieldLabel(AppLocalizations l10n, String label) {
  return l10n.opdFieldRequiredLabel(label);
}

String _opdOptionalFieldLabel(AppLocalizations l10n, String label) {
  return l10n.opdFieldOptionalLabel(label);
}

IconData _flowStageIcon(String value) {
  return switch (value.toUpperCase()) {
    'WAITING_CONSULTATION_PAYMENT' => Icons.payments_outlined,
    'WAITING_VITALS' => Icons.monitor_heart_outlined,
    'WAITING_DOCTOR_ASSIGNMENT' => Icons.assignment_ind_outlined,
    'WAITING_DOCTOR_REVIEW' => Icons.medical_services_outlined,
    'LAB_REQUESTED' => Icons.science_outlined,
    'RADIOLOGY_REQUESTED' => Icons.biotech_outlined,
    'LAB_AND_RADIOLOGY_REQUESTED' => Icons.hub_outlined,
    'PHARMACY_REQUESTED' => Icons.local_pharmacy_outlined,
    'WAITING_DISPOSITION' => Icons.task_alt_outlined,
    'ADMITTED' => Icons.bed_outlined,
    'DISCHARGED' => Icons.logout_outlined,
    _ => Icons.sync_alt_outlined,
  };
}

void _showFailureIfNeeded(BuildContext context, AppFailure? failure) {
  if (failure == null) {
    return;
  }

  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(context.l10n.failureMessage(failure))));
}

final List<AppSelectOption<String>> _painSeverityOptions =
    List<AppSelectOption<String>>.unmodifiable(<AppSelectOption<String>>[
      for (int value = 0; value <= 10; value += 1)
        AppSelectOption<String>(value: '$value', label: value.toString()),
    ]);

const String _opdNoRouteDecisionValue = 'NO_ROUTE_DECISION';
const String _riskFlagFall = 'FALL_RISK';
const String _riskFlagPregnancy = 'PREGNANCY';
const String _riskFlagInfection = 'INFECTION_RISK';
const String _riskFlagAlteredMentalState = 'ALTERED_MENTAL_STATE';
const String _riskFlagBleeding = 'BLEEDING';

const List<String> _triageRiskFlagOptions = <String>[
  _riskFlagFall,
  _riskFlagPregnancy,
  _riskFlagInfection,
  _riskFlagAlteredMentalState,
  _riskFlagBleeding,
];

const List<String> _triageLevelOptions = <String>[
  'LEVEL_1',
  'LEVEL_2',
  'LEVEL_3',
  'LEVEL_4',
  'LEVEL_5',
  'IMMEDIATE',
  'URGENT',
  'LESS_URGENT',
  'NON_URGENT',
];

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

const List<String> _paymentMethods = <String>[
  'CASH',
  'MOBILE_MONEY',
  'BANK_TRANSFER',
  'CREDIT_CARD',
  'INSURANCE',
  'OTHER',
];

const List<String> _triageRouteOptions = <String>[
  'CONSULTATION',
  'EMERGENCY',
  'ADMIT',
  'THEATRE',
  'MINOR_PROCEDURE',
  'LAB',
  'RADIOLOGY',
  'LAB_AND_RADIOLOGY',
  'PHYSIOTHERAPY',
  'OTHER_SERVICE',
  'DISCHARGE',
];

List<String> _opdDispositionOptions({required bool hasPharmacyOrder}) {
  return <String>[
    'DISCHARGE',
    if (hasPharmacyOrder) 'SEND_TO_PHARMACY',
    'ADMIT',
  ];
}
