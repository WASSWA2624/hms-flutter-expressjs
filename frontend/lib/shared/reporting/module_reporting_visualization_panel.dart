import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/dashboard/dashboard.dart';
import 'package:hosspi_hms/shared/reporting/module_reporting_data.dart';
import 'package:hosspi_hms/shared/reporting/module_reporting_models.dart';
import 'package:hosspi_hms/shared/reporting/module_reporting_table.dart';
import 'package:hosspi_hms/shared/reporting/module_reporting_visualization.dart';

/// Adaptive visualization host for module report dialogs.
///
/// Shows only visualization kinds applicable to [snapshot], and lets the user
/// switch among them. Table export reuses [ModuleReportingSnapshotTable].
class ModuleReportingVisualizationPanel extends StatefulWidget {
  const ModuleReportingVisualizationPanel({
    required this.snapshot,
    required this.report,
    required this.labels,
    this.canExport = true,
    super.key,
  });

  final ModuleReportingReportSnapshot snapshot;
  final ModuleReportingReport report;
  final ModuleReportingLabels labels;
  final bool canExport;

  @override
  State<ModuleReportingVisualizationPanel> createState() =>
      _ModuleReportingVisualizationPanelState();
}

class _ModuleReportingVisualizationPanelState
    extends State<ModuleReportingVisualizationPanel> {
  ModuleReportingVisualizationKind? _selected;

  @override
  void didUpdateWidget(covariant ModuleReportingVisualizationPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snapshot != widget.snapshot ||
        oldWidget.report.id != widget.report.id) {
      _selected = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<ModuleReportingVisualizationKind> applicable =
        moduleReportingApplicableVisualizations(widget.snapshot);
    if (applicable.isEmpty) {
      return const SizedBox.shrink();
    }

    final ModuleReportingVisualizationKind selected =
        _selected != null && applicable.contains(_selected)
        ? _selected!
        : moduleReportingDefaultVisualization(
            applicable: applicable,
            preferred: widget.report.contentKind,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              for (int index = 0; index < applicable.length; index += 1) ...<Widget>[
                if (index > 0) SizedBox(width: theme.spacing.xs),
                _VisualizationChip(
                  kind: applicable[index],
                  selected: applicable[index] == selected,
                  onSelected: () => setState(() => _selected = applicable[index]),
                ),
              ],
            ],
          ),
        ),
        SizedBox(height: theme.spacing.sm),
        _VisualizationBody(
          kind: selected,
          snapshot: widget.snapshot,
          report: widget.report,
          labels: widget.labels,
          canExport: widget.canExport,
        ),
      ],
    );
  }
}

class _VisualizationChip extends StatelessWidget {
  const _VisualizationChip({
    required this.kind,
    required this.selected,
    required this.onSelected,
  });

  final ModuleReportingVisualizationKind kind;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return FilterChip(
      selected: selected,
      showCheckmark: false,
      avatar: Icon(moduleReportingVisualizationIcon(kind), size: 16),
      label: Text(moduleReportingVisualizationLabel(kind)),
      onSelected: (_) => onSelected(),
      visualDensity: VisualDensity.compact,
      selectedColor: colors.primaryContainer,
      side: BorderSide(
        color: selected ? colors.primary : theme.borders.faint,
      ),
    );
  }
}

class _VisualizationBody extends StatelessWidget {
  const _VisualizationBody({
    required this.kind,
    required this.snapshot,
    required this.report,
    required this.labels,
    required this.canExport,
  });

  final ModuleReportingVisualizationKind kind;
  final ModuleReportingReportSnapshot snapshot;
  final ModuleReportingReport report;
  final ModuleReportingLabels labels;
  final bool canExport;

  @override
  Widget build(BuildContext context) {
    switch (kind) {
      case ModuleReportingVisualizationKind.table:
        return ModuleReportingSnapshotTable(
          snapshot: snapshot,
          labels: labels,
          canExport: canExport,
          storageKeyPrefix: report.id,
          exportFileNameStem: report.id,
        );
      case ModuleReportingVisualizationKind.kpiCards:
        return DashboardMetricStrip(
          cards: moduleReportingKpiCards(snapshot),
          maxCards: 6,
          compact: true,
        );
      case ModuleReportingVisualizationKind.lineChart:
        return _SeriesChartHost(
          title: report.label,
          emptyMessage: labels.emptyBody,
          points: moduleReportingSeriesPoints(snapshot),
          style: DashboardTrendChartStyle.line,
        );
      case ModuleReportingVisualizationKind.barChart:
        return _SeriesChartHost(
          title: report.label,
          emptyMessage: labels.emptyBody,
          points: moduleReportingSeriesPoints(snapshot),
          style: DashboardTrendChartStyle.bar,
        );
      case ModuleReportingVisualizationKind.areaChart:
        return _SeriesChartHost(
          title: report.label,
          emptyMessage: labels.emptyBody,
          points: moduleReportingSeriesPoints(snapshot),
          style: DashboardTrendChartStyle.area,
        );
      case ModuleReportingVisualizationKind.donutChart:
        return _DonutChartHost(
          title: report.label,
          emptyMessage: labels.emptyBody,
          totalLabel: labels.exportValueColumn,
          segments: moduleReportingDistributionSegments(snapshot),
        );
      case ModuleReportingVisualizationKind.rankingChart:
        return _RankingChart(
          points: moduleReportingDistributionSegments(snapshot)
              .map(
                (DashboardDistributionSegmentData segment) =>
                    ModuleReportingSeriesPoint(
                      label: segment.label,
                      value: segment.value,
                    ),
              )
              .toList(growable: false),
        );
      case ModuleReportingVisualizationKind.gaugeChart:
        return _GaugeChart(points: moduleReportingSeriesPoints(snapshot));
      case ModuleReportingVisualizationKind.scatterChart:
        return _ScatterChart(snapshot: snapshot);
      case ModuleReportingVisualizationKind.heatmap:
        return _HeatmapChart(cells: moduleReportingHeatmapCells(snapshot));
    }
  }
}

class _ChartSurface extends StatelessWidget {
  const _ChartSurface({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(theme.radius.md),
        border: Border.all(color: theme.borders.faint),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, size: 18, color: colors.primary),
                SizedBox(width: theme.spacing.xs),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: AppFontWeight.emphasis,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: theme.spacing.sm),
            child,
          ],
        ),
      ),
    );
  }
}

class _SeriesChartHost extends StatelessWidget {
  const _SeriesChartHost({
    required this.title,
    required this.emptyMessage,
    required this.points,
    required this.style,
  });

  final String title;
  final String emptyMessage;
  final List<ModuleReportingSeriesPoint> points;
  final DashboardTrendChartStyle style;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    if (points.isEmpty) {
      return AppMutedText(emptyMessage);
    }
    final List<DashboardTrendPointData> trendPoints = <DashboardTrendPointData>[
      for (final ModuleReportingSeriesPoint point in points)
        DashboardTrendPointData(value: point.value, label: point.label),
    ];
    return _ChartSurface(
      title: title,
      icon: style == DashboardTrendChartStyle.bar
          ? Icons.bar_chart_outlined
          : style == DashboardTrendChartStyle.area
          ? Icons.area_chart_outlined
          : Icons.show_chart_outlined,
      child: SizedBox(
        height: 240,
        width: double.infinity,
        child: CustomPaint(
          painter: DashboardTrendChartPainter(
            points: trendPoints,
            style: style,
            barColor: colors.primary.withValues(alpha: 0.18),
            lineColor: colors.primary,
            gridColor: theme.borders.faint,
            labelColor: colors.onSurfaceVariant,
            textStyle: theme.textTheme.labelSmall,
            labelBuilder: (DashboardTrendPointData point, {bool compact = false}) {
              final String label = point.label ?? '';
              if (!compact || label.length <= 12) {
                return label;
              }
              return '${label.substring(0, 11)}…';
            },
            showValues: points.length <= 16,
          ),
        ),
      ),
    );
  }
}

class _DonutChartHost extends StatelessWidget {
  const _DonutChartHost({
    required this.title,
    required this.emptyMessage,
    required this.totalLabel,
    required this.segments,
  });

  final String title;
  final String emptyMessage;
  final String totalLabel;
  final List<DashboardDistributionSegmentData> segments;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    if (segments.isEmpty) {
      return AppMutedText(emptyMessage);
    }
    final num total = segments.fold<num>(
      0,
      (num sum, DashboardDistributionSegmentData segment) =>
          sum + segment.value,
    );
    return _ChartSurface(
      title: title,
      icon: Icons.donut_large_outlined,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          SizedBox(
            width: 160,
            height: 160,
            child: CustomPaint(
              painter: DashboardDonutChartPainter(
                segments: segments,
                total: total,
                fallbackColor: colors.primary,
                trackColor: colors.surfaceContainerHighest,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      AppFormatters.compactNumber(
                        total,
                        Localizations.localeOf(context),
                      ),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: AppFontWeight.emphasis,
                      ),
                    ),
                    Text(
                      totalLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(width: theme.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (int index = 0; index < segments.length; index += 1)
                  Padding(
                    padding: EdgeInsets.only(bottom: theme.spacing.xs),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Color.lerp(
                              colors.primary,
                              colors.tertiary,
                              index / math.max(1, segments.length - 1),
                            ),
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: theme.spacing.xs),
                        Expanded(
                          child: Text(
                            segments[index].label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          AppFormatters.decimal(
                            segments[index].value,
                            Localizations.localeOf(context),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RankingChart extends StatelessWidget {
  const _RankingChart({required this.points});

  final List<ModuleReportingSeriesPoint> points;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final List<ModuleReportingSeriesPoint> ranked =
        List<ModuleReportingSeriesPoint>.from(points)
          ..sort(
            (ModuleReportingSeriesPoint left, ModuleReportingSeriesPoint right) =>
                right.value.compareTo(left.value),
          );
    final num maxValue = ranked.fold<num>(
      0,
      (num max, ModuleReportingSeriesPoint point) =>
          point.value > max ? point.value : max,
    );
    final List<ModuleReportingSeriesPoint> top =
        ranked.take(12).toList(growable: false);
    return _ChartSurface(
      title: 'Ranking',
      icon: Icons.leaderboard_outlined,
      child: Column(
        children: <Widget>[
          for (int index = 0; index < top.length; index += 1)
            Padding(
              padding: EdgeInsets.only(bottom: theme.spacing.sm),
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 24,
                    child: Text(
                      '${index + 1}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      top[index].label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: theme.spacing.sm),
                  Expanded(
                    flex: 5,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(theme.radius.sm),
                      child: LinearProgressIndicator(
                        value: maxValue <= 0
                            ? 0
                            : (top[index].value / maxValue).toDouble(),
                        minHeight: 12,
                        backgroundColor: colors.surfaceContainerHighest,
                      ),
                    ),
                  ),
                  SizedBox(width: theme.spacing.sm),
                  SizedBox(
                    width: 72,
                    child: Text(
                      AppFormatters.compactNumber(
                        top[index].value,
                        Localizations.localeOf(context),
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _GaugeChart extends StatelessWidget {
  const _GaugeChart({required this.points});

  final List<ModuleReportingSeriesPoint> points;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final num value = points.isEmpty ? 0 : points.first.value;
    final num maxValue = points.fold<num>(
      value,
      (num max, ModuleReportingSeriesPoint point) =>
          point.value > max ? point.value : max,
    );
    final double ratio = maxValue <= 0
        ? 0
        : (value / maxValue).clamp(0, 1).toDouble();
    return _ChartSurface(
      title: points.isEmpty ? 'Gauge' : points.first.label,
      icon: Icons.speed_outlined,
      child: SizedBox(
        height: 180,
        child: CustomPaint(
          painter: _GaugePainter(
            ratio: ratio,
            color: colors.primary,
            trackColor: colors.surfaceContainerHighest,
            labelColor: colors.onSurface,
            valueLabel: AppFormatters.compactNumber(
              value,
              Localizations.localeOf(context),
            ),
            textStyle: theme.textTheme.titleMedium,
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  const _GaugePainter({
    required this.ratio,
    required this.color,
    required this.trackColor,
    required this.labelColor,
    required this.valueLabel,
    required this.textStyle,
  });

  final double ratio;
  final Color color;
  final Color trackColor;
  final Color labelColor;
  final String valueLabel;
  final TextStyle? textStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height * 0.72);
    final double radius = math.min(size.width, size.height) * 0.42;
    final Rect arc = Rect.fromCircle(center: center, radius: radius);
    final Paint track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round
      ..color = trackColor;
    final Paint fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round
      ..color = color;
    const double start = math.pi;
    const double sweep = math.pi;
    canvas.drawArc(arc, start, sweep, false, track);
    canvas.drawArc(arc, start, sweep * ratio, false, fill);

    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: valueLabel,
        style: textStyle?.copyWith(color: labelColor),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height),
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.ratio != ratio ||
        oldDelegate.valueLabel != valueLabel ||
        oldDelegate.color != color;
  }
}

class _ScatterChart extends StatelessWidget {
  const _ScatterChart({required this.snapshot});

  final ModuleReportingReportSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final List<String> numeric = moduleReportingNumericColumns(snapshot.columns);
    if (numeric.length < 2) {
      return const SizedBox.shrink();
    }
    final String xKey = numeric[0];
    final String yKey = numeric[1];
    final List<Offset> points = <Offset>[
      for (final Map<String, Object?> row in snapshot.rows.take(80))
        Offset(
          (moduleReportingAsNum(row[xKey]) ?? 0).toDouble(),
          (moduleReportingAsNum(row[yKey]) ?? 0).toDouble(),
        ),
    ];
    return _ChartSurface(
      title: '${moduleReportingColumnLabel(xKey)} × ${moduleReportingColumnLabel(yKey)}',
      icon: Icons.scatter_plot_outlined,
      child: SizedBox(
        height: 240,
        child: CustomPaint(
          painter: _ScatterPainter(
            points: points,
            color: colors.primary,
            gridColor: theme.borders.faint,
          ),
        ),
      ),
    );
  }
}

class _ScatterPainter extends CustomPainter {
  const _ScatterPainter({
    required this.points,
    required this.color,
    required this.gridColor,
  });

  final List<Offset> points;
  final Color color;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (int i = 0; i <= 3; i += 1) {
      final double y = size.height * (i / 3);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    if (points.isEmpty) {
      return;
    }
    double minX = points.first.dx;
    double maxX = points.first.dx;
    double minY = points.first.dy;
    double maxY = points.first.dy;
    for (final Offset point in points) {
      minX = math.min(minX, point.dx);
      maxX = math.max(maxX, point.dx);
      minY = math.min(minY, point.dy);
      maxY = math.max(maxY, point.dy);
    }
    final double spanX = math.max(1, maxX - minX);
    final double spanY = math.max(1, maxY - minY);
    final Paint dot = Paint()..color = color;
    for (final Offset point in points) {
      final double x = ((point.dx - minX) / spanX) * (size.width - 16) + 8;
      final double y =
          size.height - (((point.dy - minY) / spanY) * (size.height - 16) + 8);
      canvas.drawCircle(Offset(x, y), 4, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _ScatterPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.color != color;
  }
}

class _HeatmapChart extends StatelessWidget {
  const _HeatmapChart({required this.cells});

  final List<ModuleReportingHeatmapCell> cells;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    if (cells.isEmpty) {
      return const SizedBox.shrink();
    }
    final List<String> rows = cells
        .map((ModuleReportingHeatmapCell cell) => cell.rowKey)
        .toSet()
        .toList(growable: false);
    final List<String> columns = cells
        .map((ModuleReportingHeatmapCell cell) => cell.columnKey)
        .toSet()
        .toList(growable: false);
    final Map<String, num> lookup = <String, num>{
      for (final ModuleReportingHeatmapCell cell in cells)
        '${cell.rowKey}::${cell.columnKey}': cell.value,
    };
    final num maxValue = cells.fold<num>(
      0,
      (num max, ModuleReportingHeatmapCell cell) =>
          cell.value > max ? cell.value : max,
    );

    return _ChartSurface(
      title: 'Heatmap',
      icon: Icons.grid_on_outlined,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const SizedBox(width: 96),
                for (final String column in columns)
                  SizedBox(
                    width: 72,
                    child: Text(
                      column,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
              ],
            ),
            SizedBox(height: theme.spacing.xs),
            for (final String row in rows)
              Padding(
                padding: EdgeInsets.only(bottom: theme.spacing.xs),
                child: Row(
                  children: <Widget>[
                    SizedBox(
                      width: 96,
                      child: Text(
                        row,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                    for (final String column in columns)
                      Container(
                        width: 72,
                        height: 36,
                        margin: const EdgeInsets.only(right: 2),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(
                            alpha: maxValue <= 0
                                ? 0.05
                                : (0.08 +
                                      0.72 *
                                          ((lookup['$row::$column'] ?? 0) /
                                                  maxValue)
                                              .toDouble()),
                          ),
                          borderRadius: BorderRadius.circular(theme.radius.sm),
                        ),
                        child: Text(
                          AppFormatters.compactNumber(
                            lookup['$row::$column'] ?? 0,
                            Localizations.localeOf(context),
                          ),
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
