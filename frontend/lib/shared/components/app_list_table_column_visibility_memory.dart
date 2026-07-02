import 'package:flutter/foundation.dart';

/// Session-scoped column visibility for [AppListTable].
///
/// Survives widget disposal when users leave and return to a workspace route
/// during the same app session. Cleared when the process restarts.
final class AppListTableColumnVisibilityMemory {
  AppListTableColumnVisibilityMemory._();

  static final AppListTableColumnVisibilityMemory instance =
      AppListTableColumnVisibilityMemory._();

  final Map<String, Set<String>> _visibleColumnKeysByStorageKey =
      <String, Set<String>>{};

  Set<String>? read(String storageKey) {
    final Set<String>? value = _visibleColumnKeysByStorageKey[storageKey];
    if (value == null) {
      return null;
    }
    return Set<String>.of(value);
  }

  void write(String storageKey, Set<String> visibleColumnKeys) {
    _visibleColumnKeysByStorageKey[storageKey] = Set<String>.of(
      visibleColumnKeys,
    );
  }

  @visibleForTesting
  void clear() {
    _visibleColumnKeysByStorageKey.clear();
  }

  @visibleForTesting
  void remove(String storageKey) {
    _visibleColumnKeysByStorageKey.remove(storageKey);
  }
}
