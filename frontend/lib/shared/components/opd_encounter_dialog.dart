import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/utils/app_display.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/presentation/controllers/opd_encounter_dialog_controller.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_request_billing_state.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_action_dialog_actions.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/components/app_currency_amount_field.dart';
import 'package:hosspi_hms/shared/components/app_dialog.dart';
import 'package:hosspi_hms/shared/components/app_form_information_banner.dart';
import 'package:hosspi_hms/shared/components/app_loading_indicator.dart';
import 'package:hosspi_hms/shared/components/app_patient_details.dart';
import 'package:hosspi_hms/shared/components/app_select_field.dart';
import 'package:hosspi_hms/shared/components/app_switch_field.dart';
import 'package:hosspi_hms/shared/components/app_tab_strip.dart';
import 'package:hosspi_hms/shared/components/app_text_field.dart';
import 'package:hosspi_hms/shared/components/app_triage_components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/app_form_section.dart';
import 'package:hosspi_hms/shared/forms/app_form_shell.dart';
import 'package:hosspi_hms/shared/forms/app_responsive_field_row.dart';
import 'package:hosspi_hms/shared/icons/app_action_icons.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_action_context.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_billing_state.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_provider_options.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_status_display.dart';
import 'package:hosspi_hms/shared/patient_actions/patient_actions.dart';

const IconData opdEncounterIcon = AppActionIcons.personAdd;

const AccessRequirement opdEncounterPermissionRequirement = AccessRequirement(
  anyRoles: <AppRole>[
    AppRole.platformAdmin,
    AppRole.tenantAdmin,
    AppRole.facilityAdmin,
    AppRole.receptionist,
    AppRole.nurse,
    AppRole.doctor,
    AppRole.operations,
    AppRole.ambulanceOperator,
  ],
  activeModules: <String>['scheduling-queue'],
);

enum _WalkInPatientMode { existing, appointment, newPatient }

class _WalkInModeSelector extends StatelessWidget {
  const _WalkInModeSelector({
    required this.value,
    required this.enabled,
    required this.existingLabel,
    required this.appointmentLabel,
    required this.newPatientLabel,
    required this.showNewPatient,
    required this.onChanged,
  });

  final _WalkInPatientMode value;
  final bool enabled;
  final String existingLabel;
  final String appointmentLabel;
  final String newPatientLabel;
  final bool showNewPatient;
  final ValueChanged<_WalkInPatientMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final Widget strip = AppTabStrip(
      tabs: <AppTabItem>[
        AppTabItem(
          id: _WalkInPatientMode.existing.name,
          icon: AppActionIcons.person,
          label: existingLabel,
        ),
        AppTabItem(
          id: _WalkInPatientMode.appointment.name,
          icon: AppActionIcons.calendar,
          label: appointmentLabel,
        ),
        if (showNewPatient)
          AppTabItem(
            id: _WalkInPatientMode.newPatient.name,
            icon: AppActionIcons.personAdd,
            label: newPatientLabel,
          ),
      ],
      selectedId: value.name,
      onTabTapped: (String id) {
        if (!enabled) {
          return;
        }
        onChanged(_WalkInPatientMode.values.byName(id));
      },
    );

    if (enabled) {
      return strip;
    }
    return Opacity(opacity: 0.6, child: strip);
  }
}

typedef OpdEncounterPayloadSubmit =
    Future<Result<OpdFlowDetail>> Function(Map<String, Object?> payload);

const List<String> _opdEncounterCancelReasonCodes = <String>[
  'PATIENT_LEFT',
  'DUPLICATE_ENCOUNTER',
  'ENTERED_IN_ERROR',
  'PATIENT_ALREADY_SEEN',
  'OTHER',
];

enum OpdEncounterDialogAction { submit, continueWorkflow, closed, cancelled }

@immutable
final class OpdEncounterDialogResult {
  const OpdEncounterDialogResult({
    this.action = OpdEncounterDialogAction.submit,
    this.flow,
  });

  final OpdEncounterDialogAction action;
  final OpdFlowSummary? flow;
}

class OpdEncounterDialog extends ConsumerStatefulWidget {
  const OpdEncounterDialog({
    required this.providerSchedules,
    required this.appointments,
    this.activeFlows = const <OpdFlowSummary>[],
    this.initialPatientId,
    this.initialPatient,
    this.initialAppointmentId,
    this.initialAppointment,
    this.defaultArrivalMode = 'WALK_IN',
    this.defaultProviderId,
    this.onSuccess,
    this.onExistingActiveEncounter,
    this.onCancelEncounter,
    this.onCloseEncounter,
    required this.onSubmit,
    super.key,
  });

  final List<OpdProviderSchedule> providerSchedules;
  final List<OpdAppointment> appointments;
  final List<OpdFlowSummary> activeFlows;
  final String? initialPatientId;
  final Patient? initialPatient;
  final String? initialAppointmentId;
  final OpdAppointment? initialAppointment;
  final String defaultArrivalMode;
  final String? defaultProviderId;
  final VoidCallback? onSuccess;
  final ValueChanged<OpdFlowSummary>? onExistingActiveEncounter;
  final Future<Result<OpdFlowDetail>> Function(
    String flowId,
    Map<String, Object?> payload,
  )?
  onCancelEncounter;
  final Future<Result<OpdFlowDetail>> Function(
    String flowId,
    Map<String, Object?> payload,
  )?
  onCloseEncounter;
  final OpdEncounterPayloadSubmit onSubmit;

  @override
  ConsumerState<OpdEncounterDialog> createState() => _OpdEncounterDialogState();
}

class _OpdEncounterDialogState extends ConsumerState<OpdEncounterDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final GlobalKey<RegisterNewPatientFormState> _newPatientFormKey =
      GlobalKey<RegisterNewPatientFormState>();
  late final TextEditingController _feeController;
  late final TextEditingController _notesController;
  List<Patient> _patientOptions = const <Patient>[];
  List<OpdAppointment> _appointmentOptions = const <OpdAppointment>[];
  List<OpdProviderOption> _providerOptions = const <OpdProviderOption>[];
  List<OpdProviderSchedule> _providerSchedules = const <OpdProviderSchedule>[];
  PatientReferenceData _patientReferenceData = const PatientReferenceData();
  _WalkInPatientMode _patientMode = _WalkInPatientMode.existing;
  bool _isLoadingPatients = false;
  bool _isLoadingAppointments = false;
  bool _isLoadingProviders = false;
  bool _isLoadingPatientReferenceData = false;
  bool _isLoadingBillingDefaults = false;
  bool _isResolvingActiveEncounter = false;
  String? _patientId;
  String? _appointmentId;
  String? _providerId;
  OpdFlowSummary? _activeEncounter;
  String _currency = appDefaultCurrencyCode;
  String _arrivalMode = 'WALK_IN';
  String _emergencySeverity = 'HIGH';
  String? _triageLevel;
  bool _requireConsultationPayment = true;
  bool _forceNewEncounter = false;
  bool _isSaving = false;
  bool _hasLookupFailure = false;
  AppFailure? _failure;
  int _activeEncounterLookupToken = 0;
  bool _appliedInitialContext = false;
  OpdBillingDefaults? _billingDefaults;
  bool _lockArrivalMode = false;
  ClinicalRequestPayerContext? _payerContext;
  ClinicalRequestBillingLineItem? _resolvedConsultationLine;
  bool _engineFeeResolved = false;

  List<AppSelectOption<String>>? _cachedPatientSelectOptions;
  List<Patient>? _cachedPatientSelectSource;
  List<AppSelectOption<String>>? _cachedAppointmentSelectOptions;
  List<OpdAppointment>? _cachedAppointmentSelectSource;

  List<AppSelectOption<String>> _patientSelectOptions() {
    if (identical(_cachedPatientSelectSource, _patientOptions) &&
        _cachedPatientSelectOptions != null) {
      return _cachedPatientSelectOptions!;
    }
    _cachedPatientSelectSource = _patientOptions;
    _cachedPatientSelectOptions = _patientOptions
        .map(_patientSelectOption)
        .whereType<AppSelectOption<String>>()
        .toList(growable: false);
    return _cachedPatientSelectOptions!;
  }

  List<AppSelectOption<String>> _appointmentSelectOptions() {
    if (identical(_cachedAppointmentSelectSource, _appointmentOptions) &&
        _cachedAppointmentSelectOptions != null) {
      return _cachedAppointmentSelectOptions!;
    }
    _cachedAppointmentSelectSource = _appointmentOptions;
    _cachedAppointmentSelectOptions = _appointmentOptions
        .map(_appointmentSelectOption)
        .whereType<AppSelectOption<String>>()
        .toList(growable: false);
    return _cachedAppointmentSelectOptions!;
  }

  bool get _pinPatientContext =>
      widget.initialPatient != null || _isNonEmpty(widget.initialPatientId);

  bool get _pinAppointmentContext =>
      widget.initialAppointment != null ||
      _isNonEmpty(widget.initialAppointmentId);

  bool get _showPatientSection =>
      !_pinPatientContext && !_pinAppointmentContext;

  bool get _isInitialLoading =>
      _isLoadingPatients ||
      _isLoadingAppointments ||
      _isLoadingProviders ||
      _isLoadingPatientReferenceData ||
      _isLoadingBillingDefaults;

  bool get _showLoadingOverlay =>
      _isInitialLoading ||
      (_isResolvingActiveEncounter && _activeEncounter == null);

  /// Blocks dismiss/close and competing footer actions while initial option
  /// loads or a mutation is in flight.
  bool get _blocksDismiss =>
      _isSaving ||
      _isInitialLoading ||
      _isResolvingActiveEncounter ||
      (_newPatientFormKey.currentState?.isCheckingDuplicates ?? false);

  @override
  void initState() {
    super.initState();
    _feeController = TextEditingController();
    _notesController = TextEditingController();
    _patientOptions = <Patient>[
      if (widget.initialPatient != null) widget.initialPatient!,
    ];
    _appointmentOptions = _eligibleAppointmentOptions(<OpdAppointment>[
      ...widget.appointments,
      if (widget.initialAppointment != null) widget.initialAppointment!,
    ]);
    _providerSchedules = widget.providerSchedules;
    _patientId = _initialPatientApiId();
    _appointmentId = _initialAppointmentApiId();
    _providerId =
        widget.defaultProviderId ?? widget.initialAppointment?.providerUserId;
    _arrivalMode =
        widget.defaultArrivalMode.toUpperCase() == 'ONLINE_APPOINTMENT'
        ? 'WALK_IN'
        : widget.defaultArrivalMode.toUpperCase();
    if (_appointmentId != null) {
      _patientMode = _WalkInPatientMode.appointment;
      _arrivalMode = 'ONLINE_APPOINTMENT';
    } else if (_patientId != null) {
      _patientMode = _WalkInPatientMode.existing;
    }
    _loadInitialData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _applyInitialContext();
        _refreshActiveEncounterForSelection();
      }
    });
  }

  void _loadInitialData() {
    if (_showPatientSection ||
        (widget.initialPatient == null &&
            _isNonEmpty(widget.initialPatientId))) {
      unawaited(_loadPatientOptions());
    }
    if (_showPatientSection ||
        (widget.initialAppointment == null &&
            _isNonEmpty(widget.initialAppointmentId))) {
      unawaited(_loadAppointmentOptions());
    }
    unawaited(_loadProviderOptions());
    if (_showPatientSection) {
      unawaited(_loadPatientReferenceData());
    }
    unawaited(_loadBillingDefaults());
  }

  void _retryInitialData() {
    setState(() {
      _failure = null;
      _hasLookupFailure = false;
    });
    _loadInitialData();
    _refreshActiveEncounterForSelection();
  }

  @override
  void dispose() {
    _feeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String? _initialPatientApiId() {
    return _firstNonEmptyText(<String?>[
      widget.initialPatient?.publicId,
      widget.initialPatient?.id,
      widget.initialPatientId,
    ]);
  }

  String? _initialAppointmentApiId() {
    return _firstNonEmptyText(<String?>[
      widget.initialAppointment?.publicId,
      widget.initialAppointment?.id,
      widget.initialAppointmentId,
    ]);
  }

  void _applyInitialContext({bool force = false}) {
    if (_appliedInitialContext && !force) {
      return;
    }
    if (_pinAppointmentContext) {
      final OpdAppointment? appointment = _appointmentByApiId(_appointmentId);
      setState(() {
        _appliedInitialContext = true;
        _patientMode = _WalkInPatientMode.appointment;
        if (appointment != null) {
          _appointmentId = appointment.apiId;
          _providerId = appointment.providerUserId ?? _providerId;
        }
        _arrivalMode = 'ONLINE_APPOINTMENT';
        _applyProviderDefaultsToState(_providerId);
      });
      return;
    }
    if (_pinPatientContext) {
      setState(() {
        _appliedInitialContext = true;
        _patientMode = _WalkInPatientMode.existing;
        _patientId = _initialPatientApiId();
      });
      return;
    }
    if (widget.initialPatient == null &&
        !_isNonEmpty(widget.initialPatientId) &&
        widget.initialAppointment == null &&
        !_isNonEmpty(widget.initialAppointmentId)) {
      _appliedInitialContext = true;
      return;
    }

    final OpdAppointment? appointment = _appointmentByApiId(_appointmentId);
    if (appointment != null) {
      setState(() {
        _appliedInitialContext = true;
        _patientMode = _WalkInPatientMode.appointment;
        _appointmentId = appointment.apiId;
        _providerId = appointment.providerUserId ?? _providerId;
        _arrivalMode = 'ONLINE_APPOINTMENT';
        _applyProviderDefaultsToState(_providerId);
      });
      return;
    }

    final Patient? patient = _patientByApiId(_patientId);
    if (patient == null && !_isNonEmpty(_patientId)) {
      _appliedInitialContext = true;
      return;
    }

    final List<OpdAppointment> patientAppointments =
        _eligibleAppointmentsForPatient(patient);
    setState(() {
      _appliedInitialContext = true;
      if (patientAppointments.isEmpty) {
        _patientMode = _WalkInPatientMode.existing;
        _patientId =
            _firstNonEmptyText(<String?>[patient?.publicId, patient?.id]) ??
            _patientId;
        return;
      }

      _patientMode = _WalkInPatientMode.appointment;
      _arrivalMode = 'ONLINE_APPOINTMENT';
      if (patientAppointments.length == 1) {
        final OpdAppointment match = patientAppointments.single;
        _appointmentId = match.apiId;
        _providerId = match.providerUserId ?? _providerId;
        _applyProviderDefaultsToState(_providerId);
      } else {
        _appointmentId = null;
      }
    });
  }

  List<OpdAppointment> _eligibleAppointmentsForPatient(Patient? patient) {
    final Set<String> patientKeys =
        <String?>[
              patient?.id,
              patient?.publicId,
              patient?.effectiveIdentifier,
              widget.initialPatientId,
            ]
            .whereType<String>()
            .map((String value) => value.trim().toUpperCase())
            .where((String value) => value.isNotEmpty)
            .toSet();
    final Set<String> phoneKeys = <String?>[patient?.primaryPhone]
        .whereType<String>()
        .map((String value) => value.trim().toUpperCase())
        .where((String value) => value.isNotEmpty)
        .toSet();

    return _appointmentOptions
        .where((OpdAppointment appointment) {
          final Set<String> appointmentPatientKeys =
              <String?>[appointment.patientId, appointment.patientIdentifier]
                  .whereType<String>()
                  .map((String value) => value.trim().toUpperCase())
                  .where((String value) => value.isNotEmpty)
                  .toSet();
          final bool matchesPatient =
              patientKeys.isNotEmpty &&
              appointmentPatientKeys.any(patientKeys.contains);
          final bool matchesPhone =
              phoneKeys.isNotEmpty &&
              phoneKeys.contains(
                (appointment.patientPhone ?? '').trim().toUpperCase(),
              );
          return matchesPatient || matchesPhone;
        })
        .toList(growable: false);
  }

  List<Patient> _mergePatients(Iterable<Patient> patients) {
    final Map<String, Patient> byId = <String, Patient>{};
    for (final Patient patient in patients) {
      final String key =
          _firstNonEmptyText(<String?>[patient.publicId, patient.id]) ?? '';
      if (key.isEmpty) {
        continue;
      }
      byId[key] = patient;
    }
    return byId.values.toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bool hasActiveEncounter = _activeEncounter != null;
    final bool isNewPatientMode = _patientMode == _WalkInPatientMode.newPatient;
    final String primaryActionLabel = isNewPatientMode
        ? (_newPatientFormKey.currentState?.duplicateWarningAccepted == true
              ? l10n.patientsRegisterAnywayAction
              : l10n.opdCreatePatientAction)
        : hasActiveEncounter && !_forceNewEncounter
        ? l10n.opdOpenActiveEncounterAction
        : l10n.opdStartEncounterAction;
    final IconData primaryActionIcon = isNewPatientMode
        ? AppActionIcons.add
        : hasActiveEncounter && !_forceNewEncounter
        ? AppActionIcons.edit
        : AppActionIcons.start;

    return AppDialog(
      title: Text(l10n.opdWalkInDialogTitle),
      icon: const Icon(opdEncounterIcon),
      pinActionsToBottom: true,
      closeEnabled: !_blocksDismiss,
      maxWidth: 880,
      content: _dialogBody(l10n, hasActiveEncounter),
      actions: <Widget>[
        if (hasActiveEncounter) ...<Widget>[
          if (!_forceNewEncounter)
            AppButton.secondary(
              label: l10n.opdStartNewEncounterAction,
              leadingIcon: AppActionIcons.add,
              enabled: !_blocksDismiss,
              onPressed: _promptStartNewEncounter,
            ),
          AppButton.secondary(
            label: l10n.opdContinueEncounterAction,
            leadingIcon: AppActionIcons.start,
            enabled: !_blocksDismiss,
            onPressed: _continueWorkflow,
          ),
          if (widget.onCloseEncounter != null)
            AppButton.secondary(
              label: l10n.opdCloseEncounterAction,
              leadingIcon: AppActionIcons.success,
              enabled: !_blocksDismiss,
              onPressed: _promptCloseEncounter,
            ),
          if (widget.onCancelEncounter != null)
            AppButton.secondary(
              label: l10n.opdCancelEncounterAction,
              leadingIcon: AppActionIcons.delete,
              enabled: !_blocksDismiss,
              onPressed: _promptCancelEncounter,
            ),
        ],
        AppButton.close(
          label: l10n.commonCancelActionLabel,
          leadingIcon: AppActionIcons.cancel,
          enabled: !_blocksDismiss,
          onPressed: _blocksDismiss
              ? null
              : () => Navigator.of(context).maybePop(),
        ),
        AppButton.primary(
          label: primaryActionLabel,
          leadingIcon: primaryActionIcon,
          enabled:
              !_blocksDismiss &&
              (!_isResolvingActiveEncounter || _activeEncounter != null),
          isLoading: _isSaving,
          onPressed: _submit,
        ),
      ],
    );
  }

  Widget _dialogBody(AppLocalizations l10n, bool hasActiveEncounter) {
    final ThemeData theme = Theme.of(context);
    final Widget form = SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: AppFormShell(
        formKey: _formKey,
        enabled: !_blocksDismiss,
        formStatus: appFormFailureStatus(context, _failure),
        children: <Widget>[
          if (_hasLookupFailure)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: AppButton.secondary(
                label: l10n.commonRetryActionLabel,
                leadingIcon: AppActionIcons.refresh,
                enabled: !_blocksDismiss,
                onPressed: _blocksDismiss ? null : _retryInitialData,
              ),
            ),
          if (_shouldShowActiveEncounterNotice()) _activeEncounterNotice(l10n),
          if (_showPatientSection) ...<Widget>[
            _WalkInModeSelector(
              value: _patientMode,
              enabled: !_blocksDismiss && !hasActiveEncounter,
              existingLabel: l10n.opdExistingPatientModeLabel,
              appointmentLabel: l10n.opdAppointmentPatientModeLabel,
              newPatientLabel: l10n.opdNewPatientModeLabel,
              showNewPatient: ref
                  .watch(appAccessPolicyProvider)
                  .grants(AppPermissions.patientWrite),
              onChanged: _setPatientMode,
            ),
            _patientModeContent(l10n),
          ] else if (_pinPatientContext)
            _knownPatientSummary(l10n),
          ..._arrivalFields(l10n),
          AppResponsiveFieldRow.two(
            left: _providerField(l10n),
            right: _consultationFeeField(l10n),
            breakpoint: 760,
            gap: AppResponsiveFieldRowGap.form,
          ),
          ..._billingStatusFields(l10n),
        ],
      ),
    );

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        ExcludeSemantics(
          excluding: _showLoadingOverlay,
          child: AbsorbPointer(absorbing: _showLoadingOverlay, child: form),
        ),
        if (_showLoadingOverlay)
          Positioned.fill(
            child: ColoredBox(
              key: const ValueKey<String>('opd-encounter-loading-overlay'),
              color: theme.colorScheme.surface.withValues(alpha: 0.94),
              child: AppLoadingIndicator(
                title: l10n.opdLoadingTitle,
                body: l10n.opdLoadingBody,
                expand: true,
                semanticLabel: l10n.opdLoadingTitle,
              ),
            ),
          ),
      ],
    );
  }

  List<Widget> _arrivalFields(AppLocalizations l10n) {
    if (_patientMode == _WalkInPatientMode.appointment ||
        _pinPatientContext ||
        _pinAppointmentContext) {
      return const <Widget>[];
    }
    return <Widget>[
      AppSelectField<String>.searchable(
        value: _arrivalMode,
        labelText: _opdRequiredFieldLabel(l10n, l10n.opdArrivalModeLabel),
        semanticLabel: _opdRequiredFieldLabel(l10n, l10n.opdArrivalModeLabel),
        helperText: _lockArrivalMode
            ? l10n.opdEncounterArrivalModeLockedHelper
            : null,
        enabled: !_blocksDismiss && !_lockArrivalMode,
        onChanged: (String? value) {
          setState(() {
            _arrivalMode = value ?? 'WALK_IN';
          });
        },
        options: _statusOptions(_arrivalModeOptions),
      ),
      if (_arrivalMode == 'EMERGENCY') ...<Widget>[
        AppResponsiveFieldRow(
          gap: AppResponsiveFieldRowGap.form,
          children: <Widget>[
            AppSelectField<String>.searchable(
              value: _emergencySeverity,
              labelText: _opdRequiredFieldLabel(
                l10n,
                l10n.opdEmergencySeverityLabel,
              ),
              semanticLabel: _opdRequiredFieldLabel(
                l10n,
                l10n.opdEmergencySeverityLabel,
              ),
              enabled: !_blocksDismiss,
              onChanged: (String? value) {
                setState(() {
                  _emergencySeverity = value ?? _emergencySeverity;
                });
              },
              options: _statusOptions(_emergencySeverityOptions),
            ),
            AppTriageUrgencyField(
              value: _triageLevel,
              labelText: _opdOptionalFieldLabel(l10n, l10n.opdTriageLevelLabel),
              semanticLabel: _opdOptionalFieldLabel(
                l10n,
                l10n.opdTriageLevelLabel,
              ),
              enabled: !_blocksDismiss,
              onChanged: (String? value) {
                setState(() {
                  _triageLevel = value;
                });
              },
              options: _triageLevelFieldOptions(),
            ),
          ],
        ),
        AppTextField(
          controller: _notesController,
          labelText: _opdOptionalFieldLabel(l10n, l10n.opdNotesLabel),
          enabled: !_blocksDismiss,
          maxLines: 3,
        ),
      ],
    ];
  }

  Widget _providerField(AppLocalizations l10n) {
    return _ProviderSelectField(
      value: _providerId,
      providers: _providerOptionsForDialog(),
      schedules: _providerSchedules,
      labelText: _opdOptionalFieldLabel(l10n, l10n.opdSearchProviderLabel),
      helperText: l10n.opdSearchProviderHelper,
      emptyHelperText: l10n.opdNoProvidersHelper,
      enabled: !_blocksDismiss,
      onChanged: (String? value) {
        setState(() {
          _providerId = value;
          _applyProviderDefaultsToState(value, overwrite: true);
        });
      },
    );
  }

  Widget _consultationFeeField(AppLocalizations l10n) {
    return AppCurrencyAmountField(
      amountController: _feeController,
      currency: _currency,
      amountLabelText: _opdOptionalFieldLabel(
        l10n,
        l10n.opdConsultationFeeLabel,
      ),
      currencyLabelText: _opdRequiredFieldLabel(l10n, l10n.opdCurrencyLabel),
      enabled: !_blocksDismiss,
      onCurrencyChanged: (String? value) {
        setState(() {
          _currency = value ?? appDefaultCurrencyCode;
        });
      },
    );
  }

  List<Widget> _billingStatusFields(AppLocalizations l10n) {
    final OpdFlowSummary? activeEncounter = _activeEncounter;
    final bool billingAlreadyPaid =
        activeEncounter != null &&
        opdFlowBillingState(activeEncounter) == OpdBillingState.paid;
    final Locale locale = Localizations.localeOf(context);
    String formatShare(num? value) => value == null
        ? l10n.profileUnknownValue
        : AppFormatters.currency(value, locale, currencyCode: _currency);

    return <Widget>[
      if (billingAlreadyPaid)
        AppFormInformationBanner.message(
          title: l10n.opdPaymentStatusLabel,
          message: l10n.opdEncounterBillingPaidBanner,
        ),
      if (_engineFeeResolved)
        AppFormInformationBanner.message(
          title: l10n.opdBillingSectionTitle,
          message: _payerContext?.insured == true
              ? l10n.opdEngineResolvedFeeInsuredHint(
                  _payerContext?.payerLabel ?? l10n.profileUnknownValue,
                  formatShare(_resolvedConsultationLine?.patientShare),
                  formatShare(_resolvedConsultationLine?.insurerShare),
                )
              : l10n.opdEngineResolvedFeeHint,
        ),
      AppSwitchField(
        title: l10n.opdPaymentRequiredLabel,
        value: _requireConsultationPayment,
        enabled: !_blocksDismiss && !billingAlreadyPaid,
        secondary: const Icon(AppActionIcons.payment),
        onChanged: (bool value) {
          setState(() {
            _requireConsultationPayment = value;
          });
        },
      ),
    ];
  }

  bool _shouldShowActiveEncounterNotice() {
    return _patientMode != _WalkInPatientMode.newPatient;
  }

  Widget _knownPatientSummary(AppLocalizations l10n) {
    final Patient? patient =
        widget.initialPatient ?? _patientByApiId(_patientId);
    if (patient == null) {
      return const SizedBox.shrink();
    }

    final ThemeData theme = Theme.of(context);
    final String patientNumber = (patient.effectiveIdentifier ?? '').trim();
    final String? phone = patient.primaryPhone?.trim();
    final String? email = patient.primaryEmail?.trim();
    return Padding(
      padding: EdgeInsets.only(bottom: theme.spacing.md),
      child: AppPatientDetails(
        patientName: patient.effectiveDisplayName,
        patientNumber: patientNumber,
        patientNumberLabel: l10n.opdPatientIdLabel,
        copyPatientNumberTooltip: l10n.opdCopyPatientIdAction,
        copyPatientNumberMessage: l10n.clinicalPatientIdCopiedMessage,
        semanticLabel: l10n.opdPatientSectionTitle,
        showAvatar: false,
        persistExpandPreference: false,
        initiallyExpanded: false,
        ageLabel: patient.dateOfBirth == null
            ? null
            : formatPatientAge(l10n, patient.dateOfBirth),
        genderLabel: patient.gender == null
            ? null
            : patientGenderLabel(l10n, patient.gender!),
        genderIcon: patientGenderIcon(patient.gender),
        phoneLabel: phone,
        emailLabel: email,
      ),
    );
  }

  Widget _activeEncounterNotice(AppLocalizations l10n) {
    final ThemeData theme = Theme.of(context);
    final OpdFlowSummary? flow = _activeEncounter;
    if (_isResolvingActiveEncounter && flow == null) {
      return const SizedBox.shrink();
    }

    if (flow == null) {
      return const SizedBox.shrink();
    }

    final Patient? patient =
        widget.initialPatient ?? _patientByApiId(_patientId);
    final String stageLabel = opdStageDisplayLabel(
      l10n,
      flow.displayCode ?? flow.stage ?? flow.status,
    );
    final String nextStepLabel = opdNextStepDisplayLabel(
      l10n,
      flow.displayNextStep ?? flow.nextStep,
    );
    final String? patientId =
        patient?.effectiveIdentifier ??
        _firstNonEmptyText(<String?>[
          patient?.publicId,
          patient?.id,
          flow.patientIdentifier,
          flow.patientId,
        ]);
    final List<OpdEncounterSummaryPair> pairs = <OpdEncounterSummaryPair>[
      OpdEncounterSummaryPair(
        label: l10n.clinicalEncounterNumberLabel,
        value: flow.apiId,
        copyable: true,
      ),
      if (patientId != null)
        OpdEncounterSummaryPair(
          label: l10n.opdPatientIdLabel,
          value: patientId,
          copyable: true,
        ),
      OpdEncounterSummaryPair(
        label: l10n.opdNextStepColumnLabel,
        value: nextStepLabel.isEmpty ? l10n.profileUnknownValue : nextStepLabel,
      ),
      OpdEncounterSummaryPair(
        label: l10n.opdVisitTypeColumnLabel,
        value: opdArrivalModeDisplayLabel(
          l10n,
          _firstNonEmptyText(<String?>[flow.arrivalMode, flow.encounterType]),
        ),
      ),
      OpdEncounterSummaryPair(
        label: l10n.opdProviderColumnLabel,
        value: flow.providerDisplayName ?? l10n.profileUnknownValue,
      ),
      OpdEncounterSummaryPair(
        label: l10n.opdPayerBillingColumnLabel,
        value: _flowBillingLabel(context, flow),
      ),
      OpdEncounterSummaryPair(
        label: l10n.opdTimeColumnLabel,
        value: _formatDateTime(context, flow.startedAt),
      ),
    ];

    return Padding(
      padding: EdgeInsets.only(bottom: theme.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppFormInformationBanner.message(
            title: l10n.opdActiveEncounterFoundTitle,
            message: l10n.opdActiveEncounterFoundBody,
            variant: AppFormInformationVariant.warning,
            icon: AppActionIcons.info,
            children: <Widget>[
              Align(
                alignment: Alignment.centerLeft,
                child: AppWorkspaceStatusBadge(
                  status: AppWorkspaceStatus(
                    label: stageLabel,
                    tone: AppWorkspaceStatusTone.warning,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: theme.spacing.sm),
          OpdEncounterSummaryRow(pairs: pairs),
        ],
      ),
    );
  }

  Future<void> _loadBillingDefaults() async {
    setState(() {
      _isLoadingBillingDefaults = true;
    });
    final Patient? patient =
        widget.initialPatient ?? _patientByApiId(_patientId);
    final Result<OpdBillingDefaults> result = await ref
        .read(opdEncounterDialogControllerProvider)
        .getBillingDefaults(
          facilityId: patient?.facilityId,
          tenantId: patient?.tenantId,
        );
    if (!mounted) {
      return;
    }
    result.when(
      success: (OpdBillingDefaults defaults) {
        setState(() {
          _billingDefaults = defaults;
          _applyProviderDefaultsToState(_providerId);
          _isLoadingBillingDefaults = false;
        });
      },
      failure: (AppFailure failure) {
        setState(() {
          _failure = failure;
          _hasLookupFailure = true;
          _isLoadingBillingDefaults = false;
        });
      },
    );
  }

  void _continueWorkflow() {
    final OpdFlowSummary? flow = _activeEncounter;
    if (flow == null) {
      return;
    }
    Navigator.of(context).pop(
      OpdEncounterDialogResult(
        action: OpdEncounterDialogAction.continueWorkflow,
        flow: flow,
      ),
    );
  }

  Future<void> _promptStartNewEncounter() async {
    final OpdFlowSummary? flow = _activeEncounter;
    if (flow == null) {
      return;
    }
    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AppConfirmActionDialog(
        title: context.l10n.opdStartNewEncounterConfirmTitle,
        body: context.l10n.opdStartNewEncounterConfirmBody,
        highlightedText: flow.apiId,
        submitLabel: context.l10n.opdStartNewEncounterConfirmAction,
        destructive: true,
        icon: const Icon(AppActionIcons.add),
      ),
    );
    if (!mounted || confirmed != true) {
      return;
    }
    setState(() {
      _forceNewEncounter = true;
      _failure = null;
    });
  }

  Future<void> _promptCloseEncounter() async {
    final OpdFlowSummary? flow = _activeEncounter;
    if (flow == null || widget.onCloseEncounter == null) {
      return;
    }
    OpdFlowDetail? closedDetail;
    final bool? confirmed = await showOpdCloseEncounterDialog(
      context: context,
      flow: flow,
      onConfirm: (Map<String, Object?> payload) async {
        final Result<OpdFlowDetail> result = await widget.onCloseEncounter!(
          flow.apiId,
          payload,
        );
        return result.when(
          success: (OpdFlowDetail detail) {
            closedDetail = detail;
            return null;
          },
          failure: (AppFailure failure) => failure,
        );
      },
    );
    if (confirmed != true || closedDetail == null || !mounted) {
      return;
    }
    widget.onSuccess?.call();
    Navigator.of(context).pop(
      OpdEncounterDialogResult(
        action: OpdEncounterDialogAction.closed,
        flow: closedDetail!.summary,
      ),
    );
  }

  Future<void> _promptCancelEncounter() async {
    final OpdFlowSummary? flow = _activeEncounter;
    if (flow == null || widget.onCancelEncounter == null) {
      return;
    }
    OpdFlowDetail? cancelledDetail;
    final bool? confirmed = await showOpdCancelEncounterDialog(
      context: context,
      flow: flow,
      onConfirm: (Map<String, Object?> payload) async {
        final Result<OpdFlowDetail> result = await widget.onCancelEncounter!(
          flow.apiId,
          payload,
        );
        return result.when(
          success: (OpdFlowDetail detail) {
            cancelledDetail = detail;
            return null;
          },
          failure: (AppFailure failure) => failure,
        );
      },
    );
    if (confirmed != true || cancelledDetail == null || !mounted) {
      return;
    }
    widget.onSuccess?.call();
    Navigator.of(context).pop(
      OpdEncounterDialogResult(
        action: OpdEncounterDialogAction.cancelled,
        flow: cancelledDetail!.summary,
      ),
    );
  }

  Future<void> _submit() async {
    if (_isSaving) {
      return;
    }
    if (_patientMode == _WalkInPatientMode.newPatient) {
      await _createPatientAndContinue();
      return;
    }
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });

    final Result<OpdFlowDetail> result = await widget.onSubmit(_payload());
    if (!mounted) {
      return;
    }
    return result.when(
      success: (OpdFlowDetail detail) {
        final OpdFlowSummary? activeEncounter = _activeEncounter;
        final bool reusingActive =
            activeEncounter != null && !_forceNewEncounter;
        if (reusingActive) {
          widget.onExistingActiveEncounter?.call(activeEncounter);
        }
        widget.onSuccess?.call();
        Navigator.of(context).pop(
          OpdEncounterDialogResult(
            flow: reusingActive ? activeEncounter : detail.summary,
          ),
        );
      },
      failure: (AppFailure failure) {
        setState(() {
          _failure = failure;
          _isSaving = false;
        });
      },
    );
  }

  Future<void> _createPatientAndContinue() async {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }
    final RegisterNewPatientFormState? formState =
        _newPatientFormKey.currentState;
    if (formState != null) {
      final bool canContinue = await formState.prepareSubmit();
      if (!canContinue) {
        return;
      }
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final Result<Patient> result = await ref
        .read(opdEncounterDialogControllerProvider)
        .createPatient(_newPatientRegistrationPayload());
    if (!mounted) {
      return;
    }
    result.when(
      success: (Patient patient) {
        setState(() {
          _isSaving = false;
          _patientMode = _WalkInPatientMode.existing;
          _patientId = _firstNonEmptyText(<String?>[
            patient.publicId,
            patient.id,
          ]);
          _patientOptions = _mergePatients(<Patient>[
            ..._patientOptions,
            patient,
          ]);
          _lockArrivalMode = false;
        });
        _refreshActiveEncounterForSelection();
        _loadBillingDefaults();
      },
      failure: (AppFailure failure) {
        setState(() {
          _failure = failure;
          _isSaving = false;
        });
      },
    );
  }

  void _setPatientMode(_WalkInPatientMode mode) {
    setState(() {
      _patientMode = mode;
      if (mode == _WalkInPatientMode.appointment) {
        _arrivalMode = 'ONLINE_APPOINTMENT';
      } else if (_arrivalMode == 'ONLINE_APPOINTMENT') {
        _arrivalMode = 'WALK_IN';
      }
    });
    _refreshActiveEncounterForSelection();
  }

  Widget _patientModeContent(AppLocalizations l10n) {
    return switch (_patientMode) {
      _WalkInPatientMode.existing => AppSelectField<String>.searchable(
        value: _patientId,
        options: _patientSelectOptions(),
        labelText: _opdRequiredFieldLabel(l10n, l10n.opdSearchPatientLabel),
        semanticLabel: _opdRequiredFieldLabel(l10n, l10n.opdSearchPatientLabel),
        enabled: !_blocksDismiss,
        onChanged: _selectExistingPatient,
        validator: (String? value) =>
            _patientMode != _WalkInPatientMode.existing || _isNonEmpty(value)
            ? null
            : l10n.validationRequired,
      ),
      _WalkInPatientMode.appointment => AppSelectField<String>.searchable(
        value: _appointmentId,
        options: _appointmentSelectOptions(),
        labelText: _opdRequiredFieldLabel(
          l10n,
          l10n.opdAppointmentPatientLabel,
        ),
        helperText: l10n.opdAppointmentPatientHelper,
        semanticLabel: _opdRequiredFieldLabel(
          l10n,
          l10n.opdAppointmentPatientLabel,
        ),
        enabled: !_blocksDismiss,
        onChanged: _selectAppointmentPatient,
        validator: (String? value) =>
            _patientMode != _WalkInPatientMode.appointment || _isNonEmpty(value)
            ? null
            : l10n.validationRequired,
      ),
      _WalkInPatientMode.newPatient => RegisterNewPatientForm(
        key: _newPatientFormKey,
        referenceData: _patientReferenceData,
        registrationScope: PatientRegistrationScope.resolve(
          referenceData: _patientReferenceData,
          accessPolicy: ref.watch(appAccessPolicyProvider),
        ),
        enabled: !_blocksDismiss,
        includeNotes: false,
        includeActiveToggle: false,
        requireGender: false,
        onLookupDuplicates: (PatientDuplicateQuery query) {
          return ref
              .read(opdEncounterDialogControllerProvider)
              .listDuplicateCandidates(query);
        },
        onDuplicateStateChanged: () => setState(() {}),
        onUseExistingPatient: _continueWithExistingPatient,
      ),
    };
  }

  void _selectExistingPatient(String? value) {
    final Patient? patient = _patientByApiId(value);
    setState(() {
      _patientId = value;
    });
    _resolveActiveEncounterForPatient(
      patientId: patient?.id,
      patientPublicId: patient?.publicId ?? value,
      patientIdentifier: patient?.effectiveIdentifier,
      patientPhone: patient?.primaryPhone,
    );
    unawaited(
      _refreshEngineConsultationFee(patient?.publicId ?? patient?.id ?? value),
    );
  }

  void _continueWithExistingPatient(Patient patient) {
    final String? patientKey = _firstNonEmptyText(<String?>[
      patient.publicId,
      patient.id,
    ]);
    setState(() {
      _patientMode = _WalkInPatientMode.existing;
      _patientId = patientKey;
      _patientOptions = _mergePatients(<Patient>[..._patientOptions, patient]);
      _lockArrivalMode = false;
      _failure = null;
    });
    _selectExistingPatient(patientKey);
    _loadBillingDefaults();
  }

  void _selectAppointmentPatient(String? value) {
    final OpdAppointment? appointment = _appointmentByApiId(value);
    final Patient? contextPatient = _patientByApiId(_patientId);
    setState(() {
      _appointmentId = value;
      _providerId = appointment?.providerUserId ?? _providerId;
      _arrivalMode = 'ONLINE_APPOINTMENT';
      _applyProviderDefaultsToState(_providerId);
    });
    _resolveActiveEncounterForPatient(
      patientId: appointment?.patientId ?? contextPatient?.id,
      patientPublicId:
          appointment?.patientIdentifier ??
          contextPatient?.publicId ??
          _patientId,
      patientIdentifier:
          appointment?.patientIdentifier ?? contextPatient?.effectiveIdentifier,
      patientPhone: appointment?.patientPhone ?? contextPatient?.primaryPhone,
      appointmentId: appointment?.apiId,
    );
    unawaited(
      _refreshEngineConsultationFee(
        appointment?.patientIdentifier ??
            appointment?.patientId ??
            contextPatient?.publicId ??
            contextPatient?.id ??
            _patientId,
      ),
    );
  }

  void _refreshActiveEncounterForSelection() {
    if (_patientMode == _WalkInPatientMode.existing) {
      _selectExistingPatient(_patientId);
      return;
    }
    if (_patientMode == _WalkInPatientMode.appointment) {
      _selectAppointmentPatient(_appointmentId);
      return;
    }

    _activeEncounterLookupToken++;
    setState(() {
      _activeEncounter = null;
      _isResolvingActiveEncounter = false;
    });
  }

  void _resolveActiveEncounterForPatient({
    String? patientId,
    String? patientPublicId,
    String? patientIdentifier,
    String? patientPhone,
    String? appointmentId,
  }) {
    final int token = ++_activeEncounterLookupToken;
    final OpdFlowSummary? localMatch = _findActiveEncounterForPatient(
      flows: widget.activeFlows,
      patientId: patientId,
      patientPublicId: patientPublicId,
      patientIdentifier: patientIdentifier,
      patientPhone: patientPhone,
      appointmentId: appointmentId,
    );
    final String? search = _firstNonEmptyText(<String?>[
      patientPublicId,
      patientIdentifier,
      patientPhone,
      patientId,
      appointmentId,
    ]);

    final bool hasSearch = _isNonEmpty(search);
    setState(() {
      _isResolvingActiveEncounter = hasSearch;
      _forceNewEncounter = false;
      _applyActiveEncounterToState(localMatch);
    });

    if (!hasSearch) {
      return;
    }

    unawaited(
      _loadActiveEncounterMatch(
        token: token,
        search: search!,
        localMatch: localMatch,
        patientId: patientId,
        patientPublicId: patientPublicId,
        patientIdentifier: patientIdentifier,
        patientPhone: patientPhone,
        appointmentId: appointmentId,
      ),
    );
  }

  Future<void> _loadActiveEncounterMatch({
    required int token,
    required String search,
    required OpdFlowSummary? localMatch,
    String? patientId,
    String? patientPublicId,
    String? patientIdentifier,
    String? patientPhone,
    String? appointmentId,
  }) async {
    final Result<AppPage<OpdFlowSummary>> result = await ref
        .read(opdEncounterDialogControllerProvider)
        .listOpdFlows(
          OpdFlowQuery(
            search: search,
            pageRequest: const AppPageRequest(pageSize: 25),
          ),
        );
    if (!mounted || token != _activeEncounterLookupToken) {
      return;
    }

    result.when(
      success: (AppPage<OpdFlowSummary> page) {
        final OpdFlowSummary? remoteMatch = _findActiveEncounterForPatient(
          flows: <OpdFlowSummary>[...page.items, ...widget.activeFlows],
          patientId: patientId,
          patientPublicId: patientPublicId,
          patientIdentifier: patientIdentifier,
          patientPhone: patientPhone,
          appointmentId: appointmentId,
        );
        setState(() {
          _isResolvingActiveEncounter = false;
          _applyActiveEncounterToState(remoteMatch ?? localMatch);
        });
      },
      failure: (AppFailure failure) {
        setState(() {
          _isResolvingActiveEncounter = false;
          _applyActiveEncounterToState(localMatch);
          if (localMatch == null) {
            _failure = failure;
            _hasLookupFailure = true;
          }
        });
      },
    );
  }

  void _applyActiveEncounterToState(OpdFlowSummary? flow) {
    _activeEncounter = flow;
    if (flow == null) {
      _lockArrivalMode = false;
      _requireConsultationPayment = true;
      return;
    }

    final String encounterType = (flow.encounterType ?? '').toUpperCase();
    final String arrivalMode = (flow.arrivalMode ?? '').toUpperCase();
    if (_patientMode != _WalkInPatientMode.appointment) {
      if (encounterType == 'EMERGENCY' || arrivalMode == 'EMERGENCY') {
        _arrivalMode = 'EMERGENCY';
        _lockArrivalMode = true;
      } else if (_isNonEmpty(flow.arrivalMode)) {
        _arrivalMode = flow.arrivalMode!;
        _lockArrivalMode = true;
      }
    }
    if (_isNonEmpty(flow.providerUserId)) {
      _providerId = flow.providerUserId;
    }
    final num? billingAmount =
        flow.consultationFee ?? flow.consultationPaidAmount;
    if (billingAmount != null) {
      _feeController.text = _currencyAmountInput(billingAmount);
    }
    if (_isNonEmpty(flow.consultationCurrency)) {
      _currency = flow.consultationCurrency!.trim().toUpperCase();
    }
    _requireConsultationPayment = flow.consultationPaymentRequired;
    if (_isNonEmpty(flow.triageLevel)) {
      _triageLevel = flow.triageLevel;
    }
  }

  OpdFlowSummary? _findActiveEncounterForPatient({
    required Iterable<OpdFlowSummary> flows,
    String? patientId,
    String? patientPublicId,
    String? patientIdentifier,
    String? patientPhone,
    String? appointmentId,
  }) {
    final Set<String> patientKeys =
        <String?>[patientId, patientPublicId, patientIdentifier]
            .whereType<String>()
            .map((String value) => value.trim().toUpperCase())
            .where((String value) => value.isNotEmpty)
            .toSet();
    final Set<String> phoneKeys = <String?>[patientPhone]
        .whereType<String>()
        .map((String value) => value.trim().toUpperCase())
        .where((String value) => value.isNotEmpty)
        .toSet();
    final String normalizedAppointmentId =
        appointmentId?.trim().toUpperCase() ?? '';
    final List<OpdFlowSummary> matches = flows
        .where((OpdFlowSummary flow) {
          if (flow.isTerminal ||
              _isCompletedStatus(flow.status ?? flow.stage)) {
            return false;
          }
          if (normalizedAppointmentId.isNotEmpty &&
              (flow.appointmentId ?? '').trim().toUpperCase() ==
                  normalizedAppointmentId) {
            return true;
          }
          final bool hasPatientKeyMatch =
              patientKeys.contains(
                (flow.patientId ?? '').trim().toUpperCase(),
              ) ||
              patientKeys.contains(
                (flow.patientIdentifier ?? '').trim().toUpperCase(),
              );
          if (patientKeys.isNotEmpty) {
            return hasPatientKeyMatch;
          }
          return phoneKeys.contains(
            (flow.patientPhone ?? '').trim().toUpperCase(),
          );
        })
        .toList(growable: false);

    if (matches.isEmpty) {
      return null;
    }
    matches.sort((OpdFlowSummary left, OpdFlowSummary right) {
      return _activeEncounterTime(right).compareTo(_activeEncounterTime(left));
    });
    return matches.first;
  }

  int _activeEncounterTime(OpdFlowSummary flow) {
    return (flow.startedAt ?? flow.queuedAt)?.millisecondsSinceEpoch ?? 0;
  }

  void _applyProviderDefaultsToState(
    String? providerId, {
    bool overwrite = false,
  }) {
    final OpdProviderOption? provider = _providerOptionById(providerId);
    final OpdBillingDefaults? billingDefaults = _billingDefaults;
    final num? providerFee = provider?.consultationFee;
    final num? fallbackFee = billingDefaults?.standardConsultationFee;
    final String? providerCurrency = provider?.consultationCurrency;
    final String? fallbackCurrency =
        billingDefaults?.standardConsultationCurrency ??
        billingDefaults?.defaultCurrency;

    if (providerFee != null &&
        (overwrite || _feeController.text.trim().isEmpty)) {
      _feeController.text = _currencyAmountInput(providerFee);
    } else if (fallbackFee != null &&
        (overwrite || _feeController.text.trim().isEmpty)) {
      _feeController.text = _currencyAmountInput(fallbackFee);
    }

    if (_isNonEmpty(providerCurrency) &&
        (overwrite || _currency == appDefaultCurrencyCode)) {
      _currency = providerCurrency!.trim().toUpperCase();
    } else if (_isNonEmpty(fallbackCurrency) &&
        (overwrite || _currency == appDefaultCurrencyCode)) {
      _currency = fallbackCurrency!.trim().toUpperCase();
    }
  }

  Future<void> _refreshEngineConsultationFee(String? patientId) async {
    if (!_isNonEmpty(patientId) || !mounted) {
      return;
    }
    final ClinicalRequestPayerContext? payerContext = await ref
        .read(opdEncounterDialogControllerProvider)
        .resolvePayerContextForPatient(patientId!);
    if (!mounted) {
      return;
    }
    final num fallback =
        num.tryParse(_feeController.text.trim()) ??
        _billingDefaults?.standardConsultationFee ??
        0;
    final List<ClinicalRequestBillingLineItem> fallbackItems =
        <ClinicalRequestBillingLineItem>[
          ClinicalRequestBillingLineItem(
            id: 'CONSULTATION',
            label: context.l10n.opdConsultationFeeLabel,
            unitPrice: fallback,
            catalogType: 'CONSULTATION',
            billingEntity: 'FACILITY',
            currency: _currency,
          ),
        ];
    final List<ClinicalRequestBillingLineItem> resolved = await ref
        .read(opdEncounterDialogControllerProvider)
        .resolveConsultationBillingLineItems(
          catalogFallbackItems: fallbackItems,
          payerContext: payerContext,
          billingEntity: 'FACILITY',
          currency: _currency,
        );
    if (!mounted || resolved.isEmpty) {
      return;
    }
    final ClinicalRequestBillingLineItem line = resolved.first;
    setState(() {
      _payerContext = payerContext;
      _resolvedConsultationLine = line;
      _engineFeeResolved = true;
      if (line.unitPrice != null) {
        _feeController.text = _currencyAmountInput(line.unitPrice);
      }
      if (_isNonEmpty(line.currency)) {
        _currency = line.currency!.trim().toUpperCase();
      }
    });
  }

  Map<String, Object?> _newPatientRegistrationPayload() {
    return _newPatientFormKey.currentState?.buildPayload() ??
        const <String, Object?>{};
  }

  Future<void> _loadPatientReferenceData() async {
    setState(() {
      _isLoadingPatientReferenceData = true;
    });
    final Result<PatientReferenceData> result = await ref
        .read(opdEncounterDialogControllerProvider)
        .loadPatientReferenceData();
    if (!mounted) {
      return;
    }

    result.when(
      success: (PatientReferenceData data) {
        setState(() {
          _patientReferenceData = data;
          _isLoadingPatientReferenceData = false;
        });
      },
      failure: (AppFailure failure) {
        setState(() {
          _failure = failure;
          _hasLookupFailure = true;
          _isLoadingPatientReferenceData = false;
        });
      },
    );
  }

  Future<void> _loadPatientOptions() async {
    setState(() {
      _isLoadingPatients = true;
    });
    final Result<AppPage<Patient>> result = await ref
        .read(opdEncounterDialogControllerProvider)
        .listPatients(
          const PatientListQuery(
            isActive: true,
            pageRequest: AppPageRequest(pageSize: 50),
          ),
        );
    if (!mounted) {
      return;
    }

    result.when(
      success: (AppPage<Patient> page) {
        setState(() {
          _patientOptions = _mergePatients(<Patient>[
            ..._patientOptions,
            ...page.items,
          ]);
          _isLoadingPatients = false;
        });
        _applyInitialContext(force: true);
      },
      failure: (AppFailure failure) {
        setState(() {
          _failure = failure;
          _hasLookupFailure = true;
          _isLoadingPatients = false;
        });
      },
    );
  }

  Future<void> _loadAppointmentOptions() async {
    setState(() {
      _isLoadingAppointments = true;
    });
    final Result<AppPage<OpdAppointment>> result = await ref
        .read(opdEncounterDialogControllerProvider)
        .listAppointments(
          const OpdAppointmentQuery(pageRequest: AppPageRequest(pageSize: 50)),
        );
    if (!mounted) {
      return;
    }

    result.when(
      success: (AppPage<OpdAppointment> page) {
        setState(() {
          _appointmentOptions = _eligibleAppointmentOptions(<OpdAppointment>[
            ..._appointmentOptions,
            ...page.items,
          ]);
          _isLoadingAppointments = false;
        });
        _applyInitialContext(force: true);
        _refreshActiveEncounterForSelection();
      },
      failure: (AppFailure failure) {
        setState(() {
          _failure = failure;
          _hasLookupFailure = true;
          _isLoadingAppointments = false;
        });
      },
    );
  }

  Future<void> _loadProviderOptions() async {
    setState(() {
      _isLoadingProviders = true;
    });
    final OpdEncounterDialogController controller = ref.read(
      opdEncounterDialogControllerProvider,
    );
    final Future<Result<List<OpdProviderOption>>> providersFuture = controller
        .listProviders();
    final Future<Result<List<OpdProviderSchedule>>> schedulesFuture = controller
        .listProviderSchedules();
    final Result<List<OpdProviderOption>> providersResult =
        await providersFuture;
    final Result<List<OpdProviderSchedule>> schedulesResult =
        await schedulesFuture;
    if (!mounted) {
      return;
    }

    providersResult.when(
      success: (List<OpdProviderOption> providers) {
        var schedules = _providerSchedules;
        schedulesResult.when(
          success: (List<OpdProviderSchedule> value) => schedules = value,
          // Schedules only annotate availability; keep seeded schedules on failure.
          failure: (_) {},
        );
        setState(() {
          _providerOptions = dedupeOpdProviderOptions(providers);
          _providerSchedules = schedules;
          _applyProviderDefaultsToState(_providerId);
          _isLoadingProviders = false;
        });
      },
      failure: (AppFailure failure) {
        setState(() {
          _failure = failure;
          _hasLookupFailure = true;
          _isLoadingProviders = false;
        });
      },
    );
  }

  List<OpdProviderOption> _providerOptionsForDialog() {
    final Map<String, OpdProviderOption> options = <String, OpdProviderOption>{
      for (final OpdProviderOption provider in _providerOptions)
        provider.id: provider,
    };

    for (final OpdAppointment appointment in _appointmentOptions) {
      final String? id = appointment.providerUserId;
      if (!_isNonEmpty(id) || options.containsKey(id)) {
        continue;
      }
      options[id!] = OpdProviderOption(
        id: id,
        displayName: appointment.providerDisplayName,
        facilityId: appointment.facilityId,
      );
    }

    final OpdFlowSummary? activeEncounter = _activeEncounter;
    final String? activeProviderId = activeEncounter?.providerUserId;
    if (_isNonEmpty(activeProviderId) &&
        !options.containsKey(activeProviderId)) {
      options[activeProviderId!] = OpdProviderOption(
        id: activeProviderId,
        displayName: activeEncounter?.providerDisplayName,
        facilityId: activeEncounter?.facilityId,
      );
    }

    return dedupeOpdProviderOptions(options.values);
  }

  Map<String, Object?> _payload() {
    final String notes = _notesController.text.trim();
    final String consultationFee = normalizeCurrencyAmount(_feeController.text);
    final String arrivalMode = _patientMode == _WalkInPatientMode.appointment
        ? 'ONLINE_APPOINTMENT'
        : _arrivalMode;
    final bool hasConsultationFee = consultationFee.isNotEmpty;
    final OpdFlowSummary? activeEncounter = _activeEncounter;
    final bool canReuseOpenEncounter =
        _patientMode != _WalkInPatientMode.newPatient;

    return <String, Object?>{
      if (activeEncounter != null && !_forceNewEncounter)
        'existing_encounter_id': activeEncounter.apiId,
      if (activeEncounter != null && _forceNewEncounter) ...<String, Object?>{
        'force_new_encounter': true,
        'supersede_encounter_id': activeEncounter.apiId,
        'reuse_open_encounter': false,
      },
      if (_patientMode == _WalkInPatientMode.appointment)
        'appointment_id': _appointmentId
      else if (_patientMode == _WalkInPatientMode.newPatient)
        'patient_registration': _newPatientRegistrationPayload()
      else
        'patient_id': _patientId,
      'provider_user_id': _providerId,
      'arrival_mode': arrivalMode,
      if (arrivalMode == 'EMERGENCY')
        'emergency': <String, Object?>{
          'severity': _emergencySeverity,
          'triage_level': _triageLevel,
          'notes': notes,
        },
      'consultation_fee': consultationFee,
      'currency': _currency,
      if ((_payerContext?.coveragePlanId ?? '').trim().isNotEmpty)
        'coverage_plan_id': _payerContext!.coveragePlanId,
      if ((_payerContext?.insuranceCompanyId ?? '').trim().isNotEmpty)
        'insurance_company_id': _payerContext!.insuranceCompanyId,
      'require_consultation_payment': _requireConsultationPayment,
      if (canReuseOpenEncounter && !_forceNewEncounter)
        'reuse_open_encounter': true,
      'create_consultation_invoice':
          hasConsultationFee || _requireConsultationPayment,
    };
  }

  OpdAppointment? _appointmentByApiId(String? value) {
    if (!_isNonEmpty(value)) {
      return null;
    }

    for (final OpdAppointment appointment in _appointmentOptions) {
      if (appointment.publicId == value || appointment.id == value) {
        return appointment;
      }
    }
    return null;
  }

  Patient? _patientByApiId(String? value) {
    if (!_isNonEmpty(value)) {
      return null;
    }

    for (final Patient patient in _patientOptions) {
      if (patient.publicId == value || patient.id == value) {
        return patient;
      }
    }
    return null;
  }

  OpdProviderOption? _providerOptionById(String? value) {
    if (!_isNonEmpty(value)) {
      return null;
    }

    for (final OpdProviderOption provider in _providerOptionsForDialog()) {
      if (provider.id == value) {
        return provider;
      }
    }
    return null;
  }
}

/// Opens the OPD close-encounter confirmation (mutating; not barrier-dismissible).
///
/// On persisted success pops `true`; Cancel pops `false`; failure keeps the
/// dialog open with shared failure UI and patches nothing.
Future<bool?> showOpdCloseEncounterDialog({
  required BuildContext context,
  required OpdFlowSummary flow,
  required Future<AppFailure?> Function(Map<String, Object?> payload) onConfirm,
}) {
  return showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _CloseEncounterDialog(flow: flow, onConfirm: onConfirm),
  );
}

/// Confirm closing an OPD encounter with optional reason notes.
///
/// Composes the shared [AppTextActionDialog] shell (Cancel + domain close verb).
class _CloseEncounterDialog extends StatelessWidget {
  const _CloseEncounterDialog({required this.flow, required this.onConfirm});

  final OpdFlowSummary flow;
  final Future<AppFailure?> Function(Map<String, Object?> payload) onConfirm;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppTextActionDialog(
      title: l10n.opdCloseEncounterAction,
      icon: const Icon(AppActionIcons.success),
      submitLeadingIcon: AppActionIcons.success,
      fieldLabel: l10n.opdEncounterCloseReasonLabel,
      submitLabel: l10n.opdCloseEncounterAction,
      isRequired: false,
      maxLines: 3,
      prefixIcon: const Icon(AppActionIcons.edit),
      leadingContent: <Widget>[
        AppFormInformationBanner.message(
          title: l10n.clinicalEncounterNumberLabel,
          message: flow.apiId,
        ),
      ],
      onSubmit: (String notes) {
        return onConfirm(<String, Object?>{
          'reason_notes': notes.isEmpty ? null : notes,
        });
      },
    );
  }
}

/// Opens the OPD cancel-encounter confirmation (mutating; not barrier-dismissible).
///
/// On persisted success pops `true`; Cancel pops `false`; failure keeps the
/// dialog open with shared failure UI and patches nothing.
Future<bool?> showOpdCancelEncounterDialog({
  required BuildContext context,
  required OpdFlowSummary flow,
  required Future<AppFailure?> Function(Map<String, Object?> payload) onConfirm,
}) {
  return showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _CancelEncounterDialog(flow: flow, onConfirm: onConfirm),
  );
}

/// Confirm cancelling an OPD encounter with a required reason code.
///
/// Destructive primary commit + Cancel. Widgets never call APIs; [onConfirm]
/// owns the HTTP mutation and Riverpod patch on persisted success only.
class _CancelEncounterDialog extends StatefulWidget {
  const _CancelEncounterDialog({required this.flow, required this.onConfirm});

  final OpdFlowSummary flow;
  final Future<AppFailure?> Function(Map<String, Object?> payload) onConfirm;

  @override
  State<_CancelEncounterDialog> createState() => _CancelEncounterDialogState();
}

class _CancelEncounterDialogState extends State<_CancelEncounterDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _notesController;
  String _reasonCode = _opdEncounterCancelReasonCodes.first;
  bool _isSaving = false;
  AppFailure? _failure;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  String _reasonLabel(AppLocalizations l10n, String code) {
    return switch (code) {
      'PATIENT_LEFT' => l10n.opdEncounterCancelReasonPatientLeft,
      'DUPLICATE_ENCOUNTER' => l10n.opdEncounterCancelReasonDuplicate,
      'ENTERED_IN_ERROR' => l10n.opdEncounterCancelReasonEnteredInError,
      'PATIENT_ALREADY_SEEN' => l10n.opdEncounterCancelReasonAlreadySeen,
      _ => l10n.opdEncounterCancelReasonOther,
    };
  }

  Future<void> _submit() async {
    if (_isSaving) {
      return;
    }
    final AppLocalizations l10n = context.l10n;
    final String notes = _notesController.text.trim();
    if (_reasonCode == 'OTHER' && notes.isEmpty) {
      setState(() {
        _validationMessage = l10n.opdEncounterCancelReasonNotesRequiredMessage;
        _failure = null;
      });
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
      _validationMessage = null;
    });
    final AppFailure? failure = await widget.onConfirm(<String, Object?>{
      'reason_code': _reasonCode,
      'reason_notes': notes.isEmpty ? null : notes,
    });
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

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return AppDialog(
      title: Text(l10n.opdCancelEncounterAction),
      icon: Icon(AppActionIcons.delete, color: colorScheme.error),
      closeEnabled: !_isSaving,
      scrollable: true,
      pinActionsToBottom: true,
      maxWidth: 680,
      content: AppFormShell(
        formKey: _formKey,
        enabled: !_isSaving,
        density: AppFormSectionDensity.compact,
        formStatus: appFormFailureStatus(context, _failure),
        children: <Widget>[
          if (_validationMessage != null)
            AppFormInformationBanner.message(
              message: _validationMessage!,
              variant: AppFormInformationVariant.error,
              icon: AppActionIcons.error,
            ),
          OpdActionContextPanel(flow: widget.flow, showTitle: false),
          AppFormInformationBanner.message(
            message: l10n.opdCancelEncounterConfirmBody,
            variant: AppFormInformationVariant.warning,
            icon: AppActionIcons.warning,
          ),
          AppSelectField<String>.searchable(
            value: _reasonCode,
            labelText: l10n.opdEncounterCancelReasonCodeLabel,
            enabled: !_isSaving,
            options: _opdEncounterCancelReasonCodes
                .map(
                  (String code) => AppSelectOption<String>(
                    value: code,
                    label: _reasonLabel(l10n, code),
                  ),
                )
                .toList(growable: false),
            onChanged: (String? value) {
              setState(() {
                _reasonCode = value ?? _reasonCode;
                _validationMessage = null;
              });
            },
          ),
          if (_reasonCode == 'OTHER')
            AppTextField(
              controller: _notesController,
              labelText: l10n.opdEncounterCancelReasonNotesLabel,
              maxLines: 3,
              enabled: !_isSaving,
              textCapitalization: TextCapitalization.sentences,
              prefixIcon: const Icon(AppActionIcons.edit),
              onChanged: (_) {
                if (_validationMessage != null) {
                  setState(() => _validationMessage = null);
                }
              },
            ),
        ],
      ),
      actions: clinicalActionDialogActions(
        context,
        l10n.opdCancelEncounterAction,
        _isSaving,
        _isSaving ? null : _submit,
        submitLeadingIcon: AppActionIcons.delete,
        destructive: true,
      ),
    );
  }
}

/// Opens the OPD encounter workspace through the shared [showAppDialog] shell.
///
/// Canonical opener for start / check-in / pinned-patient encounter flows.
/// Callers must pass a fully configured host — typically [OpdEncounterDialog]
/// or the pinned-patient host from `opd_encounter_flow.dart` — with already
/// resolved contextual IDs (`human_friendly_id` / domain IDs). This opener does
/// not load, mutate, or patch Riverpod; the hosted dialog owns commits.
///
/// Barrier dismiss is always disabled so in-flight loads/mutations cannot be
/// abandoned without an explicit Cancel. While busy, the hosted dialog sets
/// `closeEnabled: false` and disables Cancel / competing footer actions.
Future<OpdEncounterDialogResult?> showOpdEncounterDialog({
  required BuildContext context,
  required Widget dialog,
  RouteSettings? routeSettings,
}) {
  return showAppDialog<OpdEncounterDialogResult>(
    context: context,
    barrierDismissible: false,
    routeSettings:
        routeSettings ?? const RouteSettings(name: 'showOpdEncounterDialog'),
    builder: (_) => dialog,
  );
}

class _ProviderSelectField extends StatelessWidget {
  const _ProviderSelectField({
    required this.value,
    required this.providers,
    required this.schedules,
    required this.labelText,
    required this.helperText,
    required this.emptyHelperText,
    required this.enabled,
    required this.onChanged,
  });

  final String? value;
  final List<OpdProviderOption> providers;
  final List<OpdProviderSchedule> schedules;
  final String labelText;
  final String helperText;
  final String emptyHelperText;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final List<AppSelectOption<String>> options = _providerSelectOptions(
      providers: providers,
      schedules: schedules,
    );

    return AppSelectField<String>.searchable(
      value: value,
      options: options,
      labelText: labelText,
      helperText: options.isEmpty ? emptyHelperText : helperText,
      semanticLabel: labelText,
      enabled: enabled,
      onChanged: onChanged,
    );
  }
}

String _opdRequiredFieldLabel(AppLocalizations l10n, String label) {
  return l10n.opdFieldRequiredLabel(label);
}

String _opdOptionalFieldLabel(AppLocalizations l10n, String label) {
  return l10n.opdFieldOptionalLabel(label);
}

List<AppSelectOption<String>> _statusOptions(List<String> values) {
  return <AppSelectOption<String>>[
    for (final String value in values)
      AppSelectOption<String>(value: value, label: _apiLabel(value)),
  ];
}

List<AppTriageOption> _triageLevelFieldOptions() {
  return <AppTriageOption>[
    for (final String value in _triageLevelOptions)
      AppTriageOption(
        value: value,
        label: _apiLabel(value),
        tone: appTriageToneForValue(value),
        icon: appTriageIconForValue(value),
      ),
  ];
}

AppSelectOption<String>? _patientSelectOption(Patient patient) {
  final String? value = _firstNonEmptyText(<String?>[
    patient.publicId,
    patient.id,
  ]);
  if (!_isNonEmpty(value)) {
    return null;
  }

  return AppSelectOption<String>(
    value: value!,
    label: _joinDisplay(<String?>[
      patient.effectiveDisplayName,
      patient.effectiveIdentifier,
      patient.primaryPhone,
    ]),
  );
}

AppSelectOption<String>? _appointmentSelectOption(OpdAppointment appointment) {
  final String value = appointment.publicId ?? appointment.id;
  if (!_isNonEmpty(value)) {
    return null;
  }

  return AppSelectOption<String>(
    value: value,
    label: _joinDisplay(<String?>[
      appointment.displayTitle,
      appointment.patientIdentifier,
      appointment.patientPhone,
      appointment.providerDisplayName,
      appointment.status,
    ]),
  );
}

List<OpdAppointment> _eligibleAppointmentOptions(
  Iterable<OpdAppointment> appointments,
) {
  final Map<String, OpdAppointment> options = <String, OpdAppointment>{};

  for (final OpdAppointment appointment in appointments) {
    final String value = appointment.publicId ?? appointment.id;
    if (!_isNonEmpty(value) ||
        _isTerminalAppointmentStatus(appointment.status)) {
      continue;
    }

    options[value] = appointment;
  }

  return options.values.toList(growable: false);
}

bool _isTerminalAppointmentStatus(String? status) {
  return switch (status?.toUpperCase()) {
    'CANCELLED' || 'NO_SHOW' || 'COMPLETED' => true,
    _ => false,
  };
}

List<AppSelectOption<String>> _providerSelectOptions({
  required List<OpdProviderOption> providers,
  required List<OpdProviderSchedule> schedules,
}) {
  return opdProviderSelectOptions(providers: providers, schedules: schedules);
}

String _flowBillingLabel(BuildContext context, OpdFlowSummary flow) {
  return opdFlowBillingDisplay(context, flow).label;
}

String _currencyAmountInput(num? amount) {
  return opdCurrencyAmountInput(amount);
}

bool _isCompletedStatus(String? status) {
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

bool _isNonEmpty(String? value) {
  return value != null && value.trim().isNotEmpty;
}

String? _firstNonEmptyText(Iterable<String?> values) {
  for (final String? value in values) {
    final String normalized = value?.trim() ?? '';
    if (normalized.isNotEmpty) {
      return normalized;
    }
  }
  return null;
}

String _apiLabel(String value) {
  return AppDisplay.apiLabel(value);
}

String _formatDateTime(BuildContext context, DateTime? value) {
  return value == null
      ? context.l10n.profileUnknownValue
      : AppFormatters.dateTime(value, Localizations.localeOf(context));
}

String _joinDisplay(Iterable<String?> values) {
  return AppDisplay.joinNonEmpty(values, separator: ' | ');
}

const List<String> _arrivalModeOptions = <String>['WALK_IN', 'EMERGENCY'];

const List<String> _emergencySeverityOptions = <String>[
  'LOW',
  'MEDIUM',
  'HIGH',
  'CRITICAL',
];

const List<String> _triageLevelOptions = <String>[
  'LEVEL_1',
  'LEVEL_2',
  'LEVEL_3',
  'LEVEL_4',
  'LEVEL_5',
  'IMMEDIATE',
  'URGENT',
  'LESS_URGENT',
  'NON_URGENT',
];
