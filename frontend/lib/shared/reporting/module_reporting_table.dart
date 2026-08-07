import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/reporting/module_reporting_data.dart';
import 'package:hosspi_hms/shared/reporting/module_reporting_models.dart';

/// Title-cases snake/kebab keys for table headers (`quantity_dispensed` →
/// `Quantity Dispensed`).
String moduleReportingColumnLabel(String key) {
  final String trimmed = key.trim();
  if (trimmed.isEmpty) {
    return trimmed;
  }
  return trimmed
      .replaceAll(RegExp(r'[_\-]+'), ' ')
      .split(RegExp(r'\s+'))
      .where((String part) => part.isNotEmpty)
      .map((String part) {
        if (part.length == 1) {
          return part.toUpperCase();
        }
        return '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}';
      })
      .join(' ');
}

bool moduleReportingIsNumericColumn(String key) {
  final String normalized = key.trim().toLowerCase();
  if (normalized.isEmpty) {
    return false;
  }
  const Set<String> exact = <String>{
    'amount',
    'profit',
    'quantity',
    'value',
    'count',
    'dispensed',
    'cancelled',
    'returns',
    'reorder_level',
    'days_to_expiry',
    'orders_created',
    'partially_dispensed',
    'quantity_dispensed',
  };
  if (exact.contains(normalized)) {
    return true;
  }
  return normalized.contains('quantity') ||
      normalized.contains('amount') ||
      normalized.contains('profit') ||
      normalized.contains('price') ||
      normalized.contains('value') ||
      normalized.contains('count') ||
      normalized.startsWith('days_') ||
      normalized.endsWith('_qty') ||
      normalized.endsWith('_total');
}

bool moduleReportingIsDateColumn(String key) {
  final String normalized = key.trim().toLowerCase();
  return normalized == 'date' ||
      normalized == 'period' ||
      normalized.endsWith('_date') ||
      normalized.endsWith('_at') ||
      normalized.contains('expiry_date');
}

num? moduleReportingAsNum(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value;
  }
  if (value is String) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return num.tryParse(trimmed.replaceAll(',', ''));
  }
  return num.tryParse(value.toString());
}

DateTime? moduleReportingAsDate(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return DateTime.tryParse(trimmed);
  }
  return null;
}

/// Formats a cell for display in [ModuleReportingSnapshotTable].
String moduleReportingFormatCellValue(
  Object? value, {
  required Locale locale,
  required String unknownLabel,
  bool preferNumeric = false,
  bool preferDate = false,
}) {
  if (value == null) {
    return unknownLabel;
  }
  if (value is bool) {
    return value ? 'Yes' : 'No';
  }

  if (preferDate || value is DateTime) {
    final DateTime? parsed = moduleReportingAsDate(value);
    if (parsed != null) {
      if (parsed.hour == 0 &&
          parsed.minute == 0 &&
          parsed.second == 0 &&
          parsed.millisecond == 0) {
        return AppFormatters.mediumDate(parsed, locale);
      }
      return AppFormatters.dateTime(parsed, locale);
    }
  }

  if (preferNumeric || value is num) {
    final num? number = moduleReportingAsNum(value);
    if (number != null) {
      if (number % 1 == 0) {
        return AppFormatters.decimal(number.toInt(), locale);
      }
      return AppFormatters.decimal(number, locale);
    }
  }

  final String text = value.toString().trim();
  if (text.isEmpty) {
    return unknownLabel;
  }

  // SCREAMING_SNAKE enum-like tokens → readable labels.
  if (RegExp(r'^[A-Z0-9]+(?:_[A-Z0-9]+)+$').hasMatch(text)) {
    return moduleReportingColumnLabel(text);
  }
  return text;
}

List<AppListTableColumn<Map<String, Object?>>> moduleReportingTableColumns({
  required List<String> columnKeys,
  required Locale locale,
  required String unknownLabel,
}) {
  return <AppListTableColumn<Map<String, Object?>>>[
    for (final String key in columnKeys)
      AppListTableColumn<Map<String, Object?>>(
        id: key,
        label: moduleReportingColumnLabel(key),
        numeric: moduleReportingIsNumericColumn(key),
        preferredWidth: moduleReportingIsNumericColumn(key)
            ? 120
            : moduleReportingIsDateColumn(key)
            ? 140
            : 180,
        sortComparator: moduleReportingIsNumericColumn(key)
            ? (Map<String, Object?> left, Map<String, Object?> right) =>
                  appListTableCompareNumber(
                    moduleReportingAsNum(left[key]),
                    moduleReportingAsNum(right[key]),
                  )
            : moduleReportingIsDateColumn(key)
            ? (Map<String, Object?> left, Map<String, Object?> right) =>
                  appListTableCompareDateTime(
                    moduleReportingAsDate(left[key]),
                    moduleReportingAsDate(right[key]),
                  )
            : (Map<String, Object?> left, Map<String, Object?> right) =>
                  appListTableCompareText(
                    left[key]?.toString(),
                    right[key]?.toString(),
                  ),
        exportValue: (Map<String, Object?> row) => row[key],
        cellBuilder: (BuildContext context, Map<String, Object?> row) {
          final String formatted = moduleReportingFormatCellValue(
            row[key],
            locale: locale,
            unknownLabel: unknownLabel,
            preferNumeric: moduleReportingIsNumericColumn(key),
            preferDate: moduleReportingIsDateColumn(key),
          );
          final TextStyle? style = Theme.of(context).textTheme.bodyMedium;
          if (moduleReportingIsNumericColumn(key)) {
            return Text(
              formatted,
              style: style,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            );
          }
          return Text(
            formatted,
            style: style,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          );
        },
      ),
  ];
}

bool moduleReportingRowMatchesQuery(
  Map<String, Object?> row,
  List<String> columnKeys,
  String query, {
  required Locale locale,
  required String unknownLabel,
}) {
  final String normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) {
    return true;
  }
  for (final String key in columnKeys) {
    final String haystack = moduleReportingFormatCellValue(
      row[key],
      locale: locale,
      unknownLabel: unknownLabel,
      preferNumeric: moduleReportingIsNumericColumn(key),
      preferDate: moduleReportingIsDateColumn(key),
    ).toLowerCase();
    if (haystack.contains(normalized)) {
      return true;
    }
    final Object? raw = row[key];
    if (raw != null && raw.toString().toLowerCase().contains(normalized)) {
      return true;
    }
  }
  return false;
}

/// [AppListTable] body for a module reporting snapshot.
class ModuleReportingSnapshotTable extends StatefulWidget {
  const ModuleReportingSnapshotTable({
    required this.snapshot,
    required this.labels,
    this.storageKeyPrefix,
    super.key,
  });

  final ModuleReportingReportSnapshot snapshot;
  final ModuleReportingLabels labels;
  final String? storageKeyPrefix;

  @override
  State<ModuleReportingSnapshotTable> createState() =>
      _ModuleReportingSnapshotTableState();
}

class _ModuleReportingSnapshotTableState
    extends State<ModuleReportingSnapshotTable> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ModuleReportingReportSnapshot snapshot = widget.snapshot;
    if (!snapshot.hasRows || snapshot.columns.isEmpty) {
      return const SizedBox.shrink();
    }

    final Locale locale = Localizations.localeOf(context);
    final String unknownLabel = widget.labels.unknownValue;
    final List<String> columnKeys = snapshot.columns;
    final List<Map<String, Object?>> rows = snapshot.rows;
    final List<AppListTableColumn<Map<String, Object?>>> columns =
        moduleReportingTableColumns(
          columnKeys: columnKeys,
          locale: locale,
          unknownLabel: unknownLabel,
        );
    final String? storagePrefix = widget.storageKeyPrefix;

    return AppListTable<Map<String, Object?>>(
      items: rows,
      columns: columns,
      columnChoices: columns,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      forceCompact: true,
      enableExport: false,
      showRowNumbers: true,
      padEmptyRows: false,
      displayMode: AppListTableDisplayMode.table,
      tableHorizontalMargin: 0,
      columnVisibilityLabel: widget.labels.exportColumnsSectionLabel,
      columnVisibilityStorageKey: storagePrefix == null
          ? null
          : 'module-reporting-table:$storagePrefix:columns',
      columnWidthStorageKey: storagePrefix == null
          ? null
          : 'module-reporting-table:$storagePrefix:widths',
      itemKeyBuilder: (Map<String, Object?> row) =>
          ValueKey<int>(identityHashCode(row)),
      rowsVersion: Object.hash(
        columnKeys.join('|'),
        rows.length,
        rows.isEmpty ? 0 : identityHashCode(rows.first),
      ),
      search: AppListTableSearch<Map<String, Object?>>(
        controller: _searchController,
        semanticLabel: widget.labels.searchSemanticLabel,
        hintText: widget.labels.searchHint,
        clearLabel: widget.labels.clearSearchLabel,
        matcher: (Map<String, Object?> row, String query) =>
            moduleReportingRowMatchesQuery(
              row,
              columnKeys,
              query,
              locale: locale,
              unknownLabel: unknownLabel,
            ),
      ),
      emptyBuilder: (_) => AppMutedText(widget.labels.emptyBody),
      mobileItemBuilder: (BuildContext context, Map<String, Object?> row) {
        final String titleKey = columnKeys.first;
        final String title = moduleReportingFormatCellValue(
          row[titleKey],
          locale: locale,
          unknownLabel: unknownLabel,
          preferNumeric: moduleReportingIsNumericColumn(titleKey),
          preferDate: moduleReportingIsDateColumn(titleKey),
        );
        final List<AppListTableMobileMeta> meta = <AppListTableMobileMeta>[];
        for (final String key in columnKeys.skip(1).take(3)) {
          meta.add(
            AppListTableMobileMeta(
              label:
                  '${moduleReportingColumnLabel(key)}: '
                  '${moduleReportingFormatCellValue(row[key], locale: locale, unknownLabel: unknownLabel, preferNumeric: moduleReportingIsNumericColumn(key), preferDate: moduleReportingIsDateColumn(key))}',
            ),
          );
        }
        return AppListTableMobileItem(title: title, meta: meta);
      },
    );
  }
}
