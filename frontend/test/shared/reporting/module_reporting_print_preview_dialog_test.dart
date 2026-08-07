import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/theme/app_theme.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/reporting/module_reporting_data.dart';
import 'package:hosspi_hms/shared/reporting/module_reporting_models.dart';
import 'package:hosspi_hms/shared/reporting/module_reporting_print_preview_dialog.dart';

ModuleReportingLabels _labels() {
  return ModuleReportingLabels(
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
    dateRangeLabel: 'Range',
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
    advancedFiltersTitle: 'Advanced',
    categoryTitle: (String id) => id,
    periodToday: 'Today',
    periodLastWeek: 'Last week',
    periodLastMonth: 'Last month',
    periodLast3Months: 'Last 3 months',
    periodLast6Months: 'Last 6 months',
    periodLast12Months: 'Last 12 months',
    periodLast24Months: 'Last 24 months',
    periodCustom: 'Custom',
    periodLabel: 'Period',
    activeRangeSummary: (String period, String from, String to) =>
        '$period · $from – $to',
    customRangeTitle: 'Custom range',
    customRangeBody: 'Body',
    customRangeApplyAction: 'Apply',
    customRangeRequired: 'Required',
    unavailableTitle: 'Unavailable',
    unavailableBody: 'Unavailable body',
    unavailableMappedBody: 'Mapped',
    loadingTitle: 'Loading',
    loadingBody: 'Loading body',
    errorTitle: 'Error',
    errorBody: 'Error body',
    emptyTitle: 'Empty',
    emptyBody: 'Empty body',
    retryAction: 'Retry',
    printAction: 'Print',
    printSubtitle: 'Subtitle',
    printFooter: 'Footer',
    referenceLabel: 'Reference',
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
    exportPdfSubtitle: 'PDF subtitle',
    exportFieldColumn: 'Field',
    exportValueColumn: 'Value',
    exportSheetName: 'Sheet',
    exportNotesLabel: 'Notes',
    exportColumnsSectionLabel: 'Columns',
    exportFiltersSectionLabel: 'Filters',
    exportEmptyColumnsMessage: 'No columns',
    exportEmptyRowsMessage: 'No rows',
    exportSuccessMessage: 'Success',
    exportFailureMessage: 'Failure',
    unknownValue: 'Unknown',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('print composer mounts when opened from nested report dialog', (
    WidgetTester tester,
  ) async {
    late WidgetRef ref;
    const ModuleReportingReport report = ModuleReportingReport(
      id: 'total_sales',
      label: 'TOTAL SALES',
      categoryId: 'sales',
      contentKind: ModuleReportingContentKind.table,
      datasetKey: 'pharmacy_drug_consumption',
    );
    final ModuleReportingReportSnapshot snapshot =
        ModuleReportingReportSnapshot.ready(
          columns: const <String>['drug', 'qty'],
          rows: const <Map<String, Object?>>[
            <String, Object?>{'drug': 'Amox', 'qty': 3},
          ],
          title: 'TOTAL SALES',
          subtitle: 'demo',
        );
    final ModuleReportingLabels labels = _labels();

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer(
              builder: (BuildContext context, WidgetRef widgetRef, _) {
                ref = widgetRef;
                return AppButton.primary(
                  label: 'Open report',
                  onPressed: () {
                    unawaited(
                      showAppDialog<void>(
                        context: context,
                        builder: (BuildContext dialogContext) {
                          return AppDialog(
                            title: const Text('TOTAL SALES'),
                            content: const Text('Report body'),
                            actions: <Widget>[
                              AppButton.primary(
                                label: 'Print',
                                onPressed: () {
                                  unawaited(
                                    openModuleReportingPrintPreviewDialog(
                                      context: dialogContext,
                                      ref: ref,
                                      report: report,
                                      snapshot: snapshot,
                                      labels: labels,
                                      periodLabel: 'Last month',
                                      from: DateTime(2026, 7, 8),
                                      to: DateTime(2026, 8, 7),
                                    ),
                                  );
                                },
                              ),
                            ],
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open report'));
    await tester.pumpAndSettle();
    expect(find.text('TOTAL SALES'), findsWidgets);

    await tester.tap(find.widgetWithText(AppButton, 'Print'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final Object? exception = tester.takeException();
    expect(exception, isNull, reason: '$exception');

    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
    expect(find.byType(ModuleReportingPrintPreviewDialog), findsOneWidget);
    expect(find.textContaining('PRINT PREVIEW'), findsWidgets);
  });
}
