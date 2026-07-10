import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';
import 'package:hosspi_hms/features/home/presentation/controllers/home_controller.dart';
import 'package:hosspi_hms/features/home/presentation/controllers/home_dashboard_optimistic_patch.dart';

HomeDashboard? readSuccessfulHomeDashboard(
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
  final HomeDashboardOptimisticPatch? patch = state?.patch;
  if (patch == null || patch.isEmpty) {
    return dashboard;
  }
  return patch.applyTo(dashboard);
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
