import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/components/app_dialog.dart';
import 'package:hosspi_hms/shared/components/app_list_table_column_visibility_memory.dart';
import 'package:hosspi_hms/shared/components/app_search_bar.dart';
import 'package:hosspi_hms/shared/data/data.dart';

typedef AppListTableCellBuilder<T> =
    Widget Function(BuildContext context, T item);
typedef AppListTableHeaderBuilder<T> = Widget Function(BuildContext context);
typedef AppListTableMobileItemBuilder<T> =
    Widget Function(BuildContext context, T item);
typedef AppListTableItemKeyBuilder<T> = LocalKey Function(T item);
typedef AppListTablePageLabelBuilder<T> = String Function(AppPage<T> page);
typedef AppListTableRowColorBuilder<T> =
    Color? Function(BuildContext context, T item);
typedef AppListTableSearchMatcher<T> = bool Function(T item, String query);
typedef AppListTableSortComparator<T> = int Function(T left, T right);

enum AppListTableDisplayMode { adaptive, table, list }

const int _maxVisibleTableColumns = 5;
const double _rowNumberColumnWidth = 48;

LocalKey appListTableUniqueRowKey<T>({
  required int index,
  required AppListTableItemKeyBuilder<T>? itemKeyBuilder,
  required T item,
}) {
  final LocalKey? baseKey = itemKeyBuilder?.call(item);
  if (baseKey is ValueKey<Object?>) {
    return ValueKey<Object>(Object.hash(index, baseKey.value));
  }
  if (baseKey != null) {
    return ValueKey<Object>(Object.hash(index, baseKey));
  }
  return ValueKey<int>(index);
}

List<AppListTableColumn<T>> _availableColumnsFor<T>(
  List<AppListTableColumn<T>> columns,
  List<AppListTableColumn<T>>? columnChoices,
) {
  final List<AppListTableColumn<T>> availableColumns =
      <AppListTableColumn<T>>[];
  final Set<String> keys = <String>{};

  void addColumns(Iterable<AppListTableColumn<T>> source) {
    for (final AppListTableColumn<T> column in source) {
      if (keys.add(column.key)) {
        availableColumns.add(column);
      }
    }
  }

  addColumns(columns);
  addColumns(columnChoices ?? <AppListTableColumn<T>>[]);
  return availableColumns;
}

List<AppListTableColumn<T>> appListTableDefaultVisibleColumns<T>(
  List<AppListTableColumn<T>> availableColumns, {
  List<AppListTableColumn<T>>? defaultColumns,
}) {
  if (availableColumns.isEmpty) {
    return <AppListTableColumn<T>>[];
  }

  final List<AppListTableColumn<T>>? configuredDefault = defaultColumns;
  final List<AppListTableColumn<T>> defaultSource =
      configuredDefault == null || configuredDefault.isEmpty
      ? availableColumns
      : configuredDefault;
  final List<AppListTableColumn<T>> visible = defaultSource
      .take(math.min(defaultSource.length, _maxVisibleTableColumns))
      .toList(growable: true);
  final Set<String> visibleKeys = visible
      .map((AppListTableColumn<T> column) => column.key)
      .toSet();
  for (final AppListTableColumn<T> column in availableColumns) {
    if (column.alwaysVisible && visibleKeys.add(column.key)) {
      visible.add(column);
    }
  }
  return visible;
}

int appListTableCompareText(String? left, String? right) {
  return (left ?? '').trim().toLowerCase().compareTo(
    (right ?? '').trim().toLowerCase(),
  );
}

int appListTableCompareDateTime(DateTime? left, DateTime? right) {
  if (left == null && right == null) {
    return 0;
  }
  if (left == null) {
    return 1;
  }
  if (right == null) {
    return -1;
  }
  return left.compareTo(right);
}

int appListTableCompareNumber(num? left, num? right) {
  if (left == null && right == null) {
    return 0;
  }
  if (left == null) {
    return 1;
  }
  if (right == null) {
    return -1;
  }
  return left.compareTo(right);
}

String appListTableColumnVisibilityStorageKey<T>(
  List<AppListTableColumn<T>> columns,
  List<AppListTableColumn<T>>? columnChoices,
) {
  final Set<String> schemaKeys = <String>{};
  for (final AppListTableColumn<T> column in columns) {
    schemaKeys.add(column.key);
  }
  for (final AppListTableColumn<T> column
      in columnChoices ?? <AppListTableColumn<T>>[]) {
    schemaKeys.add(column.key);
  }

  final List<String> sortedKeys = schemaKeys.toList(growable: false)..sort();
  return sortedKeys.join('\u0001');
}

/// Whether [AppListTable.isLoading] should replace the table body with a skeleton.
///
/// Keeps already-fetched rows visible during background refresh; only the initial
/// empty load shows the full-table loading state.
bool appListTableShowsInitialLoading({
  required bool isLoading,
  required List<dynamic> visibleItems,
}) {
  return isLoading && visibleItems.isEmpty;
}

class AppListTableColumnVisibilityController<T> extends ChangeNotifier {
  AppListTableColumnVisibilityController({this.storageKey});

  final String? storageKey;

  List<AppListTableColumn<T>> _availableColumns = <AppListTableColumn<T>>[];
  Set<String> _visibleColumnKeys = <String>{};

  void syncColumns({
    required List<AppListTableColumn<T>> columns,
    List<AppListTableColumn<T>>? columnChoices,
    String? storageKey,
  }) {
    final List<AppListTableColumn<T>> nextColumns = _availableColumnsFor(
      columns,
      columnChoices,
    );
    final List<String> currentKeys = _availableColumns
        .map((AppListTableColumn<T> column) => column.key)
        .toList(growable: false);
    final List<String> nextKeys = nextColumns
        .map((AppListTableColumn<T> column) => column.key)
        .toList(growable: false);

    if (listEquals(currentKeys, nextKeys)) {
      return;
    }

    _availableColumns = nextColumns;
    _visibleColumnKeys = _resolveVisibleColumnKeys(
      columns: columns,
      availableColumns: nextColumns,
      storageKey: storageKey,
    );
    notifyListeners();
  }

  List<AppListTableColumn<T>> get visibleColumns {
    final List<AppListTableColumn<T>> columns = _availableColumns
        .where(
          (AppListTableColumn<T> column) =>
              column.alwaysVisible || _visibleColumnKeys.contains(column.key),
        )
        .toList(growable: false);
    if (columns.isNotEmpty || _availableColumns.isEmpty) {
      return columns;
    }
    return appListTableDefaultVisibleColumns(_availableColumns);
  }

  bool get canConfigure => _availableColumns.length > 1;

  bool get hasCustomColumnVisibility {
    return !setEquals(_visibleColumnKeys, _defaultColumnKeys);
  }

  bool isColumnVisible(String key) {
    final AppListTableColumn<T>? column = _columnByKey(key);
    if (column?.alwaysVisible ?? false) {
      return true;
    }
    return _visibleColumnKeys.contains(key);
  }

  AppSearchBarAction settingsAction(
    BuildContext context, {
    String? label,
    String? title,
    String? applyLabel,
    String? resetLabel,
  }) {
    final String resolvedLabel = label ?? 'Table column settings';
    return AppSearchBarAction(
      icon: Icons.settings_outlined,
      label: resolvedLabel,
      tooltip: resolvedLabel,
      active: hasCustomColumnVisibility,
      onPressed: () {
        openColumnVisibilityDialog(
          context,
          title: title,
          applyLabel: applyLabel,
          resetLabel: resetLabel,
        );
      },
    );
  }

  Future<void> openColumnVisibilityDialog(
    BuildContext context, {
    String? title,
    String? applyLabel,
    String? resetLabel,
    String? storageKey,
  }) async {
    if (!canConfigure) {
      return;
    }

    final Set<String>? value = await showAppDialog<Set<String>>(
      context: context,
      builder: (_) => _ColumnVisibilityDialog<T>(
        columns: _availableColumns,
        visibleColumnKeys: _visibleColumnKeys,
        defaultColumnKeys: _defaultColumnKeys,
        title: title ?? 'Table columns',
        applyLabel: applyLabel ?? 'Apply columns',
        resetLabel: resetLabel ?? 'Reset columns',
      ),
    );
    if (value == null) {
      return;
    }

    _visibleColumnKeys = _withAlwaysVisibleColumnKeys(value);
    _persistVisibleColumnKeys(storageKey);
    notifyListeners();
  }

  Set<String> get _defaultColumnKeys {
    return appListTableDefaultVisibleColumns(
      _availableColumns,
    ).map((AppListTableColumn<T> column) => column.key).toSet();
  }

  AppListTableColumn<T>? _columnByKey(String key) {
    for (final AppListTableColumn<T> column in _availableColumns) {
      if (column.key == key) {
        return column;
      }
    }
    return null;
  }

  Set<String> _withAlwaysVisibleColumnKeys(Set<String> keys) {
    return <String>{
      ...keys,
      for (final AppListTableColumn<T> column in _availableColumns)
        if (column.alwaysVisible) column.key,
    };
  }

  Set<String> _resolveVisibleColumnKeys({
    required List<AppListTableColumn<T>> columns,
    required List<AppListTableColumn<T>> availableColumns,
    String? storageKey,
  }) {
    final Set<String> availableKeys = availableColumns
        .map((AppListTableColumn<T> column) => column.key)
        .toSet();
    final String? resolvedStorageKey = _resolvedStorageKey(storageKey);
    final Set<String>? savedKeys = resolvedStorageKey == null
        ? null
        : AppListTableColumnVisibilityMemory.instance.read(resolvedStorageKey);
    if (savedKeys != null) {
      final Set<String> restoredKeys = savedKeys
          .where(availableKeys.contains)
          .toSet();
      if (restoredKeys.isNotEmpty) {
        return _withAlwaysVisibleColumnKeys(restoredKeys);
      }
    }

    return appListTableDefaultVisibleColumns(
      availableColumns,
      defaultColumns: columns,
    ).map((AppListTableColumn<T> column) => column.key).toSet();
  }

  String? _resolvedStorageKey(String? override) {
    return override ?? storageKey;
  }

  void _persistVisibleColumnKeys(String? storageKey) {
    final String? resolvedStorageKey = _resolvedStorageKey(storageKey);
    if (resolvedStorageKey == null) {
      return;
    }
    AppListTableColumnVisibilityMemory.instance.write(
      resolvedStorageKey,
      _visibleColumnKeys,
    );
  }
}

@immutable
final class AppListTableSearch<T> {
  const AppListTableSearch({
    required this.controller,
    required this.semanticLabel,
    required this.matcher,
    this.hintText,
    this.clearLabel,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.enabled = true,
    this.isLoading = false,
    this.autofocus = false,
    this.showClearButton = true,
    this.focusNode,
    this.showAdvancedFilterButton = false,
    this.onAdvancedFilterPressed,
    this.advancedFilterButtonLabel,
    this.advancedFilterTitle,
    this.advancedFilterApplyLabel,
    this.advancedFilterResetLabel,
    this.searchFields = const <AppSearchBarFieldChoice>[],
    this.textFilters = const <AppSearchBarTextFilter>[],
    this.searchFieldLabel,
    this.allFieldsLabel,
    this.enableDateFilter = true,
    this.dateFilterLabel,
    this.dateFromLabel,
    this.dateToLabel,
    this.datePickerButtonLabel,
    this.invalidDateMessage,
    this.firstDate,
    this.lastDate,
    this.currentDate,
    this.filterGroups = const <AppSearchBarFilterGroup>[],
    this.filterValue = AppSearchBarFilterValue.empty,
    this.onFilterChanged,
    this.hasActiveFilters = false,
    this.trailingActions = const <AppSearchBarAction>[],
    this.maxTrailingActions,
    this.trailingActionsOverflowLabel = 'More actions',
  });

  final TextEditingController controller;
  final String semanticLabel;
  final AppListTableSearchMatcher<T> matcher;
  final String? hintText;
  final String? clearLabel;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final bool enabled;
  final bool isLoading;
  final bool autofocus;
  final bool showClearButton;
  final FocusNode? focusNode;
  final bool showAdvancedFilterButton;
  final VoidCallback? onAdvancedFilterPressed;
  final String? advancedFilterButtonLabel;
  final String? advancedFilterTitle;
  final String? advancedFilterApplyLabel;
  final String? advancedFilterResetLabel;
  final List<AppSearchBarFieldChoice> searchFields;
  final List<AppSearchBarTextFilter> textFilters;
  final String? searchFieldLabel;
  final String? allFieldsLabel;
  final bool enableDateFilter;
  final String? dateFilterLabel;
  final String? dateFromLabel;
  final String? dateToLabel;
  final String? datePickerButtonLabel;
  final String? invalidDateMessage;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final DateTime? currentDate;
  final List<AppSearchBarFilterGroup> filterGroups;
  final AppSearchBarFilterValue filterValue;
  final ValueChanged<AppSearchBarFilterValue>? onFilterChanged;
  final bool hasActiveFilters;
  final List<AppSearchBarAction> trailingActions;
  final int? maxTrailingActions;
  final String trailingActionsOverflowLabel;

  Widget buildSearchBar(
    BuildContext context, {
    List<AppSearchBarAction> trailingActions = const <AppSearchBarAction>[],
    int? maxTrailingActions,
    String? trailingActionsOverflowLabel,
  }) {
    return AppSearchBar(
      controller: controller,
      semanticLabel: semanticLabel,
      hintText: hintText,
      clearLabel: clearLabel,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      onClear: onClear,
      enabled: enabled,
      isLoading: isLoading,
      autofocus: autofocus,
      showClearButton: showClearButton,
      focusNode: focusNode,
      showAdvancedFilterButton: showAdvancedFilterButton,
      onAdvancedFilterPressed: onAdvancedFilterPressed,
      advancedFilterButtonLabel: advancedFilterButtonLabel,
      advancedFilterTitle: advancedFilterTitle,
      advancedFilterApplyLabel: advancedFilterApplyLabel,
      advancedFilterResetLabel: advancedFilterResetLabel,
      searchFields: searchFields,
      textFilters: textFilters,
      searchFieldLabel: searchFieldLabel,
      allFieldsLabel: allFieldsLabel,
      enableDateFilter: enableDateFilter,
      dateFilterLabel: dateFilterLabel,
      dateFromLabel: dateFromLabel,
      dateToLabel: dateToLabel,
      datePickerButtonLabel: datePickerButtonLabel,
      invalidDateMessage: invalidDateMessage,
      firstDate: firstDate,
      lastDate: lastDate,
      currentDate: currentDate,
      filterGroups: filterGroups,
      filterValue: filterValue,
      onFilterChanged: onFilterChanged,
      hasActiveFilters: hasActiveFilters,
      trailingActions: <AppSearchBarAction>[
        ...this.trailingActions,
        ...trailingActions,
      ],
      maxTrailingActions: maxTrailingActions ?? this.maxTrailingActions,
      trailingActionsOverflowLabel:
          trailingActionsOverflowLabel ?? this.trailingActionsOverflowLabel,
    );
  }
}

class AppListTableColumn<T> {
  const AppListTableColumn({
    required this.label,
    required this.cellBuilder,
    this.id,
    this.numeric = false,
    this.alwaysVisible = false,
    this.tooltip,
    this.sortComparator,
    this.headerBuilder,
  });

  final String? id;
  final String label;
  final AppListTableCellBuilder<T> cellBuilder;
  final bool numeric;
  final bool alwaysVisible;
  final String? tooltip;
  final AppListTableSortComparator<T>? sortComparator;
  final AppListTableHeaderBuilder<T>? headerBuilder;

  String get key => id ?? label;

  bool get isSortable => sortComparator != null;
}

class AppListTable<T> extends StatefulWidget {
  const AppListTable({
    required this.columns,
    required this.mobileItemBuilder,
    this.items,
    this.page,
    this.columnChoices,
    this.itemKeyBuilder,
    this.onRowSelected,
    this.onPageChanged,
    this.pageLabelBuilder,
    this.previousPageLabel,
    this.nextPageLabel,
    this.emptyBuilder,
    this.loadingBuilder,
    this.errorBuilder,
    this.footer,
    this.rowColorBuilder,
    this.maxVisibleItems,
    this.isLoading = false,
    this.error,
    this.shrinkWrap = false,
    this.physics,
    this.displayMode = AppListTableDisplayMode.adaptive,
    this.search,
    this.searchListenable,
    this.searchMatcher,
    @Deprecated(
      'Section titles belong on AppWorkspace or AppWorkspaceDetailPanel only.',
    )
    this.title,
    @Deprecated(
      'Section descriptions belong on AppWorkspace or AppWorkspaceDetailPanel only.',
    )
    this.description,
    this.columnVisibilityLabel,
    this.columnVisibilityTitle,
    this.columnVisibilityApplyLabel,
    this.columnVisibilityResetLabel,
    this.columnVisibilityController,
    this.columnVisibilityStorageKey,
    this.tableHorizontalMargin,
    this.maxTrailingActions,
    this.trailingActionsOverflowLabel = 'More actions',
    super.key,
  }) : assert(
         items != null || page != null,
         'Provide either items or page to AppListTable.',
       ),
       assert(
         searchListenable == null || searchMatcher != null,
         'Provide searchMatcher when searchListenable is used.',
       );

  final List<T>? items;
  final AppPage<T>? page;
  final List<AppListTableColumn<T>> columns;
  final List<AppListTableColumn<T>>? columnChoices;
  final AppListTableMobileItemBuilder<T> mobileItemBuilder;
  final AppListTableItemKeyBuilder<T>? itemKeyBuilder;
  final ValueChanged<T>? onRowSelected;
  final ValueChanged<AppPageRequest>? onPageChanged;
  final AppListTablePageLabelBuilder<T>? pageLabelBuilder;
  final String? previousPageLabel;
  final String? nextPageLabel;
  final WidgetBuilder? emptyBuilder;
  final WidgetBuilder? loadingBuilder;
  final Widget Function(BuildContext context, Object error)? errorBuilder;
  final Widget? footer;
  final AppListTableRowColorBuilder<T>? rowColorBuilder;
  final int? maxVisibleItems;
  final bool isLoading;
  final Object? error;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final AppListTableDisplayMode displayMode;
  final AppListTableSearch<T>? search;
  final ValueListenable<String>? searchListenable;
  final AppListTableSearchMatcher<T>? searchMatcher;
  final String? title;
  final String? description;
  final String? columnVisibilityLabel;
  final String? columnVisibilityTitle;
  final String? columnVisibilityApplyLabel;
  final String? columnVisibilityResetLabel;
  final AppListTableColumnVisibilityController<T>? columnVisibilityController;
  final String? columnVisibilityStorageKey;
  final double? tableHorizontalMargin;
  final int? maxTrailingActions;
  final String trailingActionsOverflowLabel;

  @override
  State<AppListTable<T>> createState() => _AppListTableState<T>();
}

class _AppListTableState<T> extends State<AppListTable<T>> {
  Set<String> _visibleColumnKeys = <String>{};
  String? _sortColumnKey;
  bool _sortAscending = true;
  int? _renderLimit;
  String _trackedQuery = '';
  int _trackedSortedItemCount = 0;

  @override
  void initState() {
    super.initState();
    widget.columnVisibilityController?.addListener(
      _handleColumnVisibilityChanged,
    );
    _syncVisibleColumns();
    _ensureDefaultSortColumn();
  }

  @override
  void didUpdateWidget(covariant AppListTable<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.columnVisibilityController !=
        widget.columnVisibilityController) {
      oldWidget.columnVisibilityController?.removeListener(
        _handleColumnVisibilityChanged,
      );
      widget.columnVisibilityController?.addListener(
        _handleColumnVisibilityChanged,
      );
    }
    if (oldWidget.columns != widget.columns ||
        oldWidget.columnChoices != widget.columnChoices ||
        oldWidget.columnVisibilityController !=
            widget.columnVisibilityController) {
      _syncVisibleColumns();
      _ensureDefaultSortColumn();
    }
  }

  @override
  void dispose() {
    widget.columnVisibilityController?.removeListener(
      _handleColumnVisibilityChanged,
    );
    super.dispose();
  }

  void _handleColumnVisibilityChanged() {
    final String? sortColumnKey = _sortColumnKey;
    if (sortColumnKey != null &&
        widget.columnVisibilityController?.isColumnVisible(sortColumnKey) ==
            false) {
      _sortColumnKey = null;
      _sortAscending = true;
      _ensureDefaultSortColumn();
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppListTableSearch<T>? resolvedSearch = widget.search;
    if (resolvedSearch == null) {
      final ValueListenable<String>? searchListenable = widget.searchListenable;
      if (searchListenable == null) {
        return _buildForQuery(context, query: '', searchBar: null);
      }

      return ValueListenableBuilder<String>(
        valueListenable: searchListenable,
        builder: (BuildContext context, String query, _) {
          return _buildForQuery(
            context,
            query: query,
            searchBar: null,
            usesExternalSearchListenable: true,
          );
        },
      );
    }

    final Widget searchBar = resolvedSearch.buildSearchBar(
      context,
      trailingActions: _searchActions(),
      maxTrailingActions: widget.maxTrailingActions,
      trailingActionsOverflowLabel: widget.trailingActionsOverflowLabel,
    );
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: resolvedSearch.controller,
      builder: (BuildContext context, TextEditingValue value, _) {
        return _buildForQuery(context, query: value.text, searchBar: searchBar);
      },
    );
  }

  Widget _buildForQuery(
    BuildContext context, {
    required String query,
    required Widget? searchBar,
    bool usesExternalSearchListenable = false,
  }) {
    final ({bool disablePagination, List<T> items, int totalSortedCount, AppPage<T>? page}) data =
        _visibleData(
          query,
          usesExternalSearchListenable: usesExternalSearchListenable,
        );
    final Widget content = _wrapIncrementalScroll(
      context,
      totalSortedCount: data.totalSortedCount,
      child: _buildForItems(context, data.items),
    );
    final Widget? footer = _footerForPage(
      context,
      data.page,
      disablePagination: data.disablePagination,
    );
    final Widget? toolbar = _buildToolbar(context, searchBar);
    final ThemeData theme = Theme.of(context);

    assert(() {
      if ((widget.title?.trim().isNotEmpty ?? false) ||
          (widget.description?.trim().isNotEmpty ?? false)) {
        debugPrint(
          'AppListTable title/description are deprecated. '
          'Move section copy to AppWorkspace or AppWorkspaceDetailPanel.',
        );
      }
      return true;
    }());

    if (toolbar == null && footer == null) {
      return content;
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool canExpand =
            !widget.shrinkWrap && constraints.hasBoundedHeight;

        return Column(
          mainAxisSize: canExpand ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (toolbar != null) ...<Widget>[
              toolbar,
              SizedBox(height: theme.spacing.xs),
            ],
            if (canExpand) Expanded(child: content) else content,
            ?footer,
          ],
        );
      },
    );
  }

  ({bool disablePagination, List<T> items, int totalSortedCount, AppPage<T>? page})
  _visibleData(
    String query, {
    required bool usesExternalSearchListenable,
  }) {
    final AppPage<T>? page = widget.page;
    final List<T> sourceItems = page?.items ?? widget.items ?? <T>[];
    final String normalizedQuery = query.trim();
    List<T> visibleItems = sourceItems;

    if (normalizedQuery.isNotEmpty) {
      final AppListTableSearchMatcher<T>? matcher = usesExternalSearchListenable
          ? widget.searchMatcher
          : widget.search?.matcher ?? widget.searchMatcher;
      if (matcher != null) {
        visibleItems = _filteredItems(sourceItems, normalizedQuery, matcher);
      }
    }

    final List<T> sortedItems = _sortedItems(visibleItems);
    _syncRenderLimit(query, sortedItems.length);
    final List<T> renderedItems = _limitedVisibleItems(sortedItems);
    if (usesExternalSearchListenable &&
        normalizedQuery.isNotEmpty &&
        page != null) {
      return (
        disablePagination: true,
        items: renderedItems,
        totalSortedCount: sortedItems.length,
        page: AppPage<T>(
          items: renderedItems,
          request: page.request.first(),
          totalItemCount: sortedItems.length,
        ),
      );
    }

    return (
      disablePagination: false,
      items: renderedItems,
      totalSortedCount: sortedItems.length,
      page: page,
    );
  }

  void _syncRenderLimit(String query, int sortedItemCount) {
    final int? cap = widget.maxVisibleItems;
    if (cap == null || cap <= 0) {
      _renderLimit = null;
      return;
    }
    if (query != _trackedQuery || sortedItemCount != _trackedSortedItemCount) {
      _trackedQuery = query;
      _trackedSortedItemCount = sortedItemCount;
      _renderLimit = cap;
    }
  }

  List<T> _limitedVisibleItems(List<T> items) {
    final int? limit = widget.maxVisibleItems;
    if (limit == null || limit <= 0 || items.length <= limit) {
      return items;
    }
    final int renderCount = math.min(_renderLimit ?? limit, items.length);
    return items.take(renderCount).toList(growable: false);
  }

  bool _canRevealMoreItems(int totalSortedCount) {
    final int? limit = widget.maxVisibleItems;
    if (limit == null || limit <= 0 || totalSortedCount <= limit) {
      return false;
    }
    return (_renderLimit ?? limit) < totalSortedCount;
  }

  void _revealMoreItems(int totalSortedCount) {
    final int? batch = widget.maxVisibleItems;
    if (batch == null || batch <= 0) {
      return;
    }
    final int current = _renderLimit ?? batch;
    if (current >= totalSortedCount) {
      return;
    }
    setState(() {
      _renderLimit = math.min(current + batch, totalSortedCount);
    });
  }

  Widget _wrapIncrementalScroll(
    BuildContext context, {
    required int totalSortedCount,
    required Widget child,
  }) {
    if (!_canRevealMoreItems(totalSortedCount)) {
      return child;
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification notification) {
        if (notification is! ScrollUpdateNotification) {
          return false;
        }
        final double? delta = notification.scrollDelta;
        if (delta == null || delta == 0) {
          return false;
        }
        final ScrollMetrics metrics = notification.metrics;
        if (metrics.maxScrollExtent <= 0) {
          return false;
        }
        if (metrics.pixels < metrics.maxScrollExtent - 240) {
          return false;
        }
        _revealMoreItems(totalSortedCount);
        return false;
      },
      child: child,
    );
  }

  Widget _buildForItems(BuildContext context, List<T> visibleItems) {
    final Object? resolvedError = widget.error;
    if (resolvedError != null && widget.errorBuilder != null) {
      return widget.errorBuilder!(context, resolvedError);
    }

    if (appListTableShowsInitialLoading(
      isLoading: widget.isLoading,
      visibleItems: visibleItems,
    )) {
      return widget.loadingBuilder?.call(context) ??
          const _DefaultListTableLoading();
    }

    if (visibleItems.isEmpty && widget.emptyBuilder != null) {
      return widget.emptyBuilder!(context);
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool hasBoundedHeight = constraints.hasBoundedHeight;
        final bool effectiveShrinkWrap = widget.shrinkWrap || !hasBoundedHeight;
        final ScrollPhysics? effectivePhysics = hasBoundedHeight
            ? widget.physics
            : widget.physics ?? const NeverScrollableScrollPhysics();
        final List<AppListTableColumn<T>> visibleColumns = _visibleColumns;

        if (_usesListLayout(constraints)) {
          return _MobileListTable<T>(
            items: visibleItems,
            itemBuilder: widget.mobileItemBuilder,
            itemKeyBuilder: widget.itemKeyBuilder,
            onRowSelected: widget.onRowSelected,
            shrinkWrap: effectiveShrinkWrap,
            physics: effectivePhysics,
            rowColorBuilder: widget.rowColorBuilder,
          );
        }

        final Widget desktopTable = _DesktopListTable<T>(
          items: visibleItems,
          columns: visibleColumns,
          itemKeyBuilder: widget.itemKeyBuilder,
          onRowSelected: widget.onRowSelected,
          minWidth: _tableMinWidth(constraints, visibleColumns),
          rowColorBuilder: widget.rowColorBuilder,
          compact: _usesCompactTableLayout(constraints),
          horizontalMargin: widget.tableHorizontalMargin,
          sortColumnKey: _sortColumnKey,
          sortAscending: _sortAscending,
          onSort: _sortByColumn,
        );

        if (!hasBoundedHeight) {
          return desktopTable;
        }

        return Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(child: desktopTable),
        );
      },
    );
  }

  Widget? _footerForPage(
    BuildContext context,
    AppPage<T>? visiblePage, {
    required bool disablePagination,
  }) {
    final Widget? resolvedFooter = widget.footer;
    if (resolvedFooter != null) {
      return resolvedFooter;
    }

    final AppListTablePageLabelBuilder<T>? pageLabelBuilder =
        widget.pageLabelBuilder;
    final String? previousPageLabel = widget.previousPageLabel;
    final String? nextPageLabel = widget.nextPageLabel;
    if (visiblePage == null ||
        pageLabelBuilder == null ||
        previousPageLabel == null ||
        nextPageLabel == null) {
      return null;
    }

    return _AppPaginationControls(
      pageRequest: visiblePage.request,
      hasPreviousPage: visiblePage.hasPreviousPage,
      hasNextPage: visiblePage.hasNextPage,
      pageLabel: pageLabelBuilder(visiblePage),
      previousPageLabel: previousPageLabel,
      nextPageLabel: nextPageLabel,
      onPageChanged: disablePagination ? null : widget.onPageChanged,
    );
  }

  bool _usesListLayout(BoxConstraints constraints) {
    return switch (widget.displayMode) {
      AppListTableDisplayMode.list => true,
      AppListTableDisplayMode.table => false,
      AppListTableDisplayMode.adaptive =>
        switch (AppBreakpoints.fromConstraints(constraints)) {
          AppBreakpoint.xs || AppBreakpoint.sm => true,
          _ => false,
        },
    };
  }

  bool _usesCompactTableLayout(BoxConstraints constraints) {
    return AppBreakpoints.fromConstraints(constraints) == AppBreakpoint.md;
  }

  double _tableMinWidth(
    BoxConstraints constraints,
    List<AppListTableColumn<T>> visibleColumns,
  ) {
    if (visibleColumns.isEmpty) {
      return constraints.maxWidth;
    }

    final bool compact = _usesCompactTableLayout(constraints);
    final double minColumnWidth = compact ? 128 : 148;
    return math.max(
      constraints.maxWidth,
      _rowNumberColumnWidth + visibleColumns.length * minColumnWidth,
    );
  }

  List<T> _filteredItems(
    List<T> sourceItems,
    String query,
    AppListTableSearchMatcher<T> matcher,
  ) {
    final String normalizedQuery = _normalizeTableSearchQuery(query);
    if (normalizedQuery.isEmpty) {
      return sourceItems;
    }
    final List<String> tokens = _tableSearchTokens(normalizedQuery);

    return sourceItems
        .where(
          (T item) =>
              matcher(item, normalizedQuery) ||
              (tokens.length > 1 &&
                  tokens.every((String token) => matcher(item, token))),
        )
        .toList(growable: false);
  }

  List<T> _sortedItems(List<T> sourceItems) {
    final String? sortColumnKey = _sortColumnKey;
    if (sortColumnKey == null) {
      return sourceItems;
    }

    final AppListTableColumn<T>? column = _columnByKey(
      _availableColumns,
      sortColumnKey,
    );
    final AppListTableSortComparator<T>? comparator = column?.sortComparator;
    if (comparator == null) {
      return sourceItems;
    }

    final List<T> sortedItems = List<T>.of(sourceItems);
    sortedItems.sort((T left, T right) {
      final int result = comparator(left, right);
      return _sortAscending ? result : -result;
    });
    return sortedItems;
  }

  Widget? _buildToolbar(BuildContext context, Widget? searchBar) {
    return searchBar;
  }

  List<AppSearchBarAction> _searchActions() {
    if (_availableColumns.length <= 1) {
      return const <AppSearchBarAction>[];
    }

    return <AppSearchBarAction>[
      AppSearchBarAction(
        icon: Icons.settings_outlined,
        label: _columnVisibilityLabel,
        tooltip: _columnVisibilityLabel,
        active: _hasCustomColumnVisibility,
        onPressed: _openColumnVisibilityDialog,
      ),
    ];
  }

  List<AppListTableColumn<T>> get _availableColumns {
    return _availableColumnsFor(widget.columns, widget.columnChoices);
  }

  List<AppListTableColumn<T>> get _visibleColumns {
    final AppListTableColumnVisibilityController<T>? controller =
        widget.columnVisibilityController;
    if (controller != null) {
      return controller.visibleColumns;
    }

    final List<AppListTableColumn<T>> availableColumns = _availableColumns;
    final List<AppListTableColumn<T>> visibleColumns = availableColumns
        .where(
          (AppListTableColumn<T> column) =>
              column.alwaysVisible || _visibleColumnKeys.contains(column.key),
        )
        .toList(growable: false);
    if (visibleColumns.isNotEmpty || availableColumns.isEmpty) {
      return visibleColumns;
    }
    return _defaultVisibleColumns(availableColumns);
  }

  bool get _hasCustomColumnVisibility {
    final AppListTableColumnVisibilityController<T>? controller =
        widget.columnVisibilityController;
    if (controller != null) {
      return controller.hasCustomColumnVisibility;
    }
    return !setEquals(_visibleColumnKeys, _defaultColumnKeys);
  }

  Set<String> get _defaultColumnKeys {
    return _defaultVisibleColumns(
      _availableColumns,
    ).map((AppListTableColumn<T> column) => column.key).toSet();
  }

  List<AppListTableColumn<T>> _defaultVisibleColumns(
    List<AppListTableColumn<T>> availableColumns,
  ) {
    return appListTableDefaultVisibleColumns(
      availableColumns,
      defaultColumns: widget.columns,
    );
  }

  void _syncVisibleColumns() {
    final AppListTableColumnVisibilityController<T>? controller =
        widget.columnVisibilityController;
    final String? storageKey = _resolvedColumnVisibilityStorageKey();
    if (controller != null) {
      controller.syncColumns(
        columns: widget.columns,
        columnChoices: widget.columnChoices,
        storageKey: storageKey,
      );
      return;
    }

    final List<AppListTableColumn<T>> availableColumns = _availableColumns;
    final Set<String> availableKeys = availableColumns
        .map((AppListTableColumn<T> column) => column.key)
        .toSet();
    final Set<String> next = _visibleColumnKeys
        .where(availableKeys.contains)
        .toSet();

    if (next.isEmpty) {
      final Set<String>? savedKeys = storageKey == null
          ? null
          : AppListTableColumnVisibilityMemory.instance.read(storageKey);
      if (savedKeys != null) {
        final Set<String> restoredKeys = savedKeys
            .where(availableKeys.contains)
            .toSet();
        if (restoredKeys.isNotEmpty) {
          next.addAll(_withAlwaysVisibleColumnKeys(restoredKeys));
        } else {
          next.addAll(_defaultColumnKeys);
        }
      } else {
        next.addAll(_defaultColumnKeys);
      }
    }

    _visibleColumnKeys = next;
    final String? sortColumnKey = _sortColumnKey;
    if (sortColumnKey != null && !_visibleColumnKeys.contains(sortColumnKey)) {
      _sortColumnKey = null;
      _sortAscending = true;
      _ensureDefaultSortColumn();
    }
  }

  void _ensureDefaultSortColumn() {
    if (_sortColumnKey != null) {
      return;
    }

    for (final AppListTableColumn<T> column in _visibleColumns) {
      if (column.isSortable) {
        _sortColumnKey = column.key;
        _sortAscending = true;
        return;
      }
    }
  }

  AppListTableColumn<T>? _columnByKey(
    List<AppListTableColumn<T>> columns,
    String key,
  ) {
    for (final AppListTableColumn<T> column in columns) {
      if (column.key == key) {
        return column;
      }
    }
    return null;
  }

  void _sortByColumn(AppListTableColumn<T> column) {
    if (!column.isSortable) {
      return;
    }

    setState(() {
      if (_sortColumnKey == column.key) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumnKey = column.key;
        _sortAscending = true;
      }
    });
  }

  Future<void> _openColumnVisibilityDialog() async {
    final AppListTableColumnVisibilityController<T>? controller =
        widget.columnVisibilityController;
    final String? storageKey = _resolvedColumnVisibilityStorageKey();
    if (controller != null) {
      await controller.openColumnVisibilityDialog(
        context,
        title: widget.columnVisibilityTitle,
        applyLabel: widget.columnVisibilityApplyLabel,
        resetLabel: widget.columnVisibilityResetLabel,
        storageKey: storageKey,
      );
      return;
    }

    final Set<String>? value = await showAppDialog<Set<String>>(
      context: context,
      builder: (_) => _ColumnVisibilityDialog<T>(
        columns: _availableColumns,
        visibleColumnKeys: _visibleColumnKeys,
        defaultColumnKeys: _defaultColumnKeys,
        title: widget.columnVisibilityTitle ?? 'Table columns',
        applyLabel: widget.columnVisibilityApplyLabel ?? 'Apply columns',
        resetLabel: widget.columnVisibilityResetLabel ?? 'Reset columns',
      ),
    );
    if (!mounted || value == null) {
      return;
    }

    setState(() {
      _visibleColumnKeys = _withAlwaysVisibleColumnKeys(value);
      final String? sortColumnKey = _sortColumnKey;
      if (sortColumnKey != null &&
          !_visibleColumnKeys.contains(sortColumnKey)) {
        _sortColumnKey = null;
        _sortAscending = true;
      }
    });
    _persistVisibleColumnKeys(storageKey);
  }

  String? _resolvedColumnVisibilityStorageKey() {
    final String? explicitKey = widget.columnVisibilityStorageKey;
    if (explicitKey != null) {
      return explicitKey;
    }
    if (widget.columnVisibilityController?.storageKey != null) {
      return widget.columnVisibilityController!.storageKey;
    }
    return appListTableColumnVisibilityStorageKey(
      widget.columns,
      widget.columnChoices,
    );
  }

  void _persistVisibleColumnKeys(String? storageKey) {
    if (storageKey == null) {
      return;
    }
    AppListTableColumnVisibilityMemory.instance.write(
      storageKey,
      _visibleColumnKeys,
    );
  }

  String get _columnVisibilityLabel {
    return widget.columnVisibilityLabel ?? 'Table column settings';
  }

  Set<String> _withAlwaysVisibleColumnKeys(Set<String> keys) {
    return <String>{
      ...keys,
      for (final AppListTableColumn<T> column in _availableColumns)
        if (column.alwaysVisible) column.key,
    };
  }
}

String _normalizeTableSearchQuery(String query) {
  return query.trim().replaceAll(RegExp(r'\s+'), ' ');
}

List<String> _tableSearchTokens(String query) {
  final String normalized = _normalizeTableSearchQuery(query);
  if (normalized.isEmpty) {
    return const <String>[];
  }
  return normalized
      .split(' ')
      .where((String token) => token.isNotEmpty)
      .toList(growable: false);
}

class _ColumnVisibilityDialog<T> extends StatefulWidget {
  const _ColumnVisibilityDialog({
    required this.columns,
    required this.visibleColumnKeys,
    required this.defaultColumnKeys,
    required this.title,
    required this.applyLabel,
    required this.resetLabel,
  });

  final List<AppListTableColumn<T>> columns;
  final Set<String> visibleColumnKeys;
  final Set<String> defaultColumnKeys;
  final String title;
  final String applyLabel;
  final String resetLabel;

  @override
  State<_ColumnVisibilityDialog<T>> createState() =>
      _ColumnVisibilityDialogState<T>();
}

class _ColumnVisibilityDialogState<T>
    extends State<_ColumnVisibilityDialog<T>> {
  late Set<String> _visibleColumnKeys;

  @override
  void initState() {
    super.initState();
    _visibleColumnKeys = Set<String>.of(widget.visibleColumnKeys);
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: Text(widget.title),
      icon: const Icon(Icons.settings_outlined),
      maxWidth: 480,
      scrollable: true,
      showMaximizeButton: false,
      resizable: false,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final AppListTableColumn<T> column in widget.columns)
            Builder(
              builder: (BuildContext context) {
                final bool isChecked =
                    column.alwaysVisible ||
                    _visibleColumnKeys.contains(column.key);
                final bool canChange =
                    !column.alwaysVisible &&
                    (!isChecked || _visibleColumnKeys.length > 1);

                return Material(
                  type: MaterialType.transparency,
                  child: CheckboxListTile(
                    value: isChecked,
                    title: Text(column.label),
                    subtitle: column.tooltip == null
                        ? null
                        : Text(column.tooltip!),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: canChange
                        ? (bool? value) {
                            setState(() {
                              final Set<String> next = Set<String>.of(
                                _visibleColumnKeys,
                              );
                              if (value ?? false) {
                                next.add(column.key);
                              } else {
                                next.remove(column.key);
                              }
                              _visibleColumnKeys = next;
                            });
                          }
                        : null,
                  ),
                );
              },
            ),
        ],
      ),
      actions: <Widget>[
        AppButton.tertiary(
          label: widget.resetLabel,
          leadingIcon: Icons.restart_alt,
          onPressed: () {
            setState(() {
              _visibleColumnKeys = Set<String>.of(widget.defaultColumnKeys);
            });
          },
        ),
        AppButton.primary(
          label: widget.applyLabel,
          leadingIcon: Icons.check,
          onPressed: () {
            Navigator.of(context).pop(_visibleColumnKeys);
          },
        ),
      ],
    );
  }
}

class _AppPaginationControls extends StatelessWidget {
  const _AppPaginationControls({
    required this.pageRequest,
    required this.hasPreviousPage,
    required this.hasNextPage,
    required this.pageLabel,
    required this.previousPageLabel,
    required this.nextPageLabel,
    required this.onPageChanged,
  });

  final AppPageRequest pageRequest;
  final bool hasPreviousPage;
  final bool hasNextPage;
  final String pageLabel;
  final String previousPageLabel;
  final String nextPageLabel;
  final ValueChanged<AppPageRequest>? onPageChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: theme.spacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          Flexible(
            child: Text(
              pageLabel,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          SizedBox(width: theme.spacing.sm),
          AppButton(
            iconOnly: true,
            leadingIcon: Icons.chevron_left,
            label: previousPageLabel,
            semanticLabel: previousPageLabel,
            tooltip: previousPageLabel,
            onPressed: hasPreviousPage && onPageChanged != null
                ? () {
                    onPageChanged!(pageRequest.previous());
                  }
                : null,
          ),
          AppButton(
            iconOnly: true,
            leadingIcon: Icons.chevron_right,
            label: nextPageLabel,
            semanticLabel: nextPageLabel,
            tooltip: nextPageLabel,
            onPressed: hasNextPage && onPageChanged != null
                ? () {
                    onPageChanged!(pageRequest.next());
                  }
                : null,
          ),
        ],
      ),
    );
  }
}

class _MobileListTable<T> extends StatelessWidget {
  const _MobileListTable({
    required this.items,
    required this.itemBuilder,
    required this.itemKeyBuilder,
    required this.onRowSelected,
    required this.shrinkWrap,
    required this.physics,
    required this.rowColorBuilder,
  });

  final List<T> items;
  final AppListTableMobileItemBuilder<T> itemBuilder;
  final AppListTableItemKeyBuilder<T>? itemKeyBuilder;
  final ValueChanged<T>? onRowSelected;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final AppListTableRowColorBuilder<T>? rowColorBuilder;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: items.length,
      shrinkWrap: shrinkWrap,
      physics: physics,
      itemBuilder: (BuildContext context, int index) {
        final T item = items[index];
        Widget row = KeyedSubtree(
          key: appListTableUniqueRowKey<T>(
            index: index,
            itemKeyBuilder: itemKeyBuilder,
            item: item,
          ),
          child: _NumberedMobileListItem(
            number: index + 1,
            child: itemBuilder(context, item),
          ),
        );

        if (onRowSelected != null) {
          row = _SelectableMobileDataRow<T>(
            item: item,
            onSelected: onRowSelected!,
            child: row,
          );
        }

        final Color? rowColor = rowColorBuilder?.call(context, item);
        if (rowColor == null) {
          return row;
        }

        return ColoredBox(color: rowColor, child: row);
      },
      separatorBuilder: (BuildContext context, int index) {
        return const Divider(height: 1);
      },
    );
  }
}

class _NumberedMobileListItem extends StatelessWidget {
  const _NumberedMobileListItem({required this.number, required this.child});

  final int number;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: _rowNumberColumnWidth,
          child: Padding(
            padding: EdgeInsets.only(
              top: theme.spacing.xs,
              left: theme.spacing.xs,
              right: theme.spacing.xs,
            ),
            child: Text(
              number.toString(),
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _SelectableMobileDataRow<T> extends StatelessWidget {
  const _SelectableMobileDataRow({
    required this.item,
    required this.onSelected,
    required this.child,
  });

  static const Map<ShortcutActivator, Intent> _shortcuts =
      <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      };

  final T item;
  final ValueChanged<T> onSelected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: _shortcuts,
      child: Actions(
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              onSelected(item);
              return null;
            },
          ),
        },
        child: Semantics(
          button: true,
          enabled: true,
          onTap: () {
            onSelected(item);
          },
          child: InkWell(
            mouseCursor: SystemMouseCursors.click,
            onTap: () {
              onSelected(item);
            },
            child: child,
          ),
        ),
      ),
    );
  }
}

class _DesktopListTable<T> extends StatefulWidget {
  const _DesktopListTable({
    required this.items,
    required this.columns,
    required this.itemKeyBuilder,
    required this.onRowSelected,
    required this.minWidth,
    required this.rowColorBuilder,
    required this.compact,
    this.horizontalMargin,
    required this.sortColumnKey,
    required this.sortAscending,
    required this.onSort,
  });

  final List<T> items;
  final List<AppListTableColumn<T>> columns;
  final AppListTableItemKeyBuilder<T>? itemKeyBuilder;
  final ValueChanged<T>? onRowSelected;
  final double minWidth;
  final AppListTableRowColorBuilder<T>? rowColorBuilder;
  final bool compact;
  final double? horizontalMargin;
  final String? sortColumnKey;
  final bool sortAscending;
  final ValueChanged<AppListTableColumn<T>> onSort;

  @override
  State<_DesktopListTable<T>> createState() => _DesktopListTableState<T>();
}

class _DesktopListTableState<T> extends State<_DesktopListTable<T>> {
  late final ScrollController _horizontalController;

  @override
  void initState() {
    super.initState();
    _horizontalController = ScrollController();
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final double horizontalMargin =
        widget.horizontalMargin ??
        (widget.compact ? theme.spacing.sm : theme.spacing.md);
    final double columnSpacing = widget.compact
        ? theme.spacing.md
        : theme.spacing.xl;
    final double rowMinHeight = widget.compact ? 32 : 34;
    final double rowMaxHeight = widget.compact ? 50 : 56;

    final Widget table = DataTable(
      showCheckboxColumn: false,
      horizontalMargin: horizontalMargin,
      columnSpacing: columnSpacing,
      headingRowHeight: widget.compact ? 44 : 48,
      dataRowMinHeight: rowMinHeight,
      dataRowMaxHeight: rowMaxHeight,
      headingTextStyle: theme.textTheme.labelLarge?.copyWith(
        color: colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
      ),
      dataTextStyle: theme.textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w500,
      ),
      columns: <DataColumn>[
        DataColumn(
          numeric: true,
          label: SizedBox(
            width: _rowNumberColumnWidth,
            child: Text(
              '#',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        for (final AppListTableColumn<T> column in widget.columns)
          DataColumn(
            numeric: column.numeric,
            tooltip: column.tooltip,
            label: _DataColumnHeader<T>(
              column: column,
              compact: widget.compact,
              isSorted: widget.sortColumnKey == column.key,
              sortAscending: widget.sortAscending,
              onSort: widget.onSort,
            ),
          ),
      ],
      rows: <DataRow>[
        for (var index = 0; index < widget.items.length; index += 1)
          _dataRow(context, index),
      ],
    );

    return Scrollbar(
      controller: _horizontalController,
      thumbVisibility: true,
      notificationPredicate: (ScrollNotification notification) {
        return notification.metrics.axis == Axis.horizontal;
      },
      child: SingleChildScrollView(
        controller: _horizontalController,
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: widget.minWidth),
          child: table,
        ),
      ),
    );
  }

  DataRow _dataRow(BuildContext context, int index) {
    final T item = widget.items[index];

    return DataRow(
      key: appListTableUniqueRowKey<T>(
        index: index,
        itemKeyBuilder: widget.itemKeyBuilder,
        item: item,
      ),
      color: _rowColor(context, item),
      onSelectChanged: widget.onRowSelected == null
          ? null
          : (_) {
              widget.onRowSelected!(item);
            },
      cells: <DataCell>[
        DataCell(
          SizedBox(
            width: _rowNumberColumnWidth,
            child: Text((index + 1).toString(), textAlign: TextAlign.center),
          ),
        ),
        for (final AppListTableColumn<T> column in widget.columns)
          DataCell(column.cellBuilder(context, item)),
      ],
    );
  }

  WidgetStateProperty<Color?>? _rowColor(BuildContext context, T item) {
    final AppListTableRowColorBuilder<T>? builder = widget.rowColorBuilder;
    if (builder == null) {
      return null;
    }

    return WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
      final Color? color = builder(context, item);
      if (color == null) {
        return null;
      }
      if (states.contains(WidgetState.hovered)) {
        return Color.alphaBlend(
          Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
          color,
        );
      }
      return color;
    });
  }
}

class _DataColumnHeader<T> extends StatelessWidget {
  const _DataColumnHeader({
    required this.column,
    required this.compact,
    required this.isSorted,
    required this.sortAscending,
    required this.onSort,
  });

  final AppListTableColumn<T> column;
  final bool compact;
  final bool isSorted;
  final bool sortAscending;
  final ValueChanged<AppListTableColumn<T>> onSort;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final double maxWidth = compact ? 132 : 164;
    final TextStyle? headerStyle = theme.textTheme.labelLarge?.copyWith(
      color: isSorted ? colorScheme.primary : colorScheme.onSurfaceVariant,
      fontWeight: isSorted ? FontWeight.w700 : FontWeight.w600,
    );

    if (!column.isSortable) {
      final AppListTableHeaderBuilder<T>? headerBuilder = column.headerBuilder;
      if (headerBuilder != null) {
        return headerBuilder(context);
      }
      return ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Text(
          column.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: headerStyle,
        ),
      );
    }

    final IconData sortIcon = isSorted
        ? sortAscending
              ? Icons.arrow_upward
              : Icons.arrow_downward
        : Icons.swap_vert;
    final Color foreground = isSorted
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;
    final String direction = sortAscending ? 'ascending' : 'descending';
    final String tooltip = isSorted
        ? 'Sorted by ${column.label}, $direction'
        : 'Sort by ${column.label}';

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Tooltip(
        message: tooltip,
        child: Semantics(
          button: true,
          selected: isSorted,
          label: tooltip,
          child: InkWell(
            onTap: () {
              onSort(column);
            },
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: theme.spacing.xs),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSorted
                          ? colorScheme.primary
                          : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        column.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: headerStyle?.copyWith(color: foreground),
                      ),
                    ),
                    SizedBox(width: theme.spacing.xs),
                    Icon(
                      sortIcon,
                      color: foreground.withValues(alpha: isSorted ? 1 : 0.74),
                      size: theme.appTokens.listIconSize * 0.82,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DefaultListTableLoading extends StatelessWidget {
  const _DefaultListTableLoading();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Center(
      child: SizedBox.square(
        dimension: theme.appTokens.statusIconSize,
        child: const CircularProgressIndicator(strokeWidth: 3),
      ),
    );
  }
}
