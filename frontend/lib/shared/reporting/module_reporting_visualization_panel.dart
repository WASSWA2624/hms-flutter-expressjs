import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
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
    this.currencyCode,
    super.key,
  });

  final ModuleReportingReportSnapshot snapshot;
  final ModuleReportingReport report;
  final ModuleReportingLabels labels;
  final bool canExport;
  final String? currencyCode;

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
        _VisualizationSwitcher(
          kinds: applicable,
          selected: selected,
          onSelected: (ModuleReportingVisualizationKind kind) {
            setState(() => _selected = kind);
          },
        ),
        SizedBox(height: theme.spacing.xs),
        ModuleReportingVisualizationView(
          kind: selected,
          snapshot: widget.snapshot,
          labels: widget.labels,
          title: widget.report.label,
          canExport: widget.canExport,
          storageKeyPrefix: widget.report.id,
          currencyCode: widget.currencyCode,
        ),
      ],
    );
  }
}

Color _visualizationAccent(
  ColorScheme colors,
  ModuleReportingVisualizationKind kind,
) {
  return switch (kind) {
    ModuleReportingVisualizationKind.kpiCards => colors.secondaryContainer,
    ModuleReportingVisualizationKind.lineChart => colors.primaryContainer,
    ModuleReportingVisualizationKind.barChart => colors.tertiaryContainer,
    ModuleReportingVisualizationKind.areaChart => Color.lerp(
      colors.primaryContainer,
      colors.tertiaryContainer,
      0.45,
    )!,
    ModuleReportingVisualizationKind.donutChart => Color.lerp(
      colors.secondaryContainer,
      colors.primaryContainer,
      0.35,
    )!,
    ModuleReportingVisualizationKind.rankingChart => colors.errorContainer,
    ModuleReportingVisualizationKind.gaugeChart => Color.lerp(
      colors.tertiaryContainer,
      colors.secondaryContainer,
      0.4,
    )!,
    ModuleReportingVisualizationKind.scatterChart => Color.lerp(
      colors.primaryContainer,
      colors.secondaryContainer,
      0.55,
    )!,
    ModuleReportingVisualizationKind.heatmap => Color.lerp(
      colors.errorContainer,
      colors.tertiaryContainer,
      0.35,
    )!,
    ModuleReportingVisualizationKind.table => colors.surfaceContainerHighest,
  };
}

Color _visualizationOnAccent(
  ColorScheme colors,
  ModuleReportingVisualizationKind kind,
) {
  return switch (kind) {
    ModuleReportingVisualizationKind.kpiCards => colors.onSecondaryContainer,
    ModuleReportingVisualizationKind.lineChart => colors.onPrimaryContainer,
    ModuleReportingVisualizationKind.barChart => colors.onTertiaryContainer,
    ModuleReportingVisualizationKind.rankingChart => colors.onErrorContainer,
    ModuleReportingVisualizationKind.table => colors.onSurfaceVariant,
    _ => colors.onPrimaryContainer,
  };
}

class _VisualizationSwitcher extends StatelessWidget {
  const _VisualizationSwitcher({
    required this.kinds,
    required this.selected,
    required this.onSelected,
  });

  final List<ModuleReportingVisualizationKind> kinds;
  final ModuleReportingVisualizationKind selected;
  final ValueChanged<ModuleReportingVisualizationKind> onSelected;

  static const double _iconOnlyBreakpoint = 560;
  static const double _shortLabelBreakpoint = 820;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final bool iconOnly = width < _iconOnlyBreakpoint;
        final bool shortLabels = width < _shortLabelBreakpoint;

        if (width < 420) {
          return AppSelectField<ModuleReportingVisualizationKind>(
            value: selected,
            semanticLabel: 'Presentation',
            isDense: true,
            allowClear: false,
            enableSpeechToText: false,
            options: <AppSelectOption<ModuleReportingVisualizationKind>>[
              for (final ModuleReportingVisualizationKind kind in kinds)
                AppSelectOption<ModuleReportingVisualizationKind>(
                  value: kind,
                  label: moduleReportingVisualizationLabel(kind),
                  leadingIcon: Icon(
                    moduleReportingVisualizationIcon(kind),
                    size: 18,
                    color: _visualizationOnAccent(colors, kind),
                  ),
                ),
            ],
            onChanged: (ModuleReportingVisualizationKind? value) {
              if (value != null) {
                onSelected(value);
              }
            },
          );
        }

        return SizedBox(
          height: iconOnly ? 40 : 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: kinds.length,
            separatorBuilder: (_, _) => SizedBox(width: theme.spacing.xs),
            itemBuilder: (BuildContext context, int index) {
              final ModuleReportingVisualizationKind kind = kinds[index];
              final bool isSelected = kind == selected;
              final String label = shortLabels || iconOnly
                  ? moduleReportingVisualizationShortLabel(kind)
                  : moduleReportingVisualizationLabel(kind);
              final IconData icon = moduleReportingVisualizationIcon(kind);
              final Color accent = _visualizationAccent(colors, kind);
              final Color onAccent = _visualizationOnAccent(colors, kind);
              final Color fill = isSelected
                  ? accent
                  : accent.withValues(alpha: 0.42);
              final Color foreground = isSelected
                  ? onAccent
                  : Color.lerp(onAccent, colors.onSurface, 0.35)!;

              return Tooltip(
                message: moduleReportingVisualizationLabel(kind),
                waitDuration: const Duration(milliseconds: 400),
                child: Material(
                  color: fill,
                  elevation: isSelected ? 1 : 0,
                  shadowColor: colors.shadow.withValues(alpha: 0.18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(theme.radius.md),
                    side: BorderSide(
                      color: isSelected
                          ? Color.lerp(accent, onAccent, 0.35)!
                          : accent.withValues(alpha: 0.7),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: InkWell(
                    onTap: () => onSelected(kind),
                    borderRadius: BorderRadius.circular(theme.radius.md),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: theme.spacing.sm,
                        vertical: theme.spacing.xs,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(icon, size: 16, color: foreground),
                          if (!iconOnly) ...<Widget>[
                            SizedBox(width: theme.spacing.xs),
                            Text(
                              label,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: foreground,
                                fontWeight: isSelected
                                    ? AppFontWeight.emphasis
                                    : AppFontWeight.label,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class ModuleReportingVisualizationView extends StatelessWidget {
  const ModuleReportingVisualizationView({
    required this.kind,
    required this.snapshot,
    required this.labels,
    required this.title,
    this.canExport = true,
    this.embedded = false,
    this.showOptionsBar = true,
    this.fitForPrint = false,
    this.storageKeyPrefix,
    this.dataLimit,
    this.currencyCode,
    super.key,
  });

  final ModuleReportingVisualizationKind kind;
  final ModuleReportingReportSnapshot snapshot;
  final ModuleReportingLabels labels;
  final String title;
  final bool canExport;

  /// When true, omits the outer titled card chrome (print-preview blocks already
  /// provide a header). Chart options, legends, and painters stay identical.
  final bool embedded;

  /// Legend / axis / values toggles. Disable for static print captures.
  final bool showOptionsBar;

  /// Tight width-fitted layout for print capture / PDF (no horizontal overflow).
  final bool fitForPrint;
  final String? storageKeyPrefix;
  final int? dataLimit;
  final String? currencyCode;

  @override
  Widget build(BuildContext context) {
    final int seriesLimit = dataLimit ?? 40;
    final Locale locale = Localizations.localeOf(context);
    final String? metricKey = moduleReportingSnapshotPrimaryMetricKey(snapshot);
    switch (kind) {
      case ModuleReportingVisualizationKind.table:
        return ModuleReportingSnapshotTable(
          snapshot: snapshot,
          labels: labels,
          canExport: canExport,
          storageKeyPrefix: storageKeyPrefix ?? title,
          exportFileNameStem: storageKeyPrefix ?? title,
          currencyCode: currencyCode,
        );
      case ModuleReportingVisualizationKind.kpiCards:
        return DashboardMetricStrip(
          cards: moduleReportingKpiCards(
            snapshot,
            locale: locale,
            currencyCode: currencyCode,
          ),
          maxCards: 6,
          compact: true,
        );
      case ModuleReportingVisualizationKind.lineChart:
        return _SeriesChartHost(
          title: title,
          emptyMessage: labels.emptyBody,
          points: moduleReportingSeriesPoints(snapshot, limit: seriesLimit),
          style: DashboardTrendChartStyle.line,
          embedded: embedded,
          showOptionsBar: showOptionsBar,
          fitForPrint: fitForPrint,
          metricKey: metricKey,
          currencyCode: currencyCode,
        );
      case ModuleReportingVisualizationKind.barChart:
        return _SeriesChartHost(
          title: title,
          emptyMessage: labels.emptyBody,
          points: moduleReportingSeriesPoints(snapshot, limit: seriesLimit),
          style: DashboardTrendChartStyle.bar,
          embedded: embedded,
          showOptionsBar: showOptionsBar,
          fitForPrint: fitForPrint,
          metricKey: metricKey,
          currencyCode: currencyCode,
        );
      case ModuleReportingVisualizationKind.areaChart:
        return _SeriesChartHost(
          title: title,
          emptyMessage: labels.emptyBody,
          points: moduleReportingSeriesPoints(snapshot, limit: seriesLimit),
          style: DashboardTrendChartStyle.area,
          embedded: embedded,
          showOptionsBar: showOptionsBar,
          fitForPrint: fitForPrint,
          metricKey: metricKey,
          currencyCode: currencyCode,
        );
      case ModuleReportingVisualizationKind.donutChart:
        return _DonutChartHost(
          title: title,
          emptyMessage: labels.emptyBody,
          totalLabel: labels.exportValueColumn,
          segments: moduleReportingDistributionSegments(
            snapshot,
            limit: seriesLimit,
          ),
          embedded: embedded,
          showOptionsBar: showOptionsBar,
          fitForPrint: fitForPrint,
          metricKey: metricKey,
          currencyCode: currencyCode,
        );
      case ModuleReportingVisualizationKind.rankingChart:
        return _RankingChart(
          points: moduleReportingDistributionSegments(
                snapshot,
                limit: seriesLimit,
              )
              .map(
                (DashboardDistributionSegmentData segment) =>
                    ModuleReportingSeriesPoint(
                      label: segment.label,
                      value: segment.value,
                      metricKey: metricKey,
                    ),
              )
              .toList(growable: false),
          embedded: embedded,
          showOptionsBar: showOptionsBar,
          fitForPrint: fitForPrint,
          metricKey: metricKey,
          currencyCode: currencyCode,
        );
      case ModuleReportingVisualizationKind.gaugeChart:
        return _GaugeChart(
          points: moduleReportingSeriesPoints(snapshot, limit: seriesLimit),
          embedded: embedded,
          showOptionsBar: showOptionsBar,
          fitForPrint: fitForPrint,
          metricKey: metricKey,
          currencyCode: currencyCode,
        );
      case ModuleReportingVisualizationKind.scatterChart:
        return _ScatterChart(
          snapshot: snapshot,
          embedded: embedded,
          showOptionsBar: showOptionsBar,
          fitForPrint: fitForPrint,
          currencyCode: currencyCode,
        );
      case ModuleReportingVisualizationKind.heatmap:
        return _HeatmapChart(
          cells: moduleReportingHeatmapCells(snapshot),
          embedded: embedded,
          showOptionsBar: showOptionsBar,
          fitForPrint: fitForPrint,
          metricKey: metricKey,
          currencyCode: currencyCode,
        );
    }
  }
}

class _ChartChromeOptions {
  const _ChartChromeOptions({
    this.showLegend = true,
    this.showAxisLabels = true,
    this.showValues = true,
  });

  final bool showLegend;
  final bool showAxisLabels;
  final bool showValues;

  _ChartChromeOptions copyWith({
    bool? showLegend,
    bool? showAxisLabels,
    bool? showValues,
  }) {
    return _ChartChromeOptions(
      showLegend: showLegend ?? this.showLegend,
      showAxisLabels: showAxisLabels ?? this.showAxisLabels,
      showValues: showValues ?? this.showValues,
    );
  }
}

class _ChartOptionsBar extends StatelessWidget {
  const _ChartOptionsBar({
    required this.options,
    required this.onChanged,
    this.showLegendToggle = true,
    this.showAxisToggle = true,
    this.showValuesToggle = true,
  });

  final _ChartChromeOptions options;
  final ValueChanged<_ChartChromeOptions> onChanged;
  final bool showLegendToggle;
  final bool showAxisToggle;
  final bool showValuesToggle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    Widget chip({
      required String label,
      required bool selected,
      required ValueChanged<bool> onSelected,
      required IconData icon,
    }) {
      return FilterChip(
        selected: selected,
        showCheckmark: false,
        avatar: Icon(icon, size: 16),
        label: Text(label),
        onSelected: onSelected,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        selectedColor: colors.primaryContainer,
        backgroundColor: colors.surfaceContainerHighest.withValues(alpha: 0.55),
        side: BorderSide(
          color: selected ? colors.primary : theme.borders.faint,
        ),
        labelStyle: theme.textTheme.labelMedium?.copyWith(
          color: selected ? colors.onPrimaryContainer : colors.onSurfaceVariant,
          fontWeight: selected ? AppFontWeight.emphasis : AppFontWeight.label,
        ),
      );
    }

    return Wrap(
      spacing: theme.spacing.xs,
      runSpacing: theme.spacing.xs,
      children: <Widget>[
        if (showLegendToggle)
          chip(
            label: 'Legend',
            selected: options.showLegend,
            icon: Icons.legend_toggle_outlined,
            onSelected: (bool value) =>
                onChanged(options.copyWith(showLegend: value)),
          ),
        if (showAxisToggle)
          chip(
            label: 'Axis labels',
            selected: options.showAxisLabels,
            icon: Icons.straighten_outlined,
            onSelected: (bool value) =>
                onChanged(options.copyWith(showAxisLabels: value)),
          ),
        if (showValuesToggle)
          chip(
            label: 'Values',
            selected: options.showValues,
            icon: Icons.pin_outlined,
            onSelected: (bool value) =>
                onChanged(options.copyWith(showValues: value)),
          ),
      ],
    );
  }
}

class _ChartLegendWrap extends StatelessWidget {
  const _ChartLegendWrap({
    required this.labels,
    required this.colors,
    this.values = const <String>[],
    this.compact = false,
  });

  final List<String> labels;
  final List<Color> colors;
  final List<String> values;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final double maxLabelWidth = compact ? 118 : 180;
    return Wrap(
      spacing: theme.spacing.xs,
      runSpacing: theme.spacing.xs,
      children: <Widget>[
        for (int index = 0; index < labels.length; index += 1)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? theme.spacing.xs : theme.spacing.sm,
              vertical: theme.spacing.xs,
            ),
            decoration: BoxDecoration(
              color: colors[index].withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(theme.radius.md),
              border: Border.all(color: colors[index].withValues(alpha: 0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: colors[index],
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: theme.spacing.xs),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxLabelWidth),
                  child: Text(
                    values.isEmpty || index >= values.length
                        ? labels[index]
                        : '${labels[index]} · ${values[index]}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: AppFontWeight.emphasis,
                      fontSize: compact ? 10 : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ChartSurface extends StatelessWidget {
  const _ChartSurface({
    required this.title,
    required this.icon,
    required this.child,
    this.accent,
    this.toolbar,
    this.embedded = false,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Color? accent;
  final Widget? toolbar;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final Color wash = (accent ?? colors.primaryContainer).withValues(
      alpha: 0.22,
    );

    final Widget body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (!embedded)
          Row(
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: (accent ?? colors.primaryContainer).withValues(
                    alpha: 0.55,
                  ),
                  borderRadius: BorderRadius.circular(theme.radius.sm),
                ),
                child: Padding(
                  padding: EdgeInsets.all(theme.spacing.xs),
                  child: Icon(
                    icon,
                    size: 18,
                    color: accent ?? colors.primary,
                  ),
                ),
              ),
              SizedBox(width: theme.spacing.sm),
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
        if (!embedded && toolbar != null) SizedBox(height: theme.spacing.sm),
        ?toolbar,
        if (toolbar != null) SizedBox(height: theme.spacing.sm),
        if (!embedded && toolbar == null) SizedBox(height: theme.spacing.sm),
        child,
      ],
    );

    if (embedded) {
      return body;
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color.lerp(colors.surface, wash, 0.55)!,
            colors.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(theme.radius.md),
        border: Border.all(color: theme.borders.faint),
        boxShadow: dashboardSoftShadow(colors),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.md),
        child: body,
      ),
    );
  }
}

double _chartHeightForWidth(double width) {
  if (width < 420) {
    return 200;
  }
  if (width < 720) {
    return 240;
  }
  return 280;
}

class _SeriesChartHost extends StatefulWidget {
  const _SeriesChartHost({
    required this.title,
    required this.emptyMessage,
    required this.points,
    required this.style,
    this.embedded = false,
    this.showOptionsBar = true,
    this.fitForPrint = false,
    this.metricKey,
    this.currencyCode,
  });

  final String title;
  final String emptyMessage;
  final List<ModuleReportingSeriesPoint> points;
  final DashboardTrendChartStyle style;
  final bool embedded;
  final bool showOptionsBar;
  final bool fitForPrint;
  final String? metricKey;
  final String? currencyCode;

  @override
  State<_SeriesChartHost> createState() => _SeriesChartHostState();
}

class _SeriesChartHostState extends State<_SeriesChartHost> {
  _ChartChromeOptions _options = const _ChartChromeOptions();

  @override
  void initState() {
    super.initState();
    if (widget.fitForPrint) {
      _options = const _ChartChromeOptions(
        showLegend: true,
        showAxisLabels: true,
        showValues: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    if (widget.points.isEmpty) {
      return AppMutedText(widget.emptyMessage);
    }
    final List<DashboardTrendPointData> trendPoints = <DashboardTrendPointData>[
      for (final ModuleReportingSeriesPoint point in widget.points)
        DashboardTrendPointData(value: point.value, label: point.label),
    ];
    final List<Color> pointColors = <Color>[
      for (int index = 0; index < trendPoints.length; index += 1)
        dashboardFallbackSegmentColor(colors.primary, index),
    ];
    final Locale locale = Localizations.localeOf(context);
    final IconData icon = widget.style == DashboardTrendChartStyle.bar
        ? Icons.bar_chart_outlined
        : widget.style == DashboardTrendChartStyle.area
        ? Icons.area_chart_outlined
        : Icons.show_chart_outlined;
    final Color accent = widget.style == DashboardTrendChartStyle.bar
        ? colors.tertiary
        : widget.style == DashboardTrendChartStyle.area
        ? colors.secondary
        : colors.primary;

    return _ChartSurface(
      title: widget.title,
      icon: icon,
      accent: accent,
      embedded: widget.embedded,
      toolbar: widget.showOptionsBar
          ? _ChartOptionsBar(
              options: _options,
              onChanged: (next) => setState(() => _options = next),
            )
          : null,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double width = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width;
          final bool fitAll =
              widget.fitForPrint || trendPoints.length <= 8;
          final double height = widget.fitForPrint
              ? 200
              : _chartHeightForWidth(width);
          final double chartWidth = fitAll
              ? width
              : math.max(width, trendPoints.length * 72.0);
          final bool showValues = widget.fitForPrint
              ? trendPoints.length <= 14 && _options.showValues
              : _options.showValues;
          final bool showAxisLabels = widget.fitForPrint
              ? trendPoints.length <= 14 && _options.showAxisLabels
              : _options.showAxisLabels;
          final Widget paint = SizedBox(
            width: chartWidth,
            height: height,
            child: CustomPaint(
              painter: DashboardTrendChartPainter(
                points: trendPoints,
                style: widget.style,
                barColor: colors.primary.withValues(alpha: 0.18),
                lineColor: pointColors.first,
                gridColor: theme.borders.faint,
                labelColor: colors.onSurfaceVariant,
                textStyle: theme.textTheme.labelSmall,
                labelBuilder:
                    (DashboardTrendPointData point, {bool compact = false}) {
                      final String label = point.label ?? '';
                      final int maxLen = widget.fitForPrint ? 8 : 12;
                      if (!compact || label.length <= maxLen) {
                        return label;
                      }
                      return '${label.substring(0, maxLen - 1)}…';
                    },
                pointColors: pointColors,
                showValues: showValues,
                showAxisLabels: showAxisLabels,
                valueFormatter: (num value) =>
                    moduleReportingFormatMetricValue(
                      value,
                      locale: locale,
                      columnKey: widget.metricKey ??
                          (widget.points.isEmpty
                              ? null
                              : widget.points.first.metricKey),
                      currencyCode: widget.currencyCode,
                      compact: true,
                    ),
                minBarHeight: fitAll ? 4 : 0,
              ),
            ),
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                height: height,
                width: double.infinity,
                child: fitAll || chartWidth <= width + 0.5
                    ? paint
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: paint,
                      ),
              ),
              if (_options.showLegend) ...<Widget>[
                SizedBox(height: theme.spacing.sm),
                _ChartLegendWrap(
                  compact: widget.fitForPrint,
                  labels: <String>[
                    for (final DashboardTrendPointData point in trendPoints)
                      point.label ?? '',
                  ],
                  colors: pointColors,
                  values: <String>[
                    for (final DashboardTrendPointData point in trendPoints)
                      moduleReportingFormatMetricValue(
                        point.value,
                        locale: locale,
                        columnKey: widget.metricKey ??
                            (widget.points.isEmpty
                                ? null
                                : widget.points.first.metricKey),
                        currencyCode: widget.currencyCode,
                        compact: true,
                      ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _DonutChartHost extends StatefulWidget {
  const _DonutChartHost({
    required this.title,
    required this.emptyMessage,
    required this.totalLabel,
    required this.segments,
    this.embedded = false,
    this.showOptionsBar = true,
    this.fitForPrint = false,
    this.metricKey,
    this.currencyCode,
  });

  final String title;
  final String emptyMessage;
  final String totalLabel;
  final List<DashboardDistributionSegmentData> segments;
  final bool embedded;
  final bool showOptionsBar;
  final bool fitForPrint;
  final String? metricKey;
  final String? currencyCode;

  @override
  State<_DonutChartHost> createState() => _DonutChartHostState();
}

class _DonutChartHostState extends State<_DonutChartHost> {
  _ChartChromeOptions _options = const _ChartChromeOptions(showAxisLabels: false);

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    if (widget.segments.isEmpty) {
      return AppMutedText(widget.emptyMessage);
    }
    final List<Color> segmentColors = <Color>[
      for (int index = 0; index < widget.segments.length; index += 1)
        dashboardFallbackSegmentColor(colors.primary, index),
    ];
    final List<DashboardDistributionSegmentData> coloredSegments =
        <DashboardDistributionSegmentData>[
          for (int index = 0; index < widget.segments.length; index += 1)
            DashboardDistributionSegmentData(
              label: widget.segments[index].label,
              value: widget.segments[index].value,
              colorHex: dashboardColorToHex(segmentColors[index]),
            ),
        ];
    final num total = coloredSegments.fold<num>(
      0,
      (num sum, DashboardDistributionSegmentData segment) =>
          sum + segment.value,
    );
    final Locale locale = Localizations.localeOf(context);

    return _ChartSurface(
      title: widget.title,
      icon: Icons.donut_large_outlined,
      accent: colors.secondary,
      embedded: widget.embedded,
      toolbar: widget.showOptionsBar
          ? _ChartOptionsBar(
              options: _options,
              showAxisToggle: false,
              onChanged: (next) => setState(() => _options = next),
            )
          : null,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool stacked =
              widget.fitForPrint || constraints.maxWidth < 520;
          final double donutSize = widget.fitForPrint ? 148 : (stacked ? 180 : 168);
          final Widget donut = SizedBox(
            width: donutSize,
            height: donutSize,
            child: CustomPaint(
              painter: DashboardDonutChartPainter(
                segments: coloredSegments,
                total: total,
                fallbackColor: colors.primary,
                trackColor: colors.surfaceContainerHighest,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      moduleReportingFormatMetricValue(
                        total,
                        locale: locale,
                        columnKey: widget.metricKey,
                        currencyCode: widget.currencyCode,
                        compact: true,
                      ),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: AppFontWeight.emphasis,
                      ),
                    ),
                    Text(
                      widget.totalLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );

          final Widget? legend = !_options.showLegend
              ? null
              : _ChartLegendWrap(
                  compact: widget.fitForPrint,
                  labels: <String>[
                    for (final DashboardDistributionSegmentData segment
                        in coloredSegments)
                      segment.label,
                  ],
                  colors: segmentColors,
                  values: _options.showValues
                      ? <String>[
                          for (final DashboardDistributionSegmentData segment
                              in coloredSegments)
                            moduleReportingFormatMetricValue(
                              segment.value,
                              locale: locale,
                              columnKey: widget.metricKey,
                              currencyCode: widget.currencyCode,
                              compact: true,
                            ),
                        ]
                      : const <String>[],
                );

          if (stacked) {
            return Column(
              children: <Widget>[
                donut,
                if (legend != null) ...<Widget>[
                  SizedBox(height: theme.spacing.md),
                  legend,
                ],
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              donut,
              SizedBox(width: theme.spacing.md),
              if (legend != null) Expanded(child: legend),
            ],
          );
        },
      ),
    );
  }
}

class _RankingChart extends StatefulWidget {
  const _RankingChart({
    required this.points,
    this.embedded = false,
    this.showOptionsBar = true,
    this.fitForPrint = false,
    this.metricKey,
    this.currencyCode,
  });

  final List<ModuleReportingSeriesPoint> points;
  final bool embedded;
  final bool showOptionsBar;
  final bool fitForPrint;
  final String? metricKey;
  final String? currencyCode;

  @override
  State<_RankingChart> createState() => _RankingChartState();
}

class _RankingChartState extends State<_RankingChart> {
  _ChartChromeOptions _options = const _ChartChromeOptions(
    showAxisLabels: true,
    showLegend: false,
  );

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final List<ModuleReportingSeriesPoint> ranked =
        List<ModuleReportingSeriesPoint>.from(widget.points)
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
    final Locale locale = Localizations.localeOf(context);

    return _ChartSurface(
      title: 'Ranking',
      icon: Icons.leaderboard_outlined,
      accent: colors.error,
      embedded: widget.embedded,
      toolbar: widget.showOptionsBar
          ? _ChartOptionsBar(
              options: _options,
              showLegendToggle: false,
              showAxisToggle: true,
              onChanged: (next) => setState(() => _options = next),
            )
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
                        fontWeight: AppFontWeight.emphasis,
                      ),
                    ),
                  ),
                  if (_options.showAxisLabels)
                    Expanded(
                      flex: 3,
                      child: Text(
                        top[index].label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  else
                    const Spacer(flex: 3),
                  SizedBox(width: theme.spacing.sm),
                  Expanded(
                    flex: 5,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(theme.radius.sm),
                      child: LinearProgressIndicator(
                        value: maxValue <= 0
                            ? 0
                            : (top[index].value / maxValue).toDouble(),
                        minHeight: widget.fitForPrint ? 12 : 14,
                        color: dashboardFallbackSegmentColor(
                          colors.primary,
                          index,
                        ),
                        backgroundColor: colors.surfaceContainerHighest,
                      ),
                    ),
                  ),
                  if (_options.showValues) ...<Widget>[
                    SizedBox(width: theme.spacing.sm),
                    SizedBox(
                      width: 72,
                      child: Text(
                        moduleReportingFormatMetricValue(
                          top[index].value,
                          locale: locale,
                          columnKey:
                              top[index].metricKey ?? widget.metricKey,
                          currencyCode: widget.currencyCode,
                          compact: true,
                        ),
                        textAlign: TextAlign.right,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: dashboardFallbackSegmentColor(
                            colors.primary,
                            index,
                          ),
                          fontWeight: AppFontWeight.emphasis,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _GaugeChart extends StatefulWidget {
  const _GaugeChart({
    required this.points,
    this.embedded = false,
    this.showOptionsBar = true,
    this.fitForPrint = false,
    this.metricKey,
    this.currencyCode,
  });

  final List<ModuleReportingSeriesPoint> points;
  final bool embedded;
  final bool showOptionsBar;
  final bool fitForPrint;
  final String? metricKey;
  final String? currencyCode;

  @override
  State<_GaugeChart> createState() => _GaugeChartState();
}

class _GaugeChartState extends State<_GaugeChart> {
  _ChartChromeOptions _options = const _ChartChromeOptions(
    showLegend: true,
    showAxisLabels: false,
  );

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final num value = widget.points.isEmpty ? 0 : widget.points.first.value;
    final num maxValue = widget.points.fold<num>(
      value,
      (num max, ModuleReportingSeriesPoint point) =>
          point.value > max ? point.value : max,
    );
    final double ratio = maxValue <= 0
        ? 0
        : (value / maxValue).clamp(0, 1).toDouble();
    final Color low = colors.tertiary;
    final Color mid = colors.primary;
    final Color high = colors.error;
    final Color needle = ratio < 0.33
        ? low
        : ratio < 0.66
        ? mid
        : high;
    final Locale locale = Localizations.localeOf(context);

    return _ChartSurface(
      title: widget.points.isEmpty ? 'Gauge' : widget.points.first.label,
      icon: Icons.speed_outlined,
      accent: needle,
      embedded: widget.embedded,
      toolbar: widget.showOptionsBar
          ? _ChartOptionsBar(
              options: _options,
              showAxisToggle: false,
              onChanged: (next) => setState(() => _options = next),
            )
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            height: widget.fitForPrint ? 160 : 180,
            width: double.infinity,
            child: CustomPaint(
              painter: _GaugePainter(
                ratio: ratio,
                color: needle,
                trackColor: colors.surfaceContainerHighest,
                lowColor: low,
                midColor: mid,
                highColor: high,
                labelColor: colors.onSurface,
                valueLabel: _options.showValues
                    ? moduleReportingFormatMetricValue(
                        value,
                        locale: locale,
                        columnKey: widget.points.isEmpty
                            ? widget.metricKey
                            : (widget.points.first.metricKey ??
                                  widget.metricKey),
                        currencyCode: widget.currencyCode,
                        compact: true,
                      )
                    : '',
                textStyle: theme.textTheme.titleMedium,
              ),
            ),
          ),
          if (_options.showLegend) ...<Widget>[
            SizedBox(height: theme.spacing.sm),
            _ChartLegendWrap(
              compact: widget.fitForPrint,
              labels: const <String>['Low', 'Mid', 'High'],
              colors: <Color>[low, mid, high],
            ),
          ],
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  const _GaugePainter({
    required this.ratio,
    required this.color,
    required this.trackColor,
    required this.lowColor,
    required this.midColor,
    required this.highColor,
    required this.labelColor,
    required this.valueLabel,
    required this.textStyle,
  });

  final double ratio;
  final Color color;
  final Color trackColor;
  final Color lowColor;
  final Color midColor;
  final Color highColor;
  final Color labelColor;
  final String valueLabel;
  final TextStyle? textStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height * 0.72);
    final double radius = math.min(size.width, size.height) * 0.42;
    final Rect arc = Rect.fromCircle(center: center, radius: radius);
    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round;

    const double start = math.pi;
    const double sweep = math.pi;
    stroke.color = trackColor;
    canvas.drawArc(arc, start, sweep, false, stroke);

    stroke.color = lowColor;
    canvas.drawArc(arc, start, sweep * 0.33, false, stroke);
    stroke.color = midColor;
    canvas.drawArc(arc, start + sweep * 0.33, sweep * 0.33, false, stroke);
    stroke.color = highColor;
    canvas.drawArc(arc, start + sweep * 0.66, sweep * 0.34, false, stroke);

    stroke
      ..color = color
      ..strokeWidth = 6;
    canvas.drawArc(arc, start, sweep * ratio, false, stroke);

    if (valueLabel.isEmpty) {
      return;
    }
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

class _ScatterChart extends StatefulWidget {
  const _ScatterChart({
    required this.snapshot,
    this.embedded = false,
    this.showOptionsBar = true,
    this.fitForPrint = false,
    this.currencyCode,
  });

  final ModuleReportingReportSnapshot snapshot;
  final bool embedded;
  final bool showOptionsBar;
  final bool fitForPrint;
  final String? currencyCode;

  @override
  State<_ScatterChart> createState() => _ScatterChartState();
}

class _ScatterChartState extends State<_ScatterChart> {
  _ChartChromeOptions _options = const _ChartChromeOptions(showLegend: false);

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final List<String> numeric = moduleReportingNumericColumns(
      widget.snapshot.columns,
    );
    if (numeric.length < 2) {
      return const SizedBox.shrink();
    }
    final String xKey = numeric[0];
    final String yKey = numeric[1];
    final String xLabel = moduleReportingColumnLabel(
      xKey,
      currencyCode: widget.currencyCode,
    );
    final String yLabel = moduleReportingColumnLabel(
      yKey,
      currencyCode: widget.currencyCode,
    );
    final List<Offset> points = <Offset>[
      for (final Map<String, Object?> row in widget.snapshot.rows.take(80))
        Offset(
          (moduleReportingAsNum(row[xKey]) ?? 0).toDouble(),
          (moduleReportingAsNum(row[yKey]) ?? 0).toDouble(),
        ),
    ];
    final List<Color> pointColors = <Color>[
      for (int index = 0; index < points.length; index += 1)
        dashboardFallbackSegmentColor(colors.primary, index % 12),
    ];

    return _ChartSurface(
      title: '$xLabel × $yLabel',
      icon: Icons.scatter_plot_outlined,
      accent: colors.secondary,
      embedded: widget.embedded,
      toolbar: widget.showOptionsBar
          ? _ChartOptionsBar(
              options: _options,
              showLegendToggle: false,
              showValuesToggle: false,
              onChanged: (next) => setState(() => _options = next),
            )
          : null,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double height = widget.fitForPrint
              ? 200
              : _chartHeightForWidth(
                  constraints.maxWidth.isFinite
                      ? constraints.maxWidth
                      : MediaQuery.sizeOf(context).width,
                );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (_options.showAxisLabels)
                Padding(
                  padding: EdgeInsets.only(bottom: theme.spacing.xs),
                  child: Text(
                    'Y: $yLabel',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              SizedBox(
                height: height,
                child: CustomPaint(
                  painter: _ScatterPainter(
                    points: points,
                    colors: pointColors,
                    gridColor: theme.borders.faint,
                  ),
                ),
              ),
              if (_options.showAxisLabels)
                Padding(
                  padding: EdgeInsets.only(top: theme.spacing.xs),
                  child: Text(
                    'X: $xLabel',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ScatterPainter extends CustomPainter {
  const _ScatterPainter({
    required this.points,
    required this.colors,
    required this.gridColor,
  });

  final List<Offset> points;
  final List<Color> colors;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (int i = 0; i <= 3; i += 1) {
      final double y = size.height * (i / 3);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
      final double x = size.width * (i / 3);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
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
    for (int index = 0; index < points.length; index += 1) {
      final Offset point = points[index];
      final double x = ((point.dx - minX) / spanX) * (size.width - 16) + 8;
      final double y =
          size.height - (((point.dy - minY) / spanY) * (size.height - 16) + 8);
      final Color color = colors[index % colors.length];
      canvas.drawCircle(
        Offset(x, y),
        5,
        Paint()..color = color.withValues(alpha: 0.85),
      );
      canvas.drawCircle(
        Offset(x, y),
        5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ScatterPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.colors != colors;
  }
}

class _HeatmapChart extends StatefulWidget {
  const _HeatmapChart({
    required this.cells,
    this.embedded = false,
    this.showOptionsBar = true,
    this.fitForPrint = false,
    this.metricKey,
    this.currencyCode,
  });

  final List<ModuleReportingHeatmapCell> cells;
  final bool embedded;
  final bool showOptionsBar;
  final bool fitForPrint;
  final String? metricKey;
  final String? currencyCode;

  @override
  State<_HeatmapChart> createState() => _HeatmapChartState();
}

class _HeatmapChartState extends State<_HeatmapChart> {
  _ChartChromeOptions _options = const _ChartChromeOptions(showLegend: true);

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    if (widget.cells.isEmpty) {
      return const SizedBox.shrink();
    }
    final List<String> rows = widget.cells
        .map((ModuleReportingHeatmapCell cell) => cell.rowKey)
        .toSet()
        .toList(growable: false);
    final List<String> columns = widget.cells
        .map((ModuleReportingHeatmapCell cell) => cell.columnKey)
        .toSet()
        .toList(growable: false);
    final Map<String, num> lookup = <String, num>{
      for (final ModuleReportingHeatmapCell cell in widget.cells)
        '${cell.rowKey}::${cell.columnKey}': cell.value,
    };
    final num maxValue = widget.cells.fold<num>(
      0,
      (num max, ModuleReportingHeatmapCell cell) =>
          cell.value > max ? cell.value : max,
    );
    final Locale locale = Localizations.localeOf(context);
    final List<Color> scale = <Color>[
      dashboardFallbackSegmentColor(colors.tertiary, 0).withValues(alpha: 0.25),
      dashboardFallbackSegmentColor(colors.primary, 2).withValues(alpha: 0.55),
      dashboardFallbackSegmentColor(colors.error, 4).withValues(alpha: 0.85),
    ];

    Color cellColor(num value) {
      if (maxValue <= 0) {
        return scale.first;
      }
      final double t = (value / maxValue).clamp(0, 1).toDouble();
      if (t < 0.5) {
        return Color.lerp(scale[0], scale[1], t * 2)!;
      }
      return Color.lerp(scale[1], scale[2], (t - 0.5) * 2)!;
    }

    return _ChartSurface(
      title: 'Heatmap',
      icon: Icons.grid_on_outlined,
      accent: colors.tertiary,
      embedded: widget.embedded,
      toolbar: widget.showOptionsBar
          ? _ChartOptionsBar(
              options: _options,
              showAxisToggle: true,
              onChanged: (next) => setState(() => _options = next),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (_options.showLegend) ...<Widget>[
            _ChartLegendWrap(
              compact: widget.fitForPrint,
              labels: const <String>['Low', 'Medium', 'High'],
              colors: scale,
            ),
            SizedBox(height: theme.spacing.sm),
          ],
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double cellWidth = constraints.maxWidth < 480 ? 56 : 72;
              final double labelWidth = constraints.maxWidth < 480 ? 72 : 96;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (_options.showAxisLabels)
                      Row(
                        children: <Widget>[
                          SizedBox(width: labelWidth),
                          for (final String column in columns)
                            SizedBox(
                              width: cellWidth,
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
                    if (_options.showAxisLabels)
                      SizedBox(height: theme.spacing.xs),
                    for (final String row in rows)
                      Padding(
                        padding: EdgeInsets.only(bottom: theme.spacing.xs),
                        child: Row(
                          children: <Widget>[
                            SizedBox(
                              width: labelWidth,
                              child: _options.showAxisLabels
                                  ? Text(
                                      row,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.labelSmall,
                                    )
                                  : null,
                            ),
                            for (final String column in columns)
                              Builder(
                                builder: (BuildContext context) {
                                  final num value =
                                      lookup['$row::$column'] ?? 0;
                                  final Color fill = cellColor(value);
                                  return Container(
                                    width: cellWidth,
                                    height: 36,
                                    margin: const EdgeInsets.only(right: 2),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: fill,
                                      borderRadius: BorderRadius.circular(
                                        theme.radius.sm,
                                      ),
                                      border: Border.all(
                                        color: fill.withValues(alpha: 0.9),
                                      ),
                                    ),
                                    child: _options.showValues
                                        ? Text(
                                            moduleReportingFormatMetricValue(
                                              value,
                                              locale: locale,
                                              columnKey: widget.metricKey,
                                              currencyCode: widget.currencyCode,
                                              compact: true,
                                            ),
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                                  color: colors.onSurface,
                                                  fontWeight:
                                                      AppFontWeight.emphasis,
                                                ),
                                          )
                                        : null,
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
