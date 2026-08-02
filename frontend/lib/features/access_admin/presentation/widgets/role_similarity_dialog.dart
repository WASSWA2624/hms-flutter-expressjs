import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/utils/app_display.dart';
import 'package:hosspi_hms/features/access_admin/domain/entities/role_similarity.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

enum RoleSimilarityAction { cancel, useExisting, proceed }

final class RoleSimilarityDialogResult {
  const RoleSimilarityDialogResult._({
    required this.action,
    this.selectedRole,
  });

  const RoleSimilarityDialogResult.cancel()
    : this._(action: RoleSimilarityAction.cancel);

  const RoleSimilarityDialogResult.proceed()
    : this._(action: RoleSimilarityAction.proceed);

  const RoleSimilarityDialogResult.useExisting(this.selectedRole)
    : action = RoleSimilarityAction.useExisting;

  final RoleSimilarityAction action;
  final RoleSimilarityMatch? selectedRole;
}

/// Access-admin role adapter over [showAppSimilarityReviewDialog].
Future<RoleSimilarityDialogResult> showRoleSimilarityDialog(
  BuildContext context, {
  required RoleSimilarityProposedValues proposed,
  required List<RoleSimilarityMatch> matches,
  bool allowProceed = true,
}) async {
  final AppLocalizations l10n = context.l10n;
  final List<RoleSimilarityMatch> visibleMatches = matches
      .take(5)
      .toList(growable: false);
  final bool hasExactNameConflict = visibleMatches.any(
    (RoleSimilarityMatch match) =>
        match.exactNameConflict || match.exactDisplayNameConflict,
  );
  final bool hasMatches = visibleMatches.isNotEmpty;
  final int overallScore = hasMatches
      ? visibleMatches
            .map((RoleSimilarityMatch match) => match.score)
            .reduce((int a, int b) => a > b ? a : b)
      : 0;
  final RoleSimilarityMatch? topMatch =
      visibleMatches.isEmpty ? null : visibleMatches.first;

  final String dialogTitle = hasExactNameConflict || hasMatches
      ? l10n.accessAdminSimilarRoleDialogTitle
      : l10n.accessAdminNoSimilarRoleDialogTitle;
  final String proceedLabel = hasMatches
      ? l10n.accessAdminProceedCreateRoleAction
      : l10n.accessAdminContinueCreateRoleAction;
  final AppFormInformationVariant bannerVariant = hasExactNameConflict
      ? AppFormInformationVariant.error
      : hasMatches
      ? AppFormInformationVariant.warning
      : AppFormInformationVariant.success;

  final List<AppSimilarityMatch<RoleSimilarityMatch>> appMatches =
      visibleMatches.map((RoleSimilarityMatch match) {
        final bool hardConflict =
            match.exactNameConflict || match.exactDisplayNameConflict;
        return AppSimilarityMatch<RoleSimilarityMatch>(
          item: match,
          title: match.role.title,
          subtitle: match.role.effectiveDisplayId,
          overallScore: match.score,
          isExact: hardConflict,
          fields: _fieldRows(l10n: l10n, comparisons: match.fieldComparisons),
        );
      }).toList(growable: false);

  final AppSimilarityReviewResult<RoleSimilarityMatch> result =
      await showAppSimilarityReviewDialog<RoleSimilarityMatch>(
        context,
        title: dialogTitle,
        bannerTitle: hasExactNameConflict
            ? l10n.accessAdminRoleNameAlreadyInUse
            : hasMatches
            ? l10n.accessAdminSimilarRoleWarningTitle
            : l10n.accessAdminNoSimilarRoleBannerTitle,
        bannerMessage: hasExactNameConflict
            ? l10n.accessAdminSimilarRoleWarningBody
            : hasMatches
            ? l10n.accessAdminSimilarRoleReviewBannerBody(
                topMatch?.score ?? overallScore,
              )
            : l10n.accessAdminNoSimilarRoleDialogBody,
        bannerVariant: bannerVariant,
        proposedFields: _proposedFields(l10n: l10n, proposed: proposed),
        matches: appMatches,
        overallScore: overallScore,
        blockProceed: !allowProceed || hasExactNameConflict,
        enableRetry: false,
        proposedReadOnly: true,
        proceedLabel: proceedLabel,
        useThisLabel: l10n.accessAdminUseExistingRoleAction,
        useThisIcon: Icons.open_in_new,
        proposedHeading: l10n.accessAdminSimilarRoleProposedHeading,
        matchesHeading: l10n.tenantFacilitySimilarTenantMatchesHeading,
        exactBadgeLabel: l10n.accessAdminSimilarRoleExactConflictLabel,
        nearBadgeLabel: l10n.accessAdminSimilarRoleNearMatchLabel,
        existingHeading: l10n.accessAdminSimilarRoleExistingHeading,
        fieldColumnLabel: l10n.tenantFacilitySimilarTenantFieldLabel,
        proposedColumnLabel: l10n.tenantFacilitySimilarTenantProposedValueLabel,
        existingColumnLabel:
            l10n.tenantFacilitySimilarTenantExistingValueLabel,
        closestMatchLabel: l10n.accessAdminSimilarRoleOverallSimilarityLabel,
        noMatchLabel: l10n.accessAdminNoSimilarRoleDialogBody,
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
      return const RoleSimilarityDialogResult.cancel();
    case AppSimilarityReviewAction.replaceExisting:
      return const RoleSimilarityDialogResult.cancel();
    case AppSimilarityReviewAction.proceed:
      return const RoleSimilarityDialogResult.proceed();
    case AppSimilarityReviewAction.useExisting:
      final RoleSimilarityMatch? selected = result.selected;
      if (selected == null) {
        return const RoleSimilarityDialogResult.cancel();
      }
      return RoleSimilarityDialogResult.useExisting(selected);
  }
}

List<AppSimilarityProposedField> _proposedFields({
  required AppLocalizations l10n,
  required RoleSimilarityProposedValues proposed,
}) {
  return <AppSimilarityProposedField>[
    AppSimilarityProposedField(
      key: 'name',
      label: l10n.accessAdminRoleNameLabel,
      initialValue: proposed.name,
      isRequired: true,
    ),
    AppSimilarityProposedField(
      key: 'display_name',
      label: l10n.accessAdminRoleDisplayNameLabel,
      initialValue: proposed.displayName,
      isRequired: true,
    ),
    AppSimilarityProposedField(
      key: 'scope',
      label: l10n.accessAdminRoleScopeLabel,
      initialValue: _proposedScopeLabel(proposed, l10n),
    ),
    if ((proposed.description ?? '').trim().isNotEmpty)
      AppSimilarityProposedField(
        key: 'description',
        label: l10n.accessAdminRoleDescriptionLabel,
        initialValue: proposed.description!.trim(),
      ),
  ];
}

List<AppSimilarityFieldRow> _fieldRows({
  required AppLocalizations l10n,
  required List<RoleFieldComparison> comparisons,
}) {
  return _sortedComparisons(comparisons)
      .map(
        (RoleFieldComparison comparison) => AppSimilarityFieldRow(
          key: comparison.field,
          label: _fieldLabel(l10n, comparison.field),
          proposedValue: _display(comparison.inputValue, l10n),
          existingValue: _display(comparison.candidateValue, l10n),
          score: _comparisonScore(comparison),
        ),
      )
      .toList(growable: false);
}

int? _comparisonScore(RoleFieldComparison comparison) {
  return switch (comparison.status) {
    RoleFieldComparisonStatus.match => 100,
    RoleFieldComparisonStatus.similar ||
    RoleFieldComparisonStatus.different => comparison.score,
    RoleFieldComparisonStatus.missing => null,
  };
}

List<RoleFieldComparison> _sortedComparisons(
  List<RoleFieldComparison> comparisons,
) {
  int rank(RoleFieldComparisonStatus status) {
    return switch (status) {
      RoleFieldComparisonStatus.match => 0,
      RoleFieldComparisonStatus.similar => 1,
      RoleFieldComparisonStatus.different => 2,
      RoleFieldComparisonStatus.missing => 3,
    };
  }

  final List<RoleFieldComparison> next = List<RoleFieldComparison>.of(
    comparisons,
  )..removeWhere(
      (RoleFieldComparison entry) =>
          entry.field == 'display_id' && entry.inputValue == null,
    );
  next.sort((RoleFieldComparison left, RoleFieldComparison right) {
    final int byStatus = rank(left.status).compareTo(rank(right.status));
    if (byStatus != 0) {
      return byStatus;
    }
    return (right.score ?? -1).compareTo(left.score ?? -1);
  });
  return next;
}

String _display(String? value, AppLocalizations l10n) {
  final String trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? l10n.clinicalOrderEmptyValueLabel : trimmed;
}

String _fieldLabel(AppLocalizations l10n, String field) {
  return switch (field) {
    'name' => l10n.accessAdminRoleNameLabel,
    'display_name' => l10n.accessAdminRoleDisplayNameLabel,
    'description' => l10n.accessAdminRoleDescriptionLabel,
    'scope' => l10n.accessAdminRoleScopeLabel,
    'cross_identity' => l10n.accessAdminSimilarRoleCrossIdentityLabel,
    _ => AppDisplay.apiLabel(field),
  };
}

String _proposedScopeLabel(
  RoleSimilarityProposedValues proposed,
  AppLocalizations l10n,
) {
  final String kind = deriveRoleScopeKind(
    tenantId: proposed.tenantId,
    facilityId: proposed.facilityId,
    scope: proposed.scope,
  );
  if (kind == 'facility') {
    final String? name = proposed.facilityName?.trim();
    if (name != null && name.isNotEmpty) {
      return '${l10n.accessAdminRoleScopeFacilityBadge} · $name';
    }
    return l10n.accessAdminRoleScopeFacilityBadge;
  }
  if (kind == 'tenant') {
    final String? name = proposed.tenantName?.trim();
    if (name != null && name.isNotEmpty) {
      return '${l10n.accessAdminRoleScopeTenantBadge} · $name';
    }
    return l10n.accessAdminRoleScopeTenantBadge;
  }
  return l10n.accessAdminRoleScopePlatformLabel;
}
