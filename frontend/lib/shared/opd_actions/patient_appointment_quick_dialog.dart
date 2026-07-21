import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/utils/app_display.dart';
import 'package:hosspi_hms/features/opd/data/repositories/opd_repository_impl.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/presentation/controllers/opd_workspace_controller.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/features/patients/presentation/widgets/patient_form_fields.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_action_dialog_actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_encounter_flow.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_flow_actions_dialog.dart'
    show opdFrontDeskActionRequirement, showFlowActionsDialog;
import 'package:hosspi_hms/shared/opd_actions/opd_provider_options.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_reschedule_appointment_dialog.dart';

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
  bool _isCheckingEncounter = false;
  bool _isSaving = false;
  bool _isOpeningLinkedAction = false;
  bool _encounterCheckFailed = false;
  OpdFlowSummary? _openEncounter;
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

  bool get _isBusy =>
      _isSaving ||
      _isLoadingProviders ||
      _isCheckingEncounter ||
      _isOpeningLinkedAction;

  bool get _schedulingBlocked =>
      _openEncounter != null || _encounterCheckFailed;

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
        if (_openEncounter != null) ...<Widget>[
          AppFormInformationBanner(
            title: l10n.patientsAppointmentActiveEncounterTitle,
            message: l10n.patientsAppointmentActiveEncounterBody,
            variant: AppFormInformationVariant.warning,
            icon: AppActionIcons.warning,
          ),
          AppQuickActions(
            title: l10n.patientsQuickActionsTitle,
            permissionActions: <AppPermissionActionItem>[
              AppPermissionActionItem(
                requirement: opdFrontDeskActionRequirement,
                label: l10n.opdContinueEncounterAction,
                icon: AppActionIcons.start,
                variant: AppButtonVariant.primary,
                fullWidth: true,
                enabled: !_isBusy,
                isLoading: _isOpeningLinkedAction,
                onPressed: _openContinueEncounter,
              ),
              AppPermissionActionItem(
                requirement: opdFrontDeskActionRequirement,
                label: l10n.opdOpenActiveEncounterAction,
                icon: AppActionIcons.edit,
                fullWidth: true,
                enabled: !_isBusy,
                onPressed: _openEditEncounter,
              ),
              if (_resolveLinkedAppointment() != null)
                AppPermissionActionItem(
                  requirement: opdFrontDeskActionRequirement,
                  label: l10n.opdRescheduleAction,
                  icon: AppActionIcons.reschedule,
                  fullWidth: true,
                  enabled: !_isBusy,
                  onPressed: _openReschedule,
                ),
            ],
          ),
        ],
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
      _isBusy || _schedulingBlocked ? null : _submit,
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

  void _completeLinkedActionSuccess() {
    if (widget.embedded) {
      widget.onSaved?.call();
      return;
    }
    Navigator.of(context).pop(true);
  }

  OpdAppointment? _resolveLinkedAppointment() {
    final OpdFlowSummary? encounter = _openEncounter;
    if (encounter == null) {
      return null;
    }
    final OpdWorkspaceState? workspace = ref
        .read(opdWorkspaceControllerProvider)
        .asData
        ?.value
        .when(
          success: (OpdWorkspaceState value) => value,
          failure: (_) => null,
        );
    if (workspace == null) {
      return null;
    }
    final Set<String> appointmentIds = <String>{
      for (final String? value in <String?>[encounter.appointmentId])
        if (value != null && value.trim().isNotEmpty) value.trim().toUpperCase(),
    };
    if (appointmentIds.isEmpty) {
      return null;
    }
    for (final OpdAppointment appointment in workspace.appointments.items) {
      final Set<String> keys = <String>{
        for (final String? value in <String?>[
          appointment.id,
          appointment.apiId,
          appointment.publicId,
        ])
          if (value != null && value.trim().isNotEmpty)
            value.trim().toUpperCase(),
      };
      if (keys.any(appointmentIds.contains)) {
        return appointment;
      }
    }
    return null;
  }

  Future<void> _openContinueEncounter() async {
    final OpdFlowSummary? encounter = _openEncounter;
    if (encounter == null || _isBusy) {
      return;
    }
    setState(() => _isOpeningLinkedAction = true);
    widget.onBusyChanged?.call(true);
    final bool? changed = await showFlowActionsDialog(
      context: context,
      flow: encounter,
      allowBillingActions: false,
    );
    if (!mounted) {
      return;
    }
    if (changed == true) {
      _completeLinkedActionSuccess();
      return;
    }
    setState(() => _isOpeningLinkedAction = false);
    widget.onBusyChanged?.call(false);
  }

  Future<void> _openEditEncounter() async {
    if (_isBusy) {
      return;
    }
    setState(() => _isOpeningLinkedAction = true);
    widget.onBusyChanged?.call(true);
    final OpdAppointment? linkedAppointment = _resolveLinkedAppointment();
    final OpdWorkspaceState? workspace = ref
        .read(opdWorkspaceControllerProvider)
        .asData
        ?.value
        .when(
          success: (OpdWorkspaceState value) => value,
          failure: (_) => null,
        );
    final OpdEncounterDialogResult? dialogResult;
    if (workspace != null && linkedAppointment != null) {
      dialogResult = await showOpdEncounterDialog(
        context: context,
        dialog: buildOpdWorkspaceEncounterDialog(
          ref: ref,
          state: workspace,
          initialAppointment: linkedAppointment,
          initialAppointmentId: linkedAppointment.apiId,
          defaultArrivalMode: 'ONLINE_APPOINTMENT',
          defaultProviderId: linkedAppointment.providerUserId,
          includeEncounterLifecycleCallbacks: false,
        ),
      );
    } else {
      dialogResult = await showOpdEncounterDialog(
        context: context,
        dialog: buildPatientPinnedOpdEncounterDialog(
          ref: ref,
          patient: widget.patient,
        ),
      );
    }
    if (!mounted) {
      return;
    }
    if (dialogResult != null &&
        (dialogResult.action == OpdEncounterDialogAction.submit ||
            dialogResult.action == OpdEncounterDialogAction.cancelled ||
            dialogResult.action == OpdEncounterDialogAction.closed ||
            dialogResult.action == OpdEncounterDialogAction.continueWorkflow)) {
      _completeLinkedActionSuccess();
      return;
    }
    setState(() => _isOpeningLinkedAction = false);
    widget.onBusyChanged?.call(false);
  }

  Future<void> _openReschedule() async {
    final OpdAppointment? appointment = _resolveLinkedAppointment();
    if (appointment == null || _isBusy) {
      return;
    }
    setState(() => _isOpeningLinkedAction = true);
    widget.onBusyChanged?.call(true);
    final bool? changed = await showOpdRescheduleAppointmentDialog(
      context: context,
      appointment: appointment,
    );
    if (!mounted) {
      return;
    }
    if (changed == true) {
      _completeLinkedActionSuccess();
      return;
    }
    setState(() => _isOpeningLinkedAction = false);
    widget.onBusyChanged?.call(false);
  }

  Future<void> _loadFormOptions() async {
    setState(() => _isLoadingProviders = true);
    widget.onBusyChanged?.call(true);
    final AppFailure? optionsFailure = await ref
        .read(opdWorkspaceControllerProvider.notifier)
        .ensureAppointmentFormOptionsLoaded();
    final Result<OpdFlowSummary?> encounterResult =
        await _lookupOpenEncounter();
    if (!mounted) {
      return;
    }
    AppFailure? encounterFailure;
    OpdFlowSummary? openEncounter;
    encounterResult.when(
      success: (OpdFlowSummary? value) => openEncounter = value,
      failure: (AppFailure failure) => encounterFailure = failure,
    );
    setState(() {
      _failure = optionsFailure ?? encounterFailure;
      _openEncounter = openEncounter;
      _encounterCheckFailed = encounterFailure != null;
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
      _isCheckingEncounter = true;
      _failure = null;
      _encounterCheckFailed = false;
    });
    widget.onBusyChanged?.call(true);
    final Result<OpdFlowSummary?> encounterResult =
        await _lookupOpenEncounter();
    if (!mounted) {
      return;
    }
    AppFailure? encounterFailure;
    OpdFlowSummary? openEncounter;
    encounterResult.when(
      success: (OpdFlowSummary? value) => openEncounter = value,
      failure: (AppFailure failure) => encounterFailure = failure,
    );
    if (encounterFailure != null || openEncounter != null) {
      setState(() {
        _isCheckingEncounter = false;
        _encounterCheckFailed = encounterFailure != null;
        _openEncounter = openEncounter;
        _failure = encounterFailure;
      });
      widget.onBusyChanged?.call(false);
      return;
    }
    setState(() {
      _isCheckingEncounter = false;
      _isSaving = true;
    });
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

  Future<Result<OpdFlowSummary?>> _lookupOpenEncounter() async {
    final Set<String> patientKeys = <String>{
      for (final String? value in <String?>[
        widget.patient.id,
        widget.patient.publicId,
        widget.patient.effectiveIdentifier,
      ])
        if (value != null && value.trim().isNotEmpty)
          value.trim().toUpperCase(),
    };
    final OpdWorkspaceState? workspace = ref
        .read(opdWorkspaceControllerProvider)
        .asData
        ?.value
        .when(
          success: (OpdWorkspaceState value) => value,
          failure: (_) => null,
        );
    final Iterable<OpdFlowSummary> localFlows = <OpdFlowSummary>[
      ...?workspace?.flows.items,
      ...?workspace?.triageQueue.items,
    ];
    final OpdFlowSummary? localMatch = _matchingOpenEncounter(
      localFlows,
      patientKeys,
    );
    if (localMatch != null) {
      return Result<OpdFlowSummary?>.success(localMatch);
    }

    final String search = widget.patient.publicId?.trim().isNotEmpty == true
        ? widget.patient.publicId!.trim()
        : widget.patient.id.trim();
    final Result<AppPage<OpdFlowSummary>> result = await ref
        .read(opdRepositoryProvider)
        .listOpdFlows(
          OpdFlowQuery(
            search: search,
            pageRequest: const AppPageRequest(pageSize: 25),
          ),
        );
    return result.when(
      success: (AppPage<OpdFlowSummary> page) =>
          Result<OpdFlowSummary?>.success(
            _matchingOpenEncounter(page.items, patientKeys),
          ),
      failure: (AppFailure failure) => Result<OpdFlowSummary?>.failure(failure),
    );
  }

  OpdFlowSummary? _matchingOpenEncounter(
    Iterable<OpdFlowSummary> flows,
    Set<String> patientKeys,
  ) {
    for (final OpdFlowSummary flow in flows) {
      if (flow.isTerminal || isOpdTerminalStatus(flow.status ?? flow.stage)) {
        continue;
      }
      final Set<String> flowKeys = <String>{
        for (final String? value in <String?>[
          flow.patientId,
          flow.patientIdentifier,
        ])
          if (value != null && value.trim().isNotEmpty)
            value.trim().toUpperCase(),
      };
      if (flowKeys.any(patientKeys.contains)) {
        return flow;
      }
    }
    return null;
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
