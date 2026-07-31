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

    test('assignedToMe scope matches providerUserId to current user', () {
      final ClinicalWorklistEntry mine = _entry(
        providerUserId: 'user-1',
        status: 'OPEN',
      );
      final ClinicalWorklistEntry other = _entry(
        providerUserId: 'user-2',
        status: 'OPEN',
      );
      final ClinicalWorklistEntry unassigned = _entry(status: 'OPEN');
      final ClinicalWorklistEntry closed = _entry(
        providerUserId: 'user-1',
        status: 'CLOSED',
      );

      expect(
        clinicalWorklistEntryMatchesScope(
          mine,
          ClinicalQueueScope.assignedToMe,
          currentUserId: 'user-1',
        ),
        isTrue,
      );
      expect(
        clinicalWorklistEntryMatchesScope(
          other,
          ClinicalQueueScope.assignedToMe,
          currentUserId: 'user-1',
        ),
        isFalse,
      );
      expect(
        clinicalWorklistEntryMatchesScope(
          unassigned,
          ClinicalQueueScope.assignedToMe,
          currentUserId: 'user-1',
        ),
        isFalse,
      );
      expect(
        clinicalWorklistEntryMatchesScope(
          closed,
          ClinicalQueueScope.assignedToMe,
          currentUserId: 'user-1',
        ),
        isFalse,
      );
      expect(
        clinicalWorklistEntryMatchesScope(
          mine,
          ClinicalQueueScope.assignedToMe,
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

    test('pending, urgent, and resultsReady scopes exclude terminal entries', () {
      expect(
        clinicalWorklistEntryMatchesScope(
          _entry(status: 'COMPLETED'),
          ClinicalQueueScope.all,
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

    test('facet counts stay independent of the active worklist page', () {
      final ClinicalWorklistFacetCounts facets = clinicalWorklistFacetCounts(
        <ClinicalWorklistEntry>[
          _entry(encounterId: 'enc-1', status: 'OPEN'),
          _entry(
            encounterId: 'enc-2',
            providerUserId: 'user-1',
            status: 'OPEN',
          ),
          _entry(encounterId: 'enc-3', isUrgent: true, status: 'OPEN'),
          _entry(encounterId: 'enc-4', resultsReady: true, status: 'OPEN'),
        ],
        <ClinicalWorklistEntry>[
          _entry(
            encounterId: 'enc-5',
            status: 'COMPLETED',
            updatedAt: DateTime.now(),
          ),
        ],
        currentUserId: 'user-1',
      );

      expect(facets.pending, 4);
      expect(facets.assignedToMe, 1);
      expect(facets.urgent, 1);
      expect(facets.resultsReady, 1);
      expect(facets.completedToday, 1);
    });

    test('completedCount uses independent facet counts', () {
      final ClinicalWorkspaceState state = ClinicalWorkspaceState(
        query: const ClinicalWorklistQuery(),
        worklist: AppPage<ClinicalWorklistEntry>(
          request: const AppPageRequest(),
          items: const <ClinicalWorklistEntry>[],
        ),
        facetCounts: const ClinicalWorklistFacetCounts(completedToday: 3),
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
        facetCounts: const ClinicalWorklistFacetCounts(
          pending: 2,
          urgent: 1,
          resultsReady: 2,
        ),
      );

      expect(state.pendingCount, 2);
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

    test('fromUri remaps ?section=waiting-review to pending (all)', () {
      final ClinicalWorkspaceQuery query = ClinicalWorkspaceQuery.fromUri(
        Uri.parse('/clinical?section=waiting-review'),
      );
      expect(query.section, ClinicalWorkspaceSection.all);
    });

    test('fromUri parses ?section=assigned-to-me', () {
      final ClinicalWorkspaceQuery query = ClinicalWorkspaceQuery.fromUri(
        Uri.parse('/clinical?section=assigned-to-me'),
      );
      expect(query.section, ClinicalWorkspaceSection.assignedToMe);
    });

    test('fromUri parses ?section=results-ready as resultsReady', () {
      final ClinicalWorkspaceQuery query = ClinicalWorkspaceQuery.fromUri(
        Uri.parse('/clinical?section=results-ready'),
      );
      expect(query.section, ClinicalWorkspaceSection.resultsReady);
    });

    test('fromUri remaps ?section=in-consultation to pending (all)', () {
      final ClinicalWorkspaceQuery query = ClinicalWorkspaceQuery.fromUri(
        Uri.parse('/clinical?section=in-consultation'),
      );
      expect(query.section, ClinicalWorkspaceSection.all);
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
        ClinicalWorkspaceSection.all,
      );
      expect(
        ClinicalWorkspaceQuery.fromUri(
          Uri.parse('/clinical?section=pending'),
        ).section,
        ClinicalWorkspaceSection.all,
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
        ClinicalWorkspaceSection.all,
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

  group('clinicalOpdFlowApiId', () {
    test('prefers explicit opdFlowApiId', () {
      expect(
        clinicalOpdFlowApiId(
          _entry(
            encounterPublicId: 'ENC0000004',
            opdFlowApiId: 'flow-explicit',
          ),
        ),
        'flow-explicit',
      );
    });

    test('uses encounter public id for encounter-sourced outpatient rows', () {
      expect(
        clinicalOpdFlowApiId(
          _entry(
            sourceQueue: 'ENCOUNTER',
            encounterId: 'uuid-enc-4',
            encounterPublicId: 'ENC0000004',
            encounterType: 'OUTPATIENT',
          ),
        ),
        'ENC0000004',
      );
    });

    test('returns null for inpatient rows without explicit flow id', () {
      expect(
        clinicalOpdFlowApiId(
          _entry(
            sourceQueue: 'IPD',
            encounterId: 'uuid-ipd',
            encounterPublicId: 'ENC0000099',
            encounterType: 'IPD',
          ),
        ),
        isNull,
      );
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
  String? providerUserId,
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
    providerUserId: providerUserId,
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
