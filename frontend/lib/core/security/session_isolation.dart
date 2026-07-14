import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/network/network_providers.dart';
import 'package:hosspi_hms/core/realtime/realtime_providers.dart';
import 'package:hosspi_hms/core/realtime/realtime_service.dart';
import 'package:hosspi_hms/core/storage/database/app_database.dart';
import 'package:hosspi_hms/core/storage/storage_providers.dart';

/// Increments on logout, account switch, or tenant/facility context change so
/// keep-alive providers can drop previous-context state immediately.
final sessionEpochProvider = NotifierProvider<SessionEpochController, int>(
  SessionEpochController.new,
);

final class SessionEpochController extends Notifier<int> {
  @override
  int build() => 0;

  void bump() {
    state = state + 1;
  }
}

/// Tears down authenticated in-memory/network/local state for session isolation.
class SessionIsolationService {
  const SessionIsolationService(this.ref);

  final Ref ref;

  Future<void> disposeAuthenticatedState({
    bool closeNetwork = true,
    bool clearLocalCaches = true,
  }) async {
    ref.read(sessionEpochProvider.notifier).bump();

    try {
      final RealtimeService realtime = ref.read(realtimeServiceProvider);
      await realtime.disconnect();
    } catch (_) {
      // Best-effort disconnect; isolation must continue.
    }

    if (closeNetwork) {
      try {
        final Dio dio = ref.read(dioProvider);
        dio.close(force: true);
      } catch (_) {}
      try {
        final Dio publicDio = ref.read(publicDioProvider);
        publicDio.close(force: true);
      } catch (_) {}
      ref.invalidate(dioProvider);
      ref.invalidate(publicDioProvider);
      ref.invalidate(apiClientProvider);
      ref.invalidate(publicApiClientProvider);
    }

    if (clearLocalCaches) {
      try {
        final AppDatabase database = ref.read(appDatabaseProvider);
        await database.clearUserScopedCaches();
      } catch (_) {}
    }
  }
}

final sessionIsolationServiceProvider = Provider<SessionIsolationService>((
  Ref ref,
) {
  return SessionIsolationService(ref);
});
