import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/presentation/controllers/opd_workspace_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_action_dialog_actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_encounter_flow.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_flow_actions_dialog.dart'
    show opdFrontDeskActionRequirement;
import 'package:hosspi_hms/shared/opd_actions/opd_queue_actions_dialog.dart'
    show isOpdQueueTerminalStatus;
import 'package:hosspi_hms/shared/opd_actions/opd_status_display.dart';

/// Shared appointment actions for OPD and Reception workspaces.
Future<bool?> showOpdAppointmentActionsDialog({
  required BuildContext context,
  required OpdAppointment appointment,
  OpdWorkspaceState? workspaceState,
}) {
  return showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => OpdAppointmentActionsDialog(
      appointment: appointment,
      workspaceState: workspaceState,
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
    super.key,
  });

  final OpdAppointment appointment;

  /// When set, check-in opens the encounter dialog; otherwise direct check-in.
  final OpdWorkspaceState? workspaceState;

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

    return AppDialog(
      title: Text(l10n.receptionAppointmentActionsAction),
      icon: const Icon(Icons.event_available_outlined),
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
          AppTriageSummaryPanel(
            items: <AppInfoTileData>[
              AppInfoTileData(
                label: l10n.opdPatientColumnLabel,
                value: widget.appointment.displayTitle,
              ),
              AppInfoTileData(
                label: l10n.opdStatusColumnLabel,
                value: opdStageDisplayLabel(
                  l10n,
                  widget.appointment.status ?? '',
                ),
              ),
              AppInfoTileData(
                label: l10n.opdProviderColumnLabel,
                value:
                    widget.appointment.providerDisplayName ??
                    l10n.profileUnknownValue,
              ),
              AppInfoTileData(
                label: l10n.opdTimeColumnLabel,
                value: widget.appointment.scheduledStart == null
                    ? l10n.profileUnknownValue
                    : AppFormatters.dateTime(
                        widget.appointment.scheduledStart!,
                        locale,
                      ),
              ),
              AppInfoTileData(
                label: l10n.opdReasonLabel,
                value: widget.appointment.reason ?? l10n.profileUnknownValue,
              ),
            ],
            emptyValue: l10n.profileUnknownValue,
          ),
          if (!terminal)
            AppActionSection(
              title: l10n.opdActionsColumnLabel,
              minItemWidth: 180,
              permissionActions: <AppPermissionActionItem>[
                if (canQueue)
                  AppPermissionActionItem(
                    requirement: opdFrontDeskActionRequirement,
                    label: l10n.opdQueueAction,
                    icon: Icons.queue_outlined,
                    fullWidth: true,
                    isLoading: _activeAction == _AppointmentFooterAction.queue,
                    enabled: !_isSaving,
                    onPressed: _isSaving
                        ? null
                        : () => _run(
                            _AppointmentFooterAction.queue,
                            () => ref
                                .read(opdWorkspaceControllerProvider.notifier)
                                .assignAppointmentToQueue(widget.appointment),
                          ),
                  ),
                if (canReschedule)
                  AppPermissionActionItem(
                    requirement: opdFrontDeskActionRequirement,
                    label: l10n.opdRescheduleAction,
                    icon: AppActionIcons.calendar,
                    fullWidth: true,
                    enabled: !_isSaving,
                    onPressed: _isSaving ? null : _openReschedule,
                  ),
                if (canCancelAppointment)
                  AppPermissionActionItem(
                    requirement: opdFrontDeskActionRequirement,
                    label: l10n.opdCancelAction,
                    icon: AppActionIcons.delete,
                    fullWidth: true,
                    destructive: true,
                    enabled: !_isSaving,
                    onPressed: _isSaving ? null : _openCancel,
                  ),
                if (canCheckIn)
                  AppPermissionActionItem(
                    requirement: opdFrontDeskActionRequirement,
                    label: l10n.opdCheckInAction,
                    icon: Icons.login_outlined,
                    variant: AppButtonVariant.primary,
                    fullWidth: true,
                    isLoading:
                        _activeAction == _AppointmentFooterAction.checkIn,
                    enabled: !_isSaving,
                    onPressed: _isSaving ? null : _openCheckIn,
                  ),
              ],
            ),
        ],
      ),
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

/// Opens the OPD appointment reschedule dialog (mutating; not barrier-dismissible).
Future<bool?> showOpdRescheduleAppointmentDialog({
  required BuildContext context,
  required OpdAppointment appointment,
}) {
  return showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => OpdRescheduleAppointmentDialog(appointment: appointment),
  );
}

class OpdRescheduleAppointmentDialog extends ConsumerStatefulWidget {
  const OpdRescheduleAppointmentDialog({required this.appointment, super.key});

  final OpdAppointment appointment;

  @override
  ConsumerState<OpdRescheduleAppointmentDialog> createState() =>
      _OpdRescheduleAppointmentDialogState();
}

class _OpdRescheduleAppointmentDialogState
    extends ConsumerState<OpdRescheduleAppointmentDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late DateTime? _date;
  late AppTimeValue? _startTime;
  late AppTimeValue? _endTime;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    final DateTime start =
        widget.appointment.scheduledStart?.toLocal() ??
        DateTime.now().add(const Duration(hours: 1));
    final DateTime end =
        widget.appointment.scheduledEnd?.toLocal() ??
        start.add(const Duration(minutes: 30));
    _date = DateTime(start.year, start.month, start.day);
    _startTime = AppTimeValue(hour: start.hour, minute: start.minute);
    _endTime = AppTimeValue(hour: end.hour, minute: end.minute);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final Locale locale = Localizations.localeOf(context);
    return AppDialog(
      title: Text(l10n.opdRescheduleAction),
      icon: const Icon(AppActionIcons.calendar),
      scrollable: true,
      pinActionsToBottom: true,
      closeEnabled: !_isSaving,
      maxWidth: 680,
      content: AppFormShell(
        formKey: _formKey,
        enabled: !_isSaving,
        density: AppFormSectionDensity.compact,
        formStatus: appFormFailureStatus(context, _failure),
        children: <Widget>[
          AppTriageSummaryPanel(
            items: <AppInfoTileData>[
              AppInfoTileData(
                label: l10n.opdPatientColumnLabel,
                value: widget.appointment.displayTitle,
              ),
              AppInfoTileData(
                label: l10n.opdProviderColumnLabel,
                value:
                    widget.appointment.providerDisplayName ??
                    l10n.profileUnknownValue,
              ),
              AppInfoTileData(
                label: l10n.opdTimeColumnLabel,
                value: widget.appointment.scheduledStart == null
                    ? l10n.profileUnknownValue
                    : AppFormatters.dateTime(
                        widget.appointment.scheduledStart!,
                        locale,
                      ),
              ),
            ],
            emptyValue: l10n.profileUnknownValue,
          ),
          AppFormSection(
            density: AppFormSectionDensity.compact,
            children: <Widget>[
              AppDateField(
                value: _date,
                firstDate: DateTime.now().subtract(const Duration(days: 1)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                labelText: l10n.opdFieldRequiredLabel(
                  l10n.patientsAppointmentDateLabel,
                ),
                pickerButtonLabel: l10n.patientsDatePickerAction,
                invalidDateMessage: l10n.appDateInvalidMessage,
                enabled: !_isSaving,
                isRequired: true,
                validator: (DateTime? value) =>
                    value == null ? l10n.validationRequired : null,
                onChanged: (DateTime? value) => setState(() => _date = value),
              ),
              AppResponsiveFieldRow(
                gap: AppResponsiveFieldRowGap.form,
                children: <Widget>[
                  AppTimeField(
                    value: _startTime,
                    labelText: l10n.opdFieldRequiredLabel(
                      l10n.opdAppointmentStartLabel,
                    ),
                    pickerButtonLabel: l10n.appTimePickerAction,
                    invalidTimeMessage: l10n.patientsTimeInvalidMessage,
                    hintText: l10n.patientsTimeHint,
                    hourLabelText: l10n.appTimeHourLabel,
                    minuteLabelText: l10n.appTimeMinuteLabel,
                    enabled: !_isSaving,
                    isRequired: true,
                    validator: (AppTimeValue? value) =>
                        value == null ? l10n.validationRequired : null,
                    onChanged: (AppTimeValue? value) {
                      setState(() => _startTime = value);
                    },
                  ),
                  AppTimeField(
                    value: _endTime,
                    labelText: l10n.opdFieldRequiredLabel(
                      l10n.opdAppointmentEndLabel,
                    ),
                    pickerButtonLabel: l10n.appTimePickerAction,
                    invalidTimeMessage: l10n.patientsTimeInvalidMessage,
                    hintText: l10n.patientsTimeHint,
                    hourLabelText: l10n.appTimeHourLabel,
                    minuteLabelText: l10n.appTimeMinuteLabel,
                    enabled: !_isSaving,
                    isRequired: true,
                    validator: (AppTimeValue? value) =>
                        value == null ? l10n.validationRequired : null,
                    onChanged: (AppTimeValue? value) {
                      setState(() => _endTime = value);
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      actions: clinicalActionDialogActions(
        context,
        l10n.patientsEditAction,
        _isSaving,
        _isSaving ? null : _submit,
        submitLeadingIcon: AppActionIcons.edit,
      ),
    );
  }

  Future<void> _submit() async {
    if (_isSaving) {
      return;
    }
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }
    final DateTime? start = _combine(_date, _startTime);
    final DateTime? end = _combine(_date, _endTime);
    if (start == null || end == null || !end.isAfter(start)) {
      setState(() => _failure = AppFailure.validation());
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(opdWorkspaceControllerProvider.notifier)
        .rescheduleAppointment(widget.appointment, start, end);
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _failure = failure;
      _isSaving = false;
    });
  }

  DateTime? _combine(DateTime? date, AppTimeValue? time) {
    if (date == null || time == null) {
      return null;
    }
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
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

class OpdCancelAppointmentDialog extends ConsumerStatefulWidget {
  const OpdCancelAppointmentDialog({required this.appointment, super.key});

  final OpdAppointment appointment;

  @override
  ConsumerState<OpdCancelAppointmentDialog> createState() =>
      _OpdCancelAppointmentDialogState();
}

class _OpdCancelAppointmentDialogState
    extends ConsumerState<OpdCancelAppointmentDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _reasonController;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _reasonController = TextEditingController();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final Locale locale = Localizations.localeOf(context);
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return AppDialog(
      title: Text(l10n.opdCancelAction),
      icon: Icon(AppActionIcons.delete, color: colorScheme.error),
      scrollable: true,
      pinActionsToBottom: true,
      closeEnabled: !_isSaving,
      maxWidth: 680,
      content: AppFormShell(
        formKey: _formKey,
        enabled: !_isSaving,
        density: AppFormSectionDensity.compact,
        formStatus: appFormFailureStatus(context, _failure),
        children: <Widget>[
          AppTriageSummaryPanel(
            items: <AppInfoTileData>[
              AppInfoTileData(
                label: l10n.opdPatientColumnLabel,
                value: widget.appointment.displayTitle,
              ),
              AppInfoTileData(
                label: l10n.opdStatusColumnLabel,
                value: opdStageDisplayLabel(
                  l10n,
                  widget.appointment.status ?? '',
                ),
              ),
              AppInfoTileData(
                label: l10n.opdProviderColumnLabel,
                value:
                    widget.appointment.providerDisplayName ??
                    l10n.profileUnknownValue,
              ),
              AppInfoTileData(
                label: l10n.opdTimeColumnLabel,
                value: widget.appointment.scheduledStart == null
                    ? l10n.profileUnknownValue
                    : AppFormatters.dateTime(
                        widget.appointment.scheduledStart!,
                        locale,
                      ),
              ),
            ],
            emptyValue: l10n.profileUnknownValue,
          ),
          AppFormInformationBanner.message(
            message: l10n.opdCancelAppointmentConfirmBody,
            variant: AppFormInformationVariant.warning,
            icon: Icons.warning_amber_outlined,
          ),
          AppFormSection(
            density: AppFormSectionDensity.compact,
            children: <Widget>[
              AppTextField(
                controller: _reasonController,
                labelText: l10n.opdFieldOptionalLabel(
                  l10n.opdCancellationReasonLabel,
                ),
                enabled: !_isSaving,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                prefixIcon: const Icon(Icons.notes_outlined),
              ),
            ],
          ),
        ],
      ),
      actions: clinicalActionDialogActions(
        context,
        l10n.opdCancelAction,
        _isSaving,
        _isSaving ? null : _submit,
        submitLeadingIcon: AppActionIcons.delete,
        destructive: true,
      ),
    );
  }

  Future<void> _submit() async {
    if (_isSaving) {
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final String reason = _reasonController.text.trim();
    final AppFailure? failure = await ref
        .read(opdWorkspaceControllerProvider.notifier)
        .cancelAppointment(
          widget.appointment,
          reason.isEmpty ? null : reason,
        );
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _failure = failure;
      _isSaving = false;
    });
  }
}
