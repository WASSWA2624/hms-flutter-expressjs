import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

class PatientBillingContextPanel extends StatelessWidget {
  const PatientBillingContextPanel({required this.detail, super.key});

  final PatientDetail detail;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final Locale locale = Localizations.localeOf(context);
    final List<PatientSummaryRecord> invoices = detail.workspace.invoices;
    final List<PatientSummaryRecord> payments = detail.workspace.payments;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                l10n.patientsBillingSectionTitle,
                style: theme.textTheme.titleSmall,
              ),
            ),
            AppButton.secondary(
              label: l10n.patientsOpenBillingWorkbenchAction,
              leadingIcon: Icons.receipt_long_outlined,
              onPressed: () => context.go(
                AppRoutes.billing.location(
                  queryParameters: <String, String>{
                    'patientId': detail.patient.id,
                  },
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: theme.spacing.sm),
        Text(
          l10n.patientsInvoicesSectionTitle,
          style: theme.textTheme.labelLarge,
        ),
        SizedBox(height: theme.spacing.xs),
        if (invoices.isEmpty)
          Text(
            l10n.patientsNoInvoices,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          ...invoices.map(
            (PatientSummaryRecord invoice) => _BillingSummaryTile(
              record: invoice,
              locale: locale,
              leadingIcon: Icons.receipt_outlined,
            ),
          ),
        SizedBox(height: theme.spacing.md),
        Text(
          l10n.patientsPaymentsSectionTitle,
          style: theme.textTheme.labelLarge,
        ),
        SizedBox(height: theme.spacing.xs),
        if (payments.isEmpty)
          Text(
            l10n.patientsNoPayments,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          ...payments.map(
            (PatientSummaryRecord payment) => _BillingSummaryTile(
              record: payment,
              locale: locale,
              leadingIcon: Icons.payments_outlined,
            ),
          ),
      ],
    );
  }
}

class _BillingSummaryTile extends StatelessWidget {
  const _BillingSummaryTile({
    required this.record,
    required this.locale,
    required this.leadingIcon,
  });

  final PatientSummaryRecord record;
  final Locale locale;
  final IconData leadingIcon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? occurredAt = record.occurredAt == null
        ? null
        : AppFormatters.dateTime(record.occurredAt!, locale);
    final String? amount = record.amount == null
        ? null
        : AppFormatters.currency(
            record.amount!,
            locale,
            currencyCode: record.currency,
          );
    final String subtitle = <String>[
      if ((record.status ?? '').trim().isNotEmpty) record.status!.trim(),
      ?amount,
      ?occurredAt,
    ].join(' · ');

    return Padding(
      padding: EdgeInsets.only(bottom: theme.spacing.xs),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(leadingIcon),
        title: Text(record.title ?? record.id),
        subtitle: subtitle.isEmpty ? null : Text(subtitle),
      ),
    );
  }
}
