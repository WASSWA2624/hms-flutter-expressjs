import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/core/utils/app_display.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/department_similarity.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';
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

Future<DepartmentSimilarityDialogResult> showDepartmentSimilarityDialog(
  BuildContext context, {
  required DepartmentSimilarityProposedValues proposed,
  required List<DepartmentSimilarityMatch> matches,
  bool allowProceed = true,
}) {
  final AppLocalizations l10n = context.l10n;
  final List<DepartmentSimilarityMatch> visibleMatches = matches
      .take(5)
      .toList(growable: false);
  final bool hasExactNameConflict = visibleMatches.any(
    (DepartmentSimilarityMatch match) => match.exactNameConflict,
  );
  final bool hasMatches = visibleMatches.isNotEmpty;
  final bool canProceed = allowProceed && !hasExactNameConflict;
  final int overallScore = hasMatches
      ? visibleMatches
            .map((DepartmentSimilarityMatch match) => match.score)
            .reduce((int a, int b) => a > b ? a : b)
      : 0;

  final String dialogTitle = hasExactNameConflict || hasMatches
      ? l10n.tenantFacilitySimilarDepartmentDialogTitle
      : l10n.tenantFacilityNoSimilarDepartmentDialogTitle;

  final String proceedLabel = hasMatches
      ? l10n.tenantFacilityProceedCreateDepartmentAction
      : l10n.tenantFacilityContinueCreateDepartmentAction;

  return showAppDialog<DepartmentSimilarityDialogResult>(
    context: context,
    builder: (BuildContext dialogContext) {
      final ThemeData theme = Theme.of(dialogContext);
      final AppFormInformationVariant bannerVariant = hasExactNameConflict
          ? AppFormInformationVariant.error
          : hasMatches
          ? AppFormInformationVariant.warning
          : AppFormInformationVariant.success;
      final String bannerTitle = hasExactNameConflict
          ? l10n.tenantFacilityDepartmentNameAlreadyInUse
          : hasMatches
          ? l10n.tenantFacilitySimilarDepartmentWarningTitle
          : l10n.tenantFacilityNoSimilarDepartmentBannerTitle;
      final String bannerMessage = hasExactNameConflict
          ? l10n.tenantFacilitySimilarDepartmentWarningBody
          : hasMatches
          ? l10n.tenantFacilitySimilarDepartmentWarningBody
          : l10n.tenantFacilityNoSimilarDepartmentDialogBody;

      return AppDialog(
        title: Text(dialogTitle),
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
              title: bannerTitle,
              message: bannerMessage,
              variant: bannerVariant,
              icon: hasExactNameConflict
                  ? Icons.gpp_bad_outlined
                  : hasMatches
                  ? Icons.manage_search_outlined
                  : Icons.verified_outlined,
            ),
            SizedBox(height: theme.spacing.md),
            _ProposedDepartmentCard(
              proposed: proposed,
              overallScore: overallScore,
              hasMatches: hasMatches,
              hasExactNameConflict: hasExactNameConflict,
            ),
            SizedBox(height: theme.spacing.lg),
            if (hasMatches) ...<Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      l10n.tenantFacilitySimilarTenantMatchesHeading,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    l10n.tenantFacilitySimilarTenantMatchCountLabel(
                      visibleMatches.length,
                    ),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              SizedBox(height: theme.spacing.sm),
              for (int index = 0; index < visibleMatches.length; index += 1) ...<
                Widget
              >[
                if (index > 0) SizedBox(height: theme.spacing.md),
                _DepartmentSimilarityMatchCard(
                  match: visibleMatches[index],
                  onUseExisting: () => Navigator.of(dialogContext).pop(
                    DepartmentSimilarityDialogResult.useExisting(
                      visibleMatches[index].department,
                    ),
                  ),
                ),
              ],
            ] else
              _NoMatchScorePanel(score: overallScore),
          ],
        ),
        actions: <Widget>[
          AppButton.tertiary(
            label: l10n.commonCancelActionLabel,
            leadingIcon: Icons.close,
            onPressed: () => Navigator.of(dialogContext).pop(
              const DepartmentSimilarityDialogResult.cancel(),
            ),
          ),
          if (canProceed)
            AppButton.primary(
              label: proceedLabel,
              leadingIcon: hasMatches
                  ? Icons.add_home_work_outlined
                  : Icons.check_circle_outline,
              onPressed: () => Navigator.of(dialogContext).pop(
                const DepartmentSimilarityDialogResult.proceed(),
              ),
            ),
        ],
      );
    },
  ).then(
    (DepartmentSimilarityDialogResult? value) =>
        value ?? const DepartmentSimilarityDialogResult.cancel(),
  );
}

class _ProposedDepartmentCard extends StatelessWidget {
  const _ProposedDepartmentCard({
    required this.proposed,
    required this.overallScore,
    required this.hasMatches,
    required this.hasExactNameConflict,
  });

  final DepartmentSimilarityProposedValues proposed;
  final int overallScore;
  final bool hasMatches;
  final bool hasExactNameConflict;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final AppStatusColors statusColors = theme.statusColors;
    final String typeLabel = tenantFacilityDepartmentTypeLabel(l10n, proposed.type);
    final String statusLabel = tenantFacilityActiveStatusLabel(
      l10n,
      proposed.isActive,
    );
    final String shortName = resolveDepartmentShortName(
      proposed.name,
      proposed.shortName,
    );

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
      (l10n.tenantFacilityDepartmentNameLabel, _display(proposed.name, l10n)),
      (
        l10n.tenantFacilityDepartmentShortNameLabel,
        _display(shortName, l10n),
      ),
      (l10n.tenantFacilityDepartmentTypeLabel, typeLabel),
      (l10n.tenantFacilityActiveLabel, statusLabel),
    ];

    return AppSectionPanel(
      tone: AppWorkspaceStatusTone.info,
      density: AppContentPanelDensity.compact,
      leadingIcon: Icons.edit_note_outlined,
      title: l10n.tenantFacilitySimilarDepartmentProposedHeading,
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
              l10n.tenantFacilityDepartmentOverallSimilarityLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: badgeOnContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '$overallScore%',
              style: theme.textTheme.titleSmall?.copyWith(
                color: badgeOnContainer,
                fontWeight: FontWeight.w800,
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
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: theme.spacing.xs / 2),
                    Text(
                      value,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
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

  String _display(String? value, AppLocalizations l10n) {
    final String trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? l10n.clinicalOrderEmptyValueLabel : trimmed;
  }
}

class _NoMatchScorePanel extends StatelessWidget {
  const _NoMatchScorePanel({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final AppStatusColors statusColors = theme.statusColors;

    return AppContentPanel(
      tone: AppWorkspaceStatusTone.success,
      density: AppContentPanelDensity.compact,
      child: Row(
        children: <Widget>[
          Icon(
            Icons.verified_outlined,
            color: statusColors.success,
            size: theme.appTokens.listIconSize,
          ),
          SizedBox(width: theme.spacing.sm),
          Expanded(
            child: Text(
              l10n.tenantFacilityDepartmentNoMatchScoreLabel(score),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: theme.spacing.sm,
              vertical: theme.spacing.xs,
            ),
            decoration: BoxDecoration(
              color: statusColors.successContainer,
              borderRadius: BorderRadius.circular(theme.radius.md),
              border: Border.all(
                color: statusColors.success.withValues(alpha: 0.55),
              ),
            ),
            child: Text(
              '$score%',
              style: theme.textTheme.labelLarge?.copyWith(
                color: statusColors.onSuccessContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DepartmentSimilarityMatchCard extends StatelessWidget {
  const _DepartmentSimilarityMatchCard({
    required this.match,
    required this.onUseExisting,
  });

  final DepartmentSimilarityMatch match;
  final VoidCallback onUseExisting;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final AppStatusColors statusColors = theme.statusColors;
    final bool hardConflict = match.exactNameConflict;
    final Color accent = hardConflict
        ? statusColors.error
        : statusColors.warning;
    final Color badgeContainer = hardConflict
        ? statusColors.errorContainer
        : statusColors.warningContainer;
    final Color badgeOnContainer = hardConflict
        ? statusColors.onErrorContainer
        : statusColors.onWarningContainer;
    final List<DepartmentFieldComparison> comparisons = _sortedComparisons(
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
                hardConflict
                    ? Icons.gpp_bad_outlined
                    : Icons.account_tree_outlined,
                color: accent,
                size: theme.appTokens.listIconSize,
              ),
              SizedBox(width: theme.spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.tenantFacilitySimilarDepartmentExistingHeading,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                    SizedBox(height: theme.spacing.xs / 2),
                    Text(
                      match.department.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (match.department.displayId != null &&
                        match.department.displayId!.trim().isNotEmpty) ...<Widget>[
                      SizedBox(height: theme.spacing.xs / 2),
                      Text(
                        match.department.displayId!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      hardConflict
                          ? l10n.tenantFacilitySimilarTenantExactConflictLabel
                          : match.score >= departmentSimilarityThreshold
                          ? l10n.tenantFacilitySimilarTenantNearMatchLabel
                          : l10n.tenantFacilitySimilarTenantPartialMatchLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: badgeOnContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: theme.spacing.md),
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(theme.radius.sm),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(theme.spacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    l10n.tenantFacilitySimilarTenantComparisonHeading,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
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
          SizedBox(height: theme.spacing.md),
          Align(
            alignment: Alignment.centerRight,
            child: AppButton.secondary(
              label: l10n.tenantFacilityUseThisDepartmentAction,
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
      fontWeight: FontWeight.w800,
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

  final DepartmentFieldComparison comparison;

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
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            _comparisonValue(l10n, comparison.field, comparison.inputValue),
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            _comparisonValue(
              l10n,
              comparison.field,
              comparison.candidateValue,
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
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

  final DepartmentFieldComparison comparison;

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
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            _StatusChip(comparison: comparison),
          ],
        ),
        SizedBox(height: theme.spacing.xs),
        _StackedValue(
          label: l10n.tenantFacilitySimilarTenantProposedValueLabel,
          value: _comparisonValue(l10n, comparison.field, comparison.inputValue),
        ),
        SizedBox(height: theme.spacing.xs / 2),
        _StackedValue(
          label: l10n.tenantFacilitySimilarTenantExistingValueLabel,
          value: _comparisonValue(
            l10n,
            comparison.field,
            comparison.candidateValue,
          ),
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
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.comparison});

  final DepartmentFieldComparison comparison;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final AppStatusColors statusColors = theme.statusColors;
    final (Color bg, Color fg, Color border) = switch (comparison.status) {
      DepartmentFieldComparisonStatus.match => (
        statusColors.successContainer,
        statusColors.onSuccessContainer,
        statusColors.success.withValues(alpha: 0.45),
      ),
      DepartmentFieldComparisonStatus.similar => (
        statusColors.warningContainer,
        statusColors.onWarningContainer,
        statusColors.warning.withValues(alpha: 0.45),
      ),
      DepartmentFieldComparisonStatus.different => (
        statusColors.errorContainer,
        statusColors.onErrorContainer,
        statusColors.error.withValues(alpha: 0.4),
      ),
      DepartmentFieldComparisonStatus.missing => (
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
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

List<DepartmentFieldComparison> _sortedComparisons(
  List<DepartmentFieldComparison> comparisons,
) {
  int rank(DepartmentFieldComparisonStatus status) {
    return switch (status) {
      DepartmentFieldComparisonStatus.match => 0,
      DepartmentFieldComparisonStatus.similar => 1,
      DepartmentFieldComparisonStatus.different => 2,
      DepartmentFieldComparisonStatus.missing => 3,
    };
  }

  final List<DepartmentFieldComparison> next =
      List<DepartmentFieldComparison>.of(comparisons);
  next.sort((DepartmentFieldComparison left, DepartmentFieldComparison right) {
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

String _comparisonValue(
  AppLocalizations l10n,
  String field,
  String? value,
) {
  if (value == null) {
    return _display(value, l10n);
  }

  return switch (field) {
    'department_type' => _departmentTypeDisplay(l10n, value),
    'status' => tenantFacilityActiveStatusLabel(
      l10n,
      value.trim().toLowerCase() == 'active',
    ),
    _ => _display(value, l10n),
  };
}

String _departmentTypeDisplay(AppLocalizations l10n, String value) {
  final DepartmentSetupType? type = _parseDepartmentType(value);
  if (type != null) {
    return tenantFacilityDepartmentTypeLabel(l10n, type);
  }
  return _display(value, l10n);
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

String _fieldLabel(AppLocalizations l10n, String field) {
  return switch (field) {
    'name' => l10n.tenantFacilityDepartmentNameLabel,
    'short_name' => l10n.tenantFacilityDepartmentShortNameLabel,
    'department_type' => l10n.tenantFacilityDepartmentTypeLabel,
    'status' => l10n.tenantFacilityActiveLabel,
    'display_id' => l10n.accessAdminColumnDetails,
    _ => AppDisplay.apiLabel(field),
  };
}

String _statusLabel(
  AppLocalizations l10n,
  DepartmentFieldComparisonStatus status,
) {
  return switch (status) {
    DepartmentFieldComparisonStatus.match =>
      l10n.tenantFacilitySimilarFieldStatusMatch,
    DepartmentFieldComparisonStatus.similar =>
      l10n.tenantFacilitySimilarFieldStatusSimilar,
    DepartmentFieldComparisonStatus.different =>
      l10n.tenantFacilitySimilarFieldStatusDifferent,
    DepartmentFieldComparisonStatus.missing =>
      l10n.tenantFacilitySimilarFieldStatusMissing,
  };
}
