import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/features/nursing/domain/entities/nursing_entities.dart';
import 'package:hosspi_hms/features/nursing/presentation/nursing_access.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_helpers.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_patient_cell.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_worklist_actions.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

/// Plain-text value for export / print for a Nursing worklist column.
String nursingWorklistExportCellValue(
  BuildContext context,
  NursingWorkItem item,
  String columnId, {
  NursingQueueScope scope = NursingQueueScope.all,
}) {
  final AppLocalizations l10n = context.l10n;
  return switch (columnId) {
    'patient' => item.displayTitle,
    'location' => item.locationLabel ?? l10n.profileUnknownValue,
    'task_type' => nursingTaskTypeLabel(context, item),
    'priority' => nursingPriorityStatus(context, item).label,
    'status' => nursingSummaryStatus(item).label,
    'admission' => nursingAdmissionLabel(context, item),
    'due_time' => nursingDueTimeLabel(context, item),
    // Product exception (tables.mdc): no assignee API field — synthetic summary.
    'responsible_nurse' => nursingResponsibleNurseLabel(context, item),
    'observations' => nursingLastObservationLabel(context, item),
    'medication_due_count' => '${item.medicationDueCount}',
    'transfer_status' => nursingApiLabel(
      item.transferStatus ?? l10n.profileUnknownValue,
    ),
    'discharge_status' => nursingApiLabel(
      item.dischargeStatus ?? l10n.profileUnknownValue,
    ),
    'next_action' => nursingResolveNextActionLabel(l10n, item, scope),
    _ => '',
  };
}

List<AppListTableColumn<NursingWorkItem>> nursingColumnsForScope(
  AppLocalizations l10n,
  NursingQueueScope scope, {
  AppAccessPolicy? policy,
}) {
  final bool showNextAction =
      policy == null || nursingBoardShowsNextActionColumn(policy, scope);
  // Medication due count / med data column — ∩ pharmacy:read
  // ([NursingMedicationDueAtomPermissions.medicationDueCount]).
  final bool showMedicationDue =
      policy == null ||
      NursingMedicationDueAtomPermissions.medicationDueCount.isAllowed(policy);

  final List<AppListTableColumn<NursingWorkItem>> defaults =
      _nursingBaseColumnsForScope(
        l10n,
        scope,
        showMedicationDue: showMedicationDue,
      );
  if (showNextAction) {
    defaults.add(nursingNextActionColumn(l10n, scope));
  }
  if (defaults.length >= 5) {
    return defaults;
  }

  final List<AppListTableColumn<NursingWorkItem>> resolved =
      List<AppListTableColumn<NursingWorkItem>>.of(defaults);
  final Set<String> resolvedIds = resolved
      .map((AppListTableColumn<NursingWorkItem> column) => column.key)
      .toSet();
  for (final AppListTableColumn<NursingWorkItem> choice
      in _nursingOptionalColumnPool(
        l10n,
        showMedicationDue: showMedicationDue,
      )) {
    if (resolved.length >= 5) {
      break;
    }
    if (resolvedIds.contains(choice.key)) {
      continue;
    }
    resolved.add(choice);
    resolvedIds.add(choice.key);
  }
  return resolved;
}

List<AppListTableColumn<NursingWorkItem>> nursingColumnChoicesForScope(
  AppLocalizations l10n,
  NursingQueueScope scope, {
  AppAccessPolicy? policy,
}) {
  final Set<String> defaultIds = nursingColumnsForScope(
    l10n,
    scope,
    policy: policy,
  ).map((AppListTableColumn<NursingWorkItem> c) => c.key).toSet();
  final bool showMedicationDue =
      policy == null ||
      NursingMedicationDueAtomPermissions.medicationDueCount.isAllowed(policy);

  return <AppListTableColumn<NursingWorkItem>>[
    for (final AppListTableColumn<NursingWorkItem> column
        in _nursingOptionalColumnPool(
          l10n,
          showMedicationDue: showMedicationDue,
        ))
      if (!defaultIds.contains(column.key)) column,
  ];
}

List<AppListTableColumn<NursingWorkItem>> _nursingBaseColumnsForScope(
  AppLocalizations l10n,
  NursingQueueScope scope, {
  required bool showMedicationDue,
}) {
  return switch (scope) {
    NursingQueueScope.urgent => <AppListTableColumn<NursingWorkItem>>[
      nursingPatientColumn(l10n),
      nursingPriorityColumn(l10n),
      nursingLocationColumn(l10n),
      nursingStatusColumn(l10n),
    ],
    NursingQueueScope.medicationDue => <AppListTableColumn<NursingWorkItem>>[
      nursingPatientColumn(l10n),
      if (showMedicationDue) nursingMedicationDueCountColumn(l10n),
      nursingLocationColumn(l10n),
      nursingStatusColumn(l10n),
    ],
    NursingQueueScope.handoverPending => <AppListTableColumn<NursingWorkItem>>[
      nursingPatientColumn(l10n),
      nursingResponsibleNurseColumn(l10n),
      nursingLocationColumn(l10n),
      nursingStatusColumn(l10n),
    ],
    NursingQueueScope.transferPending => <AppListTableColumn<NursingWorkItem>>[
      nursingPatientColumn(l10n),
      nursingLocationColumn(l10n),
      nursingTransferStatusColumn(l10n),
      nursingStatusColumn(l10n),
    ],
    NursingQueueScope.dischargePending => <AppListTableColumn<NursingWorkItem>>[
      nursingPatientColumn(l10n),
      nursingLocationColumn(l10n),
      nursingDischargeStatusColumn(l10n),
      nursingStatusColumn(l10n),
    ],
    _ => <AppListTableColumn<NursingWorkItem>>[
      nursingPatientColumn(l10n),
      nursingLocationColumn(l10n),
      nursingTaskTypeColumn(l10n),
      nursingStatusColumn(l10n),
    ],
  };
}

List<AppListTableColumn<NursingWorkItem>> _nursingOptionalColumnPool(
  AppLocalizations l10n, {
  required bool showMedicationDue,
}) {
  return <AppListTableColumn<NursingWorkItem>>[
    nursingPriorityColumn(l10n),
    nursingTaskTypeColumn(l10n),
    nursingAdmissionColumn(l10n),
    nursingDueTimeColumn(l10n),
    nursingResponsibleNurseColumn(l10n),
    nursingObservationsColumn(l10n),
    if (showMedicationDue) nursingMedicationDueCountColumn(l10n),
    nursingTransferStatusColumn(l10n),
    nursingDischargeStatusColumn(l10n),
  ];
}

AppListTableColumn<NursingWorkItem> nursingNextActionColumn(
  AppLocalizations l10n,
  NursingQueueScope scope,
) {
  return AppListTableColumn<NursingWorkItem>(
    id: 'next_action',
    label: l10n.nursingNextActionColumnLabel,
    alwaysVisible: true,
    sortComparator: (NursingWorkItem left, NursingWorkItem right) =>
        appListTableCompareText(
          nursingResolveNextActionLabel(l10n, left, scope),
          nursingResolveNextActionLabel(l10n, right, scope),
        ),
    exportValue: (NursingWorkItem item) =>
        nursingResolveNextActionLabel(l10n, item, scope),
    cellBuilder: (BuildContext context, NursingWorkItem item) {
      return NursingNextActionCell(item: item, scope: scope);
    },
  );
}

AppListTableColumn<NursingWorkItem> nursingPatientColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<NursingWorkItem>(
    id: 'patient',
    label: l10n.opdPatientColumnLabel,
    sortComparator: (NursingWorkItem left, NursingWorkItem right) =>
        appListTableCompareText(left.displayTitle, right.displayTitle),
    exportValue: (NursingWorkItem item) => item.displayTitle,
    cellBuilder: (BuildContext context, NursingWorkItem item) {
      return NursingPatientCell(item: item);
    },
  );
}

AppListTableColumn<NursingWorkItem> nursingLocationColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<NursingWorkItem>(
    id: 'location',
    label: l10n.nursingLocationColumnLabel,
    sortComparator: (NursingWorkItem left, NursingWorkItem right) =>
        appListTableCompareText(left.locationLabel, right.locationLabel),
    exportValue: (NursingWorkItem item) =>
        item.locationLabel ?? l10n.profileUnknownValue,
    cellBuilder: (BuildContext context, NursingWorkItem item) {
      return Text(
        item.locationLabel ?? context.l10n.profileUnknownValue,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    },
  );
}

AppListTableColumn<NursingWorkItem> nursingTaskTypeColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<NursingWorkItem>(
    id: 'task_type',
    label: l10n.nursingTaskTypeColumnLabel,
    sortComparator: (NursingWorkItem left, NursingWorkItem right) =>
        appListTableCompareText(left.taskTypeCode, right.taskTypeCode),
    exportValue: (NursingWorkItem item) => switch (item.taskTypeCode) {
      'MEDICATION_DUE' => l10n.nursingMedicationDueSummaryLabel,
      'HANDOVER_PENDING' => l10n.nursingHandoverPendingSummaryLabel,
      'TRANSFER_PENDING' => l10n.nursingTransferPendingSummaryLabel,
      'DISCHARGE_PENDING' => l10n.nursingDischargePendingSummaryLabel,
      final String? value when value != null && value.trim().isNotEmpty =>
        nursingApiLabel(value),
      _ => l10n.profileUnknownValue,
    },
    cellBuilder: (BuildContext context, NursingWorkItem item) {
      return Text(nursingTaskTypeLabel(context, item));
    },
  );
}

AppListTableColumn<NursingWorkItem> nursingPriorityColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<NursingWorkItem>(
    id: 'priority',
    label: l10n.nursingPriorityColumnLabel,
    sortComparator: (NursingWorkItem left, NursingWorkItem right) =>
        appListTableCompareText(left.priorityCode, right.priorityCode),
    exportValue: (NursingWorkItem item) => switch (item.priorityCode) {
      'HIGH' => l10n.nursingPriorityHighLabel,
      'MEDIUM' => l10n.nursingPriorityMediumLabel,
      _ => l10n.nursingPriorityRoutineLabel,
    },
    cellBuilder: (BuildContext context, NursingWorkItem item) {
      return AppWorkspaceStatusBadge(
        status: nursingPriorityStatus(context, item),
      );
    },
  );
}

AppListTableColumn<NursingWorkItem> nursingStatusColumn(AppLocalizations l10n) {
  return AppListTableColumn<NursingWorkItem>(
    id: 'status',
    label: l10n.opdStatusColumnLabel,
    sortComparator: (NursingWorkItem left, NursingWorkItem right) =>
        appListTableCompareText(left.admissionStatus, right.admissionStatus),
    exportValue: (NursingWorkItem item) => nursingSummaryStatus(item).label,
    cellBuilder: (BuildContext context, NursingWorkItem item) {
      return AppWorkspaceStatusBadge(status: nursingSummaryStatus(item));
    },
  );
}

AppListTableColumn<NursingWorkItem> nursingAdmissionColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<NursingWorkItem>(
    id: 'admission',
    label: l10n.nursingAdmissionColumnLabel,
    sortComparator: (NursingWorkItem left, NursingWorkItem right) =>
        appListTableCompareText(left.displayId, right.displayId),
    exportValue: (NursingWorkItem item) {
      final String? id = item.displayId?.trim();
      if (id == null || id.isEmpty) {
        return l10n.profileUnknownValue;
      }
      return id;
    },
    cellBuilder: (BuildContext context, NursingWorkItem item) {
      return Text(nursingAdmissionLabel(context, item));
    },
  );
}

AppListTableColumn<NursingWorkItem> nursingDueTimeColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<NursingWorkItem>(
    id: 'due_time',
    label: l10n.nursingDueTimeColumnLabel,
    sortComparator: (NursingWorkItem left, NursingWorkItem right) =>
        appListTableCompareDateTime(left.dueReferenceAt, right.dueReferenceAt),
    exportValue: (NursingWorkItem item) =>
        item.dueReferenceAt?.toIso8601String() ?? l10n.profileUnknownValue,
    cellBuilder: (BuildContext context, NursingWorkItem item) {
      return Text(nursingDueTimeLabel(context, item));
    },
  );
}

AppListTableColumn<NursingWorkItem> nursingResponsibleNurseColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<NursingWorkItem>(
    id: 'responsible_nurse',
    label: l10n.nursingResponsibleNurseColumnLabel,
    sortComparator: (NursingWorkItem left, NursingWorkItem right) =>
        appListTableCompareText(
          nursingResponsibleNurseSortValue(left),
          nursingResponsibleNurseSortValue(right),
        ),
    exportValue: (NursingWorkItem item) => item.pendingHandoverCount > 0
        ? l10n.nursingHandoverPendingSummaryLabel
        : l10n.nursingAssignedShiftLabel,
    cellBuilder: (BuildContext context, NursingWorkItem item) {
      return Text(nursingResponsibleNurseLabel(context, item));
    },
  );
}

AppListTableColumn<NursingWorkItem> nursingObservationsColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<NursingWorkItem>(
    id: 'observations',
    label: l10n.nursingObservationsTitle,
    sortComparator: (NursingWorkItem left, NursingWorkItem right) =>
        appListTableCompareDateTime(
          left.lastObservationAt,
          right.lastObservationAt,
        ),
    exportValue: (NursingWorkItem item) =>
        item.lastObservationAt?.toIso8601String() ?? l10n.profileUnknownValue,
    cellBuilder: (BuildContext context, NursingWorkItem item) {
      return Text(nursingLastObservationLabel(context, item));
    },
  );
}

AppListTableColumn<NursingWorkItem> nursingMedicationDueCountColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<NursingWorkItem>(
    id: 'medication_due_count',
    label: l10n.nursingMedicationDueSummaryLabel,
    sortComparator: (NursingWorkItem left, NursingWorkItem right) =>
        left.medicationDueCount.compareTo(right.medicationDueCount),
    exportValue: (NursingWorkItem item) => '${item.medicationDueCount}',
    cellBuilder: (BuildContext context, NursingWorkItem item) {
      return Text(item.medicationDueCount.toString());
    },
  );
}

AppListTableColumn<NursingWorkItem> nursingTransferStatusColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<NursingWorkItem>(
    id: 'transfer_status',
    label: l10n.nursingTransferPendingSummaryLabel,
    sortComparator: (NursingWorkItem left, NursingWorkItem right) =>
        appListTableCompareText(left.transferStatus, right.transferStatus),
    exportValue: (NursingWorkItem item) => nursingApiLabel(
      item.transferStatus ?? l10n.profileUnknownValue,
    ),
    cellBuilder: (BuildContext context, NursingWorkItem item) {
      final String? status = item.transferStatus;
      if (status == null || status.trim().isEmpty) {
        return Text(context.l10n.profileUnknownValue);
      }
      return AppWorkspaceStatusBadge(
        status: AppWorkspaceStatus(
          label: nursingApiLabel(status),
          tone: nursingStatusTone(status),
        ),
      );
    },
  );
}

AppListTableColumn<NursingWorkItem> nursingDischargeStatusColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<NursingWorkItem>(
    id: 'discharge_status',
    label: l10n.dischargeStatusFilterLabel,
    sortComparator: (NursingWorkItem left, NursingWorkItem right) =>
        appListTableCompareText(left.dischargeStatus, right.dischargeStatus),
    exportValue: (NursingWorkItem item) => nursingApiLabel(
      item.dischargeStatus ?? l10n.profileUnknownValue,
    ),
    cellBuilder: (BuildContext context, NursingWorkItem item) {
      final String? status = item.dischargeStatus;
      if (status == null || status.trim().isEmpty) {
        return Text(context.l10n.profileUnknownValue);
      }
      return AppWorkspaceStatusBadge(
        status: AppWorkspaceStatus(
          label: nursingApiLabel(status),
          tone: nursingStatusTone(status),
        ),
      );
    },
  );
}
