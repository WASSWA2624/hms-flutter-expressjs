import 'dart:async';

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
import 'package:hosspi_hms/shared/layout/app_workspace.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_provider_options.dart';
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

/// Edit an OPD appointment schedule with validated date/time, duration, and
/// optional provider reassignment; success-only sync.
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
  late final TextEditingController _durationController;
  late DateTime? _date;
  late AppTimeValue? _startTime;
  late AppTimeValue? _endTime;
  String? _providerId;
  bool _isLoadingProviders = false;
  bool _isSaving = false;
  bool _syncingTimes = false;
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
    final int initialDuration =
        opdRescheduleDurationMinutes(_startTime, _endTime) ?? 30;
    _durationController = TextEditingController(text: '$initialDuration');
    _providerId = widget.appointment.providerUserId?.trim();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_loadFormOptions());
    });
  }

  @override
  void dispose() {
    _durationController.dispose();
    super.dispose();
  }

  bool get _isBusy => _isSaving || _isLoadingProviders;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final Locale locale = Localizations.localeOf(context);
    final OpdWorkspaceState? workspace = ref
        .watch(opdWorkspaceControllerProvider)
        .asData
        ?.value
        .when(
          success: (OpdWorkspaceState state) => state,
          failure: (_) => null,
        );
    final List<OpdProviderOption> providers = opdProvidersWithAssigned(
      providers: workspace?.queueProviderOptions ?? const <OpdProviderOption>[],
      assignedProviderId: widget.appointment.providerUserId,
      assignedProviderDisplayName: widget.appointment.providerDisplayName,
      facilityId: widget.appointment.facilityId,
    );
    final List<OpdProviderSchedule> schedules =
        workspace?.providerSchedules ?? const <OpdProviderSchedule>[];
    final List<AppSelectOption<String>> providerOptions =
        opdProviderSelectOptions(providers: providers, schedules: schedules);
    final String statusLabel = opdStageDisplayLabel(
      l10n,
      widget.appointment.status ?? '',
    );
    final String patientNumber =
        (widget.appointment.patientIdentifier ??
                widget.appointment.patientId ??
                '')
            .trim();
    final String genderLabel = patientGenderLabel(
      l10n,
      widget.appointment.patientGender,
    );
    final String? phone = widget.appointment.patientPhone?.trim();
    final String providerLabel =
        (widget.appointment.providerDisplayName ?? '').trim().isEmpty
        ? l10n.profileUnknownValue
        : widget.appointment.providerDisplayName!.trim();
    final String arrivalLabel = widget.appointment.scheduledStart == null
        ? l10n.profileUnknownValue
        : AppFormatters.dateTime(widget.appointment.scheduledStart!, locale);

    return AppDialog(
      title: Text(l10n.opdRescheduleAction),
      icon: const Icon(AppActionIcons.reschedule),
      scrollable: true,
      pinActionsToBottom: true,
      closeEnabled: !_isBusy,
      maxWidth: 720,
      content: AppFormShell(
        formKey: _formKey,
        enabled: !_isBusy,
        density: AppFormSectionDensity.compact,
        formStatus: appFormFailureStatus(
          context,
          _failure,
          messageBuilder: (AppFailure failure) => failure.displayMessage(l10n),
        ),
        children: <Widget>[
          AppPatientDetails(
            patientName: widget.appointment.displayTitle,
            patientNumber: patientNumber.isEmpty
                ? l10n.profileUnknownValue
                : patientNumber,
            patientNumberLabel: l10n.opdPatientIdLabel,
            ageLabel: widget.appointment.patientDateOfBirth == null
                ? null
                : formatPatientAge(l10n, widget.appointment.patientDateOfBirth),
            genderLabel: genderLabel.isEmpty ? null : genderLabel,
            genderIcon: patientGenderIcon(widget.appointment.patientGender),
            phoneLabel: phone,
            status: statusLabel.isEmpty
                ? null
                : AppWorkspaceStatus(
                    label: statusLabel,
                    tone: opdStageStatusTone(widget.appointment.status),
                  ),
            showAvatar: false,
            persistExpandPreference: false,
            initiallyExpanded: false,
            semanticLabel: widget.appointment.displayTitle,
            expandedFields: <AppWorkspacePatientContextField>[
              AppWorkspacePatientContextField(
                label: l10n.opdProviderColumnLabel,
                value: providerLabel,
                icon: Icons.medical_services_outlined,
              ),
              AppWorkspacePatientContextField(
                label: l10n.opdTimeColumnLabel,
                value: arrivalLabel,
                icon: Icons.schedule_outlined,
              ),
            ],
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
                enabled: !_isBusy,
                isRequired: true,
                validator: AppValidators.requiredValue(l10n.validationRequired),
                onChanged: (DateTime? value) => setState(() => _date = value),
              ),
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
                enabled: !_isBusy,
                isRequired: true,
                validator: AppValidators.requiredValue(l10n.validationRequired),
                onChanged: _onStartChanged,
              ),
              AppTextField(
                controller: _durationController,
                labelText: l10n.opdFieldRequiredLabel(
                  l10n.patientsAppointmentDurationLabel,
                ),
                enabled: !_isBusy,
                isRequired: true,
                keyboardType: TextInputType.number,
                validator: _durationValidator(l10n),
                onChanged: _onDurationChanged,
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
                enabled: !_isBusy,
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
                onChanged: _onEndChanged,
              ),
            ],
          ),
          AppFormSection(
            density: AppFormSectionDensity.compact,
            children: <Widget>[
              AppSelectField<String>.searchable(
                value: _providerId,
                labelText: l10n.patientsProviderLabel,
                helperText: providerOptions.isEmpty && !_isLoadingProviders
                    ? l10n.opdNoProvidersHelper
                    : l10n.patientsProviderOptionalHelper,
                enabled: !_isBusy,
                isLoading: _isLoadingProviders,
                onChanged: (String? value) =>
                    setState(() => _providerId = value),
                options: providerOptions,
              ),
            ],
          ),
        ],
      ),
      actions: clinicalActionDialogActions(
        context,
        l10n.patientsEditAction,
        _isSaving,
        _isBusy ? null : _submit,
        submitLeadingIcon: AppActionIcons.edit,
      ),
    );
  }

  Future<void> _loadFormOptions() async {
    setState(() {
      _isLoadingProviders = true;
      _failure = null;
    });
    final AppFailure? optionsFailure = await ref
        .read(opdWorkspaceControllerProvider.notifier)
        .ensureAppointmentFormOptionsLoaded();
    if (!mounted) {
      return;
    }
    final OpdWorkspaceState? workspace = ref
        .read(opdWorkspaceControllerProvider)
        .asData
        ?.value
        .when(
          success: (OpdWorkspaceState state) => state,
          failure: (_) => null,
        );
    final List<OpdProviderOption> providers = opdProvidersWithAssigned(
      providers: workspace?.queueProviderOptions ?? const <OpdProviderOption>[],
      assignedProviderId: widget.appointment.providerUserId,
      assignedProviderDisplayName: widget.appointment.providerDisplayName,
      facilityId: widget.appointment.facilityId,
    );
    final List<AppSelectOption<String>> providerOptions =
        opdProviderSelectOptions(
          providers: providers,
          schedules: workspace?.providerSchedules ?? const <OpdProviderSchedule>[],
        );
    setState(() {
      _failure = optionsFailure;
      _isLoadingProviders = false;
      _providerId = resolveOpdProviderSelection(
        options: providerOptions,
        providers: providers,
        assignedProviderId: widget.appointment.providerUserId,
        assignedProviderDisplayName: widget.appointment.providerDisplayName,
      );
    });
  }

  void _onStartChanged(AppTimeValue? value) {
    setState(() {
      _startTime = value;
      _applyDurationToEnd();
    });
  }

  void _onDurationChanged(String raw) {
    if (_syncingTimes) {
      return;
    }
    setState(_applyDurationToEnd);
  }

  void _onEndChanged(AppTimeValue? value) {
    if (_syncingTimes) {
      return;
    }
    setState(() {
      _endTime = value;
      _applyEndToDuration();
    });
  }

  void _applyDurationToEnd() {
    final int? minutes = int.tryParse(_durationController.text.trim());
    if (minutes == null || minutes <= 0) {
      return;
    }
    final AppTimeValue? nextEnd = opdRescheduleEndFromDuration(
      _startTime,
      minutes,
    );
    if (nextEnd == null) {
      return;
    }
    _syncingTimes = true;
    _endTime = nextEnd;
    _syncingTimes = false;
  }

  void _applyEndToDuration() {
    final int? minutes = opdRescheduleDurationMinutes(_startTime, _endTime);
    if (minutes == null) {
      return;
    }
    final String next = '$minutes';
    if (_durationController.text.trim() == next) {
      return;
    }
    _syncingTimes = true;
    _durationController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    _syncingTimes = false;
  }

  Future<void> _submit() async {
    if (_isBusy) {
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
    final String? originalProvider = widget.appointment.providerUserId?.trim();
    final String? nextProvider = _providerId?.trim();
    final bool updateProvider =
        (originalProvider ?? '') != (nextProvider ?? '');

    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(opdWorkspaceControllerProvider.notifier)
        .rescheduleAppointment(
          widget.appointment,
          start,
          end,
          providerUserId: nextProvider,
          updateProvider: updateProvider,
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

/// Minutes between [start] and [end] when end is strictly after start.
@visibleForTesting
int? opdRescheduleDurationMinutes(AppTimeValue? start, AppTimeValue? end) {
  if (start == null || end == null || !end.isAfter(start)) {
    return null;
  }
  return end.totalMinutes - start.totalMinutes;
}

/// End clock time for [start] plus [minutes], when it stays on the same day.
@visibleForTesting
AppTimeValue? opdRescheduleEndFromDuration(AppTimeValue? start, int minutes) {
  if (start == null || minutes <= 0) {
    return null;
  }
  final int total = start.totalMinutes + minutes;
  if (total >= 24 * 60) {
    return null;
  }
  return AppTimeValue(hour: total ~/ 60, minute: total % 60);
}

FormFieldValidator<String> _durationValidator(AppLocalizations l10n) {
  return (String? value) {
    final int? minutes = int.tryParse(value?.trim() ?? '');
    if (minutes == null) {
      return l10n.validationRequired;
    }
    return minutes <= 0 || minutes > 720
        ? l10n.patientsDurationInvalidMessage
        : null;
  };
}
