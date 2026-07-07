import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/utils/app_display.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';
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
    final List<String> journeySteps = buildOpdVisitJourneySteps(
      l10n: l10n,
      flow: flow,
      detail: detail,
    );

    return AppSectionPanel(
      title: showTitle ? l10n.opdEncounterContextTitle : null,
      density: AppContentPanelDensity.compact,
      children: <Widget>[
        OpdEncounterSummaryRow(pairs: pairs),
        if (journeySteps.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: theme.spacing.sm),
            child: _OpdVisitJourneyTrail(
              label: l10n.opdVisitJourneyLabel,
              steps: journeySteps,
              currentStageCode: flow.displayCode ?? flow.stage,
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

class _OpdVisitJourneyTrail extends StatelessWidget {
  const _OpdVisitJourneyTrail({
    required this.label,
    required this.steps,
    required this.currentStageCode,
  });

  final String label;
  final List<String> steps;
  final String? currentStageCode;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppWorkspaceStatusTone currentTone = opdStageStatusTone(
      currentStageCode,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: theme.spacing.xs),
        Wrap(
          spacing: theme.spacing.xs,
          runSpacing: theme.spacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            for (int index = 0; index < steps.length; index++) ...<Widget>[
              if (index > 0)
                Icon(
                  Icons.arrow_forward,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              _OpdJourneyStepChip(
                label: steps[index],
                tone: index == steps.length - 1
                    ? currentTone
                    : AppWorkspaceStatusTone.neutral,
                emphasized: index == steps.length - 1,
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _OpdJourneyStepChip extends StatelessWidget {
  const _OpdJourneyStepChip({
    required this.label,
    required this.tone,
    required this.emphasized,
  });

  final String label;
  final AppWorkspaceStatusTone tone;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppStatusColors statusColors = theme.statusColors;
    final _JourneyChipColors colors = _journeyChipColors(
      theme,
      statusColors,
      tone,
      emphasized: emphasized,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(theme.radius.sm),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.sm,
          vertical: theme.spacing.xs,
        ),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colors.foreground,
            fontWeight: emphasized ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

@immutable
final class _JourneyChipColors {
  const _JourneyChipColors({
    required this.background,
    required this.foreground,
    required this.border,
  });

  final Color background;
  final Color foreground;
  final Color border;
}

_JourneyChipColors _journeyChipColors(
  ThemeData theme,
  AppStatusColors statusColors,
  AppWorkspaceStatusTone tone, {
  required bool emphasized,
}) {
  if (!emphasized) {
    return _JourneyChipColors(
      background: theme.colorScheme.surfaceContainerHighest,
      foreground: theme.colorScheme.onSurfaceVariant,
      border: theme.colorScheme.outlineVariant,
    );
  }

  return switch (tone) {
    AppWorkspaceStatusTone.success => _JourneyChipColors(
      background: statusColors.successContainer,
      foreground: statusColors.onSuccessContainer,
      border: statusColors.success,
    ),
    AppWorkspaceStatusTone.warning => _JourneyChipColors(
      background: statusColors.warningContainer,
      foreground: statusColors.onWarningContainer,
      border: statusColors.warning,
    ),
    AppWorkspaceStatusTone.error => _JourneyChipColors(
      background: statusColors.errorContainer,
      foreground: statusColors.onErrorContainer,
      border: statusColors.error,
    ),
    AppWorkspaceStatusTone.info => _JourneyChipColors(
      background: statusColors.infoContainer,
      foreground: statusColors.onInfoContainer,
      border: statusColors.info,
    ),
    AppWorkspaceStatusTone.neutral => _JourneyChipColors(
      background: theme.colorScheme.surfaceContainerHighest,
      foreground: theme.colorScheme.onSurfaceVariant,
      border: theme.colorScheme.outlineVariant,
    ),
  };
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
