import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/nursing/domain/entities/nursing_entities.dart';
import 'package:hosspi_hms/features/nursing/presentation/nursing_access.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';

/// Stage-aware next-action kinds for the nursing worklist.
enum NursingNextActionKind {
  vitals,
  medication,
  handover,
  transfer,
  discharge,
  escalate,
}

NursingNextActionKind nursingResolveNextActionKind(
  NursingWorkItem item,
  NursingQueueScope scope,
) {
  if (scope == NursingQueueScope.urgent && item.hasCriticalAlert) {
    return NursingNextActionKind.escalate;
  }

  return switch (scope) {
    NursingQueueScope.medicationDue => NursingNextActionKind.medication,
    NursingQueueScope.handoverPending => NursingNextActionKind.handover,
    NursingQueueScope.transferPending => NursingNextActionKind.transfer,
    NursingQueueScope.dischargePending => NursingNextActionKind.discharge,
    NursingQueueScope.all ||
    NursingQueueScope.assignedWard ||
    NursingQueueScope.urgent => switch (item.taskTypeCode) {
      'MEDICATION_DUE' => NursingNextActionKind.medication,
      'HANDOVER_PENDING' => NursingNextActionKind.handover,
      'TRANSFER_PENDING' => NursingNextActionKind.transfer,
      'DISCHARGE_PENDING' => NursingNextActionKind.discharge,
      _ => NursingNextActionKind.vitals,
    },
  };
}

/// Requirement for the stage next-action control on a row.
AccessRequirement nursingNextActionRequirement(NursingNextActionKind kind) {
  return switch (kind) {
    NursingNextActionKind.medication => nursingMedicationWriteRequirement,
    NursingNextActionKind.vitals ||
    NursingNextActionKind.handover ||
    NursingNextActionKind.transfer ||
    NursingNextActionKind.discharge ||
    NursingNextActionKind.escalate => nursingWriteRequirement,
  };
}

String nursingResolveNextActionLabel(
  AppLocalizations l10n,
  NursingWorkItem item,
  NursingQueueScope scope,
) {
  return switch (nursingResolveNextActionKind(item, scope)) {
    NursingNextActionKind.escalate => l10n.nursingActionEscalate,
    NursingNextActionKind.medication => l10n.nursingActionAdministerMedication,
    NursingNextActionKind.handover => l10n.nursingActionCreateHandover,
    NursingNextActionKind.transfer => l10n.nursingActionAcknowledgeTransfer,
    NursingNextActionKind.discharge => l10n.nursingActionDischargeClearance,
    NursingNextActionKind.vitals => l10n.nursingActionRecordVitals,
  };
}

IconData nursingResolveNextActionIcon(
  NursingWorkItem item,
  NursingQueueScope scope,
) {
  return switch (nursingResolveNextActionKind(item, scope)) {
    NursingNextActionKind.escalate => Icons.report_problem_outlined,
    NursingNextActionKind.medication => Icons.medication_outlined,
    NursingNextActionKind.handover => Icons.swap_horiz_outlined,
    NursingNextActionKind.transfer => Icons.transfer_within_a_station_outlined,
    NursingNextActionKind.discharge => Icons.fact_check_outlined,
    NursingNextActionKind.vitals => Icons.monitor_heart_outlined,
  };
}
