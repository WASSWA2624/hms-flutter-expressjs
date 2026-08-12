import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/features/nursing/domain/entities/nursing_entities.dart';
import 'package:hosspi_hms/features/nursing/presentation/nursing_access.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/components/components.dart';

String nursingScopeToQueryValue(NursingQueueScope scope) {
  return switch (scope) {
    NursingQueueScope.all => 'all',
    NursingQueueScope.assignedWard => 'assigned-ward',
    NursingQueueScope.urgent => 'urgent',
    NursingQueueScope.medicationDue => 'medication-due',
    NursingQueueScope.handoverPending => 'handover-pending',
    NursingQueueScope.transferPending => 'transfer-pending',
    NursingQueueScope.dischargePending => 'discharge-pending',
  };
}

NursingQueueScope? nursingScopeFromQueryValue(String? raw) {
  return switch (raw?.trim().toLowerCase()) {
    'all' || '' || null => NursingQueueScope.all,
    'assigned-ward' ||
    'assigned_ward' ||
    'ward' => NursingQueueScope.assignedWard,
    'urgent' || 'critical' => NursingQueueScope.urgent,
    'medication-due' ||
    'medication_due' ||
    'medication' => NursingQueueScope.medicationDue,
    'handover-pending' ||
    'handover_pending' ||
    'handover' => NursingQueueScope.handoverPending,
    'transfer-pending' ||
    'transfer_pending' ||
    'transfer' => NursingQueueScope.transferPending,
    'discharge-pending' ||
    'discharge_pending' ||
    'discharge' => NursingQueueScope.dischargePending,
    _ => null,
  };
}

/// Sibling-count model: dedicated unfiltered [NursingScopeCounts].
/// Active tab with search/advanced filters uses the filtered worklist total.
int nursingScopeTabCount(
  NursingWorkspaceState state,
  NursingQueueScope scope, {
  NursingQueueScope? activeScope,
}) {
  final int scopeTotal = state.scopeCounts.forScope(scope);
  if (activeScope == null || scope != activeScope) {
    return scopeTotal;
  }
  final bool narrowed =
      state.query.search.trim().isNotEmpty || state.query.hasAdvancedFilters;
  if (!narrowed) {
    return scopeTotal;
  }
  return state.worklist.totalItemCount ?? scopeTotal;
}

AppTabCountTone nursingScopeCountTone(NursingQueueScope scope) {
  return switch (scope) {
    NursingQueueScope.urgent => AppTabCountTone.danger,
    NursingQueueScope.medicationDue ||
    NursingQueueScope.handoverPending ||
    NursingQueueScope.transferPending ||
    NursingQueueScope.dischargePending => AppTabCountTone.warning,
    NursingQueueScope.all ||
    NursingQueueScope.assignedWard => AppTabCountTone.info,
  };
}

AppTabItem? _tabItemForScope(
  AppLocalizations l10n,
  NursingWorkspaceState state,
  NursingQueueScope scope, {
  NursingQueueScope? activeScope,
}) {
  final int count = nursingScopeTabCount(
    state,
    scope,
    activeScope: activeScope,
  );
  final AppTabCountTone tone = nursingScopeCountTone(scope);
  return switch (scope) {
    NursingQueueScope.all => AppTabItem(
      id: nursingScopeToQueryValue(NursingQueueScope.all),
      icon: Icons.inventory_2_outlined,
      label: l10n.nursingScopeAllLabel,
      count: count,
      countTone: tone,
    ),
    NursingQueueScope.assignedWard => AppTabItem(
      id: nursingScopeToQueryValue(NursingQueueScope.assignedWard),
      icon: Icons.local_hospital_outlined,
      label: l10n.nursingScopeAssignedWardLabel,
      count: count,
      countTone: tone,
    ),
    NursingQueueScope.urgent => AppTabItem(
      id: nursingScopeToQueryValue(NursingQueueScope.urgent),
      icon: Icons.priority_high_outlined,
      label: l10n.nursingScopeUrgentLabel,
      count: count,
      countTone: tone,
    ),
    NursingQueueScope.medicationDue => AppTabItem(
      id: nursingScopeToQueryValue(NursingQueueScope.medicationDue),
      icon: Icons.medication_outlined,
      label: l10n.nursingScopeMedicationDueLabel,
      count: count,
      countTone: tone,
    ),
    NursingQueueScope.handoverPending => AppTabItem(
      id: nursingScopeToQueryValue(NursingQueueScope.handoverPending),
      icon: Icons.swap_horiz_outlined,
      label: l10n.nursingScopeHandoverPendingLabel,
      count: count,
      countTone: tone,
    ),
    NursingQueueScope.transferPending => AppTabItem(
      id: nursingScopeToQueryValue(NursingQueueScope.transferPending),
      icon: Icons.transfer_within_a_station_outlined,
      label: l10n.nursingScopeTransferPendingLabel,
      count: count,
      countTone: tone,
    ),
    NursingQueueScope.dischargePending => AppTabItem(
      id: nursingScopeToQueryValue(NursingQueueScope.dischargePending),
      icon: Icons.logout_outlined,
      label: l10n.nursingScopeDischargePendingLabel,
      count: count,
      countTone: tone,
    ),
  };
}

List<AppTabItem> nursingTabItems(
  AppLocalizations l10n,
  NursingWorkspaceState state, {
  AppAccessPolicy? policy,
  NursingQueueScope? activeScope,
}) {
  final Iterable<NursingQueueScope> scopes = policy == null
      ? nursingTabStripOrder
      : nursingAllowedScopes(policy);
  return <AppTabItem>[
    for (final NursingQueueScope scope in scopes)
      if (_tabItemForScope(
            l10n,
            state,
            scope,
            activeScope: activeScope,
          )
          case final AppTabItem item)
        item,
  ];
}
