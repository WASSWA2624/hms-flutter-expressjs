import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/realtime/realtime_events.dart';
import 'package:hosspi_hms/core/realtime/realtime_message.dart';
import 'package:hosspi_hms/core/workspace/workspace_event_refresh_plan.dart';
import 'package:hosspi_hms/core/workspace/workspace_refresh_plan.dart';

void main() {
  group('WorkspaceEventRefreshPlan', () {
    test('maps appointment events to appointment slices only', () {
      final WorkspaceRefreshPlan plan =
          WorkspaceEventRefreshPlan.forClinicalFlow(
            RealtimeEvents.appointmentCreated,
          );

      expect(plan.appointments, isTrue);
      expect(plan.flows, isFalse);
      expect(plan.queue, isFalse);
    });

    test('maps lab workflow events to workbench slices', () {
      final WorkspaceRefreshPlan plan = WorkspaceEventRefreshPlan.forLab(
        RealtimeEvents.labResultReady,
      );

      expect(plan.primaryList, isTrue);
      expect(plan.selectedDetail, isTrue);
      expect(plan.flows, isFalse);
      expect(plan.appointments, isFalse);
    });

    test('returns empty plan for unknown events', () {
      expect(
        WorkspaceEventRefreshPlan.forClinicalFlow('custom.unknown').isEmpty,
        isTrue,
      );
    });
  });
}
