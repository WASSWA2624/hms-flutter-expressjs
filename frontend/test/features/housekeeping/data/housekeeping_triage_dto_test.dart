import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/housekeeping/data/dtos/housekeeping_dtos.dart';
import 'package:hosspi_hms/features/housekeeping/domain/entities/housekeeping_entities.dart';

void main() {
  group('HousekeepingWorkItemDto.fromMaintenanceRequestResponse', () {
    test('maps triage response into a maintenance work item', () {
      final HousekeepingWorkItem item =
          HousekeepingWorkItemDto.fromMaintenanceRequestResponse(
            <String, Object?>{
              'id': 'MR-001',
              'human_friendly_id': 'MR-001',
              'status': 'IN_PROGRESS',
              'description': '[TRIAGE] triage_summary=Leak confirmed',
              'facility_id': 'FAC-1',
              'facility_label': 'Main Campus',
              'asset_id': 'AST-1',
              'asset_label': 'Tap-12',
              'reported_at': '2026-07-16T08:00:00.000Z',
              'updated_at': '2026-07-16T09:00:00.000Z',
            },
          ).toEntity();

      expect(item.id, 'MR-001');
      expect(item.displayId, 'MR-001');
      expect(item.resource, HousekeepingResource.maintenanceRequests);
      expect(item.status, 'IN_PROGRESS');
      expect(item.subtitle, '[TRIAGE] triage_summary=Leak confirmed');
      expect(item.facilityId, 'FAC-1');
      expect(item.assetLabel, 'Tap-12');
      expect(item.title, 'Tap-12');
      expect(item.targetPath, '/housekeeping/maintenance-requests/MR-001');
      expect(item.timelineAt, isNotNull);
    });
  });
}
