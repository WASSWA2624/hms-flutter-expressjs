import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/room_similarity.dart';
import 'package:hosspi_hms/features/tenant_facility/domain/entities/tenant_facility_setup.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

enum RoomSimilarityAction { cancel, useExisting, proceed }

final class RoomSimilarityDialogResult {
  const RoomSimilarityDialogResult._({
    required this.action,
    this.selectedRoom,
  });

  const RoomSimilarityDialogResult.cancel()
    : this._(action: RoomSimilarityAction.cancel);

  const RoomSimilarityDialogResult.proceed()
    : this._(action: RoomSimilarityAction.proceed);

  const RoomSimilarityDialogResult.useExisting(RoomProfile room)
    : this._(action: RoomSimilarityAction.useExisting, selectedRoom: room);

  final RoomSimilarityAction action;
  final RoomProfile? selectedRoom;
}

Future<RoomSimilarityDialogResult> showRoomSimilarityDialog(
  BuildContext context, {
  required RoomSimilarityProposedValues proposed,
  required List<RoomSimilarityMatch> matches,
  bool allowProceed = true,
}) {
  final AppLocalizations l10n = context.l10n;
  final List<RoomSimilarityMatch> visibleMatches = matches
      .take(5)
      .toList(growable: false);
  final bool hasExactNameConflict = visibleMatches.any(
    (RoomSimilarityMatch match) => match.exactNameConflict,
  );
  final bool hasMatches = visibleMatches.isNotEmpty;
  final bool canProceed = allowProceed && !hasExactNameConflict;
  final int overallScore = hasMatches
      ? visibleMatches
            .map((RoomSimilarityMatch match) => match.score)
            .reduce((int a, int b) => a > b ? a : b)
      : 0;

  final String dialogTitle = hasExactNameConflict || hasMatches
      ? l10n.tenantFacilitySimilarRoomDialogTitle
      : l10n.tenantFacilityNoSimilarRoomDialogTitle;

  final String proceedLabel = hasMatches
      ? l10n.tenantFacilityProceedCreateRoomAction
      : l10n.tenantFacilityContinueCreateRoomAction;

  return showAppDialog<RoomSimilarityDialogResult>(
    context: context,
    builder: (BuildContext dialogContext) {
      final ThemeData theme = Theme.of(dialogContext);
      final AppFormInformationVariant bannerVariant = hasExactNameConflict
          ? AppFormInformationVariant.error
          : hasMatches
          ? AppFormInformationVariant.warning
          : AppFormInformationVariant.success;
      final String bannerTitle = hasExactNameConflict
          ? l10n.tenantFacilityRoomNameAlreadyInUse
          : hasMatches
          ? l10n.tenantFacilitySimilarRoomWarningTitle
          : l10n.tenantFacilityNoSimilarRoomBannerTitle;
      final String bannerMessage = hasExactNameConflict
          ? l10n.tenantFacilitySimilarRoomWarningBody
          : hasMatches
          ? l10n.tenantFacilitySimilarRoomWarningBody
          : l10n.tenantFacilityNoSimilarRoomDialogBody;

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
            _ProposedRoomCard(
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
                _RoomSimilarityMatchCard(
                  match: visibleMatches[index],
                  onUseExisting: () => Navigator.of(dialogContext).pop(
                    RoomSimilarityDialogResult.useExisting(
                      visibleMatches[index].room,
                    ),
                  ),
                ),
              ],
            ] else
              _RoomNoMatchScorePanel(score: overallScore),
          ],
        ),
        actions: <Widget>[
          AppButton.tertiary(
            label: l10n.commonCancelActionLabel,
            leadingIcon: Icons.close,
            onPressed: () => Navigator.of(dialogContext).pop(
              const RoomSimilarityDialogResult.cancel(),
            ),
          ),
          if (canProceed)
            AppButton.primary(
              label: proceedLabel,
              leadingIcon: hasMatches
                  ? Icons.add_home_work_outlined
                  : Icons.check_circle_outline,
              onPressed: () => Navigator.of(dialogContext).pop(
                const RoomSimilarityDialogResult.proceed(),
              ),
            ),
        ],
      );
    },
  ).then(
    (RoomSimilarityDialogResult? value) =>
        value ?? const RoomSimilarityDialogResult.cancel(),
  );
}

class _ProposedRoomCard extends StatelessWidget {
  const _ProposedRoomCard({
    required this.proposed,
    required this.overallScore,
    required this.hasMatches,
    required this.hasExactNameConflict,
  });

  final RoomSimilarityProposedValues proposed;
  final int overallScore;
  final bool hasMatches;
  final bool hasExactNameConflict;

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
      (l10n.tenantFacilityRoomNameLabel, _display(proposed.name, l10n)),
      (
        l10n.tenantFacilityRoomWardLabel,
        _display(proposed.wardName, l10n),
      ),
      (l10n.tenantFacilityRoomFloorLabel, _display(proposed.floor, l10n)),
    ];

    return AppSectionPanel(
      tone: AppWorkspaceStatusTone.info,
      density: AppContentPanelDensity.compact,
      leadingIcon: Icons.edit_note_outlined,
      title: l10n.tenantFacilitySimilarRoomProposedHeading,
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
              l10n.tenantFacilityRoomOverallSimilarityLabel,
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

class _RoomNoMatchScorePanel extends StatelessWidget {
  const _RoomNoMatchScorePanel({required this.score});

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
              l10n.tenantFacilityRoomNoMatchScoreLabel(score),
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

class _RoomSimilarityMatchCard extends StatelessWidget {
  const _RoomSimilarityMatchCard({
    required this.match,
    required this.onUseExisting,
  });

  final RoomSimilarityMatch match;
  final VoidCallback onUseExisting;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final AppStatusColors statusColors = theme.statusColors;
    final RoomProfile room = match.room;
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
                      l10n.tenantFacilitySimilarRoomExistingHeading,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: theme.spacing.xs / 2),
                    Text(
                      room.name,
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
                    if ((room.floor ?? '').trim().isNotEmpty) ...<Widget>[
                      SizedBox(height: theme.spacing.xs / 2),
                      Text(
                        room.floor!,
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
              for (final RoomFieldComparison comparison
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
              label: l10n.tenantFacilityUseThisRoomAction,
              leadingIcon: Icons.check,
              onPressed: onUseExisting,
            ),
          ),
        ],
      ),
    );
  }
}
