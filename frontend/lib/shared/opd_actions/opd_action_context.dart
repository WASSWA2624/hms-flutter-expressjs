import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/utils/app_display.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_billing_state.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_status_display.dart';

class OpdActionContextPanel extends StatelessWidget {
  const OpdActionContextPanel({
    required this.flow,
    this.detail,
    this.showTitle = true,
    super.key,
  });

  final OpdFlowSummary flow;
  final OpdFlowDetail? detail;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final List<OpdEncounterSummaryPair> pairs = buildOpdEncounterSummaryPairs(
      l10n: l10n,
      flow: flow,
      detail: detail,
      billing: opdFlowBillingDisplay(context, flow),
    );
    final String journey = buildOpdVisitJourneyLabel(
      l10n: l10n,
      flow: flow,
      detail: detail,
    );

    return AppSectionPanel(
      title: showTitle ? l10n.opdEncounterContextTitle : null,
      density: AppContentPanelDensity.compact,
      children: <Widget>[
        OpdEncounterSummaryRow(pairs: pairs),
        if (journey.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: theme.spacing.xs),
            child: Text(
              '${l10n.opdVisitJourneyLabel}: $journey',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }
}

@immutable
final class OpdEncounterSummaryPair {
  const OpdEncounterSummaryPair({
    required this.label,
    required this.value,
    this.copyable = false,
  });

  final String label;
  final String value;
  final bool copyable;
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
  final String stageLabel = opdStatusDisplayLabel(l10n, flow);
  final String nextStepLabel = opdNextStepDisplayLabel(
    l10n,
    flow.displayNextStep ?? flow.nextStep,
  );
  final String assignedLabel =
      _firstNonEmpty(<String?>[
        flow.assignedStaffLabel,
        flow.assignedStaffDisplayName,
        flow.providerDisplayName,
      ]) ??
      l10n.profileUnknownValue;
  final OpdBillingDisplay billingDisplay = billing;
  final String arrivalLabel = opdArrivalModeDisplayLabel(
    l10n,
    flow.arrivalMode,
  );

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
    ),
    if (nextStepLabel.isNotEmpty)
      OpdEncounterSummaryPair(
        label: l10n.opdNextStepColumnLabel,
        value: nextStepLabel,
      ),
    OpdEncounterSummaryPair(
      label: l10n.opdProviderColumnLabel,
      value: assignedLabel,
    ),
    OpdEncounterSummaryPair(
      label: l10n.opdPaymentStatusLabel,
      value:
          AppDisplay.joinNonEmpty(<String?>[
            billingDisplay.statusLabel,
            billingDisplay.amountLabel,
          ], separator: ' \u00b7 ').isEmpty
          ? l10n.profileUnknownValue
          : AppDisplay.joinNonEmpty(<String?>[
              billingDisplay.statusLabel,
              billingDisplay.amountLabel,
            ], separator: ' \u00b7 '),
    ),
  ];

  if (_isNonEmpty(flow.triageLevel)) {
    pairs.insert(
      pairs.length - 1,
      OpdEncounterSummaryPair(
        label: l10n.opdTriageLevelLabel,
        value: triageLevelDisplayLabel(l10n, flow.triageLevel),
      ),
    );
  }

  return pairs;
}

String buildOpdVisitJourneyLabel({
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

  return steps.join(' \u2192 ');
}

class OpdEncounterSummaryRow extends StatelessWidget {
  const OpdEncounterSummaryRow({required this.pairs, super.key});

  final List<OpdEncounterSummaryPair> pairs;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle labelStyle = theme.textTheme.bodySmall!.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    final TextStyle valueStyle = theme.textTheme.bodySmall!;

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: theme.spacing.xs,
      runSpacing: theme.spacing.xs,
      children: <Widget>[
        for (int index = 0; index < pairs.length; index++) ...<Widget>[
          if (index > 0) Text(';', style: labelStyle),
          _OpdEncounterSummaryPairChip(
            pair: pairs[index],
            labelStyle: labelStyle,
            valueStyle: valueStyle,
          ),
        ],
      ],
    );
  }
}

class _OpdEncounterSummaryPairChip extends StatelessWidget {
  const _OpdEncounterSummaryPairChip({
    required this.pair,
    required this.labelStyle,
    required this.valueStyle,
  });

  final OpdEncounterSummaryPair pair;
  final TextStyle labelStyle;
  final TextStyle valueStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text('${pair.label}: ', style: labelStyle),
        if (pair.copyable)
          AppCopyableIdentifier(
            value: pair.value,
            textStyle: valueStyle.copyWith(fontWeight: FontWeight.w700),
            copiedMessage: pair.label == context.l10n.opdPatientIdLabel
                ? context.l10n.clinicalPatientIdCopiedMessage
                : context.l10n.opdEncounterIdCopiedMessage,
          )
        else
          Text(pair.value, style: valueStyle),
      ],
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
