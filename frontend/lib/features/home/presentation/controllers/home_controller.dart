import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/realtime/realtime_event_groups.dart';
import 'package:hosspi_hms/core/realtime/realtime_message.dart';
import 'package:hosspi_hms/core/realtime/realtime_refresh.dart';
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
  if (payload.isEmpty) {
    return true;
  }

  return _matchesScopeValue(
        request.tenantId,
        _payloadString(payload, const <String>['tenant_id', 'tenantId']),
      ) &&
      _matchesScopeValue(
        request.facilityId,
        _payloadString(payload, const <String>['facility_id', 'facilityId']),
      ) &&
      _matchesScopeValue(
        request.branchId,
        _payloadString(payload, const <String>['branch_id', 'branchId']),
      );
}

bool _matchesScopeValue(String? currentValue, String? eventValue) {
  if (currentValue == null || eventValue == null) {
    return true;
  }
  return currentValue == eventValue;
}

String? _payloadString(Map<String, Object?> payload, Iterable<String> keys) {
  for (final String key in keys) {
    final Object? value = payload[key];
    final String normalized = value?.toString().trim() ?? '';
    if (normalized.isNotEmpty) {
      return normalized;
    }
  }
  return null;
}
