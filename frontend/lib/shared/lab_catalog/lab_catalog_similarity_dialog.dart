import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/lab/domain/entities/lab_catalog_similarity.dart';
import 'package:hosspi_hms/features/lab/domain/entities/lab_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/layout/layout.dart';

enum LabCatalogSimilarityAction { cancel, useExisting, proceed }

final class LabCatalogProposedTest {
  const LabCatalogProposedTest({
    required this.name,
    this.code,
    this.category,
  });

  final String name;
  final String? code;
  final String? category;
}

final class LabCatalogSimilarityDialogResult {
  const LabCatalogSimilarityDialogResult._({
    required this.action,
    this.selectedItem,
  });

  const LabCatalogSimilarityDialogResult.cancel()
    : this._(action: LabCatalogSimilarityAction.cancel);

  const LabCatalogSimilarityDialogResult.proceed()
    : this._(action: LabCatalogSimilarityAction.proceed);

  const LabCatalogSimilarityDialogResult.useExisting(
    LabCatalogItem item,
  ) : this._(
        action: LabCatalogSimilarityAction.useExisting,
        selectedItem: item,
      );

  final LabCatalogSimilarityAction action;
  final LabCatalogItem? selectedItem;
}

Future<LabCatalogSimilarityDialogResult>
showLabCatalogSimilarityDialog(
  BuildContext context, {
  required LabCatalogProposedTest proposed,
  required List<LabCatalogSimilarityMatch> matches,
  bool allowProceed = true,
  bool isEditing = false,
}) {
  final AppLocalizations l10n = context.l10n;
  final List<LabCatalogSimilarityMatch> visibleMatches = matches
      .take(5)
      .toList(growable: false);
  final bool hasExactMatch = visibleMatches.any(
    (LabCatalogSimilarityMatch match) => match.isExact,
  );
  final bool hasMatches = visibleMatches.isNotEmpty;
  // Create/Save anyway stays available even for exact name/code clashes;
  // the caller sends confirm_similar after proceed.
  final bool canProceed = allowProceed;
  final LabCatalogSimilarityMatch? topMatch =
      visibleMatches.isEmpty ? null : visibleMatches.first;
  final _SimilarityBannerCopy banner = _similarityBannerCopy(
    l10n: l10n,
    proposed: proposed,
    topMatch: topMatch,
    hasExactMatch: hasExactMatch,
  );
  final String proceedLabel = isEditing
      ? l10n.labProceedUpdateTestAction
      : hasMatches || hasExactMatch
      ? l10n.labProceedCreateTestAction
      : l10n.labContinueSaveTestAction;
  final IconData proceedIcon = isEditing || !(hasMatches || hasExactMatch)
      ? Icons.save_outlined
      : Icons.add_circle_outline;

  return showAppDialog<LabCatalogSimilarityDialogResult>(
    context: context,
    builder: (BuildContext dialogContext) {
      final ThemeData theme = Theme.of(dialogContext);
      final AppFormInformationVariant bannerVariant = hasExactMatch
          ? AppFormInformationVariant.error
          : hasMatches
          ? AppFormInformationVariant.warning
          : AppFormInformationVariant.success;

      return AppDialog(
        title: Text(l10n.labSimilarTestDialogTitle),
        icon: Icon(
          hasExactMatch
              ? Icons.gpp_bad_outlined
              : hasMatches
              ? Icons.warning_amber_outlined
              : Icons.verified_outlined,
        ),
        scrollable: true,
        maxWidth: 760,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppFormInformationBanner(
              title: banner.title,
              message: banner.message,
              variant: bannerVariant,
              icon: hasExactMatch
                  ? Icons.gpp_bad_outlined
                  : hasMatches
                  ? Icons.manage_search_outlined
                  : Icons.verified_outlined,
            ),
            SizedBox(height: theme.spacing.md),
            _ProposedTestCard(proposed: proposed),
            SizedBox(height: theme.spacing.lg),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    l10n.labSimilarTestMatchesHeading,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  l10n.labSimilarTestMatchCountLabel(
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
            if (!hasMatches)
              AppFormInformationBanner(
                title: l10n.labSimilarTestScoreLabel(0),
                message: l10n.labNoSimilarTestDialogBody,
                variant: AppFormInformationVariant.success,
                icon: Icons.percent_outlined,
              )
            else
              for (int index = 0; index < visibleMatches.length; index += 1) ...<
                Widget
              >[
                if (index > 0) SizedBox(height: theme.spacing.md),
                _SimilarityMatchCard(
                  proposed: proposed,
                  match: visibleMatches[index],
                  onUseThis: () => Navigator.of(dialogContext).pop(
                    LabCatalogSimilarityDialogResult.useExisting(
                      visibleMatches[index].item,
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
              const LabCatalogSimilarityDialogResult.cancel(),
            ),
          ),
          if (canProceed)
            AppButton.primary(
              label: proceedLabel,
              leadingIcon: proceedIcon,
              onPressed: () => Navigator.of(dialogContext).pop(
                const LabCatalogSimilarityDialogResult.proceed(),
              ),
            ),
        ],
      );
    },
  ).then(
    (LabCatalogSimilarityDialogResult? value) =>
        value ?? const LabCatalogSimilarityDialogResult.cancel(),
  );
}

class _ProposedTestCard extends StatelessWidget {
  const _ProposedTestCard({required this.proposed});

  final LabCatalogProposedTest proposed;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AppSectionPanel(
      tone: AppWorkspaceStatusTone.info,
      density: AppContentPanelDensity.compact,
      leadingIcon: Icons.edit_note_outlined,
      title: l10n.labSimilarTestProposedHeading,
      children: <Widget>[
        _ProposedFactGrid(
          facts: <(String, String)>[
            (l10n.labTestNameLabel, proposed.name),
            (
              l10n.labTestCodeLabel,
              _displayValue(proposed.code),
            ),
            (
              l10n.labCategoryLabel,
              _displayValue(proposed.category),
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

  final LabCatalogProposedTest proposed;
  final LabCatalogSimilarityMatch match;
  final VoidCallback onUseThis;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final LabCatalogItem test = match.item;
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
                      l10n.labSimilarTestExistingHeading,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                    SizedBox(height: theme.spacing.xs / 2),
                    Text(
                      test.name ?? test.apiId,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (test.apiId.trim().isNotEmpty ||
                        test.isStandard) ...<Widget>[
                      SizedBox(height: theme.spacing.xs / 2),
                      Text(
                        <String>[
                          if (test.apiId.trim().isNotEmpty)
                            test.apiId,
                          if (test.isStandard)
                            l10n.labStandardCatalogBadge,
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
                      l10n.labSimilarTestScoreLabel(match.score),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: badgeOnContainer,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      match.isExact
                          ? (match.score >= 100
                                ? l10n.labSimilarTestExactMatchLabel
                                : l10n.labSimilarTestExactFieldMatchLabel)
                          : _isPartialMatch(proposed, match)
                          ? l10n.labSimilarTestPartialMatchLabel
                          : l10n.labSimilarTestNearMatchLabel,
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
                    l10n.labSimilarTestComparisonHeading,
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
              label: l10n.labUseThisTestAction,
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
          child: Text(l10n.labSimilarTestFieldColumnLabel, style: style),
        ),
        Expanded(
          child: Text(
            l10n.labSimilarTestYourEntryLabel,
            style: style,
          ),
        ),
        SizedBox(width: theme.spacing.sm),
        Expanded(
          child: Text(
            l10n.labSimilarTestExistingValueLabel,
            style: style,
          ),
        ),
        SizedBox(
          width: 96,
          child: Text(
            l10n.labSimilarTestStatusColumnLabel,
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
  required LabCatalogProposedTest proposed,
  required LabCatalogSimilarityMatch match,
}) {
  final LabCatalogItem test = match.item;
  final String proposedName = proposed.name.trim();
  final String existingName = (test.name ?? '').trim();
  final String proposedCode = (proposed.code ?? '').trim();
  final String existingCode = (test.code ?? '').trim();
  final String proposedCategory = (proposed.category ?? '').trim();
  final String existingCategory = (test.category ?? '').trim();

  final String normalizedProposedName = normalizeLabCatalogName(
    proposedName,
  );
  final String normalizedExistingName = normalizeLabCatalogName(
    existingName,
  );
  final String normalizedProposedCode =
      normalizeLabCatalogCodeForSimilarity(proposedCode);
  final String normalizedExistingCode =
      normalizeLabCatalogCodeForSimilarity(existingCode);

  final bool nameExact =
      normalizedProposedName.isNotEmpty &&
      normalizedProposedName == normalizedExistingName;
  final bool codeExact =
      normalizedProposedCode.isNotEmpty &&
      normalizedExistingCode.isNotEmpty &&
      normalizedProposedCode == normalizedExistingCode;
  final String normalizedProposedCategory =
      normalizeLabCatalogCategory(proposedCategory);
  final String normalizedExistingCategory =
      normalizeLabCatalogCategory(existingCategory);
  final bool categoryExact =
      normalizedProposedCategory.isNotEmpty &&
      normalizedExistingCategory.isNotEmpty &&
      normalizedProposedCategory == normalizedExistingCategory;

  final bool nameReason = match.reasons.contains('name');
  final bool codeReason = match.reasons.contains('code');
  final bool categoryReason = match.reasons.contains('category');
  final int? nameScore = match.nameScore;
  final int? codeScore = match.codeScore;
  final int? categoryScore = match.categoryScore;

  _FieldCompareStatus codeStatus() {
    if (codeExact || (proposedCode.isEmpty && existingCode.isEmpty)) {
      return _FieldCompareStatus.match;
    }
    if (codeReason ||
        (codeScore != null && codeScore >= labCatalogSimilarityThreshold)) {
      return _FieldCompareStatus.similar;
    }
    if (proposedCode.isEmpty && existingCode.isNotEmpty) {
      return _FieldCompareStatus.onlyExisting;
    }
    return _FieldCompareStatus.conflict;
  }

  _FieldCompareStatus categoryStatus() {
    if (categoryExact) {
      return _FieldCompareStatus.match;
    }
    if (proposedCategory.isEmpty && existingCategory.isNotEmpty) {
      return _FieldCompareStatus.onlyExisting;
    }
    if (categoryReason ||
        (categoryScore != null &&
            categoryScore >= labCatalogSimilarityThreshold)) {
      return _FieldCompareStatus.similar;
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
          : nameReason ||
                (nameScore != null &&
                    nameScore >= labCatalogSimilarityThreshold)
          ? _FieldCompareStatus.similar
          : _FieldCompareStatus.conflict,
      similarityPercent: nameExact ? 100 : nameScore,
    ),
    _FieldComparison(
      label: 'code',
      proposedValue: _displayValue(proposedCode),
      existingValue: _displayValue(existingCode),
      status: codeStatus(),
      similarityPercent: codeExact
          ? 100
          : (proposedCode.isEmpty && existingCode.isEmpty)
          ? 100
          : codeScore,
    ),
    _FieldComparison(
      label: 'category',
      proposedValue: _displayValue(proposedCategory),
      existingValue: _displayValue(existingCategory),
      status: categoryStatus(),
      similarityPercent: categoryExact ? 100 : categoryScore,
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
          '${l10n.labSimilarTestYourEntryLabel}: '
          '${comparison.proposedValue}',
          style: theme.textTheme.bodySmall,
        ),
        Text(
          '${l10n.labSimilarTestExistingValueLabel}: '
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
      label: comparison.similarityPercent == null
          ? l10n.patientsDuplicateStatusConflictLabel
          : '${l10n.patientsDuplicateStatusConflictLabel} · '
                '${comparison.similarityPercent}%',
      icon: Icons.cancel_outlined,
      color: statusColors.error,
    ),
    _FieldCompareStatus.onlyExisting => _StatusVisual(
      label: l10n.labSimilarTestOnlyExistingLabel,
      icon: Icons.info_outline,
      color: theme.colorScheme.onSurfaceVariant,
    ),
  };
}

String _fieldLabel(AppLocalizations l10n, String label) {
  return switch (label) {
    'name' => l10n.labTestNameLabel,
    'code' => l10n.labTestCodeLabel,
    'category' => l10n.labCategoryLabel,
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
  required LabCatalogProposedTest proposed,
  required LabCatalogSimilarityMatch? topMatch,
  required bool hasExactMatch,
}) {
  final int score = topMatch?.score ?? 0;
  if (hasExactMatch) {
    return _SimilarityBannerCopy(
      title: l10n.labSimilarTestExactBannerTitle,
      message: l10n.labSimilarTestExactBannerBody(score),
    );
  }

  if (topMatch == null) {
    return _SimilarityBannerCopy(
      title: l10n.labSimilarTestReviewBannerTitle(0),
      message: l10n.labNoSimilarTestDialogBody,
    );
  }

  final List<_FieldComparison> comparisons = _buildFieldComparisons(
    proposed: proposed,
    match: topMatch,
  );
  final String fieldSummary = comparisons
      .map(
        (_FieldComparison comparison) =>
            l10n.labSimilarTestFieldStatusPart(
              _fieldLabel(l10n, comparison.label),
              _fieldStatusPlainLabel(l10n, comparison),
            ),
      )
      .join(' · ');

  return _SimilarityBannerCopy(
    title: l10n.labSimilarTestReviewBannerTitle(score),
    message: l10n.labSimilarTestReviewBannerBody(
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
    _FieldCompareStatus.conflict => comparison.similarityPercent == null
        ? l10n.patientsDuplicateStatusConflictLabel
        : '${l10n.patientsDuplicateStatusConflictLabel} · '
              '${comparison.similarityPercent}%',
    _FieldCompareStatus.onlyExisting =>
      l10n.labSimilarTestOnlyExistingLabel,
  };
}

bool _isPartialMatch(
  LabCatalogProposedTest proposed,
  LabCatalogSimilarityMatch match,
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
