import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/presentation/controllers/opd_workspace_controller.dart';
import 'package:hosspi_hms/features/patients/data/repositories/patient_repository_impl.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_follow_up_action_dialog.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_action_context.dart';

/// Opens [FollowUpDialog] with mutating-dialog dismiss rules.
///
/// Returns `true` only after a persisted success from
/// [OpdWorkspaceController.createFollowUp]. When [offerSkip] is true, Cancel
/// is labeled Skip for optional post-disposition prompts.
Future<bool?> showFollowUpDialog({
  required BuildContext context,
  required OpdFlowSummary flow,
  bool offerSkip = false,
}) {
  return showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => FollowUpDialog(flow: flow, offerSkip: offerSkip),
  );
}

/// OPD follow-up scheduling dialog — reuses [ClinicalFollowUpActionDialog].
///
/// Creates a follow-up via `POST /api/v1/follow-ups` with public
/// `encounter_id`, UTC `scheduled_at`, `status`, and optional `notes`.
/// When the patient has no phone on file, requires contact capture before save.
class FollowUpDialog extends ConsumerStatefulWidget {
  const FollowUpDialog({
    required this.flow,
    this.offerSkip = false,
    super.key,
  });

  final OpdFlowSummary flow;
  final bool offerSkip;

  @override
  ConsumerState<FollowUpDialog> createState() => _FollowUpDialogState();
}

class _FollowUpDialogState extends ConsumerState<FollowUpDialog> {
  late final TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(
      text: widget.flow.patientPhone?.trim() ?? '',
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final OpdFlowSummary currentFlow = _followUpCurrentFlow(ref, widget.flow);
    final OpdFlowDetail? currentDetail = _followUpCurrentDetail(
      ref,
      widget.flow,
    );
    final bool needsContact = (currentFlow.patientPhone ?? '').trim().isEmpty;

    return ClinicalFollowUpActionDialog(
      title: l10n.opdFollowUpAction,
      submitLabel: l10n.opdSaveFollowUpAction,
      cancelLabel: widget.offerSkip ? l10n.receptionFollowUpSkipAction : null,
      leadingContent: <Widget>[
        OpdActionContextPanel(
          flow: currentFlow,
          detail: currentDetail,
          showTitle: false,
        ),
        if (needsContact)
          AppTextField(
            controller: _phoneController,
            labelText: l10n.opdFieldRequiredLabel(
              l10n.receptionFollowUpContactRequiredLabel,
            ),
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            prefixIcon: const Icon(Icons.phone_outlined),
            isRequired: true,
            validator: AppValidators.requiredText(l10n.validationRequired),
          ),
      ],
      onSubmit: ({required DateTime scheduledAt, required String notes}) {
        return _submit(
          currentFlow: currentFlow,
          scheduledAt: scheduledAt,
          notes: notes,
          needsContact: needsContact,
        );
      },
    );
  }

  Future<AppFailure?> _submit({
    required OpdFlowSummary currentFlow,
    required DateTime scheduledAt,
    required String notes,
    required bool needsContact,
  }) async {
    if (needsContact) {
      final String phone = _phoneController.text.trim();
      if (phone.isEmpty) {
        return AppFailure.validation(
          validationFields: const <String>{'primary_phone'},
        );
      }
      final String? patientId = currentFlow.patientId?.trim();
      if (patientId == null || patientId.isEmpty) {
        return AppFailure.validation(
          validationFields: const <String>{'patient_id'},
        );
      }
      final Result<Patient> updateResult = await ref
          .read(patientRepositoryProvider)
          .updatePatient(patientId, <String, Object?>{'primary_phone': phone});
      final AppFailure? updateFailure = updateResult.when(
        success: (_) => null,
        failure: (AppFailure failure) => failure,
      );
      if (updateFailure != null) {
        return updateFailure;
      }
    }

    return ref
        .read(opdWorkspaceControllerProvider.notifier)
        .createFollowUp(
          flow: currentFlow,
          scheduledAt: scheduledAt,
          notes: notes,
        );
  }
}

OpdFlowSummary _followUpCurrentFlow(WidgetRef ref, OpdFlowSummary flow) {
  final OpdWorkspaceState? workspaceState = _workspaceState(ref);
  final OpdFlowDetail? selected = workspaceState?.selectedFlow;
  if (selected != null && _isSameFlow(selected.summary, flow)) {
    return selected.summary;
  }
  return flow;
}

OpdFlowDetail? _followUpCurrentDetail(WidgetRef ref, OpdFlowSummary flow) {
  final OpdWorkspaceState? workspaceState = _workspaceState(ref);
  final OpdFlowDetail? selected = workspaceState?.selectedFlow;
  if (selected != null && _isSameFlow(selected.summary, flow)) {
    return selected;
  }
  return null;
}

OpdWorkspaceState? _workspaceState(WidgetRef ref) {
  final Result<OpdWorkspaceState>? workspaceResult = ref
      .watch(opdWorkspaceControllerProvider)
      .asData
      ?.value;
  return workspaceResult?.when(
    success: (OpdWorkspaceState state) => state,
    failure: (_) => null,
  );
}

bool _isSameFlow(OpdFlowSummary left, OpdFlowSummary right) {
  return left.id == right.id ||
      (left.publicId != null && left.publicId == right.publicId);
}
