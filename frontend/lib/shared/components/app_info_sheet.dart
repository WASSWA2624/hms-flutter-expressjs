import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/shared/components/app_copyable_identifier.dart';

/// How [AppInfoSheetRow] presents a field label relative to its value.
enum AppInfoSheetLayout {
  /// Label on its own line above the value.
  stacked,

  /// Single line: `Label: value`.
  inline,
}

@immutable
final class AppInfoSheetItem {
  const AppInfoSheetItem({
    required this.label,
    this.value,
    this.copyable = false,
    this.copyTooltip,
    this.copiedMessage,
    this.copySemanticLabel,
    this.showCopyIcon = true,
    this.copyPlaceholderValues = const <String>{},
  });

  final String label;
  final String? value;
  final bool copyable;
  final String? copyTooltip;
  final String? copiedMessage;
  final String? copySemanticLabel;
  final bool showCopyIcon;
  final Set<String> copyPlaceholderValues;
}

/// Compact label/value rows for detail panels — no per-field borders.
class AppInfoSheetRow extends StatelessWidget {
  const AppInfoSheetRow({
    required this.label,
    required this.value,
    this.copyable = false,
    this.copyTooltip,
    this.copiedMessage,
    this.copySemanticLabel,
    this.showCopyIcon = true,
    this.copyPlaceholderValues = const <String>{},
    this.maxLines = 3,
    this.showDivider = false,
    this.layout = AppInfoSheetLayout.stacked,
    super.key,
  });

  final String label;
  final String value;
  final bool copyable;
  final String? copyTooltip;
  final String? copiedMessage;
  final String? copySemanticLabel;
  final bool showCopyIcon;
  final Set<String> copyPlaceholderValues;
  final int maxLines;
  final bool showDivider;
  final AppInfoSheetLayout layout;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle? labelStyle = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final TextStyle? valueStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: AppFontWeight.emphasis,
    );
    final Widget valueWidget = copyable
        ? AppCopyableIdentifier(
            value: value,
            tooltip: copyTooltip,
            copiedMessage: copiedMessage,
            semanticLabel: copySemanticLabel,
            showCopyIcon: showCopyIcon,
            maxLines: maxLines,
            placeholderValues: copyPlaceholderValues,
            textStyle: valueStyle,
          )
        : Text(
            value,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: valueStyle,
          );

    final Widget body = layout == AppInfoSheetLayout.inline
        ? Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text('$label: ', style: labelStyle),
              valueWidget,
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: labelStyle,
              ),
              SizedBox(height: theme.spacing.xs),
              valueWidget,
            ],
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        body,
        if (showDivider)
          Padding(
            padding: EdgeInsets.only(top: theme.spacing.sm),
            child: Divider(
              height: 1,
              thickness: 1,
              color: theme.borders.faint,
            ),
          ),
      ],
    );
  }
}

/// Responsive grid of compact info rows packed left-to-right.
///
/// Items size to their content (up to a per-column max width) and wrap when a
/// row runs out of horizontal space — they are not stretched to fill the row.
class AppInfoSheetGrid extends StatelessWidget {
  const AppInfoSheetGrid({
    required this.items,
    this.emptyValue = '',
    this.maxColumns = 3,
    this.minItemWidth = 120,
    this.spacing,
    this.runSpacing,
    this.layout = AppInfoSheetLayout.stacked,
    super.key,
  });

  final List<AppInfoSheetItem> items;
  final String emptyValue;
  final int maxColumns;
  final double minItemWidth;
  final double? spacing;
  final double? runSpacing;
  final AppInfoSheetLayout layout;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double gap = spacing ?? theme.spacing.md;
    final double rowGap = runSpacing ?? gap;
    final double effectiveMinWidth = layout == AppInfoSheetLayout.inline
        ? math.max(minItemWidth, 180)
        : minItemWidth;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double availableWidth = constraints.maxWidth;
        final int columns = _columnsForWidth(availableWidth, maxColumns);
        final double itemMaxWidth = _itemMaxWidth(
          availableWidth: availableWidth,
          columns: columns,
          spacing: gap,
        );

        return Wrap(
          spacing: gap,
          runSpacing: rowGap,
          children: <Widget>[
            for (final AppInfoSheetItem item in items)
              ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: math.min(effectiveMinWidth, itemMaxWidth),
                  maxWidth: itemMaxWidth,
                ),
                child: AppInfoSheetRow(
                  label: item.label,
                  value: _resolvedValue(item.value, emptyValue),
                  copyable: item.copyable,
                  copyTooltip: item.copyTooltip,
                  copiedMessage: item.copiedMessage,
                  copySemanticLabel: item.copySemanticLabel,
                  showCopyIcon: item.showCopyIcon,
                  copyPlaceholderValues: item.copyPlaceholderValues,
                  layout: layout,
                ),
              ),
          ],
        );
      },
    );
  }
}

int _columnsForWidth(double availableWidth, int maxColumns) {
  if (!availableWidth.isFinite || availableWidth <= 0) {
    return 1;
  }
  if (availableWidth < 480) {
    return 1;
  }
  if (availableWidth < 720) {
    return math.min(2, maxColumns);
  }
  return math.min(3, maxColumns);
}

double _itemMaxWidth({
  required double availableWidth,
  required int columns,
  required double spacing,
}) {
  if (!availableWidth.isFinite || availableWidth <= 0) {
    return 280;
  }
  final int effectiveColumns = columns.clamp(1, 64);
  return (availableWidth - spacing * (effectiveColumns - 1)) / effectiveColumns;
}

String _resolvedValue(String? value, String emptyValue) {
  final String? normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) {
    return emptyValue;
  }

  return normalized;
}
