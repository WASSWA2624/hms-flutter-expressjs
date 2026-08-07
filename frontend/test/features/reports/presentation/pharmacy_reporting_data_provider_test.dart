import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/reports/domain/entities/reports_entities.dart';
import 'package:hosspi_hms/features/reports/presentation/widgets/pharmacy_reporting_data_provider.dart';
import 'package:hosspi_hms/shared/reporting/reporting.dart';

void main() {
  const ModuleReportingReport consumptionReport = ModuleReportingReport(
    id: 'top_selling_medicines',
    categoryId: 'operational_kpis',
    label: 'Top 10 selling medicines',
    datasetKey: 'pharmacy_drug_consumption',
  );

  const ModuleReportingReport expiredReport = ModuleReportingReport(
    id: 'expired_stock',
    categoryId: 'inventory_stock',
    label: 'Expired stock',
    datasetKey: 'inventory_stock_risk',
  );

  const ModuleReportingReport overstockReport = ModuleReportingReport(
    id: 'overstock',
    categoryId: 'inventory_stock',
    label: 'Overstock',
    datasetKey: 'inventory_stock_risk',
  );

  const ModuleReportingReport trendReport = ModuleReportingReport(
    id: 'sales_by_period',
    categoryId: 'sales_revenue',
    label: 'Sales by period',
    contentKind: ModuleReportingContentKind.chart,
    datasetKey: 'pharmacy_drug_consumption',
  );

  test('projects top selling medicines to top 20 by amount', () {
    final ReportDatasetPreview preview = ReportDatasetPreview(
      datasetKey: 'pharmacy_drug_consumption',
      title: 'Consumption',
      columns: const <String>['drug', 'amount'],
      rows: <Map<String, Object?>>[
        for (int i = 0; i < 25; i++)
          <String, Object?>{'drug': 'Drug $i', 'amount': i.toDouble()},
      ],
    );

    final ModuleReportingReportSnapshot snapshot =
        projectPharmacyReportingPreview(
          report: consumptionReport,
          preview: preview,
        );

    expect(snapshot.state, ModuleReportingLoadState.ready);
    expect(snapshot.rows, hasLength(20));
    expect(snapshot.rows.first['drug'], 'Drug 24');
  });

  test('filters expired stock by risk_state', () {
    final ReportDatasetPreview preview = ReportDatasetPreview(
      datasetKey: 'inventory_stock_risk',
      columns: const <String>['inventory_item', 'risk_state', 'quantity'],
      rows: const <Map<String, Object?>>[
        <String, Object?>{
          'inventory_item': 'A',
          'risk_state': 'EXPIRED',
          'quantity': 2,
        },
        <String, Object?>{
          'inventory_item': 'B',
          'risk_state': 'LOW',
          'quantity': 1,
        },
        <String, Object?>{
          'inventory_item': 'C',
          'risk_state': 'EXPIRED',
          'quantity': 0,
        },
      ],
    );

    final ModuleReportingReportSnapshot snapshot =
        projectPharmacyReportingPreview(
          report: expiredReport,
          preview: preview,
        );

    expect(snapshot.state, ModuleReportingLoadState.ready);
    expect(snapshot.rows, hasLength(2));
    expect(
      snapshot.rows.every(
        (Map<String, Object?> row) => row['risk_state'] == 'EXPIRED',
      ),
      isTrue,
    );
  });

  test('overstock projects OVERSTOCK risk rows', () {
    final ReportDatasetPreview preview = ReportDatasetPreview(
      datasetKey: 'inventory_stock_risk',
      columns: const <String>['inventory_item', 'risk_state', 'quantity'],
      rows: const <Map<String, Object?>>[
        <String, Object?>{
          'inventory_item': 'A',
          'risk_state': 'LOW',
          'quantity': 4,
        },
        <String, Object?>{
          'inventory_item': 'B',
          'risk_state': 'OVERSTOCK',
          'quantity': 900,
        },
        <String, Object?>{
          'inventory_item': 'C',
          'risk_state': 'OK',
          'quantity': 120,
        },
      ],
    );

    final ModuleReportingReportSnapshot snapshot =
        projectPharmacyReportingPreview(
          report: overstockReport,
          preview: preview,
        );

    expect(snapshot.state, ModuleReportingLoadState.ready);
    expect(snapshot.rows, hasLength(1));
    expect(snapshot.rows.single['inventory_item'], 'B');
  });

  test('sales by period prefers breakdown daily_totals', () {
    final ReportDatasetPreview preview = ReportDatasetPreview(
      datasetKey: 'pharmacy_drug_consumption',
      columns: const <String>['drug', 'amount'],
      rows: const <Map<String, Object?>>[
        <String, Object?>{'drug': 'Amox', 'amount': 10},
      ],
      breakdown: const <String, Object?>{
        'daily_totals': <Map<String, Object?>>[
          <String, Object?>{'date': '2026-01-01', 'amount': 4},
          <String, Object?>{'date': '2026-01-02', 'amount': 6},
        ],
      },
    );

    final ModuleReportingReportSnapshot snapshot =
        projectPharmacyReportingPreview(
          report: trendReport,
          preview: preview,
        );

    expect(snapshot.state, ModuleReportingLoadState.ready);
    expect(snapshot.rows, hasLength(2));
    expect(snapshot.columns, contains('date'));
    expect(snapshot.rows.first['date'], '2026-01-01');
  });

  test('total sales summary amount uses period daily_totals', () {
    const ModuleReportingReport totalSales = ModuleReportingReport(
      id: 'total_sales',
      categoryId: 'sales_revenue',
      label: 'Total sales',
      datasetKey: 'pharmacy_drug_consumption',
    );
    final ReportDatasetPreview preview = ReportDatasetPreview(
      datasetKey: 'pharmacy_drug_consumption',
      columns: const <String>['drug', 'amount'],
      rows: const <Map<String, Object?>>[
        <String, Object?>{'drug': 'Amox', 'amount': 10},
      ],
      summary: const <String, Object?>{'amount': 10},
      breakdown: const <String, Object?>{
        'daily_totals': <Map<String, Object?>>[
          <String, Object?>{'date': '2026-01-01', 'amount': 40},
          <String, Object?>{'date': '2026-01-02', 'amount': 60},
        ],
      },
    );

    final ModuleReportingReportSnapshot snapshot =
        projectPharmacyReportingPreview(
          report: totalSales,
          preview: preview,
        );

    expect(snapshot.state, ModuleReportingLoadState.ready);
    expect(snapshot.summary?['amount'], 100);
  });

  test('profit and margin projects null margin when buy missing', () {
    const ModuleReportingReport marginReport = ModuleReportingReport(
      id: 'profit_and_margin',
      categoryId: 'sales_revenue',
      label: 'Profit and profit margin',
      datasetKey: 'pharmacy_drug_consumption',
    );
    final ReportDatasetPreview preview = ReportDatasetPreview(
      datasetKey: 'pharmacy_drug_consumption',
      columns: const <String>['drug', 'amount', 'profit'],
      rows: const <Map<String, Object?>>[
        <String, Object?>{'drug': 'A', 'amount': 100, 'profit': 25},
        <String, Object?>{'drug': 'B', 'amount': 50, 'profit': null},
      ],
      summary: const <String, Object?>{'amount': 150, 'profit': 25},
    );

    final ModuleReportingReportSnapshot snapshot =
        projectPharmacyReportingPreview(
          report: marginReport,
          preview: preview,
        );

    expect(snapshot.state, ModuleReportingLoadState.ready);
    expect(snapshot.columns, contains('profit_margin'));
    expect(snapshot.rows.first['profit_margin'], 0.25);
    expect(snapshot.rows[1]['profit_margin'], isNull);
    expect(snapshot.summary?['profit_margin'], closeTo(25 / 150, 0.0001));
  });

  test('fast moving filters velocity_class FAST', () {
    const ModuleReportingReport fastReport = ModuleReportingReport(
      id: 'fast_moving',
      categoryId: 'inventory_stock',
      label: 'Fast-moving products',
      datasetKey: 'inventory_stock_velocity',
    );
    final ReportDatasetPreview preview = ReportDatasetPreview(
      datasetKey: 'inventory_stock_velocity',
      columns: const <String>[
        'inventory_item',
        'velocity_class',
        'issued_quantity',
      ],
      rows: const <Map<String, Object?>>[
        <String, Object?>{
          'inventory_item': 'A',
          'velocity_class': 'FAST',
          'issued_quantity': 40,
        },
        <String, Object?>{
          'inventory_item': 'B',
          'velocity_class': 'DEAD',
          'issued_quantity': 0,
        },
        <String, Object?>{
          'inventory_item': 'C',
          'velocity_class': 'SLOW',
          'issued_quantity': 2,
        },
      ],
    );

    final ModuleReportingReportSnapshot snapshot =
        projectPharmacyReportingPreview(
          report: fastReport,
          preview: preview,
        );

    expect(snapshot.state, ModuleReportingLoadState.ready);
    expect(snapshot.rows, hasLength(1));
    expect(snapshot.rows.single['inventory_item'], 'A');
  });

  test('reorder quantity keeps only positive reorder_quantity rows', () {
    const ModuleReportingReport reorderReport = ModuleReportingReport(
      id: 'reorder_quantity',
      categoryId: 'inventory_stock',
      label: 'Reorder quantity',
      datasetKey: 'inventory_reorder',
    );
    final ReportDatasetPreview preview = ReportDatasetPreview(
      datasetKey: 'inventory_reorder',
      columns: const <String>[
        'inventory_item',
        'quantity',
        'reorder_level',
        'reorder_quantity',
      ],
      rows: const <Map<String, Object?>>[
        <String, Object?>{
          'inventory_item': 'A',
          'quantity': 5,
          'reorder_level': 20,
          'reorder_quantity': 15,
        },
        <String, Object?>{
          'inventory_item': 'B',
          'quantity': 50,
          'reorder_level': 20,
          'reorder_quantity': 0,
        },
      ],
    );

    final ModuleReportingReportSnapshot snapshot =
        projectPharmacyReportingPreview(
          report: reorderReport,
          preview: preview,
        );

    expect(snapshot.state, ModuleReportingLoadState.ready);
    expect(snapshot.rows, hasLength(1));
    expect(snapshot.rows.single['inventory_item'], 'A');
  });
}
