import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/utils/app_display.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/opd/data/repositories/opd_repository_impl.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/patients/data/repositories/patient_repository_impl.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/components/app_content_panel.dart';
import 'package:hosspi_hms/shared/components/app_currency_amount_field.dart';
import 'package:hosspi_hms/shared/components/app_dialog.dart';
import 'package:hosspi_hms/shared/components/app_gender_field.dart';
import 'package:hosspi_hms/shared/components/app_list_item_text.dart';
import 'package:hosspi_hms/shared/components/app_select_field.dart';
import 'package:hosspi_hms/shared/components/app_state_view.dart';
import 'package:hosspi_hms/shared/components/app_switch_field.dart';
import 'package:hosspi_hms/shared/components/app_text_field.dart';
import 'package:hosspi_hms/shared/components/app_triage_components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/app_form_section.dart';
import 'package:hosspi_hms/shared/forms/app_form_shell.dart';
import 'package:hosspi_hms/shared/forms/app_responsive_field_row.dart';
import 'package:hosspi_hms/shared/forms/app_validators.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_billing_state.dart';

const IconData opdEncounterIcon = Icons.person_add_alt_1_outlined;

const AccessRequirement opdEncounterPermissionRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.patientWrite,
    AppPermissions.clinicalWrite,
    AppPermissions.billingWrite,
    AppPermissions.operationsWrite,
    AppPermissions.emergencyWrite,
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
    required this.onChanged,
  });

  final _WalkInPatientMode value;
  final bool enabled;
  final String existingLabel;
  final String appointmentLabel;
  final String newPatientLabel;
  final ValueChanged<_WalkInPatientMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SegmentedButton<_WalkInPatientMode>(
      expandedInsets: EdgeInsets.zero,
      segments: <ButtonSegment<_WalkInPatientMode>>[
        ButtonSegment<_WalkInPatientMode>(
          value: _WalkInPatientMode.existing,
          label: _WalkInTabLabel(existingLabel),
          icon: const Icon(Icons.badge_outlined),
        ),
        ButtonSegment<_WalkInPatientMode>(
          value: _WalkInPatientMode.appointment,
          label: _WalkInTabLabel(appointmentLabel),
          icon: const Icon(Icons.event_available_outlined),
        ),
        ButtonSegment<_WalkInPatientMode>(
          value: _WalkInPatientMode.newPatient,
          label: _WalkInTabLabel(newPatientLabel),
          icon: const Icon(Icons.person_add_alt_1_outlined),
        ),
      ],
      selected: <_WalkInPatientMode>{value},
      showSelectedIcon: false,
      style: ButtonStyle(
        minimumSize: WidgetStatePropertyAll<Size>(Size(theme.spacing.none, 44)),
        shape: const WidgetStatePropertyAll<OutlinedBorder>(
          RoundedRectangleBorder(),
        ),
      ),
      onSelectionChanged: enabled
          ? (Set<_WalkInPatientMode> selected) => onChanged(selected.first)
          : null,
    );
  }
}

class _WalkInTabLabel extends StatelessWidget {
  const _WalkInTabLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

typedef OpdEncounterPayloadSubmit =
    Future<AppFailure?> Function(Map<String, Object?> payload);

class OpdEncounterDialog extends ConsumerStatefulWidget {
  const OpdEncounterDialog({
    required this.providerSchedules,
    required this.appointments,
    this.activeFlows = const <OpdFlowSummary>[],
    this.source,
    this.initialPatientId,
    this.initialPatient,
    this.initialAppointmentId,
    this.initialAppointment,
    this.defaultArrivalMode = 'WALK_IN',
    this.defaultProviderId,
    this.onSuccess,
    this.onExistingActiveEncounter,
    required this.onSubmit,
    super.key,
  });

  final List<OpdProviderSchedule> providerSchedules;
  final List<OpdAppointment> appointments;
  final List<OpdFlowSummary> activeFlows;
  final String? source;
  final String? initialPatientId;
  final Patient? initialPatient;
  final String? initialAppointmentId;
  final OpdAppointment? initialAppointment;
  final String defaultArrivalMode;
  final String? defaultProviderId;
  final VoidCallback? onSuccess;
  final ValueChanged<OpdFlowSummary>? onExistingActiveEncounter;
  final OpdEncounterPayloadSubmit onSubmit;

  @override
  ConsumerState<OpdEncounterDialog> createState() => _OpdEncounterDialogState();
}

class _OpdEncounterDialogState extends ConsumerState<OpdEncounterDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _newPatientFirstNameController;
  late final TextEditingController _newPatientLastNameController;
  late final TextEditingController _feeController;
  late final TextEditingController _notesController;
  List<Patient> _patientOptions = const <Patient>[];
  List<OpdAppointment> _appointmentOptions = const <OpdAppointment>[];
  List<OpdProviderOption> _providerOptions = const <OpdProviderOption>[];
  _WalkInPatientMode _patientMode = _WalkInPatientMode.existing;
  bool _isLoadingPatients = false;
  bool _isLoadingAppointments = false;
  bool _isLoadingProviders = false;
  bool _isResolvingActiveEncounter = false;
  String? _patientId;
  String? _appointmentId;
  String? _providerId;
  OpdFlowSummary? _activeEncounter;
  String? _newPatientGender;
  String _currency = appDefaultCurrencyCode;
  String _arrivalMode = 'WALK_IN';
  String _emergencySeverity = 'HIGH';
  String? _triageLevel;
  bool _requireConsultationPayment = true;
  bool _isSaving = false;
  AppFailure? _failure;
  int _activeEncounterLookupToken = 0;
  bool _appliedInitialContext = false;

  @override
  void initState() {
    super.initState();
    _newPatientFirstNameController = TextEditingController();
    _newPatientLastNameController = TextEditingController();
    _feeController = TextEditingController();
    _notesController = TextEditingController();
    _patientOptions = <Patient>[
      if (widget.initialPatient != null) widget.initialPatient!,
    ];
    _appointmentOptions = _eligibleAppointmentOptions(<OpdAppointment>[
      ...widget.appointments,
      if (widget.initialAppointment != null) widget.initialAppointment!,
    ]);
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
    unawaited(_loadPatientOptions());
    unawaited(_loadAppointmentOptions());
    unawaited(_loadProviderOptions());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _applyInitialContext();
        _refreshActiveEncounterForSelection();
      }
    });
  }

  @override
  void dispose() {
    _newPatientFirstNameController.dispose();
    _newPatientLastNameController.dispose();
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
        _requireConsultationPayment = true;
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
      _requireConsultationPayment = true;
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

    return AppDialog(
      title: Text(l10n.opdWalkInDialogTitle),
      icon: const Icon(opdEncounterIcon),
      scrollable: true,
      maxWidth: 880,
      content: AppFormShell(
        formKey: _formKey,
        enabled: !_isSaving,
        formStatus: _failure == null
            ? null
            : AppFailureStateView(failure: _failure!),
        children: <Widget>[
          AppSectionPanel(
            title: l10n.opdPatientSectionTitle,
            density: AppContentPanelDensity.compact,
            children: <Widget>[
              _WalkInModeSelector(
                value: _patientMode,
                enabled: !_isSaving,
                existingLabel: l10n.opdExistingPatientModeLabel,
                appointmentLabel: l10n.opdAppointmentPatientModeLabel,
                newPatientLabel: l10n.opdNewPatientModeLabel,
                onChanged: _setPatientMode,
              ),
              _patientModeContent(l10n),
              _activeEncounterNotice(l10n),
            ],
          ),
          AppResponsiveFieldRow.two(
            left: _routingSection(l10n),
            right: _billingSection(l10n),
            breakpoint: 760,
            gap: AppResponsiveFieldRowGap.form,
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: l10n.commonCancelActionLabel,
          enabled: !_isSaving,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: hasActiveEncounter
              ? l10n.opdOpenActiveEncounterAction
              : l10n.opdStartEncounterAction,
          leadingIcon: hasActiveEncounter
              ? Icons.open_in_new_outlined
              : Icons.play_arrow_outlined,
          enabled: !_isResolvingActiveEncounter || _activeEncounter != null,
          isLoading: _isSaving,
          onPressed: _submit,
        ),
      ],
    );
  }

  Widget _routingSection(AppLocalizations l10n) {
    return AppSectionPanel(
      title: l10n.opdRoutingSectionTitle,
      density: AppContentPanelDensity.compact,
      children: <Widget>[
        if (_patientMode != _WalkInPatientMode.appointment)
          AppSelectField<String>.searchable(
            value: _arrivalMode,
            labelText: _opdRequiredFieldLabel(l10n, l10n.opdArrivalModeLabel),
            semanticLabel: _opdRequiredFieldLabel(
              l10n,
              l10n.opdArrivalModeLabel,
            ),
            enabled: !_isSaving,
            onChanged: (String? value) {
              setState(() {
                _arrivalMode = value ?? 'WALK_IN';
                _requireConsultationPayment = _arrivalMode != 'EMERGENCY';
              });
            },
            options: _statusOptions(_arrivalModeOptions),
          ),
        if (_arrivalMode == 'EMERGENCY' &&
            _patientMode != _WalkInPatientMode.appointment)
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
                enabled: !_isSaving,
                onChanged: (String? value) {
                  setState(() {
                    _emergencySeverity = value ?? _emergencySeverity;
                  });
                },
                options: _statusOptions(_emergencySeverityOptions),
              ),
              AppTriageUrgencyField(
                value: _triageLevel,
                labelText: _opdOptionalFieldLabel(
                  l10n,
                  l10n.opdTriageLevelLabel,
                ),
                semanticLabel: _opdOptionalFieldLabel(
                  l10n,
                  l10n.opdTriageLevelLabel,
                ),
                enabled: !_isSaving,
                onChanged: (String? value) {
                  setState(() {
                    _triageLevel = value;
                  });
                },
                options: _triageLevelFieldOptions(),
              ),
            ],
          ),
        _ProviderSelectField(
          value: _providerId,
          providers: _providerOptionsForDialog(),
          schedules: widget.providerSchedules,
          labelText: _opdOptionalFieldLabel(l10n, l10n.opdSearchProviderLabel),
          helperText: l10n.opdSearchProviderHelper,
          emptyHelperText: l10n.opdNoProvidersHelper,
          enabled: !_isSaving,
          isLoading: _isLoadingProviders,
          onChanged: (String? value) {
            setState(() {
              _providerId = value;
              _applyProviderDefaultsToState(value);
            });
          },
        ),
      ],
    );
  }

  Widget _billingSection(AppLocalizations l10n) {
    return AppSectionPanel(
      title: l10n.opdBillingSectionTitle,
      density: AppContentPanelDensity.compact,
      children: <Widget>[
        AppCurrencyAmountField(
          amountController: _feeController,
          currency: _currency,
          amountLabelText: _opdOptionalFieldLabel(
            l10n,
            l10n.opdConsultationFeeLabel,
          ),
          currencyLabelText: _opdRequiredFieldLabel(
            l10n,
            l10n.opdCurrencyLabel,
          ),
          enabled: !_isSaving,
          onCurrencyChanged: (String? value) {
            setState(() {
              _currency = value ?? appDefaultCurrencyCode;
            });
          },
        ),
        AppTextField(
          controller: _notesController,
          labelText: _opdOptionalFieldLabel(l10n, l10n.opdNotesLabel),
          enabled: !_isSaving,
          maxLines: 3,
        ),
        AppSwitchField(
          title: l10n.opdPaymentRequiredLabel,
          value: _requireConsultationPayment,
          enabled: !_isSaving,
          secondary: const Icon(Icons.payments_outlined),
          onChanged: (bool value) {
            setState(() {
              _requireConsultationPayment = value;
            });
          },
        ),
      ],
    );
  }

  Widget _activeEncounterNotice(AppLocalizations l10n) {
    if (_patientMode == _WalkInPatientMode.newPatient) {
      return const SizedBox.shrink();
    }

    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final OpdFlowSummary? flow = _activeEncounter;
    if (_isResolvingActiveEncounter && flow == null) {
      return Padding(
        padding: EdgeInsets.only(top: theme.spacing.md),
        child: Row(
          children: <Widget>[
            SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.primary,
              ),
            ),
            SizedBox(width: theme.spacing.sm),
            Expanded(
              child: Text(
                l10n.opdActiveEncounterCheckingLabel,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (flow == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.only(top: theme.spacing.md),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.secondaryContainer.withValues(alpha: 0.28),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: EdgeInsets.all(theme.spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: theme.spacing.sm,
                runSpacing: theme.spacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: colorScheme.onSecondaryContainer,
                  ),
                  Text(
                    l10n.opdActiveEncounterFoundTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                  AppWorkspaceStatusBadge(
                    status: AppWorkspaceStatus(
                      label: _apiLabel(flow.stage ?? flow.status ?? ''),
                      tone: AppWorkspaceStatusTone.warning,
                    ),
                  ),
                ],
              ),
              SizedBox(height: theme.spacing.xs),
              Text(
                l10n.opdActiveEncounterFoundBody,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
              SizedBox(height: theme.spacing.md),
              Wrap(
                spacing: theme.spacing.lg,
                runSpacing: theme.spacing.sm,
                children: <Widget>[
                  _ActiveEncounterDetail(
                    label: l10n.clinicalEncounterNumberLabel,
                    value: flow.apiId,
                  ),
                  _ActiveEncounterDetail(
                    label: l10n.opdStageLabel,
                    value: _apiLabel(flow.stage ?? flow.status ?? ''),
                  ),
                  _ActiveEncounterDetail(
                    label: l10n.opdVisitTypeColumnLabel,
                    value: _apiLabel(
                      _firstNonEmptyText(<String?>[
                            flow.arrivalMode,
                            flow.encounterType,
                          ]) ??
                          '',
                    ),
                  ),
                  _ActiveEncounterDetail(
                    label: l10n.opdProviderColumnLabel,
                    value: flow.providerDisplayName ?? l10n.profileUnknownValue,
                  ),
                  _ActiveEncounterDetail(
                    label: l10n.opdPayerBillingColumnLabel,
                    value: _flowBillingLabel(context, flow),
                  ),
                  _ActiveEncounterDetail(
                    label: l10n.opdTimeColumnLabel,
                    value: _formatDateTime(context, flow.startedAt),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });

    final AppFailure? failure = await widget.onSubmit(_payload());
    if (!mounted) {
      return;
    }
    if (failure == null) {
      final OpdFlowSummary? activeEncounter = _activeEncounter;
      if (activeEncounter != null) {
        widget.onExistingActiveEncounter?.call(activeEncounter);
      }
      widget.onSuccess?.call();
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _failure = failure;
      _isSaving = false;
    });
  }

  void _setPatientMode(_WalkInPatientMode mode) {
    setState(() {
      _patientMode = mode;
      if (mode == _WalkInPatientMode.appointment) {
        _arrivalMode = 'ONLINE_APPOINTMENT';
        _requireConsultationPayment = true;
      } else if (_arrivalMode == 'ONLINE_APPOINTMENT') {
        _arrivalMode = 'WALK_IN';
        _requireConsultationPayment = true;
      }
    });
    _refreshActiveEncounterForSelection();
  }

  Widget _patientModeContent(AppLocalizations l10n) {
    return switch (_patientMode) {
      _WalkInPatientMode.existing => AppSelectField<String>.searchable(
        value: _patientId,
        options: _patientOptions
            .map(_patientSelectOption)
            .whereType<AppSelectOption<String>>()
            .toList(growable: false),
        labelText: _opdRequiredFieldLabel(l10n, l10n.opdSearchPatientLabel),
        semanticLabel: _opdRequiredFieldLabel(l10n, l10n.opdSearchPatientLabel),
        isLoading: _isLoadingPatients,
        enabled: !_isSaving,
        onChanged: _selectExistingPatient,
        validator: (String? value) =>
            _patientMode != _WalkInPatientMode.existing || _isNonEmpty(value)
            ? null
            : l10n.validationRequired,
      ),
      _WalkInPatientMode.appointment => AppSelectField<String>.searchable(
        value: _appointmentId,
        options: _appointmentOptions
            .map(_appointmentSelectOption)
            .whereType<AppSelectOption<String>>()
            .toList(growable: false),
        labelText: _opdRequiredFieldLabel(
          l10n,
          l10n.opdAppointmentPatientLabel,
        ),
        helperText: l10n.opdAppointmentPatientHelper,
        semanticLabel: _opdRequiredFieldLabel(
          l10n,
          l10n.opdAppointmentPatientLabel,
        ),
        isLoading: _isLoadingAppointments,
        enabled: !_isSaving,
        onChanged: _selectAppointmentPatient,
        validator: (String? value) =>
            _patientMode != _WalkInPatientMode.appointment || _isNonEmpty(value)
            ? null
            : l10n.validationRequired,
      ),
      _WalkInPatientMode.newPatient => AppFormSection(
        density: AppFormSectionDensity.compact,
        children: <Widget>[
          AppResponsiveFieldRow.two(
            left: AppTextField(
              controller: _newPatientFirstNameController,
              labelText: _opdRequiredFieldLabel(l10n, l10n.opdFirstNameLabel),
              semanticLabel: _opdRequiredFieldLabel(
                l10n,
                l10n.opdFirstNameLabel,
              ),
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              enabled: !_isSaving,
              isRequired: true,
              validator: AppValidators.requiredText(l10n.validationRequired),
            ),
            right: AppTextField(
              controller: _newPatientLastNameController,
              labelText: _opdRequiredFieldLabel(l10n, l10n.opdLastNameLabel),
              semanticLabel: _opdRequiredFieldLabel(
                l10n,
                l10n.opdLastNameLabel,
              ),
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              enabled: !_isSaving,
              isRequired: true,
              validator: AppValidators.requiredText(l10n.validationRequired),
            ),
          ),
          AppGenderField(
            value: _newPatientGender,
            labelText: _opdOptionalFieldLabel(l10n, l10n.opdGenderLabel),
            semanticLabel: _opdOptionalFieldLabel(l10n, l10n.opdGenderLabel),
            maleLabel: l10n.patientsGenderMale,
            femaleLabel: l10n.patientsGenderFemale,
            otherLabel: l10n.patientsGenderOther,
            unknownLabel: l10n.patientsGenderUnknown,
            includeUnknown: false,
            enabled: !_isSaving,
            onChanged: (String? value) {
              setState(() {
                _newPatientGender = value;
              });
            },
          ),
        ],
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
  }

  void _selectAppointmentPatient(String? value) {
    final OpdAppointment? appointment = _appointmentByApiId(value);
    final Patient? contextPatient = _patientByApiId(_patientId);
    setState(() {
      _appointmentId = value;
      _providerId = appointment?.providerUserId ?? _providerId;
      _arrivalMode = 'ONLINE_APPOINTMENT';
      _requireConsultationPayment = true;
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

    setState(() {
      _isResolvingActiveEncounter = _isNonEmpty(search);
      _applyActiveEncounterToState(localMatch);
    });

    if (!_isNonEmpty(search)) {
      setState(() {
        _isResolvingActiveEncounter = false;
      });
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
        .read(opdRepositoryProvider)
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
      failure: (_) {
        setState(() {
          _isResolvingActiveEncounter = false;
          _applyActiveEncounterToState(localMatch);
        });
      },
    );
  }

  void _applyActiveEncounterToState(OpdFlowSummary? flow) {
    _activeEncounter = flow;
    if (flow == null) {
      return;
    }

    final String encounterType = (flow.encounterType ?? '').toUpperCase();
    final String arrivalMode = (flow.arrivalMode ?? '').toUpperCase();
    if (_patientMode != _WalkInPatientMode.appointment) {
      if (encounterType == 'EMERGENCY' || arrivalMode == 'EMERGENCY') {
        _arrivalMode = 'EMERGENCY';
      } else if (_isNonEmpty(flow.arrivalMode) &&
          arrivalMode != 'ONLINE_APPOINTMENT') {
        _arrivalMode = flow.arrivalMode!;
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
    if (provider == null) {
      return;
    }
    if (provider.consultationFee != null &&
        (overwrite || _feeController.text.trim().isEmpty)) {
      _feeController.text = _currencyAmountInput(provider.consultationFee);
    }
    if (_isNonEmpty(provider.consultationCurrency) &&
        (overwrite || _currency == appDefaultCurrencyCode)) {
      _currency = provider.consultationCurrency!.trim().toUpperCase();
    }
  }

  Map<String, Object?> _newPatientRegistrationPayload() {
    return <String, Object?>{
      'first_name': _newPatientFirstNameController.text.trim(),
      'last_name': _newPatientLastNameController.text.trim(),
      'gender': _newPatientGender,
    };
  }

  Future<void> _loadPatientOptions() async {
    setState(() {
      _isLoadingPatients = true;
    });
    final Result<AppPage<Patient>> result = await ref
        .read(patientRepositoryProvider)
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
        .read(opdRepositoryProvider)
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
      failure: (_) {
        setState(() {
          _isLoadingAppointments = false;
        });
      },
    );
  }

  Future<void> _loadProviderOptions() async {
    setState(() {
      _isLoadingProviders = true;
    });
    final Result<List<OpdProviderOption>> result = await ref
        .read(opdRepositoryProvider)
        .listProviders();
    if (!mounted) {
      return;
    }

    result.when(
      success: (List<OpdProviderOption> providers) {
        setState(() {
          _providerOptions = providers;
          _applyProviderDefaultsToState(_providerId);
          _isLoadingProviders = false;
        });
      },
      failure: (_) {
        setState(() {
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

    return options.values.toList(growable: false);
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
      if (activeEncounter != null)
        'existing_encounter_id': activeEncounter.apiId,
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
      'require_consultation_payment': _requireConsultationPayment,
      if (canReuseOpenEncounter) 'reuse_open_encounter': true,
      'create_consultation_invoice':
          hasConsultationFee || _requireConsultationPayment,
      'notes': notes,
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

class _ActiveEncounterDetail extends StatelessWidget {
  const _ActiveEncounterDetail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 132, maxWidth: 220),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: theme.spacing.xs / 2),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
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
    required this.isLoading,
    required this.onChanged,
  });

  final String? value;
  final List<OpdProviderOption> providers;
  final List<OpdProviderSchedule> schedules;
  final String labelText;
  final String helperText;
  final String emptyHelperText;
  final bool enabled;
  final bool isLoading;
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
      helperText: options.isEmpty && !isLoading ? emptyHelperText : helperText,
      semanticLabel: labelText,
      enabled: enabled,
      isLoading: isLoading,
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
  final Map<String, AppSelectOption<String>> options =
      <String, AppSelectOption<String>>{};

  for (final OpdProviderOption provider in providers) {
    final String value = provider.id;
    if (!_isNonEmpty(value) || options.containsKey(value)) {
      continue;
    }
    options[value] = AppSelectOption<String>(
      value: value,
      label: _joinDisplay(<String?>[
        provider.displayTitle,
        provider.positionTitle,
        provider.practitionerType,
        provider.staffProfileId,
        value,
      ]),
      leadingIcon: const Icon(Icons.person_search_outlined),
      labelWidget: AppListItemText(
        title: provider.displayTitle,
        subtitle: _joinDisplay(<String?>[
          provider.positionTitle,
          provider.practitionerType,
          provider.staffProfileId,
        ]),
      ),
    );
  }

  for (final OpdProviderSchedule schedule in schedules) {
    final String value = schedule.providerApiId;
    if (!_isNonEmpty(value) || options.containsKey(value)) {
      continue;
    }
    options[value] = AppSelectOption<String>(
      value: value,
      label: _joinDisplay(<String?>[
        schedule.providerDisplayName,
        value,
        schedule.facilityName,
      ]),
      leadingIcon: const Icon(Icons.person_search_outlined),
      labelWidget: AppListItemText(
        title: schedule.providerDisplayName ?? value,
        subtitle: schedule.facilityName,
      ),
    );
  }

  return options.values.toList(growable: false);
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
