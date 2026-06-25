import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/realtime/realtime_message.dart';
import 'package:hosspi_hms/core/realtime/realtime_scope.dart';

void main() {
  group('RealtimeScope', () {
    test('matchesTenantFacility accepts empty payloads', () {
      expect(
        RealtimeScope.matchesTenantFacility(
          payload: const <String, Object?>{},
          tenantId: 'tenant-1',
          facilityId: 'facility-1',
        ),
        isTrue,
      );
    });

    test('matchesTenantFacility filters by tenant and facility', () {
      const Map<String, Object?> payload = <String, Object?>{
        'tenant_id': 'tenant-1',
        'facility_id': 'facility-2',
      };

      expect(
        RealtimeScope.matchesTenantFacility(
          payload: payload,
          tenantId: 'tenant-1',
          facilityId: 'facility-1',
        ),
        isFalse,
      );
      expect(
        RealtimeScope.matchesTenantFacility(
          payload: payload,
          tenantId: 'tenant-1',
          facilityId: 'facility-2',
        ),
        isTrue,
      );
    });

    test('matchesMessage delegates to payload scope checks', () {
      const RealtimeMessage message = RealtimeMessage(
        event: 'patient.updated',
        payload: <String, Object?>{'tenant_id': 'tenant-1'},
      );

      expect(
        RealtimeScope.matchesMessage(message: message, tenantId: 'tenant-1'),
        isTrue,
      );
      expect(
        RealtimeScope.matchesMessage(message: message, tenantId: 'tenant-2'),
        isFalse,
      );
    });
  });
}
