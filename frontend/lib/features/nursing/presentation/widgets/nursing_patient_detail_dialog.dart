import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/clinical/domain/entities/clinical_entities.dart';
import 'package:hosspi_hms/features/nursing/domain/entities/nursing_entities.dart';
import 'package:hosspi_hms/features/nursing/presentation/controllers/nursing_workspace_controller.dart';
import 'package:hosspi_hms/features/nursing/presentation/nursing_access.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_discharge_clearance_dialog.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_escalation_dialog.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_handover_dialog.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_helpers.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_medication_dialog.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_next_action.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_note_dialog.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_print_summary_dialog.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_transfer_dialog.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_vitals_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

class NursingPatientDetailDialog extends ConsumerWidget {
  const NursingPatientDetailDialog({this.omitNextActionKind, super.key});

  final NursingNextActionKind? omitNextActionKind;

  /// Shared complementary write gate (source ∪). Prefer tab
  /// `*AtomPermissions.write` / stage atoms at call sites when scoped.
  static const AccessRequirement writeRequirement =
      NursingAllAtomPermissions.write;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<Result<NursingWorkspaceState>> state = ref.watch(
      nursingWorkspaceControllerProvider,
    );
    final NursingPatientDetail? detail = nursingSelectedDetailFromState(state);
    final NursingPatientSummary? summary = detail?.enrichedSummary;

    return AppPatientDetailDialog(
      title: summary?.displayTitle ?? l10n.nursingPatientContextLabel,
      icon: const Icon(Icons.bed_outlined),
      semanticLabel: l10n.nursingPatientContextLabel,
      closeLabel: l10n.commonCloseActionLabel,
      content: detail == null
          ? AppWorkspaceStatePanel.state(
              variant: AppStateViewVariant.empty,
              title: l10n.nursingNoSelectionTitle,
              body: l10n.nursingNoSelectionBody,
              icon: Icons.bed_outlined,
            )
          : _NursingPatientDetailContent(
              detail: detail,
              omitNextActionKind: omitNextActionKind,
            ),
    );
  }
}

class _NursingPatientDetailContent extends ConsumerWidget {
  const _NursingPatientDetailContent({
    required this.detail,
    this.omitNextActionKind,
  });

  final NursingPatientDetail detail;
  final NursingNextActionKind? omitNextActionKind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final NursingPatientSummary summary = detail.enrichedSummary;
    final ThemeData theme = Theme.of(context);
    final AppAccessPolicy policy = ref.watch(appAccessPolicyProvider);
    final bool canWrite = canWriteNursing(policy);
    // Meds panel / due chip — ∩ pharmacy:read (MedicationDueAtomPermissions).
    final bool canReadMeds =
        NursingMedicationDueAtomPermissions.medicationsPanel.isAllowed(policy);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppPatientDetails(
          patientName: summary.displayTitle,
          patientNumber: summary.patientDisplayId ?? '',
          ageLabel: detail.patientDateOfBirth == null
              ? null
              : AppFormatters.mediumDate(
                  detail.patientDateOfBirth!,
                  Localizations.localeOf(context),
                ),
          genderLabel: detail.patientGender == null
              ? null
              : nursingApiLabel(detail.patientGender!),
          showAvatar: false,
          status: nursingSummaryStatus(summary),
          semanticLabel: l10n.nursingPatientContextLabel,
          alerts: <AppWorkspaceStatus>[
            if (summary.isUrgent)
              AppWorkspaceStatus(
                label: l10n.nursingUrgentSummaryLabel,
                tone: AppWorkspaceStatusTone.error,
              ),
            if (canReadMeds && summary.hasMedicationDue)
              AppWorkspaceStatus(
                label: l10n.nursingMedicationDueSummaryLabel,
                tone: AppWorkspaceStatusTone.warning,
              ),
            if (summary.hasPendingTransfer)
              AppWorkspaceStatus(
                label: l10n.nursingTransferPendingSummaryLabel,
                tone: AppWorkspaceStatusTone.warning,
              ),
          ],
          expandedFields: <AppWorkspacePatientContextField>[
            AppWorkspacePatientContextField(
              label: l10n.nursingAdmissionLabel,
              value: summary.displayId ?? '',
              icon: Icons.tag_outlined,
              copyable: true,
              copyTooltip: l10n.copyAdmissionIdAction,
              copiedMessage: l10n.admissionIdCopiedMessage,
            ),
            AppWorkspacePatientContextField(
              label: l10n.nursingEncounterLabel,
              value: summary.encounterDisplayId ?? '',
              icon: Icons.medical_information_outlined,
              copyable: true,
              copyTooltip: l10n.opdCopyEncounterIdAction,
              copiedMessage: l10n.opdEncounterIdCopiedMessage,
            ),
            AppWorkspacePatientContextField(
              label: l10n.nursingLocationLabel,
              value: summary.locationLabel ?? '',
              icon: Icons.location_on_outlined,
            ),
            AppWorkspacePatientContextField(
              label: l10n.nursingFacilityLabel,
              value: detail.facilityName ?? '',
              icon: Icons.business_outlined,
            ),
            AppWorkspacePatientContextField(
              label: l10n.nursingIcuLabel,
              value: summary.icuStatus == null
                  ? ''
                  : nursingApiLabel(summary.icuStatus!),
              icon: Icons.monitor_heart_outlined,
              tone: summary.hasCriticalAlert
                  ? AppWorkspaceStatusTone.error
                  : AppWorkspaceStatusTone.neutral,
            ),
            AppWorkspacePatientContextField(
              label: l10n.nursingBedLabel,
              value: summary.bedDisplayLabel ?? '',
              icon: Icons.bed_outlined,
            ),
          ],
        ),
        SizedBox(height: theme.spacing.md),
        _NursingActionBar(
          detail: detail,
          omitNextActionKind: omitNextActionKind,
        ),
        SizedBox(height: theme.spacing.md),
        _NursingAdmissionChecklistPanel(detail: detail, canWrite: canWrite),
        if (canViewNursingBillingClearance(policy)) ...<Widget>[
          SizedBox(height: theme.spacing.md),
          _NursingBillingClearancePanel(detail: detail),
        ],
        SizedBox(height: theme.spacing.md),
        _NursingRecordPanel(
          title: l10n.nursingObservationsTitle,
          records: nursingVitalRecords(
            context,
            detail,
            onEdit: canWrite
                ? (NursingVitalSign vital) =>
                      _openVitalsDialog(context, vital: vital)
                : null,
          ),
          emptyLabel: l10n.nursingNoRecordsLabel,
        ),
        if (canReadMeds) ...<Widget>[
          SizedBox(height: theme.spacing.md),
          _NursingRecordPanel(
            title: l10n.nursingMedicationsTitle,
            records: nursingMedicationRecords(context, detail),
            emptyLabel: l10n.nursingNoRecordsLabel,
          ),
        ],
        SizedBox(height: theme.spacing.md),
        _NursingRecordPanel(
          title: l10n.nursingNotesTitle,
          records: nursingNoteRecords(context, detail),
          emptyLabel: l10n.nursingNoRecordsLabel,
        ),
        SizedBox(height: theme.spacing.md),
        _NursingRecordPanel(
          title: l10n.nursingCarePlansTitle,
          records: nursingCarePlanRecords(context, detail),
          emptyLabel: l10n.nursingNoRecordsLabel,
        ),
        SizedBox(height: theme.spacing.md),
        _NursingHandoverPanel(detail: detail),
        SizedBox(height: theme.spacing.md),
        AppCollapsibleSection(
          title: l10n.nursingWardActivityTitle,
          child: AppWardActivityList(
            items: nursingActivityEntries(context, detail),
            emptyLabel: l10n.nursingNoRecordsLabel,
          ),
        ),
      ],
    );
  }
}

class _NursingActionBar extends ConsumerWidget {
  const _NursingActionBar({required this.detail, this.omitNextActionKind});

  final NursingPatientDetail detail;
  final NursingNextActionKind? omitNextActionKind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final NursingWorkspaceController controller = ref.read(
      nursingWorkspaceControllerProvider.notifier,
    );

    final NursingPatientSummary summary = detail.enrichedSummary;
    final bool icuActive =
        (summary.icuStatus ?? '').trim().toUpperCase() == 'ACTIVE';
    final NursingNextActionKind? omit = omitNextActionKind;
    const AccessRequirement writeRequirement =
        NursingPatientDetailDialog.writeRequirement;

    return AppQuickActions(
      title: l10n.nursingActionsTitle,
      presentation: AppQuickActionsPresentation.detailPanel,
      permissionActions: <AppPermissionActionItem>[
        AppPermissionActionItem(
          requirement: nursingBillingClearanceReadRequirement,
          label: l10n.dischargeOpenBillingAction,
          icon: Icons.receipt_long_outlined,
          onPressed: () => _openBillingWorkspace(context, summary),
        ),
        if (omit != NursingNextActionKind.handover)
          AppPermissionActionItem(
            requirement: NursingHandoverPendingAtomPermissions.createHandover,
            label: l10n.nursingActionCreateHandover,
            icon: Icons.swap_horiz_outlined,
            onPressed: () => _openHandoverDialog(context),
          ),
        if (omit != NursingNextActionKind.vitals)
          AppPermissionActionItem(
            requirement: writeRequirement,
            label: l10n.nursingActionRecordVitals,
            icon: Icons.monitor_heart_outlined,
            onPressed: () => _openVitalsDialog(context),
          ),
        AppPermissionActionItem(
          requirement: writeRequirement,
          label: l10n.nursingActionAddNote,
          icon: Icons.note_add_outlined,
          onPressed: () => _openNoteDialog(context),
        ),
        AppPermissionActionItem(
          requirement: writeRequirement,
          label: l10n.nursingActionOrderLab,
          icon: Icons.science_outlined,
          onPressed: () => _openLabOrderDialog(context, controller),
        ),
        AppPermissionActionItem(
          requirement: writeRequirement,
          label: l10n.nursingActionOrderRadiology,
          icon: Icons.biotech_outlined,
          onPressed: () => _openRadiologyOrderDialog(context, controller),
        ),
        if (omit != NursingNextActionKind.medication)
          AppPermissionActionItem(
            requirement:
                NursingMedicationDueAtomPermissions.administerMedication,
            label: l10n.nursingActionAdministerMedication,
            icon: Icons.medication_outlined,
            onPressed: () => _openMedicationDialog(context, detail),
          ),
        AppPermissionActionItem(
          requirement: writeRequirement,
          label: l10n.clinicalPrescribeAction,
          icon: Icons.medication_outlined,
          onPressed: () => _openPrescriptionDialog(context, controller),
        ),
        if (omit != NursingNextActionKind.escalate)
          AppPermissionActionItem(
            requirement: NursingUrgentAtomPermissions.escalate,
            label: l10n.nursingActionEscalate,
            icon: Icons.report_problem_outlined,
            onPressed: () => _openEscalationDialog(context),
          ),
        if (detail.activeTransfer != null &&
            omit != NursingNextActionKind.transfer)
          AppPermissionActionItem(
            requirement:
                NursingTransferPendingAtomPermissions.acknowledgeTransfer,
            label: l10n.nursingActionAcknowledgeTransfer,
            icon: Icons.transfer_within_a_station_outlined,
            onPressed: () => _openTransferDialog(context, detail),
          ),
        if (summary.isDischargePending &&
            omit != NursingNextActionKind.discharge)
          AppPermissionActionItem(
            requirement: NursingDischargePendingAtomPermissions.write,
            label: l10n.nursingActionDischargeClearance,
            icon: Icons.fact_check_outlined,
            onPressed: () => _openDischargeClearanceDialog(context, detail),
          ),
        if (icuActive)
          AppPermissionActionItem(
            requirement: NursingHandoverPendingAtomPermissions.openIcu,
            label: l10n.nursingActionOpenIcu,
            icon: Icons.monitor_heart_outlined,
            onPressed: () => _openIcuWorkspace(context, summary),
          ),
        AppPermissionActionItem(
          requirement: NursingAllAtomPermissions.printSummary,
          label: l10n.nursingActionPrintSummary,
          icon: Icons.print_outlined,
          onPressed: () => _openPrintSummaryDialog(context, detail),
        ),
        for (final NursingHandover handover in detail.handovers)
          if (handover.isPending)
            AppPermissionActionItem(
              requirement: NursingHandoverPendingAtomPermissions.acceptHandover,
              label: l10n.nursingActionAcceptHandover,
              icon: Icons.done_all_outlined,
              onPressed: () =>
                  _openAcceptHandoverDialog(context, controller, handover),
            ),
      ],
    );
  }
}

class _NursingRecordPanel extends StatelessWidget {
  const _NursingRecordPanel({
    required this.title,
    required this.records,
    required this.emptyLabel,
  });

  final String title;
  final List<AppNursingRecordEntry> records;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    return AppCollapsibleSection(
      title: title,
      child: AppNursingRecordList(items: records, emptyLabel: emptyLabel),
    );
  }
}

class _NursingHandoverPanel extends StatelessWidget {
  const _NursingHandoverPanel({required this.detail});

  final NursingPatientDetail detail;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppCollapsibleSection(
      title: l10n.nursingHandoversTitle,
      child: AppNursingRecordList(
        items: nursingHandoverRecords(context, detail),
        emptyLabel: l10n.nursingNoRecordsLabel,
      ),
    );
  }
}

class _NursingBillingClearancePanel extends StatelessWidget {
  const _NursingBillingClearancePanel({required this.detail});

  final NursingPatientDetail detail;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final NursingPatientSummary summary = detail.enrichedSummary;
    final NursingDischargeSummary? discharge = detail.latestDischarge;
    final bool billingCleared = discharge?.billingCleared == true;
    final bool nursingCleared = discharge?.nursingCleared == true;
    final String ledgerLabel = billingCleared
        ? l10n.billingClearanceCleared
        : l10n.patientsOutstandingBalanceFilterLabel;
    final String statusLabel = discharge?.status?.trim().isNotEmpty == true
        ? nursingApiLabel(discharge!.status!)
        : (summary.dischargeStatus == null ||
              summary.dischargeStatus!.trim().isEmpty)
        ? l10n.profileUnknownValue
        : nursingApiLabel(summary.dischargeStatus!);
    final String body = discharge?.summary?.trim().isNotEmpty == true
        ? discharge!.summary!.trim()
        : l10n.nursingChecklistDischargePendingBody;

    return AppCollapsibleSection(
      title: l10n.dischargeBillingSectionTitle,
      child: AppNursingRecordList(
        items: <AppNursingRecordEntry>[
          AppNursingRecordEntry(
            title: ledgerLabel,
            subtitle: nursingDateTimeLabel(context, discharge?.dischargedAt),
            body: body,
            icon: Icons.receipt_long_outlined,
            status: AppWorkspaceStatus(
              label: ledgerLabel,
              tone: billingCleared
                  ? AppWorkspaceStatusTone.success
                  : AppWorkspaceStatusTone.warning,
            ),
          ),
          AppNursingRecordEntry(
            title: statusLabel,
            subtitle: nursingCleared
                ? l10n.billingClearanceCleared
                : l10n.nursingActionDischargeClearance,
            body: l10n.nursingChecklistDischargePendingBody,
            icon: Icons.fact_check_outlined,
            status: AppWorkspaceStatus(
              label: statusLabel,
              tone: nursingStatusTone(
                discharge?.status ?? summary.dischargeStatus,
              ),
            ),
          ),
        ],
        emptyLabel: l10n.nursingNoRecordsLabel,
      ),
    );
  }
}

class _NursingAdmissionChecklistPanel extends StatelessWidget {
  const _NursingAdmissionChecklistPanel({
    required this.detail,
    this.canWrite = true,
  });

  final NursingPatientDetail detail;
  final bool canWrite;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppCollapsibleSection(
      title: l10n.nursingWardAdmissionChecklistTitle,
      description: l10n.nursingWardAdmissionChecklistDescription,
      child: AppCareTaskChecklist(
        items: nursingAdmissionChecklistItems(
          context,
          detail,
          onOpenHandover: canWrite ? () => _openHandoverDialog(context) : null,
          onConfirmIdentity: canWrite ? () => _confirmIdentity(context) : null,
          onOpenVitals: canWrite ? () => _openVitalsDialog(context) : null,
          onOpenAllergies: canWrite
              ? () => _openAllergiesDialog(context)
              : null,
          onOpenBelongings: canWrite
              ? () => _openBelongingsDialog(context)
              : null,
          onOpenCarePlan: canWrite ? () => _openCarePlanDialog(context) : null,
          onNotifyDoctor: canWrite
              ? () => _openNotifyDoctorDialog(context)
              : null,
          onOpenDischargeClearance: canWrite
              ? () => _openDischargeClearanceDialog(context, detail)
              : null,
        ),
        emptyLabel: l10n.nursingNoRecordsLabel,
      ),
    );
  }
}

Future<void> _openVitalsDialog(
  BuildContext context, {
  NursingVitalSign? vital,
}) async {
  await nursingShowActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => NursingVitalsDialog(vital: vital),
    ),
  );
}

Future<void> _openNoteDialog(BuildContext context) async {
  await nursingShowActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const NursingNoteDialog(),
    ),
  );
}

Future<void> _openMedicationDialog(
  BuildContext context,
  NursingPatientDetail detail,
) async {
  await nursingShowActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => NursingMedicationDialog(detail: detail),
    ),
  );
}

Future<void> _openPrescriptionDialog(
  BuildContext context,
  NursingWorkspaceController controller,
) async {
  final ClinicalReferenceData referenceData = await controller
      .prescriptionReferenceData();
  if (!context.mounted) {
    return;
  }
  await nursingShowActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ClinicalPrescriptionActionDialog(
        referenceData: referenceData,
        onSubmit: controller.prescribeMedication,
      ),
    ),
  );
}

Future<void> _openHandoverDialog(BuildContext context) async {
  await nursingShowActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const NursingHandoverDialog(),
    ),
  );
}

Future<void> _openEscalationDialog(BuildContext context) async {
  await nursingShowActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const NursingEscalationDialog(),
    ),
  );
}

Future<void> _openTransferDialog(
  BuildContext context,
  NursingPatientDetail detail,
) async {
  await nursingShowActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => NursingTransferDialog(detail: detail),
    ),
  );
}

Future<void> _openPrintSummaryDialog(
  BuildContext context,
  NursingPatientDetail detail,
) async {
  await nursingShowActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => NursingPrintSummaryDialog(detail: detail),
    ),
  );
}

Future<void> _openAcceptHandoverDialog(
  BuildContext context,
  NursingWorkspaceController controller,
  NursingHandover handover,
) async {
  await nursingShowActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ClinicalFreeTextActionDialog(
        title: context.l10n.nursingActionAcceptHandover,
        label: context.l10n.nursingHandoverNotesLabel,
        submitLabel: context.l10n.nursingActionAcceptHandover,
        icon: const Icon(Icons.note_add_outlined),
        onSubmit: (String note) => controller.acceptHandover(handover, note),
      ),
    ),
  );
}

Future<void> _openLabOrderDialog(
  BuildContext context,
  NursingWorkspaceController controller,
) async {
  final ClinicalReferenceData referenceData = await controller
      .prescriptionReferenceData();
  if (!context.mounted) {
    return;
  }
  final NursingPatientSummary? summary =
      ProviderScope.containerOf(context, listen: false)
          .read(nursingWorkspaceControllerProvider)
          .value
          ?.when(
            success: (NursingWorkspaceState state) =>
                state.selectedDetail?.summary,
            failure: (_) => null,
          );
  await nursingShowActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ClinicalLabOrderActionDialog(
        referenceData: referenceData,
        patientContext: ClinicalRequestPatientContext(
          patientName: summary?.patientDisplayName ?? summary?.displayTitle,
          patientId: summary?.patientDisplayId ?? summary?.patientId,
          encounterId: summary?.encounterDisplayId,
        ),
        onSearchLabTests:
            ({
              required String termType,
              String? query,
              int? limit,
              String source = 'ALL',
            }) {
              return controller.searchClinicalTerms(
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
              ClinicalRequestBillingSubmit? billing,
            }) {
              return controller.orderLab(
                labTestIds: labTestIds,
                labPanelIds: labPanelIds,
                billing: billing,
              );
            },
        onUpdate:
            ({
              required String labOrderId,
              required List<String> labTestIds,
              required List<String> labPanelIds,
              ClinicalRequestBillingSubmit? billing,
            }) {
              return controller.orderLab(
                labTestIds: labTestIds,
                labPanelIds: labPanelIds,
                billing: billing,
              );
            },
      ),
    ),
  );
}

Future<void> _openRadiologyOrderDialog(
  BuildContext context,
  NursingWorkspaceController controller,
) async {
  final ClinicalReferenceData referenceData = await controller
      .prescriptionReferenceData();
  if (!context.mounted) {
    return;
  }
  final NursingPatientSummary? summary =
      ProviderScope.containerOf(context, listen: false)
          .read(nursingWorkspaceControllerProvider)
          .value
          ?.when(
            success: (NursingWorkspaceState state) =>
                state.selectedDetail?.summary,
            failure: (_) => null,
          );
  await nursingShowActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ClinicalRadiologyOrderActionDialog(
        referenceData: referenceData,
        patientContext: ClinicalRequestPatientContext(
          patientName: summary?.patientDisplayName ?? summary?.displayTitle,
          patientId: summary?.patientDisplayId ?? summary?.patientId,
          encounterId: summary?.encounterDisplayId,
        ),
        onSearchRadiologyTests:
            ({
              required String termType,
              String? query,
              int? limit,
              String source = 'ALL',
            }) {
              return controller.searchClinicalTerms(
                termType: termType,
                query: query,
                limit: limit ?? 80,
                source: source,
              );
            },
        onSubmit: controller.orderRadiology,
      ),
    ),
  );
}

Future<void> _openDischargeClearanceDialog(
  BuildContext context,
  NursingPatientDetail detail,
) async {
  await nursingShowActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => NursingDischargeClearanceDialog(detail: detail),
    ),
  );
}

Future<void> _openAllergiesDialog(BuildContext context) async {
  await nursingShowActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ClinicalFreeTextActionDialog(
        title: context.l10n.nursingActionRecordAllergies,
        label: context.l10n.nursingAllergiesLabel,
        submitLabel: context.l10n.nursingActionRecordAllergies,
        icon: const Icon(Icons.health_and_safety_outlined),
        onSubmit: (String note) {
          return ProviderScope.containerOf(context, listen: false)
              .read(nursingWorkspaceControllerProvider.notifier)
              .recordAllergies(note);
        },
      ),
    ),
  );
}

Future<void> _openBelongingsDialog(BuildContext context) async {
  await nursingShowActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ClinicalFreeTextActionDialog(
        title: context.l10n.nursingActionRecordBelongings,
        label: context.l10n.nursingBelongingsLabel,
        submitLabel: context.l10n.nursingActionRecordBelongings,
        icon: const Icon(Icons.work_outline),
        onSubmit: (String note) {
          return ProviderScope.containerOf(context, listen: false)
              .read(nursingWorkspaceControllerProvider.notifier)
              .recordBelongings(note);
        },
      ),
    ),
  );
}

Future<void> _openNotifyDoctorDialog(BuildContext context) async {
  await nursingShowActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ClinicalFreeTextActionDialog(
        title: context.l10n.nursingActionNotifyDoctor,
        label: context.l10n.nursingNotifyDoctorLabel,
        submitLabel: context.l10n.nursingActionNotifyDoctor,
        icon: const Icon(Icons.contact_phone_outlined),
        onSubmit: (String note) {
          return ProviderScope.containerOf(context, listen: false)
              .read(nursingWorkspaceControllerProvider.notifier)
              .notifyDoctor(note);
        },
      ),
    ),
  );
}

Future<void> _confirmIdentity(BuildContext context) async {
  final NursingWorkspaceController controller = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(nursingWorkspaceControllerProvider.notifier);
  final AppFailure? failure = await controller.confirmIdentity();
  if (!context.mounted) {
    return;
  }
  if (failure != null) {
    nursingShowFailureIfNeeded(context, failure);
    return;
  }
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(context.l10n.nursingSavedMessage)));
}

Future<void> _openCarePlanDialog(BuildContext context) async {
  await nursingShowActionResult(
    context,
    showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ClinicalFreeTextActionDialog(
        title: context.l10n.nursingChecklistCarePlanTitle,
        label: context.l10n.nursingCarePlanLabel,
        submitLabel: context.l10n.nursingChecklistCarePlanTitle,
        icon: const Icon(Icons.playlist_add_check_outlined),
        onSubmit: (String plan) {
          return ProviderScope.containerOf(
            context,
            listen: false,
          ).read(nursingWorkspaceControllerProvider.notifier).addCarePlan(plan);
        },
      ),
    ),
  );
}

void _openBillingWorkspace(
  BuildContext context,
  NursingPatientSummary summary,
) {
  final String? patientId = summary.patientId?.trim();
  final String location = (patientId == null || patientId.isEmpty)
      ? AppRoutes.billing.path
      : AppRoutes.billing.location(
          queryParameters: <String, String>{'patient_id': patientId},
        );
  if (Navigator.of(context).canPop()) {
    Navigator.of(context).pop();
  }
  if (context.mounted) {
    context.go(location);
  }
}

void _openIcuWorkspace(BuildContext context, NursingPatientSummary summary) {
  final String? displayId = summary.displayId?.trim();
  final String location = displayId == null || displayId.isEmpty
      ? AppRoutes.icu.path
      : '${AppRoutes.icu.path}?id=$displayId';
  context.go(location);
}
