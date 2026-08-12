import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/forms/forms.dart';
import 'package:hosspi_hms/shared/printing/printing.dart';

/// Column choice for Billing workspace list print (aligned with exportable fields).
final class BillingWorkspacePrintColumn {
  const BillingWorkspacePrintColumn({
    required this.id,
    required this.label,
  });

  final String id;
  final String label;
}

abstract final class BillingWorkspacePrintStrings {
  static const String optionsSection = 'Print sections';
  static const String summarySection = 'Summary';
  static const String rowsSection = 'Rows';
  static String rowCount(int count) => '$count rows';
}

final class BillingWorkspacePrintOptionsController extends ChangeNotifier {
  BillingWorkspacePrintOptionsController({
    required List<BillingWorkspacePrintColumn> columns,
  }) : _columns = List<BillingWorkspacePrintColumn>.unmodifiable(columns) {
    _selectedColumnIds =
        columns.map((BillingWorkspacePrintColumn c) => c.id).toSet();
    _includeSummary = true;
    _includeRows = true;
  }

  final List<BillingWorkspacePrintColumn> _columns;
  late Set<String> _selectedColumnIds;
  late bool _includeSummary;
  late bool _includeRows;

  List<BillingWorkspacePrintColumn> get columns => _columns;

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
              _columns.any((BillingWorkspacePrintColumn c) => c.id == id),
        )
        .toSet();
    if (setEquals(next, _selectedColumnIds)) {
      return;
    }
    _selectedColumnIds = next;
    notifyListeners();
  }
}

/// Preview-first worklist print for Billing queue tables.
Future<void> printBillingWorkspaceList({
  required WidgetRef ref,
  required BuildContext context,
  required String title,
  required List<BillingWorkspacePrintColumn> columns,
  required List<Map<String, String>> rows,
  required String emptyText,
}) async {
  final BillingWorkspacePrintOptionsController options =
      BillingWorkspacePrintOptionsController(columns: columns);

  String buildBodyHtml() {
    return billingWorkspaceListHtml(
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
          ? BillingWorkspacePrintStrings.rowCount(rows.length)
          : null,
      recordReference: PrintFormContextReference(
        label: title,
        value: BillingWorkspacePrintStrings.rowCount(rows.length),
      ),
      bodyHtml: buildBodyHtml(),
      bodyHtmlBuilder: buildBodyHtml,
      previewSectionsExtra: BillingWorkspacePrintOptionsSection(
        controller: options,
      ),
      previewDocumentRevision: options,
      isPrintEnabled: () => options.canPrint,
    );
  } finally {
    options.dispose();
  }
}

String billingWorkspaceListHtml({
  required List<Map<String, String>> rows,
  required BillingWorkspacePrintOptionsController options,
  required String emptyText,
}) {
  final StringBuffer buffer = StringBuffer();

  if (options.includeSummary) {
    buffer.write(
      PrintFormTemplate.section(
        title: BillingWorkspacePrintStrings.summarySection,
        bodyHtml:
            '<p>${PrintFormTemplate.escape(BillingWorkspacePrintStrings.rowCount(rows.length))}</p>',
      ),
    );
  }

  if (options.includeRows) {
    final List<BillingWorkspacePrintColumn> selected = options.columns
        .where(
          (BillingWorkspacePrintColumn column) =>
              options.selectedColumnIds.contains(column.id),
        )
        .toList(growable: false);
    final List<List<String>> tableRows = <List<String>>[
      for (final Map<String, String> row in rows)
        <String>[
          for (final BillingWorkspacePrintColumn column in selected)
            row[column.id] ?? '',
        ],
    ];
    buffer.write(
      PrintFormTemplate.section(
        title: BillingWorkspacePrintStrings.rowsSection,
        bodyHtml: PrintFormTemplate.table(
          headers: <String>[
            for (final BillingWorkspacePrintColumn column in selected)
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

class BillingWorkspacePrintOptionsSection extends StatelessWidget {
  const BillingWorkspacePrintOptionsSection({
    required this.controller,
    super.key,
  });

  final BillingWorkspacePrintOptionsController controller;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, _) {
        return AppFormSection(
          title: BillingWorkspacePrintStrings.optionsSection,
          density: AppFormSectionDensity.compact,
          children: <Widget>[
            AppReportSectionPicker(
              compact: true,
              sections: const <AppReportSectionData>[
                AppReportSectionData(
                  id: 'summary',
                  title: BillingWorkspacePrintStrings.summarySection,
                  icon: Icons.summarize_outlined,
                ),
                AppReportSectionData(
                  id: 'rows',
                  title: BillingWorkspacePrintStrings.rowsSection,
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
                  for (final BillingWorkspacePrintColumn column
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
