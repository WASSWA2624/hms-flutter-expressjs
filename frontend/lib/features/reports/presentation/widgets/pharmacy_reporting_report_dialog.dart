import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/features/reports/presentation/pharmacy_reporting_catalog.dart';
import 'package:hosspi_hms/features/reports/presentation/pharmacy_reporting_labels.dart';
import 'package:hosspi_hms/features/reports/presentation/reports_access.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/reporting/reporting.dart';

/// Pharmacy compatibility aliases for the shared report dialog kit.
typedef PharmacyReportingPeriodPreset = ModuleReportingPeriodPreset;
typedef PharmacyReportingExportFormat = ModuleReportingExportFormat;
typedef PharmacyReportingExportRow = ModuleReportingExportRow;
typedef PharmacyReportingReportDialog = ModuleReportingReportDialog;

({DateTime from, DateTime to}) pharmacyReportingRangeForPreset(
  PharmacyReportingPeriodPreset preset, {
  DateTime? now,
}) {
  return moduleReportingRangeForPreset(preset, now: now);
}

Future<void> openPharmacyReportingReportDialog({
  required BuildContext context,
  required PharmacyReportingReport report,
  required AppAccessPolicy policy,
}) {
  return openModuleReportingReportDialog(
    context: context,
    report: report,
    labels: pharmacyReportingLabels(context.l10n),
    canExport: canExportEvidence(policy),
  );
}
