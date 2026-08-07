import 'package:flutter/material.dart';

/// Primary surface kind for a module report dialog (drives export defaults).
enum ModuleReportingContentKind {
  table,
  chart,
}

/// Period presets shared by the report dialog toolbar and data providers.
enum ModuleReportingPeriodPreset {
  today,
  lastWeek,
  lastMonth,
  last3Months,
  last6Months,
  last12Months,
  last24Months,
  custom,
}

/// Preferred export format for entitled module report dialogs.
enum ModuleReportingExportFormat { excel, pdf }

/// One reportable item under a [ModuleReportingCategory].
@immutable
final class ModuleReportingReport {
  const ModuleReportingReport({
    required this.id,
    required this.categoryId,
    required this.label,
    this.contentKind = ModuleReportingContentKind.table,
    this.datasetKey,
    this.initialPeriodPreset,
  });

  final String id;
  final String categoryId;

  /// Display label for chips/buttons (may be module-local English or l10n).
  final String label;
  final ModuleReportingContentKind contentKind;

  /// Optional existing reports dataset when a backend mapping exists.
  final String? datasetKey;

  /// When set, the report dialog opens on this period instead of last month.
  final ModuleReportingPeriodPreset? initialPeriodPreset;

  bool get hasBackend => datasetKey != null && datasetKey!.isNotEmpty;
}

/// Top-level reporting category for a module catalog.
@immutable
final class ModuleReportingCategory {
  const ModuleReportingCategory({
    required this.id,
    required this.icon,
    required this.reports,
  });

  final String id;
  final IconData icon;
  final List<ModuleReportingReport> reports;
}

/// Filter keys shared by [ModuleReportingShell] and the filters dialog.
abstract final class ModuleReportingFilterKeys {
  static const String category = 'category';
  static const String subcategory = 'subcategory';
  static const String contentKind = 'content_kind';

  /// Stored when a multi-select section has nothing checked so catalog
  /// filtering matches zero rows (empty option sets mean "no filter" / all).
  static const String noneSentinel = '__none__';
}

/// Injected chrome copy so the shared reporting kit stays module-agnostic.
@immutable
final class ModuleReportingLabels {
  const ModuleReportingLabels({
    required this.reportingTabLabel,
    required this.analyticsTabLabel,
    required this.searchSemanticLabel,
    required this.searchHint,
    required this.clearSearchLabel,
    required this.filtersActionLabel,
    required this.expandAllAction,
    required this.collapseAllAction,
    required this.catalogEmpty,
    required this.categoryFilterLabel,
    required this.subcategoryFilterLabel,
    required this.contentKindFilterLabel,
    required this.contentKindTable,
    required this.contentKindChart,
    required this.allLabel,
    required this.dateRangeLabel,
    required this.dateFromLabel,
    required this.dateToLabel,
    required this.datePickerLabel,
    required this.invalidDateMessage,
    required this.dateFilterHint,
    required this.selectCategoryHint,
    required this.clearFiltersAction,
    required this.applyFiltersAction,
    required this.closeAction,
    required this.cancelAction,
    required this.advancedFiltersTitle,
    required this.categoryTitle,
    required this.periodToday,
    required this.periodLastWeek,
    required this.periodLastMonth,
    required this.periodLast3Months,
    required this.periodLast6Months,
    required this.periodLast12Months,
    required this.periodLast24Months,
    required this.periodCustom,
    required this.periodLabel,
    required this.activeRangeSummary,
    required this.customRangeTitle,
    required this.customRangeBody,
    required this.customRangeApplyAction,
    required this.customRangeRequired,
    required this.unavailableTitle,
    required this.unavailableBody,
    required this.unavailableMappedBody,
    required this.loadingTitle,
    required this.loadingBody,
    required this.errorTitle,
    required this.errorBody,
    required this.emptyTitle,
    required this.emptyBody,
    required this.retryAction,
    required this.printAction,
    required this.printSubtitle,
    required this.printFooter,
    required this.referenceLabel,
    required this.previewTitle,
    required this.nameColumnLabel,
    required this.statusColumnLabel,
    required this.exportAction,
    required this.exportDialogTitle,
    required this.exportDialogBody,
    required this.exportFormatLabel,
    required this.exportExcelAction,
    required this.exportExcelOptionBody,
    required this.exportPdfAction,
    required this.exportPdfOptionBody,
    required this.exportPdfSubtitle,
    required this.exportFieldColumn,
    required this.exportValueColumn,
    required this.exportSheetName,
    required this.exportNotesLabel,
    required this.exportColumnsSectionLabel,
    required this.exportFiltersSectionLabel,
    required this.exportEmptyColumnsMessage,
    required this.exportEmptyRowsMessage,
    required this.exportSuccessMessage,
    required this.exportFailureMessage,
    required this.unknownValue,
  });

  final String reportingTabLabel;
  final String analyticsTabLabel;
  final String searchSemanticLabel;
  final String searchHint;
  final String clearSearchLabel;
  final String filtersActionLabel;
  final String expandAllAction;
  final String collapseAllAction;
  final String catalogEmpty;
  final String categoryFilterLabel;
  final String subcategoryFilterLabel;
  final String contentKindFilterLabel;
  final String contentKindTable;
  final String contentKindChart;
  final String allLabel;
  final String dateRangeLabel;
  final String dateFromLabel;
  final String dateToLabel;
  final String datePickerLabel;
  final String invalidDateMessage;
  final String dateFilterHint;
  final String selectCategoryHint;
  final String clearFiltersAction;
  final String applyFiltersAction;
  final String closeAction;
  final String cancelAction;
  final String advancedFiltersTitle;
  final String Function(String categoryId) categoryTitle;
  final String periodToday;
  final String periodLastWeek;
  final String periodLastMonth;
  final String periodLast3Months;
  final String periodLast6Months;
  final String periodLast12Months;
  final String periodLast24Months;
  final String periodCustom;
  final String periodLabel;
  final String Function(String period, String from, String to) activeRangeSummary;
  final String customRangeTitle;
  final String customRangeBody;
  final String customRangeApplyAction;
  final String customRangeRequired;
  final String unavailableTitle;
  final String unavailableBody;
  final String unavailableMappedBody;
  final String loadingTitle;
  final String loadingBody;
  final String errorTitle;
  final String errorBody;
  final String emptyTitle;
  final String emptyBody;
  final String retryAction;
  final String printAction;
  final String printSubtitle;
  final String printFooter;
  final String referenceLabel;
  final String previewTitle;
  final String nameColumnLabel;
  final String statusColumnLabel;
  final String exportAction;
  final String exportDialogTitle;
  final String exportDialogBody;
  final String exportFormatLabel;
  final String exportExcelAction;
  final String exportExcelOptionBody;
  final String exportPdfAction;
  final String exportPdfOptionBody;
  final String exportPdfSubtitle;
  final String exportFieldColumn;
  final String exportValueColumn;
  final String exportSheetName;
  final String exportNotesLabel;
  final String exportColumnsSectionLabel;
  final String exportFiltersSectionLabel;
  final String exportEmptyColumnsMessage;
  final String exportEmptyRowsMessage;
  final String exportSuccessMessage;
  final String exportFailureMessage;
  final String unknownValue;
}

List<ModuleReportingCategory> filterModuleReportingCatalog({
  required List<ModuleReportingCategory> catalog,
  required String searchQuery,
  required Set<String> categoryIds,
  required Set<String> reportIds,
  required Set<String> contentKinds,
}) {
  final String needle = searchQuery.trim().toLowerCase();
  final List<ModuleReportingCategory> filtered = <ModuleReportingCategory>[];

  for (final ModuleReportingCategory category in catalog) {
    if (categoryIds.isNotEmpty && !categoryIds.contains(category.id)) {
      continue;
    }

    final List<ModuleReportingReport> reports = category.reports.where((
      ModuleReportingReport report,
    ) {
      if (reportIds.isNotEmpty && !reportIds.contains(report.id)) {
        return false;
      }
      if (contentKinds.isNotEmpty &&
          !contentKinds.contains(report.contentKind.name)) {
        return false;
      }
      if (needle.isEmpty) {
        return true;
      }
      return report.label.toLowerCase().contains(needle) ||
          report.id.toLowerCase().contains(needle) ||
          category.id.toLowerCase().contains(needle);
    }).toList(growable: false);

    if (reports.isEmpty) {
      continue;
    }

    filtered.add(
      ModuleReportingCategory(
        id: category.id,
        icon: category.icon,
        reports: reports,
      ),
    );
  }

  return filtered;
}
