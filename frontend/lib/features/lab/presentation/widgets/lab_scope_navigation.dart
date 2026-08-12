import 'package:hosspi_hms/features/lab/domain/entities/lab_entities.dart';
import 'package:hosspi_hms/shared/components/components.dart';

/// Sibling-count model: dedicated unfiltered [LabWorkbenchSummary] patient totals.
/// Active tab with search/date/client advanced filters uses the filtered total.
int labSectionTabCount(
  LabWorkspaceState state,
  LabDeskSection section, {
  LabDeskSection? activeSection,
  int? activeClientFilteredTotal,
}) {
  if (section.isFollowUps) {
    return 0;
  }
  const LabWorkbenchView view = LabWorkbenchView.patients;
  final int scopeTotal = switch (section) {
    LabDeskSection.worklist => state.summary.totalForView(view),
    LabDeskSection.collection => state.summary.collectionForView(view),
    LabDeskSection.critical => state.summary.criticalForView(view),
    LabDeskSection.completed => state.summary.completedForView(view),
    LabDeskSection.followUps => 0,
  };
  if (activeSection == null || section != activeSection) {
    return scopeTotal;
  }
  final bool serverNarrowed =
      state.query.search.trim().isNotEmpty ||
      state.query.orderedFrom != null ||
      state.query.orderedTo != null;
  final bool clientNarrowed = activeClientFilteredTotal != null;
  if (!serverNarrowed && !clientNarrowed) {
    return scopeTotal;
  }
  if (clientNarrowed) {
    return activeClientFilteredTotal;
  }
  return state.worklist.totalItemCount ?? state.worklist.items.length;
}

AppTabCountTone labSectionCountTone(LabDeskSection section) {
  return switch (section) {
    LabDeskSection.critical => AppTabCountTone.danger,
    LabDeskSection.collection => AppTabCountTone.warning,
    LabDeskSection.worklist ||
    LabDeskSection.completed ||
    LabDeskSection.followUps => AppTabCountTone.info,
  };
}
