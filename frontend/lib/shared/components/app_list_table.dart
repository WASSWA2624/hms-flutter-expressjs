import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/components/app_dialog.dart';
import 'package:hosspi_hms/shared/components/app_icon_button.dart';
import 'package:hosspi_hms/shared/components/app_search_bar.dart';
import 'package:hosspi_hms/shared/data/data.dart';

typedef AppListTableCellBuilder<T> =
    Widget Function(BuildContext context, T item);
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
  return defaultSource
      .take(math.min(defaultSource.length, _maxVisibleTableColumns))
      .toList(growable: false);
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

class AppListTableColumnVisibilityController<T> extends ChangeNotifier {
  List<AppListTableColumn<T>> _availableColumns = <AppListTableColumn<T>>[];
  Set<String> _visibleColumnKeys = <String>{};

  void syncColumns({
    required List<AppListTableColumn<T>> columns,
    List<AppListTableColumn<T>>? columnChoices,
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
    _visibleColumnKeys = appListTableDefaultVisibleColumns(
      nextColumns,
      defaultColumns: columns,
    ).map((AppListTableColumn<T> column) => column.key).toSet();
    notifyListeners();
  }

  List<AppListTableColumn<T>> get visibleColumns {
    final List<AppListTableColumn<T>> columns = _availableColumns
        .where(
          (AppListTableColumn<T> column) =>
              _visibleColumnKeys.contains(column.key),
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
    return _visibleColumnKeys.contains(key);
  }

  AppSearchBarAction settingsAction(
    BuildContext context, {
    String? label,
    String? title,
    String? applyLabel,
    String? resetLabel,
    String? cancelLabel,
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
          cancelLabel: cancelLabel,
        );
      },
    );
  }

  Future<void> openColumnVisibilityDialog(
    BuildContext context, {
    String? title,
    String? applyLabel,
    String? resetLabel,
    String? cancelLabel,
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
        cancelLabel:
            cancelLabel ?? MaterialLocalizations.of(context).cancelButtonLabel,
      ),
    );
    if (value == null) {
      return;
    }

    _visibleColumnKeys = value;
    notifyListeners();
  }

  Set<String> get _defaultColumnKeys {
    return appListTableDefaultVisibleColumns(
      _availableColumns,
    ).map((AppListTableColumn<T> column) => column.key).toSet();
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
    this.advancedFilterCancelLabel,
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
  final String? advancedFilterCancelLabel;
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

  Widget buildSearchBar(
    BuildContext context, {
    List<AppSearchBarAction> trailingActions = const <AppSearchBarAction>[],
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
      advancedFilterCancelLabel: advancedFilterCancelLabel,
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
    );
  }
}

class AppListTableColumn<T> {
  const AppListTableColumn({
    required this.label,
    required this.cellBuilder,
    this.id,
    this.numeric = false,
    this.tooltip,
    this.sortComparator,
  });

  final String? id;
  final String label;
  final AppListTableCellBuilder<T> cellBuilder;
  final bool numeric;
  final String? tooltip;
  final AppListTableSortComparator<T>? sortComparator;

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
    this.isLoading = false,
    this.error,
    this.shrinkWrap = false,
    this.physics,
    this.displayMode = AppListTableDisplayMode.adaptive,
    this.search,
    this.searchListenable,
    this.searchMatcher,
    this.title,
    this.description,
    this.columnVisibilityLabel,
    this.columnVisibilityTitle,
    this.columnVisibilityApplyLabel,
    this.columnVisibilityResetLabel,
    this.columnVisibilityCancelLabel,
    this.columnVisibilityController,
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
  final String? columnVisibilityCancelLabel;
  final AppListTableColumnVisibilityController<T>? columnVisibilityController;

  @override
  State<AppListTable<T>> createState() => _AppListTableState<T>();
}

class _AppListTableState<T> extends State<AppListTable<T>> {
  Set<String> _visibleColumnKeys = <String>{};
  String? _sortColumnKey;
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    widget.columnVisibilityController?.addListener(
      _handleColumnVisibilityChanged,
    );
    _syncVisibleColumns();
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
    final ({bool disablePagination, List<T> items, AppPage<T>? page}) data =
        _visibleData(
          query,
          usesExternalSearchListenable: usesExternalSearchListenable,
        );
    final Widget content = _buildForItems(context, data.items);
    final Widget? footer = _footerForPage(
      context,
      data.page,
      disablePagination: data.disablePagination,
    );
    final Widget? toolbar = _buildToolbar(context, searchBar);
    final Widget? title = _buildTitle(context);
    final ThemeData theme = Theme.of(context);

    if (toolbar == null && title == null && footer == null) {
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
            if (title != null) ...<Widget>[
              title,
              SizedBox(height: theme.spacing.xs),
            ],
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

  ({bool disablePagination, List<T> items, AppPage<T>? page}) _visibleData(
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
    if (usesExternalSearchListenable &&
        normalizedQuery.isNotEmpty &&
        page != null) {
      return (
        disablePagination: true,
        items: sortedItems,
        page: AppPage<T>(
          items: sortedItems,
          request: page.request.first(),
          totalItemCount: sortedItems.length,
        ),
      );
    }

    return (disablePagination: false, items: sortedItems, page: page);
  }

  Widget _buildForItems(BuildContext context, List<T> visibleItems) {
    final Object? resolvedError = widget.error;
    if (resolvedError != null && widget.errorBuilder != null) {
      return widget.errorBuilder!(context, resolvedError);
    }

    if (widget.isLoading) {
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

        return _DesktopListTable<T>(
          items: visibleItems,
          columns: visibleColumns,
          itemKeyBuilder: widget.itemKeyBuilder,
          onRowSelected: widget.onRowSelected,
          minWidth: _tableMinWidth(constraints, visibleColumns),
          rowColorBuilder: widget.rowColorBuilder,
          compact: _usesCompactTableLayout(constraints),
          sortColumnKey: _sortColumnKey,
          sortAscending: _sortAscending,
          onSort: _sortByColumn,
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
    final String normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      return sourceItems;
    }

    return sourceItems
        .where((T item) => matcher(item, normalizedQuery))
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

  Widget? _buildTitle(BuildContext context) {
    final String? title = widget.title;
    final String? description = widget.description;
    if ((title == null || title.trim().isEmpty) &&
        (description == null || description.trim().isEmpty)) {
      return null;
    }

    return _ListTableTitle(title: title, description: description);
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
              _visibleColumnKeys.contains(column.key),
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
    if (controller != null) {
      controller.syncColumns(
        columns: widget.columns,
        columnChoices: widget.columnChoices,
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
      next.addAll(_defaultColumnKeys);
    }

    _visibleColumnKeys = next;
    final String? sortColumnKey = _sortColumnKey;
    if (sortColumnKey != null && !_visibleColumnKeys.contains(sortColumnKey)) {
      _sortColumnKey = null;
      _sortAscending = true;
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
    if (controller != null) {
      await controller.openColumnVisibilityDialog(
        context,
        title: widget.columnVisibilityTitle,
        applyLabel: widget.columnVisibilityApplyLabel,
        resetLabel: widget.columnVisibilityResetLabel,
        cancelLabel: widget.columnVisibilityCancelLabel,
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
        cancelLabel:
            widget.columnVisibilityCancelLabel ??
            MaterialLocalizations.of(context).cancelButtonLabel,
      ),
    );
    if (!mounted || value == null) {
      return;
    }

    setState(() {
      _visibleColumnKeys = value;
      final String? sortColumnKey = _sortColumnKey;
      if (sortColumnKey != null && !value.contains(sortColumnKey)) {
        _sortColumnKey = null;
        _sortAscending = true;
      }
    });
  }

  String get _columnVisibilityLabel {
    return widget.columnVisibilityLabel ?? 'Table column settings';
  }
}

class _ListTableTitle extends StatelessWidget {
  const _ListTableTitle({required this.title, required this.description});

  final String? title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String? title = this.title?.trim();
    final String? description = this.description?.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (title != null && title.isNotEmpty)
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
        if (description != null && description.isNotEmpty)
          Text(
            description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _ColumnVisibilityDialog<T> extends StatefulWidget {
  const _ColumnVisibilityDialog({
    required this.columns,
    required this.visibleColumnKeys,
    required this.defaultColumnKeys,
    required this.title,
    required this.applyLabel,
    required this.resetLabel,
    required this.cancelLabel,
  });

  final List<AppListTableColumn<T>> columns;
  final Set<String> visibleColumnKeys;
  final Set<String> defaultColumnKeys;
  final String title;
  final String applyLabel;
  final String resetLabel;
  final String cancelLabel;

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
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final AppListTableColumn<T> column in widget.columns)
            Builder(
              builder: (BuildContext context) {
                final bool isChecked = _visibleColumnKeys.contains(column.key);
                final bool canChange =
                    !isChecked || _visibleColumnKeys.length > 1;

                return CheckboxListTile(
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
        AppButton.secondary(
          label: widget.cancelLabel,
          onPressed: () {
            Navigator.of(context).pop();
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
          AppIconButton(
            icon: Icons.chevron_left,
            semanticLabel: previousPageLabel,
            onPressed: hasPreviousPage && onPageChanged != null
                ? () {
                    onPageChanged!(pageRequest.previous());
                  }
                : null,
          ),
          AppIconButton(
            icon: Icons.chevron_right,
            semanticLabel: nextPageLabel,
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
          key: itemKeyBuilder?.call(item),
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
              top: theme.spacing.sm,
              left: theme.spacing.xs,
              right: theme.spacing.xs,
            ),
            child: Text(
              number.toString(),
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
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
    final double horizontalMargin = widget.compact
        ? theme.spacing.sm
        : theme.spacing.md;
    final double columnSpacing = widget.compact
        ? theme.spacing.md
        : theme.spacing.xl;
    final double rowMinHeight = widget.compact ? 38 : 40;
    final double rowMaxHeight = widget.compact ? 56 : 64;

    final Widget table = DataTable(
      showCheckboxColumn: false,
      horizontalMargin: horizontalMargin,
      columnSpacing: columnSpacing,
      headingRowHeight: widget.compact ? 52 : 56,
      dataRowMinHeight: rowMinHeight,
      dataRowMaxHeight: rowMaxHeight,
      headingTextStyle: theme.textTheme.labelMedium?.copyWith(
        color: colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w800,
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
                fontWeight: FontWeight.w800,
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
      key: widget.itemKeyBuilder?.call(item),
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
    final TextStyle? headerStyle = theme.textTheme.labelMedium?.copyWith(
      color: colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w800,
    );

    if (!column.isSortable) {
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
