import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/shared/components/app_button.dart';
import 'package:hosspi_hms/shared/components/app_dialog.dart';
import 'package:hosspi_hms/shared/components/app_list_table_column_layout_memory.dart';
import 'package:hosspi_hms/shared/components/app_list_table_column_visibility_memory.dart';
import 'package:hosspi_hms/shared/components/app_list_table_text_policy.dart';
import 'package:hosspi_hms/shared/components/app_loading_indicator.dart';
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

/// How [AppListTable] requests additional [AppPage] data.
///
/// [infinite] loads the next page when the user scrolls near the bottom and
/// appends rows (preferred). [buttons] keeps classic previous/next controls.
enum AppListTablePaginationMode { infinite, buttons }

const int _maxVisibleTableColumns = 5;
const int _minTableRowCount = 50;
const double _rowNumberColumnWidth = 48;
const double _mobileRowNumberColumnWidth = 28;
const double _minResizableColumnWidth = 72;
const String _defaultGoToTopLabel = 'Go to top';
const String _defaultLoadingMoreLabel = 'Loading more...';
const String _defaultAllRowsLoadedLabel = 'All rows loaded';
const Duration _goToTopAnimationDuration = Duration(milliseconds: 280);
const double _goToTopButtonExtent = 48;
const double _defaultColumnWidth = 160;
const double _defaultCompactColumnWidth = 136;
const double _columnResizeHandleWidth = 8;
const double _infiniteScrollLoadExtent = 240;

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
  String? _syncedStorageKey;
  Set<String> _syncedDefaultColumnKeys = <String>{};

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
    final Set<String> nextDefaultKeys = appListTableDefaultVisibleColumns(
      nextColumns,
      defaultColumns: columns,
    ).map((AppListTableColumn<T> column) => column.key).toSet();
    final String? resolvedStorageKey = _resolvedStorageKey(storageKey);

    final bool availableUnchanged = listEquals(currentKeys, nextKeys);
    final bool defaultsUnchanged = setEquals(
      _syncedDefaultColumnKeys,
      nextDefaultKeys,
    );
    final bool storageUnchanged = _syncedStorageKey == resolvedStorageKey;
    if (availableUnchanged && defaultsUnchanged && storageUnchanged) {
      return;
    }

    _availableColumns = nextColumns;
    _syncedDefaultColumnKeys = nextDefaultKeys;
    _syncedStorageKey = resolvedStorageKey;
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
    final Set<String> defaults = _syncedDefaultColumnKeys.isEmpty
        ? _defaultColumnKeys
        : _syncedDefaultColumnKeys;
    return !setEquals(_visibleColumnKeys, defaults);
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
    String? closeLabel,
  }) {
    final String resolvedLabel = label ?? 'Settings';
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
          closeLabel: closeLabel,
        );
      },
    );
  }

  Future<void> openColumnVisibilityDialog(
    BuildContext context, {
    String? title,
    String? applyLabel,
    String? resetLabel,
    String? closeLabel,
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
        defaultColumnKeys: _syncedDefaultColumnKeys.isEmpty
            ? _defaultColumnKeys
            : _syncedDefaultColumnKeys,
        title: title ?? 'Table columns',
        applyLabel: applyLabel ?? 'Apply columns',
        resetLabel: resetLabel ?? 'Reset columns',
        closeLabel: closeLabel ?? 'Close',
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
    this.advancedFilterCloseLabel,
    this.advancedFilterResetAppliesImmediately = false,
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
  final String? advancedFilterCloseLabel;
  final bool advancedFilterResetAppliesImmediately;
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
      advancedFilterCloseLabel: advancedFilterCloseLabel,
      advancedFilterResetAppliesImmediately:
          advancedFilterResetAppliesImmediately,
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
      // Prefer caller trailing actions (e.g. Add) ahead of table Settings.
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
    this.preferredWidth,
    this.fixedWidth,
  });

  final String? id;
  final String label;
  final AppListTableCellBuilder<T> cellBuilder;
  final bool numeric;
  final bool alwaysVisible;
  final String? tooltip;
  final AppListTableSortComparator<T>? sortComparator;
  final AppListTableHeaderBuilder<T>? headerBuilder;

  /// Optional default width before user resize; clamped like saved widths.
  final double? preferredWidth;

  /// Exact non-resizable width; bypasses the resize minimum clamp.
  final double? fixedWidth;

  String get key => id ?? label;

  bool get isSortable => sortComparator != null;
}

/// One meta fragment on the secondary line of [AppListTableMobileItem].
final class AppListTableMobileMeta {
  const AppListTableMobileMeta({required this.label, this.icon});

  final String label;
  final IconData? icon;
}

/// Compact two-line flush mobile row for [AppListTable] list layout.
///
/// Line 1: bold [title] with optional muted inline [caption] (caption truncates
/// after the title as one line).
/// Line 2: middot-joined [meta] entries (optional icons); the whole meta line
/// truncates from the end.
/// Optional [trailing] hosts a labeled next-action (or similar) without nesting
/// a second list chrome. A chevron is still added by the table when the row is
/// selectable.
class AppListTableMobileItem extends StatelessWidget {
  const AppListTableMobileItem({
    required this.title,
    this.caption,
    this.meta = const <AppListTableMobileMeta>[],
    this.leading,
    this.trailing,
    this.showAvatar = true,
    this.avatarLabel,
    this.padding,
    super.key,
  });

  final String title;
  final String? caption;
  final List<AppListTableMobileMeta> meta;
  final Widget? leading;
  final Widget? trailing;
  final bool showAvatar;
  final String? avatarLabel;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppListTokens listTokens = theme.listTokens;
    final String resolvedTitle = title.trim();
    final String? resolvedCaption = caption?.trim();
    final List<AppListTableMobileMeta> resolvedMeta = meta
        .where((AppListTableMobileMeta item) => item.label.trim().isNotEmpty)
        .toList(growable: false);
    final Widget? leadingWidget =
        leading ??
        (showAvatar
            ? _AppListTableMobileAvatar(
                label: avatarLabel?.trim().isNotEmpty == true
                    ? avatarLabel!.trim()
                    : resolvedTitle,
              )
            : null);

    return Padding(
      padding:
          padding ??
          EdgeInsets.symmetric(
            horizontal: theme.spacing.xs,
            vertical: theme.spacing.xs,
          ),
      child: Row(
        children: <Widget>[
          if (leadingWidget != null) ...<Widget>[
            leadingWidget,
            SizedBox(width: theme.spacing.xs),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text.rich(
                  TextSpan(
                    children: <InlineSpan>[
                      TextSpan(
                        text: resolvedTitle,
                        style: listTokens.mobileTitle,
                      ),
                      if (resolvedCaption != null &&
                          resolvedCaption.isNotEmpty)
                        TextSpan(
                          text: '  $resolvedCaption',
                          style: listTokens.mobileCaption,
                        ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (resolvedMeta.isNotEmpty) ...<Widget>[
                  SizedBox(height: listTokens.mobileMetaLineGap),
                  _AppListTableMobileMetaRow(items: resolvedMeta),
                ],
              ],
            ),
          ),
          if (trailing != null) ...<Widget>[
            SizedBox(width: theme.spacing.xs),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _AppListTableMobileAvatar extends StatelessWidget {
  const _AppListTableMobileAvatar({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppListTokens listTokens = theme.listTokens;
    final ColorScheme colors = theme.colorScheme;
    final String initials = _initialsFor(label);
    final Color background = _avatarTone(colors, label);
    final double size = listTokens.mobileAvatarSize;

    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: Text(initials, style: listTokens.mobileAvatarInitials),
      ),
    );
  }

  static String _initialsFor(String value) {
    final List<String> parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((String part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) {
      return '?';
    }
    if (parts.length == 1) {
      final String token = parts.first;
      return token.length >= 2
          ? token.substring(0, 2).toUpperCase()
          : token.toUpperCase();
    }
    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }

  static Color _avatarTone(ColorScheme colors, String seed) {
    final List<Color> tones = <Color>[
      colors.primaryContainer,
      colors.secondaryContainer,
      colors.tertiaryContainer,
      colors.surfaceContainerHighest,
      colors.errorContainer,
    ];
    return tones[seed.hashCode.abs() % tones.length];
  }
}

class _AppListTableMobileMetaRow extends StatelessWidget {
  const _AppListTableMobileMetaRow({required this.items});

  final List<AppListTableMobileMeta> items;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppListTokens listTokens = theme.listTokens;
    final TextStyle style = listTokens.mobileMeta;
    final Color muted =
        style.color ?? theme.colorScheme.onSurfaceVariant;
    final double iconSize = listTokens.mobileMetaIconSize;

    return Text.rich(
      TextSpan(
        style: style,
        children: <InlineSpan>[
          for (int index = 0; index < items.length; index++) ...<InlineSpan>[
            if (index > 0) const TextSpan(text: ' · '),
            if (items[index].icon != null)
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: EdgeInsetsDirectional.only(
                    end: theme.spacing.xs / 2,
                  ),
                  child: Icon(
                    items[index].icon,
                    size: iconSize,
                    color: muted,
                  ),
                ),
              ),
            TextSpan(text: items[index].label.trim()),
          ],
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
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
    this.paginationMode = AppListTablePaginationMode.infinite,
    this.emptyBuilder,
    this.loadingBuilder,
    this.errorBuilder,
    this.footer,
    this.rowColorBuilder,
    this.initialSortColumnKey,
    this.initialSortAscending = true,
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
    this.columnVisibilityCloseLabel,
    this.columnVisibilityController,
    this.columnVisibilityStorageKey,
    this.columnWidthStorageKey,
    this.enableColumnResize = true,
    this.tableHorizontalMargin,
    this.showRowNumbers = true,
    this.padEmptyRows,
    this.surfaceHeader,
    this.forceCompact = false,
    this.maxTrailingActions,
    this.trailingActionsOverflowLabel = 'More actions',
    this.goToTopLabel = _defaultGoToTopLabel,
    this.loadingMoreLabel = _defaultLoadingMoreLabel,
    this.allRowsLoadedLabel = _defaultAllRowsLoadedLabel,
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
  final AppListTablePaginationMode paginationMode;
  final WidgetBuilder? emptyBuilder;
  final WidgetBuilder? loadingBuilder;
  final Widget Function(BuildContext context, Object error)? errorBuilder;
  final Widget? footer;
  final AppListTableRowColorBuilder<T>? rowColorBuilder;
  final String? initialSortColumnKey;
  final bool initialSortAscending;
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
  final String? columnVisibilityCloseLabel;
  final AppListTableColumnVisibilityController<T>? columnVisibilityController;
  final String? columnVisibilityStorageKey;
  final String? columnWidthStorageKey;
  final bool enableColumnResize;
  final double? tableHorizontalMargin;

  /// When false, hides the leading `#` index column (desktop and mobile).
  final bool showRowNumbers;

  /// When set, overrides empty spacer-row padding. Defaults to padding only for
  /// non-infinite, non-shrink-wrapped tables without a [surfaceHeader].
  final bool? padEmptyRows;

  /// Optional chrome rendered inside the table surface above the rows; scrolls
  /// with table content when the table scrolls vertically.
  final Widget? surfaceHeader;

  /// When true, uses compact row/header metrics regardless of breakpoint.
  final bool forceCompact;
  final int? maxTrailingActions;
  final String trailingActionsOverflowLabel;
  final String goToTopLabel;
  final String loadingMoreLabel;
  final String allRowsLoadedLabel;

  @override
  State<AppListTable<T>> createState() => _AppListTableState<T>();
}

class _AppListTableState<T> extends State<AppListTable<T>> {
  Set<String> _visibleColumnKeys = <String>{};
  Map<String, double> _columnWidths = <String, double>{};
  String? _sortColumnKey;
  bool _sortAscending = true;
  int? _renderLimit;
  String _trackedQuery = '';
  int _trackedSortedItemCount = 0;
  List<T> _accumulatedItems = <T>[];
  int _accumulatedPageIndex = -1;
  bool _pendingLoadMore = false;
  ScrollPosition? _ancestorScrollPosition;
  List<T>? _cachedSortSource;
  String? _cachedSortColumnKey;
  bool? _cachedSortAscending;
  List<T>? _cachedSortedItems;
  int _lastSeenItemsLength = -1;

  @override
  void initState() {
    super.initState();
    widget.columnVisibilityController?.addListener(
      _handleColumnVisibilityChanged,
    );
    _syncVisibleColumns();
    _syncColumnWidths();
    _syncAccumulatedPage(widget.page);
    _ensureDefaultSortColumn();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reattachAncestorScrollListener();
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
    final bool columnsChanged = !_sameColumnIdentity(
      oldWidget.columns,
      widget.columns,
    );
    final List<AppListTableColumn<T>> previousChoices =
        oldWidget.columnChoices ?? <AppListTableColumn<T>>[];
    final List<AppListTableColumn<T>> nextChoices =
        widget.columnChoices ?? <AppListTableColumn<T>>[];
    final bool columnChoicesChanged = !_sameColumnIdentity(
      previousChoices,
      nextChoices,
    );
    if (columnsChanged ||
        columnChoicesChanged ||
        oldWidget.columnVisibilityController !=
            widget.columnVisibilityController ||
        oldWidget.columnVisibilityStorageKey !=
            widget.columnVisibilityStorageKey ||
        oldWidget.initialSortColumnKey != widget.initialSortColumnKey ||
        oldWidget.initialSortAscending != widget.initialSortAscending) {
      if (oldWidget.initialSortColumnKey != widget.initialSortColumnKey ||
          oldWidget.initialSortAscending != widget.initialSortAscending) {
        _sortColumnKey = null;
        _invalidateSortCache();
      }
      _syncVisibleColumns();
      _ensureDefaultSortColumn();
    }
    if (oldWidget.columnWidthStorageKey != widget.columnWidthStorageKey ||
        columnsChanged ||
        columnChoicesChanged) {
      _syncColumnWidths();
    }
    if (oldWidget.page != widget.page ||
        oldWidget.paginationMode != widget.paginationMode ||
        !identical(oldWidget.items, widget.items)) {
      _syncAccumulatedPage(widget.page);
      if (!identical(oldWidget.items, widget.items)) {
        _invalidateSortCache();
      }
    }
    if (oldWidget.isLoading && !widget.isLoading) {
      _pendingLoadMore = false;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _reattachAncestorScrollListener();
      }
    });
  }

  @override
  void dispose() {
    _detachAncestorScrollListener();
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

  bool get _usesInfinitePagination {
    return widget.paginationMode == AppListTablePaginationMode.infinite &&
        widget.page != null &&
        widget.onPageChanged != null;
  }

  void _syncAccumulatedPage(AppPage<T>? page) {
    _invalidateSortCache();
    if (!_usesInfinitePagination || page == null) {
      _accumulatedItems = page?.items ?? widget.items ?? <T>[];
      _accumulatedPageIndex = page?.pageIndex ?? -1;
      _pendingLoadMore = false;
      return;
    }

    if (page.pageIndex == 0) {
      _accumulatedItems = List<T>.of(page.items);
      _accumulatedPageIndex = 0;
      _pendingLoadMore = false;
      return;
    }

    if (page.pageIndex == _accumulatedPageIndex + 1) {
      _accumulatedItems = <T>[..._accumulatedItems, ...page.items];
      _accumulatedPageIndex = page.pageIndex;
      _pendingLoadMore = false;
      return;
    }

    if (page.pageIndex == _accumulatedPageIndex) {
      // Same page re-emitted (refresh); keep accumulated prefix and replace
      // the current page slice when possible.
      final int offset = page.request.offset;
      if (offset <= _accumulatedItems.length) {
        _accumulatedItems = <T>[
          ..._accumulatedItems.take(offset),
          ...page.items,
        ];
      } else {
        _accumulatedItems = List<T>.of(page.items);
        _accumulatedPageIndex = page.pageIndex;
      }
      _pendingLoadMore = false;
      return;
    }

    _accumulatedItems = List<T>.of(page.items);
    _accumulatedPageIndex = page.pageIndex;
    _pendingLoadMore = false;
  }

  void _syncColumnWidths() {
    final String? storageKey = _resolvedColumnWidthStorageKey();
    final Map<String, double> next = <String, double>{};
    if (storageKey != null) {
      final Map<String, double>? saved = AppListTableColumnLayoutMemory.instance
          .read(storageKey);
      if (saved != null) {
        next.addAll(saved);
      }
    }
    _columnWidths = next;
  }

  String? _resolvedColumnWidthStorageKey() {
    return widget.columnWidthStorageKey ??
        widget.columnVisibilityStorageKey ??
        appListTableColumnVisibilityStorageKey(
          widget.columns,
          widget.columnChoices,
        );
  }

  double _columnWidthFor(
    AppListTableColumn<T> column, {
    required bool compact,
  }) {
    final double? fixed = column.fixedWidth;
    if (fixed != null) {
      return fixed;
    }
    final double? saved = _columnWidths[column.key];
    if (saved != null) {
      return saved.clamp(_minResizableColumnWidth, 640);
    }
    final double? preferred = column.preferredWidth;
    if (preferred != null) {
      return preferred.clamp(_minResizableColumnWidth, 640);
    }
    if (_isActionsColumn(column)) {
      return compact ? 168.0 : 200.0;
    }
    return compact ? _defaultCompactColumnWidth : _defaultColumnWidth;
  }

  bool _isActionsColumn(AppListTableColumn<T> column) {
    final String key = column.key.trim().toLowerCase();
    final String label = column.label.trim().toLowerCase();
    return column.id == 'actions' || key == 'actions' || label == 'actions';
  }

  void _updateColumnWidth(String columnKey, double width) {
    final double nextWidth = width.clamp(_minResizableColumnWidth, 640);
    if (_columnWidths[columnKey] == nextWidth) {
      return;
    }
    setState(() {
      _columnWidths = <String, double>{..._columnWidths, columnKey: nextWidth};
    });
    final String? storageKey = _resolvedColumnWidthStorageKey();
    if (storageKey != null) {
      AppListTableColumnLayoutMemory.instance.writeWidth(
        storageKey,
        columnKey,
        nextWidth,
      );
    }
  }

  void _reattachAncestorScrollListener() {
    if (!_usesInfinitePagination && widget.maxVisibleItems == null) {
      _detachAncestorScrollListener();
      return;
    }

    final ScrollableState? scrollable = Scrollable.maybeOf(context);
    final ScrollPosition? position = scrollable?.position;
    if (identical(position, _ancestorScrollPosition)) {
      return;
    }
    _detachAncestorScrollListener();
    _ancestorScrollPosition = position;
    _ancestorScrollPosition?.addListener(_handleAncestorScroll);
  }

  void _detachAncestorScrollListener() {
    _ancestorScrollPosition?.removeListener(_handleAncestorScroll);
    _ancestorScrollPosition = null;
  }

  void _handleAncestorScroll() {
    final ScrollPosition? position = _ancestorScrollPosition;
    if (position == null || !position.hasContentDimensions) {
      return;
    }
    _handleScrollMetrics(position);
  }

  void _handleScrollMetrics(ScrollMetrics metrics) {
    if (metrics.maxScrollExtent <= 0) {
      return;
    }
    if (metrics.pixels < metrics.maxScrollExtent - _infiniteScrollLoadExtent) {
      return;
    }
    _onNearScrollEnd();
  }

  void _onNearScrollEnd() {
    final String query = _currentQuery();
    final AppPage<T>? sourcePage = widget.page;
    final List<T> sourceItems = _usesInfinitePagination
        ? _accumulatedItems
        : sourcePage?.items ?? widget.items ?? <T>[];
    final bool usesExternalSearchListenable = widget.searchListenable != null;
    List<T> visibleItems = sourceItems;
    if (query.trim().isNotEmpty) {
      final AppListTableSearchMatcher<T>? matcher = usesExternalSearchListenable
          ? widget.searchMatcher
          : widget.search?.matcher ?? widget.searchMatcher;
      if (matcher != null) {
        visibleItems = _filteredItems(sourceItems, query, matcher);
      }
    }
    final int totalSortedCount = visibleItems.length;
    if (_canRevealMoreItems(totalSortedCount)) {
      _revealMoreItems(totalSortedCount);
    }
    _maybeRequestNextPage();
  }

  String _currentQuery() {
    final AppListTableSearch<T>? search = widget.search;
    if (search != null) {
      return search.controller.text;
    }
    return widget.searchListenable?.value ?? '';
  }

  void _maybeRequestNextPage() {
    if (!_usesInfinitePagination) {
      return;
    }
    final AppPage<T>? page = widget.page;
    if (page == null) {
      return;
    }
    if (_pendingLoadMore || widget.isLoading) {
      return;
    }
    if (!page.hasNextPage) {
      return;
    }
    _pendingLoadMore = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {});
      }
    });
    widget.onPageChanged!(page.request.next());
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
    final ({
      bool disablePagination,
      List<T> items,
      int totalSortedCount,
      AppPage<T>? page,
      int rowNumberOffset,
    })
    data = _visibleData(
      query,
      usesExternalSearchListenable: usesExternalSearchListenable,
    );
    Widget content = _wrapIncrementalScroll(
      context,
      totalSortedCount: data.totalSortedCount,
      child: _buildForItems(
        context,
        data.items,
        rowNumberOffset: data.rowNumberOffset,
      ),
    );
    final ThemeData theme = Theme.of(context);
    final bool loadingMore = _isLoadingMore(data.items.length);
    if (loadingMore) {
      final ColorScheme colorScheme = theme.colorScheme;
      content = Stack(
        fit: StackFit.passthrough,
        children: <Widget>[
          content,
          Positioned(
            left: 0,
            right: 0,
            bottom: theme.spacing.sm,
            child: IgnorePointer(
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(theme.radius.md),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.45),
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: colorScheme.shadow.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: theme.spacing.md,
                      vertical: theme.spacing.sm,
                    ),
                    child: AppLoadingIndicator.compact(
                      title: widget.loadingMoreLabel,
                      expand: false,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }
    final Widget? footer = _footerForPage(
      context,
      data.page,
      disablePagination: data.disablePagination,
      visibleItemCount: data.items.length,
    );
    final Widget? toolbar = _buildToolbar(context, searchBar);

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

  bool _isLoadingMore(int visibleItemCount) {
    return (widget.isLoading || _pendingLoadMore) &&
        visibleItemCount > 0 &&
        _usesInfinitePagination;
  }

  ({
    bool disablePagination,
    List<T> items,
    int totalSortedCount,
    AppPage<T>? page,
    int rowNumberOffset,
  })
  _visibleData(String query, {required bool usesExternalSearchListenable}) {
    final AppPage<T>? sourcePage = widget.page;
    final List<T> sourceItems = _usesInfinitePagination
        ? _accumulatedItems
        : sourcePage?.items ?? widget.items ?? <T>[];
    // In-place list mutations keep the same [List] identity, so also invalidate
    // when the item count changes (empty → selected rows is the common case).
    if (sourceItems.length != _lastSeenItemsLength) {
      _lastSeenItemsLength = sourceItems.length;
      _invalidateSortCache();
    }
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
        sourcePage != null) {
      return (
        disablePagination: true,
        items: renderedItems,
        totalSortedCount: sortedItems.length,
        rowNumberOffset: 0,
        page: AppPage<T>(
          items: renderedItems,
          request: sourcePage.request.first(),
          totalItemCount: sortedItems.length,
        ),
      );
    }

    final AppPage<T>? visiblePage =
        _usesInfinitePagination && sourcePage != null
        ? AppPage<T>(
            items: renderedItems,
            request: AppPageRequest(
              pageSize: math.max(renderedItems.length, 1),
            ),
            totalItemCount: sourcePage.totalItemCount,
          )
        : sourcePage;

    final int rowNumberOffset = _usesInfinitePagination
        ? 0
        : sourcePage?.request.offset ?? 0;

    return (
      disablePagination: false,
      items: renderedItems,
      totalSortedCount: sortedItems.length,
      page: visiblePage,
      rowNumberOffset: rowNumberOffset,
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
    final bool canReveal = _canRevealMoreItems(totalSortedCount);
    final bool canLoadPage =
        _usesInfinitePagination && (widget.page?.hasNextPage ?? false);
    if (!canReveal && !canLoadPage) {
      return child;
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification notification) {
        if (notification.metrics.axis != Axis.vertical) {
          return false;
        }
        if (notification is! ScrollUpdateNotification &&
            notification is! OverscrollNotification &&
            notification is! ScrollEndNotification) {
          return false;
        }
        _handleScrollMetrics(notification.metrics);
        return false;
      },
      child: child,
    );
  }

  Widget _buildForItems(
    BuildContext context,
    List<T> visibleItems, {
    required int rowNumberOffset,
  }) {
    final Object? resolvedError = widget.error;
    if (resolvedError != null && widget.errorBuilder != null) {
      return widget.errorBuilder!(context, resolvedError);
    }

    if (appListTableShowsInitialLoading(
      isLoading: widget.isLoading,
      visibleItems: visibleItems,
    )) {
      final Widget loading =
          widget.loadingBuilder?.call(context) ??
          const _DefaultListTableLoading();
      final Widget? surfaceHeader = widget.surfaceHeader;
      if (surfaceHeader == null) {
        return loading;
      }
      return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final ThemeData theme = Theme.of(context);
          final ColorScheme colorScheme = theme.colorScheme;
          final bool canExpand =
              !widget.shrinkWrap && constraints.hasBoundedHeight;
          return Material(
            color: colorScheme.surface,
            shape: RoundedRectangleBorder(
              side: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.55),
              ),
            ),
            child: Column(
              mainAxisSize: canExpand ? MainAxisSize.max : MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                surfaceHeader,
                if (canExpand) Expanded(child: loading) else loading,
              ],
            ),
          );
        },
      );
    }

    if (visibleItems.isEmpty && widget.emptyBuilder != null) {
      final Widget empty = widget.emptyBuilder!(context);
      final Widget? surfaceHeader = widget.surfaceHeader;
      if (surfaceHeader == null) {
        return empty;
      }
      return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final ThemeData theme = Theme.of(context);
          final ColorScheme colorScheme = theme.colorScheme;
          final bool canExpand =
              !widget.shrinkWrap && constraints.hasBoundedHeight;
          return Material(
            color: colorScheme.surface,
            shape: RoundedRectangleBorder(
              side: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.55),
              ),
            ),
            child: Column(
              mainAxisSize: canExpand ? MainAxisSize.max : MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                surfaceHeader,
                if (canExpand) Expanded(child: empty) else empty,
              ],
            ),
          );
        },
      );
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool hasBoundedHeight = constraints.hasBoundedHeight;
        final bool effectiveShrinkWrap = widget.shrinkWrap || !hasBoundedHeight;
        final ScrollPhysics? effectivePhysics = hasBoundedHeight
            ? widget.physics
            : widget.physics ?? const NeverScrollableScrollPhysics();
        final List<AppListTableColumn<T>> visibleColumns = _visibleColumns;
        final bool compact =
            widget.forceCompact || _usesCompactTableLayout(constraints);
        final Map<String, double> resolvedWidths = _resolvedColumnWidths(
          constraints: constraints,
          visibleColumns: visibleColumns,
          compact: compact,
        );

        if (_usesListLayout(constraints)) {
          return _MobileListTable<T>(
            items: visibleItems,
            itemBuilder: widget.mobileItemBuilder,
            itemKeyBuilder: widget.itemKeyBuilder,
            onRowSelected: widget.onRowSelected,
            shrinkWrap: effectiveShrinkWrap,
            physics: effectivePhysics,
            rowColorBuilder: widget.rowColorBuilder,
            rowNumberOffset: rowNumberOffset,
            showRowNumbers: widget.showRowNumbers,
            surfaceHeader: widget.surfaceHeader,
            goToTopLabel: widget.goToTopLabel,
          );
        }

        final bool padEmptyRows =
            widget.padEmptyRows ??
            (!_usesInfinitePagination &&
                !effectiveShrinkWrap &&
                widget.surfaceHeader == null);

        return _DesktopListTable<T>(
          items: visibleItems,
          columns: visibleColumns,
          itemKeyBuilder: widget.itemKeyBuilder,
          onRowSelected: widget.onRowSelected,
          minWidth: constraints.hasBoundedWidth
              ? math.max(
                  constraints.maxWidth,
                  _columnsWidthTotal(resolvedWidths),
                )
              : _columnsWidthTotal(resolvedWidths),
          rowColorBuilder: widget.rowColorBuilder,
          compact: compact,
          dense: widget.forceCompact,
          horizontalMargin: widget.tableHorizontalMargin,
          sortColumnKey: _sortColumnKey,
          sortAscending: _sortAscending,
          onSort: _sortByColumn,
          rowNumberOffset: rowNumberOffset,
          showRowNumbers: widget.showRowNumbers,
          enableColumnResize: widget.enableColumnResize,
          scrollVertically: hasBoundedHeight,
          padEmptyRows: padEmptyRows,
          surfaceHeader: widget.surfaceHeader,
          goToTopLabel: widget.goToTopLabel,
          columnWidthFor: (AppListTableColumn<T> column) {
            return resolvedWidths[column.key] ??
                _columnWidthFor(column, compact: compact);
          },
          onColumnWidthChanged: widget.enableColumnResize
              ? _updateColumnWidth
              : null,
        );
      },
    );
  }

  Widget? _footerForPage(
    BuildContext context,
    AppPage<T>? visiblePage, {
    required bool disablePagination,
    required int visibleItemCount,
  }) {
    final Widget? resolvedFooter = widget.footer;
    if (resolvedFooter != null) {
      return resolvedFooter;
    }

    if (visiblePage == null) {
      return null;
    }

    final bool showButtons =
        widget.paginationMode == AppListTablePaginationMode.buttons &&
        !disablePagination;
    final AppListTablePageLabelBuilder<T>? pageLabelBuilder =
        widget.pageLabelBuilder;
    final String? previousPageLabel = widget.previousPageLabel;
    final String? nextPageLabel = widget.nextPageLabel;

    if (showButtons) {
      if (pageLabelBuilder == null ||
          previousPageLabel == null ||
          nextPageLabel == null) {
        return null;
      }
      return _AppPaginationControls(
        pageRequest: widget.page!.request,
        hasPreviousPage: widget.page!.hasPreviousPage,
        hasNextPage: widget.page!.hasNextPage,
        pageLabel: pageLabelBuilder(widget.page!),
        previousPageLabel: previousPageLabel,
        nextPageLabel: nextPageLabel,
        onPageChanged: widget.onPageChanged,
      );
    }

    final bool showInfiniteChrome =
        _usesInfinitePagination ||
        (pageLabelBuilder != null && visibleItemCount > 0);
    if (!showInfiniteChrome) {
      return null;
    }

    final bool hasMore = widget.page?.hasNextPage ?? false;
    final String? statusLabel = pageLabelBuilder == null
        ? null
        : pageLabelBuilder(visiblePage);
    final bool reachedEnd =
        _usesInfinitePagination && !hasMore && visibleItemCount > 0;

    // Load-more chrome is overlaid on the table body; footer only shows
    // status / end-of-list copy so it does not look like an extra row.
    if (statusLabel == null && !reachedEnd) {
      return null;
    }

    return _AppInfiniteScrollFooter(
      statusLabel: statusLabel,
      reachedEnd: reachedEnd,
      allRowsLoadedLabel: widget.allRowsLoadedLabel,
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

  double _columnsWidthTotal(Map<String, double> widths) {
    double total = widget.showRowNumbers ? _rowNumberColumnWidth : 0;
    for (final double width in widths.values) {
      total += width;
    }
    return total;
  }

  Map<String, double> _resolvedColumnWidths({
    required BoxConstraints constraints,
    required List<AppListTableColumn<T>> visibleColumns,
    required bool compact,
  }) {
    final Map<String, double> widths = <String, double>{
      for (final AppListTableColumn<T> column in visibleColumns)
        column.key: _columnWidthFor(column, compact: compact),
    };
    if (!constraints.hasBoundedWidth || visibleColumns.isEmpty) {
      return widths;
    }

    final ThemeData theme = Theme.of(context);
    final double horizontalMargin =
        widget.tableHorizontalMargin ??
        (widget.forceCompact
            ? theme.spacing.xs
            : compact
            ? theme.spacing.sm
            : theme.spacing.md);
    final double columnSpacing = widget.forceCompact
        ? theme.spacing.xs
        : compact
        ? theme.spacing.sm
        : theme.spacing.lg;
    final int columnCount =
        visibleColumns.length + (widget.showRowNumbers ? 1 : 0);
    final double chrome =
        (horizontalMargin * 2) +
        (columnCount > 1 ? columnSpacing * (columnCount - 1) : 0);
    final double baseTotal = _columnsWidthTotal(widths);
    final double extra = constraints.maxWidth - chrome - baseTotal;
    if (extra <= 0) {
      return widths;
    }

    AppListTableColumn<T>? expandable;
    for (final AppListTableColumn<T> column in visibleColumns.reversed) {
      if (column.fixedWidth == null) {
        expandable = column;
        break;
      }
    }
    if (expandable == null) {
      return widths;
    }
    widths[expandable.key] = widths[expandable.key]! + extra;
    return widths;
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

    // Length must be part of the cache key: callers often mutate the same
    // List instance in place (clear/addAll), which keeps [identical] true.
    if (identical(sourceItems, _cachedSortSource) &&
        _cachedSortedItems != null &&
        _cachedSortedItems!.length == sourceItems.length &&
        _cachedSortColumnKey == sortColumnKey &&
        _cachedSortAscending == _sortAscending) {
      return _cachedSortedItems!;
    }

    final List<T> sortedItems = List<T>.of(sourceItems);
    sortedItems.sort((T left, T right) {
      final int result = comparator(left, right);
      return _sortAscending ? result : -result;
    });
    _cachedSortSource = sourceItems;
    _cachedSortColumnKey = sortColumnKey;
    _cachedSortAscending = _sortAscending;
    _cachedSortedItems = sortedItems;
    return sortedItems;
  }

  void _invalidateSortCache() {
    _cachedSortSource = null;
    _cachedSortColumnKey = null;
    _cachedSortAscending = null;
    _cachedSortedItems = null;
  }

  bool _sameColumnIdentity(
    List<AppListTableColumn<T>> left,
    List<AppListTableColumn<T>> right,
  ) {
    if (identical(left, right)) {
      return true;
    }
    if (left.length != right.length) {
      return false;
    }
    for (int index = 0; index < left.length; index += 1) {
      final AppListTableColumn<T> a = left[index];
      final AppListTableColumn<T> b = right[index];
      if (a.key != b.key ||
          a.label != b.label ||
          a.isSortable != b.isSortable ||
          a.alwaysVisible != b.alwaysVisible ||
          a.numeric != b.numeric) {
        return false;
      }
    }
    return true;
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

    final String? preferredKey = widget.initialSortColumnKey;
    if (preferredKey != null) {
      final AppListTableColumn<T>? preferred = _columnByKey(
        _visibleColumns,
        preferredKey,
      );
      if (preferred != null && preferred.isSortable) {
        _sortColumnKey = preferred.key;
        _sortAscending = widget.initialSortAscending;
        return;
      }
    }

    for (final AppListTableColumn<T> column in _visibleColumns) {
      if (column.isSortable) {
        _sortColumnKey = column.key;
        _sortAscending = widget.initialSortAscending;
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
      // Keep prior cache until the next _sortedItems call rebuilds it for the
      // new direction/column; clear so we never show a stale order.
      _invalidateSortCache();
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
        closeLabel: widget.columnVisibilityCloseLabel,
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
        closeLabel: widget.columnVisibilityCloseLabel ?? 'Close',
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
    return widget.columnVisibilityLabel ?? 'Settings';
  }

  Set<String> _withAlwaysVisibleColumnKeys(Set<String> keys) {
    return <String>{
      ...keys,
      for (final AppListTableColumn<T> column in _availableColumns)
        if (column.alwaysVisible) column.key,
    };
  }
}

final RegExp _whitespaceRun = RegExp(r'\s+');

String _normalizeTableSearchQuery(String query) {
  return query.trim().replaceAll(_whitespaceRun, ' ');
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
    required this.closeLabel,
  });

  final List<AppListTableColumn<T>> columns;
  final Set<String> visibleColumnKeys;
  final Set<String> defaultColumnKeys;
  final String title;
  final String applyLabel;
  final String resetLabel;
  final String closeLabel;

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
        AppButton.tertiary(
          label: widget.closeLabel,
          leadingIcon: Icons.close,
          onPressed: () => Navigator.of(context).pop(),
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

class _AppInfiniteScrollFooter extends StatelessWidget {
  const _AppInfiniteScrollFooter({
    required this.statusLabel,
    required this.reachedEnd,
    required this.allRowsLoadedLabel,
  });

  final String? statusLabel;
  final bool reachedEnd;
  final String allRowsLoadedLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.only(top: theme.spacing.xs, bottom: theme.spacing.sm),
      child: Row(
        children: <Widget>[
          if (statusLabel != null)
            Expanded(
              child: Text(
                statusLabel!,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          else
            const Spacer(),
          if (reachedEnd)
            Text(
              allRowsLoadedLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
              ),
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
    this.rowNumberOffset = 0,
    this.showRowNumbers = true,
    this.surfaceHeader,
    this.goToTopLabel = _defaultGoToTopLabel,
  });

  final List<T> items;
  final AppListTableMobileItemBuilder<T> itemBuilder;
  final AppListTableItemKeyBuilder<T>? itemKeyBuilder;
  final ValueChanged<T>? onRowSelected;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final AppListTableRowColorBuilder<T>? rowColorBuilder;
  final int rowNumberOffset;
  final bool showRowNumbers;
  final Widget? surfaceHeader;
  final String goToTopLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return _GoToTopHost(
      label: goToTopLabel,
      headerExtent: 56,
      builder: (BuildContext context, Key headerKey) {
        return ListView.separated(
          itemCount: items.length + (surfaceHeader == null ? 0 : 1),
          shrinkWrap: shrinkWrap,
          physics: physics,
          itemBuilder: (BuildContext context, int index) {
            if (surfaceHeader != null && index == 0) {
              return KeyedSubtree(key: headerKey, child: surfaceHeader!);
            }
            final int itemIndex = surfaceHeader == null ? index : index - 1;
            final T item = items[itemIndex];
            Widget row = KeyedSubtree(
              key: appListTableUniqueRowKey<T>(
                index: itemIndex,
                itemKeyBuilder: itemKeyBuilder,
                item: item,
              ),
              child: showRowNumbers
                  ? _NumberedMobileListItem(
                      number: rowNumberOffset + itemIndex + 1,
                      child: itemBuilder(context, item),
                    )
                  : itemBuilder(context, item),
            );

            if (onRowSelected != null) {
              row = _SelectableMobileDataRow<T>(
                item: item,
                onSelected: onRowSelected!,
                child: row,
              );
            }

            final Color? rowColor = rowColorBuilder?.call(context, item);
            if (rowColor != null) {
              row = ColoredBox(color: rowColor, child: row);
            }

            if (surfaceHeader == null && itemIndex == 0) {
              row = KeyedSubtree(key: headerKey, child: row);
            }
            return row;
          },
          separatorBuilder: (BuildContext context, int index) {
            if (surfaceHeader != null && index == 0) {
              return Divider(
                height: 1,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              );
            }
            return Divider(
              height: 1,
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            );
          },
        );
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

    return Row(
      children: <Widget>[
        SizedBox(
          width: _mobileRowNumberColumnWidth,
          child: Text(
            number.toString(),
            textAlign: TextAlign.center,
            style: theme.listTokens.mobileRowNumber,
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
            child: Builder(
              builder: (BuildContext context) {
                final ThemeData theme = Theme.of(context);
                return Row(
                  children: <Widget>[
                    Expanded(child: child),
                    Padding(
                      padding: EdgeInsetsDirectional.only(
                        end: theme.spacing.xs,
                      ),
                      child: Icon(
                        Icons.chevron_right,
                        color: theme.colorScheme.onSurfaceVariant,
                        size: theme.listTokens.mobileChevronSize,
                      ),
                    ),
                  ],
                );
              },
            ),
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
    this.dense = false,
    this.horizontalMargin,
    required this.sortColumnKey,
    required this.sortAscending,
    required this.onSort,
    this.rowNumberOffset = 0,
    this.showRowNumbers = true,
    this.enableColumnResize = true,
    this.scrollVertically = false,
    this.padEmptyRows = true,
    this.surfaceHeader,
    this.goToTopLabel = _defaultGoToTopLabel,
    required this.columnWidthFor,
    this.onColumnWidthChanged,
  });

  final List<T> items;
  final List<AppListTableColumn<T>> columns;
  final AppListTableItemKeyBuilder<T>? itemKeyBuilder;
  final ValueChanged<T>? onRowSelected;
  final double minWidth;
  final AppListTableRowColorBuilder<T>? rowColorBuilder;
  final bool compact;
  final bool dense;
  final double? horizontalMargin;
  final String? sortColumnKey;
  final bool sortAscending;
  final ValueChanged<AppListTableColumn<T>> onSort;
  final int rowNumberOffset;
  final bool showRowNumbers;
  final bool enableColumnResize;
  /// When true, vertical scroll is nested inside horizontal scroll so the
  /// bottom horizontal scrollbar stays fixed above the table footer.
  final bool scrollVertically;
  /// When false, do not pad the table with blank numbered spacer rows.
  final bool padEmptyRows;
  final Widget? surfaceHeader;
  final String goToTopLabel;
  final double Function(AppListTableColumn<T> column) columnWidthFor;
  final void Function(String columnKey, double width)? onColumnWidthChanged;

  @override
  State<_DesktopListTable<T>> createState() => _DesktopListTableState<T>();
}

class _DesktopListTableState<T> extends State<_DesktopListTable<T>> {
  late final ScrollController _horizontalController;
  late final ScrollController _verticalController;

  double get _headingRowHeight {
    if (widget.dense) {
      return 32;
    }
    return widget.compact ? 44 : 48;
  }

  @override
  void initState() {
    super.initState();
    _horizontalController = ScrollController();
    _verticalController = ScrollController();
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final double horizontalMargin =
        widget.horizontalMargin ??
        (widget.dense
            ? theme.spacing.xs
            : widget.compact
            ? theme.spacing.sm
            : theme.spacing.md);
    final double columnSpacing = widget.dense
        ? theme.spacing.xs
        : widget.compact
        ? theme.spacing.sm
        : theme.spacing.lg;
    // Rows grow with wrapped cell content; min height keeps comfortable padding.
    final double rowMinHeight = widget.dense
        ? 44
        : widget.compact
        ? 48
        : 52;
    const double rowMaxHeight = double.infinity;
    final int minRowCount = widget.padEmptyRows
        ? _minTableRowCount
        : widget.items.length;
    final bool showRowNumbers = widget.showRowNumbers;

    _resolveTableStyles(theme);

    return Material(
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: _GoToTopHost(
        label: widget.goToTopLabel,
        headerExtent: _headingRowHeight,
        builder: (BuildContext context, Key headerKey) {
          final Widget table = DataTable(
            showCheckboxColumn: false,
            horizontalMargin: horizontalMargin,
            columnSpacing: columnSpacing,
            headingRowHeight: _headingRowHeight,
            dataRowMinHeight: rowMinHeight,
            dataRowMaxHeight: rowMaxHeight,
            headingRowColor: _cachedHeadingRowColor,
            dividerThickness: theme.appTokens.dividerThickness,
            headingTextStyle: _cachedHeadingTextStyle,
            dataTextStyle: _cachedDataTextStyle,
            border: TableBorder(
              verticalInside: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.38),
                width: theme.appTokens.dividerThickness,
              ),
            ),
            columns: <DataColumn>[
              if (showRowNumbers)
                DataColumn(
                  numeric: true,
                  label: SizedBox(
                    width: _rowNumberColumnWidth,
                    child: Text(
                      '#',
                      textAlign: TextAlign.center,
                      style: _cachedNumberColumnStyle,
                    ),
                  ),
                ),
              for (final AppListTableColumn<T> column in widget.columns)
                DataColumn(
                  numeric: column.numeric,
                  tooltip: column.tooltip,
                  label: _DataColumnHeader<T>(
                    column: column,
                    isSorted: widget.sortColumnKey == column.key,
                    sortAscending: widget.sortAscending,
                    onSort: widget.onSort,
                    width: widget.columnWidthFor(column),
                    enableResize:
                        widget.enableColumnResize && column.fixedWidth == null,
                    onWidthChanged:
                        widget.onColumnWidthChanged == null ||
                            column.fixedWidth != null
                        ? null
                        : (double width) {
                            widget.onColumnWidthChanged!(column.key, width);
                          },
                  ),
                ),
            ],
            rows: <DataRow>[
              for (var index = 0; index < widget.items.length; index += 1)
                _dataRow(context, index),
              for (
                var index = widget.items.length;
                index < minRowCount;
                index += 1
              )
                _emptyRow(context, index),
            ],
          );

          final Widget? surfaceHeader = widget.surfaceHeader;
          final bool scrollWithHeader = surfaceHeader != null;

          if (widget.scrollVertically) {
            return LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double tableWidth = math.max(
                  widget.minWidth,
                  constraints.maxWidth,
                );
                final Widget horizontalTable = Scrollbar(
                  controller: _horizontalController,
                  thumbVisibility: true,
                  scrollbarOrientation: ScrollbarOrientation.bottom,
                  notificationPredicate: (ScrollNotification notification) {
                    return notification.metrics.axis == Axis.horizontal;
                  },
                  child: SingleChildScrollView(
                    controller: _horizontalController,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(width: tableWidth, child: table),
                  ),
                );

                if (scrollWithHeader) {
                  return Scrollbar(
                    controller: _verticalController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _verticalController,
                      child: KeyedSubtree(
                        key: headerKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            surfaceHeader,
                            horizontalTable,
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return Scrollbar(
                  controller: _horizontalController,
                  thumbVisibility: true,
                  scrollbarOrientation: ScrollbarOrientation.bottom,
                  notificationPredicate: (ScrollNotification notification) {
                    return notification.metrics.axis == Axis.horizontal;
                  },
                  child: SingleChildScrollView(
                    controller: _horizontalController,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: tableWidth,
                      height: constraints.maxHeight,
                      child: Scrollbar(
                        controller: _verticalController,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: _verticalController,
                          child: KeyedSubtree(key: headerKey, child: table),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          }

          final Widget horizontalTable = Scrollbar(
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

          if (scrollWithHeader) {
            return KeyedSubtree(
              key: headerKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[surfaceHeader, horizontalTable],
              ),
            );
          }

          return KeyedSubtree(key: headerKey, child: horizontalTable);
        },
      ),
    );
  }

  ColorScheme? _cachedTableStyleScheme;
  WidgetStatePropertyAll<Color>? _cachedHeadingRowColor;
  TextStyle? _cachedHeadingTextStyle;
  TextStyle? _cachedDataTextStyle;
  TextStyle? _cachedNumberColumnStyle;

  void _resolveTableStyles(ThemeData theme) {
    final ColorScheme cs = theme.colorScheme;
    if (identical(_cachedTableStyleScheme, cs)) {
      return;
    }
    _cachedTableStyleScheme = cs;
    _cachedHeadingRowColor = WidgetStatePropertyAll<Color>(
      cs.surfaceContainerHigh.withValues(alpha: 0.72),
    );
    _cachedHeadingTextStyle = theme.textTheme.labelLarge?.copyWith(
      color: cs.onSurfaceVariant,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.1,
    );
    _cachedDataTextStyle = theme.textTheme.bodyMedium?.copyWith(
      color: cs.onSurface,
      fontWeight: FontWeight.w500,
    );
    _cachedNumberColumnStyle = theme.textTheme.labelMedium?.copyWith(
      color: cs.onSurfaceVariant,
      fontWeight: FontWeight.w700,
    );
    _rowNumberStyle = null;
  }

  TextStyle? _rowNumberStyle;

  TextStyle? _resolveRowNumberStyle(ThemeData theme) {
    if (_rowNumberStyle != null &&
        identical(_cachedTableStyleScheme, theme.colorScheme)) {
      return _rowNumberStyle;
    }
    _rowNumberStyle = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    return _rowNumberStyle;
  }

  DataRow _dataRow(BuildContext context, int index) {
    final T item = widget.items[index];

    return DataRow(
      key: appListTableUniqueRowKey<T>(
        index: index,
        itemKeyBuilder: widget.itemKeyBuilder,
        item: item,
      ),
      color: _rowColor(context, item, index),
      onSelectChanged: widget.onRowSelected == null
          ? null
          : (_) {
              widget.onRowSelected!(item);
            },
      cells: <DataCell>[
        if (widget.showRowNumbers)
          DataCell(
            _DesktopRowKeyboardActivator(
              enabled: widget.onRowSelected != null,
              onActivate: () => widget.onRowSelected?.call(item),
              child: Align(
                child: SizedBox(
                  width: _rowNumberColumnWidth,
                  child: Text(
                    (widget.rowNumberOffset + index + 1).toString(),
                    textAlign: TextAlign.center,
                    style: _resolveRowNumberStyle(Theme.of(context)),
                  ),
                ),
              ),
            ),
          ),
        for (final AppListTableColumn<T> column in widget.columns)
          DataCell(
            _AppListTableCell(
              width: widget.columnWidthFor(column),
              numeric: column.numeric,
              child: column.cellBuilder(context, item),
            ),
          ),
      ],
    );
  }

  DataRow _emptyRow(BuildContext context, int index) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Color? stripe = index.isOdd
        ? colorScheme.surfaceContainerLowest.withValues(alpha: 0.65)
        : null;

    return DataRow(
      key: ValueKey<int>(index),
      color: stripe == null ? null : WidgetStatePropertyAll<Color>(stripe),
      cells: <DataCell>[
        if (widget.showRowNumbers)
          DataCell(
            Align(
              child: SizedBox(
                width: _rowNumberColumnWidth,
                child: Text(
                  (widget.rowNumberOffset + index + 1).toString(),
                  textAlign: TextAlign.center,
                  style: _resolveRowNumberStyle(theme),
                ),
              ),
            ),
          ),
        for (final AppListTableColumn<T> column in widget.columns)
          DataCell(SizedBox(width: widget.columnWidthFor(column))),
      ],
    );
  }

  WidgetStateProperty<Color?>? _cachedDefaultRowColor;
  ColorScheme? _cachedRowColorScheme;

  WidgetStateProperty<Color?> _defaultRowColor(ColorScheme colorScheme) {
    if (_cachedDefaultRowColor != null &&
        identical(_cachedRowColorScheme, colorScheme)) {
      return _cachedDefaultRowColor!;
    }
    _cachedRowColorScheme = colorScheme;
    _cachedDefaultRowColor = WidgetStateProperty.resolveWith<Color?>((
      Set<WidgetState> states,
    ) {
      if (states.contains(WidgetState.hovered)) {
        return colorScheme.primary.withValues(alpha: 0.05);
      }
      if (states.contains(WidgetState.selected)) {
        return colorScheme.primary.withValues(alpha: 0.08);
      }
      return null;
    });
    return _cachedDefaultRowColor!;
  }

  WidgetStateProperty<Color?>? _rowColor(
    BuildContext context,
    T item,
    int index,
  ) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final AppListTableRowColorBuilder<T>? builder = widget.rowColorBuilder;
    final Color? custom = builder?.call(context, item);
    final Color? stripe = index.isOdd
        ? colorScheme.surfaceContainerLowest.withValues(alpha: 0.65)
        : null;
    final Color? base = custom ?? stripe;
    if (base == null) {
      return _defaultRowColor(colorScheme);
    }

    return WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
      Color color = base;
      if (states.contains(WidgetState.hovered)) {
        color = Color.alphaBlend(
          colorScheme.primary.withValues(alpha: 0.06),
          color,
        );
      }
      if (states.contains(WidgetState.selected)) {
        color = Color.alphaBlend(
          colorScheme.primary.withValues(alpha: 0.08),
          color,
        );
      }
      return color;
    });
  }
}

/// Constrains cell content to the column width so text wraps and the row can
/// grow with the tallest cell.
///
/// Long labels keep their natural font size and wrap inside the column instead
/// of being shrunk by [FittedBox] or clipped to a fixed line count.
class _AppListTableCell extends StatelessWidget {
  const _AppListTableCell({
    required this.width,
    required this.numeric,
    required this.child,
  });

  final double width;
  final bool numeric;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle style = DefaultTextStyle.of(context).style;
    // Tight width so text wraps at the column edge; row height then follows
    // the tallest cell via DataTable's unbounded dataRowMaxHeight.
    return SizedBox(
      width: width,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: theme.spacing.sm),
        child: AppListTableTextPolicy(
          child: DefaultTextStyle(
            style: style,
            overflow: TextOverflow.visible,
            textAlign: numeric ? TextAlign.right : TextAlign.start,
            child: _AppListTableWrappingScope(child: child),
          ),
        ),
      ),
    );
  }
}

/// Rewrites nested [Text]/[RichText] so explicit maxLines/ellipsis in cell
/// builders cannot prevent wrapping inside the table.
class _AppListTableWrappingScope extends StatelessWidget {
  const _AppListTableWrappingScope({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => _enableCellTextWrapping(child);
}

Widget _enableCellTextWrapping(Widget widget) {
  if (widget is Text) {
    return Text.rich(
      widget.textSpan ?? TextSpan(text: widget.data, style: widget.style),
      key: widget.key,
      style: widget.style,
      strutStyle: widget.strutStyle,
      textAlign: widget.textAlign,
      textDirection: widget.textDirection,
      locale: widget.locale,
      overflow: TextOverflow.visible,
      textScaler: widget.textScaler,
      semanticsLabel: widget.semanticsLabel,
      textWidthBasis: widget.textWidthBasis,
      textHeightBehavior: widget.textHeightBehavior,
      selectionColor: widget.selectionColor,
    );
  }

  if (widget is RichText) {
    return RichText(
      key: widget.key,
      text: widget.text,
      textAlign: widget.textAlign,
      textDirection: widget.textDirection,
      overflow: TextOverflow.visible,
      textScaler: widget.textScaler,
      locale: widget.locale,
      strutStyle: widget.strutStyle,
      textWidthBasis: widget.textWidthBasis,
      textHeightBehavior: widget.textHeightBehavior,
      selectionColor: widget.selectionColor,
    );
  }

  if (widget is Padding) {
    final Widget? child = widget.child;
    if (child == null) {
      return widget;
    }
    return Padding(
      key: widget.key,
      padding: widget.padding,
      child: _enableCellTextWrapping(child),
    );
  }

  if (widget is Align) {
    final Widget? child = widget.child;
    if (child == null) {
      return widget;
    }
    return Align(
      key: widget.key,
      alignment: widget.alignment,
      widthFactor: widget.widthFactor,
      heightFactor: widget.heightFactor,
      child: _enableCellTextWrapping(child),
    );
  }

  if (widget is SizedBox) {
    final Widget? child = widget.child;
    if (child == null) {
      return widget;
    }
    return SizedBox(
      key: widget.key,
      width: widget.width,
      height: widget.height,
      child: _enableCellTextWrapping(child),
    );
  }

  if (widget is ConstrainedBox) {
    final Widget? child = widget.child;
    if (child == null) {
      return widget;
    }
    return ConstrainedBox(
      key: widget.key,
      constraints: widget.constraints,
      child: _enableCellTextWrapping(child),
    );
  }

  if (widget is ColoredBox) {
    final Widget? child = widget.child;
    if (child == null) {
      return widget;
    }
    return ColoredBox(
      key: widget.key,
      color: widget.color,
      child: _enableCellTextWrapping(child),
    );
  }

  if (widget is DecoratedBox) {
    final Widget? child = widget.child;
    if (child == null) {
      return widget;
    }
    return DecoratedBox(
      key: widget.key,
      decoration: widget.decoration,
      position: widget.position,
      child: _enableCellTextWrapping(child),
    );
  }

  if (widget is Flexible) {
    return Flexible(
      key: widget.key,
      flex: widget.flex,
      fit: widget.fit,
      child: _enableCellTextWrapping(widget.child),
    );
  }

  if (widget is Expanded) {
    return Expanded(
      key: widget.key,
      flex: widget.flex,
      child: _enableCellTextWrapping(widget.child),
    );
  }

  if (widget is Column) {
    return Column(
      key: widget.key,
      mainAxisAlignment: widget.mainAxisAlignment,
      mainAxisSize: widget.mainAxisSize,
      crossAxisAlignment: widget.crossAxisAlignment,
      textDirection: widget.textDirection,
      verticalDirection: widget.verticalDirection,
      textBaseline: widget.textBaseline,
      children: widget.children.map(_enableCellTextWrapping).toList(),
    );
  }

  if (widget is Row) {
    return Row(
      key: widget.key,
      mainAxisAlignment: widget.mainAxisAlignment,
      mainAxisSize: widget.mainAxisSize,
      crossAxisAlignment: widget.crossAxisAlignment == CrossAxisAlignment.center
          ? CrossAxisAlignment.start
          : widget.crossAxisAlignment,
      textDirection: widget.textDirection,
      verticalDirection: widget.verticalDirection,
      textBaseline: widget.textBaseline,
      children: widget.children.map(_enableCellTextWrapping).toList(),
    );
  }

  if (widget is Wrap) {
    return Wrap(
      key: widget.key,
      direction: widget.direction,
      alignment: widget.alignment,
      spacing: widget.spacing,
      runAlignment: widget.runAlignment,
      runSpacing: widget.runSpacing,
      crossAxisAlignment: widget.crossAxisAlignment,
      textDirection: widget.textDirection,
      verticalDirection: widget.verticalDirection,
      clipBehavior: widget.clipBehavior,
      children: widget.children.map(_enableCellTextWrapping).toList(),
    );
  }

  if (widget is GestureDetector) {
    final Widget? child = widget.child;
    if (child == null) {
      return widget;
    }
    return GestureDetector(
      key: widget.key,
      onTap: widget.onTap,
      onTapDown: widget.onTapDown,
      onTapUp: widget.onTapUp,
      onTapCancel: widget.onTapCancel,
      onSecondaryTap: widget.onSecondaryTap,
      onSecondaryTapDown: widget.onSecondaryTapDown,
      onSecondaryTapUp: widget.onSecondaryTapUp,
      onSecondaryTapCancel: widget.onSecondaryTapCancel,
      onDoubleTap: widget.onDoubleTap,
      onLongPress: widget.onLongPress,
      onLongPressStart: widget.onLongPressStart,
      onLongPressMoveUpdate: widget.onLongPressMoveUpdate,
      onLongPressUp: widget.onLongPressUp,
      onLongPressEnd: widget.onLongPressEnd,
      behavior: widget.behavior,
      excludeFromSemantics: widget.excludeFromSemantics,
      child: _enableCellTextWrapping(child),
    );
  }

  return widget;
}

class _DesktopRowKeyboardActivator extends StatefulWidget {
  const _DesktopRowKeyboardActivator({
    required this.enabled,
    required this.onActivate,
    required this.child,
  });


  final bool enabled;
  final VoidCallback onActivate;
  final Widget child;

  @override
  State<_DesktopRowKeyboardActivator> createState() =>
      _DesktopRowKeyboardActivatorState();
}

class _DesktopRowKeyboardActivatorState
    extends State<_DesktopRowKeyboardActivator> {
  static const Map<ShortcutActivator, Intent> _shortcuts =
      <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      };

  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return FocusableActionDetector(
      enabled: widget.enabled,
      shortcuts: _shortcuts,
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onActivate();
            return null;
          },
        ),
      },
      onShowFocusHighlight: (bool value) {
        if (_focused != value) {
          setState(() => _focused = value);
        }
      },
      child: Semantics(
        button: widget.enabled,
        enabled: widget.enabled,
        onTap: widget.enabled ? widget.onActivate : null,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: _focused
                ? Border.all(color: theme.colorScheme.primary)
                : null,
            borderRadius: BorderRadius.circular(theme.radius.xs),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class _DataColumnHeader<T> extends StatelessWidget {
  const _DataColumnHeader({
    required this.column,
    required this.isSorted,
    required this.sortAscending,
    required this.onSort,
    required this.width,
    required this.enableResize,
    this.onWidthChanged,
  });

  final AppListTableColumn<T> column;
  final bool isSorted;
  final bool sortAscending;
  final ValueChanged<AppListTableColumn<T>> onSort;
  final double width;
  final bool enableResize;
  final ValueChanged<double>? onWidthChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextStyle? headerStyle = theme.textTheme.labelLarge?.copyWith(
      color: isSorted ? colorScheme.primary : colorScheme.onSurfaceVariant,
      fontWeight: isSorted ? FontWeight.w700 : FontWeight.w600,
    );

    Widget label;
    if (!column.isSortable) {
      final AppListTableHeaderBuilder<T>? headerBuilder = column.headerBuilder;
      if (headerBuilder != null) {
        label = headerBuilder(context);
      } else {
        label = Text(
          column.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: headerStyle,
        );
      }
    } else {
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

      label = Tooltip(
        message: tooltip,
        child: Semantics(
          button: true,
          selected: isSorted,
          label: tooltip,
          child: InkWell(
            onTap: () {
              onSort(column);
            },
            borderRadius: BorderRadius.circular(theme.radius.sm),
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
                  children: <Widget>[
                    Expanded(
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
      );
    }

    return SizedBox(
      width: width,
      child: Row(
        children: <Widget>[
          Expanded(child: label),
          if (enableResize && onWidthChanged != null)
            _ColumnResizeHandle(width: width, onWidthChanged: onWidthChanged!),
        ],
      ),
    );
  }
}

class _ColumnResizeHandle extends StatefulWidget {
  const _ColumnResizeHandle({
    required this.width,
    required this.onWidthChanged,
  });

  final double width;
  final ValueChanged<double> onWidthChanged;

  @override
  State<_ColumnResizeHandle> createState() => _ColumnResizeHandleState();
}

class _ColumnResizeHandleState extends State<_ColumnResizeHandle> {
  double? _dragWidth;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) {
          _dragWidth = widget.width;
        },
        onHorizontalDragUpdate: (DragUpdateDetails details) {
          final double next = (_dragWidth ?? widget.width) + details.delta.dx;
          _dragWidth = next;
          widget.onWidthChanged(next);
        },
        onHorizontalDragEnd: (_) {
          _dragWidth = null;
        },
        onHorizontalDragCancel: () {
          _dragWidth = null;
        },
        child: Semantics(
          label: 'Resize column',
          slider: true,
          child: SizedBox(
            width: _columnResizeHandleWidth,
            child: Center(
              child: Container(
                width: 2,
                height: 18,
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoToTopHost extends StatefulWidget {
  const _GoToTopHost({
    required this.label,
    required this.headerExtent,
    required this.builder,
  });

  final String label;
  final double headerExtent;
  final Widget Function(BuildContext context, Key headerKey) builder;

  @override
  State<_GoToTopHost> createState() => _GoToTopHostState();
}

class _GoToTopHostState extends State<_GoToTopHost> {
  final GlobalKey _headerKey = GlobalKey(debugLabel: 'appListTableHeader');
  OverlayEntry? _overlayEntry;
  ScrollPosition? _trackedPosition;
  bool _headerHidden = false;
  bool _visibilityCheckScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _reattachScrollPosition();
        _scheduleVisibilityCheck();
      }
    });
  }

  @override
  void dispose() {
    _detachScrollPosition();
    _removeOverlay();
    super.dispose();
  }

  void _scheduleVisibilityCheck() {
    if (_visibilityCheckScheduled) {
      return;
    }
    _visibilityCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _visibilityCheckScheduled = false;
      if (!mounted) {
        return;
      }
      _reattachScrollPosition();
      _syncVisibility();
    });
  }

  void _reattachScrollPosition() {
    final BuildContext? headerContext = _headerKey.currentContext;
    final ScrollPosition? position = headerContext == null
        ? null
        : Scrollable.maybeOf(headerContext)?.position;
    if (identical(position, _trackedPosition)) {
      return;
    }
    _detachScrollPosition();
    _trackedPosition = position;
    _trackedPosition?.addListener(_scheduleVisibilityCheck);
  }

  void _detachScrollPosition() {
    _trackedPosition?.removeListener(_scheduleVisibilityCheck);
    _trackedPosition = null;
  }

  bool _isHeaderHidden() {
    final BuildContext? headerContext = _headerKey.currentContext;
    if (headerContext == null) {
      return false;
    }
    final RenderObject? headerRender = headerContext.findRenderObject();
    if (headerRender == null || !headerRender.attached) {
      return false;
    }

    final ScrollableState? scrollable = Scrollable.maybeOf(headerContext);
    final ScrollPosition? position = scrollable?.position;
    if (position == null || !position.hasPixels) {
      return false;
    }

    final RenderAbstractViewport? viewport = RenderAbstractViewport.maybeOf(
      headerRender,
    );
    if (viewport != null) {
      final RevealedOffset revealed = viewport.getOffsetToReveal(
        headerRender,
        0,
      );
      // Headers are hidden as soon as their top edge leaves the viewport top.
      return position.pixels > revealed.offset + 0.5;
    }

    return position.pixels > widget.headerExtent;
  }

  Rect? _viewportRectInOverlay(BuildContext overlayContext) {
    final BuildContext? headerContext = _headerKey.currentContext;
    if (headerContext == null) {
      return null;
    }
    final ScrollableState? scrollable = Scrollable.maybeOf(headerContext);
    if (scrollable == null) {
      return null;
    }
    final RenderObject? viewportRender = scrollable.context.findRenderObject();
    final RenderObject? overlayRender = overlayContext.findRenderObject();
    if (viewportRender is! RenderBox ||
        overlayRender is! RenderBox ||
        !viewportRender.hasSize) {
      return null;
    }
    final Offset topLeft = overlayRender.globalToLocal(
      viewportRender.localToGlobal(Offset.zero),
    );
    return topLeft & viewportRender.size;
  }

  void _syncVisibility() {
    final bool nextHidden = _isHeaderHidden();
    if (nextHidden == _headerHidden && _overlayEntry != null) {
      _overlayEntry!.markNeedsBuild();
      return;
    }
    _headerHidden = nextHidden;
    if (!_headerHidden) {
      _removeOverlay();
      return;
    }
    _ensureOverlay();
    _overlayEntry?.markNeedsBuild();
  }

  void _ensureOverlay() {
    if (_overlayEntry != null) {
      return;
    }
    final OverlayState? overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      return;
    }
    _overlayEntry = OverlayEntry(builder: _buildOverlay);
    overlay.insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Future<void> _goToTop() async {
    final BuildContext? headerContext = _headerKey.currentContext;
    if (headerContext == null) {
      return;
    }
    final ScrollableState? scrollable = Scrollable.maybeOf(headerContext);
    final ScrollPosition? position = scrollable?.position;
    if (position != null && position.hasPixels) {
      await position.animateTo(
        0,
        duration: _goToTopAnimationDuration,
        curve: Curves.easeOutCubic,
      );
    } else {
      await Scrollable.ensureVisible(
        headerContext,
        duration: _goToTopAnimationDuration,
        curve: Curves.easeOutCubic,
      );
    }
    _scheduleVisibilityCheck();
  }

  Widget _buildOverlay(BuildContext overlayContext) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    if (!_headerHidden) {
      return const SizedBox.shrink();
    }

    final Rect? viewportRect = _viewportRectInOverlay(overlayContext);
    final Widget button = Material(
      elevation: 3,
      color: colorScheme.surfaceContainerHighest,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        tooltip: widget.label,
        onPressed: _goToTop,
        icon: Icon(
          Icons.vertical_align_top,
          color: colorScheme.onSurfaceVariant,
        ),
        style: IconButton.styleFrom(
          backgroundColor: colorScheme.surfaceContainerHighest,
          foregroundColor: colorScheme.onSurfaceVariant,
        ),
      ),
    );

    if (viewportRect == null) {
      return Positioned(
        right: theme.spacing.md,
        bottom: theme.spacing.xl,
        child: button,
      );
    }

    return Positioned(
      left: viewportRect.right - _goToTopButtonExtent - theme.spacing.md,
      top: viewportRect.bottom - _goToTopButtonExtent - theme.spacing.xl,
      child: button,
    );
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification notification) {
        if (notification.metrics.axis != Axis.vertical) {
          return false;
        }
        if (notification is ScrollUpdateNotification ||
            notification is ScrollEndNotification ||
            notification is OverscrollNotification) {
          _scheduleVisibilityCheck();
        }
        return false;
      },
      child: widget.builder(context, _headerKey),
    );
  }
}

class _DefaultListTableLoading extends StatelessWidget {
  const _DefaultListTableLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: AppLoadingIndicator.compact(),
    );
  }
}
