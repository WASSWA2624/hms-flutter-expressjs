import 'package:flutter/material.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_entities.dart';
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_adjustment_similarity.dart';
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_support.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

enum BillingAdjustmentSimilarityAction { cancel, useExisting, proceed }

final class BillingAdjustmentSimilarityDialogResult {
  const BillingAdjustmentSimilarityDialogResult._({
    required this.action,
    this.selectedAdjustment,
  });

  const BillingAdjustmentSimilarityDialogResult.cancel()
    : this._(action: BillingAdjustmentSimilarityAction.cancel);

  const BillingAdjustmentSimilarityDialogResult.proceed()
    : this._(action: BillingAdjustmentSimilarityAction.proceed);

  const BillingAdjustmentSimilarityDialogResult.useExisting(
    this.selectedAdjustment,
  ) : action = BillingAdjustmentSimilarityAction.useExisting;

  final BillingAdjustmentSimilarityAction action;
  final BillingAdjustment? selectedAdjustment;
}

/// Adjust adapter over [showAppSimilarityReviewDialog] (billing.md §18).
Future<BillingAdjustmentSimilarityDialogResult>
showBillingAdjustmentSimilarityDialog(
  BuildContext context, {
  required BillingWorkItem invoice,
  required BillingAdjustmentDraft draft,
  required BillingAdjustmentSimilarityResult check,
}) async {
  final AppLocalizations l10n = context.l10n;
  final List<BillingAdjustmentSimilarityMatch> visibleMatches = check.matches
      .take(5)
      .toList(growable: false);
  final bool hasExact = check.hasExactConflict;
  final bool hasMatches = visibleMatches.isNotEmpty;
  final int overallScore = check.closestScore;

  final List<AppSimilarityMatch<BillingAdjustment>> appMatches = visibleMatches
      .map((BillingAdjustmentSimilarityMatch match) {
        return AppSimilarityMatch<BillingAdjustment>(
          item: match.adjustment,
          title: billingPublicLabel(match.adjustment.displayId) ??
              l10n.billingAdjustmentsTitle,
          subtitle: billingJoinDisplay(<String?>[
            match.adjustment.reason,
            billingMoney(context, match.adjustment.amount, invoice.currency),
          ]),
          overallScore: match.score,
          isExact: match.isExact,
          fields: match.fieldComparisons
              .map(
                (BillingAdjustmentFieldComparison comparison) =>
                    AppSimilarityFieldRow(
                      key: comparison.field,
                      label: _fieldLabel(l10n, comparison.field),
                      proposedValue: billingPublicLabel(comparison.inputValue) ??
                          comparison.inputValue,
                      existingValue:
                          billingPublicLabel(comparison.candidateValue) ??
                          comparison.candidateValue,
                      score: comparison.score,
                    ),
              )
              .toList(growable: false),
        );
      })
      .toList(growable: false);

  final AppSimilarityReviewResult<BillingAdjustment> result =
      await showAppSimilarityReviewDialog<BillingAdjustment>(
        context,
        title: hasExact
            ? l10n.billingAdjustExactDialogTitle
            : hasMatches
            ? l10n.billingAdjustSimilarDialogTitle
            : l10n.billingAdjustNoSimilarDialogTitle,
        bannerTitle: hasExact
            ? l10n.billingAdjustExactBannerTitle
            : hasMatches
            ? l10n.billingAdjustSimilarBannerTitle
            : l10n.billingAdjustNoSimilarBannerTitle,
        bannerMessage: hasExact
            ? l10n.billingAdjustExactDialogBody
            : hasMatches
            ? l10n.billingAdjustSimilarDialogBody
            : l10n.billingAdjustNoSimilarDialogBody,
        bannerVariant: hasExact
            ? AppFormInformationVariant.error
            : hasMatches
            ? AppFormInformationVariant.warning
            : AppFormInformationVariant.success,
        proposedFields: _proposedFields(context, l10n, invoice, draft),
        matches: appMatches,
        overallScore: overallScore,
        blockProceed: hasExact,
        enableRetry: false,
        proposedReadOnly: true,
        proceedLabel: hasMatches
            ? l10n.billingAdjustProceedCreateAction
            : l10n.billingAdjustContinueCreateAction,
        useThisLabel: l10n.billingAdjustUseExistingAction,
        useThisIcon: Icons.open_in_new,
        proposedHeading: l10n.tenantFacilitySimilarTenantProposedHeading,
        matchesHeading: l10n.tenantFacilitySimilarTenantMatchesHeading,
        exactBadgeLabel: l10n.accessAdminSimilarRoleExactConflictLabel,
        nearBadgeLabel: l10n.accessAdminSimilarRoleNearMatchLabel,
        existingHeading: l10n.accessAdminSimilarRoleExistingHeading,
        fieldColumnLabel: l10n.tenantFacilitySimilarTenantFieldLabel,
        proposedColumnLabel: l10n.tenantFacilitySimilarTenantProposedValueLabel,
        existingColumnLabel: l10n.tenantFacilitySimilarTenantExistingValueLabel,
        closestMatchLabel: l10n.accessAdminSimilarRoleOverallSimilarityLabel,
        noMatchLabel: l10n.billingAdjustNoSimilarDialogBody,
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
    case AppSimilarityReviewAction.replaceExisting:
      return const BillingAdjustmentSimilarityDialogResult.cancel();
    case AppSimilarityReviewAction.proceed:
      return const BillingAdjustmentSimilarityDialogResult.proceed();
    case AppSimilarityReviewAction.useExisting:
      final BillingAdjustment? selected = result.selected;
      if (selected == null) {
        return const BillingAdjustmentSimilarityDialogResult.cancel();
      }
      return BillingAdjustmentSimilarityDialogResult.useExisting(selected);
  }
}

List<AppSimilarityProposedField> _proposedFields(
  BuildContext context,
  AppLocalizations l10n,
  BillingWorkItem invoice,
  BillingAdjustmentDraft draft,
) {
  final num amount = num.tryParse(draft.amount.replaceAll(',', '')) ?? 0;
  return <AppSimilarityProposedField>[
    AppSimilarityProposedField(
      key: 'invoice',
      label: l10n.billingInvoiceLabel,
      initialValue: billingWorkItemPublicId(context, invoice),
    ),
    AppSimilarityProposedField(
      key: 'type',
      label: l10n.billingAdjustTypeLabel,
      initialValue: draft.status?.trim().isNotEmpty == true
          ? billingApiLabel(context, draft.status)
          : draft.reason,
    ),
    AppSimilarityProposedField(
      key: 'amount',
      label: l10n.billingAdjustmentAmountLabel,
      initialValue: billingMoney(context, amount, invoice.currency),
    ),
  ];
}

String _fieldLabel(AppLocalizations l10n, String field) {
  return switch (field) {
    'invoice' => l10n.billingInvoiceLabel,
    'type' => l10n.billingAdjustTypeLabel,
    'amount' => l10n.billingAdjustmentAmountLabel,
    _ => field,
  };
}
