import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/shared/components/app_content_panel.dart';

class AppResponsiveWrap extends StatelessWidget {
  const AppResponsiveWrap({
    required this.children,
    this.maxColumns = 3,
    this.minItemWidth = 180,
    this.spacing,
    this.runSpacing,
    super.key,
  });

  final List<Widget> children;
  final int maxColumns;
  final double minItemWidth;
  final double? spacing;
  final double? runSpacing;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double gap = spacing ?? theme.spacing.sm;
    final double rowGap = runSpacing ?? gap;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double itemWidth = _itemWidth(
          availableWidth: constraints.maxWidth,
          itemCount: children.length,
          maxColumns: maxColumns,
          spacing: gap,
          minWidth: minItemWidth,
        );

        return Wrap(
          spacing: gap,
          runSpacing: rowGap,
          children: <Widget>[
            for (final Widget child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}

class AppInfoTileGrid extends StatelessWidget {
  const AppInfoTileGrid({
    required this.items,
    this.maxColumns = 4,
    this.minItemWidth = 160,
    this.spacing,
    this.runSpacing,
    this.emptyValue = '',
    this.borderedTiles = true,
    super.key,
  });

  final List<AppInfoTileData> items;
  final int maxColumns;
  final double minItemWidth;
  final double? spacing;
  final double? runSpacing;
  final String emptyValue;
  final bool borderedTiles;

  @override
  Widget build(BuildContext context) {
    return AppResponsiveWrap(
      maxColumns: maxColumns,
      minItemWidth: minItemWidth,
      spacing: spacing,
      runSpacing: runSpacing,
      children: <Widget>[
        for (final AppInfoTileData item in items)
          AppInfoTile(
            label: item.label,
            value: item.value,
            icon: item.icon,
            emptyValue: emptyValue,
            bordered: borderedTiles,
          ),
      ],
    );
  }
}

@immutable
final class AppInfoTileData {
  const AppInfoTileData({required this.label, this.value, this.icon});

  final String label;
  final String? value;
  final IconData? icon;
}

class AppInfoTile extends StatelessWidget {
  const AppInfoTile({
    required this.label,
    this.value,
    this.icon,
    this.emptyValue = '',
    this.bordered = true,
    this.maxLines = 2,
    super.key,
  });

  final String label;
  final String? value;
  final IconData? icon;
  final String emptyValue;
  final bool bordered;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final Widget content = _AppInfoTileContent(
      label: label,
      value: value,
      icon: icon,
      emptyValue: emptyValue,
      maxLines: maxLines,
    );

    if (!bordered) {
      return content;
    }

    return AppContentPanel(
      density: AppContentPanelDensity.compact,
      child: content,
    );
  }
}

class _AppInfoTileContent extends StatelessWidget {
  const _AppInfoTileContent({
    required this.label,
    required this.value,
    required this.icon,
    required this.emptyValue,
    required this.maxLines,
  });

  final String label;
  final String? value;
  final IconData? icon;
  final String emptyValue;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String displayValue = _resolvedValue(value, emptyValue);

    if (icon == null) {
      return _InfoText(label: label, value: displayValue, maxLines: maxLines);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(
          icon,
          size: theme.appTokens.listIconSize,
          color: theme.colorScheme.primary,
        ),
        SizedBox(width: theme.spacing.xs),
        Expanded(
          child: _InfoText(
            label: label,
            value: displayValue,
            maxLines: maxLines,
          ),
        ),
      ],
    );
  }
}

class _InfoText extends StatelessWidget {
  const _InfoText({
    required this.label,
    required this.value,
    required this.maxLines,
  });

  final String label;
  final String value;
  final int maxLines;

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
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: theme.spacing.xs),
        Text(
          value,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
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

  return value!;
}

double _itemWidth({
  required double availableWidth,
  required int itemCount,
  required int maxColumns,
  required double spacing,
  required double minWidth,
}) {
  if (!availableWidth.isFinite || availableWidth <= 0) {
    return minWidth;
  }

  final int effectiveMaxColumns = math
      .min(itemCount, maxColumns)
      .clamp(1, 64)
      .toInt();
  for (int columns = effectiveMaxColumns; columns > 1; columns -= 1) {
    final double width = (availableWidth - spacing * (columns - 1)) / columns;
    if (width >= minWidth) {
      return width;
    }
  }

  return availableWidth;
}
