import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/presentation/controllers/opd_workspace_controller.dart';
import 'package:hosspi_hms/features/patients/data/repositories/patient_repository_impl.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/features/patients/presentation/widgets/patient_form_fields.dart';
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
/// Requires phone or email (at least one); persists patient contact when new
/// or changed.
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
  final GlobalKey<State<AppPhoneField>> _phoneFieldKey =
      GlobalKey<State<AppPhoneField>>();
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  String? _initialPhone;
  String? _initialEmail;
  bool _contactHydrating = false;

  @override
  void initState() {
    super.initState();
    _initialPhone = widget.flow.patientPhone?.trim();
    _phoneController = TextEditingController(text: _initialPhone ?? '');
    _emailController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hydrateContactFromPatient();
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _hydrateContactFromPatient() async {
    final String? patientId = widget.flow.patientId?.trim();
    if (patientId == null || patientId.isEmpty || !mounted) {
      return;
    }
    setState(() => _contactHydrating = true);
    final Result<PatientDetail> detailResult = await ref
        .read(patientRepositoryProvider)
        .loadPatientDetail(patientId);
    if (!mounted) {
      return;
    }
    detailResult.when(
      success: (PatientDetail detail) {
        final String phone = detail.patient.primaryPhone?.trim() ?? '';
        final String email = detail.patient.primaryEmail?.trim() ?? '';
        if (phone.isNotEmpty && _phoneController.text.trim().isEmpty) {
          _phoneController.text = phone;
        }
        if (email.isNotEmpty) {
          _emailController.text = email;
        }
        _initialPhone = _phoneController.text.trim();
        _initialEmail = _emailController.text.trim();
      },
      failure: (_) {},
    );
    if (mounted) {
      setState(() => _contactHydrating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final OpdFlowSummary currentFlow = _followUpCurrentFlow(ref, widget.flow);
    final OpdFlowDetail? currentDetail = _followUpCurrentDetail(
      ref,
      widget.flow,
    );

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
        AppFormSection(
          title: l10n.receptionFollowUpContactSectionTitle,
          description: l10n.receptionFollowUpContactEitherHint,
          density: AppFormSectionDensity.compact,
          children: <Widget>[
            PatientPhoneField(
              phoneFieldKey: _phoneFieldKey,
              controller: _phoneController,
              labelText: l10n.patientsPhoneLabel,
              isLoading: _contactHydrating,
              textInputAction: TextInputAction.next,
            ),
            PatientEmailField(
              controller: _emailController,
              labelText: l10n.patientsEmailLabel,
              isLoading: _contactHydrating,
              textInputAction: TextInputAction.next,
            ),
          ],
        ),
      ],
      onSubmit: ({required DateTime scheduledAt, required String notes}) {
        return _submit(
          currentFlow: currentFlow,
          scheduledAt: scheduledAt,
          notes: notes,
        );
      },
    );
  }

  Future<AppFailure?> _submit({
    required OpdFlowSummary currentFlow,
    required DateTime scheduledAt,
    required String notes,
  }) async {
    AppPhoneField.commitPhone(_phoneFieldKey);
    final String phone = _phoneController.text.trim();
    final String email = _emailController.text.trim();
    if (phone.isEmpty && email.isEmpty) {
      return AppFailure.validation(
        validationFields: const <String>{'primary_phone', 'primary_email'},
      );
    }

    final String? patientId = currentFlow.patientId?.trim();
    if (patientId == null || patientId.isEmpty) {
      return AppFailure.validation(
        validationFields: const <String>{'patient_id'},
      );
    }

    final bool phoneChanged = phone != (_initialPhone ?? '').trim();
    final bool emailChanged = email != (_initialEmail ?? '').trim();
    if (phoneChanged || emailChanged) {
      final Map<String, Object?> contactPayload = <String, Object?>{
        if (phoneChanged && phone.isNotEmpty) 'primary_phone': phone,
        if (emailChanged && email.isNotEmpty) 'primary_email': email,
      };
      if (contactPayload.isNotEmpty) {
        final Result<Patient> updateResult = await ref
            .read(patientRepositoryProvider)
            .updatePatient(patientId, contactPayload);
        final AppFailure? updateFailure = updateResult.when(
          success: (_) => null,
          failure: (AppFailure failure) => failure,
        );
        if (updateFailure != null) {
          return updateFailure;
        }
        if (phoneChanged && phone.isNotEmpty) {
          _initialPhone = phone;
        }
        if (emailChanged && email.isNotEmpty) {
          _initialEmail = email;
        }
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
