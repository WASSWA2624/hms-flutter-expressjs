import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/shared/reporting/module_reporting_table.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  const Locale locale = Locale('en');

  setUpAll(() async {
    await initializeDateFormatting('en');
  });

  test('humanizes snake_case column keys', () {
    expect(
      moduleReportingColumnLabel('quantity_dispensed'),
      'Quantity Dispensed (units)',
    );
    expect(moduleReportingColumnLabel('risk_state'), 'Risk State');
    expect(
      moduleReportingColumnLabel('amount', currencyCode: 'UGX'),
      'Amount (UGX)',
    );
    expect(
      moduleReportingColumnLabel('profit_margin'),
      'Profit Margin (%)',
    );
    expect(
      moduleReportingColumnLabel('credit_balance', currencyCode: 'UGX'),
      'Credit Balance (UGX)',
    );
    expect(
      moduleReportingColumnLabel('retention_rate'),
      'Retention Rate (%)',
    );
    expect(
      moduleReportingColumnLabel('customer_count'),
      'Customer Count',
    );
  });

  test('detects numeric and date columns', () {
    expect(moduleReportingIsNumericColumn('amount'), isTrue);
    expect(moduleReportingIsNumericColumn('credit_balance'), isTrue);
    expect(moduleReportingIsNumericColumn('retention_rate'), isTrue);
    expect(moduleReportingIsNumericColumn('days_to_expiry'), isTrue);
    expect(moduleReportingIsNumericColumn('drug'), isFalse);
    expect(moduleReportingIsDateColumn('expiry_date'), isTrue);
    expect(moduleReportingIsDateColumn('dispensed_at'), isTrue);
    expect(moduleReportingIsDateColumn('drug'), isFalse);
  });

  test('formats numbers, dates, and enum tokens', () {
    expect(
      moduleReportingFormatCellValue(
        1250.5,
        locale: locale,
        unknownLabel: '—',
        preferNumeric: true,
      ),
      '1,250.5',
    );
    expect(
      moduleReportingFormatCellValue(
        1250.5,
        locale: locale,
        unknownLabel: '—',
        preferNumeric: true,
        columnKey: 'amount',
        currencyCode: 'UGX',
      ),
      contains('UGX'),
    );
    expect(
      moduleReportingFormatCellValue(
        42,
        locale: locale,
        unknownLabel: '—',
        preferNumeric: true,
        columnKey: 'quantity_dispensed',
      ),
      '42 units',
    );
    expect(
      moduleReportingFormatCellValue(
        12,
        locale: locale,
        unknownLabel: '—',
        preferNumeric: true,
        columnKey: 'days_to_expiry',
      ),
      '12 days',
    );
    expect(
      moduleReportingFormatCellValue(
        0.15,
        locale: locale,
        unknownLabel: '—',
        preferNumeric: true,
        columnKey: 'profit_margin',
      ),
      '15%',
    );
    expect(
      moduleReportingFormatMetricValue(
        5500,
        locale: locale,
        columnKey: 'amount',
        currencyCode: 'UGX',
        compact: true,
      ),
      '5.5K UGX',
    );
    expect(
      moduleReportingFormatCellValue(
        '2026-08-07',
        locale: locale,
        unknownLabel: '—',
        preferDate: true,
      ),
      'Aug 7, 2026',
    );
    expect(
      moduleReportingFormatCellValue(
        'EXPIRING_SOON',
        locale: locale,
        unknownLabel: '—',
      ),
      'Expiring Soon',
    );
    expect(
      moduleReportingFormatCellValue(
        null,
        locale: locale,
        unknownLabel: '—',
      ),
      '—',
    );
  });

  test('infers metric units from column keys', () {
    expect(
      moduleReportingMetricUnitForKey('amount'),
      ModuleReportingMetricUnit.currency,
    );
    expect(
      moduleReportingMetricUnitForKey('quantity_dispensed'),
      ModuleReportingMetricUnit.quantity,
    );
    expect(
      moduleReportingMetricUnitForKey('profit_margin'),
      ModuleReportingMetricUnit.percent,
    );
    expect(
      moduleReportingMetricUnitForKey('days_to_expiry'),
      ModuleReportingMetricUnit.days,
    );
    expect(
      moduleReportingMetricUnitForKey('orders_created'),
      ModuleReportingMetricUnit.count,
    );
    expect(
      moduleReportingMetricUnitForKey('strength'),
      ModuleReportingMetricUnit.plain,
    );
    expect(
      moduleReportingMetricUnitForKey('form'),
      ModuleReportingMetricUnit.plain,
    );
    expect(
      moduleReportingMetricUnitForKey('dosage_form'),
      ModuleReportingMetricUnit.plain,
    );
    expect(
      moduleReportingMetricUnitForKey('selling_price'),
      ModuleReportingMetricUnit.currency,
    );
    expect(
      moduleReportingMetricUnitForKey('profit_per_unit'),
      ModuleReportingMetricUnit.currency,
    );
    expect(
      moduleReportingMetricUnitForKey('void_count'),
      ModuleReportingMetricUnit.count,
    );
    expect(
      moduleReportingMetricUnitForKey('remaining_quantity'),
      ModuleReportingMetricUnit.quantity,
    );
    expect(
      moduleReportingMetricUnitForKey('average_items_per_prescription'),
      ModuleReportingMetricUnit.plain,
    );
  });

  test('row search matches formatted and raw values', () {
    final Map<String, Object?> row = <String, Object?>{
      'drug': 'Amoxicillin',
      'risk_state': 'EXPIRING_SOON',
      'amount': 1200,
    };
    expect(
      moduleReportingRowMatchesQuery(
        row,
        <String>['drug', 'risk_state', 'amount'],
        'amox',
        locale: locale,
        unknownLabel: '—',
      ),
      isTrue,
    );
    expect(
      moduleReportingRowMatchesQuery(
        row,
        <String>['drug', 'risk_state', 'amount'],
        'expiring',
        locale: locale,
        unknownLabel: '—',
      ),
      isTrue,
    );
    expect(
      moduleReportingRowMatchesQuery(
        row,
        <String>['drug', 'risk_state', 'amount'],
        'missing',
        locale: locale,
        unknownLabel: '—',
      ),
      isFalse,
    );
  });
}
