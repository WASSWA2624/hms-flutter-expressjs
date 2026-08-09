import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';

void main() {
  group('HrQueue', () {
    test('fromValue resolves known queues case-insensitively', () {
      expect(HrQueue.fromValue('LEAVE_REQUESTS'), HrQueue.leaveRequests);
      expect(HrQueue.fromValue('payroll_drafts'), HrQueue.payrollDrafts);
      expect(HrQueue.fromValue(' overdue_shifts '), HrQueue.overdueShifts);
    });

    test('fromValue returns null for unknown or empty values', () {
      expect(HrQueue.fromValue(null), isNull);
      expect(HrQueue.fromValue(''), isNull);
      expect(HrQueue.fromValue('not_a_queue'), isNull);
    });
  });

  group('HrWorkspaceQuery.fromUri', () {
    test('parses staff focus id and seeds search', () {
      final HrWorkspaceQuery query = HrWorkspaceQuery.fromUri(
        Uri.parse('/hr?id=STF-001'),
      );

      expect(query.focusStaffId, 'STF-001');
      expect(query.search, 'STF-001');
      expect(query.queue, isNull);
      expect(query.hasRouteTargeting, isTrue);
    });

    test('parses queue targeting', () {
      final HrWorkspaceQuery query = HrWorkspaceQuery.fromUri(
        Uri.parse('/hr?queue=PAYROLL_DRAFTS'),
      );

      expect(query.focusStaffId, isNull);
      expect(query.queue, HrQueue.payrollDrafts);
      expect(query.hasRouteTargeting, isTrue);
    });

    test('parses standalone search term', () {
      final HrWorkspaceQuery query = HrWorkspaceQuery.fromUri(
        Uri.parse('/hr?search=Jane'),
      );

      expect(query.focusStaffId, isNull);
      expect(query.queue, isNull);
      expect(query.search, 'Jane');
      expect(query.hasRouteTargeting, isTrue);
    });

    test('parses section tab targeting', () {
      final HrWorkspaceQuery query = HrWorkspaceQuery.fromUri(
        Uri.parse('/hr?section=leave-requests'),
      );

      expect(query.section, 'leave-requests');
      expect(query.hasRouteTargeting, isTrue);
    });

    test('parses tab alias for section', () {
      final HrWorkspaceQuery query = HrWorkspaceQuery.fromUri(
        Uri.parse('/hr?tab=payroll'),
      );

      expect(query.section, 'payroll');
      expect(query.hasRouteTargeting, isTrue);
    });

    test('has no targeting when query string is empty', () {
      final HrWorkspaceQuery query = HrWorkspaceQuery.fromUri(Uri.parse('/hr'));

      expect(query.hasRouteTargeting, isFalse);
      expect(query.section, isEmpty);
    });

    test('prefers staff identifier aliases', () {
      final HrWorkspaceQuery query = HrWorkspaceQuery.fromUri(
        Uri.parse('/hr?staff_profile_id=abc-123'),
      );

      expect(query.focusStaffId, 'abc-123');
    });
  });

  group('HrDeskSection', () {
    test('exposes all expected desk tabs', () {
      expect(
        HrDeskSection.values,
        containsAll(<HrDeskSection>[
          HrDeskSection.staffDirectory,
          HrDeskSection.shiftRoster,
          HrDeskSection.leaveRequests,
          HrDeskSection.swapRequests,
          HrDeskSection.unassignedShifts,
          HrDeskSection.payroll,
          HrDeskSection.access,
        ]),
      );
      expect(HrDeskSection.values.indexOf(HrDeskSection.shiftRoster), 1);
    });

    test('routeQueryValue matches canonical section params', () {
      expect(HrDeskSection.staffDirectory.routeQueryValue, 'staff');
      expect(HrDeskSection.leaveRequests.routeQueryValue, 'leave-requests');
      expect(HrDeskSection.swapRequests.routeQueryValue, 'swap-requests');
      expect(HrDeskSection.shiftRoster.routeQueryValue, 'shift-roster');
      expect(
        HrDeskSection.unassignedShifts.routeQueryValue,
        'unassigned-shifts',
      );
      expect(HrDeskSection.payroll.routeQueryValue, 'payroll');
      expect(HrDeskSection.access.routeQueryValue, 'access');
    });

    test('fromQuery resolves aliases', () {
      expect(
        HrDeskSection.fromQuery('leave-requests'),
        HrDeskSection.leaveRequests,
      );
      expect(HrDeskSection.fromQuery('leaves'), HrDeskSection.leaveRequests);
      expect(HrDeskSection.fromQuery('swap-requests'), HrDeskSection.swapRequests);
      expect(HrDeskSection.fromQuery('roster'), HrDeskSection.shiftRoster);
      expect(
        HrDeskSection.fromQuery('unassigned-shifts'),
        HrDeskSection.unassignedShifts,
      );
      expect(HrDeskSection.fromQuery('roles'), HrDeskSection.access);
      expect(HrDeskSection.fromQuery('unknown'), isNull);
    });

    test('fromQueue maps work queues onto desk tabs', () {
      expect(
        HrDeskSection.fromQueue(HrQueue.leaveRequests),
        HrDeskSection.leaveRequests,
      );
      expect(
        HrDeskSection.fromQueue(HrQueue.swapRequests),
        HrDeskSection.swapRequests,
      );
      expect(
        HrDeskSection.fromQueue(HrQueue.rosterDrafts),
        HrDeskSection.shiftRoster,
      );
      expect(
        HrDeskSection.fromQueue(HrQueue.unassignedShifts),
        HrDeskSection.unassignedShifts,
      );
      expect(
        HrDeskSection.fromQueue(HrQueue.overdueShifts),
        HrDeskSection.unassignedShifts,
      );
      expect(
        HrDeskSection.fromQueue(HrQueue.payrollDrafts),
        HrDeskSection.payroll,
      );
      expect(HrDeskSection.fromQueue(null), isNull);
    });
  });

  group('HrWorkspaceSummary', () {
    test('workloadCount sums all actionable queues', () {
      const HrWorkspaceSummary summary = HrWorkspaceSummary(
        totalStaff: 42,
        leaveRequests: 2,
        swapRequests: 1,
        draftRosters: 3,
        unassignedShifts: 4,
        payrollDraftRuns: 1,
        overdueShifts: 5,
      );

      expect(summary.workloadCount, 16);
    });
  });

  group('HrStaffProfile', () {
    test('effectiveId prefers display id over uuid', () {
      const HrStaffProfile profile = HrStaffProfile(
        id: 'uuid-1',
        displayId: 'STF-9',
      );

      expect(profile.effectiveId, 'STF-9');
    });

    test('displayName falls back through identity fields', () {
      const HrStaffProfile named = HrStaffProfile(
        id: 'uuid-1',
        userFullName: 'Jane Doe',
      );
      const HrStaffProfile numbered = HrStaffProfile(
        id: 'uuid-2',
        staffNumber: 'EMP-7',
      );

      expect(named.displayName, 'Jane Doe');
      expect(numbered.displayName, 'EMP-7');
    });

    test('assignmentLine joins non-empty descriptors', () {
      const HrStaffProfile profile = HrStaffProfile(
        id: 'uuid-1',
        position: 'Nurse',
        departmentName: 'ICU',
      );

      expect(profile.assignmentLine, 'Nurse | ICU');
    });
  });
}
