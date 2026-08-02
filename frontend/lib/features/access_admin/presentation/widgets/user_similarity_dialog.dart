import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/utils/app_display.dart';
import 'package:hosspi_hms/features/access_admin/domain/entities/user_similarity.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

enum UserSimilarityAction { cancel, useExisting, proceed }

final class UserSimilarityDialogResult {
  const UserSimilarityDialogResult._({
    required this.action,
    this.selectedUser,
  });

  const UserSimilarityDialogResult.cancel()
    : this._(action: UserSimilarityAction.cancel);

  const UserSimilarityDialogResult.proceed()
    : this._(action: UserSimilarityAction.proceed);

  const UserSimilarityDialogResult.useExisting(this.selectedUser)
    : action = UserSimilarityAction.useExisting;

  final UserSimilarityAction action;
  final UserSimilarityMatch? selectedUser;
}

/// Access-admin user adapter over [showAppSimilarityReviewDialog].
Future<UserSimilarityDialogResult> showUserSimilarityDialog(
  BuildContext context, {
  required UserSimilarityProposedValues proposed,
  required List<UserSimilarityMatch> matches,
  bool allowProceed = true,
  bool isEdit = false,
}) async {
  final AppLocalizations l10n = context.l10n;
  final List<UserSimilarityMatch> visibleMatches = matches
      .take(5)
      .toList(growable: false);
  final bool hasExactConflict = visibleMatches.any(
    (UserSimilarityMatch match) =>
        match.exactEmailConflict || match.exactPhoneConflict,
  );
  final bool hasMatches = visibleMatches.isNotEmpty;
  final int overallScore = hasMatches
      ? visibleMatches
            .map((UserSimilarityMatch match) => match.score)
            .reduce((int a, int b) => a > b ? a : b)
      : 0;
  final UserSimilarityMatch? topMatch =
      visibleMatches.isEmpty ? null : visibleMatches.first;

  final String dialogTitle = hasExactConflict || hasMatches
      ? l10n.accessAdminSimilarUserDialogTitle
      : l10n.accessAdminNoSimilarUserDialogTitle;
  final String proceedLabel = hasMatches
      ? (isEdit
            ? l10n.accessAdminProceedEditUserAction
            : l10n.accessAdminProceedCreateUserAction)
      : (isEdit
            ? l10n.accessAdminContinueEditUserAction
            : l10n.accessAdminContinueCreateUserAction);
  final AppFormInformationVariant bannerVariant = hasExactConflict
      ? AppFormInformationVariant.error
      : hasMatches
      ? AppFormInformationVariant.warning
      : AppFormInformationVariant.success;

  final List<AppSimilarityMatch<UserSimilarityMatch>> appMatches =
      visibleMatches.map((UserSimilarityMatch match) {
        final bool hardConflict =
            match.exactEmailConflict || match.exactPhoneConflict;
        return AppSimilarityMatch<UserSimilarityMatch>(
          item: match,
          title: match.user.title,
          subtitle: match.user.effectiveDisplayId,
          overallScore: match.score,
          isExact: hardConflict,
          fields: _fieldRows(l10n: l10n, comparisons: match.fieldComparisons),
        );
      }).toList(growable: false);

  final AppSimilarityReviewResult<UserSimilarityMatch> result =
      await showAppSimilarityReviewDialog<UserSimilarityMatch>(
        context,
        title: dialogTitle,
        bannerTitle: hasExactConflict
            ? l10n.accessAdminUserContactAlreadyInUse
            : hasMatches
            ? l10n.accessAdminSimilarUserWarningTitle
            : l10n.accessAdminNoSimilarUserBannerTitle,
        bannerMessage: hasExactConflict
            ? l10n.accessAdminSimilarUserWarningBody
            : hasMatches
            ? l10n.accessAdminSimilarUserReviewBannerBody(
                topMatch?.score ?? overallScore,
              )
            : l10n.accessAdminNoSimilarUserDialogBody,
        bannerVariant: bannerVariant,
        proposedFields: _proposedFields(l10n: l10n, proposed: proposed),
        matches: appMatches,
        overallScore: overallScore,
        blockProceed: !allowProceed || hasExactConflict,
        enableRetry: false,
        proposedReadOnly: true,
        proceedLabel: proceedLabel,
        useThisLabel: l10n.accessAdminUseExistingUserAction,
        useThisIcon: Icons.open_in_new,
        proposedHeading: l10n.accessAdminSimilarUserProposedHeading,
        matchesHeading: l10n.tenantFacilitySimilarTenantMatchesHeading,
        exactBadgeLabel: l10n.accessAdminSimilarUserExactConflictLabel,
        nearBadgeLabel: l10n.accessAdminSimilarUserNearMatchLabel,
        existingHeading: l10n.accessAdminSimilarUserExistingHeading,
        fieldColumnLabel: l10n.tenantFacilitySimilarTenantFieldLabel,
        proposedColumnLabel: l10n.tenantFacilitySimilarTenantProposedValueLabel,
        existingColumnLabel:
            l10n.tenantFacilitySimilarTenantExistingValueLabel,
        closestMatchLabel: l10n.accessAdminSimilarUserOverallSimilarityLabel,
        noMatchLabel: l10n.accessAdminNoSimilarUserDialogBody,
        emptyValueLabel: l10n.clinicalOrderEmptyValueLabel,
        dialogIcon: hasExactConflict
            ? Icons.gpp_bad_outlined
            : hasMatches
            ? Icons.warning_amber_outlined
            : Icons.verified_outlined,
      );

  switch (result.action) {
    case AppSimilarityReviewAction.cancel:
    case AppSimilarityReviewAction.retry:
      return const UserSimilarityDialogResult.cancel();
    case AppSimilarityReviewAction.replaceExisting:
      return const UserSimilarityDialogResult.cancel();
    case AppSimilarityReviewAction.proceed:
      return const UserSimilarityDialogResult.proceed();
    case AppSimilarityReviewAction.useExisting:
      final UserSimilarityMatch? selected = result.selected;
      if (selected == null) {
        return const UserSimilarityDialogResult.cancel();
      }
      return UserSimilarityDialogResult.useExisting(selected);
  }
}

List<AppSimilarityProposedField> _proposedFields({
  required AppLocalizations l10n,
  required UserSimilarityProposedValues proposed,
}) {
  final List<AppSimilarityProposedField> fields = <AppSimilarityProposedField>[];

  if ((proposed.firstName ?? '').trim().isNotEmpty ||
      (proposed.lastName ?? '').trim().isNotEmpty) {
    fields.add(
      AppSimilarityProposedField(
        key: 'full_name',
        label: l10n.accessAdminSimilarUserNameLabel,
        initialValue: proposed.fullName,
      ),
    );
  }
  fields.add(
    AppSimilarityProposedField(
      key: 'email',
      label: l10n.accessAdminEmailLabel,
      initialValue: proposed.email,
      isRequired: true,
    ),
  );
  if ((proposed.phone ?? '').trim().isNotEmpty) {
    fields.add(
      AppSimilarityProposedField(
        key: 'phone',
        label: l10n.accessAdminPhoneLabel,
        initialValue: proposed.phone!.trim(),
      ),
    );
  }
  fields.add(
    AppSimilarityProposedField(
      key: 'position_title',
      label: l10n.accessAdminPositionLabel,
      initialValue: proposed.positionTitle ?? '',
    ),
  );
  if ((proposed.tenantName ?? '').trim().isNotEmpty) {
    fields.add(
      AppSimilarityProposedField(
        key: 'tenant',
        label: l10n.tenantFacilitySelectTenantLabel,
        initialValue: proposed.tenantName!.trim(),
      ),
    );
  }
  if ((proposed.facilityName ?? '').trim().isNotEmpty) {
    fields.add(
      AppSimilarityProposedField(
        key: 'facility',
        label: l10n.accessAdminColumnFacility,
        initialValue: proposed.facilityName!.trim(),
      ),
    );
  }
  if ((proposed.tenantName ?? '').trim().isEmpty &&
      (proposed.facilityName ?? '').trim().isEmpty) {
    final String scopeLabel = _proposedScopeLabel(proposed, l10n).trim();
    if (scopeLabel.isNotEmpty) {
      fields.add(
        AppSimilarityProposedField(
          key: 'scope',
          label: l10n.accessAdminCreateRoleScopeSectionTitle,
          initialValue: scopeLabel,
        ),
      );
    }
  }

  return fields;
}

List<AppSimilarityFieldRow> _fieldRows({
  required AppLocalizations l10n,
  required List<UserFieldComparison> comparisons,
}) {
  return _sortedComparisons(comparisons)
      .map(
        (UserFieldComparison comparison) => AppSimilarityFieldRow(
          key: comparison.field,
          label: _fieldLabel(l10n, comparison.field),
          proposedValue: _display(comparison.inputValue, l10n),
          existingValue: _display(comparison.candidateValue, l10n),
          score: _comparisonScore(comparison),
        ),
      )
      .toList(growable: false);
}

int? _comparisonScore(UserFieldComparison comparison) {
  return switch (comparison.status) {
    UserFieldComparisonStatus.match => 100,
    UserFieldComparisonStatus.similar ||
    UserFieldComparisonStatus.different => comparison.score,
    UserFieldComparisonStatus.missing => null,
  };
}

List<UserFieldComparison> _sortedComparisons(
  List<UserFieldComparison> comparisons,
) {
  int rank(UserFieldComparisonStatus status) {
    return switch (status) {
      UserFieldComparisonStatus.match => 0,
      UserFieldComparisonStatus.similar => 1,
      UserFieldComparisonStatus.different => 2,
      UserFieldComparisonStatus.missing => 3,
    };
  }

  final List<UserFieldComparison> next = List<UserFieldComparison>.of(
    comparisons,
  )..removeWhere(
      (UserFieldComparison entry) =>
          entry.field == 'display_id' && entry.inputValue == null,
    );
  next.sort((UserFieldComparison left, UserFieldComparison right) {
    final int byStatus = rank(left.status).compareTo(rank(right.status));
    if (byStatus != 0) {
      return byStatus;
    }
    return (right.score ?? -1).compareTo(left.score ?? -1);
  });
  return next;
}

String _display(String? value, AppLocalizations l10n) {
  final String? publicValue = publicUserLabel(value);
  return publicValue ?? l10n.clinicalOrderEmptyValueLabel;
}

String _fieldLabel(AppLocalizations l10n, String field) {
  return switch (field) {
    'email' => l10n.accessAdminEmailLabel,
    'phone' => l10n.accessAdminPhoneLabel,
    'position_title' => l10n.accessAdminPositionLabel,
    'first_name' => l10n.accessAdminFirstNameLabel,
    'last_name' => l10n.accessAdminLastNameLabel,
    'full_name' => l10n.accessAdminSimilarUserNameLabel,
    'facility' => l10n.accessAdminColumnFacility,
    'display_id' => l10n.hrUserIdLabel,
    _ => AppDisplay.apiLabel(field),
  };
}

String _proposedScopeLabel(
  UserSimilarityProposedValues proposed,
  AppLocalizations l10n,
) {
  final String? facilityName = proposed.facilityName?.trim();
  final String? tenantName = proposed.tenantName?.trim();
  if (facilityName != null && facilityName.isNotEmpty) {
    if (tenantName != null && tenantName.isNotEmpty) {
      return '$tenantName · $facilityName';
    }
    return facilityName;
  }
  if (tenantName != null && tenantName.isNotEmpty) {
    return tenantName;
  }
  return '';
}
