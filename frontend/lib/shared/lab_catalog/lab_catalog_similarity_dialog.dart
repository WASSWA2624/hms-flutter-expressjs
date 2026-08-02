import 'package:flutter/material.dart';
import 'package:hosspi_hms/features/lab/domain/entities/lab_catalog_similarity.dart';
import 'package:hosspi_hms/features/lab/domain/entities/lab_entities.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/components.dart';

enum LabCatalogSimilarityAction { cancel, useExisting, proceed }

final class LabCatalogProposedTest {
  const LabCatalogProposedTest({
    required this.name,
    this.code,
    this.category,
    this.specimenType,
    this.resultKind,
    this.unit,
    this.description,
    this.referenceRangeSummary,
    this.memberTestsSummary,
    this.isPanel = false,
  });

  final String name;
  final String? code;
  final String? category;
  final String? specimenType;
  final String? resultKind;
  final String? unit;
  final String? description;
  final String? referenceRangeSummary;
  final String? memberTestsSummary;
  final bool isPanel;
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

/// Lab catalog adapter over [showAppSimilarityReviewDialog].
Future<LabCatalogSimilarityDialogResult> showLabCatalogSimilarityDialog(
  BuildContext context, {
  required LabCatalogProposedTest proposed,
  required List<LabCatalogSimilarityMatch> matches,
  bool allowProceed = true,
  bool isEditing = false,
}) async {
  final AppLocalizations l10n = context.l10n;
  final bool isPanel = proposed.isPanel;
  final List<LabCatalogSimilarityMatch> visibleMatches = matches
      .take(5)
      .toList(growable: false);
  final bool hasExactMatch = visibleMatches.any(
    (LabCatalogSimilarityMatch match) => match.isExact,
  );
  final bool hasMatches = visibleMatches.isNotEmpty;
  // Create/Save anyway stays available even for exact name/code clashes;
  // the caller sends confirm_similar after proceed.
  final LabCatalogSimilarityMatch? topMatch =
      visibleMatches.isEmpty ? null : visibleMatches.first;
  final int overallScore = topMatch?.score ?? 0;
  final _SimilarityBannerCopy banner = _similarityBannerCopy(
    l10n: l10n,
    proposed: proposed,
    topMatch: topMatch,
    hasExactMatch: hasExactMatch,
  );
  final String dialogTitle = hasExactMatch || hasMatches
      ? (isPanel
            ? l10n.labSimilarPanelDialogTitle
            : l10n.labSimilarTestDialogTitle)
      : (isPanel
            ? l10n.labNoSimilarPanelDialogTitle
            : l10n.labNoSimilarTestDialogTitle);
  final String proceedLabel = isEditing
      ? (isPanel
            ? l10n.labProceedUpdatePanelAction
            : l10n.labProceedUpdateTestAction)
      : hasMatches || hasExactMatch
      ? (isPanel
            ? l10n.labProceedCreatePanelAction
            : l10n.labProceedCreateTestAction)
      : (isPanel
            ? l10n.labContinueSavePanelAction
            : l10n.labContinueSaveTestAction);
  final AppFormInformationVariant bannerVariant = hasExactMatch
      ? AppFormInformationVariant.error
      : hasMatches
      ? AppFormInformationVariant.warning
      : AppFormInformationVariant.success;

  final List<AppSimilarityMatch<LabCatalogItem>> appMatches = visibleMatches
      .map((LabCatalogSimilarityMatch match) {
        final LabCatalogItem test = match.item;
        return AppSimilarityMatch<LabCatalogItem>(
          item: test,
          title: test.name ?? test.apiId,
          subtitle: <String>[
            if (test.apiId.trim().isNotEmpty) test.apiId,
            if ((test.code ?? '').trim().isNotEmpty) test.code!.trim(),
            if ((test.category ?? '').trim().isNotEmpty) test.category!.trim(),
            if ((test.specimenType ?? '').trim().isNotEmpty)
              test.specimenType!.trim(),
            if ((test.resultKind ?? '').trim().isNotEmpty)
              test.resultKind!.trim(),
            if (test.isStandard) l10n.labStandardCatalogBadge,
          ].join(' · '),
          overallScore: match.score,
          isExact: match.isExact,
          fields: _buildFieldRows(
            l10n: l10n,
            proposed: proposed,
            match: match,
          ),
        );
      })
      .toList(growable: false);

  final AppSimilarityReviewResult<LabCatalogItem> result =
      await showAppSimilarityReviewDialog<LabCatalogItem>(
        context,
        title: dialogTitle,
        bannerTitle: banner.title,
        bannerMessage: banner.message,
        bannerVariant: bannerVariant,
        proposedFields: _proposedFields(l10n: l10n, proposed: proposed),
        matches: appMatches,
        overallScore: overallScore,
        blockProceed: !allowProceed,
        enableRetry: false,
        proposedReadOnly: true,
        proceedLabel: proceedLabel,
        useThisLabel: isPanel
            ? l10n.labUseThisPanelAction
            : l10n.labUseThisTestAction,
        useThisIcon: Icons.check_circle_outline,
        proposedHeading: isPanel
            ? l10n.labSimilarPanelProposedHeading
            : l10n.labSimilarTestProposedHeading,
        matchesHeading: l10n.labSimilarTestMatchesHeading,
        exactBadgeLabel: l10n.labSimilarTestExactMatchLabel,
        nearBadgeLabel: l10n.labSimilarTestNearMatchLabel,
        existingHeading: isPanel
            ? l10n.labSimilarPanelExistingHeading
            : l10n.labSimilarTestExistingHeading,
        fieldColumnLabel: l10n.labSimilarTestFieldColumnLabel,
        proposedColumnLabel: l10n.labSimilarTestYourEntryLabel,
        existingColumnLabel: l10n.labSimilarTestExistingValueLabel,
        noMatchLabel: isPanel
            ? l10n.labNoSimilarPanelDialogBody
            : l10n.labNoSimilarTestDialogBody,
        emptyValueLabel: l10n.clinicalOrderEmptyValueLabel,
        dialogIcon: hasExactMatch
            ? Icons.gpp_bad_outlined
            : hasMatches
            ? Icons.warning_amber_outlined
            : Icons.verified_outlined,
      );

  switch (result.action) {
    case AppSimilarityReviewAction.cancel:
    case AppSimilarityReviewAction.retry:
      return const LabCatalogSimilarityDialogResult.cancel();
    case AppSimilarityReviewAction.proceed:
      return const LabCatalogSimilarityDialogResult.proceed();
    case AppSimilarityReviewAction.useExisting:
      final LabCatalogItem? item = result.selected;
      if (item == null) {
        return const LabCatalogSimilarityDialogResult.cancel();
      }
      return LabCatalogSimilarityDialogResult.useExisting(item);
  }
}

List<AppSimilarityProposedField> _proposedFields({
  required AppLocalizations l10n,
  required LabCatalogProposedTest proposed,
}) {
  final bool isPanel = proposed.isPanel;
  return <AppSimilarityProposedField>[
    AppSimilarityProposedField(
      key: 'name',
      label: isPanel ? l10n.labPanelNameLabel : l10n.labTestNameLabel,
      initialValue: proposed.name,
      isRequired: true,
    ),
    AppSimilarityProposedField(
      key: 'code',
      label: isPanel ? l10n.labPanelCodeLabel : l10n.labTestCodeLabel,
      initialValue: proposed.code ?? '',
    ),
    AppSimilarityProposedField(
      key: 'category',
      label: l10n.labCategoryLabel,
      initialValue: proposed.category ?? '',
    ),
    if (!isPanel) ...<AppSimilarityProposedField>[
      AppSimilarityProposedField(
        key: 'specimenType',
        label: l10n.labSpecimenTypeLabel,
        initialValue: proposed.specimenType ?? '',
      ),
      AppSimilarityProposedField(
        key: 'resultKind',
        label: l10n.labResultKindLabel,
        initialValue: proposed.resultKind ?? '',
      ),
      AppSimilarityProposedField(
        key: 'unit',
        label: l10n.labDefaultUnitLabel,
        initialValue: proposed.unit ?? '',
      ),
      AppSimilarityProposedField(
        key: 'description',
        label: l10n.labTestDescriptionLabel,
        initialValue: proposed.description ?? '',
      ),
      AppSimilarityProposedField(
        key: 'referenceRangeSummary',
        label: l10n.labTestRangesSectionTitle,
        initialValue: proposed.referenceRangeSummary ?? '',
      ),
    ] else ...<AppSimilarityProposedField>[
      AppSimilarityProposedField(
        key: 'description',
        label: l10n.labPanelDescriptionLabel,
        initialValue: proposed.description ?? '',
      ),
      AppSimilarityProposedField(
        key: 'memberTestsSummary',
        label: l10n.labPanelTestsLabel,
        initialValue: proposed.memberTestsSummary ?? '',
      ),
    ],
  ];
}

List<AppSimilarityFieldRow> _buildFieldRows({
  required AppLocalizations l10n,
  required LabCatalogProposedTest proposed,
  required LabCatalogSimilarityMatch match,
}) {
  final LabCatalogItem test = match.item;
  final String existingRanges = _existingReferenceRangeSummary(test);
  final String existingMembership = test.panelItems
      .map((LabPanelItem item) => item.displayTitle)
      .where((String value) => value.trim().isNotEmpty)
      .join(', ');

  return <AppSimilarityFieldRow>[
    _compareScoredField(
      l10n: l10n,
      label: 'id',
      proposedValue: '',
      existingValue: test.apiId,
      scoredPercent: null,
      strongReason: false,
      normalize: (String value) => value.trim().toUpperCase(),
    ),
    _compareScoredField(
      l10n: l10n,
      label: 'name',
      proposedValue: proposed.name,
      existingValue: test.name,
      scoredPercent: match.nameScore,
      strongReason: match.reasons.contains('name'),
      normalize: normalizeLabCatalogName,
    ),
    _compareScoredField(
      l10n: l10n,
      label: 'code',
      proposedValue: proposed.code,
      existingValue: test.code,
      scoredPercent: match.codeScore,
      strongReason: match.reasons.contains('code'),
      normalize: normalizeLabCatalogCodeForSimilarity,
    ),
    _compareScoredField(
      l10n: l10n,
      label: 'category',
      proposedValue: proposed.category,
      existingValue: test.category,
      scoredPercent: match.categoryScore,
      strongReason: match.reasons.contains('category'),
      normalize: normalizeLabCatalogCategory,
    ),
    if (proposed.isPanel)
      _compareScoredField(
        l10n: l10n,
        label: 'composition',
        proposedValue: proposed.memberTestsSummary,
        existingValue: existingMembership,
        scoredPercent: match.compositionScore,
        strongReason: match.reasons.contains('composition'),
        normalize: normalizeLabCatalogName,
      )
    else ...<AppSimilarityFieldRow>[
      _compareScoredField(
        l10n: l10n,
        label: 'specimen',
        proposedValue: proposed.specimenType,
        existingValue: test.specimenType,
        scoredPercent: null,
        strongReason: false,
        normalize: normalizeLabCatalogName,
      ),
      _compareScoredField(
        l10n: l10n,
        label: 'resultKind',
        proposedValue: proposed.resultKind,
        existingValue: test.resultKind,
        scoredPercent: null,
        strongReason: false,
        normalize: (String value) => value.trim().toUpperCase(),
      ),
      _compareScoredField(
        l10n: l10n,
        label: 'unit',
        proposedValue: proposed.unit,
        existingValue: test.unit,
        scoredPercent: null,
        strongReason: false,
        normalize: normalizeLabCatalogName,
      ),
      _compareScoredField(
        l10n: l10n,
        label: 'description',
        proposedValue: proposed.description,
        existingValue: test.description,
        scoredPercent: null,
        strongReason: false,
        normalize: normalizeLabCatalogName,
      ),
      _compareScoredField(
        l10n: l10n,
        label: 'ranges',
        proposedValue: proposed.referenceRangeSummary,
        existingValue: existingRanges,
        scoredPercent: null,
        strongReason: false,
        normalize: normalizeLabCatalogName,
      ),
    ],
    if (proposed.isPanel)
      _compareScoredField(
        l10n: l10n,
        label: 'description',
        proposedValue: proposed.description,
        existingValue: test.description,
        scoredPercent: null,
        strongReason: false,
        normalize: normalizeLabCatalogName,
      ),
    if (test.isStandard)
      _compareScoredField(
        l10n: l10n,
        label: 'source',
        proposedValue: '',
        existingValue: 'STANDARD',
        scoredPercent: null,
        strongReason: false,
        normalize: (String value) => value.trim().toUpperCase(),
      ),
  ];
}

AppSimilarityFieldRow _compareScoredField({
  required AppLocalizations l10n,
  required String label,
  required String? proposedValue,
  required String? existingValue,
  required int? scoredPercent,
  required bool strongReason,
  required String Function(String value) normalize,
}) {
  final String proposed = (proposedValue ?? '').trim();
  final String existing = (existingValue ?? '').trim();
  final String normalizedProposed = normalize(proposed);
  final String normalizedExisting = normalize(existing);

  final bool bothEmpty = proposed.isEmpty && existing.isEmpty;
  final bool exact =
      bothEmpty ||
      (normalizedProposed.isNotEmpty &&
          normalizedExisting.isNotEmpty &&
          normalizedProposed == normalizedExisting);

  int? percent = scoredPercent;
  if (percent == null &&
      normalizedProposed.isNotEmpty &&
      normalizedExisting.isNotEmpty) {
    percent = exact
        ? 100
        : labTextSimilarityScore(normalizedProposed, normalizedExisting);
  } else if (exact) {
    percent = 100;
  }

  return AppSimilarityFieldRow(
    key: label,
    label: _fieldLabel(l10n, label),
    proposedValue: _displayValue(proposed),
    existingValue: _displayValue(existing),
    score: percent,
  );
}

String _existingReferenceRangeSummary(LabCatalogItem item) {
  if (item.referenceRanges.isNotEmpty) {
    return item.referenceRanges
        .map((LabReferenceRange range) => range.displayLabel)
        .where((String value) => value.trim().isNotEmpty)
        .join(', ');
  }
  if ((item.referenceRange ?? '').trim().isNotEmpty) {
    return item.referenceRange!.trim();
  }
  if (item.referenceRangeCount > 0) {
    return '${item.referenceRangeCount}';
  }
  return '';
}

String _fieldLabel(AppLocalizations l10n, String label) {
  return switch (label) {
    'id' => l10n.labCatalogItemIdLabel,
    'name' => l10n.labTestNameLabel,
    'code' => l10n.labTestCodeLabel,
    'category' => l10n.labCategoryLabel,
    'specimen' => l10n.labSpecimenTypeLabel,
    'resultKind' => l10n.labResultKindLabel,
    'unit' => l10n.labDefaultUnitLabel,
    'description' => l10n.labTestDescriptionLabel,
    'ranges' => l10n.labTestRangesSectionTitle,
    'composition' => l10n.labPanelTestsLabel,
    'source' => l10n.labStandardCatalogBadge,
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
  final bool isPanel = proposed.isPanel;
  if (hasExactMatch) {
    return _SimilarityBannerCopy(
      title: l10n.labSimilarTestExactBannerTitle,
      message: isPanel
          ? l10n.labSimilarPanelExactBannerBody(score)
          : l10n.labSimilarTestExactBannerBody(score),
    );
  }

  if (topMatch == null) {
    return _SimilarityBannerCopy(
      title: isPanel
          ? l10n.labNoSimilarPanelBannerTitle
          : l10n.labNoSimilarTestBannerTitle,
      message: isPanel
          ? l10n.labNoSimilarPanelDialogBody
          : l10n.labNoSimilarTestDialogBody,
    );
  }

  final List<AppSimilarityFieldRow> comparisons = _buildFieldRows(
    l10n: l10n,
    proposed: proposed,
    match: topMatch,
  );
  final String fieldSummary = comparisons
      .map(
        (AppSimilarityFieldRow row) => l10n.labSimilarTestFieldStatusPart(
          row.label,
          _fieldStatusPlainLabel(l10n, row),
        ),
      )
      .join(' · ');

  return _SimilarityBannerCopy(
    title: l10n.labSimilarTestReviewBannerTitle(score),
    message: isPanel
        ? l10n.labSimilarPanelReviewBannerBody(score, fieldSummary)
        : l10n.labSimilarTestReviewBannerBody(score, fieldSummary),
  );
}

String _fieldStatusPlainLabel(
  AppLocalizations l10n,
  AppSimilarityFieldRow row,
) {
  if (row.isExact) {
    return l10n.patientsDuplicateStatusMatchLabel;
  }
  if ((row.proposedValue ?? '—') == '—' && (row.existingValue ?? '—') != '—') {
    return l10n.labSimilarTestOnlyExistingLabel;
  }
  if (row.score != null && row.score! >= labCatalogSimilarityThreshold) {
    return row.score == null
        ? l10n.patientsDuplicateStatusSimilarLabel
        : '${l10n.patientsDuplicateStatusSimilarLabel} · ${row.score}%';
  }
  return row.score == null
      ? l10n.patientsDuplicateStatusConflictLabel
      : '${l10n.patientsDuplicateStatusConflictLabel} · ${row.score}%';
}
