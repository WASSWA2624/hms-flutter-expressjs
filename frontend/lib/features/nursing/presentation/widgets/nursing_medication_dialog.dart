import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/features/nursing/domain/entities/nursing_entities.dart';
import 'package:hosspi_hms/features/nursing/presentation/controllers/nursing_workspace_controller.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';

class NursingMedicationDialog extends ConsumerStatefulWidget {
  const NursingMedicationDialog({required this.detail, super.key});

  final NursingPatientDetail detail;

  @override
  ConsumerState<NursingMedicationDialog> createState() =>
      _NursingMedicationDialogState();
}

class _NursingMedicationDialogState
    extends ConsumerState<NursingMedicationDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _doseController;
  late final TextEditingController _unitController;
  late DateTime _administeredDate;
  late AppTimeValue _administeredTime;
  String? _prescriptionId;
  String _route = 'ORAL';
  bool _confirm = false;
  bool _isSaving = false;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    final MedicationSuggestion? firstSuggestion =
        widget.detail.medicationSuggestions.isEmpty
        ? null
        : widget.detail.medicationSuggestions.first;
    final DateTime now = DateTime.now();
    _prescriptionId = firstSuggestion?.id;
    _doseController = TextEditingController(text: firstSuggestion?.dose ?? '');
    _unitController = TextEditingController(text: firstSuggestion?.unit ?? '');
    _administeredDate = DateTime(now.year, now.month, now.day);
    _administeredTime = AppTimeValue.fromTimeOfDay(TimeOfDay.fromDateTime(now));
    _route = nursingSupportedMedicationRoute(firstSuggestion?.route) ?? _route;
  }

  @override
  void dispose() {
    _doseController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.nursingActionAdministerMedication),
      icon: const Icon(Icons.medication_outlined),
      scrollable: true,
      content: Form(
        key: _formKey,
        child: AppFormSection(
          children: <Widget>[
            if (_failure != null)
              AppFormInformationBanner.failure(
                context: context,
                failure: _failure!,
              ),
            AppMedicationAdministrationForm(
              medicationLabel: l10n.nursingMedicationLabel,
              doseLabel: l10n.nursingDoseLabel,
              unitLabel: l10n.nursingVitalUnitLabel,
              routeLabel: l10n.nursingRouteLabel,
              administeredDateLabel: l10n.nursingAdministeredAtLabel,
              administeredTimeLabel: l10n.opdTimeColumnLabel,
              datePickerLabel: l10n.nursingDatePickerLabel,
              invalidDateMessage: l10n.nursingInvalidDateMessage,
              timePickerLabel: l10n.appTimePickerAction,
              invalidTimeMessage: l10n.appTimeInvalidMessage,
              confirmLabel: l10n.nursingConfirmMedicationLabel,
              confirmSubtitle: l10n.nursingConfirmMedicationSubtitle,
              requiredMessage: l10n.validationRequired,
              doseController: _doseController,
              unitController: _unitController,
              administeredDate: _administeredDate,
              administeredTime: _administeredTime,
              routeValue: _route,
              routeOptions: nursingStatusOptions(nursingMedicationRoutes),
              confirmed: _confirm,
              medicationValue: _prescriptionId,
              medicationOptions: <AppSelectOption<String>>[
                for (final MedicationSuggestion suggestion
                    in widget.detail.medicationSuggestions)
                  AppSelectOption<String>(
                    value: suggestion.id,
                    label: nursingJoinDisplay(<String?>[
                      suggestion.displayTitle,
                      suggestion.dose,
                      suggestion.unit,
                      suggestion.route == null
                          ? null
                          : nursingApiLabel(suggestion.route!),
                    ]),
                  ),
              ],
              selectedMedicationDescription: _selectedMedicationDescription(
                context,
              ),
              noMedicationMessage: l10n.nursingNoRecordsLabel,
              enabled: !_isSaving,
              onMedicationChanged: _selectMedication,
              onAdministeredDateChanged: (DateTime? value) {
                if (value != null) {
                  setState(() => _administeredDate = value);
                }
              },
              onAdministeredTimeChanged: (AppTimeValue? value) {
                if (value != null) {
                  setState(() => _administeredTime = value);
                }
              },
              onRouteChanged: (String? value) {
                if (value != null) {
                  setState(() => _route = value);
                }
              },
              onConfirmedChanged: (bool value) {
                setState(() => _confirm = value);
              },
            ),
          ],
        ),
      ),
      actions: nursingDialogActions(
        context,
        submitLabel: l10n.nursingActionAdministerMedication,
        isSaving: _isSaving,
        onSubmit: _submit,
      ),
    );
  }

  MedicationSuggestion? get _selectedSuggestion {
    if (_prescriptionId == null) {
      return null;
    }
    for (final MedicationSuggestion suggestion
        in widget.detail.medicationSuggestions) {
      if (suggestion.id == _prescriptionId) {
        return suggestion;
      }
    }
    return null;
  }

  String? _selectedMedicationDescription(BuildContext context) {
    final MedicationSuggestion? suggestion = _selectedSuggestion;
    if (suggestion == null) {
      return null;
    }
    return nursingJoinDisplay(<String?>[
      suggestion.frequency,
      suggestion.orderStatus == null
          ? null
          : nursingApiLabel(suggestion.orderStatus!),
      suggestion.itemStatus == null
          ? null
          : nursingApiLabel(suggestion.itemStatus!),
      suggestion.route == null ? null : nursingApiLabel(suggestion.route!),
    ]);
  }

  void _selectMedication(String? value) {
    MedicationSuggestion? suggestion;
    for (final MedicationSuggestion item
        in widget.detail.medicationSuggestions) {
      if (item.id == value) {
        suggestion = item;
        break;
      }
    }
    setState(() {
      _prescriptionId = value;
      if (suggestion != null) {
        _doseController.text = suggestion.dose ?? _doseController.text;
        _unitController.text = suggestion.unit ?? _unitController.text;
        _route = nursingSupportedMedicationRoute(suggestion.route) ?? _route;
      }
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if ((_prescriptionId ?? '').trim().isEmpty) {
      setState(() => _failure = AppFailure.validation());
      return;
    }

    final DateTime administeredAt = DateTime(
      _administeredDate.year,
      _administeredDate.month,
      _administeredDate.day,
      _administeredTime.hour,
      _administeredTime.minute,
    );

    setState(() {
      _isSaving = true;
      _failure = null;
    });
    final AppFailure? failure = await ref
        .read(nursingWorkspaceControllerProvider.notifier)
        .addMedicationAdministration(<String, Object?>{
          'prescription_id': _prescriptionId?.trim(),
          'administered_at': administeredAt.toUtc().toIso8601String(),
          'dose': _doseController.text.trim(),
          'unit': _unitController.text.trim(),
          'route': _route,
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
}
