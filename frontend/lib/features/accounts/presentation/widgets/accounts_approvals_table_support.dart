import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_entities.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_access.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_strings.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_support.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

typedef AccountsApprovalsNextHandler =
    Future<void> Function(
      BuildContext context,
      WidgetRef ref,
      AccountsWorkItem item,
    );

const String accountsApprovalsJournalColumnId = 'journal';
const String accountsApprovalsAmountColumnId = 'amount';
const String accountsApprovalsStatusColumnId = 'status';
const String accountsApprovalsNextColumnId = 'next';
const String accountsApprovalsTypeColumnId = 'type';
const String accountsApprovalsByColumnId = 'by';
const String accountsApprovalsReasonColumnId = 'reason';
const String accountsApprovalsPeriodColumnId = 'period';

const String accountsApprovalsTableSettingsKey = 'accounts_approvals_v1';

const List<String> accountsApprovalsDefaultColumnIds = <String>[
  accountsApprovalsJournalColumnId,
  accountsApprovalsTypeColumnId,
  accountsApprovalsAmountColumnId,
  accountsApprovalsStatusColumnId,
  accountsApprovalsNextColumnId,
];

String accountsApprovalsStatusLabel(AccountsWorkItem item) {
  final String status = (item.status ?? '').trim().toUpperCase();
  return switch (status) {
    'PENDING' => AccountsStrings.statusPending,
    'APPROVED' => AccountsStrings.statusApproved,
    'REJECTED' || 'DENIED' => AccountsStrings.statusRejected,
    'DRAFT' => AccountsStrings.statusDraft,
    _ => (item.status ?? '').trim().isEmpty
        ? AccountsStrings.unknownValue
        : item.status!,
  };
}

String accountsApprovalsTypeLabel(String? type) {
  final String normalized = (type ?? '').trim().toUpperCase();
  return switch (normalized) {
    'JOURNAL_POST' || 'POST' => AccountsStrings.approvalTypeJournalPost,
    'VOID' => AccountsStrings.approvalTypeVoid,
    'REVERSAL' || 'REVERSE' => AccountsStrings.approvalTypeReversal,
    'PERIOD_CLOSE' || 'CLOSE' => AccountsStrings.approvalTypePeriodClose,
    _ => (type ?? '').trim().isEmpty ? AccountsStrings.unknownValue : type!,
  };
}

String? accountsApprovalsNextLabel(
  AccountsWorkItem item, {
  required bool canApprove,
}) {
  if (item.canApproveOrReject) {
    return canApprove ? AccountsStrings.approveAction : null;
  }
  return null;
}

bool accountsApprovalsMatchesSearch(AccountsWorkItem item, String query) {
  final String needle = query.trim().toLowerCase();
  if (needle.isEmpty) {
    return true;
  }
  final List<String?> haystacks = <String?>[
    item.effectiveDisplayId,
    item.journalDisplayId,
    item.accountDisplayId,
    item.status,
    item.approvalType,
    item.requestReason,
    item.requestedByDisplayId,
    item.periodLabel,
    item.source,
    item.reference,
  ];
  for (final String? value in haystacks) {
    if ((value ?? '').toLowerCase().contains(needle)) {
      return true;
    }
  }
  return false;
}

List<AppListTableColumn<AccountsWorkItem>> accountsApprovalsColumns({
  required BuildContext context,
  required WidgetRef ref,
  required AppAccessPolicy accessPolicy,
  required bool isSaving,
  required AccountsApprovalsNextHandler onNextAction,
}) {
  final Map<String, AppListTableColumn<AccountsWorkItem>> builders =
      _accountsApprovalsColumnBuilders(
        context,
        ref: ref,
        accessPolicy: accessPolicy,
        isSaving: isSaving,
        onNextAction: onNextAction,
      );
  final bool showNext = accountsSectionShowsNextActionColumn(
    accessPolicy,
    AccountsDeskSection.approvals,
  );
  return <AppListTableColumn<AccountsWorkItem>>[
    for (final String id in accountsApprovalsDefaultColumnIds)
      if (id != accountsApprovalsNextColumnId || showNext) builders[id]!,
  ];
}

List<AppListTableColumn<AccountsWorkItem>> accountsApprovalsColumnChoices({
  required BuildContext context,
  required WidgetRef ref,
  required AppAccessPolicy accessPolicy,
  required bool isSaving,
  required AccountsApprovalsNextHandler onNextAction,
}) {
  final Map<String, AppListTableColumn<AccountsWorkItem>> builders =
      _accountsApprovalsColumnBuilders(
        context,
        ref: ref,
        accessPolicy: accessPolicy,
        isSaving: isSaving,
        onNextAction: onNextAction,
      );
  return <AppListTableColumn<AccountsWorkItem>>[
    builders[accountsApprovalsByColumnId]!,
    builders[accountsApprovalsReasonColumnId]!,
    builders[accountsApprovalsPeriodColumnId]!,
  ];
}

Map<String, AppListTableColumn<AccountsWorkItem>> _accountsApprovalsColumnBuilders(
  BuildContext context, {
  required WidgetRef ref,
  required AppAccessPolicy accessPolicy,
  required bool isSaving,
  required AccountsApprovalsNextHandler onNextAction,
}) {
  final bool canApprove = canDecideAccountsApproval(accessPolicy);
  return <String, AppListTableColumn<AccountsWorkItem>>{
    accountsApprovalsJournalColumnId: AppListTableColumn<AccountsWorkItem>(
      id: accountsApprovalsJournalColumnId,
      label: AccountsStrings.journalColumn,
      alwaysVisible: true,
      cellBuilder: (_, AccountsWorkItem item) => Text(
        accountsWorkItemPublicId(item),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      exportValue: (AccountsWorkItem item) => accountsWorkItemPublicId(item),
    ),
    accountsApprovalsAmountColumnId: AppListTableColumn<AccountsWorkItem>(
      id: accountsApprovalsAmountColumnId,
      label: AccountsStrings.amountColumn,
      numeric: true,
      cellBuilder: (BuildContext context, AccountsWorkItem item) =>
          Text(accountsMoney(context, item.amount, item.currency)),
      exportValue: (AccountsWorkItem item) => item.amount.toString(),
    ),
    accountsApprovalsStatusColumnId: AppListTableColumn<AccountsWorkItem>(
      id: accountsApprovalsStatusColumnId,
      label: AccountsStrings.statusColumn,
      cellBuilder: (_, AccountsWorkItem item) {
        return AppWorkspaceStatusBadge(
          status: AppWorkspaceStatus(
            label: accountsApprovalsStatusLabel(item),
            tone: item.canApproveOrReject
                ? AppWorkspaceStatusTone.warning
                : AppWorkspaceStatusTone.neutral,
          ),
        );
      },
      exportValue: (AccountsWorkItem item) => accountsApprovalsStatusLabel(item),
    ),
    accountsApprovalsNextColumnId: AppListTableColumn<AccountsWorkItem>(
      id: accountsApprovalsNextColumnId,
      label: AccountsStrings.nextColumn,
      alwaysVisible: true,
      exportable: false,
      cellBuilder: (BuildContext context, AccountsWorkItem item) {
        return AccountsApprovalsNextButton(
          item: item,
          canApprove: canApprove,
          isSaving: isSaving,
          onPressed: () => onNextAction(context, ref, item),
        );
      },
    ),
    accountsApprovalsTypeColumnId: AppListTableColumn<AccountsWorkItem>(
      id: accountsApprovalsTypeColumnId,
      label: AccountsStrings.typeColumn,
      cellBuilder: (_, AccountsWorkItem item) =>
          Text(accountsApprovalsTypeLabel(item.approvalType)),
      exportValue: (AccountsWorkItem item) =>
          accountsApprovalsTypeLabel(item.approvalType),
    ),
    accountsApprovalsByColumnId: AppListTableColumn<AccountsWorkItem>(
      id: accountsApprovalsByColumnId,
      label: AccountsStrings.byColumn,
      cellBuilder: (_, AccountsWorkItem item) => Text(
        accountsPublicLabel(item.requestedByDisplayId) ??
            AccountsStrings.unknownValue,
      ),
      exportValue: (AccountsWorkItem item) =>
          accountsPublicLabel(item.requestedByDisplayId) ?? '',
    ),
    accountsApprovalsReasonColumnId: AppListTableColumn<AccountsWorkItem>(
      id: accountsApprovalsReasonColumnId,
      label: AccountsStrings.reasonColumn,
      cellBuilder: (_, AccountsWorkItem item) => Text(
        accountsPublicLabel(item.requestReason) ??
            AccountsStrings.unknownValue,
      ),
      exportValue: (AccountsWorkItem item) =>
          accountsPublicLabel(item.requestReason) ?? '',
    ),
    accountsApprovalsPeriodColumnId: AppListTableColumn<AccountsWorkItem>(
      id: accountsApprovalsPeriodColumnId,
      label: AccountsStrings.periodColumn,
      cellBuilder: (_, AccountsWorkItem item) => Text(
        accountsPublicLabel(item.periodLabel) ?? AccountsStrings.unknownValue,
      ),
      exportValue: (AccountsWorkItem item) =>
          accountsPublicLabel(item.periodLabel) ?? '',
    ),
  };
}

class AccountsApprovalsNextButton extends StatelessWidget {
  const AccountsApprovalsNextButton({
    required this.item,
    required this.canApprove,
    required this.isSaving,
    required this.onPressed,
    super.key,
  });

  final AccountsWorkItem item;
  final bool canApprove;
  final bool isSaving;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    final String? label = accountsApprovalsNextLabel(
      item,
      canApprove: canApprove,
    );
    if (label == null) {
      return const SizedBox.shrink();
    }
    final ThemeData theme = Theme.of(context);
    final bool enabled = canApprove && !isSaving;
    final Color color = enabled
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface.withValues(alpha: 0.38);

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Tooltip(
        message: AccountsStrings.approveActionTooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled
              ? () {
                  unawaited(onPressed());
                }
              : null,
          child: MouseRegion(
            cursor: enabled
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: theme.spacing.xs,
                vertical: 2,
              ),
              child: Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: color,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
