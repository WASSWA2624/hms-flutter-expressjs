import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/discharge/data/repositories/discharge_repository_impl.dart';
import 'package:hosspi_hms/features/discharge/domain/entities/discharge_entities.dart';
import 'package:hosspi_hms/features/discharge/presentation/discharge_access.dart';
import 'package:hosspi_hms/features/discharge/presentation/widgets/discharge_planning_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_disposition_actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';

/// Opens the shared system-validated discharge planning dialog.
Future<bool?> showDischargePlanningDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String admissionId,
  Widget? title,
  DischargeAdmissionDetail? initialDetail,
  AccessRequirement createRequirement =
      DischargeAllPatientsAtomPermissions.create,
  AccessRequirement updateRequirement =
      DischargeAllPatientsAtomPermissions.update,
  void Function(AppFailure failure)? onFailure,
}) async {
  final String normalizedAdmissionId = admissionId.trim();
  if (normalizedAdmissionId.isEmpty) {
    return null;
  }

  DischargeAdmissionDetail? detail = initialDetail;
  if (detail == null) {
    final Result<DischargeAdmissionDetail> result = await ref
        .read(dischargeRepositoryProvider)
        .getAdmissionDetail(normalizedAdmissionId);
    final AppFailure? failure = result.when(
      success: (_) => null,
      failure: (AppFailure value) => value,
    );
    if (failure != null) {
      onFailure?.call(failure);
      return null;
    }
    detail = result.when(
      success: (DischargeAdmissionDetail value) => value,
      failure: (_) => null,
    );
  }

  if (detail == null || !context.mounted) {
    return null;
  }

  // Prefer the root navigator's context so an intermediate route commit
  // (shell retention) cannot leave us holding a deactivated page element.
  final NavigatorState? navigator = Navigator.maybeOf(
    context,
    rootNavigator: true,
  );
  if (navigator == null || !navigator.mounted) {
    return null;
  }

  final AppLocalizations l10n = context.l10n;
  final Widget resolvedTitle =
      title ??
      Text(
        clinicalDispositionActionLabel(
          l10n,
          sourceQueue: 'IPD',
          status: detail.summary.admissionStatus,
          stage: detail.summary.stage,
          location: detail.summary.location,
          hasAdmission: true,
        ),
      );

  return showAppDialog<bool>(
    context: navigator.context,
    builder: (_) => DischargePlanningDialog(
      admissionId: normalizedAdmissionId,
      title: resolvedTitle,
      initialDetail: detail,
      createRequirement: createRequirement,
      updateRequirement: updateRequirement,
    ),
  );
}
