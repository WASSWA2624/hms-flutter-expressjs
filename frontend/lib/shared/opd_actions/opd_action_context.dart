import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/utils/app_display.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/app_content_panel.dart';
import 'package:hosspi_hms/shared/components/app_copyable_identifier.dart';
import 'package:hosspi_hms/shared/components/app_info_tile.dart';
import 'package:hosspi_hms/shared/components/app_patient_details.dart';
import 'package:hosspi_hms/shared/components/app_workflow_stepper.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_billing_state.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_status_display.dart';

/// Shared patient identity and completed/current/next workflow context used by
/// appointment, queue, and encounter action hubs.
class OpdWorkflowContextPanel extends StatelessWidget {
  const OpdWorkflowContextPanel({
    required this.patientName,
    required this.patientNumber,
    required this.currentStep,
    this.currentStepCode,
    this.currentStepTone,
    this.nextStep,
    this.completedSteps = const <String>[],
    this.expandedFields = const <AppWorkspacePatientContextField>[],
    this.expandedChild,
    this.showTitle = true,
    this.showJourneyStepper = true,
    super.key,
  });

  final String patientName;
  final String patientNumber;
  final String currentStep;
  final String? currentStepCode;
  final AppWorkspaceStatusTone? currentStepTone;
  final String? nextStep;
  final List<String> completedSteps;
  final List<AppWorkspacePatientContextField> expandedFields;
  final Widget? expandedChild;
  final bool showTitle;
  final bool showJourneyStepper;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String normalizedCurrent = currentStep.trim();
    final String normalizedNext = nextStep?.trim() ?? '';
    final List<String> completed = <String>[
      for (final String step in completedSteps)
        if (step.trim().isNotEmpty && step.trim() != normalizedCurrent)
          step.trim(),
    ];
    final List<AppWorkflowStepItem> steps = <AppWorkflowStepItem>[
      for (var index = 0; index < completed.length; index += 1)
        AppWorkflowStepItem(
          id: 'completed-$index',
          label: completed[index],
          state: AppWorkflowStepState.completed,
        ),
      if (normalizedCurrent.isNotEmpty)
        AppWorkflowStepItem(
          id: 'current',
          label: normalizedCurrent,
          description: l10n.receptionCurrentStepLabel,
          state: AppWorkflowStepState.current,
        ),
      if (normalizedNext.isNotEmpty && normalizedNext != normalizedCurrent)
        AppWorkflowStepItem(
          id: 'next',
          label: normalizedNext,
          description: l10n.opdNextActionFilterLabel,
          state: AppWorkflowStepState.upcoming,
        ),
    ];

    return AppSectionPanel(
      key: const ValueKey<String>('opdWorkflowContextPanel'),
      title: showTitle ? l10n.opdEncounterContextTitle : null,
      density: AppContentPanelDensity.compact,
      children: <Widget>[
        AppPatientDetails(
          patientName: patientName,
          patientNumber: patientNumber,
          patientNumberLabel: l10n.opdPatientIdLabel,
          status: normalizedCurrent.isEmpty
              ? null
              : AppWorkspaceStatus(
                  label: normalizedCurrent,
                  tone: currentStepTone ?? opdStageStatusTone(currentStepCode),
                ),
          expandedFields: expandedFields,
          expandedChild: expandedChild,
          showAvatar: false,
          semanticLabel: patientName,
          persistExpandPreference: false,
        ),
        if (showJourneyStepper && steps.isNotEmpty) ...<Widget>[
          SizedBox(height: theme.spacing.md),
          AppWorkflowStepper(
            steps: steps,
            semanticLabel: l10n.opdVisitJourneyLabel,
          ),
        ],
      ],
    );
  }
}

class OpdActionContextPanel extends StatelessWidget {
  const OpdActionContextPanel({
    required this.flow,
    this.detail,
    this.showTitle = true,
    this.showJourneyStepper = true,
    this.showPayment = true,
    super.key,
  });

  final OpdFlowSummary flow;
  final OpdFlowDetail? detail;
  final bool showTitle;
  final bool showJourneyStepper;
  final bool showPayment;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<OpdEncounterSummaryPair> pairs = buildOpdEncounterSummaryPairs(
      l10n: l10n,
      flow: flow,
      detail: detail,
      billing: opdFlowBillingDisplay(context, flow),
    );
    final List<String> journeySteps = showJourneyStepper
        ? buildOpdVisitJourneySteps(l10n: l10n, flow: flow, detail: detail)
        : const <String>[];

    final String currentStep = opdStatusDisplayLabel(l10n, flow);
    final String nextStep = showJourneyStepper
        ? opdNextStepDisplayLabel(l10n, flow.displayNextStep ?? flow.nextStep)
        : '';
    final List<OpdEncounterSummaryPair> expandedPairs = pairs
        .where(
          (OpdEncounterSummaryPair pair) =>
              pair.label != l10n.opdPatientColumnLabel &&
              pair.label != l10n.opdPatientIdLabel &&
              pair.label != l10n.opdCurrentStageLabel &&
              pair.label != l10n.opdNextStepColumnLabel &&
              (showPayment || pair.label != l10n.opdPaymentStatusLabel) &&
              (pair.label != l10n.opdEncounterIdLabel ||
                  (flow.publicId?.trim().isNotEmpty ?? false)),
        )
        .toList(growable: false);

    return OpdWorkflowContextPanel(
      patientName:
          _firstNonEmpty(<String?>[
            flow.patientDisplayName,
            flow.displayTitle,
          ]) ??
          l10n.profileUnknownValue,
      patientNumber: _firstNonEmpty(<String?>[flow.patientIdentifier]) ?? '',
      currentStep: currentStep,
      currentStepCode: flow.displayCode ?? flow.stage,
      nextStep: nextStep,
      completedSteps: journeySteps,
      expandedChild: expandedPairs.isEmpty
          ? null
          : OpdEncounterSummaryRow(pairs: expandedPairs),
      showTitle: showTitle,
      showJourneyStepper: showJourneyStepper,
    );
  }
}

@immutable
final class OpdEncounterSummaryPair {
  const OpdEncounterSummaryPair({
    required this.label,
    required this.value,
    this.copyable = false,
    this.valueTone,
  });

  final String label;
  final String value;
  final bool copyable;
  final AppWorkspaceStatusTone? valueTone;
}

List<OpdEncounterSummaryPair> buildOpdEncounterSummaryPairs({
  required AppLocalizations l10n,
  required OpdFlowSummary flow,
  required OpdBillingDisplay billing,
  OpdFlowDetail? detail,
}) {
  final String patientName =
      _firstNonEmpty(<String?>[flow.patientDisplayName, flow.displayTitle]) ??
      l10n.profileUnknownValue;
  final String? patientId = _firstNonEmpty(<String?>[
    flow.patientIdentifier,
    flow.patientId,
  ]);
  final String encounterId = flow.apiId;
  final String stageCode = (flow.displayCode ?? flow.stage ?? '').trim();
  final String stageLabel = opdStatusDisplayLabel(l10n, flow);
  final String nextStepCode = (flow.displayNextStep ?? flow.nextStep ?? '')
      .trim();
  final String nextStepLabel = opdNextStepDisplayLabel(
    l10n,
    flow.displayNextStep ?? flow.nextStep,
  );
  final String assignedLabel =
      _firstNonEmpty(<String?>[
        _usableAssignedStaffLabel(flow.assignedStaffLabel),
        flow.assignedStaffDisplayName,
        flow.providerDisplayName,
      ]) ??
      l10n.profileUnknownValue;
  final OpdBillingDisplay billingDisplay = billing;
  final String arrivalLabel = opdArrivalModeDisplayLabel(
    l10n,
    flow.arrivalMode,
  );
  final String paymentValue =
      AppDisplay.joinNonEmpty(<String?>[
        billingDisplay.statusLabel,
        billingDisplay.amountLabel,
      ], separator: ' \u00b7 ').isEmpty
      ? l10n.profileUnknownValue
      : AppDisplay.joinNonEmpty(<String?>[
          billingDisplay.statusLabel,
          billingDisplay.amountLabel,
        ], separator: ' \u00b7 ');

  final List<OpdEncounterSummaryPair> pairs = <OpdEncounterSummaryPair>[
    OpdEncounterSummaryPair(
      label: l10n.opdPatientColumnLabel,
      value: patientName,
    ),
    if (patientId != null)
      OpdEncounterSummaryPair(
        label: l10n.opdPatientIdLabel,
        value: patientId,
        copyable: true,
      ),
    OpdEncounterSummaryPair(
      label: l10n.opdEncounterIdLabel,
      value: encounterId,
      copyable: true,
    ),
    if (arrivalLabel.isNotEmpty)
      OpdEncounterSummaryPair(
        label: l10n.opdArrivalModeLabel,
        value: arrivalLabel,
      ),
    OpdEncounterSummaryPair(
      label: l10n.opdCurrentStageLabel,
      value: stageLabel.isEmpty ? l10n.profileUnknownValue : stageLabel,
      valueTone: opdStageStatusTone(stageCode),
    ),
    if (nextStepLabel.isNotEmpty)
      OpdEncounterSummaryPair(
        label: l10n.opdNextStepColumnLabel,
        value: nextStepLabel,
        valueTone: opdNextStepStatusTone(nextStepCode),
      ),
    OpdEncounterSummaryPair(
      label: l10n.opdProviderColumnLabel,
      value: assignedLabel,
    ),
    OpdEncounterSummaryPair(
      label: l10n.opdPaymentStatusLabel,
      value: paymentValue,
      valueTone: billingDisplay.tone,
    ),
  ];

  if (_isNonEmpty(flow.triageLevel)) {
    pairs.insert(
      pairs.length - 1,
      OpdEncounterSummaryPair(
        label: l10n.opdTriageLevelLabel,
        value: triageLevelDisplayLabel(l10n, flow.triageLevel),
        valueTone: triageLevelStatusTone(flow.triageLevel),
      ),
    );
  }

  return pairs;
}

List<String> buildOpdVisitJourneySteps({
  required AppLocalizations l10n,
  required OpdFlowSummary flow,
  OpdFlowDetail? detail,
}) {
  final List<String> steps = <String>[];
  final String arrival = opdArrivalModeDisplayLabel(l10n, flow.arrivalMode);
  if (arrival.isNotEmpty) {
    steps.add(arrival);
  }

  for (final OpdTimelineItem item
      in detail?.timeline ?? const <OpdTimelineItem>[]) {
    final String label = _timelineStepLabel(l10n, item);
    if (label.isNotEmpty && !steps.contains(label)) {
      steps.add(label);
    }
  }

  final String currentStage = opdStatusDisplayLabel(l10n, flow);
  if (currentStage.isNotEmpty &&
      (steps.isEmpty || steps.last != currentStage)) {
    steps.add(currentStage);
  }

  return steps;
}

String buildOpdVisitJourneyLabel({
  required AppLocalizations l10n,
  required OpdFlowSummary flow,
  OpdFlowDetail? detail,
}) {
  return buildOpdVisitJourneySteps(
    l10n: l10n,
    flow: flow,
    detail: detail,
  ).join(' \u2192 ');
}

class OpdEncounterSummaryRow extends StatelessWidget {
  const OpdEncounterSummaryRow({required this.pairs, super.key});

  final List<OpdEncounterSummaryPair> pairs;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int maxColumns = switch (constraints.maxWidth) {
          >= 900 => 3,
          >= 560 => 2,
          _ => 1,
        };

        return AppResponsiveWrap(
          maxColumns: maxColumns,
          minItemWidth: 200,
          children: <Widget>[
            for (final OpdEncounterSummaryPair pair in pairs)
              _OpdEncounterSummaryTile(pair: pair),
          ],
        );
      },
    );
  }
}

class _OpdEncounterSummaryTile extends StatelessWidget {
  const _OpdEncounterSummaryTile({required this.pair});

  final OpdEncounterSummaryPair pair;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;

    return AppContentPanel(
      density: AppContentPanelDensity.compact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            pair.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: theme.spacing.xs),
          if (pair.valueTone != null)
            AppWorkspaceStatusBadge(
              status: AppWorkspaceStatus(
                label: pair.value,
                tone: pair.valueTone!,
              ),
            )
          else if (pair.copyable)
            AppCopyableIdentifier(
              value: pair.value,
              textStyle: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              copiedMessage: pair.label == l10n.opdPatientIdLabel
                  ? l10n.clinicalPatientIdCopiedMessage
                  : l10n.opdEncounterIdCopiedMessage,
            )
          else
            Text(
              pair.value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

String _timelineStepLabel(AppLocalizations l10n, OpdTimelineItem item) {
  final String stageLabel = opdStageDisplayLabel(l10n, item.stage);
  if (stageLabel.isNotEmpty) {
    return stageLabel;
  }
  return AppDisplay.apiLabel(item.action);
}

/// Drops backend/UI placeholder labels so a real provider name can surface.
String? _usableAssignedStaffLabel(String? label) {
  final String normalized = (label ?? '').trim();
  if (normalized.isEmpty) {
    return null;
  }
  switch (normalized.toLowerCase()) {
    case 'assigned staff unknown':
    case 'doctor needed':
    case 'with doctor':
    case 'doctor assigned':
      return null;
    default:
      return normalized;
  }
}

String? _firstNonEmpty(Iterable<String?> values) {
  for (final String? value in values) {
    final String normalized = value?.trim() ?? '';
    if (normalized.isNotEmpty) {
      return normalized;
    }
  }
  return null;
}

bool _isNonEmpty(String? value) {
  return value != null && value.trim().isNotEmpty;
}

String opdResponsibleRoleForStage(AppLocalizations l10n, String? stage) {
  return switch ((stage ?? '').trim().toUpperCase()) {
    'PAYMENT_DUE' || 'WAITING_CONSULTATION_PAYMENT' =>
      '${l10n.opdWorkflowReceptionTitle} / ${l10n.navigationBillingLabel}',
    'VITALS_NEEDED' || 'WAITING_VITALS' => l10n.navigationNursingLabel,
    'DOCTOR_NEEDED' || 'WAITING_DOCTOR_ASSIGNMENT' =>
      '${l10n.opdWorkflowReceptionTitle} / ${l10n.navigationNursingLabel}',
    'WITH_DOCTOR' ||
    'WAITING_DOCTOR_REVIEW' ||
    'DECISION_NEEDED' ||
    'WAITING_DISPOSITION' ||
    'RESULTS_READY' ||
    'REPORT_READY' ||
    'MEDICINES_DISPENSED' => l10n.opdWorkflowDoctorTitle,
    'LAB_PENDING' ||
    'SAMPLE_PENDING' ||
    'IN_LAB' ||
    'LAB_REQUESTED' => l10n.navigationLabLabel,
    'IMAGING_PENDING' ||
    'REPORT_PENDING' ||
    'RADIOLOGY_REQUESTED' => l10n.navigationRadiologyLabel,
    'LAB_AND_RADIOLOGY_REQUESTED' =>
      '${l10n.navigationLabLabel} / ${l10n.navigationRadiologyLabel}',
    'PHARMACY_PENDING' || 'PHARMACY_REQUESTED' => l10n.navigationPharmacyLabel,
    'ADMISSION_PENDING' || 'ADMITTED' => l10n.navigationIpdLabel,
    'DISCHARGED' => l10n.navigationDischargeLabel,
    _ => l10n.profileUnknownValue,
  };
}
