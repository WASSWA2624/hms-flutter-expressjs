import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/core/permissions/permission_providers.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_entities.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_access.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_strings.dart';
import 'package:hosspi_hms/features/accounts/presentation/controllers/accounts_workspace_controller.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_approval_print_helpers.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_form_dialogs.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_gl_dialog.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_journal_dialog.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_journal_print_helpers.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_journal_similarity.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_journal_similarity_dialog.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_patient_ledger_dialog.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_period_dialogs.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_detail_widgets.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_support.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_workspace_table_support.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

/// Dispatches Open work / To post Next by priority label (accounts.md §4.1).
Future<void> runAccountsNextAction(
  BuildContext context,
  WidgetRef ref,
  AccountsWorkItem item,
) async {
  final accessPolicy = ref.read(appAccessPolicyProvider);
  final String? label = accountsNextActionLabel(
    item,
    canWrite: canWriteAccounts(accessPolicy),
    canApprove: canApproveAccounts(accessPolicy),
    canEnter: canEnterAccounts(accessPolicy),
  );
  if (label == null) {
    return;
  }

  ref.read(accountsWorkspaceControllerProvider.notifier).selectItem(item);
  if (!context.mounted) {
    return;
  }

  switch (label) {
    case AccountsStrings.approveAction:
      await showAccountsApproveDialog(context, ref);
    case AccountsStrings.postAction:
      await showAccountsPostDialog(context, ref);
    case AccountsStrings.reverseAction:
      await showAccountsReverseDialog(context, ref);
    case AccountsStrings.voidAction:
      await showAccountsVoidDialog(context, ref);
    case AccountsStrings.closeAction:
      await showAccountsCloseFromWorkItem(context, ref, item);
    case AccountsStrings.glAction:
      await showAccountsGlFromWorkItem(context, ref, item);
    case AccountsStrings.ledgerAction:
      await showAccountsPatientLedgerDialog(
        context,
        ref,
        patientId: item.patientId ?? '',
        patientDisplayName: accountsPublicLabel(item.patientDisplayName),
        currency: item.currency,
      );
    default:
      return;
  }
}

Future<void> showAccountsPostDialog(BuildContext context, WidgetRef ref) async {
  final AccountsOptionalNotesResult? result =
      await showAppDialog<AccountsOptionalNotesResult>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AccountsNotesForm(
          dialogTitle: const Text(AccountsStrings.postDialogTitle),
          dialogIcon: const Icon(Icons.publish_outlined),
          submitLabel: AccountsStrings.postAction,
        ),
      );
  if (result == null || !context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(accountsWorkspaceControllerProvider.notifier)
      .postSelectedJournal(notes: result.notes);
  if (!context.mounted) {
    return;
  }
  showAccountsMutationSnackBar(
    context,
    ref,
    failure,
    successMessage: AccountsStrings.posted,
  );
}

Future<void> showAccountsApproveDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  if (!canDecideAccountsApproval(ref.read(appAccessPolicyProvider))) {
    return;
  }
  final AccountsOptionalNotesResult? result =
      await showAppDialog<AccountsOptionalNotesResult>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AccountsNotesForm(
          dialogTitle: const Text(AccountsStrings.approveAction),
          dialogIcon: const Icon(Icons.check_circle_outline),
          submitLabel: AccountsStrings.approveAction,
        ),
      );
  if (result == null || !context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(accountsWorkspaceControllerProvider.notifier)
      .approveSelectedApproval(
        AccountsApprovalDecisionDraft(notes: result.notes),
      );
  if (!context.mounted) {
    return;
  }
  showAccountsMutationSnackBar(
    context,
    ref,
    failure,
    successMessage: AccountsStrings.saved,
  );
}

Future<void> showAccountsRejectDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  if (!canDecideAccountsApproval(ref.read(appAccessPolicyProvider))) {
    return;
  }
  final AccountsReasonDraft? draft = await showAppDialog<AccountsReasonDraft>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AccountsReasonForm(
      dialogTitle: const Text(AccountsStrings.rejectAction),
      dialogIcon: const Icon(Icons.cancel_outlined),
      submitLabel: AccountsStrings.rejectAction,
    ),
  );
  if (draft == null || !context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(accountsWorkspaceControllerProvider.notifier)
      .rejectSelectedApproval(
        AccountsApprovalDecisionDraft(
          reason: draft.reason,
          notes: draft.notes,
        ),
      );
  if (!context.mounted) {
    return;
  }
  showAccountsMutationSnackBar(
    context,
    ref,
    failure,
    successMessage: AccountsStrings.saved,
  );
}

Future<void> showAccountsReverseDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  if (!canWriteAccounts(ref.read(appAccessPolicyProvider))) {
    return;
  }
  final AccountsReasonDraft? draft = await showAppDialog<AccountsReasonDraft>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AccountsReasonForm(
      dialogTitle: const Text(AccountsStrings.reverseAction),
      dialogIcon: const Icon(Icons.undo_outlined),
      submitLabel: AccountsStrings.reverseAction,
    ),
  );
  if (draft == null || !context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(accountsWorkspaceControllerProvider.notifier)
      .reverseSelectedJournal(reason: draft.reason, notes: draft.notes);
  if (!context.mounted) {
    return;
  }
  showAccountsMutationSnackBar(context, ref, failure);
}

Future<void> showAccountsVoidDialog(BuildContext context, WidgetRef ref) async {
  if (!canWriteAccounts(ref.read(appAccessPolicyProvider))) {
    return;
  }
  final AccountsReasonDraft? draft = await showAppDialog<AccountsReasonDraft>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AccountsReasonForm(
      dialogTitle: const Text(AccountsStrings.voidAction),
      dialogIcon: const Icon(Icons.block_outlined),
      submitLabel: AccountsStrings.voidAction,
    ),
  );
  if (draft == null || !context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(accountsWorkspaceControllerProvider.notifier)
      .voidSelectedJournal(reason: draft.reason, notes: draft.notes);
  if (!context.mounted) {
    return;
  }
  showAccountsMutationSnackBar(context, ref, failure);
}

Future<void> showAccountsCloseFromWorkItem(
  BuildContext context,
  WidgetRef ref,
  AccountsWorkItem item,
) async {
  if (!canWriteAccounts(ref.read(appAccessPolicyProvider))) {
    return;
  }
  final AccountsNotesDraft? draft = await showAccountsClosePeriodDialog(
    context,
    period: null,
  );
  if (draft == null || !context.mounted) {
    return;
  }
  final AppFailure? failure = await ref
      .read(accountsWorkspaceControllerProvider.notifier)
      .closeSelectedPeriod(notes: draft.notes);
  if (!context.mounted) {
    return;
  }
  showAccountsMutationSnackBar(context, ref, failure);
}

Future<void> showAccountsGlFromWorkItem(
  BuildContext context,
  WidgetRef ref,
  AccountsWorkItem item,
) async {
  final String accountId = (item.accountId ?? '').trim();
  if (accountId.isEmpty) {
    return;
  }
  final String label =
      accountsPublicLabel(item.accountDisplayId) ??
      AccountsStrings.accountColumn;
  await showAccountsGlDialog(
    context,
    ref,
    account: AccountsGlAccount(
      id: accountId,
      name: label,
      displayId: accountsPublicLabel(item.accountDisplayId),
      code: accountsPublicLabel(item.accountDisplayId) ?? '',
      currency: item.currency ?? 'UGX',
      hasActivity: true,
    ),
  );
}

void showAccountsMutationSnackBar(
  BuildContext context,
  WidgetRef ref,
  AppFailure? failure, {
  String? successMessage,
}) {
  if (!context.mounted) {
    return;
  }
  final bool pendingApproval =
      ref
          .read(accountsWorkspaceControllerProvider)
          .asData
          ?.value
          .when(
            success: (AccountsWorkspaceState state) =>
                state.lastActionPendingApproval,
            failure: (_) => false,
          ) ??
      false;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        failure == null
            ? (successMessage ??
                  (pendingApproval
                      ? AccountsStrings.submittedForApproval
                      : AccountsStrings.saved))
            : context.l10n.failureMessage(failure),
      ),
    ),
  );
}

Future<void> printAccountsWorkItem(
  BuildContext context,
  WidgetRef ref,
  AccountsWorkItem item,
) {
  if (item.isApproval) {
    return printAccountsApprovalPacket(
      ref: ref,
      context: context,
      item: item,
    );
  }
  return printAccountsJournalPacket(ref: ref, context: context, item: item);
}

/// Edit draft lines before post — similarity excludes self (accounts.md §18).
Future<void> editAccountsJournalDraft(
  BuildContext context,
  WidgetRef ref,
  AccountsWorkItem item,
) async {
  if (!item.canPost) {
    return;
  }
  final AccountsJournalDraft? draft = await showAccountsJournalDialog(
    context,
    initial: accountsJournalDraftFromWorkItem(item),
  );
  if (draft == null || !context.mounted) {
    return;
  }

  final AccountsWorkspaceState? workspace = ref
      .read(accountsWorkspaceControllerProvider)
      .asData
      ?.value
      .when(
        success: (AccountsWorkspaceState value) => value,
        failure: (_) => null,
      );
  final List<AccountsWorkItem> candidates = <AccountsWorkItem>[
    ...?workspace?.workItems.items,
  ];
  final AccountsJournalSimilarityResult check = checkAccountsJournalSimilarity(
    draft: draft,
    candidates: candidates,
    excludeJournalId: item.id,
  );
  if (check.hasMatches && context.mounted) {
    final AccountsJournalSimilarityDialogResult review =
        await showAccountsJournalSimilarityDialog(
          context,
          draft: draft,
          check: check,
        );
    if (!context.mounted) {
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
        await showAccountsWorkItemDetailDialog(
          context,
          ref,
          existing,
          canWrite: canWriteAccounts(ref.read(appAccessPolicyProvider)),
          canApprove: canApproveAccounts(ref.read(appAccessPolicyProvider)),
        );
        return;
      case AccountsJournalSimilarityAction.proceed:
        break;
    }
  }

  final AppFailure? failure = await ref
      .read(accountsWorkspaceControllerProvider.notifier)
      .updateJournal(item.id, draft);
  if (!context.mounted) {
    return;
  }
  showAccountsMutationSnackBar(
    context,
    ref,
    failure,
    successMessage: AccountsStrings.saved,
  );
}

Future<void> showAccountsWorkItemDetailDialog(
  BuildContext hostContext,
  WidgetRef hostRef,
  AccountsWorkItem item, {
  required bool canWrite,
  required bool canApprove,
}) {
  return showAppDialog<void>(
    context: hostContext,
    builder: (BuildContext dialogContext) {
      return Consumer(
        builder: (BuildContext context, WidgetRef ref, _) {
          final accessPolicy = ref.watch(appAccessPolicyProvider);
          final AccountsWorkspaceState? workspace = ref
              .watch(accountsWorkspaceControllerProvider)
              .asData
              ?.value
              .when(
                success: (AccountsWorkspaceState value) => value,
                failure: (_) => null,
              );
          final AccountsWorkItem live = workspace?.selectedItem?.id == item.id
              ? workspace!.selectedItem!
              : item;
          final bool isSaving = workspace?.isSaving ?? false;
          return AppDialog(
            title: Text(accountsDetailTitle(context, live)),
            icon: const Icon(Icons.receipt_long_outlined),
            scrollable: true,
            maxWidth: 860,
            content: AccountsDetailBody(
              item: live,
              canWrite: canWrite,
              canApprove: canApprove,
              isSaving: isSaving,
              onPost: canWrite && live.canPost
                  ? () => unawaited(
                      showAccountsPostDialog(hostContext, ref),
                    )
                  : null,
              onApprove: canApprove && live.canApproveOrReject
                  ? () => unawaited(showAccountsApproveDialog(hostContext, ref))
                  : null,
              onReject: canApprove && live.canApproveOrReject
                  ? () => unawaited(showAccountsRejectDialog(hostContext, ref))
                  : null,
              onEdit: canWrite && live.canPost
                  ? () => unawaited(
                      editAccountsJournalDraft(hostContext, ref, live),
                    )
                  : null,
              onReverse: canWrite && live.canReverse
                  ? () => unawaited(
                      showAccountsReverseDialog(hostContext, ref),
                    )
                  : null,
              onVoid: canWrite && live.canVoid
                  ? () => unawaited(
                      showAccountsVoidDialog(hostContext, ref),
                    )
                  : null,
              onClose: canWrite && live.canClose
                  ? () => unawaited(
                      showAccountsCloseFromWorkItem(hostContext, ref, live),
                    )
                  : null,
              onOpenGl: live.canOpenGl && canViewAccountsGl(accessPolicy)
                  ? () => unawaited(
                      showAccountsGlFromWorkItem(hostContext, ref, live),
                    )
                  : null,
              onOpenLedger:
                  live.canOpenLedger &&
                      canReadAccountsPatientLedgers(accessPolicy)
                  ? () => unawaited(
                      showAccountsPatientLedgerDialog(
                        hostContext,
                        ref,
                        patientId: live.patientId ?? '',
                        patientDisplayName: accountsPublicLabel(
                          live.patientDisplayName,
                        ),
                        currency: live.currency,
                      ),
                    )
                  : null,
              onPrint: () => unawaited(
                printAccountsWorkItem(hostContext, ref, live),
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).maybePop(),
                child: const Text(AccountsStrings.closeAction),
              ),
            ],
          );
        },
      );
    },
  );
}
