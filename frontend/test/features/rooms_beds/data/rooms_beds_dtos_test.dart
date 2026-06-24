import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/rooms_beds/data/dtos/rooms_beds_dtos.dart';
import 'package:hosspi_hms/features/rooms_beds/domain/entities/rooms_beds_entities.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';

void main() {
  group('RoomsBeds DTOs', () {
    test('decodes paginated bed assignment records', () {
      final List<BedAssignmentRecord> records = decodeBedAssignmentRecords(
        <String, Object?>{
          'data': <Object?>[
            <String, Object?>{
              'id': 'BAS-001',
              'admission_id': '88eda54e-151e-46a0-9d20-5a7b170dec7d',
              'admission_display_id': 'ADM-001',
              'bed_id': 'BED-001',
              'assigned_at': '2026-05-21T08:30:00.000Z',
              'released_at': null,
            },
            <String, Object?>{
              'id': '',
              'admission_id': 'ADM-002',
              'bed_id': 'BED-002',
            },
          ],
          'pagination': <String, Object?>{'total': 2},
        },
      );

      expect(records, hasLength(1));
      expect(records.single.id, 'BAS-001');
      expect(
        records.single.admissionId,
        '88eda54e-151e-46a0-9d20-5a7b170dec7d',
      );
      expect(records.single.admissionDisplayId, 'ADM-001');
      expect(records.single.bedId, 'BED-001');
      expect(records.single.isActive, isTrue);
      expect(
        records.single.assignedAt,
        DateTime.parse('2026-05-21T08:30:00.000Z'),
      );
    });
    test('decodes admission transfer context from IPD flow payload', () {
      final BedAdmissionContext context = decodeBedAdmissionContext(
        <String, Object?>{
          'data': <String, Object?>{
            'id': 'ADM-001',
            'display_id': 'Admission 001',
            'open_transfer_request': <String, Object?>{
              'id': 'TRQ-001',
              'status': 'REQUESTED',
            },
          },
        },
      );

      expect(context.admissionId, 'ADM-001');
      expect(context.admissionDisplayId, 'Admission 001');
      expect(context.transferRequestId, 'TRQ-001');
      expect(context.transferStatus, 'REQUESTED');
      expect(context.hasOpenTransfer, isTrue);
    });

    test('RoomsBedsQuery parses ward deep link parameters', () {
      final RoomsBedsQuery query = RoomsBedsQuery.fromUri(
        Uri.parse('/rooms-beds?ward=WRD-001&status=CLEANING&search=A1'),
      );

      expect(query.wardId, 'WRD-001');
      expect(query.status, BedSetupStatus.cleaning);
      expect(query.search, 'A1');
      expect(query.hasRouteTargeting, isTrue);
    });
  });
}
