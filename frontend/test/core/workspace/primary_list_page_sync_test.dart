import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/workspace/primary_list_page_sync.dart';
import 'package:hosspi_hms/shared/data/data.dart';

void main() {
  group('PrimaryListPageSync', () {
    test('upsert prepends and increments total count', () {
      const AppPage<_Item> page = AppPage<_Item>(
        items: <_Item>[_Item('a')],
        request: AppPageRequest(pageSize: 12),
        totalItemCount: 1,
      );

      final AppPage<_Item> patched = PrimaryListPageSync.upsert<_Item>(
        page: page,
        item: const _Item('b'),
        matches: (left, right) => left.id == right.id,
      );

      expect(patched.items.map((item) => item.id), <String>['b', 'a']);
      expect(patched.totalItemCount, 2);
    });

    test('remove drops matching row and decrements total count', () {
      const AppPage<_Item> page = AppPage<_Item>(
        items: <_Item>[_Item('a'), _Item('b')],
        request: AppPageRequest(pageSize: 12),
        totalItemCount: 2,
      );

      final AppPage<_Item> patched = PrimaryListPageSync.remove<_Item>(
        page: page,
        id: 'a',
        matchesId: (item, targetId) => item.id == targetId,
      );

      expect(patched.items.single.id, 'b');
      expect(patched.totalItemCount, 1);
    });
  });
}

final class _Item {
  const _Item(this.id);
  final String id;
}
