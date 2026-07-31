import 'package:excel/excel.dart' hide Border;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/components/app_date_field.dart';
import 'package:hosspi_hms/shared/components/app_dialog.dart';
import 'package:hosspi_hms/shared/components/app_list_table.dart';
import 'package:hosspi_hms/shared/components/app_list_table_export_save.dart';
import 'package:hosspi_hms/shared/components/app_search_bar.dart';
import 'package:hosspi_hms/shared/components/app_select_field.dart';
import 'package:hosspi_hms/shared/components/app_text_field.dart';
import 'package:hosspi_hms/shared/icons/app_action_icons.dart';

/// Extracts a plain Excel cell value for [item] (string, number, bool, or date).
typedef AppListTableExportValue<T> = Object? Function(T item);

/// Optional export-dialog filter applied only to the generated file.
typedef AppListTableExportRowFilter<T> =
    bool Function(T item, AppSearchBarFilterValue filters);

/// Optional date accessor used by the export dialog From/To range.
typedef AppListTableExportDateOf<T> = DateTime? Function(T item);

/// Saves generated workbook bytes. Returns `false` when the user cancels.
typedef AppListTableExportSaver =
    Future<bool> Function({
      required Uint8List bytes,
      required String fileName,
    });

/// Caller-supplied export behavior for [AppListTable].
@immutable
final class AppListTableExportConfig<T> {
  const AppListTableExportConfig({
    this.fileNameStem = 'export',
    this.sheetName = 'Sheet1',
    this.enableDateFilter = true,
    this.filterGroups = const <AppSearchBarFilterGroup>[],
    this.textFilters = const <AppSearchBarTextFilter>[],
    this.initialFilterValue = AppSearchBarFilterValue.empty,
    this.rowFilter,
    this.dateOf,
    this.items,
    this.saver,
    this.firstDate,
    this.lastDate,
    this.currentDate,
    this.dateFilterLabel,
    this.dateFromLabel,
    this.dateToLabel,
    this.datePickerButtonLabel,
    this.invalidDateMessage,
    this.allFieldsLabel,
  });

  final String fileNameStem;
  final String sheetName;
  final bool enableDateFilter;
  final List<AppSearchBarFilterGroup> filterGroups;
  final List<AppSearchBarTextFilter> textFilters;
  final AppSearchBarFilterValue initialFilterValue;
  final AppListTableExportRowFilter<T>? rowFilter;
  final AppListTableExportDateOf<T>? dateOf;
  final List<T>? items;
  final AppListTableExportSaver? saver;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final DateTime? currentDate;
  final String? dateFilterLabel;
  final String? dateFromLabel;
  final String? dateToLabel;
  final String? datePickerButtonLabel;
  final String? invalidDateMessage;
  final String? allFieldsLabel;
}

/// Builds `.xlsx` bytes for the selected columns and rows.
Uint8List buildAppListTableExcelBytes<T>({
  required List<T> rows,
  required List<AppListTableColumn<T>> columns,
  required String sheetName,
}) {
  final Excel excel = Excel.createExcel();
  final String defaultSheet = excel.getDefaultSheet() ?? 'Sheet1';
  if (defaultSheet != sheetName) {
    excel.rename(defaultSheet, sheetName);
  }
  final Sheet sheet = excel[sheetName];

  for (int columnIndex = 0; columnIndex < columns.length; columnIndex += 1) {
    sheet
            .cell(
              CellIndex.indexByColumnRow(
                columnIndex: columnIndex,
                rowIndex: 0,
              ),
            )
            .value =
        TextCellValue(columns[columnIndex].label);
  }

  for (int rowIndex = 0; rowIndex < rows.length; rowIndex += 1) {
    final T item = rows[rowIndex];
    for (int columnIndex = 0; columnIndex < columns.length; columnIndex += 1) {
      final Object? raw = columns[columnIndex].exportValue?.call(item);
      sheet
              .cell(
                CellIndex.indexByColumnRow(
                  columnIndex: columnIndex,
                  rowIndex: rowIndex + 1,
                ),
              )
              .value =
          _excelCellValue(raw);
    }
  }

  final List<int>? encoded = excel.encode();
  if (encoded == null || encoded.isEmpty) {
    throw StateError('Failed to encode Excel workbook.');
  }
  return Uint8List.fromList(encoded);
}

CellValue _excelCellValue(Object? raw) {
  if (raw == null) {
    return TextCellValue('');
  }
  if (raw is CellValue) {
    return raw;
  }
  if (raw is bool) {
    return BoolCellValue(raw);
  }
  if (raw is int) {
    return IntCellValue(raw);
  }
  if (raw is double) {
    return DoubleCellValue(raw);
  }
  if (raw is num) {
    return DoubleCellValue(raw.toDouble());
  }
  if (raw is DateTime) {
    return DateTimeCellValue.fromDateTime(raw);
  }
  return TextCellValue(raw.toString());
}

List<T> applyAppListTableExportFilters<T>({
  required List<T> rows,
  required AppSearchBarFilterValue filters,
  AppListTableExportRowFilter<T>? rowFilter,
  AppListTableExportDateOf<T>? dateOf,
}) {
  if (!filters.isActive) {
    return List<T>.of(rows);
  }

  Iterable<T> filtered = rows;
  // Only apply date bounds when a date accessor exists. Without [dateOf],
  // dropping every row would produce empty workbooks for tables that inherit
  // live search-bar dates but have not wired export date extraction yet.
  if (dateOf != null &&
      (filters.dateFrom != null || filters.dateTo != null)) {
    final DateTime? from = filters.dateFrom == null
        ? null
        : DateUtils.dateOnly(filters.dateFrom!);
    final DateTime? to = filters.dateTo == null
        ? null
        : DateUtils.dateOnly(filters.dateTo!);
    filtered = filtered.where((T item) {
      final DateTime? raw = dateOf(item);
      if (raw == null) {
        return false;
      }
      final DateTime value = DateUtils.dateOnly(raw);
      if (from != null && value.isBefore(from)) {
        return false;
      }
      if (to != null && value.isAfter(to)) {
        return false;
      }
      return true;
    });
  }
  if (rowFilter != null) {
    filtered = filtered.where((T item) => rowFilter(item, filters));
  }
  return filtered.toList(growable: false);
}

String appListTableExportFileName(String stem) {
  final String sanitized = stem.trim().isEmpty
      ? 'export'
      : stem.trim().replaceAll(RegExp(r'[^\w\-]+'), '_');
  final DateTime now = DateTime.now();
  final String stamp =
      '${now.year.toString().padLeft(4, '0')}'
      '${now.month.toString().padLeft(2, '0')}'
      '${now.day.toString().padLeft(2, '0')}_'
      '${now.hour.toString().padLeft(2, '0')}'
      '${now.minute.toString().padLeft(2, '0')}';
  return '${sanitized}_$stamp.xlsx';
}

Future<void> showAppListTableExportDialog<T>({
  required BuildContext context,
  required List<AppListTableColumn<T>> columns,
  required Set<String> visibleColumnKeys,
  required List<T> rows,
  required AppListTableExportConfig<T> config,
  String? title,
  String? exportLabel,
  String? cancelLabel,
  String? columnsSectionLabel,
  String? filtersSectionLabel,
  String? emptyColumnsMessage,
  String? emptyRowsMessage,
  String? successMessage,
  String? failureMessage,
  String? invalidDateMessage,
}) {
  return showAppDialog<void>(
    context: context,
    builder: (_) => AppListTableExportDialog<T>(
      columns: columns,
      visibleColumnKeys: visibleColumnKeys,
      rows: rows,
      config: config,
      title: title ?? 'Export',
      exportLabel: exportLabel ?? 'Export',
      cancelLabel: cancelLabel ?? 'Cancel',
      columnsSectionLabel: columnsSectionLabel ?? 'Columns',
      filtersSectionLabel: filtersSectionLabel ?? 'Filters',
      emptyColumnsMessage:
          emptyColumnsMessage ?? 'Select at least one column to export.',
      emptyRowsMessage: emptyRowsMessage ?? 'No rows match the export filters.',
      successMessage: successMessage ?? 'Export downloaded.',
      failureMessage: failureMessage ?? 'Export failed. Try again.',
      invalidDateMessage:
          invalidDateMessage ??
          config.invalidDateMessage ??
          'From date must be on or before To date.',
    ),
  );
}

class AppListTableExportDialog<T> extends StatefulWidget {
  const AppListTableExportDialog({
    required this.columns,
    required this.visibleColumnKeys,
    required this.rows,
    required this.config,
    required this.title,
    required this.exportLabel,
    required this.cancelLabel,
    required this.columnsSectionLabel,
    required this.filtersSectionLabel,
    required this.emptyColumnsMessage,
    required this.emptyRowsMessage,
    required this.successMessage,
    required this.failureMessage,
    required this.invalidDateMessage,
    super.key,
  });

  final List<AppListTableColumn<T>> columns;
  final Set<String> visibleColumnKeys;
  final List<T> rows;
  final AppListTableExportConfig<T> config;
  final String title;
  final String exportLabel;
  final String cancelLabel;
  final String columnsSectionLabel;
  final String filtersSectionLabel;
  final String emptyColumnsMessage;
  final String emptyRowsMessage;
  final String successMessage;
  final String failureMessage;
  final String invalidDateMessage;

  @override
  State<AppListTableExportDialog<T>> createState() =>
      _AppListTableExportDialogState<T>();
}

class _AppListTableExportDialogState<T>
    extends State<AppListTableExportDialog<T>> {
  static const String _allValue = '__all__';

  late Set<String> _selectedColumnKeys;
  late DateTime? _dateFrom;
  late DateTime? _dateTo;
  late Map<String, TextEditingController> _textControllers;
  late Map<String, String> _options;
  late Map<String, Set<String>> _selections;
  String? _inlineError;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    final Set<String> availableKeys = widget.columns
        .map((AppListTableColumn<T> column) => column.key)
        .toSet();
    final Set<String> seeded = widget.visibleColumnKeys
        .where(availableKeys.contains)
        .toSet();
    _selectedColumnKeys = _withAlwaysVisible(
      seeded.isEmpty
          ? widget.columns
                .map((AppListTableColumn<T> column) => column.key)
                .toSet()
          : seeded,
    );
    final AppSearchBarFilterValue initial = widget.config.initialFilterValue;
    _dateFrom = initial.dateFrom;
    _dateTo = initial.dateTo;
    _textControllers = <String, TextEditingController>{
      for (final AppSearchBarTextFilter filter in widget.config.textFilters)
        filter.key: TextEditingController(text: initial.texts[filter.key] ?? ''),
    };
    _options = Map<String, String>.of(initial.options);
    _selections = <String, Set<String>>{
      for (final MapEntry<String, Set<String>> entry
          in initial.selections.entries)
        entry.key: Set<String>.of(entry.value),
    };
  }

  @override
  void dispose() {
    for (final TextEditingController controller in _textControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _showsFilters {
    return widget.config.enableDateFilter ||
        widget.config.filterGroups.isNotEmpty ||
        widget.config.textFilters.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool canInteract = !_isExporting;
    final DateTime firstDate =
        widget.config.firstDate ?? DateTime(DateTime.now().year - 20);
    final DateTime lastDate =
        widget.config.lastDate ?? DateTime(DateTime.now().year + 5);

    return AppDialog(
      title: Text(widget.title),
      icon: const Icon(AppActionIcons.download),
      scrollable: true,
      closeEnabled: canInteract,
      maxWidth: 760,
      content: AbsorbPointer(
        absorbing: !canInteract,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _ExportSectionHeader(
              label: widget.columnsSectionLabel,
              trailing: TextButton(
                onPressed: canInteract
                    ? () {
                        setState(() {
                          _selectedColumnKeys = _withAlwaysVisible(
                            widget.visibleColumnKeys,
                          );
                          _inlineError = null;
                        });
                      }
                    : null,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.symmetric(horizontal: theme.spacing.sm),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  context.l10n.commonTableExportSelectVisibleColumnsAction,
                ),
              ),
            ),
            SizedBox(height: theme.spacing.sm),
            _ExportColumnGrid(
              header: _ExportSelectAllColumnsTile(
                label: context.l10n.commonTableExportSelectAllColumnsAction,
                value: _selectAllColumnsValue,
                enabled: canInteract && _hasToggleableColumns,
                onChanged: _setAllColumnsSelected,
              ),
              children: <Widget>[
                for (final AppListTableColumn<T> column in widget.columns)
                  _ExportColumnTile(
                    label: column.label,
                    tooltip: _usefulTooltip(column),
                    isChecked:
                        column.alwaysVisible ||
                        _selectedColumnKeys.contains(column.key),
                    canChange: !column.alwaysVisible &&
                        (!(column.alwaysVisible ||
                                _selectedColumnKeys.contains(column.key)) ||
                            _selectedColumnKeys.length > 1),
                    onChanged: (bool? value) {
                      setState(() {
                        final Set<String> next = Set<String>.of(
                          _selectedColumnKeys,
                        );
                        if (value ?? false) {
                          next.add(column.key);
                        } else {
                          next.remove(column.key);
                        }
                        _selectedColumnKeys = _withAlwaysVisible(next);
                        _inlineError = null;
                      });
                    },
                  ),
              ],
            ),
            if (_showsFilters) ...<Widget>[
              SizedBox(height: theme.spacing.lg),
              _ExportSectionHeader(
                label: widget.filtersSectionLabel,
                trailing: TextButton(
                  onPressed: canInteract && _filters.isActive
                      ? _clearExportFilters
                      : null,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.symmetric(
                      horizontal: theme.spacing.sm,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    context.l10n.commonTableExportClearFiltersAction,
                  ),
                ),
              ),
              SizedBox(height: theme.spacing.sm),
              _ExportFilterGrid(
                children: <Widget>[
                  if (widget.config.enableDateFilter) ...<Widget>[
                    AppDateField(
                      value: _dateFrom,
                      firstDate: firstDate,
                      lastDate: lastDate,
                      currentDate: widget.config.currentDate,
                      pickerButtonLabel:
                          widget.config.datePickerButtonLabel ?? 'Pick date',
                      invalidDateMessage: widget.invalidDateMessage,
                      labelText: widget.config.dateFromLabel ?? 'From',
                      enableSpeechToText: false,
                      onChanged: (DateTime? value) {
                        setState(() {
                          _dateFrom = value;
                          _inlineError = null;
                        });
                      },
                    ),
                    AppDateField(
                      value: _dateTo,
                      firstDate: firstDate,
                      lastDate: lastDate,
                      currentDate: widget.config.currentDate,
                      pickerButtonLabel:
                          widget.config.datePickerButtonLabel ?? 'Pick date',
                      invalidDateMessage: widget.invalidDateMessage,
                      labelText: widget.config.dateToLabel ?? 'To',
                      enableSpeechToText: false,
                      onChanged: (DateTime? value) {
                        setState(() {
                          _dateTo = value;
                          _inlineError = null;
                        });
                      },
                    ),
                  ],
                  for (final AppSearchBarTextFilter filter
                      in widget.config.textFilters)
                    AppTextField(
                      controller: _textControllers[filter.key],
                      labelText: filter.label,
                      hintText: filter.hintText,
                      prefixIcon: filter.icon == null
                          ? null
                          : Icon(filter.icon),
                      keyboardType: filter.keyboardType,
                      textInputAction:
                          filter.textInputAction ?? TextInputAction.next,
                      enableSpeechToText: false,
                      onChanged: (_) {
                        if (_inlineError != null) {
                          setState(() => _inlineError = null);
                        }
                      },
                    ),
                  for (final AppSearchBarFilterGroup group
                      in widget.config.filterGroups)
                    if (group.choices.isNotEmpty && !group.allowMultiple)
                      AppSelectField<String>.searchable(
                        value: _options[group.key],
                        labelText: group.label,
                        hintText:
                            group.allLabel ??
                            widget.config.allFieldsLabel ??
                            'All',
                        enableSpeechToText: false,
                        options: <AppSelectOption<String>>[
                          AppSelectOption<String>(
                            value: _allValue,
                            label:
                                group.allLabel ??
                                widget.config.allFieldsLabel ??
                                'All',
                            leadingIcon: const Icon(Icons.filter_list_off),
                          ),
                          for (final AppSearchBarFilterChoice choice
                              in group.choices)
                            AppSelectOption<String>(
                              value: choice.value,
                              label: choice.label,
                              leadingIcon: choice.icon == null
                                  ? null
                                  : Icon(choice.icon),
                            ),
                        ],
                        onChanged: (String? value) {
                          setState(() {
                            final Map<String, String> next =
                                Map<String, String>.of(_options);
                            if (value == null || value == _allValue) {
                              next.remove(group.key);
                            } else {
                              next[group.key] = value;
                            }
                            _options = next;
                            _inlineError = null;
                          });
                        },
                      )
                    else if (group.choices.isNotEmpty && group.allowMultiple)
                      _ExportMultiSelectGroup(
                        group: group,
                        selected: _selections[group.key] ?? const <String>{},
                        onChanged: (Set<String> values) {
                          setState(() {
                            final Map<String, Set<String>> next =
                                <String, Set<String>>{
                                  for (final MapEntry<String, Set<String>> entry
                                      in _selections.entries)
                                    entry.key: Set<String>.of(entry.value),
                                };
                            if (values.isEmpty) {
                              next.remove(group.key);
                            } else {
                              next[group.key] = values;
                            }
                            _selections = next;
                            _inlineError = null;
                          });
                        },
                      ),
                ],
              ),
            ],
            if (_inlineError != null) ...<Widget>[
              SizedBox(height: theme.spacing.md),
              Text(
                _inlineError!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        AppButton.primary(
          label: widget.exportLabel,
          leadingIcon: AppActionIcons.download,
          isLoading: _isExporting,
          enabled: canInteract,
          onPressed: canInteract ? _export : null,
        ),
        AppButton.tertiary(
          label: widget.cancelLabel,
          leadingIcon: Icons.close,
          enabled: canInteract,
          onPressed: canInteract ? () => Navigator.of(context).pop() : null,
        ),
      ],
    );
  }

  String? _usefulTooltip(AppListTableColumn<T> column) {
    final String? tooltip = column.tooltip?.trim();
    if (tooltip == null || tooltip.isEmpty) {
      return null;
    }
    if (tooltip.toLowerCase() == column.label.trim().toLowerCase()) {
      return null;
    }
    return tooltip;
  }

  bool get _hasToggleableColumns {
    return widget.columns.any(
      (AppListTableColumn<T> column) => !column.alwaysVisible,
    );
  }

  bool get _allToggleableColumnsSelected {
    return widget.columns.every(
      (AppListTableColumn<T> column) =>
          column.alwaysVisible || _selectedColumnKeys.contains(column.key),
    );
  }

  bool get _anyToggleableColumnSelected {
    return widget.columns.any(
      (AppListTableColumn<T> column) =>
          !column.alwaysVisible && _selectedColumnKeys.contains(column.key),
    );
  }

  bool? get _selectAllColumnsValue {
    if (_allToggleableColumnsSelected) {
      return true;
    }
    if (!_anyToggleableColumnSelected) {
      return false;
    }
    return null;
  }

  void _setAllColumnsSelected(bool? value) {
    setState(() {
      if (value ?? false) {
        _selectedColumnKeys = widget.columns
            .map((AppListTableColumn<T> column) => column.key)
            .toSet();
      } else {
        _selectedColumnKeys = <String>{
          for (final AppListTableColumn<T> column in widget.columns)
            if (column.alwaysVisible) column.key,
        };
        if (_selectedColumnKeys.isEmpty && widget.columns.isNotEmpty) {
          _selectedColumnKeys = <String>{widget.columns.first.key};
        }
      }
      _inlineError = null;
    });
  }

  Set<String> _withAlwaysVisible(Set<String> keys) {
    return <String>{
      ...keys,
      for (final AppListTableColumn<T> column in widget.columns)
        if (column.alwaysVisible) column.key,
    };
  }

  AppSearchBarFilterValue get _filters {
    return AppSearchBarFilterValue(
      dateFrom: _dateFrom,
      dateTo: _dateTo,
      texts: <String, String>{
        for (final MapEntry<String, TextEditingController> entry
            in _textControllers.entries)
          if (entry.value.text.trim().isNotEmpty)
            entry.key: entry.value.text.trim(),
      },
      options: _options,
      selections: _selections,
    );
  }

  void _clearExportFilters() {
    setState(() {
      _dateFrom = null;
      _dateTo = null;
      for (final TextEditingController controller in _textControllers.values) {
        controller.clear();
      }
      _options = <String, String>{};
      _selections = <String, Set<String>>{};
      _inlineError = null;
    });
  }

  Future<void> _export() async {
    if (_isExporting) {
      return;
    }
    if (_selectedColumnKeys.isEmpty) {
      setState(() => _inlineError = widget.emptyColumnsMessage);
      return;
    }
    if (!appSearchBarDateRangeIsValid(_dateFrom, _dateTo)) {
      setState(() => _inlineError = widget.invalidDateMessage);
      return;
    }

    final List<AppListTableColumn<T>> selectedColumns = widget.columns
        .where(
          (AppListTableColumn<T> column) =>
              _selectedColumnKeys.contains(column.key),
        )
        .toList(growable: false);
    if (selectedColumns.isEmpty) {
      setState(() => _inlineError = widget.emptyColumnsMessage);
      return;
    }

    final List<T> sourceRows = widget.config.items ?? widget.rows;
    final List<T> filteredRows = applyAppListTableExportFilters<T>(
      rows: sourceRows,
      filters: _filters,
      rowFilter: widget.config.rowFilter,
      dateOf: widget.config.dateOf,
    );
    if (filteredRows.isEmpty) {
      setState(() => _inlineError = widget.emptyRowsMessage);
      return;
    }

    setState(() {
      _isExporting = true;
      _inlineError = null;
    });

    try {
      final Uint8List bytes = buildAppListTableExcelBytes<T>(
        rows: filteredRows,
        columns: selectedColumns,
        sheetName: widget.config.sheetName,
      );
      final String fileName = appListTableExportFileName(
        widget.config.fileNameStem,
      );
      final AppListTableExportSaver saver =
          widget.config.saver ?? appListTableSaveExportFile;
      final bool saved = await saver(bytes: bytes, fileName: fileName);
      if (!mounted) {
        return;
      }
      if (!saved) {
        setState(() => _isExporting = false);
        return;
      }
      final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(
        context,
      );
      Navigator.of(context).pop();
      messenger?.showSnackBar(SnackBar(content: Text(widget.successMessage)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isExporting = false;
        _inlineError = widget.failureMessage;
      });
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(widget.failureMessage)));
    }
  }
}

class _ExportSectionHeader extends StatelessWidget {
  const _ExportSectionHeader({required this.label, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class _ExportSelectAllColumnsTile extends StatelessWidget {
  const _ExportSelectAllColumnsTile({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final bool? value;
  final bool enabled;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Material(
      type: MaterialType.transparency,
      child: CheckboxListTile(
        tristate: true,
        value: value,
        title: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        dense: true,
        visualDensity: VisualDensity.compact,
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        onChanged: enabled ? onChanged : null,
      ),
    );
  }
}

class _ExportColumnTile extends StatelessWidget {
  const _ExportColumnTile({
    required this.label,
    required this.isChecked,
    required this.canChange,
    required this.onChanged,
    this.tooltip,
  });

  final String label;
  final String? tooltip;
  final bool isChecked;
  final bool canChange;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: CheckboxListTile(
        value: isChecked,
        title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: tooltip == null
            ? null
            : Text(tooltip!, maxLines: 2, overflow: TextOverflow.ellipsis),
        dense: true,
        visualDensity: VisualDensity.compact,
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        onChanged: canChange ? onChanged : null,
      ),
    );
  }
}

class _ExportColumnGrid extends StatelessWidget {
  const _ExportColumnGrid({required this.children, this.header});

  final Widget? header;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(theme.radius.md),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.md,
          vertical: theme.spacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (header != null) ...<Widget>[
              header!,
              Divider(
                height: theme.spacing.md,
                color: colorScheme.outlineVariant.withValues(alpha: 0.55),
              ),
            ],
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double spacing = theme.spacing.md;
                final double availableWidth = constraints.maxWidth.isFinite
                    ? constraints.maxWidth
                    : 680;
                final int columns = availableWidth >= 720
                    ? 3
                    : availableWidth >= 420
                    ? 2
                    : 1;
                final double itemWidth =
                    (availableWidth - (spacing * (columns - 1))) / columns;
                return Wrap(
                  spacing: spacing,
                  runSpacing: theme.spacing.xs,
                  children: <Widget>[
                    for (final Widget child in children)
                      SizedBox(width: itemWidth, child: child),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ExportFilterGrid extends StatelessWidget {
  const _ExportFilterGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double spacing = theme.spacing.md;
        final double availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 680;
        final bool twoColumns = availableWidth >= 560;
        final double itemWidth = twoColumns
            ? (availableWidth - spacing) / 2
            : availableWidth;
        return Wrap(
          spacing: spacing,
          runSpacing: theme.spacing.md,
          children: <Widget>[
            for (final Widget child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}

class _ExportMultiSelectGroup extends StatelessWidget {
  const _ExportMultiSelectGroup({
    required this.group,
    required this.selected,
    required this.onChanged,
  });

  final AppSearchBarFilterGroup group;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          group.label,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: theme.spacing.xs),
        Wrap(
          spacing: theme.spacing.xs,
          runSpacing: theme.spacing.xs,
          children: <Widget>[
            for (final AppSearchBarFilterChoice choice in group.choices)
              FilterChip(
                label: Text(choice.label),
                selected: selected.contains(choice.value),
                onSelected: (bool value) {
                  final Set<String> next = Set<String>.of(selected);
                  if (value) {
                    next.add(choice.value);
                  } else {
                    next.remove(choice.value);
                  }
                  onChanged(next);
                },
              ),
          ],
        ),
      ],
    );
  }
}
