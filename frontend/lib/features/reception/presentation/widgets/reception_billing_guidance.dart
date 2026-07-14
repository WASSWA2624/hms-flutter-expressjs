import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/permissions/access_gate.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/opd/domain/entities/opd_entities.dart';
import 'package:hosspi_hms/features/patients/domain/entities/patient_entities.dart';
import 'package:hosspi_hms/features/reception/presentation/reception_access.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/opd_actions/opd_billing_state.dart';

/// Billing guidance for reception — never cashier finalize/refund/reconcile.
class ReceptionBillingGuidancePanel extends StatelessWidget {
  const ReceptionBillingGuidancePanel({
    this.patientDetail,
    this.flow,
    this.queueEntry,
    super.key,
  });

  final PatientDetail? patientDetail;
  final OpdFlowSummary? flow;
  final OpdQueueEntry? queueEntry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final Locale locale = Localizations.localeOf(context);
    final List<PatientSummaryRecord> invoices =
        patientDetail?.workspace.invoices ?? const <PatientSummaryRecord>[];
    final List<PatientSummaryRecord> payments =
        patientDetail?.workspace.payments ?? const <PatientSummaryRecord>[];
    final OpdBillingDisplay? billing = flow != null
        ? opdFlowBillingDisplay(context, flow!)
        : queueEntry != null
        ? opdQueueBillingDisplay(context, queueEntry!)
        : null;

    return AppAccessActionGate(
      requirement: receptionBillingGuidanceRequirement,
      builder: (BuildContext context, bool isAllowed) {
        if (!isAllowed) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              l10n.receptionBillingGuidanceTitle,
              style: theme.textTheme.titleSmall,
            ),
            SizedBox(height: theme.spacing.xs),
            Text(
              l10n.receptionBillingGuidanceBody,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (billing != null) ...<Widget>[
              SizedBox(height: theme.spacing.sm),
              AppInfoTile(
                label: l10n.opdPaymentStatusLabel,
                value: billing.label,
                icon: Icons.payments_outlined,
              ),
              if ((billing.amountLabel ?? '').isNotEmpty)
                AppInfoTile(
                  label: l10n.receptionEstimatedChargeLabel,
                  value: billing.amountLabel!,
                  icon: Icons.receipt_long_outlined,
                ),
            ],
            if (flow?.consultationPaymentRequired == true) ...<Widget>[
              SizedBox(height: theme.spacing.sm),
              Text(
                l10n.receptionPaymentGateHandoffMessage,
                style: theme.textTheme.bodyMedium,
              ),
            ],
            SizedBox(height: theme.spacing.sm),
            Text(
              l10n.receptionPaymentMethodsAdvice,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (invoices.isNotEmpty) ...<Widget>[
              SizedBox(height: theme.spacing.md),
              Text(
                l10n.patientsInvoicesSectionTitle,
                style: theme.textTheme.labelLarge,
              ),
              SizedBox(height: theme.spacing.xs),
              ...invoices.take(3).map(
                (PatientSummaryRecord invoice) => _GuidanceRecordTile(
                  record: invoice,
                  locale: locale,
                  leadingIcon: Icons.receipt_outlined,
                ),
              ),
            ],
            if (payments.isNotEmpty) ...<Widget>[
              SizedBox(height: theme.spacing.md),
              Text(
                l10n.patientsPaymentsSectionTitle,
                style: theme.textTheme.labelLarge,
              ),
              SizedBox(height: theme.spacing.xs),
              ...payments.take(3).map(
                (PatientSummaryRecord payment) => _GuidanceRecordTile(
                  record: payment,
                  locale: locale,
                  leadingIcon: Icons.paid_outlined,
                ),
              ),
            ],
            SizedBox(height: theme.spacing.md),
            AppAccessActionGate(
              requirement: receptionBillingCashierRequirement,
              builder: (BuildContext context, bool canCashier) {
                if (!canCashier) {
                  return Text(
                    l10n.receptionBillingCashierRestrictedMessage,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  );
                }
                final String? patientId =
                    patientDetail?.patient.id ??
                    flow?.patientId ??
                    queueEntry?.patientId;
                return AppButton.secondary(
                  label: l10n.patientsOpenBillingWorkbenchAction,
                  leadingIcon: Icons.point_of_sale_outlined,
                  onPressed: () => context.go(
                    AppRoutes.billing.location(
                      queryParameters: <String, String>{
                        if (patientId != null && patientId.isNotEmpty)
                          'patientId': patientId,
                      },
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _GuidanceRecordTile extends StatelessWidget {
  const _GuidanceRecordTile({
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
    final String amount = record.amount == null
        ? ''
        : AppFormatters.currency(
            record.amount!,
            locale,
            currencyCode: record.currency,
          );
    final String subtitle = <String>[
      if ((record.status ?? '').trim().isNotEmpty) record.status!.trim(),
      if (amount.isNotEmpty) amount,
    ].join(' · ');

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(leadingIcon, color: theme.colorScheme.onSurfaceVariant),
      title: Text(
        (record.title ?? '').trim().isEmpty ? record.id : record.title!.trim(),
      ),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
    );
  }
}
