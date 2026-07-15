import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';

/// Selectable report section descriptor (presentation-only).
@immutable
final class AppReportSectionData {
  const AppReportSectionData({
    required this.id,
    required this.title,
    required this.icon,
    this.count = 0,
    this.enabled = true,
    this.disabledReason,
    this.semanticLabel,
  });

  final Object id;
  final String title;
  final IconData icon;
  final int count;
  final bool enabled;
  final String? disabledReason;
  final String? semanticLabel;
}

/// Checkbox-style report section tile for print/export section pickers.
class AppReportSectionTile extends StatelessWidget {
  const AppReportSectionTile({
    required this.section,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final AppReportSectionData section;
  final bool selected;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool interactive = section.enabled && onChanged != null;
    final bool isSelected = selected && section.enabled;

    return Semantics(
      button: interactive,
      enabled: interactive,
      checked: isSelected,
      label:
          section.semanticLabel ??
          '${section.title}${section.count > 0 ? ', ${section.count}' : ''}'
              '${section.enabled ? '' : ', ${section.disabledReason ?? 'unavailable'}'}',
      child: InkWell(
        onTap: interactive ? () => onChanged!(!selected) : null,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primaryContainer.withValues(alpha: 0.28)
                : colorScheme.surface,
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: theme.spacing.sm,
              vertical: theme.spacing.xs,
            ),
            child: Row(
              children: <Widget>[
                Checkbox(
                  value: isSelected,
                  visualDensity: VisualDensity.compact,
                  onChanged: interactive
                      ? (bool? value) => onChanged!(value ?? false)
                      : null,
                ),
                Icon(
                  section.icon,
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  size: theme.appTokens.listIconSize,
                ),
                SizedBox(width: theme.spacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        section.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: section.enabled
                              ? null
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (!section.enabled &&
                          (section.disabledReason?.trim().isNotEmpty ?? false))
                        Text(
                          section.disabledReason!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(width: theme.spacing.sm),
                Text(
                  section.count.toString(),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
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

/// Vertical list of selectable report sections.
class AppReportSectionList extends StatelessWidget {
  const AppReportSectionList({
    required this.sections,
    required this.selectedIds,
    required this.onSelectionChanged,
    this.spacing,
    super.key,
  });

  final List<AppReportSectionData> sections;
  final Set<Object> selectedIds;
  final ValueChanged<Set<Object>> onSelectionChanged;
  final double? spacing;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double gap = spacing ?? theme.spacing.xs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (var index = 0; index < sections.length; index += 1) ...<Widget>[
          if (index > 0) SizedBox(height: gap),
          AppReportSectionTile(
            section: sections[index],
            selected: selectedIds.contains(sections[index].id),
            onChanged: sections[index].enabled
                ? (bool selected) {
                    final Set<Object> next = Set<Object>.of(selectedIds);
                    if (selected) {
                      next.add(sections[index].id);
                    } else {
                      next.remove(sections[index].id);
                    }
                    onSelectionChanged(next);
                  }
                : null,
          ),
        ],
      ],
    );
  }
}
