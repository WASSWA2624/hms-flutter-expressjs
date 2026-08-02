import 'package:flutter/material.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

enum PharmacyStorageShelfSimilarityAction {
  cancel,
  useExisting,
  proceed,
  retry,
}

final class PharmacyStorageShelfSimilarityDialogResult {
  const PharmacyStorageShelfSimilarityDialogResult._({
    required this.action,
    this.selectedShelf,
    this.proposed,
  });

  const PharmacyStorageShelfSimilarityDialogResult.cancel()
    : this._(action: PharmacyStorageShelfSimilarityAction.cancel);

  const PharmacyStorageShelfSimilarityDialogResult.proceed({
    PharmacyStorageShelfSimilarityProposedValues? proposed,
  }) : this._(
         action: PharmacyStorageShelfSimilarityAction.proceed,
         proposed: proposed,
       );

  const PharmacyStorageShelfSimilarityDialogResult.useExisting(
    PharmacyStorageShelf shelf,
  ) : this._(
        action: PharmacyStorageShelfSimilarityAction.useExisting,
        selectedShelf: shelf,
      );

  const PharmacyStorageShelfSimilarityDialogResult.retry({
    required PharmacyStorageShelfSimilarityProposedValues proposed,
  }) : this._(
         action: PharmacyStorageShelfSimilarityAction.retry,
         proposed: proposed,
       );

  final PharmacyStorageShelfSimilarityAction action;
  final PharmacyStorageShelf? selectedShelf;
  final PharmacyStorageShelfSimilarityProposedValues? proposed;
}

final class PharmacyStorageShelfSimilarityProposedValues {
  const PharmacyStorageShelfSimilarityProposedValues({
    required this.label,
    this.shelfCode,
    this.isActive,
  });

  final String label;
  final String? shelfCode;

  /// Present on edit flows so Active is shown with other form fields.
  final bool? isActive;
}

/// Pharmacy storage-shelf adapter over [showAppSimilarityReviewDialog].
/// Peers are expected to already be scoped to the selected room by the API.
Future<PharmacyStorageShelfSimilarityDialogResult>
showPharmacyStorageShelfSimilarityDialog(
  BuildContext context, {
  required PharmacyStorageShelfSimilarityProposedValues proposed,
  required PharmacyStorageShelfSimilarityResult check,
  bool isEdit = false,
}) async {
  final AppLocalizations l10n = context.l10n;
  final List<PharmacyStorageShelfSimilarityMatch> visibleMatches = check.matches
      .take(5)
      .toList(growable: false);
  final bool hasExactConflict = check.hasExactConflict;
  final bool hasMatches = visibleMatches.isNotEmpty;
  final int overallScore = check.closestScore;

  final String dialogTitle = hasExactConflict
      ? l10n.pharmacyStorageShelfDuplicateDialogTitle
      : hasMatches
      ? l10n.pharmacyStorageShelfSimilarDialogTitle
      : l10n.pharmacyStorageShelfNoSimilarDialogTitle;
  final String bannerTitle = hasExactConflict
      ? l10n.pharmacyStorageShelfExactBannerTitle
      : hasMatches
      ? l10n.pharmacyStorageShelfSimilarBannerTitle
      : l10n.pharmacyStorageShelfNoSimilarBannerTitle;
  final String bannerMessage = hasExactConflict
      ? l10n.pharmacyStorageShelfDuplicateDialogBody
      : hasMatches
      ? l10n.pharmacyStorageShelfSimilarDialogBody(overallScore)
      : l10n.pharmacyStorageShelfNoSimilarDialogBody;
  final AppFormInformationVariant bannerVariant = hasExactConflict
      ? AppFormInformationVariant.error
      : hasMatches
      ? AppFormInformationVariant.warning
      : AppFormInformationVariant.success;

  final List<AppSimilarityMatch<PharmacyStorageShelf>> matches = visibleMatches
      .map((PharmacyStorageShelfSimilarityMatch match) {
        final List<AppSimilarityFieldRow> fields = match.fieldComparisons
            .isNotEmpty
            ? match.fieldComparisons
                  .map(
                    (PharmacyStorageShelfFieldComparison comparison) =>
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
                  key: 'label',
                  label: l10n.pharmacyStorageShelfLabelField,
                  proposedValue: proposed.label,
                  existingValue: match.shelf.label,
                  score:
                      match.labelScore ??
                      (match.exactLabelConflict ? 100 : null),
                ),
                AppSimilarityFieldRow(
                  key: 'shelf_code',
                  label: l10n.pharmacyStorageShelfCodeLabel,
                  proposedValue: proposed.shelfCode,
                  existingValue: match.shelf.shelfCode,
                  score:
                      match.codeScore ??
                      (match.exactCodeConflict ? 100 : null),
                ),
              ];
        return AppSimilarityMatch<PharmacyStorageShelf>(
          item: match.shelf,
          title: (match.shelf.label ?? '').trim().isNotEmpty
              ? match.shelf.label!.trim()
              : match.shelf.displayLabel,
          subtitle: match.shelf.shelfCode,
          overallScore: match.score,
          isExact: match.hasExactConflict || match.isExact,
          fields: fields,
        );
      })
      .toList(growable: false);

  final AppSimilarityReviewResult<PharmacyStorageShelf> result =
      await showAppSimilarityReviewDialog<PharmacyStorageShelf>(
        context,
        title: dialogTitle,
        bannerTitle: bannerTitle,
        bannerMessage: bannerMessage,
        bannerVariant: bannerVariant,
        proposedFields: <AppSimilarityProposedField>[
          AppSimilarityProposedField(
            key: 'label',
            label: l10n.pharmacyStorageShelfLabelField,
            initialValue: proposed.label,
            isRequired: true,
          ),
          AppSimilarityProposedField(
            key: 'shelf_code',
            label: l10n.pharmacyStorageShelfCodeLabel,
            initialValue: proposed.shelfCode ?? '',
          ),
          if (proposed.isActive != null)
            AppSimilarityProposedField(
              key: 'is_active',
              label: l10n.pharmacyStorageActiveLabel,
              initialValue: proposed.isActive!
                  ? l10n.commonYesLabel
                  : l10n.commonNoLabel,
              editable: false,
            ),
        ],
        matches: matches,
        overallScore: overallScore,
        blockProceed: hasExactConflict,
        proceedLabel: l10n.pharmacyStorageShelfCreateAnywayAction,
        continueLabel: l10n.commonContinueActionLabel,
        useThisLabel: l10n.pharmacyStorageShelfUseExistingAction,
        proposedHeading: l10n.pharmacyStorageShelfProposedHeading,
        matchesHeading: l10n.pharmacyStorageShelfMatchesHeading,
        exactBadgeLabel: l10n.pharmacyStorageShelfExactMatchLabel,
        nearBadgeLabel: l10n.pharmacyStorageShelfNearMatchLabel,
        existingHeading: l10n.pharmacyStorageShelfExistingHeading,
        fieldColumnLabel: l10n.pharmacyStorageShelfFieldColumnLabel,
        proposedColumnLabel: l10n.pharmacyStorageShelfFieldProposedLabel,
        existingColumnLabel: l10n.pharmacyStorageShelfFieldExistingLabel,
        closestMatchLabel: l10n.pharmacyStorageShelfOverallSimilarityLabel,
        noMatchLabel: l10n.pharmacyStorageShelfNoMatchScoreLabel(overallScore),
        emptyValueLabel: l10n.clinicalOrderEmptyValueLabel,
        dialogIcon: hasExactConflict
            ? Icons.gpp_bad_outlined
            : hasMatches
            ? Icons.warning_amber_outlined
            : Icons.verified_outlined,
      );

  PharmacyStorageShelfSimilarityProposedValues proposedFrom(
    Map<String, String> values,
  ) {
    final String label = (values['label'] ?? proposed.label).trim();
    final String code = (values['shelf_code'] ?? proposed.shelfCode ?? '')
        .trim();
    return PharmacyStorageShelfSimilarityProposedValues(
      label: label.isEmpty ? proposed.label : label,
      shelfCode: code.isEmpty ? null : code,
    );
  }

  switch (result.action) {
    case AppSimilarityReviewAction.cancel:
      return const PharmacyStorageShelfSimilarityDialogResult.cancel();
    case AppSimilarityReviewAction.retry:
      return PharmacyStorageShelfSimilarityDialogResult.retry(
        proposed: proposedFrom(result.proposedValues),
      );
    case AppSimilarityReviewAction.useExisting:
      final PharmacyStorageShelf? shelf = result.selected;
      if (shelf == null) {
        return const PharmacyStorageShelfSimilarityDialogResult.cancel();
      }
      return PharmacyStorageShelfSimilarityDialogResult.useExisting(shelf);
    case AppSimilarityReviewAction.proceed:
      return PharmacyStorageShelfSimilarityDialogResult.proceed(
        proposed: proposedFrom(result.proposedValues),
      );
  }
}

String _fieldLabel(String field, AppLocalizations l10n) {
  switch (field.trim().toLowerCase()) {
    case 'label':
      return l10n.pharmacyStorageShelfLabelField;
    case 'shelf_code':
    case 'code':
      return l10n.pharmacyStorageShelfCodeLabel;
    default:
      return field;
  }
}
