import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/utils/app_display.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/presentation/controllers/opd_workspace_controller.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/features/patients/presentation/widgets/patient_form_fields.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_action_dialog_actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_provider_options.dart';

/// Opens the patient appointment quick-schedule dialog (mutating).
Future<bool?> showPatientAppointmentQuickDialog({
  required BuildContext context,
  required Patient patient,
  required PatientReferenceData referenceData,
}) {
  return showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PatientAppointmentQuickDialog(
      patient: patient,
      referenceData: referenceData,
    ),
  );
}

/// Schedule or adjust a patient appointment from registry/reception quick actions.
class PatientAppointmentQuickDialog extends ConsumerStatefulWidget {
  const PatientAppointmentQuickDialog({
    required this.patient,
    required this.referenceData,
    this.embedded = false,
    this.onSaved,
    this.onCancel,
    this.onBusyChanged,
    super.key,
  });

  final Patient patient;
  final PatientReferenceData referenceData;
  final bool embedded;
  final VoidCallback? onSaved;
  final VoidCallback? onCancel;
  final ValueChanged<bool>? onBusyChanged;

  @override
  ConsumerState<PatientAppointmentQuickDialog> createState() =>
      _PatientAppointmentQuickDialogState();
}

class _PatientAppointmentQuickDialogState
    extends ConsumerState<PatientAppointmentQuickDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _durationController = TextEditingController(
    text: '30',
  );
  final TextEditingController _reasonController = TextEditingController();
  DateTime? _date = DateTime.now();
  AppTimeValue? _startTime = const AppTimeValue(hour: 9, minute: 0);
  String? _facilityId;
  String? _providerId;
  String _status = 'SCHEDULED';
  bool _isLoadingProviders = false;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _facilityId = widget.patient.facilityId;
    // Defer controller writes until after the first frame so Riverpod does not
    // see a provider mutation during dialog mount/build.
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
    _reasonController.dispose();
    super.dispose();
  }

  bool get _isBusy => _isSaving || _isLoadingProviders;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final OpdWorkspaceState? workspace = ref
        .watch(opdWorkspaceControllerProvider)
        .asData
        ?.value
        .when(
          success: (OpdWorkspaceState state) => state,
          failure: (_) => null,
        );
    final List<OpdProviderOption> providers =
        workspace?.queueProviderOptions ?? const <OpdProviderOption>[];
    final List<OpdProviderSchedule> schedules =
        workspace?.providerSchedules ?? const <OpdProviderSchedule>[];

    final Widget form = AppFormShell(
      formKey: _formKey,
      enabled: !_isBusy,
      density: AppFormSectionDensity.compact,
      formStatus: appFormFailureStatus(
        context,
        _failure,
        messageBuilder: (AppFailure failure) => failure.displayMessage(l10n),
      ),
      children: <Widget>[
        if (widget.referenceData.facilities.length > 1)
          PatientFacilitySelectField(
            facilities: widget.referenceData.facilities,
            value: _facilityId,
            labelText: l10n.patientsFacilityLabel,
            enabled: !_isBusy,
            onChanged: (String? value) => setState(() => _facilityId = value),
          ),
        AppFormSection(
          density: AppFormSectionDensity.compact,
          children: <Widget>[
            AppDateField(
              value: _date,
              firstDate: DateTime.now().subtract(const Duration(days: 1)),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              labelText: l10n.patientsAppointmentDateLabel,
              pickerButtonLabel: l10n.patientsDatePickerAction,
              invalidDateMessage: l10n.appDateInvalidMessage,
              enabled: !_isBusy,
              isRequired: true,
              validator: AppValidators.requiredValue(l10n.validationRequired),
              onChanged: (DateTime? value) => setState(() => _date = value),
            ),
            AppResponsiveFieldRow(
              gap: AppResponsiveFieldRowGap.form,
              children: <Widget>[
                AppTimeField(
                  value: _startTime,
                  labelText: l10n.patientsAppointmentTimeLabel,
                  pickerButtonLabel: l10n.appTimePickerAction,
                  invalidTimeMessage: l10n.patientsTimeInvalidMessage,
                  hintText: l10n.patientsTimeHint,
                  hourLabelText: l10n.appTimeHourLabel,
                  minuteLabelText: l10n.appTimeMinuteLabel,
                  enabled: !_isBusy,
                  isRequired: true,
                  validator: (AppTimeValue? value) =>
                      value == null ? l10n.validationRequired : null,
                  onChanged: (AppTimeValue? value) {
                    setState(() => _startTime = value);
                  },
                ),
                AppTextField(
                  controller: _durationController,
                  labelText: l10n.patientsAppointmentDurationLabel,
                  enabled: !_isBusy,
                  isRequired: true,
                  keyboardType: TextInputType.number,
                  validator: _durationValidator(l10n),
                ),
              ],
            ),
          ],
        ),
        AppResponsiveFieldRow.two(
          left: AppSelectField<String>.searchable(
            value: _status,
            labelText: l10n.patientsAppointmentStatusLabel,
            enabled: !_isBusy,
            onChanged: (String? value) =>
                setState(() => _status = value ?? 'SCHEDULED'),
            options: _statusOptions(const <String>['SCHEDULED', 'CONFIRMED']),
          ),
          right: AppSelectField<String>.searchable(
            value: _providerId,
            labelText: l10n.patientsProviderLabel,
            helperText: l10n.patientsProviderOptionalHelper,
            enabled: !_isBusy,
            onChanged: (String? value) => setState(() => _providerId = value),
            options: opdProviderSelectOptions(
              providers: providers,
              schedules: schedules,
            ),
          ),
        ),
        AppTextField(
          controller: _reasonController,
          labelText: l10n.patientsAppointmentReasonLabel,
          enabled: !_isBusy,
          maxLines: 3,
        ),
      ],
    );
    final List<Widget> actions = clinicalActionDialogActions(
      context,
      l10n.patientsQuickAppointmentAction,
      _isSaving,
      _isBusy ? null : _submit,
      onCancel: _cancel,
      submitLeadingIcon: AppActionIcons.calendar,
    );
    if (widget.embedded) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          form,
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: actions,
          ),
        ],
      );
    }
    return AppDialog(
      title: Text(l10n.patientsAppointmentDialogTitle),
      icon: const Icon(AppActionIcons.calendar),
      scrollable: true,
      pinActionsToBottom: true,
      closeEnabled: !_isBusy,
      maxWidth: 720,
      content: form,
      actions: actions,
    );
  }

  void _cancel() {
    if (_isBusy) {
      return;
    }
    if (widget.embedded) {
      widget.onCancel?.call();
      return;
    }
    Navigator.of(context).pop(false);
  }

  Future<void> _loadFormOptions() async {
    setState(() => _isLoadingProviders = true);
    widget.onBusyChanged?.call(true);
    final AppFailure? failure = await ref
        .read(opdWorkspaceControllerProvider.notifier)
        .ensureAppointmentFormOptionsLoaded();
    if (!mounted) {
      return;
    }
    setState(() {
      _failure = failure;
      _isLoadingProviders = false;
    });
    widget.onBusyChanged?.call(false);
  }

  Future<void> _submit() async {
    if (_isBusy) {
      return;
    }
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }
    final DateTime? scheduledStart = _combineDateAndTime(_date, _startTime);
    if (scheduledStart == null) {
      setState(() => _failure = AppFailure.validation());
      return;
    }
    final int duration = int.parse(_durationController.text.trim());

    setState(() {
      _isSaving = true;
      _failure = null;
    });
    widget.onBusyChanged?.call(true);
    final AppFailure? failure = await ref
        .read(opdWorkspaceControllerProvider.notifier)
        .createAppointment(<String, Object?>{
          'tenant_id': widget.patient.tenantId,
          'facility_id': _facilityId,
          'patient_id': patientApiId(widget.patient),
          'provider_user_id': _providerId,
          'status': _status,
          'scheduled_start': scheduledStart.toUtc().toIso8601String(),
          'scheduled_end': scheduledStart
              .add(Duration(minutes: duration))
              .toUtc()
              .toIso8601String(),
          'reason': _reasonController.text.trim(),
        });
    if (!mounted) {
      return;
    }
    if (failure == null) {
      if (widget.embedded) {
        widget.onSaved?.call();
      } else {
        Navigator.of(context).pop(true);
      }
      return;
    }
    setState(() {
      _isSaving = false;
      _failure = failure;
    });
    widget.onBusyChanged?.call(false);
  }

  DateTime? _combineDateAndTime(DateTime? date, AppTimeValue? time) {
    if (date == null || time == null) {
      return null;
    }
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }
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

List<AppSelectOption<String>> _statusOptions(Iterable<String> values) {
  return <AppSelectOption<String>>[
    for (final String value in values)
      AppSelectOption<String>(value: value, label: AppDisplay.apiLabel(value)),
  ];
}
