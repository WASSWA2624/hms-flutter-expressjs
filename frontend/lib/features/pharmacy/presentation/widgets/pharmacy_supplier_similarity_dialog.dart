import 'package:flutter/material.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

enum PharmacySupplierSimilarityAction {
  cancel,
  useExisting,
  proceed,
  retry,
}

final class PharmacySupplierSimilarityDialogResult {
  const PharmacySupplierSimilarityDialogResult._({
    required this.action,
    this.selectedSupplier,
    this.proposed,
  });

  const PharmacySupplierSimilarityDialogResult.cancel()
    : this._(action: PharmacySupplierSimilarityAction.cancel);

  const PharmacySupplierSimilarityDialogResult.proceed({
    PharmacySupplierSimilarityProposedValues? proposed,
  }) : this._(
         action: PharmacySupplierSimilarityAction.proceed,
         proposed: proposed,
       );

  const PharmacySupplierSimilarityDialogResult.useExisting(
    PharmacySupplier supplier,
  ) : this._(
        action: PharmacySupplierSimilarityAction.useExisting,
        selectedSupplier: supplier,
      );

  const PharmacySupplierSimilarityDialogResult.retry({
    required PharmacySupplierSimilarityProposedValues proposed,
  }) : this._(
         action: PharmacySupplierSimilarityAction.retry,
         proposed: proposed,
       );

  final PharmacySupplierSimilarityAction action;
  final PharmacySupplier? selectedSupplier;
  final PharmacySupplierSimilarityProposedValues? proposed;
}

final class PharmacySupplierSimilarityProposedValues {
  const PharmacySupplierSimilarityProposedValues({
    required this.name,
    this.location,
    this.contactEmail,
    this.phone,
  });

  final String name;
  final String? location;
  final String? contactEmail;
  final String? phone;
}

/// Pharmacy supplier adapter over [showAppSimilarityReviewDialog].
Future<PharmacySupplierSimilarityDialogResult>
showPharmacySupplierSimilarityDialog(
  BuildContext context, {
  required PharmacySupplierSimilarityProposedValues proposed,
  required PharmacySupplierSimilarityResult check,
  bool isEdit = false,
}) async {
  final AppLocalizations l10n = context.l10n;
  final List<PharmacySupplierSimilarityMatch> visibleMatches = check.matches
      .take(5)
      .toList(growable: false);
  final bool hasExactConflict = check.hasExactConflict;
  final bool hasMatches = visibleMatches.isNotEmpty;
  final int overallScore = check.closestScore;

  final String dialogTitle = hasExactConflict
      ? l10n.pharmacySupplierDuplicateDialogTitle
      : hasMatches
      ? l10n.pharmacySupplierSimilarDialogTitle
      : l10n.pharmacySupplierNoSimilarDialogTitle;
  final String bannerTitle = hasExactConflict
      ? l10n.pharmacySupplierExactBannerTitle
      : hasMatches
      ? l10n.pharmacySupplierSimilarBannerTitle
      : l10n.pharmacySupplierNoSimilarBannerTitle;
  final String bannerMessage = hasExactConflict
      ? l10n.pharmacySupplierDuplicateDialogBody
      : hasMatches
      ? l10n.pharmacySupplierSimilarDialogBody(overallScore)
      : l10n.pharmacySupplierNoSimilarDialogBody;
  final AppFormInformationVariant bannerVariant = hasExactConflict
      ? AppFormInformationVariant.error
      : hasMatches
      ? AppFormInformationVariant.warning
      : AppFormInformationVariant.success;

  final List<AppSimilarityMatch<PharmacySupplier>> matches = visibleMatches
      .map((PharmacySupplierSimilarityMatch match) {
        final List<AppSimilarityFieldRow> fields = match.fieldComparisons
            .isNotEmpty
            ? match.fieldComparisons
                  .map(
                    (PharmacySupplierFieldComparison comparison) =>
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
                  key: 'name',
                  label: l10n.pharmacySupplierNameLabel,
                  proposedValue: proposed.name,
                  existingValue: match.supplier.name,
                  score:
                      match.nameScore ??
                      (match.exactNameConflict ? 100 : null),
                ),
                AppSimilarityFieldRow(
                  key: 'location',
                  label: l10n.pharmacySupplierLocationLabel,
                  proposedValue: proposed.location,
                  existingValue: match.supplier.location,
                  score: match.locationScore,
                ),
                AppSimilarityFieldRow(
                  key: 'contact_email',
                  label: l10n.pharmacySupplierEmailLabel,
                  proposedValue: proposed.contactEmail,
                  existingValue: match.supplier.contactEmail,
                  score:
                      match.emailScore ??
                      (match.exactEmailConflict ? 100 : null),
                ),
                AppSimilarityFieldRow(
                  key: 'phone',
                  label: l10n.pharmacySupplierPhoneLabel,
                  proposedValue: proposed.phone,
                  existingValue: match.supplier.phone,
                  score:
                      match.phoneScore ??
                      (match.exactPhoneConflict ? 100 : null),
                ),
              ];
        return AppSimilarityMatch<PharmacySupplier>(
          item: match.supplier,
          title: match.supplier.primaryName.isEmpty
              ? match.supplier.id
              : match.supplier.primaryName,
          subtitle: match.supplier.contactEmail ?? match.supplier.phone,
          overallScore: match.score,
          isExact: match.hasExactConflict || match.isExact,
          fields: fields,
        );
      })
      .toList(growable: false);

  final AppSimilarityReviewResult<PharmacySupplier> result =
      await showAppSimilarityReviewDialog<PharmacySupplier>(
        context,
        title: dialogTitle,
        bannerTitle: bannerTitle,
        bannerMessage: bannerMessage,
        bannerVariant: bannerVariant,
        proposedFields: <AppSimilarityProposedField>[
          AppSimilarityProposedField(
            key: 'name',
            label: l10n.pharmacySupplierNameLabel,
            initialValue: proposed.name,
            isRequired: true,
          ),
          AppSimilarityProposedField(
            key: 'location',
            label: l10n.pharmacySupplierLocationLabel,
            initialValue: proposed.location ?? '',
          ),
          AppSimilarityProposedField(
            key: 'contact_email',
            label: l10n.pharmacySupplierEmailLabel,
            initialValue: proposed.contactEmail ?? '',
          ),
          AppSimilarityProposedField(
            key: 'phone',
            label: l10n.pharmacySupplierPhoneLabel,
            initialValue: proposed.phone ?? '',
          ),
        ],
        matches: matches,
        overallScore: overallScore,
        proceedLabel: isEdit
            ? l10n.pharmacySupplierSaveAnywayAction
            : l10n.pharmacySupplierCreateAnywayAction,
        continueLabel: l10n.commonContinueActionLabel,
        useThisLabel: l10n.pharmacySupplierUseExistingAction,
        proposedHeading: l10n.pharmacySupplierProposedHeading,
        matchesHeading: l10n.pharmacySupplierMatchesHeading,
        exactBadgeLabel: l10n.pharmacySupplierExactMatchLabel,
        nearBadgeLabel: l10n.pharmacySupplierNearMatchLabel,
        existingHeading: l10n.pharmacySupplierExistingHeading,
        fieldColumnLabel: l10n.pharmacySupplierFieldColumnLabel,
        proposedColumnLabel: l10n.pharmacySupplierFieldProposedLabel,
        existingColumnLabel: l10n.pharmacySupplierFieldExistingLabel,
        closestMatchLabel: l10n.pharmacySupplierOverallSimilarityLabel,
        noMatchLabel: l10n.pharmacySupplierNoMatchScoreLabel(overallScore),
        emptyValueLabel: l10n.clinicalOrderEmptyValueLabel,
        dialogIcon: hasExactConflict
            ? Icons.gpp_bad_outlined
            : hasMatches
            ? Icons.warning_amber_outlined
            : Icons.verified_outlined,
      );

  PharmacySupplierSimilarityProposedValues proposedFrom(
    Map<String, String> values,
  ) {
    final String name = (values['name'] ?? proposed.name).trim();
    final String location =
        (values['location'] ?? proposed.location ?? '').trim();
    final String email =
        (values['contact_email'] ?? proposed.contactEmail ?? '').trim();
    final String phone = (values['phone'] ?? proposed.phone ?? '').trim();
    return PharmacySupplierSimilarityProposedValues(
      name: name.isEmpty ? proposed.name : name,
      location: location.isEmpty ? null : location,
      contactEmail: email.isEmpty ? null : email,
      phone: phone.isEmpty ? null : phone,
    );
  }

  switch (result.action) {
    case AppSimilarityReviewAction.cancel:
      return const PharmacySupplierSimilarityDialogResult.cancel();
    case AppSimilarityReviewAction.retry:
      return PharmacySupplierSimilarityDialogResult.retry(
        proposed: proposedFrom(result.proposedValues),
      );
    case AppSimilarityReviewAction.useExisting:
      final PharmacySupplier? supplier = result.selected;
      if (supplier == null) {
        return const PharmacySupplierSimilarityDialogResult.cancel();
      }
      return PharmacySupplierSimilarityDialogResult.useExisting(supplier);
    case AppSimilarityReviewAction.replaceExisting:
      return const PharmacySupplierSimilarityDialogResult.cancel();
    case AppSimilarityReviewAction.proceed:
      return PharmacySupplierSimilarityDialogResult.proceed(
        proposed: proposedFrom(result.proposedValues),
      );
  }
}

String _fieldLabel(String field, AppLocalizations l10n) {
  switch (field.trim().toLowerCase()) {
    case 'name':
      return l10n.pharmacySupplierNameLabel;
    case 'location':
      return l10n.pharmacySupplierLocationLabel;
    case 'contact_email':
    case 'email':
      return l10n.pharmacySupplierEmailLabel;
    case 'phone':
      return l10n.pharmacySupplierPhoneLabel;
    default:
      return field;
  }
}
