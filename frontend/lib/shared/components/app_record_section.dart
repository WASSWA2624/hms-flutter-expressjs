import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/shared/components/app_icon_button.dart';
import 'package:hosspi_hms/shared/components/app_list_item_text.dart';

typedef AppRecordTextBuilder<T> = String Function(T item);
typedef AppRecordWidgetBuilder<T> =
    Widget Function(BuildContext context, T item);

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
    this.initiallyExpanded = false,
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

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.only(bottom: theme.spacing.sm),
      initiallyExpanded: initiallyExpanded,
      title: Text(title, style: theme.textTheme.titleSmall),
      trailing: _addButton(context),
      children: <Widget>[
        if (visibleItems.isEmpty)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Padding(
              padding: EdgeInsets.only(bottom: theme.spacing.xs),
              child: Text(
                emptyLabel,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          for (final T item in visibleItems)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: _itemLeading(context, item),
              title: AppListItemText(
                title: itemTitle(item),
                subtitle: itemSubtitle?.call(item),
              ),
              trailing: _itemActions(context, item),
            ),
      ],
    );
  }

  Widget? _addButton(BuildContext context) {
    final VoidCallback? handler = onAdd;
    if (handler == null) {
      return null;
    }

    return _GuardedIconAction(
      icon: Icons.add,
      label: addLabel ?? 'Add',
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
        _GuardedIconAction(
          icon: Icons.edit_outlined,
          label: editLabel ?? 'Edit',
          requirement: editRequirement,
          onPressed: () => onEdit!(item),
        ),
      if (onDelete != null)
        _GuardedIconAction(
          icon: Icons.delete_outline,
          label: deleteLabel ?? 'Delete',
          requirement: deleteRequirement,
          onPressed: () => onDelete!(item),
        ),
    ];

    if (actions.isEmpty) {
      return null;
    }

    return Wrap(children: actions);
  }
}

class _GuardedIconAction extends StatelessWidget {
  const _GuardedIconAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.requirement,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final AccessRequirement? requirement;

  @override
  Widget build(BuildContext context) {
    final AccessRequirement? resolvedRequirement = requirement;
    if (resolvedRequirement == null) {
      return AppIconButton(
        icon: icon,
        semanticLabel: label,
        tooltip: label,
        onPressed: onPressed,
      );
    }

    return AppAccessActionGate(
      requirement: resolvedRequirement,
      builder: (_, bool isAllowed) => AppIconButton(
        icon: icon,
        semanticLabel: label,
        tooltip: label,
        onPressed: isAllowed ? onPressed : null,
      ),
    );
  }
}
