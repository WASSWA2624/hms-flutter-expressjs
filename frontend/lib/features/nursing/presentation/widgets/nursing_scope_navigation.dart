import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/features/nursing/domain/entities/nursing_entities.dart';
import 'package:hosspi_hms/features/nursing/presentation/nursing_access.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_helpers.dart';
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

int? _tabCountOrNull(int value) => value > 0 ? value : null;

List<AppTabItem> nursingTabItems(
  AppLocalizations l10n,
  NursingWorkspaceState state, {
  AppAccessPolicy? policy,
}) {
  final List<NursingQueueScope> scopes = policy == null
      ? NursingQueueScope.values
      : nursingAllowedScopes(policy);
  return <AppTabItem>[
    for (final NursingQueueScope scope in scopes)
      _tabItemForScope(l10n, state, scope),
  ];
}

AppTabItem _tabItemForScope(
  AppLocalizations l10n,
  NursingWorkspaceState state,
  NursingQueueScope scope,
) {
  return switch (scope) {
    NursingQueueScope.all => AppTabItem(
      id: nursingScopeToQueryValue(scope),
      icon: Icons.inventory_2_outlined,
      label: l10n.nursingScopeAllLabel,
      count: _tabCountOrNull(nursingPageTotal(state.worklist)),
    ),
    NursingQueueScope.assignedWard => AppTabItem(
      id: nursingScopeToQueryValue(scope),
      icon: Icons.local_hospital_outlined,
      label: l10n.nursingScopeAssignedWardLabel,
      count: _tabCountOrNull(state.assignedWardCount),
    ),
    NursingQueueScope.urgent => AppTabItem(
      id: nursingScopeToQueryValue(scope),
      icon: Icons.priority_high_outlined,
      label: l10n.nursingScopeUrgentLabel,
      count: _tabCountOrNull(state.urgentCount),
      countTone: AppTabCountTone.danger,
    ),
    NursingQueueScope.medicationDue => AppTabItem(
      id: nursingScopeToQueryValue(scope),
      icon: Icons.medication_outlined,
      label: l10n.nursingScopeMedicationDueLabel,
      count: _tabCountOrNull(state.medicationDueCount),
      countTone: AppTabCountTone.warning,
    ),
    NursingQueueScope.handoverPending => AppTabItem(
      id: nursingScopeToQueryValue(scope),
      icon: Icons.swap_horiz_outlined,
      label: l10n.nursingScopeHandoverPendingLabel,
      count: _tabCountOrNull(state.handoverPendingCount),
    ),
    NursingQueueScope.transferPending => AppTabItem(
      id: nursingScopeToQueryValue(scope),
      icon: Icons.transfer_within_a_station_outlined,
      label: l10n.nursingScopeTransferPendingLabel,
      count: _tabCountOrNull(state.transferPendingCount),
      countTone: AppTabCountTone.warning,
    ),
    NursingQueueScope.dischargePending => AppTabItem(
      id: nursingScopeToQueryValue(scope),
      icon: Icons.logout_outlined,
      label: l10n.nursingScopeDischargePendingLabel,
      count: _tabCountOrNull(state.dischargePendingCount),
    ),
  };
}
