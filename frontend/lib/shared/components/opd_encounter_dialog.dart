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
import 'package:hosspi_hms/features/claims/data/repositories/insurance_catalog_repository.dart';
import 'package:hosspi_hms/features/opd/data/repositories/opd_repository_impl.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/patients/data/repositories/patient_repository_impl.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_request_billing_resolve.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_request_billing_state.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/components/app_checkbox_field.dart';
import 'package:hosspi_hms/shared/components/app_content_panel.dart';
import 'package:hosspi_hms/shared/components/app_copyable_identifier.dart';
import 'package:hosspi_hms/shared/components/app_currency_amount_field.dart';
import 'package:hosspi_hms/shared/components/app_dialog.dart';
import 'package:hosspi_hms/shared/components/app_form_information_banner.dart';
import 'package:hosspi_hms/shared/components/app_payment_method.dart';
import 'package:hosspi_hms/shared/components/app_select_field.dart';
import 'package:hosspi_hms/shared/components/app_switch_field.dart';
import 'package:hosspi_hms/shared/components/app_text_field.dart';
import 'package:hosspi_hms/shared/components/app_triage_components.dart';
import 'package:hosspi_hms/shared/data/data.dart';
import 'package:hosspi_hms/shared/forms/app_form_section.dart';
import 'package:hosspi_hms/shared/forms/app_form_shell.dart';
import 'package:hosspi_hms/shared/forms/app_responsive_field_row.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_billing_state.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_provider_options.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_status_display.dart';
import 'package:hosspi_hms/shared/patient_actions/patient_actions.dart';

const IconData opdEncounterIcon = Icons.person_add_alt_1_outlined;

const AccessRequirement opdEncounterPermissionRequirement = AccessRequirement(
  anyRoles: <AppRole>[
    AppRole.superAdmin,
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

const List<String> _opdStartPaymentMethods = <String>[
  'CASH',
  'MOBILE_MONEY',
  'BANK_TRANSFER',
  'CREDIT_CARD',
  'INSURANCE',
  'OTHER',
];

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
    this.source,
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
  final String? source;
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
  late final TextEditingController _transactionRefController;
  List<Patient> _patientOptions = const <Patient>[];
  List<OpdAppointment> _appointmentOptions = const <OpdAppointment>[];
  List<OpdProviderOption> _providerOptions = const <OpdProviderOption>[];
  PatientReferenceData _patientReferenceData = const PatientReferenceData();
  _WalkInPatientMode _patientMode = _WalkInPatientMode.existing;
  bool _isLoadingPatients = false;
  bool _isLoadingAppointments = false;
  bool _isLoadingProviders = false;
  bool _isResolvingActiveEncounter = false;
  String? _patientId;
  String? _appointmentId;
  String? _providerId;
  OpdFlowSummary? _activeEncounter;
  String _currency = appDefaultCurrencyCode;
  String _arrivalMode = 'WALK_IN';
  String _emergencySeverity = 'HIGH';
  String? _triageLevel;
  String _paymentMethod = 'CASH';
  bool _requireConsultationPayment = true;
  bool _payNow = false;
  bool _isSaving = false;
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

  @override
  void initState() {
    super.initState();
    _feeController = TextEditingController();
    _notesController = TextEditingController();
    _transactionRefController = TextEditingController();
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
    unawaited(_loadPatientReferenceData());
    unawaited(_loadBillingDefaults());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _applyInitialContext();
        _refreshActiveEncounterForSelection();
      }
    });
  }

  @override
  void dispose() {
    _feeController.dispose();
    _notesController.dispose();
    _transactionRefController.dispose();
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
        _requireConsultationPayment = true;
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
    final bool isNewPatientMode = _patientMode == _WalkInPatientMode.newPatient;
    final String primaryActionLabel = isNewPatientMode
        ? l10n.opdCreatePatientAction
        : hasActiveEncounter
        ? l10n.opdOpenActiveEncounterAction
        : l10n.opdStartEncounterAction;
    final IconData primaryActionIcon = isNewPatientMode
        ? Icons.person_add_alt_1_outlined
        : hasActiveEncounter
        ? Icons.save_outlined
        : Icons.play_arrow_outlined;

    return AppDialog(
      title: Text(l10n.opdWalkInDialogTitle),
      icon: const Icon(opdEncounterIcon),
      scrollable: true,
      closeEnabled: !_isSaving,
      maxWidth: 880,
      content: AppFormShell(
        formKey: _formKey,
        enabled: !_isSaving,
        formStatus: appFormFailureStatus(context, _failure),
        children: <Widget>[
          if (_shouldShowActiveEncounterNotice()) _activeEncounterNotice(l10n),
          if (_showPatientSection)
            AppSectionPanel(
              title: l10n.opdPatientSectionTitle,
              density: AppContentPanelDensity.compact,
              children: <Widget>[
                _WalkInModeSelector(
                  value: _patientMode,
                  enabled: !_isSaving && !hasActiveEncounter,
                  existingLabel: l10n.opdExistingPatientModeLabel,
                  appointmentLabel: l10n.opdAppointmentPatientModeLabel,
                  newPatientLabel: l10n.opdNewPatientModeLabel,
                  onChanged: _setPatientMode,
                ),
                _patientModeContent(l10n),
              ],
            )
          else if (_pinPatientContext)
            _knownPatientSummary(l10n),
          AppResponsiveFieldRow.two(
            left: _routingSection(l10n),
            right: _billingSection(l10n),
            breakpoint: 760,
            gap: AppResponsiveFieldRowGap.form,
          ),
        ],
      ),
      actions: <Widget>[
        if (hasActiveEncounter) ...<Widget>[
          AppButton.secondary(
            label: l10n.opdContinueEncounterAction,
            leadingIcon: Icons.play_arrow_outlined,
            enabled: !_isSaving,
            onPressed: _continueWorkflow,
          ),
          if (widget.onCloseEncounter != null)
            AppButton.secondary(
              label: l10n.opdCloseEncounterAction,
              leadingIcon: Icons.check_circle_outline,
              enabled: !_isSaving,
              onPressed: _promptCloseEncounter,
            ),
          if (widget.onCancelEncounter != null)
            AppButton.secondary(
              label: l10n.opdCancelEncounterAction,
              leadingIcon: Icons.cancel_outlined,
              enabled: !_isSaving,
              onPressed: _promptCancelEncounter,
            ),
        ],
        AppButton.primary(
          label: primaryActionLabel,
          leadingIcon: primaryActionIcon,
          enabled:
              !_isSaving &&
              (!_isResolvingActiveEncounter || _activeEncounter != null),
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
            helperText: _lockArrivalMode
                ? l10n.opdEncounterArrivalModeLockedHelper
                : null,
            enabled: !_isSaving && !_lockArrivalMode,
            onChanged: (String? value) {
              setState(() {
                _arrivalMode = value ?? 'WALK_IN';
                _requireConsultationPayment = _arrivalMode != 'EMERGENCY';
                if (!_requireConsultationPayment) {
                  _payNow = false;
                }
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
    final OpdFlowSummary? activeEncounter = _activeEncounter;
    final bool billingAlreadyPaid =
        activeEncounter != null &&
        opdFlowBillingState(activeEncounter) == OpdBillingState.paid;

    return AppSectionPanel(
      title: l10n.opdBillingSectionTitle,
      density: AppContentPanelDensity.compact,
      children: <Widget>[
        if (billingAlreadyPaid)
          AppFormInformationBanner.message(
            title: l10n.opdPaymentStatusLabel,
            message: l10n.opdEncounterBillingPaidBanner,
          ),
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
          isRequired: _payNow,
          allowZero: !_payNow,
          onCurrencyChanged: (String? value) {
            setState(() {
              _currency = value ?? appDefaultCurrencyCode;
            });
          },
        ),
        if (_engineFeeResolved)
          AppFormInformationBanner.message(
            title: l10n.opdBillingSectionTitle,
            message: _payerContext?.insured == true
                ? '${l10n.opdEngineResolvedFeeHint} '
                      '${_payerContext?.payerLabel ?? ''} · '
                      '${l10n.billingReceivePaymentPatientShareLabel}: '
                      '${_resolvedConsultationLine?.patientShare ?? '-'} · '
                      '${l10n.billingReceivePaymentInsurerShareLabel}: '
                      '${_resolvedConsultationLine?.insurerShare ?? '-'}'
                : l10n.opdEngineResolvedFeeHint,
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
          enabled: !_isSaving && !billingAlreadyPaid,
          secondary: const Icon(Icons.payments_outlined),
          onChanged: (bool value) {
            setState(() {
              _requireConsultationPayment = value;
              if (!value) {
                _payNow = false;
              }
            });
          },
        ),
        AppCheckboxField(
          title: l10n.patientsMarkPaymentReceivedLabel,
          value: _payNow,
          enabled: !_isSaving && !billingAlreadyPaid,
          secondary: const Icon(Icons.point_of_sale_outlined),
          onChanged: (bool value) {
            setState(() {
              _payNow = value;
              if (value) {
                _requireConsultationPayment = true;
              }
            });
          },
        ),
        if (_payNow)
          AppResponsiveFieldRow.two(
            left: AppSelectField<String>.searchable(
              value: _paymentMethod,
              labelText: _opdRequiredFieldLabel(
                l10n,
                l10n.opdPaymentMethodLabel,
              ),
              semanticLabel: _opdRequiredFieldLabel(
                l10n,
                l10n.opdPaymentMethodLabel,
              ),
              enabled: !_isSaving,
              onChanged: (String? value) {
                setState(() {
                  _paymentMethod = value ?? 'CASH';
                });
              },
              options: buildAppPaymentMethodSelectOptions(
                methods: _opdStartPaymentMethods,
              ),
              validator: (String? value) => _payNow && !_isNonEmpty(value)
                  ? l10n.validationRequired
                  : null,
            ),
            right: AppTextField(
              controller: _transactionRefController,
              labelText: _opdOptionalFieldLabel(
                l10n,
                l10n.opdTransactionReferenceLabel,
              ),
              enabled: !_isSaving,
            ),
            breakpoint: 520,
            gap: AppResponsiveFieldRowGap.form,
          ),
      ],
    );
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
    return Padding(
      padding: EdgeInsets.only(bottom: theme.spacing.md),
      child: AppFormInformationBanner.message(
        title: l10n.opdPatientSectionTitle,
        message: _joinDisplay(<String?>[
          patient.effectiveDisplayName,
          patient.effectiveIdentifier,
          patient.primaryPhone,
        ]),
      ),
    );
  }

  Widget _activeEncounterNotice(AppLocalizations l10n) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final OpdFlowSummary? flow = _activeEncounter;
    if (_isResolvingActiveEncounter && flow == null) {
      return Padding(
        padding: EdgeInsets.only(bottom: theme.spacing.md),
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

    return Padding(
      padding: EdgeInsets.only(bottom: theme.spacing.md),
      child: SizedBox(
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer.withValues(alpha: 0.28),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: EdgeInsets.all(theme.spacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                        label: stageLabel,
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
                LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final double maxWidth = constraints.maxWidth;
                    final int columns = maxWidth >= 900
                        ? 3
                        : maxWidth >= 560
                        ? 2
                        : 1;
                    final double itemWidth = columns == 1
                        ? maxWidth
                        : (maxWidth - theme.spacing.lg * (columns - 1)) /
                              columns;
                    final List<Widget> details = <Widget>[
                      _ActiveEncounterCopyableDetail(
                        label: l10n.clinicalEncounterNumberLabel,
                        value: flow.apiId,
                      ),
                      if (patient != null)
                        _ActiveEncounterCopyableDetail(
                          label: l10n.opdPatientIdLabel,
                          value:
                              patient.effectiveIdentifier ??
                              _firstNonEmptyText(<String?>[
                                patient.publicId,
                                patient.id,
                              ]) ??
                              l10n.profileUnknownValue,
                        ),
                      _ActiveEncounterDetail(
                        label: l10n.opdNextStepColumnLabel,
                        value: nextStepLabel.isEmpty
                            ? l10n.profileUnknownValue
                            : nextStepLabel,
                      ),
                      _ActiveEncounterDetail(
                        label: l10n.opdVisitTypeColumnLabel,
                        value: opdArrivalModeDisplayLabel(
                          l10n,
                          _firstNonEmptyText(<String?>[
                            flow.arrivalMode,
                            flow.encounterType,
                          ]),
                        ),
                      ),
                      _ActiveEncounterDetail(
                        label: l10n.opdProviderColumnLabel,
                        value:
                            flow.providerDisplayName ??
                            l10n.profileUnknownValue,
                      ),
                      _ActiveEncounterDetail(
                        label: l10n.opdPayerBillingColumnLabel,
                        value: _flowBillingLabel(context, flow),
                      ),
                      _ActiveEncounterDetail(
                        label: l10n.opdTimeColumnLabel,
                        value: _formatDateTime(context, flow.startedAt),
                      ),
                    ];

                    return Wrap(
                      spacing: theme.spacing.lg,
                      runSpacing: theme.spacing.sm,
                      children: <Widget>[
                        for (final Widget detail in details)
                          SizedBox(width: itemWidth, child: detail),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadBillingDefaults() async {
    final Patient? patient =
        widget.initialPatient ?? _patientByApiId(_patientId);
    final Result<OpdBillingDefaults> result = await ref
        .read(opdRepositoryProvider)
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
        });
      },
      failure: (_) {},
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

  Future<void> _promptCloseEncounter() async {
    final OpdFlowSummary? flow = _activeEncounter;
    if (flow == null || widget.onCloseEncounter == null) {
      return;
    }
    final Map<String, Object?>? payload =
        await showAppDialog<Map<String, Object?>>(
          context: context,
          builder: (_) => _CloseEncounterDialog(flow: flow),
        );
    if (payload == null || !mounted) {
      return;
    }
    await _runEncounterMutation(
      action: OpdEncounterDialogAction.closed,
      request: () => widget.onCloseEncounter!(flow.apiId, payload),
    );
  }

  Future<void> _promptCancelEncounter() async {
    final OpdFlowSummary? flow = _activeEncounter;
    if (flow == null || widget.onCancelEncounter == null) {
      return;
    }
    final Map<String, Object?>? payload =
        await showAppDialog<Map<String, Object?>>(
          context: context,
          builder: (_) => _CancelEncounterDialog(l10n: context.l10n),
        );
    if (payload == null || !mounted) {
      return;
    }
    await _runEncounterMutation(
      action: OpdEncounterDialogAction.cancelled,
      request: () => widget.onCancelEncounter!(flow.apiId, payload),
    );
  }

  Future<void> _runEncounterMutation({
    required OpdEncounterDialogAction action,
    required Future<Result<OpdFlowDetail>> Function() request,
  }) async {
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final Result<OpdFlowDetail> result = await request();
    if (!mounted) {
      return;
    }
    result.when(
      success: (OpdFlowDetail detail) {
        widget.onSuccess?.call();
        Navigator.of(
          context,
        ).pop(OpdEncounterDialogResult(action: action, flow: detail.summary));
      },
      failure: (AppFailure failure) {
        setState(() {
          _failure = failure;
          _isSaving = false;
        });
      },
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
      success: (OpdFlowDetail _) {
        final OpdFlowSummary? activeEncounter = _activeEncounter;
        if (activeEncounter != null) {
          widget.onExistingActiveEncounter?.call(activeEncounter);
        }
        widget.onSuccess?.call();
        Navigator.of(
          context,
        ).pop(OpdEncounterDialogResult(flow: activeEncounter));
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
    final RegisterNewPatientFormState? formState =
        _newPatientFormKey.currentState;
    if (formState != null) {
      final bool canContinue = await formState.prepareSubmit();
      if (!canContinue) {
        return;
      }
    }
    if (!validateAndSaveAppForm(_formKey)) {
      return;
    }
    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final Result<Patient> result = await ref
        .read(patientRepositoryProvider)
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
        options: _patientSelectOptions(),
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
        isLoading: _isLoadingAppointments,
        enabled: !_isSaving,
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
        enabled: !_isSaving,
        includeNotes: false,
        includeActiveToggle: false,
        requireGender: false,
        onLookupDuplicates: (PatientDuplicateQuery query) {
          return ref
              .read(patientRepositoryProvider)
              .listDuplicateCandidates(query);
        },
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

    final bool hasSearch = _isNonEmpty(search);
    setState(() {
      _isResolvingActiveEncounter = hasSearch;
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
      _lockArrivalMode = false;
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
    if (opdFlowBillingState(flow) == OpdBillingState.paid) {
      _payNow = false;
    }
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
        .read(insuranceCatalogRepositoryProvider)
        .resolvePayerContextForPatient(patientId);
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
    final List<ClinicalRequestBillingLineItem> resolved =
        await resolveClinicalRequestBillingLineItems(
          context: context,
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
    final Result<PatientReferenceData> result = await ref
        .read(patientRepositoryProvider)
        .loadReferenceData();
    if (!mounted) {
      return;
    }

    result.when(
      success: (PatientReferenceData data) {
        setState(() {
          _patientReferenceData = data;
        });
      },
      failure: (_) {},
    );
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
          _providerOptions = dedupeOpdProviderOptions(providers);
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

    return dedupeOpdProviderOptions(options.values);
  }

  Map<String, Object?> _payload() {
    final String notes = _notesController.text.trim();
    final String consultationFee = normalizeCurrencyAmount(_feeController.text);
    final String transactionRef = _transactionRefController.text.trim();
    final String arrivalMode = _patientMode == _WalkInPatientMode.appointment
        ? 'ONLINE_APPOINTMENT'
        : _arrivalMode;
    final bool hasConsultationFee = consultationFee.isNotEmpty;
    final bool submitPayment = _payNow && hasConsultationFee;
    final OpdFlowSummary? activeEncounter = _activeEncounter;
    final bool canReuseOpenEncounter =
        _patientMode != _WalkInPatientMode.newPatient;

    return <String, Object?>{
      if (_isNonEmpty(widget.source)) 'source': widget.source,
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
      if ((_payerContext?.coveragePlanId ?? '').trim().isNotEmpty)
        'coverage_plan_id': _payerContext!.coveragePlanId,
      if ((_payerContext?.insuranceCompanyId ?? '').trim().isNotEmpty)
        'insurance_company_id': _payerContext!.insuranceCompanyId,
      'require_consultation_payment': _requireConsultationPayment,
      if (canReuseOpenEncounter) 'reuse_open_encounter': true,
      'create_consultation_invoice':
          hasConsultationFee || _requireConsultationPayment || submitPayment,
      if (submitPayment)
        'pay_now': <String, Object?>{
          'method': _paymentMethod,
          'amount': consultationFee,
          'status': 'COMPLETED',
          if (transactionRef.isNotEmpty) 'transaction_ref': transactionRef,
          'paid_at': DateTime.now().toUtc().toIso8601String(),
        },
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

    return Column(
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
    );
  }
}

class _ActiveEncounterCopyableDetail extends StatelessWidget {
  const _ActiveEncounterCopyableDetail({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Column(
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
        AppCopyableIdentifier(
          value: value,
          copiedMessage: context.l10n.identifierCopiedMessage,
          textStyle: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _CloseEncounterDialog extends StatefulWidget {
  const _CloseEncounterDialog({required this.flow});

  final OpdFlowSummary flow;

  @override
  State<_CloseEncounterDialog> createState() => _CloseEncounterDialogState();
}

class _CloseEncounterDialogState extends State<_CloseEncounterDialog> {
  late final TextEditingController _reasonController;

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
      title: Text(l10n.opdCloseEncounterAction),
      icon: const Icon(Icons.check_circle_outline),
      content: AppFormSection(
        children: <Widget>[
          AppFormInformationBanner.message(
            title: l10n.clinicalEncounterNumberLabel,
            message: widget.flow.apiId,
          ),
          AppTextField(
            controller: _reasonController,
            labelText: l10n.opdEncounterCloseReasonLabel,
            maxLines: 3,
          ),
        ],
      ),
      actions: <Widget>[
        AppButton.primary(
          label: l10n.opdCloseEncounterAction,
          leadingIcon: Icons.check_circle_outline,
          onPressed: () {
            Navigator.of(context).pop(<String, Object?>{
              'reason_notes': _reasonController.text.trim(),
            });
          },
        ),
      ],
    );
  }
}

class _CancelEncounterDialog extends StatefulWidget {
  const _CancelEncounterDialog({required this.l10n});

  final AppLocalizations l10n;

  @override
  State<_CancelEncounterDialog> createState() => _CancelEncounterDialogState();
}

class _CancelEncounterDialogState extends State<_CancelEncounterDialog> {
  late final TextEditingController _notesController;
  String _reasonCode = _opdEncounterCancelReasonCodes.first;

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

  String _reasonLabel(String code) {
    return switch (code) {
      'PATIENT_LEFT' => widget.l10n.opdEncounterCancelReasonPatientLeft,
      'DUPLICATE_ENCOUNTER' => widget.l10n.opdEncounterCancelReasonDuplicate,
      'ENTERED_IN_ERROR' => widget.l10n.opdEncounterCancelReasonEnteredInError,
      'PATIENT_ALREADY_SEEN' => widget.l10n.opdEncounterCancelReasonAlreadySeen,
      _ => widget.l10n.opdEncounterCancelReasonOther,
    };
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = widget.l10n;
    return AppDialog(
      title: Text(l10n.opdCancelEncounterAction),
      icon: const Icon(Icons.cancel_outlined),
      content: AppFormSection(
        children: <Widget>[
          AppSelectField<String>.searchable(
            value: _reasonCode,
            labelText: l10n.opdEncounterCancelReasonCodeLabel,
            options: _opdEncounterCancelReasonCodes
                .map(
                  (String code) => AppSelectOption<String>(
                    value: code,
                    label: _reasonLabel(code),
                  ),
                )
                .toList(growable: false),
            onChanged: (String? value) {
              setState(() {
                _reasonCode = value ?? _reasonCode;
              });
            },
          ),
          if (_reasonCode == 'OTHER')
            AppTextField(
              controller: _notesController,
              labelText: l10n.opdEncounterCancelReasonNotesLabel,
              maxLines: 3,
            ),
        ],
      ),
      actions: <Widget>[
        AppButton.primary(
          label: l10n.opdCancelEncounterAction,
          leadingIcon: Icons.cancel_outlined,
          onPressed: () {
            final String notes = _notesController.text.trim();
            if (_reasonCode == 'OTHER' && notes.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    l10n.opdEncounterCancelReasonNotesRequiredMessage,
                  ),
                ),
              );
              return;
            }
            Navigator.of(context).pop(<String, Object?>{
              'reason_code': _reasonCode,
              'reason_notes': notes.isEmpty ? null : notes,
            });
          },
        ),
      ],
    );
  }
}

Future<OpdEncounterDialogResult?> showOpdEncounterDialog({
  required BuildContext context,
  required OpdEncounterDialog dialog,
  bool barrierDismissible = false,
}) {
  return showAppDialog<OpdEncounterDialogResult>(
    context: context,
    barrierDismissible: barrierDismissible,
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
