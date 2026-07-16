import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/utils/app_display.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/opd/presentation/controllers/opd_encounter_dialog_controller.dart';
import 'package:hosspi_hms/features/opd/presentation/controllers/opd_workspace_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_action_context.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_provider_options.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_status_display.dart';

/// Opens [RecordVitalsDialog] with mutating-dialog dismiss rules.
Future<bool?> showRecordVitalsDialog({
  required BuildContext context,
  required OpdFlowSummary flow,
  OpdFlowDetail? detail,
  bool editing = false,
}) {
  return showAppDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => RecordVitalsDialog(
      flow: flow,
      detail: detail,
      editing: editing,
    ),
  );
}

/// OPD encounter vitals dialog composed on [AppRecordVitalsDialog].
///
/// Keeps triage/routing sections while reusing the canonical vitals shell used
/// by nursing and other modules.
class RecordVitalsDialog extends ConsumerStatefulWidget {
  const RecordVitalsDialog({
    required this.flow,
    this.detail,
    this.editing = false,
    super.key,
  });

  final OpdFlowSummary flow;
  final OpdFlowDetail? detail;
  final bool editing;

  @override
  ConsumerState<RecordVitalsDialog> createState() => _RecordVitalsDialogState();
}

class _RecordVitalsDialogState extends ConsumerState<RecordVitalsDialog> {
  late final TextEditingController _chiefComplaintController;
  late final TextEditingController _symptomsController;
  late final TextEditingController _allergiesController;
  late final TextEditingController _notesController;
  String? _triageLevel;
  String? _painSeverity;
  String? _routeDecision;
  String? _providerId;
  final Set<String> _riskFlags = <String>{};
  List<OpdProviderOption> _providerOptions = const <OpdProviderOption>[];
  List<OpdProviderSchedule> _providerSchedules = const <OpdProviderSchedule>[];
  bool _emergencyIndicator = false;
  bool _isLoadingProviders = false;
  AppFailure? _providerLoadFailure;

  bool get _editingVitals => widget.editing && widget.detail != null;

  @override
  void initState() {
    super.initState();
    _chiefComplaintController = TextEditingController(
      text: widget.flow.chiefComplaint ?? '',
    );
    _symptomsController = TextEditingController();
    _allergiesController = TextEditingController();
    _notesController = TextEditingController();
    _triageLevel = widget.flow.triageLevel;
    _providerId = widget.flow.providerUserId;
    unawaited(_loadProviderOptions());
  }

  @override
  void dispose() {
    _chiefComplaintController.dispose();
    _symptomsController.dispose();
    _allergiesController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String actionLabel = _editingVitals
        ? l10n.opdEditVitalsAction
        : l10n.opdRecordVitalsAction;
    return AppRecordVitalsDialog(
      title: actionLabel,
      submitLabel: actionLabel,
      cancelLabel: l10n.commonCancelActionLabel,
      temperatureLabel: l10n.patientsTemperatureLabel,
      systolicLabel: l10n.patientsSystolicLabel,
      diastolicLabel: l10n.patientsDiastolicLabel,
      heartRateLabel: l10n.patientsHeartRateLabel,
      respiratoryRateLabel: l10n.patientsRespiratoryRateLabel,
      oxygenSaturationLabel: l10n.patientsOxygenSaturationLabel,
      weightLabel: l10n.patientsWeightLabel,
      heightLabel: l10n.patientsHeightLabel,
      bloodPressureLabel: l10n.patientsBloodPressureLabel,
      unitLabel: l10n.patientsVitalUnitLabel,
      recordedDateLabel: l10n.nursingRecordedAtLabel,
      recordedTimeLabel: l10n.opdTimeColumnLabel,
      datePickerLabel: l10n.nursingDatePickerLabel,
      invalidDateMessage: l10n.nursingInvalidDateMessage,
      timePickerLabel: l10n.appTimePickerAction,
      invalidTimeMessage: l10n.appTimeInvalidMessage,
      requiredMessage: l10n.validationRequired,
      timeFormatHint: l10n.appTimeFormatHint,
      vitalsSectionTitle: l10n.patientsVitalsSectionTitle,
      vitalsHelperText: l10n.opdVitalsAtLeastOneRequiredHelper,
      atLeastOneVitalMessage: l10n.opdVitalsAtLeastOneRequiredHelper,
      showRecordedAt: false,
      normalizeBloodPressureToMmHg: true,
      isBusy: _isLoadingProviders,
      maxWidth: 780,
      initialValues: _initialValues(),
      leadingSectionsBuilder: _leadingSections,
      trailingSectionsBuilder: _trailingSections,
      formStatusSectionsBuilder: _formStatusSections,
      onSubmit: _submitVitals,
    );
  }

  List<Widget> _leadingSections(BuildContext context, bool enabled) {
    return <Widget>[
      OpdActionContextPanel(flow: widget.flow, showTitle: false),
      if (!_editingVitals) _triagePrioritySection(context, enabled),
    ];
  }

  List<Widget> _trailingSections(BuildContext context, bool enabled) {
    return <Widget>[_notesSection(context, enabled)];
  }

  List<Widget> _formStatusSections(BuildContext context) {
    if (_providerLoadFailure == null) {
      return const <Widget>[];
    }
    return <Widget>[
      AppFormInformationBanner.failure(
        context: context,
        failure: _providerLoadFailure!,
      ),
    ];
  }

  Widget _triagePrioritySection(BuildContext context, bool enabled) {
    final AppLocalizations l10n = context.l10n;
    return AppFormSection(
      title: l10n.patientsTriagePrioritySectionTitle,
      density: AppFormSectionDensity.compact,
      children: <Widget>[
        AppTextField(
          controller: _chiefComplaintController,
          labelText: _optionalFieldLabel(l10n, l10n.opdChiefComplaintLabel),
          enabled: enabled,
          maxLines: 2,
        ),
        AppTextField(
          controller: _symptomsController,
          labelText: _optionalFieldLabel(l10n, l10n.opdSymptomsLabel),
          enabled: enabled,
          maxLines: 2,
        ),
        AppResponsiveFieldRow(
          gap: AppResponsiveFieldRowGap.form,
          children: <Widget>[
            AppSelectField<String>.searchable(
              value: _painSeverity,
              labelText: _optionalFieldLabel(l10n, l10n.opdPainSeverityLabel),
              semanticLabel: _optionalFieldLabel(
                l10n,
                l10n.opdPainSeverityLabel,
              ),
              enabled: enabled,
              onChanged: (String? value) {
                setState(() => _painSeverity = value);
              },
              options: _painSeverityOptions,
            ),
            AppTextField(
              controller: _allergiesController,
              labelText: _optionalFieldLabel(l10n, l10n.opdAllergiesLabel),
              enabled: enabled,
            ),
          ],
        ),
        AppSwitchField(
          title: l10n.opdEmergencyIndicatorsLabel,
          value: _emergencyIndicator,
          enabled: enabled,
          secondary: const Icon(Icons.emergency_outlined),
          onChanged: (bool value) {
            setState(() {
              _emergencyIndicator = value;
              if (value && _triageLevel == null) {
                _triageLevel = 'LEVEL_1';
              }
              if (value && _routeDecision == null) {
                _routeDecision = 'EMERGENCY';
              }
            });
          },
        ),
        AppTriageRiskFlagSelector(
          title: l10n.opdRiskFlagsLabel,
          options: _triageRiskFlagFieldOptions(l10n),
          selected: _riskFlags,
          enabled: enabled,
          onChanged: _setRiskFlag,
        ),
        AppTriageUrgencyField(
          value: _triageLevel,
          labelText: _optionalFieldLabel(l10n, l10n.opdTriageLevelLabel),
          semanticLabel: _optionalFieldLabel(l10n, l10n.opdTriageLevelLabel),
          enabled: enabled,
          onChanged: (String? value) => setState(() => _triageLevel = value),
          options: _triageLevelFieldOptions(l10n),
        ),
        AppTriageDecisionField(
          value: _routeDecision ?? _noRouteDecisionValue,
          labelText: _optionalFieldLabel(l10n, l10n.opdRouteDecisionLabel),
          semanticLabel: _optionalFieldLabel(l10n, l10n.opdRouteDecisionLabel),
          enabled: enabled,
          onChanged: (String? value) {
            setState(() {
              _routeDecision =
                  value == null || value == _noRouteDecisionValue ? null : value;
            });
          },
          options: _routeDecisionOptions(context),
        ),
        if (_routeDecision == 'CONSULTATION')
          _RecordVitalsProviderSelectField(
            value: _providerId,
            providers: _providerOptions,
            schedules: _providerSchedules,
            labelText: _optionalFieldLabel(l10n, l10n.opdSearchProviderLabel),
            helperText: l10n.opdSearchProviderHelper,
            emptyHelperText: l10n.opdNoProvidersHelper,
            enabled: enabled,
            isLoading: _isLoadingProviders,
            onChanged: (String? value) {
              setState(() => _providerId = value);
            },
          ),
      ],
    );
  }

  Widget _notesSection(BuildContext context, bool enabled) {
    final AppLocalizations l10n = context.l10n;
    return AppFormSection(
      title: l10n.patientsNotesSectionTitle,
      density: AppFormSectionDensity.compact,
      children: <Widget>[
        AppTextField(
          controller: _notesController,
          labelText: _optionalFieldLabel(l10n, l10n.opdTriageNotesLabel),
          enabled: enabled,
          maxLines: 3,
        ),
      ],
    );
  }

  Future<AppFailure?> _submitVitals(List<Map<String, Object?>> vitals) async {
    final AppLocalizations l10n = context.l10n;
    if (!_editingVitals &&
        _routeDecision == 'CONSULTATION' &&
        !_isNonEmpty(_providerId ?? widget.flow.providerUserId)) {
      return AppFailure.validation(
        validationFields: const <String>{'provider_user_id'},
      );
    }

    final String triageNotes = _triageNotesPayload(l10n);
    final AppFailure? failure = _editingVitals
        ? await ref
              .read(opdWorkspaceControllerProvider.notifier)
              .updateVitals(widget.detail!, vitals)
        : await ref
              .read(opdWorkspaceControllerProvider.notifier)
              .recordVitals(widget.flow, <String, Object?>{
                'vitals': vitals,
                'triage_level': _triageLevel,
                'triage_priority': _triageLevel,
                'chief_complaint': _chiefComplaintController.text.trim(),
                'emergency': _emergencyIndicator,
                'triage_notes': triageNotes,
              });
    if (failure != null) {
      return failure;
    }

    final String? routeDecision = _editingVitals ? null : _routeDecision;
    if (_isNonEmpty(routeDecision)) {
      return ref
          .read(opdWorkspaceControllerProvider.notifier)
          .disposeFlow(
            widget.flow,
            routeDecision!.trim(),
            triageNotes,
            providerUserId: _providerId,
            triageLevel: _triageLevel,
            emergency: _emergencyIndicator,
          );
    }
    return null;
  }

  AppRecordVitalsInitialValues? _initialValues() {
    if (!_editingVitals) {
      return null;
    }
    return AppRecordVitalsInitialValues(
      temperature: _initialVitalValue('TEMPERATURE'),
      systolic: _initialSystolicValue(),
      diastolic: _initialDiastolicValue(),
      heartRate: _initialVitalValue('HEART_RATE'),
      respiratoryRate: _initialVitalValue('RESPIRATORY_RATE'),
      oxygenSaturation: _initialVitalValue('OXYGEN_SATURATION'),
      weight: _initialVitalValue('WEIGHT'),
      height: _initialVitalValue('HEIGHT'),
      bloodPressureUnit: _initialVitalUnit(
        'BLOOD_PRESSURE',
        AppVitalsUnits.bloodPressureMmHg,
      ),
      temperatureUnit: _initialVitalUnit(
        'TEMPERATURE',
        AppVitalsUnits.temperatureCelsius,
      ),
      weightUnit: _initialVitalUnit('WEIGHT', AppVitalsUnits.weightKilograms),
      heightUnit: _initialVitalUnit('HEIGHT', AppVitalsUnits.heightCentimeters),
    );
  }

  String _initialVitalValue(String type) {
    final OpdVitalSign? vital = _initialVital(type);
    return _formatOpdVitalInput(vital?.value);
  }

  String _initialSystolicValue() {
    final OpdVitalSign? vital = _initialVital('BLOOD_PRESSURE');
    final String value = _formatOpdVitalNumber(vital?.systolicValue);
    return value.isEmpty ? _legacyBloodPressurePart(vital?.value, 0) : value;
  }

  String _initialDiastolicValue() {
    final OpdVitalSign? vital = _initialVital('BLOOD_PRESSURE');
    final String value = _formatOpdVitalNumber(vital?.diastolicValue);
    return value.isEmpty ? _legacyBloodPressurePart(vital?.value, 1) : value;
  }

  String _initialVitalUnit(String type, String fallback) {
    final String normalized = _initialVital(type)?.unit?.trim() ?? '';
    return switch (normalized) {
      AppVitalsUnits.bloodPressureKpa => AppVitalsUnits.bloodPressureKpa,
      AppVitalsUnits.bloodPressureMmHg => AppVitalsUnits.bloodPressureMmHg,
      AppVitalsUnits.temperatureFahrenheit ||
      'F' => AppVitalsUnits.temperatureFahrenheit,
      AppVitalsUnits.temperatureCelsius ||
      'C' => AppVitalsUnits.temperatureCelsius,
      AppVitalsUnits.weightPounds => AppVitalsUnits.weightPounds,
      AppVitalsUnits.weightKilograms => AppVitalsUnits.weightKilograms,
      AppVitalsUnits.heightMeters => AppVitalsUnits.heightMeters,
      AppVitalsUnits.heightCentimeters => AppVitalsUnits.heightCentimeters,
      _ => fallback,
    };
  }

  OpdVitalSign? _initialVital(String type) {
    OpdVitalSign? latest;
    for (final OpdVitalSign vital
        in widget.detail?.vitalMeasurements ?? const <OpdVitalSign>[]) {
      if (vital.vitalType != type) {
        continue;
      }
      if (latest == null) {
        latest = vital;
        continue;
      }
      final DateTime? recordedAt = vital.recordedAt;
      final DateTime? latestRecordedAt = latest.recordedAt;
      if (recordedAt != null &&
          (latestRecordedAt == null || recordedAt.isAfter(latestRecordedAt))) {
        latest = vital;
      }
    }
    return latest;
  }

  String _formatOpdVitalInput(String? value) {
    final num? parsed = value == null ? null : num.tryParse(value.trim());
    if (parsed == null) {
      return value?.trim() ?? '';
    }
    return formatAppVitalNumber(parsed);
  }

  String _formatOpdVitalNumber(num? value) {
    return value == null ? '' : formatAppVitalNumber(value);
  }

  String _legacyBloodPressurePart(String? value, int index) {
    final List<String> parts = (value ?? '').split('/');
    if (parts.length <= index) {
      return '';
    }
    return _formatOpdVitalInput(parts[index]);
  }

  void _setRiskFlag(String flag, bool selected) {
    setState(() {
      if (selected) {
        _riskFlags.add(flag);
      } else {
        _riskFlags.remove(flag);
      }
    });
  }

  Future<void> _loadProviderOptions() async {
    setState(() {
      _isLoadingProviders = true;
      _providerLoadFailure = null;
    });
    final OpdEncounterDialogController dialogController = ref.read(
      opdEncounterDialogControllerProvider,
    );
    final List<Object> results = await Future.wait(<Future<Object>>[
      dialogController.listProviders(),
      dialogController.listProviderSchedules(),
    ]);
    if (!mounted) {
      return;
    }

    final Result<List<OpdProviderOption>> providerResult =
        results[0] as Result<List<OpdProviderOption>>;
    final Result<List<OpdProviderSchedule>> scheduleResult =
        results[1] as Result<List<OpdProviderSchedule>>;

    AppFailure? loadFailure;
    providerResult.when(
      success: (List<OpdProviderOption> providers) {
        _providerOptions = dedupeOpdProviderOptions(providers);
      },
      failure: (AppFailure failure) {
        loadFailure = failure;
      },
    );
    scheduleResult.when(
      success: (List<OpdProviderSchedule> schedules) {
        _providerSchedules = schedules;
      },
      failure: (AppFailure failure) {
        loadFailure ??= failure;
      },
    );
    setState(() {
      _providerLoadFailure = loadFailure;
      _isLoadingProviders = false;
    });
  }

  String _triageNotesPayload(AppLocalizations l10n) {
    final List<String> lines = <String>[];
    void add(String label, String value) {
      final String normalized = value.trim();
      if (normalized.isNotEmpty) {
        lines.add('$label: $normalized');
      }
    }

    add(l10n.opdSymptomsLabel, _symptomsController.text);
    add(l10n.opdPainSeverityLabel, _painSeverity ?? '');
    add(l10n.opdAllergiesLabel, _allergiesController.text);
    if (_riskFlags.isNotEmpty) {
      lines.add(
        '${l10n.opdRiskFlagsLabel}: ${_riskFlags.map((String flag) => _riskFlagLabel(l10n, flag)).join(', ')}',
      );
    }
    add(l10n.opdTriageNotesLabel, _notesController.text);
    return lines.join('\n');
  }
}

class _RecordVitalsProviderSelectField extends StatelessWidget {
  const _RecordVitalsProviderSelectField({
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
    final List<AppSelectOption<String>> options = opdProviderSelectOptions(
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

List<AppTriageOption> _triageLevelFieldOptions(AppLocalizations l10n) {
  return <AppTriageOption>[
    for (final String value in _triageLevelOptions)
      AppTriageOption(
        value: value,
        label: triageLevelDisplayLabel(l10n, value, emptyAsPending: false),
        tone: appTriageToneForValue(value),
        icon: appTriageIconForValue(value),
      ),
  ];
}

List<AppTriageOption> _triageRouteFieldOptions() {
  return <AppTriageOption>[
    for (final String value in _triageRouteOptions)
      AppTriageOption(
        value: value,
        label: _apiLabel(value),
        tone: appTriageToneForValue(value),
        icon: appTriageIconForValue(value),
      ),
  ];
}

List<AppTriageRiskFlagOption> _triageRiskFlagFieldOptions(
  AppLocalizations l10n,
) {
  return <AppTriageRiskFlagOption>[
    for (final String value in _triageRiskFlagOptions)
      AppTriageRiskFlagOption(
        value: value,
        label: _riskFlagLabel(l10n, value),
        icon: _riskFlagIcon(value),
      ),
  ];
}

List<AppTriageOption> _routeDecisionOptions(BuildContext context) {
  return <AppTriageOption>[
    AppTriageOption(
      value: _noRouteDecisionValue,
      label: context.l10n.opdNoRouteDecisionLabel,
      tone: AppWorkspaceStatusTone.neutral,
      icon: Icons.remove_circle_outline,
    ),
    ..._triageRouteFieldOptions(),
  ];
}

String _riskFlagLabel(AppLocalizations l10n, String flag) {
  return switch (flag) {
    _riskFlagFall => l10n.opdRiskFlagFall,
    _riskFlagPregnancy => l10n.opdRiskFlagPregnancy,
    _riskFlagInfection => l10n.opdRiskFlagInfection,
    _riskFlagAlteredMentalState => l10n.opdRiskFlagAlteredMentalState,
    _riskFlagBleeding => l10n.opdRiskFlagBleeding,
    _ => _apiLabel(flag),
  };
}

IconData _riskFlagIcon(String flag) {
  return switch (flag) {
    _riskFlagFall => Icons.personal_injury_outlined,
    _riskFlagPregnancy => Icons.pregnant_woman_outlined,
    _riskFlagInfection => Icons.coronavirus_outlined,
    _riskFlagAlteredMentalState => Icons.psychology_alt_outlined,
    _riskFlagBleeding => Icons.bloodtype_outlined,
    _ => Icons.warning_amber_outlined,
  };
}

String _optionalFieldLabel(AppLocalizations l10n, String label) {
  return l10n.opdFieldOptionalLabel(label);
}

bool _isNonEmpty(String? value) {
  return value != null && value.trim().isNotEmpty;
}

String _apiLabel(String value) => AppDisplay.apiLabel(value);

final List<AppSelectOption<String>> _painSeverityOptions =
    List<AppSelectOption<String>>.unmodifiable(<AppSelectOption<String>>[
      for (int value = 0; value <= 10; value += 1)
        AppSelectOption<String>(value: '$value', label: value.toString()),
    ]);

const String _noRouteDecisionValue = 'NO_ROUTE_DECISION';
const String _riskFlagFall = 'FALL_RISK';
const String _riskFlagPregnancy = 'PREGNANCY';
const String _riskFlagInfection = 'INFECTION_RISK';
const String _riskFlagAlteredMentalState = 'ALTERED_MENTAL_STATE';
const String _riskFlagBleeding = 'BLEEDING';

const List<String> _triageRiskFlagOptions = <String>[
  _riskFlagFall,
  _riskFlagPregnancy,
  _riskFlagInfection,
  _riskFlagAlteredMentalState,
  _riskFlagBleeding,
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

const List<String> _triageRouteOptions = <String>[
  'CONSULTATION',
  'EMERGENCY',
  'ADMIT',
  'THEATRE',
  'MINOR_PROCEDURE',
  'LAB',
  'RADIOLOGY',
  'LAB_AND_RADIOLOGY',
  'PHYSIOTHERAPY',
  'OTHER_SERVICE',
  'DISCHARGE',
];
