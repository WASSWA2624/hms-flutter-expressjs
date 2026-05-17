import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';

import 'component_test_app.dart';

void main() {
  const items = <_RowItem>[
    _RowItem(id: '1', title: 'Alpha', status: 'Active'),
    _RowItem(id: '2', title: 'Beta', status: 'Draft'),
  ];

  testWidgets('AppListTable uses mobile row builders on small screens', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      SizedBox(
        height: 360,
        child: AppListTable<_RowItem>(
          items: items,
          columns: _columns,
          itemKeyBuilder: (_RowItem item) => ValueKey<String>(item.id),
          mobileItemBuilder: (BuildContext context, _RowItem item) {
            return ListTile(
              title: Text('Mobile ${item.title}'),
              subtitle: Text(item.status),
            );
          },
        ),
      ),
      size: const Size(500, 600),
    );

    expect(find.text('Mobile Alpha'), findsOneWidget);
    expect(find.text('Title'), findsNothing);
  });

  testWidgets('AppListTable mobile rows activate from the keyboard', (
    WidgetTester tester,
  ) async {
    _RowItem? selectedItem;

    await pumpComponent(
      tester,
      SizedBox(
        height: 360,
        child: AppListTable<_RowItem>(
          items: items,
          columns: _columns,
          mobileItemBuilder: (BuildContext context, _RowItem item) {
            return ListTile(title: Text('Mobile ${item.title}'));
          },
          onRowSelected: (_RowItem item) {
            selectedItem = item;
          },
        ),
      ),
      size: const Size(500, 600),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(selectedItem, items.first);
  });

  testWidgets('AppListTable uses table columns on wider screens', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      SizedBox(
        height: 360,
        child: AppListTable<_RowItem>(
          items: items,
          columns: _columns,
          mobileItemBuilder: (BuildContext context, _RowItem item) {
            return Text(item.title);
          },
        ),
      ),
      size: const Size(900, 600),
    );

    expect(find.byType(DataTable), findsOneWidget);
    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Alpha'), findsOneWidget);
  });

  testWidgets('AppListTable uses a compact table on tablet screens', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      SizedBox(
        height: 360,
        child: AppListTable<_RowItem>(
          items: items,
          columns: _columns,
          mobileItemBuilder: (BuildContext context, _RowItem item) {
            return Text(item.title);
          },
        ),
      ),
      size: const Size(700, 600),
    );

    final DataTable table = tester.widget<DataTable>(find.byType(DataTable));
    expect(find.text('Title'), findsOneWidget);
    expect(table.horizontalMargin, 8);
    expect(table.columnSpacing, 12);
  });

  testWidgets('AppListTable can force list rendering on wide screens', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      SizedBox(
        height: 360,
        child: AppListTable<_RowItem>(
          items: items,
          columns: _columns,
          displayMode: AppListTableDisplayMode.list,
          mobileItemBuilder: (BuildContext context, _RowItem item) {
            return ListTile(title: Text('List ${item.title}'));
          },
        ),
      ),
      size: const Size(900, 600),
    );

    expect(find.byType(DataTable), findsNothing);
    expect(find.text('List Alpha'), findsOneWidget);
  });

  testWidgets('AppListTable builds mobile rows lazily', (
    WidgetTester tester,
  ) async {
    final pagedItems = List<_RowItem>.generate(1000, (int index) {
      return _RowItem(id: '$index', title: 'Item $index', status: 'Active');
    });
    final builtIndexes = <int>{};

    await pumpComponent(
      tester,
      SizedBox(
        height: 120,
        child: AppListTable<_RowItem>(
          items: pagedItems,
          columns: _columns,
          mobileItemBuilder: (BuildContext context, _RowItem item) {
            builtIndexes.add(int.parse(item.id));

            return ListTile(title: Text(item.title));
          },
        ),
      ),
      size: const Size(500, 600),
    );

    expect(builtIndexes.length, lessThan(pagedItems.length));
    expect(find.text('Item 999'), findsNothing);
  });

  testWidgets('AppListTable attaches AppSearchBar and filters visible items', (
    WidgetTester tester,
  ) async {
    final searchController = TextEditingController();
    addTearDown(searchController.dispose);

    await pumpComponent(
      tester,
      SizedBox(
        height: 420,
        child: AppListTable<_RowItem>(
          items: items,
          columns: _columns,
          search: AppListTableSearch<_RowItem>(
            controller: searchController,
            semanticLabel: 'Search rows',
            hintText: 'Search',
            clearLabel: 'Clear search',
            matcher: (_RowItem item, String query) {
              final String normalizedQuery = query.toLowerCase();
              return item.title.toLowerCase().contains(normalizedQuery) ||
                  item.status.toLowerCase().contains(normalizedQuery);
            },
          ),
          emptyBuilder: (_) => const Text('No rows'),
          mobileItemBuilder: (BuildContext context, _RowItem item) {
            return Text(item.title);
          },
        ),
      ),
      size: const Size(900, 600),
    );

    expect(find.byType(AppSearchBar), findsOneWidget);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);

    await tester.enterText(find.byType(EditableText), 'draft');
    await tester.pump();

    expect(find.text('Alpha'), findsNothing);
    expect(find.text('Beta'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pump();

    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
  });

  testWidgets('AppPaginatedListTable wires page controls to page requests', (
    WidgetTester tester,
  ) async {
    AppPageRequest? nextRequest;

    await pumpComponent(
      tester,
      SizedBox(
        height: 360,
        child: AppPaginatedListTable<_RowItem>(
          page: const AppPage<_RowItem>(
            items: items,
            request: AppPageRequest(pageIndex: 1, pageSize: 2),
            totalItemCount: 6,
          ),
          columns: _columns,
          mobileItemBuilder: (BuildContext context, _RowItem item) {
            return Text(item.title);
          },
          pageLabelBuilder: (AppPage<_RowItem> page) {
            return '${page.firstItemNumber}-${page.lastItemNumber}';
          },
          previousPageLabel: 'Previous page',
          nextPageLabel: 'Next page',
          onPageChanged: (AppPageRequest request) {
            nextRequest = request;
          },
        ),
      ),
      size: const Size(900, 600),
    );

    expect(find.text('3-4'), findsOneWidget);

    await tester.tap(find.byTooltip('Next page'));
    await tester.pump();

    expect(nextRequest, const AppPageRequest(pageIndex: 2, pageSize: 2));
  });

  testWidgets('AppPaginationControls emits page requests', (
    WidgetTester tester,
  ) async {
    AppPageRequest? nextRequest;

    await pumpComponent(
      tester,
      AppPaginationControls(
        pageRequest: const AppPageRequest(pageIndex: 1),
        hasPreviousPage: true,
        hasNextPage: true,
        pageLabel: 'Page 2',
        previousPageLabel: 'Previous page',
        nextPageLabel: 'Next page',
        onPageChanged: (AppPageRequest request) {
          nextRequest = request;
        },
      ),
    );

    await tester.tap(find.byTooltip('Next page'));
    await tester.pump();

    expect(nextRequest, const AppPageRequest(pageIndex: 2));
  });

  testWidgets('AppSearchablePaginatedListTable filters rows in real time', (
    WidgetTester tester,
  ) async {
    final ValueNotifier<String> searchQuery = ValueNotifier<String>('');
    addTearDown(searchQuery.dispose);

    await pumpComponent(
      tester,
      SizedBox(
        height: 360,
        child: AppSearchablePaginatedListTable<_RowItem>(
          page: const AppPage<_RowItem>(
            items: items,
            request: AppPageRequest(pageIndex: 1, pageSize: 2),
            totalItemCount: 6,
          ),
          searchListenable: searchQuery,
          searchMatcher: (_RowItem item, String query) {
            final String normalizedQuery = query.toLowerCase();
            return item.title.toLowerCase().contains(normalizedQuery) ||
                item.status.toLowerCase().contains(normalizedQuery);
          },
          columns: _columns,
          mobileItemBuilder: (BuildContext context, _RowItem item) {
            return Text(item.title);
          },
          pageLabelBuilder: (AppPage<_RowItem> page) {
            return '${page.firstItemNumber}-${page.lastItemNumber} '
                'of ${page.totalItemCount}';
          },
          previousPageLabel: 'Previous page',
          nextPageLabel: 'Next page',
        ),
      ),
      size: const Size(900, 600),
    );

    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('3-4 of 6'), findsOneWidget);

    searchQuery.value = 'draft';
    await tester.pump();

    expect(find.text('Alpha'), findsNothing);
    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('1-1 of 1'), findsOneWidget);

    searchQuery.value = '';
    await tester.pump();

    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('3-4 of 6'), findsOneWidget);
  });
}

const List<AppListTableColumn<_RowItem>> _columns =
    <AppListTableColumn<_RowItem>>[
      AppListTableColumn<_RowItem>(label: 'Title', cellBuilder: _titleCell),
      AppListTableColumn<_RowItem>(label: 'Status', cellBuilder: _statusCell),
    ];

Widget _titleCell(BuildContext context, _RowItem item) {
  return Text(item.title);
}

Widget _statusCell(BuildContext context, _RowItem item) {
  return Text(item.status);
}

final class _RowItem {
  const _RowItem({required this.id, required this.title, required this.status});

  final String id;
  final String title;
  final String status;
}
