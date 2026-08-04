import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/realtime/realtime_event_groups.dart';
import 'package:hosspi_hms/core/realtime/realtime_events.dart';
import 'package:hosspi_hms/core/realtime/realtime_message.dart';
import 'package:hosspi_hms/core/realtime/realtime_refresh.dart';
import 'package:hosspi_hms/core/realtime/realtime_scope.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/features/home/data/repositories/home_repository_impl.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_lookups.dart';
import 'package:hosspi_hms/features/home/presentation/controllers/home_dashboard_optimistic_patch.dart';

final homeControllerProvider =
    FutureProvider.family<Result<HomeDashboard>, HomeDashboardRequest>((
      ref,
      request,
    ) {
      watchSessionDashboardScope(ref);
      listenForRealtimeRefresh(
        ref: ref,
        events: _homeDashboardRealtimeEvents,
        includeCrudMutations: true,
        debounce: const Duration(milliseconds: 200),
        shouldRefresh: (RealtimeMessage message) {
          return _matchesDashboardScope(request, message.payload);
        },
        onRefresh: (RealtimeMessage message) async {
          final String? actorUserId = _payloadActorUserId(message.payload);
          final String? currentUserId = ref
              .read(sessionStateProvider)
              .session
              ?.user
              ?.id;
          final bool isSelfMutation =
              actorUserId != null &&
              currentUserId != null &&
              actorUserId == currentUserId;

          final HomeDashboardOptimisticPatch? patch =
              HomeDashboardOptimisticPatch.fromRealtimePayload(message.payload);

          if (patch != null) {
            final HomeDashboardOptimisticPatchState? current = ref.read(
              homeDashboardOptimisticPatchProvider(request),
            );
            final HomeDashboard? baseline =
                current?.baseline ?? _readSuccessfulHomeDashboard(ref, request);
            if (baseline != null) {
              ref
                  .read(homeDashboardOptimisticPatchProvider(request).notifier)
                  .state = current == null
                  ? HomeDashboardOptimisticPatchState(
                      patch: patch,
                      baseline: baseline,
                    )
                  : current.mergePatch(patch);
            }
            if (!RealtimeEventGroups.platformAdmin.contains(message.event)) {
              // Dashboard deltas are enough for instant UI; skip a heavy reload.
              return;
            }
          } else if (!isSelfMutation) {
            ref
                    .read(
                      homeDashboardOptimisticPatchProvider(request).notifier,
                    )
                    .state =
                null;
          }

          ref.invalidateSelf();
        },
      );

      // Watch (not read) so /auth/me enrichment and role/permission updates
      // rebuild the dashboard instead of leaving a stale limited fallback.
      return ref.watch(homeRepositoryProvider).loadDashboard(request);
    });

final homeLookupsControllerProvider =
    FutureProvider.family<Result<HomeDashboardLookups>, HomeDashboardRequest>((
      ref,
      request,
    ) {
      watchSessionDashboardScope(ref);
      return ref.watch(homeRepositoryProvider).loadLookups(request);
    });

const Set<String> _homeDashboardRealtimeEvents = <String>{
  ...RealtimeEventGroups.patients,
  ...RealtimeEventGroups.appointments,
  ...RealtimeEventGroups.opdFlow,
  ...RealtimeEventGroups.admissions,
  ...RealtimeEventGroups.criticalAlerts,
  ...RealtimeEventGroups.diagnostics,
  ...RealtimeEventGroups.pharmacy,
  ...RealtimeEventGroups.billing,
  ...RealtimeEventGroups.emergency,
  ...RealtimeEventGroups.operations,
  ...RealtimeEventGroups.hr,
  ...RealtimeEventGroups.biomedical,
  ...RealtimeEventGroups.communications,
  RealtimeEvents.facilityLayoutUpdated,
  ...RealtimeEventGroups.platformAdmin,
};

bool _matchesDashboardScope(
  HomeDashboardRequest request,
  Map<String, Object?> payload,
) {
  return RealtimeScope.matchesTenantFacility(
    payload: payload,
    tenantId: request.tenantId,
    facilityId: request.facilityId,
  );
}

String? _payloadActorUserId(Map<String, Object?> payload) {
  final Object? direct = payload['actor_user_id'] ?? payload['actorUserId'];
  if (direct is String && direct.trim().isNotEmpty) {
    return direct.trim();
  }

  final Object? nested = payload['payload'];
  if (nested is Map<String, Object?>) {
    final Object? nestedActor =
        nested['actor_user_id'] ?? nested['actorUserId'];
    if (nestedActor is String && nestedActor.trim().isNotEmpty) {
      return nestedActor.trim();
    }
  }
  if (nested is Map<Object?, Object?>) {
    final Object? nestedActor =
        nested['actor_user_id'] ?? nested['actorUserId'];
    if (nestedActor is String && nestedActor.trim().isNotEmpty) {
      return nestedActor.trim();
    }
  }

  return null;
}

HomeDashboard? _readSuccessfulHomeDashboard(
  Ref ref,
  HomeDashboardRequest request,
) {
  final AsyncValue<Result<HomeDashboard>> asyncValue = ref.read(
    homeControllerProvider(request),
  );

  return switch (asyncValue) {
    AsyncData<Result<HomeDashboard>>(:final value) => value.when(
      success: (HomeDashboard dashboard) => dashboard,
      failure: (_) => null,
    ),
    _ => null,
  };
}
