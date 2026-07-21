import 'package:hosspi_hms/core/realtime/realtime_message.dart';

/// Scope helpers for filtering websocket domain events to the active workspace.
abstract final class RealtimeScope {
  static String? payloadString(
    Map<String, Object?> payload,
    Iterable<String> keys,
  ) {
    for (final String key in keys) {
      final Object? value = payload[key];
      final String normalized = value?.toString().trim() ?? '';
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
    return null;
  }

  static bool matchesValue(String? currentValue, String? eventValue) {
    if (currentValue == null || eventValue == null) {
      return true;
    }
    return currentValue == eventValue;
  }

  static bool matchesTenantFacility({
    required Map<String, Object?> payload,
    String? tenantId,
    String? facilityId,
  }) {
    if (payload.isEmpty) {
      return true;
    }

    return matchesValue(
          tenantId,
          payloadString(payload, const <String>['tenant_id', 'tenantId']),
        ) &&
        matchesValue(
          facilityId,
          payloadString(payload, const <String>['facility_id', 'facilityId']),
        ) &&
        matchesValue(
        );
  }

  static bool matchesMessage({
    required RealtimeMessage message,
    String? tenantId,
    String? facilityId,
  }) {
    return matchesTenantFacility(
      payload: message.payload,
      tenantId: tenantId,
      facilityId: facilityId,
    );
  }
}
