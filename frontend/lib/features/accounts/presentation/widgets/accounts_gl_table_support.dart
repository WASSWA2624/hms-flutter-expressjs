import 'package:flutter/material.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_entities.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_strings.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_support.dart';
import 'package:hosspi_hms/shared/components/components.dart';

/// GL table settings + columns (`accounts_gl_v1`). Isolated from work-queue support.

const String accountsGlAccountColumnId = 'account';
const String accountsGlDebitColumnId = 'debit';
const String accountsGlCreditColumnId = 'credit';
const String accountsGlBalanceColumnId = 'balance';
const String accountsGlNextColumnId = 'next';
const String accountsGlTypeColumnId = 'type';
const String accountsGlPeriodColumnId = 'period';
const String accountsGlUpdatedColumnId = 'updated';

const String accountsGlTableSettingsKey = 'accounts_gl_v1';

const List<String> accountsGlDefaultColumnIds = <String>[
  accountsGlAccountColumnId,
  accountsGlDebitColumnId,
  accountsGlCreditColumnId,
  accountsGlBalanceColumnId,
  accountsGlNextColumnId,
];

List<AppListTableColumn<AccountsGlAccount>> accountsGlDefaultColumns({
  required BuildContext context,
  required bool Function(AccountsGlAccount account) showNext,
  required void Function(AccountsGlAccount account) onOpenGl,
}) {
  return <AppListTableColumn<AccountsGlAccount>>[
    AppListTableColumn<AccountsGlAccount>(
      id: accountsGlAccountColumnId,
      label: AccountsStrings.accountColumn,
      alwaysVisible: true,
      preferredWidth: 220,
      cellBuilder: (_, AccountsGlAccount item) => Text(
        item.accountLabel,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      exportValue: (AccountsGlAccount item) => item.accountLabel,
    ),
    AppListTableColumn<AccountsGlAccount>(
      id: accountsGlDebitColumnId,
      label: AccountsStrings.debitColumn,
      numeric: true,
      preferredWidth: 120,
      cellBuilder: (BuildContext context, AccountsGlAccount item) =>
          Text(accountsMoney(context, item.debit, item.currency)),
      exportValue: (AccountsGlAccount item) => item.debit.toString(),
    ),
    AppListTableColumn<AccountsGlAccount>(
      id: accountsGlCreditColumnId,
      label: AccountsStrings.creditColumn,
      numeric: true,
      preferredWidth: 120,
      cellBuilder: (BuildContext context, AccountsGlAccount item) =>
          Text(accountsMoney(context, item.credit, item.currency)),
      exportValue: (AccountsGlAccount item) => item.credit.toString(),
    ),
    AppListTableColumn<AccountsGlAccount>(
      id: accountsGlBalanceColumnId,
      label: AccountsStrings.balanceColumn,
      numeric: true,
      preferredWidth: 120,
      cellBuilder: (BuildContext context, AccountsGlAccount item) =>
          Text(accountsMoney(context, item.balance, item.currency)),
      exportValue: (AccountsGlAccount item) => item.balance.toString(),
    ),
    AppListTableColumn<AccountsGlAccount>(
      id: accountsGlNextColumnId,
      label: AccountsStrings.nextColumn,
      alwaysVisible: true,
      exportable: false,
      preferredWidth: 72,
      cellBuilder: (BuildContext context, AccountsGlAccount item) {
        if (!showNext(item)) {
          return const SizedBox.shrink();
        }
        return Semantics(
          button: true,
          label: AccountsStrings.nextGl,
          child: Tooltip(
            message: AccountsStrings.nextGlTooltip,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onOpenGl(item),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Text(
                  AccountsStrings.nextGl,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  ];
}

List<AppListTableColumn<AccountsGlAccount>> accountsGlOptionalColumns(
  BuildContext context,
) {
  return <AppListTableColumn<AccountsGlAccount>>[
    AppListTableColumn<AccountsGlAccount>(
      id: accountsGlTypeColumnId,
      label: AccountsStrings.typeColumn,
      preferredWidth: 120,
      cellBuilder: (_, AccountsGlAccount item) => Text(
        accountsPublicLabel(item.type) ?? AccountsStrings.unknownValue,
      ),
      exportValue: (AccountsGlAccount item) =>
          accountsPublicLabel(item.type) ?? '',
    ),
    AppListTableColumn<AccountsGlAccount>(
      id: accountsGlPeriodColumnId,
      label: AccountsStrings.periodColumn,
      preferredWidth: 120,
      cellBuilder: (_, AccountsGlAccount item) => Text(
        accountsPublicLabel(item.period) ?? AccountsStrings.unknownValue,
      ),
      exportValue: (AccountsGlAccount item) =>
          accountsPublicLabel(item.period) ?? '',
    ),
    AppListTableColumn<AccountsGlAccount>(
      id: accountsGlUpdatedColumnId,
      label: AccountsStrings.updatedColumn,
      preferredWidth: 160,
      cellBuilder: (BuildContext context, AccountsGlAccount item) =>
          Text(accountsDateTime(context, item.updatedAt)),
      exportValue: (AccountsGlAccount item) =>
          item.updatedAt?.toIso8601String() ?? '',
    ),
  ];
}
