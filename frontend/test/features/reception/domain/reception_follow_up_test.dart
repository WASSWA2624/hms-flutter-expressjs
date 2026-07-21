import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/reception/domain/entities/reception_entities.dart';

void main() {
  group('ReceptionFollowUpEntry', () {
    test('fromJson projects contact and scheduled_at', () {
      final ReceptionFollowUpEntry entry = ReceptionFollowUpEntry.fromJson(
        <String, Object?>{
          'id': 'fu-uuid',
          'human_friendly_id': 'FU-1',
          'encounter_id': 'ENC-1',
          'patient_id': 'PAT-1',
          'patient_display_name': 'Ada Lovelace',
          'patient_primary_phone': '+256700000001',
          'patient_primary_email': 'ada@example.com',
          'encounter_type': 'OPD',
          'scheduled_at': '2026-07-22T09:30:00.000Z',
          'status': 'SCHEDULED',
          'notes': 'Call about meds',
        },
      );

      expect(entry.id, 'FU-1');
      expect(entry.encounterId, 'ENC-1');
      expect(entry.patientId, 'PAT-1');
      expect(entry.patientIdentifier, 'PAT-1');
      expect(entry.patientDisplayName, 'Ada Lovelace');
      expect(entry.patientPhone, '+256700000001');
      expect(entry.patientEmail, 'ada@example.com');
      expect(entry.encounterType, 'OPD');
      expect(entry.scheduledAt.toUtc().toIso8601String(), '2026-07-22T09:30:00.000Z');
      expect(entry.isScheduled, isTrue);
      expect(entry.notes, 'Call about meds');
    });

    test('sorts by scheduled_at ascending for worklist order', () {
      final List<ReceptionFollowUpEntry> entries = <ReceptionFollowUpEntry>[
        ReceptionFollowUpEntry(
          id: 'later',
          encounterId: 'e2',
          patientId: 'p2',
          patientIdentifier: 'p2',
          scheduledAt: DateTime.utc(2026, 7, 23),
        ),
        ReceptionFollowUpEntry(
          id: 'earlier',
          encounterId: 'e1',
          patientId: 'p1',
          patientIdentifier: 'p1',
          scheduledAt: DateTime.utc(2026, 7, 21),
        ),
      ]..sort(
        (ReceptionFollowUpEntry a, ReceptionFollowUpEntry b) =>
            a.scheduledAt.compareTo(b.scheduledAt),
      );

      expect(entries.first.id, 'earlier');
      expect(entries.last.id, 'later');
    });
  });
}
