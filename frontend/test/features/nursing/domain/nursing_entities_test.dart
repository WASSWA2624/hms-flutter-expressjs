import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/nursing/domain/entities/nursing_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

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
        NursingDetailPanel.fromValue('transfer'),
        NursingDetailPanel.transfer,
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

  group('NursingPatientSummary.matchesScope', () {
    test('assignedWard requires hasActiveBed', () {
      const NursingPatientSummary withBed = NursingPatientSummary(
        id: 'adm-1',
        admissionId: 'adm-1',
        hasActiveBed: true,
      );
      const NursingPatientSummary withoutBed = NursingPatientSummary(
        id: 'adm-2',
        admissionId: 'adm-2',
        hasActiveBed: false,
      );
      expect(withBed.matchesScope(NursingQueueScope.assignedWard), isTrue);
      expect(withoutBed.matchesScope(NursingQueueScope.assignedWard), isFalse);
      expect(withBed.matchesScope(NursingQueueScope.all), isTrue);
      expect(withoutBed.matchesScope(NursingQueueScope.all), isTrue);
    });
  });

  group('NursingScopeCounts', () {
    test('fromCatalog and forScope use matchesScope including assignedWard', () {
      const List<NursingPatientSummary> catalog = <NursingPatientSummary>[
        NursingPatientSummary(
          id: 'a',
          admissionId: 'a',
          hasActiveBed: true,
          hasCriticalAlert: true,
        ),
        NursingPatientSummary(
          id: 'b',
          admissionId: 'b',
          hasActiveBed: false,
          medicationDueCount: 1,
        ),
      ];
      final NursingScopeCounts counts = NursingScopeCounts.fromCatalog(catalog);
      expect(counts.all, 2);
      expect(counts.assignedWard, 1);
      expect(counts.urgent, 1);
      expect(counts.medicationDue, 1);
      expect(counts.forScope(NursingQueueScope.all), 2);
      expect(counts.forScope(NursingQueueScope.assignedWard), 1);
      expect(counts.forScope(NursingQueueScope.urgent), 1);
    });

    test('workspace state counts come from scopeCounts', () {
      const NursingWorkspaceState state = NursingWorkspaceState(
        query: NursingWorklistQuery(),
        worklist: AppPage<NursingPatientSummary>(
          items: <NursingPatientSummary>[],
          request: AppPageRequest(),
          totalItemCount: 0,
        ),
        scopeCounts: NursingScopeCounts(
          all: 5,
          handoverPending: 2,
          transferPending: 1,
        ),
        pendingHandovers: <NursingHandover>[
          NursingHandover(id: 'h1', admissionId: 'a'),
        ],
      );
      expect(state.allCount, 5);
      expect(state.handoverPendingCount, 2);
      expect(state.transferPendingCount, 1);
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

  group('NursingWorkspaceQuery', () {
    test('fromUri parses scope, id, and panel correctly', () {
      final Uri uri = Uri.parse('/nursing?scope=urgent&id=abc&panel=vitals');
      final NursingWorkspaceQuery query = NursingWorkspaceQuery.fromUri(uri);
      expect(query.scope, 'urgent');
      expect(query.admissionId, 'abc');
      expect(query.panel, 'vitals');
      expect(query.search, '');
    });

    test('fromUri handles alias parameters', () {
      final Uri uri = Uri.parse(
        '/nursing?section=medication-due&admission_id=X1&detail=handover&q=jones',
      );
      final NursingWorkspaceQuery query = NursingWorkspaceQuery.fromUri(uri);
      expect(query.scope, 'medication-due');
      expect(query.admissionId, 'X1');
      expect(query.panel, 'handover');
      expect(query.search, 'jones');
    });

    test('fromUri returns empty strings for missing parameters', () {
      final Uri uri = Uri.parse('/nursing');
      final NursingWorkspaceQuery query = NursingWorkspaceQuery.fromUri(uri);
      expect(query.scope, '');
      expect(query.search, '');
      expect(query.admissionId, '');
      expect(query.panel, '');
    });

    test('hasRouteTargeting returns true when any parameter is set', () {
      const NursingWorkspaceQuery empty = NursingWorkspaceQuery();
      expect(empty.hasRouteTargeting, isFalse);

      const NursingWorkspaceQuery withScope = NursingWorkspaceQuery(
        scope: 'urgent',
      );
      expect(withScope.hasRouteTargeting, isTrue);

      const NursingWorkspaceQuery withSearch = NursingWorkspaceQuery(
        search: 'Smith',
      );
      expect(withSearch.hasRouteTargeting, isTrue);

      const NursingWorkspaceQuery withId = NursingWorkspaceQuery(
        admissionId: 'abc-123',
      );
      expect(withId.hasRouteTargeting, isTrue);

      const NursingWorkspaceQuery withPanel = NursingWorkspaceQuery(
        panel: 'vitals',
      );
      expect(withPanel.hasRouteTargeting, isTrue);
    });

    test('signature produces distinct strings for different queries', () {
      const NursingWorkspaceQuery q1 = NursingWorkspaceQuery(
        scope: 'urgent',
        admissionId: 'abc',
      );
      const NursingWorkspaceQuery q2 = NursingWorkspaceQuery(
        scope: 'all',
        admissionId: 'abc',
      );
      const NursingWorkspaceQuery q3 = NursingWorkspaceQuery(
        scope: 'urgent',
        admissionId: 'abc',
      );
      expect(q1.signature, isNot(equals(q2.signature)));
      expect(q1.signature, equals(q3.signature));
    });

    test('fromUri picks first matching key from alias list', () {
      final Uri uri = Uri.parse('/nursing?encounterId=ENC1&admissionId=ADM1');
      final NursingWorkspaceQuery query = NursingWorkspaceQuery.fromUri(uri);
      expect(query.admissionId, 'ADM1');
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
