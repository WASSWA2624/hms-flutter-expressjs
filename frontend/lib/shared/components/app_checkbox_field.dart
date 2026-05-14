import 'package:flutter/material.dart';
import 'package:flutter_template/app/theme/app_theme_extensions.dart';
import 'package:flutter_template/shared/components/src/app_field_error_text.dart';

class AppCheckboxField extends StatelessWidget {
  const AppCheckboxField({
    required this.title,
    required this.value,
    this.onChanged,
    this.subtitle,
    this.errorText,
    this.semanticLabel,
    this.validator,
    this.onSaved,
    this.autovalidateMode = AutovalidateMode.disabled,
    this.enabled = true,
    this.secondary,
    this.contentPadding,
    super.key,
  });

  final String title;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? subtitle;
  final String? errorText;
  final String? semanticLabel;
  final FormFieldValidator<bool>? validator;
  final FormFieldSetter<bool>? onSaved;
  final AutovalidateMode autovalidateMode;
  final bool enabled;
  final Widget? secondary;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool canChange = enabled;

    return FormField<bool>(
      key: ValueKey<bool>(value),
      initialValue: value,
      validator: validator,
      onSaved: onSaved,
      autovalidateMode: autovalidateMode,
      forceErrorText: errorText,
      builder: (FormFieldState<bool> field) {
        Widget content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            CheckboxListTile(
              value: field.value ?? false,
              onChanged: canChange
                  ? (bool? newValue) {
                      final bool resolvedValue = newValue ?? false;
                      field.didChange(resolvedValue);
                      onChanged?.call(resolvedValue);
                    }
                  : null,
              title: Text(title),
              subtitle: subtitle == null ? null : Text(subtitle!),
              secondary: secondary,
              enabled: canChange,
              dense: true,
              visualDensity: VisualDensity.compact,
              contentPadding: contentPadding ?? EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),
            if (field.errorText != null) ...<Widget>[
              SizedBox(height: theme.spacing.xs),
              AppFieldErrorText(errorText: field.errorText),
            ],
          ],
        );

        if (semanticLabel != null) {
          content = Semantics(
            checked: field.value ?? false,
            enabled: canChange,
            label: semanticLabel,
            child: content,
          );
        }

        return content;
      },
    );
  }
}
