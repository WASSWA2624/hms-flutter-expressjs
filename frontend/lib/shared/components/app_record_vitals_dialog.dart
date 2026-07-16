import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_action_dialog_actions.dart';
import 'package:hosspi_hms/shared/components/app_date_field.dart';
import 'package:hosspi_hms/shared/components/app_dialog.dart';
import 'package:hosspi_hms/shared/components/app_form_information_banner.dart';
import 'package:hosspi_hms/shared/components/app_time_field.dart';
import 'package:hosspi_hms/shared/components/app_time_value.dart';
import 'package:hosspi_hms/shared/components/app_vitals_form.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/icons/app_action_icons.dart';

@immutable
final class AppRecordVitalsInitialValues {
  const AppRecordVitalsInitialValues({
    this.id,
    this.vitalType,
    this.value,
    this.unit,
    this.systolicValue,
    this.diastolicValue,
    this.recordedAt,
    this.temperature,
    this.systolic,
    this.diastolic,
    this.heartRate,
    this.respiratoryRate,
    this.oxygenSaturation,
    this.weight,
    this.height,
    this.bloodPressureUnit,
    this.temperatureUnit,
    this.weightUnit,
    this.heightUnit,
  });

  /// Single-vital edit id (nursing). When set, payload building scopes to
  /// [vitalType].
  final String? id;
  final String? vitalType;
  final String? value;
  final String? unit;
  final num? systolicValue;
  final num? diastolicValue;
  final DateTime? recordedAt;

  /// Multi-field seed for encounter flows that edit a full vitals set.
  final String? temperature;
  final String? systolic;
  final String? diastolic;
  final String? heartRate;
  final String? respiratoryRate;
  final String? oxygenSaturation;
  final String? weight;
  final String? height;
  final String? bloodPressureUnit;
  final String? temperatureUnit;
  final String? weightUnit;
  final String? heightUnit;

  bool get hasMultiFieldSeed {
    return <String?>[
      temperature,
      systolic,
      diastolic,
      heartRate,
      respiratoryRate,
      oxygenSaturation,
      weight,
      height,
    ].any((String? value) => value != null && value.trim().isNotEmpty);
  }
}

/// Canonical vitals recording dialog used by nursing, OPD, and other modules.
///
/// Compose domain-specific triage/routing chrome through
/// [leadingSectionsBuilder] / [trailingSectionsBuilder] without forking the
/// vitals form shell.
class AppRecordVitalsDialog extends StatefulWidget {
  const AppRecordVitalsDialog({
    required this.title,
    required this.submitLabel,
    required this.cancelLabel,
    required this.temperatureLabel,
    required this.systolicLabel,
    required this.diastolicLabel,
    required this.heartRateLabel,
    required this.respiratoryRateLabel,
    required this.oxygenSaturationLabel,
    required this.weightLabel,
    required this.heightLabel,
    required this.bloodPressureLabel,
    required this.unitLabel,
    required this.recordedDateLabel,
    required this.recordedTimeLabel,
    required this.datePickerLabel,
    required this.invalidDateMessage,
    required this.timePickerLabel,
    required this.invalidTimeMessage,
    required this.requiredMessage,
    required this.onSubmit,
    this.initialValues,
    this.icon = const Icon(Icons.monitor_heart_outlined),
    this.vitalsSectionTitle,
    this.vitalsHelperText,
    this.atLeastOneVitalMessage,
    this.requireAtLeastOneVital = true,
    this.showRecordedAt = true,
    this.normalizeBloodPressureToMmHg = false,
    this.isBusy = false,
    this.maxWidth = 760,
    this.timeFormatHint,
    this.leadingSectionsBuilder,
    this.trailingSectionsBuilder,
    this.formStatusSectionsBuilder,
    super.key,
  });

  final String title;
  final Widget icon;
  final String submitLabel;
  final String cancelLabel;
  final String temperatureLabel;
  final String systolicLabel;
  final String diastolicLabel;
  final String heartRateLabel;
  final String respiratoryRateLabel;
  final String oxygenSaturationLabel;
  final String weightLabel;
  final String heightLabel;
  final String bloodPressureLabel;
  final String unitLabel;
  final String recordedDateLabel;
  final String recordedTimeLabel;
  final String datePickerLabel;
  final String invalidDateMessage;
  final String timePickerLabel;
  final String invalidTimeMessage;
  final String requiredMessage;
  final AppRecordVitalsInitialValues? initialValues;
  final String? vitalsSectionTitle;
  final String? vitalsHelperText;
  final String? atLeastOneVitalMessage;
  final bool requireAtLeastOneVital;
  final bool showRecordedAt;
  final bool normalizeBloodPressureToMmHg;

  /// Parent-driven busy flag (e.g. reference data load). Blocks dismiss and
  /// form edits alongside in-dialog submit loading.
  final bool isBusy;
  final double maxWidth;
  final String? timeFormatHint;
  final List<Widget> Function(BuildContext context, bool enabled)?
  leadingSectionsBuilder;
  final List<Widget> Function(BuildContext context, bool enabled)?
  trailingSectionsBuilder;
  final List<Widget> Function(BuildContext context)? formStatusSectionsBuilder;
  final Future<AppFailure?> Function(List<Map<String, Object?>> payloads)
  onSubmit;

  @override
  State<AppRecordVitalsDialog> createState() => _AppRecordVitalsDialogState();
}

class _AppRecordVitalsDialogState extends State<AppRecordVitalsDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _temperatureController;
  late final TextEditingController _systolicController;
  late final TextEditingController _diastolicController;
  late final TextEditingController _heartRateController;
  late final TextEditingController _respiratoryRateController;
  late final TextEditingController _oxygenSaturationController;
  late final TextEditingController _weightController;
  late final TextEditingController _heightController;
  late DateTime _recordedDate;
  late AppTimeValue _recordedTime;
  String _bloodPressureUnit = AppVitalsUnits.bloodPressureMmHg;
  String _temperatureUnit = AppVitalsUnits.temperatureCelsius;
  String _weightUnit = AppVitalsUnits.weightKilograms;
  String _heightUnit = AppVitalsUnits.heightCentimeters;
  bool _isSaving = false;
  AppFailure? _failure;
  String? _formErrorText;

  @override
  void initState() {
    super.initState();
    _temperatureController = TextEditingController();
    _systolicController = TextEditingController();
    _diastolicController = TextEditingController();
    _heartRateController = TextEditingController();
    _respiratoryRateController = TextEditingController();
    _oxygenSaturationController = TextEditingController();
    _weightController = TextEditingController();
    _heightController = TextEditingController();
    final DateTime initialRecordedAt =
        widget.initialValues?.recordedAt ?? DateTime.now();
    _recordedDate = DateTime(
      initialRecordedAt.year,
      initialRecordedAt.month,
      initialRecordedAt.day,
    );
    _recordedTime = AppTimeValue.fromTimeOfDay(
      TimeOfDay.fromDateTime(initialRecordedAt),
    );
    _populateInitialValues(widget.initialValues);
  }

  @override
  void dispose() {
    _temperatureController.dispose();
    _systolicController.dispose();
    _diastolicController.dispose();
    _heartRateController.dispose();
    _respiratoryRateController.dispose();
    _oxygenSaturationController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  bool get _enabled => !_isSaving && !widget.isBusy;

  Widget? _buildFormStatus(BuildContext context) {
    return appFormCombinedStatus(<Widget?>[
      ...?widget.formStatusSectionsBuilder?.call(context),
      if (_formErrorText != null)
        AppFormInformationBanner.message(
          message: _formErrorText!,
          variant: AppFormInformationVariant.error,
        ),
      appFormFailureStatus(context, _failure),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = _enabled;
    return AppDialog(
      title: Text(widget.title),
      icon: widget.icon,
      scrollable: true,
      pinActionsToBottom: true,
      closeEnabled: enabled,
      maxWidth: widget.maxWidth,
      content: AppFormShell(
        formKey: _formKey,
        enabled: enabled,
        density: AppFormSectionDensity.compact,
        formStatus: _buildFormStatus(context),
        children: <Widget>[
          ...?widget.leadingSectionsBuilder?.call(context, enabled),
          AppFormSection(
            title: widget.vitalsSectionTitle,
            density: AppFormSectionDensity.compact,
            children: <Widget>[
              if (widget.vitalsHelperText != null)
                Text(
                  widget.vitalsHelperText!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              AppVitalsForm(
                temperatureController: _temperatureController,
                systolicController: _systolicController,
                diastolicController: _diastolicController,
                heartRateController: _heartRateController,
                respiratoryRateController: _respiratoryRateController,
                oxygenSaturationController: _oxygenSaturationController,
                weightController: _weightController,
                heightController: _heightController,
                temperatureLabel: widget.temperatureLabel,
                systolicLabel: widget.systolicLabel,
                diastolicLabel: widget.diastolicLabel,
                heartRateLabel: widget.heartRateLabel,
                respiratoryRateLabel: widget.respiratoryRateLabel,
                oxygenSaturationLabel: widget.oxygenSaturationLabel,
                weightLabel: widget.weightLabel,
                heightLabel: widget.heightLabel,
                bloodPressureLabel: widget.bloodPressureLabel,
                unitLabel: widget.unitLabel,
                bloodPressureUnit: _bloodPressureUnit,
                temperatureUnit: _temperatureUnit,
                weightUnit: _weightUnit,
                heightUnit: _heightUnit,
                onBloodPressureUnitChanged: (String? value) {
                  if (value != null) {
                    setState(() => _bloodPressureUnit = value);
                  }
                },
                onTemperatureUnitChanged: (String? value) {
                  if (value != null) {
                    setState(() => _temperatureUnit = value);
                  }
                },
                onWeightUnitChanged: (String? value) {
                  if (value != null) {
                    setState(() => _weightUnit = value);
                  }
                },
                onHeightUnitChanged: (String? value) {
                  if (value != null) {
                    setState(() => _heightUnit = value);
                  }
                },
                enabled: enabled,
              ),
              if (widget.showRecordedAt) _recordedAtFields(context, enabled),
            ],
          ),
          ...?widget.trailingSectionsBuilder?.call(context, enabled),
        ],
      ),
      actions: clinicalActionDialogActions(
        context,
        widget.submitLabel,
        _isSaving,
        enabled ? _submit : null,
        cancelLabel: widget.cancelLabel,
        submitLeadingIcon: _isEditing ? AppActionIcons.edit : AppActionIcons.save,
        enabled: !widget.isBusy,
      ),
    );
  }

  Widget _recordedAtFields(BuildContext context, bool enabled) {
    final ThemeData theme = Theme.of(context);
    final String timeHint =
        widget.timeFormatHint ?? context.l10n.appTimeFormatHint;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxWidth < 560;
        final List<Widget> fields = <Widget>[
          AppDateField(
            value: _recordedDate,
            labelText: widget.recordedDateLabel,
            pickerButtonLabel: widget.datePickerLabel,
            invalidDateMessage: widget.invalidDateMessage,
            firstDate: DateTime(1900),
            lastDate: DateTime.now().add(const Duration(days: 1)),
            currentDate: DateTime.now(),
            enabled: enabled,
            isRequired: true,
            validator: (DateTime? value) =>
                value == null ? widget.requiredMessage : null,
            onChanged: (DateTime? value) {
              if (value != null) {
                setState(() => _recordedDate = value);
              }
            },
          ),
          AppTimeField(
            value: _recordedTime,
            labelText: widget.recordedTimeLabel,
            hintText: timeHint,
            pickerButtonLabel: widget.timePickerLabel,
            invalidTimeMessage: widget.invalidTimeMessage,
            enabled: enabled,
            isRequired: true,
            validator: (AppTimeValue? value) =>
                value == null ? widget.requiredMessage : null,
            onChanged: (AppTimeValue? value) {
              if (value != null) {
                setState(() => _recordedTime = value);
              }
            },
          ),
        ];
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(height: theme.spacing.md),
              fields[0],
              SizedBox(height: theme.spacing.md),
              fields[1],
            ],
          );
        }
        return Padding(
          padding: EdgeInsets.only(top: theme.spacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: fields[0]),
              SizedBox(width: theme.spacing.md),
              Expanded(child: fields[1]),
            ],
          ),
        );
      },
    );
  }

  bool get _isEditing {
    final String? id = widget.initialValues?.id?.trim();
    return id != null && id.isNotEmpty;
  }

  void _populateInitialValues(AppRecordVitalsInitialValues? initialValues) {
    if (initialValues == null) {
      return;
    }

    if (initialValues.bloodPressureUnit != null &&
        initialValues.bloodPressureUnit!.trim().isNotEmpty) {
      _bloodPressureUnit = initialValues.bloodPressureUnit!.trim();
    }
    if (initialValues.temperatureUnit != null &&
        initialValues.temperatureUnit!.trim().isNotEmpty) {
      _temperatureUnit = initialValues.temperatureUnit!.trim();
    }
    if (initialValues.weightUnit != null &&
        initialValues.weightUnit!.trim().isNotEmpty) {
      _weightUnit = initialValues.weightUnit!.trim();
    }
    if (initialValues.heightUnit != null &&
        initialValues.heightUnit!.trim().isNotEmpty) {
      _heightUnit = initialValues.heightUnit!.trim();
    }

    if (initialValues.hasMultiFieldSeed) {
      _temperatureController.text = initialValues.temperature ?? '';
      _systolicController.text = initialValues.systolic ?? '';
      _diastolicController.text = initialValues.diastolic ?? '';
      _heartRateController.text = initialValues.heartRate ?? '';
      _respiratoryRateController.text = initialValues.respiratoryRate ?? '';
      _oxygenSaturationController.text = initialValues.oxygenSaturation ?? '';
      _weightController.text = initialValues.weight ?? '';
      _heightController.text = initialValues.height ?? '';
      return;
    }

    final String value = initialValues.value ?? '';
    final String unit = initialValues.unit ?? '';
    switch ((initialValues.vitalType ?? '').trim().toUpperCase()) {
      case 'BLOOD_PRESSURE':
        _systolicController.text = _numLabel(initialValues.systolicValue);
        _diastolicController.text = _numLabel(initialValues.diastolicValue);
        if (unit.isNotEmpty) {
          _bloodPressureUnit = unit;
        }
        break;
      case 'TEMPERATURE':
        _temperatureController.text = value;
        if (unit.isNotEmpty) {
          _temperatureUnit = unit;
        }
        break;
      case 'HEART_RATE':
        _heartRateController.text = value;
        break;
      case 'RESPIRATORY_RATE':
        _respiratoryRateController.text = value;
        break;
      case 'OXYGEN_SATURATION':
        _oxygenSaturationController.text = value;
        break;
      case 'WEIGHT':
        _weightController.text = value;
        if (unit.isNotEmpty) {
          _weightUnit = unit;
        }
        break;
      case 'HEIGHT':
        _heightController.text = value;
        if (unit.isNotEmpty) {
          _heightUnit = unit;
        }
        break;
    }
  }

  Future<void> _submit() async {
    if (_isSaving || widget.isBusy) {
      return;
    }
    if (!validateAndSaveAppForm(_formKey)) {
      setState(() {
        _failure = AppFailure.validation();
        _formErrorText = widget.requiredMessage;
      });
      return;
    }
    final List<Map<String, Object?>> payloads = buildAppVitalPayloads(
      temperature: _temperatureController.text,
      systolic: _systolicController.text,
      diastolic: _diastolicController.text,
      heartRate: _heartRateController.text,
      respiratoryRate: _respiratoryRateController.text,
      oxygenSaturation: _oxygenSaturationController.text,
      weight: _weightController.text,
      height: _heightController.text,
      bloodPressureUnit: _bloodPressureUnit,
      temperatureUnit: _temperatureUnit,
      weightUnit: _weightUnit,
      heightUnit: _heightUnit,
      recordedAt: widget.showRecordedAt ? _recordedAt() : DateTime.now(),
      vitalId: widget.initialValues?.id,
      editingVitalType: _editingVitalType,
      normalizeBloodPressureToMmHg: widget.normalizeBloodPressureToMmHg,
    );
    if (payloads.isEmpty) {
      if (!widget.requireAtLeastOneVital) {
        return;
      }
      setState(() {
        _failure = AppFailure.validation(
          validationFields: const <String>{'vitals'},
        );
        _formErrorText =
            widget.atLeastOneVitalMessage ?? widget.requiredMessage;
      });
      return;
    }
    if (!_hasCompleteBloodPressureInput()) {
      setState(() {
        _failure = AppFailure.validation(
          validationFields: const <String>{'blood_pressure'},
        );
        _formErrorText = widget.requiredMessage;
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _failure = null;
      _formErrorText = null;
    });
    final AppFailure? failure = await widget.onSubmit(payloads);
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

  DateTime _recordedAt() {
    return DateTime(
      _recordedDate.year,
      _recordedDate.month,
      _recordedDate.day,
      _recordedTime.hour,
      _recordedTime.minute,
    );
  }

  String? get _editingVitalType {
    final String? id = widget.initialValues?.id?.trim();
    if (id == null || id.isEmpty) {
      return null;
    }
    final String? type = widget.initialValues?.vitalType?.trim().toUpperCase();
    return type == null || type.isEmpty ? null : type;
  }

  bool _hasCompleteBloodPressureInput() {
    final bool hasSystolic =
        normalizeAppVitalInput(_systolicController.text).isNotEmpty;
    final bool hasDiastolic =
        normalizeAppVitalInput(_diastolicController.text).isNotEmpty;
    return hasSystolic == hasDiastolic;
  }

  String _numLabel(num? value) {
    if (value == null) {
      return '';
    }
    return formatAppVitalNumber(value);
  }
}

/// Builds snake_case vitals payloads for record/update mutations.
List<Map<String, Object?>> buildAppVitalPayloads({
  required String temperature,
  required String systolic,
  required String diastolic,
  required String heartRate,
  required String respiratoryRate,
  required String oxygenSaturation,
  required String weight,
  required String height,
  required String bloodPressureUnit,
  required String temperatureUnit,
  required String weightUnit,
  required String heightUnit,
  required DateTime recordedAt,
  String? vitalId,
  String? editingVitalType,
  bool normalizeBloodPressureToMmHg = false,
}) {
  final String recordedAtValue = recordedAt.toUtc().toIso8601String();
  final List<Map<String, Object?>> payloads = <Map<String, Object?>>[];
  final String? editingType = editingVitalType?.trim().toUpperCase();
  final String? trimmedVitalId = vitalId?.trim();
  final Map<String, Object?> idEntry =
      trimmedVitalId == null || trimmedVitalId.isEmpty
      ? const <String, Object?>{}
      : <String, Object?>{'vital_id': trimmedVitalId};

  final String normalizedSystolic = normalizeAppVitalInput(systolic);
  final String normalizedDiastolic = normalizeAppVitalInput(diastolic);
  if ((editingType == null || editingType == 'BLOOD_PRESSURE') &&
      (normalizedSystolic.isNotEmpty || normalizedDiastolic.isNotEmpty)) {
    if (normalizedSystolic.isEmpty || normalizedDiastolic.isEmpty) {
      return const <Map<String, Object?>>[];
    }
    if (normalizeBloodPressureToMmHg) {
      final String systolicMmHg = _bloodPressureMmHgValue(
        normalizedSystolic,
        bloodPressureUnit,
      );
      final String diastolicMmHg = _bloodPressureMmHgValue(
        normalizedDiastolic,
        bloodPressureUnit,
      );
      if (systolicMmHg.isEmpty || diastolicMmHg.isEmpty) {
        return const <Map<String, Object?>>[];
      }
      payloads.add(<String, Object?>{
        ...idEntry,
        'vital_type': 'BLOOD_PRESSURE',
        'value': '$systolicMmHg/$diastolicMmHg',
        'unit': AppVitalsUnits.bloodPressureMmHg,
        'systolic_value': systolicMmHg,
        'diastolic_value': diastolicMmHg,
        'recorded_at': recordedAtValue,
      });
    } else {
      payloads.add(<String, Object?>{
        ...idEntry,
        'vital_type': 'BLOOD_PRESSURE',
        'systolic_value': num.tryParse(normalizedSystolic),
        'diastolic_value': num.tryParse(normalizedDiastolic),
        'unit': bloodPressureUnit,
        'recorded_at': recordedAtValue,
      });
    }
  }

  void addValue(String type, String rawValue, String unit) {
    if (editingType != null && editingType != type) {
      return;
    }
    final String value = normalizeAppVitalInput(rawValue);
    if (value.isEmpty) {
      return;
    }
    payloads.add(<String, Object?>{
      ...idEntry,
      'vital_type': type,
      'value': value,
      'unit': unit,
      'recorded_at': recordedAtValue,
    });
  }

  addValue('TEMPERATURE', temperature, temperatureUnit);
  addValue('HEART_RATE', heartRate, AppVitalsUnits.heartRate);
  addValue('RESPIRATORY_RATE', respiratoryRate, AppVitalsUnits.respiratoryRate);
  addValue(
    'OXYGEN_SATURATION',
    oxygenSaturation,
    AppVitalsUnits.oxygenSaturation,
  );
  addValue('WEIGHT', weight, weightUnit);
  addValue('HEIGHT', height, heightUnit);
  return payloads;
}

String normalizeAppVitalInput(String value) {
  return value.trim().replaceAll(',', '');
}

String _bloodPressureMmHgValue(String rawValue, String unit) {
  final double? value = double.tryParse(rawValue);
  if (value == null) {
    return '';
  }
  final double mmHg = unit == AppVitalsUnits.bloodPressureKpa
      ? value / AppVitalsUnits.bloodPressureKpaFactor
      : value;
  return formatAppVitalNumber(mmHg, decimals: 2);
}
