import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_entities.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_access.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_strings.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_support.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

const String accountsLedgersTableSettingsKey = 'accounts_ledgers_v1';
const String accountsLedgersPatientColumnId = 'patient';
const String accountsLedgersInvoicedColumnId = 'invoiced';
const String accountsLedgersPaidColumnId = 'paid';
const String accountsLedgersBalanceColumnId = 'balance';
const String accountsLedgersNextColumnId = 'next';
const String accountsLedgersClearanceColumnId = 'clearance';
const String accountsLedgersUpdatedColumnId = 'updated';

const List<String> accountsLedgersDefaultColumnIds = <String>[
  accountsLedgersPatientColumnId,
  accountsLedgersInvoicedColumnId,
  accountsLedgersPaidColumnId,
  accountsLedgersBalanceColumnId,
  accountsLedgersNextColumnId,
];

String accountsClearanceLabel(AccountsClearanceState state) {
  return switch (state) {
    AccountsClearanceState.cleared => AccountsStrings.clearanceCleared,
    AccountsClearanceState.partial => AccountsStrings.clearancePartial,
    AccountsClearanceState.outstanding => AccountsStrings.clearanceOutstanding,
  };
}

AppWorkspaceStatusTone accountsClearanceTone(AccountsClearanceState state) {
  return switch (state) {
    AccountsClearanceState.cleared => AppWorkspaceStatusTone.success,
    AccountsClearanceState.partial => AppWorkspaceStatusTone.info,
    AccountsClearanceState.outstanding => AppWorkspaceStatusTone.warning,
  };
}

String? accountsPatientLedgerNextActionLabel({
  required AppAccessPolicy policy,
  required AccountsPatientBalance row,
}) {
  if (row.hasBalance && canPayFromAccounts(policy)) {
    return AccountsStrings.payAction;
  }
  if (canReadAccountsPatientLedgers(policy)) {
    return AccountsStrings.ledgerAction;
  }
  return null;
}

bool accountsLedgersShowsNextActionColumn(AppAccessPolicy policy) {
  return canPayFromAccounts(policy) || canReadAccountsPatientLedgers(policy);
}

Map<String, AppListTableColumn<AccountsPatientBalance>>
_accountsLedgersColumnBuilders({
  required BuildContext context,
  required AppAccessPolicy policy,
  required void Function(AccountsPatientBalance row) onOpenLedger,
  required void Function(AccountsPatientBalance row) onPay,
}) {
  return <String, AppListTableColumn<AccountsPatientBalance>>{
    accountsLedgersPatientColumnId: AppListTableColumn<AccountsPatientBalance>(
      id: accountsLedgersPatientColumnId,
      label: AccountsStrings.patientColumn,
      alwaysVisible: true,
      cellBuilder: (_, AccountsPatientBalance row) => Text(row.displayLabel),
      exportValue: (AccountsPatientBalance row) => row.displayLabel,
    ),
    accountsLedgersInvoicedColumnId: AppListTableColumn<AccountsPatientBalance>(
      id: accountsLedgersInvoicedColumnId,
      label: AccountsStrings.invoicedColumn,
      numeric: true,
      cellBuilder: (BuildContext context, AccountsPatientBalance row) =>
          Text(accountsMoney(context, row.invoiced, row.currency)),
      exportValue: (AccountsPatientBalance row) => row.invoiced.toString(),
    ),
    accountsLedgersPaidColumnId: AppListTableColumn<AccountsPatientBalance>(
      id: accountsLedgersPaidColumnId,
      label: AccountsStrings.paidColumn,
      numeric: true,
      cellBuilder: (BuildContext context, AccountsPatientBalance row) =>
          Text(accountsMoney(context, row.paid, row.currency)),
      exportValue: (AccountsPatientBalance row) => row.paid.toString(),
    ),
    accountsLedgersBalanceColumnId: AppListTableColumn<AccountsPatientBalance>(
      id: accountsLedgersBalanceColumnId,
      label: AccountsStrings.balanceColumn,
      numeric: true,
      cellBuilder: (BuildContext context, AccountsPatientBalance row) =>
          Text(accountsMoney(context, row.balance, row.currency)),
      exportValue: (AccountsPatientBalance row) => row.balance.toString(),
    ),
    accountsLedgersNextColumnId: AppListTableColumn<AccountsPatientBalance>(
      id: accountsLedgersNextColumnId,
      label: AccountsStrings.nextColumn,
      alwaysVisible: true,
      exportable: false,
      cellBuilder: (_, AccountsPatientBalance row) {
        final String? label = accountsPatientLedgerNextActionLabel(
          policy: policy,
          row: row,
        );
        if (label == null) {
          return const SizedBox.shrink();
        }
        return AppButton.secondary(
          label: label,
          tooltip: label == AccountsStrings.payAction
              ? AccountsStrings.payActionTooltip
              : AccountsStrings.ledgerActionTooltip,
          dense: true,
          onPressed: () {
            if (label == AccountsStrings.payAction) {
              onPay(row);
            } else {
              onOpenLedger(row);
            }
          },
        );
      },
    ),
    accountsLedgersClearanceColumnId:
        AppListTableColumn<AccountsPatientBalance>(
          id: accountsLedgersClearanceColumnId,
          label: AccountsStrings.clearanceColumn,
          cellBuilder: (_, AccountsPatientBalance row) {
            return AppWorkspaceStatusBadge(
              status: AppWorkspaceStatus(
                label: accountsClearanceLabel(row.clearance),
                tone: accountsClearanceTone(row.clearance),
              ),
            );
          },
          exportValue: (AccountsPatientBalance row) =>
              accountsClearanceLabel(row.clearance),
        ),
    accountsLedgersUpdatedColumnId: AppListTableColumn<AccountsPatientBalance>(
      id: accountsLedgersUpdatedColumnId,
      label: AccountsStrings.updatedColumn,
      cellBuilder: (BuildContext context, AccountsPatientBalance row) =>
          Text(accountsDateTime(context, row.updatedAt)),
      exportValue: (AccountsPatientBalance row) =>
          row.updatedAt?.toIso8601String(),
    ),
  };
}

List<AppListTableColumn<AccountsPatientBalance>> accountsLedgersColumns({
  required BuildContext context,
  required AppAccessPolicy policy,
  required void Function(AccountsPatientBalance row) onOpenLedger,
  required void Function(AccountsPatientBalance row) onPay,
}) {
  final Map<String, AppListTableColumn<AccountsPatientBalance>> columns =
      _accountsLedgersColumnBuilders(
        context: context,
        policy: policy,
        onOpenLedger: onOpenLedger,
        onPay: onPay,
      );
  final bool showNext = accountsLedgersShowsNextActionColumn(policy);
  return <AppListTableColumn<AccountsPatientBalance>>[
    for (final String id in accountsLedgersDefaultColumnIds)
      if (id != accountsLedgersNextColumnId || showNext) columns[id]!,
  ];
}

List<AppListTableColumn<AccountsPatientBalance>> accountsLedgersColumnChoices({
  required BuildContext context,
  required AppAccessPolicy policy,
  required void Function(AccountsPatientBalance row) onOpenLedger,
  required void Function(AccountsPatientBalance row) onPay,
}) {
  final Map<String, AppListTableColumn<AccountsPatientBalance>> columns =
      _accountsLedgersColumnBuilders(
        context: context,
        policy: policy,
        onOpenLedger: onOpenLedger,
        onPay: onPay,
      );
  return <AppListTableColumn<AccountsPatientBalance>>[
    columns[accountsLedgersClearanceColumnId]!,
    columns[accountsLedgersUpdatedColumnId]!,
  ];
}
