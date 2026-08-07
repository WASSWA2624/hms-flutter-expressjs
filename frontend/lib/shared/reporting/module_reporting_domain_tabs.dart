import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/reporting/module_reporting_models.dart';

/// Nested Reporting / Analytics tab strip for a module domain group.
class ModuleReportingDomainTabs extends StatelessWidget {
  const ModuleReportingDomainTabs({
    required this.labels,
    required this.reportingChild,
    required this.analyticsChild,
    required this.selectedId,
    required this.onTabTapped,
    super.key,
  });

  static const String reportingTabId = 'reporting';
  static const String analyticsTabId = 'analytics';

  final ModuleReportingLabels labels;
  final Widget reportingChild;
  final Widget analyticsChild;
  final String selectedId;
  final ValueChanged<String> onTabTapped;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isReporting = selectedId == reportingTabId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppTabStrip(
          variant: AppTabStripVariant.nested,
          tabs: <AppTabItem>[
            AppTabItem(
              id: reportingTabId,
              label: labels.reportingTabLabel,
              icon: Icons.description_outlined,
            ),
            AppTabItem(
              id: analyticsTabId,
              label: labels.analyticsTabLabel,
              icon: Icons.insights_outlined,
            ),
          ],
          selectedId: selectedId,
          onTabTapped: onTabTapped,
        ),
        SizedBox(height: theme.spacing.md),
        if (isReporting) reportingChild else analyticsChild,
      ],
    );
  }
}
