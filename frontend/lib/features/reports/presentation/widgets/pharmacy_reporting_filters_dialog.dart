import 'package:flutter/material.dart';
import 'package:hosspi_hms/features/reports/presentation/pharmacy_reporting_catalog.dart';
import 'package:hosspi_hms/features/reports/presentation/pharmacy_reporting_labels.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/reporting/reporting.dart';

const String pharmacyReportingCategoryFilterKey =
    ModuleReportingFilterKeys.category;
const String pharmacyReportingSubcategoryFilterKey =
    ModuleReportingFilterKeys.subcategory;
const String pharmacyReportingContentKindFilterKey =
    ModuleReportingFilterKeys.contentKind;
const String pharmacyReportingFilterNoneSentinel =
    ModuleReportingFilterKeys.noneSentinel;

bool pharmacyReportingFiltersAreActive(
  AppSearchBarFilterValue value, {
  required int totalCategories,
  required int totalReports,
}) {
  return moduleReportingFiltersAreActive(
    value,
    totalCategories: totalCategories,
    totalReports: totalReports,
  );
}

Future<void> openPharmacyReportingFiltersDialog({
  required BuildContext context,
  required List<PharmacyReportingCategory> catalog,
  required AppSearchBarFilterValue initialValue,
  required ValueChanged<AppSearchBarFilterValue> onApply,
}) {
  return openModuleReportingFiltersDialog(
    context: context,
    catalog: catalog,
    initialValue: initialValue,
    onApply: onApply,
    labels: pharmacyReportingLabels(context.l10n),
  );
}

/// Compatibility alias for tests and older imports.
typedef PharmacyReportingFiltersDialog = ModuleReportingFiltersDialog;
