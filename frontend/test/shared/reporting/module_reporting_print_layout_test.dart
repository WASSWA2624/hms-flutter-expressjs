import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/shared/reporting/module_reporting_data.dart';
import 'package:hosspi_hms/shared/reporting/module_reporting_models.dart';
import 'package:hosspi_hms/shared/reporting/module_reporting_print_layout.dart';
import 'package:hosspi_hms/shared/reporting/module_reporting_visualization.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
  });

  test('default print blocks cover applicable visualizations', () {
    final ModuleReportingReportSnapshot snapshot =
        ModuleReportingReportSnapshot.ready(
          columns: const <String>['date', 'amount'],
          rows: <Map<String, Object?>>[
            for (int i = 0; i < 4; i++)
              <String, Object?>{'date': '2026-08-0${i + 1}', 'amount': (i + 1) * 10},
          ],
          summary: const <String, Object?>{'amount': 100},
        );
    final List<ModuleReportingPrintBlock> blocks =
        moduleReportingDefaultPrintBlocks(
          report: const ModuleReportingReport(
            id: 'sales_by_period',
            categoryId: 'sales',
            label: 'Sales by period',
            contentKind: ModuleReportingContentKind.chart,
            datasetKey: 'pharmacy_drug_consumption',
          ),
          snapshot: snapshot,
        );
    expect(blocks, isNotEmpty);
    expect(
      blocks.any(
        (ModuleReportingPrintBlock block) =>
            block.kind == ModuleReportingVisualizationKind.table,
      ),
      isTrue,
    );
  });

  test('layout html includes only visible blocks', () {
    const ModuleReportingLabels labels = ModuleReportingLabels(
      reportingTabLabel: 'Reporting',
      analyticsTabLabel: 'Analytics',
      searchSemanticLabel: 'Search',
      searchHint: 'Search',
      clearSearchLabel: 'Clear',
      filtersActionLabel: 'Filters',
      expandAllAction: 'Expand',
      collapseAllAction: 'Collapse',
      catalogEmpty: 'Empty',
      categoryFilterLabel: 'Category',
      subcategoryFilterLabel: 'Subcategory',
      contentKindFilterLabel: 'Kind',
      contentKindTable: 'Table',
      contentKindChart: 'Chart',
      allLabel: 'All',
      dateRangeLabel: 'Dates',
      dateFromLabel: 'From',
      dateToLabel: 'To',
      datePickerLabel: 'Pick',
      invalidDateMessage: 'Invalid',
      dateFilterHint: 'Hint',
      selectCategoryHint: 'Select',
      clearFiltersAction: 'Clear filters',
      applyFiltersAction: 'Apply',
      closeAction: 'Close',
      cancelAction: 'Cancel',
      advancedFiltersTitle: 'Filters',
      categoryTitle: _categoryTitle,
      periodToday: 'Today',
      periodLastWeek: 'Week',
      periodLastMonth: 'Month',
      periodLast3Months: '3m',
      periodLast6Months: '6m',
      periodLast12Months: '12m',
      periodLast24Months: '24m',
      periodCustom: 'Custom',
      periodLabel: 'Period',
      activeRangeSummary: _rangeSummary,
      customRangeTitle: 'Custom',
      customRangeBody: 'Body',
      customRangeApplyAction: 'Apply',
      customRangeRequired: 'Required',
      unavailableTitle: 'Unavailable',
      unavailableBody: 'Unavailable body',
      unavailableMappedBody: 'Mapped unavailable',
      loadingTitle: 'Loading',
      loadingBody: 'Loading body',
      errorTitle: 'Error',
      errorBody: 'Error body',
      emptyTitle: 'Empty',
      emptyBody: 'No rows',
      retryAction: 'Retry',
      printAction: 'Print',
      printSubtitle: 'Subtitle',
      printFooter: 'Footer',
      referenceLabel: 'Ref',
      previewTitle: 'Preview',
      nameColumnLabel: 'Name',
      statusColumnLabel: 'Status',
      exportAction: 'Export',
      exportDialogTitle: 'Export',
      exportDialogBody: 'Body',
      exportFormatLabel: 'Format',
      exportExcelAction: 'Excel',
      exportExcelOptionBody: 'Excel body',
      exportPdfAction: 'PDF',
      exportPdfOptionBody: 'PDF body',
      exportPdfSubtitle: 'PDF sub',
      exportFieldColumn: 'Field',
      exportValueColumn: 'Value',
      exportSheetName: 'Sheet',
      exportNotesLabel: 'Caption',
      exportColumnsSectionLabel: 'Columns',
      exportFiltersSectionLabel: 'Filters',
      exportEmptyColumnsMessage: 'No columns',
      exportEmptyRowsMessage: 'No rows',
      exportSuccessMessage: 'OK',
      exportFailureMessage: 'Fail',
      unknownValue: '—',
    );

    final ModuleReportingReportSnapshot snapshot =
        ModuleReportingReportSnapshot.ready(
          columns: const <String>['drug', 'amount'],
          rows: const <Map<String, Object?>>[
            <String, Object?>{'drug': 'Amox', 'amount': 12},
            <String, Object?>{'drug': 'Para', 'amount': 8},
          ],
        );
    final List<ModuleReportingPrintBlock> blocks =
        moduleReportingDefaultPrintBlocks(
          report: const ModuleReportingReport(
            id: 'total_sales',
            categoryId: 'sales',
            label: 'Total sales',
          ),
          snapshot: snapshot,
        );
    final ModuleReportingPrintBlock hidden = blocks.first.copyWith(
      visible: false,
      title: 'Hidden presentation block',
    );
    final List<ModuleReportingPrintBlock> mixed = <ModuleReportingPrintBlock>[
      hidden,
      ...blocks.skip(1),
    ];
    final String html = moduleReportingPrintLayoutBodyHtml(
      labels: labels,
      report: const ModuleReportingReport(
        id: 'total_sales',
        categoryId: 'sales',
        label: 'Total sales',
      ),
      snapshot: snapshot,
      blocks: mixed,
      periodLabel: 'Last month',
      from: DateTime(2026, 7, 1),
      to: DateTime(2026, 7, 31),
      locale: const Locale('en'),
    );
    expect(html, contains('Total sales'));
    expect(html, contains('Last month'));
    expect(html, isNot(contains('Hidden presentation block')));
  });
}

String _categoryTitle(String id) => id;
String _rangeSummary(String period, String from, String to) =>
    '$period · $from – $to';
