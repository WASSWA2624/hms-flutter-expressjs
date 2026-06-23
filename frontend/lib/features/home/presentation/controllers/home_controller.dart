import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/realtime/realtime_event_groups.dart';
import 'package:hosspi_hms/core/realtime/realtime_message.dart';
import 'package:hosspi_hms/core/realtime/realtime_refresh.dart';
import 'package:hosspi_hms/core/realtime/realtime_scope.dart';
import 'package:hosspi_hms/features/home/data/repositories/home_repository_impl.dart';
import 'package:hosspi_hms/features/home/domain/entities/home_dashboard.dart';

final homeControllerProvider =
    FutureProvider.family<Result<HomeDashboard>, HomeDashboardRequest>((
      ref,
      request,
    ) {
      listenForRealtimeRefresh(
        ref: ref,
        events: _homeDashboardRealtimeEvents,
        includeCrudMutations: true,
        debounce: const Duration(milliseconds: 600),
        shouldRefresh: (RealtimeMessage message) {
          return _matchesDashboardScope(request, message.payload);
        },
        onRefresh: (_) async {
          ref.invalidateSelf();
        },
      );

      return ref.watch(homeRepositoryProvider).loadDashboard(request);
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
};

bool _matchesDashboardScope(
  HomeDashboardRequest request,
  Map<String, Object?> payload,
) {
  return RealtimeScope.matchesTenantFacility(
    payload: payload,
    tenantId: request.tenantId,
    facilityId: request.facilityId,
    branchId: request.branchId,
  );
}
