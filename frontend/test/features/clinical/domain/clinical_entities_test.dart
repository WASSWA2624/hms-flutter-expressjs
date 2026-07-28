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

    test('scopes exclude inpatient and IPD source rows', () {
      final ClinicalWorklistEntry ipd = _entry(
        sourceQueue: 'IPD',
        encounterType: 'IPD',
        stage: 'WAITING_DOCTOR_REVIEW',
        isUrgent: true,
        resultsReady: true,
        status: 'COMPLETED',
        updatedAt: DateTime.now(),
      );
      final ClinicalWorklistEntry inpatientType = _entry(
        encounterType: 'INPATIENT',
        stage: 'WAITING_DOCTOR_REVIEW',
      );

      expect(clinicalWorklistEntryIsOutpatient(ipd), isFalse);
      expect(clinicalWorklistEntryIsOutpatient(inpatientType), isFalse);
      for (final ClinicalQueueScope scope in ClinicalQueueScope.values) {
        expect(clinicalWorklistEntryMatchesScope(ipd, scope), isFalse);
        expect(
          clinicalWorklistEntryMatchesScope(inpatientType, scope),
          isFalse,
        );
      }
    });

    test('inConsultation scope matches consultation-like stages', () {
      final ClinicalWorklistEntry inProgress = _entry(
        status: 'IN_PROGRESS',
        stage: 'IN_PROGRESS',
      );
      final ClinicalWorklistEntry consulting = _entry(
        status: 'OPEN',
        stage: 'CONSULTING',
      );
      final ClinicalWorklistEntry closed = _entry(status: 'CLOSED');

      expect(
        clinicalWorklistEntryMatchesScope(
          inProgress,
          ClinicalQueueScope.inConsultation,
        ),
        isTrue,
      );
      expect(
        clinicalWorklistEntryMatchesScope(
          consulting,
          ClinicalQueueScope.inConsultation,
        ),
        isTrue,
      );
      expect(
        clinicalWorklistEntryMatchesScope(
          closed,
          ClinicalQueueScope.inConsultation,
        ),
        isFalse,
      );
    });

    test('completed scope matches same-day terminal outpatient entries', () {
      final DateTime now = DateTime.now();
      final ClinicalWorklistEntry completedToday = _entry(
        status: 'COMPLETED',
        updatedAt: now,
      );
      final ClinicalWorklistEntry dischargedToday = _entry(
        status: 'DISCHARGED',
        updatedAt: now,
      );
      final ClinicalWorklistEntry completedYesterday = _entry(
        status: 'COMPLETED',
        updatedAt: now.subtract(const Duration(days: 1)),
      );
      final ClinicalWorklistEntry open = _entry(status: 'OPEN');

      expect(
        clinicalWorklistEntryMatchesScope(
          completedToday,
          ClinicalQueueScope.completed,
        ),
        isTrue,
      );
      expect(
        clinicalWorklistEntryMatchesScope(
          dischargedToday,
          ClinicalQueueScope.completed,
        ),
        isTrue,
      );
      expect(
        clinicalWorklistEntryMatchesScope(
          completedYesterday,
          ClinicalQueueScope.completed,
        ),
        isFalse,
      );
      expect(
        clinicalWorklistEntryMatchesScope(open, ClinicalQueueScope.completed),
        isFalse,
      );
    });

    test('waiting review and urgent scopes exclude terminal entries', () {
      expect(
        clinicalWorklistEntryMatchesScope(
          _entry(stage: 'WAITING_DOCTOR_REVIEW', status: 'COMPLETED'),
          ClinicalQueueScope.waitingReview,
        ),
        isFalse,
      );
      expect(
        clinicalWorklistEntryMatchesScope(
          _entry(isUrgent: true, status: 'CLOSED'),
          ClinicalQueueScope.urgent,
        ),
        isFalse,
      );
      expect(
        clinicalWorklistEntryMatchesScope(
          _entry(resultsReady: true, status: 'DISCHARGED'),
          ClinicalQueueScope.resultsReady,
        ),
        isFalse,
      );
    });

    test('inConsultationCount counts non-terminal consultation entries', () {
      final ClinicalWorkspaceState state = ClinicalWorkspaceState(
        query: const ClinicalWorklistQuery(),
        worklist: AppPage<ClinicalWorklistEntry>(
          request: const AppPageRequest(),
          items: <ClinicalWorklistEntry>[
            _entry(encounterId: 'enc-1', stage: 'IN_PROGRESS', status: 'OPEN'),
            _entry(encounterId: 'enc-2', stage: 'CONSULTING', status: 'OPEN'),
            _entry(encounterId: 'enc-3', status: 'COMPLETED'),
          ],
        ),
      );

      expect(state.inConsultationCount, 2);
    });

    test('completedCount counts same-day terminal outpatient entries', () {
      final DateTime now = DateTime.now();
      final ClinicalWorkspaceState state = ClinicalWorkspaceState(
        query: const ClinicalWorklistQuery(),
        worklist: AppPage<ClinicalWorklistEntry>(
          request: const AppPageRequest(),
          items: <ClinicalWorklistEntry>[
            _entry(encounterId: 'enc-1', status: 'OPEN', updatedAt: now),
            _entry(encounterId: 'enc-2', status: 'COMPLETED', updatedAt: now),
            _entry(encounterId: 'enc-3', status: 'DISCHARGED', updatedAt: now),
            _entry(encounterId: 'enc-4', status: 'CANCELLED', updatedAt: now),
            _entry(
              encounterId: 'enc-5',
              status: 'COMPLETED',
              updatedAt: now.subtract(const Duration(days: 1)),
            ),
            _entry(
              encounterId: 'enc-6',
              sourceQueue: 'IPD',
              encounterType: 'IPD',
              status: 'DISCHARGED',
              updatedAt: now,
            ),
          ],
        ),
      );

      expect(state.completedCount, 3);
    });

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

  group('ClinicalWorkspaceSection parsing', () {
    test(
      'fromUri parses ?section=urgent as ClinicalWorkspaceSection.urgent',
      () {
        final ClinicalWorkspaceQuery query = ClinicalWorkspaceQuery.fromUri(
          Uri.parse('/clinical?section=urgent'),
        );
        expect(query.section, ClinicalWorkspaceSection.urgent);
      },
    );

    test('fromUri parses ?section=waiting-review as waitingReview', () {
      final ClinicalWorkspaceQuery query = ClinicalWorkspaceQuery.fromUri(
        Uri.parse('/clinical?section=waiting-review'),
      );
      expect(query.section, ClinicalWorkspaceSection.waitingReview);
    });

    test('fromUri parses ?section=results-ready as resultsReady', () {
      final ClinicalWorkspaceQuery query = ClinicalWorkspaceQuery.fromUri(
        Uri.parse('/clinical?section=results-ready'),
      );
      expect(query.section, ClinicalWorkspaceSection.resultsReady);
    });

    test('fromUri parses ?section=in-consultation as inConsultation', () {
      final ClinicalWorkspaceQuery query = ClinicalWorkspaceQuery.fromUri(
        Uri.parse('/clinical?section=in-consultation'),
      );
      expect(query.section, ClinicalWorkspaceSection.inConsultation);
    });

    test('fromUri parses ?section=completed as completed', () {
      final ClinicalWorkspaceQuery query = ClinicalWorkspaceQuery.fromUri(
        Uri.parse('/clinical?section=completed'),
      );
      expect(query.section, ClinicalWorkspaceSection.completed);
    });

    test('fromUri defaults to all when section is missing', () {
      final ClinicalWorkspaceQuery query = ClinicalWorkspaceQuery.fromUri(
        Uri.parse('/clinical'),
      );
      expect(query.section, ClinicalWorkspaceSection.all);
    });

    test('fromUri accepts ?tab= alias for section', () {
      final ClinicalWorkspaceQuery query = ClinicalWorkspaceQuery.fromUri(
        Uri.parse('/clinical?tab=urgent'),
      );
      expect(query.section, ClinicalWorkspaceSection.urgent);
    });

    test('fromUri parses alternate aliases for sections', () {
      expect(
        ClinicalWorkspaceQuery.fromUri(
          Uri.parse('/clinical?section=review'),
        ).section,
        ClinicalWorkspaceSection.waitingReview,
      );
      expect(
        ClinicalWorkspaceQuery.fromUri(
          Uri.parse('/clinical?section=results'),
        ).section,
        ClinicalWorkspaceSection.resultsReady,
      );
      expect(
        ClinicalWorkspaceQuery.fromUri(
          Uri.parse('/clinical?section=follow-ups'),
        ).section,
        ClinicalWorkspaceSection.followUps,
      );
      expect(
        ClinicalWorkspaceQuery.fromUri(
          Uri.parse('/clinical?section=consultation'),
        ).section,
        ClinicalWorkspaceSection.inConsultation,
      );
      expect(
        ClinicalWorkspaceQuery.fromUri(
          Uri.parse('/clinical?section=closed'),
        ).section,
        ClinicalWorkspaceSection.completed,
      );
      expect(
        ClinicalWorkspaceQuery.fromUri(
          Uri.parse('/clinical?section=done'),
        ).section,
        ClinicalWorkspaceSection.completed,
      );
    });

    test('panel key no longer conflicts with section parsing', () {
      final ClinicalWorkspaceQuery query = ClinicalWorkspaceQuery.fromUri(
        Uri.parse('/clinical?section=urgent&panel=details'),
      );
      expect(query.section, ClinicalWorkspaceSection.urgent);
      expect(query.panel, 'details');
    });

    test('hasRouteTargeting returns true for non-default section', () {
      const ClinicalWorkspaceQuery query = ClinicalWorkspaceQuery(
        section: ClinicalWorkspaceSection.urgent,
      );
      expect(query.hasRouteTargeting, isTrue);
    });

    test(
      'hasRouteTargeting returns false for default section with no params',
      () {
        const ClinicalWorkspaceQuery query = ClinicalWorkspaceQuery();
        expect(query.hasRouteTargeting, isFalse);
      },
    );

    test('signature includes section name', () {
      const ClinicalWorkspaceQuery query = ClinicalWorkspaceQuery(
        section: ClinicalWorkspaceSection.resultsReady,
        encounterId: 'enc-1',
      );
      expect(query.signature, contains('resultsReady'));
      expect(query.signature, contains('enc-1'));
    });
  });
}

ClinicalWorklistEntry _entry({
  String sourceQueue = 'OPD',
  String encounterId = 'encounter-1',
  String? encounterPublicId,
  String? encounterType,
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
    encounterType: encounterType,
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
