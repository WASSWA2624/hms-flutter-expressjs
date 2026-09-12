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
    return AppPropertyValueList(
      spacing: Theme.of(context).spacing.md,
      items: <AppPropertyValueData>[
        for (final AppWorkspacePatientContextField field in fields)
          if (field.hasValue)
            AppPropertyValueData(
              label: field.label,
              value: field.value,
              icon: field.icon,
              copyable: field.copyable,
              copyTooltip: field.copyTooltip,
              copiedMessage: field.copiedMessage,
              copySemanticLabel: field.copySemanticLabel,
              showCopyIcon: field.showCopyIcon,
              copyPlaceholderValues: field.copyPlaceholderValues,
            ),
      ],
    );
  }
}
