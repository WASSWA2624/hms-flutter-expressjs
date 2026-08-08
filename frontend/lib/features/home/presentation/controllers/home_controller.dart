import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/realtime/realtime_event_groups.dart';
import 'package:hosspi_hms/core/realtime/realtime_events.dart';
import 'package:hosspi_hms/core/realtime/realtime_message.dart';
import 'package:hosspi_hms/core/realtime/realtime_refresh.dart';
import 'package:hosspi_hms/core/realtime/realtime_scope.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/core/security/session_isolation.dart';
import 'package:hosspi_hms/features/home/data/repositories/home_repository_impl.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard_lookups.dart';
import 'package:hosspi_hms/features/home/domain/repositories/home_repository.dart';
import 'package:hosspi_hms/features/home/presentation/controllers/home_dashboard_optimistic_patch.dart';

/// Clears default home dashboard providers when the session epoch bumps.
///
/// Home controllers are autoDispose, so leaving Home already drops state.
/// This binder still invalidates the empty-request family on logout / re-auth
/// so any brief retained listener (dialogs, reconciles) cannot keep prior
/// account metrics alive into the next session.
final homeSessionIsolationBinderProvider = Provider<int>((Ref ref) {
  ref.listen<int>(sessionEpochProvider, (int? previous, int next) {
    if (previous == null || previous == next) {
      return;
    }
    const HomeDashboardRequest request = HomeDashboardRequest.empty;
    ref.invalidate(homeCoreControllerProvider(request));
    ref.invalidate(homeControllerProvider(request));
    ref.invalidate(homeLookupsControllerProvider(request));
    ref.read(homeDashboardOptimisticPatchProvider(request).notifier).state =
        null;
  });
  return ref.watch(sessionEpochProvider);
});

/// Soft realtime refreshes skip the core phase so queues/activity do not
/// briefly clear while the full pack reloads.
final Set<HomeDashboardRequest> _homeFullOnlyReloads = <HomeDashboardRequest>{};

/// Fast KPI pack (`phase=core`). Painted immediately while [homeControllerProvider]
/// enriches queues, activity, and snapshot counts.
final homeCoreControllerProvider = FutureProvider.autoDispose
    .family<Result<HomeDashboard>, HomeDashboardRequest>((ref, request) {
      watchSessionDashboardScope(ref);
      return ref
          .watch(homeRepositoryProvider)
          .loadDashboard(request.copyWith(phase: HomeDashboardPhase.core));
    });

/// Full workspace pack. Depends on [homeCoreControllerProvider] so enrichment
/// starts only after the core pack resolves (or skips core on soft refresh).
final homeControllerProvider = FutureProvider.autoDispose
    .family<Result<HomeDashboard>, HomeDashboardRequest>((ref, request) async {
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
            // Count deltas alone skip a reload, but pharmacy packs also drive
            // most-sold / status-mix charts that deltas do not cover.
            final bool pharmacyTouched = RealtimeEventGroups.pharmacy.contains(
              message.event,
            );
            if (!RealtimeEventGroups.platformAdmin.contains(message.event) &&
                !pharmacyTouched) {
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

          // Soft invalidate: keep prior KPIs visible; reload full pack only.
          _homeFullOnlyReloads.add(request);
          ref.invalidateSelf();
        },
      );

      // Watch (not read) so /auth/me enrichment and role/permission updates
      // rebuild the dashboard instead of leaving a stale limited fallback.
      final HomeRepository repository = ref.watch(homeRepositoryProvider);
      final bool fullOnly = _homeFullOnlyReloads.remove(request);
      if (fullOnly) {
        return repository.loadDashboard(
          request.copyWith(phase: HomeDashboardPhase.full),
        );
      }

      final Result<HomeDashboard> core = await ref.watch(
        homeCoreControllerProvider(request).future,
      );
      final bool shouldEnrich = core.when(
        success: (HomeDashboard dashboard) => dashboard.isEnriching,
        failure: (_) => false,
      );
      if (!shouldEnrich) {
        return core;
      }

      return repository.loadDashboard(
        request.copyWith(phase: HomeDashboardPhase.full),
      );
    });

/// Progressive view: core KPIs as soon as ready, then the full pack.
///
/// Prefer this over watching [homeControllerProvider] alone so the page can
/// paint before queues/activity finish loading.
AsyncValue<Result<HomeDashboard>> watchHomeDashboard(
  Ref ref,
  HomeDashboardRequest request,
) {
  final AsyncValue<Result<HomeDashboard>> full = ref.watch(
    homeControllerProvider(request),
  );
  final AsyncValue<Result<HomeDashboard>> core = ref.watch(
    homeCoreControllerProvider(request),
  );

  if (full.hasValue) {
    return full;
  }
  if (core.hasValue) {
    return core;
  }
  return full;
}

/// Widget-ref variant of [watchHomeDashboard].
AsyncValue<Result<HomeDashboard>> watchHomeDashboardForWidget(
  WidgetRef ref,
  HomeDashboardRequest request,
) {
  final AsyncValue<Result<HomeDashboard>> full = ref.watch(
    homeControllerProvider(request),
  );
  final AsyncValue<Result<HomeDashboard>> core = ref.watch(
    homeCoreControllerProvider(request),
  );

  if (full.hasValue) {
    return full;
  }
  if (core.hasValue) {
    return core;
  }
  return full;
}

final homeLookupsControllerProvider = FutureProvider.autoDispose
    .family<Result<HomeDashboardLookups>, HomeDashboardRequest>((ref, request) {
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
  final AsyncValue<Result<HomeDashboard>> asyncValue = watchHomeDashboard(
    ref,
    request,
  );

  return switch (asyncValue) {
    AsyncData<Result<HomeDashboard>>(:final value) => value.when(
      success: (HomeDashboard dashboard) => dashboard,
      failure: (_) => null,
    ),
    _ => null,
  };
}
