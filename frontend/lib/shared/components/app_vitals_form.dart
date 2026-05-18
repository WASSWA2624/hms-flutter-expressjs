import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/app_currency_amount_field.dart';
import 'package:hosspi_hms/shared/components/app_select_field.dart';
import 'package:hosspi_hms/shared/components/app_text_field.dart';

class AppVitalsForm extends StatelessWidget {
  const AppVitalsForm({
    required this.temperatureController,
    required this.systolicController,
    required this.diastolicController,
    required this.heartRateController,
    required this.respiratoryRateController,
    required this.oxygenSaturationController,
    required this.temperatureLabel,
    required this.systolicLabel,
    required this.diastolicLabel,
    required this.heartRateLabel,
    required this.respiratoryRateLabel,
    required this.oxygenSaturationLabel,
    this.weightController,
    this.heightController,
    this.weightLabel,
    this.heightLabel,
    this.bloodPressureLabel,
    this.unitLabel,
    this.reference = const AppVitalsReference.adult(),
    this.bloodPressureUnit = AppVitalsUnits.bloodPressureMmHg,
    this.temperatureUnit = AppVitalsUnits.temperatureCelsius,
    this.weightUnit = AppVitalsUnits.weightKilograms,
    this.heightUnit = AppVitalsUnits.heightCentimeters,
    this.onBloodPressureUnitChanged,
    this.onTemperatureUnitChanged,
    this.onWeightUnitChanged,
    this.onHeightUnitChanged,
    this.enabled = true,
    super.key,
  });

  final TextEditingController temperatureController;
  final TextEditingController systolicController;
  final TextEditingController diastolicController;
  final TextEditingController heartRateController;
  final TextEditingController respiratoryRateController;
  final TextEditingController oxygenSaturationController;
  final TextEditingController? weightController;
  final TextEditingController? heightController;
  final String temperatureLabel;
  final String systolicLabel;
  final String diastolicLabel;
  final String heartRateLabel;
  final String respiratoryRateLabel;
  final String oxygenSaturationLabel;
  final String? weightLabel;
  final String? heightLabel;
  final String? bloodPressureLabel;
  final String? unitLabel;
  final AppVitalsReference reference;
  final String bloodPressureUnit;
  final String temperatureUnit;
  final String weightUnit;
  final String heightUnit;
  final ValueChanged<String?>? onBloodPressureUnitChanged;
  final ValueChanged<String?>? onTemperatureUnitChanged;
  final ValueChanged<String?>? onWeightUnitChanged;
  final ValueChanged<String?>? onHeightUnitChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String resolvedUnitLabel = unitLabel ?? l10n.patientsVitalUnitLabel;
    final List<Widget> bodyMeasureFields = <Widget>[
      if (weightController != null && weightLabel != null)
        _vitalSignInput(
          context,
          controller: weightController!,
          labelText: weightLabel!,
          range: reference.weight.forWeightUnit(weightUnit),
          unit: weightUnit,
          unitLabelText: resolvedUnitLabel,
          unitOptions: onWeightUnitChanged == null
              ? null
              : AppVitalsUnits.weightOptions,
          onUnitChanged: onWeightUnitChanged,
          unitWidth: 112,
        ),
      if (heightController != null && heightLabel != null)
        _vitalSignInput(
          context,
          controller: heightController!,
          labelText: heightLabel!,
          range: reference.height.forHeightUnit(heightUnit),
          unit: heightUnit,
          unitLabelText: resolvedUnitLabel,
          unitOptions: onHeightUnitChanged == null
              ? null
              : AppVitalsUnits.heightOptions,
          onUnitChanged: onHeightUnitChanged,
          unitWidth: 112,
        ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _BloodPressureInput(
          title: bloodPressureLabel ?? l10n.patientsBloodPressureLabel,
          systolicController: systolicController,
          diastolicController: diastolicController,
          systolicLabelText: systolicLabel,
          diastolicLabelText: diastolicLabel,
          unit: bloodPressureUnit,
          unitLabelText: resolvedUnitLabel,
          unitOptions: onBloodPressureUnitChanged == null
              ? const <AppSelectOption<String>>[]
              : AppVitalsUnits.bloodPressureOptions,
          profileLabel: reference.profileLabel,
          systolicRange: reference.systolic.forBloodPressureUnit(
            bloodPressureUnit,
          ),
          diastolicRange: reference.diastolic.forBloodPressureUnit(
            bloodPressureUnit,
          ),
          enabled: enabled,
          onUnitChanged: onBloodPressureUnitChanged,
        ),
        SizedBox(height: Theme.of(context).spacing.md),
        _vitalSignInput(
          context,
          controller: temperatureController,
          labelText: temperatureLabel,
          range: reference.temperature.forTemperatureUnit(temperatureUnit),
          unit: temperatureUnit,
          unitLabelText: resolvedUnitLabel,
          unitOptions: onTemperatureUnitChanged == null
              ? null
              : AppVitalsUnits.temperatureOptions,
          onUnitChanged: onTemperatureUnitChanged,
          unitWidth: 112,
        ),
        SizedBox(height: Theme.of(context).spacing.md),
        _vitalSignInput(
          context,
          controller: heartRateController,
          labelText: heartRateLabel,
          range: reference.heartRate,
          unit: AppVitalsUnits.heartRate,
          unitLabelText: resolvedUnitLabel,
        ),
        SizedBox(height: Theme.of(context).spacing.md),
        _vitalSignsGrid(context, <Widget>[
          _vitalSignInput(
            context,
            controller: respiratoryRateController,
            labelText: respiratoryRateLabel,
            range: reference.respiratoryRate,
            unit: AppVitalsUnits.respiratoryRate,
            unitLabelText: resolvedUnitLabel,
          ),
          _vitalSignInput(
            context,
            controller: oxygenSaturationController,
            labelText: oxygenSaturationLabel,
            range: reference.oxygenSaturation,
            unit: AppVitalsUnits.oxygenSaturation,
            unitLabelText: resolvedUnitLabel,
          ),
        ]),
        if (bodyMeasureFields.isNotEmpty) ...<Widget>[
          SizedBox(height: Theme.of(context).spacing.md),
          _vitalSignsGrid(context, bodyMeasureFields),
        ],
      ],
    );
  }

  Widget _vitalSignsGrid(BuildContext context, List<Widget> children) {
    final ThemeData theme = Theme.of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth >= 720 ? 2 : 1;
        final double gap = theme.spacing.md;
        final double width =
            (constraints.maxWidth - (gap * (columns - 1))) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: theme.spacing.md,
          children: <Widget>[
            for (final Widget child in children)
              SizedBox(width: math.max(width, 0), child: child),
          ],
        );
      },
    );
  }

  Widget _vitalSignInput(
    BuildContext context, {
    required TextEditingController controller,
    required String labelText,
    required AppVitalReferenceRange range,
    required String unit,
    required String unitLabelText,
    List<AppSelectOption<String>>? unitOptions,
    ValueChanged<String?>? onUnitChanged,
    double unitWidth = 128,
  }) {
    return _VitalSignInput(
      controller: controller,
      labelText: labelText,
      unit: unit,
      unitLabelText: unitLabelText,
      range: range,
      profileLabel: reference.profileLabel,
      enabled: enabled,
      unitOptions: unitOptions,
      onUnitChanged: onUnitChanged,
      unitWidth: unitWidth,
      validator: (String? value) =>
          _validateVitalValue(context, value, range, isRequired: false),
    );
  }

  String? _validateVitalValue(
    BuildContext context,
    String? value,
    AppVitalReferenceRange range, {
    required bool isRequired,
  }) {
    final String normalized = normalizeCurrencyAmount(value ?? '');
    if (normalized.isEmpty) {
      return isRequired ? context.l10n.validationRequired : null;
    }

    final double? parsed = double.tryParse(normalized);
    if (parsed == null) {
      return context.l10n.patientsVitalNumberInvalidMessage;
    }

    if (!range.containsValid(parsed)) {
      return context.l10n.patientsVitalLimitMessage(range.validLabel);
    }

    return null;
  }
}

@immutable
final class AppVitalsReference {
  const AppVitalsReference({
    required this.profileLabel,
    required this.systolic,
    required this.diastolic,
    required this.temperature,
    required this.heartRate,
    required this.respiratoryRate,
    required this.oxygenSaturation,
    required this.weight,
    required this.height,
  });

  const AppVitalsReference.adult()
    : profileLabel = 'adult',
      systolic = const AppVitalReferenceRange(
        normalMin: 90,
        normalMax: 120,
        validMin: 30,
        validMax: 300,
        unit: AppVitalsUnits.bloodPressureMmHg,
      ),
      diastolic = const AppVitalReferenceRange(
        normalMin: 60,
        normalMax: 80,
        validMin: 10,
        validMax: 200,
        unit: AppVitalsUnits.bloodPressureMmHg,
      ),
      temperature = const AppVitalReferenceRange(
        normalMin: 36,
        normalMax: 37.5,
        validMin: 25,
        validMax: 45,
        unit: AppVitalsUnits.temperatureCelsius,
        decimals: 1,
      ),
      heartRate = const AppVitalReferenceRange(
        normalMin: 60,
        normalMax: 100,
        validMin: 20,
        validMax: 250,
        unit: AppVitalsUnits.heartRate,
      ),
      respiratoryRate = const AppVitalReferenceRange(
        normalMin: 12,
        normalMax: 20,
        validMin: 4,
        validMax: 80,
        unit: AppVitalsUnits.respiratoryRate,
      ),
      oxygenSaturation = const AppVitalReferenceRange(
        normalMin: 94,
        normalMax: 100,
        validMin: 0,
        validMax: 100,
        unit: AppVitalsUnits.oxygenSaturation,
      ),
      weight = const AppVitalReferenceRange(
        normalMin: 45,
        normalMax: 120,
        validMin: 0.2,
        validMax: 400,
        unit: AppVitalsUnits.weightKilograms,
      ),
      height = const AppVitalReferenceRange(
        normalMin: 145,
        normalMax: 205,
        validMin: 20,
        validMax: 250,
        unit: AppVitalsUnits.heightCentimeters,
      );

  factory AppVitalsReference.fromPatientData({
    DateTime? dateOfBirth,
    String? gender,
  }) {
    final String ageBand = _resolveVitalAgeBand(dateOfBirth);
    final String sex = _resolveVitalSex(gender);
    return AppVitalsReference(
      profileLabel: _vitalProfileLabel(ageBand, sex),
      systolic: _bloodPressureSystolicRange(ageBand),
      diastolic: _bloodPressureDiastolicRange(ageBand),
      temperature: const AppVitalReferenceRange(
        normalMin: 36,
        normalMax: 37.5,
        validMin: 25,
        validMax: 45,
        unit: AppVitalsUnits.temperatureCelsius,
        decimals: 1,
      ),
      heartRate: _heartRateRange(ageBand),
      respiratoryRate: _respiratoryRateRange(ageBand),
      oxygenSaturation: const AppVitalReferenceRange(
        normalMin: 94,
        normalMax: 100,
        validMin: 0,
        validMax: 100,
        unit: AppVitalsUnits.oxygenSaturation,
      ),
      weight: _weightRange(ageBand, sex),
      height: _heightRange(ageBand, sex),
    );
  }

  final String profileLabel;
  final AppVitalReferenceRange systolic;
  final AppVitalReferenceRange diastolic;
  final AppVitalReferenceRange temperature;
  final AppVitalReferenceRange heartRate;
  final AppVitalReferenceRange respiratoryRate;
  final AppVitalReferenceRange oxygenSaturation;
  final AppVitalReferenceRange weight;
  final AppVitalReferenceRange height;
}

@immutable
final class AppVitalReferenceRange {
  const AppVitalReferenceRange({
    required this.normalMin,
    required this.normalMax,
    required this.validMin,
    required this.validMax,
    required this.unit,
    this.decimals = 0,
  });

  final double normalMin;
  final double normalMax;
  final double validMin;
  final double validMax;
  final String unit;
  final int decimals;

  bool containsNormal(double value) {
    return value >= normalMin && value <= normalMax;
  }

  bool containsValid(double value) {
    return value >= validMin && value <= validMax;
  }

  String get normalLabel {
    return '${formatAppVitalNumber(normalMin, decimals: decimals)}-'
        '${formatAppVitalNumber(normalMax, decimals: decimals)} $unit';
  }

  String get validLabel {
    return '${formatAppVitalNumber(validMin, decimals: decimals)}-'
        '${formatAppVitalNumber(validMax, decimals: decimals)} $unit';
  }

  AppVitalReferenceRange forBloodPressureUnit(String selectedUnit) {
    if (selectedUnit != AppVitalsUnits.bloodPressureKpa) {
      return this;
    }

    return AppVitalReferenceRange(
      normalMin: normalMin * AppVitalsUnits.bloodPressureKpaFactor,
      normalMax: normalMax * AppVitalsUnits.bloodPressureKpaFactor,
      validMin: validMin * AppVitalsUnits.bloodPressureKpaFactor,
      validMax: validMax * AppVitalsUnits.bloodPressureKpaFactor,
      unit: AppVitalsUnits.bloodPressureKpa,
      decimals: 1,
    );
  }

  AppVitalReferenceRange forTemperatureUnit(String selectedUnit) {
    if (selectedUnit != AppVitalsUnits.temperatureFahrenheit) {
      return this;
    }

    return AppVitalReferenceRange(
      normalMin: _celsiusToFahrenheit(normalMin),
      normalMax: _celsiusToFahrenheit(normalMax),
      validMin: _celsiusToFahrenheit(validMin),
      validMax: _celsiusToFahrenheit(validMax),
      unit: AppVitalsUnits.temperatureFahrenheit,
      decimals: 1,
    );
  }

  AppVitalReferenceRange forWeightUnit(String selectedUnit) {
    if (selectedUnit != AppVitalsUnits.weightPounds) {
      return this;
    }

    double convert(double value) => value * 2.2046226218;

    return AppVitalReferenceRange(
      normalMin: convert(normalMin),
      normalMax: convert(normalMax),
      validMin: convert(validMin),
      validMax: convert(validMax),
      unit: AppVitalsUnits.weightPounds,
      decimals: decimals,
    );
  }

  AppVitalReferenceRange forHeightUnit(String selectedUnit) {
    if (selectedUnit != AppVitalsUnits.heightMeters) {
      return this;
    }

    double convert(double value) => value / 100;

    return AppVitalReferenceRange(
      normalMin: convert(normalMin),
      normalMax: convert(normalMax),
      validMin: convert(validMin),
      validMax: convert(validMax),
      unit: AppVitalsUnits.heightMeters,
      decimals: 2,
    );
  }
}

abstract final class AppVitalsUnits {
  static const String bloodPressureMmHg = 'mmHg';
  static const String bloodPressureKpa = 'kPa';
  static const String temperatureCelsius = '\u00B0C';
  static const String temperatureFahrenheit = '\u00B0F';
  static const String heartRate = 'beats per minute';
  static const String respiratoryRate = 'breaths per minute';
  static const String oxygenSaturation = '%';
  static const String weightKilograms = 'kg';
  static const String weightPounds = 'lb';
  static const String heightCentimeters = 'cm';
  static const String heightMeters = 'm';
  static const double bloodPressureKpaFactor = 0.133322;

  static const List<AppSelectOption<String>>
  bloodPressureOptions = <AppSelectOption<String>>[
    AppSelectOption<String>(value: bloodPressureMmHg, label: bloodPressureMmHg),
    AppSelectOption<String>(value: bloodPressureKpa, label: bloodPressureKpa),
  ];

  static const List<AppSelectOption<String>> temperatureOptions =
      <AppSelectOption<String>>[
        AppSelectOption<String>(
          value: temperatureCelsius,
          label: temperatureCelsius,
        ),
        AppSelectOption<String>(
          value: temperatureFahrenheit,
          label: temperatureFahrenheit,
        ),
      ];

  static const List<AppSelectOption<String>> weightOptions =
      <AppSelectOption<String>>[
        AppSelectOption<String>(value: weightKilograms, label: weightKilograms),
        AppSelectOption<String>(value: weightPounds, label: weightPounds),
      ];

  static const List<AppSelectOption<String>> heightOptions =
      <AppSelectOption<String>>[
        AppSelectOption<String>(
          value: heightCentimeters,
          label: heightCentimeters,
        ),
        AppSelectOption<String>(value: heightMeters, label: heightMeters),
      ];
}

class _BloodPressureInput extends StatelessWidget {
  const _BloodPressureInput({
    required this.title,
    required this.systolicController,
    required this.diastolicController,
    required this.systolicLabelText,
    required this.diastolicLabelText,
    required this.unit,
    required this.unitLabelText,
    required this.unitOptions,
    required this.profileLabel,
    required this.systolicRange,
    required this.diastolicRange,
    required this.enabled,
    required this.onUnitChanged,
  });

  final String title;
  final TextEditingController systolicController;
  final TextEditingController diastolicController;
  final String systolicLabelText;
  final String diastolicLabelText;
  final String unit;
  final String unitLabelText;
  final List<AppSelectOption<String>> unitOptions;
  final String profileLabel;
  final AppVitalReferenceRange systolicRange;
  final AppVitalReferenceRange diastolicRange;
  final bool enabled;
  final ValueChanged<String?>? onUnitChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.md),
        child: AnimatedBuilder(
          animation: Listenable.merge(<Listenable>[
            systolicController,
            diastolicController,
          ]),
          builder: (BuildContext context, _) {
            final _VitalSignStatus? systolicStatus = _statusForVitalText(
              systolicController.text,
              systolicRange,
            );
            final _VitalSignStatus? diastolicStatus = _statusForVitalText(
              diastolicController.text,
              diastolicRange,
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final Widget heading = Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    );
                    final Widget? unitField = unitOptions.isEmpty
                        ? null
                        : _VitalUnitSelector(
                            value: unit,
                            labelText: unitLabelText,
                            enabled: enabled,
                            options: unitOptions,
                            onChanged: onUnitChanged,
                          );

                    if (constraints.maxWidth < 620) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          heading,
                          SizedBox(height: theme.spacing.sm),
                          _BloodPressureFieldPair(
                            left: _bloodPressureValueField(
                              context,
                              controller: systolicController,
                              labelText: systolicLabelText,
                              status: systolicStatus,
                              pairedController: diastolicController,
                              range: systolicRange,
                            ),
                            right: _bloodPressureValueField(
                              context,
                              controller: diastolicController,
                              labelText: diastolicLabelText,
                              status: diastolicStatus,
                              pairedController: systolicController,
                              range: diastolicRange,
                            ),
                          ),
                          if (unitField != null) ...<Widget>[
                            SizedBox(height: theme.spacing.sm),
                            SizedBox(width: double.infinity, child: unitField),
                          ],
                        ],
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        heading,
                        SizedBox(height: theme.spacing.sm),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              child: _bloodPressureValueField(
                                context,
                                controller: systolicController,
                                labelText: systolicLabelText,
                                status: systolicStatus,
                                pairedController: diastolicController,
                                range: systolicRange,
                              ),
                            ),
                            SizedBox(width: theme.spacing.md),
                            Expanded(
                              child: _bloodPressureValueField(
                                context,
                                controller: diastolicController,
                                labelText: diastolicLabelText,
                                status: diastolicStatus,
                                pairedController: systolicController,
                                range: diastolicRange,
                              ),
                            ),
                            if (unitField != null) ...<Widget>[
                              SizedBox(width: theme.spacing.md),
                              SizedBox(width: 132, child: unitField),
                            ],
                          ],
                        ),
                      ],
                    );
                  },
                ),
                SizedBox(height: theme.spacing.xs),
                _BloodPressureFieldPair(
                  left: _VitalRangeCaption(
                    status: systolicStatus,
                    range: systolicRange,
                    profileLabel: profileLabel,
                  ),
                  right: _VitalRangeCaption(
                    status: diastolicStatus,
                    range: diastolicRange,
                    profileLabel: profileLabel,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _bloodPressureValueField(
    BuildContext context, {
    required TextEditingController controller,
    required TextEditingController pairedController,
    required String labelText,
    required _VitalSignStatus? status,
    required AppVitalReferenceRange range,
  }) {
    final Color? statusColor = _statusColor(context, status);
    return AppTextField(
      controller: controller,
      labelText: labelText,
      semanticLabel: '$labelText $unit',
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: <TextInputFormatter>[
        const CurrencyAmountInputFormatter(),
      ],
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (String? value) => _validateVitalValue(
        context,
        value,
        range,
        isRequired: normalizeCurrencyAmount(pairedController.text).isNotEmpty,
      ),
      suffixIcon: status == null
          ? null
          : Icon(_statusIcon(status), color: statusColor),
    );
  }
}

class _BloodPressureFieldPair extends StatelessWidget {
  const _BloodPressureFieldPair({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 560) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              left,
              SizedBox(height: theme.spacing.sm),
              right,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: left),
            SizedBox(width: theme.spacing.md),
            Expanded(child: right),
          ],
        );
      },
    );
  }
}

class _VitalSignInput extends StatelessWidget {
  const _VitalSignInput({
    required this.controller,
    required this.labelText,
    required this.unit,
    required this.unitLabelText,
    required this.range,
    required this.profileLabel,
    required this.enabled,
    this.unitWidth = 128,
    this.unitOptions,
    this.onUnitChanged,
    this.validator,
  });

  final TextEditingController controller;
  final String labelText;
  final String unit;
  final String unitLabelText;
  final AppVitalReferenceRange range;
  final String profileLabel;
  final bool enabled;
  final double unitWidth;
  final List<AppSelectOption<String>>? unitOptions;
  final ValueChanged<String?>? onUnitChanged;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (BuildContext context, TextEditingValue value, _) {
        final _VitalSignStatus? status = _statusForVitalText(value.text, range);
        final Color? statusColor = _statusColor(context, status);
        final Widget? statusIcon = status == null
            ? null
            : Icon(
                _statusIcon(status),
                color: statusColor,
                size: Theme.of(context).appTokens.listIconSize,
              );
        final Widget input = AppTextField(
          controller: controller,
          labelText: labelText,
          semanticLabel: '$labelText $unit',
          enabled: enabled,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: <TextInputFormatter>[
            const CurrencyAmountInputFormatter(),
          ],
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: validator,
          suffixIcon: unitOptions == null
              ? _VitalFieldSuffix(unit: unit, statusIcon: statusIcon)
              : status == null
              ? null
              : statusIcon,
        );
        final Widget? unitControl = unitOptions == null
            ? null
            : _VitalUnitSelector(
                value: unit,
                labelText: unitLabelText,
                enabled: enabled,
                options: unitOptions!,
                onChanged: onUnitChanged,
              );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (unitControl == null)
              input
            else
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final bool stacked =
                      constraints.hasBoundedWidth && constraints.maxWidth < 340;
                  if (stacked) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        input,
                        SizedBox(height: Theme.of(context).spacing.sm),
                        SizedBox(width: double.infinity, child: unitControl),
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(child: input),
                      SizedBox(width: Theme.of(context).spacing.sm),
                      SizedBox(width: unitWidth, child: unitControl),
                    ],
                  );
                },
              ),
            SizedBox(height: Theme.of(context).spacing.xs),
            _VitalRangeCaption(
              status: status,
              range: range,
              profileLabel: profileLabel,
            ),
          ],
        );
      },
    );
  }
}

class _VitalUnitSelector extends StatelessWidget {
  const _VitalUnitSelector({
    required this.value,
    required this.labelText,
    required this.enabled,
    required this.options,
    required this.onChanged,
  });

  final String value;
  final String labelText;
  final bool enabled;
  final List<AppSelectOption<String>> options;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle? valueStyle = theme.textTheme.bodyLarge?.copyWith(
      color: enabled
          ? theme.colorScheme.onSurface
          : theme.colorScheme.onSurface.withValues(alpha: 0.62),
      fontWeight: FontWeight.w500,
    );

    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      menuMaxHeight: 144,
      icon: const Icon(Icons.arrow_drop_down),
      style: valueStyle,
      decoration: InputDecoration(labelText: labelText),
      onChanged: enabled ? onChanged : null,
      items: <DropdownMenuItem<String>>[
        for (final AppSelectOption<String> option in options)
          DropdownMenuItem<String>(
            value: option.value,
            enabled: option.enabled,
            child: Text(
              option.label,
              maxLines: 1,
              overflow: TextOverflow.visible,
            ),
          ),
      ],
    );
  }
}

class _VitalFieldSuffix extends StatelessWidget {
  const _VitalFieldSuffix({required this.unit, required this.statusIcon});

  final String unit;
  final Widget? statusIcon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: theme.spacing.xs,
        end: theme.spacing.sm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            unit,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (statusIcon != null) ...<Widget>[
            SizedBox(width: theme.spacing.xs),
            statusIcon!,
          ],
        ],
      ),
    );
  }
}

class _VitalRangeCaption extends StatelessWidget {
  const _VitalRangeCaption({
    required this.status,
    required this.range,
    required this.profileLabel,
  });

  final _VitalSignStatus? status;
  final AppVitalReferenceRange range;
  final String profileLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final AppStatusColors statusColors = theme.statusColors;
    final String rangeText = l10n.patientsVitalRangeSuggestion(
      profileLabel,
      range.normalLabel,
    );
    final String text = switch (status) {
      _VitalSignStatus.normal =>
        '${l10n.patientsVitalNormalLabel} - $rangeText',
      _VitalSignStatus.abnormal =>
        '${l10n.patientsVitalAbnormalLabel} - $rangeText',
      null => rangeText,
    };
    final Color color = switch (status) {
      _VitalSignStatus.normal => statusColors.success,
      _VitalSignStatus.abnormal => statusColors.warning,
      null => theme.colorScheme.onSurfaceVariant,
    };

    return Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodySmall?.copyWith(
        color: color,
        fontWeight: status == null ? FontWeight.w500 : FontWeight.w700,
      ),
    );
  }
}

enum _VitalSignStatus { normal, abnormal }

_VitalSignStatus? _statusForVitalText(
  String text,
  AppVitalReferenceRange range,
) {
  final double? value = parseAppVitalInput(text);
  if (value == null) {
    return null;
  }
  return range.containsNormal(value)
      ? _VitalSignStatus.normal
      : _VitalSignStatus.abnormal;
}

String? _validateVitalValue(
  BuildContext context,
  String? value,
  AppVitalReferenceRange range, {
  required bool isRequired,
}) {
  final String normalized = normalizeCurrencyAmount(value ?? '');
  if (normalized.isEmpty) {
    return isRequired ? context.l10n.validationRequired : null;
  }

  final double? parsed = double.tryParse(normalized);
  if (parsed == null) {
    return context.l10n.patientsVitalNumberInvalidMessage;
  }

  if (!range.containsValid(parsed)) {
    return context.l10n.patientsVitalLimitMessage(range.validLabel);
  }

  return null;
}

Color? _statusColor(BuildContext context, _VitalSignStatus? status) {
  final AppStatusColors statusColors = Theme.of(context).statusColors;
  return switch (status) {
    _VitalSignStatus.normal => statusColors.success,
    _VitalSignStatus.abnormal => statusColors.warning,
    null => null,
  };
}

IconData _statusIcon(_VitalSignStatus status) {
  return switch (status) {
    _VitalSignStatus.normal => Icons.check_circle_outline,
    _VitalSignStatus.abnormal => Icons.warning_amber_outlined,
  };
}

String _resolveVitalAgeBand(DateTime? dateOfBirth) {
  if (dateOfBirth == null) {
    return 'ADULT';
  }
  final DateTime now = DateTime.now();
  final int ageDays = now.difference(dateOfBirth).inDays.clamp(0, 36500);
  int ageMonths =
      (now.year - dateOfBirth.year) * 12 + now.month - dateOfBirth.month;
  if (now.day < dateOfBirth.day) {
    ageMonths -= 1;
  }
  ageMonths = math.max(0, ageMonths);

  int ageYears = now.year - dateOfBirth.year;
  final int monthDelta = now.month - dateOfBirth.month;
  if (monthDelta < 0 || (monthDelta == 0 && now.day < dateOfBirth.day)) {
    ageYears -= 1;
  }
  ageYears = math.max(0, ageYears);

  if (ageDays <= 28) {
    return 'NEONATE';
  }
  if (ageMonths < 12) {
    return 'INFANT';
  }
  if (ageYears < 13) {
    return 'CHILD';
  }
  if (ageYears < 18) {
    return 'ADOLESCENT';
  }
  return 'ADULT';
}

String _resolveVitalSex(String? sex) {
  final String normalized = (sex ?? '').trim().toUpperCase();
  if (normalized == 'MALE' || normalized == 'FEMALE') {
    return normalized;
  }
  return 'UNSPECIFIED_SEX';
}

String _vitalProfileLabel(String ageBand, String sex) {
  return '${_apiLabel(ageBand)} ${_apiLabel(sex)}';
}

String _apiLabel(String value) {
  return value
      .split('_')
      .where((String part) => part.isNotEmpty)
      .map((String part) {
        final String lower = part.toLowerCase();
        return '${lower[0].toUpperCase()}${lower.substring(1)}';
      })
      .join(' ');
}

AppVitalReferenceRange _bloodPressureSystolicRange(String ageBand) {
  return switch (ageBand) {
    'NEONATE' => _range(60, 90, 30, 300, AppVitalsUnits.bloodPressureMmHg),
    'INFANT' => _range(70, 100, 30, 300, AppVitalsUnits.bloodPressureMmHg),
    'CHILD' => _range(90, 110, 30, 300, AppVitalsUnits.bloodPressureMmHg),
    'ADOLESCENT' => _range(95, 120, 30, 300, AppVitalsUnits.bloodPressureMmHg),
    _ => _range(90, 120, 30, 300, AppVitalsUnits.bloodPressureMmHg),
  };
}

AppVitalReferenceRange _bloodPressureDiastolicRange(String ageBand) {
  return switch (ageBand) {
    'NEONATE' => _range(30, 60, 10, 200, AppVitalsUnits.bloodPressureMmHg),
    'INFANT' => _range(35, 65, 10, 200, AppVitalsUnits.bloodPressureMmHg),
    'CHILD' => _range(55, 75, 10, 200, AppVitalsUnits.bloodPressureMmHg),
    'ADOLESCENT' => _range(60, 80, 10, 200, AppVitalsUnits.bloodPressureMmHg),
    _ => _range(60, 80, 10, 200, AppVitalsUnits.bloodPressureMmHg),
  };
}

AppVitalReferenceRange _heartRateRange(String ageBand) {
  return switch (ageBand) {
    'NEONATE' => _range(100, 180, 20, 250, AppVitalsUnits.heartRate),
    'INFANT' => _range(100, 160, 20, 250, AppVitalsUnits.heartRate),
    'CHILD' => _range(70, 130, 20, 250, AppVitalsUnits.heartRate),
    'ADOLESCENT' => _range(60, 110, 20, 250, AppVitalsUnits.heartRate),
    _ => _range(60, 100, 20, 250, AppVitalsUnits.heartRate),
  };
}

AppVitalReferenceRange _respiratoryRateRange(String ageBand) {
  return switch (ageBand) {
    'NEONATE' => _range(30, 60, 4, 80, AppVitalsUnits.respiratoryRate),
    'INFANT' => _range(30, 53, 4, 80, AppVitalsUnits.respiratoryRate),
    'CHILD' => _range(20, 30, 4, 80, AppVitalsUnits.respiratoryRate),
    'ADOLESCENT' => _range(12, 20, 4, 80, AppVitalsUnits.respiratoryRate),
    _ => _range(12, 20, 4, 80, AppVitalsUnits.respiratoryRate),
  };
}

AppVitalReferenceRange _weightRange(String ageBand, String sex) {
  return switch (ageBand) {
    'NEONATE' => _range(
      2.5,
      4.5,
      0.2,
      400,
      AppVitalsUnits.weightKilograms,
      decimals: 1,
    ),
    'INFANT' => _range(
      3.5,
      11,
      0.2,
      400,
      AppVitalsUnits.weightKilograms,
      decimals: 1,
    ),
    'CHILD' => _range(10, 45, 0.2, 400, AppVitalsUnits.weightKilograms),
    'ADOLESCENT' when sex == 'MALE' => _range(
      40,
      90,
      0.2,
      400,
      AppVitalsUnits.weightKilograms,
    ),
    'ADOLESCENT' when sex == 'FEMALE' => _range(
      35,
      80,
      0.2,
      400,
      AppVitalsUnits.weightKilograms,
    ),
    'ADOLESCENT' => _range(35, 80, 0.2, 400, AppVitalsUnits.weightKilograms),
    'ADULT' when sex == 'MALE' => _range(
      50,
      140,
      0.2,
      400,
      AppVitalsUnits.weightKilograms,
    ),
    'ADULT' when sex == 'FEMALE' => _range(
      40,
      130,
      0.2,
      400,
      AppVitalsUnits.weightKilograms,
    ),
    _ => _range(45, 120, 0.2, 400, AppVitalsUnits.weightKilograms),
  };
}

AppVitalReferenceRange _heightRange(String ageBand, String sex) {
  return switch (ageBand) {
    'NEONATE' => _range(45, 55, 20, 250, AppVitalsUnits.heightCentimeters),
    'INFANT' => _range(50, 80, 20, 250, AppVitalsUnits.heightCentimeters),
    'CHILD' => _range(80, 155, 20, 250, AppVitalsUnits.heightCentimeters),
    'ADOLESCENT' when sex == 'MALE' => _range(
      140,
      195,
      20,
      250,
      AppVitalsUnits.heightCentimeters,
    ),
    'ADOLESCENT' when sex == 'FEMALE' => _range(
      140,
      180,
      20,
      250,
      AppVitalsUnits.heightCentimeters,
    ),
    'ADOLESCENT' => _range(140, 190, 20, 250, AppVitalsUnits.heightCentimeters),
    'ADULT' when sex == 'MALE' => _range(
      150,
      210,
      20,
      250,
      AppVitalsUnits.heightCentimeters,
    ),
    'ADULT' when sex == 'FEMALE' => _range(
      140,
      200,
      20,
      250,
      AppVitalsUnits.heightCentimeters,
    ),
    _ => _range(145, 205, 20, 250, AppVitalsUnits.heightCentimeters),
  };
}

AppVitalReferenceRange _range(
  num normalMin,
  num normalMax,
  num validMin,
  num validMax,
  String unit, {
  int decimals = 0,
}) {
  return AppVitalReferenceRange(
    normalMin: normalMin.toDouble(),
    normalMax: normalMax.toDouble(),
    validMin: validMin.toDouble(),
    validMax: validMax.toDouble(),
    unit: unit,
    decimals: decimals,
  );
}

double? parseAppVitalInput(String? value) {
  final String normalized = normalizeCurrencyAmount(value ?? '');
  if (normalized.isEmpty) {
    return null;
  }
  return double.tryParse(normalized);
}

String formatAppVitalNumber(num value, {int decimals = 0}) {
  if (decimals <= 0 && value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toStringAsFixed(decimals);
}

double _celsiusToFahrenheit(double value) => (value * 9 / 5) + 32;
