import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    final String? patientId = _firstNonEmpty(<String?>[
      flow.patientIdentifier,
      flow.patientId,
    ]);
    final String encounterId = flow.apiId;
    final OpdBillingDisplay billing = opdFlowBillingDisplay(context, flow);
    final String stageLabel = opdStatusDisplayLabel(l10n, flow);
    final String nextStepLabel = opdNextStepDisplayLabel(
      l10n,
      flow.displayNextStep ?? flow.nextStep,
    );

    return AppSectionPanel(
      title: showTitle ? l10n.opdEncounterContextTitle : null,
      density: AppContentPanelDensity.compact,
      children: <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              flow.displayTitle,
              style: theme.textTheme.titleMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (_isNonEmpty(patientId) && patientId != flow.displayTitle)
              Padding(
                padding: EdgeInsets.only(top: theme.spacing.xs),
                child: Text(
                  patientId!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
        Wrap(
          spacing: theme.spacing.sm,
          runSpacing: theme.spacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            AppStatusText(
              label: stageLabel.isEmpty ? l10n.profileUnknownValue : stageLabel,
              tone: opdStageStatusTone(flow.displayCode ?? flow.stage),
            ),
            AppStatusText(label: billing.label, tone: billing.tone),
            if (_isNonEmpty(flow.triageLevel))
              AppStatusText(
                label: _apiLabel(flow.triageLevel),
                tone: appTriageToneForValue(flow.triageLevel),
              ),
            if (nextStepLabel.isNotEmpty)
              AppStatusText(
                label: nextStepLabel,
                tone: AppWorkspaceStatusTone.info,
              ),
          ],
        ),
        Wrap(
          spacing: theme.spacing.sm,
          runSpacing: theme.spacing.sm,
          children: <Widget>[
            if (patientId != null)
              AppButton.secondary(
                label: l10n.opdCopyPatientIdAction,
                leadingIcon: Icons.copy_outlined,
                onPressed: () => _copyTextToClipboard(
                  context,
                  patientId,
                  l10n.clinicalPatientIdCopiedMessage,
                ),
              ),
            AppButton.secondary(
              label: l10n.opdCopyEncounterIdAction,
              leadingIcon: Icons.copy_outlined,
              onPressed: () => _copyTextToClipboard(
                context,
                encounterId,
                l10n.opdEncounterIdCopiedMessage,
              ),
            ),
          ],
        ),
        AppInfoTileGrid(
          minItemWidth: 130,
          borderedTiles: false,
          emptyValue: l10n.profileUnknownValue,
          items: <AppInfoTileData>[
            AppInfoTileData(
              label: l10n.settingsWorkspaceModuleRole,
              value: opdResponsibleRoleForStage(
                l10n,
                flow.displayCode ?? flow.stage,
              ),
              icon: Icons.badge_outlined,
            ),
            AppInfoTileData(
              label: l10n.opdProviderColumnLabel,
              value: flow.assignedStaffLabel ?? flow.providerDisplayName,
              icon: Icons.person_outline,
            ),
            AppInfoTileData(
              label: l10n.opdCompletedFlowSummaryLabel,
              value: _completedActionSummary(detail),
              icon: Icons.check_circle_outline,
            ),
            if (detail != null)
              AppInfoTileData(
                label: l10n.opdServicesSummaryLabel,
                value: _servicesCountLabel(l10n, detail!),
                icon: Icons.medical_information_outlined,
              ),
          ],
        ),
      ],
    );
  }
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

String _completedActionSummary(OpdFlowDetail? detail) {
  final List<String> actions = <String>[];
  for (final OpdTimelineItem item
      in detail?.timeline ?? const <OpdTimelineItem>[]) {
    final String label = _apiLabel(item.action);
    if (label.isNotEmpty && !actions.contains(label)) {
      actions.add(label);
    }
  }
  if (actions.isEmpty) {
    return '';
  }
  return actions.reversed.take(4).join(' • ');
}

String _servicesCountLabel(AppLocalizations l10n, OpdFlowDetail detail) {
  final int serviceCount =
      detail.labOrders.length +
      detail.radiologyOrders.length +
      detail.pharmacyOrders.length +
      detail.procedures.length;
  return AppDisplay.joinNonEmpty(<String?>[
    '${detail.vitalSigns.length} ${l10n.opdVitalsSummaryLabel}',
    if (serviceCount > 0) '$serviceCount ${l10n.opdServicesSummaryLabel}',
    if (detail.clinicalNotes.isNotEmpty)
      '${detail.clinicalNotes.length} ${l10n.opdClinicalNotesSummaryLabel}',
  ], separator: ' • ');
}

String _apiLabel(String? value) {
  final String label = AppDisplay.apiLabel(value ?? '');
  return label.isEmpty ? '' : label;
}

bool _isNonEmpty(String? value) {
  return value != null && value.trim().isNotEmpty;
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

Future<void> _copyTextToClipboard(
  BuildContext context,
  String value,
  String message,
) async {
  await Clipboard.setData(ClipboardData(text: value));
  if (!context.mounted) {
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
