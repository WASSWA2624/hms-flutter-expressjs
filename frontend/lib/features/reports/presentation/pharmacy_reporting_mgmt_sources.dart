import 'package:hosspi_hms/shared/reporting/reporting.dart';

/// Named source contract for each management / executive report.
///
/// Management dialogs compose existing category datasets — same formulas, no
/// executive-only money math. [datasetKey] null = honest unavailable (schema gap).
final class PharmacyReportingMgmtComposition {
  const PharmacyReportingMgmtComposition({
    required this.id,
    required this.label,
    required this.sourceReportId,
    required this.projectionNote,
    this.datasetKey,
    this.contentKind = ModuleReportingContentKind.table,
  });

  final String id;
  final String label;

  /// Catalog report id whose dataset + formulas this management id reuses.
  final String sourceReportId;
  final String? datasetKey;
  final ModuleReportingContentKind contentKind;

  /// Short projection / filter note for parity docs and subtitles.
  final String projectionNote;

  bool get hasBackend =>
      datasetKey != null && datasetKey!.trim().isNotEmpty;
}

/// Absolute qty floor when sample size is too small for σ (documented threshold).
const int kPharmacyUnusualAdjustmentAbsFloor = 10;

/// Unusual = |qty| > mean(|qty|) + [kPharmacyUnusualAdjustmentSigma]σ (n ≥ 2).
const num kPharmacyUnusualAdjustmentSigma = 2;

/// All `mgmt_*` compositions (stable ids; order matches Management catalog).
const List<PharmacyReportingMgmtComposition> pharmacyReportingMgmtCompositions =
    <PharmacyReportingMgmtComposition>[
  PharmacyReportingMgmtComposition(
    id: 'mgmt_revenue',
    label: 'Financial: Revenue',
    sourceReportId: 'revenue',
    datasetKey: 'pharmacy_financial_revenue',
    contentKind: ModuleReportingContentKind.chart,
    projectionNote: 'period_series / daily_totals',
  ),
  PharmacyReportingMgmtComposition(
    id: 'mgmt_expenses',
    label: 'Financial: Expenses',
    sourceReportId: 'operating_expenses',
    datasetKey: 'pharmacy_financial_operating_expenses',
    projectionNote: 'pass-through expenditures ledger',
  ),
  PharmacyReportingMgmtComposition(
    id: 'mgmt_gross_profit',
    label: 'Financial: Gross profit',
    sourceReportId: 'gross_profit',
    datasetKey: 'pharmacy_financial_gross_profit',
    projectionNote: 'pass-through dispense retail margin',
  ),
  PharmacyReportingMgmtComposition(
    id: 'mgmt_net_profit',
    label: 'Financial: Net profit',
    sourceReportId: 'net_profit',
    datasetKey: 'pharmacy_financial_net_profit',
    projectionNote: 'pass-through gross − refunds − write_offs',
  ),
  PharmacyReportingMgmtComposition(
    id: 'mgmt_profit_margin',
    label: 'Financial: Profit margin',
    sourceReportId: 'gross_profit',
    datasetKey: 'pharmacy_financial_gross_profit',
    projectionNote: 'profit_margin = profit / amount',
  ),
  PharmacyReportingMgmtComposition(
    id: 'mgmt_stock_value',
    label: 'Inventory: Stock value',
    sourceReportId: 'stock_value',
    datasetKey: 'inventory_stock_value',
    projectionNote: 'pass-through qty × buy_unit_price',
  ),
  PharmacyReportingMgmtComposition(
    id: 'mgmt_fast_moving',
    label: 'Inventory: Fast-moving stock',
    sourceReportId: 'fast_moving',
    datasetKey: 'inventory_stock_velocity',
    projectionNote: 'velocity_class FAST',
  ),
  PharmacyReportingMgmtComposition(
    id: 'mgmt_slow_moving',
    label: 'Inventory: Slow-moving stock',
    sourceReportId: 'slow_moving',
    datasetKey: 'inventory_stock_velocity',
    projectionNote: 'velocity_class SLOW',
  ),
  PharmacyReportingMgmtComposition(
    id: 'mgmt_expiring',
    label: 'Inventory: Expiring stock',
    sourceReportId: 'near_expiry_stock',
    datasetKey: 'inventory_stock_risk',
    projectionNote: 'EXPIRING_SOON',
  ),
  PharmacyReportingMgmtComposition(
    id: 'mgmt_dead_stock',
    label: 'Inventory: Dead stock',
    sourceReportId: 'dead_stock',
    datasetKey: 'inventory_stock_velocity',
    projectionNote: 'velocity_class DEAD',
  ),
  PharmacyReportingMgmtComposition(
    id: 'mgmt_stock_turnover',
    label: 'Inventory: Stock turnover',
    sourceReportId: 'stock_turnover',
    datasetKey: 'inventory_stock_turnover',
    contentKind: ModuleReportingContentKind.chart,
    projectionNote: 'pass-through turnover formula',
  ),
  PharmacyReportingMgmtComposition(
    id: 'mgmt_sales_trend',
    label: 'Sales: Sales trend',
    sourceReportId: 'sales_by_period',
    datasetKey: 'pharmacy_drug_consumption',
    contentKind: ModuleReportingContentKind.chart,
    projectionNote: 'period_series / daily_totals',
  ),
  PharmacyReportingMgmtComposition(
    id: 'mgmt_top_products',
    label: 'Sales: Top products',
    sourceReportId: 'frequently_purchased_medicines',
    datasetKey: 'pharmacy_drug_consumption',
    projectionNote: 'top 20 by amount',
  ),
  PharmacyReportingMgmtComposition(
    id: 'mgmt_top_categories',
    label: 'Sales: Top categories',
    sourceReportId: 'sales_by_category',
    datasetKey: 'pharmacy_sales_by_category',
    projectionNote: 'top 10 by amount',
  ),
  PharmacyReportingMgmtComposition(
    id: 'mgmt_top_customers',
    label: 'Sales: Top customers',
    sourceReportId: 'purchases_by_customer',
    datasetKey: 'pharmacy_sales_by_customer',
    projectionNote: 'top 10 by amount',
  ),
  PharmacyReportingMgmtComposition(
    id: 'mgmt_sales_by_staff_branch',
    label: 'Sales: Sales by staff/branch',
    sourceReportId: 'sales_by_staff',
    datasetKey: 'pharmacy_sales_by_staff',
    projectionNote: 'staff slice; branch = facility scope',
  ),
  PharmacyReportingMgmtComposition(
    id: 'mgmt_supplier_spend',
    label: 'Procurement: Supplier spend',
    sourceReportId: 'supplier_spend',
    datasetKey: 'pharmacy_purchases_by_supplier',
    projectionNote: 'supplier amount (inbound × buy)',
  ),
  PharmacyReportingMgmtComposition(
    id: 'mgmt_purchase_trends',
    label: 'Procurement: Purchase trends',
    sourceReportId: 'purchase_value',
    datasetKey: 'pharmacy_purchase_inbound_value',
    contentKind: ModuleReportingContentKind.chart,
    projectionNote: 'daily amount from occurred_at',
  ),
  PharmacyReportingMgmtComposition(
    id: 'mgmt_supplier_performance',
    label: 'Procurement: Supplier performance',
    sourceReportId: 'supplier_performance',
    datasetKey: 'pharmacy_purchase_orders',
    projectionNote: 'by_supplier fulfillment / delivery',
  ),
  PharmacyReportingMgmtComposition(
    id: 'mgmt_expired_medicines',
    label: 'Risk: Expired medicines',
    sourceReportId: 'expired_stock',
    datasetKey: 'inventory_stock_risk',
    projectionNote: 'EXPIRED',
  ),
  PharmacyReportingMgmtComposition(
    id: 'mgmt_stock_outs',
    label: 'Risk: Stock-outs',
    sourceReportId: 'out_of_stock',
    datasetKey: 'inventory_stock_risk',
    projectionNote: 'OUT_OF_STOCK / qty≤0',
  ),
  // Pack 13 controlled marker not shipped — keep unavailable (no fake stock).
  PharmacyReportingMgmtComposition(
    id: 'mgmt_controlled_medicines',
    label: 'Risk: Controlled medicines',
    sourceReportId: 'controlled_medicine_stock',
    datasetKey: null,
    projectionNote: 'gap: awaiting drug.is_controlled (pack 13)',
  ),
  PharmacyReportingMgmtComposition(
    id: 'mgmt_unusual_adjustments',
    label: 'Risk: Unusual adjustments',
    sourceReportId: 'stock_adjustments',
    datasetKey: 'inventory_stock_adjustments',
    projectionNote:
        'leave-one-out |qty| > mean+${kPharmacyUnusualAdjustmentSigma}σ (n≥2); else |qty|≥$kPharmacyUnusualAdjustmentAbsFloor',
  ),
  PharmacyReportingMgmtComposition(
    id: 'mgmt_high_value_losses',
    label: 'Risk: High-value losses',
    sourceReportId: 'stock_write_offs',
    datasetKey: 'inventory_stock_write_offs',
    projectionNote: 'DAMAGE|EXPIRY write-offs by value desc',
  ),
];

/// Lookup by management report id.
Map<String, PharmacyReportingMgmtComposition>
    get pharmacyReportingMgmtCompositionById =>
        <String, PharmacyReportingMgmtComposition>{
          for (final PharmacyReportingMgmtComposition entry
              in pharmacyReportingMgmtCompositions)
            entry.id: entry,
        };
