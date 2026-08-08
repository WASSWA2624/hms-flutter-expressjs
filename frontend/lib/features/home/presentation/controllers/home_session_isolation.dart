import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/security/session_isolation.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';
import 'package:hosspi_hms/features/home/presentation/controllers/home_controller.dart';
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
    ref.invalidate(homeControllerProvider(request));
    ref.invalidate(homeLookupsControllerProvider(request));
    ref.read(homeDashboardOptimisticPatchProvider(request).notifier).state =
        null;
  });
  return ref.watch(sessionEpochProvider);
});
