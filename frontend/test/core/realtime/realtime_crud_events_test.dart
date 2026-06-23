import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/realtime/realtime_crud_events.dart';

void main() {
  group('RealtimeCrudEvents', () {
    test('matches audit-driven CRUD event suffixes', () {
      expect(RealtimeCrudEvents.matches('department.created'), isTrue);
      expect(RealtimeCrudEvents.matches('appointment.canceled'), isTrue);
      expect(RealtimeCrudEvents.matches('subscription.activated'), isTrue);
      expect(RealtimeCrudEvents.matches('patient.updated'), isTrue);
    });

    test('ignores connection and workflow events', () {
      expect(RealtimeCrudEvents.matches('authenticated'), isFalse);
      expect(RealtimeCrudEvents.matches('opd.flow.updated'), isFalse);
      expect(RealtimeCrudEvents.matches('facility.layout_updated'), isFalse);
    });
  });
}
