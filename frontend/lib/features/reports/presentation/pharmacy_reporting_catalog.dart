import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/features/reports/presentation/pharmacy_reporting_mgmt_sources.dart';
import 'package:hosspi_hms/features/reports/presentation/reports_access.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/reporting/reporting.dart';

/// Pharmacy aliases for the shared module reporting catalog models.
typedef PharmacyReportingContentKind = ModuleReportingContentKind;
typedef PharmacyReportingReport = ModuleReportingReport;
typedef PharmacyReportingCategory = ModuleReportingCategory;

/// Stable category ids (also used by Reporting advanced filters).
abstract final class PharmacyReportingCategoryIds {
  static const String salesRevenue = 'sales_revenue';
  static const String inventoryStock = 'inventory_stock';
  static const String medicinesProducts = 'medicines_products';
  static const String purchasingSuppliers = 'purchasing_suppliers';
  static const String dispensing = 'dispensing';
  static const String patientsCustomers = 'patients_customers';
  static const String expiryLoss = 'expiry_loss';
  static const String financial = 'financial';
  static const String staffActivity = 'staff_activity';
  static const String branch = 'branch';
  static const String stockTransfers = 'stock_transfers';
  static const String prescriptionClinical = 'prescription_clinical';
  static const String controlledMedicines = 'controlled_medicines';
  static const String supplierProcurement = 'supplier_procurement';
  static const String operationalKpis = 'operational_kpis';
  static const String auditCompliance = 'audit_compliance';
  static const String managementExecutive = 'management_executive';
}

String pharmacyReportingCategoryLabel(
  AppLocalizations l10n,
  String categoryId,
) {
  return switch (categoryId) {
    PharmacyReportingCategoryIds.salesRevenue =>
      l10n.reportsPharmacyReportingCategorySales,
    PharmacyReportingCategoryIds.inventoryStock =>
      l10n.reportsPharmacyReportingCategoryInventory,
    PharmacyReportingCategoryIds.medicinesProducts =>
      l10n.reportsPharmacyReportingCategoryMedicines,
    PharmacyReportingCategoryIds.purchasingSuppliers =>
      l10n.reportsPharmacyReportingCategoryPurchasing,
    PharmacyReportingCategoryIds.dispensing =>
      l10n.reportsPharmacyReportingCategoryDispensing,
    PharmacyReportingCategoryIds.patientsCustomers =>
      l10n.reportsPharmacyReportingCategoryCustomers,
    PharmacyReportingCategoryIds.expiryLoss =>
      l10n.reportsPharmacyReportingCategoryExpiry,
    PharmacyReportingCategoryIds.financial =>
      l10n.reportsPharmacyReportingCategoryFinancial,
    PharmacyReportingCategoryIds.staffActivity =>
      l10n.reportsPharmacyReportingCategoryStaff,
    PharmacyReportingCategoryIds.branch =>
      l10n.reportsPharmacyReportingCategoryBranch,
    PharmacyReportingCategoryIds.stockTransfers =>
      l10n.reportsPharmacyReportingCategoryTransfers,
    PharmacyReportingCategoryIds.prescriptionClinical =>
      l10n.reportsPharmacyReportingCategoryPrescription,
    PharmacyReportingCategoryIds.controlledMedicines =>
      l10n.reportsPharmacyReportingCategoryControlled,
    PharmacyReportingCategoryIds.supplierProcurement =>
      l10n.reportsPharmacyReportingCategoryProcurement,
    PharmacyReportingCategoryIds.operationalKpis =>
      l10n.reportsPharmacyReportingCategoryKpis,
    PharmacyReportingCategoryIds.auditCompliance =>
      l10n.reportsPharmacyReportingCategoryAudit,
    PharmacyReportingCategoryIds.managementExecutive =>
      l10n.reportsPharmacyReportingCategoryManagement,
    _ => categoryId,
  };
}

/// Operational KPI ids whose labels imply calendar today — dialog opens on today.
bool pharmacyReportingForcesTodayPeriod(String reportId) {
  return reportId == 'total_sales_today' || reportId == 'todays_profit';
}

PharmacyReportingReport _report(
  String categoryId,
  String id,
  String label, {
  PharmacyReportingContentKind kind = PharmacyReportingContentKind.table,
  String? datasetKey,
  ModuleReportingPeriodPreset? initialPeriodPreset,
}) {
  return PharmacyReportingReport(
    id: id,
    categoryId: categoryId,
    label: label,
    contentKind: kind,
    datasetKey: datasetKey,
    initialPeriodPreset: initialPeriodPreset,
  );
}

List<PharmacyReportingReport> _reports(
  String categoryId,
  List<(String, String, PharmacyReportingContentKind?, String?)> rows,
) {
  return rows
      .map(
        (
          (String, String, PharmacyReportingContentKind?, String?) row,
        ) {
          return _report(
            categoryId,
            row.$1,
            row.$2,
            kind: row.$3 ?? PharmacyReportingContentKind.table,
            datasetKey: row.$4,
            initialPeriodPreset: pharmacyReportingForcesTodayPeriod(row.$1)
                ? ModuleReportingPeriodPreset.today
                : null,
          );
        },
      )
      .toList(growable: false);
}

/// Full pharmacy reporting catalog from `.cursor/reporting-analytics.md/pharmacy-reporting.md`.
List<PharmacyReportingCategory> pharmacyReportingCatalog() {
  const String sales = PharmacyReportingCategoryIds.salesRevenue;
  const String inventory = PharmacyReportingCategoryIds.inventoryStock;
  const String medicines = PharmacyReportingCategoryIds.medicinesProducts;
  const String purchasing = PharmacyReportingCategoryIds.purchasingSuppliers;
  const String dispensing = PharmacyReportingCategoryIds.dispensing;
  const String customers = PharmacyReportingCategoryIds.patientsCustomers;
  const String expiry = PharmacyReportingCategoryIds.expiryLoss;
  const String financial = PharmacyReportingCategoryIds.financial;
  const String staff = PharmacyReportingCategoryIds.staffActivity;
  const String branch = PharmacyReportingCategoryIds.branch;
  const String transfers = PharmacyReportingCategoryIds.stockTransfers;
  const String prescription = PharmacyReportingCategoryIds.prescriptionClinical;
  const String controlled = PharmacyReportingCategoryIds.controlledMedicines;
  const String procurement = PharmacyReportingCategoryIds.supplierProcurement;
  const String kpis = PharmacyReportingCategoryIds.operationalKpis;
  const String audit = PharmacyReportingCategoryIds.auditCompliance;
  const String management = PharmacyReportingCategoryIds.managementExecutive;

  return <PharmacyReportingCategory>[
    PharmacyReportingCategory(
      id: sales,
      icon: Icons.point_of_sale_outlined,
      reports: _reports(sales, <(String, String, PharmacyReportingContentKind?, String?)>[
        ('total_sales', 'Total sales', null, 'pharmacy_drug_consumption'),
        ('sales_by_period', 'Sales by day/week/month/year', PharmacyReportingContentKind.chart, 'pharmacy_drug_consumption'),
        ('sales_by_medicine', 'Sales by medicine/product', null, 'pharmacy_drug_consumption'),
        ('sales_by_category', 'Sales by category', null, 'pharmacy_sales_by_category'),
        ('sales_by_cashier', 'Sales by cashier/user', null, null),
        ('sales_by_branch', 'Sales by branch', null, 'pharmacy_sales_by_branch'),
        ('sales_by_customer', 'Sales by customer/patient', null, 'pharmacy_sales_by_customer'),
        ('sales_by_payment_method', 'Cash, card, mobile money, credit sales', null, 'pharmacy_sales_payment_methods'),
        ('discounts', 'Discounts', null, 'pharmacy_sales_discounts'),
        ('refunds_returns', 'Refunds/returns', null, 'pharmacy_sales_refunds'),
        ('gross_revenue', 'Gross revenue', null, 'pharmacy_drug_consumption'),
        ('net_revenue', 'Net revenue', null, 'pharmacy_sales_net_revenue'),
        ('profit_and_margin', 'Profit and profit margin', null, 'pharmacy_drug_consumption'),
        ('tax_vat', 'Tax/VAT', null, null),
        ('average_transaction_value', 'Average transaction value', null, 'pharmacy_sales_avg_transaction'),
        ('number_of_transactions', 'Number of transactions', null, 'pharmacy_dispense_throughput'),
      ]),
    ),
    PharmacyReportingCategory(
      id: inventory,
      icon: Icons.inventory_2_outlined,
      reports: _reports(inventory, <(String, String, PharmacyReportingContentKind?, String?)>[
        ('current_stock_quantity', 'Current stock quantity', null, 'inventory_stock_risk'),
        ('stock_value', 'Stock value', null, 'inventory_stock_value'),
        ('opening_closing_stock', 'Opening and closing stock', null, 'inventory_opening_closing'),
        ('stock_received', 'Stock received', null, 'inventory_stock_received'),
        ('stock_issued', 'Stock issued/dispensed', null, 'inventory_stock_issued'),
        ('stock_adjustments', 'Stock adjustments', null, 'inventory_stock_adjustments'),
        ('damaged_stock', 'Damaged stock', null, 'inventory_damaged_stock'),
        ('lost_stock', 'Lost/missing stock', null, 'inventory_lost_stock'),
        ('expired_stock', 'Expired stock', null, 'inventory_stock_risk'),
        ('near_expiry_stock', 'Near-expiry stock', null, 'inventory_stock_risk'),
        ('overstock', 'Overstock', null, 'inventory_stock_risk'),
        ('understock', 'Understock', null, 'inventory_stock_risk'),
        ('out_of_stock', 'Out-of-stock items', null, 'inventory_stock_risk'),
        ('reorder_level', 'Reorder level', null, 'inventory_reorder'),
        ('reorder_quantity', 'Reorder quantity', null, 'inventory_reorder'),
        ('stock_turnover', 'Stock turnover', PharmacyReportingContentKind.chart, 'inventory_stock_turnover'),
        ('fast_moving', 'Fast-moving products', null, 'inventory_stock_velocity'),
        ('slow_moving', 'Slow-moving products', null, 'inventory_stock_velocity'),
        ('dead_stock', 'Dead stock', null, 'inventory_stock_velocity'),
        ('stock_movement_history', 'Stock movement history', null, 'inventory_stock_movement_history'),
      ]),
    ),
    PharmacyReportingCategory(
      id: medicines,
      icon: Icons.medication_outlined,
      reports: _reports(medicines, <(String, String, PharmacyReportingContentKind?, String?)>[
        ('medicine_name', 'Medicine name', null, 'pharmacy_medicines_catalog'),
        ('generic_brand_name', 'Generic/brand name', null, 'pharmacy_medicines_catalog'),
        ('medicine_category', 'Category', null, 'pharmacy_medicines_catalog'),
        ('strength', 'Strength', null, 'pharmacy_medicines_catalog'),
        ('dosage_form', 'Dosage form', null, 'pharmacy_medicines_catalog'),
        ('unit_of_measure', 'Unit of measure', null, 'pharmacy_medicines_catalog'),
        ('batch_lot', 'Batch/lot number', null, 'pharmacy_medicines_catalog'),
        ('manufacturing_date', 'Manufacturing date', null, 'pharmacy_medicines_catalog'),
        ('expiry_date', 'Expiry date', null, 'pharmacy_medicines_catalog'),
        ('selling_price', 'Selling price', null, 'pharmacy_medicines_catalog'),
        ('purchase_price', 'Purchase price', null, 'pharmacy_medicines_catalog'),
        ('profit_per_unit', 'Profit per unit', null, 'pharmacy_medicines_catalog'),
        ('profit_margin', 'Profit margin', null, 'pharmacy_medicines_catalog'),
        // Schema gap: barcode — keep unavailable (do not use asset.barcode).
        // is_controlled migrated — see controlled medicines category + pharmacy_controlled_*.
        ('barcode', 'Barcode', null, null),
        ('prescription_controlled_status', 'Prescription/controlled status', null, null),
        ('storage_requirements', 'Storage requirements', null, 'pharmacy_medicines_catalog'),
      ]),
    ),
    PharmacyReportingCategory(
      id: purchasing,
      icon: Icons.local_shipping_outlined,
      reports: _reports(purchasing, <(String, String, PharmacyReportingContentKind?, String?)>[
        ('purchase_orders', 'Purchase orders', null, 'pharmacy_purchase_orders'),
        ('purchases_by_supplier', 'Purchases by supplier', null, 'pharmacy_purchases_by_supplier'),
        ('purchase_value', 'Purchase value', null, 'pharmacy_purchase_inbound_value'),
        ('outstanding_supplier_invoices', 'Outstanding supplier invoices', null, null),
        ('payment_history', 'Payment history', null, null),
        ('supplier_pricing', 'Supplier pricing', null, 'pharmacy_supplier_pricing'),
        ('supplier_performance', 'Supplier performance', PharmacyReportingContentKind.chart, 'pharmacy_purchase_orders'),
        ('delivery_time', 'Delivery time', null, 'pharmacy_purchase_orders'),
        ('quantity_ordered_vs_received', 'Quantity ordered vs received', null, null),
        ('purchase_returns', 'Purchase returns', null, 'pharmacy_purchase_returns'),
        ('price_changes', 'Price changes', null, 'pharmacy_drug_price_changes'),
        ('most_used_suppliers', 'Most-used suppliers', null, 'pharmacy_purchases_by_supplier'),
      ]),
    ),
    PharmacyReportingCategory(
      id: dispensing,
      icon: Icons.medical_services_outlined,
      reports: _reports(dispensing, <(String, String, PharmacyReportingContentKind?, String?)>[
        ('number_of_prescriptions', 'Number of prescriptions', null, 'pharmacy_dispense_throughput'),
        ('items_dispensed', 'Number of items dispensed', null, 'pharmacy_drug_consumption'),
        ('medicines_dispensed_by_period', 'Medicines dispensed by period', PharmacyReportingContentKind.chart, 'pharmacy_drug_consumption'),
        ('medicines_dispensed_by_prescriber', 'Medicines dispensed by prescriber', null, 'pharmacy_dispensing_by_prescriber'),
        ('medicines_dispensed_by_patient', 'Medicines dispensed by patient', null, 'pharmacy_sales_by_customer'),
        ('prescription_status', 'Prescription status', null, 'pharmacy_dispense_throughput'),
        ('dispensing_errors_voids', 'Dispensing errors/voids', null, 'pharmacy_dispense_throughput'),
        ('partial_dispensing', 'Partial dispensing', null, 'pharmacy_dispensing_partial'),
        ('prescription_frequency', 'Prescription frequency', null, 'pharmacy_dispensing_frequency'),
        ('average_items_per_prescription', 'Average items per prescription', null, 'pharmacy_dispensing_avg_items'),
      ]),
    ),
    PharmacyReportingCategory(
      id: customers,
      icon: Icons.people_outline,
      reports: _reports(customers, <(String, String, PharmacyReportingContentKind?, String?)>[
        ('number_of_customers', 'Number of customers', null, 'pharmacy_customer_count'),
        ('new_vs_returning', 'New vs returning customers', PharmacyReportingContentKind.chart, 'pharmacy_customers_new_vs_returning'),
        ('purchases_by_customer', 'Purchases by customer', null, 'pharmacy_sales_by_customer'),
        ('patient_medication_history', 'Patient medication history', null, 'pharmacy_patient_medication_history'),
        ('customer_credit_balance', 'Customer credit balance', null, 'pharmacy_customer_credit_balance'),
        ('outstanding_payments', 'Outstanding payments', null, 'pharmacy_customer_outstanding'),
        ('frequently_purchased_medicines', 'Frequently purchased medicines', null, 'pharmacy_drug_consumption'),
        ('customer_demographics', 'Customer demographics', null, 'pharmacy_customer_demographics'),
        ('customer_retention', 'Customer retention', PharmacyReportingContentKind.chart, 'pharmacy_customer_retention'),
      ]),
    ),
    PharmacyReportingCategory(
      id: expiry,
      icon: Icons.event_busy_outlined,
      reports: _reports(expiry, <(String, String, PharmacyReportingContentKind?, String?)>[
        ('expiring_windows', 'Medicines expiring within 30/60/90/180 days', null, 'inventory_stock_risk'),
        ('already_expired', 'Already expired medicines', null, 'inventory_stock_risk'),
        ('expired_stock_value', 'Value of expired stock', null, 'inventory_stock_risk'),
        ('damaged_stock_loss', 'Damaged stock', null, 'inventory_damaged_stock'),
        ('lost_stock_loss', 'Lost stock', null, 'inventory_lost_stock'),
        ('stock_write_offs', 'Stock write-offs', null, 'inventory_stock_write_offs'),
        ('adjustment_reasons', 'Reasons for adjustments', null, 'inventory_adjustment_reasons'),
        ('expiry_losses_breakdown', 'Expiry losses by product/category/supplier', null, 'inventory_stock_risk'),
      ]),
    ),
    PharmacyReportingCategory(
      id: financial,
      icon: Icons.payments_outlined,
      reports: _reports(financial, <(String, String, PharmacyReportingContentKind?, String?)>[
        ('revenue', 'Revenue', PharmacyReportingContentKind.chart, 'pharmacy_financial_revenue'),
        ('cogs', 'Cost of goods sold', null, 'pharmacy_financial_cogs'),
        ('gross_profit', 'Gross profit', null, 'pharmacy_financial_gross_profit'),
        ('net_profit', 'Net profit', null, 'pharmacy_financial_net_profit'),
        ('operating_expenses', 'Operating expenses', null, 'pharmacy_financial_operating_expenses'),
        ('financial_discounts', 'Discounts', null, 'pharmacy_sales_discounts'),
        ('taxes', 'Taxes', null, null),
        ('supplier_payables', 'Supplier payables', null, null),
        ('customer_receivables', 'Customer receivables', null, 'pharmacy_financial_receivables'),
        ('cash_flow', 'Cash flow', PharmacyReportingContentKind.chart, 'pharmacy_financial_cash_flow'),
        ('daily_cash_position', 'Daily cash position', null, 'pharmacy_financial_cash_flow'),
        ('profit_by_product_category', 'Profit by product/category', null, 'pharmacy_financial_profit_by_category'),
        ('profit_by_branch', 'Profit by branch', null, 'pharmacy_profit_by_branch'),
        ('profit_by_period', 'Profit by period', PharmacyReportingContentKind.chart, 'pharmacy_financial_profit_by_period'),
      ]),
    ),
    PharmacyReportingCategory(
      id: staff,
      icon: Icons.badge_outlined,
      reports: _reports(staff, <(String, String, PharmacyReportingContentKind?, String?)>[
        ('sales_by_staff', 'Sales by staff', null, 'pharmacy_sales_by_staff'),
        ('dispensing_by_staff', 'Dispensing by staff', null, 'pharmacy_dispensing_by_staff'),
        ('purchases_entered_by_staff', 'Purchases entered by staff', null, 'pharmacy_purchases_by_staff'),
        ('stock_adjustments_by_staff', 'Stock adjustments by staff', null, 'pharmacy_stock_adjustments_by_staff'),
        ('refunds_by_staff', 'Refunds by staff', null, 'pharmacy_refunds_by_staff'),
        ('discounts_authorized', 'Discounts authorized', null, 'pharmacy_discounts_authorized'),
        ('voided_transactions', 'Voided transactions', null, 'pharmacy_voided_transactions'),
        ('login_activity_history', 'Login/activity history', null, 'pharmacy_login_activity'),
        ('user_productivity', 'User productivity', PharmacyReportingContentKind.chart, 'pharmacy_user_productivity'),
        ('audit_trail', 'Audit trail', null, 'pharmacy_audit_trail'),
      ]),
    ),
    PharmacyReportingCategory(
      id: branch,
      icon: Icons.storefront_outlined,
      reports: _reports(branch, <(String, String, PharmacyReportingContentKind?, String?)>[
        ('sales_by_branch', 'Sales by branch', null, 'pharmacy_sales_by_branch'),
        ('stock_by_branch', 'Stock by branch', null, 'pharmacy_stock_by_branch'),
        ('profit_by_branch', 'Profit by branch', null, 'pharmacy_profit_by_branch'),
        ('transfers_between_branches', 'Transfers between branches', null, 'pharmacy_transfers_between_branches'),
        ('purchases_by_branch', 'Purchases by branch', null, 'pharmacy_purchases_by_branch'),
        ('stock_shortages_by_branch', 'Stock shortages by branch', null, 'pharmacy_stock_shortages_by_branch'),
        ('best_performing_branch', 'Best-performing branch', null, 'pharmacy_best_performing_branch'),
        ('branch_comparison', 'Branch comparison', PharmacyReportingContentKind.chart, 'pharmacy_branch_comparison'),
      ]),
    ),
    PharmacyReportingCategory(
      id: transfers,
      icon: Icons.swap_horiz_outlined,
      reports: _reports(transfers, <(String, String, PharmacyReportingContentKind?, String?)>[
        ('transfer_quantity', 'Transfer quantity', null, 'pharmacy_transfer_quantity'),
        ('sending_branch', 'Sending branch', null, 'pharmacy_sending_branch'),
        ('receiving_branch', 'Receiving branch', null, 'pharmacy_receiving_branch'),
        ('transfer_date', 'Transfer date', null, 'pharmacy_transfer_date'),
        ('transfer_status', 'Transfer status', null, 'pharmacy_transfer_status'),
        ('products_transferred', 'Products transferred', null, 'pharmacy_products_transferred'),
        ('pending_transfers', 'Pending transfers', null, 'pharmacy_pending_transfers'),
        ('transfer_discrepancies', 'Transfer discrepancies', null, 'pharmacy_transfer_discrepancies'),
      ]),
    ),
    PharmacyReportingCategory(
      id: prescription,
      icon: Icons.description_outlined,
      reports: _reports(prescription, <(String, String, PharmacyReportingContentKind?, String?)>[
        (
          'prescription_count',
          'Prescription count',
          null,
          'pharmacy_prescription_count',
        ),
        ('prescriber', 'Prescriber', null, 'pharmacy_prescription_prescriber'),
        (
          'diagnosis_indication',
          'Diagnosis/indication',
          null,
          'pharmacy_prescription_diagnosis',
        ),
        (
          'medicine_prescribed',
          'Medicine prescribed',
          null,
          'pharmacy_prescription_medicine',
        ),
        ('dosage', 'Dosage', null, 'pharmacy_prescription_dosage'),
        ('frequency', 'Frequency', null, 'pharmacy_prescription_frequency'),
        ('duration', 'Duration', null, 'pharmacy_prescription_duration'),
        // No drug-interaction / allergy-alert / duplicate-therapy entities — keep unavailable.
        ('drug_interactions', 'Drug interactions', null, null),
        ('allergy_alerts', 'Allergy alerts', null, null),
        ('duplicate_therapy', 'Duplicate therapy', null, null),
        (
          'antibiotic_usage',
          'Antibiotic usage',
          null,
          'pharmacy_prescription_antibiotic_usage',
        ),
        (
          'controlled_drug_dispensing',
          'Controlled-drug dispensing',
          null,
          'pharmacy_prescription_controlled_dispensing',
        ),
      ]),
    ),
    PharmacyReportingCategory(
      id: controlled,
      icon: Icons.lock_outline,
      reports: _reports(controlled, <(String, String, PharmacyReportingContentKind?, String?)>[
        ('controlled_medicine_stock', 'Controlled medicine stock', null, 'pharmacy_controlled_stock'),
        ('opening_balance', 'Opening balance', null, 'pharmacy_controlled_balance'),
        ('quantity_received', 'Quantity received', null, 'pharmacy_controlled_received'),
        ('quantity_dispensed', 'Quantity dispensed', null, 'pharmacy_controlled_dispensed'),
        ('closing_balance', 'Closing balance', null, 'pharmacy_controlled_balance'),
        ('batch_numbers', 'Batch numbers', null, 'pharmacy_controlled_batches'),
        ('controlled_prescriber', 'Prescriber', null, 'pharmacy_controlled_actors'),
        ('controlled_patient', 'Patient', null, 'pharmacy_controlled_actors'),
        ('dispensing_staff', 'Dispensing staff', null, 'pharmacy_controlled_actors'),
        ('controlled_adjustments', 'Adjustments', null, 'pharmacy_controlled_adjustments'),
        ('wastage', 'Wastage', null, 'pharmacy_controlled_wastage'),
        ('regulatory_log', 'Regulatory log', null, 'pharmacy_controlled_regulatory_log'),
      ]),
    ),
    PharmacyReportingCategory(
      id: procurement,
      icon: Icons.handshake_outlined,
      reports: _reports(procurement, <(String, String, PharmacyReportingContentKind?, String?)>[
        ('supplier_spend', 'Supplier spend', null, 'pharmacy_purchases_by_supplier'),
        ('price_comparison', 'Price comparison', null, 'pharmacy_supplier_pricing'),
        (
          'price_trends',
          'Price trends',
          PharmacyReportingContentKind.chart,
          'pharmacy_drug_price_changes',
        ),
        ('supplier_reliability', 'Supplier reliability', null, 'pharmacy_purchase_orders'),
        ('order_fulfillment_rate', 'Order fulfillment rate', null, 'pharmacy_purchase_orders'),
        ('late_deliveries', 'Late deliveries', null, 'pharmacy_purchase_orders'),
        ('purchase_frequency', 'Purchase frequency', null, 'pharmacy_purchases_by_supplier'),
        ('purchase_volume', 'Purchase volume', null, 'pharmacy_purchases_by_supplier'),
        ('supplier_payment_status', 'Supplier payment status', null, null),
      ]),
    ),
    PharmacyReportingCategory(
      id: kpis,
      icon: Icons.speed_outlined,
      reports: _reports(kpis, <(String, String, PharmacyReportingContentKind?, String?)>[
        ('total_sales_today', 'Total sales today', null, 'pharmacy_drug_consumption'),
        ('todays_profit', "Today's profit", null, 'pharmacy_drug_consumption'),
        ('kpi_prescriptions', 'Number of prescriptions', null, 'pharmacy_dispense_throughput'),
        ('kpi_transactions', 'Number of transactions', null, 'pharmacy_dispense_throughput'),
        ('current_stock_value', 'Current stock value', null, 'inventory_stock_value'),
        ('low_stock_items', 'Low-stock items', null, 'inventory_stock_risk'),
        ('kpi_out_of_stock', 'Out-of-stock items', null, 'inventory_stock_risk'),
        ('near_expiry_value', 'Near-expiry value', null, 'inventory_stock_risk'),
        ('expired_stock_value_kpi', 'Expired-stock value', null, 'inventory_stock_risk'),
        (
          'outstanding_customer_credit',
          'Outstanding customer credit',
          null,
          'pharmacy_customer_credit_balance',
        ),
        // AP not modeled on PO/supplier schema — keep unavailable (no fake).
        ('outstanding_supplier_payments', 'Outstanding supplier payments', null, null),
        ('top_selling_medicines', 'Top 10 selling medicines', null, 'pharmacy_drug_consumption'),
        (
          'top_profitable_medicines',
          'Top 10 profitable medicines',
          null,
          'pharmacy_drug_consumption',
        ),
        ('kpi_slow_moving', 'Slow-moving products', null, 'inventory_stock_velocity'),
      ]),
    ),
    PharmacyReportingCategory(
      id: audit,
      icon: Icons.fact_check_outlined,
      reports: _reports(audit, <(String, String, PharmacyReportingContentKind?, String?)>[
        ('who_created', 'Who created a transaction', null, 'pharmacy_audit_who_created'),
        ('who_edited', 'Who edited it', null, 'pharmacy_audit_who_edited'),
        ('who_deleted_voided', 'Who deleted/voided it', null, 'pharmacy_audit_who_deleted'),
        ('previous_vs_new_values', 'Previous vs new values', null, 'pharmacy_audit_previous_vs_new'),
        ('change_date_time', 'Date/time of changes', null, 'pharmacy_audit_change_datetime'),
        ('audit_stock_adjustments', 'Stock adjustments', null, 'pharmacy_audit_stock_adjustments'),
        ('audit_price_changes', 'Price changes', null, 'pharmacy_audit_price_changes'),
        ('user_permissions', 'User permissions', null, 'pharmacy_audit_user_permissions'),
        ('unauthorized_attempts', 'Unauthorized attempts', null, 'pharmacy_audit_unauthorized'),
        (
          'prescription_controlled_audit',
          'Prescription/controlled-drug audit trail',
          null,
          'pharmacy_audit_rx_controlled',
        ),
      ]),
    ),
    PharmacyReportingCategory(
      id: management,
      icon: Icons.analytics_outlined,
      reports: <PharmacyReportingReport>[
        for (final PharmacyReportingMgmtComposition entry
            in pharmacyReportingMgmtCompositions)
          _report(
            management,
            entry.id,
            entry.label,
            kind: entry.contentKind,
            datasetKey: entry.datasetKey,
          ),
      ],
    ),
  ];
}

/// Hides Audit & Compliance when the actor lacks compliance entitlements.
List<PharmacyReportingCategory> pharmacyReportingCatalogForPolicy(
  AppAccessPolicy policy,
) {
  final List<PharmacyReportingCategory> catalog = pharmacyReportingCatalog();
  if (canReadReportsCompliance(policy)) {
    return catalog;
  }
  return catalog
      .where(
        (PharmacyReportingCategory category) =>
            category.id != PharmacyReportingCategoryIds.auditCompliance,
      )
      .toList(growable: false);
}

List<PharmacyReportingCategory> filterPharmacyReportingCatalog({
  required List<PharmacyReportingCategory> catalog,
  required String searchQuery,
  required Set<String> categoryIds,
  required Set<String> reportIds,
  required Set<String> contentKinds,
}) {
  return filterModuleReportingCatalog(
    catalog: catalog,
    searchQuery: searchQuery,
    categoryIds: categoryIds,
    reportIds: reportIds,
    contentKinds: contentKinds,
  );
}
