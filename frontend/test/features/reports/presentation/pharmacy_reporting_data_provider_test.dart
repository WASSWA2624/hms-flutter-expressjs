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

  test('medicines catalog projects drug and batch column subsets', () {
    const ModuleReportingReport nameReport = ModuleReportingReport(
      id: 'medicine_name',
      categoryId: 'medicines_products',
      label: 'Medicine name',
      datasetKey: 'pharmacy_medicines_catalog',
    );
    const ModuleReportingReport batchReport = ModuleReportingReport(
      id: 'batch_lot',
      categoryId: 'medicines_products',
      label: 'Batch/lot number',
      datasetKey: 'pharmacy_medicines_catalog',
    );
    final ReportDatasetPreview preview = ReportDatasetPreview(
      datasetKey: 'pharmacy_medicines_catalog',
      subtitle: 'Catalog as of 2026-08-07',
      columns: const <String>[
        'row_kind',
        'name',
        'code',
        'human_friendly_id',
        'batch_number',
        'quantity',
        'expiry_date',
        'strength',
        'selling_price',
      ],
      rows: const <Map<String, Object?>>[
        <String, Object?>{
          'row_kind': 'drug',
          'name': 'Paracetamol',
          'code': 'PCM500',
          'human_friendly_id': 'DRG-1',
          'batch_number': null,
          'quantity': null,
          'expiry_date': null,
          'strength': '500 mg',
          'selling_price': 2050,
        },
        <String, Object?>{
          'row_kind': 'batch',
          'name': 'Paracetamol',
          'code': 'PCM500',
          'human_friendly_id': 'DRG-1',
          'batch_number': 'PCM500A',
          'quantity': 100,
          'expiry_date': '2027-01-01',
          'strength': '500 mg',
          'selling_price': 2050,
        },
      ],
    );

    final ModuleReportingReportSnapshot nameSnapshot =
        projectPharmacyReportingPreview(
          report: nameReport,
          preview: preview,
        );
    expect(nameSnapshot.state, ModuleReportingLoadState.ready);
    expect(nameSnapshot.columns, <String>['name', 'code', 'human_friendly_id']);
    expect(nameSnapshot.rows, hasLength(1));
    expect(nameSnapshot.rows.single['name'], 'Paracetamol');

    final ModuleReportingReportSnapshot batchSnapshot =
        projectPharmacyReportingPreview(
          report: batchReport,
          preview: preview,
        );
    expect(batchSnapshot.state, ModuleReportingLoadState.ready);
    expect(batchSnapshot.rows, hasLength(1));
    expect(batchSnapshot.rows.single['batch_number'], 'PCM500A');
  });

  test('items_dispensed keeps pack quantity from consumption', () {
    const ModuleReportingReport itemsReport = ModuleReportingReport(
      id: 'items_dispensed',
      categoryId: 'dispensing',
      label: 'Number of items dispensed',
      datasetKey: 'pharmacy_drug_consumption',
    );
    final ReportDatasetPreview preview = ReportDatasetPreview(
      datasetKey: 'pharmacy_drug_consumption',
      columns: const <String>['drug', 'quantity_dispensed', 'amount'],
      rows: const <Map<String, Object?>>[
        <String, Object?>{'drug': 'Amox', 'quantity_dispensed': 12, 'amount': 100},
      ],
      summary: const <String, Object?>{'quantity_dispensed': 12},
    );

    final ModuleReportingReportSnapshot snapshot =
        projectPharmacyReportingPreview(
          report: itemsReport,
          preview: preview,
        );

    expect(snapshot.state, ModuleReportingLoadState.ready);
    expect(snapshot.rows.single['quantity_dispensed'], 12);
    expect(snapshot.subtitle, contains('Pack quantity'));
  });

  test('medicines_dispensed_by_period projects pack qty series', () {
    const ModuleReportingReport periodReport = ModuleReportingReport(
      id: 'medicines_dispensed_by_period',
      categoryId: 'dispensing',
      label: 'Medicines dispensed by period',
      contentKind: ModuleReportingContentKind.chart,
      datasetKey: 'pharmacy_drug_consumption',
    );
    final ReportDatasetPreview preview = ReportDatasetPreview(
      datasetKey: 'pharmacy_drug_consumption',
      columns: const <String>['drug', 'quantity_dispensed'],
      rows: const <Map<String, Object?>>[
        <String, Object?>{'drug': 'Amox', 'quantity_dispensed': 5},
      ],
      summary: const <String, Object?>{'quantity_dispensed': 9},
      breakdown: const <String, Object?>{
        'daily_totals': <Map<String, Object?>>[
          <String, Object?>{'date': '2026-01-01', 'quantity_dispensed': 4, 'amount': 10},
          <String, Object?>{'date': '2026-01-02', 'quantity_dispensed': 5, 'amount': 20},
        ],
      },
    );

    final ModuleReportingReportSnapshot snapshot =
        projectPharmacyReportingPreview(
          report: periodReport,
          preview: preview,
        );

    expect(snapshot.state, ModuleReportingLoadState.ready);
    expect(snapshot.columns, <String>['date', 'quantity_dispensed']);
    expect(snapshot.rows, hasLength(2));
    expect(snapshot.subtitle, contains('Pack quantity'));
  });

  test('prescription_status and voids project distinct throughput breakdowns', () {
    const ModuleReportingReport statusReport = ModuleReportingReport(
      id: 'prescription_status',
      categoryId: 'dispensing',
      label: 'Prescription status',
      datasetKey: 'pharmacy_dispense_throughput',
    );
    const ModuleReportingReport voidsReport = ModuleReportingReport(
      id: 'dispensing_errors_voids',
      categoryId: 'dispensing',
      label: 'Dispensing errors/voids',
      datasetKey: 'pharmacy_dispense_throughput',
    );
    final ReportDatasetPreview preview = ReportDatasetPreview(
      datasetKey: 'pharmacy_dispense_throughput',
      columns: const <String>['date', 'orders_created', 'cancelled', 'returns'],
      rows: const <Map<String, Object?>>[
        <String, Object?>{
          'date': '2026-01-01',
          'orders_created': 5,
          'cancelled': 1,
          'returns': 2,
        },
      ],
      summary: const <String, Object?>{
        'orders_created': 5,
        'cancelled': 1,
        'returns': 2,
      },
      breakdown: const <String, Object?>{
        'status_totals': <Map<String, Object?>>[
          <String, Object?>{'status': 'DISPENSED', 'orders_created': 3},
          <String, Object?>{'status': 'CANCELLED', 'orders_created': 1},
        ],
        'voids': <Map<String, Object?>>[
          <String, Object?>{'void_type': 'CANCELLED_ORDERS', 'void_count': 1},
          <String, Object?>{'void_type': 'RETURNED_LOGS', 'void_count': 2},
        ],
      },
    );

    final ModuleReportingReportSnapshot statusSnapshot =
        projectPharmacyReportingPreview(
          report: statusReport,
          preview: preview,
        );
    expect(statusSnapshot.rows, hasLength(2));
    expect(statusSnapshot.rows.first['status'], 'DISPENSED');

    final ModuleReportingReportSnapshot voidsSnapshot =
        projectPharmacyReportingPreview(
          report: voidsReport,
          preview: preview,
        );
    expect(voidsSnapshot.rows, hasLength(2));
    expect(voidsSnapshot.rows.first['void_type'], 'CANCELLED_ORDERS');
    expect(voidsSnapshot.rows[1]['void_type'], 'RETURNED_LOGS');
    expect(voidsSnapshot.rows.first['void_count'], isNot(voidsSnapshot.rows[1]['void_count']));
  });

  test('medicines_dispensed_by_patient drops amount column', () {
    const ModuleReportingReport patientReport = ModuleReportingReport(
      id: 'medicines_dispensed_by_patient',
      categoryId: 'dispensing',
      label: 'Medicines dispensed by patient',
      datasetKey: 'pharmacy_sales_by_customer',
    );
    final ReportDatasetPreview preview = ReportDatasetPreview(
      datasetKey: 'pharmacy_sales_by_customer',
      columns: const <String>['patient', 'amount', 'quantity_dispensed'],
      rows: const <Map<String, Object?>>[
        <String, Object?>{
          'patient': 'PAT-1 · Amina',
          'amount': 500,
          'quantity_dispensed': 8,
        },
      ],
      summary: const <String, Object?>{'amount': 500, 'quantity_dispensed': 8},
    );

    final ModuleReportingReportSnapshot snapshot =
        projectPharmacyReportingPreview(
          report: patientReport,
          preview: preview,
        );

    expect(snapshot.columns, <String>['patient', 'quantity_dispensed']);
    expect(snapshot.rows.single.containsKey('amount'), isFalse);
  });

  test('expiring windows buckets dayOffset 8 into 0-30 and excludes expired', () {
    const ModuleReportingReport windowsReport = ModuleReportingReport(
      id: 'expiring_windows',
      categoryId: 'expiry_loss',
      label: 'Medicines expiring within 30/60/90/180 days',
      datasetKey: 'inventory_stock_risk',
    );
    final ReportDatasetPreview preview = ReportDatasetPreview(
      datasetKey: 'inventory_stock_risk',
      columns: const <String>[
        'inventory_item',
        'risk_state',
        'days_to_expiry',
        'quantity',
        'value',
      ],
      rows: const <Map<String, Object?>>[
        <String, Object?>{
          'inventory_item': 'Near8',
          'risk_state': 'EXPIRING_SOON',
          'days_to_expiry': 8,
          'quantity': 36,
          'value': 23400,
        },
        <String, Object?>{
          'inventory_item': 'Win52',
          'risk_state': 'EXPIRING_SOON',
          'days_to_expiry': 52,
          'quantity': 40,
          'value': 26000,
        },
        <String, Object?>{
          'inventory_item': 'Win78',
          'risk_state': 'EXPIRING_SOON',
          'days_to_expiry': 78,
          'quantity': 30,
          'value': 19500,
        },
        <String, Object?>{
          'inventory_item': 'Win145',
          'risk_state': 'EXPIRING_SOON',
          'days_to_expiry': 145,
          'quantity': 45,
          'value': 29250,
        },
        <String, Object?>{
          'inventory_item': 'Expired14',
          'risk_state': 'EXPIRED',
          'days_to_expiry': -14,
          'quantity': 22,
          'value': 14300,
        },
      ],
    );

    final ModuleReportingReportSnapshot snapshot =
        projectPharmacyReportingPreview(
          report: windowsReport,
          preview: preview,
        );

    expect(snapshot.state, ModuleReportingLoadState.ready);
    expect(snapshot.rows, hasLength(4));
    expect(snapshot.columns, contains('expiry_window'));
    expect(
      snapshot.rows.map((Map<String, Object?> row) => row['expiry_window']),
      containsAll(<String>['0-30', '30-60', '60-90', '90-180']),
    );
    expect(
      snapshot.rows.any(
        (Map<String, Object?> row) => row['inventory_item'] == 'Expired14',
      ),
      isFalse,
    );
    expect(classifyPharmacyExpiryWindow(8), '0-30');
    expect(classifyPharmacyExpiryWindow(-14), isNull);
  });

  test('expired stock value uses buy-cost value and dayOffset −14 value > 0', () {
    const ModuleReportingReport valueReport = ModuleReportingReport(
      id: 'expired_stock_value',
      categoryId: 'expiry_loss',
      label: 'Value of expired stock',
      datasetKey: 'inventory_stock_risk',
    );
    final ReportDatasetPreview preview = ReportDatasetPreview(
      datasetKey: 'inventory_stock_risk',
      columns: const <String>[
        'inventory_item',
        'risk_state',
        'days_to_expiry',
        'quantity',
        'value',
      ],
      rows: const <Map<String, Object?>>[
        <String, Object?>{
          'inventory_item': 'Expired14',
          'risk_state': 'EXPIRED',
          'days_to_expiry': -14,
          'quantity': 22,
          'value': 14300,
        },
        <String, Object?>{
          'inventory_item': 'Near8',
          'risk_state': 'EXPIRING_SOON',
          'days_to_expiry': 8,
          'quantity': 36,
          'value': 23400,
        },
      ],
    );

    final ModuleReportingReportSnapshot snapshot =
        projectPharmacyReportingPreview(
          report: valueReport,
          preview: preview,
        );

    expect(snapshot.state, ModuleReportingLoadState.ready);
    expect(snapshot.rows, hasLength(1));
    expect(snapshot.rows.single['inventory_item'], 'Expired14');
    expect(snapshot.rows.single['value'], greaterThan(0));
    expect(snapshot.summary?['value'], 14300);
    expect(snapshot.subtitle, contains('buy cost'));
  });

  test('expiry losses breakdown aggregates expired by drug/category/supplier', () {
    const ModuleReportingReport breakdownReport = ModuleReportingReport(
      id: 'expiry_losses_breakdown',
      categoryId: 'expiry_loss',
      label: 'Expiry losses by product/category/supplier',
      datasetKey: 'inventory_stock_risk',
    );
    final ReportDatasetPreview preview = ReportDatasetPreview(
      datasetKey: 'inventory_stock_risk',
      columns: const <String>[
        'drug',
        'category',
        'supplier_id',
        'supplier',
        'risk_state',
        'quantity',
        'value',
      ],
      rows: const <Map<String, Object?>>[
        <String, Object?>{
          'drug': 'Amox',
          'category': 'MEDICATION',
          'supplier_id': 'sup-1',
          'supplier': 'Acme',
          'risk_state': 'EXPIRED',
          'quantity': 10,
          'value': 6500,
        },
        <String, Object?>{
          'drug': 'Amox',
          'category': 'MEDICATION',
          'supplier_id': 'sup-1',
          'supplier': 'Acme',
          'risk_state': 'EXPIRED',
          'quantity': 5,
          'value': 3250,
        },
        <String, Object?>{
          'drug': 'Near',
          'category': 'MEDICATION',
          'supplier_id': 'sup-1',
          'supplier': 'Acme',
          'risk_state': 'EXPIRING_SOON',
          'quantity': 8,
          'value': 5200,
        },
      ],
    );

    final ModuleReportingReportSnapshot snapshot =
        projectPharmacyReportingPreview(
          report: breakdownReport,
          preview: preview,
        );

    expect(snapshot.state, ModuleReportingLoadState.ready);
    expect(snapshot.rows, hasLength(1));
    expect(snapshot.rows.single['drug'], 'Amox');
    expect(snapshot.rows.single['quantity'], 15);
    expect(snapshot.rows.single['value'], 9750);
  });
  test('branch reports project ready facility rows', () {
    const ModuleReportingReport salesByBranch = ModuleReportingReport(
      id: 'sales_by_branch',
      categoryId: 'branch',
      label: 'Sales by branch',
      datasetKey: 'pharmacy_sales_by_branch',
    );
    const ModuleReportingReport comparison = ModuleReportingReport(
      id: 'branch_comparison',
      categoryId: 'branch',
      label: 'Branch comparison',
      contentKind: ModuleReportingContentKind.chart,
      datasetKey: 'pharmacy_branch_comparison',
    );

    final ReportDatasetPreview salesPreview = ReportDatasetPreview(
      datasetKey: 'pharmacy_sales_by_branch',
      title: 'Pharmacy sales by branch',
      columns: const <String>['facility', 'amount', 'quantity_dispensed'],
      rows: const <Map<String, Object?>>[
        <String, Object?>{
          'facility': 'DemoCare General Hospital',
          'amount': 1200,
          'quantity_dispensed': 40,
        },
      ],
      summary: const <String, Object?>{'amount': 1200, 'facility_count': 1},
    );

    final ModuleReportingReportSnapshot salesSnapshot =
        projectPharmacyReportingPreview(
          report: salesByBranch,
          preview: salesPreview,
        );
    expect(salesSnapshot.state, ModuleReportingLoadState.ready);
    expect(salesSnapshot.rows, hasLength(1));
    expect(salesSnapshot.rows.single['facility'], 'DemoCare General Hospital');

    final ReportDatasetPreview comparisonPreview = ReportDatasetPreview(
      datasetKey: 'pharmacy_branch_comparison',
      title: 'Branch comparison',
      subtitle: 'Side-by-side facility metrics',
      columns: const <String>['facility', 'amount', 'value'],
      rows: const <Map<String, Object?>>[
        <String, Object?>{
          'facility': 'DemoCare General Hospital',
          'amount': 1200,
          'value': 5000,
        },
      ],
    );
    final ModuleReportingReportSnapshot comparisonSnapshot =
        projectPharmacyReportingPreview(
          report: comparison,
          preview: comparisonPreview,
        );
    expect(comparisonSnapshot.state, ModuleReportingLoadState.ready);
    expect(comparisonSnapshot.subtitle, 'Side-by-side facility metrics');
    expect(comparisonSnapshot.rows.single['amount'], 1200);
  });

  test('transfers between branches stays unavailable without dataset', () {
    const ModuleReportingReport transfers = ModuleReportingReport(
      id: 'transfers_between_branches',
      categoryId: 'branch',
      label: 'Transfers between branches',
    );
    expect(transfers.hasBackend, isFalse);
  });

  test('new vs returning partition is disjoint and sums customer_count', () {
    const ModuleReportingReport report = ModuleReportingReport(
      id: 'new_vs_returning',
      categoryId: 'patients_customers',
      label: 'New vs returning customers',
      contentKind: ModuleReportingContentKind.chart,
      datasetKey: 'pharmacy_customers_new_vs_returning',
    );
    final ReportDatasetPreview preview = ReportDatasetPreview(
      datasetKey: 'pharmacy_customers_new_vs_returning',
      columns: const <String>['segment', 'customer_count'],
      rows: const <Map<String, Object?>>[
        <String, Object?>{'segment': 'new', 'customer_count': 40},
        <String, Object?>{'segment': 'returning', 'customer_count': 60},
        <String, Object?>{'segment': 'other', 'customer_count': 99},
      ],
    );

    final ModuleReportingReportSnapshot snapshot =
        projectPharmacyReportingPreview(report: report, preview: preview);

    expect(snapshot.state, ModuleReportingLoadState.ready);
    expect(snapshot.rows, hasLength(2));
    expect(
      snapshot.rows.every(
        (Map<String, Object?> row) =>
            row['segment'] == 'new' || row['segment'] == 'returning',
      ),
      isTrue,
    );
    expect(snapshot.summary?['new_count'], 40);
    expect(snapshot.summary?['returning_count'], 60);
    expect(snapshot.summary?['customer_count'], 100);
    expect(snapshot.summary?['disjoint'], isTrue);
  });

  test('frequently purchased medicines keeps top 20 by amount then quantity', () {
    const ModuleReportingReport report = ModuleReportingReport(
      id: 'frequently_purchased_medicines',
      categoryId: 'patients_customers',
      label: 'Frequently purchased medicines',
      datasetKey: 'pharmacy_drug_consumption',
    );
    final ReportDatasetPreview preview = ReportDatasetPreview(
      datasetKey: 'pharmacy_drug_consumption',
      columns: const <String>['drug', 'amount', 'quantity_dispensed'],
      rows: <Map<String, Object?>>[
        for (int i = 0; i < 25; i++)
          <String, Object?>{
            'drug': 'Drug $i',
            'amount': i.toDouble(),
            'quantity_dispensed': i,
          },
      ],
    );

    final ModuleReportingReportSnapshot snapshot =
        projectPharmacyReportingPreview(report: report, preview: preview);

    expect(snapshot.rows, hasLength(20));
    expect(snapshot.rows.first['drug'], 'Drug 24');
  });

  test('customer demographics pass-through excludes inventing PHI columns', () {
    const ModuleReportingReport report = ModuleReportingReport(
      id: 'customer_demographics',
      categoryId: 'patients_customers',
      label: 'Customer demographics',
      datasetKey: 'pharmacy_customer_demographics',
    );
    final ReportDatasetPreview preview = ReportDatasetPreview(
      datasetKey: 'pharmacy_customer_demographics',
      columns: const <String>['dimension', 'bucket', 'customer_count'],
      rows: const <Map<String, Object?>>[
        <String, Object?>{
          'dimension': 'gender',
          'bucket': 'FEMALE',
          'customer_count': 12,
        },
      ],
    );

    final ModuleReportingReportSnapshot snapshot =
        projectPharmacyReportingPreview(report: report, preview: preview);

    expect(snapshot.columns, <String>['dimension', 'bucket', 'customer_count']);
    expect(snapshot.rows.single.containsKey('first_name'), isFalse);
    expect(snapshot.rows.single.containsKey('phone'), isFalse);
  });

  test('revenue chart prefers breakdown daily_totals and keeps ledger subtitle', () {
    const ModuleReportingReport revenueReport = ModuleReportingReport(
      id: 'revenue',
      categoryId: 'financial',
      label: 'Revenue',
      contentKind: ModuleReportingContentKind.chart,
      datasetKey: 'pharmacy_financial_revenue',
    );
    final ReportDatasetPreview preview = ReportDatasetPreview(
      datasetKey: 'pharmacy_financial_revenue',
      title: 'Pharmacy revenue',
      subtitle: 'Ledger: dispense retail amount (consumption)',
      columns: const <String>['date', 'amount'],
      rows: const <Map<String, Object?>>[
        <String, Object?>{'date': '2026-08-01', 'amount': 10},
      ],
      breakdown: const <String, Object?>{
        'daily_totals': <Map<String, Object?>>[
          <String, Object?>{'date': '2026-08-01', 'amount': 40, 'profit': 12},
          <String, Object?>{'date': '2026-08-02', 'amount': 60, 'profit': 18},
        ],
      },
    );

    final ModuleReportingReportSnapshot snapshot =
        projectPharmacyReportingPreview(
          report: revenueReport,
          preview: preview,
        );

    expect(snapshot.state, ModuleReportingLoadState.ready);
    expect(snapshot.rows, hasLength(2));
    expect(snapshot.subtitle, contains('dispense retail amount'));
    expect(snapshot.rows.first['amount'], 40);
  });

  test('cogs pass-through keeps currency column key and ledger subtitle', () {
    const ModuleReportingReport cogsReport = ModuleReportingReport(
      id: 'cogs',
      categoryId: 'financial',
      label: 'Cost of goods sold',
      datasetKey: 'pharmacy_financial_cogs',
    );
    final ReportDatasetPreview preview = ReportDatasetPreview(
      datasetKey: 'pharmacy_financial_cogs',
      subtitle: 'Ledger: Σ buy_unit_price × qty (unset buy → 0)',
      columns: const <String>['date', 'cogs'],
      rows: const <Map<String, Object?>>[
        <String, Object?>{'date': '2026-08-01', 'cogs': 1300},
      ],
      summary: const <String, Object?>{'cogs': 1300, 'amount': 1300},
    );

    final ModuleReportingReportSnapshot snapshot =
        projectPharmacyReportingPreview(
          report: cogsReport,
          preview: preview,
        );

    expect(snapshot.state, ModuleReportingLoadState.ready);
    expect(snapshot.columns, contains('cogs'));
    expect(snapshot.summary?['cogs'], 1300);
    expect(snapshot.subtitle, contains('buy_unit_price'));
  });

  test('sales_by_staff passes through staff amounts and unattributed summary', () {
    const ModuleReportingReport report = ModuleReportingReport(
      id: 'sales_by_staff',
      categoryId: 'staff_activity',
      label: 'Sales by staff',
      datasetKey: 'pharmacy_sales_by_staff',
    );
    final ReportDatasetPreview preview = ReportDatasetPreview(
      datasetKey: 'pharmacy_sales_by_staff',
      columns: const <String>['staff', 'amount', 'quantity_dispensed'],
      rows: const <Map<String, Object?>>[
        <String, Object?>{
          'staff': 'USR-1 · Harper Demo',
          'amount': 400,
          'quantity_dispensed': 10,
        },
      ],
      summary: const <String, Object?>{
        'attributed_amount': 400,
        'unattributed_amount': 50,
        'period_amount': 450,
      },
    );

    final ModuleReportingReportSnapshot snapshot =
        projectPharmacyReportingPreview(report: report, preview: preview);

    expect(snapshot.state, ModuleReportingLoadState.ready);
    expect(snapshot.rows, hasLength(1));
    expect(snapshot.summary?['unattributed_amount'], 50);
  });

  test('audit_trail hides diff without compliance permission', () {
    const ModuleReportingReport report = ModuleReportingReport(
      id: 'audit_trail',
      categoryId: 'staff_activity',
      label: 'Audit trail',
      datasetKey: 'pharmacy_audit_trail',
    );
    final ReportDatasetPreview preview = ReportDatasetPreview(
      datasetKey: 'pharmacy_audit_trail',
      columns: const <String>[
        'timestamp',
        'action',
        'entity',
        'entity_id',
        'staff',
        'diff',
      ],
      rows: const <Map<String, Object?>>[
        <String, Object?>{
          'timestamp': '2026-08-01T10:00:00.000Z',
          'action': 'CREATE',
          'entity': 'stock_adjustment',
          'entity_id': 'adj-1',
          'staff': 'USR-1 · Harper Demo',
          'diff': '{"qty":1}',
        },
      ],
    );

    final ModuleReportingReportSnapshot gated =
        projectPharmacyReportingPreview(
          report: report,
          preview: preview,
        );
    expect(gated.columns.contains('diff'), isFalse);
    expect(gated.rows.single.containsKey('diff'), isFalse);

    final ModuleReportingReportSnapshot entitled =
        projectPharmacyReportingPreview(
          report: report,
          preview: preview,
          includeAuditDiff: true,
        );
    expect(entitled.columns, contains('diff'));
    expect(entitled.rows.single['diff'], '{"qty":1}');
  });
}
