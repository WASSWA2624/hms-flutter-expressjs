import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/shared/components/app_state_view.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

/// Chronological clinical/ops timeline item (presentation-only).
@immutable
final class AppTimelineItem {
  const AppTimelineItem({
    required this.title,
    this.occurredAt,
    this.subtitle,
    this.description,
    this.icon,
    this.tone = AppWorkspaceStatusTone.neutral,
    this.id,
  });

  final Object? id;
  final String title;
  final DateTime? occurredAt;
  final String? subtitle;
  final String? description;
  final IconData? icon;
  final AppWorkspaceStatusTone tone;

  AppWorkspaceActivityItem toActivityItem({
    required String Function(DateTime value) formatOccurredAt,
    String missingTimestampLabel = '',
  }) {
    final String resolvedSubtitle =
        subtitle ??
        (occurredAt == null
            ? missingTimestampLabel
            : formatOccurredAt(occurredAt!));
    return AppWorkspaceActivityItem(
      title: title,
      subtitle: resolvedSubtitle,
      description: description,
      icon: icon,
      tone: tone,
    );
  }
}

/// Vertical chronological timeline with non-color status cues.
///
/// Callers supply typed items and localized empty-state copy. Sorting is by
/// [AppTimelineItem.occurredAt] descending when [sortDescending] is true.
class AppTimeline extends StatelessWidget {
  const AppTimeline({
    required this.items,
    this.title,
    this.description,
    this.emptyTitle,
    this.emptyBody,
    this.emptyAction,
    this.emptyIcon = Icons.timeline_outlined,
    this.sortDescending = true,
    this.maxItems,
    this.missingTimestampLabel = '',
    this.dense = false,
    this.asActivityList = false,
    super.key,
  });

  final List<AppTimelineItem> items;
  final String? title;
  final String? description;
  final String? emptyTitle;
  final String? emptyBody;
  final Widget? emptyAction;
  final IconData emptyIcon;
  final bool sortDescending;
  final int? maxItems;
  final String missingTimestampLabel;
  final bool dense;
  final bool asActivityList;

  @override
  Widget build(BuildContext context) {
    final List<AppTimelineItem> ordered = _orderedItems();
    if (asActivityList) {
      final Locale locale = Localizations.localeOf(context);
      return AppWorkspaceActivityList(
        title: title,
        description: description,
        emptyTitle: emptyTitle,
        emptyBody: emptyBody,
        emptyAction: emptyAction,
        items: <AppWorkspaceActivityItem>[
          for (final AppTimelineItem item in ordered)
            item.toActivityItem(
              formatOccurredAt: (DateTime value) =>
                  AppFormatters.dateTime(value, locale),
              missingTimestampLabel: missingTimestampLabel,
            ),
        ],
      );
    }

    final String? resolvedTitle = title?.trim().isNotEmpty == true
        ? title
        : null;
    final Widget body = ordered.isEmpty
        ? AppStateView(
            variant: AppStateViewVariant.empty,
            title: emptyTitle ?? '',
            body: emptyBody ?? '',
            icon: emptyIcon,
            action: emptyAction,
            crossAxisAlignment: CrossAxisAlignment.center,
            textAlign: TextAlign.center,
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (var index = 0; index < ordered.length; index += 1)
                _TimelineNode(
                  item: ordered[index],
                  isLast: index == ordered.length - 1,
                  dense: dense,
                  missingTimestampLabel: missingTimestampLabel,
                ),
            ],
          );

    if (resolvedTitle != null) {
      return AppCollapsibleSection(
        title: resolvedTitle,
        description: description,
        child: body,
      );
    }

    return body;
  }

  List<AppTimelineItem> _orderedItems() {
    final List<AppTimelineItem> copy = List<AppTimelineItem>.of(items);
    copy.sort((AppTimelineItem a, AppTimelineItem b) {
      final DateTime left =
          a.occurredAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final DateTime right =
          b.occurredAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return sortDescending ? right.compareTo(left) : left.compareTo(right);
    });
    if (maxItems != null && copy.length > maxItems!) {
      return copy.take(maxItems!).toList(growable: false);
    }
    return copy;
  }
}

class _TimelineNode extends StatelessWidget {
  const _TimelineNode({
    required this.item,
    required this.isLast,
    required this.dense,
    required this.missingTimestampLabel,
  });

  final AppTimelineItem item;
  final bool isLast;
  final bool dense;
  final String missingTimestampLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Color toneColor = _toneColor(theme, item.tone);
    final Locale locale = Localizations.localeOf(context);
    final String timestamp =
        item.subtitle ??
        (item.occurredAt == null
            ? missingTimestampLabel
            : AppFormatters.dateTime(item.occurredAt!, locale));
    final IconData resolvedIcon = item.icon ?? _defaultToneIcon(item.tone);

    return Semantics(
      container: true,
      label: <String>[
        item.title,
        if (timestamp.isNotEmpty) timestamp,
        if (item.description != null && item.description!.isNotEmpty)
          item.description!,
      ].join('. '),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(
              width: dense ? 24 : 28,
              child: Column(
                children: <Widget>[
                  Container(
                    width: dense ? 10 : 12,
                    height: dense ? 10 : 12,
                    decoration: BoxDecoration(
                      color: toneColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: colorScheme.surface),
                    ),
                    child: Icon(
                      resolvedIcon,
                      size: dense ? 6 : 8,
                      color: colorScheme.surface,
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: colorScheme.outlineVariant,
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(width: theme.spacing.sm),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: isLast
                      ? 0
                      : (dense ? theme.spacing.sm : theme.spacing.md),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (timestamp.isNotEmpty)
                      Text(
                        timestamp,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    if (item.description != null &&
                        item.description!.trim().isNotEmpty) ...<Widget>[
                      SizedBox(height: theme.spacing.xs),
                      Text(
                        item.description!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Color _toneColor(ThemeData theme, AppWorkspaceStatusTone tone) {
    return switch (tone) {
      AppWorkspaceStatusTone.success => theme.statusColors.success,
      AppWorkspaceStatusTone.warning => theme.statusColors.warning,
      AppWorkspaceStatusTone.error => theme.statusColors.error,
      AppWorkspaceStatusTone.info => theme.statusColors.info,
      AppWorkspaceStatusTone.neutral => theme.colorScheme.primary,
    };
  }

  static IconData _defaultToneIcon(AppWorkspaceStatusTone tone) {
    return switch (tone) {
      AppWorkspaceStatusTone.success => Icons.check,
      AppWorkspaceStatusTone.warning => Icons.priority_high,
      AppWorkspaceStatusTone.error => Icons.close,
      AppWorkspaceStatusTone.info => Icons.info_outline,
      AppWorkspaceStatusTone.neutral => Icons.circle,
    };
  }
}
