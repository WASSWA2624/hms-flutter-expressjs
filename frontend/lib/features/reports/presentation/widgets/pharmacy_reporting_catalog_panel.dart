import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/features/reports/presentation/pharmacy_reporting_catalog.dart';
import 'package:hosspi_hms/features/reports/presentation/widgets/pharmacy_reporting_report_dialog.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';

/// Category sections and subcategory buttons for the pharmacy Reporting tab.
class PharmacyReportingCatalogPanel extends StatelessWidget {
  const PharmacyReportingCatalogPanel({
    required this.l10n,
    required this.policy,
    required this.categories,
    super.key,
  });

  final AppLocalizations l10n;
  final AppAccessPolicy policy;
  final List<PharmacyReportingCategory> categories;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (categories.isEmpty) {
      return AppMutedText(l10n.reportsPharmacyReportingCatalogEmpty);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final PharmacyReportingCategory category in categories) ...<Widget>[
          AppSectionPanel(
            title: pharmacyReportingCategoryLabel(l10n, category.id),
            leadingIcon: category.icon,
            density: AppContentPanelDensity.compact,
            children: <Widget>[
              Wrap(
                spacing: theme.spacing.sm,
                runSpacing: theme.spacing.sm,
                children: <Widget>[
                  for (final PharmacyReportingReport report in category.reports)
                    ActionChip(
                      avatar: Icon(
                        report.contentKind == PharmacyReportingContentKind.chart
                            ? Icons.bar_chart_outlined
                            : Icons.description_outlined,
                        size: 18,
                      ),
                      label: Text(report.label),
                      onPressed: () {
                        openPharmacyReportingReportDialog(
                          context: context,
                          report: report,
                          policy: policy,
                        );
                      },
                    ),
                ],
              ),
            ],
          ),
          SizedBox(height: theme.spacing.md),
        ],
      ],
    );
  }
}
