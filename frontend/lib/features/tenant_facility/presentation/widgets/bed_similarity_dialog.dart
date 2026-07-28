import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/unit_similarity.dart';
import 'package:hosspi_hms/features/tenant_facility/presentation/widgets/tenant_facility_setup_helpers.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

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

Future<UnitSimilarityDialogResult> showUnitSimilarityDialog(
  BuildContext context, {
  required UnitSimilarityProposedValues proposed,
  required List<UnitSimilarityMatch> matches,
  bool allowProceed = true,
}) {
  final AppLocalizations l10n = context.l10n;
  final List<UnitSimilarityMatch> visibleMatches = matches
      .take(5)
      .toList(growable: false);
  final bool hasExactNameConflict = visibleMatches.any(
    (UnitSimilarityMatch match) => match.exactNameConflict,
  );
  final bool hasMatches = visibleMatches.isNotEmpty;
  final bool canProceed = allowProceed && !hasExactNameConflict;
  final int overallScore = hasMatches
      ? visibleMatches
            .map((UnitSimilarityMatch match) => match.score)
            .reduce((int a, int b) => a > b ? a : b)
      : 0;

  final String dialogTitle = hasExactNameConflict || hasMatches
      ? l10n.tenantFacilitySimilarUnitDialogTitle
      : l10n.tenantFacilityNoSimilarUnitDialogTitle;

  final String proceedLabel = hasMatches
      ? l10n.tenantFacilityProceedCreateUnitAction
      : l10n.tenantFacilityContinueCreateUnitAction;

  return showAppDialog<UnitSimilarityDialogResult>(
    context: context,
    builder: (BuildContext dialogContext) {
      final ThemeData theme = Theme.of(dialogContext);
      final AppFormInformationVariant bannerVariant = hasExactNameConflict
          ? AppFormInformationVariant.error
          : hasMatches
          ? AppFormInformationVariant.warning
          : AppFormInformationVariant.success;
      final String bannerTitle = hasExactNameConflict
          ? l10n.tenantFacilityUnitNameAlreadyInUse
          : hasMatches
          ? l10n.tenantFacilitySimilarUnitWarningTitle
          : l10n.tenantFacilityNoSimilarUnitBannerTitle;
      final String bannerMessage = hasExactNameConflict
          ? l10n.tenantFacilitySimilarUnitWarningBody
          : hasMatches
          ? l10n.tenantFacilitySimilarUnitWarningBody
          : l10n.tenantFacilityNoSimilarUnitDialogBody;

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
            _ProposedUnitCard(
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
                _UnitSimilarityMatchCard(
                  match: visibleMatches[index],
                  onUseExisting: () => Navigator.of(dialogContext).pop(
                    UnitSimilarityDialogResult.useExisting(
                      visibleMatches[index].unit,
                    ),
                  ),
                ),
              ],
            ] else
              _UnitNoMatchScorePanel(score: overallScore),
          ],
        ),
        actions: <Widget>[
          AppButton.tertiary(
            label: l10n.commonCancelActionLabel,
            leadingIcon: Icons.close,
            onPressed: () => Navigator.of(dialogContext).pop(
              const UnitSimilarityDialogResult.cancel(),
            ),
          ),
          if (canProceed)
            AppButton.primary(
              label: proceedLabel,
              leadingIcon: hasMatches
                  ? Icons.add_home_work_outlined
                  : Icons.check_circle_outline,
              onPressed: () => Navigator.of(dialogContext).pop(
                const UnitSimilarityDialogResult.proceed(),
              ),
            ),
        ],
      );
    },
  ).then(
    (UnitSimilarityDialogResult? value) =>
        value ?? const UnitSimilarityDialogResult.cancel(),
  );
}

class _ProposedUnitCard extends StatelessWidget {
  const _ProposedUnitCard({
    required this.proposed,
    required this.overallScore,
    required this.hasMatches,
    required this.hasExactNameConflict,
  });

  final UnitSimilarityProposedValues proposed;
  final int overallScore;
  final bool hasMatches;
  final bool hasExactNameConflict;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final AppStatusColors statusColors = theme.statusColors;
    final String statusLabel = tenantFacilityActiveStatusLabel(
      l10n,
      proposed.isActive,
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
      (l10n.tenantFacilityUnitNameLabel, _display(proposed.name, l10n)),
      (
        l10n.tenantFacilityUnitDepartmentLabel,
        _display(proposed.departmentName, l10n),
      ),
      (l10n.tenantFacilityActiveLabel, statusLabel),
    ];

    return AppSectionPanel(
      tone: AppWorkspaceStatusTone.info,
      density: AppContentPanelDensity.compact,
      leadingIcon: Icons.edit_note_outlined,
      title: l10n.tenantFacilitySimilarUnitProposedHeading,
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
              l10n.tenantFacilityUnitOverallSimilarityLabel,
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

class _UnitNoMatchScorePanel extends StatelessWidget {
  const _UnitNoMatchScorePanel({required this.score});

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
              l10n.tenantFacilityUnitNoMatchScoreLabel(score),
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

class _UnitSimilarityMatchCard extends StatelessWidget {
  const _UnitSimilarityMatchCard({
    required this.match,
    required this.onUseExisting,
  });

  final UnitSimilarityMatch match;
  final VoidCallback onUseExisting;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final AppStatusColors statusColors = theme.statusColors;
    final UnitProfile unit = match.unit;
    final Color accent = match.exactNameConflict
        ? statusColors.error
        : statusColors.warning;

    return AppContentPanel(
      tone: match.exactNameConflict
          ? AppWorkspaceStatusTone.error
          : AppWorkspaceStatusTone.warning,
      density: AppContentPanelDensity.compact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.tenantFacilitySimilarUnitExistingHeading,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: theme.spacing.xs / 2),
                    Text(
                      unit.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if ((match.departmentName ?? '').trim().isNotEmpty) ...<
                      Widget
                    >[
                      SizedBox(height: theme.spacing.xs / 2),
                      Text(
                        match.departmentName!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: theme.spacing.sm,
                  vertical: theme.spacing.xs,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(theme.radius.md),
                  border: Border.all(color: accent.withValues(alpha: 0.45)),
                ),
                child: Text(
                  '${match.score}%',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: theme.spacing.sm),
          Wrap(
            spacing: theme.spacing.sm,
            runSpacing: theme.spacing.xs,
            children: <Widget>[
              for (final UnitFieldComparison comparison
                  in match.fieldComparisons)
                if (comparison.score != null)
                  Text(
                    '${comparison.field}: ${comparison.score}%',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
            ],
          ),
          SizedBox(height: theme.spacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: AppButton.secondary(
              label: l10n.tenantFacilityUseThisUnitAction,
              leadingIcon: Icons.check,
              onPressed: onUseExisting,
            ),
          ),
        ],
      ),
    );
  }
}
