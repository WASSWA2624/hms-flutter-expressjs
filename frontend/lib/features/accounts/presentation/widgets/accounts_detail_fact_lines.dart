import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

/// Flat horizontal summary facts: icon + "Label: value" (no nested cards).
class AccountsDetailFactLines extends StatelessWidget {
  const AccountsDetailFactLines({required this.fields, super.key});

  final List<AppWorkspacePatientContextField> fields;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final List<AppWorkspacePatientContextField> visible = fields
        .where((AppWorkspacePatientContextField field) => field.hasValue)
        .toList(growable: false);
    if (visible.isEmpty) {
      return const SizedBox.shrink();
    }

    final TextStyle? labelStyle = theme.textTheme.bodyMedium?.copyWith(
      color: colorScheme.onSurfaceVariant,
      fontWeight: AppFontWeight.emphasis,
    );
    final TextStyle? valueStyle = theme.textTheme.bodyMedium?.copyWith(
      color: colorScheme.onSurface,
      fontWeight: AppFontWeight.regular,
    );

    return Wrap(
      spacing: theme.spacing.md,
      runSpacing: theme.spacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        for (final AppWorkspacePatientContextField field in visible)
          _AccountsDetailFactLine(
            field: field,
            labelStyle: labelStyle,
            valueStyle: valueStyle,
          ),
      ],
    );
  }
}

class _AccountsDetailFactLine extends StatelessWidget {
  const _AccountsDetailFactLine({
    required this.field,
    required this.labelStyle,
    required this.valueStyle,
  });

  final AppWorkspacePatientContextField field;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Semantics(
      label: '${field.label}: ${field.value}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (field.icon != null) ...<Widget>[
            Icon(
              field.icon,
              size: theme.appTokens.listIconSize,
              color: theme.colorScheme.primary,
            ),
            SizedBox(width: theme.spacing.xs),
          ],
          Text.rich(
            TextSpan(
              children: <InlineSpan>[
                TextSpan(text: '${field.label}: ', style: labelStyle),
                if (field.copyable)
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: AppCopyableIdentifier(
                      value: field.value,
                      tooltip: field.copyTooltip,
                      copiedMessage: field.copiedMessage,
                      semanticLabel: field.copySemanticLabel,
                      showCopyIcon: field.showCopyIcon,
                      placeholderValues: field.copyPlaceholderValues,
                      textStyle: valueStyle,
                    ),
                  )
                else
                  TextSpan(text: field.value, style: valueStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
