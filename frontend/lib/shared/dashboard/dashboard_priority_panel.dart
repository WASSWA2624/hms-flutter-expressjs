import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/components/app_content_panel.dart';
import 'package:hosspi_hms/shared/dashboard/dashboard_models.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

class DashboardPriorityPanel extends StatelessWidget {
  const DashboardPriorityPanel({required this.data, super.key});

  final DashboardPriorityPanelData data;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double gap = theme.spacing.lg;
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
                title: data.shortcutsTitle,
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
      density: AppContentPanelDensity.spacious,
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
      density: AppContentPanelDensity.spacious,
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
    required this.title,
    required this.shortcuts,
    required this.maxTiles,
  });

  final String title;
  final List<DashboardShortcutData> shortcuts;
  final int maxTiles;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double gap = theme.spacing.sm;

    return AppSectionPanel(
      title: title,
      leadingIcon: Icons.link_rounded,
      density: AppContentPanelDensity.spacious,
      children: <Widget>[
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool wide = constraints.maxWidth >= 640;
            final int columns = wide ? math.min(3, shortcuts.length) : 1;
            final double tileWidth = columns <= 1
                ? constraints.maxWidth
                : (constraints.maxWidth - (gap * (columns - 1))) / columns;
            final List<DashboardShortcutData> visible = shortcuts
                .take(maxTiles)
                .toList(growable: false);

            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: <Widget>[
                for (final DashboardShortcutData shortcut in visible)
                  SizedBox(
                    width: columns <= 1 ? constraints.maxWidth : tileWidth,
                    child: _DashboardShortcutTile(shortcut: shortcut),
                  ),
              ],
            );
          },
        ),
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
    final _WorklistTitleParts parts = _parseWorklistTitle(item.title);
    final String detailLine = _worklistDetailLine(
      reference: parts.reference,
      subtitle: item.subtitle,
    );

    final Widget row = Padding(
      padding: EdgeInsets.symmetric(vertical: theme.spacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.only(top: theme.spacing.xs / 2),
            child: Icon(
              item.icon,
              size: theme.appTokens.listIconSize,
              color: colorScheme.primary,
            ),
          ),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  parts.headline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (detailLine.isNotEmpty) ...<Widget>[
                  SizedBox(height: theme.spacing.xs / 2),
                  Text(
                    detailLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
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

    return InkWell(onTap: item.onTap, borderRadius: BorderRadius.circular(theme.radius.md), child: row);
  }
}

class _DashboardShortcutTile extends StatelessWidget {
  const _DashboardShortcutTile({required this.shortcut});

  final DashboardShortcutData shortcut;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(theme.radius.lg),
      child: InkWell(
        onTap: shortcut.onTap,
        borderRadius: BorderRadius.circular(theme.radius.lg),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(theme.radius.lg),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.7),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: theme.spacing.md,
              vertical: theme.spacing.md,
            ),
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
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: theme.appTokens.listIconSize,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
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
    final DashboardQuickActionData? primaryAction =
        actions.isNotEmpty ? actions.first : null;

    return Semantics(
      label: message,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: theme.spacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.dashboard_customize_outlined,
              size: 32,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            SizedBox(height: theme.spacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (primaryAction != null) ...<Widget>[
              SizedBox(height: theme.spacing.md),
              AppButton.primary(
                label: primaryAction.label,
                leadingIcon: primaryAction.icon,
                onPressed: primaryAction.onPressed,
                semanticLabel: primaryAction.semanticsLabel,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DashboardQuietState extends StatelessWidget {
  const _DashboardQuietState();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: theme.spacing.sm),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.check_circle_outline,
            size: 24,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          SizedBox(width: theme.spacing.sm),
          Text(
            'All clear',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

@immutable
final class _WorklistTitleParts {
  const _WorklistTitleParts({required this.headline, this.reference});

  final String headline;
  final String? reference;
}

_WorklistTitleParts _parseWorklistTitle(String title) {
  final List<String> parts = title
      .trim()
      .split(RegExp(r'\s+'))
      .where((String part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.length < 2) {
    return _WorklistTitleParts(headline: title);
  }

  for (int index = 1; index < parts.length; index += 1) {
    if (_looksLikeReference(parts[index])) {
      return _WorklistTitleParts(
        headline: parts.sublist(0, index).join(' '),
        reference: parts.sublist(index).join(' '),
      );
    }
  }

  return _WorklistTitleParts(headline: title);
}

bool _looksLikeReference(String token) {
  return RegExp(r'^[A-Z]{2,5}-[A-Z0-9]+$').hasMatch(token);
}

String _worklistDetailLine({
  required String? reference,
  required String subtitle,
}) {
  final String trimmedSubtitle = subtitle.trim();
  if (reference != null && reference.isNotEmpty) {
    if (trimmedSubtitle.isEmpty) {
      return reference;
    }
    return '$reference · $trimmedSubtitle';
  }
  return trimmedSubtitle;
}
