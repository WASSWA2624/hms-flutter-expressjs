import 'package:hosspi_hms/features/radiology/domain/entities/radiology_entities.dart';
import 'package:hosspi_hms/shared/components/components.dart';

/// Sibling-count model: dedicated unfiltered [RadiologySummary] scope totals.
/// Active tab with search / date / advanced filters uses the filtered
/// [RadiologyWorkspaceState.orders] `totalItemCount`.
int radiologySectionTabCount(
  RadiologyWorkspaceState state,
  RadiologyDeskSection section, {
  RadiologyDeskSection? activeSection,
}) {
  if (section.isFollowUps) {
    return 0;
  }
  final int scopeTotal = switch (section) {
    RadiologyDeskSection.worklist => state.workloadCount,
    RadiologyDeskSection.reporting => state.reportingCount,
    RadiologyDeskSection.allOrders => state.historyCount,
    RadiologyDeskSection.followUps => 0,
  };
  if (activeSection == null || section != activeSection) {
    return scopeTotal;
  }
  if (!_radiologyQueryNarrowed(state.query)) {
    return scopeTotal;
  }
  return state.orders.totalItemCount ?? state.orders.items.length;
}

bool _radiologyQueryNarrowed(RadiologyWorkspaceQuery query) {
  return query.search.trim().isNotEmpty ||
      query.from != null ||
      (query.status != null && query.status!.trim().isNotEmpty) ||
      (query.modality != null && query.modality!.trim().isNotEmpty) ||
      (query.priority != null && query.priority!.trim().isNotEmpty) ||
      (query.billingGate != null && query.billingGate!.trim().isNotEmpty);
}

AppTabCountTone radiologySectionCountTone(RadiologyDeskSection section) {
  return switch (section) {
    RadiologyDeskSection.worklist ||
    RadiologyDeskSection.reporting => AppTabCountTone.warning,
    RadiologyDeskSection.allOrders ||
    RadiologyDeskSection.followUps => AppTabCountTone.info,
  };
}
