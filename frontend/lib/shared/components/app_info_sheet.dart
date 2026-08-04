import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/shared/components/app_copyable_identifier.dart';

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

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: theme.spacing.xs),
        copyable
            ? AppCopyableIdentifier(
                value: value,
                tooltip: copyTooltip,
                copiedMessage: copiedMessage,
                semanticLabel: copySemanticLabel,
                showCopyIcon: showCopyIcon,
                maxLines: maxLines,
                placeholderValues: copyPlaceholderValues,
                textStyle: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: AppFontWeight.medium,
                ),
              )
            : Text(
                value,
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: AppFontWeight.medium,
                ),
              ),
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
    super.key,
  });

  final List<AppInfoSheetItem> items;
  final String emptyValue;
  final int maxColumns;
  final double minItemWidth;
  final double? spacing;
  final double? runSpacing;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double gap = spacing ?? theme.spacing.md;
    final double rowGap = runSpacing ?? gap;

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
                  minWidth: math.min(minItemWidth, itemMaxWidth),
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
