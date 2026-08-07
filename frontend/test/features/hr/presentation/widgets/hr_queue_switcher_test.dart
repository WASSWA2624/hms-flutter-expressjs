import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_queue_switcher.dart';
import 'package:hosspi_hms/l10n/app_localizations_en.dart';

void main() {
  final AppLocalizationsEn l10n = AppLocalizationsEn();

  group('hrQueuesForSection', () {
    test('each desk primary owns a single queue', () {
      expect(
        hrQueuesForSection(HrDeskSection.leaveRequests, HrQueue.leaveRequests),
        <HrQueue>[HrQueue.leaveRequests],
      );
      expect(
        hrQueuesForSection(HrDeskSection.swapRequests, HrQueue.swapRequests),
        <HrQueue>[HrQueue.swapRequests],
      );
      expect(
        hrQueuesForSection(HrDeskSection.shiftRoster, HrQueue.rosterDrafts),
        <HrQueue>[HrQueue.rosterDrafts],
      );
      expect(
        hrQueuesForSection(
          HrDeskSection.unassignedShifts,
          HrQueue.unassignedShifts,
        ),
        <HrQueue>[HrQueue.unassignedShifts],
      );
      expect(
        hrQueuesForSection(HrDeskSection.payroll, HrQueue.payrollDrafts),
        <HrQueue>[HrQueue.payrollDrafts],
      );
    });

    test('Unassigned exposes overdue only when deep-linked', () {
      expect(
        hrQueuesForSection(
          HrDeskSection.unassignedShifts,
          HrQueue.overdueShifts,
        ),
        <HrQueue>[HrQueue.unassignedShifts, HrQueue.overdueShifts],
      );
    });

    test('Dialog (null section) exposes workspace queues + overdue when selected', () {
      expect(hrQueuesForSection(null, HrQueue.leaveRequests), hrWorkspaceQueues);
      expect(
        hrQueuesForSection(null, HrQueue.overdueShifts),
        <HrQueue>[...hrWorkspaceQueues, HrQueue.overdueShifts],
      );
    });
  });

  group('hrDefaultQueueForSection', () {
    test('defaults match entity-per-tab IA', () {
      expect(
        hrDefaultQueueForSection(HrDeskSection.leaveRequests),
        HrQueue.leaveRequests,
      );
      expect(
        hrDefaultQueueForSection(HrDeskSection.swapRequests),
        HrQueue.swapRequests,
      );
      expect(
        hrDefaultQueueForSection(HrDeskSection.shiftRoster),
        HrQueue.rosterDrafts,
      );
      expect(
        hrDefaultQueueForSection(HrDeskSection.unassignedShifts),
        HrQueue.unassignedShifts,
      );
      expect(
        hrDefaultQueueForSection(HrDeskSection.payroll),
        HrQueue.payrollDrafts,
      );
      expect(hrDefaultQueueForSection(HrDeskSection.staffDirectory), isNull);
    });
  });

  test('hrQueueLabel covers every queue', () {
    for (final HrQueue queue in HrQueue.values) {
      expect(hrQueueLabel(l10n, queue), isNotEmpty);
      expect(hrQueueIcon(queue), isA<IconData>());
    }
  });
}
