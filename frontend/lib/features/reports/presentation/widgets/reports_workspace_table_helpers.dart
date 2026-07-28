import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/reports/domain/entities/reports_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

typedef ReportRowActionHandler =
    Future<void> Function(
      BuildContext context,
      WidgetRef ref,
      ReportsWorkspaceItem item,
    );

typedef ComplianceRowActionHandler =
    Future<void> Function(
      BuildContext context,
      WidgetRef ref,
      ComplianceLogItem item,
    );

typedef ReportDetailDialogOpener =
    Future<void> Function(
      BuildContext context,
      WidgetRef ref,
      ReportsWorkspaceState state,
      ReportsWorkspaceItem item,
      AppAccessPolicy policy,
    );

typedef ComplianceDetailDialogOpener =
    Future<void> Function(
      BuildContext context,
      WidgetRef ref,
      ReportsWorkspaceState state,
      ComplianceLogItem item,
      AppAccessPolicy policy,
    );

bool canWriteReports(AppAccessPolicy policy) {
  return policy.grantsAny(const <AppPermission>[
    AppPermissions.reportsWrite,
    AppPermissions.tenantAdmin,
    AppPermissions.facilityAdmin,
    AppPermissions.systemAdmin,
  ]);
}

bool canExportEvidence(AppAccessPolicy policy) {
  return policy.grantsAny(const <AppPermission>[
    AppPermissions.evidenceExport,
    AppPermissions.tenantAdmin,
    AppPermissions.facilityAdmin,
    AppPermissions.systemAdmin,
  ]);
}

bool matchesReportItemSearch(
  BuildContext context,
  ReportsWorkspaceItem item,
  String query,
) {
  final String normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) {
    return true;
  }

  final AppLocalizations l10n = context.l10n;
  final String? nextAction = reportNextActionLabel(
    l10n,
    item,
    canWrite: true,
    canExport: true,
  );

  return <String?>[
    item.title,
    item.subtitle,
    item.description,
    item.status,
    reportsApiLabel(item.status),
    item.format,
    item.category,
    reportsApiLabel(item.category),
    item.datasetKey,
    item.facilityLabel,
    item.ownerLabel,
    item.reference,
    item.errorMessage,
    reportsDateTime(context, item.occurredAt),
    item.occurredAt?.toIso8601String(),
    item.value?.toString(),
    item.count?.toString(),
    nextAction,
  ].whereType<String>().any((String value) {
    return value.toLowerCase().contains(normalized);
  });
}

bool matchesComplianceLogSearch(
  BuildContext context,
  ComplianceLogItem item,
  String query,
) {
  final String normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) {
    return true;
  }

  return <String?>[
    item.title,
    item.subtitle,
    item.userLabel,
    item.patientLabel,
    item.action,
    reportsApiLabel(item.action),
    item.entity,
    reportsApiLabel(item.entity),
    item.scope,
    reportsApiLabel(item.scope),
    item.purpose,
    reportsApiLabel(item.purpose),
    item.legalBasis,
    reportsApiLabel(item.legalBasis),
    item.recordReference,
    item.facilityLabel,
    item.ipAddress,
    item.details,
    reportsDateTime(context, item.occurredAt),
    item.occurredAt?.toIso8601String(),
  ].whereType<String>().any((String value) {
    return value.toLowerCase().contains(normalized);
  });
}

/// Stable next-action keys for report rows. `null` means no mutation next-action
/// (row select opens detail; do not render a duplicate preview button).
const String reportNextActionRun = 'run';
const String reportNextActionSchedule = 'schedule';
const String reportNextActionRetry = 'retry';
const String reportNextActionCancel = 'cancel';
const String reportNextActionDownload = 'download';
const String complianceNextActionExport = 'export';

String? reportPrimaryNextActionKey(
  ReportsWorkspaceItem item, {
  required bool canWrite,
  required bool canExport,
}) {
  if (item.kind == ReportItemKind.definition) {
    if (canWrite && item.canRun) {
      return reportNextActionRun;
    }
    if (canWrite && item.canSchedule) {
      return reportNextActionSchedule;
    }
  }
  if (item.kind == ReportItemKind.run) {
    if (canWrite && item.canRetry) {
      return reportNextActionRetry;
    }
    if (canWrite && item.canCancel) {
      return reportNextActionCancel;
    }
    if (canExport && item.downloadAvailable) {
      return reportNextActionDownload;
    }
  }
  if (item.isSchedule && canWrite) {
    return reportNextActionSchedule;
  }
  return null;
}

String? reportNextActionLabel(
  AppLocalizations l10n,
  ReportsWorkspaceItem item, {
  required bool canWrite,
  required bool canExport,
}) {
  return switch (reportPrimaryNextActionKey(
    item,
    canWrite: canWrite,
    canExport: canExport,
  )) {
    reportNextActionRun => l10n.reportsRunAction,
    reportNextActionSchedule => l10n.reportsScheduleAction,
    reportNextActionRetry => l10n.reportsRetryAction,
    reportNextActionCancel => l10n.reportsCancelRunAction,
    reportNextActionDownload => l10n.reportsDownloadAction,
    _ => null,
  };
}

String? complianceNextActionLabel(
  AppLocalizations l10n, {
  required bool canExport,
}) {
  if (!canExport) {
    return null;
  }
  return l10n.reportsExportEvidenceAction;
}

String? compliancePrimaryNextActionKey({required bool canExport}) {
  return canExport ? complianceNextActionExport : null;
}

List<AppListTableColumn<ReportsWorkspaceItem>> reportItemColumns(
  BuildContext context,
  WidgetRef ref,
  AppLocalizations l10n, {
  required bool canWrite,
  required bool canExport,
  required bool isSaving,
  required ReportRowActionHandler onNextAction,
}) {
  return <AppListTableColumn<ReportsWorkspaceItem>>[
    AppListTableColumn<ReportsWorkspaceItem>(
      id: 'name',
      label: l10n.reportsNameColumnLabel,
      sortComparator: (ReportsWorkspaceItem left, ReportsWorkspaceItem right) {
        return appListTableCompareText(left.title, right.title);
      },
      cellBuilder: (_, ReportsWorkspaceItem item) => ReportsTwoLineCell(
        title: item.title,
        subtitle: item.subtitle,
        icon: reportsItemIcon(item.kind),
      ),
    ),
    AppListTableColumn<ReportsWorkspaceItem>(
      id: 'reference',
      label: l10n.reportsReferenceLabel,
      sortComparator: (ReportsWorkspaceItem left, ReportsWorkspaceItem right) {
        return appListTableCompareText(left.reference, right.reference);
      },
      cellBuilder: (BuildContext context, ReportsWorkspaceItem item) {
        return Text(reportsValueOrUnknown(context, item.reference));
      },
    ),
    AppListTableColumn<ReportsWorkspaceItem>(
      id: 'updated',
      label: l10n.reportsUpdatedColumnLabel,
      sortComparator: (ReportsWorkspaceItem left, ReportsWorkspaceItem right) {
        return appListTableCompareDateTime(left.occurredAt, right.occurredAt);
      },
      cellBuilder: (BuildContext context, ReportsWorkspaceItem item) {
        return Text(reportsDateTime(context, item.occurredAt));
      },
    ),
    AppListTableColumn<ReportsWorkspaceItem>(
      id: 'status',
      label: l10n.reportsStatusColumnLabel,
      sortComparator: (ReportsWorkspaceItem left, ReportsWorkspaceItem right) {
        return appListTableCompareText(left.status, right.status);
      },
      cellBuilder: (BuildContext context, ReportsWorkspaceItem item) {
        return AppWorkspaceStatusBadge(
          status: reportsTableStatus(context, item.status),
        );
      },
    ),
    _reportNextActionColumn(
      ref: ref,
      l10n: l10n,
      canWrite: canWrite,
      canExport: canExport,
      isSaving: isSaving,
      onAction: onNextAction,
    ),
  ];
}

List<AppListTableColumn<ReportsWorkspaceItem>> reportItemColumnChoices(
  BuildContext context,
  AppLocalizations l10n,
) {
  return <AppListTableColumn<ReportsWorkspaceItem>>[
    AppListTableColumn<ReportsWorkspaceItem>(
      id: 'owner',
      label: l10n.reportsOwnerLabel,
      sortComparator: (ReportsWorkspaceItem left, ReportsWorkspaceItem right) {
        return appListTableCompareText(left.ownerLabel, right.ownerLabel);
      },
      cellBuilder: (BuildContext context, ReportsWorkspaceItem item) {
        return Text(reportsValueOrUnknown(context, item.ownerLabel));
      },
    ),
    AppListTableColumn<ReportsWorkspaceItem>(
      id: 'format',
      label: l10n.reportsFormatColumnLabel,
      cellBuilder: (BuildContext context, ReportsWorkspaceItem item) {
        return Text(reportsValueOrUnknown(context, item.format));
      },
    ),
    AppListTableColumn<ReportsWorkspaceItem>(
      id: 'dataset',
      label: l10n.reportsDatasetLabel,
      cellBuilder: (BuildContext context, ReportsWorkspaceItem item) {
        return Text(reportsValueOrUnknown(context, item.datasetKey));
      },
    ),
    AppListTableColumn<ReportsWorkspaceItem>(
      id: 'facility',
      label: l10n.reportsFacilityLabel,
      cellBuilder: (BuildContext context, ReportsWorkspaceItem item) {
        return Text(reportsValueOrUnknown(context, item.facilityLabel));
      },
    ),
    AppListTableColumn<ReportsWorkspaceItem>(
      id: 'category',
      label: l10n.reportsCategoryLabel,
      cellBuilder: (BuildContext context, ReportsWorkspaceItem item) {
        return Text(
          reportsValueOrUnknown(context, reportsApiLabel(item.category)),
        );
      },
    ),
    AppListTableColumn<ReportsWorkspaceItem>(
      id: 'description',
      label: l10n.reportsDetailsLabel,
      cellBuilder: (BuildContext context, ReportsWorkspaceItem item) {
        return Text(reportsValueOrUnknown(context, item.description));
      },
    ),
    AppListTableColumn<ReportsWorkspaceItem>(
      id: 'value',
      label: l10n.reportsValueLabel,
      cellBuilder: (BuildContext context, ReportsWorkspaceItem item) {
        return Text(
          item.value == null
              ? context.l10n.profileUnknownValue
              : AppFormatters.decimal(
                  item.value!,
                  Localizations.localeOf(context),
                ),
        );
      },
    ),
    AppListTableColumn<ReportsWorkspaceItem>(
      id: 'error',
      label: l10n.reportsErrorLabel,
      cellBuilder: (BuildContext context, ReportsWorkspaceItem item) {
        return Text(reportsValueOrUnknown(context, item.errorMessage));
      },
    ),
  ];
}

List<AppListTableColumn<ReportsWorkspaceItem>> scheduleColumns(
  BuildContext context,
  WidgetRef ref,
  AppLocalizations l10n, {
  required bool canWrite,
  required bool canExport,
  required bool isSaving,
  required ReportRowActionHandler onNextAction,
}) {
  return <AppListTableColumn<ReportsWorkspaceItem>>[
    AppListTableColumn<ReportsWorkspaceItem>(
      id: 'name',
      label: l10n.reportsNameColumnLabel,
      sortComparator: (ReportsWorkspaceItem left, ReportsWorkspaceItem right) {
        return appListTableCompareText(left.title, right.title);
      },
      cellBuilder: (_, ReportsWorkspaceItem item) => ReportsTwoLineCell(
        title: item.title,
        subtitle: item.subtitle,
        icon: Icons.schedule_outlined,
      ),
    ),
    AppListTableColumn<ReportsWorkspaceItem>(
      id: 'format',
      label: l10n.reportsFormatColumnLabel,
      cellBuilder: (BuildContext context, ReportsWorkspaceItem item) {
        return Text(reportsValueOrUnknown(context, item.format));
      },
    ),
    AppListTableColumn<ReportsWorkspaceItem>(
      id: 'updated',
      label: l10n.reportsUpdatedColumnLabel,
      sortComparator: (ReportsWorkspaceItem left, ReportsWorkspaceItem right) {
        return appListTableCompareDateTime(left.occurredAt, right.occurredAt);
      },
      cellBuilder: (BuildContext context, ReportsWorkspaceItem item) {
        return Text(reportsDateTime(context, item.occurredAt));
      },
    ),
    AppListTableColumn<ReportsWorkspaceItem>(
      id: 'status',
      label: l10n.reportsStatusColumnLabel,
      sortComparator: (ReportsWorkspaceItem left, ReportsWorkspaceItem right) {
        return appListTableCompareText(left.status, right.status);
      },
      cellBuilder: (BuildContext context, ReportsWorkspaceItem item) {
        return AppWorkspaceStatusBadge(
          status: reportsTableStatus(context, item.status),
        );
      },
    ),
    _reportNextActionColumn(
      ref: ref,
      l10n: l10n,
      canWrite: canWrite,
      canExport: canExport,
      isSaving: isSaving,
      onAction: onNextAction,
    ),
  ];
}

List<AppListTableColumn<ComplianceLogItem>> complianceLogColumns(
  BuildContext context,
  WidgetRef ref,
  AppLocalizations l10n, {
  required bool canExport,
  required ComplianceRowActionHandler onNextAction,
}) {
  return <AppListTableColumn<ComplianceLogItem>>[
    AppListTableColumn<ComplianceLogItem>(
      id: 'event',
      label: l10n.reportsEventColumnLabel,
      sortComparator: (ComplianceLogItem left, ComplianceLogItem right) {
        return appListTableCompareText(left.title, right.title);
      },
      cellBuilder: (_, ComplianceLogItem item) => ReportsTwoLineCell(
        title: item.title,
        subtitle: item.subtitle,
        icon: Icons.manage_search_outlined,
      ),
    ),
    AppListTableColumn<ComplianceLogItem>(
      id: 'user',
      label: l10n.reportsUserColumnLabel,
      sortComparator: (ComplianceLogItem left, ComplianceLogItem right) {
        return appListTableCompareText(left.userLabel, right.userLabel);
      },
      cellBuilder: (BuildContext context, ComplianceLogItem item) {
        return Text(reportsValueOrUnknown(context, item.userLabel));
      },
    ),
    AppListTableColumn<ComplianceLogItem>(
      id: 'record',
      label: l10n.reportsRecordColumnLabel,
      sortComparator: (ComplianceLogItem left, ComplianceLogItem right) {
        return appListTableCompareText(
          left.recordReference,
          right.recordReference,
        );
      },
      cellBuilder: (BuildContext context, ComplianceLogItem item) {
        return Text(reportsValueOrUnknown(context, item.recordReference));
      },
    ),
    AppListTableColumn<ComplianceLogItem>(
      id: 'timestamp',
      label: l10n.reportsTimestampColumnLabel,
      sortComparator: (ComplianceLogItem left, ComplianceLogItem right) {
        return appListTableCompareDateTime(left.occurredAt, right.occurredAt);
      },
      cellBuilder: (BuildContext context, ComplianceLogItem item) {
        return Text(reportsDateTime(context, item.occurredAt));
      },
    ),
    _complianceNextActionColumn(
      ref: ref,
      l10n: l10n,
      canExport: canExport,
      onAction: onNextAction,
    ),
  ];
}

List<AppListTableColumn<ComplianceLogItem>> complianceLogColumnChoices(
  BuildContext context,
  AppLocalizations l10n,
) {
  return <AppListTableColumn<ComplianceLogItem>>[
    AppListTableColumn<ComplianceLogItem>(
      id: 'patient',
      label: l10n.reportsPatientLabel,
      cellBuilder: (BuildContext context, ComplianceLogItem item) {
        return Text(reportsValueOrUnknown(context, item.patientLabel));
      },
    ),
    AppListTableColumn<ComplianceLogItem>(
      id: 'action',
      label: l10n.reportsActionLabel,
      cellBuilder: (BuildContext context, ComplianceLogItem item) {
        return Text(
          reportsValueOrUnknown(context, reportsApiLabel(item.action)),
        );
      },
    ),
    AppListTableColumn<ComplianceLogItem>(
      id: 'entity',
      label: l10n.reportsEntityLabel,
      cellBuilder: (BuildContext context, ComplianceLogItem item) {
        return Text(
          reportsValueOrUnknown(context, reportsApiLabel(item.entity)),
        );
      },
    ),
    AppListTableColumn<ComplianceLogItem>(
      id: 'scope',
      label: l10n.reportsScopeLabel,
      cellBuilder: (BuildContext context, ComplianceLogItem item) {
        return Text(
          reportsValueOrUnknown(context, reportsApiLabel(item.scope)),
        );
      },
    ),
    AppListTableColumn<ComplianceLogItem>(
      id: 'purpose',
      label: l10n.reportsPurposeLabel,
      cellBuilder: (BuildContext context, ComplianceLogItem item) {
        return Text(
          reportsValueOrUnknown(context, reportsApiLabel(item.purpose)),
        );
      },
    ),
    AppListTableColumn<ComplianceLogItem>(
      id: 'legal_basis',
      label: l10n.reportsLegalBasisLabel,
      cellBuilder: (BuildContext context, ComplianceLogItem item) {
        return Text(
          reportsValueOrUnknown(context, reportsApiLabel(item.legalBasis)),
        );
      },
    ),
    AppListTableColumn<ComplianceLogItem>(
      id: 'facility',
      label: l10n.reportsFacilityLabel,
      cellBuilder: (BuildContext context, ComplianceLogItem item) {
        return Text(reportsValueOrUnknown(context, item.facilityLabel));
      },
    ),
    AppListTableColumn<ComplianceLogItem>(
      id: 'ip_address',
      label: l10n.reportsIpAddressLabel,
      cellBuilder: (BuildContext context, ComplianceLogItem item) {
        return Text(reportsValueOrUnknown(context, item.ipAddress));
      },
    ),
    AppListTableColumn<ComplianceLogItem>(
      id: 'details',
      label: l10n.reportsDetailsLabel,
      cellBuilder: (BuildContext context, ComplianceLogItem item) {
        return Text(reportsValueOrUnknown(context, item.details));
      },
    ),
  ];
}

AppListTableColumn<ReportsWorkspaceItem> _reportNextActionColumn({
  required WidgetRef ref,
  required AppLocalizations l10n,
  required bool canWrite,
  required bool canExport,
  required bool isSaving,
  required ReportRowActionHandler onAction,
}) {
  return AppListTableColumn<ReportsWorkspaceItem>(
    id: 'next_action',
    label: l10n.reportsNextActionColumnLabel,
    alwaysVisible: true,
    cellBuilder: (BuildContext context, ReportsWorkspaceItem item) {
      return ReportNextActionCell(
        item: item,
        canWrite: canWrite,
        canExport: canExport,
        isSaving: isSaving,
        onPressed: () => onAction(context, ref, item),
      );
    },
  );
}

AppListTableColumn<ComplianceLogItem> _complianceNextActionColumn({
  required WidgetRef ref,
  required AppLocalizations l10n,
  required bool canExport,
  required ComplianceRowActionHandler onAction,
}) {
  return AppListTableColumn<ComplianceLogItem>(
    id: 'next_action',
    label: l10n.reportsNextActionColumnLabel,
    alwaysVisible: true,
    cellBuilder: (BuildContext context, ComplianceLogItem item) {
      final String? label = complianceNextActionLabel(
        l10n,
        canExport: canExport,
      );
      if (label == null) {
        return const SizedBox.shrink();
      }
      return ComplianceNextActionCell(
        label: label,
        onPressed: () => onAction(context, ref, item),
      );
    },
  );
}

class ReportNextActionCell extends StatelessWidget {
  const ReportNextActionCell({
    required this.item,
    required this.canWrite,
    required this.canExport,
    required this.isSaving,
    required this.onPressed,
    super.key,
  });

  final ReportsWorkspaceItem item;
  final bool canWrite;
  final bool canExport;
  final bool isSaving;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String? label = reportNextActionLabel(
      l10n,
      item,
      canWrite: canWrite,
      canExport: canExport,
    );
    if (label == null) {
      return const SizedBox.shrink();
    }

    final bool enabled = !isSaving;
    return ReportsCompactActionButton(
      label: label,
      enabled: enabled,
      onPressed: onPressed,
    );
  }
}

class ComplianceNextActionCell extends StatelessWidget {
  const ComplianceNextActionCell({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return ReportsCompactActionButton(label: label, onPressed: onPressed);
  }
}

class ReportsCompactActionButton extends StatelessWidget {
  const ReportsCompactActionButton({
    required this.label,
    required this.onPressed,
    this.enabled = true,
    super.key,
  });

  final String label;
  final Future<void> Function() onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color primaryColor = enabled
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface.withValues(alpha: 0.38);

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Tooltip(
        message: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled
              ? () {
                  unawaited(onPressed());
                }
              : null,
          child: MouseRegion(
            cursor: enabled
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: theme.spacing.xs,
                vertical: 2,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.arrow_forward_outlined,
                    size: 14,
                    color: primaryColor,
                  ),
                  SizedBox(width: theme.spacing.xs),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ReportsTwoLineCell extends StatelessWidget {
  const ReportsTwoLineCell({
    required this.title,
    this.subtitle,
    this.icon,
    super.key,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Icon(icon, size: theme.appTokens.listIconSize),
          SizedBox(width: theme.spacing.xs),
        ],
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
              if (subtitle != null && subtitle!.isNotEmpty)
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}



class ReportsMobileTile extends StatelessWidget {
  const ReportsMobileTile({
    required this.title,
    required this.icon,
    this.subtitle,
    this.status,
    this.nextActionLabel,
    this.nextActionEnabled = true,
    this.onNextAction,
    this.onOpenDetail,
    super.key,
  });

  final String title;
  final String? subtitle;
  final AppWorkspaceStatus? status;
  final IconData icon;
  final String? nextActionLabel;
  final bool nextActionEnabled;
  final Future<void> Function()? onNextAction;
  final VoidCallback? onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.sm,
        vertical: theme.spacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: theme.appTokens.listIconSize),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                InkWell(
                  onTap: onOpenDetail,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...<Widget>[
                        SizedBox(height: theme.spacing.xs),
                        Text(
                          subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (status != null) ...<Widget>[
                  SizedBox(height: theme.spacing.xs),
                  AppWorkspaceStatusBadge(status: status!),
                ],
                if (nextActionLabel != null &&
                    onNextAction != null) ...<Widget>[
                  SizedBox(height: theme.spacing.xs),
                  ReportsCompactActionButton(
                    label: nextActionLabel!,
                    enabled: nextActionEnabled,
                    onPressed: onNextAction!,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

AppWorkspaceStatus reportsTableStatus(BuildContext context, String? value) {
  return AppWorkspaceStatus(
    label: reportsValueOrUnknown(context, reportsApiLabel(value)),
    tone: reportsStatusTone(value),
    icon: reportsStatusIcon(value),
  );
}

IconData reportsStatusIcon(String? value) {
  return switch ((value ?? '').trim().toUpperCase()) {
    'COMPLETED' ||
    'ACTIVE' ||
    'NORMAL' ||
    'PINNED' => Icons.check_circle_outline,
    'FAILED' || 'CRITICAL' || 'CANCELLED' => Icons.error_outline,
    'QUEUED' ||
    'PROCESSING' ||
    'WARNING' ||
    'PAUSED' => Icons.pending_actions_outlined,
    _ => Icons.radio_button_unchecked,
  };
}

AppWorkspaceStatusTone reportsStatusTone(String? value) {
  return switch ((value ?? '').trim().toUpperCase()) {
    'COMPLETED' ||
    'ACTIVE' ||
    'NORMAL' ||
    'PINNED' => AppWorkspaceStatusTone.success,
    'FAILED' || 'CRITICAL' || 'CANCELLED' => AppWorkspaceStatusTone.error,
    'QUEUED' ||
    'PROCESSING' ||
    'WARNING' ||
    'PAUSED' => AppWorkspaceStatusTone.warning,
    'INFO' => AppWorkspaceStatusTone.info,
    _ => AppWorkspaceStatusTone.neutral,
  };
}

String reportsDateTime(BuildContext context, DateTime? value) {
  if (value == null) {
    return context.l10n.profileUnknownValue;
  }
  return AppFormatters.dateTime(
    value.toLocal(),
    Localizations.localeOf(context),
  );
}

String reportsValueOrUnknown(BuildContext context, String? value) {
  final String normalized = value?.trim() ?? '';
  return normalized.isEmpty ? context.l10n.profileUnknownValue : normalized;
}

String? reportsJoinDisplay(Iterable<String?> values) {
  final String joined = values
      .map((String? value) => value?.trim() ?? '')
      .where((String value) => value.isNotEmpty)
      .join(' | ');
  return joined.isEmpty ? null : joined;
}

String? reportsApiLabel(String? value) {
  final String normalized =
      value?.trim().replaceAll('_', ' ').toLowerCase() ?? '';
  if (normalized.isEmpty) {
    return null;
  }
  return normalized
      .split(RegExp(r'\s+'))
      .where((String part) => part.isNotEmpty)
      .map(
        (String part) =>
            '${part.substring(0, 1).toUpperCase()}${part.substring(1)}',
      )
      .join(' ');
}

IconData reportsItemIcon(ReportItemKind kind) {
  return switch (kind) {
    ReportItemKind.definition => Icons.article_outlined,
    ReportItemKind.run => Icons.outbox_outlined,
    ReportItemKind.schedule => Icons.schedule_outlined,
    ReportItemKind.dashboardWidget => Icons.dashboard_customize_outlined,
    ReportItemKind.kpiSnapshot => Icons.bar_chart_outlined,
    ReportItemKind.analyticsEvent => Icons.insights_outlined,
  };
}
