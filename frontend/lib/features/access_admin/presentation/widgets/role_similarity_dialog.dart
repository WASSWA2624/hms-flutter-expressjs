import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/utils/app_display.dart';
import 'package:hosspi_hms/features/access_admin/domain/entities/role_similarity.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

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

Future<RoleSimilarityDialogResult> showRoleSimilarityDialog(
  BuildContext context, {
  required RoleSimilarityProposedValues proposed,
  required List<RoleSimilarityMatch> matches,
  bool allowProceed = true,
}) {
  final AppLocalizations l10n = context.l10n;
  final List<RoleSimilarityMatch> visibleMatches = matches
      .take(5)
      .toList(growable: false);
  final bool hasExactNameConflict = visibleMatches.any(
    (RoleSimilarityMatch match) =>
        match.exactNameConflict || match.exactDisplayNameConflict,
  );
  final bool hasMatches = visibleMatches.isNotEmpty;
  final bool canProceed = allowProceed && !hasExactNameConflict;
  final int overallScore = hasMatches
      ? visibleMatches
            .map((RoleSimilarityMatch match) => match.score)
            .reduce((int a, int b) => a > b ? a : b)
      : 0;
  final RoleSimilarityMatch? topMatch = visibleMatches.isEmpty
      ? null
      : visibleMatches.first;

  return showAppDialog<RoleSimilarityDialogResult>(
    context: context,
    builder: (BuildContext dialogContext) {
      final ThemeData theme = Theme.of(dialogContext);
      return AppDialog(
        title: Text(
          hasExactNameConflict || hasMatches
              ? l10n.accessAdminSimilarRoleDialogTitle
              : l10n.accessAdminNoSimilarRoleDialogTitle,
        ),
        icon: Icon(
          hasExactNameConflict
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
              title: hasExactNameConflict
                  ? l10n.accessAdminRoleNameAlreadyInUse
                  : hasMatches
                  ? l10n.accessAdminSimilarRoleWarningTitle
                  : l10n.accessAdminNoSimilarRoleBannerTitle,
              message: hasExactNameConflict
                  ? l10n.accessAdminSimilarRoleWarningBody
                  : hasMatches
                  ? l10n.accessAdminSimilarRoleReviewBannerBody(
                      topMatch?.score ?? overallScore,
                    )
                  : l10n.accessAdminNoSimilarRoleDialogBody,
              variant: hasExactNameConflict
                  ? AppFormInformationVariant.error
                  : hasMatches
                  ? AppFormInformationVariant.warning
                  : AppFormInformationVariant.success,
              icon: hasExactNameConflict
                  ? Icons.gpp_bad_outlined
                  : hasMatches
                  ? Icons.manage_search_outlined
                  : Icons.verified_outlined,
            ),
            SizedBox(height: theme.spacing.md),
            _ProposedRoleCard(
              proposed: proposed,
              overallScore: overallScore,
              hasExactNameConflict: hasExactNameConflict,
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
                _RoleSimilarityMatchCard(
                  match: visibleMatches[index],
                  onUseExisting: () => Navigator.of(dialogContext).pop(
                    RoleSimilarityDialogResult.useExisting(
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
              const RoleSimilarityDialogResult.cancel(),
            ),
          ),
          if (canProceed)
            AppButton.primary(
              label: hasMatches
                  ? l10n.accessAdminProceedCreateRoleAction
                  : l10n.accessAdminContinueCreateRoleAction,
              leadingIcon: hasMatches
                  ? Icons.add_moderator_outlined
                  : Icons.check_circle_outline,
              onPressed: () => Navigator.of(dialogContext).pop(
                const RoleSimilarityDialogResult.proceed(),
              ),
            ),
        ],
      );
    },
  ).then(
    (RoleSimilarityDialogResult? value) =>
        value ?? const RoleSimilarityDialogResult.cancel(),
  );
}

class _ProposedRoleCard extends StatelessWidget {
  const _ProposedRoleCard({
    required this.proposed,
    required this.overallScore,
    required this.hasExactNameConflict,
    required this.hasMatches,
  });

  final RoleSimilarityProposedValues proposed;
  final int overallScore;
  final bool hasExactNameConflict;
  final bool hasMatches;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final AppStatusColors statusColors = theme.statusColors;
    final Color badgeContainer = hasExactNameConflict
        ? statusColors.errorContainer
        : hasMatches
        ? statusColors.warningContainer
        : statusColors.successContainer;
    final Color badgeOnContainer = hasExactNameConflict
        ? statusColors.onErrorContainer
        : hasMatches
        ? statusColors.onWarningContainer
        : statusColors.onSuccessContainer;
    final Color accent = hasExactNameConflict
        ? statusColors.error
        : hasMatches
        ? statusColors.warning
        : statusColors.success;

    final List<(String, String)> facts = <(String, String)>[
      (l10n.accessAdminRoleNameLabel, _display(proposed.name, l10n)),
      (
        l10n.accessAdminRoleDisplayNameLabel,
        _display(proposed.displayName, l10n),
      ),
      (
        l10n.accessAdminRoleScopeLabel,
        _display(_proposedScopeLabel(proposed, l10n), l10n),
      ),
      if ((proposed.description ?? '').trim().isNotEmpty)
        (
          l10n.accessAdminRoleDescriptionLabel,
          _display(proposed.description, l10n),
        ),
    ];

    return AppSectionPanel(
      tone: AppWorkspaceStatusTone.info,
      density: AppContentPanelDensity.compact,
      leadingIcon: Icons.edit_note_outlined,
      title: l10n.accessAdminSimilarRoleProposedHeading,
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
              l10n.accessAdminSimilarRoleOverallSimilarityLabel,
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

class _RoleSimilarityMatchCard extends StatelessWidget {
  const _RoleSimilarityMatchCard({
    required this.match,
    required this.onUseExisting,
  });

  final RoleSimilarityMatch match;
  final VoidCallback onUseExisting;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final AppStatusColors statusColors = theme.statusColors;
    final bool hardConflict =
        match.exactNameConflict || match.exactDisplayNameConflict;
    final Color accent = hardConflict
        ? statusColors.error
        : statusColors.warning;
    final Color badgeContainer = hardConflict
        ? statusColors.errorContainer
        : statusColors.warningContainer;
    final Color badgeOnContainer = hardConflict
        ? statusColors.onErrorContainer
        : statusColors.onWarningContainer;
    final List<RoleFieldComparison> comparisons = _sortedComparisons(
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
                hardConflict ? Icons.gpp_bad_outlined : Icons.badge_outlined,
                color: accent,
                size: theme.appTokens.listIconSize,
              ),
              SizedBox(width: theme.spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.accessAdminSimilarRoleExistingHeading,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: accent,
                      ),
                    ),
                    SizedBox(height: theme.spacing.xs / 2),
                    Text(
                      match.role.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: theme.spacing.xs / 2),
                    Text(
                      match.role.effectiveDisplayId,
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
                          ? l10n.accessAdminSimilarRoleExactConflictLabel
                          : match.score >= roleSimilarityThreshold
                          ? l10n.accessAdminSimilarRoleNearMatchLabel
                          : l10n.accessAdminSimilarRolePartialMatchLabel,
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
                      l10n.accessAdminSimilarRoleComparisonHeading,
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
              label: l10n.accessAdminUseExistingRoleAction,
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

  final RoleFieldComparison comparison;

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

  final RoleFieldComparison comparison;

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

  final RoleFieldComparison comparison;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final AppStatusColors statusColors = theme.statusColors;
    final (Color bg, Color fg, Color border) = switch (comparison.status) {
      RoleFieldComparisonStatus.match => (
        statusColors.successContainer,
        statusColors.onSuccessContainer,
        statusColors.success.withValues(alpha: 0.45),
      ),
      RoleFieldComparisonStatus.similar => (
        statusColors.warningContainer,
        statusColors.onWarningContainer,
        statusColors.warning.withValues(alpha: 0.45),
      ),
      RoleFieldComparisonStatus.different => (
        statusColors.errorContainer,
        statusColors.onErrorContainer,
        statusColors.error.withValues(alpha: 0.4),
      ),
      RoleFieldComparisonStatus.missing => (
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

String _statusLabel(AppLocalizations l10n, RoleFieldComparisonStatus status) {
  return switch (status) {
    RoleFieldComparisonStatus.match =>
      l10n.tenantFacilitySimilarFieldStatusMatch,
    RoleFieldComparisonStatus.similar =>
      l10n.tenantFacilitySimilarFieldStatusSimilar,
    RoleFieldComparisonStatus.different =>
      l10n.tenantFacilitySimilarFieldStatusDifferent,
    RoleFieldComparisonStatus.missing =>
      l10n.tenantFacilitySimilarFieldStatusMissing,
  };
}
