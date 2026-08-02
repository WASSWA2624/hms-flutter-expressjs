import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/utils/app_display.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/unit_similarity.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'tenant_facility_setup_helpers.dart';

enum UnitSimilarityAction { cancel, useExisting, proceed }

final class UnitSimilarityDialogResult {
  const UnitSimilarityDialogResult._({
    required this.action,
    this.selectedUnit,
  });

  const UnitSimilarityDialogResult.cancel()
    : this._(action: UnitSimilarityAction.cancel);

  const UnitSimilarityDialogResult.proceed()
    : this._(action: UnitSimilarityAction.proceed);

  const UnitSimilarityDialogResult.useExisting(UnitProfile unit)
    : this._(action: UnitSimilarityAction.useExisting, selectedUnit: unit);

  final UnitSimilarityAction action;
  final UnitProfile? selectedUnit;
}

/// Unit adapter over [showAppSimilarityReviewDialog].
Future<UnitSimilarityDialogResult> showUnitSimilarityDialog(
  BuildContext context, {
  required UnitSimilarityProposedValues proposed,
  required List<UnitSimilarityMatch> matches,
  bool allowProceed = true,
}) async {
  final AppLocalizations l10n = context.l10n;
  final List<UnitSimilarityMatch> visibleMatches = matches
      .take(5)
      .toList(growable: false);
  final bool hasExactNameConflict = visibleMatches.any(
    (UnitSimilarityMatch match) => match.exactNameConflict,
  );
  final bool hasMatches = visibleMatches.isNotEmpty;
  final bool canProceed = allowProceed && !hasExactNameConflict;
  final int overallScore = _maxMatchScore(visibleMatches);

  final String dialogTitle = hasExactNameConflict || hasMatches
      ? l10n.tenantFacilitySimilarUnitDialogTitle
      : l10n.tenantFacilityNoSimilarUnitDialogTitle;
  final String bannerTitle = hasExactNameConflict
      ? l10n.tenantFacilityUnitNameAlreadyInUse
      : hasMatches
      ? l10n.tenantFacilitySimilarUnitWarningTitle
      : l10n.tenantFacilityNoSimilarUnitBannerTitle;
  final String bannerMessage = hasExactNameConflict || hasMatches
      ? l10n.tenantFacilitySimilarUnitWarningBody
      : l10n.tenantFacilityNoSimilarUnitDialogBody;
  final AppFormInformationVariant bannerVariant = hasExactNameConflict
      ? AppFormInformationVariant.error
      : hasMatches
      ? AppFormInformationVariant.warning
      : AppFormInformationVariant.success;

  final List<AppSimilarityMatch<UnitProfile>> appMatches = visibleMatches
      .map((UnitSimilarityMatch match) {
        final List<AppSimilarityFieldRow> fields = match.fieldComparisons
            .map(
              (UnitFieldComparison comparison) => AppSimilarityFieldRow(
                key: comparison.field,
                label: _unitFieldLabel(l10n, comparison.field),
                proposedValue: _unitComparisonValue(
                  l10n,
                  comparison.field,
                  comparison.inputValue,
                ),
                existingValue: _unitComparisonValue(
                  l10n,
                  comparison.field,
                  comparison.candidateValue,
                ),
                score: comparison.score,
              ),
            )
            .toList(growable: false);
        return AppSimilarityMatch<UnitProfile>(
          item: match.unit,
          title: match.unit.name,
          subtitle: _nonEmpty(match.unit.displayId),
          overallScore: match.score,
          isExact: match.exactNameConflict,
          fields: fields,
        );
      })
      .toList(growable: false);

  final AppSimilarityReviewResult<UnitProfile> result =
      await showAppSimilarityReviewDialog<UnitProfile>(
        context,
        title: dialogTitle,
        bannerTitle: bannerTitle,
        bannerMessage: bannerMessage,
        bannerVariant: bannerVariant,
        proposedFields: <AppSimilarityProposedField>[
          AppSimilarityProposedField(
            key: 'name',
            label: l10n.tenantFacilityUnitNameLabel,
            initialValue: proposed.name,
            isRequired: true,
          ),
          AppSimilarityProposedField(
            key: 'department',
            label: l10n.tenantFacilityUnitDepartmentLabel,
            initialValue: proposed.departmentName ?? '',
          ),
          AppSimilarityProposedField(
            key: 'status',
            label: l10n.tenantFacilityActiveLabel,
            initialValue: tenantFacilityActiveStatusLabel(
              l10n,
              proposed.isActive,
            ),
          ),
        ],
        matches: appMatches,
        overallScore: overallScore,
        blockProceed: !canProceed,
        enableRetry: false,
        proposedReadOnly: true,
        proceedLabel: l10n.tenantFacilityProceedCreateUnitAction,
        continueLabel: l10n.tenantFacilityContinueCreateUnitAction,
        useThisLabel: l10n.tenantFacilityUseThisUnitAction,
        proposedHeading: l10n.tenantFacilitySimilarUnitProposedHeading,
        matchesHeading: l10n.tenantFacilitySimilarTenantMatchesHeading,
        exactBadgeLabel: l10n.tenantFacilitySimilarTenantExactConflictLabel,
        nearBadgeLabel: l10n.tenantFacilitySimilarTenantNearMatchLabel,
        existingHeading: l10n.tenantFacilitySimilarUnitExistingHeading,
        fieldColumnLabel: l10n.tenantFacilitySimilarTenantFieldLabel,
        proposedColumnLabel: l10n.tenantFacilitySimilarTenantProposedValueLabel,
        existingColumnLabel: l10n.tenantFacilitySimilarTenantExistingValueLabel,
        closestMatchLabel: l10n.tenantFacilityUnitOverallSimilarityLabel,
        noMatchLabel: l10n.tenantFacilityUnitNoMatchScoreLabel(overallScore),
        emptyValueLabel: l10n.clinicalOrderEmptyValueLabel,
        dialogIcon: hasExactNameConflict
            ? Icons.gpp_bad_outlined
            : hasMatches
            ? Icons.warning_amber_outlined
            : Icons.verified_outlined,
      );

  switch (result.action) {
    case AppSimilarityReviewAction.cancel:
    case AppSimilarityReviewAction.retry:
      return const UnitSimilarityDialogResult.cancel();
    case AppSimilarityReviewAction.useExisting:
      final UnitProfile? unit = result.selected;
      if (unit == null) {
        return const UnitSimilarityDialogResult.cancel();
      }
      return UnitSimilarityDialogResult.useExisting(unit);
    case AppSimilarityReviewAction.proceed:
      return const UnitSimilarityDialogResult.proceed();
  }
}

int _maxMatchScore(List<UnitSimilarityMatch> matches) {
  if (matches.isEmpty) {
    return 0;
  }
  return matches
      .map((UnitSimilarityMatch match) => match.score)
      .reduce((int a, int b) => a > b ? a : b);
}

String? _nonEmpty(String? value) {
  final String trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

String _unitFieldLabel(AppLocalizations l10n, String field) {
  return switch (field) {
    'name' => l10n.tenantFacilityUnitNameLabel,
    'department' => l10n.tenantFacilityUnitDepartmentLabel,
    'status' => l10n.tenantFacilityActiveLabel,
    _ => AppDisplay.apiLabel(field),
  };
}

String? _unitComparisonValue(
  AppLocalizations l10n,
  String field,
  String? value,
) {
  if (value == null) {
    return null;
  }
  return switch (field) {
    'status' => tenantFacilityActiveStatusLabel(
      l10n,
      value.trim().toLowerCase() == 'active',
    ),
    _ => value,
  };
}
