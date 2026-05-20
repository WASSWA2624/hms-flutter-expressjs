import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/shared/components/src/app_field_error_text.dart';

class AppRadioOption<T> {
  const AppRadioOption({
    required this.value,
    required this.label,
    this.description,
    this.secondary,
    this.enabled = true,
  });

  final T value;
  final String label;
  final String? description;
  final Widget? secondary;
  final bool enabled;
}

class AppRadioGroup<T> extends StatelessWidget {
  const AppRadioGroup({
    required this.options,
    this.value,
    this.onChanged,
    this.labelText,
    this.errorText,
    this.semanticLabel,
    this.validator,
    this.onSaved,
    this.autovalidateMode = AutovalidateMode.disabled,
    this.enabled = true,
    this.contentPadding,
    super.key,
  });

  final List<AppRadioOption<T>> options;
  final T? value;
  final ValueChanged<T?>? onChanged;
  final String? labelText;
  final String? errorText;
  final String? semanticLabel;
  final FormFieldValidator<T>? validator;
  final FormFieldSetter<T>? onSaved;
  final AutovalidateMode autovalidateMode;
  final bool enabled;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool canChange = enabled;

    return FormField<T>(
      key: ValueKey<T?>(value),
      initialValue: value,
      validator: validator,
      onSaved: onSaved,
      autovalidateMode: autovalidateMode,
      forceErrorText: errorText,
      builder: (FormFieldState<T> field) {
        final Widget group = RadioGroup<T>(
          groupValue: field.value,
          onChanged: canChange
              ? (T? newValue) {
                  field.didChange(newValue);
                  onChanged?.call(newValue);
                }
              : (_) {},
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (labelText != null) ...<Widget>[
                Text(labelText!, style: theme.textTheme.titleSmall),
                SizedBox(height: theme.spacing.xs),
              ],
              for (final AppRadioOption<T> option in options)
                Material(
                  type: MaterialType.transparency,
                  child: RadioListTile<T>(
                    value: option.value,
                    enabled: canChange && option.enabled,
                    title: Text(option.label),
                    subtitle: option.description == null
                        ? null
                        : Text(option.description!),
                    secondary: option.secondary,
                    selected: field.value == option.value,
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    contentPadding: contentPadding ?? EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ),
              if (field.errorText != null) ...<Widget>[
                SizedBox(height: theme.spacing.xs),
                AppFieldErrorText(errorText: field.errorText),
              ],
            ],
          ),
        );

        if (semanticLabel == null && labelText == null) {
          return group;
        }

        return Semantics(
          container: true,
          enabled: canChange,
          label: semanticLabel ?? labelText,
          child: group,
        );
      },
    );
  }
}
