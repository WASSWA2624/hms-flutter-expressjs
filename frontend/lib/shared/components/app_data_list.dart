import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/responsive/app_breakpoints.dart';
import 'package:hosspi_hms/shared/components/app_icon_button.dart';
import 'package:hosspi_hms/shared/data/data.dart';

typedef AppDataCellBuilder<T> = Widget Function(BuildContext context, T item);
typedef AppDataMobileItemBuilder<T> =
    Widget Function(BuildContext context, T item);
typedef AppDataItemKeyBuilder<T> = LocalKey Function(T item);
typedef AppDataPageLabelBuilder<T> = String Function(AppPage<T> page);
typedef AppDataRowColorBuilder<T> =
    Color? Function(BuildContext context, T item);

class AppDataColumn<T> {
  const AppDataColumn({
    required this.label,
    required this.cellBuilder,
    this.numeric = false,
    this.tooltip,
  });

  final String label;
  final AppDataCellBuilder<T> cellBuilder;
  final bool numeric;
  final String? tooltip;
}

class AppDataList<T> extends StatelessWidget {
  const AppDataList({
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
    super.key,
  });

  final List<T> items;
  final List<AppDataColumn<T>> columns;
  final AppDataMobileItemBuilder<T> mobileItemBuilder;
  final AppDataItemKeyBuilder<T>? itemKeyBuilder;
  final ValueChanged<T>? onRowSelected;
  final WidgetBuilder? emptyBuilder;
  final WidgetBuilder? loadingBuilder;
  final Widget Function(BuildContext context, Object error)? errorBuilder;
  final Widget? footer;
  final AppDataRowColorBuilder<T>? rowColorBuilder;
  final bool isLoading;
  final Object? error;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    final Object? resolvedError = error;
    if (resolvedError != null && errorBuilder != null) {
      return errorBuilder!(context, resolvedError);
    }

    if (isLoading) {
      return loadingBuilder?.call(context) ?? const _DefaultDataListLoading();
    }

    if (items.isEmpty && emptyBuilder != null) {
      return emptyBuilder!(context);
    }

    final Widget content = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final AppBreakpoint breakpoint = AppBreakpoints.fromConstraints(
          constraints,
        );
        if (breakpoint.isMobile) {
          return _MobileDataList<T>(
            items: items,
            itemBuilder: mobileItemBuilder,
            itemKeyBuilder: itemKeyBuilder,
            onRowSelected: onRowSelected,
            shrinkWrap: shrinkWrap,
            physics: physics,
            rowColorBuilder: rowColorBuilder,
          );
        }

        return _DesktopDataTable<T>(
          items: items,
          columns: columns,
          itemKeyBuilder: itemKeyBuilder,
          onRowSelected: onRowSelected,
          minWidth: constraints.maxWidth,
          rowColorBuilder: rowColorBuilder,
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
}

class AppPaginatedDataList<T> extends StatelessWidget {
  const AppPaginatedDataList({
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
    super.key,
  });

  final AppPage<T> page;
  final List<AppDataColumn<T>> columns;
  final AppDataMobileItemBuilder<T> mobileItemBuilder;
  final AppDataPageLabelBuilder<T> pageLabelBuilder;
  final String previousPageLabel;
  final String nextPageLabel;
  final AppDataItemKeyBuilder<T>? itemKeyBuilder;
  final ValueChanged<T>? onRowSelected;
  final ValueChanged<AppPageRequest>? onPageChanged;
  final WidgetBuilder? emptyBuilder;
  final WidgetBuilder? loadingBuilder;
  final Widget Function(BuildContext context, Object error)? errorBuilder;
  final AppDataRowColorBuilder<T>? rowColorBuilder;
  final bool isLoading;
  final Object? error;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    return AppDataList<T>(
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

class _MobileDataList<T> extends StatelessWidget {
  const _MobileDataList({
    required this.items,
    required this.itemBuilder,
    required this.itemKeyBuilder,
    required this.onRowSelected,
    required this.shrinkWrap,
    required this.physics,
    required this.rowColorBuilder,
  });

  final List<T> items;
  final AppDataMobileItemBuilder<T> itemBuilder;
  final AppDataItemKeyBuilder<T>? itemKeyBuilder;
  final ValueChanged<T>? onRowSelected;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final AppDataRowColorBuilder<T>? rowColorBuilder;

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

class _DesktopDataTable<T> extends StatelessWidget {
  const _DesktopDataTable({
    required this.items,
    required this.columns,
    required this.itemKeyBuilder,
    required this.onRowSelected,
    required this.minWidth,
    required this.rowColorBuilder,
  });

  final List<T> items;
  final List<AppDataColumn<T>> columns;
  final AppDataItemKeyBuilder<T>? itemKeyBuilder;
  final ValueChanged<T>? onRowSelected;
  final double minWidth;
  final AppDataRowColorBuilder<T>? rowColorBuilder;

  @override
  Widget build(BuildContext context) {
    final Widget table = DataTable(
      showCheckboxColumn: false,
      columns: <DataColumn>[
        for (final AppDataColumn<T> column in columns)
          DataColumn(
            numeric: column.numeric,
            tooltip: column.tooltip,
            label: Text(column.label),
          ),
      ],
      rows: <DataRow>[
        for (final T item in items)
          DataRow(
            key: itemKeyBuilder?.call(item),
            color: _rowColor(context, item),
            onSelectChanged: onRowSelected == null
                ? null
                : (_) {
                    onRowSelected!(item);
                  },
            cells: <DataCell>[
              for (final AppDataColumn<T> column in columns)
                DataCell(column.cellBuilder(context, item)),
            ],
          ),
      ],
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: minWidth),
        child: table,
      ),
    );
  }

  WidgetStateProperty<Color?>? _rowColor(BuildContext context, T item) {
    final AppDataRowColorBuilder<T>? builder = rowColorBuilder;
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

class _DefaultDataListLoading extends StatelessWidget {
  const _DefaultDataListLoading();

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
