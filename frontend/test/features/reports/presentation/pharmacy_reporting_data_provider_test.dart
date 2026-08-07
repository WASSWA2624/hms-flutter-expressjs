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

  test('overstock stays honest-empty ready state', () {
    final ReportDatasetPreview preview = ReportDatasetPreview(
      datasetKey: 'inventory_stock_risk',
      columns: const <String>['inventory_item', 'risk_state'],
      rows: const <Map<String, Object?>>[
        <String, Object?>{'inventory_item': 'A', 'risk_state': 'LOW'},
      ],
    );

    final ModuleReportingReportSnapshot snapshot =
        projectPharmacyReportingPreview(
          report: overstockReport,
          preview: preview,
        );

    expect(snapshot.state, ModuleReportingLoadState.empty);
    expect(snapshot.rows, isEmpty);
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
}
