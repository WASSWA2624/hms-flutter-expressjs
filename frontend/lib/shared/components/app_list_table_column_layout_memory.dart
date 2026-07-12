import 'package:flutter/foundation.dart';

/// Session-scoped column widths for [AppListTable].
///
/// Survives widget disposal when users leave and return to a workspace route
/// during the same app session. Cleared when the process restarts.
final class AppListTableColumnLayoutMemory {
  AppListTableColumnLayoutMemory._();

  static final AppListTableColumnLayoutMemory instance =
      AppListTableColumnLayoutMemory._();

  final Map<String, Map<String, double>> _widthsByStorageKey =
      <String, Map<String, double>>{};

  Map<String, double>? read(String storageKey) {
    final Map<String, double>? value = _widthsByStorageKey[storageKey];
    if (value == null) {
      return null;
    }
    return Map<String, double>.of(value);
  }

  void write(String storageKey, Map<String, double> widths) {
    _widthsByStorageKey[storageKey] = Map<String, double>.of(widths);
  }

  void writeWidth(String storageKey, String columnKey, double width) {
    final Map<String, double> next = Map<String, double>.of(
      _widthsByStorageKey[storageKey] ?? <String, double>{},
    );
    next[columnKey] = width;
    _widthsByStorageKey[storageKey] = next;
  }

  @visibleForTesting
  void clear() {
    _widthsByStorageKey.clear();
  }

  @visibleForTesting
  void remove(String storageKey) {
    _widthsByStorageKey.remove(storageKey);
  }
}
