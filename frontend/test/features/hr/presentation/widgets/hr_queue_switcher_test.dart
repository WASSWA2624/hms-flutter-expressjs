import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/features/hr/presentation/widgets/hr_queue_switcher.dart';
import 'package:hosspi_hms/l10n/app_localizations_en.dart';

void main() {
  final AppLocalizationsEn l10n = AppLocalizationsEn();

  group('hrQueuesForSection', () {
    test('Leave owns leave + swap only', () {
      expect(
        hrQueuesForSection(HrDeskSection.leaveRequests, HrQueue.leaveRequests),
        <HrQueue>[HrQueue.leaveRequests, HrQueue.swapRequests],
      );
    });

    test('Shifts owns roster + unassigned; overdue only when selected', () {
      expect(
        hrQueuesForSection(HrDeskSection.shiftRoster, HrQueue.rosterDrafts),
        <HrQueue>[HrQueue.rosterDrafts, HrQueue.unassignedShifts],
      );
      expect(
        hrQueuesForSection(HrDeskSection.shiftRoster, HrQueue.overdueShifts),
        <HrQueue>[
          HrQueue.rosterDrafts,
          HrQueue.unassignedShifts,
          HrQueue.overdueShifts,
        ],
      );
    });

    test('Payroll owns payroll only', () {
      expect(
        hrQueuesForSection(HrDeskSection.payroll, HrQueue.payrollDrafts),
        <HrQueue>[HrQueue.payrollDrafts],
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
    test('defaults match flat IA', () {
      expect(
        hrDefaultQueueForSection(HrDeskSection.leaveRequests),
        HrQueue.leaveRequests,
      );
      expect(
        hrDefaultQueueForSection(HrDeskSection.shiftRoster),
        HrQueue.rosterDrafts,
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
