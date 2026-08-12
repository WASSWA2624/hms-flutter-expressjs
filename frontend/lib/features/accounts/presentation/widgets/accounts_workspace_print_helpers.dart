import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';

/// Column choice for Accounts workspace list print (aligned with exportable
/// fields).
final class AccountsWorkspacePrintColumn {
  const AccountsWorkspacePrintColumn({
    required this.id,
    required this.label,
  });

  final String id;
  final String label;
}

abstract final class AccountsWorkspacePrintStrings {
  static const String optionsSection = 'Print sections';
  static const String summarySection = 'Summary';
  static const String rowsSection = 'Rows';
  static String rowCount(int count) => '$count rows';
}

final class AccountsWorkspacePrintOptionsController extends ChangeNotifier {
  AccountsWorkspacePrintOptionsController({
    required List<AccountsWorkspacePrintColumn> columns,
  }) : _columns = List<AccountsWorkspacePrintColumn>.unmodifiable(columns) {
    _selectedColumnIds =
        columns.map((AccountsWorkspacePrintColumn c) => c.id).toSet();
    _includeSummary = true;
    _includeRows = true;
  }

  final List<AccountsWorkspacePrintColumn> _columns;
  late Set<String> _selectedColumnIds;
  late bool _includeSummary;
  late bool _includeRows;

  List<AccountsWorkspacePrintColumn> get columns => _columns;

  Set<String> get selectedColumnIds =>
      Set<String>.unmodifiable(_selectedColumnIds);

  bool get includeSummary => _includeSummary;

  bool get includeRows => _includeRows;

  bool get canPrint =>
      (_includeSummary || _includeRows) &&
      (!_includeRows || _selectedColumnIds.isNotEmpty);

  void setIncludeSummary(bool value) {
    if (_includeSummary == value) {
      return;
    }
    _includeSummary = value;
    notifyListeners();
  }

  void setIncludeRows(bool value) {
    if (_includeRows == value) {
      return;
    }
    _includeRows = value;
    notifyListeners();
  }

  void setSelectedColumns(Set<String> selected) {
    final Set<String> next = selected
        .where(
          (String id) => _columns.any(
            (AccountsWorkspacePrintColumn c) => c.id == id,
          ),
        )
        .toSet();
    if (setEquals(next, _selectedColumnIds)) {
      return;
    }
    _selectedColumnIds = next;
    notifyListeners();
  }
}

/// Preview-first worklist print for Accounts tables.
Future<void> printAccountsWorkspaceList({
  required WidgetRef ref,
  required BuildContext context,
  required String title,
  required List<AccountsWorkspacePrintColumn> columns,
  required List<Map<String, String>> rows,
  required String emptyText,
}) async {
  final AccountsWorkspacePrintOptionsController options =
      AccountsWorkspacePrintOptionsController(columns: columns);

  String buildBodyHtml() {
    return accountsWorkspaceListHtml(
      rows: rows,
      options: options,
      emptyText: emptyText,
    );
  }

  try {
    await PrintDocumentTemplates.registry(
      ref: ref,
      context: context,
      title: title,
      previewDialogTitle: context.l10n.printPreviewTitle,
      subtitle: options.includeSummary
          ? AccountsWorkspacePrintStrings.rowCount(rows.length)
          : null,
      recordReference: PrintFormContextReference(
        label: title,
        value: AccountsWorkspacePrintStrings.rowCount(rows.length),
      ),
      bodyHtml: buildBodyHtml(),
      bodyHtmlBuilder: buildBodyHtml,
      previewSectionsExtra: AccountsWorkspacePrintOptionsSection(
        controller: options,
      ),
      previewDocumentRevision: options,
      isPrintEnabled: () => options.canPrint,
    );
  } finally {
    options.dispose();
  }
}

/// Builds print rows from [AppListTableColumn]s (exportable only) and opens
/// preview.
Future<void> printAccountsListTable<T>({
  required WidgetRef ref,
  required BuildContext context,
  required String title,
  required List<AppListTableColumn<T>> columns,
  required List<T> items,
  required String emptyText,
}) async {
  final List<AppListTableColumn<T>> exportColumns = columns
      .where((AppListTableColumn<T> column) => column.includesInExport)
      .toList(growable: false);
  final List<AccountsWorkspacePrintColumn> printColumns =
      <AccountsWorkspacePrintColumn>[
        for (final AppListTableColumn<T> column in exportColumns)
          AccountsWorkspacePrintColumn(id: column.key, label: column.label),
      ];
  final List<Map<String, String>> printRows = <Map<String, String>>[
    for (final T item in items)
      <String, String>{
        for (final AppListTableColumn<T> column in exportColumns)
          column.key:
              resolveAppListTableExportValue(
                column: column,
                item: item,
                context: context,
              )?.toString() ??
              '',
      },
  ];
  await printAccountsWorkspaceList(
    ref: ref,
    context: context,
    title: title,
    columns: printColumns,
    rows: printRows,
    emptyText: emptyText,
  );
}

String accountsWorkspaceListHtml({
  required List<Map<String, String>> rows,
  required AccountsWorkspacePrintOptionsController options,
  required String emptyText,
}) {
  final StringBuffer buffer = StringBuffer();

  if (options.includeSummary) {
    buffer.write(
      PrintFormTemplate.section(
        title: AccountsWorkspacePrintStrings.summarySection,
        bodyHtml:
            '<p>${PrintFormTemplate.escape(AccountsWorkspacePrintStrings.rowCount(rows.length))}</p>',
      ),
    );
  }

  if (options.includeRows) {
    final List<AccountsWorkspacePrintColumn> selected = options.columns
        .where(
          (AccountsWorkspacePrintColumn column) =>
              options.selectedColumnIds.contains(column.id),
        )
        .toList(growable: false);
    final List<List<String>> tableRows = <List<String>>[
      for (final Map<String, String> row in rows)
        <String>[
          for (final AccountsWorkspacePrintColumn column in selected)
            row[column.id] ?? '',
        ],
    ];
    buffer.write(
      PrintFormTemplate.section(
        title: AccountsWorkspacePrintStrings.rowsSection,
        bodyHtml: PrintFormTemplate.table(
          headers: <String>[
            for (final AccountsWorkspacePrintColumn column in selected)
              column.label,
          ],
          rows: tableRows,
          emptyText: emptyText,
        ),
      ),
    );
  }

  return buffer.toString();
}

class AccountsWorkspacePrintOptionsSection extends StatelessWidget {
  const AccountsWorkspacePrintOptionsSection({
    required this.controller,
    super.key,
  });

  final AccountsWorkspacePrintOptionsController controller;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, _) {
        return AppFormSection(
          title: AccountsWorkspacePrintStrings.optionsSection,
          density: AppFormSectionDensity.compact,
          children: <Widget>[
            AppReportSectionPicker(
              compact: true,
              sections: const <AppReportSectionData>[
                AppReportSectionData(
                  id: 'summary',
                  title: AccountsWorkspacePrintStrings.summarySection,
                  icon: Icons.summarize_outlined,
                ),
                AppReportSectionData(
                  id: 'rows',
                  title: AccountsWorkspacePrintStrings.rowsSection,
                  icon: Icons.list_alt_outlined,
                ),
              ],
              selectedIds: <Object>{
                if (controller.includeSummary) 'summary',
                if (controller.includeRows) 'rows',
              },
              onSelectionChanged: (Set<Object> selected) {
                controller.setIncludeSummary(selected.contains('summary'));
                controller.setIncludeRows(selected.contains('rows'));
              },
            ),
            SizedBox(height: theme.spacing.xs),
            if (controller.includeRows)
              AppReportSectionPicker(
                compact: true,
                sections: <AppReportSectionData>[
                  for (final AccountsWorkspacePrintColumn column
                      in controller.columns)
                    AppReportSectionData(
                      id: column.id,
                      title: column.label,
                      icon: Icons.view_column_outlined,
                    ),
                ],
                selectedIds: controller.selectedColumnIds,
                onSelectionChanged: (Set<Object> selected) {
                  controller.setSelectedColumns(
                    selected.map((Object id) => id.toString()).toSet(),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}
