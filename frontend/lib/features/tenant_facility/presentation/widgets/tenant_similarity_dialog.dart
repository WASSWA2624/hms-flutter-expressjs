import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/utils/app_display.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_similarity.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

enum TenantSimilarityAction { cancel, useExisting, proceed }

final class TenantSimilarityProposedValues {
  const TenantSimilarityProposedValues({
    required this.name,
    this.slug,
    this.contactName,
    this.contactPhone,
    this.contactEmail,
    this.currency,
    this.standardConsultationFee,
  });

  final String name;
  final String? slug;
  final String? contactName;
  final String? contactPhone;
  final String? contactEmail;
  final String? currency;
  final String? standardConsultationFee;
}

final class TenantSimilarityDialogResult {
  const TenantSimilarityDialogResult._({
    required this.action,
    this.selectedTenant,
  });

  const TenantSimilarityDialogResult.cancel()
    : this._(action: TenantSimilarityAction.cancel);

  const TenantSimilarityDialogResult.proceed()
    : this._(action: TenantSimilarityAction.proceed);

  const TenantSimilarityDialogResult.useExisting(TenantProfile tenant)
    : this._(
        action: TenantSimilarityAction.useExisting,
        selectedTenant: tenant,
      );

  final TenantSimilarityAction action;
  final TenantProfile? selectedTenant;
}

/// Tenant adapter over [showAppSimilarityReviewDialog].
Future<TenantSimilarityDialogResult> showTenantSimilarityDialog(
  BuildContext context, {
  required TenantSimilarityProposedValues proposed,
  required List<TenantSimilarityMatch> matches,
  bool allowProceed = true,
}) async {
  final AppLocalizations l10n = context.l10n;
  final List<TenantSimilarityMatch> visibleMatches = matches
      .take(5)
      .toList(growable: false);
  final bool hasExactSlugConflict = visibleMatches.any(
    (TenantSimilarityMatch match) => match.exactSlugConflict,
  );
  final bool hasMatches = visibleMatches.isNotEmpty;
  final bool canProceed = allowProceed && !hasExactSlugConflict;
  final TenantSimilarityMatch? topMatch = visibleMatches.isEmpty
      ? null
      : visibleMatches.first;
  final int overallScore = topMatch?.score ?? 0;

  final String dialogTitle = hasExactSlugConflict || hasMatches
      ? l10n.tenantFacilitySimilarTenantDialogTitle
      : l10n.tenantFacilityNoSimilarTenantDialogTitle;
  final String bannerTitle = hasExactSlugConflict
      ? l10n.tenantFacilityTenantSlugAlreadyInUse
      : hasMatches
      ? l10n.tenantFacilitySimilarTenantWarningTitle
      : l10n.tenantFacilityNoSimilarTenantBannerTitle;
  final String bannerMessage = hasExactSlugConflict
      ? l10n.tenantFacilitySimilarTenantHardConflictBody
      : hasMatches
      ? l10n.tenantFacilitySimilarTenantReviewBannerBody(overallScore)
      : l10n.tenantFacilityNoSimilarTenantDialogBody;
  final AppFormInformationVariant bannerVariant = hasExactSlugConflict
      ? AppFormInformationVariant.error
      : hasMatches
      ? AppFormInformationVariant.warning
      : AppFormInformationVariant.success;

  final List<AppSimilarityMatch<TenantProfile>> appMatches = visibleMatches
      .map((TenantSimilarityMatch match) {
        final List<AppSimilarityFieldRow> fields = match.fieldComparisons
            .map(
              (TenantFieldComparison comparison) => AppSimilarityFieldRow(
                key: comparison.field,
                label: _tenantFieldLabel(l10n, comparison.field),
                proposedValue: comparison.inputValue,
                existingValue: comparison.candidateValue,
                score: comparison.score,
              ),
            )
            .toList(growable: false);
        return AppSimilarityMatch<TenantProfile>(
          item: match.tenant,
          title: match.tenant.name,
          subtitle: _nonEmpty(match.tenant.displayId),
          overallScore: match.score,
          isExact: match.exactSlugConflict,
          fields: fields,
        );
      })
      .toList(growable: false);

  final AppSimilarityReviewResult<TenantProfile> result =
      await showAppSimilarityReviewDialog<TenantProfile>(
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
            key: 'slug',
            label: l10n.tenantFacilityTenantSlugLabel,
            initialValue: proposed.slug ?? '',
          ),
          AppSimilarityProposedField(
            key: 'contact_name',
            label: l10n.tenantFacilityTenantDetailsContactNameLabel,
            initialValue: proposed.contactName ?? '',
          ),
          AppSimilarityProposedField(
            key: 'contact_phone',
            label: l10n.profilePhoneLabel,
            initialValue: proposed.contactPhone ?? '',
          ),
          AppSimilarityProposedField(
            key: 'contact_email',
            label: l10n.profileEmailLabel,
            initialValue: proposed.contactEmail ?? '',
          ),
          AppSimilarityProposedField(
            key: 'currency',
            label: l10n.tenantFacilityDefaultCurrencyLabel,
            initialValue: proposed.currency ?? '',
          ),
          AppSimilarityProposedField(
            key: 'consultation_fee',
            label: l10n.settingsConfigurationConsultationFeeLabel,
            initialValue: proposed.standardConsultationFee ?? '',
          ),
        ],
        matches: appMatches,
        overallScore: overallScore,
        blockProceed: !canProceed,
        enableRetry: false,
        proposedReadOnly: true,
        proceedLabel: l10n.tenantFacilityProceedCreateTenantAction,
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
        dialogIcon: hasExactSlugConflict
            ? Icons.gpp_bad_outlined
            : hasMatches
            ? Icons.warning_amber_outlined
            : Icons.verified_outlined,
      );

  switch (result.action) {
    case AppSimilarityReviewAction.cancel:
    case AppSimilarityReviewAction.retry:
      return const TenantSimilarityDialogResult.cancel();
    case AppSimilarityReviewAction.useExisting:
      final TenantProfile? tenant = result.selected;
      if (tenant == null) {
        return const TenantSimilarityDialogResult.cancel();
      }
      return TenantSimilarityDialogResult.useExisting(tenant);
    case AppSimilarityReviewAction.proceed:
      return const TenantSimilarityDialogResult.proceed();
  }
}

String? _nonEmpty(String? value) {
  final String trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

String _tenantFieldLabel(AppLocalizations l10n, String field) {
  return switch (field) {
    'name' => l10n.tenantFacilityTenantNameLabel,
    'slug' => l10n.tenantFacilityTenantSlugLabel,
    'contact_name' => l10n.tenantFacilityTenantDetailsContactNameLabel,
    'contact_phone' => l10n.profilePhoneLabel,
    'contact_email' => l10n.profileEmailLabel,
    'currency' => l10n.tenantFacilityDefaultCurrencyLabel,
    'consultation_fee' => l10n.settingsConfigurationConsultationFeeLabel,
    _ => AppDisplay.apiLabel(field),
  };
}
