import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    final String? patientId = _firstNonEmpty(<String?>[
      flow.patientIdentifier,
      flow.patientId,
    ]);
    final String encounterId = flow.apiId;
    final bool hasAssignedProvider = _isNonEmpty(flow.providerUserId) ||
        _isNonEmpty(flow.providerDisplayName) ||
        _isNonEmpty(flow.assignedStaffDisplayName);

    return AppSectionPanel(
      title: showTitle ? l10n.opdEncounterContextTitle : null,
      density: AppContentPanelDensity.compact,
      children: <Widget>[
        Wrap(
          spacing: Theme.of(context).spacing.sm,
          runSpacing: Theme.of(context).spacing.sm,
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
              label: l10n.opdStageLabel,
              value: opdStatusDisplayLabel(l10n, flow),
              icon: Icons.flag_outlined,
            ),
            AppInfoTileData(
              label: l10n.opdNextStepColumnLabel,
              value: opdNextStepDisplayLabel(
                l10n,
                flow.displayNextStep ?? flow.nextStep,
              ),
              icon: Icons.next_plan_outlined,
            ),
            AppInfoTileData(
              label: l10n.settingsWorkspaceModuleRole,
              value: opdResponsibleRoleForStage(
                l10n,
                flow.displayCode ?? flow.stage,
                hasAssignedProvider: hasAssignedProvider,
              ),
              icon: Icons.badge_outlined,
            ),
            AppInfoTileData(
              label: l10n.opdPaymentStatusLabel,
              value: opdFlowBillingDisplay(context, flow).label,
              icon: Icons.payments_outlined,
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
          ],
        ),
      ],
    );
  }
}

String opdResponsibleRoleForStage(
  AppLocalizations l10n,
  String? stage, {
  bool hasAssignedProvider = false,
}) {
  return switch ((stage ?? '').trim().toUpperCase()) {
    'PAYMENT_DUE' ||
    'WAITING_CONSULTATION_PAYMENT' => l10n.navigationBillingLabel,
    'VITALS_NEEDED' || 'WAITING_VITALS' => l10n.navigationNursingLabel,
    'DOCTOR_NEEDED' || 'WAITING_DOCTOR_ASSIGNMENT' => hasAssignedProvider
        ? l10n.opdWorkflowDoctorTitle
        : l10n.opdWorkflowReceptionTitle,
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
    'PHARMACY_PENDING' ||
    'PHARMACY_REQUESTED' => l10n.navigationPharmacyLabel,
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

String _apiLabel(String? value) {
  final String label = AppDisplay.apiLabel(value ?? '');
  return label.isEmpty ? '' : label;
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

bool _isNonEmpty(String? value) => value?.trim().isNotEmpty ?? false;

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
