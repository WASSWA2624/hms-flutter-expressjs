import 'package:hosspi_hms/features/billing/domain/entities/billing_price_book_entry.dart';

/// Field comparison for Price book similarity review (billing.md §18).
enum BillingPriceBookFieldStatus { match, similar, different, missing }

final class BillingPriceBookFieldComparison {
  const BillingPriceBookFieldComparison({
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
  final BillingPriceBookFieldStatus status;
}

final class BillingPriceBookSimilarityDraft {
  const BillingPriceBookSimilarityDraft({
    required this.catalogItemId,
    required this.paymentMode,
    this.coveragePlanId,
    this.effectiveFrom,
    this.isActive = true,
  });

  final String catalogItemId;
  final String paymentMode;
  final String? coveragePlanId;
  final DateTime? effectiveFrom;
  final bool isActive;
}

final class BillingPriceBookSimilarityMatch {
  const BillingPriceBookSimilarityMatch({
    required this.entry,
    required this.score,
    required this.fieldComparisons,
    required this.isExact,
  });

  final BillingPriceBookEntry entry;
  final int score;
  final List<BillingPriceBookFieldComparison> fieldComparisons;
  final bool isExact;
}

final class BillingPriceBookSimilarityResult {
  const BillingPriceBookSimilarityResult({required this.matches});

  final List<BillingPriceBookSimilarityMatch> matches;

  bool get hasMatches => matches.isNotEmpty;

  bool get hasExactConflict =>
      matches.any((BillingPriceBookSimilarityMatch match) => match.isExact);

  int get closestScore => matches.isEmpty
      ? 0
      : matches
            .map((BillingPriceBookSimilarityMatch match) => match.score)
            .reduce((int a, int b) => a > b ? a : b);
}

/// Scores proposed Item · Mode · Scheme · Effective against existing rows.
BillingPriceBookSimilarityResult checkBillingPriceBookSimilarity({
  required BillingPriceBookSimilarityDraft draft,
  required Iterable<BillingPriceBookEntry> candidates,
  String? excludeEntryId,
}) {
  final List<BillingPriceBookSimilarityMatch> matches =
      <BillingPriceBookSimilarityMatch>[];

  for (final BillingPriceBookEntry entry in candidates) {
    if (excludeEntryId != null &&
        excludeEntryId.isNotEmpty &&
        entry.id == excludeEntryId) {
      continue;
    }
    final BillingPriceBookSimilarityMatch? match = _scoreCandidate(
      draft,
      entry,
    );
    if (match != null && (match.isExact || match.score >= 70)) {
      matches.add(match);
    }
  }

  matches.sort(
    (BillingPriceBookSimilarityMatch a, BillingPriceBookSimilarityMatch b) =>
        b.score.compareTo(a.score),
  );
  return BillingPriceBookSimilarityResult(
    matches: matches.take(5).toList(growable: false),
  );
}

BillingPriceBookSimilarityMatch? _scoreCandidate(
  BillingPriceBookSimilarityDraft draft,
  BillingPriceBookEntry entry,
) {
  final BillingPriceBookFieldComparison item = _textField(
    field: 'item',
    input: draft.catalogItemId,
    candidate: entry.catalogItemId,
  );
  final String proposedMode = draft.paymentMode.trim().toUpperCase();
  final String existingMode = entry.paymentMode.trim().toUpperCase();
  final BillingPriceBookFieldComparison mode = BillingPriceBookFieldComparison(
    field: 'mode',
    inputValue: proposedMode,
    candidateValue: existingMode,
    score: proposedMode == existingMode ? 100 : 0,
    status: proposedMode == existingMode
        ? BillingPriceBookFieldStatus.match
        : BillingPriceBookFieldStatus.different,
  );
  final BillingPriceBookFieldComparison scheme = _textField(
    field: 'scheme',
    input: draft.coveragePlanId ?? '',
    candidate: entry.coveragePlanId ?? entry.coveragePlanName ?? '',
  );
  final BillingPriceBookFieldComparison effective = _effectiveField(
    input: draft.effectiveFrom,
    candidate: entry.effectiveFrom,
  );

  final List<BillingPriceBookFieldComparison> fields =
      <BillingPriceBookFieldComparison>[item, mode, scheme, effective];
  final int score =
      (fields.fold<int>(
                0,
                (int sum, BillingPriceBookFieldComparison field) =>
                    sum + field.score,
              ) /
              fields.length)
          .round();
  final bool identityExact = fields.every(
    (BillingPriceBookFieldComparison field) => field.score == 100,
  );
  // Exact active row blocks create (billing.md §18 Price Add).
  final bool isExact = identityExact && entry.isActive;

  if (!isExact && score < 70) {
    return null;
  }
  return BillingPriceBookSimilarityMatch(
    entry: entry,
    score: score,
    fieldComparisons: fields,
    isExact: isExact,
  );
}

BillingPriceBookFieldComparison _textField({
  required String field,
  required String input,
  required String candidate,
}) {
  final String left = input.trim().toLowerCase();
  final String right = candidate.trim().toLowerCase();
  if (left.isEmpty && right.isEmpty) {
    return BillingPriceBookFieldComparison(
      field: field,
      inputValue: input,
      candidateValue: candidate,
      score: 100,
      status: BillingPriceBookFieldStatus.missing,
    );
  }
  if (left.isEmpty || right.isEmpty) {
    return BillingPriceBookFieldComparison(
      field: field,
      inputValue: input,
      candidateValue: candidate,
      score: 40,
      status: BillingPriceBookFieldStatus.missing,
    );
  }
  if (left == right) {
    return BillingPriceBookFieldComparison(
      field: field,
      inputValue: input,
      candidateValue: candidate,
      score: 100,
      status: BillingPriceBookFieldStatus.match,
    );
  }
  final int score = _tokenOverlapScore(left, right);
  return BillingPriceBookFieldComparison(
    field: field,
    inputValue: input,
    candidateValue: candidate,
    score: score,
    status: score >= 70
        ? BillingPriceBookFieldStatus.similar
        : BillingPriceBookFieldStatus.different,
  );
}

BillingPriceBookFieldComparison _effectiveField({
  required DateTime? input,
  required DateTime? candidate,
}) {
  final String inputLabel = _dateLabel(input);
  final String candidateLabel = _dateLabel(candidate);
  if (input == null && candidate == null) {
    return BillingPriceBookFieldComparison(
      field: 'effective',
      inputValue: inputLabel,
      candidateValue: candidateLabel,
      score: 100,
      status: BillingPriceBookFieldStatus.missing,
    );
  }
  if (input == null || candidate == null) {
    return BillingPriceBookFieldComparison(
      field: 'effective',
      inputValue: inputLabel,
      candidateValue: candidateLabel,
      score: 50,
      status: BillingPriceBookFieldStatus.similar,
    );
  }
  final DateTime left = DateTime.utc(input.year, input.month, input.day);
  final DateTime right = DateTime.utc(
    candidate.year,
    candidate.month,
    candidate.day,
  );
  if (left == right) {
    return BillingPriceBookFieldComparison(
      field: 'effective',
      inputValue: inputLabel,
      candidateValue: candidateLabel,
      score: 100,
      status: BillingPriceBookFieldStatus.match,
    );
  }
  final int dayDelta = left.difference(right).inDays.abs();
  if (dayDelta <= 7) {
    return BillingPriceBookFieldComparison(
      field: 'effective',
      inputValue: inputLabel,
      candidateValue: candidateLabel,
      score: 85,
      status: BillingPriceBookFieldStatus.similar,
    );
  }
  if (dayDelta <= 30) {
    return BillingPriceBookFieldComparison(
      field: 'effective',
      inputValue: inputLabel,
      candidateValue: candidateLabel,
      score: 60,
      status: BillingPriceBookFieldStatus.similar,
    );
  }
  return BillingPriceBookFieldComparison(
    field: 'effective',
    inputValue: inputLabel,
    candidateValue: candidateLabel,
    score: 0,
    status: BillingPriceBookFieldStatus.different,
  );
}

String _dateLabel(DateTime? value) {
  if (value == null) {
    return '';
  }
  final DateTime local = value.toLocal();
  final String month = local.month.toString().padLeft(2, '0');
  final String day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
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
