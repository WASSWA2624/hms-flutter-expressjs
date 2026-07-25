import 'package:flutter/material.dart';
import 'package:hosspi_hms/app/theme/app_theme_extensions.dart';
import 'package:hosspi_hms/features/radiology/domain/entities/radiology_catalog_similarity.dart';
import 'package:hosspi_hms/features/radiology/domain/entities/radiology_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

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

Future<RadiologyCatalogSimilarityAction> showRadiologyCatalogSimilarityDialog(
  BuildContext context, {
  required RadiologyCatalogProposedTest proposed,
  required List<RadiologyCatalogSimilarityMatch> matches,
  bool allowProceed = true,
}) {
  final AppLocalizations l10n = context.l10n;
  final List<RadiologyCatalogSimilarityMatch> visibleMatches = matches
      .take(5)
      .toList(growable: false);
  final bool hasExactMatch = visibleMatches.any(
    (RadiologyCatalogSimilarityMatch match) => match.isExact,
  );
  final bool canProceed = allowProceed && !hasExactMatch;

  return showAppDialog<RadiologyCatalogSimilarityAction>(
    context: context,
    builder: (BuildContext dialogContext) {
      final ThemeData theme = Theme.of(dialogContext);

      return AppDialog(
        title: Text(l10n.radiologySimilarImagingTestDialogTitle),
        icon: const Icon(Icons.warning_amber_outlined),
        scrollable: true,
        maxWidth: 720,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppFormInformationBanner(
              title: hasExactMatch
                  ? l10n.radiologySimilarImagingTestExactBannerTitle
                  : l10n.radiologySimilarImagingTestDialogTitle,
              message: hasExactMatch
                  ? l10n.radiologySimilarImagingTestExactBannerBody
                  : l10n.radiologySimilarImagingTestDialogBody,
              variant: hasExactMatch
                  ? AppFormInformationVariant.error
                  : AppFormInformationVariant.warning,
              icon: hasExactMatch
                  ? Icons.block
                  : Icons.warning_amber_outlined,
            ),
            SizedBox(height: theme.spacing.md),
            _ProposedTestCard(proposed: proposed),
            SizedBox(height: theme.spacing.md),
            Text(
              l10n.radiologySimilarImagingTestMatchesHeading,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: theme.spacing.sm),
            for (int index = 0; index < visibleMatches.length; index += 1) ...<
              Widget
            >[
              if (index > 0) SizedBox(height: theme.spacing.sm),
              _SimilarityMatchCard(
                proposed: proposed,
                match: visibleMatches[index],
              ),
            ],
          ],
        ),
        actions: <Widget>[
          AppButton.tertiary(
            label: l10n.commonCancelActionLabel,
            leadingIcon: Icons.close,
            onPressed: () => Navigator.of(
              dialogContext,
            ).pop(RadiologyCatalogSimilarityAction.cancel),
          ),
          AppButton.secondary(
            label: l10n.radiologyUseExistingImagingTestAction,
            leadingIcon: Icons.content_copy_outlined,
            onPressed: () => Navigator.of(
              dialogContext,
            ).pop(RadiologyCatalogSimilarityAction.useExisting),
          ),
          AppButton.primary(
            label: l10n.radiologyProceedCreateImagingTestAction,
            leadingIcon: Icons.add_circle_outline,
            onPressed: canProceed
                ? () => Navigator.of(
                    dialogContext,
                  ).pop(RadiologyCatalogSimilarityAction.proceed)
                : null,
          ),
        ],
      );
    },
  ).then(
    (RadiologyCatalogSimilarityAction? value) =>
        value ?? RadiologyCatalogSimilarityAction.cancel,
  );
}

Future<bool> showRadiologyCatalogNoSimilarDialog(BuildContext context) {
  final AppLocalizations l10n = context.l10n;

  return showAppDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      final ThemeData theme = Theme.of(dialogContext);

      return AppDialog(
        title: Text(l10n.radiologyNoSimilarImagingTestDialogTitle),
        icon: const Icon(Icons.verified_outlined),
        scrollable: true,
        maxWidth: 520,
        content: Text(
          l10n.radiologyNoSimilarImagingTestDialogBody,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        actions: <Widget>[
          AppButton.tertiary(
            label: l10n.commonCancelActionLabel,
            leadingIcon: Icons.close,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          AppButton.primary(
            label: l10n.radiologyContinueSaveImagingTestAction,
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
    final ThemeData theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(theme.radius.md),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.edit_note_outlined,
                  color: theme.colorScheme.primary,
                  size: theme.appTokens.listIconSize,
                ),
                SizedBox(width: theme.spacing.sm),
                Expanded(
                  child: Text(
                    l10n.radiologySimilarImagingTestProposedHeading,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: theme.spacing.sm),
            _SummaryValue(
              label: l10n.radiologyTestNameLabel,
              value: proposed.name,
            ),
            SizedBox(height: theme.spacing.xs),
            _SummaryValue(
              label: l10n.radiologyTestCodeOptionalLabel,
              value: _displayValue(proposed.code),
            ),
            SizedBox(height: theme.spacing.xs),
            _SummaryValue(
              label: l10n.radiologyModalityLabel,
              value: _displayValue(proposed.modality),
            ),
          ],
        ),
      ),
    );
  }
}

class _SimilarityMatchCard extends StatelessWidget {
  const _SimilarityMatchCard({
    required this.proposed,
    required this.match,
  });

  final RadiologyCatalogProposedTest proposed;
  final RadiologyCatalogSimilarityMatch match;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final RadiologyCatalogTest test = match.test;
    final AppStatusColors statusColors = theme.statusColors;
    final Color accent = match.isExact
        ? statusColors.error
        : statusColors.warning;
    final Color container = match.isExact
        ? statusColors.errorContainer
        : statusColors.warningContainer;
    final Color onContainer = match.isExact
        ? statusColors.onErrorContainer
        : statusColors.onWarningContainer;
    final List<_FieldComparison> comparisons = _buildFieldComparisons(
      proposed: proposed,
      match: match,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(theme.radius.md),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Padding(
        padding: EdgeInsets.all(theme.spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                        l10n.radiologySimilarImagingTestExistingHeading,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: theme.spacing.xs / 2),
                      Text(
                        test.name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (test.isStandard) ...<Widget>[
                        SizedBox(height: theme.spacing.xs / 2),
                        Text(
                          l10n.radiologyStandardCatalogBadge,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: theme.spacing.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: theme.spacing.sm,
                        vertical: theme.spacing.xs / 2,
                      ),
                      decoration: BoxDecoration(
                        color: container,
                        borderRadius: BorderRadius.circular(theme.radius.full),
                        border: Border.all(color: accent),
                      ),
                      child: Text(
                        l10n.radiologySimilarImagingTestScoreLabel(match.score),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: onContainer,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    SizedBox(height: theme.spacing.xs),
                    Text(
                      match.isExact
                          ? l10n.radiologySimilarImagingTestExactMatchLabel
                          : l10n.radiologySimilarImagingTestNearMatchLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: theme.spacing.md),
            Text(
              l10n.radiologySimilarImagingTestComparisonHeading,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: theme.spacing.sm),
            for (int index = 0; index < comparisons.length; index += 1) ...<
              Widget
            >[
              if (index > 0) SizedBox(height: theme.spacing.sm),
              _FieldComparisonRow(comparison: comparisons[index]),
            ],
          ],
        ),
      ),
    );
  }
}

enum _FieldCompareStatus { match, similar, conflict }

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
  final RadiologyCatalogTest test = match.test;
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
      similarityPercent: nameReason && !nameExact ? match.score : null,
    ),
    _FieldComparison(
      label: 'code',
      proposedValue: _displayValue(proposedCode),
      existingValue: _displayValue(existingCode),
      status: codeExact
          ? _FieldCompareStatus.match
          : (codeReason
                ? _FieldCompareStatus.similar
                : (proposedCode.isEmpty && existingCode.isEmpty
                      ? _FieldCompareStatus.match
                      : _FieldCompareStatus.conflict)),
      similarityPercent: codeReason && !codeExact ? match.score : null,
    ),
    _FieldComparison(
      label: 'modality',
      proposedValue: _displayValue(proposedModality),
      existingValue: _displayValue(existingModality),
      status: modalityExact
          ? _FieldCompareStatus.match
          : _FieldCompareStatus.conflict,
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
    final AppStatusColors statusColors = theme.statusColors;
    final (String statusLabel, IconData icon, Color color) = switch (
      comparison.status
    ) {
      _FieldCompareStatus.match => (
        l10n.patientsDuplicateStatusMatchLabel,
        Icons.check_circle_outline,
        statusColors.success,
      ),
      _FieldCompareStatus.similar => (
        comparison.similarityPercent == null
            ? l10n.patientsDuplicateStatusSimilarLabel
            : '${l10n.patientsDuplicateStatusSimilarLabel} · '
                  '${l10n.patientsDuplicateSimilarityLabel(comparison.similarityPercent!)}',
        Icons.change_circle_outlined,
        statusColors.warning,
      ),
      _FieldCompareStatus.conflict => (
        l10n.patientsDuplicateStatusConflictLabel,
        Icons.cancel_outlined,
        statusColors.error,
      ),
    };
    final String fieldLabel = switch (comparison.label) {
      'name' => l10n.radiologyTestNameLabel,
      'code' => l10n.radiologyTestCodeLabel,
      'modality' => l10n.radiologyModalityLabel,
      _ => comparison.label,
    };
    final bool valuesAgree =
        comparison.status == _FieldCompareStatus.match ||
        comparison.proposedValue == comparison.existingValue;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: theme.appTokens.listIconSize, color: color),
        SizedBox(width: theme.spacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      fieldLabel,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    statusLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              SizedBox(height: theme.spacing.xs / 2),
              if (valuesAgree)
                Text(
                  comparison.existingValue,
                  style: theme.textTheme.bodySmall,
                )
              else ...<Widget>[
                Text(
                  '${l10n.radiologySimilarImagingTestYourEntryLabel}: '
                  '${comparison.proposedValue}',
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  '${l10n.radiologySimilarImagingTestExistingValueLabel}: '
                  '${comparison.existingValue}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          TextSpan(
            text: '$label: ',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(text: value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

String _displayValue(String? value) {
  final String trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? '—' : trimmed;
}
