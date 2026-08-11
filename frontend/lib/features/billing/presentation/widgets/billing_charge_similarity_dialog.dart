import 'package:flutter/material.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_entities.dart';
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_charge_similarity.dart';
import 'package:hosspi_hms/features/billing/presentation/widgets/billing_support.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

enum BillingChargeSimilarityAction { cancel, useExisting, proceed }

final class BillingChargeSimilarityDialogResult {
  const BillingChargeSimilarityDialogResult._({
    required this.action,
    this.selectedItem,
  });

  const BillingChargeSimilarityDialogResult.cancel()
    : this._(action: BillingChargeSimilarityAction.cancel);

  const BillingChargeSimilarityDialogResult.proceed()
    : this._(action: BillingChargeSimilarityAction.proceed);

  const BillingChargeSimilarityDialogResult.useExisting(this.selectedItem)
    : action = BillingChargeSimilarityAction.useExisting;

  final BillingChargeSimilarityAction action;
  final BillingWorkItem? selectedItem;
}

/// Charge adapter over [showAppSimilarityReviewDialog] (billing.md §18).
Future<BillingChargeSimilarityDialogResult> showBillingChargeSimilarityDialog(
  BuildContext context, {
  required BillingChargeDraft draft,
  required BillingChargeSimilarityResult check,
}) async {
  final AppLocalizations l10n = context.l10n;
  final List<BillingChargeSimilarityMatch> visibleMatches = check.matches
      .take(5)
      .toList(growable: false);
  final bool hasExact = check.hasExactConflict;
  final bool hasMatches = visibleMatches.isNotEmpty;
  final int overallScore = check.closestScore;
  final BillingChargeSimilarityMatch? topMatch =
      visibleMatches.isEmpty ? null : visibleMatches.first;

  final String dialogTitle = hasExact
      ? l10n.billingChargeExactDialogTitle
      : hasMatches
      ? l10n.billingChargeSimilarDialogTitle
      : l10n.billingChargeNoSimilarDialogTitle;
  final String bannerTitle = hasExact
      ? l10n.billingChargeExactBannerTitle
      : hasMatches
      ? l10n.billingChargeSimilarBannerTitle
      : l10n.billingChargeNoSimilarBannerTitle;
  final String bannerMessage = hasExact
      ? l10n.billingChargeExactDialogBody
      : hasMatches
      ? l10n.billingChargeSimilarDialogBody
      : l10n.billingChargeNoSimilarDialogBody;
  final AppFormInformationVariant bannerVariant = hasExact
      ? AppFormInformationVariant.error
      : hasMatches
      ? AppFormInformationVariant.warning
      : AppFormInformationVariant.success;

  final List<AppSimilarityMatch<BillingWorkItem>> appMatches = visibleMatches
      .map((BillingChargeSimilarityMatch match) {
        return AppSimilarityMatch<BillingWorkItem>(
          item: match.item,
          title: billingPublicLabel(match.item.displayId) ??
              billingPublicLabel(match.item.invoiceDisplayId) ??
              l10n.billingInvoiceLabel,
          subtitle: billingJoinDisplay(<String?>[
            match.item.effectivePatientName,
            billingPublicLabel(match.item.patientDisplayId),
          ]),
          overallScore: match.score,
          isExact: match.isExact,
          fields: match.fieldComparisons
              .map(
                (BillingChargeFieldComparison comparison) =>
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

  final AppSimilarityReviewResult<BillingWorkItem> result =
      await showAppSimilarityReviewDialog<BillingWorkItem>(
        context,
        title: dialogTitle,
        bannerTitle: bannerTitle,
        bannerMessage: bannerMessage,
        bannerVariant: bannerVariant,
        proposedFields: _proposedFields(context, l10n, draft),
        matches: appMatches,
        overallScore: overallScore,
        blockProceed: hasExact,
        enableRetry: false,
        proposedReadOnly: true,
        proceedLabel: hasMatches
            ? l10n.billingChargeProceedCreateAction
            : l10n.billingChargeContinueCreateAction,
        useThisLabel: l10n.billingChargeUseExistingAction,
        useThisIcon: Icons.open_in_new,
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
        noMatchLabel: l10n.billingChargeNoSimilarDialogBody,
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
      return const BillingChargeSimilarityDialogResult.cancel();
    case AppSimilarityReviewAction.proceed:
      return const BillingChargeSimilarityDialogResult.proceed();
    case AppSimilarityReviewAction.useExisting:
      final BillingWorkItem? selected = result.selected;
      if (selected == null) {
        return const BillingChargeSimilarityDialogResult.cancel();
      }
      return BillingChargeSimilarityDialogResult.useExisting(selected);
  }
}

List<AppSimilarityProposedField> _proposedFields(
  BuildContext context,
  AppLocalizations l10n,
  BillingChargeDraft draft,
) {
  final String patient = billingJoinDisplay(<String?>[
    draft.patientDisplayName,
    billingPublicLabel(draft.patientDisplayId),
  ]);
  final String mode = draft.paymentMode.toUpperCase() == 'INSURANCE'
      ? l10n.billingChargeModeInsurance
      : l10n.billingChargeModeSelfPay;
  return <AppSimilarityProposedField>[
    AppSimilarityProposedField(
      key: 'patient',
      label: l10n.billingChargePatientLabel,
      initialValue: patient.isEmpty ? l10n.billingUnknownPatient : patient,
    ),
    AppSimilarityProposedField(
      key: 'item',
      label: l10n.billingChargeItemLabel,
      initialValue: draft.itemDescription,
    ),
    AppSimilarityProposedField(
      key: 'encounter',
      label: l10n.billingEncounterLabel,
      initialValue: billingPublicLabel(draft.encounterDisplayId) ??
          l10n.billingNotRecorded,
    ),
    AppSimilarityProposedField(
      key: 'mode',
      label: l10n.billingChargeModeLabel,
      initialValue: mode,
    ),
    AppSimilarityProposedField(
      key: 'amount',
      label: l10n.billingChargeAmountLabel,
      initialValue: billingMoney(context, draft.lineAmount, draft.currency),
    ),
  ];
}

String _fieldLabel(AppLocalizations l10n, String field) {
  return switch (field) {
    'patient' => l10n.billingChargePatientLabel,
    'item' => l10n.billingChargeItemLabel,
    'encounter' => l10n.billingEncounterLabel,
    'mode' => l10n.billingChargeModeLabel,
    'amount' => l10n.billingChargeAmountLabel,
    _ => field,
  };
}
