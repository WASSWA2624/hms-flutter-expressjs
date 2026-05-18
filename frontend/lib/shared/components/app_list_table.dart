import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
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
typedef AppListTableHeaderBuilder = Widget Function(BuildContext context);
typedef AppListTableSearchMatcher<T> = bool Function(T item, String query);

enum AppListTableDisplayMode { adaptive, table, list }

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

  Widget buildSearchBar(BuildContext context) {
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
    );
  }
}

class AppListTableColumn<T> {
  const AppListTableColumn({
    required this.label,
    required this.cellBuilder,
    this.headerBuilder,
    this.numeric = false,
    this.tooltip,
  });

  final String label;
  final AppListTableCellBuilder<T> cellBuilder;
  final AppListTableHeaderBuilder? headerBuilder;
  final bool numeric;
  final String? tooltip;
}

class AppListTable<T> extends StatelessWidget {
  const AppListTable({
    required this.items,
    required this.columns,
    required this.mobileItemBuilder,
    this.itemKeyBuilder,
    this.onRowSelected,
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
    super.key,
  });

  final List<T> items;
  final List<AppListTableColumn<T>> columns;
  final AppListTableMobileItemBuilder<T> mobileItemBuilder;
  final AppListTableItemKeyBuilder<T>? itemKeyBuilder;
  final ValueChanged<T>? onRowSelected;
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

  @override
  Widget build(BuildContext context) {
    final AppListTableSearch<T>? resolvedSearch = search;
    if (resolvedSearch == null) {
      return _buildForItems(context, items);
    }

    return _ListTableSearchLayout(
      searchBar: resolvedSearch.buildSearchBar(context),
      shrinkWrap: shrinkWrap,
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: resolvedSearch.controller,
        builder: (BuildContext context, TextEditingValue value, _) {
          return _buildForItems(
            context,
            _filteredItems(items, value.text, resolvedSearch.matcher),
          );
        },
      ),
    );
  }

  Widget _buildForItems(BuildContext context, List<T> visibleItems) {
    final Object? resolvedError = error;
    if (resolvedError != null && errorBuilder != null) {
      return errorBuilder!(context, resolvedError);
    }

    if (isLoading) {
      return loadingBuilder?.call(context) ?? const _DefaultListTableLoading();
    }

    if (visibleItems.isEmpty && emptyBuilder != null) {
      return emptyBuilder!(context);
    }

    final Widget content = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (_usesListLayout(constraints)) {
          return _MobileListTable<T>(
            items: visibleItems,
            itemBuilder: mobileItemBuilder,
            itemKeyBuilder: itemKeyBuilder,
            onRowSelected: onRowSelected,
            shrinkWrap: shrinkWrap,
            physics: physics,
            rowColorBuilder: rowColorBuilder,
          );
        }

        return _DesktopListTable<T>(
          items: visibleItems,
          columns: columns,
          itemKeyBuilder: itemKeyBuilder,
          onRowSelected: onRowSelected,
          minWidth: _tableMinWidth(constraints),
          rowColorBuilder: rowColorBuilder,
          compact: _usesCompactTableLayout(constraints),
        );
      },
    );

    final Widget? resolvedFooter = footer;
    if (resolvedFooter == null) {
      return content;
    }

    if (shrinkWrap) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[content, resolvedFooter],
      );
    }

    return Column(
      children: <Widget>[
        Expanded(child: content),
        resolvedFooter,
      ],
    );
  }

  bool _usesListLayout(BoxConstraints constraints) {
    return switch (displayMode) {
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

  double _tableMinWidth(BoxConstraints constraints) {
    if (columns.isEmpty) {
      return constraints.maxWidth;
    }

    final bool compact = _usesCompactTableLayout(constraints);
    final double minColumnWidth = compact ? 128 : 148;
    return math.max(constraints.maxWidth, columns.length * minColumnWidth);
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
}

class _ListTableSearchLayout extends StatelessWidget {
  const _ListTableSearchLayout({
    required this.searchBar,
    required this.child,
    required this.shrinkWrap,
  });

  final Widget searchBar;
  final Widget child;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<Widget> children = <Widget>[
      searchBar,
      SizedBox(height: theme.spacing.sm),
      if (shrinkWrap) child else Expanded(child: child),
    ];

    return Column(
      mainAxisSize: shrinkWrap ? MainAxisSize.min : MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

class AppPaginatedListTable<T> extends StatelessWidget {
  const AppPaginatedListTable({
    required this.page,
    required this.columns,
    required this.mobileItemBuilder,
    required this.pageLabelBuilder,
    required this.previousPageLabel,
    required this.nextPageLabel,
    this.itemKeyBuilder,
    this.onRowSelected,
    this.onPageChanged,
    this.emptyBuilder,
    this.loadingBuilder,
    this.errorBuilder,
    this.rowColorBuilder,
    this.isLoading = false,
    this.error,
    this.shrinkWrap = false,
    this.physics,
    this.displayMode = AppListTableDisplayMode.adaptive,
    this.search,
    super.key,
  });

  final AppPage<T> page;
  final List<AppListTableColumn<T>> columns;
  final AppListTableMobileItemBuilder<T> mobileItemBuilder;
  final AppListTablePageLabelBuilder<T> pageLabelBuilder;
  final String previousPageLabel;
  final String nextPageLabel;
  final AppListTableItemKeyBuilder<T>? itemKeyBuilder;
  final ValueChanged<T>? onRowSelected;
  final ValueChanged<AppPageRequest>? onPageChanged;
  final WidgetBuilder? emptyBuilder;
  final WidgetBuilder? loadingBuilder;
  final Widget Function(BuildContext context, Object error)? errorBuilder;
  final AppListTableRowColorBuilder<T>? rowColorBuilder;
  final bool isLoading;
  final Object? error;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final AppListTableDisplayMode displayMode;
  final AppListTableSearch<T>? search;

  @override
  Widget build(BuildContext context) {
    return AppListTable<T>(
      items: page.items,
      columns: columns,
      mobileItemBuilder: mobileItemBuilder,
      itemKeyBuilder: itemKeyBuilder,
      onRowSelected: onRowSelected,
      emptyBuilder: emptyBuilder,
      loadingBuilder: loadingBuilder,
      errorBuilder: errorBuilder,
      rowColorBuilder: rowColorBuilder,
      isLoading: isLoading,
      error: error,
      shrinkWrap: shrinkWrap,
      physics: physics,
      displayMode: displayMode,
      search: search,
      footer: AppPaginationControls(
        pageRequest: page.request,
        hasPreviousPage: page.hasPreviousPage,
        hasNextPage: page.hasNextPage,
        pageLabel: pageLabelBuilder(page),
        previousPageLabel: previousPageLabel,
        nextPageLabel: nextPageLabel,
        onPageChanged: onPageChanged,
      ),
    );
  }
}

class AppSearchablePaginatedListTable<T> extends StatelessWidget {
  const AppSearchablePaginatedListTable({
    required this.page,
    required this.columns,
    required this.mobileItemBuilder,
    required this.pageLabelBuilder,
    required this.previousPageLabel,
    required this.nextPageLabel,
    required this.searchListenable,
    required this.searchMatcher,
    this.itemKeyBuilder,
    this.onRowSelected,
    this.onPageChanged,
    this.emptyBuilder,
    this.loadingBuilder,
    this.errorBuilder,
    this.rowColorBuilder,
    this.isLoading = false,
    this.error,
    this.shrinkWrap = false,
    this.physics,
    this.displayMode = AppListTableDisplayMode.adaptive,
    super.key,
  });

  final AppPage<T> page;
  final List<AppListTableColumn<T>> columns;
  final AppListTableMobileItemBuilder<T> mobileItemBuilder;
  final AppListTablePageLabelBuilder<T> pageLabelBuilder;
  final String previousPageLabel;
  final String nextPageLabel;
  final ValueListenable<String> searchListenable;
  final AppListTableSearchMatcher<T> searchMatcher;
  final AppListTableItemKeyBuilder<T>? itemKeyBuilder;
  final ValueChanged<T>? onRowSelected;
  final ValueChanged<AppPageRequest>? onPageChanged;
  final WidgetBuilder? emptyBuilder;
  final WidgetBuilder? loadingBuilder;
  final Widget Function(BuildContext context, Object error)? errorBuilder;
  final AppListTableRowColorBuilder<T>? rowColorBuilder;
  final bool isLoading;
  final Object? error;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final AppListTableDisplayMode displayMode;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: searchListenable,
      builder: (BuildContext context, String query, _) {
        final String normalizedQuery = query.trim();
        final bool isSearching = normalizedQuery.isNotEmpty;
        final AppPage<T> visiblePage = isSearching
            ? _filteredPage(normalizedQuery)
            : page;

        return AppPaginatedListTable<T>(
          page: visiblePage,
          columns: columns,
          mobileItemBuilder: mobileItemBuilder,
          pageLabelBuilder: pageLabelBuilder,
          previousPageLabel: previousPageLabel,
          nextPageLabel: nextPageLabel,
          itemKeyBuilder: itemKeyBuilder,
          onRowSelected: onRowSelected,
          onPageChanged: isSearching ? null : onPageChanged,
          emptyBuilder: emptyBuilder,
          loadingBuilder: loadingBuilder,
          errorBuilder: errorBuilder,
          rowColorBuilder: rowColorBuilder,
          isLoading: isLoading,
          error: error,
          shrinkWrap: shrinkWrap,
          physics: physics,
          displayMode: displayMode,
        );
      },
    );
  }

  AppPage<T> _filteredPage(String query) {
    final List<T> visibleItems = page.items
        .where((T item) => searchMatcher(item, query))
        .toList(growable: false);

    return AppPage<T>(
      items: visibleItems,
      request: page.request.first(),
      totalItemCount: visibleItems.length,
    );
  }
}

class AppPaginationControls extends StatelessWidget {
  const AppPaginationControls({
    required this.pageRequest,
    required this.hasPreviousPage,
    required this.hasNextPage,
    required this.pageLabel,
    required this.previousPageLabel,
    required this.nextPageLabel,
    required this.onPageChanged,
    super.key,
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
          child: itemBuilder(context, item),
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
  });

  final List<T> items;
  final List<AppListTableColumn<T>> columns;
  final AppListTableItemKeyBuilder<T>? itemKeyBuilder;
  final ValueChanged<T>? onRowSelected;
  final double minWidth;
  final AppListTableRowColorBuilder<T>? rowColorBuilder;
  final bool compact;

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
      headingRowHeight: widget.compact ? 38 : 42,
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
        for (final AppListTableColumn<T> column in widget.columns)
          DataColumn(
            numeric: column.numeric,
            tooltip: column.tooltip,
            label: column.headerBuilder?.call(context) ?? Text(column.label),
          ),
      ],
      rows: <DataRow>[
        for (final T item in widget.items)
          DataRow(
            key: widget.itemKeyBuilder?.call(item),
            color: _rowColor(context, item),
            onSelectChanged: widget.onRowSelected == null
                ? null
                : (_) {
                    widget.onRowSelected!(item);
                  },
            cells: <DataCell>[
              for (final AppListTableColumn<T> column in widget.columns)
                DataCell(column.cellBuilder(context, item)),
            ],
          ),
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
