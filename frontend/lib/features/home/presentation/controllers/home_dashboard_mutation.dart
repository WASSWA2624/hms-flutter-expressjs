import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';
import 'package:hosspi_hms/features/home/presentation/controllers/home_controller.dart';
import 'package:hosspi_hms/features/home/presentation/controllers/home_dashboard_optimistic_patch.dart';
import 'package:hosspi_hms/features/home/presentation/controllers/home_dashboard_sync.dart';

void homeOnDashboardMutationSuccess(
  WidgetRef ref,
  HomeDashboardRequest request, {
  HomeDashboardOptimisticPatch? patch,
}) {
  if (patch != null && !patch.isEmpty) {
    homeApplyDashboardOptimisticPatch(ref, request, patch);
  }
  ref.invalidate(homeControllerProvider(request));
}

void homeOnDashboardDialogClosed(
  WidgetRef ref,
  HomeDashboardRequest request,
  bool? saved, {
  HomeDashboardOptimisticPatch? patch,
}) {
  if (saved == true) {
    homeOnDashboardMutationSuccess(ref, request, patch: patch);
  }
}

void homeRefreshDashboard(WidgetRef ref, HomeDashboardRequest request) {
  homeOnDashboardMutationSuccess(ref, request);
}
