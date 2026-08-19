import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/opd/data/repositories/opd_repository_impl.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/presentation/controllers/opd_workspace_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/opd_actions/appointment_window.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_provider_options.dart';

/// Schedule a visitor (non-patient) meeting with any facility staff host.
///
/// When [embedded] is true, only the form body is built so a parent dialog can
/// own the tab strip and pinned footer actions.
class ReceptionVisitorAppointmentDialog extends ConsumerStatefulWidget {
  const ReceptionVisitorAppointmentDialog({
    this.embedded = false,
    this.onSaved,
    this.onCancel,
    this.onBusyChanged,
    super.key,
  });

  final bool embedded;
  final VoidCallback? onSaved;
  final VoidCallback? onCancel;
  final ValueChanged<bool>? onBusyChanged;

  @override
  ReceptionVisitorAppointmentDialogState createState() =>
      ReceptionVisitorAppointmentDialogState();
}

class ReceptionVisitorAppointmentDialogState
    extends ConsumerState<ReceptionVisitorAppointmentDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final GlobalKey<State<AppPhoneField>> _phoneFieldKey =
      GlobalKey<State<AppPhoneField>>();
  final TextEditingController _visitorNameController = TextEditingController();
  final TextEditingController _visitorPhoneController = TextEditingController();
  final TextEditingController _visitorOrganizationController =
      TextEditingController();
  final TextEditingController _durationController = TextEditingController(
    text: '30',
  );
  final TextEditingController _reasonController = TextEditingController();

  DateTime? _date = DateTime.now();
  AppTimeValue? _startTime = const AppTimeValue(hour: 9, minute: 0);
  AppTimeValue? _endTime = const AppTimeValue(hour: 9, minute: 30);
  String? _hostId;
  List<OpdProviderOption> _hosts = const <OpdProviderOption>[];
  List<OpdProviderSchedule> _schedules = const <OpdProviderSchedule>[];
  bool _isLoadingHosts = false;
  bool _isSaving = false;
  AppFailure? _failure;

  bool get isSaving => _isSaving;

  bool get isBusy => _isSaving || _isLoadingHosts;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_loadHosts());
    });
  }

  @override
  void dispose() {
    _visitorNameController.dispose();
    _visitorPhoneController.dispose();
    _visitorOrganizationController.dispose();
    _durationController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<AppSelectOption<String>> hostOptions = opdProviderSelectOptions(
      providers: _hosts,
      schedules: _schedules,
    );

    final Widget form = AppFormShell(
      formKey: _formKey,
      enabled: !isBusy,
      density: AppFormSectionDensity.compact,
      formStatus: appFormFailureStatus(
        context,
        _failure,
        messageBuilder: (AppFailure failure) => failure.displayMessage(l10n),
      ),
      children: <Widget>[
        AppTextField(
          controller: _visitorNameController,
          labelText: l10n.receptionVisitorNameLabel,
          enabled: !isBusy,
          isRequired: true,
          textInputAction: TextInputAction.next,
          validator: (String? value) {
            if ((value ?? '').trim().isEmpty) {
              return l10n.validationRequired;
            }
            return null;
          },
        ),
        AppResponsiveFieldRow(
          gap: AppResponsiveFieldRowGap.form,
          children: <Widget>[
            AppPhoneField(
              key: _phoneFieldKey,
              controller: _visitorPhoneController,
              labelText: l10n.receptionVisitorPhoneLabel,
              countryLabelText: l10n.appPhoneCountryLabel,
              countrySearchLabelText: l10n.appPhoneCountrySearchLabel,
              countryNoResultsText: l10n.appPhoneCountryNoResults,
              numberLabelText: l10n.appPhoneNumberLabel,
              numberHintText: l10n.appPhoneNumberHint,
              invalidPhoneMessage: l10n.appPhoneInvalidMessage,
              helperText: l10n.patientsAppointmentContactPhoneHelper,
              enabled: !isBusy,
              // Reception calls visitors back about their meeting, so the
              // number is mandatory rather than a nicety.
              isRequired: true,
              requiredMessage: l10n.validationRequired,
              textInputAction: TextInputAction.next,
            ),
            AppTextField(
              controller: _visitorOrganizationController,
              labelText: l10n.receptionVisitorOrganizationLabel,
              enabled: !isBusy,
              textInputAction: TextInputAction.next,
            ),
          ],
        ),
        AppSelectField<String>.searchable(
          value: _hostId,
          labelText: l10n.receptionStaffHostLabel,
          hintText: l10n.receptionStaffHostSearchHint,
          emptyResultsText: l10n.appSelectNoResults,
          options: hostOptions,
          enabled: !isBusy,
          isLoading: _isLoadingHosts,
          isRequired: true,
          onChanged: (String? value) => setState(() => _hostId = value),
          validator: (String? value) {
            if ((value ?? '').trim().isEmpty) {
              return l10n.validationRequired;
            }
            return null;
          },
        ),
        AppResponsiveFieldRow.two(
          gap: AppResponsiveFieldRowGap.form,
          left: AppDateField(
            value: _date,
            firstDate: DateTime.now().subtract(const Duration(days: 1)),
            lastDate: DateTime.now().add(const Duration(days: 365)),
            labelText: l10n.patientsAppointmentDateLabel,
            pickerButtonLabel: l10n.patientsDatePickerAction,
            invalidDateMessage: l10n.appDateInvalidMessage,
            enabled: !isBusy,
            isRequired: true,
            validator: AppValidators.requiredValue(l10n.validationRequired),
            onChanged: (DateTime? value) => setState(() => _date = value),
          ),
          right: AppTimeField(
            value: _startTime,
            labelText: l10n.patientsAppointmentTimeLabel,
            pickerButtonLabel: l10n.appTimePickerAction,
            invalidTimeMessage: l10n.patientsTimeInvalidMessage,
            hintText: l10n.patientsTimeHint,
            hourLabelText: l10n.appTimeHourLabel,
            minuteLabelText: l10n.appTimeMinuteLabel,
            enabled: !isBusy,
            isRequired: true,
            validator: (AppTimeValue? value) =>
                value == null ? l10n.validationRequired : null,
            onChanged: _handleStartTimeChanged,
          ),
        ),
        AppResponsiveFieldRow.two(
          gap: AppResponsiveFieldRowGap.form,
          left: AppTimeField(
            value: _endTime,
            labelText: l10n.patientsAppointmentEndTimeLabel,
            pickerButtonLabel: l10n.appTimePickerAction,
            invalidTimeMessage: l10n.patientsTimeInvalidMessage,
            hintText: l10n.patientsTimeHint,
            hourLabelText: l10n.appTimeHourLabel,
            minuteLabelText: l10n.appTimeMinuteLabel,
            enabled: !isBusy,
            validator: appointmentEndTimeValidator(
              l10n: l10n,
              startTime: () => _startTime,
              duration: () => _durationController.text,
            ),
            onChanged: _handleEndTimeChanged,
          ),
          right: AppTextField(
            controller: _durationController,
            labelText: l10n.patientsAppointmentDurationLabel,
            enabled: !isBusy,
            keyboardType: TextInputType.number,
            validator: appointmentDurationValidator(
              l10n: l10n,
              startTime: () => _startTime,
              endTime: () => _endTime,
            ),
            onChanged: _handleDurationChanged,
          ),
        ),
        AppTextField(
          controller: _reasonController,
          labelText: l10n.patientsAppointmentReasonLabel,
          enabled: !isBusy,
          maxLines: 2,
          textInputAction: TextInputAction.done,
        ),
      ],
    );

    if (widget.embedded) {
      return form;
    }

    return AppDialog(
      title: Text(l10n.receptionVisitorMeetingTitle),
      icon: const Icon(Icons.badge_outlined),
      scrollable: true,
      pinActionsToBottom: true,
      closeEnabled: !isBusy,
      maxWidth: 720,
      content: form,
      actions: <Widget>[
        if (widget.onCancel != null)
          AppButton.close(
            label: l10n.commonCancelActionLabel,
            leadingIcon: AppActionIcons.cancel,
            enabled: !isBusy,
            onPressed: isBusy ? null : widget.onCancel,
          ),
        AppButton.primary(
          label: l10n.receptionScheduleAppointmentAction,
          leadingIcon: AppActionIcons.calendar,
          isLoading: _isSaving,
          enabled: !isBusy,
          onPressed: isBusy ? null : () => unawaited(submit()),
        ),
      ],
    );
  }

  /// Validates and creates the visitor appointment.
  ///
  /// Returns `true` on success (and invokes [ReceptionVisitorAppointmentDialog.onSaved]
  /// when provided). Returns `false` on validation or API failure.
  Future<bool> submit() async {
    if (isBusy) {
      return false;
    }
    AppPhoneField.commitPhone(_phoneFieldKey);
    if (!validateAndSaveAppForm(_formKey)) {
      return false;
    }
    final DateTime? scheduledStart = _combineDateAndTime(_date, _startTime);
    final int? duration = AppointmentWindow.resolveMinutes(
      duration: _durationController.text,
      start: _startTime,
      end: _endTime,
    );
    if (scheduledStart == null || duration == null) {
      setState(() => _failure = AppFailure.validation());
      return false;
    }
    final DateTime scheduledEnd = scheduledStart.add(
      Duration(minutes: duration),
    );

    setState(() {
      _isSaving = true;
      _failure = null;
    });
    widget.onBusyChanged?.call(true);

    final AppFailure? failure = await ref
        .read(opdWorkspaceControllerProvider.notifier)
        .createAppointment(<String, Object?>{
          'subject_type': 'VISITOR',
          'visitor_name': _visitorNameController.text.trim(),
          'visitor_phone': _visitorPhoneController.text.trim().isEmpty
              ? null
              : _visitorPhoneController.text.trim(),
          'visitor_organization':
              _visitorOrganizationController.text.trim().isEmpty
              ? null
              : _visitorOrganizationController.text.trim(),
          'provider_user_id': _hostId,
          'status': 'SCHEDULED',
          'scheduled_start': scheduledStart.toUtc().toIso8601String(),
          'scheduled_end': scheduledEnd.toUtc().toIso8601String(),
          'reason': _reasonController.text.trim().isEmpty
              ? null
              : _reasonController.text.trim(),
        });

    if (!mounted) {
      return false;
    }
    if (failure != null) {
      setState(() {
        _isSaving = false;
        _failure = failure;
      });
      widget.onBusyChanged?.call(false);
      return false;
    }

    setState(() => _isSaving = false);
    widget.onBusyChanged?.call(false);
    if (widget.onSaved != null) {
      widget.onSaved!();
      return true;
    }
    Navigator.of(context).pop(true);
    return true;
  }

  /// Keeps the end time anchored to the duration when the start time moves.
  void _handleStartTimeChanged(AppTimeValue? value) {
    setState(() {
      _startTime = value;
      final int? minutes = AppointmentWindow.parseDuration(
        _durationController.text,
      );
      if (AppointmentWindow.isValidDuration(minutes)) {
        _endTime = AppointmentWindow.endAfter(value, minutes);
        return;
      }
      _syncDurationFromWindow();
    });
  }

  void _handleEndTimeChanged(AppTimeValue? value) {
    setState(() {
      _endTime = value;
      _syncDurationFromWindow();
    });
  }

  void _handleDurationChanged(String value) {
    final int? minutes = AppointmentWindow.parseDuration(value);
    if (!AppointmentWindow.isValidDuration(minutes)) {
      // Mid-edit or out-of-range input leaves the end time alone; the field
      // validators report the problem on submit.
      return;
    }
    final AppTimeValue? end = AppointmentWindow.endAfter(_startTime, minutes);
    if (end == _endTime) {
      return;
    }
    setState(() => _endTime = end);
  }

  void _syncDurationFromWindow() {
    final int? minutes = AppointmentWindow.durationBetween(
      _startTime,
      _endTime,
    );
    _durationController.text = minutes == null ? '' : '$minutes';
  }

  Future<void> _loadHosts() async {
    setState(() => _isLoadingHosts = true);
    widget.onBusyChanged?.call(true);
    final Result<List<OpdProviderOption>> hostsResult = await ref
        .read(opdRepositoryProvider)
        .listMeetingHosts();
    final Result<List<OpdProviderSchedule>> schedulesResult = await ref
        .read(opdRepositoryProvider)
        .listProviderSchedules();
    if (!mounted) {
      return;
    }
    hostsResult.when(
      success: (List<OpdProviderOption> hosts) {
        schedulesResult.when(
          success: (List<OpdProviderSchedule> schedules) {
            setState(() {
              _hosts = hosts;
              _schedules = schedules;
              _isLoadingHosts = false;
              _failure = null;
            });
          },
          failure: (AppFailure failure) {
            setState(() {
              _hosts = hosts;
              _isLoadingHosts = false;
              _failure = failure;
            });
          },
        );
      },
      failure: (AppFailure failure) {
        setState(() {
          _isLoadingHosts = false;
          _failure = failure;
        });
      },
    );
    widget.onBusyChanged?.call(false);
  }

  DateTime? _combineDateAndTime(DateTime? date, AppTimeValue? time) {
    if (date == null || time == null) {
      return null;
    }
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }
}
