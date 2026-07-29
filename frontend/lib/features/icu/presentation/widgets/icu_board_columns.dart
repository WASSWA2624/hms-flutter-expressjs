import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/features/icu/domain/entities/icu_entities.dart';
import 'package:hosspi_hms/features/icu/presentation/widgets/icu_format.dart';
import 'package:hosspi_hms/features/icu/presentation/widgets/icu_next_action_button.dart';
import 'package:hosspi_hms/features/icu/presentation/widgets/icu_patient_cell.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

List<AppListTableColumn<IcuPatientSummary>> icuColumnsForSection(
  AppLocalizations l10n,
  IcuWorkspaceSection section, {
  required AccessRequirement writeRequirement,
  bool showNextAction = true,
}) {
  AppListTableColumn<IcuPatientSummary>? nextAction() {
    if (!showNextAction) {
      return null;
    }
    return icuNextActionColumn(
      l10n,
      section,
      writeRequirement: writeRequirement,
    );
  }

  return switch (section) {
    IcuWorkspaceSection.critical => <AppListTableColumn<IcuPatientSummary>>[
      icuPatientColumn(l10n),
      icuBedColumn(l10n),
      icuAlertColumn(l10n),
      icuStatusColumn(l10n),
      if (nextAction() case final AppListTableColumn<IcuPatientSummary> column)
        column,
    ],
    IcuWorkspaceSection.transfers => <AppListTableColumn<IcuPatientSummary>>[
      icuPatientColumn(l10n),
      icuBedColumn(l10n),
      icuTransferColumn(l10n),
      icuStatusColumn(l10n),
      if (nextAction() case final AppListTableColumn<IcuPatientSummary> column)
        column,
    ],
    IcuWorkspaceSection.discharge => <AppListTableColumn<IcuPatientSummary>>[
      icuPatientColumn(l10n),
      icuBedColumn(l10n),
      icuAdmittedColumn(l10n),
      icuStatusColumn(l10n),
      if (nextAction() case final AppListTableColumn<IcuPatientSummary> column)
        column,
    ],
    IcuWorkspaceSection.ended => <AppListTableColumn<IcuPatientSummary>>[
      icuPatientColumn(l10n),
      icuBedColumn(l10n),
      icuIcuStartColumn(l10n),
      icuStatusColumn(l10n),
      if (nextAction() case final AppListTableColumn<IcuPatientSummary> column)
        column,
    ],
    IcuWorkspaceSection.active ||
    IcuWorkspaceSection.all ||
    IcuWorkspaceSection.beds ||
    IcuWorkspaceSection.followUps => <AppListTableColumn<IcuPatientSummary>>[
      icuPatientColumn(l10n),
      icuBedColumn(l10n),
      icuSourceColumn(l10n),
      icuStatusColumn(l10n),
      if (nextAction() case final AppListTableColumn<IcuPatientSummary> column)
        column,
    ],
  };
}

List<AppListTableColumn<IcuPatientSummary>> icuColumnChoicesForSection(
  AppLocalizations l10n,
  IcuWorkspaceSection section, {
  required AccessRequirement writeRequirement,
  bool showNextAction = true,
}) {
  final Set<String> defaultKeys = icuColumnsForSection(
    l10n,
    section,
    writeRequirement: writeRequirement,
    showNextAction: showNextAction,
  ).map((AppListTableColumn<IcuPatientSummary> column) => column.key).toSet();

  final List<AppListTableColumn<IcuPatientSummary>> choices =
      <AppListTableColumn<IcuPatientSummary>>[];
  void addIfHidden(AppListTableColumn<IcuPatientSummary> column) {
    if (!defaultKeys.contains(column.key)) {
      choices.add(column);
    }
  }

  addIfHidden(icuAlertColumn(l10n));
  addIfHidden(icuSourceColumn(l10n));
  addIfHidden(icuIcuStartColumn(l10n));
  addIfHidden(icuTransferColumn(l10n));
  addIfHidden(icuAdmittedColumn(l10n));
  addIfHidden(icuEncounterColumn(l10n));

  return choices;
}

List<Widget> icuMobilePriorityFields(
  BuildContext context,
  IcuPatientSummary item,
  IcuWorkspaceSection section,
) {
  final AppLocalizations l10n = context.l10n;
  final ThemeData theme = Theme.of(context);
  final List<Widget> fields = <Widget>[];

  switch (section) {
    case IcuWorkspaceSection.critical:
      fields.add(AppWorkspaceStatusBadge(status: alertStatus(l10n, item)));
    case IcuWorkspaceSection.transfers:
      fields.add(
        Text(
          apiLabel(item.transferStatus ?? l10n.profileUnknownValue),
          style: theme.textTheme.bodySmall,
        ),
      );
    case IcuWorkspaceSection.discharge:
      fields.add(
        Text(
          dateTimeLabel(context, item.admittedAt),
          style: theme.textTheme.bodySmall,
        ),
      );
    case IcuWorkspaceSection.ended:
      fields.add(
        Text(
          dateTimeLabel(context, item.boardIcuStartAt),
          style: theme.textTheme.bodySmall,
        ),
      );
    case IcuWorkspaceSection.active:
    case IcuWorkspaceSection.all:
    case IcuWorkspaceSection.beds:
    case IcuWorkspaceSection.followUps:
      fields.add(Text(item.locationLabel, style: theme.textTheme.bodySmall));
      if (item.sourceLabel.isNotEmpty) {
        fields.add(
          Text(apiLabel(item.sourceLabel), style: theme.textTheme.bodySmall),
        );
      }
  }

  return fields;
}

AppListTableColumn<IcuPatientSummary> icuPatientColumn(AppLocalizations l10n) {
  return AppListTableColumn<IcuPatientSummary>(
    id: 'patient',
    label: l10n.opdPatientColumnLabel,
    sortComparator: (IcuPatientSummary left, IcuPatientSummary right) =>
        appListTableCompareText(left.displayTitle, right.displayTitle),
    cellBuilder: (BuildContext context, IcuPatientSummary item) {
      return IcuPatientCell(item: item);
    },
  );
}

AppListTableColumn<IcuPatientSummary> icuBedColumn(AppLocalizations l10n) {
  return AppListTableColumn<IcuPatientSummary>(
    id: 'bed',
    label: l10n.icuColumnBedLabel,
    sortComparator: (IcuPatientSummary left, IcuPatientSummary right) =>
        appListTableCompareText(left.locationLabel, right.locationLabel),
    cellBuilder: (BuildContext context, IcuPatientSummary item) {
      return Text(item.locationLabel);
    },
  );
}

AppListTableColumn<IcuPatientSummary> icuSourceColumn(AppLocalizations l10n) {
  return AppListTableColumn<IcuPatientSummary>(
    id: 'source',
    label: l10n.icuColumnSourceLabel,
    sortComparator: (IcuPatientSummary left, IcuPatientSummary right) =>
        appListTableCompareText(left.sourceLabel, right.sourceLabel),
    cellBuilder: (BuildContext context, IcuPatientSummary item) {
      final String label = item.sourceLabel;
      if (label.isEmpty) {
        return Text(l10n.profileUnknownValue);
      }
      return Text(apiLabel(label));
    },
  );
}

AppListTableColumn<IcuPatientSummary> icuAlertColumn(AppLocalizations l10n) {
  return AppListTableColumn<IcuPatientSummary>(
    id: 'alert',
    label: l10n.icuColumnAlertLabel,
    sortComparator: (IcuPatientSummary left, IcuPatientSummary right) =>
        appListTableCompareText(left.criticalSeverity, right.criticalSeverity),
    cellBuilder: (BuildContext context, IcuPatientSummary item) {
      return AppWorkspaceStatusBadge(status: alertStatus(l10n, item));
    },
  );
}

AppListTableColumn<IcuPatientSummary> icuStatusColumn(AppLocalizations l10n) {
  return AppListTableColumn<IcuPatientSummary>(
    id: 'status',
    label: l10n.opdStatusColumnLabel,
    sortComparator: (IcuPatientSummary left, IcuPatientSummary right) =>
        appListTableCompareText(left.icuStatus, right.icuStatus),
    cellBuilder: (BuildContext context, IcuPatientSummary item) {
      return AppWorkspaceStatusBadge(status: icuStatus(item));
    },
  );
}

AppListTableColumn<IcuPatientSummary> icuIcuStartColumn(AppLocalizations l10n) {
  return AppListTableColumn<IcuPatientSummary>(
    id: 'icu_start',
    label: l10n.icuColumnStartLabel,
    sortComparator: (IcuPatientSummary left, IcuPatientSummary right) =>
        appListTableCompareDateTime(
          left.boardIcuStartAt,
          right.boardIcuStartAt,
        ),
    cellBuilder: (BuildContext context, IcuPatientSummary item) {
      return Text(dateTimeLabel(context, item.boardIcuStartAt));
    },
  );
}

AppListTableColumn<IcuPatientSummary> icuTransferColumn(AppLocalizations l10n) {
  return AppListTableColumn<IcuPatientSummary>(
    id: 'transfer',
    label: l10n.icuColumnTransferLabel,
    sortComparator: (IcuPatientSummary left, IcuPatientSummary right) =>
        appListTableCompareText(left.transferStatus, right.transferStatus),
    cellBuilder: (BuildContext context, IcuPatientSummary item) {
      final String? status = item.transferStatus;
      if (status == null || status.trim().isEmpty) {
        return Text(l10n.profileUnknownValue);
      }
      return Text(apiLabel(status));
    },
  );
}

AppListTableColumn<IcuPatientSummary> icuAdmittedColumn(AppLocalizations l10n) {
  return AppListTableColumn<IcuPatientSummary>(
    id: 'admitted',
    label: l10n.icuAdmittedLabel,
    sortComparator: (IcuPatientSummary left, IcuPatientSummary right) =>
        appListTableCompareDateTime(left.admittedAt, right.admittedAt),
    cellBuilder: (BuildContext context, IcuPatientSummary item) {
      return Text(dateTimeLabel(context, item.admittedAt));
    },
  );
}

AppListTableColumn<IcuPatientSummary> icuEncounterColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<IcuPatientSummary>(
    id: 'encounter',
    label: l10n.icuAdmissionLabel,
    sortComparator: (IcuPatientSummary left, IcuPatientSummary right) =>
        appListTableCompareText(
          left.encounterId ?? left.displayId,
          right.encounterId ?? right.displayId,
        ),
    cellBuilder: (BuildContext context, IcuPatientSummary item) {
      return Text(
        item.encounterId ?? item.displayId ?? l10n.profileUnknownValue,
      );
    },
  );
}

AppListTableColumn<IcuPatientSummary> icuNextActionColumn(
  AppLocalizations l10n,
  IcuWorkspaceSection section, {
  required AccessRequirement writeRequirement,
}) {
  return AppListTableColumn<IcuPatientSummary>(
    id: 'next_action',
    label: l10n.icuNextActionColumnLabel,
    alwaysVisible: true,
    sortComparator: (IcuPatientSummary left, IcuPatientSummary right) =>
        appListTableCompareText(left.nextStep, right.nextStep),
    cellBuilder: (BuildContext context, IcuPatientSummary item) {
      return IcuNextActionButton(
        summary: item,
        section: section,
        writeRequirement: writeRequirement,
      );
    },
  );
}
