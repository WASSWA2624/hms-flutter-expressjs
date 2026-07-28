import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/utils/app_display.dart';
import 'package:hosspi_hms/features/access_admin/domain/entities/user_similarity.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

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

Future<UserSimilarityDialogResult> showUserSimilarityDialog(
  BuildContext context, {
  required UserSimilarityProposedValues proposed,
  required List<UserSimilarityMatch> matches,
  bool allowProceed = true,
  bool isEdit = false,
}) {
  final AppLocalizations l10n = context.l10n;
  final List<UserSimilarityMatch> visibleMatches = matches
      .take(5)
      .toList(growable: false);
  final bool hasExactConflict = visibleMatches.any(
    (UserSimilarityMatch match) =>
        match.exactEmailConflict || match.exactPhoneConflict,
  );
  final bool hasMatches = visibleMatches.isNotEmpty;
  final bool canProceed = allowProceed && !hasExactConflict;
  final int overallScore = hasMatches
      ? visibleMatches
            .map((UserSimilarityMatch match) => match.score)
            .reduce((int a, int b) => a > b ? a : b)
      : 0;
  final UserSimilarityMatch? topMatch = visibleMatches.isEmpty
      ? null
      : visibleMatches.first;

  return showAppDialog<UserSimilarityDialogResult>(
    context: context,
    builder: (BuildContext dialogContext) {
      final ThemeData theme = Theme.of(dialogContext);
      return AppDialog(
        title: Text(
          hasExactConflict || hasMatches
              ? l10n.accessAdminSimilarUserDialogTitle
              : l10n.accessAdminNoSimilarUserDialogTitle,
        ),
        icon: Icon(
          hasExactConflict
              ? Icons.gpp_bad_outlined
              : hasMatches
              ? Icons.warning_amber_outlined
              : Icons.verified_outlined,
        ),
        scrollable: true,
        maxWidth: 820,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppFormInformationBanner(
              title: hasExactConflict
                  ? l10n.accessAdminUserContactAlreadyInUse
                  : hasMatches
                  ? l10n.accessAdminSimilarUserWarningTitle
                  : l10n.accessAdminNoSimilarUserBannerTitle,
              message: hasExactConflict
                  ? l10n.accessAdminSimilarUserWarningBody
                  : hasMatches
                  ? l10n.accessAdminSimilarUserReviewBannerBody(
                      topMatch?.score ?? overallScore,
                    )
                  : l10n.accessAdminNoSimilarUserDialogBody,
              variant: hasExactConflict
                  ? AppFormInformationVariant.error
                  : hasMatches
                  ? AppFormInformationVariant.warning
                  : AppFormInformationVariant.success,
              icon: hasExactConflict
                  ? Icons.gpp_bad_outlined
                  : hasMatches
                  ? Icons.manage_search_outlined
                  : Icons.verified_outlined,
            ),
            SizedBox(height: theme.spacing.md),
            _ProposedUserCard(
              proposed: proposed,
              overallScore: overallScore,
              hasExactConflict: hasExactConflict,
              hasMatches: hasMatches,
            ),
            if (hasMatches) ...<Widget>[
              SizedBox(height: theme.spacing.lg),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      l10n.tenantFacilitySimilarTenantMatchesHeading,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    l10n.tenantFacilitySimilarTenantMatchCountLabel(
                      visibleMatches.length,
                    ),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              SizedBox(height: theme.spacing.sm),
              for (int index = 0; index < visibleMatches.length; index += 1) ...<
                Widget
              >[
                if (index > 0) SizedBox(height: theme.spacing.md),
                _UserSimilarityMatchCard(
                  match: visibleMatches[index],
                  onUseExisting: () => Navigator.of(dialogContext).pop(
                    UserSimilarityDialogResult.useExisting(
                      visibleMatches[index],
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
        actions: <Widget>[
          AppButton.tertiary(
            label: l10n.commonCancelActionLabel,
            leadingIcon: Icons.close,
            onPressed: () => Navigator.of(dialogContext).pop(
              const UserSimilarityDialogResult.cancel(),
            ),
          ),
          if (canProceed)
            AppButton.primary(
              label: hasMatches
                  ? (isEdit
                        ? l10n.accessAdminProceedEditUserAction
                        : l10n.accessAdminProceedCreateUserAction)
                  : (isEdit
                        ? l10n.accessAdminContinueEditUserAction
                        : l10n.accessAdminContinueCreateUserAction),
              leadingIcon: hasMatches
                  ? (isEdit
                        ? Icons.edit_outlined
                        : Icons.person_add_alt_1_outlined)
                  : Icons.check_circle_outline,
              onPressed: () => Navigator.of(dialogContext).pop(
                const UserSimilarityDialogResult.proceed(),
              ),
            ),
        ],
      );
    },
  ).then(
    (UserSimilarityDialogResult? value) =>
        value ?? const UserSimilarityDialogResult.cancel(),
  );
}

class _ProposedUserCard extends StatelessWidget {
  const _ProposedUserCard({
    required this.proposed,
    required this.overallScore,
    required this.hasExactConflict,
    required this.hasMatches,
  });

  final UserSimilarityProposedValues proposed;
  final int overallScore;
  final bool hasExactConflict;
  final bool hasMatches;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final AppStatusColors statusColors = theme.statusColors;
    final Color badgeContainer = hasExactConflict
        ? statusColors.errorContainer
        : hasMatches
        ? statusColors.warningContainer
        : statusColors.successContainer;
    final Color badgeOnContainer = hasExactConflict
        ? statusColors.onErrorContainer
        : hasMatches
        ? statusColors.onWarningContainer
        : statusColors.onSuccessContainer;
    final Color accent = hasExactConflict
        ? statusColors.error
        : hasMatches
        ? statusColors.warning
        : statusColors.success;

    final List<(String, String)> facts = <(String, String)>[
      if ((proposed.firstName ?? '').trim().isNotEmpty ||
          (proposed.lastName ?? '').trim().isNotEmpty)
        (
          l10n.accessAdminSimilarUserNameLabel,
          _display(
            <String?>[proposed.firstName, proposed.lastName]
                .whereType<String>()
                .map((String value) => value.trim())
                .where((String value) => value.isNotEmpty)
                .join(' '),
            l10n,
          ),
        ),
      (l10n.accessAdminEmailLabel, _display(proposed.email, l10n)),
      if ((proposed.phone ?? '').trim().isNotEmpty)
        (l10n.accessAdminPhoneLabel, _display(proposed.phone, l10n)),
      (l10n.accessAdminPositionLabel, _display(proposed.positionTitle, l10n)),
      if ((proposed.tenantName ?? '').trim().isNotEmpty)
        (
          l10n.tenantFacilitySelectTenantLabel,
          _display(proposed.tenantName, l10n),
        ),
      if ((proposed.facilityName ?? '').trim().isNotEmpty)
        (
          l10n.accessAdminColumnFacility,
          _display(proposed.facilityName, l10n),
        ),
      if ((proposed.tenantName ?? '').trim().isEmpty &&
          (proposed.facilityName ?? '').trim().isEmpty &&
          _proposedScopeLabel(proposed, l10n).trim().isNotEmpty)
        (
          l10n.accessAdminCreateRoleScopeSectionTitle,
          _display(_proposedScopeLabel(proposed, l10n), l10n),
        ),
    ];

    return AppSectionPanel(
      tone: AppWorkspaceStatusTone.info,
      density: AppContentPanelDensity.compact,
      leadingIcon: Icons.person_outline,
      title: l10n.accessAdminSimilarUserProposedHeading,
      trailing: Container(
        padding: EdgeInsets.symmetric(
          horizontal: theme.spacing.sm,
          vertical: theme.spacing.xs,
        ),
        decoration: BoxDecoration(
          color: badgeContainer,
          borderRadius: BorderRadius.circular(theme.radius.md),
          border: Border.all(color: accent.withValues(alpha: 0.55)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text(
              l10n.accessAdminSimilarUserOverallSimilarityLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: badgeOnContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '$overallScore%',
              style: theme.textTheme.titleSmall?.copyWith(
                color: badgeOnContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      children: <Widget>[
        Wrap(
          spacing: theme.spacing.md,
          runSpacing: theme.spacing.sm,
          children: <Widget>[
            for (final (String label, String value) in facts)
              SizedBox(
                width: 220,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: theme.spacing.xs / 2),
                    Text(
                      value,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _UserSimilarityMatchCard extends StatelessWidget {
  const _UserSimilarityMatchCard({
    required this.match,
    required this.onUseExisting,
  });

  final UserSimilarityMatch match;
  final VoidCallback onUseExisting;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final AppStatusColors statusColors = theme.statusColors;
    final bool hardConflict =
        match.exactEmailConflict || match.exactPhoneConflict;
    final Color accent = hardConflict
        ? statusColors.error
        : statusColors.warning;
    final Color badgeContainer = hardConflict
        ? statusColors.errorContainer
        : statusColors.warningContainer;
    final Color badgeOnContainer = hardConflict
        ? statusColors.onErrorContainer
        : statusColors.onWarningContainer;
    final List<UserFieldComparison> comparisons = _sortedComparisons(
      match.fieldComparisons,
    );

    return AppContentPanel(
      tone: hardConflict
          ? AppWorkspaceStatusTone.error
          : AppWorkspaceStatusTone.neutral,
      density: AppContentPanelDensity.compact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                hardConflict ? Icons.gpp_bad_outlined : Icons.person_outline,
                color: accent,
                size: theme.appTokens.listIconSize,
              ),
              SizedBox(width: theme.spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.accessAdminSimilarUserExistingHeading,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: accent,
                      ),
                    ),
                    SizedBox(height: theme.spacing.xs / 2),
                    Text(
                      match.user.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: theme.spacing.xs / 2),
                    Text(
                      match.user.effectiveDisplayId,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: theme.spacing.sm),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: theme.spacing.sm,
                  vertical: theme.spacing.xs,
                ),
                decoration: BoxDecoration(
                  color: badgeContainer,
                  borderRadius: BorderRadius.circular(theme.radius.md),
                  border: Border.all(color: accent.withValues(alpha: 0.55)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      '${match.score}%',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: badgeOnContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      hardConflict
                          ? l10n.accessAdminSimilarUserExactConflictLabel
                          : match.score >= userSimilarityThreshold
                          ? l10n.accessAdminSimilarUserNearMatchLabel
                          : l10n.accessAdminSimilarUserPartialMatchLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: badgeOnContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (comparisons.isNotEmpty) ...<Widget>[
            SizedBox(height: theme.spacing.md),
            DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(theme.radius.sm),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.7,
                  ),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.all(theme.spacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      l10n.accessAdminSimilarUserComparisonHeading,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: theme.spacing.sm),
                    LayoutBuilder(
                      builder:
                          (BuildContext context, BoxConstraints constraints) {
                            final bool compact = constraints.maxWidth < 620;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                if (!compact) ...<Widget>[
                                  _ComparisonTableHeader(),
                                  SizedBox(height: theme.spacing.xs),
                                ],
                                for (
                                  int index = 0;
                                  index < comparisons.length;
                                  index += 1
                                ) ...<Widget>[
                                  if (index > 0 || !compact)
                                    Divider(
                                      height: theme.spacing.md,
                                      color: theme.colorScheme.outlineVariant
                                          .withValues(alpha: 0.55),
                                    ),
                                  if (compact)
                                    _FieldComparisonStacked(
                                      comparison: comparisons[index],
                                    )
                                  else
                                    _FieldComparisonRow(
                                      comparison: comparisons[index],
                                    ),
                                ],
                              ],
                            );
                          },
                    ),
                  ],
                ),
              ),
            ),
          ],
          SizedBox(height: theme.spacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton.secondary(
              label: l10n.accessAdminUseExistingUserAction,
              leadingIcon: Icons.open_in_new,
              onPressed: onUseExisting,
            ),
          ),
        ],
      ),
    );
  }
}

class _ComparisonTableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final TextStyle style = theme.textTheme.labelSmall!.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );

    return Row(
      children: <Widget>[
        SizedBox(
          width: 128,
          child: Text(l10n.tenantFacilitySimilarTenantFieldLabel, style: style),
        ),
        Expanded(
          child: Text(
            l10n.tenantFacilitySimilarTenantProposedValueLabel,
            style: style,
          ),
        ),
        Expanded(
          child: Text(
            l10n.tenantFacilitySimilarTenantExistingValueLabel,
            style: style,
          ),
        ),
        SizedBox(
          width: 108,
          child: Text(
            l10n.tenantFacilitySimilarTenantStatusLabel,
            style: style,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

class _FieldComparisonRow extends StatelessWidget {
  const _FieldComparisonRow({required this.comparison});

  final UserFieldComparison comparison;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 128,
          child: Text(
            _fieldLabel(l10n, comparison.field),
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            _display(comparison.inputValue, l10n),
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            _display(comparison.candidateValue, l10n),
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SizedBox(
          width: 108,
          child: Align(
            alignment: Alignment.centerRight,
            child: _StatusChip(comparison: comparison),
          ),
        ),
      ],
    );
  }
}

class _FieldComparisonStacked extends StatelessWidget {
  const _FieldComparisonStacked({required this.comparison});

  final UserFieldComparison comparison;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                _fieldLabel(l10n, comparison.field),
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            _StatusChip(comparison: comparison),
          ],
        ),
        SizedBox(height: theme.spacing.xs),
        _StackedValue(
          label: l10n.tenantFacilitySimilarTenantProposedValueLabel,
          value: _display(comparison.inputValue, l10n),
        ),
        SizedBox(height: theme.spacing.xs / 2),
        _StackedValue(
          label: l10n.tenantFacilitySimilarTenantExistingValueLabel,
          value: _display(comparison.candidateValue, l10n),
        ),
      ],
    );
  }
}

class _StackedValue extends StatelessWidget {
  const _StackedValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.comparison});

  final UserFieldComparison comparison;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final AppStatusColors statusColors = theme.statusColors;
    final (Color bg, Color fg, Color border) = switch (comparison.status) {
      UserFieldComparisonStatus.match => (
        statusColors.successContainer,
        statusColors.onSuccessContainer,
        statusColors.success.withValues(alpha: 0.45),
      ),
      UserFieldComparisonStatus.similar => (
        statusColors.warningContainer,
        statusColors.onWarningContainer,
        statusColors.warning.withValues(alpha: 0.45),
      ),
      UserFieldComparisonStatus.different => (
        statusColors.errorContainer,
        statusColors.onErrorContainer,
        statusColors.error.withValues(alpha: 0.4),
      ),
      UserFieldComparisonStatus.missing => (
        theme.colorScheme.surfaceContainerHighest,
        theme.colorScheme.onSurfaceVariant,
        theme.colorScheme.outlineVariant,
      ),
    };

    final String label = _statusLabel(l10n, comparison.status);
    final String? score = comparison.score == null
        ? null
        : '${comparison.score}%';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: theme.spacing.sm,
        vertical: theme.spacing.xs / 2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(theme.radius.sm),
        border: Border.all(color: border),
      ),
      child: Text(
        score == null ? label : '$label · $score',
        style: theme.textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
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

String _statusLabel(AppLocalizations l10n, UserFieldComparisonStatus status) {
  return switch (status) {
    UserFieldComparisonStatus.match =>
      l10n.tenantFacilitySimilarFieldStatusMatch,
    UserFieldComparisonStatus.similar =>
      l10n.tenantFacilitySimilarFieldStatusSimilar,
    UserFieldComparisonStatus.different =>
      l10n.tenantFacilitySimilarFieldStatusDifferent,
    UserFieldComparisonStatus.missing =>
      l10n.tenantFacilitySimilarFieldStatusMissing,
  };
}
