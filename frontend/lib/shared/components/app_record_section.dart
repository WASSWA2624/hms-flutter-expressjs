import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/components/app_list_item_text.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

typedef AppRecordTextBuilder<T> = String Function(T item);
typedef AppRecordWidgetBuilder<T> =
    Widget Function(BuildContext context, T item);

enum AppRecordActionVariant { add, edit, delete }

/// CRUD record list section for detail dialogs.
///
/// Uses [AppCollapsibleSection] chrome so patient and other detail modals
/// share the same collapsible section component as the rest of the app.
class AppExpandableRecordSection<T> extends StatelessWidget {
  const AppExpandableRecordSection({
    required this.title,
    required this.emptyLabel,
    required this.items,
    required this.itemTitle,
    this.itemSubtitle,
    this.itemLeadingIcon,
    this.itemLeadingBuilder,
    this.maxItems,
    this.initiallyExpanded = true,
    this.responsiveActionButtons = false,
    this.onAdd,
    this.onEdit,
    this.onDelete,
    this.addLabel,
    this.editLabel,
    this.deleteLabel,
    this.addRequirement,
    this.editRequirement,
    this.deleteRequirement,
    super.key,
  });

  final String title;
  final String emptyLabel;
  final List<T> items;
  final AppRecordTextBuilder<T> itemTitle;
  final AppRecordTextBuilder<T>? itemSubtitle;
  final IconData? itemLeadingIcon;
  final AppRecordWidgetBuilder<T>? itemLeadingBuilder;
  final int? maxItems;
  final bool initiallyExpanded;
  final bool responsiveActionButtons;
  final VoidCallback? onAdd;
  final ValueChanged<T>? onEdit;
  final ValueChanged<T>? onDelete;
  final String? addLabel;
  final String? editLabel;
  final String? deleteLabel;
  final AccessRequirement? addRequirement;
  final AccessRequirement? editRequirement;
  final AccessRequirement? deleteRequirement;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<T> visibleItems = maxItems == null
        ? items
        : items.take(maxItems!).toList(growable: false);
    final Widget? addButton = _addButton(context);

    return AppCollapsibleSection(
      title: title,
      initiallyExpanded: initiallyExpanded,
      actions: addButton == null ? const <Widget>[] : <Widget>[addButton],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (visibleItems.isEmpty)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                emptyLabel,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            for (var index = 0; index < visibleItems.length; index += 1) ...<
              Widget
            >[
              if (index > 0) const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: _itemLeading(context, visibleItems[index]),
                title: _itemTitle(context, visibleItems[index]),
                trailing: _itemActions(context, visibleItems[index]),
              ),
            ],
        ],
      ),
    );
  }

  Widget _itemTitle(BuildContext context, T item) {
    final String? subtitle = itemSubtitle?.call(item);
    if (subtitle == null || subtitle.trim().isEmpty) {
      return Text(
        itemTitle(item),
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    return AppListItemText(title: itemTitle(item), subtitle: subtitle);
  }

  Widget? _addButton(BuildContext context) {
    final VoidCallback? handler = onAdd;
    if (handler == null) {
      return null;
    }

    return _GuardedRecordAction(
      icon: Icons.add,
      label: addLabel ?? 'Add',
      variant: AppRecordActionVariant.add,
      responsive: responsiveActionButtons,
      requirement: addRequirement,
      onPressed: handler,
    );
  }

  Widget? _itemLeading(BuildContext context, T item) {
    final AppRecordWidgetBuilder<T>? builder = itemLeadingBuilder;
    if (builder != null) {
      return builder(context, item);
    }

    final IconData? icon = itemLeadingIcon;
    if (icon == null) {
      return null;
    }

    final ThemeData theme = Theme.of(context);
    return Icon(
      icon,
      color: theme.colorScheme.primary,
      size: theme.appTokens.listIconSize,
    );
  }

  Widget? _itemActions(BuildContext context, T item) {
    final List<Widget> actions = <Widget>[
      if (onEdit != null)
        _GuardedRecordAction(
          icon: Icons.edit_outlined,
          label: editLabel ?? 'Edit',
          variant: AppRecordActionVariant.edit,
          responsive: responsiveActionButtons,
          requirement: editRequirement,
          onPressed: () => onEdit!(item),
        ),
      if (onDelete != null)
        _GuardedRecordAction(
          icon: Icons.delete_outline,
          label: deleteLabel ?? 'Delete',
          variant: AppRecordActionVariant.delete,
          responsive: responsiveActionButtons,
          requirement: deleteRequirement,
          onPressed: () => onDelete!(item),
        ),
    ];

    if (actions.isEmpty) {
      return null;
    }

    return Wrap(spacing: Theme.of(context).spacing.xs, children: actions);
  }
}

class _GuardedRecordAction extends StatelessWidget {
  const _GuardedRecordAction({
    required this.icon,
    required this.label,
    required this.variant,
    required this.onPressed,
    this.responsive = false,
    this.requirement,
  });

  final IconData icon;
  final String label;
  final AppRecordActionVariant variant;
  final VoidCallback onPressed;
  final bool responsive;
  final AccessRequirement? requirement;

  @override
  Widget build(BuildContext context) {
    final bool compact = !responsive || AppBreakpoints.of(context).isMobile;
    final AccessRequirement? resolvedRequirement = requirement;
    if (resolvedRequirement == null) {
      return _buildButton(context, iconOnly: compact);
    }

    return AppAccessActionGate(
      requirement: resolvedRequirement,
      builder: (_, bool isAllowed) =>
          _buildButton(context, iconOnly: compact, enabled: isAllowed),
    );
  }

  Widget _buildButton(
    BuildContext context, {
    required bool iconOnly,
    bool enabled = true,
  }) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final VoidCallback? handler = enabled ? onPressed : null;

    switch (variant) {
      case AppRecordActionVariant.add:
        return AppButton.primary(
          iconOnly: iconOnly,
          dense: true,
          leadingIcon: icon,
          label: label,
          semanticLabel: label,
          tooltip: label,
          onPressed: handler,
        );
      case AppRecordActionVariant.edit:
        return AppButton.secondary(
          iconOnly: iconOnly,
          dense: true,
          leadingIcon: icon,
          label: label,
          semanticLabel: label,
          tooltip: label,
          onPressed: handler,
        );
      case AppRecordActionVariant.delete:
        return AppButton.tertiary(
          iconOnly: iconOnly,
          dense: true,
          leadingIcon: icon,
          label: label,
          semanticLabel: label,
          tooltip: label,
          color: colorScheme.error,
          onPressed: handler,
        );
    }
  }
}
