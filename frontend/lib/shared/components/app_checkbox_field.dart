import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/shared/components/app_field_error_text.dart';

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
        final Widget titleContent = secondary == null
            ? Text(title)
            : Row(
                children: <Widget>[
                  IconTheme(
                    data: IconThemeData(
                      size: theme.appTokens.listIconSize,
                      color: canChange
                          ? theme.colorScheme.onSurfaceVariant
                          : theme.disabledColor,
                    ),
                    child: secondary!,
                  ),
                  SizedBox(width: theme.spacing.sm),
                  Expanded(child: Text(title)),
                ],
              );
        Widget content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Material(
              type: MaterialType.transparency,
              child: CheckboxListTile(
                value: field.value ?? false,
                onChanged: canChange
                    ? (bool? newValue) {
                        final bool resolvedValue = newValue ?? false;
                        field.didChange(resolvedValue);
                        onChanged?.call(resolvedValue);
                      }
                    : null,
                title: titleContent,
                subtitle: subtitle == null ? null : Text(subtitle!),
                enabled: canChange,
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
