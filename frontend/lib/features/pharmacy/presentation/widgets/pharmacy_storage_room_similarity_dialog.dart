import 'package:flutter/material.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

enum PharmacyStorageRoomSimilarityAction {
  cancel,
  useExisting,
  proceed,
  retry,
}

final class PharmacyStorageRoomSimilarityDialogResult {
  const PharmacyStorageRoomSimilarityDialogResult._({
    required this.action,
    this.selectedRoom,
    this.proposed,
  });

  const PharmacyStorageRoomSimilarityDialogResult.cancel()
    : this._(action: PharmacyStorageRoomSimilarityAction.cancel);

  const PharmacyStorageRoomSimilarityDialogResult.proceed({
    PharmacyStorageRoomSimilarityProposedValues? proposed,
  }) : this._(
         action: PharmacyStorageRoomSimilarityAction.proceed,
         proposed: proposed,
       );

  const PharmacyStorageRoomSimilarityDialogResult.useExisting(
    PharmacyStorageRoom room,
  ) : this._(
        action: PharmacyStorageRoomSimilarityAction.useExisting,
        selectedRoom: room,
      );

  const PharmacyStorageRoomSimilarityDialogResult.retry({
    required PharmacyStorageRoomSimilarityProposedValues proposed,
  }) : this._(
         action: PharmacyStorageRoomSimilarityAction.retry,
         proposed: proposed,
       );

  final PharmacyStorageRoomSimilarityAction action;
  final PharmacyStorageRoom? selectedRoom;
  final PharmacyStorageRoomSimilarityProposedValues? proposed;
}

final class PharmacyStorageRoomSimilarityProposedValues {
  const PharmacyStorageRoomSimilarityProposedValues({
    required this.name,
    this.code,
    this.isActive,
  });

  final String name;
  final String? code;

  /// Present on edit flows so Active is shown with other form fields.
  final bool? isActive;
}

/// Pharmacy storage-room adapter over [showAppSimilarityReviewDialog].
Future<PharmacyStorageRoomSimilarityDialogResult>
showPharmacyStorageRoomSimilarityDialog(
  BuildContext context, {
  required PharmacyStorageRoomSimilarityProposedValues proposed,
  required PharmacyStorageRoomSimilarityResult check,
  bool isEdit = false,
}) async {
  final AppLocalizations l10n = context.l10n;
  final List<PharmacyStorageRoomSimilarityMatch> visibleMatches = check.matches
      .take(5)
      .toList(growable: false);
  final bool hasExactConflict = check.hasExactConflict;
  final bool hasMatches = visibleMatches.isNotEmpty;
  final int overallScore = check.closestScore;

  final String dialogTitle = hasExactConflict
      ? l10n.pharmacyStorageRoomDuplicateDialogTitle
      : hasMatches
      ? l10n.pharmacyStorageRoomSimilarDialogTitle
      : l10n.pharmacyStorageRoomNoSimilarDialogTitle;
  final String bannerTitle = hasExactConflict
      ? l10n.pharmacyStorageRoomExactBannerTitle
      : hasMatches
      ? l10n.pharmacyStorageRoomSimilarBannerTitle
      : l10n.pharmacyStorageRoomNoSimilarBannerTitle;
  final String bannerMessage = hasExactConflict
      ? l10n.pharmacyStorageRoomDuplicateDialogBody
      : hasMatches
      ? l10n.pharmacyStorageRoomSimilarDialogBody(overallScore)
      : l10n.pharmacyStorageRoomNoSimilarDialogBody;
  final AppFormInformationVariant bannerVariant = hasExactConflict
      ? AppFormInformationVariant.error
      : hasMatches
      ? AppFormInformationVariant.warning
      : AppFormInformationVariant.success;

  final List<AppSimilarityMatch<PharmacyStorageRoom>> matches = visibleMatches
      .map((PharmacyStorageRoomSimilarityMatch match) {
        final List<AppSimilarityFieldRow> fields = match.fieldComparisons
            .isNotEmpty
            ? match.fieldComparisons
                  .map(
                    (PharmacyStorageRoomFieldComparison comparison) =>
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
                  label: l10n.pharmacyStorageRoomNameLabel,
                  proposedValue: proposed.name,
                  existingValue: match.room.name,
                  score:
                      match.nameScore ??
                      (match.exactNameConflict ? 100 : null),
                ),
                AppSimilarityFieldRow(
                  key: 'code',
                  label: l10n.pharmacyStorageRoomCodeLabel,
                  proposedValue: proposed.code,
                  existingValue: match.room.code,
                  score:
                      match.codeScore ??
                      (match.exactCodeConflict ? 100 : null),
                ),
              ];
        return AppSimilarityMatch<PharmacyStorageRoom>(
          item: match.room,
          title: match.room.name ?? match.room.id,
          subtitle: match.room.code,
          overallScore: match.score,
          isExact: match.hasExactConflict || match.isExact,
          fields: fields,
        );
      })
      .toList(growable: false);

  final AppSimilarityReviewResult<PharmacyStorageRoom> result =
      await showAppSimilarityReviewDialog<PharmacyStorageRoom>(
        context,
        title: dialogTitle,
        bannerTitle: bannerTitle,
        bannerMessage: bannerMessage,
        bannerVariant: bannerVariant,
        proposedFields: <AppSimilarityProposedField>[
          AppSimilarityProposedField(
            key: 'name',
            label: l10n.pharmacyStorageRoomNameLabel,
            initialValue: proposed.name,
            isRequired: true,
          ),
          AppSimilarityProposedField(
            key: 'code',
            label: l10n.pharmacyStorageRoomCodeLabel,
            initialValue: proposed.code ?? '',
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
        proceedLabel: l10n.pharmacyStorageRoomCreateAnywayAction,
        continueLabel: l10n.commonContinueActionLabel,
        useThisLabel: l10n.pharmacyStorageRoomUseExistingAction,
        proposedHeading: l10n.pharmacyStorageRoomProposedHeading,
        matchesHeading: l10n.pharmacyStorageRoomMatchesHeading,
        exactBadgeLabel: l10n.pharmacyStorageRoomExactMatchLabel,
        nearBadgeLabel: l10n.pharmacyStorageRoomNearMatchLabel,
        existingHeading: l10n.pharmacyStorageRoomExistingHeading,
        fieldColumnLabel: l10n.pharmacyStorageRoomFieldColumnLabel,
        proposedColumnLabel: l10n.pharmacyStorageRoomFieldProposedLabel,
        existingColumnLabel: l10n.pharmacyStorageRoomFieldExistingLabel,
        closestMatchLabel: l10n.pharmacyStorageRoomOverallSimilarityLabel,
        noMatchLabel: l10n.pharmacyStorageRoomNoMatchScoreLabel(overallScore),
        emptyValueLabel: l10n.clinicalOrderEmptyValueLabel,
        dialogIcon: hasExactConflict
            ? Icons.gpp_bad_outlined
            : hasMatches
            ? Icons.warning_amber_outlined
            : Icons.verified_outlined,
      );

  PharmacyStorageRoomSimilarityProposedValues proposedFrom(
    Map<String, String> values,
  ) {
    final String name = (values['name'] ?? proposed.name).trim();
    final String code = (values['code'] ?? proposed.code ?? '').trim();
    return PharmacyStorageRoomSimilarityProposedValues(
      name: name.isEmpty ? proposed.name : name,
      code: code.isEmpty ? null : code,
    );
  }

  switch (result.action) {
    case AppSimilarityReviewAction.cancel:
      return const PharmacyStorageRoomSimilarityDialogResult.cancel();
    case AppSimilarityReviewAction.retry:
      return PharmacyStorageRoomSimilarityDialogResult.retry(
        proposed: proposedFrom(result.proposedValues),
      );
    case AppSimilarityReviewAction.useExisting:
      final PharmacyStorageRoom? room = result.selected;
      if (room == null) {
        return const PharmacyStorageRoomSimilarityDialogResult.cancel();
      }
      return PharmacyStorageRoomSimilarityDialogResult.useExisting(room);
    case AppSimilarityReviewAction.replaceExisting:
      return const PharmacyStorageRoomSimilarityDialogResult.cancel();
    case AppSimilarityReviewAction.proceed:
      return PharmacyStorageRoomSimilarityDialogResult.proceed(
        proposed: proposedFrom(result.proposedValues),
      );
  }
}

String _fieldLabel(String field, AppLocalizations l10n) {
  switch (field.trim().toLowerCase()) {
    case 'name':
      return l10n.pharmacyStorageRoomNameLabel;
    case 'code':
      return l10n.pharmacyStorageRoomCodeLabel;
    default:
      return field;
  }
}
