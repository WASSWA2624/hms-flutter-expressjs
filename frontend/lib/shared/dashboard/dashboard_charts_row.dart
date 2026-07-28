import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/shared/components/app_content_panel.dart';
import 'package:hosspi_hms/shared/dashboard/dashboard_chart_painters.dart';
import 'package:hosspi_hms/shared/dashboard/dashboard_layout.dart';
import 'package:hosspi_hms/shared/dashboard/dashboard_models.dart';
import 'package:intl/intl.dart' hide TextDirection;

class DashboardChartsRow extends StatelessWidget {
  const DashboardChartsRow({
    required this.data,
    this.twoColumns = false,
    super.key,
  });

  final DashboardChartsData data;
  final bool twoColumns;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double gap = theme.spacing.md;
    final Widget trendPanel = RepaintBoundary(
      child: _DashboardTrendPanel(chart: data.trend),
    );
    final Widget distributionPanel = RepaintBoundary(
      child: _DashboardDistributionPanel(chart: data.distribution),
    );

    if (twoColumns) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(flex: 3, child: trendPanel),
          SizedBox(width: gap),
          Expanded(flex: 2, child: distributionPanel),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        trendPanel,
        SizedBox(height: gap),
        distributionPanel,
      ],
    );
  }
}

class _DashboardTrendPanel extends StatelessWidget {
  const _DashboardTrendPanel({required this.chart});

  final DashboardTrendChartData chart;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: dashboardSurfaceCardDecoration(theme, colorScheme),
      child: AppSectionPanel(
        title: chart.title,
        leadingIcon: Icons.show_chart_outlined,
        density: AppContentPanelDensity.spacious,
        backgroundColor: Colors.transparent,
        borderColor: Colors.transparent,
        children: <Widget>[
          if (chart.subtitle != null && chart.subtitle!.trim().isNotEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: theme.spacing.sm),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  chart.subtitle!.trim(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          if (chart.points.isEmpty)
            _DashboardChartEmptyState(message: chart.emptyMessage)
          else
            _DashboardTrendChart(points: chart.points),
        ],
      ),
    );
  }
}

class _DashboardTrendChart extends StatelessWidget {
  const _DashboardTrendChart({required this.points});

  final List<DashboardTrendPointData> points;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final List<DashboardTrendPointData> visiblePoints = points
        .take(14)
        .toList(growable: false);

    return Semantics(
      label: 'Trend chart with ${visiblePoints.length} points',
      child: Column(
        children: <Widget>[
          SizedBox(
            height: 180,
            width: double.infinity,
            child: CustomPaint(
              painter: DashboardTrendChartPainter(
                points: visiblePoints,
                barColor: colorScheme.primary.withValues(alpha: 0.18),
                lineColor: colorScheme.primary,
                gridColor: colorScheme.outlineVariant,
                labelColor: colorScheme.onSurfaceVariant,
                textStyle: theme.textTheme.labelSmall,
                labelBuilder: _trendPointLabel,
              ),
            ),
          ),
          SizedBox(height: theme.spacing.xs),
          Row(
            children: <Widget>[
              if (visiblePoints.isNotEmpty)
                Text(
                  _trendPointLabel(visiblePoints.first),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              const Spacer(),
              if (visiblePoints.length > 1)
                Text(
                  _trendPointLabel(visiblePoints.last),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DashboardDistributionPanel extends StatelessWidget {
  const _DashboardDistributionPanel({required this.chart});

  final DashboardDistributionChartData chart;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final bool hasData =
        chart.total > 0 ||
        chart.segments.any(
          (DashboardDistributionSegmentData s) => s.value != 0,
        );

    return DecoratedBox(
      decoration: dashboardSurfaceCardDecoration(theme, colorScheme),
      child: AppSectionPanel(
        title: chart.title,
        leadingIcon: Icons.donut_large_outlined,
        density: AppContentPanelDensity.spacious,
        backgroundColor: Colors.transparent,
        borderColor: Colors.transparent,
        children: <Widget>[
          if (!hasData)
            _DashboardChartEmptyState(message: chart.emptyMessage)
          else
            _DashboardDistributionChart(chart: chart),
        ],
      ),
    );
  }
}

class _DashboardDistributionChart extends StatelessWidget {
  const _DashboardDistributionChart({required this.chart});

  final DashboardDistributionChartData chart;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final List<DashboardDistributionSegmentData> segments = chart.segments;
    final num total = chart.total > 0
        ? chart.total
        : segments.fold<num>(
            0,
            (num sum, DashboardDistributionSegmentData segment) =>
                sum + segment.value,
          );

    return Semantics(
      label:
          'Distribution chart with total ${NumberFormat.compact().format(total)}',
      child: Column(
        children: <Widget>[
          SizedBox(
            height: 170,
            width: double.infinity,
            child: Center(
              child: SizedBox(
                width: 154,
                height: 154,
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    CustomPaint(
                      size: const Size.square(154),
                      painter: DashboardDonutChartPainter(
                        segments: segments,
                        total: total,
                        fallbackColor: colorScheme.primary,
                        trackColor: colorScheme.surfaceContainerHighest,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          NumberFormat.compact().format(total),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          chart.totalLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: theme.spacing.sm),
          Wrap(
            spacing: theme.spacing.sm,
            runSpacing: theme.spacing.xs,
            children: <Widget>[
              for (int index = 0; index < segments.length; index += 1)
                _DistributionLegendItem(
                  segment: segments[index],
                  total: total,
                  color: _segmentColor(theme, segments[index], index),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DistributionLegendItem extends StatelessWidget {
  const _DistributionLegendItem({
    required this.segment,
    required this.total,
    required this.color,
  });

  final DashboardDistributionSegmentData segment;
  final num total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final double percent = total <= 0 ? 0 : (segment.value / total) * 100;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.sm,
        vertical: theme.spacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(theme.radius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: theme.spacing.xs),
          Text(
            '${_formatToken(segment.label)} ${percent.round()}%',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardChartEmptyState extends StatelessWidget {
  const _DashboardChartEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Semantics(
      label: message,
      child: Row(
        children: <Widget>[
          Icon(
            Icons.insights_outlined,
            size: 24,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _trendPointLabel(DashboardTrendPointData point, {bool compact = false}) {
  final String? label = point.label?.trim();
  if (label != null && label.isNotEmpty) {
    return label;
  }
  if (point.date == null) {
    return '0';
  }
  return DateFormat(compact ? 'E' : 'MMM d').format(point.date!.toLocal());
}

Color _segmentColor(
  ThemeData theme,
  DashboardDistributionSegmentData segment,
  int index,
) {
  return _segmentColorFromHex(segment.colorHex) ??
      _fallbackSegmentColor(theme.colorScheme.primary, index);
}

Color? _segmentColorFromHex(String? value) {
  final String normalized = (value ?? '').trim().replaceFirst('#', '');
  if (normalized.length != 6 && normalized.length != 8) {
    return null;
  }
  final int? parsed = int.tryParse(normalized, radix: 16);
  if (parsed == null) {
    return null;
  }
  return Color(normalized.length == 6 ? 0xFF000000 | parsed : parsed);
}

Color _fallbackSegmentColor(Color seed, int index) {
  final HSLColor hsl = HSLColor.fromColor(seed);
  final double hue = (hsl.hue + (index * 42)) % 360;
  return hsl
      .withHue(hue)
      .withSaturation(math.min(0.86, hsl.saturation + 0.18))
      .toColor();
}

String _formatToken(String value) {
  return value
      .replaceAll('_', ' ')
      .split(' ')
      .where((String part) => part.trim().isNotEmpty)
      .map(
        (String part) =>
            '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
      )
      .join(' ');
}
