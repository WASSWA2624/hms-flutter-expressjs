import 'package:flutter/material.dart';
import 'package:hosspi_hms/features/nursing/domain/entities/nursing_entities.dart';
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

String nursingPrimaryActionLabel(
  AppLocalizations l10n,
  NursingQueueScope scope,
) {
  return switch (scope) {
    NursingQueueScope.medicationDue => l10n.nursingActionAdministerMedication,
    NursingQueueScope.handoverPending => l10n.nursingActionCreateHandover,
    NursingQueueScope.transferPending => l10n.nursingActionAcknowledgeTransfer,
    NursingQueueScope.dischargePending => l10n.nursingActionDischargeClearance,
    _ => l10n.nursingActionRecordVitals,
  };
}

IconData nursingPrimaryActionIcon(NursingQueueScope scope) {
  return switch (scope) {
    NursingQueueScope.medicationDue => Icons.medication_outlined,
    NursingQueueScope.handoverPending => Icons.swap_horiz_outlined,
    NursingQueueScope.transferPending =>
      Icons.transfer_within_a_station_outlined,
    NursingQueueScope.dischargePending => Icons.fact_check_outlined,
    _ => Icons.monitor_heart_outlined,
  };
}

List<AppTabItem> nursingTabItems(AppLocalizations l10n) {
  return <AppTabItem>[
    AppTabItem(
      id: nursingScopeToQueryValue(NursingQueueScope.all),
      icon: Icons.inventory_2_outlined,
      label: l10n.nursingScopeAllLabel,
    ),
    AppTabItem(
      id: nursingScopeToQueryValue(NursingQueueScope.assignedWard),
      icon: Icons.local_hospital_outlined,
      label: l10n.nursingScopeAssignedWardLabel,
    ),
    AppTabItem(
      id: nursingScopeToQueryValue(NursingQueueScope.urgent),
      icon: Icons.priority_high_outlined,
      label: l10n.nursingScopeUrgentLabel,
    ),
    AppTabItem(
      id: nursingScopeToQueryValue(NursingQueueScope.medicationDue),
      icon: Icons.medication_outlined,
      label: l10n.nursingScopeMedicationDueLabel,
    ),
    AppTabItem(
      id: nursingScopeToQueryValue(NursingQueueScope.handoverPending),
      icon: Icons.swap_horiz_outlined,
      label: l10n.nursingScopeHandoverPendingLabel,
    ),
    AppTabItem(
      id: nursingScopeToQueryValue(NursingQueueScope.transferPending),
      icon: Icons.transfer_within_a_station_outlined,
      label: l10n.nursingScopeTransferPendingLabel,
    ),
    AppTabItem(
      id: nursingScopeToQueryValue(NursingQueueScope.dischargePending),
      icon: Icons.logout_outlined,
      label: l10n.nursingScopeDischargePendingLabel,
    ),
  ];
}
