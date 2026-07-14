import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/presentation/controllers/opd_workspace_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_status_display.dart';

/// Lightweight appointment actions for Reception — avoids importing the full OPD page.
Future<bool?> showReceptionAppointmentActionsDialog({
  required BuildContext context,
  required OpdAppointment appointment,
}) {
  return showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ReceptionAppointmentActionsDialog(appointment: appointment),
  );
}

class _ReceptionAppointmentActionsDialog extends ConsumerStatefulWidget {
  const _ReceptionAppointmentActionsDialog({required this.appointment});

  final OpdAppointment appointment;

  @override
  ConsumerState<_ReceptionAppointmentActionsDialog> createState() =>
      _ReceptionAppointmentActionsDialogState();
}

class _ReceptionAppointmentActionsDialogState
    extends ConsumerState<_ReceptionAppointmentActionsDialog> {
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final Locale locale = Localizations.localeOf(context);
    final String status = (widget.appointment.status ?? '').toUpperCase();
    final bool terminal = _isTerminal(status);
    final bool canQueue =
        !terminal &&
        status != 'IN_PROGRESS' &&
        widget.appointment.patientId != null;
    final bool canCheckIn =
        !terminal && status != 'IN_PROGRESS' && status != 'COMPLETED';
    final bool canReschedule = !terminal;
    final bool canCancel = !terminal && status != 'CANCELLED';

    return AppDialog(
      title: Text(widget.appointment.displayTitle),
      icon: const Icon(Icons.event_available_outlined),
      scrollable: true,
      maxWidth: 680,
      content: AppFormSection(
        density: AppFormSectionDensity.compact,
        children: <Widget>[
          if (_failure != null)
            AppFormInformationBanner.failure(
              context: context,
              failure: _failure!,
            ),
          AppInfoTile(
            label: l10n.opdStatusColumnLabel,
            value: opdStageDisplayLabel(l10n, widget.appointment.status ?? ''),
            icon: Icons.flag_outlined,
          ),
          AppInfoTile(
            label: l10n.opdProviderColumnLabel,
            value:
                widget.appointment.providerDisplayName ??
                l10n.profileUnknownValue,
            icon: Icons.person_outline,
          ),
          AppInfoTile(
            label: l10n.opdTimeColumnLabel,
            value: widget.appointment.scheduledStart == null
                ? l10n.profileUnknownValue
                : AppFormatters.dateTime(
                    widget.appointment.scheduledStart!,
                    locale,
                  ),
            icon: Icons.schedule_outlined,
          ),
        ],
      ),
      actions: <Widget>[
        if (canQueue)
          AppButton.secondary(
            label: l10n.opdQueueAction,
            leadingIcon: Icons.queue_outlined,
            isLoading: _isSaving,
            onPressed: () => _run(
              () => ref
                  .read(opdWorkspaceControllerProvider.notifier)
                  .assignAppointmentToQueue(widget.appointment),
            ),
          ),
        if (canReschedule)
          AppButton.secondary(
            label: l10n.opdRescheduleAction,
            leadingIcon: Icons.edit_calendar_outlined,
            enabled: !_isSaving,
            onPressed: _openReschedule,
          ),
        if (canCancel)
          AppButton.secondary(
            label: l10n.opdCancelAction,
            leadingIcon: Icons.cancel_outlined,
            enabled: !_isSaving,
            onPressed: _openCancel,
          ),
        if (canCheckIn)
          AppButton.primary(
            label: l10n.opdCheckInAction,
            leadingIcon: Icons.login_outlined,
            isLoading: _isSaving,
            onPressed: () => _run(
              () => ref
                  .read(opdWorkspaceControllerProvider.notifier)
                  .checkInAppointment(widget.appointment),
            ),
          ),
      ],
    );
  }

  Future<void> _openReschedule() async {
    final bool? changed = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _ReceptionRescheduleDialog(appointment: widget.appointment),
    );
    if (changed == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _openCancel() async {
    final bool? changed = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ReceptionCancelDialog(appointment: widget.appointment),
    );
    if (changed == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _run(Future<AppFailure?> Function() action) async {
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await action();
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

  bool _isTerminal(String status) {
    switch (status) {
      case 'COMPLETED':
      case 'CANCELLED':
      case 'NO_SHOW':
      case 'CLOSED':
        return true;
      default:
        return false;
    }
  }
}

class _ReceptionRescheduleDialog extends ConsumerStatefulWidget {
  const _ReceptionRescheduleDialog({required this.appointment});

  final OpdAppointment appointment;

  @override
  ConsumerState<_ReceptionRescheduleDialog> createState() =>
      _ReceptionRescheduleDialogState();
}

class _ReceptionRescheduleDialogState
    extends ConsumerState<_ReceptionRescheduleDialog> {
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
    return AppDialog(
      title: Text(l10n.opdRescheduleAction),
      icon: const Icon(Icons.edit_calendar_outlined),
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null)
              AppFormInformationBanner.failure(
                context: context,
                failure: _failure!,
              ),
            AppDateField(
              value: _date,
              firstDate: DateTime.now().subtract(const Duration(days: 1)),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              labelText: l10n.patientsAppointmentDateLabel,
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
                  labelText: l10n.opdAppointmentStartLabel,
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
                  labelText: l10n.opdAppointmentEndLabel,
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
      ),
      actions: <Widget>[
        AppButton.primary(
          label: l10n.opdRescheduleAction,
          leadingIcon: Icons.edit_calendar_outlined,
          isLoading: _isSaving,
          onPressed: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
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

class _ReceptionCancelDialog extends ConsumerStatefulWidget {
  const _ReceptionCancelDialog({required this.appointment});

  final OpdAppointment appointment;

  @override
  ConsumerState<_ReceptionCancelDialog> createState() =>
      _ReceptionCancelDialogState();
}

class _ReceptionCancelDialogState extends ConsumerState<_ReceptionCancelDialog> {
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
    return AppDialog(
      title: Text(l10n.opdCancelAction),
      icon: const Icon(Icons.cancel_outlined),
      content: AppFormSection(
        children: <Widget>[
          if (_failure != null)
            AppFormInformationBanner.failure(
              context: context,
              failure: _failure!,
            ),
          AppTextField(
            controller: _reasonController,
            labelText: l10n.opdCancellationReasonLabel,
            enabled: !_isSaving,
            maxLines: 3,
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.primary(
          label: l10n.opdCancelAction,
          leadingIcon: Icons.cancel_outlined,
          isLoading: _isSaving,
          onPressed: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(opdWorkspaceControllerProvider.notifier)
        .cancelAppointment(widget.appointment, _reasonController.text.trim());
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
