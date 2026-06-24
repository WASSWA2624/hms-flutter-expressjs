import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_entities.dart';
import 'package:hosspi_hms/features/billing/presentation/controllers/billing_workspace_controller.dart';
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_support.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

Future<void> showBillingLedgerDialog(
  BuildContext context,
  WidgetRef ref, {
  required BillingWorkItem item,
}) async {
  final String? patientId = item.patientId ?? item.effectivePatientNumber;
  if (patientId == null || patientId.isEmpty) {
    return;
  }

  await showAppDialog<void>(
    context: context,
    builder: (_) => _BillingLedgerDialog(patientId: patientId, item: item),
  );
}

class _BillingLedgerDialog extends ConsumerStatefulWidget {
  const _BillingLedgerDialog({required this.patientId, required this.item});

  final String patientId;
  final BillingWorkItem item;

  @override
  ConsumerState<_BillingLedgerDialog> createState() =>
      _BillingLedgerDialogState();
}

class _BillingLedgerDialogState extends ConsumerState<_BillingLedgerDialog> {
  late Future<Result<BillingPatientLedger>> _ledgerFuture;

  @override
  void initState() {
    super.initState();
    _ledgerFuture = ref
        .read(billingWorkspaceControllerProvider.notifier)
        .fetchPatientLedger(widget.patientId);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppDialog(
      title: Text(l10n.billingLedgerTitle),
      icon: const Icon(Icons.account_balance_wallet_outlined),
      scrollable: true,
      maxWidth: 860,
      content: FutureBuilder<Result<BillingPatientLedger>>(
        future: _ledgerFuture,
        builder:
            (
              BuildContext context,
              AsyncSnapshot<Result<BillingPatientLedger>> snapshot,
            ) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return snapshot.data!.when(
                success: (BillingPatientLedger ledger) {
                  return _BillingLedgerBody(
                    ledger: ledger,
                    currency: widget.item.currency,
                  );
                },
                failure: (AppFailure failure) {
                  return AppFailureStateView(
                    failure: failure,
                    onRetry: () {
                      setState(() {
                        _ledgerFuture = ref
                            .read(billingWorkspaceControllerProvider.notifier)
                            .fetchPatientLedger(widget.patientId);
                      });
                    },
                  );
                },
              );
            },
      ),
      actions: <Widget>[
        AppButton.secondary(
          label: l10n.commonCloseActionLabel,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }
}

class _BillingLedgerBody extends StatelessWidget {
  const _BillingLedgerBody({required this.ledger, this.currency});

  final BillingPatientLedger ledger;
  final String? currency;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final BillingLedgerSummary summary = ledger.summary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppReportSummaryGrid(
          records: <AppReportSummaryItem>[
            AppReportSummaryItem(
              label: l10n.billingAmountColumn,
              value: billingMoney(context, summary.totalInvoiced, currency),
              icon: Icons.receipt_long_outlined,
            ),
            AppReportSummaryItem(
              label: l10n.billingPaidColumn,
              value: billingMoney(context, summary.netPaid, currency),
              icon: Icons.payments_outlined,
            ),
            AppReportSummaryItem(
              label: l10n.billingBalanceColumn,
              value: billingMoney(context, summary.balanceDue, currency),
              icon: Icons.account_balance_wallet_outlined,
            ),
          ],
        ),
        SizedBox(height: theme.spacing.md),
        if (ledger.entries.isEmpty)
          Text(l10n.billingLedgerEmpty)
        else
          Column(
            children: <Widget>[
              for (final BillingLedgerEntry entry in ledger.entries)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(_ledgerIcon(entry.kind)),
                  title: Text(
                    billingJoinDisplay(<String?>[
                      entry.displayId,
                      billingApiLabel(context, entry.action),
                    ]),
                  ),
                  subtitle: Text(
                    billingJoinDisplay(<String?>[
                      billingApiLabel(context, entry.status),
                      billingDateTime(context, entry.timelineAt),
                    ]),
                  ),
                  trailing: Text(
                    billingMoney(context, entry.amount, entry.currency),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  IconData _ledgerIcon(BillingWorkItemKind kind) {
    return switch (kind) {
      BillingWorkItemKind.invoice => Icons.receipt_long_outlined,
      BillingWorkItemKind.payment => Icons.payments_outlined,
      BillingWorkItemKind.refund => Icons.assignment_return_outlined,
      BillingWorkItemKind.claim => Icons.health_and_safety_outlined,
      BillingWorkItemKind.adjustment => Icons.tune,
      BillingWorkItemKind.approval => Icons.rule_outlined,
      BillingWorkItemKind.preAuthorization => Icons.verified_user_outlined,
      BillingWorkItemKind.other => Icons.receipt_outlined,
    };
  }
}
