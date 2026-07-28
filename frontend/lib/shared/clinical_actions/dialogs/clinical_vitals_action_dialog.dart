import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

/// Clinical encounter vitals dialog composed on [AppRecordVitalsDialog].
///
/// Records or updates OPD-backed vitals without triage/routing chrome.
class ClinicalVitalsActionDialog extends StatelessWidget {
  const ClinicalVitalsActionDialog({
    required this.onSubmit,
    this.detail,
    this.editing = false,
    super.key,
  });

  final OpdFlowDetail? detail;
  final bool editing;
  final Future<AppFailure?> Function(List<Map<String, Object?>> vitals)
  onSubmit;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool isEdit = editing;
    final OpdFlowSummary? summary = detail?.summary;

    return AppRecordVitalsDialog(
      title: isEdit ? l10n.opdEditVitalsAction : l10n.opdRecordVitalsAction,
      submitLabel: isEdit
          ? l10n.opdEditVitalsAction
          : l10n.opdRecordVitalsAction,
      cancelLabel: l10n.commonCancelActionLabel,
      temperatureLabel: l10n.patientsTemperatureLabel,
      systolicLabel: l10n.nursingSystolicLabel,
      diastolicLabel: l10n.nursingDiastolicLabel,
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
      maxWidth: 780,
      reference: AppVitalsReference.fromPatientData(
        dateOfBirth: summary?.patientDateOfBirth,
        gender: summary?.patientGender,
      ),
      initialValues: isEdit ? _initialValuesFromDetail(detail) : null,
      onSubmit: onSubmit,
    );
  }
}

AppRecordVitalsInitialValues? _initialValuesFromDetail(OpdFlowDetail? detail) {
  if (detail == null || detail.vitalMeasurements.isEmpty) {
    return null;
  }

  return AppRecordVitalsInitialValues(
    temperature: _initialVitalValue(detail, 'TEMPERATURE'),
    systolic: _initialSystolicValue(detail),
    diastolic: _initialDiastolicValue(detail),
    heartRate: _initialVitalValue(detail, 'HEART_RATE'),
    respiratoryRate: _initialVitalValue(detail, 'RESPIRATORY_RATE'),
    oxygenSaturation: _initialVitalValue(detail, 'OXYGEN_SATURATION'),
    weight: _initialVitalValue(detail, 'WEIGHT'),
    height: _initialVitalValue(detail, 'HEIGHT'),
    bloodPressureUnit: _initialVitalUnit(
      detail,
      'BLOOD_PRESSURE',
      AppVitalsUnits.bloodPressureMmHg,
    ),
    temperatureUnit: _initialVitalUnit(
      detail,
      'TEMPERATURE',
      AppVitalsUnits.temperatureCelsius,
    ),
    weightUnit: _initialVitalUnit(
      detail,
      'WEIGHT',
      AppVitalsUnits.weightKilograms,
    ),
    heightUnit: _initialVitalUnit(
      detail,
      'HEIGHT',
      AppVitalsUnits.heightCentimeters,
    ),
  );
}

String _initialVitalValue(OpdFlowDetail detail, String type) {
  final OpdVitalSign? vital = _latestVital(detail, type);
  return _formatOpdVitalInput(vital?.value);
}

String _initialSystolicValue(OpdFlowDetail detail) {
  final OpdVitalSign? vital = _latestVital(detail, 'BLOOD_PRESSURE');
  final String value = _formatOpdVitalNumber(vital?.systolicValue);
  return value.isEmpty ? _legacyBloodPressurePart(vital?.value, 0) : value;
}

String _initialDiastolicValue(OpdFlowDetail detail) {
  final OpdVitalSign? vital = _latestVital(detail, 'BLOOD_PRESSURE');
  final String value = _formatOpdVitalNumber(vital?.diastolicValue);
  return value.isEmpty ? _legacyBloodPressurePart(vital?.value, 1) : value;
}

String _initialVitalUnit(
  OpdFlowDetail detail,
  String type,
  String fallback,
) {
  final String normalized = _latestVital(detail, type)?.unit?.trim() ?? '';
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

OpdVitalSign? _latestVital(OpdFlowDetail detail, String type) {
  OpdVitalSign? latest;
  for (final OpdVitalSign vital in detail.vitalMeasurements) {
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
