import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/components/app_content_panel.dart';
import 'package:hosspi_hms/shared/components/app_info_tile.dart';
import 'package:hosspi_hms/shared/dashboard/dashboard_models.dart';
import 'package:hosspi_hms/shared/dashboard/dashboard_quick_actions.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

class DashboardPriorityPanel extends StatelessWidget {
  const DashboardPriorityPanel({required this.data, super.key});

  final DashboardPriorityPanelData data;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double gap = theme.spacing.md;
    final bool hasQueue = data.showQueue;
    final bool hasAlerts = data.showAlerts && data.alertsTitle != null;
    final bool hasShortcuts = data.showShortcuts && data.shortcuts.isNotEmpty;
    final bool hasQueueContent = hasQueue && data.queueItems.isNotEmpty;
    final bool hasAlertContent = hasAlerts && data.alertItems.isNotEmpty;
    final bool hasWorkContent = hasQueueContent || hasAlertContent;

    if (!hasQueue && !hasAlerts && !hasShortcuts) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wide = constraints.maxWidth >= 980;
        final Widget queuePanel = hasQueue
            ? _DashboardQueuePanel(
                title: data.queueTitle,
                items: data.queueItems,
                emptyMessage: data.emptyMessage,
                emptyActions: data.emptyActions,
                maxItems: data.maxQueueItems,
                viewAllLabel: data.viewAllLabel,
                onViewAll: data.onViewAll,
              )
            : const SizedBox.shrink();
        final Widget alertsPanel = hasAlerts
            ? _DashboardAlertsPanel(
                title: data.alertsTitle!,
                items: data.alertItems,
              )
            : const SizedBox.shrink();

        final Widget work = hasWorkContent
            ? (wide && hasQueueContent && hasAlertContent
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(flex: 3, child: queuePanel),
                        SizedBox(width: gap),
                        Expanded(flex: 2, child: alertsPanel),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        if (hasQueue) queuePanel,
                        if (hasQueue && hasAlerts) SizedBox(height: gap),
                        if (hasAlerts) alertsPanel,
                      ],
                    ))
            : (hasQueue
                  ? queuePanel
                  : hasAlerts
                  ? alertsPanel
                  : const SizedBox.shrink());

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            work,
            if (hasShortcuts) ...<Widget>[
              if (hasQueue || hasAlerts) SizedBox(height: gap),
              _DashboardShortcutsSection(
                shortcuts: data.shortcuts,
                maxTiles: data.maxShortcuts,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _DashboardQueuePanel extends StatelessWidget {
  const _DashboardQueuePanel({
    this.title,
    required this.items,
    required this.emptyMessage,
    required this.emptyActions,
    required this.maxItems,
    required this.viewAllLabel,
    this.onViewAll,
  });

  final String? title;
  final List<DashboardWorklistItemData> items;
  final String emptyMessage;
  final List<DashboardQuickActionData> emptyActions;
  final int maxItems;
  final String viewAllLabel;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    return AppSectionPanel(
      title: title,
      leadingIcon: Icons.format_list_bulleted,
      trailing: items.isEmpty || onViewAll == null
          ? null
          : AppButton.tertiary(
              label: viewAllLabel,
              leadingIcon: Icons.open_in_new,
              onPressed: onViewAll,
            ),
      children: <Widget>[
        if (items.isEmpty)
          _DashboardEmptyState(
            message: emptyMessage,
            actions: emptyActions,
          )
        else
          for (final DashboardWorklistItemData item in items.take(maxItems))
            _DashboardWorklistRow(item: item),
      ],
    );
  }
}

class _DashboardAlertsPanel extends StatelessWidget {
  const _DashboardAlertsPanel({required this.title, required this.items});

  final String title;
  final List<DashboardWorklistItemData> items;

  @override
  Widget build(BuildContext context) {
    return AppSectionPanel(
      title: title,
      leadingIcon: Icons.warning_amber_outlined,
      children: <Widget>[
        if (items.isEmpty)
          const _DashboardQuietState()
        else
          for (final DashboardWorklistItemData item in items.take(3))
            _DashboardWorklistRow(item: item),
      ],
    );
  }
}

class _DashboardShortcutsSection extends StatelessWidget {
  const _DashboardShortcutsSection({
    required this.shortcuts,
    required this.maxTiles,
  });

  final List<DashboardShortcutData> shortcuts;
  final int maxTiles;

  @override
  Widget build(BuildContext context) {
    return AppResponsiveWrap(
      children: <Widget>[
        for (final DashboardShortcutData shortcut in shortcuts.take(maxTiles))
          _DashboardShortcutTile(shortcut: shortcut),
      ],
    );
  }
}

class _DashboardWorklistRow extends StatelessWidget {
  const _DashboardWorklistRow({required this.item});

  final DashboardWorklistItemData item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Widget row = Padding(
      padding: EdgeInsets.symmetric(vertical: theme.spacing.xs),
      child: Row(
        children: <Widget>[
          Icon(
            item.icon,
            size: theme.appTokens.listIconSize,
            color: colorScheme.primary,
          ),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: item.subtitle.isEmpty
                ? Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  )
                : Text.rich(
                    TextSpan(
                      children: <InlineSpan>[
                        TextSpan(
                          text: item.title,
                          style: theme.textTheme.titleSmall,
                        ),
                        TextSpan(
                          text: ' · ${item.subtitle}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
          if (item.status != null) ...<Widget>[
            SizedBox(width: theme.spacing.sm),
            AppWorkspaceStatusBadge(status: item.status!),
          ],
        ],
      ),
    );

    if (item.onTap == null) {
      return row;
    }

    return InkWell(onTap: item.onTap, child: row);
  }
}

class _DashboardShortcutTile extends StatelessWidget {
  const _DashboardShortcutTile({required this.shortcut});

  final DashboardShortcutData shortcut;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return InkWell(
      onTap: shortcut.onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outlineVariant),
          color: colorScheme.surfaceContainerLowest,
        ),
        child: Padding(
          padding: EdgeInsets.all(theme.spacing.md),
          child: Row(
            children: <Widget>[
              Icon(
                shortcut.icon,
                size: theme.appTokens.listIconSize,
                color: colorScheme.primary,
              ),
              SizedBox(width: theme.spacing.sm),
              Expanded(
                child: Text(
                  shortcut.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              SizedBox(width: theme.spacing.xs),
              Icon(
                Icons.chevron_right,
                size: theme.appTokens.listIconSize,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardEmptyState extends StatelessWidget {
  const _DashboardEmptyState({required this.message, required this.actions});

  final String message;
  final List<DashboardQuickActionData> actions;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Semantics(
      label: message,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (actions.isNotEmpty) ...<Widget>[
            SizedBox(height: theme.spacing.sm),
            DashboardQuickActions(actions: actions),
          ],
        ],
      ),
    );
  }
}

class _DashboardQuietState extends StatelessWidget {
  const _DashboardQuietState();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Icon(
      Icons.check_circle_outline,
      size: 24,
      color: theme.colorScheme.onSurfaceVariant,
    );
  }
}
