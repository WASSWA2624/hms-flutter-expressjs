import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/reception/data/reception_follow_up_repository.dart';
import 'package:hosspi_hms/features/reception/domain/entities/reception_entities.dart';
import 'package:hosspi_hms/features/reception/presentation/reception_access.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_follow_up_action_dialog.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_action_context.dart';

Future<bool?> showReceptionFollowUpDetailDialog({
  required BuildContext context,
  required ReceptionFollowUpEntry entry,
}) {
  return showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ReceptionFollowUpDetailDialog(entry: entry),
  );
}

/// Call details for a scheduled follow-up with complete / reschedule actions.
class ReceptionFollowUpDetailDialog extends ConsumerStatefulWidget {
  const ReceptionFollowUpDetailDialog({required this.entry, super.key});

  final ReceptionFollowUpEntry entry;

  @override
  ConsumerState<ReceptionFollowUpDetailDialog> createState() =>
      _ReceptionFollowUpDetailDialogState();
}

class _ReceptionFollowUpDetailDialogState
    extends ConsumerState<ReceptionFollowUpDetailDialog> {
  bool _isBusy = false;
  AppFailure? _failure;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ReceptionFollowUpEntry entry = widget.entry;
    final bool canWrite = receptionFrontDeskWriteRequirement.isAllowed(
      ref.watch(appAccessPolicyProvider),
    );
    final String patientName =
        entry.patientDisplayName?.trim().isNotEmpty == true
        ? entry.patientDisplayName!.trim()
        : l10n.profileUnknownValue;
    final String phone =
        entry.patientPhone?.trim().isNotEmpty == true
        ? entry.patientPhone!.trim()
        : l10n.profileUnknownValue;
    final String email =
        entry.patientEmail?.trim().isNotEmpty == true
        ? entry.patientEmail!.trim()
        : l10n.profileUnknownValue;
    final DateTime localScheduled = entry.scheduledAt.toLocal();

    return AppDialog(
      title: Text(l10n.opdFollowUpsTitle),
      icon: const Icon(AppActionIcons.followUp),
      maxWidth: 640,
      closeEnabled: !_isBusy,
      content: AppFormSection(
        density: AppFormSectionDensity.compact,
        children: <Widget>[
          if (_failure != null)
            AppFormInformationBanner.failure(
              context: context,
              failure: _failure!,
            ),
          OpdWorkflowContextPanel(
            patientName: patientName,
            patientNumber: entry.patientIdentifier,
            currentStep: l10n.opdFollowUpAction,
            currentStepCode: entry.status,
            nextStep: l10n.receptionFollowUpDetailBody,
            showJourneyStepper: false,
            expandedFields: <AppWorkspacePatientContextField>[
              AppWorkspacePatientContextField(
                label: l10n.patientsPhoneLabel,
                value: phone,
                icon: Icons.phone_outlined,
              ),
              AppWorkspacePatientContextField(
                label: l10n.patientsEmailLabel,
                value: email,
                icon: Icons.email_outlined,
              ),
              AppWorkspacePatientContextField(
                label: l10n.opdFollowUpDateLabel,
                value: AppFormatters.shortDate(
                  localScheduled,
                  Localizations.localeOf(context),
                ),
                icon: Icons.event_outlined,
              ),
              AppWorkspacePatientContextField(
                label: l10n.opdFollowUpTimeLabel,
                value: AppFormatters.time(
                  localScheduled,
                  Localizations.localeOf(context),
                ),
                icon: Icons.schedule_outlined,
              ),
              if (entry.notes != null && entry.notes!.trim().isNotEmpty)
                AppWorkspacePatientContextField(
                  label: l10n.opdNotesLabel,
                  value: entry.notes!.trim(),
                  icon: AppActionIcons.edit,
                ),
            ],
          ),
          SizedBox(height: theme.spacing.sm),
          Text(
            l10n.receptionFollowUpDetailBody,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
      actions: <Widget>[
        if (canWrite) ...<Widget>[
          AppButton(
            onPressed: _isBusy ? null : () => _complete(context),
            label: l10n.receptionMarkFollowUpCompletedAction,
            leadingIcon: AppActionIcons.success,
            isLoading: _isBusy,
          ),
          AppButton(
            onPressed: _isBusy ? null : () => _scheduleAnother(context),
            label: l10n.receptionScheduleAnotherFollowUpAction,
            leadingIcon: AppActionIcons.followUp,
            variant: AppButtonVariant.secondary,
          ),
        ],
      ],
    );
  }

  Future<void> _complete(BuildContext context) async {
    setState(() {
      _isBusy = true;
      _failure = null;
    });
    final Result<void> result = await ref
        .read(receptionFollowUpRepositoryProvider)
        .completeFollowUp(widget.entry.id);
    if (!mounted) {
      return;
    }
    final AppFailure? failure = result.when(
      success: (_) => null,
      failure: (AppFailure value) => value,
    );
    if (failure != null) {
      setState(() {
        _failure = failure;
        _isBusy = false;
      });
      return;
    }
    Navigator.of(this.context).pop(true);
  }

  Future<void> _scheduleAnother(BuildContext context) async {
    final bool? scheduled = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ClinicalFollowUpActionDialog(
        title: context.l10n.receptionScheduleAnotherFollowUpAction,
        submitLabel: context.l10n.opdSaveFollowUpAction,
        onSubmit: ({required DateTime scheduledAt, required String notes}) async {
          final Result<void> result = await ref
              .read(receptionFollowUpRepositoryProvider)
              .createFollowUp(<String, Object?>{
                'encounter_id': widget.entry.encounterId,
                'scheduled_at': scheduledAt.toUtc().toIso8601String(),
                'status': 'SCHEDULED',
                'notes': notes,
              });
          return result.when(
            success: (_) => null,
            failure: (AppFailure value) => value,
          );
        },
      ),
    );
    if (!mounted || scheduled != true) {
      return;
    }
    Navigator.of(this.context).pop(true);
  }
}
