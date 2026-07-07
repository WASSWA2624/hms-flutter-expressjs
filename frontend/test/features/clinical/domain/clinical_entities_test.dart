import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/clinical/domain/entities/clinical_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

void main() {
  group('ClinicalWorklistEntry filtering', () {
    test('default query shows all active clinical work', () {
      expect(const ClinicalWorklistQuery().scope, ClinicalQueueScope.all);
    });

    test('all scope includes records from any date', () {
      final DateTime now = DateTime.now();
      final ClinicalWorklistEntry yesterday = _entry(
        updatedAt: now.subtract(const Duration(days: 1)),
      );

      expect(
        clinicalWorklistEntryMatchesScope(yesterday, ClinicalQueueScope.all),
        isTrue,
      );
    });

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

    test(
      'worklist patient secondary line prefers age/sex over identifiers',
      () {
        final ClinicalWorklistEntry withAgeSex = _entry(
          patientDisplayName: 'Amina Kato',
          patientAgeSex: '32 / F',
        );
        const ClinicalWorklistEntry withIdOnly = ClinicalWorklistEntry(
          id: 'encounter-2',
          sourceQueue: 'OPD',
          encounterId: 'encounter-2',
          patientDisplayName: 'John Doe',
          patientPublicId: 'PAT000002',
          patientPhone: '+256700000002',
        );

        expect(withAgeSex.worklistPatientSecondaryLine, '32 / F');
        expect(withIdOnly.worklistPatientSecondaryLine, 'PAT000002');
      },
    );

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
      expect(
        _entry().matchesFilters(
          const ClinicalWorklistFilters(
            provider: clinicalUnassignedProviderFilterValue,
          ),
        ),
        isTrue,
      );
      expect(
        _entry(providerDisplayName: 'Dr Kizza').matchesFilters(
          const ClinicalWorklistFilters(
            provider: clinicalUnassignedProviderFilterValue,
          ),
        ),
        isFalse,
      );
    });

    test(
      'deduplicates one encounter across generic, OPD, and triage queues',
      () {
        final List<ClinicalWorklistEntry> entries =
            deduplicateClinicalWorklistEntries(<ClinicalWorklistEntry>[
              _entry(
                sourceQueue: 'ENCOUNTER',
                encounterId: 'enc-1',
                patientDisplayName: 'Joshua Suuna',
                patientGender: 'MALE',
                status: 'OPEN',
              ),
              _entry(
                encounterId: 'enc-1',
                encounterPublicId: 'ENC0000010',
                stage: 'WAITING_VITALS',
                opdFlowApiId: 'ENC0000010',
              ),
              _entry(
                sourceQueue: 'TRIAGE',
                encounterId: 'enc-1',
                encounterPublicId: 'ENC0000010',
                stage: 'WAITING_VITALS',
                opdFlowApiId: 'ENC0000010',
              ),
            ]);

        expect(entries, hasLength(1));
        expect(entries.single.sourceQueue, 'TRIAGE');
        expect(entries.single.opdFlowApiId, 'ENC0000010');
        expect(entries.single.patientDisplayName, 'Joshua Suuna');
        expect(entries.single.patientGender, 'MALE');
      },
    );

    test(
      'prefers OPD flow rows over generic encounter rows for disposition',
      () {
        final List<ClinicalWorklistEntry> entries =
            deduplicateClinicalWorklistEntries(<ClinicalWorklistEntry>[
              _entry(sourceQueue: 'ENCOUNTER', encounterId: 'enc-1'),
              _entry(
                encounterId: 'enc-1',
                stage: 'WAITING_DOCTOR_REVIEW',
                opdFlowApiId: 'ENC0000010',
              ),
            ]);

        expect(entries, hasLength(1));
        expect(entries.single.sourceQueue, 'OPD');
        expect(entries.single.opdFlowApiId, 'ENC0000010');
      },
    );

    test('deduplicates clinical workload count across action categories', () {
      final ClinicalWorkspaceState state = ClinicalWorkspaceState(
        query: const ClinicalWorklistQuery(),
        worklist: AppPage<ClinicalWorklistEntry>(
          request: const AppPageRequest(),
          items: <ClinicalWorklistEntry>[
            _entry(
              encounterId: 'enc-1',
              stage: 'WAITING_DOCTOR_REVIEW',
              nextStep: 'REVIEW_RESULTS',
              isUrgent: true,
              resultsReady: true,
            ),
            _entry(
              encounterId: 'enc-2',
              stage: 'WAITING_DISPOSITION',
              resultsReady: true,
            ),
            _entry(
              encounterId: 'enc-3',
              status: 'CLOSED',
              stage: 'WAITING_DOCTOR_REVIEW',
              isUrgent: true,
              resultsReady: true,
            ),
          ],
        ),
      );

      expect(state.waitingReviewCount, 1);
      expect(state.urgentCount, 1);
      expect(state.resultsReadyCount, 2);
      expect(state.workloadCount, 2);
    });
  });
}

ClinicalWorklistEntry _entry({
  String sourceQueue = 'OPD',
  String encounterId = 'encounter-1',
  String? encounterPublicId,
  String? patientDisplayName,
  String? patientGender,
  String? patientAgeSex,
  String? providerDisplayName,
  String? status,
  String? stage,
  String? nextStep,
  String? opdFlowApiId,
  DateTime? updatedAt,
  bool isUrgent = false,
  bool resultsReady = false,
}) {
  return ClinicalWorklistEntry(
    id: encounterId,
    sourceQueue: sourceQueue,
    encounterId: encounterId,
    encounterPublicId: encounterPublicId,
    patientDisplayName: patientDisplayName,
    patientGender: patientGender,
    patientAgeSex: patientAgeSex,
    providerDisplayName: providerDisplayName,
    status: status,
    stage: stage,
    nextStep: nextStep,
    opdFlowApiId: opdFlowApiId,
    updatedAt: updatedAt,
    isUrgent: isUrgent,
    resultsReady: resultsReady,
  );
}
