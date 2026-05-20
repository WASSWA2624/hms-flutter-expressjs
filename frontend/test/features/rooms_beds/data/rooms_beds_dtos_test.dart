import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/rooms_beds/data/dtos/rooms_beds_dtos.dart';
import 'package:hosspi_hms/features/rooms_beds/domain/entities/rooms_beds_entities.dart';

void main() {
  group('RoomsBeds DTOs', () {
    test('decodes paginated bed assignment records', () {
      final List<BedAssignmentRecord> records = decodeBedAssignmentRecords(
        <String, Object?>{
          'data': <Object?>[
            <String, Object?>{
              'id': 'BAS-001',
              'admission_id': 'ADM-001',
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
      expect(records.single.admissionId, 'ADM-001');
      expect(records.single.bedId, 'BED-001');
      expect(records.single.isActive, isTrue);
      expect(
        records.single.assignedAt,
        DateTime.parse('2026-05-21T08:30:00.000Z'),
      );
    });
  });
}
