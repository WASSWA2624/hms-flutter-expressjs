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

    if (!hasQueue && !hasAlerts && !hasResults && !hasFollowUps) {
      return const SizedBox.shrink();
    }

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
        ? DashboardAlertsStrip(items: data.alertItems)
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

    // The alerts strip is a single compact line - it always leads, full width,
    // instead of competing with the queue for a column.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (hasAlerts) alertsPanel,
        if (hasAlerts && hasQueue) SizedBox(height: gap),
        if (hasQueue) queuePanel,
        if (hasResults) ...<Widget>[
          if (hasAlerts || hasQueue) SizedBox(height: gap),
          resultsPanel,
        ],
        if (hasFollowUps) ...<Widget>[
          if (hasAlerts || hasQueue || hasResults) SizedBox(height: gap),
          followUpPanel,
        ],
      ],
    );
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
    return DashboardAlertsStrip(items: data.alertItems);
  }
}

/// Dashboard alerts as one compact line of square-edged severity tags:
/// `icon  Label (count)`, the count tinted by severity. Deliberately
/// card-free and radius-free - alerts sit inline above the dashboard body
/// and must not spend vertical space on panel chrome.
class DashboardAlertsStrip extends StatelessWidget {
  const DashboardAlertsStrip({required this.items, super.key});

  final List<DashboardWorklistItemData> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    final ThemeData theme = Theme.of(context);
    return Wrap(
      spacing: theme.spacing.sm,
      runSpacing: theme.spacing.xs,
      children: <Widget>[
        for (final DashboardWorklistItemData item in items)
          _DashboardAlertChip(item: item),
      ],
    );
  }
}

class _DashboardAlertChip extends StatelessWidget {
  const _DashboardAlertChip({required this.item});

  final DashboardWorklistItemData item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppWorkspaceStatusTone tone =
        item.status?.tone ?? AppWorkspaceStatusTone.warning;
    final Color accent = dashboardToneAccent(theme, tone);
    final String label = item.title.trim();
    final String? count = _alertCountLabel(item.subtitle);
    final String severityLabel = item.status?.label.trim() ?? '';
    final TextStyle? labelStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurface,
      letterSpacing: 0.1,
      height: 1.2,
    );

    // Square edges: a hairline rule with one weighted severity edge, so the
    // tag reads as a rule of text rather than a chip.
    final Border border = Border(
      left: theme.borders.side(color: accent, width: 2),
      top: theme.borders.side(color: accent.withValues(alpha: 0.24)),
      right: theme.borders.side(color: accent.withValues(alpha: 0.24)),
      bottom: theme.borders.side(color: accent.withValues(alpha: 0.24)),
    );

    final Widget content = Padding(
      padding: EdgeInsets.fromLTRB(
        theme.spacing.sm,
        theme.spacing.xs,
        theme.spacing.sm,
        theme.spacing.xs,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(_alertToneIcon(tone), size: 15, color: accent),
          SizedBox(width: theme.spacing.sm),
          Flexible(
            child: Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(text: label),
                  if (count != null)
                    TextSpan(
                      text: ' ($count)',
                      style: TextStyle(
                        color: accent,
                        fontWeight: AppFontWeight.emphasis,
                      ),
                    ),
                ],
              ),
              style: labelStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    return Semantics(
      button: item.onTap != null,
      label: <String>[
        if (severityLabel.isNotEmpty) severityLabel,
        label,
        ?count,
      ].join(', '),
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(border: border),
        child: item.onTap == null
            ? content
            : Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: item.onTap,
                  hoverColor: accent.withValues(alpha: 0.06),
                  child: content,
                ),
              ),
      ),
    );
  }
}

/// Alert rows carry their count in [DashboardWorklistItemData.subtitle].
String? _alertCountLabel(String subtitle) {
  final String value = subtitle.trim();
  return value.isEmpty ? null : value;
}

IconData _alertToneIcon(AppWorkspaceStatusTone tone) {
  return switch (tone) {
    AppWorkspaceStatusTone.error => Icons.error_outline,
    AppWorkspaceStatusTone.warning => Icons.warning_amber_rounded,
    AppWorkspaceStatusTone.success => Icons.check_circle_outline,
    AppWorkspaceStatusTone.info => Icons.info_outline,
    AppWorkspaceStatusTone.neutral => Icons.circle_notifications_outlined,
  };
}

class _DashboardSectionShell extends StatelessWidget {
  const _DashboardSectionShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: dashboardSurfaceCardDecoration(theme, colorScheme),
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
                  color: theme.borders.faint,
                ),
              _DashboardWorklistRow(item: items[index]),
            ],
          ],
        ),
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
      fontWeight: AppFontWeight.emphasis,
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
