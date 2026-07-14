import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/app/startup/app_preferences_restorer.dart';
import 'package:hosspi_hms/core/storage/preferences/app_preferences_store.dart';
import 'package:hosspi_hms/core/storage/storage_providers.dart';
import 'package:hosspi_hms/shared/layout/app_shell_sidebar_preference.dart';

void main() {
  test('persists sidebar collapsed preference', () async {
    final _MemoryPreferencesStore store = _MemoryPreferencesStore();
    final ProviderContainer container = ProviderContainer(
      overrides: [appPreferencesStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    expect(container.read(appShellSidebarCollapsedProvider), isFalse);

    await container
        .read(appShellSidebarCollapsedProvider.notifier)
        .setCollapsed(collapsed: true);

    expect(container.read(appShellSidebarCollapsedProvider), isTrue);
    expect(store.getBool(AppPreferenceKeys.sidebarCollapsed), isTrue);
  });
}

final class _MemoryPreferencesStore implements AppPreferencesStore {
  final Map<String, Object?> _values = <String, Object?>{};

  @override
  String? getString(String key) => _values[key] as String?;

  @override
  bool? getBool(String key) => _values[key] as bool?;

  @override
  int? getInt(String key) => _values[key] as int?;

  @override
  Future<bool> setString(String key, String value) async {
    _values[key] = value;
    return true;
  }

  @override
  Future<bool> setBool(String key, {required bool value}) async {
    _values[key] = value;
    return true;
  }

  @override
  Future<bool> setInt(String key, int value) async {
    _values[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    _values.remove(key);
    return true;
  }
}
