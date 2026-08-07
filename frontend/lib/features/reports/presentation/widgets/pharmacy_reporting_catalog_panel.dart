import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/features/reports/presentation/pharmacy_reporting_catalog.dart';
import 'package:hosspi_hms/features/reports/presentation/pharmacy_reporting_labels.dart';
import 'package:hosspi_hms/features/reports/presentation/widgets/pharmacy_reporting_report_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/reporting/reporting.dart';

typedef PharmacyReportingCatalogExpansionController =
    ModuleReportingCatalogExpansionController;

/// Pharmacy wrapper around [ModuleReportingCatalogPanel].
class PharmacyReportingCatalogPanel extends StatelessWidget {
  const PharmacyReportingCatalogPanel({
    required this.l10n,
    required this.policy,
    required this.categories,
    required this.expansionController,
    this.forceExpanded = false,
    super.key,
  });

  final AppLocalizations l10n;
  final AppAccessPolicy policy;
  final List<PharmacyReportingCategory> categories;
  final PharmacyReportingCatalogExpansionController expansionController;
  final bool forceExpanded;

  @override
  Widget build(BuildContext context) {
    final ModuleReportingLabels labels = pharmacyReportingLabels(l10n);
    return ModuleReportingCatalogPanel(
      categories: categories,
      expansionController: expansionController,
      categoryTitle: (ModuleReportingCategory category) =>
          labels.categoryTitle(category.id),
      emptyLabel: labels.catalogEmpty,
      forceExpanded: forceExpanded,
      onReportPressed: (ModuleReportingReport report) {
        openPharmacyReportingReportDialog(
          context: context,
          report: report,
          policy: policy,
        );
      },
    );
  }
}
