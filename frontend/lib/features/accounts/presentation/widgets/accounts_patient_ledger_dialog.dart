import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/core/realtime/realtime_event_groups.dart';
import 'package:hosspi_hms/core/realtime/realtime_message.dart';
import 'package:hosspi_hms/core/realtime/realtime_providers.dart';
import 'package:hosspi_hms/core/security/session_controller.dart';
import 'package:hosspi_hms/features/accounts/data/repositories/accounts_repository_impl.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_entities.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_access.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_strings.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_patient_ledger_print_helpers.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_support.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

Future<void> showAccountsPatientLedgerDialog(
  BuildContext context,
  WidgetRef ref, {
  required String patientId,
  String? patientDisplayName,
  String? currency,
}) async {
  if (patientId.trim().isEmpty) {
    return;
  }
  await showAppDialog<void>(
    context: context,
    builder: (_) => _AccountsPatientLedgerDialog(
      patientId: patientId,
      patientDisplayName: patientDisplayName,
      currency: currency,
    ),
  );
}

class _AccountsPatientLedgerDialog extends ConsumerStatefulWidget {
  const _AccountsPatientLedgerDialog({
    required this.patientId,
    this.patientDisplayName,
    this.currency,
  });

  final String patientId;
  final String? patientDisplayName;
  final String? currency;

  @override
  ConsumerState<_AccountsPatientLedgerDialog> createState() =>
      _AccountsPatientLedgerDialogState();
}

class _AccountsPatientLedgerDialogState
    extends ConsumerState<_AccountsPatientLedgerDialog> {
  late Future<Result<AccountsPatientLedger>> _ledgerFuture;

  @override
  void initState() {
    super.initState();
    _ledgerFuture = _loadLedger();
  }

  Future<Result<AccountsPatientLedger>> _loadLedger() {
    final String? facilityId = ref
        .read(sessionStateProvider)
        .session
        ?.user
        ?.facilityId;
    return ref
        .read(accountsRepositoryProvider)
        .getPatientLedger(widget.patientId, facilityId: facilityId);
  }

  Future<void> _pay(AccountsPatientLedger ledger) async {
    final String patientId = ledger.patientId.isNotEmpty
        ? ledger.patientId
        : widget.patientId;
    await Navigator.of(context).maybePop();
    if (!mounted) {
      return;
    }
    context.go(
      AppRoutes.billing.location(
        queryParameters: <String, String>{
          'section': 'collect',
          'action': 'pay',
          'patientId': patientId,
        },
      ),
    );
  }

  Future<void> _onPrintPressed() async {
    final Result<AccountsPatientLedger> result = await _ledgerFuture;
    if (!mounted) {
      return;
    }
    await result.when(
      success: (AccountsPatientLedger ledger) {
        return printAccountsPatientLedgerPacket(
          ref: ref,
          context: context,
          ledger: ledger,
          currency: widget.currency,
        );
      },
      failure: (AppFailure failure) async {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.failureMessage(failure))),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool canPay = canPayFromAccounts(ref.watch(appAccessPolicyProvider));

    ref.listen<AsyncValue<RealtimeMessage>>(realtimeMessagesProvider, (
      AsyncValue<RealtimeMessage>? previous,
      AsyncValue<RealtimeMessage> next,
    ) {
      if (next case AsyncData<RealtimeMessage>(
        value: final RealtimeMessage m,
      )) {
        if (RealtimeEventGroups.billing.contains(m.event) && mounted) {
          setState(() {
            _ledgerFuture = _loadLedger();
          });
        }
      }
    });

    final String titleName = accountsPatientPublicLabel(
      patientDisplayName: widget.patientDisplayName,
      patientId: widget.patientId,
    );
    final bool titleHasPatient =
        titleName != AccountsStrings.patientColumn && titleName != '—';

    return AppDialog(
      title: Text(
        titleHasPatient
            ? '${AccountsStrings.patientLedgerTitle} · $titleName'
            : AccountsStrings.patientLedgerTitle,
      ),
      icon: const Icon(Icons.account_balance_wallet_outlined),
      scrollable: true,
      maxWidth: 860,
      content: FutureBuilder<Result<AccountsPatientLedger>>(
        future: _ledgerFuture,
        builder:
            (
              BuildContext context,
              AsyncSnapshot<Result<AccountsPatientLedger>> snapshot,
            ) {
              if (!snapshot.hasData) {
                return const LinearProgressIndicator(minHeight: 2);
              }
              return snapshot.data!.when(
                success: (AccountsPatientLedger ledger) {
                  return _AccountsPatientLedgerBody(
                    ledger: ledger,
                    currency: widget.currency,
                  );
                },
                failure: (AppFailure failure) {
                  return AppFailureStateView(
                    failure: failure,
                    onRetry: () {
                      setState(() {
                        _ledgerFuture = _loadLedger();
                      });
                    },
                  );
                },
              );
            },
      ),
      actions: <Widget>[
        AppButton.secondary(
          label: AccountsStrings.printAction,
          onPressed: () => unawaited(_onPrintPressed()),
        ),
        FutureBuilder<Result<AccountsPatientLedger>>(
          future: _ledgerFuture,
          builder:
              (
                BuildContext context,
                AsyncSnapshot<Result<AccountsPatientLedger>> snapshot,
              ) {
                final AccountsPatientLedger? ledger = snapshot.data?.when(
                  success: (AccountsPatientLedger value) => value,
                  failure: (_) => null,
                );
                final bool showPay =
                    canPay && ledger != null && ledger.summary.balanceDue > 0;
                if (!showPay) {
                  return const SizedBox.shrink();
                }
                return AppButton.primary(
                  label: AccountsStrings.payAction,
                  tooltip: AccountsStrings.payActionTooltip,
                  onPressed: () => unawaited(_pay(ledger)),
                );
              },
        ),
        AppButton.secondary(
          label: context.l10n.commonCloseActionLabel,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }
}

class _AccountsPatientLedgerBody extends StatelessWidget {
  const _AccountsPatientLedgerBody({required this.ledger, this.currency});

  final AccountsPatientLedger ledger;
  final String? currency;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AccountsPatientLedgerSummary summary = ledger.summary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppReportSummaryGrid(
          records: <AppReportSummaryItem>[
            AppReportSummaryItem(
              label: AccountsStrings.invoicedColumn,
              value: accountsMoney(context, summary.totalInvoiced, currency),
              icon: Icons.receipt_long_outlined,
            ),
            AppReportSummaryItem(
              label: AccountsStrings.paidColumn,
              value: accountsMoney(context, summary.netPaid, currency),
              icon: Icons.payments_outlined,
            ),
            AppReportSummaryItem(
              label: AccountsStrings.balanceColumn,
              value: accountsMoney(context, summary.balanceDue, currency),
              icon: Icons.account_balance_wallet_outlined,
            ),
          ],
        ),
        SizedBox(height: theme.spacing.md),
        if (ledger.entries.isEmpty)
          const Text(AccountsStrings.patientLedgerEmpty)
        else
          Column(
            children: <Widget>[
              for (final AccountsPatientLedgerEntry entry in ledger.entries)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.receipt_outlined),
                  title: Text(_entryTitle(entry)),
                  subtitle: Text(_entrySubtitle(context, entry)),
                  trailing: Text(
                    accountsMoney(context, entry.amount, entry.currency),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  String _entryTitle(AccountsPatientLedgerEntry entry) {
    final String joined = <String?>[
      accountsPublicLabel(entry.displayId),
      accountsPublicLabel(entry.action),
    ].whereType<String>().join(' · ');
    return joined.isEmpty ? AccountsStrings.unknownValue : joined;
  }

  String _entrySubtitle(BuildContext context, AccountsPatientLedgerEntry entry) {
    return <String?>[
      accountsPublicLabel(entry.status),
      if (entry.timelineAt != null)
        accountsDateTime(context, entry.timelineAt),
    ].whereType<String>().where((String part) => part.isNotEmpty).join(' · ');
  }
}
