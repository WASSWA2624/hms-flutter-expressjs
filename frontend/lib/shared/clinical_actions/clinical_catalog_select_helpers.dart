import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/clinical_actions/clinical_action_models.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_action_dialog_helpers.dart';
import 'package:hosspi_hms/shared/clinical_actions/dialogs/clinical_request_flow_dialogs.dart';
import 'package:hosspi_hms/shared/components/components.dart';

String clinicalCatalogOptionSearchText(
  ClinicalActionCatalogOption option, {
  Iterable<String?> extra = const <String?>[],
}) {
  return clinicalActionJoinDisplay(<String?>[
    option.apiId,
    option.displayTitle,
    option.displaySubtitle,
    option.name,
    option.code,
    option.category,
    option.secondaryText,
    option.status,
    option.searchText,
    ...extra,
  ]).toLowerCase();
}

List<AppSelectOption<String>> clinicalCatalogSelectOptions(
  List<ClinicalActionCatalogOption> options, {
  IconData icon = Icons.medical_services_outlined,
  IconData Function(ClinicalActionCatalogOption option)? iconBuilder,
  Iterable<String?> Function(ClinicalActionCatalogOption option)?
  extraSearchValues,
  Widget Function(ClinicalActionCatalogOption option)? labelBuilder,
}) {
  return <AppSelectOption<String>>[
    for (final ClinicalActionCatalogOption option in options)
      AppSelectOption<String>(
        value: option.apiId,
        label: option.displayTitle,
        searchText: clinicalCatalogOptionSearchText(
          option,
          extra: extraSearchValues?.call(option) ?? const <String?>[],
        ),
        leadingIcon: Icon(iconBuilder?.call(option) ?? icon),
        labelWidget:
            labelBuilder?.call(option) ??
            ClinicalCatalogOptionLabel(option: option),
      ),
  ];
}

class ClinicalCatalogOptionLabel extends StatelessWidget {
  const ClinicalCatalogOptionLabel({
    required this.option,
    this.title,
    this.subtitle,
    super.key,
  });

  final ClinicalActionCatalogOption option;
  final String? title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String resolvedSubtitle =
        subtitle ??
        option.displaySubtitle ??
        clinicalActionJoinDisplay(<String?>[
          option.category,
          option.secondaryText,
          option.status,
        ]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          title ?? option.displayTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (resolvedSubtitle.isNotEmpty)
          Text(
            resolvedSubtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        Text(
          clinicalRequestCatalogPriceLabel(context, option),
          style: theme.textTheme.labelMedium?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Searchable catalog picker with optional add action.
class ClinicalCatalogSelectPanel extends StatelessWidget {
  const ClinicalCatalogSelectPanel({
    required this.title,
    required this.body,
    required this.labelText,
    required this.hintText,
    required this.options,
    required this.onChanged,
    required this.onSearchTextChanged,
    this.value,
    this.enabled = true,
    this.isLoading = false,
    this.isEditing = false,
    this.selectedIsDuplicate = false,
    this.duplicateMessage,
    this.addLabel,
    this.updateLabel,
    this.onAdd,
    this.menuHeight = 360,
    super.key,
  });

  final String title;
  final String body;
  final String labelText;
  final String hintText;
  final List<AppSelectOption<String>> options;
  final String? value;
  final bool enabled;
  final bool isLoading;
  final bool isEditing;
  final bool selectedIsDuplicate;
  final String? duplicateMessage;
  final String? addLabel;
  final String? updateLabel;
  final VoidCallback? onAdd;
  final ValueChanged<String?> onChanged;
  final ValueChanged<String> onSearchTextChanged;
  final double menuHeight;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String actionLabel = isEditing
        ? (updateLabel ?? l10n.clinicalLabRequestUpdateSelectionAction)
        : (addLabel ?? l10n.clinicalLabRequestAddSelectionAction);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(title, style: theme.textTheme.labelLarge),
            SizedBox(height: theme.spacing.xs),
            Text(
              body,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: theme.spacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: AppSelectField<String>.searchable(
                    value: value,
                    labelText: labelText,
                    hintText: hintText,
                    enabled: enabled,
                    isLoading: isLoading,
                    options: options,
                    menuHeight: menuHeight,
                    onChanged: onChanged,
                    onSearchTextChanged: onSearchTextChanged,
                  ),
                ),
                SizedBox(width: theme.spacing.sm),
                Padding(
                  padding: EdgeInsets.only(top: theme.spacing.xs),
                  child: AppButton.primary(
                    label: actionLabel,
                    leadingIcon: isEditing ? Icons.done_outlined : Icons.add,
                    enabled: enabled && !selectedIsDuplicate && onAdd != null,
                    onPressed: selectedIsDuplicate ? null : onAdd,
                  ),
                ),
              ],
            ),
            if (selectedIsDuplicate && duplicateMessage != null) ...<Widget>[
              SizedBox(height: theme.spacing.xs),
              Text(
                duplicateMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Manages a multi-item request selection via searchable select + actions.
class ClinicalRequestSelectionManager extends StatelessWidget {
  const ClinicalRequestSelectionManager({
    required this.title,
    required this.emptyLabel,
    required this.options,
    required this.value,
    required this.onChanged,
    required this.onEdit,
    required this.onDelete,
    this.enabled = true,
    this.detail,
    super.key,
  });

  final String title;
  final String emptyLabel;
  final List<AppSelectOption<String>> options;
  final String? value;
  final bool enabled;
  final Widget? detail;
  final ValueChanged<String?> onChanged;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              title,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: theme.spacing.sm),
            AppSelectField<String>.searchable(
              value: value,
              labelText: title,
              hintText: emptyLabel,
              enabled: enabled && options.isNotEmpty,
              options: options,
              menuHeight: 280,
              onChanged: onChanged,
            ),
            if (detail != null) ...<Widget>[
              SizedBox(height: theme.spacing.sm),
              detail!,
            ],
            if (value != null) ...<Widget>[
              SizedBox(height: theme.spacing.sm),
              Wrap(
                spacing: theme.spacing.sm,
                runSpacing: theme.spacing.sm,
                children: <Widget>[
                  if (onEdit != null)
                    AppButton.tertiary(
                      label: l10n.clinicalLabRequestEditSelectionAction,
                      leadingIcon: Icons.edit_outlined,
                      enabled: enabled,
                      onPressed: onEdit,
                    ),
                  if (onDelete != null)
                    AppButton.tertiary(
                      label: l10n.clinicalLabRequestDeleteSelectionAction,
                      leadingIcon: Icons.delete_outline,
                      enabled: enabled,
                      onPressed: onDelete,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
