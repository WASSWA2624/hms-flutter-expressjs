import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/presentation/controllers/opd_workspace_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_action_dialog_actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_status_display.dart';

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

/// Edit an OPD appointment schedule with validated date/time and success-only sync.
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
      icon: const Icon(AppActionIcons.reschedule),
      scrollable: true,
      pinActionsToBottom: true,
      closeEnabled: !_isSaving,
      maxWidth: 680,
      content: AppFormShell(
        formKey: _formKey,
        enabled: !_isSaving,
        density: AppFormSectionDensity.compact,
        formStatus: appFormFailureStatus(
          context,
          _failure,
          messageBuilder: (AppFailure failure) => failure.displayMessage(l10n),
        ),
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
                validator: AppValidators.requiredValue(l10n.validationRequired),
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
                    validator: AppValidators.requiredValue(
                      l10n.validationRequired,
                    ),
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
                    validator: (AppTimeValue? value) {
                      if (value == null) {
                        return l10n.validationRequired;
                      }
                      final AppTimeValue? start = _startTime;
                      if (start != null && !value.isAfter(start)) {
                        return l10n.opdAppointmentEndAfterStartMessage;
                      }
                      return null;
                    },
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
    final DateTime? start = AppTimeValue.combine(_date, _startTime);
    final DateTime? end = AppTimeValue.combine(_date, _endTime);
    if (start == null || end == null || !end.isAfter(start)) {
      setState(
        () => _failure = AppFailure.validation(
          detailMessage: context.l10n.opdAppointmentEndAfterStartMessage,
        ),
      );
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
}
