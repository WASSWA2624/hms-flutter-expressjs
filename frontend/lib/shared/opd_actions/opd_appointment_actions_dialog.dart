import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/presentation/controllers/opd_workspace_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_action_context.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_encounter_flow.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_flow_actions_dialog.dart'
    show opdFrontDeskActionRequirement;
import 'package:hosspi_hms/shared/opd_actions/opd_queue_actions_dialog.dart'
    show isOpdQueueTerminalStatus;
import 'package:hosspi_hms/shared/opd_actions/opd_reschedule_appointment_dialog.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_status_display.dart';

export 'opd_reschedule_appointment_dialog.dart';

/// Shared appointment actions for OPD and Reception workspaces.
Future<bool?> showOpdAppointmentActionsDialog({
  required BuildContext context,
  required OpdAppointment appointment,
  OpdWorkspaceState? workspaceState,
  AccessRequirement actionRequirement = opdFrontDeskActionRequirement,
}) {
  return showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => OpdAppointmentActionsDialog(
      appointment: appointment,
      workspaceState: workspaceState,
      actionRequirement: actionRequirement,
    ),
  );
}

bool isOpdAppointmentTerminalStatus(String? status) {
  return switch ((status ?? '').toUpperCase()) {
    'COMPLETED' ||
    'CANCELLED' ||
    'NO_SHOW' ||
    'DISCHARGED' ||
    'ADMITTED' ||
    'CLOSED' => true,
    _ => false,
  };
}

enum _AppointmentFooterAction { queue, checkIn }

class OpdAppointmentActionsDialog extends ConsumerStatefulWidget {
  const OpdAppointmentActionsDialog({
    required this.appointment,
    this.workspaceState,
    this.actionRequirement = opdFrontDeskActionRequirement,
    super.key,
  });

  final OpdAppointment appointment;

  /// When set, check-in opens the encounter dialog; otherwise direct check-in.
  final OpdWorkspaceState? workspaceState;

  /// Front-desk write gate. Reception passes `receptionFrontDeskWriteRequirement`.
  final AccessRequirement actionRequirement;

  @override
  ConsumerState<OpdAppointmentActionsDialog> createState() =>
      _OpdAppointmentActionsDialogState();
}

class _OpdAppointmentActionsDialogState
    extends ConsumerState<OpdAppointmentActionsDialog> {
  _AppointmentFooterAction? _activeAction;
  AppFailure? _failure;

  bool get _isSaving => _activeAction != null;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final Locale locale = Localizations.localeOf(context);
    final String status = (widget.appointment.status ?? '').toUpperCase();
    final bool terminal = isOpdAppointmentTerminalStatus(status);
    final bool alreadyQueued = _hasActiveLinkedQueueEntry();
    final bool canQueue =
        !terminal &&
        status != 'IN_PROGRESS' &&
        !alreadyQueued &&
        widget.appointment.patientId != null &&
        widget.appointment.tenantId != null;
    final bool canCheckIn =
        !terminal && status != 'IN_PROGRESS' && status != 'COMPLETED';
    final bool canReschedule = !terminal;
    final bool canCancelAppointment = !terminal && status != 'CANCELLED';
    final String nextAction = canCheckIn
        ? l10n.opdCheckInAction
        : canQueue
        ? l10n.opdQueueAction
        : canReschedule
        ? l10n.opdRescheduleAction
        : '';

    return AppDialog(
      title: Text(l10n.opdAppointmentActionsTitle),
      icon: const Icon(AppActionIcons.appointment),
      scrollable: true,
      pinActionsToBottom: true,
      closeEnabled: !_isSaving,
      maxWidth: 680,
      content: AppFormSection(
        density: AppFormSectionDensity.compact,
        children: <Widget>[
          if (_failure != null)
            AppFormInformationBanner.failure(
              context: context,
              failure: _failure!,
            ),
          OpdWorkflowContextPanel(
            patientName: widget.appointment.displayTitle,
            patientNumber: widget.appointment.patientIdentifier ?? '',
            currentStep: opdStageDisplayLabel(
              l10n,
              widget.appointment.status ?? '',
            ),
            currentStepCode: widget.appointment.status,
            nextStep: nextAction,
            expandedFields: <AppWorkspacePatientContextField>[
              AppWorkspacePatientContextField(
                label: l10n.opdProviderColumnLabel,
                value:
                    widget.appointment.providerDisplayName ??
                    l10n.profileUnknownValue,
                icon: Icons.medical_services_outlined,
              ),
              AppWorkspacePatientContextField(
                label: l10n.opdTimeColumnLabel,
                value: widget.appointment.scheduledStart == null
                    ? l10n.profileUnknownValue
                    : AppFormatters.dateTime(
                        widget.appointment.scheduledStart!,
                        locale,
                      ),
                icon: Icons.schedule_outlined,
              ),
              AppWorkspacePatientContextField(
                label: l10n.opdReasonLabel,
                value: widget.appointment.reason ?? l10n.profileUnknownValue,
                icon: Icons.notes_outlined,
              ),
            ],
          ),
          if (!terminal)
            AppQuickActions(
              title: l10n.patientsQuickActionsTitle,
              permissionActions: <AppPermissionActionItem>[
                if (canQueue)
                  AppPermissionActionItem(
                    requirement: widget.actionRequirement,
                    label: l10n.opdQueueAction,
                    icon: AppActionIcons.queue,
                    fullWidth: true,
                    isLoading: _activeAction == _AppointmentFooterAction.queue,
                    enabled: !_isSaving,
                    onPressed: () => _run(
                      _AppointmentFooterAction.queue,
                      () => ref
                          .read(opdWorkspaceControllerProvider.notifier)
                          .assignAppointmentToQueue(widget.appointment),
                    ),
                  ),
                if (canReschedule)
                  AppPermissionActionItem(
                    requirement: widget.actionRequirement,
                    label: l10n.opdRescheduleAction,
                    icon: AppActionIcons.reschedule,
                    fullWidth: true,
                    enabled: !_isSaving,
                    onPressed: _openReschedule,
                  ),
                if (canCancelAppointment)
                  AppPermissionActionItem(
                    requirement: widget.actionRequirement,
                    label: l10n.opdCancelAction,
                    icon: AppActionIcons.delete,
                    fullWidth: true,
                    destructive: true,
                    enabled: !_isSaving,
                    onPressed: _openCancel,
                  ),
                if (canCheckIn)
                  AppPermissionActionItem(
                    requirement: widget.actionRequirement,
                    label: l10n.opdCheckInAction,
                    icon: AppActionIcons.start,
                    variant: AppButtonVariant.primary,
                    fullWidth: true,
                    isLoading:
                        _activeAction == _AppointmentFooterAction.checkIn,
                    enabled: !_isSaving,
                    onPressed: _openCheckIn,
                  ),
              ],
            ),
        ],
      ),
      // Cancel-only hub footer; domain mutations open child dialogs or run
      // in-body actions (queue / start encounter) with AppButton.isLoading.
      actions: <Widget>[
        AppButton.secondary(
          label: l10n.commonCancelActionLabel,
          leadingIcon: AppActionIcons.cancel,
          enabled: !_isSaving,
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
        ),
      ],
    );
  }

  Future<void> _openCheckIn() async {
    if (_isSaving) {
      return;
    }
    final OpdWorkspaceState? workspaceState = widget.workspaceState;
    if (workspaceState != null) {
      setState(() {
        _activeAction = _AppointmentFooterAction.checkIn;
        _failure = null;
      });
      final OpdEncounterDialogResult? dialogResult =
          await showOpdEncounterDialog(
            context: context,
            dialog: buildOpdWorkspaceEncounterDialog(
              ref: ref,
              state: workspaceState,
              initialAppointment: widget.appointment,
              initialAppointmentId: widget.appointment.apiId,
              defaultArrivalMode: 'ONLINE_APPOINTMENT',
              defaultProviderId: widget.appointment.providerUserId,
              includeEncounterLifecycleCallbacks: false,
            ),
          );
      if (!mounted) {
        return;
      }
      if (dialogResult == null) {
        setState(() => _activeAction = null);
        return;
      }
      if (dialogResult.action == OpdEncounterDialogAction.submit) {
        // Fallback for sparse backend snapshots that omit the linked
        // appointment identifier. Non-submit outcomes must never advance it.
        ref
            .read(opdWorkspaceControllerProvider.notifier)
            .markAppointmentInProgress(widget.appointment);
      }
      Navigator.of(
        context,
      ).pop(dialogResult.action != OpdEncounterDialogAction.continueWorkflow);
      return;
    }

    await _run(
      _AppointmentFooterAction.checkIn,
      () => ref
          .read(opdWorkspaceControllerProvider.notifier)
          .checkInAppointment(widget.appointment),
    );
  }

  bool _hasActiveLinkedQueueEntry() {
    final OpdWorkspaceState? workspaceState = widget.workspaceState;
    if (workspaceState == null) {
      return false;
    }
    final Set<String> appointmentIds = <String>{
      widget.appointment.id,
      widget.appointment.apiId,
      if (widget.appointment.publicId case final String publicId) publicId,
    }.map((String id) => id.trim().toUpperCase()).toSet();
    return workspaceState.queueEntries.items.any((OpdQueueEntry entry) {
      final String? appointmentId = entry.appointmentId;
      return appointmentId != null &&
          appointmentIds.contains(appointmentId.trim().toUpperCase()) &&
          !isOpdQueueTerminalStatus(entry.status);
    });
  }

  Future<void> _openReschedule() async {
    if (_isSaving) {
      return;
    }
    final bool? changed = await showOpdRescheduleAppointmentDialog(
      context: context,
      appointment: widget.appointment,
    );
    if (changed == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _openCancel() async {
    if (_isSaving) {
      return;
    }
    final bool? changed = await showOpdCancelAppointmentDialog(
      context: context,
      appointment: widget.appointment,
    );
    if (changed == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _run(
    _AppointmentFooterAction action,
    Future<AppFailure?> Function() run,
  ) async {
    if (_isSaving) {
      return;
    }
    setState(() {
      _activeAction = action;
      _failure = null;
    });
    final AppFailure? failure = await run();
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _failure = failure;
      _activeAction = null;
    });
  }
}

/// Opens the OPD cancel-appointment dialog (mutating; not barrier-dismissible).
Future<bool?> showOpdCancelAppointmentDialog({
  required BuildContext context,
  required OpdAppointment appointment,
}) {
  return showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => OpdCancelAppointmentDialog(appointment: appointment),
  );
}

/// Confirm cancellation of an OPD appointment with optional reason capture.
class OpdCancelAppointmentDialog extends ConsumerWidget {
  const OpdCancelAppointmentDialog({required this.appointment, super.key});

  final OpdAppointment appointment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final Locale locale = Localizations.localeOf(context);
    return AppConfirmActionDialog(
      title: l10n.opdCancelAction,
      body: l10n.opdCancelAppointmentConfirmBody,
      submitLabel: l10n.opdCancelAction,
      icon: const Icon(AppActionIcons.delete),
      submitLeadingIcon: AppActionIcons.delete,
      destructive: true,
      scrollable: true,
      pinActionsToBottom: true,
      maxWidth: 680,
      sectionDensity: AppFormSectionDensity.compact,
      leadingContent: <Widget>[
        AppTriageSummaryPanel(
          items: <AppInfoTileData>[
            AppInfoTileData(
              label: l10n.opdPatientColumnLabel,
              value: appointment.displayTitle,
            ),
            AppInfoTileData(
              label: l10n.opdStatusColumnLabel,
              value: opdStageDisplayLabel(l10n, appointment.status ?? ''),
            ),
            AppInfoTileData(
              label: l10n.opdProviderColumnLabel,
              value:
                  appointment.providerDisplayName ?? l10n.profileUnknownValue,
            ),
            AppInfoTileData(
              label: l10n.opdTimeColumnLabel,
              value: appointment.scheduledStart == null
                  ? l10n.profileUnknownValue
                  : AppFormatters.dateTime(appointment.scheduledStart!, locale),
            ),
          ],
          emptyValue: l10n.profileUnknownValue,
        ),
      ],
      noteFieldLabel: l10n.opdFieldOptionalLabel(
        l10n.opdCancellationReasonLabel,
      ),
      notePrefixIcon: const Icon(AppActionIcons.edit),
      onConfirmWithNote: (String note) {
        return ref
            .read(opdWorkspaceControllerProvider.notifier)
            .cancelAppointment(appointment, note.isEmpty ? null : note);
      },
    );
  }
}
