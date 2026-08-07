import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/reports/domain/entities/reports_entities.dart';
import 'package:hosspi_hms/features/reports/domain/repositories/reports_repository.dart';
import 'package:hosspi_hms/shared/reporting/reporting.dart';

/// Loads and projects pharmacy catalog reports onto dataset preview rows.
final class PharmacyReportingDataProvider
    implements ModuleReportingDataProvider {
  const PharmacyReportingDataProvider(this._repository);

  final ReportsRepository _repository;

  @override
  Future<ModuleReportingReportSnapshot> load({
    required ModuleReportingReport report,
    required DateTime from,
    required DateTime to,
    required ModuleReportingPeriodPreset preset,
  }) async {
    if (!report.hasBackend) {
      return ModuleReportingReportSnapshot.unavailable(
        title: report.label,
      );
    }

    final Result<ReportDatasetPreview> result = await _repository.previewDataset(
      datasetKey: report.datasetKey!,
      from: from,
      to: to,
      datePreset: _datePresetFor(preset),
    );

    return result.when(
      success: (ReportDatasetPreview preview) {
        return projectPharmacyReportingPreview(
          report: report,
          preview: preview,
        );
      },
      failure: (AppFailure failure) {
        return ModuleReportingReportSnapshot.error(
          failureMessage: failure.detailMessage?.trim().isNotEmpty == true
              ? failure.detailMessage
              : failure.messageKey,
          title: report.label,
        );
      },
    );
  }
}

String? _datePresetFor(ModuleReportingPeriodPreset preset) {
  return switch (preset) {
    ModuleReportingPeriodPreset.today => 'today',
    ModuleReportingPeriodPreset.lastWeek => 'last_7_days',
    ModuleReportingPeriodPreset.lastMonth => 'last_30_days',
    ModuleReportingPeriodPreset.custom => 'custom',
    ModuleReportingPeriodPreset.last3Months ||
    ModuleReportingPeriodPreset.last6Months ||
    ModuleReportingPeriodPreset.last12Months ||
    ModuleReportingPeriodPreset.last24Months =>
      'custom',
  };
}

String? previewSubtitleOrNull(String? value) {
  final String? trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

/// Pure projector used by [PharmacyReportingDataProvider] and unit tests.
ModuleReportingReportSnapshot projectPharmacyReportingPreview({
  required ModuleReportingReport report,
  required ReportDatasetPreview preview,
}) {
  final String reportId = report.id;
  final List<String> columns = List<String>.from(preview.columns);
  final List<Map<String, Object?>> sourceRows =
      List<Map<String, Object?>>.from(preview.rows);
  final Map<String, Object?>? summary = preview.summary;
  final Map<String, Object?>? breakdown = preview.breakdown;

  switch (reportId) {
    case 'sales_by_period':
    case 'mgmt_sales_trend':
      return _projectPeriodSeries(
        report: report,
        preview: preview,
        columns: columns,
        sourceRows: sourceRows,
        summary: summary,
        breakdown: breakdown,
      );
    case 'top_selling_medicines':
    case 'frequently_purchased_medicines':
    case 'mgmt_top_products':
      return ModuleReportingReportSnapshot.ready(
        columns: columns,
        rows: _topRows(sourceRows, limit: 20),
        summary: summary,
        breakdown: breakdown,
        title: preview.title.isEmpty ? report.label : preview.title,
        subtitle: previewSubtitleOrNull(preview.subtitle),
      );
    case 'total_sales':
    case 'gross_revenue':
      return _projectGrossSales(
        report: report,
        preview: preview,
        columns: columns,
        sourceRows: sourceRows,
        summary: summary,
        breakdown: breakdown,
        subtitleOverride: reportId == 'gross_revenue'
            ? 'Gross dispense revenue for period'
            : previewSubtitleOrNull(preview.subtitle),
      );
    case 'sales_by_medicine':
      return ModuleReportingReportSnapshot.ready(
        columns: columns,
        rows: sourceRows,
        summary: summary,
        breakdown: breakdown,
        title: preview.title.isEmpty ? report.label : preview.title,
        subtitle: previewSubtitleOrNull(preview.subtitle),
      );
    case 'profit_and_margin':
      return _projectProfitAndMargin(
        report: report,
        preview: preview,
        columns: columns,
        sourceRows: sourceRows,
        summary: summary,
        breakdown: breakdown,
      );
    case 'sales_by_category':
    case 'sales_by_branch':
    case 'sales_by_customer':
    case 'sales_by_payment_method':
    case 'discounts':
    case 'refunds_returns':
    case 'net_revenue':
    case 'average_transaction_value':
      return ModuleReportingReportSnapshot.ready(
        columns: columns,
        rows: sourceRows,
        summary: summary,
        breakdown: breakdown,
        title: preview.title.isEmpty ? report.label : preview.title,
        subtitle: previewSubtitleOrNull(preview.subtitle),
      );
    case 'number_of_transactions':
    case 'number_of_prescriptions':
    case 'items_dispensed':
    case 'medicines_dispensed_by_period':
    case 'kpi_prescriptions':
      return ModuleReportingReportSnapshot.ready(
        columns: columns,
        rows: sourceRows,
        summary: summary,
        breakdown: breakdown,
        title: preview.title.isEmpty ? report.label : preview.title,
        subtitle: previewSubtitleOrNull(preview.subtitle),
      );
    case 'current_stock_quantity':
      return _filterStockRisk(
        report: report,
        preview: preview,
        columns: columns,
        sourceRows: sourceRows,
        summary: summary,
        breakdown: breakdown,
        riskStates: const <String>{
          'OK',
          'LOW',
          'CRITICAL',
          'OVERSTOCK',
          'OUT_OF_STOCK',
        },
      );
    case 'overstock':
      return _filterStockRisk(
        report: report,
        preview: preview,
        columns: columns,
        sourceRows: sourceRows,
        summary: summary,
        breakdown: breakdown,
        riskStates: const <String>{'OVERSTOCK'},
      );
    case 'expired_stock':
    case 'already_expired':
    case 'expired_stock_value_kpi':
    case 'mgmt_expired_medicines':
      return _filterStockRisk(
        report: report,
        preview: preview,
        columns: columns,
        sourceRows: sourceRows,
        summary: summary,
        breakdown: breakdown,
        riskStates: const <String>{'EXPIRED'},
      );
    case 'near_expiry_stock':
    case 'expiring_windows':
    case 'near_expiry_value':
    case 'mgmt_expiring':
      return _filterStockRisk(
        report: report,
        preview: preview,
        columns: columns,
        sourceRows: sourceRows,
        summary: summary,
        breakdown: breakdown,
        riskStates: const <String>{'EXPIRING_SOON'},
      );
    case 'understock':
    case 'low_stock_items':
      return _filterStockRisk(
        report: report,
        preview: preview,
        columns: columns,
        sourceRows: sourceRows,
        summary: summary,
        breakdown: breakdown,
        riskStates: const <String>{'LOW', 'CRITICAL'},
      );
    case 'out_of_stock':
    case 'kpi_out_of_stock':
    case 'mgmt_stock_outs':
      return _filterStockRisk(
        report: report,
        preview: preview,
        columns: columns,
        sourceRows: sourceRows,
        summary: summary,
        breakdown: breakdown,
        outOfStockOnly: true,
        riskStates: const <String>{'OUT_OF_STOCK'},
      );
    case 'stock_value':
    case 'current_stock_value':
    case 'mgmt_stock_value':
      return ModuleReportingReportSnapshot.ready(
        columns: columns,
        rows: sourceRows,
        summary: summary,
        breakdown: breakdown,
        title: preview.title.isEmpty ? report.label : preview.title,
        subtitle: previewSubtitleOrNull(preview.subtitle) ??
            'On-hand quantity × unit cost (prefer buy_unit_price)',
      );
    case 'opening_closing_stock':
    case 'stock_received':
    case 'stock_issued':
    case 'stock_adjustments':
    case 'damaged_stock':
    case 'lost_stock':
    case 'stock_movement_history':
    case 'stock_turnover':
    case 'mgmt_stock_turnover':
      return ModuleReportingReportSnapshot.ready(
        columns: columns,
        rows: sourceRows,
        summary: summary,
        breakdown: breakdown,
        title: preview.title.isEmpty ? report.label : preview.title,
        subtitle: previewSubtitleOrNull(preview.subtitle),
      );
    case 'reorder_level':
      return ModuleReportingReportSnapshot.ready(
        columns: columns,
        rows: sourceRows,
        summary: summary,
        breakdown: breakdown,
        title: preview.title.isEmpty ? report.label : preview.title,
        subtitle: previewSubtitleOrNull(preview.subtitle),
      );
    case 'reorder_quantity':
      return ModuleReportingReportSnapshot.ready(
        columns: columns,
        rows: sourceRows
            .where(
              (Map<String, Object?> row) => _asNum(row['reorder_quantity']) > 0,
            )
            .toList(growable: false),
        summary: summary,
        breakdown: breakdown,
        title: preview.title.isEmpty ? report.label : preview.title,
        subtitle: previewSubtitleOrNull(preview.subtitle),
      );
    case 'fast_moving':
    case 'mgmt_fast_moving':
      return _filterVelocity(
        report: report,
        preview: preview,
        columns: columns,
        sourceRows: sourceRows,
        summary: summary,
        breakdown: breakdown,
        velocityClass: 'FAST',
      );
    case 'slow_moving':
    case 'mgmt_slow_moving':
    case 'kpi_slow_moving':
      return _filterVelocity(
        report: report,
        preview: preview,
        columns: columns,
        sourceRows: sourceRows,
        summary: summary,
        breakdown: breakdown,
        velocityClass: 'SLOW',
      );
    case 'dead_stock':
    case 'mgmt_dead_stock':
      return _filterVelocity(
        report: report,
        preview: preview,
        columns: columns,
        sourceRows: sourceRows,
        summary: summary,
        breakdown: breakdown,
        velocityClass: 'DEAD',
      );
    default:
      return ModuleReportingReportSnapshot.ready(
        columns: columns,
        rows: sourceRows,
        summary: summary,
        breakdown: breakdown,
        title: preview.title.isEmpty ? report.label : preview.title,
        subtitle: previewSubtitleOrNull(preview.subtitle),
      );
  }
}

ModuleReportingReportSnapshot _projectPeriodSeries({
  required ModuleReportingReport report,
  required ReportDatasetPreview preview,
  required List<String> columns,
  required List<Map<String, Object?>> sourceRows,
  required Map<String, Object?>? summary,
  required Map<String, Object?>? breakdown,
}) {
  final Object? daily = breakdown?['daily_totals'];
  if (daily is List && daily.isNotEmpty) {
    final List<Map<String, Object?>> dailyRows = <Map<String, Object?>>[
      for (final Object? entry in daily)
        if (entry is Map)
          <String, Object?>{
            for (final MapEntry<dynamic, dynamic> item
                in Map<dynamic, dynamic>.from(entry).entries)
              item.key.toString(): item.value,
          },
    ];
    final List<String> dailyColumns = dailyRows.isEmpty
        ? columns
        : dailyRows.first.keys.toList(growable: false);
    return ModuleReportingReportSnapshot.ready(
      columns: dailyColumns,
      rows: dailyRows,
      summary: summary,
      breakdown: breakdown,
      title: preview.title.isEmpty ? report.label : preview.title,
      subtitle: previewSubtitleOrNull(preview.subtitle),
    );
  }

  return ModuleReportingReportSnapshot.ready(
    columns: columns,
    rows: sourceRows,
    summary: summary,
    breakdown: breakdown,
    title: preview.title.isEmpty ? report.label : preview.title,
    subtitle: previewSubtitleOrNull(preview.subtitle),
  );
}

ModuleReportingReportSnapshot _projectGrossSales({
  required ModuleReportingReport report,
  required ReportDatasetPreview preview,
  required List<String> columns,
  required List<Map<String, Object?>> sourceRows,
  required Map<String, Object?>? summary,
  required Map<String, Object?>? breakdown,
  String? subtitleOverride,
}) {
  final num? periodAmount = _sumBreakdownDailyAmount(breakdown);
  final Map<String, Object?>? adjustedSummary = periodAmount == null
      ? summary
      : <String, Object?>{
          ...?summary,
          'amount': periodAmount,
        };

  return ModuleReportingReportSnapshot.ready(
    columns: columns,
    rows: sourceRows,
    summary: adjustedSummary,
    breakdown: breakdown,
    title: preview.title.isEmpty ? report.label : preview.title,
    subtitle: subtitleOverride ?? previewSubtitleOrNull(preview.subtitle),
  );
}

ModuleReportingReportSnapshot _projectProfitAndMargin({
  required ModuleReportingReport report,
  required ReportDatasetPreview preview,
  required List<String> columns,
  required List<Map<String, Object?>> sourceRows,
  required Map<String, Object?>? summary,
  required Map<String, Object?>? breakdown,
}) {
  final List<Map<String, Object?>> rows = <Map<String, Object?>>[
    for (final Map<String, Object?> row in sourceRows)
      <String, Object?>{
        ...row,
        'profit_margin': _profitMargin(row['profit'], row['amount']),
      },
  ];
  final List<String> nextColumns = columns.contains('profit_margin')
      ? columns
      : <String>[...columns, 'profit_margin'];

  final num totalProfit = rows.fold<num>(
    0,
    (num sum, Map<String, Object?> row) => sum + _asNum(row['profit']),
  );
  final num totalAmount = rows.fold<num>(
    0,
    (num sum, Map<String, Object?> row) => sum + _asNum(row['amount']),
  );
  final Map<String, Object?>? adjustedSummary = summary == null
      ? null
      : <String, Object?>{
          ...summary,
          'profit': totalProfit,
          'amount': totalAmount,
          'profit_margin': _profitMargin(totalProfit, totalAmount),
        };

  return ModuleReportingReportSnapshot.ready(
    columns: nextColumns,
    rows: rows,
    summary: adjustedSummary,
    breakdown: breakdown,
    title: preview.title.isEmpty ? report.label : preview.title,
    subtitle: previewSubtitleOrNull(preview.subtitle),
  );
}

num? _sumBreakdownDailyAmount(Map<String, Object?>? breakdown) {
  final Object? daily = breakdown?['daily_totals'];
  if (daily is! List || daily.isEmpty) {
    return null;
  }
  num total = 0;
  for (final Object? entry in daily) {
    if (entry is Map) {
      total += _asNum(Map<dynamic, dynamic>.from(entry)['amount']);
    }
  }
  return total;
}

Object? _profitMargin(Object? profit, Object? amount) {
  if (profit == null) {
    return null;
  }
  final num amountValue = _asNum(amount);
  if (amountValue <= 0) {
    return null;
  }
  return _asNum(profit) / amountValue;
}

ModuleReportingReportSnapshot _filterStockRisk({
  required ModuleReportingReport report,
  required ReportDatasetPreview preview,
  required List<String> columns,
  required List<Map<String, Object?>> sourceRows,
  required Map<String, Object?>? summary,
  required Map<String, Object?>? breakdown,
  Set<String> riskStates = const <String>{},
  bool outOfStockOnly = false,
}) {
  final List<Map<String, Object?>> filtered = sourceRows.where((
    Map<String, Object?> row,
  ) {
    if (outOfStockOnly) {
      return _asNum(row['quantity']) <= 0;
    }
    final String risk =
        '${row['risk_state'] ?? row['expiry_alert_status'] ?? ''}'
            .trim()
            .toUpperCase();
    return riskStates.contains(risk);
  }).toList(growable: false);

  return ModuleReportingReportSnapshot.ready(
    columns: columns,
    rows: filtered,
    summary: summary,
    breakdown: breakdown,
    title: preview.title.isEmpty ? report.label : preview.title,
    subtitle: previewSubtitleOrNull(preview.subtitle),
  );
}

ModuleReportingReportSnapshot _filterVelocity({
  required ModuleReportingReport report,
  required ReportDatasetPreview preview,
  required List<String> columns,
  required List<Map<String, Object?>> sourceRows,
  required Map<String, Object?>? summary,
  required Map<String, Object?>? breakdown,
  required String velocityClass,
}) {
  final String expected = velocityClass.trim().toUpperCase();
  final List<Map<String, Object?>> filtered = sourceRows
      .where(
        (Map<String, Object?> row) =>
            '${row['velocity_class'] ?? ''}'.trim().toUpperCase() == expected,
      )
      .toList(growable: false);

  return ModuleReportingReportSnapshot.ready(
    columns: columns,
    rows: filtered,
    summary: summary,
    breakdown: breakdown,
    title: preview.title.isEmpty ? report.label : preview.title,
    subtitle: previewSubtitleOrNull(preview.subtitle),
  );
}

List<Map<String, Object?>> _topRows(
  List<Map<String, Object?>> rows, {
  required int limit,
}) {
  final List<Map<String, Object?>> sorted =
      List<Map<String, Object?>>.from(rows)
        ..sort((Map<String, Object?> left, Map<String, Object?> right) {
          final int byAmount =
              _asNum(right['amount']).compareTo(_asNum(left['amount']));
          if (byAmount != 0) {
            return byAmount;
          }
          return _asNum(right['quantity_dispensed']).compareTo(
            _asNum(left['quantity_dispensed']),
          );
        });
  if (sorted.length <= limit) {
    return sorted;
  }
  return sorted.take(limit).toList(growable: false);
}

num _asNum(Object? value) {
  if (value is num) {
    return value;
  }
  if (value is String) {
    return num.tryParse(value) ?? 0;
  }
  return 0;
}
