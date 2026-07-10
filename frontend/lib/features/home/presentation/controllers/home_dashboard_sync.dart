import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';
import 'package:hosspi_hms/features/home/presentation/controllers/home_dashboard_optimistic_patch.dart';

void homeClearDashboardOptimisticPatch(
  WidgetRef ref,
  HomeDashboardRequest request,
) {
  ref.read(homeDashboardOptimisticPatchProvider(request).notifier).state = null;
}

void homeApplyDashboardOptimisticPatch(
  WidgetRef ref,
  HomeDashboardRequest request,
  HomeDashboardOptimisticPatch patch,
) {
  final HomeDashboardOptimisticPatch? current = ref.read(
    homeDashboardOptimisticPatchProvider(request),
  );
  ref.read(homeDashboardOptimisticPatchProvider(request).notifier).state =
      current == null ? patch : current.merge(patch);
}

HomeDashboard homeDashboardWithOptimisticPatch(
  HomeDashboard dashboard,
  HomeDashboardOptimisticPatch? patch,
) {
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
