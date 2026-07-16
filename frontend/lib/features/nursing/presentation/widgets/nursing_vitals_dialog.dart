import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/features/nursing/domain/entities/nursing_entities.dart';
import 'package:hosspi_hms/features/nursing/presentation/controllers/nursing_workspace_controller.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

/// Nursing-scoped vitals recording dialog backed by [AppRecordVitalsDialog].
class NursingVitalsDialog extends StatelessWidget {
  const NursingVitalsDialog({this.vital, super.key});

  final NursingVitalSign? vital;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool isEdit = vital != null;
    return AppRecordVitalsDialog(
      title: isEdit ? l10n.opdEditVitalsAction : l10n.nursingActionRecordVitals,
      submitLabel: isEdit
          ? l10n.opdEditVitalsAction
          : l10n.nursingActionRecordVitals,
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
      unitLabel: l10n.nursingVitalUnitLabel,
      recordedDateLabel: l10n.nursingRecordedAtLabel,
      recordedTimeLabel: l10n.opdTimeColumnLabel,
      datePickerLabel: l10n.nursingDatePickerLabel,
      invalidDateMessage: l10n.nursingInvalidDateMessage,
      timePickerLabel: l10n.appTimePickerAction,
      invalidTimeMessage: l10n.appTimeInvalidMessage,
      timeFormatHint: l10n.appTimeFormatHint,
      requiredMessage: l10n.validationRequired,
      initialValues: vital == null
          ? null
          : AppRecordVitalsInitialValues(
              id: vital!.id,
              vitalType: vital!.vitalType,
              value: vital!.value,
              unit: vital!.unit,
              systolicValue: vital!.systolicValue,
              diastolicValue: vital!.diastolicValue,
              recordedAt: vital!.recordedAt,
            ),
      onSubmit: (List<Map<String, Object?>> payloads) {
        return ProviderScope.containerOf(context, listen: false)
            .read(nursingWorkspaceControllerProvider.notifier)
            .recordVitalSet(payloads);
      },
    );
  }
}
