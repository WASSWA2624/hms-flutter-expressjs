import 'package:flutter/material.dart';
import 'package:hosspi_hms/features/nursing/domain/entities/nursing_entities.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_helpers.dart';
import 'package:hosspi_hms/features/nursing/presentation/widgets/nursing_patient_cell.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

List<AppListTableColumn<NursingWorkItem>> nursingColumnsForScope(
  AppLocalizations l10n,
  NursingQueueScope scope,
) {
  return switch (scope) {
    NursingQueueScope.urgent => <AppListTableColumn<NursingWorkItem>>[
      nursingPatientColumn(l10n),
      nursingPriorityColumn(l10n),
      nursingLocationColumn(l10n),
      nursingStatusColumn(l10n),
      nursingDueTimeColumn(l10n),
    ],
    NursingQueueScope.medicationDue => <AppListTableColumn<NursingWorkItem>>[
      nursingPatientColumn(l10n),
      nursingMedicationDueCountColumn(l10n),
      nursingLocationColumn(l10n),
      nursingDueTimeColumn(l10n),
      nursingStatusColumn(l10n),
    ],
    NursingQueueScope.handoverPending => <AppListTableColumn<NursingWorkItem>>[
      nursingPatientColumn(l10n),
      nursingResponsibleNurseColumn(l10n),
      nursingLocationColumn(l10n),
      nursingStatusColumn(l10n),
      nursingObservationsColumn(l10n),
    ],
    NursingQueueScope.transferPending => <AppListTableColumn<NursingWorkItem>>[
      nursingPatientColumn(l10n),
      nursingLocationColumn(l10n),
      nursingTransferStatusColumn(l10n),
      nursingAdmissionColumn(l10n),
      nursingStatusColumn(l10n),
    ],
    NursingQueueScope.dischargePending => <AppListTableColumn<NursingWorkItem>>[
      nursingPatientColumn(l10n),
      nursingLocationColumn(l10n),
      nursingDischargeStatusColumn(l10n),
      nursingAdmissionColumn(l10n),
      nursingDueTimeColumn(l10n),
    ],
    _ => <AppListTableColumn<NursingWorkItem>>[
      nursingPatientColumn(l10n),
      nursingLocationColumn(l10n),
      nursingTaskTypeColumn(l10n),
      nursingPriorityColumn(l10n),
      nursingStatusColumn(l10n),
    ],
  };
}

List<AppListTableColumn<NursingWorkItem>> nursingColumnChoicesForScope(
  AppLocalizations l10n,
  NursingQueueScope scope,
) {
  final Set<String> defaultLabels = nursingColumnsForScope(
    l10n,
    scope,
  ).map((AppListTableColumn<NursingWorkItem> c) => c.label).toSet();
  return <AppListTableColumn<NursingWorkItem>>[
    ...nursingColumnsForScope(l10n, scope),
    if (!defaultLabels.contains(l10n.nursingAdmissionColumnLabel))
      nursingAdmissionColumn(l10n),
    if (!defaultLabels.contains(l10n.nursingDueTimeColumnLabel))
      nursingDueTimeColumn(l10n),
    if (!defaultLabels.contains(l10n.nursingResponsibleNurseColumnLabel))
      nursingResponsibleNurseColumn(l10n),
    if (!defaultLabels.contains(l10n.nursingObservationsTitle))
      nursingObservationsColumn(l10n),
    if (!defaultLabels.contains(l10n.nursingTaskTypeColumnLabel))
      nursingTaskTypeColumn(l10n),
    if (!defaultLabels.contains(l10n.nursingPriorityColumnLabel))
      nursingPriorityColumn(l10n),
    if (!defaultLabels.contains(l10n.nursingLocationColumnLabel))
      nursingLocationColumn(l10n),
  ];
}

AppListTableColumn<NursingWorkItem> nursingPatientColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<NursingWorkItem>(
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
