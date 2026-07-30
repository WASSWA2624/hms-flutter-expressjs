import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/presentation/controllers/hr_workspace_controller.dart';
import 'package:hosspi_hms/features/hr/presentation/hr_access.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_enhanced_dialogs.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

Future<void> showHrStaffOffboardingDialog(
  BuildContext context,
  WidgetRef ref,
  HrStaffDetail detail, {
  VoidCallback? onOpenPayroll,
}) async {
  if (!HrHumanResourcesAtomPermissions.offboard.isAllowed(
    ref.read(appAccessPolicyProvider),
  )) {
    return;
  }

  final AppLocalizations l10n = context.l10n;
  final HrWorkspaceController controller = ref.read(
    hrWorkspaceControllerProvider.notifier,
  );
  final GlobalKey<_HrOffboardingFormState> formKey =
      GlobalKey<_HrOffboardingFormState>();

  final bool? saved = await showAppWorkspaceMutationDialog(
    context: context,
    title: Text(l10n.hrOffboardStaffDialogTitle),
    icon: const Icon(Icons.person_off_outlined),
    submitLabel: l10n.hrOffboardStaffAction,
    cancelLabel: l10n.commonCancelActionLabel,
    submitIcon: Icons.check_outlined,
    maxWidth: 560,
    buildFields:
        (
          BuildContext context,
          GlobalKey<FormState> _,
          bool _, [
          AppFailure? failure,
        ]) {
          return _HrOffboardingForm(
            key: formKey,
            profile: detail.profile,
            onOpenPayroll: onOpenPayroll,
          );
        },
    onSubmit: () => controller.offboardStaff(
      formKey.currentState?.toPayload() ?? <String, Object?>{},
    ),
  );
  if (saved == true && context.mounted) {
    showHrMutationSnackBar(context, null);
    // Staff payroll draft path only — never patient Billing collect/issue.
    if (formKey.currentState?.scheduleFinalPayroll == true &&
        onOpenPayroll != null) {
      onOpenPayroll!();
    }
  }
}

class _HrOffboardingForm extends StatefulWidget {
  const _HrOffboardingForm({
    required this.profile,
    this.onOpenPayroll,
    super.key,
  });

  final HrStaffProfile profile;
  final VoidCallback? onOpenPayroll;

  @override
  State<_HrOffboardingForm> createState() => _HrOffboardingFormState();
}

class _HrOffboardingFormState extends State<_HrOffboardingForm> {
  String _separationType = 'RESIGNATION';
  DateTime? _lastWorkingDay = DateTime.now();
  final TextEditingController _notesController = TextEditingController();
  bool _endAssignments = true;
  bool _revokeAccess = true;
  bool _finalPayroll = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  /// Whether the operator requested a final staff payroll draft (NOT patient Billing).
  bool get scheduleFinalPayroll => _finalPayroll;

  Map<String, Object?> toPayload() {
    return <String, Object?>{
      'separation_type': _separationType,
      'last_working_day': _lastWorkingDay?.toIso8601String(),
      'reason': _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      'end_assignments': _endAssignments,
      'revoke_access': _revokeAccess,
      'schedule_final_payroll': _finalPayroll,
    };
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return AppFormSection(
      children: <Widget>[
        AppSelectField<String>(
          value: _separationType,
          labelText: l10n.hrSeparationTypeLabel,
          options: <AppSelectOption<String>>[
            AppSelectOption<String>(
              value: 'RESIGNATION',
              label: l10n.hrSeparationTypeResignationLabel,
            ),
            AppSelectOption<String>(
              value: 'TERMINATION',
              label: l10n.hrSeparationTypeTerminationLabel,
            ),
            AppSelectOption<String>(
              value: 'RETIREMENT',
              label: l10n.hrSeparationTypeRetirementLabel,
            ),
            AppSelectOption<String>(
              value: 'CONTRACT_END',
              label: l10n.hrSeparationTypeContractEndLabel,
            ),
            AppSelectOption<String>(
              value: 'DECEASED',
              label: l10n.hrSeparationTypeDeceasedLabel,
            ),
          ],
          onChanged: (String? value) {
            if (value != null) {
              setState(() => _separationType = value);
            }
          },
        ),
        AppDateField(
          value: _lastWorkingDay,
          labelText: l10n.hrLastWorkingDayLabel,
          isRequired: true,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
          currentDate: DateTime.now(),
          pickerButtonLabel: l10n.hrPickDateAction,
          invalidDateMessage: l10n.appDateInvalidMessage,
          onChanged: (DateTime? value) =>
              setState(() => _lastWorkingDay = value),
        ),
        AppTextField(
          controller: _notesController,
          labelText: l10n.hrSeparationNotesLabel,
          maxLines: 3,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.hrOffboardEndAssignmentsLabel),
          value: _endAssignments,
          onChanged: (bool value) => setState(() => _endAssignments = value),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.hrOffboardRevokeAccessLabel),
          value: _revokeAccess,
          onChanged: (bool value) => setState(() => _revokeAccess = value),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.hrOffboardFinalPayrollLabel),
          subtitle: _finalPayroll && widget.onOpenPayroll != null
              ? TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onOpenPayroll!();
                  },
                  child: Text(l10n.hrRunPayrollAction),
                )
              : null,
          value: _finalPayroll,
          onChanged: (bool value) => setState(() => _finalPayroll = value),
        ),
        SizedBox(height: theme.spacing.xs),
        Text(
          l10n.hrOffboardStaffDialogHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
