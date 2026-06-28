import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/shared/components/app_copyable_identifier.dart';
import 'package:hosspi_hms/shared/components/app_info_tile.dart';

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
                  fontWeight: FontWeight.w600,
                ),
              )
            : Text(
                value,
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
        if (showDivider)
          Padding(
            padding: EdgeInsets.only(top: theme.spacing.sm),
            child: Divider(
              height: 1,
              thickness: 1,
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
      ],
    );
  }
}

/// Responsive grid of compact info rows (1 / 2 / 3 columns by width).
class AppInfoSheetGrid extends StatelessWidget {
  const AppInfoSheetGrid({
    required this.items,
    this.emptyValue = '',
    this.maxColumns = 3,
    this.minItemWidth = 230,
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
    return AppResponsiveWrap(
      maxColumns: maxColumns,
      minItemWidth: minItemWidth,
      spacing: spacing,
      runSpacing: runSpacing,
      children: <Widget>[
        for (final AppInfoSheetItem item in items)
          AppInfoSheetRow(
            label: item.label,
            value: _resolvedValue(item.value, emptyValue),
            copyable: item.copyable,
            copyTooltip: item.copyTooltip,
            copiedMessage: item.copiedMessage,
            copySemanticLabel: item.copySemanticLabel,
            showCopyIcon: item.showCopyIcon,
            copyPlaceholderValues: item.copyPlaceholderValues,
          ),
      ],
    );
  }
}

String _resolvedValue(String? value, String emptyValue) {
  final String? normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) {
    return emptyValue;
  }

  return normalized;
}
