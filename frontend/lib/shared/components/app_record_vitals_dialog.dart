import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_action_dialog_actions.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/components/app_date_field.dart';
import 'package:hosspi_hms/shared/components/app_dialog.dart';
import 'package:hosspi_hms/shared/components/app_form_information_banner.dart';
import 'package:hosspi_hms/shared/components/app_text_field.dart';
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
/// vitals form shell. Vital signs open in focused sub-dialogs to reduce
/// congestion.
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
    this.reference = const AppVitalsReference.adult(),
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
  final AppVitalsReference reference;
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
    final ThemeData theme = Theme.of(context);
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
                  style: theme.textTheme.bodySmall,
                ),
              Wrap(
                spacing: theme.spacing.sm,
                runSpacing: theme.spacing.sm,
                children: <Widget>[
                  for (final _VitalActionKind action in _visibleVitalActions)
                    _buildVitalActionButton(context, action, enabled),
                ],
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

  List<_VitalActionKind> get _visibleVitalActions {
    final String? editingType = _editingVitalType;
    if (editingType == null) {
      return const <_VitalActionKind>[
        _VitalActionKind.bloodPressure,
        _VitalActionKind.temperature,
        _VitalActionKind.heartRate,
        _VitalActionKind.respiratoryRate,
        _VitalActionKind.oxygenSaturation,
        _VitalActionKind.bodyMetrics,
      ];
    }
    return switch (editingType) {
      'BLOOD_PRESSURE' => const <_VitalActionKind>[
        _VitalActionKind.bloodPressure,
      ],
      'TEMPERATURE' => const <_VitalActionKind>[_VitalActionKind.temperature],
      'HEART_RATE' => const <_VitalActionKind>[_VitalActionKind.heartRate],
      'RESPIRATORY_RATE' => const <_VitalActionKind>[
        _VitalActionKind.respiratoryRate,
      ],
      'OXYGEN_SATURATION' => const <_VitalActionKind>[
        _VitalActionKind.oxygenSaturation,
      ],
      'WEIGHT' || 'HEIGHT' => const <_VitalActionKind>[
        _VitalActionKind.bodyMetrics,
      ],
      _ => const <_VitalActionKind>[
        _VitalActionKind.bloodPressure,
        _VitalActionKind.temperature,
        _VitalActionKind.heartRate,
        _VitalActionKind.respiratoryRate,
        _VitalActionKind.oxygenSaturation,
        _VitalActionKind.bodyMetrics,
      ],
    };
  }

  Widget _buildVitalActionButton(
    BuildContext context,
    _VitalActionKind action,
    bool enabled,
  ) {
    final AppLocalizations l10n = context.l10n;
    final String name = _vitalActionName(l10n, action);
    final String? summary = _vitalActionSummary(action);
    final String semanticLabel = summary == null || summary.isEmpty
        ? name
        : l10n.patientsVitalActionRecordedLabel(name, summary);
    return AppButton.secondary(
      label: semanticLabel,
      leadingIcon: _vitalActionIcon(action),
      labelWidget: _vitalActionLabelWidget(context, name, action),
      onPressed: enabled ? () => _openVitalEditor(action) : null,
    );
  }

  Widget _vitalActionLabelWidget(
    BuildContext context,
    String name,
    _VitalActionKind action,
  ) {
    final ThemeData theme = Theme.of(context);
    final TextStyle? baseStyle = theme.textTheme.labelLarge?.copyWith(
      fontSize: 14,
    );
    final List<_VitalSummaryPart> parts = _vitalActionSummaryParts(action);
    if (parts.isEmpty) {
      return Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
        style: baseStyle?.copyWith(fontWeight: FontWeight.w700),
      );
    }

    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          TextSpan(
            text: name,
            style: baseStyle?.copyWith(fontWeight: FontWeight.w700),
          ),
          TextSpan(
            text: ' · ',
            style: baseStyle?.copyWith(fontWeight: FontWeight.w500),
          ),
          for (int index = 0; index < parts.length; index++) ...<InlineSpan>[
            if (index > 0)
              TextSpan(
                text: ' · ',
                style: baseStyle?.copyWith(fontWeight: FontWeight.w500),
              ),
            TextSpan(
              text: parts[index].text,
              style: baseStyle?.copyWith(
                fontWeight: FontWeight.w500,
                color:
                    appVitalSignStatusColor(context, parts[index].status) ??
                    baseStyle.color,
              ),
            ),
          ],
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
    );
  }

  IconData _vitalActionIcon(_VitalActionKind action) {
    return switch (action) {
      _VitalActionKind.bloodPressure => Icons.favorite_outline,
      _VitalActionKind.temperature => Icons.thermostat_outlined,
      _VitalActionKind.heartRate => Icons.monitor_heart_outlined,
      _VitalActionKind.respiratoryRate => Icons.air,
      _VitalActionKind.oxygenSaturation => Icons.bloodtype_outlined,
      _VitalActionKind.bodyMetrics => Icons.monitor_weight_outlined,
    };
  }

  String _vitalActionName(AppLocalizations l10n, _VitalActionKind action) {
    return switch (action) {
      _VitalActionKind.bloodPressure => widget.bloodPressureLabel,
      _VitalActionKind.temperature => widget.temperatureLabel,
      _VitalActionKind.heartRate => widget.heartRateLabel,
      _VitalActionKind.respiratoryRate => widget.respiratoryRateLabel,
      _VitalActionKind.oxygenSaturation => widget.oxygenSaturationLabel,
      _VitalActionKind.bodyMetrics => l10n.patientsBodyMetricsLabel,
    };
  }

  String? _vitalActionSummary(_VitalActionKind action) {
    final List<_VitalSummaryPart> parts = _vitalActionSummaryParts(action);
    if (parts.isEmpty) {
      return null;
    }
    return parts.map((_VitalSummaryPart part) => part.text).join(' · ');
  }

  List<_VitalSummaryPart> _vitalActionSummaryParts(_VitalActionKind action) {
    final AppVitalsReference reference = widget.reference;
    return switch (action) {
      _VitalActionKind.bloodPressure => () {
        final String systolic = normalizeAppVitalInput(_systolicController.text);
        final String diastolic = normalizeAppVitalInput(
          _diastolicController.text,
        );
        if (systolic.isEmpty && diastolic.isEmpty) {
          return const <_VitalSummaryPart>[];
        }
        final String text = systolic.isEmpty || diastolic.isEmpty
            ? (systolic.isEmpty ? diastolic : systolic)
            : '$systolic/$diastolic $_bloodPressureUnit';
        final AppVitalSignStatus? status = () {
          if (systolic.isEmpty || diastolic.isEmpty) {
            return null;
          }
          final AppVitalSignStatus? systolicStatus = resolveAppVitalSignStatus(
            systolic,
            reference.systolic.forBloodPressureUnit(_bloodPressureUnit),
          );
          final AppVitalSignStatus? diastolicStatus = resolveAppVitalSignStatus(
            diastolic,
            reference.diastolic.forBloodPressureUnit(_bloodPressureUnit),
          );
          if (systolicStatus == AppVitalSignStatus.abnormal ||
              diastolicStatus == AppVitalSignStatus.abnormal) {
            return AppVitalSignStatus.abnormal;
          }
          if (systolicStatus == AppVitalSignStatus.normal &&
              diastolicStatus == AppVitalSignStatus.normal) {
            return AppVitalSignStatus.normal;
          }
          return null;
        }();
        return <_VitalSummaryPart>[
          _VitalSummaryPart(text: text, status: status),
        ];
      }(),
      _VitalActionKind.temperature => _singleSummaryPart(
        _temperatureController.text,
        _temperatureUnit,
        reference.temperature.forTemperatureUnit(_temperatureUnit),
      ),
      _VitalActionKind.heartRate => _singleSummaryPart(
        _heartRateController.text,
        AppVitalsUnits.heartRate,
        reference.heartRate,
      ),
      _VitalActionKind.respiratoryRate => _singleSummaryPart(
        _respiratoryRateController.text,
        AppVitalsUnits.respiratoryRate,
        reference.respiratoryRate,
      ),
      _VitalActionKind.oxygenSaturation => _singleSummaryPart(
        _oxygenSaturationController.text,
        AppVitalsUnits.oxygenSaturation,
        reference.oxygenSaturation,
      ),
      _VitalActionKind.bodyMetrics => _bodyMetricsSummaryParts(),
    };
  }

  List<_VitalSummaryPart> _singleSummaryPart(
    String raw,
    String unit,
    AppVitalReferenceRange range,
  ) {
    final String value = normalizeAppVitalInput(raw);
    if (value.isEmpty) {
      return const <_VitalSummaryPart>[];
    }
    return <_VitalSummaryPart>[
      _VitalSummaryPart(
        text: '$value $unit',
        status: resolveAppVitalSignStatus(value, range),
      ),
    ];
  }

  List<_VitalSummaryPart> _bodyMetricsSummaryParts() {
    final List<_VitalSummaryPart> parts = <_VitalSummaryPart>[];
    final String weight = normalizeAppVitalInput(_weightController.text);
    final String height = normalizeAppVitalInput(_heightController.text);
    if (weight.isNotEmpty) {
      parts.add(
        _VitalSummaryPart(
          text: '$weight $_weightUnit',
          status: resolveAppVitalSignStatus(
            weight,
            widget.reference.weight.forWeightUnit(_weightUnit),
          ),
        ),
      );
    }
    if (height.isNotEmpty) {
      parts.add(
        _VitalSummaryPart(
          text: '$height $_heightUnit',
          status: resolveAppVitalSignStatus(
            height,
            widget.reference.height.forHeightUnit(_heightUnit),
          ),
        ),
      );
    }
    final double? bmi = calculateAppBodyMassIndex(
      weight: _weightController.text,
      height: _heightController.text,
      weightUnit: _weightUnit,
      heightUnit: _heightUnit,
    );
    if (bmi != null) {
      final String bmiText = formatAppVitalNumber(bmi, decimals: 1);
      parts.add(
        _VitalSummaryPart(
          text: 'BMI $bmiText',
          status: resolveAppVitalSignStatus(
            bmiText,
            kAppBodyMassIndexReference,
          ),
        ),
      );
    }
    return parts;
  }

  Future<void> _openVitalEditor(_VitalActionKind action) async {
    if (action == _VitalActionKind.bodyMetrics) {
      await _openBodyMetricsEditor();
      return;
    }

    final AppVitalKind kind = switch (action) {
      _VitalActionKind.bloodPressure => AppVitalKind.bloodPressure,
      _VitalActionKind.temperature => AppVitalKind.temperature,
      _VitalActionKind.heartRate => AppVitalKind.heartRate,
      _VitalActionKind.respiratoryRate => AppVitalKind.respiratoryRate,
      _VitalActionKind.oxygenSaturation => AppVitalKind.oxygenSaturation,
      _VitalActionKind.bodyMetrics => AppVitalKind.weight,
    };
    final GlobalKey<FormState> editorFormKey = GlobalKey<FormState>();
    final AppLocalizations l10n = context.l10n;
    final String title = _vitalActionName(l10n, action);

    await showAppDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AppDialog(
              title: Text(title),
              icon: Icon(_vitalActionIcon(action)),
              scrollable: true,
              maxWidth: 560,
              content: Form(
                key: editorFormKey,
                child: AppVitalsForm(
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
                  reference: widget.reference,
                  bloodPressureUnit: _bloodPressureUnit,
                  temperatureUnit: _temperatureUnit,
                  weightUnit: _weightUnit,
                  heightUnit: _heightUnit,
                  visibleKinds: <AppVitalKind>{kind},
                  onBloodPressureUnitChanged: (String? value) {
                    if (value != null) {
                      setDialogState(() => _bloodPressureUnit = value);
                    }
                  },
                  onTemperatureUnitChanged: (String? value) {
                    if (value != null) {
                      setDialogState(() => _temperatureUnit = value);
                    }
                  },
                  onWeightUnitChanged: (String? value) {
                    if (value != null) {
                      setDialogState(() => _weightUnit = value);
                    }
                  },
                  onHeightUnitChanged: (String? value) {
                    if (value != null) {
                      setDialogState(() => _heightUnit = value);
                    }
                  },
                ),
              ),
              actions: <Widget>[
                AppButton.tertiary(
                  label: l10n.commonCancelActionLabel,
                  leadingIcon: AppActionIcons.cancel,
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                AppButton.primary(
                  label: l10n.clinicalRequestCatalogPickerDoneAction,
                  leadingIcon: AppActionIcons.save,
                  onPressed: () {
                    if (!(editorFormKey.currentState?.validate() ?? false)) {
                      return;
                    }
                    if (kind == AppVitalKind.bloodPressure &&
                        !_hasCompleteBloodPressureInput()) {
                      return;
                    }
                    Navigator.of(dialogContext).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openBodyMetricsEditor() async {
    await showAppDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return _BodyMetricsEditorDialog(
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
          bodyMetricsLabel: context.l10n.patientsBodyMetricsLabel,
          bmiLabel: context.l10n.patientsBmiLabel,
          cancelLabel: context.l10n.commonCancelActionLabel,
          doneLabel: context.l10n.clinicalRequestCatalogPickerDoneAction,
          reference: widget.reference,
          bloodPressureUnit: _bloodPressureUnit,
          temperatureUnit: _temperatureUnit,
          weightUnit: _weightUnit,
          heightUnit: _heightUnit,
          onWeightUnitChanged: (String value) {
            _weightUnit = value;
          },
          onHeightUnitChanged: (String value) {
            _heightUnit = value;
          },
        );
      },
    );
    if (mounted) {
      setState(() {});
    }
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

enum _VitalActionKind {
  bloodPressure,
  temperature,
  heartRate,
  respiratoryRate,
  oxygenSaturation,
  bodyMetrics,
}

@immutable
final class _VitalSummaryPart {
  const _VitalSummaryPart({required this.text, this.status});

  final String text;
  final AppVitalSignStatus? status;
}

class _BodyMetricsEditorDialog extends StatefulWidget {
  const _BodyMetricsEditorDialog({
    required this.temperatureController,
    required this.systolicController,
    required this.diastolicController,
    required this.heartRateController,
    required this.respiratoryRateController,
    required this.oxygenSaturationController,
    required this.weightController,
    required this.heightController,
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
    required this.bodyMetricsLabel,
    required this.bmiLabel,
    required this.cancelLabel,
    required this.doneLabel,
    required this.reference,
    required this.bloodPressureUnit,
    required this.temperatureUnit,
    required this.weightUnit,
    required this.heightUnit,
    required this.onWeightUnitChanged,
    required this.onHeightUnitChanged,
  });

  final TextEditingController temperatureController;
  final TextEditingController systolicController;
  final TextEditingController diastolicController;
  final TextEditingController heartRateController;
  final TextEditingController respiratoryRateController;
  final TextEditingController oxygenSaturationController;
  final TextEditingController weightController;
  final TextEditingController heightController;
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
  final String bodyMetricsLabel;
  final String bmiLabel;
  final String cancelLabel;
  final String doneLabel;
  final AppVitalsReference reference;
  final String bloodPressureUnit;
  final String temperatureUnit;
  final String weightUnit;
  final String heightUnit;
  final ValueChanged<String> onWeightUnitChanged;
  final ValueChanged<String> onHeightUnitChanged;

  @override
  State<_BodyMetricsEditorDialog> createState() =>
      _BodyMetricsEditorDialogState();
}

class _BodyMetricsEditorDialogState extends State<_BodyMetricsEditorDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _bmiController;
  late String _weightUnit;
  late String _heightUnit;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _weightUnit = widget.weightUnit;
    _heightUnit = widget.heightUnit;
    final double? bmi = calculateAppBodyMassIndex(
      weight: widget.weightController.text,
      height: widget.heightController.text,
      weightUnit: _weightUnit,
      heightUnit: _heightUnit,
    );
    _bmiController = TextEditingController(
      text: bmi == null ? '' : formatAppVitalNumber(bmi, decimals: 1),
    );
    widget.weightController.addListener(_syncFromWeightOrHeight);
    widget.heightController.addListener(_syncFromWeightOrHeight);
  }

  @override
  void dispose() {
    widget.weightController.removeListener(_syncFromWeightOrHeight);
    widget.heightController.removeListener(_syncFromWeightOrHeight);
    _bmiController.dispose();
    super.dispose();
  }

  void _applyDerivedValue(
    TextEditingController controller,
    double? value, {
    int decimals = 1,
  }) {
    if (value == null || !value.isFinite) {
      return;
    }
    controller.text = formatAppVitalNumber(value, decimals: decimals);
  }

  void _syncFromWeightOrHeight() {
    if (_syncing || !mounted) {
      return;
    }
    final double? bmi = calculateAppBodyMassIndex(
      weight: widget.weightController.text,
      height: widget.heightController.text,
      weightUnit: _weightUnit,
      heightUnit: _heightUnit,
    );
    if (bmi == null) {
      return;
    }
    _syncing = true;
    _applyDerivedValue(_bmiController, bmi);
    _syncing = false;
    setState(() {});
  }

  void _syncFromBmi(String _) {
    if (_syncing) {
      return;
    }
    final String weight = normalizeAppVitalInput(widget.weightController.text);
    final String height = normalizeAppVitalInput(widget.heightController.text);
    final String bmi = normalizeAppVitalInput(_bmiController.text);
    if (bmi.isEmpty) {
      return;
    }
    _syncing = true;
    if (height.isNotEmpty && weight.isEmpty) {
      _applyDerivedValue(
        widget.weightController,
        calculateAppWeightFromBodyMassIndex(
          bmi: _bmiController.text,
          height: widget.heightController.text,
          heightUnit: _heightUnit,
          weightUnit: _weightUnit,
        ),
      );
    } else if (weight.isNotEmpty && height.isEmpty) {
      _applyDerivedValue(
        widget.heightController,
        calculateAppHeightFromBodyMassIndex(
          bmi: _bmiController.text,
          weight: widget.weightController.text,
          weightUnit: _weightUnit,
          heightUnit: _heightUnit,
        ),
        decimals: _heightUnit == AppVitalsUnits.heightMeters ? 2 : 0,
      );
    } else if (weight.isNotEmpty && height.isNotEmpty) {
      _applyDerivedValue(
        widget.weightController,
        calculateAppWeightFromBodyMassIndex(
          bmi: _bmiController.text,
          height: widget.heightController.text,
          heightUnit: _heightUnit,
          weightUnit: _weightUnit,
        ),
      );
    }
    _syncing = false;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AppDialog(
      title: Text(widget.bodyMetricsLabel),
      icon: const Icon(Icons.monitor_weight_outlined),
      scrollable: true,
      maxWidth: 560,
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AppVitalsForm(
              temperatureController: widget.temperatureController,
              systolicController: widget.systolicController,
              diastolicController: widget.diastolicController,
              heartRateController: widget.heartRateController,
              respiratoryRateController: widget.respiratoryRateController,
              oxygenSaturationController: widget.oxygenSaturationController,
              weightController: widget.weightController,
              heightController: widget.heightController,
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
              reference: widget.reference,
              bloodPressureUnit: widget.bloodPressureUnit,
              temperatureUnit: widget.temperatureUnit,
              weightUnit: _weightUnit,
              heightUnit: _heightUnit,
              visibleKinds: const <AppVitalKind>{
                AppVitalKind.weight,
                AppVitalKind.height,
              },
              onWeightUnitChanged: (String? value) {
                if (value == null) {
                  return;
                }
                setState(() => _weightUnit = value);
                widget.onWeightUnitChanged(value);
                _syncFromWeightOrHeight();
              },
              onHeightUnitChanged: (String? value) {
                if (value == null) {
                  return;
                }
                setState(() => _heightUnit = value);
                widget.onHeightUnitChanged(value);
                _syncFromWeightOrHeight();
              },
            ),
            SizedBox(height: theme.spacing.md),
            AppTextField(
              controller: _bmiController,
              labelText: widget.bmiLabel,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: _syncFromBmi,
            ),
          ],
        ),
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: widget.cancelLabel,
          leadingIcon: AppActionIcons.cancel,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppButton.primary(
          label: widget.doneLabel,
          leadingIcon: AppActionIcons.save,
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) {
              return;
            }
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
