import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/theater/domain/entities/theater_entities.dart';

void main() {
  group('TheaterBoardQuery', () {
    test('fromUri parses case id and panel', () {
      final TheaterBoardQuery query = TheaterBoardQuery.fromUri(
        Uri.parse('/theater?id=TC0000123&panel=anesthesia'),
      );

      expect(query.focusCaseId, 'TC0000123');
      expect(query.focusPanel, TheaterDetailPanel.anesthesia);
      expect(query.hasRouteTargeting, isTrue);
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

      expect(
        compareTheaterScheduleEncounters(emergency, opd),
        lessThan(0),
      );
    });
  });

  group('TheaterScheduleEmergencyCase', () {
    test('isOpen recognizes active emergency statuses', () {
      const TheaterScheduleEmergencyCase openCase = TheaterScheduleEmergencyCase(
        id: 'EMC-1',
        status: 'OPEN',
      );
      const TheaterScheduleEmergencyCase closedCase =
          TheaterScheduleEmergencyCase(
        id: 'EMC-2',
        status: 'CLOSED',
      );

      expect(openCase.isOpen, isTrue);
      expect(closedCase.isOpen, isFalse);
    });
  });
}
