import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';

import 'component_test_app.dart';

void main() {
  setUp(() {
    AppListTableColumnVisibilityMemory.instance.clear();
  });

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

  testWidgets('AppListTable search matches multi-token queries', (
    WidgetTester tester,
  ) async {
    final searchController = TextEditingController();
    addTearDown(searchController.dispose);

    await pumpComponent(
      tester,
      SizedBox(
        height: 420,
        child: AppListTable<_RowItem>(
          items: const <_RowItem>[
            _RowItem(id: '1', title: 'Amina Stone', status: 'Verified'),
            _RowItem(id: '2', title: 'Noah Echo', status: 'Pending'),
          ],
          columns: _columns,
          search: AppListTableSearch<_RowItem>(
            controller: searchController,
            semanticLabel: 'Search rows',
            matcher: (_RowItem item, String query) {
              final String haystack = '${item.title} ${item.status}'
                  .toLowerCase();
              return haystack.contains(query.toLowerCase());
            },
          ),
          mobileItemBuilder: (BuildContext context, _RowItem item) {
            return Text(item.title);
          },
        ),
      ),
      size: const Size(900, 600),
    );

    await tester.enterText(find.byType(EditableText), 'Amina Verified');
    await tester.pump();

    expect(find.text('Amina Stone'), findsOneWidget);
    expect(find.text('Noah Echo'), findsNothing);
  });

  testWidgets('AppListTable applies default ascending sort on first build', (
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

    expect(
      tester.getTopLeft(find.text('Alpha')).dy,
      lessThan(tester.getTopLeft(find.text('Beta')).dy),
    );
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
  });

  testWidgets('AppListTable highlights the active sorted column', (
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

    final Finder sortedHeader = find.ancestor(
      of: find.text('Title'),
      matching: find.byType(InkWell),
    );
    final Text titleHeader = tester.widget<Text>(
      find.descendant(of: sortedHeader, matching: find.text('Title')),
    );
    final Color primary = Theme.of(
      tester.element(find.byType(DataTable)),
    ).colorScheme.primary;

    expect(titleHeader.style?.color, primary);
    expect(find.byTooltip('Sorted by Title, ascending'), findsOneWidget);
  });

  testWidgets('AppListTable keeps rows visible while isLoading is true', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      SizedBox(
        height: 360,
        child: AppListTable<_RowItem>(
          items: items,
          columns: _columns,
          isLoading: true,
          mobileItemBuilder: (BuildContext context, _RowItem item) {
            return Text(item.title);
          },
        ),
      ),
      size: const Size(900, 600),
    );

    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('AppListTable toggles sortable text headers', (
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

    await tester.tap(find.text('Title'));
    await tester.pump();

    expect(
      tester.getTopLeft(find.text('Beta')).dy,
      lessThan(tester.getTopLeft(find.text('Alpha')).dy),
    );

    await tester.tap(find.text('Title'));
    await tester.pump();

    expect(
      tester.getTopLeft(find.text('Alpha')).dy,
      lessThan(tester.getTopLeft(find.text('Beta')).dy),
    );
  });

  testWidgets('AppListTable places column settings inside the search bar', (
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
            matcher: (_RowItem item, String query) {
              return item.title.toLowerCase().contains(query.toLowerCase());
            },
          ),
          mobileItemBuilder: (BuildContext context, _RowItem item) {
            return Text(item.title);
          },
        ),
      ),
      size: const Size(900, 600),
    );

    final Finder settingsInSearchBar = find.descendant(
      of: find.byType(AppSearchBar),
      matching: find.byTooltip('Table column settings'),
    );

    expect(settingsInSearchBar, findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    expect(find.byIcon(Icons.view_column_outlined), findsNothing);

    await tester.tap(settingsInSearchBar);
    await tester.pumpAndSettle();

    expect(find.text('Table columns'), findsOneWidget);
  });

  testWidgets('AppListTable restores column visibility from memory', (
    WidgetTester tester,
  ) async {
    const String storageKey = 'test-table-memory';
    AppListTableColumnVisibilityMemory.instance.write(storageKey, <String>{
      'status',
    });
    addTearDown(() {
      AppListTableColumnVisibilityMemory.instance.remove(storageKey);
    });

    final TextEditingController searchController = TextEditingController();
    addTearDown(searchController.dispose);

    Future<void> pumpTable({required Key tableKey}) {
      return pumpComponent(
        tester,
        SizedBox(
          key: tableKey,
          height: 420,
          child: AppListTable<_RowItem>(
            items: items,
            columns: _columnsWithStableKeys,
            columnVisibilityStorageKey: storageKey,
            search: AppListTableSearch<_RowItem>(
              controller: searchController,
              semanticLabel: 'Search rows',
              matcher: (_, _) => true,
            ),
            mobileItemBuilder: (BuildContext context, _RowItem item) {
              return Text(item.title);
            },
          ),
        ),
        size: const Size(900, 600),
      );
    }

    await pumpTable(tableKey: const ValueKey<String>('first'));
    expect(find.text('Title'), findsNothing);
    expect(find.text('Status'), findsOneWidget);

    await pumpTable(tableKey: const ValueKey<String>('second'));
    expect(find.text('Title'), findsNothing);
    expect(find.text('Status'), findsOneWidget);
  });

  testWidgets('AppListTable keeps always-visible columns selected', (
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
          columns: _columnsWithPinnedStatus,
          search: AppListTableSearch<_RowItem>(
            controller: searchController,
            semanticLabel: 'Search rows',
            matcher: (_, _) => true,
          ),
          mobileItemBuilder: (BuildContext context, _RowItem item) {
            return Text(item.title);
          },
        ),
      ),
      size: const Size(900, 600),
    );

    await tester.tap(find.byTooltip('Table column settings'));
    await tester.pumpAndSettle();

    final CheckboxListTile pinnedStatus = tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, 'Status'),
    );
    expect(pinnedStatus.value, isTrue);
    expect(pinnedStatus.onChanged, isNull);

    await tester.tap(find.widgetWithText(CheckboxListTile, 'Title'));
    await tester.pump();
    await tester.tap(find.text('Apply columns'));
    await tester.pumpAndSettle();

    expect(find.text('Status'), findsOneWidget);
    expect(find.text('Title'), findsNothing);
    expect(find.text('Active'), findsOneWidget);
  });

  testWidgets('column visibility dialog uses a two-action footer on mobile', (
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
          columns: _columnsWithPinnedStatus,
          search: AppListTableSearch<_RowItem>(
            controller: searchController,
            semanticLabel: 'Search rows',
            matcher: (_, _) => true,
          ),
          mobileItemBuilder: (BuildContext context, _RowItem item) {
            return Text(item.title);
          },
        ),
      ),
      size: const Size(400, 498),
    );

    await tester.tap(find.byTooltip('Table column settings'));
    await tester.pumpAndSettle();

    final Finder resetAction = find.text('Reset columns');
    final Finder applyAction = find.text('Apply columns');

    expect(resetAction, findsOneWidget);
    expect(applyAction, findsOneWidget);
    expect(find.text('Cancel'), findsNothing);
    expect(
      tester.getTopLeft(resetAction).dy,
      tester.getTopLeft(applyAction).dy,
    );
  });

  testWidgets('AppListTable wires page controls to page requests', (
    WidgetTester tester,
  ) async {
    AppPageRequest? nextRequest;

    await pumpComponent(
      tester,
      SizedBox(
        height: 360,
        child: AppListTable<_RowItem>(
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

  testWidgets('AppListTable emits previous page requests', (
    WidgetTester tester,
  ) async {
    AppPageRequest? previousRequest;

    await pumpComponent(
      tester,
      SizedBox(
        height: 360,
        child: AppListTable<_RowItem>(
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
            return 'Page ${page.pageIndex + 1}';
          },
          previousPageLabel: 'Previous page',
          nextPageLabel: 'Next page',
          onPageChanged: (AppPageRequest request) {
            previousRequest = request;
          },
        ),
      ),
      size: const Size(900, 600),
    );

    await tester.tap(find.byTooltip('Previous page'));
    await tester.pump();

    expect(previousRequest, const AppPageRequest(pageSize: 2));
  });

  testWidgets('AppListTable filters paged rows in real time', (
    WidgetTester tester,
  ) async {
    final ValueNotifier<String> searchQuery = ValueNotifier<String>('');
    addTearDown(searchQuery.dispose);

    await pumpComponent(
      tester,
      SizedBox(
        height: 360,
        child: AppListTable<_RowItem>(
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

  testWidgets('AppListTable tolerates duplicate item keys', (
    WidgetTester tester,
  ) async {
    const duplicateItems = <_RowItem>[
      _RowItem(id: 'dup', title: 'Alpha', status: 'Active'),
      _RowItem(id: 'dup', title: 'Beta', status: 'Draft'),
    ];

    await pumpComponent(
      tester,
      SizedBox(
        height: 360,
        width: 960,
        child: AppListTable<_RowItem>(
          items: duplicateItems,
          columns: _columns,
          itemKeyBuilder: (_RowItem item) => ValueKey<String>(item.id),
          mobileItemBuilder: (BuildContext context, _RowItem item) {
            return ListTile(title: Text(item.title));
          },
        ),
      ),
      size: const Size(960, 600),
    );

    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
  });
}

const List<AppListTableColumn<_RowItem>> _columns =
    <AppListTableColumn<_RowItem>>[
      AppListTableColumn<_RowItem>(
        label: 'Title',
        cellBuilder: _titleCell,
        sortComparator: _compareTitle,
      ),
      AppListTableColumn<_RowItem>(
        label: 'Status',
        cellBuilder: _statusCell,
        sortComparator: _compareStatus,
      ),
    ];

const List<AppListTableColumn<_RowItem>> _columnsWithStableKeys =
    <AppListTableColumn<_RowItem>>[
      AppListTableColumn<_RowItem>(
        id: 'title',
        label: 'Title',
        cellBuilder: _titleCell,
        sortComparator: _compareTitle,
      ),
      AppListTableColumn<_RowItem>(
        id: 'status',
        label: 'Status',
        cellBuilder: _statusCell,
        sortComparator: _compareStatus,
      ),
    ];

const List<AppListTableColumn<_RowItem>> _columnsWithPinnedStatus =
    <AppListTableColumn<_RowItem>>[
      AppListTableColumn<_RowItem>(label: 'Title', cellBuilder: _titleCell),
      AppListTableColumn<_RowItem>(
        label: 'Status',
        alwaysVisible: true,
        cellBuilder: _statusCell,
      ),
    ];

int _compareTitle(_RowItem left, _RowItem right) {
  return left.title.compareTo(right.title);
}

int _compareStatus(_RowItem left, _RowItem right) {
  return left.status.compareTo(right.status);
}

Widget _titleCell(BuildContext context, _RowItem item) {
  return Text(item.title);
}

Widget _statusCell(BuildContext context, _RowItem item) {
  return AppStatusText(label: item.status, icon: Icons.check_circle_outline);
}

final class _RowItem {
  const _RowItem({required this.id, required this.title, required this.status});

  final String id;
  final String title;
  final String status;
}
