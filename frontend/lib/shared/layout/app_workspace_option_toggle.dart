import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';

@immutable
final class AppWorkspaceOptionToggleOption<T extends Object> {
  const AppWorkspaceOptionToggleOption({
    required this.value,
    required this.label,
    this.icon,
    this.semanticLabel,
    this.tooltip,
  });

  final T value;
  final String label;
  final IconData? icon;
  final String? semanticLabel;
  final String? tooltip;
}

/// Single-select workspace control for panel tabs, filters, and similar toggles.
class AppWorkspaceOptionToggle<T extends Object> extends StatelessWidget {
  const AppWorkspaceOptionToggle({
    required this.value,
    required this.options,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final T value;
  final List<AppWorkspaceOptionToggleOption<T>> options;
  final ValueChanged<T> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Theme.of(context).spacing.xs,
      runSpacing: Theme.of(context).spacing.xs,
      children: <Widget>[
        for (final AppWorkspaceOptionToggleOption<T> option in options)
          AppButton(
            label: option.label,
            leadingIcon: option.icon,
            semanticLabel: option.semanticLabel ?? option.label,
            tooltip: option.tooltip ?? option.label,
            variant: value == option.value
                ? AppButtonVariant.primary
                : AppButtonVariant.secondary,
            enabled: enabled,
            onPressed: value == option.value
                ? null
                : () => onChanged(option.value),
          ),
      ],
    );
  }
}
