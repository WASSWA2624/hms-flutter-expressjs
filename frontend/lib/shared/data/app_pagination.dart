import 'package:flutter/foundation.dart';

@immutable
final class AppPageRequest {
  const AppPageRequest({this.pageIndex = 0, this.pageSize = defaultPageSize})
    : assert(pageIndex >= 0, 'pageIndex must not be negative.'),
      assert(pageSize > 0, 'pageSize must be greater than zero.');

  static const int defaultPageSize = 20;

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
