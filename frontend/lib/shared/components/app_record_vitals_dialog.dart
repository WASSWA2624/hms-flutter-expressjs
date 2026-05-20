import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/components/app_date_field.dart';
import 'package:hosspi_hms/shared/components/app_dialog.dart';
import 'package:hosspi_hms/shared/components/app_state_view.dart';
import 'package:hosspi_hms/shared/components/app_time_field.dart';
import 'package:hosspi_hms/shared/components/app_vitals_form.dart';
import 'package:hosspi_hms/shared/forms/app_form_section.dart';

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
  });

  final String? id;
  final String? vitalType;
  final String? value;
  final String? unit;
  final num? systolicValue;
  final num? diastolicValue;
  final DateTime? recordedAt;
}

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
    super.key,
  });

  final String title;
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
  late TimeOfDay _recordedTime;
  String _bloodPressureUnit = AppVitalsUnits.bloodPressureMmHg;
  String _temperatureUnit = AppVitalsUnits.temperatureCelsius;
  String _weightUnit = AppVitalsUnits.weightKilograms;
  String _heightUnit = AppVitalsUnits.heightCentimeters;
  bool _isSaving = false;
  AppFailure? _failure;

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
    _recordedTime = TimeOfDay.fromDateTime(initialRecordedAt);
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

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AppDialog(
      title: Text(widget.title),
      icon: const Icon(Icons.monitor_heart_outlined),
      scrollable: true,
      maxWidth: 760,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null) AppFailureStateView(failure: _failure!),
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
              enabled: !_isSaving,
            ),
            LayoutBuilder(
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
                    enabled: !_isSaving,
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
                    hintText: 'HH:MM',
                    pickerButtonLabel: widget.timePickerLabel,
                    invalidTimeMessage: widget.invalidTimeMessage,
                    enabled: !_isSaving,
                    isRequired: true,
                    validator: (TimeOfDay? value) =>
                        value == null ? widget.requiredMessage : null,
                    onChanged: (TimeOfDay? value) {
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
                      fields[0],
                      SizedBox(height: theme.spacing.md),
                      fields[1],
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(child: fields[0]),
                    SizedBox(width: theme.spacing.md),
                    Expanded(child: fields[1]),
                  ],
                );
              },
            ),
          ],
        ),
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: widget.cancelLabel,
          enabled: !_isSaving,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton.primary(
          label: widget.submitLabel,
          isLoading: _isSaving,
          onPressed: _submit,
        ),
      ],
    );
  }

  void _populateInitialValues(AppRecordVitalsInitialValues? initialValues) {
    if (initialValues == null) {
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
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final List<Map<String, Object?>> payloads = _vitalPayloads(_recordedAt());
    if (payloads.isEmpty) {
      setState(() => _failure = AppFailure.validation());
      return;
    }

    setState(() {
      _isSaving = true;
      _failure = null;
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

  List<Map<String, Object?>> _vitalPayloads(DateTime recordedAt) {
    final String recordedAtValue = recordedAt.toUtc().toIso8601String();
    final List<Map<String, Object?>> payloads = <Map<String, Object?>>[];
    final String? editingType = _editingVitalType;

    final String systolic = _normalizedNumber(_systolicController.text);
    final String diastolic = _normalizedNumber(_diastolicController.text);
    if ((editingType == null || editingType == 'BLOOD_PRESSURE') &&
        (systolic.isNotEmpty || diastolic.isNotEmpty)) {
      if (systolic.isEmpty || diastolic.isEmpty) {
        return const <Map<String, Object?>>[];
      }
      payloads.add(<String, Object?>{
        ..._vitalIdEntry(),
        'vital_type': 'BLOOD_PRESSURE',
        'systolic_value': num.tryParse(systolic),
        'diastolic_value': num.tryParse(diastolic),
        'unit': _bloodPressureUnit,
        'recorded_at': recordedAtValue,
      });
    }

    void addValue(String type, TextEditingController controller, String unit) {
      if (editingType != null && editingType != type) {
        return;
      }
      final String value = _normalizedNumber(controller.text);
      if (value.isEmpty) {
        return;
      }
      payloads.add(<String, Object?>{
        ..._vitalIdEntry(),
        'vital_type': type,
        'value': value,
        'unit': unit,
        'recorded_at': recordedAtValue,
      });
    }

    addValue('TEMPERATURE', _temperatureController, _temperatureUnit);
    addValue('HEART_RATE', _heartRateController, AppVitalsUnits.heartRate);
    addValue(
      'RESPIRATORY_RATE',
      _respiratoryRateController,
      AppVitalsUnits.respiratoryRate,
    );
    addValue(
      'OXYGEN_SATURATION',
      _oxygenSaturationController,
      AppVitalsUnits.oxygenSaturation,
    );
    addValue('WEIGHT', _weightController, _weightUnit);
    addValue('HEIGHT', _heightController, _heightUnit);
    return payloads;
  }

  String? get _editingVitalType {
    final String? id = widget.initialValues?.id?.trim();
    if (id == null || id.isEmpty) {
      return null;
    }
    final String? type = widget.initialValues?.vitalType?.trim().toUpperCase();
    return type == null || type.isEmpty ? null : type;
  }

  Map<String, Object?> _vitalIdEntry() {
    final String? id = widget.initialValues?.id?.trim();
    if (id == null || id.isEmpty) {
      return const <String, Object?>{};
    }
    return <String, Object?>{'vital_id': id};
  }

  String _normalizedNumber(String value) {
    return value.trim().replaceAll(',', '');
  }

  String _numLabel(num? value) {
    if (value == null) {
      return '';
    }
    if (value == value.round()) {
      return value.toInt().toString();
    }
    return value.toString();
  }
}
