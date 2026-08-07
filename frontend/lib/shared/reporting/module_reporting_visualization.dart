import 'package:flutter/material.dart';
import 'package:hosspi_hms/shared/dashboard/dashboard.dart';
import 'package:hosspi_hms/shared/reporting/module_reporting_data.dart';
import 'package:hosspi_hms/shared/reporting/module_reporting_models.dart';
import 'package:hosspi_hms/shared/reporting/module_reporting_table.dart';

/// Supported report dialog visualization surfaces.
enum ModuleReportingVisualizationKind {
  kpiCards,
  lineChart,
  barChart,
  areaChart,
  donutChart,
  rankingChart,
  gaugeChart,
  scatterChart,
  heatmap,
  table,
}

/// One labeled numeric point projected from a report snapshot.
@immutable
final class ModuleReportingSeriesPoint {
  const ModuleReportingSeriesPoint({
    required this.label,
    required this.value,
    this.secondaryValue,
    this.category,
  });

  final String label;
  final num value;
  final num? secondaryValue;
  final String? category;
}

/// Heatmap cell projected from categorical × categorical report rows.
@immutable
final class ModuleReportingHeatmapCell {
  const ModuleReportingHeatmapCell({
    required this.rowKey,
    required this.columnKey,
    required this.value,
  });

  final String rowKey;
  final String columnKey;
  final num value;
}

String moduleReportingVisualizationLabel(ModuleReportingVisualizationKind kind) {
  return switch (kind) {
    ModuleReportingVisualizationKind.kpiCards => 'KPI cards',
    ModuleReportingVisualizationKind.lineChart => 'Line chart',
    ModuleReportingVisualizationKind.barChart => 'Bar chart',
    ModuleReportingVisualizationKind.areaChart => 'Area chart',
    ModuleReportingVisualizationKind.donutChart => 'Donut chart',
    ModuleReportingVisualizationKind.rankingChart => 'Ranking chart',
    ModuleReportingVisualizationKind.gaugeChart => 'Gauge chart',
    ModuleReportingVisualizationKind.scatterChart => 'Scatter chart',
    ModuleReportingVisualizationKind.heatmap => 'Heatmap',
    ModuleReportingVisualizationKind.table => 'Table',
  };
}

IconData moduleReportingVisualizationIcon(ModuleReportingVisualizationKind kind) {
  return switch (kind) {
    ModuleReportingVisualizationKind.kpiCards => Icons.dashboard_outlined,
    ModuleReportingVisualizationKind.lineChart => Icons.show_chart_outlined,
    ModuleReportingVisualizationKind.barChart => Icons.bar_chart_outlined,
    ModuleReportingVisualizationKind.areaChart => Icons.area_chart_outlined,
    ModuleReportingVisualizationKind.donutChart => Icons.donut_large_outlined,
    ModuleReportingVisualizationKind.rankingChart => Icons.leaderboard_outlined,
    ModuleReportingVisualizationKind.gaugeChart => Icons.speed_outlined,
    ModuleReportingVisualizationKind.scatterChart => Icons.scatter_plot_outlined,
    ModuleReportingVisualizationKind.heatmap => Icons.grid_on_outlined,
    ModuleReportingVisualizationKind.table => Icons.table_chart_outlined,
  };
}

List<Map<String, Object?>> moduleReportingSeriesSourceRows(
  ModuleReportingReportSnapshot snapshot,
) {
  final Object? daily = snapshot.breakdown?['daily_totals'];
  if (daily is List && daily.isNotEmpty) {
    return <Map<String, Object?>>[
      for (final Object? entry in daily)
        if (entry is Map)
          <String, Object?>{
            for (final MapEntry<dynamic, dynamic> item
                in Map<dynamic, dynamic>.from(entry).entries)
              item.key.toString(): item.value,
          },
    ];
  }
  return snapshot.rows;
}

String? moduleReportingLabelColumn(List<String> columns) {
  const List<String> preferred = <String>[
    'date',
    'period',
    'drug',
    'inventory_item',
    'facility',
    'order_source',
    'risk_state',
    'status',
    'name',
    'label',
  ];
  for (final String key in preferred) {
    if (columns.contains(key)) {
      return key;
    }
  }
  for (final String key in columns) {
    if (!moduleReportingIsNumericColumn(key) &&
        !moduleReportingIsDateColumn(key)) {
      return key;
    }
    if (moduleReportingIsDateColumn(key)) {
      return key;
    }
  }
  return columns.isEmpty ? null : columns.first;
}

List<String> moduleReportingNumericColumns(List<String> columns) {
  return columns
      .where(moduleReportingIsNumericColumn)
      .toList(growable: false);
}

num moduleReportingPrimaryNumeric(Map<String, Object?> row) {
  return moduleReportingAsNum(
        row['amount'] ??
            row['quantity_dispensed'] ??
            row['orders_created'] ??
            row['dispensed'] ??
            row['quantity'] ??
            row['value'] ??
            row['profit'] ??
            row['returns'],
      ) ??
      0;
}

List<ModuleReportingSeriesPoint> moduleReportingSeriesPoints(
  ModuleReportingReportSnapshot snapshot, {
  int limit = 40,
}) {
  final List<Map<String, Object?>> sourceRows =
      moduleReportingSeriesSourceRows(snapshot);
  final String? labelKey = moduleReportingLabelColumn(
    sourceRows.isEmpty
        ? snapshot.columns
        : sourceRows.first.keys.map((String key) => key).toList(growable: false),
  );
  final List<String> numericKeys = moduleReportingNumericColumns(
    sourceRows.isEmpty
        ? snapshot.columns
        : sourceRows.first.keys.toList(growable: false),
  );
  final String? secondaryKey =
      numericKeys.length >= 2 ? numericKeys[1] : null;

  final List<ModuleReportingSeriesPoint> points = <ModuleReportingSeriesPoint>[];
  for (final Map<String, Object?> row in sourceRows.take(limit)) {
    final String label =
        labelKey == null ? '' : '${row[labelKey] ?? ''}'.trim();
    final num value = moduleReportingPrimaryNumeric(row);
    if (label.isEmpty && value == 0) {
      continue;
    }
    points.add(
      ModuleReportingSeriesPoint(
        label: label.isEmpty ? '—' : label,
        value: value,
        secondaryValue: secondaryKey == null
            ? null
            : moduleReportingAsNum(row[secondaryKey]),
        category: row['category']?.toString() ??
            row['risk_state']?.toString() ??
            row['order_source']?.toString(),
      ),
    );
  }
  return points;
}

List<DashboardDistributionSegmentData> moduleReportingDistributionSegments(
  ModuleReportingReportSnapshot snapshot, {
  int limit = 12,
}) {
  final Object? mix =
      snapshot.breakdown?['source_mix'] ?? snapshot.summary?['source_mix'];
  if (mix is List && mix.isNotEmpty) {
    final List<DashboardDistributionSegmentData> fromMix =
        <DashboardDistributionSegmentData>[];
    for (final Object? entry in mix) {
      if (entry is! Map) {
        continue;
      }
      final Map<dynamic, dynamic> map = Map<dynamic, dynamic>.from(entry);
      final String label =
          '${map['order_source'] ?? map['channel'] ?? map['label'] ?? ''}';
      final num value =
          moduleReportingAsNum(
            map['quantity_dispensed'] ?? map['amount'] ?? map['value'],
          ) ??
          0;
      if (label.trim().isEmpty || value <= 0) {
        continue;
      }
      fromMix.add(
        DashboardDistributionSegmentData(label: label.trim(), value: value),
      );
      if (fromMix.length >= limit) {
        break;
      }
    }
    if (fromMix.isNotEmpty) {
      return fromMix;
    }
  }

  final Map<String, num> rolled = <String, num>{};
  final String? labelKey = moduleReportingLabelColumn(snapshot.columns);
  for (final Map<String, Object?> row in snapshot.rows) {
    final String label = labelKey == null
        ? ''
        : '${row[labelKey] ?? ''}'.trim();
    final num value = moduleReportingPrimaryNumeric(row);
    if (label.isEmpty || value <= 0) {
      continue;
    }
    rolled[label] = (rolled[label] ?? 0) + value;
  }
  final List<MapEntry<String, num>> ranked = rolled.entries.toList()
    ..sort(
      (MapEntry<String, num> left, MapEntry<String, num> right) =>
          right.value.compareTo(left.value),
    );
  return <DashboardDistributionSegmentData>[
    for (final MapEntry<String, num> entry in ranked.take(limit))
      DashboardDistributionSegmentData(label: entry.key, value: entry.value),
  ];
}

List<DashboardMetricCardData> moduleReportingKpiCards(
  ModuleReportingReportSnapshot snapshot, {
  int limit = 6,
}) {
  final List<DashboardMetricCardData> cards = <DashboardMetricCardData>[];
  final Map<String, Object?>? summary = snapshot.summary;
  if (summary != null && summary.isNotEmpty) {
    for (final MapEntry<String, Object?> entry in summary.entries) {
      if (entry.key == 'source_mix' || entry.value is Map || entry.value is List) {
        continue;
      }
      final num? number = moduleReportingAsNum(entry.value);
      if (number == null) {
        continue;
      }
      cards.add(
        DashboardMetricCardData(
          label: moduleReportingColumnLabel(entry.key),
          value: moduleReportingFormatCellValue(
            number,
            locale: const Locale('en'),
            unknownLabel: '—',
            preferNumeric: true,
          ),
          icon: Icons.analytics_outlined,
          semanticsLabel: entry.key,
          colorCode: cards.length % 2 == 0 ? 'primary' : 'info',
          compact: true,
        ),
      );
      if (cards.length >= limit) {
        return cards;
      }
    }
  }

  if (cards.isNotEmpty) {
    return cards;
  }

  final List<ModuleReportingSeriesPoint> points =
      moduleReportingSeriesPoints(snapshot, limit: 100);
  if (points.isEmpty) {
    return cards;
  }
  final num total = points.fold<num>(
    0,
    (num sum, ModuleReportingSeriesPoint point) => sum + point.value,
  );
  final ModuleReportingSeriesPoint top = points.reduce(
    (ModuleReportingSeriesPoint left, ModuleReportingSeriesPoint right) =>
        left.value >= right.value ? left : right,
  );
  return <DashboardMetricCardData>[
    DashboardMetricCardData(
      label: 'Total',
      value: moduleReportingFormatCellValue(
        total,
        locale: const Locale('en'),
        unknownLabel: '—',
        preferNumeric: true,
      ),
      icon: Icons.summarize_outlined,
      semanticsLabel: 'Total',
      colorCode: 'primary',
      compact: true,
    ),
    DashboardMetricCardData(
      label: 'Items',
      value: '${points.length}',
      icon: Icons.list_alt_outlined,
      semanticsLabel: 'Items',
      colorCode: 'info',
      compact: true,
    ),
    DashboardMetricCardData(
      label: 'Top',
      value: top.label,
      icon: Icons.emoji_events_outlined,
      semanticsLabel: 'Top item',
      colorCode: 'success',
      compact: true,
    ),
    DashboardMetricCardData(
      label: 'Top value',
      value: moduleReportingFormatCellValue(
        top.value,
        locale: const Locale('en'),
        unknownLabel: '—',
        preferNumeric: true,
      ),
      icon: Icons.trending_up_outlined,
      semanticsLabel: 'Top value',
      colorCode: 'warning',
      compact: true,
    ),
  ].take(limit).toList(growable: false);
}

List<ModuleReportingHeatmapCell> moduleReportingHeatmapCells(
  ModuleReportingReportSnapshot snapshot, {
  int maxRows = 8,
  int maxColumns = 8,
}) {
  final List<String> columns = snapshot.columns;
  final String? rowKey = columns.isEmpty
      ? null
      : (moduleReportingIsDateColumn(columns.first)
            ? columns.first
            : moduleReportingLabelColumn(columns));
  String? colKey;
  for (final String key in columns) {
    if (key == rowKey) {
      continue;
    }
    if (!moduleReportingIsNumericColumn(key) || moduleReportingIsDateColumn(key)) {
      if (key == 'batch_number') {
        continue;
      }
      colKey = key;
      break;
    }
  }
  if (rowKey == null || colKey == null) {
    final List<ModuleReportingSeriesPoint> points =
        moduleReportingSeriesPoints(snapshot, limit: maxRows * maxColumns);
    return <ModuleReportingHeatmapCell>[
      for (int index = 0; index < points.length; index += 1)
        ModuleReportingHeatmapCell(
          rowKey: points[index].label,
          columnKey: 'Value',
          value: points[index].value,
        ),
    ];
  }

  final Map<String, Map<String, num>> grid = <String, Map<String, num>>{};
  for (final Map<String, Object?> row in snapshot.rows) {
    final String r = '${row[rowKey] ?? ''}'.trim();
    final String c = '${row[colKey] ?? ''}'.trim();
    if (r.isEmpty || c.isEmpty) {
      continue;
    }
    grid.putIfAbsent(r, () => <String, num>{});
    grid[r]![c] = (grid[r]![c] ?? 0) + moduleReportingPrimaryNumeric(row);
  }
  final List<String> rowKeys = grid.keys.take(maxRows).toList(growable: false);
  final Set<String> columnKeys = <String>{
    for (final String row in rowKeys) ...?grid[row]?.keys,
  };
  final List<String> limitedColumns =
      columnKeys.take(maxColumns).toList(growable: false);
  return <ModuleReportingHeatmapCell>[
    for (final String row in rowKeys)
      for (final String column in limitedColumns)
        ModuleReportingHeatmapCell(
          rowKey: row,
          columnKey: column,
          value: grid[row]?[column] ?? 0,
        ),
  ];
}

bool moduleReportingHasScatterAxes(ModuleReportingReportSnapshot snapshot) {
  final List<String> numeric = moduleReportingNumericColumns(snapshot.columns);
  return numeric.length >= 2 && snapshot.rows.length >= 2;
}

bool moduleReportingHasHeatmapShape(ModuleReportingReportSnapshot snapshot) {
  if (snapshot.rows.length < 2) {
    return false;
  }
  final List<String> categorical = snapshot.columns
      .where(
        (String key) =>
            !moduleReportingIsNumericColumn(key) ||
            moduleReportingIsDateColumn(key),
      )
      .toList(growable: false);
  final List<String> numeric = moduleReportingNumericColumns(snapshot.columns);
  return categorical.length >= 2 && numeric.isNotEmpty;
}

/// Returns visualization kinds that can meaningfully render [snapshot] data.
List<ModuleReportingVisualizationKind> moduleReportingApplicableVisualizations(
  ModuleReportingReportSnapshot snapshot,
) {
  if (!snapshot.hasRows && (snapshot.summary == null || snapshot.summary!.isEmpty)) {
    return const <ModuleReportingVisualizationKind>[];
  }

  final List<ModuleReportingVisualizationKind> kinds =
      <ModuleReportingVisualizationKind>[];
  final List<ModuleReportingSeriesPoint> series =
      moduleReportingSeriesPoints(snapshot);
  final List<DashboardDistributionSegmentData> segments =
      moduleReportingDistributionSegments(snapshot);
  final List<DashboardMetricCardData> kpis = moduleReportingKpiCards(snapshot);

  if (kpis.isNotEmpty) {
    kinds.add(ModuleReportingVisualizationKind.kpiCards);
  }
  if (series.length >= 2) {
    kinds.add(ModuleReportingVisualizationKind.lineChart);
    kinds.add(ModuleReportingVisualizationKind.barChart);
    kinds.add(ModuleReportingVisualizationKind.areaChart);
  }
  if (segments.length >= 2) {
    kinds.add(ModuleReportingVisualizationKind.donutChart);
    kinds.add(ModuleReportingVisualizationKind.rankingChart);
  }
  if (series.isNotEmpty) {
    kinds.add(ModuleReportingVisualizationKind.gaugeChart);
  }
  if (moduleReportingHasScatterAxes(snapshot)) {
    kinds.add(ModuleReportingVisualizationKind.scatterChart);
  }
  if (moduleReportingHasHeatmapShape(snapshot) || series.length >= 2) {
    kinds.add(ModuleReportingVisualizationKind.heatmap);
  }
  if (snapshot.hasRows) {
    kinds.add(ModuleReportingVisualizationKind.table);
  }
  return kinds;
}

ModuleReportingVisualizationKind moduleReportingDefaultVisualization({
  required List<ModuleReportingVisualizationKind> applicable,
  ModuleReportingContentKind preferred = ModuleReportingContentKind.table,
}) {
  if (applicable.isEmpty) {
    return ModuleReportingVisualizationKind.table;
  }
  if (preferred == ModuleReportingContentKind.chart) {
    const List<ModuleReportingVisualizationKind> chartPreference =
        <ModuleReportingVisualizationKind>[
          ModuleReportingVisualizationKind.lineChart,
          ModuleReportingVisualizationKind.areaChart,
          ModuleReportingVisualizationKind.barChart,
          ModuleReportingVisualizationKind.donutChart,
          ModuleReportingVisualizationKind.rankingChart,
          ModuleReportingVisualizationKind.kpiCards,
        ];
    for (final ModuleReportingVisualizationKind kind in chartPreference) {
      if (applicable.contains(kind)) {
        return kind;
      }
    }
  }
  if (applicable.contains(ModuleReportingVisualizationKind.table)) {
    return ModuleReportingVisualizationKind.table;
  }
  return applicable.first;
}
