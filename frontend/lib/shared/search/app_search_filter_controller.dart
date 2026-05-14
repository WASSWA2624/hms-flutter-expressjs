import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hosspi_hms/shared/data/data.dart';

enum AppSortDirection { ascending, descending }

@immutable
final class AppSortDescriptor {
  const AppSortDescriptor({
    required this.field,
    this.direction = AppSortDirection.ascending,
  });

  final String field;
  final AppSortDirection direction;

  AppSortDescriptor copyWith({String? field, AppSortDirection? direction}) {
    return AppSortDescriptor(
      field: field ?? this.field,
      direction: direction ?? this.direction,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AppSortDescriptor &&
        other.field == field &&
        other.direction == direction;
  }

  @override
  int get hashCode => Object.hash(field, direction);
}

@immutable
final class AppSearchFilterState {
  const AppSearchFilterState({
    this.query = '',
    this.filters = const <String, Object?>{},
    this.sort,
    this.pageRequest = const AppPageRequest(),
  });

  final String query;
  final Map<String, Object?> filters;
  final AppSortDescriptor? sort;
  final AppPageRequest pageRequest;

  String get normalizedQuery => query.trim();

  bool get hasQuery => normalizedQuery.isNotEmpty;

  bool get hasActiveFilters {
    return filters.values.any(_hasFilterValue);
  }

  bool get hasActiveCriteria => hasQuery || hasActiveFilters || sort != null;

  AppSearchFilterState copyWith({
    String? query,
    Map<String, Object?>? filters,
    Object? sort = _unset,
    AppPageRequest? pageRequest,
  }) {
    return AppSearchFilterState(
      query: query ?? this.query,
      filters: Map<String, Object?>.unmodifiable(filters ?? this.filters),
      sort: identical(sort, _unset) ? this.sort : sort as AppSortDescriptor?,
      pageRequest: pageRequest ?? this.pageRequest,
    );
  }

  static bool _hasFilterValue(Object? value) {
    return switch (value) {
      null => false,
      final String text => text.trim().isNotEmpty,
      final Iterable<Object?> values => values.isNotEmpty,
      _ => true,
    };
  }

  static const Object _unset = Object();

  @override
  bool operator ==(Object other) {
    return other is AppSearchFilterState &&
        other.query == query &&
        mapEquals(other.filters, filters) &&
        other.sort == sort &&
        other.pageRequest == pageRequest;
  }

  @override
  int get hashCode => Object.hash(
    query,
    Object.hashAll(_sortedFilterHashes()),
    sort,
    pageRequest,
  );

  List<int> _sortedFilterHashes() {
    final entries = filters.entries.toList()
      ..sort((
        MapEntry<String, Object?> first,
        MapEntry<String, Object?> second,
      ) {
        return first.key.compareTo(second.key);
      });

    return <int>[
      for (final MapEntry<String, Object?> entry in entries)
        Object.hash(entry.key, entry.value),
    ];
  }
}

class AppSearchFilterController extends ChangeNotifier {
  AppSearchFilterController({
    AppSearchFilterState initialState = const AppSearchFilterState(),
    this.queryDebounceDuration = Duration.zero,
  }) : _state = initialState;

  final Duration queryDebounceDuration;

  AppSearchFilterState _state;
  Timer? _queryDebounce;

  AppSearchFilterState get state => _state;

  void setQuery(String query) {
    if (queryDebounceDuration == Duration.zero) {
      setQueryImmediately(query);
      return;
    }

    _queryDebounce?.cancel();
    _queryDebounce = Timer(queryDebounceDuration, () {
      setQueryImmediately(query);
    });
  }

  void setQueryImmediately(String query) {
    _queryDebounce?.cancel();
    _replaceState(
      _state.copyWith(query: query, pageRequest: _state.pageRequest.first()),
    );
  }

  void updateFilter(String key, Object? value) {
    final nextFilters = Map<String, Object?>.of(_state.filters);
    nextFilters[key] = value;
    _replaceState(
      _state.copyWith(
        filters: nextFilters,
        pageRequest: _state.pageRequest.first(),
      ),
    );
  }

  void replaceFilters(Map<String, Object?> filters) {
    _replaceState(
      _state.copyWith(
        filters: filters,
        pageRequest: _state.pageRequest.first(),
      ),
    );
  }

  void clearFilters() {
    replaceFilters(const <String, Object?>{});
  }

  void setSort(AppSortDescriptor? sort) {
    _replaceState(
      _state.copyWith(sort: sort, pageRequest: _state.pageRequest.first()),
    );
  }

  void setPageIndex(int pageIndex) {
    _replaceState(
      _state.copyWith(
        pageRequest: _state.pageRequest.copyWith(pageIndex: pageIndex),
      ),
    );
  }

  void setPageSize(int pageSize) {
    _replaceState(
      _state.copyWith(
        pageRequest: _state.pageRequest.copyWith(
          pageIndex: 0,
          pageSize: pageSize,
        ),
      ),
    );
  }

  void reset([AppSearchFilterState state = const AppSearchFilterState()]) {
    _queryDebounce?.cancel();
    _replaceState(state);
  }

  void _replaceState(AppSearchFilterState nextState) {
    if (nextState == _state) {
      return;
    }

    _state = nextState;
    notifyListeners();
  }

  @override
  void dispose() {
    _queryDebounce?.cancel();
    super.dispose();
  }
}
