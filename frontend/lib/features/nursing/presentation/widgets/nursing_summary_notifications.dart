import 'package:flutter/material.dart';
import 'package:hosspi_hms/features/nursing/domain/entities/nursing_entities.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_helpers.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_scope_navigation.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

List<AppWorkspaceSummaryNotification> nursingSummaryNotifications({
  required AppLocalizations l10n,
  required NursingWorkspaceState state,
  required ValueChanged<String> onTabTapped,
}) {
  return <AppWorkspaceSummaryNotification>[
    if (nursingPageTotal(state.worklist) > 0)
      AppWorkspaceSummaryNotification(
        label: 'All nursing worklist',
        count: nursingPageTotal(state.worklist),
        icon: Icons.inventory_2_outlined,
        tone: AppWorkspaceStatusTone.info,
        onSelected: () {
          onTabTapped(nursingScopeToQueryValue(NursingQueueScope.all));
        },
      ),
    if (state.assignedWardCount > 0)
      AppWorkspaceSummaryNotification(
        label: l10n.nursingAssignedWardSummaryLabel,
        count: state.assignedWardCount,
        icon: Icons.local_hospital_outlined,
        tone: AppWorkspaceStatusTone.info,
        onSelected: () {
          onTabTapped(nursingScopeToQueryValue(NursingQueueScope.assignedWard));
        },
      ),
    if (state.urgentCount > 0)
      AppWorkspaceSummaryNotification(
        label: l10n.nursingUrgentSummaryLabel,
        count: state.urgentCount,
        icon: Icons.priority_high_outlined,
        tone: AppWorkspaceStatusTone.error,
        onSelected: () {
          onTabTapped(nursingScopeToQueryValue(NursingQueueScope.urgent));
        },
      ),
    if (state.medicationDueCount > 0)
      AppWorkspaceSummaryNotification(
        label: l10n.nursingMedicationDueSummaryLabel,
        count: state.medicationDueCount,
        icon: Icons.medication_outlined,
        tone: AppWorkspaceStatusTone.warning,
        onSelected: () {
          onTabTapped(
            nursingScopeToQueryValue(NursingQueueScope.medicationDue),
          );
        },
      ),
    if (state.handoverPendingCount > 0)
      AppWorkspaceSummaryNotification(
        label: l10n.nursingHandoverPendingSummaryLabel,
        count: state.handoverPendingCount,
        icon: Icons.swap_horiz_outlined,
        onSelected: () {
          onTabTapped(
            nursingScopeToQueryValue(NursingQueueScope.handoverPending),
          );
        },
      ),
    if (state.transferPendingCount > 0)
      AppWorkspaceSummaryNotification(
        label: l10n.nursingTransferPendingSummaryLabel,
        count: state.transferPendingCount,
        icon: Icons.transfer_within_a_station_outlined,
        tone: AppWorkspaceStatusTone.warning,
        onSelected: () {
          onTabTapped(
            nursingScopeToQueryValue(NursingQueueScope.transferPending),
          );
        },
      ),
    if (state.dischargePendingCount > 0)
      AppWorkspaceSummaryNotification(
        label: l10n.nursingDischargePendingSummaryLabel,
        count: state.dischargePendingCount,
        icon: Icons.logout_outlined,
        tone: AppWorkspaceStatusTone.success,
        onSelected: () {
          onTabTapped(
            nursingScopeToQueryValue(NursingQueueScope.dischargePending),
          );
        },
      ),
  ];
}
