import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/core/errors/result.dart';

@immutable
final class AppPageRequest {
  const AppPageRequest({this.pageIndex = 0, this.pageSize = defaultPageSize})
    : assert(pageIndex >= 0, 'pageIndex must not be negative.'),
      assert(pageSize > 0, 'pageSize must be greater than zero.');

  static const int defaultPageSize = 20;

  /// Backend `MAX_PAGE_LIMIT` — do not exceed in API `limit` params.
  static const int maxPageSize = 100;

  final int pageIndex;
  final int pageSize;

  int get offset => pageIndex * pageSize;

  int get limit => pageSize;

  AppPageRequest next() {
    return copyWith(pageIndex: pageIndex + 1);
  }

  AppPageRequest previous() {
    if (pageIndex == 0) {
      return this;
    }

    return copyWith(pageIndex: pageIndex - 1);
  }

  AppPageRequest first() {
    return copyWith(pageIndex: 0);
  }

  AppPageRequest copyWith({int? pageIndex, int? pageSize}) {
    return AppPageRequest(
      pageIndex: pageIndex ?? this.pageIndex,
      pageSize: pageSize ?? this.pageSize,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AppPageRequest &&
        other.pageIndex == pageIndex &&
        other.pageSize == pageSize;
  }

  @override
  int get hashCode => Object.hash(pageIndex, pageSize);
}

@immutable
final class AppPage<T> {
  const AppPage({
    required this.items,
    required this.request,
    this.totalItemCount,
  }) : assert(
         totalItemCount == null || totalItemCount >= 0,
         'totalItemCount must not be negative.',
       );

  final List<T> items;
  final AppPageRequest request;
  final int? totalItemCount;

  int get pageIndex => request.pageIndex;

  int get pageSize => request.pageSize;

  bool get isEmpty => items.isEmpty;

  bool get hasPreviousPage => pageIndex > 0;

  bool get hasNextPage {
    final int? total = totalItemCount;
    if (total == null) {
      return items.length == pageSize;
    }

    return request.offset + items.length < total;
  }

  int get firstItemNumber {
    if (items.isEmpty) {
      return 0;
    }

    return request.offset + 1;
  }

  int get lastItemNumber {
    return request.offset + items.length;
  }

  @override
  bool operator ==(Object other) {
    return other is AppPage<T> &&
        listEquals(other.items, items) &&
        other.request == request &&
        other.totalItemCount == totalItemCount;
  }

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(items), request, totalItemCount);
}

/// Loads every row that matches the current list query by walking [AppPage]
/// results until [AppPage.hasNextPage] is false.
///
/// Each request uses [pageSize] clamped to [AppPageRequest.maxPageSize].
/// Callers must pass the same search, filters, and scope as the table query.
Future<Result<List<T>>> loadMatchingAppPageItems<T>({
  required Future<Result<AppPage<T>>> Function(AppPageRequest request) loadPage,
  int pageSize = AppPageRequest.maxPageSize,
}) async {
  final int size = pageSize < 1
      ? AppPageRequest.maxPageSize
      : (pageSize > AppPageRequest.maxPageSize
            ? AppPageRequest.maxPageSize
            : pageSize);
  AppPageRequest request = AppPageRequest(pageIndex: 0, pageSize: size);
  final List<T> items = <T>[];
  const int maxPages = 10000;
  for (int pageNumber = 0; pageNumber < maxPages; pageNumber += 1) {
    final Result<AppPage<T>> result = await loadPage(request);
    switch (result) {
      case ResultFailure<AppPage<T>>(:final failure):
        return Result<List<T>>.failure(failure);
      case ResultSuccess<AppPage<T>>(:final value):
        items.addAll(value.items);
        final int? total = value.totalItemCount;
        if (total != null && items.length >= total) {
          return Result<List<T>>.success(List<T>.unmodifiable(items));
        }
        if (!value.hasNextPage || value.items.isEmpty) {
          return Result<List<T>>.success(List<T>.unmodifiable(items));
        }
        request = request.next();
    }
  }
  return Result<List<T>>.success(List<T>.unmodifiable(items));
}

/// Unwraps [loadMatchingAppPageItems] for table export/print loaders.
Future<List<T>> matchingAppPageItemsOrThrow<T>({
  required Future<Result<AppPage<T>>> Function(AppPageRequest request) loadPage,
  int pageSize = AppPageRequest.maxPageSize,
}) async {
  final Result<List<T>> result = await loadMatchingAppPageItems<T>(
    loadPage: loadPage,
    pageSize: pageSize,
  );
  return result.when(
    success: (List<T> items) => items,
    failure: (failure) {
      throw failure;
    },
  );
}

/// Unwraps a matching-dataset [Result] for [AppListTable] loaders.
Future<List<T>> matchingItemsOrThrow<T>(Future<Result<List<T>>> future) async {
  final Result<List<T>> result = await future;
  return result.when(
    success: (List<T> items) => items,
    failure: (failure) {
      throw failure;
    },
  );
}
