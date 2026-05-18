import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/shared/components/app_text_field.dart';

class AppVitalsForm extends StatelessWidget {
  const AppVitalsForm({
    required this.temperatureController,
    required this.systolicController,
    required this.diastolicController,
    required this.heartRateController,
    required this.respiratoryRateController,
    required this.oxygenSaturationController,
    required this.weightController,
    required this.temperatureLabel,
    required this.systolicLabel,
    required this.diastolicLabel,
    required this.heartRateLabel,
    required this.respiratoryRateLabel,
    required this.oxygenSaturationLabel,
    required this.weightLabel,
    this.enabled = true,
    super.key,
  });

  final TextEditingController temperatureController;
  final TextEditingController systolicController;
  final TextEditingController diastolicController;
  final TextEditingController heartRateController;
  final TextEditingController respiratoryRateController;
  final TextEditingController oxygenSaturationController;
  final TextEditingController weightController;
  final String temperatureLabel;
  final String systolicLabel;
  final String diastolicLabel;
  final String heartRateLabel;
  final String respiratoryRateLabel;
  final String oxygenSaturationLabel;
  final String weightLabel;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _grid(context, <Widget>[
          _decimalField(temperatureController, temperatureLabel),
          _integerField(heartRateController, heartRateLabel),
        ]),
        SizedBox(height: Theme.of(context).spacing.md),
        _grid(context, <Widget>[
          _decimalField(systolicController, systolicLabel),
          _decimalField(diastolicController, diastolicLabel),
        ]),
        SizedBox(height: Theme.of(context).spacing.md),
        _grid(context, <Widget>[
          _integerField(respiratoryRateController, respiratoryRateLabel),
          _integerField(oxygenSaturationController, oxygenSaturationLabel),
          _decimalField(weightController, weightLabel),
        ]),
      ],
    );
  }

  Widget _grid(BuildContext context, List<Widget> children) {
    final ThemeData theme = Theme.of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth >= 680 ? 2 : 1;
        final double gap = theme.spacing.md;
        final double width =
            (constraints.maxWidth - (gap * (columns - 1))) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: <Widget>[
            for (final Widget child in children)
              SizedBox(width: math.max(width, 0), child: child),
          ],
        );
      },
    );
  }

  Widget _decimalField(TextEditingController controller, String label) {
    return AppTextField(
      controller: controller,
      labelText: label,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ],
    );
  }

  Widget _integerField(TextEditingController controller, String label) {
    return AppTextField(
      controller: controller,
      labelText: label,
      enabled: enabled,
      keyboardType: TextInputType.number,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
      ],
    );
  }
}
