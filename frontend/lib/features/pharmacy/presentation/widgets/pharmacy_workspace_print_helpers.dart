import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';

/// Column choice for Pharmacy workspace list print (aligned with exportable fields).
final class PharmacyWorkspacePrintColumn {
  const PharmacyWorkspacePrintColumn({
    required this.id,
    required this.label,
  });

  final String id;
  final String label;
}

abstract final class PharmacyWorkspacePrintStrings {
  static const String optionsSection = 'Print sections';
  static const String summarySection = 'Summary';
  static const String rowsSection = 'Rows';
  static String rowCount(int count) => '$count rows';
}

final class PharmacyWorkspacePrintOptionsController extends ChangeNotifier {
  PharmacyWorkspacePrintOptionsController({
    required List<PharmacyWorkspacePrintColumn> columns,
  }) : _columns = List<PharmacyWorkspacePrintColumn>.unmodifiable(columns) {
    _selectedColumnIds =
        columns.map((PharmacyWorkspacePrintColumn c) => c.id).toSet();
    _includeSummary = true;
    _includeRows = true;
  }

  final List<PharmacyWorkspacePrintColumn> _columns;
  late Set<String> _selectedColumnIds;
  late bool _includeSummary;
  late bool _includeRows;

  List<PharmacyWorkspacePrintColumn> get columns => _columns;

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
              _columns.any((PharmacyWorkspacePrintColumn c) => c.id == id),
        )
        .toSet();
    if (setEquals(next, _selectedColumnIds)) {
      return;
    }
    _selectedColumnIds = next;
    notifyListeners();
  }
}

/// Preview-first worklist print for Pharmacy tables.
Future<void> printPharmacyWorkspaceList({
  required WidgetRef ref,
  required BuildContext context,
  required String title,
  required List<PharmacyWorkspacePrintColumn> columns,
  required List<Map<String, String>> rows,
  required String emptyText,
}) async {
  final PharmacyWorkspacePrintOptionsController options =
      PharmacyWorkspacePrintOptionsController(columns: columns);

  String buildBodyHtml() {
    return pharmacyWorkspaceListHtml(
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
          ? PharmacyWorkspacePrintStrings.rowCount(rows.length)
          : null,
      recordReference: PrintFormContextReference(
        label: title,
        value: PharmacyWorkspacePrintStrings.rowCount(rows.length),
      ),
      bodyHtml: buildBodyHtml(),
      bodyHtmlBuilder: buildBodyHtml,
      previewSectionsExtra: PharmacyWorkspacePrintOptionsSection(
        controller: options,
      ),
      previewDocumentRevision: options,
      isPrintEnabled: () => options.canPrint,
    );
  } finally {
    options.dispose();
  }
}

/// Builds print rows from [AppListTableColumn]s (exportable only) and opens preview.
Future<void> printPharmacyListTable<T>({
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
  final List<PharmacyWorkspacePrintColumn> printColumns =
      <PharmacyWorkspacePrintColumn>[
        for (final AppListTableColumn<T> column in exportColumns)
          PharmacyWorkspacePrintColumn(id: column.key, label: column.label),
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
  await printPharmacyWorkspaceList(
    ref: ref,
    context: context,
    title: title,
    columns: printColumns,
    rows: printRows,
    emptyText: emptyText,
  );
}

String pharmacyWorkspaceListHtml({
  required List<Map<String, String>> rows,
  required PharmacyWorkspacePrintOptionsController options,
  required String emptyText,
}) {
  final StringBuffer buffer = StringBuffer();

  if (options.includeSummary) {
    buffer.write(
      PrintFormTemplate.section(
        title: PharmacyWorkspacePrintStrings.summarySection,
        bodyHtml:
            '<p>${PrintFormTemplate.escape(PharmacyWorkspacePrintStrings.rowCount(rows.length))}</p>',
      ),
    );
  }

  if (options.includeRows) {
    final List<PharmacyWorkspacePrintColumn> selected = options.columns
        .where(
          (PharmacyWorkspacePrintColumn column) =>
              options.selectedColumnIds.contains(column.id),
        )
        .toList(growable: false);
    final List<List<String>> tableRows = <List<String>>[
      for (final Map<String, String> row in rows)
        <String>[
          for (final PharmacyWorkspacePrintColumn column in selected)
            row[column.id] ?? '',
        ],
    ];
    buffer.write(
      PrintFormTemplate.section(
        title: PharmacyWorkspacePrintStrings.rowsSection,
        bodyHtml: PrintFormTemplate.table(
          headers: <String>[
            for (final PharmacyWorkspacePrintColumn column in selected)
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

class PharmacyWorkspacePrintOptionsSection extends StatelessWidget {
  const PharmacyWorkspacePrintOptionsSection({
    required this.controller,
    super.key,
  });

  final PharmacyWorkspacePrintOptionsController controller;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, _) {
        return AppFormSection(
          title: PharmacyWorkspacePrintStrings.optionsSection,
          density: AppFormSectionDensity.compact,
          children: <Widget>[
            AppReportSectionPicker(
              compact: true,
              sections: const <AppReportSectionData>[
                AppReportSectionData(
                  id: 'summary',
                  title: PharmacyWorkspacePrintStrings.summarySection,
                  icon: Icons.summarize_outlined,
                ),
                AppReportSectionData(
                  id: 'rows',
                  title: PharmacyWorkspacePrintStrings.rowsSection,
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
                  for (final PharmacyWorkspacePrintColumn column
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
