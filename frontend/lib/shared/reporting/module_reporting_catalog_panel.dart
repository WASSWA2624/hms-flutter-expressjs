import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/reporting/module_reporting_models.dart';

/// Owns expand/collapse state so section toggles do not rebuild the search bar.
class ModuleReportingCatalogExpansionController extends ChangeNotifier {
  ModuleReportingCatalogExpansionController({
    required Iterable<String> categoryIds,
    bool initiallyExpanded = false,
  }) {
    for (final String id in categoryIds) {
      _expanded[id] = initiallyExpanded;
    }
  }

  final Map<String, bool> _expanded = <String, bool>{};

  bool isExpanded(String categoryId) => _expanded[categoryId] ?? false;

  bool get allExpanded {
    if (_expanded.isEmpty) {
      return true;
    }
    return _expanded.values.every((bool expanded) => expanded);
  }

  void setExpanded(String categoryId, bool expanded) {
    if (_expanded[categoryId] == expanded) {
      return;
    }
    _expanded[categoryId] = expanded;
    notifyListeners();
  }

  void toggleExpandCollapseAll() {
    final bool expand = !allExpanded;
    for (final String id in _expanded.keys.toList(growable: false)) {
      _expanded[id] = expand;
    }
    notifyListeners();
  }
}

/// Category sections and report buttons for a module Reporting catalog.
class ModuleReportingCatalogPanel extends StatelessWidget {
  const ModuleReportingCatalogPanel({
    required this.categories,
    required this.expansionController,
    required this.categoryTitle,
    required this.emptyLabel,
    required this.onReportPressed,
    this.forceExpanded = false,
    super.key,
  });

  final List<ModuleReportingCategory> categories;
  final ModuleReportingCatalogExpansionController expansionController;
  final String Function(ModuleReportingCategory category) categoryTitle;
  final String emptyLabel;
  final ValueChanged<ModuleReportingReport> onReportPressed;

  /// When true (e.g. active search), section bodies stay visible so matches
  /// are not hidden behind collapsed headers.
  final bool forceExpanded;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (categories.isEmpty) {
      return AppMutedText(emptyLabel);
    }

    return ListenableBuilder(
      listenable: expansionController,
      builder: (BuildContext context, Widget? _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (final ModuleReportingCategory category
                in categories) ...<Widget>[
              AppSectionPanel(
                title: categoryTitle(category),
                leadingIcon: category.icon,
                density: AppContentPanelDensity.compact,
                collapsible: !forceExpanded,
                expanded: forceExpanded ||
                    expansionController.isExpanded(category.id),
                onExpandedChanged: forceExpanded
                    ? null
                    : (bool expanded) {
                        expansionController.setExpanded(
                          category.id,
                          expanded,
                        );
                      },
                children: <Widget>[
                  Wrap(
                    spacing: theme.spacing.sm,
                    runSpacing: theme.spacing.sm,
                    children: <Widget>[
                      for (final ModuleReportingReport report
                          in category.reports)
                        ActionChip(
                          avatar: Icon(
                            report.contentKind ==
                                    ModuleReportingContentKind.chart
                                ? Icons.bar_chart_outlined
                                : Icons.table_chart_outlined,
                            size: 18,
                          ),
                          label: Text(report.label),
                          onPressed: () => onReportPressed(report),
                        ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: theme.spacing.md),
            ],
          ],
        );
      },
    );
  }
}
