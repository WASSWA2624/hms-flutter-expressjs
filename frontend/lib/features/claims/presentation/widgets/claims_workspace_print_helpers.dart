import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';

/// Column choice for Claims workspace list print (aligned with exportable fields).
final class ClaimsWorkspacePrintColumn {
  const ClaimsWorkspacePrintColumn({
    required this.id,
    required this.label,
  });

  final String id;
  final String label;
}

abstract final class ClaimsWorkspacePrintStrings {
  static const String optionsSection = 'Print sections';
  static const String summarySection = 'Summary';
  static const String rowsSection = 'Rows';
  static String rowCount(int count) => '$count rows';
}

final class ClaimsWorkspacePrintOptionsController extends ChangeNotifier {
  ClaimsWorkspacePrintOptionsController({
    required List<ClaimsWorkspacePrintColumn> columns,
  }) : _columns = List<ClaimsWorkspacePrintColumn>.unmodifiable(columns) {
    _selectedColumnIds =
        columns.map((ClaimsWorkspacePrintColumn c) => c.id).toSet();
    _includeSummary = true;
    _includeRows = true;
  }

  final List<ClaimsWorkspacePrintColumn> _columns;
  late Set<String> _selectedColumnIds;
  late bool _includeSummary;
  late bool _includeRows;

  List<ClaimsWorkspacePrintColumn> get columns => _columns;

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
          (String id) =>
              _columns.any((ClaimsWorkspacePrintColumn c) => c.id == id),
        )
        .toSet();
    if (setEquals(next, _selectedColumnIds)) {
      return;
    }
    _selectedColumnIds = next;
    notifyListeners();
  }
}

/// Preview-first worklist print for Claims queue tables.
Future<void> printClaimsWorkspaceList({
  required WidgetRef ref,
  required BuildContext context,
  required String title,
  required List<ClaimsWorkspacePrintColumn> columns,
  required List<Map<String, String>> rows,
  required String emptyText,
}) async {
  final ClaimsWorkspacePrintOptionsController options =
      ClaimsWorkspacePrintOptionsController(columns: columns);

  String buildBodyHtml() {
    return claimsWorkspaceListHtml(
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
          ? ClaimsWorkspacePrintStrings.rowCount(rows.length)
          : null,
      recordReference: PrintFormContextReference(
        label: title,
        value: ClaimsWorkspacePrintStrings.rowCount(rows.length),
      ),
      bodyHtml: buildBodyHtml(),
      bodyHtmlBuilder: buildBodyHtml,
      previewSectionsExtra: ClaimsWorkspacePrintOptionsSection(
        controller: options,
      ),
      previewDocumentRevision: options,
      isPrintEnabled: () => options.canPrint,
    );
  } finally {
    options.dispose();
  }
}

/// Maps [AppListTable] exportable columns + rows into Claims list print.
Future<void> printClaimsListTable<T>({
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
  final List<ClaimsWorkspacePrintColumn> printColumns =
      <ClaimsWorkspacePrintColumn>[
        for (final AppListTableColumn<T> column in exportColumns)
          ClaimsWorkspacePrintColumn(id: column.key, label: column.label),
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
  await printClaimsWorkspaceList(
    ref: ref,
    context: context,
    title: title,
    columns: printColumns,
    rows: printRows,
    emptyText: emptyText,
  );
}

String claimsWorkspaceListHtml({
  required List<Map<String, String>> rows,
  required ClaimsWorkspacePrintOptionsController options,
  required String emptyText,
}) {
  final StringBuffer buffer = StringBuffer();

  if (options.includeSummary) {
    buffer.write(
      PrintFormTemplate.section(
        title: ClaimsWorkspacePrintStrings.summarySection,
        bodyHtml:
            '<p>${PrintFormTemplate.escape(ClaimsWorkspacePrintStrings.rowCount(rows.length))}</p>',
      ),
    );
  }

  if (options.includeRows) {
    final List<ClaimsWorkspacePrintColumn> selected = options.columns
        .where(
          (ClaimsWorkspacePrintColumn column) =>
              options.selectedColumnIds.contains(column.id),
        )
        .toList(growable: false);
    final List<List<String>> tableRows = <List<String>>[
      for (final Map<String, String> row in rows)
        <String>[
          for (final ClaimsWorkspacePrintColumn column in selected)
            row[column.id] ?? '',
        ],
    ];
    buffer.write(
      PrintFormTemplate.section(
        title: ClaimsWorkspacePrintStrings.rowsSection,
        bodyHtml: PrintFormTemplate.table(
          headers: <String>[
            for (final ClaimsWorkspacePrintColumn column in selected)
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

class ClaimsWorkspacePrintOptionsSection extends StatelessWidget {
  const ClaimsWorkspacePrintOptionsSection({
    required this.controller,
    super.key,
  });

  final ClaimsWorkspacePrintOptionsController controller;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, _) {
        return AppFormSection(
          title: ClaimsWorkspacePrintStrings.optionsSection,
          density: AppFormSectionDensity.compact,
          children: <Widget>[
            AppReportSectionPicker(
              compact: true,
              sections: const <AppReportSectionData>[
                AppReportSectionData(
                  id: 'summary',
                  title: ClaimsWorkspacePrintStrings.summarySection,
                  icon: Icons.summarize_outlined,
                ),
                AppReportSectionData(
                  id: 'rows',
                  title: ClaimsWorkspacePrintStrings.rowsSection,
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
                  for (final ClaimsWorkspacePrintColumn column
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
