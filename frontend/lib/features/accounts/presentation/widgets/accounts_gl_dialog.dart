import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hosspi_hms/app/router/app_routes.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/errors/result.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/features/accounts/data/repositories/accounts_repository_impl.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_entities.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_access.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_strings.dart';
import 'package:hosspi_hms/features/accounts/presentation/controllers/accounts_workspace_controller.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_gl_print_helpers.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_journal_dialog.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_journal_similarity.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_journal_similarity_dialog.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_support.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';

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
        AppButton.secondary(
          label: AccountsStrings.printAction,
          onPressed: () => unawaited(_onPrintPressed()),
        ),
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

  Future<void> _onPrintPressed() async {
    final Result<AccountsGlLedger> result = await _ledgerFuture;
    if (!mounted) {
      return;
    }
    await result.when(
      success: (AccountsGlLedger ledger) {
        return printAccountsGlLedgerPacket(
          ref: ref,
          context: context,
          ledger: ledger,
          currency: widget.account.currency,
        );
      },
      failure: (AppFailure failure) async {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.failureMessage(failure))),
        );
      },
    );
  }

  Future<void> _onJournalPressed() async {
    final AccountsJournalDraft? draft = await showAccountsJournalDialog(
      context,
    );
    if (draft == null || !mounted) {
      return;
    }

    final List<AccountsWorkItem> candidates = await _loadJournalCandidates();
    if (!mounted) {
      return;
    }
    final AccountsJournalSimilarityResult check = checkAccountsJournalSimilarity(
      draft: draft,
      candidates: candidates,
    );
    if (check.hasMatches) {
      final AccountsJournalSimilarityDialogResult review =
          await showAccountsJournalSimilarityDialog(
            context,
            draft: draft,
            check: check,
          );
      if (!mounted) {
        return;
      }
      switch (review.action) {
        case AccountsJournalSimilarityAction.cancel:
          return;
        case AccountsJournalSimilarityAction.useExisting:
          final AccountsWorkItem? existing = review.selectedItem;
          if (existing == null) {
            return;
          }
          ref
              .read(accountsWorkspaceControllerProvider.notifier)
              .selectItem(existing);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${AccountsStrings.journalColumn} '
                '${accountsWorkItemPublicId(existing)}',
              ),
            ),
          );
          return;
        case AccountsJournalSimilarityAction.proceed:
          break;
      }
    }

    final AppFailure? failure = await ref
        .read(accountsWorkspaceControllerProvider.notifier)
        .createJournal(draft);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failure == null
              ? AccountsStrings.saved
              : context.l10n.failureMessage(failure),
        ),
      ),
    );
    if (failure != null) {
      return;
    }

    await Navigator.of(context).maybePop();
    if (!mounted) {
      return;
    }
    context.go(
      AppRoutes.accounts.location(
        queryParameters: const <String, String>{'section': 'journals'},
      ),
    );
  }

  Future<List<AccountsWorkItem>> _loadJournalCandidates() async {
    final AccountsWorkspaceState? workspace = ref
        .read(accountsWorkspaceControllerProvider)
        .asData
        ?.value
        .when(
          success: (AccountsWorkspaceState value) => value,
          failure: (_) => null,
        );
    final List<AccountsWorkItem> cached = <AccountsWorkItem>[
      ...?workspace?.workItems.items,
    ];
    if (cached.any((AccountsWorkItem item) => item.canPost)) {
      return cached;
    }

    final Result<AppPage<AccountsWorkItem>> result = await ref
        .read(accountsRepositoryProvider)
        .listWorkItems(
          const AccountsWorkspaceQuery(section: AccountsDeskSection.journals),
        );
    return result.when(
      success: (AppPage<AccountsWorkItem> page) => page.items,
      failure: (_) => cached,
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
          accountsGlAccountPublicLabel(ledger.account),
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
                  title: Text(_entryTitle(entry)),
                  subtitle: Text(_entrySubtitle(context, entry)),
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

  String _entryTitle(AccountsGlLedgerEntry entry) {
    final String joined = <String?>[
      accountsPublicLabel(entry.journal),
      accountsPublicLabel(entry.reference),
    ].whereType<String>().join(' · ');
    return joined.isEmpty ? AccountsStrings.unknownValue : joined;
  }

  String _entrySubtitle(BuildContext context, AccountsGlLedgerEntry entry) {
    return <String?>[
      accountsPublicLabel(entry.memo),
      if (entry.postedAt != null) accountsDateTime(context, entry.postedAt),
    ].whereType<String>().where((String part) => part.isNotEmpty).join(' · ');
  }
}
