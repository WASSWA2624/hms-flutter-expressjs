import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/ipd/data/dtos/ipd_dtos.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';

void main() {
  group('IpdBedBoardEntryDto', () {
    test('maps ward, room, and occupant from occupancy payload', () {
      final IpdBedBoardEntry bed = const IpdBedBoardEntryDto(<String, Object?>{
        'id': 'bed-uuid-1',
        'human_friendly_id': 'BED-1',
        'label': 'Bed 101',
        'status': 'OCCUPIED',
        'ward_name': 'Medical Ward',
        'ward_human_friendly_id': 'WRD-1',
        'room_name': 'Room A',
        'floor': '1',
        'current_admission': <String, Object?>{
          'admission_id': 'adm-uuid-1',
          'admission_display_id': 'ADM-1',
          'patient_display_name': 'Jane Doe',
          'patient_display_id': 'PAT-1',
          'admitted_at': '2026-06-20T07:00:00Z',
        },
      }).toEntity();

      expect(bed.id, 'bed-uuid-1');
      expect(bed.displayId, 'BED-1');
      expect(bed.bedLabel, 'Bed 101');
      expect(bed.status, 'OCCUPIED');
      expect(bed.wardDisplayName, 'Medical Ward');
      expect(bed.roomDisplayName, 'Room A | 1');
      expect(bed.occupantPatientName, 'Jane Doe');
      expect(bed.occupantAdmissionId, 'adm-uuid-1');
      expect(bed.occupantAdmissionDisplayId, 'ADM-1');
      expect(bed.isOccupied, isTrue);
      expect(bed.occupantAdmittedAt, isNotNull);
    });

    test('treats beds without occupancy as vacant', () {
      final IpdBedBoardEntry bed = const IpdBedBoardEntryDto(<String, Object?>{
        'id': 'bed-uuid-2',
        'label': 'Bed 102',
        'status': 'AVAILABLE',
        'ward': <String, Object?>{'name': 'Surgical Ward'},
      }).toEntity();

      expect(bed.occupantAdmissionId, isNull);
      expect(bed.occupantPatientName, isNull);
      expect(bed.isOccupied, isFalse);
      expect(bed.wardDisplayName, 'Surgical Ward');
    });

    test('decodeIpdBedBoard maps a response envelope', () {
      final List<IpdBedBoardEntry> beds = decodeIpdBedBoard(<String, Object?>{
        'data': <Map<String, Object?>>[
          <String, Object?>{'id': 'bed-a', 'label': 'A', 'status': 'AVAILABLE'},
          <String, Object?>{'id': 'bed-b', 'label': 'B', 'status': 'CLEANING'},
          // Entry without an id should be dropped.
          <String, Object?>{'label': 'ghost'},
        ],
      });

      expect(beds, hasLength(2));
      expect(beds.first.id, 'bed-a');
      expect(beds.last.status, 'CLEANING');
    });
  });

  group('IpdAdmissionQuery.fromUri', () {
    test('parses admission id and panel deep-link', () {
      final IpdAdmissionQuery query = IpdAdmissionQuery.fromUri(
        Uri.parse('/ipd?id=ADM-7&panel=discharge'),
      );

      expect(query.focusAdmissionId, 'ADM-7');
      expect(query.search, 'ADM-7');
      expect(query.focusPanel, IpdDetailPanel.discharge);
      expect(query.hasRouteTargeting, isTrue);
    });

    test('maps panel synonyms', () {
      expect(
        IpdAdmissionQuery.fromUri(Uri.parse('/ipd?panel=mar')).focusPanel,
        IpdDetailPanel.medication,
      );
      expect(
        IpdAdmissionQuery.fromUri(Uri.parse('/ipd?panel=bed')).focusPanel,
        IpdDetailPanel.beds,
      );
      expect(
        IpdAdmissionQuery.fromUri(Uri.parse('/ipd?panel=unknown')).focusPanel,
        isNull,
      );
    });
  });
}
