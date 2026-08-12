import 'package:flutter/material.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_entities.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_strings.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_journal_similarity.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_support.dart';
import 'package:hosspi_hms/shared/components/components.dart';

enum AccountsJournalSimilarityAction { cancel, useExisting, proceed }

final class AccountsJournalSimilarityDialogResult {
  const AccountsJournalSimilarityDialogResult._({
    required this.action,
    this.selectedItem,
  });

  const AccountsJournalSimilarityDialogResult.cancel()
    : this._(action: AccountsJournalSimilarityAction.cancel);

  const AccountsJournalSimilarityDialogResult.proceed()
    : this._(action: AccountsJournalSimilarityAction.proceed);

  const AccountsJournalSimilarityDialogResult.useExisting(this.selectedItem)
    : action = AccountsJournalSimilarityAction.useExisting;

  final AccountsJournalSimilarityAction action;
  final AccountsWorkItem? selectedItem;
}

/// Journal create adapter over [showAppSimilarityReviewDialog] (accounts.md §18).
Future<AccountsJournalSimilarityDialogResult> showAccountsJournalSimilarityDialog(
  BuildContext context, {
  required AccountsJournalDraft draft,
  required AccountsJournalSimilarityResult check,
}) async {
  final List<AccountsJournalSimilarityMatch> visibleMatches = check.matches
      .take(5)
      .toList(growable: false);
  final bool hasExact = check.hasExactConflict;
  final bool hasMatches = visibleMatches.isNotEmpty;
  final int overallScore = check.closestScore;
  final AccountsJournalSimilarityMatch? topMatch =
      visibleMatches.isEmpty ? null : visibleMatches.first;

  final String dialogTitle = hasExact
      ? AccountsStrings.journalExactSimilarDialogTitle
      : hasMatches
      ? AccountsStrings.journalSimilarDialogTitle
      : AccountsStrings.journalNoSimilarDialogTitle;
  final String bannerTitle = hasExact
      ? 'Exact match'
      : hasMatches
      ? 'Near match'
      : 'No matches';
  final String bannerMessage = hasExact
      ? 'An identical draft already exists. Open it or continue only if you intend a duplicate.'
      : hasMatches
      ? 'Review near-duplicate drafts before creating another journal.'
      : 'No similar drafts found. You can continue.';
  final AppFormInformationVariant bannerVariant = hasExact
      ? AppFormInformationVariant.error
      : hasMatches
      ? AppFormInformationVariant.warning
      : AppFormInformationVariant.success;

  final List<AppSimilarityMatch<AccountsWorkItem>> appMatches = visibleMatches
      .map((AccountsJournalSimilarityMatch match) {
        return AppSimilarityMatch<AccountsWorkItem>(
          item: match.item,
          title: accountsWorkItemPublicId(match.item),
          subtitle: accountsJoinDisplay(<String?>[
            accountsPublicLabel(match.item.periodLabel),
            accountsPublicLabel(match.item.source),
          ]),
          overallScore: match.score,
          isExact: match.isExact,
          fields: match.fieldComparisons
              .map(
                (AccountsJournalFieldComparison comparison) =>
                    AppSimilarityFieldRow(
                      key: comparison.field,
                      label: _fieldLabel(comparison.field),
                      proposedValue:
                          accountsPublicLabel(comparison.inputValue) ??
                          (comparison.inputValue.trim().isEmpty
                              ? AccountsStrings.unknownValue
                              : comparison.inputValue),
                      existingValue:
                          accountsPublicLabel(comparison.candidateValue) ??
                          (comparison.candidateValue.trim().isEmpty
                              ? AccountsStrings.unknownValue
                              : comparison.candidateValue),
                      score: comparison.score,
                    ),
              )
              .toList(growable: false),
        );
      })
      .toList(growable: false);

  final AppSimilarityReviewResult<AccountsWorkItem> result =
      await showAppSimilarityReviewDialog<AccountsWorkItem>(
        context,
        title: dialogTitle,
        bannerTitle: bannerTitle,
        bannerMessage: bannerMessage,
        bannerVariant: bannerVariant,
        proposedFields: _proposedFields(context, draft),
        matches: appMatches,
        overallScore: overallScore,
        blockProceed: false,
        enableRetry: false,
        proposedReadOnly: true,
        proceedLabel: hasMatches ? 'Continue create' : 'Create journal',
        useThisLabel: 'Open existing',
        useThisIcon: Icons.open_in_new,
        dialogIcon: hasExact
            ? Icons.gpp_bad_outlined
            : hasMatches
            ? Icons.warning_amber_outlined
            : Icons.verified_outlined,
        emptyValueLabel: AccountsStrings.unknownValue,
        closestMatchLabel: topMatch == null
            ? bannerMessage
            : 'Closest match ${topMatch.score}%',
        noMatchLabel: bannerMessage,
      );

  switch (result.action) {
    case AppSimilarityReviewAction.cancel:
    case AppSimilarityReviewAction.retry:
    case AppSimilarityReviewAction.replaceExisting:
      return const AccountsJournalSimilarityDialogResult.cancel();
    case AppSimilarityReviewAction.proceed:
      return const AccountsJournalSimilarityDialogResult.proceed();
    case AppSimilarityReviewAction.useExisting:
      final AccountsWorkItem? selected = result.selected;
      if (selected == null) {
        return const AccountsJournalSimilarityDialogResult.cancel();
      }
      return AccountsJournalSimilarityDialogResult.useExisting(selected);
  }
}

List<AppSimilarityProposedField> _proposedFields(
  BuildContext context,
  AccountsJournalDraft draft,
) {
  final num debit = draft.lines.fold<num>(
    0,
    (num sum, AccountsJournalLineDraft line) => sum + line.debit,
  );
  final String accounts = draft.lines
      .map((AccountsJournalLineDraft line) => line.accountId.trim())
      .where((String code) => code.isNotEmpty)
      .join(', ');
  return <AppSimilarityProposedField>[
    AppSimilarityProposedField(
      key: 'period',
      label: AccountsStrings.periodColumn,
      initialValue: accountsPublicLabel(draft.periodLabel) ??
          AccountsStrings.unknownValue,
    ),
    AppSimilarityProposedField(
      key: 'source',
      label: AccountsStrings.sourceColumn,
      initialValue:
          accountsPublicLabel(draft.source) ?? AccountsStrings.unknownValue,
    ),
    AppSimilarityProposedField(
      key: 'accounts',
      label: AccountsStrings.accountColumn,
      initialValue: accounts.isEmpty ? AccountsStrings.unknownValue : accounts,
    ),
    AppSimilarityProposedField(
      key: 'amount',
      label: AccountsStrings.amountColumn,
      initialValue: accountsMoney(context, debit, null),
    ),
    AppSimilarityProposedField(
      key: 'memo',
      label: AccountsStrings.notesLabel,
      initialValue:
          accountsPublicLabel(draft.notes) ?? AccountsStrings.unknownValue,
    ),
  ];
}

String _fieldLabel(String field) {
  return switch (field) {
    'period' => AccountsStrings.periodColumn,
    'source' => AccountsStrings.sourceColumn,
    'accounts' => AccountsStrings.accountColumn,
    'amount' => AccountsStrings.amountColumn,
    'memo' => AccountsStrings.notesLabel,
    _ => field,
  };
}
