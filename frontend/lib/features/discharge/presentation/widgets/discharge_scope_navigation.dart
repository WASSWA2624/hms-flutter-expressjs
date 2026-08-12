import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/features/discharge/domain/entities/discharge_entities.dart';
import 'package:hosspi_hms/features/discharge/presentation/discharge_access.dart';
import 'package:hosspi_hms/features/ipd/domain/entities/ipd_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';

String dischargeSectionToQueryValue(DischargeDeskSection section) {
  return switch (section) {
    DischargeDeskSection.all => 'all',
    DischargeDeskSection.planned => 'planned',
    DischargeDeskSection.pendingClearance => 'pending',
    DischargeDeskSection.completed => 'completed',
    DischargeDeskSection.followUps => 'follow-ups',
  };
}

DischargeDeskSection? dischargeSectionFromQuery(String? raw) {
  switch ((raw ?? '').trim().toLowerCase()) {
    case 'all':
      return DischargeDeskSection.all;
    case 'planned':
      return DischargeDeskSection.planned;
    case 'pending':
    case 'pending_clearance':
    case 'pending-clearance':
    case 'pendingclearance':
      return DischargeDeskSection.pendingClearance;
    case 'completed':
    case 'discharged':
      return DischargeDeskSection.completed;
    case 'follow-ups':
    case 'follow_ups':
    case 'followups':
      return DischargeDeskSection.followUps;
    default:
      return null;
  }
}

/// Sibling-count model: dedicated unfiltered [DischargeSectionCounts].
/// Active tab with search/advanced filters uses the filtered section total.
int dischargeSectionTabCount(
  DischargeWorkspaceState state,
  DischargeDeskSection section, {
  DischargeDeskSection? activeSection,
  int? followUpsCount,
}) {
  if (section == DischargeDeskSection.followUps) {
    return followUpsCount ?? 0;
  }
  final int scopeTotal = state.sectionCounts.forSection(section);
  if (activeSection == null || section != activeSection) {
    return scopeTotal;
  }
  final bool narrowed =
      state.query.search.trim().isNotEmpty || state.query.hasAdvancedFilters;
  if (!narrowed) {
    return scopeTotal;
  }
  return state.queue.items
      .where(
        (IpdAdmissionSummary item) =>
            matchesDischargeDeskSection(item, section),
      )
      .length;
}

AppTabCountTone dischargeSectionCountTone(DischargeDeskSection section) {
  return switch (section) {
    DischargeDeskSection.planned ||
    DischargeDeskSection.pendingClearance => AppTabCountTone.warning,
    DischargeDeskSection.all ||
    DischargeDeskSection.completed ||
    DischargeDeskSection.followUps => AppTabCountTone.info,
  };
}

IconData dischargeSectionIcon(DischargeDeskSection section) {
  return switch (section) {
    DischargeDeskSection.all => Icons.inventory_2_outlined,
    DischargeDeskSection.planned => Icons.event_available_outlined,
    DischargeDeskSection.pendingClearance => Icons.pending_actions_outlined,
    DischargeDeskSection.completed => Icons.check_circle_outline,
    DischargeDeskSection.followUps => Icons.phone_callback_outlined,
  };
}

String dischargeSectionLabel(
  AppLocalizations l10n,
  DischargeDeskSection section,
) {
  return switch (section) {
    DischargeDeskSection.all => l10n.dischargeSectionAll,
    DischargeDeskSection.planned => l10n.dischargeSectionPlanned,
    DischargeDeskSection.pendingClearance =>
      l10n.dischargeSectionPendingClearance,
    DischargeDeskSection.completed => l10n.dischargeSectionCompleted,
    DischargeDeskSection.followUps => l10n.dischargeSectionFollowUps,
  };
}

List<AppTabItem> dischargeTabItems(
  AppLocalizations l10n,
  DischargeWorkspaceState state, {
  AppAccessPolicy? policy,
  DischargeDeskSection? activeSection,
  int? followUpsCount,
}) {
  final Iterable<DischargeDeskSection> sections = policy == null
      ? DischargeDeskSection.values
      : dischargeAllowedSections(policy);
  return <AppTabItem>[
    for (final DischargeDeskSection section in sections)
      AppTabItem(
        id: section.name,
        icon: dischargeSectionIcon(section),
        label: dischargeSectionLabel(l10n, section),
        count: dischargeSectionTabCount(
          state,
          section,
          activeSection: activeSection,
          followUpsCount: followUpsCount,
        ),
        countTone: dischargeSectionCountTone(section),
      ),
  ];
}
