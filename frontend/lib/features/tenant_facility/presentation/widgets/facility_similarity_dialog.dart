import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/utils/app_display.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/facility_similarity.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'tenant_facility_setup_helpers.dart';

enum FacilitySimilarityAction { cancel, useExisting, proceed }

final class FacilitySimilarityDialogResult {
  const FacilitySimilarityDialogResult._({
    required this.action,
    this.selectedFacility,
  });

  const FacilitySimilarityDialogResult.cancel()
    : this._(action: FacilitySimilarityAction.cancel);

  const FacilitySimilarityDialogResult.proceed()
    : this._(action: FacilitySimilarityAction.proceed);

  const FacilitySimilarityDialogResult.useExisting(FacilityProfile facility)
    : this._(
        action: FacilitySimilarityAction.useExisting,
        selectedFacility: facility,
      );

  final FacilitySimilarityAction action;
  final FacilityProfile? selectedFacility;
}

/// Facility adapter over [showAppSimilarityReviewDialog].
Future<FacilitySimilarityDialogResult> showFacilitySimilarityDialog(
  BuildContext context, {
  required FacilitySimilarityProposedValues proposed,
  required List<FacilitySimilarityMatch> matches,
  bool allowProceed = true,
}) async {
  final AppLocalizations l10n = context.l10n;
  final List<FacilitySimilarityMatch> visibleMatches = matches
      .take(5)
      .toList(growable: false);
  final bool hasExactNameConflict = visibleMatches.any(
    (FacilitySimilarityMatch match) => match.exactNameConflict,
  );
  final bool hasMatches = visibleMatches.isNotEmpty;
  final bool canProceed = allowProceed && !hasExactNameConflict;
  final int overallScore = _maxMatchScore(visibleMatches);

  final String dialogTitle = hasExactNameConflict || hasMatches
      ? l10n.tenantFacilitySimilarFacilityDialogTitle
      : l10n.tenantFacilityNoSimilarTenantDialogTitle;
  final String bannerTitle = hasExactNameConflict
      ? l10n.tenantFacilityFacilityNameAlreadyInUse
      : hasMatches
      ? l10n.tenantFacilitySimilarFacilityWarningTitle
      : l10n.tenantFacilityNoSimilarTenantBannerTitle;
  final String bannerMessage = hasExactNameConflict || hasMatches
      ? l10n.tenantFacilitySimilarFacilityWarningBody
      : l10n.tenantFacilityNoSimilarTenantDialogBody;
  final AppFormInformationVariant bannerVariant = hasExactNameConflict
      ? AppFormInformationVariant.error
      : hasMatches
      ? AppFormInformationVariant.warning
      : AppFormInformationVariant.success;

  final List<AppSimilarityMatch<FacilityProfile>> appMatches = visibleMatches
      .map((FacilitySimilarityMatch match) {
        final List<AppSimilarityFieldRow> fields = match.fieldComparisons
            .map(
              (FacilityFieldComparison comparison) => AppSimilarityFieldRow(
                key: comparison.field,
                label: _facilityFieldLabel(l10n, comparison.field),
                proposedValue: comparison.inputValue,
                existingValue: comparison.candidateValue,
                score: comparison.score,
              ),
            )
            .toList(growable: false);
        return AppSimilarityMatch<FacilityProfile>(
          item: match.facility,
          title: match.facility.name,
          subtitle: _nonEmpty(match.facility.displayId),
          overallScore: match.score,
          isExact: match.exactNameConflict,
          fields: fields,
        );
      })
      .toList(growable: false);

  final AppSimilarityReviewResult<FacilityProfile> result =
      await showAppSimilarityReviewDialog<FacilityProfile>(
        context,
        title: dialogTitle,
        bannerTitle: bannerTitle,
        bannerMessage: bannerMessage,
        bannerVariant: bannerVariant,
        proposedFields: <AppSimilarityProposedField>[
          AppSimilarityProposedField(
            key: 'name',
            label: l10n.tenantFacilityTenantNameLabel,
            initialValue: proposed.name,
            isRequired: true,
          ),
          AppSimilarityProposedField(
            key: 'facility_type',
            label: l10n.authFacilityTypeLabel,
            initialValue: tenantFacilityFacilityTypeLabel(l10n, proposed.type),
          ),
          AppSimilarityProposedField(
            key: 'status',
            label: l10n.tenantFacilityActiveLabel,
            initialValue: tenantFacilityActiveStatusLabel(
              l10n,
              proposed.isActive,
            ),
          ),
          AppSimilarityProposedField(
            key: 'phone',
            label: l10n.profilePhoneLabel,
            initialValue: proposed.phone ?? '',
          ),
          AppSimilarityProposedField(
            key: 'email',
            label: l10n.profileEmailLabel,
            initialValue: proposed.email ?? '',
          ),
          AppSimilarityProposedField(
            key: 'address_line1',
            label: l10n.tenantFacilityAddressLineLabel,
            initialValue: proposed.addressLine1 ?? '',
          ),
        ],
        matches: appMatches,
        overallScore: overallScore,
        blockProceed: !canProceed,
        enableRetry: false,
        proposedReadOnly: true,
        proceedLabel: l10n.tenantFacilityProceedCreateFacilityAction,
        continueLabel: l10n.tenantFacilityContinueCreateTenantAction,
        useThisLabel: l10n.tenantFacilityUseExistingTenantAction,
        useThisIcon: Icons.open_in_new,
        proposedHeading: l10n.tenantFacilitySimilarTenantProposedHeading,
        matchesHeading: l10n.tenantFacilitySimilarTenantMatchesHeading,
        exactBadgeLabel: l10n.tenantFacilitySimilarTenantExactConflictLabel,
        nearBadgeLabel: l10n.tenantFacilitySimilarTenantNearMatchLabel,
        existingHeading: l10n.tenantFacilitySimilarTenantExistingHeading,
        fieldColumnLabel: l10n.tenantFacilitySimilarTenantFieldLabel,
        proposedColumnLabel: l10n.tenantFacilitySimilarTenantProposedValueLabel,
        existingColumnLabel: l10n.tenantFacilitySimilarTenantExistingValueLabel,
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
      return const FacilitySimilarityDialogResult.cancel();
    case AppSimilarityReviewAction.useExisting:
      final FacilityProfile? facility = result.selected;
      if (facility == null) {
        return const FacilitySimilarityDialogResult.cancel();
      }
      return FacilitySimilarityDialogResult.useExisting(facility);
    case AppSimilarityReviewAction.replaceExisting:
      return const FacilitySimilarityDialogResult.cancel();
    case AppSimilarityReviewAction.proceed:
      return const FacilitySimilarityDialogResult.proceed();
  }
}

int _maxMatchScore(List<FacilitySimilarityMatch> matches) {
  if (matches.isEmpty) {
    return 0;
  }
  return matches
      .map((FacilitySimilarityMatch match) => match.score)
      .reduce((int a, int b) => a > b ? a : b);
}

String? _nonEmpty(String? value) {
  final String trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

String _facilityFieldLabel(AppLocalizations l10n, String field) {
  return switch (field) {
    'name' => l10n.authFacilityNameLabel,
    'facility_type' => l10n.authFacilityTypeLabel,
    'status' => l10n.tenantFacilityActiveLabel,
    'phone' => l10n.profilePhoneLabel,
    'email' => l10n.profileEmailLabel,
    'address_line1' => l10n.tenantFacilityAddressLineLabel,
    'city' => l10n.tenantFacilityCityLabel,
    'country' => l10n.tenantFacilityCountryLabel,
    'display_id' => l10n.accessAdminColumnDetails,
    _ => AppDisplay.apiLabel(field),
  };
}
