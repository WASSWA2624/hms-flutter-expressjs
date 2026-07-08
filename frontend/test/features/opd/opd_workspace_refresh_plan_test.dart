import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/realtime/realtime_events.dart';
import 'package:hosspi_hms/core/realtime/realtime_message.dart';
import 'package:hosspi_hms/core/workspace/workspace_refresh_plan.dart';
import 'package:hosspi_hms/features/opd/presentation/controllers/opd_workspace_refresh_plan.dart';

void main() {
  group('OpdWorkspaceRefreshPlan', () {
    test('maps appointment events to appointment slices only', () {
      final WorkspaceRefreshPlan plan = OpdWorkspaceRefreshPlan.forEvent(
        RealtimeEvents.appointmentCreated,
      );

      expect(plan.appointments, isTrue);
      expect(plan.flows, isFalse);
      expect(plan.queue, isFalse);
    });

    test('maps lab workflow events to flow workspace slices', () {
      final WorkspaceRefreshPlan plan = OpdWorkspaceRefreshPlan.forMessage(
        const RealtimeMessage(event: RealtimeEvents.labResultReady),
      );

      expect(plan.flows, isTrue);
      expect(plan.triage, isTrue);
      expect(plan.summaryCounts, isTrue);
      expect(plan.appointments, isFalse);
    });

    test('returns empty plan for unknown events', () {
      expect(
        OpdWorkspaceRefreshPlan.forEvent('custom.unknown').isEmpty,
        isTrue,
      );
    });
  });
}
