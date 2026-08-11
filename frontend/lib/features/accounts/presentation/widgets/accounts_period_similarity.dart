import 'package:hosspi_hms/features/accounts/domain/entities/accounts_entities.dart';

/// Field comparison for Open period similarity (accounts.md §18).
enum AccountsPeriodFieldStatus { match, similar, different, missing }

final class AccountsPeriodFieldComparison {
  const AccountsPeriodFieldComparison({
    required this.field,
    required this.inputValue,
    required this.candidateValue,
    required this.score,
    required this.status,
  });

  final String field;
  final String inputValue;
  final String candidateValue;
  final int score;
  final AccountsPeriodFieldStatus status;
}

final class AccountsPeriodSimilarityDraft {
  const AccountsPeriodSimilarityDraft({
    required this.label,
    required this.startDate,
    required this.endDate,
    this.facilityLabel = '',
  });

  final String label;
  final DateTime startDate;
  final DateTime endDate;
  final String facilityLabel;
}

final class AccountsPeriodSimilarityMatch {
  const AccountsPeriodSimilarityMatch({
    required this.period,
    required this.score,
    required this.fieldComparisons,
    required this.isExact,
    required this.isOverlap,
  });

  final AccountsFiscalPeriod period;
  final int score;
  final List<AccountsPeriodFieldComparison> fieldComparisons;
  final bool isExact;
  final bool isOverlap;
}

final class AccountsPeriodSimilarityResult {
  const AccountsPeriodSimilarityResult({required this.matches});

  final List<AccountsPeriodSimilarityMatch> matches;

  bool get hasMatches => matches.isNotEmpty;

  bool get hasExactConflict =>
      matches.any((AccountsPeriodSimilarityMatch match) => match.isExact);

  bool get hasOverlapConflict =>
      matches.any((AccountsPeriodSimilarityMatch match) => match.isOverlap);

  int get closestScore => matches.isEmpty
      ? 0
      : matches
            .map((AccountsPeriodSimilarityMatch match) => match.score)
            .reduce((int a, int b) => a > b ? a : b);
}

/// Scores Label · dates · facility against existing periods.
AccountsPeriodSimilarityResult checkAccountsPeriodSimilarity({
  required AccountsPeriodSimilarityDraft draft,
  required Iterable<AccountsFiscalPeriod> candidates,
}) {
  final List<AccountsPeriodSimilarityMatch> matches =
      <AccountsPeriodSimilarityMatch>[];

  for (final AccountsFiscalPeriod period in candidates) {
    final AccountsPeriodSimilarityMatch? match = _scoreCandidate(
      draft,
      period,
    );
    if (match != null &&
        (match.isExact || match.isOverlap || match.score >= 70)) {
      matches.add(match);
    }
  }

  matches.sort(
    (AccountsPeriodSimilarityMatch a, AccountsPeriodSimilarityMatch b) =>
        b.score.compareTo(a.score),
  );
  return AccountsPeriodSimilarityResult(
    matches: matches.take(5).toList(growable: false),
  );
}

AccountsPeriodSimilarityMatch? _scoreCandidate(
  AccountsPeriodSimilarityDraft draft,
  AccountsFiscalPeriod period,
) {
  final AccountsPeriodFieldComparison label = _textField(
    field: 'label',
    input: draft.label,
    candidate: period.label.isNotEmpty ? period.label : period.effectiveLabel,
  );
  final AccountsPeriodFieldComparison dates = _datesField(
    draftStart: draft.startDate,
    draftEnd: draft.endDate,
    periodStart: period.startDate ?? period.openedAt,
    periodEnd: period.endDate ?? period.closedAt,
  );
  final AccountsPeriodFieldComparison facility = _textField(
    field: 'facility',
    input: draft.facilityLabel,
    candidate: period.publicFacilityLabel,
  );

  final List<AccountsPeriodFieldComparison> fields =
      <AccountsPeriodFieldComparison>[label, dates, facility];
  final int score =
      (fields.fold<int>(
                0,
                (int sum, AccountsPeriodFieldComparison field) =>
                    sum + field.score,
              ) /
              fields.length)
          .round();

  final bool isExact =
      label.status == AccountsPeriodFieldStatus.match &&
      dates.status == AccountsPeriodFieldStatus.match &&
      label.inputValue.trim().isNotEmpty;
  final bool isOverlap =
      dates.status == AccountsPeriodFieldStatus.match ||
      dates.status == AccountsPeriodFieldStatus.similar;
  final bool nearLabel =
      label.status == AccountsPeriodFieldStatus.match ||
      label.status == AccountsPeriodFieldStatus.similar;

  if (!isExact && !isOverlap && !nearLabel && score < 70) {
    return null;
  }

  return AccountsPeriodSimilarityMatch(
    period: period,
    score: isExact ? 100 : (nearLabel && score < 70 ? 70 : score),
    fieldComparisons: fields,
    isExact: isExact,
    isOverlap: isOverlap && period.isOpen,
  );
}

AccountsPeriodFieldComparison _datesField({
  required DateTime draftStart,
  required DateTime draftEnd,
  required DateTime? periodStart,
  required DateTime? periodEnd,
}) {
  final String input =
      '${_formatDay(draftStart)} → ${_formatDay(draftEnd)}';
  if (periodStart == null || periodEnd == null) {
    return AccountsPeriodFieldComparison(
      field: 'dates',
      inputValue: input,
      candidateValue: '',
      score: 0,
      status: AccountsPeriodFieldStatus.missing,
    );
  }
  final String candidate =
      '${_formatDay(periodStart)} → ${_formatDay(periodEnd)}';
  final DateTime aStart = _dateOnly(draftStart);
  final DateTime aEnd = _dateOnly(draftEnd);
  final DateTime bStart = _dateOnly(periodStart);
  final DateTime bEnd = _dateOnly(periodEnd);

  if (aStart == bStart && aEnd == bEnd) {
    return AccountsPeriodFieldComparison(
      field: 'dates',
      inputValue: input,
      candidateValue: candidate,
      score: 100,
      status: AccountsPeriodFieldStatus.match,
    );
  }
  final bool overlaps = !aEnd.isBefore(bStart) && !bEnd.isBefore(aStart);
  if (overlaps) {
    return AccountsPeriodFieldComparison(
      field: 'dates',
      inputValue: input,
      candidateValue: candidate,
      score: 90,
      status: AccountsPeriodFieldStatus.similar,
    );
  }
  return AccountsPeriodFieldComparison(
    field: 'dates',
    inputValue: input,
    candidateValue: candidate,
    score: 10,
    status: AccountsPeriodFieldStatus.different,
  );
}

AccountsPeriodFieldComparison _textField({
  required String field,
  required String input,
  required String candidate,
}) {
  final String left = input.trim().toLowerCase();
  final String right = candidate.trim().toLowerCase();
  if (left.isEmpty && right.isEmpty) {
    return AccountsPeriodFieldComparison(
      field: field,
      inputValue: input,
      candidateValue: candidate,
      score: 0,
      status: AccountsPeriodFieldStatus.missing,
    );
  }
  if (left.isEmpty || right.isEmpty) {
    return AccountsPeriodFieldComparison(
      field: field,
      inputValue: input,
      candidateValue: candidate,
      score: 0,
      status: AccountsPeriodFieldStatus.missing,
    );
  }
  if (left == right) {
    return AccountsPeriodFieldComparison(
      field: field,
      inputValue: input,
      candidateValue: candidate,
      score: 100,
      status: AccountsPeriodFieldStatus.match,
    );
  }
  final int score = _tokenOverlapScore(left, right);
  return AccountsPeriodFieldComparison(
    field: field,
    inputValue: input,
    candidateValue: candidate,
    score: score,
    status: score >= 70
        ? AccountsPeriodFieldStatus.similar
        : AccountsPeriodFieldStatus.different,
  );
}

int _tokenOverlapScore(String left, String right) {
  final Set<String> leftTokens = left
      .split(RegExp(r'[^a-z0-9]+'))
      .where((String token) => token.isNotEmpty)
      .toSet();
  final Set<String> rightTokens = right
      .split(RegExp(r'[^a-z0-9]+'))
      .where((String token) => token.isNotEmpty)
      .toSet();
  if (leftTokens.isEmpty || rightTokens.isEmpty) {
    return left.contains(right) || right.contains(left) ? 75 : 20;
  }
  final int shared = leftTokens.intersection(rightTokens).length;
  final int union = leftTokens.union(rightTokens).length;
  if (union == 0) {
    return 0;
  }
  return ((shared / union) * 100).round();
}

DateTime _dateOnly(DateTime value) =>
    DateTime.utc(value.toUtc().year, value.toUtc().month, value.toUtc().day);

String _formatDay(DateTime value) {
  final DateTime local = value.toLocal();
  final String month = local.month.toString().padLeft(2, '0');
  final String day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}
