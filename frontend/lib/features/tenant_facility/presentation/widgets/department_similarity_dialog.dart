import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/utils/app_display.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/department_similarity.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'tenant_facility_setup_helpers.dart';

enum DepartmentSimilarityAction { cancel, useExisting, proceed }

final class DepartmentSimilarityDialogResult {
  const DepartmentSimilarityDialogResult._({
    required this.action,
    this.selectedDepartment,
  });

  const DepartmentSimilarityDialogResult.cancel()
    : this._(action: DepartmentSimilarityAction.cancel);

  const DepartmentSimilarityDialogResult.proceed()
    : this._(action: DepartmentSimilarityAction.proceed);

  const DepartmentSimilarityDialogResult.useExisting(DepartmentProfile department)
    : this._(
        action: DepartmentSimilarityAction.useExisting,
        selectedDepartment: department,
      );

  final DepartmentSimilarityAction action;
  final DepartmentProfile? selectedDepartment;
}

/// Department adapter over [showAppSimilarityReviewDialog].
Future<DepartmentSimilarityDialogResult> showDepartmentSimilarityDialog(
  BuildContext context, {
  required DepartmentSimilarityProposedValues proposed,
  required List<DepartmentSimilarityMatch> matches,
  bool allowProceed = true,
}) async {
  final AppLocalizations l10n = context.l10n;
  final List<DepartmentSimilarityMatch> visibleMatches = matches
      .take(5)
      .toList(growable: false);
  final bool hasExactNameConflict = visibleMatches.any(
    (DepartmentSimilarityMatch match) => match.exactNameConflict,
  );
  final bool hasMatches = visibleMatches.isNotEmpty;
  final bool canProceed = allowProceed && !hasExactNameConflict;
  final int overallScore = _maxMatchScore(visibleMatches);
  final String shortName = resolveDepartmentShortName(
    proposed.name,
    proposed.shortName,
  );

  final String dialogTitle = hasExactNameConflict || hasMatches
      ? l10n.tenantFacilitySimilarDepartmentDialogTitle
      : l10n.tenantFacilityNoSimilarDepartmentDialogTitle;
  final String bannerTitle = hasExactNameConflict
      ? l10n.tenantFacilityDepartmentNameAlreadyInUse
      : hasMatches
      ? l10n.tenantFacilitySimilarDepartmentWarningTitle
      : l10n.tenantFacilityNoSimilarDepartmentBannerTitle;
  final String bannerMessage = hasExactNameConflict || hasMatches
      ? l10n.tenantFacilitySimilarDepartmentWarningBody
      : l10n.tenantFacilityNoSimilarDepartmentDialogBody;
  final AppFormInformationVariant bannerVariant = hasExactNameConflict
      ? AppFormInformationVariant.error
      : hasMatches
      ? AppFormInformationVariant.warning
      : AppFormInformationVariant.success;

  final List<AppSimilarityMatch<DepartmentProfile>> appMatches =
      visibleMatches.map((DepartmentSimilarityMatch match) {
        final List<AppSimilarityFieldRow> fields = match.fieldComparisons
            .map(
              (DepartmentFieldComparison comparison) => AppSimilarityFieldRow(
                key: comparison.field,
                label: _departmentFieldLabel(l10n, comparison.field),
                proposedValue: _departmentComparisonValue(
                  l10n,
                  comparison.field,
                  comparison.inputValue,
                ),
                existingValue: _departmentComparisonValue(
                  l10n,
                  comparison.field,
                  comparison.candidateValue,
                ),
                score: comparison.score,
              ),
            )
            .toList(growable: false);
        return AppSimilarityMatch<DepartmentProfile>(
          item: match.department,
          title: match.department.name,
          subtitle: _nonEmpty(match.department.displayId),
          overallScore: match.score,
          isExact: match.exactNameConflict,
          fields: fields,
        );
      }).toList(growable: false);

  final AppSimilarityReviewResult<DepartmentProfile> result =
      await showAppSimilarityReviewDialog<DepartmentProfile>(
        context,
        title: dialogTitle,
        bannerTitle: bannerTitle,
        bannerMessage: bannerMessage,
        bannerVariant: bannerVariant,
        proposedFields: <AppSimilarityProposedField>[
          AppSimilarityProposedField(
            key: 'name',
            label: l10n.tenantFacilityDepartmentNameLabel,
            initialValue: proposed.name,
            isRequired: true,
          ),
          AppSimilarityProposedField(
            key: 'short_name',
            label: l10n.tenantFacilityDepartmentShortNameLabel,
            initialValue: shortName,
          ),
          AppSimilarityProposedField(
            key: 'department_type',
            label: l10n.tenantFacilityDepartmentTypeLabel,
            initialValue: tenantFacilityDepartmentTypeLabel(l10n, proposed.type),
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
        proceedLabel: l10n.tenantFacilityProceedCreateDepartmentAction,
        continueLabel: l10n.tenantFacilityContinueCreateDepartmentAction,
        useThisLabel: l10n.tenantFacilityUseThisDepartmentAction,
        useThisIcon: Icons.open_in_new,
        proposedHeading: l10n.tenantFacilitySimilarDepartmentProposedHeading,
        matchesHeading: l10n.tenantFacilitySimilarTenantMatchesHeading,
        exactBadgeLabel: l10n.tenantFacilitySimilarTenantExactConflictLabel,
        nearBadgeLabel: l10n.tenantFacilitySimilarTenantNearMatchLabel,
        existingHeading: l10n.tenantFacilitySimilarDepartmentExistingHeading,
        fieldColumnLabel: l10n.tenantFacilitySimilarTenantFieldLabel,
        proposedColumnLabel: l10n.tenantFacilitySimilarTenantProposedValueLabel,
        existingColumnLabel: l10n.tenantFacilitySimilarTenantExistingValueLabel,
        closestMatchLabel: l10n.tenantFacilityDepartmentOverallSimilarityLabel,
        noMatchLabel: l10n.tenantFacilityDepartmentNoMatchScoreLabel(
          overallScore,
        ),
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
      return const DepartmentSimilarityDialogResult.cancel();
    case AppSimilarityReviewAction.useExisting:
      final DepartmentProfile? department = result.selected;
      if (department == null) {
        return const DepartmentSimilarityDialogResult.cancel();
      }
      return DepartmentSimilarityDialogResult.useExisting(department);
    case AppSimilarityReviewAction.proceed:
      return const DepartmentSimilarityDialogResult.proceed();
  }
}

int _maxMatchScore(List<DepartmentSimilarityMatch> matches) {
  if (matches.isEmpty) {
    return 0;
  }
  return matches
      .map((DepartmentSimilarityMatch match) => match.score)
      .reduce((int a, int b) => a > b ? a : b);
}

String? _nonEmpty(String? value) {
  final String trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

String _departmentFieldLabel(AppLocalizations l10n, String field) {
  return switch (field) {
    'name' => l10n.tenantFacilityDepartmentNameLabel,
    'short_name' => l10n.tenantFacilityDepartmentShortNameLabel,
    'department_type' => l10n.tenantFacilityDepartmentTypeLabel,
    'status' => l10n.tenantFacilityActiveLabel,
    'display_id' => l10n.accessAdminColumnDetails,
    _ => AppDisplay.apiLabel(field),
  };
}

String? _departmentComparisonValue(
  AppLocalizations l10n,
  String field,
  String? value,
) {
  if (value == null) {
    return null;
  }
  return switch (field) {
    'department_type' => _departmentTypeDisplay(l10n, value),
    'status' => tenantFacilityActiveStatusLabel(
      l10n,
      value.trim().toLowerCase() == 'active',
    ),
    _ => value,
  };
}

String _departmentTypeDisplay(AppLocalizations l10n, String value) {
  final DepartmentSetupType? type = _parseDepartmentType(value);
  if (type != null) {
    return tenantFacilityDepartmentTypeLabel(l10n, type);
  }
  return value;
}

DepartmentSetupType? _parseDepartmentType(String value) {
  final String normalized = value.trim().toLowerCase();
  for (final DepartmentSetupType type in DepartmentSetupType.values) {
    if (type.name == normalized) {
      return type;
    }
  }
  return null;
}
