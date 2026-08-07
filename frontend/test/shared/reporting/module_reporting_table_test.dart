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
      'Quantity Dispensed',
    );
    expect(moduleReportingColumnLabel('risk_state'), 'Risk State');
  });

  test('detects numeric and date columns', () {
    expect(moduleReportingIsNumericColumn('amount'), isTrue);
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
