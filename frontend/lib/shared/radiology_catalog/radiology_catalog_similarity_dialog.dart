import 'package:flutter/material.dart';
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

/// Radiology catalog adapter over [showAppSimilarityReviewDialog].
Future<RadiologyCatalogSimilarityDialogResult>
showRadiologyCatalogSimilarityDialog(
  BuildContext context, {
  required RadiologyCatalogProposedTest proposed,
  required List<RadiologyCatalogSimilarityMatch> matches,
  bool allowProceed = true,
  bool isEditing = false,
}) async {
  final AppLocalizations l10n = context.l10n;
  final List<RadiologyCatalogSimilarityMatch> visibleMatches = matches
      .take(5)
      .toList(growable: false);
  final bool hasExactMatch = visibleMatches.any(
    (RadiologyCatalogSimilarityMatch match) => match.isExact,
  );
  final bool hasMatches = visibleMatches.isNotEmpty;
  // Create/Save anyway stays available even for exact name/code clashes;
  // the caller sends confirm_similar after proceed.
  final RadiologyCatalogSimilarityMatch? topMatch =
      visibleMatches.isEmpty ? null : visibleMatches.first;
  final int overallScore = topMatch?.score ?? 0;
  final _SimilarityBannerCopy banner = _similarityBannerCopy(
    l10n: l10n,
    proposed: proposed,
    topMatch: topMatch,
    hasExactMatch: hasExactMatch,
  );
  final String proceedLabel = isEditing
      ? l10n.radiologyProceedUpdateProcedureAction
      : hasMatches || hasExactMatch
      ? l10n.radiologyProceedCreateProcedureAction
      : l10n.radiologyContinueSaveProcedureAction;
  final AppFormInformationVariant bannerVariant = hasExactMatch
      ? AppFormInformationVariant.error
      : hasMatches
      ? AppFormInformationVariant.warning
      : AppFormInformationVariant.success;
  final String dialogTitle = l10n.radiologySimilarProcedureDialogTitle;

  final List<AppSimilarityMatch<RadiologyCatalogProcedure>> appMatches =
      visibleMatches.map((RadiologyCatalogSimilarityMatch match) {
        final RadiologyCatalogProcedure procedure = match.procedure;
        return AppSimilarityMatch<RadiologyCatalogProcedure>(
          item: procedure,
          title: procedure.name,
          subtitle: <String>[
            if (procedure.effectiveId.trim().isNotEmpty) procedure.effectiveId,
            if (procedure.isStandard) l10n.radiologyStandardCatalogBadge,
          ].join(' · '),
          overallScore: match.score,
          isExact: match.isExact,
          fields: _buildFieldRows(
            l10n: l10n,
            proposed: proposed,
            match: match,
          ),
        );
      }).toList(growable: false);

  final AppSimilarityReviewResult<RadiologyCatalogProcedure> result =
      await showAppSimilarityReviewDialog<RadiologyCatalogProcedure>(
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
        useThisLabel: l10n.radiologyUseThisProcedureAction,
        useThisIcon: Icons.check_circle_outline,
        proposedHeading: l10n.radiologySimilarProcedureProposedHeading,
        matchesHeading: l10n.radiologySimilarProcedureMatchesHeading,
        exactBadgeLabel: l10n.radiologySimilarProcedureExactMatchLabel,
        nearBadgeLabel: l10n.radiologySimilarProcedureNearMatchLabel,
        existingHeading: l10n.radiologySimilarProcedureExistingHeading,
        fieldColumnLabel: l10n.radiologySimilarProcedureFieldColumnLabel,
        proposedColumnLabel: l10n.radiologySimilarProcedureYourEntryLabel,
        existingColumnLabel: l10n.radiologySimilarProcedureExistingValueLabel,
        noMatchLabel: l10n.radiologyNoSimilarProcedureDialogBody,
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
      return const RadiologyCatalogSimilarityDialogResult.cancel();
    case AppSimilarityReviewAction.replaceExisting:
      return const RadiologyCatalogSimilarityDialogResult.cancel();
    case AppSimilarityReviewAction.proceed:
      return const RadiologyCatalogSimilarityDialogResult.proceed();
    case AppSimilarityReviewAction.useExisting:
      final RadiologyCatalogProcedure? procedure = result.selected;
      if (procedure == null) {
        return const RadiologyCatalogSimilarityDialogResult.cancel();
      }
      return RadiologyCatalogSimilarityDialogResult.useExisting(procedure);
  }
}

List<AppSimilarityProposedField> _proposedFields({
  required AppLocalizations l10n,
  required RadiologyCatalogProposedTest proposed,
}) {
  return <AppSimilarityProposedField>[
    AppSimilarityProposedField(
      key: 'name',
      label: l10n.radiologyProcedureNameLabel,
      initialValue: proposed.name,
      isRequired: true,
    ),
    AppSimilarityProposedField(
      key: 'code',
      label: l10n.radiologyProcedureCodeOptionalLabel,
      initialValue: proposed.code ?? '',
    ),
    AppSimilarityProposedField(
      key: 'modality',
      label: l10n.radiologyModalityLabel,
      initialValue: proposed.modality ?? '',
    ),
  ];
}

List<AppSimilarityFieldRow> _buildFieldRows({
  required AppLocalizations l10n,
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
  final String normalizedProposedModality =
      normalizeRadiologyCatalogModality(proposedModality);
  final String normalizedExistingModality =
      normalizeRadiologyCatalogModality(existingModality);

  final bool nameExact =
      normalizedProposedName.isNotEmpty &&
      normalizedProposedName == normalizedExistingName;
  final bool codeExact =
      normalizedProposedCode.isNotEmpty &&
      normalizedExistingCode.isNotEmpty &&
      normalizedProposedCode == normalizedExistingCode;
  final bool modalityExact =
      normalizedProposedModality.isNotEmpty &&
      normalizedExistingModality == normalizedExistingModality;

  final int? nameScore = match.nameScore;
  final int? codeScore = match.codeScore;
  final int? modalityScore = match.modalityScore;

  int? codePercent() {
    if (codeExact || (proposedCode.isEmpty && existingCode.isEmpty)) {
      return 100;
    }
    return codeScore;
  }

  int? modalityPercent() => modalityExact ? 100 : modalityScore;

  return <AppSimilarityFieldRow>[
    AppSimilarityFieldRow(
      key: 'id',
      label: _fieldLabel(l10n, 'id'),
      proposedValue: _displayValue(null),
      existingValue: _displayValue(test.effectiveId),
    ),
    AppSimilarityFieldRow(
      key: 'name',
      label: _fieldLabel(l10n, 'name'),
      proposedValue: _displayValue(proposedName),
      existingValue: _displayValue(existingName),
      score: nameExact ? 100 : nameScore,
    ),
    AppSimilarityFieldRow(
      key: 'code',
      label: _fieldLabel(l10n, 'code'),
      proposedValue: _displayValue(proposedCode),
      existingValue: _displayValue(existingCode),
      score: codePercent(),
    ),
    AppSimilarityFieldRow(
      key: 'modality',
      label: _fieldLabel(l10n, 'modality'),
      proposedValue: _displayValue(proposedModality),
      existingValue: _displayValue(existingModality),
      score: modalityPercent(),
    ),
    if ((test.bodyRegion ?? '').trim().isNotEmpty)
      AppSimilarityFieldRow(
        key: 'bodyRegion',
        label: _fieldLabel(l10n, 'bodyRegion'),
        proposedValue: _displayValue(null),
        existingValue: _displayValue(test.bodyRegion),
      ),
    if ((test.laterality ?? '').trim().isNotEmpty)
      AppSimilarityFieldRow(
        key: 'laterality',
        label: _fieldLabel(l10n, 'laterality'),
        proposedValue: _displayValue(null),
        existingValue: _displayValue(test.laterality),
      ),
    if ((test.equipment ?? '').trim().isNotEmpty)
      AppSimilarityFieldRow(
        key: 'equipment',
        label: _fieldLabel(l10n, 'equipment'),
        proposedValue: _displayValue(null),
        existingValue: _displayValue(test.equipment),
      ),
  ];
}

String _fieldLabel(AppLocalizations l10n, String label) {
  return switch (label) {
    'id' => l10n.radiologyCatalogProcedureIdLabel,
    'name' => l10n.radiologyProcedureNameLabel,
    'code' => l10n.radiologyProcedureCodeLabel,
    'modality' => l10n.radiologyModalityLabel,
    'bodyRegion' => l10n.radiologyBodyRegionLabel,
    'laterality' => l10n.radiologyLateralityLabel,
    'equipment' => l10n.radiologyEquipmentLabel,
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
      message: l10n.radiologyNoSimilarProcedureDialogBody,
    );
  }

  final List<AppSimilarityFieldRow> comparisons = _buildFieldRows(
    l10n: l10n,
    proposed: proposed,
    match: topMatch,
  );
  final String fieldSummary = comparisons
      .map(
        (AppSimilarityFieldRow row) =>
            l10n.radiologySimilarProcedureFieldStatusPart(
              row.label,
              _fieldStatusPlainLabel(l10n, row),
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
  AppSimilarityFieldRow row,
) {
  if (row.isExact) {
    return l10n.patientsDuplicateStatusMatchLabel;
  }
  if ((row.proposedValue ?? '—') == '—' && (row.existingValue ?? '—') != '—') {
    return l10n.radiologySimilarProcedureOnlyExistingLabel;
  }
  if (row.score != null && row.score! >= radiologyCatalogSimilarityThreshold) {
    return row.score == null
        ? l10n.patientsDuplicateStatusSimilarLabel
        : '${l10n.patientsDuplicateStatusSimilarLabel} · ${row.score}%';
  }
  return row.score == null
      ? l10n.patientsDuplicateStatusConflictLabel
      : '${l10n.patientsDuplicateStatusConflictLabel} · ${row.score}%';
}
