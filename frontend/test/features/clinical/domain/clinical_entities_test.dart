import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/clinical/domain/entities/clinical_entities.dart';

void main() {
  group('ClinicalWorklistEntry filtering', () {
    test('today scope only includes records updated today', () {
      final DateTime now = DateTime.now();
      final ClinicalWorklistEntry today = _entry(updatedAt: now);
      final ClinicalWorklistEntry yesterday = _entry(
        updatedAt: now.subtract(const Duration(days: 1)),
      );

      expect(
        clinicalWorklistEntryMatchesScope(today, ClinicalQueueScope.today),
        isTrue,
      );
      expect(
        clinicalWorklistEntryMatchesScope(yesterday, ClinicalQueueScope.today),
        isFalse,
      );
    });

    test('search field limits the searched clinical worklist values', () {
      final ClinicalWorklistEntry entry = _entry(
        patientDisplayName: 'Amina Kato',
        providerDisplayName: 'Dr Kizza',
      );

      expect(
        entry.matchesSearch(
          'kizza',
          filters: const ClinicalWorklistFilters(searchField: 'patient'),
        ),
        isFalse,
      );
      expect(
        entry.matchesSearch(
          'kizza',
          filters: const ClinicalWorklistFilters(searchField: 'provider'),
        ),
        isTrue,
      );
      expect(entry.matchesSearch('kizza'), isTrue);
    });

    test('advanced filters match source, status, provider, and date range', () {
      final DateTime updatedAt = DateTime(2026, 5, 18, 10);
      final ClinicalWorklistEntry entry = _entry(
        status: 'OPEN',
        stage: 'WAITING_DOCTOR_REVIEW',
        providerDisplayName: 'Dr Kizza',
        updatedAt: updatedAt,
      );

      expect(
        entry.matchesFilters(
          ClinicalWorklistFilters(
            dateFrom: DateTime(2026, 5, 18),
            dateTo: DateTime(2026, 5, 18),
            sourceQueue: 'OPD',
            status: 'WAITING_DOCTOR_REVIEW',
            provider: 'Dr Kizza',
          ),
        ),
        isTrue,
      );
      expect(
        entry.matchesFilters(const ClinicalWorklistFilters(sourceQueue: 'IPD')),
        isFalse,
      );
    });
  });
}

ClinicalWorklistEntry _entry({
  String sourceQueue = 'OPD',
  String encounterId = 'encounter-1',
  String? patientDisplayName,
  String? providerDisplayName,
  String? status,
  String? stage,
  DateTime? updatedAt,
}) {
  return ClinicalWorklistEntry(
    id: encounterId,
    sourceQueue: sourceQueue,
    encounterId: encounterId,
    patientDisplayName: patientDisplayName,
    providerDisplayName: providerDisplayName,
    status: status,
    stage: stage,
    updatedAt: updatedAt,
  );
}
