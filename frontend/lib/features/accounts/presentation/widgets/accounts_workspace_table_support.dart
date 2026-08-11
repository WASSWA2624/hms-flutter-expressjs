import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/utils/app_formatters.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_entities.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_access.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_strings.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_support.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

typedef AccountsNextActionHandler =
    Future<void> Function(
      BuildContext context,
      WidgetRef ref,
      AccountsWorkItem item,
    );

const String accountsJournalColumnId = 'journal';
const String accountsSourceColumnId = 'source';
const String accountsAmountColumnId = 'amount';
const String accountsStatusColumnId = 'status';
const String accountsNextActionColumnId = 'next_action';
const String accountsPeriodColumnId = 'period';
const String accountsAccountColumnId = 'account';
const String accountsPatientColumnId = 'patient';

const Map<AccountsDeskSection, List<String>> accountsDefaultColumnIds =
    <AccountsDeskSection, List<String>>{
      AccountsDeskSection.work: <String>[
        accountsJournalColumnId,
        accountsSourceColumnId,
        accountsAmountColumnId,
        accountsStatusColumnId,
        accountsNextActionColumnId,
      ],
      AccountsDeskSection.journals: <String>[
        accountsJournalColumnId,
        accountsPeriodColumnId,
        accountsAmountColumnId,
        accountsStatusColumnId,
        accountsNextActionColumnId,
      ],
      AccountsDeskSection.approvals: <String>[
        accountsJournalColumnId,
        accountsAmountColumnId,
        accountsStatusColumnId,
        accountsNextActionColumnId,
      ],
    };

/// Next priority: Approve → Post → Reverse → Void → Close → GL → Ledger.
String? accountsNextActionLabel(
  AccountsWorkItem item, {
  required bool canWrite,
  required bool canApprove,
  required bool canEnter,
}) {
  if (item.canApprove) {
    return canApprove ? AccountsStrings.approveAction : null;
  }
  if (item.canPost) {
    return canWrite ? AccountsStrings.postAction : null;
  }
  if (item.canReverse) {
    return canWrite ? AccountsStrings.reverseAction : null;
  }
  if (item.canVoid) {
    return canWrite ? AccountsStrings.voidAction : null;
  }
  if (item.canClose) {
    return canWrite ? AccountsStrings.closeAction : null;
  }
  if (item.canOpenGl) {
    return canEnter ? AccountsStrings.glAction : null;
  }
  if (item.canOpenLedger) {
    return canEnter ? AccountsStrings.ledgerAction : null;
  }
  return null;
}

String? accountsNextActionTooltip(
  AccountsWorkItem item, {
  required bool canWrite,
  required bool canApprove,
  required bool canEnter,
}) {
  if (item.canApprove) {
    return canApprove ? AccountsStrings.approveActionTooltip : null;
  }
  if (item.canPost) {
    return canWrite ? AccountsStrings.postActionTooltip : null;
  }
  if (item.canReverse) {
    return canWrite ? AccountsStrings.reverseActionTooltip : null;
  }
  if (item.canVoid) {
    return canWrite ? AccountsStrings.voidActionTooltip : null;
  }
  if (item.canClose) {
    return canWrite ? AccountsStrings.closeActionTooltip : null;
  }
  if (item.canOpenGl) {
    return canEnter ? AccountsStrings.glActionTooltip : null;
  }
  if (item.canOpenLedger) {
    return canEnter ? AccountsStrings.ledgerActionTooltip : null;
  }
  return null;
}

List<AppListTableColumn<AccountsWorkItem>> accountsColumnsForSection(
  BuildContext context,
  AccountsDeskSection section, {
  required WidgetRef ref,
  required AppAccessPolicy accessPolicy,
  required bool isSaving,
  required AccountsNextActionHandler onNextAction,
}) {
  final Map<String, AppListTableColumn<AccountsWorkItem>> columns =
      _accountsColumnBuilders(
        context,
        ref: ref,
        accessPolicy: accessPolicy,
        isSaving: isSaving,
        onNextAction: onNextAction,
      );
  final List<String> ids =
      accountsDefaultColumnIds[section] ??
      accountsDefaultColumnIds[AccountsDeskSection.work]!;
  final bool showNext = accountsSectionShowsNextActionColumn(
    accessPolicy,
    section,
  );
  return <AppListTableColumn<AccountsWorkItem>>[
    for (final String id in ids)
      if (id != accountsNextActionColumnId || showNext) columns[id]!,
  ];
}

List<AppListTableColumn<AccountsWorkItem>> accountsColumnChoicesForSection(
  BuildContext context,
  AccountsDeskSection section, {
  required WidgetRef ref,
  required AppAccessPolicy accessPolicy,
  required bool isSaving,
  required AccountsNextActionHandler onNextAction,
}) {
  final Map<String, AppListTableColumn<AccountsWorkItem>> columns =
      _accountsColumnBuilders(
        context,
        ref: ref,
        accessPolicy: accessPolicy,
        isSaving: isSaving,
        onNextAction: onNextAction,
      );
  final Set<String> defaults =
      (accountsDefaultColumnIds[section] ??
              accountsDefaultColumnIds[AccountsDeskSection.work]!)
          .toSet();
  return <AppListTableColumn<AccountsWorkItem>>[
    for (final MapEntry<String, AppListTableColumn<AccountsWorkItem>> entry
        in columns.entries)
      if (!defaults.contains(entry.key) &&
          entry.key != accountsNextActionColumnId)
        entry.value,
  ];
}

Map<String, AppListTableColumn<AccountsWorkItem>> _accountsColumnBuilders(
  BuildContext context, {
  required WidgetRef ref,
  required AppAccessPolicy accessPolicy,
  required bool isSaving,
  required AccountsNextActionHandler onNextAction,
}) {
  final bool canWrite = canWriteAccounts(accessPolicy);
  final bool canApprove = canApproveAccounts(accessPolicy);
  final bool canEnter = canEnterAccounts(accessPolicy);
  return <String, AppListTableColumn<AccountsWorkItem>>{
    accountsJournalColumnId: AppListTableColumn<AccountsWorkItem>(
      id: accountsJournalColumnId,
      label: AccountsStrings.journalColumn,
      alwaysVisible: true,
      sortComparator: (AccountsWorkItem a, AccountsWorkItem b) =>
          appListTableCompareText(a.effectiveDisplayId, b.effectiveDisplayId),
      cellBuilder: (BuildContext context, AccountsWorkItem item) {
        return Text(
          item.effectiveDisplayId,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    ),
    accountsSourceColumnId: AppListTableColumn<AccountsWorkItem>(
      id: accountsSourceColumnId,
      label: AccountsStrings.sourceColumn,
      sortComparator: (AccountsWorkItem a, AccountsWorkItem b) =>
          appListTableCompareText(a.source, b.source),
      cellBuilder: (BuildContext context, AccountsWorkItem item) {
        return Text(
          item.source.isEmpty ? AccountsStrings.unknownValue : item.source,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    ),
    accountsAmountColumnId: AppListTableColumn<AccountsWorkItem>(
      id: accountsAmountColumnId,
      label: AccountsStrings.amountColumn,
      numeric: true,
      sortComparator: (AccountsWorkItem a, AccountsWorkItem b) =>
          appListTableCompareNumber(a.amount, b.amount),
      cellBuilder: (BuildContext context, AccountsWorkItem item) {
        return Text(
          AppFormatters.currency(
            item.amount,
            Localizations.localeOf(context),
            currencyCode: item.currency ?? appDefaultCurrencyCode,
            decimalDigits: item.amount % 1 == 0 ? 0 : 2,
          ),
        );
      },
    ),
    accountsStatusColumnId: AppListTableColumn<AccountsWorkItem>(
      id: accountsStatusColumnId,
      label: AccountsStrings.statusColumn,
      sortComparator: (AccountsWorkItem a, AccountsWorkItem b) =>
          appListTableCompareText(a.status, b.status),
      cellBuilder: (BuildContext context, AccountsWorkItem item) {
        return Text(accountsStatusLabel(item.status));
      },
    ),
    accountsPeriodColumnId: AppListTableColumn<AccountsWorkItem>(
      id: accountsPeriodColumnId,
      label: AccountsStrings.periodColumn,
      sortComparator: (AccountsWorkItem a, AccountsWorkItem b) =>
          appListTableCompareText(a.periodLabel, b.periodLabel),
      cellBuilder: (BuildContext context, AccountsWorkItem item) {
        return Text(
          (item.periodLabel ?? '').trim().isEmpty
              ? AccountsStrings.unknownValue
              : item.periodLabel!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    ),
    accountsAccountColumnId: AppListTableColumn<AccountsWorkItem>(
      id: accountsAccountColumnId,
      label: AccountsStrings.accountColumn,
      sortComparator: (AccountsWorkItem a, AccountsWorkItem b) =>
          appListTableCompareText(a.accountLabel, b.accountLabel),
      cellBuilder: (BuildContext context, AccountsWorkItem item) {
        return Text(
          item.accountLabel.isEmpty
              ? AccountsStrings.unknownValue
              : item.accountLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    ),
    accountsPatientColumnId: AppListTableColumn<AccountsWorkItem>(
      id: accountsPatientColumnId,
      label: AccountsStrings.patientColumn,
      sortComparator: (AccountsWorkItem a, AccountsWorkItem b) =>
          appListTableCompareText(a.patientDisplayName, b.patientDisplayName),
      cellBuilder: (BuildContext context, AccountsWorkItem item) {
        return Text(
          (item.patientDisplayName ?? '').trim().isEmpty
              ? AccountsStrings.unknownValue
              : item.patientDisplayName!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    ),
    accountsNextActionColumnId: AppListTableColumn<AccountsWorkItem>(
      id: accountsNextActionColumnId,
      label: AccountsStrings.nextColumn,
      alwaysVisible: true,
      exportable: false,
      cellBuilder: (BuildContext context, AccountsWorkItem item) {
        final String? label = accountsNextActionLabel(
          item,
          canWrite: canWrite,
          canApprove: canApprove,
          canEnter: canEnter,
        );
        if (label == null) {
          return const SizedBox.shrink();
        }
        final String tooltip =
            accountsNextActionTooltip(
              item,
              canWrite: canWrite,
              canApprove: canApprove,
              canEnter: canEnter,
            ) ??
            label;
        return Tooltip(
          message: tooltip,
          child: TextButton(
            onPressed: () {
              unawaited(onNextAction(context, ref, item));
            },
            child: Text(label),
          ),
        );
      },
    ),
  };
}

class AccountsNextActionButton extends StatelessWidget {
  const AccountsNextActionButton({
    required this.item,
    required this.canWrite,
    required this.canApprove,
    required this.canEnter,
    required this.isSaving,
    required this.onPressed,
    super.key,
  });

  final AccountsWorkItem item;
  final bool canWrite;
  final bool canApprove;
  final bool canEnter;
  final bool isSaving;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    final String? label = accountsNextActionLabel(
      item,
      canWrite: canWrite,
      canApprove: canApprove,
      canEnter: canEnter,
    );
    if (label == null) {
      return const SizedBox.shrink();
    }
    final String? tooltip = accountsNextActionTooltip(
      item,
      canWrite: canWrite,
      canApprove: canApprove,
      canEnter: canEnter,
    );
    final ThemeData theme = Theme.of(context);
    final bool enabled = !isSaving;
    final Color primaryColor = enabled
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface.withValues(alpha: 0.38);

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Tooltip(
        message: tooltip ?? label,
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
                vertical: theme.spacing.xs,
              ),
              child: Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compatibility alias used by older work-queue call sites.
typedef AccountsWorkNextButton = AccountsNextActionButton;
typedef AccountsWorkNextHandler = AccountsNextActionHandler;

const String accountsWorkJournalColumnId = accountsJournalColumnId;
const String accountsWorkSourceColumnId = accountsSourceColumnId;
const String accountsWorkAmountColumnId = accountsAmountColumnId;
const String accountsWorkStatusColumnId = accountsStatusColumnId;
const String accountsWorkNextColumnId = accountsNextActionColumnId;
const String accountsWorkPeriodColumnId = accountsPeriodColumnId;

List<AppListTableColumn<AccountsWorkItem>> accountsWorkQueueColumns({
  required BuildContext context,
  required WidgetRef ref,
  required AccountsDeskSection section,
  required AppAccessPolicy accessPolicy,
  required bool canWrite,
  required bool canApprove,
  required bool isSaving,
  required AccountsWorkNextHandler onNextAction,
}) {
  return accountsColumnsForSection(
    context,
    section,
    ref: ref,
    accessPolicy: accessPolicy,
    isSaving: isSaving,
    onNextAction: onNextAction,
  );
}

List<AppListTableColumn<AccountsWorkItem>> accountsWorkQueueColumnChoices({
  required BuildContext context,
  required WidgetRef ref,
  required AppAccessPolicy accessPolicy,
  required bool canWrite,
  required bool canApprove,
  required bool isSaving,
  required AccountsWorkNextHandler onNextAction,
}) {
  return accountsColumnChoicesForSection(
    context,
    AccountsDeskSection.work,
    ref: ref,
    accessPolicy: accessPolicy,
    isSaving: isSaving,
    onNextAction: onNextAction,
  );
}
