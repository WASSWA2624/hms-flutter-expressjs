import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/utils/app_display.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/bed_similarity.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'tenant_facility_setup_helpers.dart';

enum BedSimilarityAction { cancel, useExisting, proceed }

final class BedSimilarityDialogResult {
  const BedSimilarityDialogResult._({
    required this.action,
    this.selectedBed,
  });

  const BedSimilarityDialogResult.cancel()
    : this._(action: BedSimilarityAction.cancel);

  const BedSimilarityDialogResult.proceed()
    : this._(action: BedSimilarityAction.proceed);

  const BedSimilarityDialogResult.useExisting(BedProfile bed)
    : this._(action: BedSimilarityAction.useExisting, selectedBed: bed);

  final BedSimilarityAction action;
  final BedProfile? selectedBed;
}

/// Bed adapter over [showAppSimilarityReviewDialog].
Future<BedSimilarityDialogResult> showBedSimilarityDialog(
  BuildContext context, {
  required BedSimilarityProposedValues proposed,
  required List<BedSimilarityMatch> matches,
  bool allowProceed = true,
}) async {
  final AppLocalizations l10n = context.l10n;
  final List<BedSimilarityMatch> visibleMatches = matches
      .take(5)
      .toList(growable: false);
  final bool hasExactLabelConflict = visibleMatches.any(
    (BedSimilarityMatch match) => match.exactLabelConflict,
  );
  final bool hasMatches = visibleMatches.isNotEmpty;
  final bool canProceed = allowProceed && !hasExactLabelConflict;
  final int overallScore = _maxMatchScore(visibleMatches);

  final String dialogTitle = hasExactLabelConflict || hasMatches
      ? l10n.tenantFacilitySimilarBedDialogTitle
      : l10n.tenantFacilityNoSimilarBedDialogTitle;
  final String bannerTitle = hasExactLabelConflict
      ? l10n.tenantFacilityBedLabelAlreadyInUse
      : hasMatches
      ? l10n.tenantFacilitySimilarBedWarningTitle
      : l10n.tenantFacilityNoSimilarBedBannerTitle;
  final String bannerMessage = hasExactLabelConflict || hasMatches
      ? l10n.tenantFacilitySimilarBedWarningBody
      : l10n.tenantFacilityNoSimilarBedDialogBody;
  final AppFormInformationVariant bannerVariant = hasExactLabelConflict
      ? AppFormInformationVariant.error
      : hasMatches
      ? AppFormInformationVariant.warning
      : AppFormInformationVariant.success;

  final List<AppSimilarityMatch<BedProfile>> appMatches = visibleMatches
      .map((BedSimilarityMatch match) {
        final List<AppSimilarityFieldRow> fields = match.fieldComparisons
            .map(
              (BedFieldComparison comparison) => AppSimilarityFieldRow(
                key: comparison.field,
                label: _bedFieldLabel(l10n, comparison.field),
                proposedValue: _bedComparisonValue(
                  l10n,
                  comparison.field,
                  comparison.inputValue,
                ),
                existingValue: _bedComparisonValue(
                  l10n,
                  comparison.field,
                  comparison.candidateValue,
                ),
                score: comparison.score,
              ),
            )
            .toList(growable: false);
        return AppSimilarityMatch<BedProfile>(
          item: match.bed,
          title: match.bed.label,
          subtitle: _nonEmpty(match.bed.displayId),
          overallScore: match.score,
          isExact: match.exactLabelConflict,
          fields: fields,
        );
      })
      .toList(growable: false);

  final AppSimilarityReviewResult<BedProfile> result =
      await showAppSimilarityReviewDialog<BedProfile>(
        context,
        title: dialogTitle,
        bannerTitle: bannerTitle,
        bannerMessage: bannerMessage,
        bannerVariant: bannerVariant,
        proposedFields: <AppSimilarityProposedField>[
          AppSimilarityProposedField(
            key: 'label',
            label: l10n.tenantFacilityBedLabelLabel,
            initialValue: proposed.label,
            isRequired: true,
          ),
          AppSimilarityProposedField(
            key: 'ward',
            label: l10n.tenantFacilityBedWardLabel,
            initialValue: proposed.wardName ?? '',
          ),
          AppSimilarityProposedField(
            key: 'room',
            label: l10n.tenantFacilityBedRoomLabel,
            initialValue: proposed.roomName ?? '',
          ),
          AppSimilarityProposedField(
            key: 'status',
            label: l10n.tenantFacilityBedStatusLabel,
            initialValue: proposed.statusLabel,
          ),
        ],
        matches: appMatches,
        overallScore: overallScore,
        blockProceed: !canProceed,
        enableRetry: false,
        proposedReadOnly: true,
        proceedLabel: l10n.tenantFacilityProceedCreateBedAction,
        continueLabel: l10n.tenantFacilityContinueCreateBedAction,
        useThisLabel: l10n.tenantFacilityUseThisBedAction,
        proposedHeading: l10n.tenantFacilitySimilarBedProposedHeading,
        matchesHeading: l10n.tenantFacilitySimilarTenantMatchesHeading,
        exactBadgeLabel: l10n.tenantFacilitySimilarTenantExactConflictLabel,
        nearBadgeLabel: l10n.tenantFacilitySimilarTenantNearMatchLabel,
        existingHeading: l10n.tenantFacilitySimilarBedExistingHeading,
        fieldColumnLabel: l10n.tenantFacilitySimilarTenantFieldLabel,
        proposedColumnLabel: l10n.tenantFacilitySimilarTenantProposedValueLabel,
        existingColumnLabel: l10n.tenantFacilitySimilarTenantExistingValueLabel,
        closestMatchLabel: l10n.tenantFacilityBedOverallSimilarityLabel,
        noMatchLabel: l10n.tenantFacilityBedNoMatchScoreLabel(overallScore),
        emptyValueLabel: l10n.clinicalOrderEmptyValueLabel,
        dialogIcon: hasExactLabelConflict
            ? Icons.gpp_bad_outlined
            : hasMatches
            ? Icons.warning_amber_outlined
            : Icons.verified_outlined,
      );

  switch (result.action) {
    case AppSimilarityReviewAction.cancel:
    case AppSimilarityReviewAction.retry:
      return const BedSimilarityDialogResult.cancel();
    case AppSimilarityReviewAction.useExisting:
      final BedProfile? bed = result.selected;
      if (bed == null) {
        return const BedSimilarityDialogResult.cancel();
      }
      return BedSimilarityDialogResult.useExisting(bed);
    case AppSimilarityReviewAction.proceed:
      return const BedSimilarityDialogResult.proceed();
  }
}

int _maxMatchScore(List<BedSimilarityMatch> matches) {
  if (matches.isEmpty) {
    return 0;
  }
  return matches
      .map((BedSimilarityMatch match) => match.score)
      .reduce((int a, int b) => a > b ? a : b);
}

String? _nonEmpty(String? value) {
  final String trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

String _bedFieldLabel(AppLocalizations l10n, String field) {
  return switch (field) {
    'label' => l10n.tenantFacilityBedLabelLabel,
    'ward' => l10n.tenantFacilityBedWardLabel,
    'room' => l10n.tenantFacilityBedRoomLabel,
    'status' => l10n.tenantFacilityBedStatusLabel,
    _ => AppDisplay.apiLabel(field),
  };
}

String? _bedComparisonValue(
  AppLocalizations l10n,
  String field,
  String? value,
) {
  if (value == null) {
    return null;
  }
  return switch (field) {
    'status' => tenantFacilityBedStatusLabel(
      l10n,
      BedSetupStatusX.fromApiValue(value),
    ),
    _ => value,
  };
}
