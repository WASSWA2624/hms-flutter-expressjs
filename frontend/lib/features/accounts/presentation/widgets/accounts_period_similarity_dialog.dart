import 'package:flutter/material.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_entities.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_strings.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_period_similarity.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_support.dart';
import 'package:hosspi_hms/shared/components/components.dart';

enum AccountsPeriodSimilarityAction { cancel, selectExisting, proceed }

final class AccountsPeriodSimilarityDialogResult {
  const AccountsPeriodSimilarityDialogResult._({
    required this.action,
    this.selected,
  });

  const AccountsPeriodSimilarityDialogResult.cancel()
    : this._(action: AccountsPeriodSimilarityAction.cancel);

  const AccountsPeriodSimilarityDialogResult.proceed()
    : this._(action: AccountsPeriodSimilarityAction.proceed);

  const AccountsPeriodSimilarityDialogResult.selectExisting(this.selected)
    : action = AccountsPeriodSimilarityAction.selectExisting;

  final AccountsPeriodSimilarityAction action;
  final AccountsFiscalPeriod? selected;
}

/// Open period adapter over [showAppSimilarityReviewDialog] (accounts.md §18).
Future<AccountsPeriodSimilarityDialogResult> showAccountsPeriodSimilarityDialog(
  BuildContext context, {
  required AccountsPeriodSimilarityDraft draft,
  required AccountsPeriodSimilarityResult check,
}) async {
  final List<AccountsPeriodSimilarityMatch> visibleMatches =
      check.matches.take(5).toList(growable: false);
  final bool hasExact = check.hasExactConflict;
  final bool hasOverlap = check.hasOverlapConflict;
  final bool hasMatches = visibleMatches.isNotEmpty;
  final bool blockProceed = hasExact || hasOverlap;
  final int overallScore = check.closestScore;
  final AccountsPeriodSimilarityMatch? topMatch =
      visibleMatches.isEmpty ? null : visibleMatches.first;

  final String dialogTitle = blockProceed
      ? AccountsStrings.periodExactDialogTitle
      : hasMatches
      ? AccountsStrings.periodSimilarDialogTitle
      : AccountsStrings.periodNoSimilarDialogTitle;
  final String bannerTitle = blockProceed
      ? AccountsStrings.periodExactBannerTitle
      : hasMatches
      ? AccountsStrings.periodSimilarBannerTitle
      : AccountsStrings.periodNoSimilarBannerTitle;
  final String bannerMessage = hasExact
      ? AccountsStrings.periodExactDialogBody
      : hasOverlap
      ? AccountsStrings.periodOverlapDialogBody
      : hasMatches
      ? AccountsStrings.periodSimilarDialogBody
      : AccountsStrings.periodNoSimilarDialogBody;
  final AppFormInformationVariant bannerVariant = blockProceed
      ? AppFormInformationVariant.error
      : hasMatches
      ? AppFormInformationVariant.warning
      : AppFormInformationVariant.success;

  final List<AppSimilarityMatch<AccountsFiscalPeriod>> appMatches =
      visibleMatches.map((AccountsPeriodSimilarityMatch match) {
        final List<AccountsPeriodFieldComparison> comparisons =
            match.isExact || match.isOverlap
            ? match.fieldComparisons
                  .where(
                    (AccountsPeriodFieldComparison field) =>
                        field.field == 'label' || field.field == 'dates',
                  )
                  .toList(growable: false)
            : match.fieldComparisons;
        return AppSimilarityMatch<AccountsFiscalPeriod>(
          item: match.period,
          title: match.period.effectiveLabel,
          subtitle: accountsJoinDisplay(<String?>[
            accountsPeriodStatusLabel(match.period),
            match.period.publicFacilityLabel,
          ]),
          overallScore: match.score,
          isExact: match.isExact || match.isOverlap,
          fields: comparisons
              .map(
                (AccountsPeriodFieldComparison comparison) =>
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

  final AppSimilarityReviewResult<AccountsFiscalPeriod> result =
      await showAppSimilarityReviewDialog<AccountsFiscalPeriod>(
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
        proceedLabel: AccountsStrings.periodContinueOpen,
        useThisLabel: AccountsStrings.periodSelectExisting,
        useThisIcon: Icons.open_in_new,
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
    case AppSimilarityReviewAction.replaceExisting:
      return const AccountsPeriodSimilarityDialogResult.cancel();
    case AppSimilarityReviewAction.proceed:
      if (blockProceed) {
        return const AccountsPeriodSimilarityDialogResult.cancel();
      }
      return const AccountsPeriodSimilarityDialogResult.proceed();
    case AppSimilarityReviewAction.useExisting:
      final AccountsFiscalPeriod? selected =
          result.selected ?? topMatch?.period;
      if (selected == null) {
        return const AccountsPeriodSimilarityDialogResult.cancel();
      }
      return AccountsPeriodSimilarityDialogResult.selectExisting(selected);
  }
}

List<AppSimilarityProposedField> _proposedFields(
  AccountsPeriodSimilarityDraft draft,
) {
  return <AppSimilarityProposedField>[
    AppSimilarityProposedField(
      key: 'label',
      label: AccountsStrings.periodLabelField,
      initialValue: accountsPublicLabel(draft.label) ??
          (draft.label.trim().isEmpty
              ? AccountsStrings.notRecorded
              : draft.label.trim()),
    ),
    AppSimilarityProposedField(
      key: 'dates',
      label: AccountsStrings.periodDatesField,
      initialValue:
          '${_formatDay(draft.startDate)} → ${_formatDay(draft.endDate)}',
    ),
    AppSimilarityProposedField(
      key: 'facility',
      label: AccountsStrings.facilityColumn,
      initialValue: accountsPublicLabel(draft.facilityLabel) ??
          AccountsStrings.notRecorded,
    ),
  ];
}

String _fieldLabel(String field) {
  return switch (field) {
    'label' => AccountsStrings.periodLabelField,
    'dates' => AccountsStrings.periodDatesField,
    'facility' => AccountsStrings.facilityColumn,
    _ => field,
  };
}

String _formatDay(DateTime value) {
  final DateTime local = value.toLocal();
  final String month = local.month.toString().padLeft(2, '0');
  final String day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}
