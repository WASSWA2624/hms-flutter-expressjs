import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/utils/app_display.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_status_display.dart';

bool opdDetailHasClinicalRecords(OpdFlowDetail detail) {
  return detail.vitalMeasurements.isNotEmpty ||
      detail.vitalSigns.isNotEmpty ||
      detail.diagnoses.isNotEmpty ||
      detail.labOrders.isNotEmpty ||
      detail.radiologyOrders.isNotEmpty ||
      detail.pharmacyOrders.isNotEmpty ||
      detail.procedures.isNotEmpty;
}

class OpdEncounterClinicalServicesPanel extends StatelessWidget {
  const OpdEncounterClinicalServicesPanel({
    required this.detail,
    required this.flow,
    super.key,
  });

  final OpdFlowDetail detail;
  final OpdFlowSummary flow;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final List<OpdClinicalServiceRow> rows = buildOpdClinicalServiceRows(
      l10n: l10n,
      locale: Localizations.localeOf(context),
      detail: detail,
      flow: flow,
    );

    return AppSectionPanel(
      title: l10n.opdClinicalServicesTitle,
      density: AppContentPanelDensity.compact,
      children: <Widget>[
        if (rows.isEmpty)
          Text(
            l10n.opdClinicalServicesEmpty,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          )
        else
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool compact = constraints.maxWidth < 640;
              if (compact) {
                return Column(
                  children: <Widget>[
                    for (final OpdClinicalServiceRow row in rows)
                      _OpdClinicalServiceCard(row: row, l10n: l10n),
                  ],
                );
              }
              return _OpdClinicalServicesTable(rows: rows, l10n: l10n);
            },
          ),
      ],
    );
  }
}

@immutable
final class OpdClinicalServiceRow {
  const OpdClinicalServiceRow({
    required this.icon,
    required this.serviceLabel,
    required this.requestedLabel,
    required this.statusLabel,
    required this.locationLabel,
    required this.resultLabel,
    required this.statusTone,
    required this.locationTone,
    this.requestedAt,
    this.statusCode,
  });

  final IconData icon;
  final String serviceLabel;
  final String requestedLabel;
  final String statusLabel;
  final String locationLabel;
  final String resultLabel;
  final AppWorkspaceStatusTone statusTone;
  final AppWorkspaceStatusTone locationTone;
  final DateTime? requestedAt;
  final String? statusCode;
}

List<OpdClinicalServiceRow> buildOpdClinicalServiceRows({
  required AppLocalizations l10n,
  required Locale locale,
  required OpdFlowDetail detail,
  required OpdFlowSummary flow,
}) {
  final List<OpdClinicalServiceRow> rows = <OpdClinicalServiceRow>[];

  for (final OpdVitalSign vital in detail.vitalMeasurements) {
    rows.add(
      OpdClinicalServiceRow(
        icon: Icons.monitor_heart_outlined,
        serviceLabel: AppDisplay.apiLabel(vital.vitalType),
        requestedLabel: _formatDateTime(l10n, locale, vital.recordedAt),
        statusLabel: l10n.opdClinicalServiceStatusCompletedLabel,
        locationLabel: l10n.opdServiceLocationTriageLabel,
        resultLabel: vital.displayValue.isEmpty
            ? l10n.profileUnknownValue
            : vital.displayValue,
        statusTone: AppWorkspaceStatusTone.success,
        locationTone: AppWorkspaceStatusTone.neutral,
        requestedAt: vital.recordedAt,
        statusCode: 'COMPLETED',
      ),
    );
  }

  void addRecords(
    List<OpdRelatedRecord> records,
    IconData icon,
    String serviceKind,
  ) {
    for (final OpdRelatedRecord record in records) {
      final String? status = record.status;
      rows.add(
        OpdClinicalServiceRow(
          icon: icon,
          serviceLabel: _serviceLabel(record),
          requestedLabel: _formatDateTime(l10n, locale, record.occurredAt),
          statusLabel: _statusLabel(l10n, status),
          locationLabel: opdClinicalServiceLocationLabel(
            l10n: l10n,
            record: record,
            flow: flow,
            serviceKind: serviceKind,
          ),
          resultLabel: _resultLabel(l10n, record),
          statusTone: opdClinicalServiceStatusTone(status),
          locationTone: opdClinicalServiceLocationTone(
            record: record,
            serviceKind: serviceKind,
            flow: flow,
          ),
          requestedAt: record.occurredAt,
          statusCode: status,
        ),
      );
    }
  }

  addRecords(detail.diagnoses, Icons.rule_outlined, 'DIAGNOSIS');
  addRecords(detail.labOrders, Icons.science_outlined, 'LAB');
  addRecords(detail.radiologyOrders, Icons.biotech_outlined, 'RADIOLOGY');
  addRecords(detail.pharmacyOrders, Icons.medication_outlined, 'PHARMACY');
  addRecords(detail.procedures, Icons.healing_outlined, 'PROCEDURE');

  rows.sort((OpdClinicalServiceRow left, OpdClinicalServiceRow right) {
    final DateTime leftDate =
        left.requestedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final DateTime rightDate =
        right.requestedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return leftDate.compareTo(rightDate);
  });

  return rows;
}

AppWorkspaceStatusTone opdClinicalServiceLocationTone({
  required OpdRelatedRecord record,
  required String serviceKind,
  required OpdFlowSummary flow,
}) {
  final String status = (record.status ?? '').toUpperCase();
  if (<String>{
    'COMPLETED',
    'DONE',
    'DISPENSED',
    'REPORTED',
    'FINAL',
  }.contains(status)) {
    return AppWorkspaceStatusTone.success;
  }

  final String stage = (flow.displayCode ?? flow.stage ?? '').toUpperCase();
  return switch (serviceKind) {
    'LAB' => switch (stage) {
      'IN_LAB' || 'SAMPLE_PENDING' => AppWorkspaceStatusTone.info,
      _ => AppWorkspaceStatusTone.neutral,
    },
    'RADIOLOGY' => switch (stage) {
      'IMAGING_PENDING' || 'REPORT_PENDING' => AppWorkspaceStatusTone.info,
      _ => AppWorkspaceStatusTone.neutral,
    },
    'PHARMACY' => switch (stage) {
      'PHARMACY_PENDING' ||
      'PHARMACY_REQUESTED' ||
      'DISPENSING' => AppWorkspaceStatusTone.info,
      _ => AppWorkspaceStatusTone.neutral,
    },
    _ => AppWorkspaceStatusTone.neutral,
  };
}

String opdClinicalServiceLocationLabel({
  required AppLocalizations l10n,
  required OpdRelatedRecord record,
  required OpdFlowSummary flow,
  required String serviceKind,
}) {
  final String stage = (flow.displayCode ?? flow.stage ?? '').toUpperCase();
  final String status = (record.status ?? '').toUpperCase();
  if (<String>{
    'COMPLETED',
    'DONE',
    'DISPENSED',
    'REPORTED',
    'FINAL',
  }.contains(status)) {
    return l10n.opdServiceLocationCompletedLabel;
  }

  return switch (serviceKind) {
    'LAB' => switch (stage) {
      'IN_LAB' || 'SAMPLE_PENDING' => l10n.opdServiceLocationInLabLabel,
      'LAB_PENDING' ||
      'LAB_REQUESTED' ||
      'LAB_AND_RADIOLOGY_REQUESTED' => l10n.opdServiceLocationWaitingLabel,
      _ => l10n.opdServiceLocationLabQueueLabel,
    },
    'RADIOLOGY' => switch (stage) {
      'IMAGING_PENDING' ||
      'REPORT_PENDING' => l10n.opdServiceLocationInRadiologyLabel,
      'RADIOLOGY_REQUESTED' ||
      'LAB_AND_RADIOLOGY_REQUESTED' => l10n.opdServiceLocationWaitingLabel,
      _ => l10n.opdServiceLocationRadiologyQueueLabel,
    },
    'PHARMACY' => switch (stage) {
      'PHARMACY_PENDING' ||
      'PHARMACY_REQUESTED' ||
      'DISPENSING' => l10n.opdServiceLocationAtPharmacyLabel,
      _ => l10n.opdServiceLocationPharmacyQueueLabel,
    },
    'DIAGNOSIS' => l10n.opdServiceLocationConsultationLabel,
    'PROCEDURE' => l10n.opdServiceLocationProcedureLabel,
    _ => l10n.profileUnknownValue,
  };
}

class _OpdClinicalServicesTable extends StatelessWidget {
  const _OpdClinicalServicesTable({required this.rows, required this.l10n});

  final List<OpdClinicalServiceRow> rows;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle headerStyle = theme.textTheme.labelSmall!.copyWith(
      fontWeight: FontWeight.w700,
      color: theme.colorScheme.onSurfaceVariant,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(theme.radius.sm),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(theme.radius.sm),
        child: Table(
          columnWidths: const <int, TableColumnWidth>{
            0: FlexColumnWidth(2.6),
            1: FlexColumnWidth(2.2),
            2: FlexColumnWidth(1.6),
            3: FlexColumnWidth(1.6),
            4: FlexColumnWidth(2.4),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: <TableRow>[
            TableRow(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
              ),
              children: <Widget>[
                _HeaderCell(l10n.opdClinicalServiceColumnLabel, headerStyle),
                _HeaderCell(
                  l10n.opdClinicalServiceRequestedColumnLabel,
                  headerStyle,
                ),
                _HeaderCell(
                  l10n.opdClinicalServiceStatusColumnLabel,
                  headerStyle,
                ),
                _HeaderCell(
                  l10n.opdClinicalServiceLocationColumnLabel,
                  headerStyle,
                ),
                _HeaderCell(
                  l10n.opdClinicalServiceResultColumnLabel,
                  headerStyle,
                ),
              ],
            ),
            for (final OpdClinicalServiceRow row in rows)
              TableRow(
                children: <Widget>[
                  _ServiceCell(row: row),
                  _BodyCell(text: row.requestedLabel),
                  _BodyCell(
                    child: _OpdClinicalServiceStatusChip(
                      label: row.statusLabel,
                      tone: row.statusTone,
                    ),
                  ),
                  _BodyCell(
                    child: _OpdClinicalServiceStatusChip(
                      label: row.locationLabel,
                      tone: row.locationTone,
                      compact: true,
                    ),
                  ),
                  _ResultCell(row: row, l10n: l10n),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.label, this.style);

  final String label;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.sm,
        vertical: theme.spacing.xs,
      ),
      child: Text(label, style: style),
    );
  }
}

class _BodyCell extends StatelessWidget {
  const _BodyCell({this.text, this.child});

  final String? text;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.sm,
        vertical: theme.spacing.xs,
      ),
      child: child ?? Text(text ?? '', style: theme.textTheme.bodySmall),
    );
  }
}

class _ServiceCell extends StatelessWidget {
  const _ServiceCell({required this.row});

  final OpdClinicalServiceRow row;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.sm,
        vertical: theme.spacing.xs,
      ),
      child: Row(
        children: <Widget>[
          Icon(
            row.icon,
            size: theme.appTokens.listIconSize,
            color: theme.colorScheme.primary,
          ),
          SizedBox(width: theme.spacing.xs),
          Expanded(
            child: Tooltip(
              message: row.serviceLabel,
              child: Text(
                row.serviceLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultCell extends StatelessWidget {
  const _ResultCell({required this.row, required this.l10n});

  final OpdClinicalServiceRow row;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool unavailable = row.resultLabel == l10n.profileUnknownValue;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.sm,
        vertical: theme.spacing.xs,
      ),
      child: Tooltip(
        message: row.resultLabel,
        child: Text(
          row.resultLabel,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: unavailable ? FontWeight.w500 : FontWeight.w700,
            color: unavailable
                ? theme.colorScheme.onSurfaceVariant
                : theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _OpdClinicalServiceStatusChip extends StatelessWidget {
  const _OpdClinicalServiceStatusChip({
    required this.label,
    required this.tone,
    this.compact = false,
  });

  final String label;
  final AppWorkspaceStatusTone tone;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppStatusColors statusColors = theme.statusColors;
    final _ClinicalChipColors colors = _clinicalChipColors(
      theme,
      statusColors,
      tone,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(theme.radius.sm),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? theme.spacing.xs : theme.spacing.sm,
          vertical: theme.spacing.xs,
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style:
              (compact
                      ? theme.textTheme.labelSmall
                      : theme.textTheme.labelMedium)
                  ?.copyWith(
                    color: colors.foreground,
                    fontWeight: FontWeight.w700,
                  ),
        ),
      ),
    );
  }
}

@immutable
final class _ClinicalChipColors {
  const _ClinicalChipColors({
    required this.background,
    required this.foreground,
    required this.border,
  });

  final Color background;
  final Color foreground;
  final Color border;
}

_ClinicalChipColors _clinicalChipColors(
  ThemeData theme,
  AppStatusColors statusColors,
  AppWorkspaceStatusTone tone,
) {
  return switch (tone) {
    AppWorkspaceStatusTone.success => _ClinicalChipColors(
      background: statusColors.successContainer,
      foreground: statusColors.onSuccessContainer,
      border: statusColors.success,
    ),
    AppWorkspaceStatusTone.warning => _ClinicalChipColors(
      background: statusColors.warningContainer,
      foreground: statusColors.onWarningContainer,
      border: statusColors.warning,
    ),
    AppWorkspaceStatusTone.error => _ClinicalChipColors(
      background: statusColors.errorContainer,
      foreground: statusColors.onErrorContainer,
      border: statusColors.error,
    ),
    AppWorkspaceStatusTone.info => _ClinicalChipColors(
      background: statusColors.infoContainer,
      foreground: statusColors.onInfoContainer,
      border: statusColors.info,
    ),
    AppWorkspaceStatusTone.neutral => _ClinicalChipColors(
      background: theme.colorScheme.surfaceContainerHighest,
      foreground: theme.colorScheme.onSurfaceVariant,
      border: theme.colorScheme.outlineVariant,
    ),
  };
}

class _OpdClinicalServiceCard extends StatelessWidget {
  const _OpdClinicalServiceCard({required this.row, required this.l10n});

  final OpdClinicalServiceRow row;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool unavailable = row.resultLabel == l10n.profileUnknownValue;

    return Padding(
      padding: EdgeInsets.only(bottom: theme.spacing.sm),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(theme.radius.sm),
        ),
        child: Padding(
          padding: EdgeInsets.all(theme.spacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    row.icon,
                    size: theme.appTokens.listIconSize,
                    color: theme.colorScheme.primary,
                  ),
                  SizedBox(width: theme.spacing.xs),
                  Expanded(
                    child: Text(
                      row.serviceLabel,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: theme.spacing.xs),
              Text(
                '${l10n.opdClinicalServiceRequestedColumnLabel}: ${row.requestedLabel}',
                style: theme.textTheme.bodySmall,
              ),
              Wrap(
                spacing: theme.spacing.xs,
                runSpacing: theme.spacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Text(
                    '${l10n.opdClinicalServiceStatusColumnLabel}:',
                    style: theme.textTheme.bodySmall,
                  ),
                  _OpdClinicalServiceStatusChip(
                    label: row.statusLabel,
                    tone: row.statusTone,
                    compact: true,
                  ),
                ],
              ),
              Wrap(
                spacing: theme.spacing.xs,
                runSpacing: theme.spacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Text(
                    '${l10n.opdClinicalServiceLocationColumnLabel}:',
                    style: theme.textTheme.bodySmall,
                  ),
                  _OpdClinicalServiceStatusChip(
                    label: row.locationLabel,
                    tone: row.locationTone,
                    compact: true,
                  ),
                ],
              ),
              Text(
                '${l10n.opdClinicalServiceResultColumnLabel}: ${row.resultLabel}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: unavailable ? FontWeight.w500 : FontWeight.w700,
                  color: unavailable
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _serviceLabel(OpdRelatedRecord record) {
  final String title = (record.title ?? '').trim();
  if (title.isNotEmpty) {
    return title;
  }
  return record.id;
}

String _statusLabel(AppLocalizations l10n, String? status) {
  final String normalized = (status ?? '').trim().toUpperCase();
  if (normalized.isEmpty) {
    return l10n.opdClinicalServiceStatusPendingLabel;
  }
  return AppDisplay.apiLabel(status);
}

String _resultLabel(AppLocalizations l10n, OpdRelatedRecord record) {
  final String subtitle = (record.subtitle ?? '').trim();
  if (subtitle.isNotEmpty && subtitle != record.id) {
    return subtitle;
  }
  final String status = (record.status ?? '').trim().toUpperCase();
  if (<String>{
    'COMPLETED',
    'DONE',
    'DISPENSED',
    'REPORTED',
    'FINAL',
  }.contains(status)) {
    return l10n.opdClinicalServiceStatusCompletedLabel;
  }
  return l10n.profileUnknownValue;
}

String _formatDateTime(AppLocalizations l10n, Locale locale, DateTime? value) {
  if (value == null) {
    return l10n.profileUnknownValue;
  }
  return AppFormatters.dateTime(value, locale);
}
