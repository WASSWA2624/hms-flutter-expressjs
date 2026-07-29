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

List<AppListTableColumn<NursingWorkItem>> nursingColumnsForScope(
  AppLocalizations l10n,
  NursingQueueScope scope, {
  AppAccessPolicy? policy,
}) {
  final bool showNextAction =
      policy == null || nursingBoardShowsNextActionColumn(policy, scope);
  final List<AppListTableColumn<NursingWorkItem>> columns = switch (scope) {
    NursingQueueScope.urgent => <AppListTableColumn<NursingWorkItem>>[
      nursingPatientColumn(l10n),
      nursingPriorityColumn(l10n),
      nursingLocationColumn(l10n),
      nursingStatusColumn(l10n),
    ],
    NursingQueueScope.medicationDue => <AppListTableColumn<NursingWorkItem>>[
      nursingPatientColumn(l10n),
      nursingMedicationDueCountColumn(l10n),
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
  if (showNextAction) {
    columns.add(nursingNextActionColumn(l10n, scope));
  }
  return columns;
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
  ).map((AppListTableColumn<NursingWorkItem> c) => c.id ?? c.label).toSet();

  final List<AppListTableColumn<NursingWorkItem>> pool =
      <AppListTableColumn<NursingWorkItem>>[
        nursingPatientColumn(l10n),
        nursingLocationColumn(l10n),
        nursingTaskTypeColumn(l10n),
        nursingPriorityColumn(l10n),
        nursingStatusColumn(l10n),
        nursingAdmissionColumn(l10n),
        nursingDueTimeColumn(l10n),
        nursingResponsibleNurseColumn(l10n),
        nursingObservationsColumn(l10n),
        nursingMedicationDueCountColumn(l10n),
        nursingTransferStatusColumn(l10n),
        nursingDischargeStatusColumn(l10n),
      ];

  return <AppListTableColumn<NursingWorkItem>>[
    ...nursingColumnsForScope(l10n, scope, policy: policy),
    for (final AppListTableColumn<NursingWorkItem> column in pool)
      if (!defaultIds.contains(column.id ?? column.label)) column,
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
