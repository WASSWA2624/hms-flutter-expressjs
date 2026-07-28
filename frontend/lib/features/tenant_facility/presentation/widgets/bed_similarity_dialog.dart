import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/bed_similarity.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

enum BedSimilarityAction { cancel, useExisting, proceed }

final class BedSimilarityDialogResult {
  const BedSimilarityDialogResult._({
    required this.action,
    this.selectedBed,
  });

  const BedSimilarityDialogResult.cancel()
    : this._(action: BedSimilarityAction.cancel);

  const BedSimilarityDialogResult.proceed()
    : this._(action: BedSimilarityAction.proceed);

  const BedSimilarityDialogResult.useExisting(BedProfile bed)
    : this._(action: BedSimilarityAction.useExisting, selectedBed: bed);

  final BedSimilarityAction action;
  final BedProfile? selectedBed;
}

Future<BedSimilarityDialogResult> showBedSimilarityDialog(
  BuildContext context, {
  required BedSimilarityProposedValues proposed,
  required List<BedSimilarityMatch> matches,
  bool allowProceed = true,
}) {
  final AppLocalizations l10n = context.l10n;
  final List<BedSimilarityMatch> visibleMatches = matches
      .take(5)
      .toList(growable: false);
  final bool hasExactLabelConflict = visibleMatches.any(
    (BedSimilarityMatch match) => match.exactLabelConflict,
  );
  final bool hasMatches = visibleMatches.isNotEmpty;
  final bool canProceed = allowProceed && !hasExactLabelConflict;
  final int overallScore = hasMatches
      ? visibleMatches
            .map((BedSimilarityMatch match) => match.score)
            .reduce((int a, int b) => a > b ? a : b)
      : 0;

  final String dialogTitle = hasExactLabelConflict || hasMatches
      ? l10n.tenantFacilitySimilarBedDialogTitle
      : l10n.tenantFacilityNoSimilarBedDialogTitle;

  final String proceedLabel = hasMatches
      ? l10n.tenantFacilityProceedCreateBedAction
      : l10n.tenantFacilityContinueCreateBedAction;

  return showAppDialog<BedSimilarityDialogResult>(
    context: context,
    builder: (BuildContext dialogContext) {
      final ThemeData theme = Theme.of(dialogContext);
      final AppFormInformationVariant bannerVariant = hasExactLabelConflict
          ? AppFormInformationVariant.error
          : hasMatches
          ? AppFormInformationVariant.warning
          : AppFormInformationVariant.success;
      final String bannerTitle = hasExactLabelConflict
          ? l10n.tenantFacilityBedLabelAlreadyInUse
          : hasMatches
          ? l10n.tenantFacilitySimilarBedWarningTitle
          : l10n.tenantFacilityNoSimilarBedBannerTitle;
      final String bannerMessage = hasExactLabelConflict
          ? l10n.tenantFacilitySimilarBedWarningBody
          : hasMatches
          ? l10n.tenantFacilitySimilarBedWarningBody
          : l10n.tenantFacilityNoSimilarBedDialogBody;

      return AppDialog(
        title: Text(dialogTitle),
        icon: Icon(
          hasExactLabelConflict
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
              icon: hasExactLabelConflict
                  ? Icons.gpp_bad_outlined
                  : hasMatches
                  ? Icons.manage_search_outlined
                  : Icons.verified_outlined,
            ),
            SizedBox(height: theme.spacing.md),
            _ProposedBedCard(
              proposed: proposed,
              overallScore: overallScore,
              hasMatches: hasMatches,
              hasExactLabelConflict: hasExactLabelConflict,
            ),
            SizedBox(height: theme.spacing.lg),
            if (hasMatches) ...<Widget>[
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
                _BedSimilarityMatchCard(
                  match: visibleMatches[index],
                  onUseExisting: () => Navigator.of(dialogContext).pop(
                    BedSimilarityDialogResult.useExisting(
                      visibleMatches[index].bed,
                    ),
                  ),
                ),
              ],
            ] else
              _BedNoMatchScorePanel(score: overallScore),
          ],
        ),
        actions: <Widget>[
          AppButton.tertiary(
            label: l10n.commonCancelActionLabel,
            leadingIcon: Icons.close,
            onPressed: () => Navigator.of(dialogContext).pop(
              const BedSimilarityDialogResult.cancel(),
            ),
          ),
          if (canProceed)
            AppButton.primary(
              label: proceedLabel,
              leadingIcon: hasMatches
                  ? Icons.add_home_work_outlined
                  : Icons.check_circle_outline,
              onPressed: () => Navigator.of(dialogContext).pop(
                const BedSimilarityDialogResult.proceed(),
              ),
            ),
        ],
      );
    },
  ).then(
    (BedSimilarityDialogResult? value) =>
        value ?? const BedSimilarityDialogResult.cancel(),
  );
}

class _ProposedBedCard extends StatelessWidget {
  const _ProposedBedCard({
    required this.proposed,
    required this.overallScore,
    required this.hasMatches,
    required this.hasExactLabelConflict,
  });

  final BedSimilarityProposedValues proposed;
  final int overallScore;
  final bool hasMatches;
  final bool hasExactLabelConflict;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final AppStatusColors statusColors = theme.statusColors;

    final Color badgeContainer = hasExactLabelConflict
        ? statusColors.errorContainer
        : hasMatches
        ? statusColors.warningContainer
        : statusColors.successContainer;
    final Color badgeOnContainer = hasExactLabelConflict
        ? statusColors.onErrorContainer
        : hasMatches
        ? statusColors.onWarningContainer
        : statusColors.onSuccessContainer;
    final Color accent = hasExactLabelConflict
        ? statusColors.error
        : hasMatches
        ? statusColors.warning
        : statusColors.success;

    final List<(String, String)> facts = <(String, String)>[
      (l10n.tenantFacilityBedLabelLabel, _display(proposed.label, l10n)),
      (l10n.tenantFacilityBedWardLabel, _display(proposed.wardName, l10n)),
      (l10n.tenantFacilityBedRoomLabel, _display(proposed.roomName, l10n)),
      (l10n.tenantFacilityBedStatusLabel, _display(proposed.statusLabel, l10n)),
    ];

    return AppSectionPanel(
      tone: AppWorkspaceStatusTone.info,
      density: AppContentPanelDensity.compact,
      leadingIcon: Icons.edit_note_outlined,
      title: l10n.tenantFacilitySimilarBedProposedHeading,
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
              l10n.tenantFacilityBedOverallSimilarityLabel,
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

  String _display(String? value, AppLocalizations l10n) {
    final String trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? l10n.clinicalOrderEmptyValueLabel : trimmed;
  }
}

class _BedNoMatchScorePanel extends StatelessWidget {
  const _BedNoMatchScorePanel({required this.score});

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
              l10n.tenantFacilityBedNoMatchScoreLabel(score),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
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
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BedSimilarityMatchCard extends StatelessWidget {
  const _BedSimilarityMatchCard({
    required this.match,
    required this.onUseExisting,
  });

  final BedSimilarityMatch match;
  final VoidCallback onUseExisting;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final AppStatusColors statusColors = theme.statusColors;
    final BedProfile bed = match.bed;
    final Color accent = match.exactLabelConflict
        ? statusColors.error
        : statusColors.warning;

    return AppContentPanel(
      tone: match.exactLabelConflict
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
                      l10n.tenantFacilitySimilarBedExistingHeading,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: theme.spacing.xs / 2),
                    Text(
                      bed.label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if ((match.wardName ?? '').trim().isNotEmpty) ...<Widget>[
                      SizedBox(height: theme.spacing.xs / 2),
                      Text(
                        match.wardName!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if ((match.roomName ?? '').trim().isNotEmpty) ...<Widget>[
                      SizedBox(height: theme.spacing.xs / 2),
                      Text(
                        match.roomName!,
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
                    fontWeight: FontWeight.w600,
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
              for (final BedFieldComparison comparison
                  in match.fieldComparisons)
                if (comparison.score != null)
                  Text(
                    '${comparison.field}: ${comparison.score}%',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
            ],
          ),
          SizedBox(height: theme.spacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: AppButton.secondary(
              label: l10n.tenantFacilityUseThisBedAction,
              leadingIcon: Icons.check,
              onPressed: onUseExisting,
            ),
          ),
        ],
      ),
    );
  }
}
