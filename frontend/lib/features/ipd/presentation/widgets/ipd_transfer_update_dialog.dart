import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';
import 'package:hosspi_hms/features/ipd/presentation/controllers/ipd_workspace_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';

/// IPD transfer-update surface. Composes the shared
/// [AppTransferUpdateDialog] chrome; mutation stays on the workspace controller.
class TransferUpdateDialog extends ConsumerWidget {
  const TransferUpdateDialog({
    required this.admission,
    required this.beds,
    super.key,
  });

  final IpdAdmissionDetail admission;
  final List<IpdBedOption> beds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;

    return AppTransferUpdateDialog(
      title: l10n.ipdManageTransferAction,
      actionLabel: l10n.ipdTransferActionFieldLabel,
      destinationBedLabel: l10n.ipdDestinationBedFieldLabel,
      destinationBedHint: l10n.ipdSelectBedHint,
      submitLabel: l10n.patientsEditAction,
      requiredMessage: l10n.validationRequired,
      initialAction: appTransferDefaultActionForStatus(
        admission.openTransferRequest?.status,
      ),
      actionOptions: <AppSelectOption<String>>[
        AppSelectOption<String>(
          value: AppTransferUpdateActions.approve,
          label: l10n.ipdTransferApproveAction,
        ),
        AppSelectOption<String>(
          value: AppTransferUpdateActions.start,
          label: l10n.ipdTransferStartAction,
        ),
        AppSelectOption<String>(
          value: AppTransferUpdateActions.complete,
          label: l10n.ipdTransferCompleteAction,
        ),
        AppSelectOption<String>(
          value: AppTransferUpdateActions.cancel,
          label: l10n.ipdTransferCancelAction,
        ),
      ],
      bedOptions: <AppSelectOption<String>>[
        for (final IpdBedOption bed in beds)
          AppSelectOption<String>(
            value: bed.id,
            label: _bedOptionLabel(bed),
          ),
      ],
      onSubmit: ({required String action, String? toBedId}) {
        return ref.read(ipdWorkspaceControllerProvider.notifier).updateTransfer(
          admission: admission.summary,
          action: action,
          transferRequestId: admission.openTransferRequest?.id,
          toBedId: toBedId,
        );
      },
    );
  }
}

String _bedOptionLabel(IpdBedOption bed) {
  final String title = bed.displayTitle.trim();
  final String? subtitle = bed.displaySubtitle?.trim();
  if (subtitle == null || subtitle.isEmpty) {
    return title.isEmpty ? bed.id : title;
  }
  if (title.isEmpty) {
    return subtitle;
  }
  return '$title | $subtitle';
}
