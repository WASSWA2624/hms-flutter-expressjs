import 'package:flutter/material.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_price_book_entry.dart';
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_price_book_dialogs.dart';
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_price_book_similarity.dart';
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_support.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

enum BillingPriceBookSimilarityAction {
  cancel,
  useExisting,
  overwrite,
  proceed,
}

final class BillingPriceBookSimilarityDialogResult {
  const BillingPriceBookSimilarityDialogResult._({
    required this.action,
    this.selectedEntry,
  });

  const BillingPriceBookSimilarityDialogResult.cancel()
    : this._(action: BillingPriceBookSimilarityAction.cancel);

  const BillingPriceBookSimilarityDialogResult.proceed()
    : this._(action: BillingPriceBookSimilarityAction.proceed);

  const BillingPriceBookSimilarityDialogResult.useExisting(this.selectedEntry)
    : action = BillingPriceBookSimilarityAction.useExisting;

  const BillingPriceBookSimilarityDialogResult.overwrite(this.selectedEntry)
    : action = BillingPriceBookSimilarityAction.overwrite;

  final BillingPriceBookSimilarityAction action;
  final BillingPriceBookEntry? selectedEntry;
}

/// Price book adapter over [showAppSimilarityReviewDialog] (billing.md §18).
Future<BillingPriceBookSimilarityDialogResult>
showBillingPriceBookSimilarityDialog(
  BuildContext context, {
  required BillingPriceBookSimilarityDraft draft,
  required BillingPriceBookSimilarityResult check,
  required bool isCreate,
}) async {
  final AppLocalizations l10n = context.l10n;
  final List<BillingPriceBookSimilarityMatch> visibleMatches = check.matches
      .take(5)
      .toList(growable: false);
  final bool hasExact = check.hasExactConflict;
  final bool hasMatches = visibleMatches.isNotEmpty;
  final int overallScore = check.closestScore;
  final BillingPriceBookSimilarityMatch? topMatch = visibleMatches.isEmpty
      ? null
      : visibleMatches.first;

  final String dialogTitle = hasExact
      ? l10n.billingPriceBookExactDialogTitle
      : hasMatches
      ? l10n.billingPriceBookSimilarDialogTitle
      : l10n.billingPriceBookNoSimilarDialogTitle;
  final String bannerTitle = hasExact
      ? l10n.billingPriceBookExactBannerTitle
      : hasMatches
      ? l10n.billingPriceBookSimilarBannerTitle
      : l10n.billingPriceBookNoSimilarBannerTitle;
  final String bannerMessage = hasExact
      ? l10n.billingPriceBookExactDialogBody
      : hasMatches
      ? l10n.billingPriceBookSimilarDialogBody
      : l10n.billingPriceBookNoSimilarDialogBody;
  final AppFormInformationVariant bannerVariant = hasExact
      ? AppFormInformationVariant.error
      : hasMatches
      ? AppFormInformationVariant.warning
      : AppFormInformationVariant.success;

  final List<AppSimilarityMatch<BillingPriceBookEntry>> appMatches =
      visibleMatches.map((BillingPriceBookSimilarityMatch match) {
        return AppSimilarityMatch<BillingPriceBookEntry>(
          item: match.entry,
          title: billingPriceBookItemDisplayLabel(l10n, match.entry),
          subtitle: billingJoinDisplay(<String?>[
            billingPriceBookModeLabel(l10n, match.entry.paymentMode),
            billingPriceBookSchemeDisplayLabel(l10n, match.entry),
          ]),
          overallScore: match.score,
          isExact: match.isExact,
          fields: match.fieldComparisons
              .map(
                (BillingPriceBookFieldComparison comparison) =>
                    AppSimilarityFieldRow(
                      key: comparison.field,
                      label: _fieldLabel(l10n, comparison.field),
                      proposedValue:
                          billingPublicLabel(comparison.inputValue) ??
                          (comparison.inputValue.trim().isEmpty
                              ? l10n.billingNotRecorded
                              : comparison.inputValue),
                      existingValue:
                          billingPublicLabel(comparison.candidateValue) ??
                          (comparison.candidateValue.trim().isEmpty
                              ? l10n.billingNotRecorded
                              : comparison.candidateValue),
                      score: comparison.score,
                    ),
              )
              .toList(growable: false),
        );
      }).toList(growable: false);

  final AppSimilarityReviewResult<BillingPriceBookEntry> result =
      await showAppSimilarityReviewDialog<BillingPriceBookEntry>(
        context,
        title: dialogTitle,
        bannerTitle: bannerTitle,
        bannerMessage: bannerMessage,
        bannerVariant: bannerVariant,
        proposedFields: _proposedFields(l10n, draft),
        matches: appMatches,
        overallScore: overallScore,
        blockProceed: hasExact && isCreate,
        enableRetry: false,
        proposedReadOnly: true,
        enableReplaceExisting: hasMatches && !hasExact,
        proceedLabel: hasMatches
            ? l10n.billingPriceBookProceedSaveAction
            : l10n.billingPriceBookContinueSaveAction,
        useThisLabel: l10n.billingPriceBookUseExistingAction,
        replaceExistingLabel: l10n.billingPriceBookOverwriteAction,
        useThisIcon: Icons.open_in_new,
        replaceExistingIcon: Icons.swap_horiz_outlined,
        proposedHeading: l10n.tenantFacilitySimilarTenantProposedHeading,
        matchesHeading: l10n.tenantFacilitySimilarTenantMatchesHeading,
        exactBadgeLabel: l10n.accessAdminSimilarRoleExactConflictLabel,
        nearBadgeLabel: l10n.accessAdminSimilarRoleNearMatchLabel,
        existingHeading: l10n.accessAdminSimilarRoleExistingHeading,
        fieldColumnLabel: l10n.tenantFacilitySimilarTenantFieldLabel,
        proposedColumnLabel: l10n.tenantFacilitySimilarTenantProposedValueLabel,
        existingColumnLabel: l10n.tenantFacilitySimilarTenantExistingValueLabel,
        closestMatchLabel: topMatch == null
            ? l10n.accessAdminNoSimilarRoleDialogBody
            : l10n.accessAdminSimilarRoleOverallSimilarityLabel,
        noMatchLabel: l10n.billingPriceBookNoSimilarDialogBody,
        emptyValueLabel: l10n.billingNotRecorded,
        dialogIcon: hasExact
            ? Icons.gpp_bad_outlined
            : hasMatches
            ? Icons.warning_amber_outlined
            : Icons.verified_outlined,
      );

  switch (result.action) {
    case AppSimilarityReviewAction.cancel:
    case AppSimilarityReviewAction.retry:
      return const BillingPriceBookSimilarityDialogResult.cancel();
    case AppSimilarityReviewAction.proceed:
      return const BillingPriceBookSimilarityDialogResult.proceed();
    case AppSimilarityReviewAction.useExisting:
      final BillingPriceBookEntry? selected = result.selected;
      if (selected == null) {
        return const BillingPriceBookSimilarityDialogResult.cancel();
      }
      return BillingPriceBookSimilarityDialogResult.useExisting(selected);
    case AppSimilarityReviewAction.replaceExisting:
      final BillingPriceBookEntry? selected = result.selected;
      if (selected == null) {
        return const BillingPriceBookSimilarityDialogResult.cancel();
      }
      return BillingPriceBookSimilarityDialogResult.overwrite(selected);
  }
}

List<AppSimilarityProposedField> _proposedFields(
  AppLocalizations l10n,
  BillingPriceBookSimilarityDraft draft,
) {
  return <AppSimilarityProposedField>[
    AppSimilarityProposedField(
      key: 'item',
      label: l10n.billingPriceBookItemLabel,
      initialValue:
          billingPublicLabel(draft.catalogItemId) ??
          (draft.catalogItemId.trim().isEmpty
              ? l10n.billingNotRecorded
              : draft.catalogItemId.trim()),
    ),
    AppSimilarityProposedField(
      key: 'mode',
      label: l10n.billingPriceBookModeLabel,
      initialValue: billingPriceBookModeLabel(l10n, draft.paymentMode),
    ),
    AppSimilarityProposedField(
      key: 'scheme',
      label: l10n.billingPriceBookSchemeLabel,
      initialValue:
          billingPublicLabel(draft.coveragePlanId) ?? l10n.billingNotRecorded,
    ),
    AppSimilarityProposedField(
      key: 'effective',
      label: l10n.billingPriceBookEffectiveLabel,
      initialValue: _formatEffective(draft.effectiveFrom) ??
          l10n.billingNotRecorded,
    ),
  ];
}

String? _formatEffective(DateTime? value) {
  if (value == null) {
    return null;
  }
  final DateTime local = value.toLocal();
  final String month = local.month.toString().padLeft(2, '0');
  final String day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}

String _fieldLabel(AppLocalizations l10n, String field) {
  return switch (field) {
    'item' => l10n.billingPriceBookItemLabel,
    'mode' => l10n.billingPriceBookModeLabel,
    'scheme' => l10n.billingPriceBookSchemeLabel,
    'effective' => l10n.billingPriceBookEffectiveLabel,
    _ => field,
  };
}
