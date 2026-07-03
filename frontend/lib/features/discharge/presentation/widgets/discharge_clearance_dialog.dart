import 'package:flutter/material.dart';
import 'package:hosspi_hms/features/discharge/domain/entities/discharge_entities.dart';
import 'package:hosspi_hms/features/discharge/presentation/widgets/discharge_planning_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';

/// Discharge workspace entry point — delegates to [DischargePlanningDialog].
class DischargeClearanceDialog extends StatelessWidget {
  const DischargeClearanceDialog({required this.detail, super.key});

  final DischargeAdmissionDetail detail;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return DischargePlanningDialog(
      admissionId: detail.summary.apiId,
      title: Text(l10n.dischargeManageClearanceTitle),
      initialDetail: detail,
    );
  }
}
