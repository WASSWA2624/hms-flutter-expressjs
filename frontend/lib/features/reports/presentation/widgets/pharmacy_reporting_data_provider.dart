import 'dart:math' as math;

import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/features/reports/domain/entities/reports_entities.dart';
import 'package:hosspi_hms/features/reports/domain/repositories/reports_repository.dart';
import 'package:hosspi_hms/features/reports/presentation/pharmacy_reporting_mgmt_sources.dart';
import 'package:hosspi_hms/features/reports/presentation/reports_access.dart';
import 'package:hosspi_hms/shared/reporting/reporting.dart';

/// Loads and projects pharmacy catalog reports onto dataset preview rows.
final class PharmacyReportingDataProvider
    implements ModuleReportingDataProvider {
  const PharmacyReportingDataProvider(
    this._repository, {
    this.policy,
  });

  final ReportsRepository _repository;
  final AppAccessPolicy? policy;

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

    if (report.id == 'regulatory_log' &&
        (policy == null || !canReadControlledRegulatoryLog(policy!))) {
      return ModuleReportingReportSnapshot.unavailable(
        title: report.label,
        subtitle: 'Requires compliance:read',
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
          includeAuditDiff: policy != null && canReadReportsCompliance(policy!),
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
  bool includeAuditDiff = false,
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
    case 'revenue':
    case 'mgmt_revenue':
    case 'profit_by_period':
      return _projectPeriodSeries(
        report: report,
        preview: preview,
        columns: columns,
        sourceRows: sourceRows,
        summary: summary,
        breakdown: breakdown,
      );
    case 'top_selling_medicines':
      return ModuleReportingReportSnapshot.ready(
        columns: columns,
        rows: _topRows(sourceRows, limit: 10),
        summary: summary,
        breakdown: breakdown,
        title: preview.title.isEmpty ? report.label : preview.title,
        subtitle: previewSubtitleOrNull(preview.subtitle) ??
            'Top 10 by dispense amount',
      );
    case 'top_profitable_medicines':
      return ModuleReportingReportSnapshot.ready(
        columns: columns,
        rows: _topRows(
          sourceRows,
          limit: 10,
          sortKey: 'profit',
          excludeNullSortKey: true,
        ),
        summary: summary,
        breakdown: breakdown,
        title: preview.title.isEmpty ? report.label : preview.title,
        subtitle: previewSubtitleOrNull(preview.subtitle) ??
            'Top 10 by profit (null profit excluded)',
      );
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
    case 'total_sales_today':
      return _projectGrossSales(
        report: report,
        preview: preview,
        columns: columns,
        sourceRows: sourceRows,
        summary: summary,
        breakdown: breakdown,
        subtitleOverride:
            previewSubtitleOrNull(preview.subtitle) ??
            'Dispense amount for calendar today',
      );
    case 'todays_profit':
      return _projectTodaysProfit(
        report: report,
        preview: preview,
        columns: columns,
        sourceRows: sourceRows,
        summary: summary,
        breakdown: breakdown,
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
    case 'mgmt_profit_margin':
      return _projectProfitAndMargin(
        report: report,
        preview: preview,
        columns: columns,
        sourceRows: sourceRows,
        summary: summary,
        breakdown: breakdown,
        subtitleOverride: reportId == 'mgmt_profit_margin'
            ? 'profit_margin = profit / amount (same Financial gross profit ledger)'
            : null,
      );
    case 'mgmt_top_categories':
      return ModuleReportingReportSnapshot.ready(
        columns: columns,
        rows: _topRows(sourceRows, limit: 10),
        summary: summary,
        breakdown: breakdown,
        title: preview.title.isEmpty ? report.label : preview.title,
        subtitle: previewSubtitleOrNull(preview.subtitle) ??
            'Top 10 categories by dispense amount (same as sales_by_category)',
      );
    case 'mgmt_top_customers':
      return ModuleReportingReportSnapshot.ready(
        columns: columns,
        rows: _topRows(sourceRows, limit: 10),
        summary: summary,
        breakdown: breakdown,
        title: preview.title.isEmpty ? report.label : preview.title,
        subtitle: previewSubtitleOrNull(preview.subtitle) ??
            'Top 10 customers by amount (same as purchases_by_customer)',
      );
    case 'sales_by_category':
    case 'sales_by_branch':
    case 'sales_by_customer':
    case 'sales_by_payment_method':
    case 'discounts':
    case 'financial_discounts':
    case 'refunds_returns':
    case 'net_revenue':
    case 'average_transaction_value':
    case 'cogs':
    case 'gross_profit':
    case 'net_profit':
    case 'operating_expenses':
    case 'customer_receivables':
    case 'cash_flow':
    case 'daily_cash_position':
    case 'profit_by_product_category':
    case 'mgmt_expenses':
    case 'mgmt_gross_profit':
    case 'mgmt_net_profit':
    case 'stock_by_branch':
    case 'profit_by_branch':
    case 'purchases_by_branch':
    case 'stock_shortages_by_branch':
    case 'best_performing_branch':
    case 'branch_comparison':
    case 'transfers_between_branches':
    case 'transfer_quantity':
    case 'sending_branch':
    case 'receiving_branch':
    case 'transfer_date':
    case 'transfer_status':
    case 'products_transferred':
    case 'pending_transfers':
    case 'transfer_discrepancies':
    case 'number_of_customers':
    case 'purchases_by_customer':
    case 'patient_medication_history':
    case 'customer_credit_balance':
    case 'outstanding_customer_credit':
    case 'outstanding_payments':
    case 'customer_demographics':
      return ModuleReportingReportSnapshot.ready(
        columns: columns,
        rows: sourceRows,
        summary: summary,
        breakdown: breakdown,
        title: preview.title.isEmpty ? report.label : preview.title,
        subtitle: previewSubtitleOrNull(preview.subtitle) ??
            (reportId == 'outstanding_customer_credit'
                ? 'Open pharmacy invoice balance sum'
                : null),
      );
    case 'new_vs_returning':
      return _projectNewVsReturning(
        report: report,
        preview: preview,
        columns: columns,
        sourceRows: sourceRows,
        summary: summary,
        breakdown: breakdown,
      );
    case 'customer_retention':
      return ModuleReportingReportSnapshot.ready(
        columns: columns,
        rows: sourceRows,
        summary: summary,
        breakdown: breakdown,
        title: preview.title.isEmpty ? report.label : preview.title,
        subtitle: previewSubtitleOrNull(preview.subtitle) ??
            'Prior window of equal length; retention_rate = retained / prior purchasers',
      );
    case 'number_of_transactions':
    case 'number_of_prescriptions':
    case 'kpi_prescriptions':
    case 'kpi_transactions':
      return ModuleReportingReportSnapshot.ready(
        columns: columns,
        rows: sourceRows,
        summary: summary,
        breakdown: breakdown,
        title: preview.title.isEmpty ? report.label : preview.title,
        subtitle: previewSubtitleOrNull(preview.subtitle) ??
            (reportId == 'kpi_transactions'
                ? 'Pharmacy orders created (orders_created)'
                : null),
      );
    case 'items_dispensed':
      return ModuleReportingReportSnapshot.ready(
        columns: columns.contains('quantity_dispensed')
            ? columns
            : <String>['drug', 'quantity_dispensed'],
        rows: sourceRows,
        summary: summary,
        breakdown: breakdown,
        title: preview.title.isEmpty ? report.label : preview.title,
        subtitle: previewSubtitleOrNull(preview.subtitle) ??
            'Pack quantity dispensed (DISPENSED logs)',
      );
    case 'medicines_dispensed_by_period':
      return _projectDispensedByPeriod(
        report: report,
        preview: preview,
        columns: columns,
        sourceRows: sourceRows,
        summary: summary,
        breakdown: breakdown,
      );
    case 'medicines_dispensed_by_patient':
      return ModuleReportingReportSnapshot.ready(
        columns: const <String>['patient', 'quantity_dispensed'],
        rows: <Map<String, Object?>>[
          for (final Map<String, Object?> row in sourceRows)
            <String, Object?>{
              'patient': row['patient'],
              'quantity_dispensed': row['quantity_dispensed'],
            },
        ],
        summary: summary == null
            ? null
            : <String, Object?>{
                'quantity_dispensed': summary['quantity_dispensed'],
              },
        breakdown: breakdown,
        title: preview.title.isEmpty ? report.label : preview.title,
        subtitle: previewSubtitleOrNull(preview.subtitle) ??
            'Pack quantity by patient',
      );
    case 'prescription_status':
      return _projectThroughputBreakdown(
        report: report,
        preview: preview,
        summary: summary,
        breakdown: breakdown,
        breakdownKey: 'status_totals',
        fallbackColumns: const <String>['status', 'orders_created'],
        subtitleFallback: 'Orders grouped by pharmacy_order.status',
      );
    case 'dispensing_errors_voids':
      return _projectThroughputBreakdown(
        report: report,
        preview: preview,
        summary: summary,
        breakdown: breakdown,
        breakdownKey: 'voids',
        fallbackColumns: const <String>['void_type', 'void_count'],
        subtitleFallback:
            'CANCELLED orders + RETURNED dispense logs (counts, not pack qty)',
      );
    case 'medicines_dispensed_by_prescriber':
    case 'partial_dispensing':
    case 'prescription_frequency':
    case 'average_items_per_prescription':
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
    case 'mgmt_expired_medicines':
      return _filterStockRisk(
        report: report,
        preview: preview,
        columns: columns,
        sourceRows: sourceRows,
        summary: summary,
        breakdown: breakdown,
        riskStates: const <String>{'EXPIRED'},
        includeDaysToExpiryNegative: true,
      );
    case 'expired_stock_value':
    case 'expired_stock_value_kpi':
      return _projectExpiredStockValue(
        report: report,
        preview: preview,
        columns: columns,
        sourceRows: sourceRows,
        summary: summary,
        breakdown: breakdown,
      );
    case 'near_expiry_stock':
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
    case 'near_expiry_value':
      return _projectNearExpiryValue(
        report: report,
        preview: preview,
        columns: columns,
        sourceRows: sourceRows,
        summary: summary,
        breakdown: breakdown,
      );
    case 'expiring_windows':
      return _projectExpiringWindows(
        report: report,
        preview: preview,
        columns: columns,
        sourceRows: sourceRows,
        summary: summary,
        breakdown: breakdown,
      );
    case 'expiry_losses_breakdown':
      return _projectExpiryLossesBreakdown(
        report: report,
        preview: preview,
        sourceRows: sourceRows,
        summary: summary,
        breakdown: breakdown,
      );
    case 'damaged_stock_loss':
    case 'stock_write_offs':
      return ModuleReportingReportSnapshot.ready(
        columns: columns,
        rows: sourceRows,
        summary: summary,
        breakdown: breakdown,
        title: preview.title.isEmpty ? report.label : preview.title,
        subtitle: previewSubtitleOrNull(preview.subtitle) ??
            'at buy cost',
      );
    case 'mgmt_high_value_losses':
      return ModuleReportingReportSnapshot.ready(
        columns: columns,
        rows: _topRows(sourceRows, limit: sourceRows.length, sortKey: 'value'),
        summary: summary,
        breakdown: breakdown,
        title: preview.title.isEmpty ? report.label : preview.title,
        subtitle: previewSubtitleOrNull(preview.subtitle) ??
            'DAMAGE|EXPIRY write-offs by value desc (same as stock_write_offs)',
      );
    case 'mgmt_unusual_adjustments':
      return _projectUnusualAdjustments(
        report: report,
        preview: preview,
        columns: columns,
        sourceRows: sourceRows,
        summary: summary,
        breakdown: breakdown,
      );
    case 'lost_stock_loss':
      return ModuleReportingReportSnapshot.ready(
        columns: columns,
        rows: sourceRows,
        summary: summary,
        breakdown: breakdown,
        title: preview.title.isEmpty ? report.label : preview.title,
        subtitle: previewSubtitleOrNull(preview.subtitle) ??
            'reason=OTHER as loss proxy (schema has no LOSS; DAMAGE excluded)',
      );
    case 'adjustment_reasons':
      return ModuleReportingReportSnapshot.ready(
        columns: columns,
        rows: sourceRows,
        summary: summary,
        breakdown: breakdown,
        title: preview.title.isEmpty ? report.label : preview.title,
        subtitle: previewSubtitleOrNull(preview.subtitle),
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
    case 'medicine_name':
      return _projectMedicinesCatalog(
        report: report,
        preview: preview,
        sourceRows: sourceRows,
        summary: summary,
        breakdown: breakdown,
        rowKind: 'drug',
        columnKeys: const <String>['name', 'code', 'human_friendly_id'],
      );
    case 'generic_brand_name':
      return _projectMedicinesCatalog(
        report: report,
        preview: preview,
        sourceRows: sourceRows,
        summary: summary,
        breakdown: breakdown,
        rowKind: 'drug',
        columnKeys: const <String>['name', 'generic_name', 'brand_name'],
      );
    case 'medicine_category':
      return _projectMedicinesCatalog(
        report: report,
        preview: preview,
        sourceRows: sourceRows,
        summary: summary,
        breakdown: breakdown,
        rowKind: 'drug',
        columnKeys: const <String>['category', 'name'],
      );
    case 'strength':
      return _projectMedicinesCatalog(
        report: report,
        preview: preview,
        sourceRows: sourceRows,
        summary: summary,
        breakdown: breakdown,
        rowKind: 'drug',
        columnKeys: const <String>['name', 'strength'],
      );
    case 'dosage_form':
      return _projectMedicinesCatalog(
        report: report,
        preview: preview,
        sourceRows: sourceRows,
        summary: summary,
        breakdown: breakdown,
        rowKind: 'drug',
        columnKeys: const <String>['name', 'dosage_form', 'form'],
      );
    case 'unit_of_measure':
      return _projectMedicinesCatalog(
        report: report,
        preview: preview,
        sourceRows: sourceRows,
        summary: summary,
        breakdown: breakdown,
        rowKind: 'drug',
        columnKeys: const <String>['name', 'unit'],
      );
    case 'batch_lot':
      return _projectMedicinesCatalog(
        report: report,
        preview: preview,
        sourceRows: sourceRows,
        summary: summary,
        breakdown: breakdown,
        rowKind: 'batch',
        columnKeys: const <String>[
          'batch_number',
          'quantity',
          'expiry_date',
          'name',
        ],
      );
    case 'manufacturing_date':
      return _projectMedicinesCatalog(
        report: report,
        preview: preview,
        sourceRows: sourceRows,
        summary: summary,
        breakdown: breakdown,
        rowKind: 'batch',
        columnKeys: const <String>['name', 'batch_number', 'manufactured_at'],
      );
    case 'expiry_date':
      return _projectMedicinesCatalog(
        report: report,
        preview: preview,
        sourceRows: sourceRows,
        summary: summary,
        breakdown: breakdown,
        rowKind: 'batch',
        columnKeys: const <String>[
          'name',
          'batch_number',
          'expiry_date',
          'days_to_expiry',
        ],
      );
    case 'selling_price':
      return _projectMedicinesCatalog(
        report: report,
        preview: preview,
        sourceRows: sourceRows,
        summary: summary,
        breakdown: breakdown,
        rowKind: 'drug',
        columnKeys: const <String>['name', 'selling_price', 'currency'],
      );
    case 'purchase_price':
      return _projectMedicinesCatalog(
        report: report,
        preview: preview,
        sourceRows: sourceRows,
        summary: summary,
        breakdown: breakdown,
        rowKind: 'drug',
        columnKeys: const <String>['name', 'purchase_price', 'currency'],
      );
    case 'profit_per_unit':
      return _projectMedicinesCatalog(
        report: report,
        preview: preview,
        sourceRows: sourceRows,
        summary: summary,
        breakdown: breakdown,
        rowKind: 'drug',
        columnKeys: const <String>['name', 'profit_per_unit', 'currency'],
      );
    case 'profit_margin':
      return _projectMedicinesCatalog(
        report: report,
        preview: preview,
        sourceRows: sourceRows,
        summary: summary,
        breakdown: breakdown,
        rowKind: 'drug',
        columnKeys: const <String>['name', 'profit_margin'],
      );
    case 'storage_requirements':
      return _projectMedicinesCatalog(
        report: report,
        preview: preview,
        sourceRows: sourceRows,
        summary: summary,
        breakdown: breakdown,
        rowKind: 'batch',
        columnKeys: const <String>[
          'name',
          'batch_number',
          'storage_requirements',
          'storage_room',
          'storage_shelf',
        ],
      );
    case 'purchase_orders':
      return _projectColumnSubset(
        report: report,
        preview: preview,
        sourceRows: sourceRows,
        summary: summary,
        breakdown: breakdown,
        columnKeys: const <String>[
          'ordered_at',
          'status',
          'supplier',
          'human_friendly_id',
        ],
      );
    case 'purchases_by_supplier':
      return _projectColumnSubset(
        report: report,
        preview: preview,
        sourceRows: sourceRows,
        summary: summary,
        breakdown: breakdown,
        columnKeys: const <String>[
          'supplier',
          'po_count',
          'quantity',
          'amount',
          'currency',
        ],
      );
    case 'purchase_value':
      return _projectColumnSubset(
        report: report,
        preview: preview,
        sourceRows: sourceRows,
        summary: summary,
        breakdown: breakdown,
        columnKeys: const <String>[
          'occurred_at',
          'supplier',
          'inventory_item',
          'quantity',
          'amount',
          'currency',
        ],
      );
    case 'supplier_pricing':
      return _projectColumnSubset(
        report: report,
        preview: preview,
        sourceRows: sourceRows,
        summary: summary,
        breakdown: breakdown,
        columnKeys: const <String>[
          'supplier',
          'drug',
          'buy_unit_price',
          'currency',
        ],
      );
    case 'supplier_performance':
    case 'mgmt_supplier_performance':
      return _projectSupplierPerformance(
        report: report,
        preview: preview,
        summary: summary,
        breakdown: breakdown,
      );
    case 'mgmt_purchase_trends':
      return _projectPurchaseTrends(
        report: report,
        preview: preview,
        sourceRows: sourceRows,
        summary: summary,
        breakdown: breakdown,
      );
    case 'delivery_time':
      return _projectDeliveryTime(
        report: report,
        preview: preview,
        sourceRows: sourceRows,
        summary: summary,
        breakdown: breakdown,
      );
    case 'purchase_returns':
      return _projectColumnSubset(
        report: report,
        preview: preview,
        sourceRows: sourceRows,
        summary: summary,
        breakdown: breakdown,
        columnKeys: const <String>[
          'occurred_at',
          'inventory_item',
          'quantity',
          'facility',
          'reason',
        ],
      );
    case 'price_changes':
      return _projectColumnSubset(
        report: report,
        preview: preview,
        sourceRows: sourceRows,
        summary: summary,
        breakdown: breakdown,
        columnKeys: const <String>[
          'changed_at',
          'drug',
          'field',
          'from_value',
          'to_value',
          'currency',
        ],
      );
    case 'most_used_suppliers':
      return _projectColumnSubset(
        report: report,
        preview: preview,
        sourceRows: sourceRows,
        summary: summary,
        breakdown: breakdown,
        columnKeys: const <String>[
          'supplier',
          'po_count',
          'quantity',
          'amount',
        ],
      );
    case 'supplier_spend':
    case 'mgmt_supplier_spend':
      return _projectColumnSubset(
        report: report,
        preview: preview,
        sourceRows: sourceRows,
        summary: summary,
        breakdown: breakdown,
        columnKeys: const <String>['supplier', 'amount'],
        subtitleOverride:
            'Purchase value basis: stock inbound × buy_unit_price (same as Purchasing)',
      );
    case 'price_comparison':
      return _projectColumnSubset(
        report: report,
        preview: preview,
        sourceRows: sourceRows,
        summary: summary,
        breakdown: breakdown,
        columnKeys: const <String>[
          'drug',
          'supplier',
          'buy_unit_price',
        ],
        subtitleOverride:
            'Current buy_unit_price by drug.supplier_id (one supplier per drug)',
      );
    case 'price_trends':
      return _projectPriceTrends(
        report: report,
        preview: preview,
        sourceRows: sourceRows,
        summary: summary,
        breakdown: breakdown,
      );
    case 'supplier_reliability':
      return _projectSupplierReliability(
        report: report,
        preview: preview,
        summary: summary,
        breakdown: breakdown,
      );
    case 'order_fulfillment_rate':
      return _projectOrderFulfillmentRate(
        report: report,
        preview: preview,
        summary: summary,
        breakdown: breakdown,
      );
    case 'late_deliveries':
      return _projectLateDeliveries(
        report: report,
        preview: preview,
        sourceRows: sourceRows,
        summary: summary,
        breakdown: breakdown,
      );
    case 'purchase_frequency':
      return _projectColumnSubset(
        report: report,
        preview: preview,
        sourceRows: sourceRows,
        summary: summary,
        breakdown: breakdown,
        columnKeys: const <String>['supplier', 'po_count'],
      );
    case 'purchase_volume':
      return _projectColumnSubset(
        report: report,
        preview: preview,
        sourceRows: sourceRows,
        summary: summary,
        breakdown: breakdown,
        columnKeys: const <String>['supplier', 'quantity'],
      );
    case 'sales_by_staff':
    case 'mgmt_sales_by_staff_branch':
    case 'dispensing_by_staff':
    case 'purchases_entered_by_staff':
    case 'stock_adjustments_by_staff':
    case 'refunds_by_staff':
    case 'discounts_authorized':
    case 'voided_transactions':
    case 'login_activity_history':
    case 'user_productivity':
    case 'prescription_count':
    case 'prescriber':
    case 'diagnosis_indication':
    case 'medicine_prescribed':
    case 'dosage':
    case 'frequency':
    case 'duration':
    case 'antibiotic_usage':
    case 'controlled_drug_dispensing':
      return ModuleReportingReportSnapshot.ready(
        columns: columns,
        rows: sourceRows,
        summary: summary,
        breakdown: breakdown,
        title: preview.title.isEmpty ? report.label : preview.title,
        subtitle: previewSubtitleOrNull(preview.subtitle) ??
            (reportId == 'mgmt_sales_by_staff_branch'
                ? 'Staff sales; branch = facility scope (same as sales_by_staff)'
                : null),
      );
    case 'controlled_medicine_stock':
    case 'quantity_received':
    case 'quantity_dispensed':
    case 'batch_numbers':
    case 'controlled_adjustments':
    case 'wastage':
    case 'regulatory_log':
      return ModuleReportingReportSnapshot.ready(
        columns: columns,
        rows: sourceRows,
        summary: summary,
        breakdown: breakdown,
        title: preview.title.isEmpty ? report.label : preview.title,
        subtitle: previewSubtitleOrNull(preview.subtitle),
      );
    case 'opening_balance':
      return _projectColumnSubset(
        report: report,
        preview: preview,
        sourceRows: sourceRows,
        summary: summary,
        breakdown: breakdown,
        columnKeys: const <String>[
          'drug',
          'facility',
          'opening_quantity',
          'unit',
        ],
      );
    case 'closing_balance':
      return _projectColumnSubset(
        report: report,
        preview: preview,
        sourceRows: sourceRows,
        summary: summary,
        breakdown: breakdown,
        columnKeys: const <String>[
          'drug',
          'facility',
          'closing_quantity',
          'opening_quantity',
          'quantity_received',
          'quantity_dispensed',
          'wastage',
          'adjustments_net',
          'unit',
        ],
      );
    case 'controlled_prescriber':
      return _projectControlledActors(
        report: report,
        preview: preview,
        sourceRows: sourceRows,
        summary: summary,
        breakdown: breakdown,
        actorRole: 'prescriber',
      );
    case 'controlled_patient':
      return _projectControlledActors(
        report: report,
        preview: preview,
        sourceRows: sourceRows,
        summary: summary,
        breakdown: breakdown,
        actorRole: 'patient',
      );
    case 'dispensing_staff':
      return _projectControlledActors(
        report: report,
        preview: preview,
        sourceRows: sourceRows,
        summary: summary,
        breakdown: breakdown,
        actorRole: 'staff',
      );
    case 'audit_trail':
      return _projectAuditTrail(
        report: report,
        preview: preview,
        columns: columns,
        sourceRows: sourceRows,
        summary: summary,
        breakdown: breakdown,
        includeAuditDiff: includeAuditDiff,
      );
    case 'who_created':
    case 'who_edited':
    case 'who_deleted_voided':
    case 'change_date_time':
    case 'unauthorized_attempts':
      return ModuleReportingReportSnapshot.ready(
        columns: columns,
        rows: sourceRows,
        summary: summary,
        breakdown: breakdown,
        title: preview.title.isEmpty ? report.label : preview.title,
        subtitle: previewSubtitleOrNull(preview.subtitle),
      );
    case 'previous_vs_new_values':
    case 'audit_price_changes':
      return ModuleReportingReportSnapshot.ready(
        columns: columns,
        rows: sourceRows,
        summary: summary,
        breakdown: breakdown,
        title: preview.title.isEmpty ? report.label : preview.title,
        subtitle: previewSubtitleOrNull(preview.subtitle),
      );
    case 'audit_stock_adjustments':
    case 'prescription_controlled_audit':
      return _projectAuditTrail(
        report: report,
        preview: preview,
        columns: columns,
        sourceRows: sourceRows,
        summary: summary,
        breakdown: breakdown,
        includeAuditDiff: includeAuditDiff,
      );
    case 'user_permissions':
      if (summary?['available'] == false) {
        return ModuleReportingReportSnapshot.unavailable(
          title: report.label,
          subtitle: previewSubtitleOrNull(preview.subtitle) ??
              'No permission-assignment audits in range',
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

ModuleReportingReportSnapshot _projectMedicinesCatalog({
  required ModuleReportingReport report,
  required ReportDatasetPreview preview,
  required List<Map<String, Object?>> sourceRows,
  required Map<String, Object?>? summary,
  required Map<String, Object?>? breakdown,
  required String rowKind,
  required List<String> columnKeys,
}) {
  final List<Map<String, Object?>> filtered = sourceRows
      .where(
        (Map<String, Object?> row) =>
            (row['row_kind']?.toString() ?? '') == rowKind,
      )
      .map(
        (Map<String, Object?> row) => <String, Object?>{
          for (final String key in columnKeys) key: row[key],
        },
      )
      .toList(growable: false);

  return ModuleReportingReportSnapshot.ready(
    columns: columnKeys,
    rows: filtered,
    summary: summary,
    breakdown: breakdown,
    title: preview.title.isEmpty ? report.label : preview.title,
    subtitle: previewSubtitleOrNull(preview.subtitle),
  );
}

ModuleReportingReportSnapshot _projectColumnSubset({
  required ModuleReportingReport report,
  required ReportDatasetPreview preview,
  required List<Map<String, Object?>> sourceRows,
  required Map<String, Object?>? summary,
  required Map<String, Object?>? breakdown,
  required List<String> columnKeys,
  String? subtitleOverride,
}) {
  final List<Map<String, Object?>> rows = sourceRows
      .map(
        (Map<String, Object?> row) => <String, Object?>{
          for (final String key in columnKeys) key: row[key],
        },
      )
      .toList(growable: false);

  return ModuleReportingReportSnapshot.ready(
    columns: columnKeys,
    rows: rows,
    summary: summary,
    breakdown: breakdown,
    title: preview.title.isEmpty ? report.label : preview.title,
    subtitle: previewSubtitleOrNull(subtitleOverride) ??
        previewSubtitleOrNull(preview.subtitle),
  );
}

ModuleReportingReportSnapshot _projectControlledActors({
  required ModuleReportingReport report,
  required ReportDatasetPreview preview,
  required List<Map<String, Object?>> sourceRows,
  required Map<String, Object?>? summary,
  required Map<String, Object?>? breakdown,
  required String actorRole,
}) {
  const List<String> columnKeys = <String>[
    'actor',
    'drug',
    'quantity_dispensed',
    'dispensed_at',
  ];
  final List<Map<String, Object?>> rows = sourceRows
      .where(
        (Map<String, Object?> row) =>
            (row['actor_role']?.toString() ?? '') == actorRole,
      )
      .map(
        (Map<String, Object?> row) => <String, Object?>{
          for (final String key in columnKeys) key: row[key],
        },
      )
      .toList(growable: false);

  return ModuleReportingReportSnapshot.ready(
    columns: columnKeys,
    rows: rows,
    summary: summary,
    breakdown: breakdown,
    title: preview.title.isEmpty ? report.label : preview.title,
    subtitle: previewSubtitleOrNull(preview.subtitle),
  );
}

ModuleReportingReportSnapshot _projectAuditTrail({
  required ModuleReportingReport report,
  required ReportDatasetPreview preview,
  required List<String> columns,
  required List<Map<String, Object?>> sourceRows,
  required Map<String, Object?>? summary,
  required Map<String, Object?>? breakdown,
  required bool includeAuditDiff,
}) {
  final List<String> visibleColumns = includeAuditDiff
      ? columns
      : columns.where((String key) => key != 'diff' && key != 'diff_json').toList();
  final List<Map<String, Object?>> rows = sourceRows
      .map((Map<String, Object?> row) {
        final Map<String, Object?> copy = Map<String, Object?>.from(row);
        if (!includeAuditDiff) {
          copy.remove('diff');
          copy.remove('diff_json');
        } else {
          final Object? diff = copy['diff'];
          if (diff is String && diff.length > 160) {
            // Progressive disclosure on narrow viewports / dense tables.
            copy['diff'] = '${diff.substring(0, 157)}…';
          }
        }
        return copy;
      })
      .toList(growable: false);

  return ModuleReportingReportSnapshot.ready(
    columns: visibleColumns,
    rows: rows,
    summary: summary,
    breakdown: breakdown,
    title: preview.title.isEmpty ? report.label : preview.title,
    subtitle: previewSubtitleOrNull(preview.subtitle),
  );
}

ModuleReportingReportSnapshot _projectSupplierPerformance({
  required ModuleReportingReport report,
  required ReportDatasetPreview preview,
  required Map<String, Object?>? summary,
  required Map<String, Object?>? breakdown,
}) {
  const List<String> columnKeys = <String>[
    'supplier',
    'delivery_days',
    'po_count',
    'receipt_count',
    'fulfillment_rate',
  ];
  final Object? bySupplier = breakdown?['by_supplier'];
  final List<Map<String, Object?>> rows = <Map<String, Object?>>[];
  if (bySupplier is List) {
    for (final Object? entry in bySupplier) {
      if (entry is! Map) continue;
      final Map<String, Object?> row = <String, Object?>{
        for (final MapEntry<dynamic, dynamic> item
            in Map<dynamic, dynamic>.from(entry).entries)
          item.key.toString(): item.value,
      };
      rows.add(<String, Object?>{
        for (final String key in columnKeys) key: row[key],
      });
    }
  }

  return ModuleReportingReportSnapshot.ready(
    columns: columnKeys,
    rows: rows,
    summary: summary,
    breakdown: breakdown,
    title: preview.title.isEmpty ? report.label : preview.title,
    subtitle: previewSubtitleOrNull(preview.subtitle) ??
        'Avg delivery_days from goods_receipt vs ordered_at; fulfillment_rate needs PO lines',
  );
}

ModuleReportingReportSnapshot _projectDeliveryTime({
  required ModuleReportingReport report,
  required ReportDatasetPreview preview,
  required List<Map<String, Object?>> sourceRows,
  required Map<String, Object?>? summary,
  required Map<String, Object?>? breakdown,
}) {
  const List<String> columnKeys = <String>[
    'supplier',
    'ordered_at',
    'received_at',
    'delivery_days',
  ];
  final List<Map<String, Object?>> rows = sourceRows
      .where((Map<String, Object?> row) => row['delivery_days'] != null)
      .map(
        (Map<String, Object?> row) => <String, Object?>{
          for (final String key in columnKeys) key: row[key],
        },
      )
      .toList(growable: false);

  return ModuleReportingReportSnapshot.ready(
    columns: columnKeys,
    rows: rows,
    summary: summary,
    breakdown: breakdown,
    title: preview.title.isEmpty ? report.label : preview.title,
    subtitle: previewSubtitleOrNull(preview.subtitle),
  );
}

List<Map<String, Object?>> _supplierBreakdownRows(
  Map<String, Object?>? breakdown,
  List<String> columnKeys,
) {
  final Object? bySupplier = breakdown?['by_supplier'];
  final List<Map<String, Object?>> rows = <Map<String, Object?>>[];
  if (bySupplier is! List) {
    return rows;
  }
  for (final Object? entry in bySupplier) {
    if (entry is! Map) continue;
    final Map<String, Object?> row = <String, Object?>{
      for (final MapEntry<dynamic, dynamic> item
          in Map<dynamic, dynamic>.from(entry).entries)
        item.key.toString(): item.value,
    };
    rows.add(<String, Object?>{
      for (final String key in columnKeys) key: row[key],
    });
  }
  return rows;
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

ModuleReportingReportSnapshot _projectPriceTrends({
  required ModuleReportingReport report,
  required ReportDatasetPreview preview,
  required List<Map<String, Object?>> sourceRows,
  required Map<String, Object?>? summary,
  required Map<String, Object?>? breakdown,
}) {
  const List<String> columnKeys = <String>[
    'changed_at',
    'drug',
    'buy_unit_price',
  ];
  final List<Map<String, Object?>> rows = sourceRows
      .where((Map<String, Object?> row) {
        final Object? field = row['field'];
        return field == null ||
            field.toString().trim().toLowerCase() == 'buy_unit_price';
      })
      .map(
        (Map<String, Object?> row) => <String, Object?>{
          'changed_at': row['changed_at'],
          'drug': row['drug'],
          'buy_unit_price': row['to_value'] ?? row['buy_unit_price'],
        },
      )
      .toList(growable: false);

  return ModuleReportingReportSnapshot.ready(
    columns: columnKeys,
    rows: rows,
    summary: <String, Object?>{
      ...?summary,
      'change_count': rows.length,
    },
    breakdown: breakdown,
    title: preview.title.isEmpty ? report.label : preview.title,
    subtitle: previewSubtitleOrNull(preview.subtitle) ??
        'Historical buy_unit_price from audit_log diffs',
  );
}

ModuleReportingReportSnapshot _projectSupplierReliability({
  required ModuleReportingReport report,
  required ReportDatasetPreview preview,
  required Map<String, Object?>? summary,
  required Map<String, Object?>? breakdown,
}) {
  const List<String> columnKeys = <String>[
    'supplier',
    'reliability_rate',
    'po_count',
    'on_time_count',
    'late_count',
  ];
  final List<Map<String, Object?>> rows =
      _supplierBreakdownRows(breakdown, columnKeys);
  final int slaDays = _asInt(summary?['sla_days']) ?? 7;

  return ModuleReportingReportSnapshot.ready(
    columns: columnKeys,
    rows: rows,
    summary: summary,
    breakdown: breakdown,
    title: preview.title.isEmpty ? report.label : preview.title,
    subtitle: previewSubtitleOrNull(preview.subtitle) ??
        '% of POs with goods_receipt within ${slaDays} days (SLA)',
  );
}

ModuleReportingReportSnapshot _projectOrderFulfillmentRate({
  required ModuleReportingReport report,
  required ReportDatasetPreview preview,
  required Map<String, Object?>? summary,
  required Map<String, Object?>? breakdown,
}) {
  const List<String> columnKeys = <String>[
    'supplier',
    'fulfillment_rate',
    'po_count',
    'receipt_count',
  ];
  final Object? bySupplier = breakdown?['by_supplier'];
  final List<Map<String, Object?>> rows = <Map<String, Object?>>[];
  if (bySupplier is List) {
    for (final Object? entry in bySupplier) {
      if (entry is! Map) continue;
      final Map<String, Object?> row = <String, Object?>{
        for (final MapEntry<dynamic, dynamic> item
            in Map<dynamic, dynamic>.from(entry).entries)
          item.key.toString(): item.value,
      };
      rows.add(<String, Object?>{
        'supplier': row['supplier'],
        'fulfillment_rate':
            row['fulfillment_rate_proxy'] ?? row['fulfillment_rate'],
        'po_count': row['po_count'],
        'receipt_count': row['receipt_count'],
      });
    }
  }

  final Map<String, Object?> projectedSummary = <String, Object?>{
    ...?summary,
    'fulfillment_rate':
        summary?['fulfillment_rate_proxy'] ?? summary?['fulfillment_rate'],
  };

  return ModuleReportingReportSnapshot.ready(
    columns: columnKeys,
    rows: rows,
    summary: projectedSummary,
    breakdown: breakdown,
    title: preview.title.isEmpty ? report.label : preview.title,
    subtitle: previewSubtitleOrNull(preview.subtitle) ??
        'Proxy: receipt-exists / PO-count (ordered vs received qty needs PO lines)',
  );
}

ModuleReportingReportSnapshot _projectLateDeliveries({
  required ModuleReportingReport report,
  required ReportDatasetPreview preview,
  required List<Map<String, Object?>> sourceRows,
  required Map<String, Object?>? summary,
  required Map<String, Object?>? breakdown,
}) {
  const List<String> columnKeys = <String>[
    'supplier',
    'ordered_at',
    'received_at',
    'delivery_days',
  ];
  final int slaDays = _asInt(summary?['sla_days']) ?? 7;
  final List<Map<String, Object?>> rows = sourceRows
      .where((Map<String, Object?> row) {
        if (row['is_late'] == true) return true;
        final int? days = _asInt(row['delivery_days']);
        return days != null && days > slaDays;
      })
      .map(
        (Map<String, Object?> row) => <String, Object?>{
          for (final String key in columnKeys) key: row[key],
        },
      )
      .toList(growable: false);

  return ModuleReportingReportSnapshot.ready(
    columns: columnKeys,
    rows: rows,
    summary: <String, Object?>{
      ...?summary,
      'late_count': summary?['late_count'] ?? rows.length,
    },
    breakdown: breakdown,
    title: preview.title.isEmpty ? report.label : preview.title,
    subtitle: previewSubtitleOrNull(preview.subtitle) ??
        'Receipts with delivery_days > ${slaDays} (SLA)',
  );
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

ModuleReportingReportSnapshot _projectDispensedByPeriod({
  required ModuleReportingReport report,
  required ReportDatasetPreview preview,
  required List<String> columns,
  required List<Map<String, Object?>> sourceRows,
  required Map<String, Object?>? summary,
  required Map<String, Object?>? breakdown,
}) {
  final ModuleReportingReportSnapshot series = _projectPeriodSeries(
    report: report,
    preview: preview,
    columns: columns,
    sourceRows: sourceRows,
    summary: summary,
    breakdown: breakdown,
  );
  final List<Map<String, Object?>> qtyRows = <Map<String, Object?>>[
    for (final Map<String, Object?> row in series.rows)
      <String, Object?>{
        'date': row['date'] ?? row['period'],
        'quantity_dispensed': row['quantity_dispensed'],
      },
  ];
  return ModuleReportingReportSnapshot.ready(
    columns: const <String>['date', 'quantity_dispensed'],
    rows: qtyRows,
    summary: summary == null
        ? null
        : <String, Object?>{
            'quantity_dispensed': summary['quantity_dispensed'],
          },
    breakdown: breakdown,
    title: preview.title.isEmpty ? report.label : preview.title,
    subtitle: previewSubtitleOrNull(preview.subtitle) ??
        'Pack quantity dispensed by period',
  );
}

ModuleReportingReportSnapshot _projectThroughputBreakdown({
  required ModuleReportingReport report,
  required ReportDatasetPreview preview,
  required Map<String, Object?>? summary,
  required Map<String, Object?>? breakdown,
  required String breakdownKey,
  required List<String> fallbackColumns,
  required String subtitleFallback,
}) {
  final Object? raw = breakdown?[breakdownKey];
  final List<Map<String, Object?>> rows = <Map<String, Object?>>[
    if (raw is List)
      for (final Object? entry in raw)
        if (entry is Map)
          <String, Object?>{
            for (final MapEntry<dynamic, dynamic> item
                in Map<dynamic, dynamic>.from(entry).entries)
              item.key.toString(): item.value,
          },
  ];
  final List<String> nextColumns = rows.isEmpty
      ? fallbackColumns
      : rows.first.keys.toList(growable: false);

  return ModuleReportingReportSnapshot.ready(
    columns: nextColumns,
    rows: rows,
    summary: summary,
    breakdown: breakdown,
    title: preview.title.isEmpty ? report.label : preview.title,
    subtitle: previewSubtitleOrNull(preview.subtitle) ?? subtitleFallback,
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
  String? subtitleOverride,
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
  final Map<String, Object?> adjustedSummary = <String, Object?>{
    ...?summary,
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
    subtitle: previewSubtitleOrNull(subtitleOverride) ??
        previewSubtitleOrNull(preview.subtitle),
  );
}

ModuleReportingReportSnapshot _projectNewVsReturning({
  required ModuleReportingReport report,
  required ReportDatasetPreview preview,
  required List<String> columns,
  required List<Map<String, Object?>> sourceRows,
  required Map<String, Object?>? summary,
  required Map<String, Object?>? breakdown,
}) {
  final List<Map<String, Object?>> rows = sourceRows
      .where((Map<String, Object?> row) {
        final String segment = '${row['segment'] ?? ''}'.trim().toLowerCase();
        return segment == 'new' || segment == 'returning';
      })
      .toList(growable: false);

  final Set<String> segments = rows
      .map((Map<String, Object?> row) => '${row['segment']}'.trim().toLowerCase())
      .toSet();
  final num newCount = rows
      .where(
        (Map<String, Object?> row) =>
            '${row['segment']}'.trim().toLowerCase() == 'new',
      )
      .fold<num>(0, (num sum, Map<String, Object?> row) => sum + _asNum(row['customer_count']));
  final num returningCount = rows
      .where(
        (Map<String, Object?> row) =>
            '${row['segment']}'.trim().toLowerCase() == 'returning',
      )
      .fold<num>(
        0,
        (num sum, Map<String, Object?> row) => sum + _asNum(row['customer_count']),
      );

  final Map<String, Object?>? adjustedSummary = <String, Object?>{
    ...?summary,
    'new_count': newCount,
    'returning_count': returningCount,
    'customer_count': newCount + returningCount,
    'disjoint':
        segments.length == rows.length ||
        (segments.contains('new') &&
            segments.contains('returning') &&
            segments.length <= 2),
  };

  return ModuleReportingReportSnapshot.ready(
    columns: columns.contains('segment') && columns.contains('customer_count')
        ? columns
        : const <String>['segment', 'customer_count'],
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
  bool includeDaysToExpiryNegative = false,
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
    if (riskStates.contains(risk)) {
      return true;
    }
    if (includeDaysToExpiryNegative &&
        row['days_to_expiry'] != null &&
        _asNum(row['days_to_expiry']) < 0) {
      return true;
    }
    return false;
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

/// Exclusive buckets: (0,30], (30,60], (60,90], (90,180]. Excludes expired.
String? classifyPharmacyExpiryWindow(Object? daysToExpiry) {
  if (daysToExpiry == null) {
    return null;
  }
  final num days = _asNum(daysToExpiry);
  if (!(days > 0)) {
    return null;
  }
  if (days <= 30) {
    return '0-30';
  }
  if (days <= 60) {
    return '30-60';
  }
  if (days <= 90) {
    return '60-90';
  }
  if (days <= 180) {
    return '90-180';
  }
  return null;
}

ModuleReportingReportSnapshot _projectExpiringWindows({
  required ModuleReportingReport report,
  required ReportDatasetPreview preview,
  required List<String> columns,
  required List<Map<String, Object?>> sourceRows,
  required Map<String, Object?>? summary,
  required Map<String, Object?>? breakdown,
}) {
  final List<Map<String, Object?>> rows = <Map<String, Object?>>[];
  for (final Map<String, Object?> row in sourceRows) {
    final String risk =
        '${row['risk_state'] ?? row['expiry_alert_status'] ?? ''}'
            .trim()
            .toUpperCase();
    if (risk == 'EXPIRED') {
      continue;
    }
    final String? window = classifyPharmacyExpiryWindow(row['days_to_expiry']) ??
        (row['expiry_window']?.toString().trim().isNotEmpty == true
            ? row['expiry_window']!.toString().trim()
            : null);
    if (window == null) {
      continue;
    }
    // Prefer EXPIRING_SOON rows; also accept positive window rows with days.
    if (risk.isNotEmpty && risk != 'EXPIRING_SOON') {
      continue;
    }
    rows.add(<String, Object?>{
      ...row,
      'expiry_window': window,
    });
  }

  final List<String> nextColumns = columns.contains('expiry_window')
      ? columns
      : <String>['expiry_window', ...columns];

  return ModuleReportingReportSnapshot.ready(
    columns: nextColumns,
    rows: rows,
    summary: summary,
    breakdown: breakdown,
    title: preview.title.isEmpty ? report.label : preview.title,
    subtitle: previewSubtitleOrNull(preview.subtitle) ??
        'Exclusive windows (0,30], (30,60], (60,90], (90,180]; expired excluded; at buy cost',
  );
}

ModuleReportingReportSnapshot _projectExpiredStockValue({
  required ModuleReportingReport report,
  required ReportDatasetPreview preview,
  required List<String> columns,
  required List<Map<String, Object?>> sourceRows,
  required Map<String, Object?>? summary,
  required Map<String, Object?>? breakdown,
}) {
  final List<Map<String, Object?>> filtered = sourceRows.where((
    Map<String, Object?> row,
  ) {
    final String risk =
        '${row['risk_state'] ?? row['expiry_alert_status'] ?? ''}'
            .trim()
            .toUpperCase();
    if (risk == 'EXPIRED') {
      return true;
    }
    return row['days_to_expiry'] != null && _asNum(row['days_to_expiry']) < 0;
  }).toList(growable: false);

  return _projectBuyCostValueRows(
    report: report,
    preview: preview,
    columns: columns,
    filtered: filtered,
    summary: summary,
    breakdown: breakdown,
    subtitleFallback: 'Expired batch quantity × buy_unit_price (at buy cost)',
  );
}

ModuleReportingReportSnapshot _projectNearExpiryValue({
  required ModuleReportingReport report,
  required ReportDatasetPreview preview,
  required List<String> columns,
  required List<Map<String, Object?>> sourceRows,
  required Map<String, Object?>? summary,
  required Map<String, Object?>? breakdown,
}) {
  final List<Map<String, Object?>> filtered = sourceRows.where((
    Map<String, Object?> row,
  ) {
    final String risk =
        '${row['risk_state'] ?? row['expiry_alert_status'] ?? ''}'
            .trim()
            .toUpperCase();
    return risk == 'EXPIRING_SOON';
  }).toList(growable: false);

  return _projectBuyCostValueRows(
    report: report,
    preview: preview,
    columns: columns,
    filtered: filtered,
    summary: summary,
    breakdown: breakdown,
    subtitleFallback:
        'EXPIRING_SOON batch quantity × buy_unit_price (at buy cost)',
  );
}

ModuleReportingReportSnapshot _projectBuyCostValueRows({
  required ModuleReportingReport report,
  required ReportDatasetPreview preview,
  required List<String> columns,
  required List<Map<String, Object?>> filtered,
  required Map<String, Object?>? summary,
  required Map<String, Object?>? breakdown,
  required String subtitleFallback,
}) {
  final List<Map<String, Object?>> rows = filtered
      .map((Map<String, Object?> row) {
        final Object? existing = row['value'];
        if (existing != null) {
          return row;
        }
        final num qty = _asNum(row['quantity']);
        final num unit = _asNum(row['unit_cost'] ?? row['buy_unit_price']);
        return <String, Object?>{
          ...row,
          'value': _roundMoney(qty * unit),
        };
      })
      .toList(growable: false);

  final num valueTotal = rows.fold<num>(
    0,
    (num sum, Map<String, Object?> row) => sum + _asNum(row['value']),
  );
  final Map<String, Object?>? adjustedSummary = <String, Object?>{
    ...?summary,
    'value': _roundMoney(valueTotal),
  };

  final List<String> nextColumns = columns.contains('value')
      ? columns
      : <String>[...columns, 'value'];

  return ModuleReportingReportSnapshot.ready(
    columns: nextColumns,
    rows: rows,
    summary: adjustedSummary,
    breakdown: breakdown,
    title: preview.title.isEmpty ? report.label : preview.title,
    subtitle: previewSubtitleOrNull(preview.subtitle) ?? subtitleFallback,
  );
}

ModuleReportingReportSnapshot _projectTodaysProfit({
  required ModuleReportingReport report,
  required ReportDatasetPreview preview,
  required List<String> columns,
  required List<Map<String, Object?>> sourceRows,
  required Map<String, Object?>? summary,
  required Map<String, Object?>? breakdown,
}) {
  num profitTotal = 0;
  bool anyProfit = false;
  for (final Map<String, Object?> row in sourceRows) {
    if (row['profit'] == null) {
      continue;
    }
    anyProfit = true;
    profitTotal += _asNum(row['profit']);
  }
  final Object? summaryProfit = summary?['profit'];
  final Object? resolvedProfit = summaryProfit ?? (anyProfit ? profitTotal : null);

  final Map<String, Object?>? adjustedSummary = <String, Object?>{
    ...?summary,
    'profit': resolvedProfit == null ? null : _roundMoney(_asNum(resolvedProfit)),
  };

  return ModuleReportingReportSnapshot.ready(
    columns: columns,
    rows: sourceRows,
    summary: adjustedSummary,
    breakdown: breakdown,
    title: preview.title.isEmpty ? report.label : preview.title,
    subtitle: previewSubtitleOrNull(preview.subtitle) ??
        'Dispense profit for calendar today (null when buy cost unset)',
  );
}

ModuleReportingReportSnapshot _projectExpiryLossesBreakdown({
  required ModuleReportingReport report,
  required ReportDatasetPreview preview,
  required List<Map<String, Object?>> sourceRows,
  required Map<String, Object?>? summary,
  required Map<String, Object?>? breakdown,
}) {
  final Map<String, Map<String, Object?>> grouped =
      <String, Map<String, Object?>>{};
  for (final Map<String, Object?> row in sourceRows) {
    final String risk =
        '${row['risk_state'] ?? row['expiry_alert_status'] ?? ''}'
            .trim()
            .toUpperCase();
    final bool expired = risk == 'EXPIRED' ||
        (row['days_to_expiry'] != null && _asNum(row['days_to_expiry']) < 0);
    if (!expired) {
      continue;
    }
    final String drug =
        '${row['drug'] ?? row['inventory_item'] ?? 'Unknown'}'.trim();
    final String category = '${row['category'] ?? ''}'.trim();
    final String supplierId = '${row['supplier_id'] ?? ''}'.trim();
    final String supplier = '${row['supplier'] ?? ''}'.trim();
    final String key = '$drug|$category|$supplierId';
    final Map<String, Object?> current = grouped.putIfAbsent(
      key,
      () => <String, Object?>{
        'drug': drug,
        'category': category.isEmpty ? null : category,
        'supplier_id': supplierId.isEmpty ? null : supplierId,
        'supplier': supplier.isEmpty ? null : supplier,
        'quantity': 0,
        'value': 0,
      },
    );
    current['quantity'] = _asNum(current['quantity']) + _asNum(row['quantity']);
    current['value'] = _asNum(current['value']) + _asNum(row['value']);
  }

  final List<Map<String, Object?>> rows = grouped.values.toList(growable: false)
    ..sort(
      (Map<String, Object?> left, Map<String, Object?> right) =>
          _asNum(right['value']).compareTo(_asNum(left['value'])),
    );

  final num valueTotal = rows.fold<num>(
    0,
    (num sum, Map<String, Object?> row) => sum + _asNum(row['value']),
  );

  return ModuleReportingReportSnapshot.ready(
    columns: const <String>[
      'drug',
      'category',
      'supplier',
      'supplier_id',
      'quantity',
      'value',
    ],
    rows: rows,
    summary: <String, Object?>{
      ...?summary,
      'value': valueTotal,
      'drug_count': rows.length,
    },
    breakdown: breakdown,
    title: preview.title.isEmpty ? report.label : preview.title,
    subtitle: previewSubtitleOrNull(preview.subtitle) ??
        'Expired value by drug / inventory category / supplier (at buy cost)',
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
  String sortKey = 'amount',
  bool excludeNullSortKey = false,
}) {
  final List<Map<String, Object?>> eligible = excludeNullSortKey
      ? rows
          .where((Map<String, Object?> row) => row[sortKey] != null)
          .toList(growable: false)
      : rows;
  final List<Map<String, Object?>> sorted =
      List<Map<String, Object?>>.from(eligible)
        ..sort((Map<String, Object?> left, Map<String, Object?> right) {
          final int byPrimary =
              _asNum(right[sortKey]).compareTo(_asNum(left[sortKey]));
          if (byPrimary != 0) {
            return byPrimary;
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

/// Daily purchase inbound totals from `occurred_at` (same amount basis as purchase_value).
ModuleReportingReportSnapshot _projectPurchaseTrends({
  required ModuleReportingReport report,
  required ReportDatasetPreview preview,
  required List<Map<String, Object?>> sourceRows,
  required Map<String, Object?>? summary,
  required Map<String, Object?>? breakdown,
}) {
  final Map<String, Map<String, Object?>> byDate = <String, Map<String, Object?>>{};
  for (final Map<String, Object?> row in sourceRows) {
    final String date = _dateKey(row['occurred_at'] ?? row['date']);
    if (date.isEmpty) {
      continue;
    }
    final Map<String, Object?> bucket = byDate.putIfAbsent(
      date,
      () => <String, Object?>{
        'date': date,
        'amount': 0,
        'quantity': 0,
      },
    );
    bucket['amount'] = _asNum(bucket['amount']) + _asNum(row['amount']);
    bucket['quantity'] = _asNum(bucket['quantity']) + _asNum(row['quantity']);
  }

  final List<Map<String, Object?>> rows = byDate.values
      .map(
        (Map<String, Object?> row) => <String, Object?>{
          'date': row['date'],
          'amount': _roundMoney(_asNum(row['amount'])),
          'quantity': _asNum(row['quantity']),
        },
      )
      .toList(growable: false)
    ..sort(
      (Map<String, Object?> left, Map<String, Object?> right) =>
          '${left['date']}'.compareTo('${right['date']}'),
    );

  final num amountTotal = rows.fold<num>(
    0,
    (num sum, Map<String, Object?> row) => sum + _asNum(row['amount']),
  );

  return ModuleReportingReportSnapshot.ready(
    columns: const <String>['date', 'amount', 'quantity'],
    rows: rows,
    summary: <String, Object?>{
      ...?summary,
      'amount': summary?['amount'] ?? _roundMoney(amountTotal),
      'quantity': summary?['quantity'] ??
          rows.fold<num>(
            0,
            (num sum, Map<String, Object?> row) => sum + _asNum(row['quantity']),
          ),
    },
    breakdown: breakdown,
    title: preview.title.isEmpty ? report.label : preview.title,
    subtitle: previewSubtitleOrNull(preview.subtitle) ??
        'Daily inbound purchase value (same as purchase_value)',
  );
}

/// Unusual stock adjustments: |qty| > mean(|qty|) + 2σ when n≥2; else |qty| ≥ 10.
ModuleReportingReportSnapshot _projectUnusualAdjustments({
  required ModuleReportingReport report,
  required ReportDatasetPreview preview,
  required List<String> columns,
  required List<Map<String, Object?>> sourceRows,
  required Map<String, Object?>? summary,
  required Map<String, Object?>? breakdown,
}) {
  final List<Map<String, Object?>> unusual = sourceRows
      .where(
        (Map<String, Object?> row) => isPharmacyUnusualAdjustmentQuantity(
          row['quantity'],
          sourceRows.map((Map<String, Object?> r) => r['quantity']),
        ),
      )
      .toList(growable: false);

  return ModuleReportingReportSnapshot.ready(
    columns: columns,
    rows: unusual,
    summary: <String, Object?>{
      ...?summary,
      'adjustment_count': unusual.length,
      'quantity': unusual.fold<num>(
        0,
        (num sum, Map<String, Object?> row) => sum + _asNum(row['quantity']),
      ),
      'threshold':
          '|qty| > mean+${kPharmacyUnusualAdjustmentSigma}σ (n≥2) else |qty|≥$kPharmacyUnusualAdjustmentAbsFloor',
    },
    breakdown: breakdown,
    title: preview.title.isEmpty ? report.label : preview.title,
    subtitle: previewSubtitleOrNull(preview.subtitle) ??
        'Unusual: |qty| > mean(|qty|)+${kPharmacyUnusualAdjustmentSigma}σ (n≥2); else |qty|≥$kPharmacyUnusualAdjustmentAbsFloor',
  );
}

/// Shared unusual-adjustment predicate for provider + unit tests.
bool isPharmacyUnusualAdjustmentQuantity(
  Object? quantity,
  Iterable<Object?> peerQuantities,
) {
  final num absQty = _asNum(quantity).abs();
  final List<num> absPeers = peerQuantities
      .map((Object? value) => _asNum(value).abs())
      .toList(growable: false);
  if (absPeers.length < 2) {
    return absQty >= kPharmacyUnusualAdjustmentAbsFloor;
  }
  final num mean =
      absPeers.fold<num>(0, (num sum, num value) => sum + value) /
          absPeers.length;
  num varianceSum = 0;
  for (final num value in absPeers) {
    final num delta = value - mean;
    varianceSum += delta * delta;
  }
  final num stdDev = _sqrt(varianceSum / absPeers.length);
  final num cutoff = mean + (kPharmacyUnusualAdjustmentSigma * stdDev);
  return absQty > cutoff;
}

String _dateKey(Object? value) {
  if (value == null) {
    return '';
  }
  if (value is DateTime) {
    final String month = value.month.toString().padLeft(2, '0');
    final String day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
  final String raw = value.toString().trim();
  if (raw.length >= 10) {
    return raw.substring(0, 10);
  }
  return raw;
}

num _sqrt(num value) {
  if (value <= 0) {
    return 0;
  }
  return math.sqrt(value.toDouble());
}

num _roundMoney(num value) => (value * 100).round() / 100;

num _asNum(Object? value) {
  if (value is num) {
    return value;
  }
  if (value is String) {
    return num.tryParse(value) ?? 0;
  }
  return 0;
}
