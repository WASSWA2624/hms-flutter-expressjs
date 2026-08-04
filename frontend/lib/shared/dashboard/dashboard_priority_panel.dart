import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/shared/actions/actions.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/components/app_content_panel.dart';
import 'package:hosspi_hms/shared/dashboard/dashboard_layout.dart';
import 'package:hosspi_hms/shared/dashboard/dashboard_models.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

class DashboardPriorityPanel extends StatelessWidget {
  const DashboardPriorityPanel({required this.data, super.key});

  final DashboardPriorityPanelData data;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double gap = theme.spacing.lg;
    final bool hasQueueContent = data.showQueue && data.queueItems.isNotEmpty;
    final bool hasQueueEmptySurface = data.showQueue &&
        data.queueItems.isEmpty &&
        (data.emptyActions.isNotEmpty || data.emptyMessage.isNotEmpty);
    final bool hasQueue = hasQueueContent || hasQueueEmptySurface;
    // Collapse quiet "All clear" / "Nothing pending" chrome — only real items.
    final bool hasAlerts =
        data.showAlerts &&
        data.alertsTitle != null &&
        data.alertItems.isNotEmpty;
    final bool hasResults =
        data.showResults &&
        data.resultsTitle != null &&
        data.resultsItems.isNotEmpty;
    final bool hasFollowUps =
        data.showFollowUps &&
        data.followUpTitle != null &&
        data.followUpItems.isNotEmpty;
    final bool hasShortcuts = data.showShortcuts && data.shortcuts.isNotEmpty;
    final bool hasAlertContent = hasAlerts;

    if (!hasQueue &&
        !hasAlerts &&
        !hasResults &&
        !hasFollowUps &&
        !hasShortcuts) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wide = constraints.maxWidth >= 980;
        final Widget queuePanel = hasQueue
            ? _DashboardQueuePanel(
                title: data.queueTitle,
                items: data.queueItems,
                emptySectionTitle: data.emptySectionTitle,
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
        final Widget resultsPanel = hasResults
            ? _DashboardSecondaryQueuePanel(
                title: data.resultsTitle!,
                icon: Icons.biotech_outlined,
                items: data.resultsItems,
                maxItems: data.maxResultsItems,
                viewAllLabel: data.viewAllLabel,
                onViewAll: data.onViewAllResults,
              )
            : const SizedBox.shrink();
        final Widget followUpPanel = hasFollowUps
            ? _DashboardSecondaryQueuePanel(
                title: data.followUpTitle!,
                icon: Icons.event_repeat_outlined,
                items: data.followUpItems,
                maxItems: data.maxFollowUpItems,
                viewAllLabel: data.viewAllLabel,
                onViewAll: data.onViewAllFollowUps,
              )
            : const SizedBox.shrink();

        final Widget work =
            hasWorkContent(
              hasQueueContent: hasQueueContent,
              hasAlertContent: hasAlertContent,
            )
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
                        if (hasAlerts && !hasQueueContent) ...<Widget>[
                          alertsPanel,
                          if (hasQueue) SizedBox(height: gap),
                        ],
                        if (hasQueue) queuePanel,
                        if (hasQueue && hasAlerts && hasQueueContent)
                          SizedBox(height: gap),
                        if (hasAlerts && hasQueueContent) alertsPanel,
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
            if (hasResults) ...<Widget>[
              if (hasWorkContent(
                    hasQueueContent: hasQueueContent,
                    hasAlertContent: hasAlertContent,
                  ) ||
                  (hasQueue && !hasQueueContent) ||
                  (hasAlerts && !hasAlertContent))
                SizedBox(height: gap),
              resultsPanel,
            ],
            if (hasFollowUps) ...<Widget>[
              if (hasResults ||
                  hasWorkContent(
                    hasQueueContent: hasQueueContent,
                    hasAlertContent: hasAlertContent,
                  ))
                SizedBox(height: gap),
              followUpPanel,
            ],
            if (hasShortcuts) ...<Widget>[
              if (hasQueue || hasAlerts || hasResults || hasFollowUps)
                SizedBox(height: gap),
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

  bool hasWorkContent({
    required bool hasQueueContent,
    required bool hasAlertContent,
  }) {
    return hasQueueContent || hasAlertContent;
  }
}

class DashboardAlertsPanel extends StatelessWidget {
  const DashboardAlertsPanel({required this.data, super.key});

  final DashboardPriorityPanelData data;

  @override
  Widget build(BuildContext context) {
    if (!data.showAlerts || data.alertsTitle == null) {
      return const SizedBox.shrink();
    }

    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: dashboardAlertsPanelDecoration(theme, colorScheme),
      child: _DashboardAlertsPanelContent(
        title: data.alertsTitle!,
        items: data.alertItems,
      ),
    );
  }
}

class _DashboardSectionShell extends StatelessWidget {
  const _DashboardSectionShell({required this.child, this.decoration});

  final Widget child;
  final BoxDecoration? decoration;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration:
          decoration ?? dashboardSurfaceCardDecoration(theme, colorScheme),
      child: child,
    );
  }
}

class _DashboardQueuePanel extends StatelessWidget {
  const _DashboardQueuePanel({
    this.title,
    this.emptySectionTitle,
    required this.items,
    required this.emptyMessage,
    required this.emptyActions,
    required this.maxItems,
    required this.viewAllLabel,
    this.onViewAll,
  });

  final String? title;
  final String? emptySectionTitle;
  final List<DashboardWorklistItemData> items;
  final String emptyMessage;
  final List<DashboardQuickActionData> emptyActions;
  final int maxItems;
  final String viewAllLabel;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final bool isEmpty = items.isEmpty;
    final bool hasEmptyActions = emptyActions.isNotEmpty;
    final bool hasEmptyMessage = emptyMessage.isNotEmpty;

    // Never leave a blank header with zero content.
    if (isEmpty && !hasEmptyActions && !hasEmptyMessage) {
      return const SizedBox.shrink();
    }

    final String? panelTitle = isEmpty ? (emptySectionTitle ?? title) : title;
    final String? panelDescription = isEmpty && hasEmptyMessage
        ? emptyMessage
        : null;

    return _DashboardSectionShell(
      child: AppSectionPanel(
        title: panelTitle,
        description: isEmpty ? panelDescription : null,
        leadingIcon: Icons.format_list_bulleted,
        density: AppContentPanelDensity.spacious,
        backgroundColor: Colors.transparent,
        borderColor: Colors.transparent,
        trailing: isEmpty || onViewAll == null
            ? null
            : AppButton.tertiary(
                label: viewAllLabel,
                leadingIcon: Icons.open_in_new,
                onPressed: onViewAll,
              ),
        children: <Widget>[
          if (isEmpty && hasEmptyActions)
            _DashboardEmptyState(actions: emptyActions),
          if (!isEmpty)
            _DashboardWorklistGroup(items: items.take(maxItems).toList()),
        ],
      ),
    );
  }
}

class _DashboardSecondaryQueuePanel extends StatelessWidget {
  const _DashboardSecondaryQueuePanel({
    required this.title,
    required this.icon,
    required this.items,
    required this.maxItems,
    required this.viewAllLabel,
    this.onViewAll,
  });

  final String title;
  final IconData icon;
  final List<DashboardWorklistItemData> items;
  final int maxItems;
  final String viewAllLabel;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return _DashboardSectionShell(
      child: AppSectionPanel(
        title: title,
        leadingIcon: icon,
        density: AppContentPanelDensity.spacious,
        backgroundColor: Colors.transparent,
        borderColor: Colors.transparent,
        trailing: onViewAll == null
            ? null
            : AppButton.tertiary(
                label: viewAllLabel,
                leadingIcon: Icons.open_in_new,
                onPressed: onViewAll,
              ),
        children: <Widget>[
          _DashboardWorklistGroup(items: items.take(maxItems).toList()),
        ],
      ),
    );
  }
}

class _DashboardAlertsPanel extends StatelessWidget {
  const _DashboardAlertsPanel({required this.title, required this.items});

  final String title;
  final List<DashboardWorklistItemData> items;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return _DashboardSectionShell(
      decoration: dashboardAlertsPanelDecoration(theme, colorScheme),
      child: AppSectionPanel(
        title: title,
        leadingIcon: Icons.warning_amber_rounded,
        density: AppContentPanelDensity.spacious,
        backgroundColor: Colors.transparent,
        borderColor: Colors.transparent,
        children: <Widget>[
          if (items.isEmpty)
            const _DashboardQuietState()
          else
            _DashboardWorklistGroup(items: items.take(3).toList()),
        ],
      ),
    );
  }
}

class _DashboardAlertsPanelContent extends StatelessWidget {
  const _DashboardAlertsPanelContent({
    required this.title,
    required this.items,
  });

  final String title;
  final List<DashboardWorklistItemData> items;

  @override
  Widget build(BuildContext context) {
    return AppSectionPanel(
      title: title,
      leadingIcon: Icons.warning_amber_rounded,
      density: AppContentPanelDensity.spacious,
      backgroundColor: Colors.transparent,
      borderColor: Colors.transparent,
      children: <Widget>[
        if (items.isEmpty)
          const _DashboardQuietState()
        else
          _DashboardWorklistGroup(items: items.take(3).toList()),
      ],
    );
  }
}

class _DashboardWorklistGroup extends StatelessWidget {
  const _DashboardWorklistGroup({required this.items});

  final List<DashboardWorklistItemData> items;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: dashboardWorklistGroupDecoration(theme, colorScheme),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(theme.radius.lg),
        child: Column(
          children: <Widget>[
            for (int index = 0; index < items.length; index += 1) ...<Widget>[
              if (index > 0)
                Divider(
                  height: 1,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.25),
                ),
              _DashboardWorklistRow(item: items[index]),
            ],
          ],
        ),
      ),
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

    return _DashboardSectionShell(
      child: AppSectionPanel(
        title: title,
        leadingIcon: Icons.link_rounded,
        density: AppContentPanelDensity.spacious,
        backgroundColor: Colors.transparent,
        borderColor: Colors.transparent,
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
      ),
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
    final TextStyle? headlineStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
    );
    final TextStyle? detailStyle = theme.textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );

    final Widget row = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.md,
        vertical: theme.spacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: dashboardAccentIconDecoration(
              theme,
              colorScheme.primary,
            ),
            child: Icon(item.icon, size: 18, color: colorScheme.primary),
          ),
          SizedBox(width: theme.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  parts.headline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: headlineStyle,
                ),
                if (detailLine.isNotEmpty)
                  Text(
                    detailLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: detailStyle,
                  ),
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        hoverColor: colorScheme.primary.withValues(alpha: 0.04),
        child: row,
      ),
    );
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
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(theme.radius.lg),
            border: theme.borders.all(color: colorScheme.outlineVariant.withValues(alpha: 0.35)),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: theme.spacing.md,
              vertical: theme.spacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: dashboardAccentIconDecoration(
                    theme,
                    colorScheme.primary,
                  ),
                  child: Icon(
                    shortcut.icon,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                ),
                SizedBox(height: theme.spacing.sm),
                Text(
                  shortcut.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
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
  const _DashboardEmptyState({required this.actions});

  final List<DashboardQuickActionData> actions;

  @override
  Widget build(BuildContext context) {
    return AppQuickActions(
      presentation: AppQuickActionsPresentation.buttonsOnly,
      actions: <AppActionItem>[
        for (final DashboardQuickActionData action in actions.take(5))
          AppActionItem(
            label: action.label,
            leadingIcon: action.icon,
            semanticLabel: action.semanticsLabel,
            onPressed: action.onPressed,
          ),
      ],
    );
  }
}

class _DashboardQuietState extends StatelessWidget {
  const _DashboardQuietState({this.message = 'All clear'});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Color successColor = theme.statusColors.success;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.md,
        vertical: theme.spacing.md,
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: successColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_rounded, size: 20, color: successColor),
          ),
          SizedBox(width: theme.spacing.md),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w400,
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
