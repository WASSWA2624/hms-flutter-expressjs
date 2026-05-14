import 'package:flutter_template/shared/data/data.dart';
import 'package:flutter_template/shared/search/search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('query and filter changes reset pagination explicitly', () {
    final controller = AppSearchFilterController(
      initialState: const AppSearchFilterState(
        pageRequest: AppPageRequest(pageIndex: 3, pageSize: 50),
      ),
    );
    addTearDown(controller.dispose);

    controller.setQueryImmediately('search');
    expect(controller.state.query, 'search');
    expect(controller.state.pageRequest, const AppPageRequest(pageSize: 50));

    controller.setPageIndex(2);
    controller.updateFilter('status', 'active');
    expect(controller.state.filters, <String, Object?>{'status': 'active'});
    expect(controller.state.pageRequest, const AppPageRequest(pageSize: 50));
  });

  test('sort state can be cleared without losing filter state', () {
    final controller = AppSearchFilterController();
    addTearDown(controller.dispose);

    controller.updateFilter('status', 'active');
    controller.setSort(
      const AppSortDescriptor(
        field: 'name',
        direction: AppSortDirection.descending,
      ),
    );
    controller.setSort(null);

    expect(controller.state.sort, isNull);
    expect(controller.state.filters, <String, Object?>{'status': 'active'});
  });

  testWidgets('setQuery debounces remote-search state updates', (
    WidgetTester tester,
  ) async {
    final controller = AppSearchFilterController(
      queryDebounceDuration: const Duration(milliseconds: 300),
    );
    addTearDown(controller.dispose);

    controller.setPageIndex(4);
    controller.setQuery('abc');

    expect(controller.state.query, isEmpty);
    expect(controller.state.pageRequest.pageIndex, 4);

    await tester.pump(const Duration(milliseconds: 299));
    expect(controller.state.query, isEmpty);

    await tester.pump(const Duration(milliseconds: 1));
    expect(controller.state.query, 'abc');
    expect(controller.state.pageRequest.pageIndex, 0);
  });
}
