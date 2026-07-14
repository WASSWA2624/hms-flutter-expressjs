import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/startup/app_preferences_restorer.dart';
import 'package:hosspi_hms/core/storage/storage_providers.dart';

final appShellSidebarCollapsedProvider =
    NotifierProvider<AppShellSidebarCollapsedController, bool>(
      AppShellSidebarCollapsedController.new,
    );

final class AppShellSidebarCollapsedController extends Notifier<bool> {
  @override
  bool build() {
    return ref
            .read(appPreferencesStoreProvider)
            .getBool(AppPreferenceKeys.sidebarCollapsed) ??
        false;
  }

  Future<void> setCollapsed({required bool collapsed}) async {
    if (collapsed == state) {
      return;
    }

    final bool previous = state;
    state = collapsed;

    try {
      final bool saved = await ref
          .read(appPreferencesStoreProvider)
          .setBool(AppPreferenceKeys.sidebarCollapsed, value: collapsed);

      if (!saved) {
        throw StateError('Unable to persist sidebar collapsed preference.');
      }
    } catch (_) {
      state = previous;
      rethrow;
    }
  }
}
