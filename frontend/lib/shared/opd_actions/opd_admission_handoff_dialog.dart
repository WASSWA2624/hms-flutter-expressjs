import 'package:flutter/material.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_action_context.dart';

/// Opens [_OpdAdmissionHandoffDialog] after an `ADMIT` disposition succeeds.
///
/// Navigation-only confirmation: admission persistence already succeeded in the
/// parent disposition mutation. Pops `true` to open inpatient care, `false` on
/// Cancel. Does not call APIs or patch Riverpod.
Future<bool?> showOpdAdmissionHandoffDialog({
  required BuildContext context,
  required OpdFlowSummary flow,
}) {
  return showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _OpdAdmissionHandoffDialog(flow: flow),
  );
}

/// Confirmation shown after an `ADMIT` disposition, offering to jump to the
/// inpatient (IPD) workspace where bed allocation and admission continue.
///
/// Navigation-only: admission persistence already succeeded in the disposition
/// mutation; Cancel aborts without routing and does not patch providers.
class _OpdAdmissionHandoffDialog extends StatelessWidget {
  const _OpdAdmissionHandoffDialog({required this.flow});

  final OpdFlowSummary flow;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppConfirmActionDialog(
      title: l10n.opdAdmissionHandoffTitle,
      body: l10n.opdAdmissionHandoffBody,
      submitLabel: l10n.opdOpenAdmissionAction,
      icon: const Icon(AppActionIcons.bed),
      submitLeadingIcon: AppActionIcons.bed,
      maxWidth: 560,
      sectionDensity: AppFormSectionDensity.compact,
      scrollable: true,
      pinActionsToBottom: true,
      leadingContent: <Widget>[
        OpdActionContextPanel(flow: flow, showTitle: false),
      ],
    );
  }
}
