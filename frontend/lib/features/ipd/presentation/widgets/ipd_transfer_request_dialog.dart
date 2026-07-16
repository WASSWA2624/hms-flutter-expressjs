import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';
import 'package:hosspi_hms/features/ipd/presentation/controllers/ipd_workspace_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';

/// IPD transfer-request surface. Composes the shared
/// [AppTransferRequestDialog] chrome; mutation stays on the workspace controller.
class TransferRequestDialog extends ConsumerWidget {
  const TransferRequestDialog({
    required this.admission,
    required this.wards,
    super.key,
  });

  final IpdAdmissionDetail admission;
  final List<IpdWardOption> wards;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final String? fromWardId = admission.activeBedAssignment?.bed?.wardId;
    final List<IpdWardOption> destinationWards = _destinationWards(
      wards,
      fromWardId,
    );

    return AppTransferRequestDialog(
      title: l10n.ipdRequestTransferAction,
      wardLabel: l10n.ipdTargetWardFieldLabel,
      wardHint: l10n.ipdSelectWardHint,
      submitLabel: l10n.ipdRequestTransferAction,
      requiredMessage: l10n.validationRequired,
      wardOptions: <AppSelectOption<String>>[
        for (final IpdWardOption ward in destinationWards)
          AppSelectOption<String>(
            value: ward.id,
            label: _wardOptionLabel(ward),
          ),
      ],
      onSubmit: (String toWardId) {
        return ref.read(ipdWorkspaceControllerProvider.notifier).requestTransfer(
          admission: admission.summary,
          fromWardId: fromWardId,
          toWardId: toWardId,
        );
      },
    );
  }
}

List<IpdWardOption> _destinationWards(
  List<IpdWardOption> wards,
  String? currentWardId,
) {
  if (currentWardId == null || currentWardId.isEmpty) {
    return wards;
  }
  return wards
      .where((IpdWardOption ward) => ward.id != currentWardId)
      .toList(growable: false);
}

String _wardOptionLabel(IpdWardOption ward) {
  final String? wardType = ward.wardType?.trim();
  if (wardType == null || wardType.isEmpty) {
    return ward.displayTitle;
  }
  return <String>[ward.displayTitle, _apiLabel(wardType)].join(' | ');
}

String _apiLabel(String value) {
  final String normalized = value.trim();
  if (normalized.isEmpty) {
    return '';
  }
  return normalized
      .split('_')
      .where((String part) => part.isNotEmpty)
      .map((String part) {
        final String lower = part.toLowerCase();
        return lower.substring(0, 1).toUpperCase() + lower.substring(1);
      })
      .join(' ');
}
