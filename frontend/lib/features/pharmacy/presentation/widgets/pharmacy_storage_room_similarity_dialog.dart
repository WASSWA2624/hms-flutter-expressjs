import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/app_workspace.dart';

enum PharmacyStorageRoomSimilarityAction { cancel, useExisting, proceed }

final class PharmacyStorageRoomSimilarityDialogResult {
  const PharmacyStorageRoomSimilarityDialogResult._({
    required this.action,
    this.selectedRoom,
  });

  const PharmacyStorageRoomSimilarityDialogResult.cancel()
    : this._(action: PharmacyStorageRoomSimilarityAction.cancel);

  const PharmacyStorageRoomSimilarityDialogResult.proceed()
    : this._(action: PharmacyStorageRoomSimilarityAction.proceed);

  const PharmacyStorageRoomSimilarityDialogResult.useExisting(
    PharmacyStorageRoom room,
  ) : this._(
        action: PharmacyStorageRoomSimilarityAction.useExisting,
        selectedRoom: room,
      );

  final PharmacyStorageRoomSimilarityAction action;
  final PharmacyStorageRoom? selectedRoom;
}

final class PharmacyStorageRoomSimilarityProposedValues {
  const PharmacyStorageRoomSimilarityProposedValues({
    required this.name,
    this.code,
  });

  final String name;
  final String? code;
}

Future<PharmacyStorageRoomSimilarityDialogResult>
showPharmacyStorageRoomSimilarityDialog(
  BuildContext context, {
  required PharmacyStorageRoomSimilarityProposedValues proposed,
  required PharmacyStorageRoomSimilarityResult check,
  bool isEdit = false,
}) {
  final AppLocalizations l10n = context.l10n;
  final List<PharmacyStorageRoomSimilarityMatch> visibleMatches = check.matches
      .take(5)
      .toList(growable: false);
  final bool hasExactConflict = check.hasExactConflict;
  final bool hasMatches = visibleMatches.isNotEmpty;
  final bool canProceed = !hasExactConflict;
  final int overallScore = check.closestScore;

  final String dialogTitle = hasExactConflict
      ? l10n.pharmacyStorageRoomDuplicateDialogTitle
      : hasMatches
      ? l10n.pharmacyStorageRoomSimilarDialogTitle
      : l10n.pharmacyStorageRoomNoSimilarDialogTitle;

  final String proceedLabel = hasMatches
      ? l10n.pharmacyStorageRoomCreateAnywayAction
      : l10n.commonContinueActionLabel;

  return showAppDialog<PharmacyStorageRoomSimilarityDialogResult>(
    context: context,
    builder: (BuildContext dialogContext) {
      final ThemeData theme = Theme.of(dialogContext);
      final AppFormInformationVariant bannerVariant = hasExactConflict
          ? AppFormInformationVariant.error
          : hasMatches
          ? AppFormInformationVariant.warning
          : AppFormInformationVariant.success;
      final String bannerTitle = hasExactConflict
          ? l10n.pharmacyStorageRoomExactBannerTitle
          : hasMatches
          ? l10n.pharmacyStorageRoomSimilarBannerTitle
          : l10n.pharmacyStorageRoomNoSimilarBannerTitle;
      final String bannerMessage = hasExactConflict
          ? l10n.pharmacyStorageRoomDuplicateDialogBody
          : hasMatches
          ? l10n.pharmacyStorageRoomSimilarDialogBody(overallScore)
          : l10n.pharmacyStorageRoomNoSimilarDialogBody;

      return AppDialog(
        title: Text(dialogTitle),
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
              title: bannerTitle,
              message: bannerMessage,
              variant: bannerVariant,
              icon: hasExactConflict
                  ? Icons.gpp_bad_outlined
                  : hasMatches
                  ? Icons.manage_search_outlined
                  : Icons.verified_outlined,
            ),
            SizedBox(height: theme.spacing.md),
            _ProposedStorageRoomCard(
              proposed: proposed,
              overallScore: overallScore,
              hasMatches: hasMatches,
              hasExactConflict: hasExactConflict,
            ),
            SizedBox(height: theme.spacing.lg),
            if (hasMatches) ...<Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      l10n.pharmacyStorageRoomMatchesHeading,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.start,
                    ),
                  ),
                  Text(
                    l10n.pharmacyStorageRoomMatchCountLabel(
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
              for (
                int index = 0;
                index < visibleMatches.length;
                index += 1
              ) ...<Widget>[
                if (index > 0) SizedBox(height: theme.spacing.md),
                _StorageRoomSimilarityMatchCard(
                  match: visibleMatches[index],
                  proposed: proposed,
                  onUseExisting: () => Navigator.of(dialogContext).pop(
                    PharmacyStorageRoomSimilarityDialogResult.useExisting(
                      visibleMatches[index].room,
                    ),
                  ),
                ),
              ],
            ] else
              _StorageRoomNoMatchScorePanel(score: overallScore),
          ],
        ),
        actions: <Widget>[
          AppButton.tertiary(
            label: l10n.commonCancelActionLabel,
            leadingIcon: Icons.close,
            onPressed: () => Navigator.of(dialogContext).pop(
              const PharmacyStorageRoomSimilarityDialogResult.cancel(),
            ),
          ),
          if (canProceed)
            AppButton.primary(
              label: isEdit && !hasMatches
                  ? l10n.commonContinueActionLabel
                  : proceedLabel,
              leadingIcon: hasMatches
                  ? Icons.add_home_work_outlined
                  : Icons.check_circle_outline,
              onPressed: () => Navigator.of(dialogContext).pop(
                const PharmacyStorageRoomSimilarityDialogResult.proceed(),
              ),
            ),
        ],
      );
    },
  ).then(
    (PharmacyStorageRoomSimilarityDialogResult? value) =>
        value ?? const PharmacyStorageRoomSimilarityDialogResult.cancel(),
  );
}

class _ProposedStorageRoomCard extends StatelessWidget {
  const _ProposedStorageRoomCard({
    required this.proposed,
    required this.overallScore,
    required this.hasMatches,
    required this.hasExactConflict,
  });

  final PharmacyStorageRoomSimilarityProposedValues proposed;
  final int overallScore;
  final bool hasMatches;
  final bool hasExactConflict;

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
      (l10n.pharmacyStorageRoomNameLabel, _display(proposed.name, l10n)),
      (l10n.pharmacyStorageRoomCodeLabel, _display(proposed.code, l10n)),
    ];

    return AppSectionPanel(
      tone: AppWorkspaceStatusTone.info,
      density: AppContentPanelDensity.compact,
      leadingIcon: Icons.edit_note_outlined,
      title: l10n.pharmacyStorageRoomProposedHeading,
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
              l10n.pharmacyStorageRoomOverallSimilarityLabel,
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
                      textAlign: TextAlign.start,
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

class _StorageRoomNoMatchScorePanel extends StatelessWidget {
  const _StorageRoomNoMatchScorePanel({required this.score});

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
              l10n.pharmacyStorageRoomNoMatchScoreLabel(score),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.start,
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

class _StorageRoomSimilarityMatchCard extends StatelessWidget {
  const _StorageRoomSimilarityMatchCard({
    required this.match,
    required this.proposed,
    required this.onUseExisting,
  });

  final PharmacyStorageRoomSimilarityMatch match;
  final PharmacyStorageRoomSimilarityProposedValues proposed;
  final VoidCallback onUseExisting;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final AppStatusColors statusColors = theme.statusColors;
    final PharmacyStorageRoom room = match.room;
    final bool exact = match.hasExactConflict || match.isExact;
    final Color accent = exact ? statusColors.error : statusColors.warning;
    final List<PharmacyStorageRoomFieldComparison> comparisons =
        match.fieldComparisons.isNotEmpty
        ? match.fieldComparisons
        : <PharmacyStorageRoomFieldComparison>[
            PharmacyStorageRoomFieldComparison(
              field: 'name',
              inputValue: proposed.name,
              candidateValue: room.name,
              score: match.nameScore ?? (match.exactNameConflict ? 100 : null),
              status: match.exactNameConflict ? 'MATCH' : null,
            ),
            PharmacyStorageRoomFieldComparison(
              field: 'code',
              inputValue: proposed.code,
              candidateValue: room.code,
              score: match.codeScore ?? (match.exactCodeConflict ? 100 : null),
              status: match.exactCodeConflict ? 'MATCH' : null,
            ),
          ];

    return AppContentPanel(
      tone: exact
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
                      l10n.pharmacyStorageRoomExistingHeading,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: theme.spacing.xs / 2),
                    Text(
                      room.name ?? room.id,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.start,
                    ),
                    if ((room.code ?? '').trim().isNotEmpty) ...<Widget>[
                      SizedBox(height: theme.spacing.xs / 2),
                      Text(
                        room.code!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.start,
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
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
                      exact
                          ? l10n.pharmacyStorageRoomExactMatchLabel
                          : l10n.pharmacyStorageRoomNearMatchLabel,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(height: theme.spacing.xs),
                  Text(
                    '${match.score}%',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: theme.spacing.sm),
          _FieldComparisonTable(comparisons: comparisons),
          SizedBox(height: theme.spacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton.secondary(
              label: l10n.pharmacyStorageRoomUseExistingAction,
              leadingIcon: Icons.check,
              onPressed: onUseExisting,
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldComparisonTable extends StatelessWidget {
  const _FieldComparisonTable({required this.comparisons});

  final List<PharmacyStorageRoomFieldComparison> comparisons;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final AppStatusColors statusColors = theme.statusColors;
    final List<PharmacyStorageRoomFieldComparison> rows = comparisons
        .where(
          (PharmacyStorageRoomFieldComparison item) =>
              item.field.trim().isNotEmpty,
        )
        .toList(growable: false);
    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              flex: 2,
              child: Text(
                l10n.pharmacyStorageRoomFieldColumnLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.start,
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                l10n.pharmacyStorageRoomFieldProposedLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.start,
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                l10n.pharmacyStorageRoomFieldExistingLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.start,
              ),
            ),
            SizedBox(
              width: 56,
              child: Text(
                '%',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
        SizedBox(height: theme.spacing.xs),
        for (final PharmacyStorageRoomFieldComparison row in rows) ...<Widget>[
          Padding(
            padding: EdgeInsets.symmetric(vertical: theme.spacing.xs / 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  flex: 2,
                  child: Text(
                    _fieldLabel(row.field, l10n),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.start,
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    _display(row.inputValue, l10n),
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.start,
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    _display(row.candidateValue, l10n),
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.start,
                  ),
                ),
                SizedBox(
                  width: 56,
                  child: Text(
                    row.score == null ? '—' : '${row.score}%',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: row.isExact
                          ? statusColors.error
                          : (row.score ?? 0) >= 70
                          ? statusColors.warning
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _fieldLabel(String field, AppLocalizations l10n) {
    switch (field.trim().toLowerCase()) {
      case 'name':
        return l10n.pharmacyStorageRoomNameLabel;
      case 'code':
        return l10n.pharmacyStorageRoomCodeLabel;
      default:
        return field;
    }
  }
}

String _display(String? value, AppLocalizations l10n) {
  final String trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? l10n.clinicalOrderEmptyValueLabel : trimmed;
}
