import 'package:flutter/material.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

enum PharmacyDrugSimilarityAction {
  cancel,
  useExisting,
  replaceExisting,
  proceed,
  retry,
}

final class PharmacyDrugSimilarityDialogResult {
  const PharmacyDrugSimilarityDialogResult._({
    required this.action,
    this.selectedDrug,
    this.proposed,
  });

  const PharmacyDrugSimilarityDialogResult.cancel()
    : this._(action: PharmacyDrugSimilarityAction.cancel);

  const PharmacyDrugSimilarityDialogResult.proceed({
    PharmacyDrugSimilarityProposedValues? proposed,
  }) : this._(
         action: PharmacyDrugSimilarityAction.proceed,
         proposed: proposed,
       );

  const PharmacyDrugSimilarityDialogResult.useExisting(PharmacyDrug drug)
    : this._(
        action: PharmacyDrugSimilarityAction.useExisting,
        selectedDrug: drug,
      );

  const PharmacyDrugSimilarityDialogResult.replaceExisting(
    PharmacyDrug drug, {
    required PharmacyDrugSimilarityProposedValues proposed,
  }) : this._(
         action: PharmacyDrugSimilarityAction.replaceExisting,
         selectedDrug: drug,
         proposed: proposed,
       );

  const PharmacyDrugSimilarityDialogResult.retry({
    required PharmacyDrugSimilarityProposedValues proposed,
  }) : this._(
         action: PharmacyDrugSimilarityAction.retry,
         proposed: proposed,
       );

  final PharmacyDrugSimilarityAction action;
  final PharmacyDrug? selectedDrug;
  final PharmacyDrugSimilarityProposedValues? proposed;
}

final class PharmacyDrugSimilarityProposedValues {
  const PharmacyDrugSimilarityProposedValues({
    required this.genericName,
    this.brandName,
    this.code,
    this.form,
    this.strength,
  });

  final String genericName;
  final String? brandName;
  final String? code;
  final String? form;
  final String? strength;
}

/// Pharmacy drug adapter over [showAppSimilarityReviewDialog].
Future<PharmacyDrugSimilarityDialogResult> showPharmacyDrugSimilarityDialog(
  BuildContext context, {
  required PharmacyDrugSimilarityProposedValues proposed,
  required PharmacyDrugSimilarityResult check,
  bool isEdit = false,
}) async {
  final AppLocalizations l10n = context.l10n;
  final List<PharmacyDrugSimilarityMatch> visibleMatches = check.matches
      .take(5)
      .toList(growable: false);
  final bool hasExactConflict = check.hasExactConflict;
  final bool hasMatches = visibleMatches.isNotEmpty;
  final int overallScore = check.closestScore;

  final String dialogTitle = hasExactConflict
      ? l10n.pharmacyDrugDuplicateDialogTitle
      : hasMatches
      ? l10n.pharmacyDrugSimilarDialogTitle
      : l10n.pharmacyDrugNoSimilarDialogTitle;
  final String bannerTitle = hasExactConflict
      ? l10n.pharmacyDrugExactBannerTitle
      : hasMatches
      ? l10n.pharmacyDrugSimilarBannerTitle
      : l10n.pharmacyDrugNoSimilarBannerTitle;
  final String bannerMessage = hasExactConflict
      ? l10n.pharmacyDrugDuplicateDialogBody
      : hasMatches
      ? l10n.pharmacyDrugSimilarDialogBody(overallScore)
      : l10n.pharmacyDrugNoSimilarDialogBody;
  final AppFormInformationVariant bannerVariant = hasExactConflict
      ? AppFormInformationVariant.error
      : hasMatches
      ? AppFormInformationVariant.warning
      : AppFormInformationVariant.success;

  final List<AppSimilarityMatch<PharmacyDrug>> matches = visibleMatches
      .map((PharmacyDrugSimilarityMatch match) {
        final List<AppSimilarityFieldRow> fields = match.fieldComparisons
            .isNotEmpty
            ? match.fieldComparisons
                  .map(
                    (PharmacyDrugFieldComparison comparison) =>
                        AppSimilarityFieldRow(
                          key: comparison.field,
                          label: _fieldLabel(comparison.field, l10n),
                          proposedValue: comparison.inputValue,
                          existingValue: comparison.candidateValue,
                          score: comparison.score,
                        ),
                  )
                  .toList(growable: false)
            : <AppSimilarityFieldRow>[
                AppSimilarityFieldRow(
                  key: 'generic_name',
                  label: l10n.pharmacyDrugGenericNameLabel,
                  proposedValue: proposed.genericName,
                  existingValue: match.drug.genericName ?? match.drug.name,
                  score:
                      match.genericScore ??
                      (match.exactIdentityConflict ? 100 : null),
                ),
                AppSimilarityFieldRow(
                  key: 'brand_name',
                  label: l10n.pharmacyDrugBrandNameLabel,
                  proposedValue: proposed.brandName,
                  existingValue: match.drug.brandName,
                  score: match.brandScore,
                ),
                AppSimilarityFieldRow(
                  key: 'code',
                  label: l10n.pharmacyDrugCodeLabel,
                  proposedValue: proposed.code,
                  existingValue: match.drug.code,
                  score:
                      match.codeScore ??
                      (match.exactCodeConflict ? 100 : null),
                ),
                AppSimilarityFieldRow(
                  key: 'form',
                  label: l10n.pharmacyDrugFormLabel,
                  proposedValue: proposed.form,
                  existingValue: match.drug.form,
                  score: match.formScore,
                ),
                AppSimilarityFieldRow(
                  key: 'strength',
                  label: l10n.pharmacyDrugStrengthLabel,
                  proposedValue: proposed.strength,
                  existingValue: match.drug.strength,
                  score: match.strengthScore,
                ),
              ];
        return AppSimilarityMatch<PharmacyDrug>(
          item: match.drug,
          title: match.drug.displayTitle,
          subtitle: match.drug.code,
          overallScore: match.score,
          isExact: match.hasExactConflict || match.isExact,
          fields: fields,
        );
      })
      .toList(growable: false);

  final AppSimilarityReviewResult<PharmacyDrug> result =
      await showAppSimilarityReviewDialog<PharmacyDrug>(
        context,
        title: dialogTitle,
        bannerTitle: bannerTitle,
        bannerMessage: bannerMessage,
        bannerVariant: bannerVariant,
        proposedFields: <AppSimilarityProposedField>[
          AppSimilarityProposedField(
            key: 'generic_name',
            label: l10n.pharmacyDrugGenericNameLabel,
            initialValue: proposed.genericName,
            isRequired: true,
          ),
          AppSimilarityProposedField(
            key: 'brand_name',
            label: l10n.pharmacyDrugBrandNameLabel,
            initialValue: proposed.brandName ?? '',
          ),
          AppSimilarityProposedField(
            key: 'code',
            label: l10n.pharmacyDrugCodeLabel,
            initialValue: proposed.code ?? '',
          ),
          AppSimilarityProposedField(
            key: 'form',
            label: l10n.pharmacyDrugFormLabel,
            initialValue: proposed.form ?? '',
          ),
          AppSimilarityProposedField(
            key: 'strength',
            label: l10n.pharmacyDrugStrengthLabel,
            initialValue: proposed.strength ?? '',
          ),
        ],
        matches: matches,
        overallScore: overallScore,
        enableReplaceExisting: true,
        proceedLabel: isEdit
            ? l10n.pharmacyDrugEditAnywayAction
            : l10n.pharmacyDrugCreateAnywayAction,
        continueLabel: l10n.commonContinueActionLabel,
        useThisLabel: l10n.pharmacyDrugUseExistingAction,
        replaceExistingLabel: l10n.pharmacyDrugReplaceExistingAction,
        proposedHeading: l10n.pharmacyDrugProposedHeading,
        matchesHeading: l10n.pharmacyDrugMatchesHeading,
        exactBadgeLabel: l10n.pharmacyDrugExactMatchLabel,
        nearBadgeLabel: l10n.pharmacyDrugNearMatchLabel,
        existingHeading: l10n.pharmacyDrugExistingHeading,
        fieldColumnLabel: l10n.pharmacyDrugFieldColumnLabel,
        proposedColumnLabel: l10n.pharmacyDrugFieldProposedLabel,
        existingColumnLabel: l10n.pharmacyDrugFieldExistingLabel,
        closestMatchLabel: l10n.pharmacyDrugOverallSimilarityLabel,
        noMatchLabel: l10n.pharmacyDrugNoMatchScoreLabel(overallScore),
        emptyValueLabel: l10n.clinicalOrderEmptyValueLabel,
        dialogIcon: hasExactConflict
            ? Icons.gpp_bad_outlined
            : hasMatches
            ? Icons.warning_amber_outlined
            : Icons.verified_outlined,
      );

  PharmacyDrugSimilarityProposedValues proposedFrom(Map<String, String> values) {
    final String generic = (values['generic_name'] ?? proposed.genericName)
        .trim();
    final String brand = (values['brand_name'] ?? proposed.brandName ?? '')
        .trim();
    final String code = (values['code'] ?? proposed.code ?? '').trim();
    final String form = (values['form'] ?? proposed.form ?? '').trim();
    final String strength = (values['strength'] ?? proposed.strength ?? '')
        .trim();
    return PharmacyDrugSimilarityProposedValues(
      genericName: generic.isEmpty ? proposed.genericName : generic,
      brandName: brand.isEmpty ? null : brand,
      code: code.isEmpty ? null : code,
      form: form.isEmpty ? null : form,
      strength: strength.isEmpty ? null : strength,
    );
  }

  switch (result.action) {
    case AppSimilarityReviewAction.cancel:
      return const PharmacyDrugSimilarityDialogResult.cancel();
    case AppSimilarityReviewAction.retry:
      return PharmacyDrugSimilarityDialogResult.retry(
        proposed: proposedFrom(result.proposedValues),
      );
    case AppSimilarityReviewAction.useExisting:
      final PharmacyDrug? drug = result.selected;
      if (drug == null) {
        return const PharmacyDrugSimilarityDialogResult.cancel();
      }
      return PharmacyDrugSimilarityDialogResult.useExisting(drug);
    case AppSimilarityReviewAction.replaceExisting:
      final PharmacyDrug? drug = result.selected;
      if (drug == null) {
        return const PharmacyDrugSimilarityDialogResult.cancel();
      }
      return PharmacyDrugSimilarityDialogResult.replaceExisting(
        drug,
        proposed: proposedFrom(result.proposedValues),
      );
    case AppSimilarityReviewAction.proceed:
      return PharmacyDrugSimilarityDialogResult.proceed(
        proposed: proposedFrom(result.proposedValues),
      );
  }
}

String _fieldLabel(String field, AppLocalizations l10n) {
  switch (field.trim().toLowerCase()) {
    case 'generic_name':
    case 'name':
      return l10n.pharmacyDrugGenericNameLabel;
    case 'brand_name':
      return l10n.pharmacyDrugBrandNameLabel;
    case 'code':
      return l10n.pharmacyDrugCodeLabel;
    case 'form':
      return l10n.pharmacyDrugFormLabel;
    case 'strength':
      return l10n.pharmacyDrugStrengthLabel;
    default:
      return field;
  }
}
