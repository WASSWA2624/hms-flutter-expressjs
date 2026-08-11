import 'package:flutter/material.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_entities.dart';
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_refund_similarity.dart';
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_support.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

enum BillingRefundSimilarityAction { cancel, useExisting, proceed }

final class BillingRefundSimilarityDialogResult {
  const BillingRefundSimilarityDialogResult._({
    required this.action,
    this.selectedPayment,
  });

  const BillingRefundSimilarityDialogResult.cancel()
    : this._(action: BillingRefundSimilarityAction.cancel);

  const BillingRefundSimilarityDialogResult.proceed()
    : this._(action: BillingRefundSimilarityAction.proceed);

  const BillingRefundSimilarityDialogResult.useExisting(this.selectedPayment)
    : action = BillingRefundSimilarityAction.useExisting;

  final BillingRefundSimilarityAction action;
  final BillingPayment? selectedPayment;
}

/// Refund adapter over [showAppSimilarityReviewDialog] (billing.md §18).
Future<BillingRefundSimilarityDialogResult> showBillingRefundSimilarityDialog(
  BuildContext context, {
  required BillingWorkItem invoice,
  required BillingRefundDraft draft,
  required BillingRefundSimilarityResult check,
}) async {
  final AppLocalizations l10n = context.l10n;
  final List<BillingRefundSimilarityMatch> visibleMatches = check.matches
      .take(5)
      .toList(growable: false);
  final bool hasExact = check.hasExactConflict;
  final bool hasMatches = visibleMatches.isNotEmpty;
  final int overallScore = check.closestScore;

  final List<AppSimilarityMatch<BillingPayment>> appMatches = visibleMatches
      .map((BillingRefundSimilarityMatch match) {
        return AppSimilarityMatch<BillingPayment>(
          item: match.payment,
          title: billingPublicLabel(match.payment.displayId) ??
              l10n.billingPaymentLabel,
          subtitle: billingJoinDisplay(<String?>[
            billingApiLabel(context, match.payment.method),
            billingMoney(context, match.payment.amount, invoice.currency),
          ]),
          overallScore: match.score,
          isExact: match.isExact,
          fields: match.fieldComparisons
              .map(
                (BillingRefundFieldComparison comparison) =>
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

  final AppSimilarityReviewResult<BillingPayment> result =
      await showAppSimilarityReviewDialog<BillingPayment>(
        context,
        title: hasExact
            ? l10n.billingRefundExactDialogTitle
            : hasMatches
            ? l10n.billingRefundSimilarDialogTitle
            : l10n.billingRefundNoSimilarDialogTitle,
        bannerTitle: hasExact
            ? l10n.billingRefundExactBannerTitle
            : hasMatches
            ? l10n.billingRefundSimilarBannerTitle
            : l10n.billingRefundNoSimilarBannerTitle,
        bannerMessage: hasExact
            ? l10n.billingRefundExactDialogBody
            : hasMatches
            ? l10n.billingRefundSimilarDialogBody
            : l10n.billingRefundNoSimilarDialogBody,
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
            ? l10n.billingRefundProceedCreateAction
            : l10n.billingRefundContinueCreateAction,
        useThisLabel: l10n.billingRefundUseExistingAction,
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
        noMatchLabel: l10n.billingRefundNoSimilarDialogBody,
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
      return const BillingRefundSimilarityDialogResult.cancel();
    case AppSimilarityReviewAction.proceed:
      return const BillingRefundSimilarityDialogResult.proceed();
    case AppSimilarityReviewAction.useExisting:
      final BillingPayment? selected = result.selected;
      if (selected == null) {
        return const BillingRefundSimilarityDialogResult.cancel();
      }
      return BillingRefundSimilarityDialogResult.useExisting(selected);
  }
}

List<AppSimilarityProposedField> _proposedFields(
  BuildContext context,
  AppLocalizations l10n,
  BillingWorkItem invoice,
  BillingRefundDraft draft,
) {
  final num amount = num.tryParse(draft.amount.replaceAll(',', '')) ?? 0;
  BillingPayment? payment;
  for (final BillingPayment candidate in invoice.payments) {
    if (candidate.id == draft.paymentId) {
      payment = candidate;
      break;
    }
  }
  return <AppSimilarityProposedField>[
    AppSimilarityProposedField(
      key: 'payment',
      label: l10n.billingPaymentLabel,
      initialValue: billingPublicLabel(payment?.displayId) ??
          l10n.billingPaymentLabel,
    ),
    AppSimilarityProposedField(
      key: 'amount',
      label: l10n.billingAdjustmentAmountLabel,
      initialValue: billingMoney(context, amount, invoice.currency),
    ),
    AppSimilarityProposedField(
      key: 'reason',
      label: l10n.billingReasonLabel,
      initialValue: draft.reason,
    ),
  ];
}

String _fieldLabel(AppLocalizations l10n, String field) {
  return switch (field) {
    'payment' => l10n.billingPaymentLabel,
    'amount' => l10n.billingAdjustmentAmountLabel,
    'reason' => l10n.billingReasonLabel,
    _ => field,
  };
}
