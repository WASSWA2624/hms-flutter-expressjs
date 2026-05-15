import 'package:flutter/material.dart';
import 'package:hosspi_hms/shared/components/app_select_field.dart';
import 'package:hosspi_hms/shared/forms/app_validators.dart';

class AppGenderField extends StatelessWidget {
  const AppGenderField({
    required this.maleLabel,
    required this.femaleLabel,
    required this.otherLabel,
    required this.unknownLabel,
    this.value,
    this.onChanged,
    this.labelText,
    this.hintText,
    this.helperText,
    this.errorText,
    this.semanticLabel,
    this.requiredMessage,
    this.validator,
    this.onSaved,
    this.autovalidateMode = AutovalidateMode.disabled,
    this.enabled = true,
    this.isLoading = false,
    this.isRequired = false,
    this.includeUnknown = true,
    this.focusNode,
    this.restorationId,
    this.menuHeight,
    super.key,
  }) : assert(
         !isRequired || requiredMessage != null,
         'requiredMessage must be provided when isRequired is true.',
       );

  static const String male = 'MALE';
  static const String female = 'FEMALE';
  static const String other = 'OTHER';
  static const String unknown = 'UNKNOWN';

  final String? value;
  final ValueChanged<String?>? onChanged;
  final String? labelText;
  final String? hintText;
  final String? helperText;
  final String? errorText;
  final String? semanticLabel;
  final String? requiredMessage;
  final FormFieldValidator<String>? validator;
  final FormFieldSetter<String>? onSaved;
  final AutovalidateMode autovalidateMode;
  final bool enabled;
  final bool isLoading;
  final bool isRequired;
  final bool includeUnknown;
  final FocusNode? focusNode;
  final String? restorationId;
  final double? menuHeight;
  final String maleLabel;
  final String femaleLabel;
  final String otherLabel;
  final String unknownLabel;

  @override
  Widget build(BuildContext context) {
    return AppSelectField<String>(
      value: value,
      onChanged: onChanged,
      labelText: labelText,
      hintText: hintText,
      helperText: helperText,
      errorText: errorText,
      semanticLabel: semanticLabel,
      validator: _validator(),
      onSaved: onSaved,
      autovalidateMode: autovalidateMode,
      enabled: enabled,
      isLoading: isLoading,
      isRequired: isRequired,
      focusNode: focusNode,
      restorationId: restorationId,
      menuHeight: menuHeight,
      options: <AppSelectOption<String>>[
        AppSelectOption<String>(
          value: male,
          label: maleLabel,
          leadingIcon: const Icon(Icons.male),
        ),
        AppSelectOption<String>(
          value: female,
          label: femaleLabel,
          leadingIcon: const Icon(Icons.female),
        ),
        AppSelectOption<String>(
          value: other,
          label: otherLabel,
          leadingIcon: const Icon(Icons.diversity_3_outlined),
        ),
        if (includeUnknown)
          AppSelectOption<String>(
            value: unknown,
            label: unknownLabel,
            leadingIcon: const Icon(Icons.help_outline),
          ),
      ],
    );
  }

  FormFieldValidator<String>? _validator() {
    if (!isRequired && validator == null) {
      return null;
    }

    return AppValidators.compose<String>(<FormFieldValidator<String>>[
      if (isRequired) AppValidators.requiredValue<String>(requiredMessage!),
      ?validator,
    ]);
  }
}
