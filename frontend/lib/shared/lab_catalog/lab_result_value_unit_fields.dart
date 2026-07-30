import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/lab/domain/entities/lab_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

/// Dense result-value + result-unit row used across lab result dialogs.
///
/// Keeps [AppTextField] and [AppSelectField]/[AppTextField] unit controls at
/// the same height (`isDense: true`). Stacks below [stackBelowWidth].
class LabResultValueUnitFields extends StatelessWidget {
  const LabResultValueUnitFields({
    required this.valueController,
    required this.unitController,
    required this.item,
    this.enabled = true,
    this.valueRequired = false,
    this.onChanged,
    this.valueValidator,
    this.valueStyle,
    this.stackBelowWidth = 420,
    this.valueFlex = 3,
    this.unitFlex = 2,
    super.key,
  });

  final TextEditingController valueController;
  final TextEditingController unitController;
  final LabOrderItem item;
  final bool enabled;
  final bool valueRequired;
  final VoidCallback? onChanged;
  final FormFieldValidator<String>? valueValidator;

  /// Optional style for the result value input (e.g. interpretation tint).
  final TextStyle? valueStyle;
  final double stackBelowWidth;
  final int valueFlex;
  final int unitFlex;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool stackFields = constraints.maxWidth < stackBelowWidth;
        final Widget valueField = AppTextField(
          controller: valueController,
          labelText: l10n.labResultValueLabel,
          enabled: enabled,
          isRequired: valueRequired,
          isDense: true,
          style: valueStyle,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: enabled && onChanged != null
              ? (_) => onChanged!()
              : null,
          validator: valueValidator,
        );
        final Widget unitField = LabResultUnitField(
          item: item,
          controller: unitController,
          enabled: enabled,
          onChanged: onChanged,
        );

        if (stackFields) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              valueField,
              SizedBox(height: theme.spacing.xs),
              unitField,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(flex: valueFlex, child: valueField),
            SizedBox(width: theme.spacing.sm),
            Expanded(flex: unitFlex, child: unitField),
          ],
        );
      },
    );
  }
}

/// Dense unit control that prefers catalog unit options when present.
class LabResultUnitField extends StatelessWidget {
  const LabResultUnitField({
    required this.item,
    required this.controller,
    this.enabled = true,
    this.onChanged,
    super.key,
  });

  final LabOrderItem item;
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    if (item.unitOptions.isEmpty) {
      return AppTextField(
        controller: controller,
        labelText: l10n.labResultUnitLabel,
        enabled: enabled,
        isDense: true,
        onChanged: enabled && onChanged != null ? (_) => onChanged!() : null,
      );
    }

    return AppSelectField<String>(
      value: controller.text.trim().isEmpty ? null : controller.text.trim(),
      labelText: l10n.labResultUnitLabel,
      enabled: enabled,
      allowClear: false,
      isDense: true,
      options: <AppSelectOption<String>>[
        for (final LabUnitOption option in item.unitOptions)
          AppSelectOption<String>(
            value: option.unit ?? option.label ?? option.id,
            label: option.displayLabel,
            leadingIcon: const Icon(Icons.straighten_outlined),
            searchText:
                '${option.id} ${option.label ?? ''} ${option.unit ?? ''}',
          ),
      ],
      onChanged: enabled
          ? (String? value) {
              controller.text = value ?? '';
              onChanged?.call();
            }
          : null,
    );
  }
}
