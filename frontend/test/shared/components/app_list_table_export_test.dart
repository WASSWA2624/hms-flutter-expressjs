import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/icons/app_action_icons.dart';

import 'component_test_app.dart';

void main() {
  setUp(() {
    AppListTableColumnVisibilityMemory.instance.clear();
  });

  final List<AppListTableColumn<_ExportRow>> columns =
      <AppListTableColumn<_ExportRow>>[
        AppListTableColumn<_ExportRow>(
          id: 'title',
          label: 'Title',
          alwaysVisible: true,
          exportValue: (_ExportRow item) => item.title,
          cellBuilder: (_, _ExportRow item) => Text(item.title),
        ),
        AppListTableColumn<_ExportRow>(
          id: 'status',
          label: 'Status',
          exportValue: (_ExportRow item) => item.status,
          cellBuilder: (_, _ExportRow item) => Text(item.status),
        ),
        AppListTableColumn<_ExportRow>(
          id: 'code',
          label: 'Code',
          exportValue: (_ExportRow item) => item.code,
          cellBuilder: (_, _ExportRow item) => Text(item.code),
        ),
      ];

  final List<_ExportRow> items = <_ExportRow>[
    _ExportRow(
      id: '1',
      title: 'Alpha',
      status: 'Active',
      code: 'A1',
      occurredAt: DateTime(2026, 1, 10),
    ),
    _ExportRow(
      id: '2',
      title: 'Beta',
      status: 'Draft',
      code: 'B2',
      occurredAt: DateTime(2026, 2, 15),
    ),
    _ExportRow(
      id: '3',
      title: 'Gamma',
      status: 'Active',
      code: 'C3',
      occurredAt: DateTime(2026, 3, 20),
    ),
  ];

  test('buildAppListTableExcelBytes writes selected columns only', () {
    final Uint8List bytes = buildAppListTableExcelBytes<_ExportRow>(
      rows: items,
      columns: columns
          .where(
            (AppListTableColumn<_ExportRow> column) =>
                column.key == 'title' || column.key == 'code',
          )
          .toList(growable: false),
      sheetName: 'Patients',
    );

    final Excel workbook = Excel.decodeBytes(bytes);
    final Sheet sheet = workbook['Patients']!;
    expect(sheet.cell(CellIndex.indexByString('A1')).value?.toString(), 'Title');
    expect(sheet.cell(CellIndex.indexByString('B1')).value?.toString(), 'Code');
    expect(
      sheet.cell(CellIndex.indexByString('A2')).value?.toString(),
      'Alpha',
    );
    expect(sheet.cell(CellIndex.indexByString('B2')).value?.toString(), 'A1');
    expect(sheet.cell(CellIndex.indexByString('C1')).value, isNull);
  });

  test('appListTablePlainTextFromWidget reads nested Text cells', () {
    expect(
      appListTablePlainTextFromWidget(const Text('Procedure A')),
      'Procedure A',
    );
    expect(
      appListTablePlainTextFromWidget(
        const Padding(padding: EdgeInsets.all(4), child: Text('CT')),
      ),
      'CT',
    );
    expect(
      appListTablePlainTextFromWidget(
        AppButton.tertiary(label: 'Edit', onPressed: () {}),
      ),
      isNull,
    );
    expect(
      appListTablePlainTextFromWidget(
        const AppListItemText(title: 'Jane Doe', subtitle: 'P-001'),
      ),
      'Jane Doe P-001',
    );
  });

  testWidgets(
    'buildAppListTableExcelBytes falls back to cellBuilder text',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
      );
      final BuildContext context = tester.element(find.byType(SizedBox));

      final List<AppListTableColumn<_ExportRow>> fallbackColumns =
          <AppListTableColumn<_ExportRow>>[
            AppListTableColumn<_ExportRow>(
              id: 'title',
              label: 'Title',
              cellBuilder: (_, _ExportRow item) => Text(item.title),
            ),
            AppListTableColumn<_ExportRow>(
              id: 'code',
              label: 'Code',
              cellBuilder: (_, _ExportRow item) =>
                  Padding(padding: EdgeInsets.zero, child: Text(item.code)),
            ),
            AppListTableColumn<_ExportRow>(
              id: 'actions',
              label: 'Actions',
              alwaysVisible: true,
              cellBuilder: (_, __) =>
                  AppButton.tertiary(label: 'Edit', onPressed: () {}),
            ),
          ];

      expect(fallbackColumns[2].includesInExport, isFalse);

      final Uint8List bytes = buildAppListTableExcelBytes<_ExportRow>(
        rows: items,
        columns: fallbackColumns
            .where((AppListTableColumn<_ExportRow> column) => column.includesInExport)
            .toList(growable: false),
        sheetName: 'Radiology',
        context: context,
      );

      final Excel workbook = Excel.decodeBytes(bytes);
      final Sheet sheet = workbook['Radiology']!;
      expect(
        sheet.cell(CellIndex.indexByString('A1')).value?.toString(),
        'Title',
      );
      expect(
        sheet.cell(CellIndex.indexByString('B1')).value?.toString(),
        'Code',
      );
      expect(
        sheet.cell(CellIndex.indexByString('A2')).value?.toString(),
        'Alpha',
      );
      expect(
        sheet.cell(CellIndex.indexByString('B2')).value?.toString(),
        'A1',
      );
      expect(sheet.cell(CellIndex.indexByString('C1')).value, isNull);
    },
  );

  test('applyAppListTableExportFilters narrows by date and row filter', () {
    final List<_ExportRow> filtered = applyAppListTableExportFilters<_ExportRow>(
      rows: items,
      filters: AppSearchBarFilterValue(
        dateFrom: DateTime(2026, 2, 1),
        dateTo: DateTime(2026, 3, 31),
        options: const <String, String>{'status': 'Active'},
      ),
      dateOf: (_ExportRow item) => item.occurredAt,
      rowFilter: (_ExportRow item, AppSearchBarFilterValue filters) {
        final String? status = filters.option('status');
        return status == null || item.status == status;
      },
    );

    expect(filtered.map((_ExportRow row) => row.id), <String>['3']);
  });

  test(
    'applyAppListTableExportFilters keeps rows when dates set but dateOf missing',
    () {
      final List<_ExportRow> filtered =
          applyAppListTableExportFilters<_ExportRow>(
            rows: items,
            filters: AppSearchBarFilterValue(
              dateFrom: DateTime(2026, 2, 1),
              dateTo: DateTime(2026, 3, 31),
            ),
          );

      expect(filtered, items);
    },
  );

  test('applyAppListTableExportFilters returns all rows when filters cleared', () {
    final List<_ExportRow> filtered = applyAppListTableExportFilters<_ExportRow>(
      rows: items,
      filters: AppSearchBarFilterValue.empty,
      dateOf: (_ExportRow item) => item.occurredAt,
      rowFilter: (_ExportRow item, AppSearchBarFilterValue filters) {
        fail('rowFilter should not run when filters are inactive');
      },
    );

    expect(filtered, items);
  });

  testWidgets('Export action appears only when enabled and allowed', (
    WidgetTester tester,
  ) async {
    final TextEditingController searchController = TextEditingController();
    addTearDown(searchController.dispose);

    Future<void> pumpTable({
      required bool enableExport,
      required bool canExport,
    }) {
      return pumpComponent(
        tester,
        SizedBox(
          height: 420,
          child: AppListTable<_ExportRow>(
            items: items,
            columns: columns,
            enableExport: enableExport,
            canExport: canExport,
            search: AppListTableSearch<_ExportRow>(
              controller: searchController,
              semanticLabel: 'Search rows',
              matcher: (_, _) => true,
            ),
            mobileItemBuilder: (BuildContext context, _ExportRow item) {
              return Text(item.title);
            },
          ),
        ),
        size: const Size(900, 600),
      );
    }

    await pumpTable(enableExport: false, canExport: true);
    expect(find.byIcon(AppActionIcons.download), findsNothing);

    await pumpTable(enableExport: true, canExport: false);
    expect(find.byIcon(AppActionIcons.download), findsNothing);

    await pumpTable(enableExport: true, canExport: true);
    expect(find.byIcon(AppActionIcons.download), findsOneWidget);
  });

  testWidgets('Export is enabled by default on AppListTable', (
    WidgetTester tester,
  ) async {
    final TextEditingController searchController = TextEditingController();
    addTearDown(searchController.dispose);

    await pumpComponent(
      tester,
      SizedBox(
        height: 420,
        child: AppListTable<_ExportRow>(
          items: items,
          columns: columns,
          search: AppListTableSearch<_ExportRow>(
            controller: searchController,
            semanticLabel: 'Search rows',
            matcher: (_, _) => true,
          ),
          mobileItemBuilder: (BuildContext context, _ExportRow item) {
            return Text(item.title);
          },
        ),
      ),
      size: const Size(900, 600),
    );

    expect(find.byIcon(AppActionIcons.download), findsOneWidget);
  });

  testWidgets(
    'Export dialog prefills Settings visibility and does not mutate it',
    (WidgetTester tester) async {
      final TextEditingController searchController = TextEditingController();
      addTearDown(searchController.dispose);

      final AppListTableColumnVisibilityController<_ExportRow> visibility =
          AppListTableColumnVisibilityController<_ExportRow>();
      addTearDown(visibility.dispose);

      Uint8List? savedBytes;
      Set<String>? exportedKeys;

      await pumpComponent(
        tester,
        SizedBox(
          height: 520,
          child: AppListTable<_ExportRow>(
            items: items,
            columns: columns,
            columnChoices: columns,
            columnVisibilityController: visibility,
            columnVisibilityStorageKey: 'export-test-visibility',
            exportConfig: AppListTableExportConfig<_ExportRow>(
              fileNameStem: 'export_test',
              enableDateFilter: false,
              saver:
                  ({required Uint8List bytes, required String fileName}) async {
                    savedBytes = bytes;
                    return true;
                  },
            ),
            search: AppListTableSearch<_ExportRow>(
              controller: searchController,
              semanticLabel: 'Search rows',
              matcher: (_, _) => true,
            ),
            mobileItemBuilder: (BuildContext context, _ExportRow item) {
              return Text(item.title);
            },
          ),
        ),
        size: const Size(1000, 700),
      );

      await tester.pumpAndSettle();
      visibility.syncColumns(columns: columns, columnChoices: columns);
      visibility.applyVisibleColumnKeys(<String>{'title', 'status'});
      await tester.pumpAndSettle();

      expect(visibility.isColumnVisible('title'), isTrue);
      expect(visibility.isColumnVisible('status'), isTrue);
      expect(visibility.isColumnVisible('code'), isFalse);

      await tester.tap(find.byIcon(AppActionIcons.download));
      await tester.pumpAndSettle();

      expect(find.byType(AppListTableExportDialog<_ExportRow>), findsOneWidget);
      expect(find.text('EXPORT'), findsOneWidget);

      final CheckboxListTile codeTile = tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, 'Code'),
      );
      expect(codeTile.value, isFalse);

      final CheckboxListTile statusTile = tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, 'Status'),
      );
      expect(statusTile.value, isTrue);

      await tester.tap(find.widgetWithText(CheckboxListTile, 'Code'));
      await tester.pumpAndSettle();

      expect(visibility.isColumnVisible('code'), isFalse);

      await tester.tap(find.widgetWithText(AppButton, 'Export').last);
      await tester.pumpAndSettle();

      expect(savedBytes, isNotNull);
      final Excel workbook = Excel.decodeBytes(savedBytes!);
      final Sheet sheet = workbook.tables.values.first;
      exportedKeys = <String>{
        for (int index = 0; index < 3; index += 1)
          if (sheet
                  .cell(
                    CellIndex.indexByColumnRow(
                      columnIndex: index,
                      rowIndex: 0,
                    ),
                  )
                  .value !=
              null)
            sheet
                .cell(
                  CellIndex.indexByColumnRow(columnIndex: index, rowIndex: 0),
                )
                .value
                .toString(),
      };
      expect(exportedKeys, containsAll(<String>['Title', 'Status', 'Code']));
      expect(find.byType(AppListTableExportDialog<_ExportRow>), findsNothing);
    },
  );

  testWidgets('Select all checkbox selects and deselects export columns', (
    WidgetTester tester,
  ) async {
    final TextEditingController searchController = TextEditingController();
    addTearDown(searchController.dispose);

    await pumpComponent(
      tester,
      SizedBox(
        height: 520,
        child: AppListTable<_ExportRow>(
          items: items,
          columns: columns,
          exportConfig: AppListTableExportConfig<_ExportRow>(
            enableDateFilter: false,
            saver: ({required Uint8List bytes, required String fileName}) async {
              return true;
            },
          ),
          search: AppListTableSearch<_ExportRow>(
            controller: searchController,
            semanticLabel: 'Search rows',
            matcher: (_, _) => true,
          ),
          mobileItemBuilder: (BuildContext context, _ExportRow item) {
            return Text(item.title);
          },
        ),
      ),
      size: const Size(1000, 700),
    );

    await tester.tap(find.byIcon(AppActionIcons.download));
    await tester.pumpAndSettle();

    final Finder selectAll = find.widgetWithText(CheckboxListTile, 'Select all');
    expect(selectAll, findsOneWidget);

    // Ensure a known starting point: not all selected.
    if (tester.widget<CheckboxListTile>(selectAll).value == true) {
      await tester.tap(selectAll);
      await tester.pumpAndSettle();
    }
    expect(tester.widget<CheckboxListTile>(selectAll).value, isFalse);

    await tester.tap(selectAll);
    await tester.pumpAndSettle();

    expect(tester.widget<CheckboxListTile>(selectAll).value, isTrue);
    expect(
      tester
          .widget<CheckboxListTile>(
            find.widgetWithText(CheckboxListTile, 'Code'),
          )
          .value,
      isTrue,
    );

    await tester.tap(selectAll);
    await tester.pumpAndSettle();

    expect(tester.widget<CheckboxListTile>(selectAll).value, isFalse);
    expect(
      tester
          .widget<CheckboxListTile>(
            find.widgetWithText(CheckboxListTile, 'Title'),
          )
          .value,
      isTrue,
    );
    expect(
      tester
          .widget<CheckboxListTile>(
            find.widgetWithText(CheckboxListTile, 'Code'),
          )
          .value,
      isFalse,
    );
  });

  testWidgets('Reset columns restores Settings defaults when selection changes', (
    WidgetTester tester,
  ) async {
    final TextEditingController searchController = TextEditingController();
    addTearDown(searchController.dispose);

    final AppListTableColumnVisibilityController<_ExportRow> visibility =
        AppListTableColumnVisibilityController<_ExportRow>();
    addTearDown(visibility.dispose);

    await pumpComponent(
      tester,
      SizedBox(
        height: 520,
        child: AppListTable<_ExportRow>(
          items: items,
          columns: columns,
          columnChoices: columns,
          columnVisibilityController: visibility,
          columnVisibilityStorageKey: 'export-reset-columns',
          exportConfig: AppListTableExportConfig<_ExportRow>(
            enableDateFilter: false,
            saver: ({required Uint8List bytes, required String fileName}) async {
              return true;
            },
          ),
          search: AppListTableSearch<_ExportRow>(
            controller: searchController,
            semanticLabel: 'Search rows',
            matcher: (_, _) => true,
          ),
          mobileItemBuilder: (BuildContext context, _ExportRow item) {
            return Text(item.title);
          },
        ),
      ),
      size: const Size(1000, 700),
    );

    await tester.pumpAndSettle();
    visibility.syncColumns(columns: columns, columnChoices: columns);
    visibility.applyVisibleColumnKeys(<String>{'title', 'status'});
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(AppActionIcons.download));
    await tester.pumpAndSettle();

    final Finder reset = find.text('Reset columns');
    expect(reset, findsOneWidget);
    expect(
      tester
          .widget<AppButton>(find.widgetWithText(AppButton, 'Reset columns'))
          .enabled,
      isFalse,
    );

    await tester.tap(find.widgetWithText(CheckboxListTile, 'Select all'));
    await tester.pumpAndSettle();
    if (tester
            .widget<CheckboxListTile>(
              find.widgetWithText(CheckboxListTile, 'Select all'),
            )
            .value !=
        true) {
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Select all'));
      await tester.pumpAndSettle();
    }

    expect(
      tester
          .widget<AppButton>(find.widgetWithText(AppButton, 'Reset columns'))
          .enabled,
      isTrue,
    );

    await tester.tap(reset);
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<CheckboxListTile>(
            find.widgetWithText(CheckboxListTile, 'Code'),
          )
          .value,
      isFalse,
    );
    expect(
      tester
          .widget<AppButton>(find.widgetWithText(AppButton, 'Reset columns'))
          .enabled,
      isFalse,
    );
  });

  testWidgets('Clear filters restores full row export', (
    WidgetTester tester,
  ) async {
    final TextEditingController searchController = TextEditingController();
    addTearDown(searchController.dispose);

    Uint8List? savedBytes;

    await pumpComponent(
      tester,
      SizedBox(
        height: 520,
        child: AppListTable<_ExportRow>(
          items: items,
          columns: columns,
          exportConfig: AppListTableExportConfig<_ExportRow>(
            enableDateFilter: false,
            initialFilterValue: const AppSearchBarFilterValue(
              options: <String, String>{'status': 'Missing'},
            ),
            filterGroups: const <AppSearchBarFilterGroup>[
              AppSearchBarFilterGroup(
                key: 'status',
                label: 'Status',
                choices: <AppSearchBarFilterChoice>[
                  AppSearchBarFilterChoice(value: 'Active', label: 'Active'),
                  AppSearchBarFilterChoice(value: 'Draft', label: 'Draft'),
                  AppSearchBarFilterChoice(
                    value: 'Missing',
                    label: 'Missing',
                  ),
                ],
              ),
            ],
            rowFilter: (_ExportRow item, AppSearchBarFilterValue filters) {
              final String? status = filters.option('status');
              return status == null || item.status == status;
            },
            saver:
                ({required Uint8List bytes, required String fileName}) async {
                  savedBytes = bytes;
                  return true;
                },
          ),
          search: AppListTableSearch<_ExportRow>(
            controller: searchController,
            semanticLabel: 'Search rows',
            matcher: (_, _) => true,
          ),
          mobileItemBuilder: (BuildContext context, _ExportRow item) {
            return Text(item.title);
          },
        ),
      ),
      size: const Size(1000, 700),
    );

    await tester.tap(find.byIcon(AppActionIcons.download));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(AppButton, 'Export').last);
    await tester.pumpAndSettle();
    expect(find.text('No rows match the export filters.'), findsOneWidget);

    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(AppButton, 'Export').last);
    await tester.pumpAndSettle();

    expect(savedBytes, isNotNull);
    final Excel workbook = Excel.decodeBytes(savedBytes!);
    final Sheet sheet = workbook.tables.values.first;
    expect(
      sheet.cell(CellIndex.indexByString('A2')).value?.toString(),
      'Alpha',
    );
    expect(
      sheet.cell(CellIndex.indexByString('A4')).value?.toString(),
      'Gamma',
    );
  });
}

final class _ExportRow {
  const _ExportRow({
    required this.id,
    required this.title,
    required this.status,
    required this.code,
    required this.occurredAt,
  });

  final String id;
  final String title;
  final String status;
  final String code;
  final DateTime occurredAt;
}
