import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_entities.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_access.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_strings.dart';
import 'package:hosspi_hms/features/accounts/presentation/controllers/accounts_workspace_controller.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_journal_dialog.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_support.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

Future<void> showAccountsGlDialog(
  BuildContext context,
  WidgetRef ref, {
  required AccountsGlAccount account,
}) async {
  await showAppDialog<void>(
    context: context,
    builder: (_) => _AccountsGlDialog(account: account),
  );
}

class _AccountsGlDialog extends ConsumerStatefulWidget {
  const _AccountsGlDialog({required this.account});

  final AccountsGlAccount account;

  @override
  ConsumerState<_AccountsGlDialog> createState() => _AccountsGlDialogState();
}

class _AccountsGlDialogState extends ConsumerState<_AccountsGlDialog> {
  late Future<Result<AccountsGlLedger>> _ledgerFuture;

  @override
  void initState() {
    super.initState();
    _ledgerFuture = _loadLedger();
  }

  Future<Result<AccountsGlLedger>> _loadLedger() {
    return ref
        .read(accountsWorkspaceControllerProvider.notifier)
        .fetchAccountLedger(widget.account.id);
  }

  @override
  Widget build(BuildContext context) {
    final bool canJournal = canCreateAccountsJournal(
      ref.watch(appAccessPolicyProvider),
    );

    return AppDialog(
      title: Text(AccountsStrings.accountLedgerTitle),
      icon: const Icon(Icons.account_balance_outlined),
      scrollable: true,
      maxWidth: 860,
      content: FutureBuilder<Result<AccountsGlLedger>>(
        future: _ledgerFuture,
        builder:
            (
              BuildContext context,
              AsyncSnapshot<Result<AccountsGlLedger>> snapshot,
            ) {
              if (!snapshot.hasData) {
                return const LinearProgressIndicator(minHeight: 2);
              }
              return snapshot.data!.when(
                success: (AccountsGlLedger ledger) {
                  return _AccountsGlLedgerBody(
                    ledger: ledger,
                    currency: widget.account.currency,
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
        if (canJournal)
          AppButton.primary(
            label: AccountsStrings.journalAction,
            onPressed: () => unawaited(_onJournalPressed()),
          ),
        AppButton.secondary(
          label: context.l10n.commonCloseActionLabel,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }

  Future<void> _onJournalPressed() async {
    final AccountsJournalDraft? draft = await showAccountsJournalDialog(
      context,
    );
    if (draft == null || !mounted) {
      return;
    }

    final AppFailure? failure = await ref
        .read(accountsWorkspaceControllerProvider.notifier)
        .createJournal(draft);
    if (!mounted) {
      return;
    }
    if (failure != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.failureMessage(failure))),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AccountsStrings.saved)),
    );
    Navigator.of(context).maybePop();
    if (!mounted) {
      return;
    }
    context.go(
      AppRoutes.accounts.location(
        queryParameters: const <String, String>{
          'section': 'journals',
        },
      ),
    );
  }
}

class _AccountsGlLedgerBody extends StatelessWidget {
  const _AccountsGlLedgerBody({required this.ledger, this.currency});

  final AccountsGlLedger ledger;
  final String? currency;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AccountsGlLedgerSummary summary = ledger.summary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          ledger.account.accountLabel,
          style: theme.textTheme.titleMedium,
        ),
        SizedBox(height: theme.spacing.md),
        AppReportSummaryGrid(
          records: <AppReportSummaryItem>[
            AppReportSummaryItem(
              label: AccountsStrings.debitColumn,
              value: accountsMoney(context, summary.debit, currency),
              icon: Icons.south_west,
            ),
            AppReportSummaryItem(
              label: AccountsStrings.creditColumn,
              value: accountsMoney(context, summary.credit, currency),
              icon: Icons.north_east,
            ),
            AppReportSummaryItem(
              label: AccountsStrings.balanceColumn,
              value: accountsMoney(context, summary.balance, currency),
              icon: Icons.account_balance_wallet_outlined,
            ),
          ],
        ),
        SizedBox(height: theme.spacing.md),
        if (ledger.entries.isEmpty)
          const Text(AccountsStrings.accountLedgerEmpty)
        else
          Column(
            children: <Widget>[
              for (final AccountsGlLedgerEntry entry in ledger.entries)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: Text(
                    <String>[
                      entry.journal,
                      entry.reference,
                    ].where((String part) => part.trim().isNotEmpty).join(' · '),
                  ),
                  subtitle: Text(
                    <String>[
                      entry.memo,
                      if (entry.postedAt != null)
                        accountsDateTime(context, entry.postedAt),
                    ].where((String part) => part.trim().isNotEmpty).join(' · '),
                  ),
                  trailing: Text(
                    accountsMoney(
                      context,
                      entry.debit != 0 ? entry.debit : entry.credit,
                      currency,
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
