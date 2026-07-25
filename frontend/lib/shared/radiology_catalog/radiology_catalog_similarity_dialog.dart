import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/radiology/domain/entities/radiology_catalog_similarity.dart';
import 'package:hosspi_hms/features/radiology/domain/entities/radiology_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

enum RadiologyCatalogSimilarityAction { cancel, useExisting, proceed }

final class RadiologyCatalogProposedTest {
  const RadiologyCatalogProposedTest({
    required this.name,
    this.code,
    this.modality,
  });

  final String name;
  final String? code;
  final String? modality;
}

final class RadiologyCatalogSimilarityDialogResult {
  const RadiologyCatalogSimilarityDialogResult._({
    required this.action,
    this.selectedProcedure,
  });

  const RadiologyCatalogSimilarityDialogResult.cancel()
    : this._(action: RadiologyCatalogSimilarityAction.cancel);

  const RadiologyCatalogSimilarityDialogResult.proceed()
    : this._(action: RadiologyCatalogSimilarityAction.proceed);

  const RadiologyCatalogSimilarityDialogResult.useExisting(
    RadiologyCatalogProcedure procedure,
  ) : this._(
        action: RadiologyCatalogSimilarityAction.useExisting,
        selectedProcedure: procedure,
      );

  final RadiologyCatalogSimilarityAction action;
  final RadiologyCatalogProcedure? selectedProcedure;
}

Future<RadiologyCatalogSimilarityDialogResult>
showRadiologyCatalogSimilarityDialog(
  BuildContext context, {
  required RadiologyCatalogProposedTest proposed,
  required List<RadiologyCatalogSimilarityMatch> matches,
  bool allowProceed = true,
  bool isEditing = false,
}) {
  final AppLocalizations l10n = context.l10n;
  final List<RadiologyCatalogSimilarityMatch> visibleMatches = matches
      .take(5)
      .toList(growable: false);
  final bool hasExactMatch = visibleMatches.any(
    (RadiologyCatalogSimilarityMatch match) => match.isExact,
  );
  final bool canProceed = allowProceed && !hasExactMatch;
  final RadiologyCatalogSimilarityMatch? topMatch =
      visibleMatches.isEmpty ? null : visibleMatches.first;
  final _SimilarityBannerCopy banner = _similarityBannerCopy(
    l10n: l10n,
    proposed: proposed,
    topMatch: topMatch,
    hasExactMatch: hasExactMatch,
  );
  final String proceedLabel = isEditing
      ? l10n.radiologyProceedUpdateProcedureAction
      : l10n.radiologyProceedCreateProcedureAction;
  final IconData proceedIcon = isEditing
      ? Icons.save_outlined
      : Icons.add_circle_outline;

  return showAppDialog<RadiologyCatalogSimilarityDialogResult>(
    context: context,
    builder: (BuildContext dialogContext) {
      final ThemeData theme = Theme.of(dialogContext);

      return AppDialog(
        title: Text(l10n.radiologySimilarProcedureDialogTitle),
        icon: Icon(
          hasExactMatch
              ? Icons.gpp_bad_outlined
              : Icons.warning_amber_outlined,
        ),
        scrollable: true,
        maxWidth: 760,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppFormInformationBanner(
              title: banner.title,
              message: banner.message,
              variant: hasExactMatch
                  ? AppFormInformationVariant.error
                  : AppFormInformationVariant.warning,
              icon: hasExactMatch
                  ? Icons.gpp_bad_outlined
                  : Icons.manage_search_outlined,
            ),
            SizedBox(height: theme.spacing.md),
            _ProposedTestCard(proposed: proposed),
            SizedBox(height: theme.spacing.lg),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    l10n.radiologySimilarProcedureMatchesHeading,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  l10n.radiologySimilarProcedureMatchCountLabel(
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
              _SimilarityMatchCard(
                proposed: proposed,
                match: visibleMatches[index],
                onUseThis: () => Navigator.of(dialogContext).pop(
                  RadiologyCatalogSimilarityDialogResult.useExisting(
                    visibleMatches[index].procedure,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: <Widget>[
          AppButton.tertiary(
            label: l10n.commonCancelActionLabel,
            leadingIcon: Icons.close,
            onPressed: () => Navigator.of(dialogContext).pop(
              const RadiologyCatalogSimilarityDialogResult.cancel(),
            ),
          ),
          if (canProceed)
            AppButton.primary(
              label: proceedLabel,
              leadingIcon: proceedIcon,
              onPressed: () => Navigator.of(dialogContext).pop(
                const RadiologyCatalogSimilarityDialogResult.proceed(),
              ),
            ),
        ],
      );
    },
  ).then(
    (RadiologyCatalogSimilarityDialogResult? value) =>
        value ?? const RadiologyCatalogSimilarityDialogResult.cancel(),
  );
}

Future<bool> showRadiologyCatalogNoSimilarDialog(
  BuildContext context, {
  required RadiologyCatalogProposedTest proposed,
}) {
  final AppLocalizations l10n = context.l10n;

  return showAppDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      final ThemeData theme = Theme.of(dialogContext);

      return AppDialog(
        title: Text(l10n.radiologyNoSimilarProcedureDialogTitle),
        icon: const Icon(Icons.verified_outlined),
        maxWidth: 560,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AppFormInformationBanner(
              title: l10n.radiologyNoSimilarProcedureBannerTitle,
              message: l10n.radiologyNoSimilarProcedureDialogBody,
              variant: AppFormInformationVariant.success,
              icon: Icons.verified_outlined,
            ),
            SizedBox(height: theme.spacing.md),
            _ProposedTestCard(proposed: proposed),
          ],
        ),
        actions: <Widget>[
          AppButton.tertiary(
            label: l10n.commonCancelActionLabel,
            leadingIcon: Icons.close,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          AppButton.primary(
            label: l10n.radiologyContinueSaveProcedureAction,
            leadingIcon: Icons.save_outlined,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      );
    },
  ).then((bool? value) => value ?? false);
}

class _ProposedTestCard extends StatelessWidget {
  const _ProposedTestCard({required this.proposed});

  final RadiologyCatalogProposedTest proposed;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppSectionPanel(
      tone: AppWorkspaceStatusTone.info,
      density: AppContentPanelDensity.compact,
      leadingIcon: Icons.edit_note_outlined,
      title: l10n.radiologySimilarProcedureProposedHeading,
      children: <Widget>[
        _ProposedFactGrid(
          facts: <(String, String)>[
            (l10n.radiologyProcedureNameLabel, proposed.name),
            (
              l10n.radiologyProcedureCodeOptionalLabel,
              _displayValue(proposed.code),
            ),
            (
              l10n.radiologyModalityLabel,
              _displayValue(proposed.modality),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProposedFactGrid extends StatelessWidget {
  const _ProposedFactGrid({required this.facts});

  final List<(String, String)> facts;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Wrap(
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
    );
  }
}

class _SimilarityMatchCard extends StatelessWidget {
  const _SimilarityMatchCard({
    required this.proposed,
    required this.match,
    required this.onUseThis,
  });

  final RadiologyCatalogProposedTest proposed;
  final RadiologyCatalogSimilarityMatch match;
  final VoidCallback onUseThis;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final RadiologyCatalogProcedure test = match.procedure;
    final AppStatusColors statusColors = theme.statusColors;
    final AppWorkspaceStatusTone tone = match.isExact
        ? AppWorkspaceStatusTone.error
        : AppWorkspaceStatusTone.warning;
    final Color accent = match.isExact
        ? statusColors.error
        : statusColors.warning;
    final Color badgeContainer = match.isExact
        ? statusColors.errorContainer
        : statusColors.warningContainer;
    final Color badgeOnContainer = match.isExact
        ? statusColors.onErrorContainer
        : statusColors.onWarningContainer;
    final List<_FieldComparison> comparisons = _buildFieldComparisons(
      proposed: proposed,
      match: match,
    );

    return AppContentPanel(
      tone: tone,
      density: AppContentPanelDensity.compact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                match.isExact
                    ? Icons.copy_all_outlined
                    : Icons.find_replace_outlined,
                color: accent,
                size: theme.appTokens.listIconSize,
              ),
              SizedBox(width: theme.spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.radiologySimilarProcedureExistingHeading,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                    SizedBox(height: theme.spacing.xs / 2),
                    Text(
                      test.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (test.effectiveId.trim().isNotEmpty ||
                        test.isStandard) ...<Widget>[
                      SizedBox(height: theme.spacing.xs / 2),
                      Text(
                        <String>[
                          if (test.effectiveId.trim().isNotEmpty)
                            test.effectiveId,
                          if (test.isStandard)
                            l10n.radiologyStandardCatalogBadge,
                        ].join(' · '),
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
                      l10n.radiologySimilarProcedureScoreLabel(match.score),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: badgeOnContainer,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      match.isExact
                          ? l10n.radiologySimilarProcedureExactMatchLabel
                          : _isPartialMatch(proposed, match)
                          ? l10n.radiologySimilarProcedurePartialMatchLabel
                          : l10n.radiologySimilarProcedureNearMatchLabel,
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
                    l10n.radiologySimilarProcedureComparisonHeading,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: theme.spacing.sm),
                  LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints constraints) {
                      final bool compact = constraints.maxWidth < 560;
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
                              _FieldComparisonStacked(comparison: comparisons[index])
                            else
                              _FieldComparisonRow(comparison: comparisons[index]),
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
            alignment: AlignmentDirectional.centerEnd,
            child: AppButton.secondary(
              label: l10n.radiologyUseThisProcedureAction,
              leadingIcon: Icons.check_circle_outline,
              onPressed: onUseThis,
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
    final TextStyle? style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w800,
    );

    return Row(
      children: <Widget>[
        SizedBox(
          width: 88,
          child: Text(l10n.radiologySimilarProcedureFieldColumnLabel, style: style),
        ),
        Expanded(
          child: Text(
            l10n.radiologySimilarProcedureYourEntryLabel,
            style: style,
          ),
        ),
        SizedBox(width: theme.spacing.sm),
        Expanded(
          child: Text(
            l10n.radiologySimilarProcedureExistingValueLabel,
            style: style,
          ),
        ),
        SizedBox(
          width: 96,
          child: Text(
            l10n.radiologySimilarProcedureStatusColumnLabel,
            style: style,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

enum _FieldCompareStatus { match, similar, conflict, onlyExisting }

final class _FieldComparison {
  const _FieldComparison({
    required this.label,
    required this.proposedValue,
    required this.existingValue,
    required this.status,
    this.similarityPercent,
  });

  final String label;
  final String proposedValue;
  final String existingValue;
  final _FieldCompareStatus status;
  final int? similarityPercent;
}

List<_FieldComparison> _buildFieldComparisons({
  required RadiologyCatalogProposedTest proposed,
  required RadiologyCatalogSimilarityMatch match,
}) {
  final RadiologyCatalogProcedure test = match.procedure;
  final String proposedName = proposed.name.trim();
  final String existingName = test.name.trim();
  final String proposedCode = (proposed.code ?? '').trim();
  final String existingCode = (test.code ?? '').trim();
  final String proposedModality = (proposed.modality ?? '').trim();
  final String existingModality = (test.modality ?? '').trim();

  final String normalizedProposedName = normalizeRadiologyCatalogName(
    proposedName,
  );
  final String normalizedExistingName = normalizeRadiologyCatalogName(
    existingName,
  );
  final String normalizedProposedCode =
      normalizeRadiologyCatalogCodeForSimilarity(proposedCode);
  final String normalizedExistingCode =
      normalizeRadiologyCatalogCodeForSimilarity(existingCode);

  final bool nameExact =
      normalizedProposedName.isNotEmpty &&
      normalizedProposedName == normalizedExistingName;
  final bool codeExact =
      normalizedProposedCode.isNotEmpty &&
      normalizedExistingCode.isNotEmpty &&
      normalizedProposedCode == normalizedExistingCode;
  final bool modalityExact =
      proposedModality.isNotEmpty &&
      existingModality.isNotEmpty &&
      proposedModality.toUpperCase() == existingModality.toUpperCase();

  final bool nameReason = match.reasons.contains('name');
  final bool codeReason = match.reasons.contains('code');

  _FieldCompareStatus codeStatus() {
    if (codeExact || (proposedCode.isEmpty && existingCode.isEmpty)) {
      return _FieldCompareStatus.match;
    }
    if (codeReason) {
      return _FieldCompareStatus.similar;
    }
    if (proposedCode.isEmpty && existingCode.isNotEmpty) {
      return _FieldCompareStatus.onlyExisting;
    }
    return _FieldCompareStatus.conflict;
  }

  return <_FieldComparison>[
    _FieldComparison(
      label: 'name',
      proposedValue: _displayValue(proposedName),
      existingValue: _displayValue(existingName),
      status: nameExact
          ? _FieldCompareStatus.match
          : nameReason
          ? _FieldCompareStatus.similar
          : _FieldCompareStatus.conflict,
      similarityPercent: nameReason && !nameExact ? match.nameScore : null,
    ),
    _FieldComparison(
      label: 'code',
      proposedValue: _displayValue(proposedCode),
      existingValue: _displayValue(existingCode),
      status: codeStatus(),
      similarityPercent: codeReason && !codeExact ? match.codeScore : null,
    ),
    _FieldComparison(
      label: 'modality',
      proposedValue: _displayValue(proposedModality),
      existingValue: _displayValue(existingModality),
      status: modalityExact
          ? _FieldCompareStatus.match
          : (proposedModality.isEmpty && existingModality.isNotEmpty
                ? _FieldCompareStatus.onlyExisting
                : _FieldCompareStatus.conflict),
      similarityPercent: match.modalityScore,
    ),
  ];
}

class _FieldComparisonRow extends StatelessWidget {
  const _FieldComparisonRow({required this.comparison});

  final _FieldComparison comparison;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final _StatusVisual status = _statusVisual(theme, l10n, comparison);
    final String fieldLabel = _fieldLabel(l10n, comparison.label);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 88,
          child: Row(
            children: <Widget>[
              Icon(status.icon, size: 18, color: status.color),
              SizedBox(width: theme.spacing.xs),
              Expanded(
                child: Text(
                  fieldLabel,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Text(
            comparison.proposedValue,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SizedBox(width: theme.spacing.sm),
        Expanded(
          child: Text(
            comparison.existingValue,
            style: theme.textTheme.bodySmall?.copyWith(
              color: comparison.status == _FieldCompareStatus.match
                  ? theme.colorScheme.onSurface
                  : status.color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(
          width: 96,
          child: Text(
            status.label,
            textAlign: TextAlign.end,
            style: theme.textTheme.labelSmall?.copyWith(
              color: status.color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _FieldComparisonStacked extends StatelessWidget {
  const _FieldComparisonStacked({required this.comparison});

  final _FieldComparison comparison;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final _StatusVisual status = _statusVisual(theme, l10n, comparison);
    final String fieldLabel = _fieldLabel(l10n, comparison.label);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(status.icon, size: 18, color: status.color),
            SizedBox(width: theme.spacing.xs),
            Expanded(
              child: Text(
                fieldLabel,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              status.label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: status.color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        SizedBox(height: theme.spacing.xs),
        Text(
          '${l10n.radiologySimilarProcedureYourEntryLabel}: '
          '${comparison.proposedValue}',
          style: theme.textTheme.bodySmall,
        ),
        Text(
          '${l10n.radiologySimilarProcedureExistingValueLabel}: '
          '${comparison.existingValue}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: comparison.status == _FieldCompareStatus.match
                ? theme.colorScheme.onSurface
                : status.color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

final class _StatusVisual {
  const _StatusVisual({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;
}

_StatusVisual _statusVisual(
  ThemeData theme,
  AppLocalizations l10n,
  _FieldComparison comparison,
) {
  final AppStatusColors statusColors = theme.statusColors;
  return switch (comparison.status) {
    _FieldCompareStatus.match => _StatusVisual(
      label: l10n.patientsDuplicateStatusMatchLabel,
      icon: Icons.check_circle_outline,
      color: statusColors.success,
    ),
    _FieldCompareStatus.similar => _StatusVisual(
      label: comparison.similarityPercent == null
          ? l10n.patientsDuplicateStatusSimilarLabel
          : '${l10n.patientsDuplicateStatusSimilarLabel} · '
                '${comparison.similarityPercent}%',
      icon: Icons.change_circle_outlined,
      color: statusColors.warning,
    ),
    _FieldCompareStatus.conflict => _StatusVisual(
      label: l10n.patientsDuplicateStatusConflictLabel,
      icon: Icons.cancel_outlined,
      color: statusColors.error,
    ),
    _FieldCompareStatus.onlyExisting => _StatusVisual(
      label: l10n.radiologySimilarProcedureOnlyExistingLabel,
      icon: Icons.info_outline,
      color: theme.colorScheme.onSurfaceVariant,
    ),
  };
}

String _fieldLabel(AppLocalizations l10n, String label) {
  return switch (label) {
    'name' => l10n.radiologyProcedureNameLabel,
    'code' => l10n.radiologyProcedureCodeLabel,
    'modality' => l10n.radiologyModalityLabel,
    _ => label,
  };
}

String _displayValue(String? value) {
  final String trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? '—' : trimmed;
}

final class _SimilarityBannerCopy {
  const _SimilarityBannerCopy({required this.title, required this.message});

  final String title;
  final String message;
}

_SimilarityBannerCopy _similarityBannerCopy({
  required AppLocalizations l10n,
  required RadiologyCatalogProposedTest proposed,
  required RadiologyCatalogSimilarityMatch? topMatch,
  required bool hasExactMatch,
}) {
  final int score = topMatch?.score ?? 0;
  if (hasExactMatch) {
    return _SimilarityBannerCopy(
      title: l10n.radiologySimilarProcedureExactBannerTitle,
      message: l10n.radiologySimilarProcedureExactBannerBody(score),
    );
  }

  if (topMatch == null) {
    return _SimilarityBannerCopy(
      title: l10n.radiologySimilarProcedureReviewBannerTitle(0),
      message: l10n.radiologySimilarProcedureDialogBody,
    );
  }

  final List<_FieldComparison> comparisons = _buildFieldComparisons(
    proposed: proposed,
    match: topMatch,
  );
  final String fieldSummary = comparisons
      .map(
        (_FieldComparison comparison) =>
            l10n.radiologySimilarProcedureFieldStatusPart(
              _fieldLabel(l10n, comparison.label),
              _fieldStatusPlainLabel(l10n, comparison),
            ),
      )
      .join(' · ');

  return _SimilarityBannerCopy(
    title: l10n.radiologySimilarProcedureReviewBannerTitle(score),
    message: l10n.radiologySimilarProcedureReviewBannerBody(
      score,
      fieldSummary,
    ),
  );
}

String _fieldStatusPlainLabel(
  AppLocalizations l10n,
  _FieldComparison comparison,
) {
  return switch (comparison.status) {
    _FieldCompareStatus.match => l10n.patientsDuplicateStatusMatchLabel,
    _FieldCompareStatus.similar => comparison.similarityPercent == null
        ? l10n.patientsDuplicateStatusSimilarLabel
        : '${l10n.patientsDuplicateStatusSimilarLabel} · '
              '${comparison.similarityPercent}%',
    _FieldCompareStatus.conflict => l10n.patientsDuplicateStatusConflictLabel,
    _FieldCompareStatus.onlyExisting =>
      l10n.radiologySimilarProcedureOnlyExistingLabel,
  };
}

bool _isPartialMatch(
  RadiologyCatalogProposedTest proposed,
  RadiologyCatalogSimilarityMatch match,
) {
  if (match.isExact) {
    return false;
  }
  final List<_FieldComparison> comparisons = _buildFieldComparisons(
    proposed: proposed,
    match: match,
  );
  final bool hasExactField = comparisons.any(
    (_FieldComparison comparison) =>
        comparison.status == _FieldCompareStatus.match,
  );
  final bool hasConflictOrSimilar = comparisons.any(
    (_FieldComparison comparison) =>
        comparison.status == _FieldCompareStatus.conflict ||
        comparison.status == _FieldCompareStatus.similar ||
        comparison.status == _FieldCompareStatus.onlyExisting,
  );
  return hasExactField && hasConflictOrSimilar;
}
