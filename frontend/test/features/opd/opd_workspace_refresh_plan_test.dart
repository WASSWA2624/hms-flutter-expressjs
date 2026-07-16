import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/realtime/realtime_events.dart';
import 'package:hosspi_hms/core/workspace/workspace_event_refresh_plan.dart';
import 'package:hosspi_hms/core/workspace/workspace_refresh_plan.dart';

void main() {
  group('WorkspaceEventRefreshPlan', () {
    test('maps appointment events to appointment slices only', () {
      for (final String event in <String>[
        RealtimeEvents.appointmentCreated,
        RealtimeEvents.appointmentUpdated,
        RealtimeEvents.appointmentRescheduled,
        RealtimeEvents.appointmentCanceled,
      ]) {
        final WorkspaceRefreshPlan plan =
            WorkspaceEventRefreshPlan.forClinicalFlow(event);

        expect(plan.appointments, isTrue, reason: event);
        expect(plan.flows, isFalse, reason: event);
        expect(plan.queue, isFalse, reason: event);
      }
    });

    test('reconciles linked appointment and queue slices for OPD events', () {
      final WorkspaceRefreshPlan plan =
          WorkspaceEventRefreshPlan.forClinicalFlow(
            RealtimeEvents.opdFlowUpdated,
          );

      expect(plan.flows, isTrue);
      expect(plan.triage, isTrue);
      expect(plan.appointments, isTrue);
      expect(plan.queue, isTrue);
      expect(plan.selectedDetail, isTrue);
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
