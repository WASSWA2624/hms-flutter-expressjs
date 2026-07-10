import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';
import 'package:hosspi_hms/features/home/presentation/controllers/home_controller.dart';
import 'package:hosspi_hms/features/home/presentation/controllers/home_dashboard_optimistic_patch.dart';

HomeDashboard? readSuccessfulHomeDashboard(
  WidgetRef ref,
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

void homeClearDashboardOptimisticPatch(
  WidgetRef ref,
  HomeDashboardRequest request,
) {
  ref.read(homeDashboardOptimisticPatchProvider(request).notifier).state = null;
}

void homeClearDashboardOptimisticPatchIfSatisfied(
  WidgetRef ref,
  HomeDashboardRequest request,
  HomeDashboard server,
) {
  final HomeDashboardOptimisticPatchState? state = ref.read(
    homeDashboardOptimisticPatchProvider(request),
  );
  if (state != null && state.isSatisfiedBy(server)) {
    homeClearDashboardOptimisticPatch(ref, request);
  }
}

void homeApplyDashboardOptimisticPatch(
  WidgetRef ref,
  HomeDashboardRequest request,
  HomeDashboardOptimisticPatch patch,
) {
  if (patch.isEmpty) {
    return;
  }

  final HomeDashboard? baseline = readSuccessfulHomeDashboard(ref, request);
  if (baseline == null) {
    return;
  }

  final HomeDashboardOptimisticPatchState? current = ref.read(
    homeDashboardOptimisticPatchProvider(request),
  );
  ref.read(homeDashboardOptimisticPatchProvider(request).notifier).state =
      current == null
      ? HomeDashboardOptimisticPatchState(patch: patch, baseline: baseline)
      : current.mergePatch(patch);
}

HomeDashboard homeDashboardWithOptimisticPatch(
  HomeDashboard dashboard,
  HomeDashboardOptimisticPatchState? state,
) {
  if (state == null || state.patch.isEmpty) {
    return dashboard;
  }
  if (state.isSatisfiedBy(dashboard)) {
    return dashboard;
  }
  return state.patch.applyTo(state.baseline);
}

void homeApplyRealtimeDashboardPatch(
  WidgetRef ref,
  HomeDashboardRequest request,
  HomeDashboardOptimisticPatch? patch,
) {
  if (patch != null && !patch.isEmpty) {
    homeApplyDashboardOptimisticPatch(ref, request, patch);
  }
}

/// Aligns the platform tenant metric card with a freshly loaded tenant list.
void homeReconcileTenantsMetricFromList(
  WidgetRef ref,
  int activeCount, {
  required int totalCount,
}) {
  const HomeDashboardRequest request = HomeDashboardRequest.empty;
  final HomeDashboard? server = readSuccessfulHomeDashboard(ref, request);
  if (server == null) {
    return;
  }

  final HomeDashboardOptimisticPatchState? patchState = ref.read(
    homeDashboardOptimisticPatchProvider(request),
  );
  final HomeDashboard display = homeDashboardWithOptimisticPatch(
    server,
    patchState,
  );

  HomeStatusCard? tenantsCard;
  for (final HomeStatusCard card in display.statusCards) {
    if (card.id == 'tenants_active') {
      tenantsCard = card;
      break;
    }
  }
  if (tenantsCard == null) {
    return;
  }

  final int currentTotal =
      (tenantsCard.secondaryValue ?? tenantsCard.value).round();
  final int currentActive = tenantsCard.value.round();
  final int totalDelta = totalCount - currentTotal;
  final int activeDelta = activeCount - currentActive;
  if (totalDelta == 0 && activeDelta == 0) {
    return;
  }

  homeApplyDashboardOptimisticPatch(
    ref,
    request,
    HomeDashboardOptimisticPatch(
      statusCardValueDeltas: activeDelta == 0
          ? const <String, int>{}
          : <String, int>{'tenants_active': activeDelta},
      statusCardSecondaryDeltas: totalDelta == 0
          ? const <String, int>{}
          : <String, int>{'tenants_active': totalDelta},
    ),
  );
}
