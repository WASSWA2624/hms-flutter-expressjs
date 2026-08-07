import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/shared/reporting/module_reporting_data.dart';
import 'package:hosspi_hms/shared/reporting/module_reporting_models.dart';
import 'package:hosspi_hms/shared/reporting/module_reporting_visualization.dart';

void main() {
  ModuleReportingReportSnapshot readyRows({
    required List<String> columns,
    required List<Map<String, Object?>> rows,
    Map<String, Object?>? summary,
    Map<String, Object?>? breakdown,
  }) {
    return ModuleReportingReportSnapshot.ready(
      columns: columns,
      rows: rows,
      summary: summary,
      breakdown: breakdown,
    );
  }

  test('period series unlocks line/bar/area/table/kpi visualizations', () {
    final ModuleReportingReportSnapshot snapshot = readyRows(
      columns: const <String>['date', 'amount', 'quantity_dispensed'],
      rows: <Map<String, Object?>>[
        for (int i = 0; i < 5; i++)
          <String, Object?>{
            'date': '2026-08-0${i + 1}',
            'amount': (i + 1) * 100,
            'quantity_dispensed': i + 2,
          },
      ],
      summary: const <String, Object?>{'amount': 1500, 'quantity_dispensed': 20},
    );

    final List<ModuleReportingVisualizationKind> applicable =
        moduleReportingApplicableVisualizations(snapshot);

    expect(applicable, contains(ModuleReportingVisualizationKind.table));
    expect(applicable, contains(ModuleReportingVisualizationKind.kpiCards));
    expect(applicable, contains(ModuleReportingVisualizationKind.lineChart));
    expect(applicable, contains(ModuleReportingVisualizationKind.barChart));
    expect(applicable, contains(ModuleReportingVisualizationKind.areaChart));
    expect(applicable, contains(ModuleReportingVisualizationKind.scatterChart));
    expect(
      moduleReportingDefaultVisualization(
        applicable: applicable,
        preferred: ModuleReportingContentKind.chart,
      ),
      ModuleReportingVisualizationKind.lineChart,
    );
  });

  test('category mix unlocks donut and ranking', () {
    final ModuleReportingReportSnapshot snapshot = readyRows(
      columns: const <String>['drug', 'amount'],
      rows: const <Map<String, Object?>>[
        <String, Object?>{'drug': 'Amox', 'amount': 40},
        <String, Object?>{'drug': 'Para', 'amount': 25},
        <String, Object?>{'drug': 'Ibuprofen', 'amount': 10},
      ],
      breakdown: const <String, Object?>{
        'source_mix': <Map<String, Object?>>[
          <String, Object?>{
            'order_source': 'PHARMACY',
            'quantity_dispensed': 12,
          },
          <String, Object?>{
            'order_source': 'CLINICAL',
            'quantity_dispensed': 8,
          },
        ],
      },
    );

    final List<ModuleReportingVisualizationKind> applicable =
        moduleReportingApplicableVisualizations(snapshot);

    expect(applicable, contains(ModuleReportingVisualizationKind.donutChart));
    expect(applicable, contains(ModuleReportingVisualizationKind.rankingChart));
    expect(
      moduleReportingDistributionSegments(snapshot),
      hasLength(2),
    );
  });

  test('empty snapshot yields no visualizations', () {
    final ModuleReportingReportSnapshot snapshot =
        ModuleReportingReportSnapshot.ready(
          columns: const <String>['drug'],
          rows: const <Map<String, Object?>>[],
        );
    expect(moduleReportingApplicableVisualizations(snapshot), isEmpty);
  });
}
