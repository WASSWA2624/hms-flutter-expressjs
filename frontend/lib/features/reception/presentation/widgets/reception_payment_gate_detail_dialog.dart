import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_entities.dart';
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_detail_widgets.dart';
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_support.dart';
import 'package:hosspi_hms/features/reception/domain/entities/reception_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_action_context.dart';

Future<void> showReceptionPaymentGateDetailDialog({
  required BuildContext context,
  required ReceptionPaymentGateEntry entry,
}) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) =>
        _ReceptionPaymentGateDetailDialog(entry: entry),
  );
}

class _ReceptionPaymentGateDetailDialog extends StatelessWidget {
  const _ReceptionPaymentGateDetailDialog({required this.entry});

  final ReceptionPaymentGateEntry entry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String total = _moneySummary(context, entry.outstandingByCurrency);

    return AppDialog(
      title: Text(context.l10n.receptionBillingGuidanceTitle),
      icon: const Icon(Icons.receipt_long_outlined),
      semanticLabel: context.l10n.receptionBillingGuidanceTitle,
      scrollable: true,
      maxWidth: 760,
      content: Column(
        key: const ValueKey<String>('receptionPaymentGateReadOnlyDetail'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          OpdWorkflowContextPanel(
            patientName: entry.patientName,
            patientNumber: entry.patientIdentifier ?? '',
            currentStep: billingClearanceLabel(context, entry.clearanceState),
            currentStepCode: entry.clearanceState.name,
            currentStepTone: billingClearanceTone(entry.clearanceState),
            nextStep: context.l10n.receptionBillingGuidanceTitle,
            expandedFields: <AppWorkspacePatientContextField>[
              AppWorkspacePatientContextField(
                label: context.l10n.billingEncounterLabel,
                value: entry.encounterIdentifier,
                icon: Icons.local_hospital_outlined,
              ),
              AppWorkspacePatientContextField(
                label: context.l10n.billingAmountDueColumn,
                value: total,
                icon: Icons.account_balance_wallet_outlined,
                tone: AppWorkspaceStatusTone.warning,
              ),
            ],
          ),
          SizedBox(height: theme.spacing.md),
          Text(
            context.l10n.receptionPaymentGateReadOnlyBody,
            style: theme.textTheme.bodyMedium,
          ),
          SizedBox(height: theme.spacing.md),
          for (final BillingWorkItem invoice in entry.invoices) ...<Widget>[
            _OutstandingInvoiceCard(invoice: invoice),
            SizedBox(height: theme.spacing.sm),
          ],
        ],
      ),
    );
  }
}

class _OutstandingInvoiceCard extends StatelessWidget {
  const _OutstandingInvoiceCard({required this.invoice});

  final BillingWorkItem invoice;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Set<String> sources = <String>{
      if ((invoice.sourceModule ?? '').trim().isNotEmpty)
        invoice.sourceModule!.trim(),
      for (final String module in invoice.sourceModules)
        if (module.trim().isNotEmpty) module.trim(),
      for (final BillingInvoiceItem item in invoice.items)
        if ((item.sourceModule ?? '').trim().isNotEmpty)
          item.sourceModule!.trim(),
    };
    final String sourceLabel = sources.isEmpty
        ? context.l10n.profileUnknownValue
        : sources
              .map((String source) => billingApiLabel(context, source))
              .join(', ');

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: AppListItemText(
                    title: sourceLabel,
                    subtitle: billingJoinDisplay(<String?>[
                      invoice.effectiveDisplayId,
                      invoice.encounterDisplayId ?? invoice.encounterId,
                    ]),
                  ),
                ),
                SizedBox(width: theme.spacing.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      billingMoney(
                        context,
                        invoice.balanceDue,
                        invoice.currency,
                      ),
                      style: theme.textTheme.titleMedium,
                    ),
                    SizedBox(height: theme.spacing.xs),
                    BillingGateBadge(state: invoice.clearanceState),
                  ],
                ),
              ],
            ),
            if (invoice.items.isNotEmpty) ...<Widget>[
              Divider(height: theme.spacing.lg),
              for (final BillingInvoiceItem item in invoice.items)
                Padding(
                  padding: EdgeInsets.only(bottom: theme.spacing.xs),
                  child: Text(
                    '${item.quantity} × ${item.description}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

String _moneySummary(BuildContext context, Map<String, num> totals) {
  return totals.entries
      .map(
        (MapEntry<String, num> entry) =>
            billingMoney(context, entry.value, entry.key),
      )
      .join(' · ');
}
