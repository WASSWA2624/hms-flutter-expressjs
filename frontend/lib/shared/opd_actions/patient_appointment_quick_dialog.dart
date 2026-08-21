import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/utils/app_display.dart';
import 'package:hosspi_hms/features/opd/data/repositories/opd_repository_impl.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/presentation/controllers/opd_workspace_controller.dart';
import 'package:hosspi_hms/features/patients/data/repositories/patient_repository_impl.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/features/patients/presentation/widgets/patient_form_fields.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_action_dialog_actions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/opd_actions/appointment_window.dart';
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
    this.allowClinicalActions = true,
    this.allowVitalsActions = true,
    super.key,
  });

  final Patient patient;
  final PatientReferenceData referenceData;
  final bool embedded;
  final VoidCallback? onSaved;
  final VoidCallback? onCancel;
  final ValueChanged<bool>? onBusyChanged;

  /// When false, Clinical notes and clinician-only quick actions are omitted.
  final bool allowClinicalActions;

  /// When false, Record/Edit vitals quick actions are omitted.
  final bool allowVitalsActions;

  @override
  ConsumerState<PatientAppointmentQuickDialog> createState() =>
      PatientAppointmentQuickDialogState();
}

class PatientAppointmentQuickDialogState
    extends ConsumerState<PatientAppointmentQuickDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final GlobalKey<State<AppPhoneField>> _phoneFieldKey =
      GlobalKey<State<AppPhoneField>>();
  final TextEditingController _durationController = TextEditingController(
    text: '30',
  );
  final TextEditingController _contactPhoneController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  DateTime? _date = DateTime.now();
  AppTimeValue? _startTime = const AppTimeValue(hour: 9, minute: 0);
  AppTimeValue? _endTime = const AppTimeValue(hour: 9, minute: 30);
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

  bool get isSaving => _isSaving;

  bool get isBusy => _isBusy;

  bool get canSubmit => !_isBusy && !_schedulingBlocked;

  @override
  void initState() {
    super.initState();
    _facilityId = widget.patient.facilityId;
    // Reception follows up on the number already on file; staff can correct it
    // here and the patient record picks up the correction on submit.
    _contactPhoneController.text = widget.patient.primaryPhone?.trim() ?? '';
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
    _contactPhoneController.dispose();
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
        AppPhoneField(
          key: _phoneFieldKey,
          controller: _contactPhoneController,
          labelText: l10n.patientsAppointmentContactPhoneLabel,
          countryLabelText: l10n.appPhoneCountryLabel,
          countrySearchLabelText: l10n.appPhoneCountrySearchLabel,
          countryNoResultsText: l10n.appPhoneCountryNoResults,
          numberLabelText: l10n.appPhoneNumberLabel,
          numberHintText: l10n.appPhoneNumberHint,
          invalidPhoneMessage: l10n.appPhoneInvalidMessage,
          helperText: l10n.patientsAppointmentContactPhoneHelper,
          enabled: !_isBusy,
          isRequired: true,
          requiredMessage: l10n.validationRequired,
          textInputAction: TextInputAction.next,
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
            enabled: !_isBusy,
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
            enabled: !_isBusy,
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
            enabled: !_isBusy,
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
            enabled: !_isBusy,
            keyboardType: TextInputType.number,
            validator: appointmentDurationValidator(
              l10n: l10n,
              startTime: () => _startTime,
              endTime: () => _endTime,
            ),
            onChanged: _handleDurationChanged,
          ),
        ),
        AppResponsiveFieldRow.two(
          left: AppSelectField<String>.searchable(
            value: _status,
            labelText: l10n.patientsAppointmentStatusLabel,
            hintText: l10n.appSelectSearchHint,
            emptyResultsText: l10n.appSelectNoResults,
            enabled: !_isBusy,
            onChanged: (String? value) =>
                setState(() => _status = value ?? 'SCHEDULED'),
            options: _statusOptions(const <String>['SCHEDULED', 'CONFIRMED']),
          ),
          right: AppSelectField<String>.searchable(
            value: _providerId,
            labelText: l10n.patientsProviderLabel,
            hintText: l10n.receptionStaffHostSearchHint,
            helperText: l10n.patientsProviderOptionalHelper,
            emptyResultsText: l10n.appSelectNoResults,
            enabled: !_isBusy,
            isLoading: _isLoadingProviders,
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
    if (widget.embedded) {
      return form;
    }
    return AppDialog(
      title: Text(l10n.patientsAppointmentDialogTitle),
      icon: const Icon(AppActionIcons.calendar),
      scrollable: true,
      pinActionsToBottom: true,
      closeEnabled: !_isBusy,
      maxWidth: 720,
      content: form,
      actions: clinicalActionDialogActions(
        context,
        l10n.patientsQuickAppointmentAction,
        _isSaving,
        _isBusy || _schedulingBlocked ? null : () => unawaited(submit()),
        onCancel: _cancel,
        submitLeadingIcon: AppActionIcons.calendar,
      ),
    );
  }

  /// Validates and creates the patient appointment.
  ///
  /// Returns `true` on success (and invokes [PatientAppointmentQuickDialog.onSaved]
  /// when provided). Returns `false` on validation or API failure.
  Future<bool> submit() async {
    if (_isBusy) {
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

    setState(() {
      _isCheckingEncounter = true;
      _failure = null;
      _encounterCheckFailed = false;
    });
    widget.onBusyChanged?.call(true);
    final Result<OpdFlowSummary?> encounterResult =
        await _lookupOpenEncounter();
    if (!mounted) {
      return false;
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
      return false;
    }
    setState(() {
      _isCheckingEncounter = false;
      _isSaving = true;
    });
    final AppFailure? contactFailure = await _syncContactPhone();
    if (!mounted) {
      return false;
    }
    if (contactFailure != null) {
      setState(() {
        _isSaving = false;
        _failure = contactFailure;
      });
      widget.onBusyChanged?.call(false);
      return false;
    }
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
      return false;
    }
    if (failure == null) {
      if (widget.embedded) {
        widget.onSaved?.call();
      } else {
        Navigator.of(context).pop(true);
      }
      return true;
    }
    setState(() {
      _isSaving = false;
      _failure = failure;
    });
    widget.onBusyChanged?.call(false);
    return false;
  }

  /// Writes a corrected contact number back to the patient record.
  ///
  /// Reception calls this number to confirm or move the appointment, so a
  /// correction typed here has to outlive the dialog. Returns the failure when
  /// the write is rejected, which keeps the booking from going ahead with a
  /// number nobody can reach.
  Future<AppFailure?> _syncContactPhone() async {
    final String phone = _contactPhoneController.text.trim();
    if (phone.isEmpty || phone == (widget.patient.primaryPhone?.trim() ?? '')) {
      return null;
    }
    final Result<Patient> result = await ref
        .read(patientRepositoryProvider)
        .updatePatient(patientApiId(widget.patient), <String, Object?>{
          'primary_phone': phone,
        });
    return result.when(
      success: (_) => null,
      failure: (AppFailure failure) => failure,
    );
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
      allowVitalsActions: widget.allowVitalsActions,
      allowClinicalActions: widget.allowClinicalActions,
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

List<AppSelectOption<String>> _statusOptions(Iterable<String> values) {
  return <AppSelectOption<String>>[
    for (final String value in values)
      AppSelectOption<String>(value: value, label: AppDisplay.apiLabel(value)),
  ];
}
