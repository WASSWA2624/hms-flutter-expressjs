import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/utils/app_display.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

class OpdActionContextPanel extends StatelessWidget {
  const OpdActionContextPanel({
    required this.flow,
    this.showTitle = true,
    super.key,
  });

  final OpdFlowSummary flow;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String? patientId = _firstNonEmpty(<String?>[
      flow.patientIdentifier,
      flow.patientId,
    ]);
    final String encounterId = flow.apiId;

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
              value: _apiLabel(flow.stage),
            ),
            AppInfoTileData(
              label: l10n.opdNextStepColumnLabel,
              value: _apiLabel(flow.nextStep),
            ),
            AppInfoTileData(
              label: l10n.opdPaymentStatusLabel,
              value: opdFlowBillingStatusLabel(l10n, flow),
            ),
            AppInfoTileData(
              label: l10n.opdProviderColumnLabel,
              value: flow.providerDisplayName,
            ),
          ],
        ),
      ],
    );
  }
}

String opdFlowBillingStatusLabel(AppLocalizations l10n, OpdFlowSummary flow) {
  final String state = opdFlowBillingState(flow);
  if (state == _opdBillingStatePaid &&
      (_isTerminalStatus(flow.stage) || _isTerminalStatus(flow.status))) {
    return l10n.opdCompletedFlowSummaryLabel;
  }
  return switch (state) {
    _opdBillingStatePaid => l10n.opdPaymentPaidLabel,
    _opdBillingStateRequired => l10n.opdPaymentRequiredLabel,
    _opdBillingStateNotRequired => l10n.opdPaymentNotRequiredLabel,
    _ => l10n.profileUnknownValue,
  };
}

String opdFlowBillingState(OpdFlowSummary flow) {
  final String stage = (flow.stage ?? '').toUpperCase();
  final String paymentStatus = (flow.consultationPaymentStatus ?? '')
      .trim()
      .toUpperCase();
  final num? paidAmount = flow.consultationPaidAmount;
  final num? fee = flow.consultationFee;
  final bool paymentCoversFee =
      paidAmount != null &&
      paidAmount > 0 &&
      (fee == null || fee <= 0 || paidAmount >= fee);
  if (flow.consultationPaid ||
      paymentStatus == 'PAID' ||
      paymentStatus == 'CLEARED' ||
      (paymentStatus == 'COMPLETED' && paymentCoversFee)) {
    return _opdBillingStatePaid;
  }
  if (flow.consultationPaymentRequired ||
      stage == 'WAITING_CONSULTATION_PAYMENT') {
    return _opdBillingStateRequired;
  }
  return _opdBillingStateNotRequired;
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

bool _isTerminalStatus(String? status) {
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

const String _opdBillingStatePaid = 'PAID';
const String _opdBillingStateRequired = 'REQUIRED';
const String _opdBillingStateNotRequired = 'NOT_REQUIRED';
