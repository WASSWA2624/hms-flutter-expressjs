import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/utils/app_display.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

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
                      _OpdClinicalServiceCard(row: row),
                  ],
                );
              }
              return _OpdClinicalServicesTable(rows: rows);
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
    this.requestedAt,
  });

  final IconData icon;
  final String serviceLabel;
  final String requestedLabel;
  final String statusLabel;
  final String locationLabel;
  final String resultLabel;
  final DateTime? requestedAt;
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
        requestedAt: vital.recordedAt,
      ),
    );
  }

  void addRecords(
    List<OpdRelatedRecord> records,
    IconData icon,
    String serviceKind,
  ) {
    for (final OpdRelatedRecord record in records) {
      rows.add(
        OpdClinicalServiceRow(
          icon: icon,
          serviceLabel: _serviceLabel(record),
          requestedLabel: _formatDateTime(l10n, locale, record.occurredAt),
          statusLabel: _statusLabel(l10n, record.status),
          locationLabel: opdClinicalServiceLocationLabel(
            l10n: l10n,
            record: record,
            flow: flow,
            serviceKind: serviceKind,
          ),
          resultLabel: _resultLabel(l10n, record),
          requestedAt: record.occurredAt,
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
  const _OpdClinicalServicesTable({required this.rows});

  final List<OpdClinicalServiceRow> rows;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final TextStyle headerStyle = theme.textTheme.labelSmall!.copyWith(
      fontWeight: FontWeight.w700,
      color: theme.colorScheme.onSurfaceVariant,
    );
    final TextStyle cellStyle = theme.textTheme.bodySmall!;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        showCheckboxColumn: false,
        headingRowHeight: 36,
        dataRowMinHeight: 40,
        dataRowMaxHeight: 48,
        horizontalMargin: theme.spacing.sm,
        columnSpacing: theme.spacing.md,
        columns: <DataColumn>[
          DataColumn(
            label: Text(l10n.opdClinicalServiceColumnLabel, style: headerStyle),
          ),
          DataColumn(
            label: Text(
              l10n.opdClinicalServiceRequestedColumnLabel,
              style: headerStyle,
            ),
          ),
          DataColumn(
            label: Text(
              l10n.opdClinicalServiceStatusColumnLabel,
              style: headerStyle,
            ),
          ),
          DataColumn(
            label: Text(
              l10n.opdClinicalServiceLocationColumnLabel,
              style: headerStyle,
            ),
          ),
          DataColumn(
            label: Text(
              l10n.opdClinicalServiceResultColumnLabel,
              style: headerStyle,
            ),
          ),
        ],
        rows: <DataRow>[
          for (final OpdClinicalServiceRow row in rows)
            DataRow(
              cells: <DataCell>[
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        row.icon,
                        size: theme.appTokens.listIconSize,
                        color: theme.colorScheme.primary,
                      ),
                      SizedBox(width: theme.spacing.xs),
                      Flexible(
                        child: Tooltip(
                          message: row.serviceLabel,
                          child: Text(
                            row.serviceLabel,
                            style: cellStyle.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                DataCell(Text(row.requestedLabel, style: cellStyle)),
                DataCell(Text(row.statusLabel, style: cellStyle)),
                DataCell(Text(row.locationLabel, style: cellStyle)),
                DataCell(
                  Tooltip(
                    message: row.resultLabel,
                    child: Text(
                      row.resultLabel,
                      style: cellStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _OpdClinicalServiceCard extends StatelessWidget {
  const _OpdClinicalServiceCard({required this.row});

  final OpdClinicalServiceRow row;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;

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
              Text(
                '${l10n.opdClinicalServiceStatusColumnLabel}: ${row.statusLabel}',
                style: theme.textTheme.bodySmall,
              ),
              Text(
                '${l10n.opdClinicalServiceLocationColumnLabel}: ${row.locationLabel}',
                style: theme.textTheme.bodySmall,
              ),
              Text(
                '${l10n.opdClinicalServiceResultColumnLabel}: ${row.resultLabel}',
                style: theme.textTheme.bodySmall,
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
