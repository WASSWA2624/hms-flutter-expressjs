import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/theater/domain/entities/theater_entities.dart';
import 'package:hosspi_hms/shared/data/data.dart';

void main() {
  group('TheaterSection', () {
    test('queryValue serializes canonical section params', () {
      expect(TheaterSection.scheduled.queryValue, 'scheduled');
      expect(TheaterSection.inTheater.queryValue, 'in-theater');
      expect(TheaterSection.recovery.queryValue, 'recovery');
      expect(TheaterSection.all.queryValue, 'all');
    });

    test('fromQuery parses all supported variants', () {
      expect(TheaterSectionX.fromQuery('scheduled'), TheaterSection.scheduled);
      expect(TheaterSectionX.fromQuery('in-theater'), TheaterSection.inTheater);
      expect(TheaterSectionX.fromQuery('in_theater'), TheaterSection.inTheater);
      expect(TheaterSectionX.fromQuery('intheater'), TheaterSection.inTheater);
      expect(TheaterSectionX.fromQuery('recovery'), TheaterSection.recovery);
      expect(TheaterSectionX.fromQuery('post-op'), TheaterSection.recovery);
      expect(TheaterSectionX.fromQuery('post_op'), TheaterSection.recovery);
      expect(TheaterSectionX.fromQuery('pacu'), TheaterSection.recovery);
      expect(TheaterSectionX.fromQuery('all'), TheaterSection.all);
      expect(TheaterSectionX.fromQuery(null), TheaterSection.all);
      expect(TheaterSectionX.fromQuery(''), TheaterSection.all);
      expect(TheaterSectionX.fromQuery('unknown'), TheaterSection.all);
    });
  });

  group('TheaterBoardQuery', () {
    test('fromUri parses case id and panel', () {
      final TheaterBoardQuery query = TheaterBoardQuery.fromUri(
        Uri.parse('/theater?id=TC0000123&panel=anesthesia'),
      );

      expect(query.focusCaseId, 'TC0000123');
      expect(query.focusPanel, TheaterDetailPanel.anesthesia);
      expect(query.hasRouteTargeting, isTrue);
    });

    test('fromUri parses section=in-theater for tab deep linking', () {
      final TheaterBoardQuery query = TheaterBoardQuery.fromUri(
        Uri.parse('/theater?section=in-theater&search=Ada'),
      );

      expect(query.section, 'in-theater');
      expect(query.search, 'Ada');
      expect(
        TheaterSectionX.fromQuery(query.section),
        TheaterSection.inTheater,
      );
      expect(query.hasRouteTargeting, isTrue);
    });

    test('fromUri defaults section to all when omitted', () {
      final TheaterBoardQuery query = TheaterBoardQuery.fromUri(
        Uri.parse('/theater'),
      );

      expect(query.section, 'all');
      expect(TheaterSectionX.fromQuery(query.section), TheaterSection.all);
      expect(query.hasRouteTargeting, isFalse);
    });

    test('copyWith preserves and overrides section', () {
      const TheaterBoardQuery original = TheaterBoardQuery(
        section: 'scheduled',
      );
      expect(original.copyWith().section, 'scheduled');
      expect(original.copyWith(section: 'recovery').section, 'recovery');
    });

    test('toCaseQuery defaults to active queue scope', () {
      const TheaterBoardQuery query = TheaterBoardQuery();
      expect(query.toCaseQuery().queueScope, 'ACTIVE');
      expect(query.toCaseQuery().scheduledDate, isNull);
    });

    test('fromUri parses patient and encounter prefill', () {
      final TheaterBoardQuery query = TheaterBoardQuery.fromUri(
        Uri.parse('/theater?patient_id=P-001&encounter_id=ENC-0042'),
      );

      expect(query.initialPatientId, 'P-001');
      expect(query.initialEncounterId, 'ENC-0042');
      expect(query.hasScheduleContext, isTrue);
    });

    test('fromUri parses emergency schedule deep link', () {
      final TheaterBoardQuery query = TheaterBoardQuery.fromUri(
        Uri.parse(
          '/theater?action=schedule&patient_id=P-001&emergency_case_id=EMC-009',
        ),
      );

      expect(query.initialPatientId, 'P-001');
      expect(query.initialEmergencyCaseId, 'EMC-009');
      expect(query.scheduleAction, 'schedule');
      expect(query.shouldOpenScheduleDialog, isTrue);
    });
  });

  group('TheaterWorkspaceState.recoveryCount', () {
    test('counts POST_OP and PACU_HANDOFF cases', () {
      const TheaterWorkspaceState state = TheaterWorkspaceState(
        cases: AppPage<TheaterCase>(
          items: <TheaterCase>[
            TheaterCase(id: '1', workflowStage: 'POST_OP'),
            TheaterCase(id: '2', workflowStage: 'PACU_HANDOFF'),
            TheaterCase(id: '3', workflowStage: 'INTRA_OP'),
            TheaterCase(id: '4', status: 'SCHEDULED'),
          ],
          request: AppPageRequest(),
          totalItemCount: 4,
        ),
        query: TheaterCaseQuery(),
      );

      expect(state.recoveryCount, 2);
      expect(state.scheduledCount, 1);
    });
  });

  group('deriveTheaterSourceKind', () {
    test('maps encounter types to theater source kinds', () {
      expect(deriveTheaterSourceKind('IPD'), 'IPD');
      expect(deriveTheaterSourceKind('ICU'), 'IPD');
      expect(deriveTheaterSourceKind('OPD'), 'OPD');
      expect(deriveTheaterSourceKind('EMERGENCY'), 'EMERGENCY');
      expect(deriveTheaterSourceKind('UNKNOWN'), isNull);
    });
  });

  group('compareTheaterScheduleEncounters', () {
    test('prioritizes emergency encounters before other types', () {
      const TheaterScheduleEncounter emergency = TheaterScheduleEncounter(
        id: 'enc-emergency',
        type: 'EMERGENCY',
      );
      const TheaterScheduleEncounter opd = TheaterScheduleEncounter(
        id: 'enc-opd',
        type: 'OPD',
      );

      expect(compareTheaterScheduleEncounters(emergency, opd), lessThan(0));
    });
  });

  group('TheaterScheduleEmergencyCase', () {
    test('isOpen recognizes active emergency statuses', () {
      const TheaterScheduleEmergencyCase openCase =
          TheaterScheduleEmergencyCase(id: 'EMC-1', status: 'OPEN');
      const TheaterScheduleEmergencyCase closedCase =
          TheaterScheduleEmergencyCase(id: 'EMC-2', status: 'CLOSED');

      expect(openCase.isOpen, isTrue);
      expect(closedCase.isOpen, isFalse);
    });
  });
}
