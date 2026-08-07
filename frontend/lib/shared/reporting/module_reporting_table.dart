import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/reporting/module_reporting_data.dart';
import 'package:hosspi_hms/shared/reporting/module_reporting_models.dart';

/// Display unit inferred from a report column / summary key.
enum ModuleReportingMetricUnit {
  currency,
  quantity,
  percent,
  days,
  count,
  plain,
}

/// Preferred numeric keys when projecting a primary series value.
const List<String> moduleReportingPrimaryNumericKeyOrder = <String>[
  'amount',
  'collections',
  'net_collections',
  'cogs',
  'expenditures',
  'quantity_dispensed',
  'orders_created',
  'dispensed',
  'quantity',
  'value',
  'profit',
  'returns',
  'void_count',
  'remaining_quantity',
  'average_items_per_prescription',
  'item_count',
];

/// Resolves the unit for a snake_case metric key.
ModuleReportingMetricUnit moduleReportingMetricUnitForKey(String? key) {
  if (key == null) {
    return ModuleReportingMetricUnit.plain;
  }
  final String normalized = key.trim().toLowerCase();
  if (normalized.isEmpty) {
    return ModuleReportingMetricUnit.plain;
  }

  if (normalized.contains('margin') ||
      normalized.contains('percent') ||
      normalized.contains('rate') ||
      normalized.endsWith('_pct') ||
      normalized.endsWith('_pc')) {
    return ModuleReportingMetricUnit.percent;
  }

  if (normalized.startsWith('days_') ||
      normalized == 'days_to_expiry' ||
      normalized.endsWith('_days')) {
    return ModuleReportingMetricUnit.days;
  }

  if (normalized.contains('amount') ||
      normalized.contains('profit') ||
      normalized.contains('price') ||
      normalized.contains('cost') ||
      normalized.contains('cogs') ||
      normalized.contains('revenue') ||
      normalized.contains('sales') ||
      normalized.contains('collections') ||
      normalized.contains('expenditures') ||
      normalized.contains('refunds') ||
      normalized.contains('write_offs') ||
      normalized.contains('transaction_value') ||
      normalized.contains('balance') ||
      normalized == 'value' ||
      (normalized.endsWith('_total') && !normalized.contains('count'))) {
    return ModuleReportingMetricUnit.currency;
  }

  if (normalized.contains('quantity') ||
      normalized.endsWith('_qty') ||
      normalized == 'dispensed' ||
      normalized == 'returns' ||
      normalized.contains('reorder')) {
    return ModuleReportingMetricUnit.quantity;
  }

  if (normalized.contains('count') ||
      normalized == 'orders_created' ||
      normalized == 'cancelled' ||
      normalized == 'partially_dispensed' ||
      normalized == 'void_count' ||
      normalized == 'item_count') {
    return ModuleReportingMetricUnit.count;
  }

  if (normalized == 'average_items_per_prescription') {
    return ModuleReportingMetricUnit.plain;
  }

  return ModuleReportingMetricUnit.plain;
}

String? moduleReportingPrimaryNumericKeyFromColumns(List<String> columns) {
  final Set<String> available = columns
      .map((String key) => key.trim().toLowerCase())
      .where((String key) => key.isNotEmpty)
      .toSet();
  for (final String preferred in moduleReportingPrimaryNumericKeyOrder) {
    if (available.contains(preferred)) {
      return preferred;
    }
  }
  for (final String key in columns) {
    if (moduleReportingIsNumericColumn(key)) {
      return key;
    }
  }
  return null;
}

String? moduleReportingPrimaryNumericKey(Map<String, Object?> row) {
  for (final String preferred in moduleReportingPrimaryNumericKeyOrder) {
    if (row.containsKey(preferred) &&
        moduleReportingAsNum(row[preferred]) != null) {
      return preferred;
    }
  }
  for (final MapEntry<String, Object?> entry in row.entries) {
    if (moduleReportingIsNumericColumn(entry.key) &&
        moduleReportingAsNum(entry.value) != null) {
      return entry.key;
    }
  }
  return null;
}

String? moduleReportingSnapshotPrimaryMetricKey(
  ModuleReportingReportSnapshot snapshot,
) {
  final String? fromColumns = moduleReportingPrimaryNumericKeyFromColumns(
    snapshot.columns,
  );
  if (fromColumns != null) {
    return fromColumns;
  }
  if (snapshot.rows.isNotEmpty) {
    return moduleReportingPrimaryNumericKey(snapshot.rows.first);
  }
  final Map<String, Object?>? summary = snapshot.summary;
  if (summary != null && summary.isNotEmpty) {
    return moduleReportingPrimaryNumericKey(summary);
  }
  return null;
}

/// Formats a numeric metric with its inferred unit (currency, units, %, days).
String moduleReportingFormatMetricValue(
  num value, {
  required Locale locale,
  String? columnKey,
  String? currencyCode,
  bool compact = false,
}) {
  final ModuleReportingMetricUnit unit = moduleReportingMetricUnitForKey(
    columnKey,
  );
  final String code =
      (currencyCode == null || currencyCode.trim().isEmpty)
      ? appDefaultCurrencyCode
      : currencyCode.trim().toUpperCase();

  switch (unit) {
    case ModuleReportingMetricUnit.currency:
      if (compact) {
        return '${AppFormatters.compactNumber(value, locale)} $code';
      }
      return AppFormatters.currency(value, locale, currencyCode: code);
    case ModuleReportingMetricUnit.quantity:
      final String number = compact
          ? AppFormatters.compactNumber(value, locale)
          : value % 1 == 0
          ? AppFormatters.decimal(value.toInt(), locale)
          : AppFormatters.decimal(value, locale);
      return '$number units';
    case ModuleReportingMetricUnit.percent:
      if (value.abs() <= 1) {
        return AppFormatters.percent(value, locale);
      }
      final String number = compact
          ? AppFormatters.compactNumber(value, locale)
          : value % 1 == 0
          ? AppFormatters.decimal(value.toInt(), locale)
          : AppFormatters.decimal(value, locale);
      return '$number%';
    case ModuleReportingMetricUnit.days:
      final String number = compact
          ? AppFormatters.compactNumber(value, locale)
          : value % 1 == 0
          ? AppFormatters.decimal(value.toInt(), locale)
          : AppFormatters.decimal(value, locale);
      return '$number days';
    case ModuleReportingMetricUnit.count:
    case ModuleReportingMetricUnit.plain:
      if (compact) {
        return AppFormatters.compactNumber(value, locale);
      }
      if (value % 1 == 0) {
        return AppFormatters.decimal(value.toInt(), locale);
      }
      return AppFormatters.decimal(value, locale);
  }
}

/// Title-cases snake/kebab keys for table headers (`quantity_dispensed` →
/// `Quantity Dispensed`). Optionally appends a unit hint.
String moduleReportingColumnLabel(String key, {String? currencyCode}) {
  final String trimmed = key.trim();
  if (trimmed.isEmpty) {
    return trimmed;
  }
  final String base = trimmed
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

  if (!moduleReportingIsNumericColumn(trimmed)) {
    return base;
  }

  final String code =
      (currencyCode == null || currencyCode.trim().isEmpty)
      ? appDefaultCurrencyCode
      : currencyCode.trim().toUpperCase();
  return switch (moduleReportingMetricUnitForKey(trimmed)) {
    ModuleReportingMetricUnit.currency => '$base ($code)',
    ModuleReportingMetricUnit.quantity => '$base (units)',
    ModuleReportingMetricUnit.percent => '$base (%)',
    ModuleReportingMetricUnit.days => '$base (days)',
    ModuleReportingMetricUnit.count || ModuleReportingMetricUnit.plain => base,
  };
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
    'void_count',
    'remaining_quantity',
    'average_items_per_prescription',
    'item_count',
  };
  if (exact.contains(normalized)) {
    return true;
  }
  return normalized.contains('quantity') ||
      normalized.contains('amount') ||
      normalized.contains('profit') ||
      normalized.contains('price') ||
      normalized.contains('margin') ||
      normalized.contains('percent') ||
      normalized.contains('rate') ||
      normalized.contains('balance') ||
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
  String? columnKey,
  String? currencyCode,
  bool compact = false,
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
      if (columnKey != null) {
        return moduleReportingFormatMetricValue(
          number,
          locale: locale,
          columnKey: columnKey,
          currencyCode: currencyCode,
          compact: compact,
        );
      }
      if (compact) {
        return AppFormatters.compactNumber(number, locale);
      }
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
  String? currencyCode,
}) {
  return <AppListTableColumn<Map<String, Object?>>>[
    for (final String key in columnKeys)
      AppListTableColumn<Map<String, Object?>>(
        id: key,
        label: moduleReportingColumnLabel(key, currencyCode: currencyCode),
        numeric: moduleReportingIsNumericColumn(key),
        preferredWidth: moduleReportingIsNumericColumn(key)
            ? 148
            : moduleReportingIsDateColumn(key)
            ? 148
            : 200,
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
        exportValue: (Map<String, Object?> row) {
          final Object? raw = row[key];
          if (moduleReportingIsNumericColumn(key)) {
            return moduleReportingAsNum(raw) ?? '';
          }
          return moduleReportingFormatCellValue(
            raw,
            locale: locale,
            unknownLabel: unknownLabel,
            preferDate: moduleReportingIsDateColumn(key),
            columnKey: key,
            currencyCode: currencyCode,
          );
        },
        cellBuilder: (BuildContext context, Map<String, Object?> row) {
          final bool numeric = moduleReportingIsNumericColumn(key);
          final bool isDate = moduleReportingIsDateColumn(key);
          final String formatted = moduleReportingFormatCellValue(
            row[key],
            locale: locale,
            unknownLabel: unknownLabel,
            preferNumeric: numeric,
            preferDate: isDate,
            columnKey: key,
            currencyCode: currencyCode,
          );
          final ThemeData theme = Theme.of(context);
          final TextStyle? style = theme.textTheme.bodyMedium?.copyWith(
            fontFeatures: numeric
                ? const <FontFeature>[FontFeature.tabularFigures()]
                : null,
            color: row[key] == null
                ? theme.colorScheme.onSurfaceVariant
                : null,
          );
          final Widget text = Text(
            formatted,
            style: style,
            textAlign: numeric ? TextAlign.right : TextAlign.start,
          );
          if (numeric) {
            return Align(alignment: Alignment.centerRight, child: text);
          }
          return Align(alignment: Alignment.centerLeft, child: text);
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
  String? currencyCode,
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
      columnKey: key,
      currencyCode: currencyCode,
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
    this.canExport = true,
    this.storageKeyPrefix,
    this.exportFileNameStem,
    this.currencyCode,
    super.key,
  });

  final ModuleReportingReportSnapshot snapshot;
  final ModuleReportingLabels labels;

  /// When true (default), shows the Excel export action on the table toolbar.
  final bool canExport;
  final String? storageKeyPrefix;
  final String? exportFileNameStem;
  final String? currencyCode;

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

    final ModuleReportingLabels labels = widget.labels;
    final Locale locale = Localizations.localeOf(context);
    final String unknownLabel = labels.unknownValue;
    final List<String> columnKeys = snapshot.columns;
    final List<Map<String, Object?>> rows = snapshot.rows;
    final String? currencyCode = widget.currencyCode;
    final List<AppListTableColumn<Map<String, Object?>>> columns =
        moduleReportingTableColumns(
          columnKeys: columnKeys,
          locale: locale,
          unknownLabel: unknownLabel,
          currencyCode: currencyCode,
        );
    final String? storagePrefix = widget.storageKeyPrefix;
    final String fileStem =
        (widget.exportFileNameStem ?? storagePrefix ?? 'report')
            .trim()
            .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')
            .toLowerCase();

    return AppListTable<Map<String, Object?>>(
      items: rows,
      columns: columns,
      columnChoices: columns,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      forceCompact: true,
      enableExport: true,
      canExport: widget.canExport,
      exportConfig: AppListTableExportConfig<Map<String, Object?>>(
        fileNameStem: fileStem.isEmpty ? 'report' : fileStem,
        sheetName: labels.exportSheetName,
        enableDateFilter: false,
      ),
      exportLabel: labels.exportAction,
      exportDialogTitle: labels.exportDialogTitle,
      exportCancelLabel: labels.cancelAction,
      exportColumnsSectionLabel: labels.exportColumnsSectionLabel,
      exportFiltersSectionLabel: labels.exportFiltersSectionLabel,
      exportEmptyColumnsMessage: labels.exportEmptyColumnsMessage,
      exportEmptyRowsMessage: labels.exportEmptyRowsMessage,
      exportSuccessMessage: labels.exportSuccessMessage,
      exportFailureMessage: labels.exportFailureMessage,
      showRowNumbers: true,
      padEmptyRows: false,
      displayMode: AppListTableDisplayMode.table,
      tableHorizontalMargin: 0,
      columnVisibilityLabel: labels.exportColumnsSectionLabel,
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
        semanticLabel: labels.searchSemanticLabel,
        hintText: labels.searchHint,
        clearLabel: labels.clearSearchLabel,
        matcher: (Map<String, Object?> row, String query) =>
            moduleReportingRowMatchesQuery(
              row,
              columnKeys,
              query,
              locale: locale,
              unknownLabel: unknownLabel,
              currencyCode: currencyCode,
            ),
      ),
      emptyBuilder: (_) => AppMutedText(labels.emptyBody),
      mobileItemBuilder: (BuildContext context, Map<String, Object?> row) {
        final String titleKey = columnKeys.first;
        final String title = moduleReportingFormatCellValue(
          row[titleKey],
          locale: locale,
          unknownLabel: unknownLabel,
          preferNumeric: moduleReportingIsNumericColumn(titleKey),
          preferDate: moduleReportingIsDateColumn(titleKey),
          columnKey: titleKey,
          currencyCode: currencyCode,
        );
        final List<AppListTableMobileMeta> meta = <AppListTableMobileMeta>[];
        for (final String key in columnKeys.skip(1).take(3)) {
          meta.add(
            AppListTableMobileMeta(
              label:
                  '${moduleReportingColumnLabel(key, currencyCode: currencyCode)}: '
                  '${moduleReportingFormatCellValue(row[key], locale: locale, unknownLabel: unknownLabel, preferNumeric: moduleReportingIsNumericColumn(key), preferDate: moduleReportingIsDateColumn(key), columnKey: key, currencyCode: currencyCode)}',
            ),
          );
        }
        return AppListTableMobileItem(title: title, meta: meta);
      },
    );
  }
}
