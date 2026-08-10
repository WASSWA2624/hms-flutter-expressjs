import 'package:flutter/material.dart';
import 'package:hosspi_hms/features/hr/domain/entities/hr_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';

/// Canonical work queues for dialog / cross-section Filters browse.
const List<HrQueue> hrWorkspaceQueues = <HrQueue>[
  HrQueue.leaveRequests,
  HrQueue.swapRequests,
  HrQueue.rosterDrafts,
  HrQueue.unassignedShifts,
  HrQueue.payrollDrafts,
];

/// Default queue loaded when selecting a worklist primary tab.
///
/// Each worklist primary owns exactly one queue (flat IA — no nested tabs,
/// no desk queue facet). Overdue deep-links land on Unassigned.
HrQueue? hrDefaultQueueForSection(HrDeskSection section) {
  return switch (section) {
    HrDeskSection.leaveRequests => HrQueue.leaveRequests,
    HrDeskSection.swapRequests => HrQueue.swapRequests,
    HrDeskSection.shiftRoster => HrQueue.rosterDrafts,
    HrDeskSection.unassignedShifts => HrQueue.unassignedShifts,
    HrDeskSection.payroll => HrQueue.payrollDrafts,
    HrDeskSection.staffDirectory || HrDeskSection.access ||
    HrDeskSection.positions => null,
  };
}

/// Queue choices for Filters.
///
/// Desk primaries are 1:1 with a queue — no queue facet on those tabs.
/// Dialog (`section == null`) still offers all workspace queues; overdue
/// appears only when already selected / deep-linked.
List<HrQueue> hrQueuesForSection(HrDeskSection? section, HrQueue selected) {
  if (section != null) {
    final HrQueue? only = hrDefaultQueueForSection(section);
    if (only == null) {
      return const <HrQueue>[];
    }
    if (section == HrDeskSection.unassignedShifts &&
        selected == HrQueue.overdueShifts) {
      return <HrQueue>[HrQueue.unassignedShifts, HrQueue.overdueShifts];
    }
    return <HrQueue>[only];
  }
  if (selected == HrQueue.overdueShifts &&
      !hrWorkspaceQueues.contains(HrQueue.overdueShifts)) {
    return <HrQueue>[...hrWorkspaceQueues, HrQueue.overdueShifts];
  }
  return hrWorkspaceQueues;
}

/// Whether [queue] belongs on [section] (or any section when [section] is null).
bool hrQueueAllowedOnSection(HrDeskSection? section, HrQueue queue) {
  if (section == null) {
    return hrQueuesForSection(null, queue).contains(queue);
  }
  if (section == HrDeskSection.unassignedShifts &&
      queue == HrQueue.overdueShifts) {
    return true;
  }
  return hrDefaultQueueForSection(section) == queue;
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
