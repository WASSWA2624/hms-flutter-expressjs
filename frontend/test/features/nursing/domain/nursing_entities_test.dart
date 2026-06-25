import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/nursing/domain/entities/nursing_entities.dart';

void main() {
  group('NursingDetailPanel.fromValue', () {
    test('maps known panel aliases', () {
      expect(
        NursingDetailPanel.fromValue('checklist'),
        NursingDetailPanel.checklist,
      );
      expect(
        NursingDetailPanel.fromValue('admission'),
        NursingDetailPanel.checklist,
      );
      expect(NursingDetailPanel.fromValue('VITALS'), NursingDetailPanel.vitals);
      expect(
        NursingDetailPanel.fromValue('mar'),
        NursingDetailPanel.medication,
      );
      expect(
        NursingDetailPanel.fromValue('handover'),
        NursingDetailPanel.handover,
      );
      expect(
        NursingDetailPanel.fromValue('clearance'),
        NursingDetailPanel.discharge,
      );
    });

    test('returns null for unknown or empty values', () {
      expect(NursingDetailPanel.fromValue(null), isNull);
      expect(NursingDetailPanel.fromValue(''), isNull);
      expect(NursingDetailPanel.fromValue('unknown'), isNull);
    });
  });

  group('NursingNoteTags.wrap', () {
    test('prefixes the note body with the tag', () {
      expect(
        NursingNoteTags.wrap(NursingNoteTags.identity, 'Jane | ADM1'),
        '[IDENTITY_CONFIRMED] Jane | ADM1',
      );
    });

    test('omits trailing space when body is empty', () {
      expect(
        NursingNoteTags.wrap(NursingNoteTags.belongings, '   '),
        '[BELONGINGS]',
      );
    });
  });

  group('NursingPatientDetail checklist note helpers', () {
    NursingPatientDetail buildDetail(List<NursingNoteRecord> notes) {
      return NursingPatientDetail(
        summary: const NursingPatientSummary(id: 'adm-1', admissionId: 'adm-1'),
        nursingNotes: notes,
      );
    }

    test('detects the latest note carrying a structured tag', () {
      final NursingPatientDetail detail = buildDetail(<NursingNoteRecord>[
        NursingNoteRecord(
          id: 'n1',
          note: '[ALLERGIES_REVIEWED] Penicillin',
          createdAt: DateTime.utc(2026, 6, 25, 8),
        ),
        NursingNoteRecord(
          id: 'n2',
          note: '[ALLERGIES_REVIEWED] Penicillin and latex',
          createdAt: DateTime.utc(2026, 6, 25, 10),
        ),
        const NursingNoteRecord(id: 'n3', note: 'Routine note'),
      ]);

      expect(detail.hasNursingNoteTag(NursingNoteTags.allergies), isTrue);
      expect(
        detail.latestNursingNoteWithTag(NursingNoteTags.allergies)?.id,
        'n2',
      );
      expect(detail.hasNursingNoteTag(NursingNoteTags.identity), isFalse);
    });

    test('ignores notes without the leading tag', () {
      final NursingPatientDetail detail = buildDetail(<NursingNoteRecord>[
        const NursingNoteRecord(
          id: 'n1',
          note: 'Doctor notified verbally [DOCTOR_NOTIFIED]',
        ),
      ]);
      expect(detail.hasNursingNoteTag(NursingNoteTags.doctorNotified), isFalse);
    });
  });
}
