import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';

/// Column choice for Access Admin workspace list print (aligned with exportable fields).
final class AccessAdminWorkspacePrintColumn {
  const AccessAdminWorkspacePrintColumn({
    required this.id,
    required this.label,
  });

  final String id;
  final String label;
}

final class AccessAdminWorkspacePrintOptionsController extends ChangeNotifier {
  AccessAdminWorkspacePrintOptionsController({
    required List<AccessAdminWorkspacePrintColumn> columns,
  }) : _columns = List<AccessAdminWorkspacePrintColumn>.unmodifiable(columns) {
    _selectedColumnIds =
        columns.map((AccessAdminWorkspacePrintColumn c) => c.id).toSet();
    _includeSummary = true;
    _includeRows = true;
  }

  final List<AccessAdminWorkspacePrintColumn> _columns;
  late Set<String> _selectedColumnIds;
  late bool _includeSummary;
  late bool _includeRows;

  List<AccessAdminWorkspacePrintColumn> get columns => _columns;

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
              _columns.any((AccessAdminWorkspacePrintColumn c) => c.id == id),
        )
        .toSet();
    if (setEquals(next, _selectedColumnIds)) {
      return;
    }
    _selectedColumnIds = next;
    notifyListeners();
  }
}

/// Preview-first worklist print for Access Admin queue tables.
Future<void> printAccessAdminWorkspaceList({
  required WidgetRef ref,
  required BuildContext context,
  required String title,
  required List<AccessAdminWorkspacePrintColumn> columns,
  required List<Map<String, String>> rows,
  required String emptyText,
}) async {
  final AppLocalizations l10n = context.l10n;
  final AccessAdminWorkspacePrintOptionsController options =
      AccessAdminWorkspacePrintOptionsController(columns: columns);

  String buildBodyHtml() {
    return accessAdminWorkspaceListHtml(
      l10n: l10n,
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
      previewDialogTitle: l10n.printPreviewTitle,
      subtitle: options.includeSummary
          ? l10n.commonPrintRowCountLabel(rows.length)
          : null,
      recordReference: PrintFormContextReference(
        label: title,
        value: l10n.commonPrintRowCountLabel(rows.length),
      ),
      bodyHtml: buildBodyHtml(),
      bodyHtmlBuilder: buildBodyHtml,
      previewSectionsExtra: AccessAdminWorkspacePrintOptionsSection(
        controller: options,
      ),
      previewDocumentRevision: options,
      isPrintEnabled: () => options.canPrint,
    );
  } finally {
    options.dispose();
  }
}

/// Maps [AppListTable] exportable columns + rows into Access Admin list print.
Future<void> printAccessAdminListTable<T>({
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
  final List<AccessAdminWorkspacePrintColumn> printColumns =
      <AccessAdminWorkspacePrintColumn>[
        for (final AppListTableColumn<T> column in exportColumns)
          AccessAdminWorkspacePrintColumn(id: column.key, label: column.label),
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
  await printAccessAdminWorkspaceList(
    ref: ref,
    context: context,
    title: title,
    columns: printColumns,
    rows: printRows,
    emptyText: emptyText,
  );
}

String accessAdminWorkspaceListHtml({
  required AppLocalizations l10n,
  required List<Map<String, String>> rows,
  required AccessAdminWorkspacePrintOptionsController options,
  required String emptyText,
}) {
  final StringBuffer buffer = StringBuffer();

  if (options.includeSummary) {
    buffer.write(
      PrintFormTemplate.section(
        title: l10n.commonPrintSummarySectionLabel,
        bodyHtml:
            '<p>${PrintFormTemplate.escape(l10n.commonPrintRowCountLabel(rows.length))}</p>',
      ),
    );
  }

  if (options.includeRows) {
    final List<AccessAdminWorkspacePrintColumn> selected = options.columns
        .where(
          (AccessAdminWorkspacePrintColumn column) =>
              options.selectedColumnIds.contains(column.id),
        )
        .toList(growable: false);
    final List<List<String>> tableRows = <List<String>>[
      for (final Map<String, String> row in rows)
        <String>[
          for (final AccessAdminWorkspacePrintColumn column in selected)
            row[column.id] ?? '',
        ],
    ];
    buffer.write(
      PrintFormTemplate.section(
        title: l10n.commonPrintRowsSectionLabel,
        bodyHtml: PrintFormTemplate.table(
          headers: <String>[
            for (final AccessAdminWorkspacePrintColumn column in selected)
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

class AccessAdminWorkspacePrintOptionsSection extends StatelessWidget {
  const AccessAdminWorkspacePrintOptionsSection({
    required this.controller,
    super.key,
  });

  final AccessAdminWorkspacePrintOptionsController controller;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;

    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, _) {
        return AppFormSection(
          title: l10n.commonPrintSectionsLabel,
          density: AppFormSectionDensity.compact,
          children: <Widget>[
            AppReportSectionPicker(
              compact: true,
              sections: <AppReportSectionData>[
                AppReportSectionData(
                  id: 'summary',
                  title: l10n.commonPrintSummarySectionLabel,
                  icon: Icons.summarize_outlined,
                ),
                AppReportSectionData(
                  id: 'rows',
                  title: l10n.commonPrintRowsSectionLabel,
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
                  for (final AccessAdminWorkspacePrintColumn column
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
