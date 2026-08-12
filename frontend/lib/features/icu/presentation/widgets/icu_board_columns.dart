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

String icuBoardExportCellValue(
  BuildContext context,
  IcuPatientSummary item,
  String columnId,
) {
  final AppLocalizations l10n = context.l10n;
  return switch (columnId) {
    'patient' => item.displayTitle,
    'patient_id' => item.displayId ?? l10n.profileUnknownValue,
    'bed' => icuPatientLocationLabel(l10n, item),
    'source' => item.sourceLabel.isEmpty
        ? l10n.profileUnknownValue
        : apiLabel(item.sourceLabel),
    'alert' => alertStatus(l10n, item).label,
    'status' => icuStatus(item).label,
    'icu_start' => dateTimeLabel(context, item.boardIcuStartAt),
    'transfer' => apiLabel(item.transferStatus ?? l10n.profileUnknownValue),
    'admitted' => dateTimeLabel(context, item.admittedAt),
    'encounter' =>
      item.encounterId ?? item.displayId ?? l10n.profileUnknownValue,
    'next_action' => () {
      final IcuNextActionKind? kind = icuBoardNextActionKind(
        item,
        // Export next-action label does not depend on section-specific omit.
        IcuWorkspaceSection.active,
      );
      return kind == null ? '' : icuNextActionLabel(l10n, kind);
    }(),
    _ => '',
  };
}

List<AppListTableColumn<IcuPatientSummary>> icuColumnsForSection(
  BuildContext context,
  IcuWorkspaceSection section, {
  required AccessRequirement writeRequirement,
  bool showNextAction = true,
}) {
  final AppLocalizations l10n = context.l10n;
  final List<AppListTableColumn<IcuPatientSummary>> defaults =
      _icuBaseColumnsForSection(context, section);
  if (showNextAction) {
    defaults.add(
      icuNextActionColumn(
        l10n,
        section,
        writeRequirement: writeRequirement,
      ),
    );
  }
  if (defaults.length >= 5) {
    return defaults;
  }
  final List<AppListTableColumn<IcuPatientSummary>> resolved =
      List<AppListTableColumn<IcuPatientSummary>>.of(defaults);
  final Set<String> resolvedIds = resolved
      .map((AppListTableColumn<IcuPatientSummary> column) => column.key)
      .toSet();
  for (final AppListTableColumn<IcuPatientSummary> choice
      in _icuOptionalColumnPool(context)) {
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

List<AppListTableColumn<IcuPatientSummary>> icuColumnChoicesForSection(
  BuildContext context,
  IcuWorkspaceSection section, {
  required AccessRequirement writeRequirement,
  bool showNextAction = true,
}) {
  final Set<String> defaultKeys = icuColumnsForSection(
    context,
    section,
    writeRequirement: writeRequirement,
    showNextAction: showNextAction,
  ).map((AppListTableColumn<IcuPatientSummary> column) => column.key).toSet();

  return <AppListTableColumn<IcuPatientSummary>>[
    for (final AppListTableColumn<IcuPatientSummary> column
        in _icuOptionalColumnPool(context))
      if (!defaultKeys.contains(column.key)) column,
  ];
}

List<AppListTableColumn<IcuPatientSummary>> _icuBaseColumnsForSection(
  BuildContext context,
  IcuWorkspaceSection section,
) {
  final AppLocalizations l10n = context.l10n;
  return switch (section) {
    IcuWorkspaceSection.critical => <AppListTableColumn<IcuPatientSummary>>[
      icuPatientColumn(l10n),
      icuBedColumn(l10n),
      icuAlertColumn(l10n),
      icuStatusColumn(l10n),
    ],
    IcuWorkspaceSection.transfers => <AppListTableColumn<IcuPatientSummary>>[
      icuPatientColumn(l10n),
      icuBedColumn(l10n),
      icuTransferColumn(l10n),
      icuStatusColumn(l10n),
    ],
    IcuWorkspaceSection.discharge => <AppListTableColumn<IcuPatientSummary>>[
      icuPatientColumn(l10n),
      icuBedColumn(l10n),
      icuAdmittedColumn(context),
      icuStatusColumn(l10n),
    ],
    IcuWorkspaceSection.ended => <AppListTableColumn<IcuPatientSummary>>[
      icuPatientColumn(l10n),
      icuBedColumn(l10n),
      icuIcuStartColumn(context),
      icuStatusColumn(l10n),
    ],
    IcuWorkspaceSection.active ||
    IcuWorkspaceSection.all ||
    IcuWorkspaceSection.beds ||
    IcuWorkspaceSection.followUps => <AppListTableColumn<IcuPatientSummary>>[
      icuPatientColumn(l10n),
      icuBedColumn(l10n),
      icuSourceColumn(l10n),
      icuStatusColumn(l10n),
    ],
  };
}

List<AppListTableColumn<IcuPatientSummary>> _icuOptionalColumnPool(
  BuildContext context,
) {
  final AppLocalizations l10n = context.l10n;
  return <AppListTableColumn<IcuPatientSummary>>[
    icuAlertColumn(l10n),
    icuSourceColumn(l10n),
    icuIcuStartColumn(context),
    icuTransferColumn(l10n),
    icuAdmittedColumn(context),
    icuEncounterColumn(l10n),
    icuPatientIdColumn(l10n),
  ];
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
      fields.add(
        Text(
          icuPatientLocationLabel(l10n, item),
          style: theme.textTheme.bodySmall,
        ),
      );
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
    exportValue: (IcuPatientSummary item) => item.displayTitle,
    cellBuilder: (BuildContext context, IcuPatientSummary item) {
      return IcuPatientCell(item: item);
    },
  );
}

AppListTableColumn<IcuPatientSummary> icuPatientIdColumn(
  AppLocalizations l10n,
) {
  return AppListTableColumn<IcuPatientSummary>(
    id: 'patient_id',
    label: l10n.opdPatientIdLabel,
    sortComparator: (IcuPatientSummary left, IcuPatientSummary right) =>
        appListTableCompareText(left.displayId, right.displayId),
    exportValue: (IcuPatientSummary item) =>
        item.displayId ?? l10n.profileUnknownValue,
    cellBuilder: (BuildContext context, IcuPatientSummary item) {
      return Text(
        item.displayId ?? context.l10n.profileUnknownValue,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    },
  );
}

AppListTableColumn<IcuPatientSummary> icuBedColumn(AppLocalizations l10n) {
  return AppListTableColumn<IcuPatientSummary>(
    id: 'bed',
    label: l10n.icuColumnBedLabel,
    sortComparator: (IcuPatientSummary left, IcuPatientSummary right) =>
        appListTableCompareText(left.locationLabel, right.locationLabel),
    exportValue: (IcuPatientSummary item) =>
        icuPatientLocationLabel(l10n, item),
    cellBuilder: (BuildContext context, IcuPatientSummary item) {
      return Text(icuPatientLocationLabel(context.l10n, item));
    },
  );
}

AppListTableColumn<IcuPatientSummary> icuSourceColumn(AppLocalizations l10n) {
  return AppListTableColumn<IcuPatientSummary>(
    id: 'source',
    label: l10n.icuColumnSourceLabel,
    sortComparator: (IcuPatientSummary left, IcuPatientSummary right) =>
        appListTableCompareText(left.sourceLabel, right.sourceLabel),
    exportValue: (IcuPatientSummary item) => item.sourceLabel.isEmpty
        ? l10n.profileUnknownValue
        : apiLabel(item.sourceLabel),
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
    exportValue: (IcuPatientSummary item) => alertStatus(l10n, item).label,
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
    exportValue: (IcuPatientSummary item) => icuStatus(item).label,
    cellBuilder: (BuildContext context, IcuPatientSummary item) {
      return AppWorkspaceStatusBadge(status: icuStatus(item));
    },
  );
}

AppListTableColumn<IcuPatientSummary> icuIcuStartColumn(BuildContext context) {
  final AppLocalizations l10n = context.l10n;
  return AppListTableColumn<IcuPatientSummary>(
    id: 'icu_start',
    label: l10n.icuColumnStartLabel,
    sortComparator: (IcuPatientSummary left, IcuPatientSummary right) =>
        appListTableCompareDateTime(
          left.boardIcuStartAt,
          right.boardIcuStartAt,
        ),
    exportValue: (IcuPatientSummary item) =>
        dateTimeLabel(context, item.boardIcuStartAt),
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
    exportValue: (IcuPatientSummary item) =>
        apiLabel(item.transferStatus ?? l10n.profileUnknownValue),
    cellBuilder: (BuildContext context, IcuPatientSummary item) {
      final String? status = item.transferStatus;
      if (status == null || status.trim().isEmpty) {
        return Text(l10n.profileUnknownValue);
      }
      return Text(apiLabel(status));
    },
  );
}

AppListTableColumn<IcuPatientSummary> icuAdmittedColumn(BuildContext context) {
  final AppLocalizations l10n = context.l10n;
  return AppListTableColumn<IcuPatientSummary>(
    id: 'admitted',
    label: l10n.icuAdmittedLabel,
    sortComparator: (IcuPatientSummary left, IcuPatientSummary right) =>
        appListTableCompareDateTime(left.admittedAt, right.admittedAt),
    exportValue: (IcuPatientSummary item) =>
        dateTimeLabel(context, item.admittedAt),
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
    exportValue: (IcuPatientSummary item) =>
        item.encounterId ?? item.displayId ?? l10n.profileUnknownValue,
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
    exportValue: (IcuPatientSummary item) {
      final IcuNextActionKind? kind = icuBoardNextActionKind(item, section);
      return kind == null ? '' : icuNextActionLabel(l10n, kind);
    },
    cellBuilder: (BuildContext context, IcuPatientSummary item) {
      return IcuNextActionButton(
        summary: item,
        section: section,
        writeRequirement: writeRequirement,
      );
    },
  );
}
