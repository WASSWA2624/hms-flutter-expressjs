import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/shared/components/app_list_table.dart';
import 'package:hosspi_hms/shared/dashboard/dashboard_models.dart';
import 'package:hosspi_hms/shared/printing/print_form_template.dart';
import 'package:hosspi_hms/shared/reporting/module_reporting_data.dart';
import 'package:hosspi_hms/shared/reporting/module_reporting_models.dart';
import 'package:hosspi_hms/shared/reporting/module_reporting_table.dart';
import 'package:hosspi_hms/shared/reporting/module_reporting_visualization.dart';

/// Logical page size used by the interactive report print canvas.
const Size moduleReportingPrintPageSize = Size(720, 960);

/// One movable presentation block on the print canvas.
@immutable
final class ModuleReportingPrintBlock {
  const ModuleReportingPrintBlock({
    required this.id,
    required this.kind,
    required this.title,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    this.visible = true,
    this.caption = '',
    this.visibleColumns = const <String>[],
    this.maxRows = 25,
    this.sortColumnKey,
    this.sortAscending = true,
  });

  final String id;
  final ModuleReportingVisualizationKind kind;
  final String title;
  final String caption;
  final bool visible;
  final double left;
  final double top;
  final double width;
  final double height;
  final List<String> visibleColumns;
  final int maxRows;
  final String? sortColumnKey;
  final bool sortAscending;

  Rect get bounds => Rect.fromLTWH(left, top, width, height);

  ModuleReportingPrintBlock copyWith({
    String? title,
    String? caption,
    bool? visible,
    double? left,
    double? top,
    double? width,
    double? height,
    List<String>? visibleColumns,
    int? maxRows,
    String? sortColumnKey,
    bool clearSortColumnKey = false,
    bool? sortAscending,
  }) {
    return ModuleReportingPrintBlock(
      id: id,
      kind: kind,
      title: title ?? this.title,
      caption: caption ?? this.caption,
      visible: visible ?? this.visible,
      left: left ?? this.left,
      top: top ?? this.top,
      width: width ?? this.width,
      height: height ?? this.height,
      visibleColumns: visibleColumns ?? this.visibleColumns,
      maxRows: maxRows ?? this.maxRows,
      sortColumnKey: clearSortColumnKey
          ? null
          : (sortColumnKey ?? this.sortColumnKey),
      sortAscending: sortAscending ?? this.sortAscending,
    );
  }
}

List<ModuleReportingPrintBlock> moduleReportingDefaultPrintBlocks({
  required ModuleReportingReport report,
  required ModuleReportingReportSnapshot snapshot,
}) {
  final List<ModuleReportingVisualizationKind> applicable =
      moduleReportingApplicableVisualizations(snapshot);
  if (applicable.isEmpty) {
    return const <ModuleReportingPrintBlock>[];
  }

  final List<String> columns = snapshot.columns;
  final List<ModuleReportingPrintBlock> blocks = <ModuleReportingPrintBlock>[];
  double cursorY = 16;
  for (int index = 0; index < applicable.length; index += 1) {
    final ModuleReportingVisualizationKind kind = applicable[index];
    final bool isTable = kind == ModuleReportingVisualizationKind.table;
    final double height = isTable
        ? 280
        : kind == ModuleReportingVisualizationKind.kpiCards
        ? 140
        : 220;
    final double width = kind == ModuleReportingVisualizationKind.kpiCards ||
            kind == ModuleReportingVisualizationKind.table
        ? moduleReportingPrintPageSize.width - 32
        : (moduleReportingPrintPageSize.width - 48) / 2;
    final double left = kind == ModuleReportingVisualizationKind.donutChart ||
            kind == ModuleReportingVisualizationKind.rankingChart ||
            kind == ModuleReportingVisualizationKind.gaugeChart
        ? (index.isOdd ? width + 32 : 16)
        : 16;
    blocks.add(
      ModuleReportingPrintBlock(
        id: '${kind.name}_$index',
        kind: kind,
        title: kind == ModuleReportingVisualizationKind.table
            ? report.label
            : moduleReportingVisualizationLabel(kind),
        left: left.clamp(16, moduleReportingPrintPageSize.width - width - 16),
        top: cursorY,
        width: width,
        height: height,
        visibleColumns: columns,
        maxRows: 25,
      ),
    );
    if (left <= 16 ||
        kind == ModuleReportingVisualizationKind.table ||
        kind == ModuleReportingVisualizationKind.kpiCards ||
        index.isOdd ||
        index == applicable.length - 1) {
      cursorY += height + 16;
    }
  }
  return blocks;
}

List<Map<String, Object?>> moduleReportingPrintTableRows({
  required ModuleReportingReportSnapshot snapshot,
  required ModuleReportingPrintBlock block,
}) {
  List<Map<String, Object?>> rows = List<Map<String, Object?>>.from(snapshot.rows);
  final String? sortKey = block.sortColumnKey;
  if (sortKey != null && sortKey.isNotEmpty) {
    rows.sort((Map<String, Object?> left, Map<String, Object?> right) {
      final int compared = moduleReportingIsNumericColumn(sortKey)
          ? appListTableCompareNumber(
              moduleReportingAsNum(left[sortKey]),
              moduleReportingAsNum(right[sortKey]),
            )
          : appListTableCompareText(
              left[sortKey]?.toString(),
              right[sortKey]?.toString(),
            );
      return block.sortAscending ? compared : -compared;
    });
  }
  if (rows.length > block.maxRows) {
    rows = rows.take(block.maxRows).toList(growable: false);
  }
  return rows;
}

String moduleReportingPrintLayoutBodyHtml({
  required ModuleReportingLabels labels,
  required ModuleReportingReport report,
  required ModuleReportingReportSnapshot snapshot,
  required List<ModuleReportingPrintBlock> blocks,
  required String periodLabel,
  required DateTime? from,
  required DateTime? to,
  required Locale locale,
}) {
  final List<ModuleReportingPrintBlock> visible = blocks
      .where((ModuleReportingPrintBlock block) => block.visible)
      .toList(growable: true)
    ..sort((ModuleReportingPrintBlock left, ModuleReportingPrintBlock right) {
      final int byTop = left.top.compareTo(right.top);
      if (byTop != 0) {
        return byTop;
      }
      return left.left.compareTo(right.left);
    });

  final String fromLabel = from == null
      ? labels.unknownValue
      : AppFormatters.mediumDate(from, locale);
  final String toLabel = to == null
      ? labels.unknownValue
      : AppFormatters.mediumDate(to, locale);

  final StringBuffer body = StringBuffer()
    ..write(
      PrintFormTemplate.section(
        title: labels.previewTitle,
        bodyHtml: PrintFormTemplate.keyValueGrid(<PrintFormMetadataItem>[
          PrintFormMetadataItem(
            label: labels.nameColumnLabel,
            value: report.label,
          ),
          PrintFormMetadataItem(
            label: labels.periodLabel,
            value: periodLabel,
          ),
          PrintFormMetadataItem(label: labels.dateFromLabel, value: fromLabel),
          PrintFormMetadataItem(label: labels.dateToLabel, value: toLabel),
        ]),
      ),
    );

  for (final ModuleReportingPrintBlock block in visible) {
    body.write(
      PrintFormTemplate.section(
        title: block.title,
        bodyHtml: _blockHtml(
          block: block,
          snapshot: snapshot,
          labels: labels,
          locale: locale,
        ),
      ),
    );
  }
  return body.toString();
}

String _blockHtml({
  required ModuleReportingPrintBlock block,
  required ModuleReportingReportSnapshot snapshot,
  required ModuleReportingLabels labels,
  required Locale locale,
}) {
  final StringBuffer html = StringBuffer();
  if (block.caption.trim().isNotEmpty) {
    html.writeln('<p><em>${_escape(block.caption.trim())}</em></p>');
  }

  switch (block.kind) {
    case ModuleReportingVisualizationKind.table:
      final List<String> columns = block.visibleColumns.isEmpty
          ? snapshot.columns
          : block.visibleColumns;
      final List<Map<String, Object?>> rows = moduleReportingPrintTableRows(
        snapshot: snapshot,
        block: block,
      );
      html.write(
        PrintFormTemplate.table(
          headers: columns.map(moduleReportingColumnLabel).toList(),
          emptyText: labels.emptyBody,
          rows: <List<String>>[
            for (final Map<String, Object?> row in rows)
              <String>[
                for (final String column in columns)
                  moduleReportingFormatCellValue(
                    row[column],
                    locale: locale,
                    unknownLabel: labels.unknownValue,
                    preferNumeric: moduleReportingIsNumericColumn(column),
                    preferDate: moduleReportingIsDateColumn(column),
                  ),
              ],
          ],
        ),
      );
      break;
    case ModuleReportingVisualizationKind.kpiCards:
      final List<DashboardMetricCardData> cards =
          moduleReportingKpiCards(snapshot);
      html.write(
        PrintFormTemplate.keyValueGrid(<PrintFormMetadataItem>[
          for (final DashboardMetricCardData card in cards)
            PrintFormMetadataItem(label: card.label, value: card.value),
        ]),
      );
      break;
    case ModuleReportingVisualizationKind.lineChart:
    case ModuleReportingVisualizationKind.barChart:
    case ModuleReportingVisualizationKind.areaChart:
    case ModuleReportingVisualizationKind.rankingChart:
    case ModuleReportingVisualizationKind.gaugeChart:
    case ModuleReportingVisualizationKind.donutChart:
    case ModuleReportingVisualizationKind.scatterChart:
    case ModuleReportingVisualizationKind.heatmap:
      final points = moduleReportingSeriesPoints(snapshot, limit: block.maxRows);
      final segments = moduleReportingDistributionSegments(
        snapshot,
        limit: block.maxRows,
      );
      final List<PrintFormMetadataItem> items = <PrintFormMetadataItem>[
        for (final point in points.take(block.maxRows))
          PrintFormMetadataItem(
            label: point.label,
            value: moduleReportingFormatCellValue(
              point.value,
              locale: locale,
              unknownLabel: labels.unknownValue,
              preferNumeric: true,
            ),
          ),
      ];
      if (items.isEmpty) {
        for (final segment in segments.take(block.maxRows)) {
          items.add(
            PrintFormMetadataItem(
              label: segment.label,
              value: moduleReportingFormatCellValue(
                segment.value,
                locale: locale,
                unknownLabel: labels.unknownValue,
                preferNumeric: true,
              ),
            ),
          );
        }
      }
      html
        ..writeln(
          '<p>${_escape(moduleReportingVisualizationLabel(block.kind))}</p>',
        )
        ..write(PrintFormTemplate.keyValueGrid(items));
      break;
  }
  return html.toString();
}

String _escape(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
