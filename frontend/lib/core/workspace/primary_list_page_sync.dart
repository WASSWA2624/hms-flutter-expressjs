import 'package:hosspi_hms/shared/data/data.dart';

/// Shared list upsert/remove helpers for workspace realtime delta appliers.
abstract final class PrimaryListPageSync {
  static AppPage<T> upsert<T>({
    required AppPage<T> page,
    required T item,
    required bool Function(T left, T right) matches,
    bool prepend = true,
  }) {
    final List<T> items = List<T>.from(page.items);
    final int index = items.indexWhere((T entry) => matches(entry, item));
    if (index >= 0) {
      items[index] = item;
    } else if (prepend) {
      items.insert(0, item);
    } else {
      items.add(item);
    }

    final int pageSize = page.request.pageSize;
    return AppPage<T>(
      items: items.take(pageSize).toList(growable: false),
      request: page.request,
      totalItemCount: index >= 0
          ? page.totalItemCount
          : (page.totalItemCount ?? items.length - 1) + 1,
    );
  }

  static AppPage<T> remove<T>({
    required AppPage<T> page,
    required String id,
    required bool Function(T item, String targetId) matchesId,
  }) {
    final List<T> items = page.items
        .where((T item) => !matchesId(item, id))
        .toList(growable: false);
    final int? total = page.totalItemCount;
    return AppPage<T>(
      items: items,
      request: page.request,
      totalItemCount: total == null ? null : (total - 1).clamp(0, 1 << 30),
    );
  }
}
