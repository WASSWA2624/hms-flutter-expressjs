import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/utils/app_display.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/ward_similarity.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'tenant_facility_setup_helpers.dart';

enum WardSimilarityAction { cancel, useExisting, proceed }

final class WardSimilarityDialogResult {
  const WardSimilarityDialogResult._({
    required this.action,
    this.selectedWard,
  });

  const WardSimilarityDialogResult.cancel()
    : this._(action: WardSimilarityAction.cancel);

  const WardSimilarityDialogResult.proceed()
    : this._(action: WardSimilarityAction.proceed);

  const WardSimilarityDialogResult.useExisting(WardProfile ward)
    : this._(action: WardSimilarityAction.useExisting, selectedWard: ward);

  final WardSimilarityAction action;
  final WardProfile? selectedWard;
}

/// Ward adapter over [showAppSimilarityReviewDialog].
Future<WardSimilarityDialogResult> showWardSimilarityDialog(
  BuildContext context, {
  required WardSimilarityProposedValues proposed,
  required List<WardSimilarityMatch> matches,
  bool allowProceed = true,
}) async {
  final AppLocalizations l10n = context.l10n;
  final List<WardSimilarityMatch> visibleMatches = matches
      .take(5)
      .toList(growable: false);
  final bool hasExactNameConflict = visibleMatches.any(
    (WardSimilarityMatch match) => match.exactNameConflict,
  );
  final bool hasMatches = visibleMatches.isNotEmpty;
  final bool canProceed = allowProceed && !hasExactNameConflict;
  final int overallScore = _maxMatchScore(visibleMatches);

  final String dialogTitle = hasExactNameConflict || hasMatches
      ? l10n.tenantFacilitySimilarWardDialogTitle
      : l10n.tenantFacilityNoSimilarWardDialogTitle;
  final String bannerTitle = hasExactNameConflict
      ? l10n.tenantFacilityWardNameAlreadyInUse
      : hasMatches
      ? l10n.tenantFacilitySimilarWardWarningTitle
      : l10n.tenantFacilityNoSimilarWardBannerTitle;
  final String bannerMessage = hasExactNameConflict || hasMatches
      ? l10n.tenantFacilitySimilarWardWarningBody
      : l10n.tenantFacilityNoSimilarWardDialogBody;
  final AppFormInformationVariant bannerVariant = hasExactNameConflict
      ? AppFormInformationVariant.error
      : hasMatches
      ? AppFormInformationVariant.warning
      : AppFormInformationVariant.success;

  final List<AppSimilarityMatch<WardProfile>> appMatches = visibleMatches
      .map((WardSimilarityMatch match) {
        final List<AppSimilarityFieldRow> fields = match.fieldComparisons
            .map(
              (WardFieldComparison comparison) => AppSimilarityFieldRow(
                key: comparison.field,
                label: _wardFieldLabel(l10n, comparison.field),
                proposedValue: _wardComparisonValue(
                  l10n,
                  comparison.field,
                  comparison.inputValue,
                ),
                existingValue: _wardComparisonValue(
                  l10n,
                  comparison.field,
                  comparison.candidateValue,
                ),
                score: comparison.score,
              ),
            )
            .toList(growable: false);
        return AppSimilarityMatch<WardProfile>(
          item: match.ward,
          title: match.ward.name,
          subtitle: _nonEmpty(match.ward.displayId),
          overallScore: match.score,
          isExact: match.exactNameConflict,
          fields: fields,
        );
      })
      .toList(growable: false);

  final AppSimilarityReviewResult<WardProfile> result =
      await showAppSimilarityReviewDialog<WardProfile>(
        context,
        title: dialogTitle,
        bannerTitle: bannerTitle,
        bannerMessage: bannerMessage,
        bannerVariant: bannerVariant,
        proposedFields: <AppSimilarityProposedField>[
          AppSimilarityProposedField(
            key: 'name',
            label: l10n.tenantFacilityWardNameLabel,
            initialValue: proposed.name,
            isRequired: true,
          ),
          AppSimilarityProposedField(
            key: 'type',
            label: l10n.tenantFacilityWardTypeLabel,
            initialValue: tenantFacilityWardTypeLabel(l10n, proposed.type),
          ),
          AppSimilarityProposedField(
            key: 'department',
            label: l10n.tenantFacilityWardDepartmentLabel,
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
        proceedLabel: l10n.tenantFacilityProceedCreateWardAction,
        continueLabel: l10n.tenantFacilityContinueCreateWardAction,
        useThisLabel: l10n.tenantFacilityUseThisWardAction,
        proposedHeading: l10n.tenantFacilitySimilarWardProposedHeading,
        matchesHeading: l10n.tenantFacilitySimilarTenantMatchesHeading,
        exactBadgeLabel: l10n.tenantFacilitySimilarTenantExactConflictLabel,
        nearBadgeLabel: l10n.tenantFacilitySimilarTenantNearMatchLabel,
        existingHeading: l10n.tenantFacilitySimilarWardExistingHeading,
        fieldColumnLabel: l10n.tenantFacilitySimilarTenantFieldLabel,
        proposedColumnLabel: l10n.tenantFacilitySimilarTenantProposedValueLabel,
        existingColumnLabel: l10n.tenantFacilitySimilarTenantExistingValueLabel,
        closestMatchLabel: l10n.tenantFacilityWardOverallSimilarityLabel,
        noMatchLabel: l10n.tenantFacilityWardNoMatchScoreLabel(overallScore),
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
      return const WardSimilarityDialogResult.cancel();
    case AppSimilarityReviewAction.useExisting:
      final WardProfile? ward = result.selected;
      if (ward == null) {
        return const WardSimilarityDialogResult.cancel();
      }
      return WardSimilarityDialogResult.useExisting(ward);
    case AppSimilarityReviewAction.proceed:
      return const WardSimilarityDialogResult.proceed();
  }
}

int _maxMatchScore(List<WardSimilarityMatch> matches) {
  if (matches.isEmpty) {
    return 0;
  }
  return matches
      .map((WardSimilarityMatch match) => match.score)
      .reduce((int a, int b) => a > b ? a : b);
}

String? _nonEmpty(String? value) {
  final String trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

String _wardFieldLabel(AppLocalizations l10n, String field) {
  return switch (field) {
    'name' => l10n.tenantFacilityWardNameLabel,
    'type' => l10n.tenantFacilityWardTypeLabel,
    'department' => l10n.tenantFacilityWardDepartmentLabel,
    'status' => l10n.tenantFacilityActiveLabel,
    _ => AppDisplay.apiLabel(field),
  };
}

String? _wardComparisonValue(
  AppLocalizations l10n,
  String field,
  String? value,
) {
  if (value == null) {
    return null;
  }
  return switch (field) {
    'type' => tenantFacilityWardTypeLabel(
      l10n,
      WardSetupTypeX.fromApiValue(value),
    ),
    'status' => tenantFacilityActiveStatusLabel(
      l10n,
      value.trim().toLowerCase() == 'active',
    ),
    _ => value,
  };
}
