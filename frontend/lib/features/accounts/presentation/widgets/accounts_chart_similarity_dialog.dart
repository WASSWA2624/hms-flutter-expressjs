import 'package:flutter/material.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_chart_account.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_strings.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_chart_similarity.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_support.dart';
import 'package:hosspi_hms/shared/components/components.dart';

enum AccountsChartSimilarityAction {
  cancel,
  selectExisting,
  overwrite,
  proceed,
}

final class AccountsChartSimilarityDialogResult {
  const AccountsChartSimilarityDialogResult._({
    required this.action,
    this.selected,
  });

  const AccountsChartSimilarityDialogResult.cancel()
    : this._(action: AccountsChartSimilarityAction.cancel);

  const AccountsChartSimilarityDialogResult.proceed()
    : this._(action: AccountsChartSimilarityAction.proceed);

  const AccountsChartSimilarityDialogResult.selectExisting(this.selected)
    : action = AccountsChartSimilarityAction.selectExisting;

  const AccountsChartSimilarityDialogResult.overwrite(this.selected)
    : action = AccountsChartSimilarityAction.overwrite;

  final AccountsChartSimilarityAction action;
  final AccountsChartAccount? selected;
}

/// Chart create/edit adapter over [showAppSimilarityReviewDialog] (accounts.md §18).
Future<AccountsChartSimilarityDialogResult> showAccountsChartSimilarityDialog(
  BuildContext context, {
  required AccountsChartSimilarityDraft draft,
  required AccountsChartSimilarityResult check,
  required bool isCreate,
}) async {
  final List<AccountsChartSimilarityMatch> visibleMatches =
      check.matches.take(5).toList(growable: false);
  final bool hasExactCode = check.hasExactCodeConflict;
  final bool hasExact = check.hasExactConflict;
  final bool hasMatches = visibleMatches.isNotEmpty;
  final int overallScore = check.closestScore;
  final AccountsChartSimilarityMatch? topMatch =
      visibleMatches.isEmpty ? null : visibleMatches.first;
  final bool blockProceed = hasExactCode || hasExact;

  final String dialogTitle = blockProceed
      ? AccountsStrings.chartExactDialogTitle
      : hasMatches
      ? AccountsStrings.chartSimilarDialogTitle
      : AccountsStrings.chartNoSimilarDialogTitle;
  final String bannerTitle = blockProceed
      ? AccountsStrings.chartExactBannerTitle
      : hasMatches
      ? AccountsStrings.chartSimilarBannerTitle
      : AccountsStrings.chartNoSimilarBannerTitle;
  final String bannerMessage = hasExactCode
      ? AccountsStrings.chartExactCodeDialogBody
      : hasExact
      ? AccountsStrings.chartExactDialogBody
      : hasMatches
      ? AccountsStrings.chartSimilarDialogBody
      : AccountsStrings.chartNoSimilarDialogBody;
  final AppFormInformationVariant bannerVariant = blockProceed
      ? AppFormInformationVariant.error
      : hasMatches
      ? AppFormInformationVariant.warning
      : AppFormInformationVariant.success;

  final List<AppSimilarityMatch<AccountsChartAccount>> appMatches =
      visibleMatches.map((AccountsChartSimilarityMatch match) {
        final List<AccountsChartFieldComparison> comparisons =
            match.isExactCode && !match.isExact
            ? match.fieldComparisons
                  .where(
                    (AccountsChartFieldComparison field) => field.field == 'code',
                  )
                  .toList(growable: false)
            : match.fieldComparisons;
        return AppSimilarityMatch<AccountsChartAccount>(
          item: match.account,
          title: match.account.accountLabel,
          subtitle: accountsJoinDisplay(<String?>[
            accountsPublicLabel(match.account.code),
            accountsChartTypeLabelSafe(match.account.accountType),
            accountsPublicLabel(match.account.parentLabel),
          ]),
          overallScore: match.score,
          isExact: match.isExact || match.isExactCode,
          fields: comparisons
              .map(
                (AccountsChartFieldComparison comparison) =>
                    AppSimilarityFieldRow(
                      key: comparison.field,
                      label: _fieldLabel(comparison.field),
                      proposedValue:
                          accountsPublicLabel(comparison.inputValue) ??
                          (comparison.inputValue.trim().isEmpty
                              ? AccountsStrings.notRecorded
                              : comparison.inputValue),
                      existingValue:
                          accountsPublicLabel(comparison.candidateValue) ??
                          (comparison.candidateValue.trim().isEmpty
                              ? AccountsStrings.notRecorded
                              : comparison.candidateValue),
                      score: comparison.score,
                    ),
              )
              .toList(growable: false),
        );
      }).toList(growable: false);

  final AppSimilarityReviewResult<AccountsChartAccount> result =
      await showAppSimilarityReviewDialog<AccountsChartAccount>(
        context,
        title: dialogTitle,
        bannerTitle: bannerTitle,
        bannerMessage: bannerMessage,
        bannerVariant: bannerVariant,
        proposedFields: _proposedFields(draft),
        matches: appMatches,
        overallScore: overallScore,
        blockProceed: blockProceed,
        enableRetry: false,
        proposedReadOnly: true,
        enableReplaceExisting: hasMatches && !blockProceed,
        proceedLabel: isCreate
            ? AccountsStrings.chartContinueCreate
            : AccountsStrings.chartContinueSave,
        useThisLabel: AccountsStrings.chartSelectExisting,
        replaceExistingLabel: AccountsStrings.chartOverwriteExisting,
        useThisIcon: Icons.open_in_new,
        replaceExistingIcon: Icons.swap_horiz_outlined,
        dialogIcon: blockProceed
            ? Icons.gpp_bad_outlined
            : hasMatches
            ? Icons.warning_amber_outlined
            : Icons.verified_outlined,
        emptyValueLabel: AccountsStrings.notRecorded,
        closestMatchLabel: topMatch == null
            ? bannerMessage
            : 'Closest match ${topMatch.score}%',
        noMatchLabel: bannerMessage,
      );

  switch (result.action) {
    case AppSimilarityReviewAction.cancel:
    case AppSimilarityReviewAction.retry:
      return const AccountsChartSimilarityDialogResult.cancel();
    case AppSimilarityReviewAction.proceed:
      return const AccountsChartSimilarityDialogResult.proceed();
    case AppSimilarityReviewAction.useExisting:
      final AccountsChartAccount? selected = result.selected ?? topMatch?.account;
      if (selected == null) {
        return const AccountsChartSimilarityDialogResult.cancel();
      }
      return AccountsChartSimilarityDialogResult.selectExisting(selected);
    case AppSimilarityReviewAction.replaceExisting:
      final AccountsChartAccount? selected = result.selected ?? topMatch?.account;
      if (selected == null) {
        return const AccountsChartSimilarityDialogResult.cancel();
      }
      return AccountsChartSimilarityDialogResult.overwrite(selected);
  }
}

List<AppSimilarityProposedField> _proposedFields(
  AccountsChartSimilarityDraft draft,
) {
  return <AppSimilarityProposedField>[
    AppSimilarityProposedField(
      key: 'code',
      label: AccountsStrings.chartCodeLabel,
      initialValue: accountsPublicLabel(draft.code) ??
          (draft.code.trim().isEmpty
              ? AccountsStrings.notRecorded
              : draft.code.trim()),
    ),
    AppSimilarityProposedField(
      key: 'name',
      label: AccountsStrings.chartNameLabel,
      initialValue: accountsPublicLabel(draft.name) ??
          (draft.name.trim().isEmpty
              ? AccountsStrings.notRecorded
              : draft.name.trim()),
    ),
    AppSimilarityProposedField(
      key: 'type',
      label: AccountsStrings.chartTypeLabel,
      initialValue: accountsChartTypeLabelSafe(draft.accountType),
    ),
    AppSimilarityProposedField(
      key: 'parent',
      label: AccountsStrings.chartParentLabel,
      initialValue: accountsPublicLabel(draft.parentLabel) ??
          AccountsStrings.notRecorded,
    ),
  ];
}

String accountsChartTypeLabelSafe(String accountType) {
  return switch (accountType.trim().toUpperCase()) {
    'ASSET' => AccountsStrings.chartTypeAsset,
    'LIABILITY' => AccountsStrings.chartTypeLiability,
    'EQUITY' => AccountsStrings.chartTypeEquity,
    'REVENUE' => AccountsStrings.chartTypeRevenue,
    'EXPENSE' => AccountsStrings.chartTypeExpense,
    _ => accountsPublicLabel(accountType) ?? AccountsStrings.notRecorded,
  };
}

String _fieldLabel(String field) {
  return switch (field) {
    'code' => AccountsStrings.chartCodeLabel,
    'name' => AccountsStrings.chartNameLabel,
    'type' => AccountsStrings.chartTypeLabel,
    'parent' => AccountsStrings.chartParentLabel,
    _ => field,
  };
}
