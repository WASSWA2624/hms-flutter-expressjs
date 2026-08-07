import 'package:flutter/material.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';

/// Canonical work queues shown in Filters (dialog / cross-section browse).
const List<HrQueue> hrWorkspaceQueues = <HrQueue>[
  HrQueue.leaveRequests,
  HrQueue.swapRequests,
  HrQueue.rosterDrafts,
  HrQueue.unassignedShifts,
  HrQueue.payrollDrafts,
];

/// Default queue loaded when selecting a worklist primary tab.
HrQueue? hrDefaultQueueForSection(HrDeskSection section) {
  return switch (section) {
    HrDeskSection.leaveRequests => HrQueue.leaveRequests,
    HrDeskSection.shiftRoster => HrQueue.rosterDrafts,
    HrDeskSection.payroll => HrQueue.payrollDrafts,
    HrDeskSection.staffDirectory || HrDeskSection.access => null,
  };
}

/// Section-scoped queue facet choices (Filters — not a nested tab strip).
///
/// Overdue appears only when already selected / deep-linked.
List<HrQueue> hrQueuesForSection(HrDeskSection? section, HrQueue selected) {
  final List<HrQueue> base = switch (section) {
    HrDeskSection.leaveRequests => <HrQueue>[
      HrQueue.leaveRequests,
      HrQueue.swapRequests,
    ],
    HrDeskSection.shiftRoster => <HrQueue>[
      HrQueue.rosterDrafts,
      HrQueue.unassignedShifts,
    ],
    HrDeskSection.payroll => <HrQueue>[HrQueue.payrollDrafts],
    // Dialog / cross-section browse: all workspace queues.
    null || HrDeskSection.staffDirectory || HrDeskSection.access =>
      hrWorkspaceQueues,
  };
  if (selected == HrQueue.overdueShifts &&
      section != HrDeskSection.leaveRequests &&
      section != HrDeskSection.payroll &&
      !base.contains(HrQueue.overdueShifts)) {
    return <HrQueue>[...base, HrQueue.overdueShifts];
  }
  return base;
}

/// Whether [queue] belongs on [section] (or any section when [section] is null).
bool hrQueueAllowedOnSection(HrDeskSection? section, HrQueue queue) {
  return hrQueuesForSection(section, queue).contains(queue);
}

String hrQueueLabel(AppLocalizations l10n, HrQueue queue) {
  return switch (queue) {
    HrQueue.leaveRequests => l10n.hrQueueLeaveRequests,
    HrQueue.swapRequests => l10n.hrQueueSwapRequests,
    HrQueue.rosterDrafts => l10n.hrQueueRosterDrafts,
    HrQueue.unassignedShifts => l10n.hrQueueUnassignedShifts,
    HrQueue.payrollDrafts => l10n.hrQueuePayrollDrafts,
    HrQueue.overdueShifts => l10n.hrQueueOverdueShifts,
  };
}

IconData hrQueueIcon(HrQueue queue) {
  return switch (queue) {
    HrQueue.leaveRequests => Icons.event_busy_outlined,
    HrQueue.swapRequests => Icons.swap_horiz_outlined,
    HrQueue.rosterDrafts => Icons.calendar_month_outlined,
    HrQueue.unassignedShifts => Icons.pending_actions_outlined,
    HrQueue.payrollDrafts => Icons.payments_outlined,
    HrQueue.overdueShifts => Icons.warning_amber_outlined,
  };
}
