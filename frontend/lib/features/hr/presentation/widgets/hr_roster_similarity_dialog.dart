import 'package:flutter/material.dart';
import 'package:hosspi_hms/core/errors/app_failure.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';
import 'package:hosspi_hms/l10n/app_localizations_x.dart';
import 'package:hosspi_hms/shared/components/app_form_information_banner.dart';
import 'package:hosspi_hms/shared/components/app_similarity.dart';

@immutable
final class HrRosterSimilarityMatch {
  const HrRosterSimilarityMatch({
    required this.id,
    required this.name,
    required this.overallScore,
    required this.isExact,
    this.displayId,
    this.periodLabel,
    this.departmentLabel,
    this.fields = const <AppSimilarityFieldRow>[],
  });

  final String id;
  final String name;
  final String? displayId;
  final String? periodLabel;
  final String? departmentLabel;
  final int overallScore;
  final bool isExact;
  final List<AppSimilarityFieldRow> fields;
}

bool isHrRosterSimilarityConflict(AppFailure? failure) {
  if (failure == null || failure.category != AppFailureCategory.conflict) {
    return false;
  }
  final String code = failure.code.toLowerCase();
  if (code.contains('similar') || code.contains('duplicate_name')) {
    return true;
  }
  final String detail = (failure.detailMessage ?? '').toLowerCase();
  return detail.contains('similar roster') ||
      detail.contains('roster template with this name') ||
      detail.contains('confirm to create anyway');
}

bool isHrRosterExactNameConflict(AppFailure? failure) {
  if (failure == null || failure.category != AppFailureCategory.conflict) {
    return false;
  }
  final String code = failure.code.toLowerCase();
  if (code.contains('duplicate_name')) {
    return true;
  }
  final String detail = (failure.detailMessage ?? '').toLowerCase();
  return detail.contains('roster template with this name already exists');
}

List<HrRosterSimilarityMatch> hrRosterSimilarityMatchesFromConflict(
  AppFailure failure, {
  required AppLocalizations l10n,
}) {
  if (failure is! ConflictFailure) {
    return const <HrRosterSimilarityMatch>[];
  }
  final List<HrRosterSimilarityMatch> matches = <HrRosterSimilarityMatch>[];
  for (final Map<String, Object?> entry in failure.conflictEntries) {
    final String id =
        (entry['id'] ?? entry['display_id'] ?? entry['human_friendly_id'] ?? '')
            .toString();
    if (id.isEmpty) {
      continue;
    }
    final String name = (entry['name'] ?? l10n.profileUnknownValue).toString();
    final int score = _asInt(entry['score']) ?? 0;
    final bool exact =
        entry['isExact'] == true ||
        entry['exactNameConflict'] == true ||
        score >= 100;
    final List<AppSimilarityFieldRow> fields = <AppSimilarityFieldRow>[];
    final Object? comparisons = entry['field_comparisons'];
    if (comparisons is List<Object?>) {
      for (final Object? raw in comparisons) {
        if (raw is! Map) {
          continue;
        }
        final Map<String, Object?> row = Map<String, Object?>.from(raw);
        final String field = (row['field'] ?? '').toString();
        if (field.isEmpty) {
          continue;
        }
        fields.add(
          AppSimilarityFieldRow(
            key: field,
            label: _fieldLabel(l10n, field),
            proposedValue: row['input_value']?.toString(),
            existingValue: row['candidate_value']?.toString(),
            score: _asInt(row['score']),
          ),
        );
      }
    }
    matches.add(
      HrRosterSimilarityMatch(
        id: id,
        name: name,
        displayId: entry['display_id']?.toString() ??
            entry['human_friendly_id']?.toString(),
        periodLabel:
            '${entry['period_start'] ?? ''} – ${entry['period_end'] ?? ''}'
                .trim(),
        departmentLabel: entry['department_id']?.toString(),
        overallScore: score,
        isExact: exact,
        fields: fields,
      ),
    );
  }
  matches.sort(
    (HrRosterSimilarityMatch a, HrRosterSimilarityMatch b) =>
        b.overallScore.compareTo(a.overallScore),
  );
  return matches;
}

Future<bool> showHrRosterSimilarityDialog({
  required BuildContext context,
  required String proposedName,
  required List<HrRosterSimilarityMatch> matches,
  required bool blockProceed,
  bool isEdit = false,
}) async {
  final AppLocalizations l10n = context.l10n;
  final List<AppSimilarityMatch<HrRosterSimilarityMatch>> appMatches = matches
      .map(
        (HrRosterSimilarityMatch match) =>
            AppSimilarityMatch<HrRosterSimilarityMatch>(
              item: match,
              title: match.name,
              subtitle: match.displayId,
              overallScore: match.overallScore,
              isExact: match.isExact,
              fields: match.fields,
            ),
      )
      .toList(growable: false);

  final int overallScore = appMatches.isEmpty
      ? 0
      : appMatches.first.overallScore;

  final AppSimilarityReviewResult<HrRosterSimilarityMatch> result =
      await showAppSimilarityReviewDialog<HrRosterSimilarityMatch>(
        context,
        title: l10n.hrRosterSimilarityDialogTitle,
        bannerTitle: blockProceed
            ? l10n.hrRosterSimilarityExactBannerTitle
            : l10n.hrRosterSimilarityNearBannerTitle,
        bannerMessage: blockProceed
            ? l10n.hrRosterSimilarityExactBannerMessage
            : (isEdit
                  ? l10n.hrRosterSimilarityNearBannerEditMessage
                  : l10n.hrRosterSimilarityNearBannerMessage),
        bannerVariant: blockProceed
            ? AppFormInformationVariant.error
            : AppFormInformationVariant.warning,
        proposedFields: <AppSimilarityProposedField>[
          AppSimilarityProposedField(
            key: 'name',
            label: l10n.hrRosterNameLabel,
            initialValue: proposedName,
            editable: false,
          ),
        ],
        matches: appMatches,
        overallScore: overallScore,
        blockProceed: blockProceed,
        enableRetry: false,
        proposedReadOnly: true,
        proceedLabel: isEdit
            ? l10n.hrRosterSimilaritySaveAnywayAction
            : l10n.hrRosterSimilarityProceedAction,
        dialogIcon: Icons.edit_calendar_outlined,
      );

  return switch (result.action) {
    AppSimilarityReviewAction.proceed => true,
    AppSimilarityReviewAction.useExisting ||
    AppSimilarityReviewAction.replaceExisting ||
    AppSimilarityReviewAction.retry ||
    AppSimilarityReviewAction.cancel => false,
  };
}

int? _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  return int.tryParse(value?.toString() ?? '');
}

String _fieldLabel(AppLocalizations l10n, String field) {
  return switch (field) {
    'name' => l10n.hrRosterNameLabel,
    'department_id' => l10n.hrDepartmentLabel,
    'facility_id' => l10n.hrRosterOverviewFacilityLabel,
    'is_recurring' => l10n.hrRosterRecurringLabel,
    'period' => l10n.hrPeriodColumnLabel,
    'month_days' => l10n.hrRosterMonthDaysLabel,
    'weekly_schedule' => l10n.hrRosterWeekHoursTitle,
    'display_id' => l10n.hrRosterOverviewIdLabel,
    _ => field,
  };
}
