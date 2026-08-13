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
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_detail_fact_lines.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_patient_ledger_print_helpers.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_support.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

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
    final l10n = context.l10n;

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

    return FutureBuilder<Result<AccountsPatientLedger>>(
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

            final Widget printAction = AppButton.secondary(
              leadingIcon: Icons.print_outlined,
              label: AccountsStrings.printAction,
              onPressed: () => unawaited(_onPrintPressed()),
            );
            final Widget closeAction = AppButton.close(
              label: l10n.commonCloseActionLabel,
              onPressed: () => Navigator.of(context).maybePop(),
            );
            final List<Widget> leadingActions = <Widget>[
              printAction,
              if (showPay)
                AppButton.primary(
                  leadingIcon: Icons.payments_outlined,
                  label: AccountsStrings.payAction,
                  tooltip: AccountsStrings.payActionTooltip,
                  onPressed: () => unawaited(_pay(ledger)),
                ),
            ];
            // AppDialog reverses exactly-two-action footers authored as
            // [Close, action] so Close stays extreme-right.
            final List<Widget> actions = leadingActions.length == 1
                ? <Widget>[closeAction, leadingActions.first]
                : <Widget>[...leadingActions, closeAction];

            return AppDialog(
              title: const Text(AccountsStrings.patientLedgerTitle),
              icon: const Icon(Icons.menu_book_outlined),
              scrollable: true,
              pinActionsToBottom: true,
              maxWidth: 860,
              content: !snapshot.hasData
                  ? const LinearProgressIndicator(minHeight: 2)
                  : snapshot.data!.when(
                      success: (AccountsPatientLedger value) {
                        return _AccountsPatientLedgerBody(
                          ledger: value,
                          currency: widget.currency,
                          fallbackPatientLabel: titleHasPatient
                              ? titleName
                              : null,
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
                    ),
              actions: actions,
            );
          },
    );
  }
}

class _AccountsPatientLedgerBody extends StatelessWidget {
  const _AccountsPatientLedgerBody({
    required this.ledger,
    this.currency,
    this.fallbackPatientLabel,
  });

  final AccountsPatientLedger ledger;
  final String? currency;
  final String? fallbackPatientLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final AccountsPatientLedgerSummary summary = ledger.summary;
    final String patientLabel =
        accountsPatientPublicLabel(
          patientDisplayName:
              ledger.patientDisplayName ?? fallbackPatientLabel,
          patientDisplayId: ledger.patientDisplayId,
          patientId: ledger.patientId,
        );
    final String? patientIdLabel =
        accountsPublicLabel(ledger.patientDisplayId) ??
        accountsPublicLabel(ledger.patientId);
    final bool balanceOutstanding = summary.balanceDue > 0;
    final bool showSeparatePatientId =
        patientIdLabel != null && patientIdLabel != patientLabel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppCollapsibleSection(
          title: AccountsStrings.invoiceSummarySectionTitle,
          titleIcon: Icons.receipt_long_outlined,
          child: AccountsDetailFactLines(
            fields: <AppWorkspacePatientContextField>[
              AppWorkspacePatientContextField(
                label: AccountsStrings.patientColumn,
                value: patientLabel,
                icon: Icons.person_outline,
              ),
              if (showSeparatePatientId)
                AppWorkspacePatientContextField(
                  label: AccountsStrings.patientIdColumn,
                  value: patientIdLabel,
                  icon: Icons.badge_outlined,
                  copyable: true,
                ),
              AppWorkspacePatientContextField(
                label: AccountsStrings.invoicedColumn,
                value: accountsMoney(
                  context,
                  summary.totalInvoiced,
                  currency,
                ),
                icon: Icons.receipt_long_outlined,
              ),
              AppWorkspacePatientContextField(
                label: AccountsStrings.paidColumn,
                value: accountsMoney(context, summary.netPaid, currency),
                icon: Icons.payments_outlined,
              ),
              AppWorkspacePatientContextField(
                label: AccountsStrings.balanceColumn,
                value: accountsMoney(context, summary.balanceDue, currency),
                icon: Icons.account_balance_wallet_outlined,
              ),
              AppWorkspacePatientContextField(
                label: AccountsStrings.clearanceColumn,
                value: balanceOutstanding
                    ? AccountsStrings.clearanceOutstanding
                    : AccountsStrings.clearanceCleared,
                icon: balanceOutstanding
                    ? Icons.warning_amber_outlined
                    : Icons.check_circle_outline,
              ),
            ],
          ),
        ),
        SizedBox(height: theme.spacing.md),
        if (ledger.entries.isEmpty)
          AppContentPanel(
            density: AppContentPanelDensity.compact,
            borderRadius: BorderRadius.zero,
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.inbox_outlined,
                  color: colorScheme.onSurfaceVariant,
                ),
                SizedBox(width: theme.spacing.sm),
                Expanded(
                  child: Text(
                    AccountsStrings.patientLedgerEmpty,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          AppContentPanel(
            density: AppContentPanelDensity.compact,
            borderRadius: BorderRadius.zero,
            child: Column(
              children: <Widget>[
                for (int index = 0; index < ledger.entries.length; index += 1)
                  ...<Widget>[
                    if (index > 0)
                      Divider(
                        height: 1,
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    _AccountsPatientLedgerEntryTile(
                      entry: ledger.entries[index],
                      fallbackCurrency: currency,
                    ),
                  ],
              ],
            ),
          ),
      ],
    );
  }
}

class _AccountsPatientLedgerEntryTile extends StatelessWidget {
  const _AccountsPatientLedgerEntryTile({
    required this.entry,
    this.fallbackCurrency,
  });

  final AccountsPatientLedgerEntry entry;
  final String? fallbackCurrency;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String title = _entryTitle(entry);
    final String subtitle = _entrySubtitle(context, entry);
    final String amount = accountsMoney(
      context,
      entry.amount,
      entry.currency ?? fallbackCurrency,
    );

    return Padding(
      padding: EdgeInsets.symmetric(vertical: theme.spacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            _ledgerIcon(entry.kind),
            size: theme.appTokens.listIconSize,
            color: colorScheme.primary,
          ),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: AppFontWeight.emphasis,
                  ),
                ),
                if (subtitle.isNotEmpty) ...<Widget>[
                  SizedBox(height: theme.spacing.xs / 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: theme.spacing.sm),
          Text(
            amount,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: AppFontWeight.emphasis,
            ),
          ),
        ],
      ),
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

  IconData _ledgerIcon(String kind) {
    final String normalized = kind.trim().toLowerCase();
    if (normalized.contains('invoice')) {
      return Icons.receipt_long_outlined;
    }
    if (normalized.contains('payment') || normalized.contains('pay')) {
      return Icons.payments_outlined;
    }
    if (normalized.contains('refund')) {
      return Icons.assignment_return_outlined;
    }
    if (normalized.contains('claim')) {
      return Icons.health_and_safety_outlined;
    }
    if (normalized.contains('adjust')) {
      return Icons.tune_outlined;
    }
    if (normalized.contains('approval')) {
      return Icons.rule_outlined;
    }
    return Icons.receipt_outlined;
  }
}
