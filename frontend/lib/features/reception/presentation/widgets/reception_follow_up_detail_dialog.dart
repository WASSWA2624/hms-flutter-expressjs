import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
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
import 'package:hosspi_hms/shared/opd_actions/opd_status_display.dart';

Future<bool?> showReceptionFollowUpDetailDialog({
  required BuildContext context,
  required ReceptionFollowUpEntry entry,
  AccessRequirement writeRequirement =
      ReceptionFollowUpsAtomPermissions.write,
}) {
  return showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ReceptionFollowUpDetailDialog(
      entry: entry,
      writeRequirement: writeRequirement,
    ),
  );
}

/// Call details for a scheduled follow-up with complete / reschedule actions.
class ReceptionFollowUpDetailDialog extends ConsumerStatefulWidget {
  const ReceptionFollowUpDetailDialog({
    required this.entry,
    this.writeRequirement = ReceptionFollowUpsAtomPermissions.write,
    super.key,
  });

  final ReceptionFollowUpEntry entry;
  final AccessRequirement writeRequirement;

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
    final Locale locale = Localizations.localeOf(context);
    final ReceptionFollowUpEntry entry = widget.entry;
    final bool canWrite = widget.writeRequirement.isAllowed(
      ref.watch(appAccessPolicyProvider),
    );
    final String patientName =
        entry.patientDisplayName?.trim().isNotEmpty == true
        ? entry.patientDisplayName!.trim()
        : l10n.profileUnknownValue;
    final String patientNumber = entry.patientIdentifier.trim().isNotEmpty
        ? entry.patientIdentifier.trim()
        : l10n.profileUnknownValue;
    final String phone =
        _nonEmpty(entry.patientPhone) ?? l10n.profileUnknownValue;
    final String email =
        _nonEmpty(entry.patientEmail) ?? l10n.profileUnknownValue;
    final String? notes = _nonEmpty(entry.notes);
    final DateTime localScheduled = entry.scheduledAt.toLocal();
    final String scheduledDate = AppFormatters.shortDate(localScheduled, locale);
    final String scheduledTime = AppFormatters.time(localScheduled, locale);
    final String unknown = l10n.profileUnknownValue;

    return AppDialog(
      title: Text(l10n.opdFollowUpsTitle),
      icon: const Icon(AppActionIcons.followUp),
      maxWidth: 720,
      scrollable: true,
      pinActionsToBottom: true,
      closeEnabled: !_isBusy,
      content: AppFormSection(
        density: AppFormSectionDensity.compact,
        children: <Widget>[
          if (_failure != null)
            AppFormInformationBanner.failure(
              context: context,
              failure: _failure!,
            ),
          AppPatientDetails(
            patientName: patientName,
            patientNumber: patientNumber,
            patientNumberLabel: l10n.opdPatientIdLabel,
            phoneLabel: phone,
            emailLabel: email,
            status: AppWorkspaceStatus(
              label: l10n.opdFollowUpAction,
              tone: opdStageStatusTone(entry.status),
            ),
            showAvatar: false,
            persistExpandPreference: false,
            initiallyExpanded: false,
            semanticLabel: patientName,
          ),
          AppFormSection(
            title: l10n.clinicalFollowUpDetailsTitle,
            density: AppFormSectionDensity.compact,
            children: <Widget>[
              AppPatientContextFactsRow(
                fields: <AppWorkspacePatientContextField>[
                  AppWorkspacePatientContextField(
                    label: l10n.opdFollowUpDateLabel,
                    value: scheduledDate.trim().isEmpty
                        ? unknown
                        : scheduledDate,
                    icon: Icons.event_outlined,
                  ),
                  AppWorkspacePatientContextField(
                    label: l10n.opdFollowUpTimeLabel,
                    value: scheduledTime.trim().isEmpty
                        ? unknown
                        : scheduledTime,
                    icon: Icons.schedule_outlined,
                  ),
                  AppWorkspacePatientContextField(
                    label: l10n.opdNotesLabel,
                    value: notes ?? unknown,
                    icon: AppActionIcons.edit,
                  ),
                ],
              ),
            ],
          ),
          AppFormInformationBanner.message(
            title: l10n.receptionFollowUpNextStepTitle,
            message: l10n.receptionFollowUpDetailBody,
            icon: Icons.phone_callback_outlined,
          ),
        ],
      ),
      actions: <Widget>[
        if (canWrite) ...<Widget>[
          AppButton.secondary(
            onPressed: _isBusy ? null : () => _reschedule(context),
            label: l10n.receptionScheduleAnotherFollowUpAction,
            leadingIcon: Icons.event_repeat_outlined,
          ),
          AppButton.primary(
            onPressed: _isBusy ? null : () => _complete(context),
            label: l10n.receptionMarkFollowUpCompletedAction,
            leadingIcon: AppActionIcons.success,
            isLoading: _isBusy,
          ),
        ] else
          AppButton.secondary(
            label: l10n.commonCloseActionLabel,
            leadingIcon: AppActionIcons.cancel,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
      ],
    );
  }

  Future<void> _complete(BuildContext context) async {
    if (!widget.writeRequirement.isAllowed(ref.read(appAccessPolicyProvider))) {
      return;
    }
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

  Future<void> _reschedule(BuildContext context) async {
    if (!widget.writeRequirement.isAllowed(ref.read(appAccessPolicyProvider))) {
      return;
    }
    final bool? scheduled = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ClinicalFollowUpActionDialog(
        title: context.l10n.receptionScheduleAnotherFollowUpAction,
        submitLabel: context.l10n.opdSaveFollowUpAction,
        initialScheduledAt: widget.entry.scheduledAt.toLocal(),
        onSubmit:
            ({required DateTime scheduledAt, required String notes}) async {
              // One scheduled follow-up per patient: update the open row.
              final Result<void> result = await ref
                  .read(receptionFollowUpRepositoryProvider)
                  .updateFollowUp(widget.entry.id, <String, Object?>{
                    'scheduled_at': scheduledAt.toUtc().toIso8601String(),
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

  static String? _nonEmpty(String? value) {
    final String trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}
