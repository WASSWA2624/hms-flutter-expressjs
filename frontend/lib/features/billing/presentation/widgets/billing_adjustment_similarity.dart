import 'package:hosspi_hms/features/billing/domain/entities/billing_entities.dart';

/// Field comparison for Adjust similarity review (billing.md §18).
enum BillingAdjustmentFieldStatus { match, similar, different, missing }

final class BillingAdjustmentFieldComparison {
  const BillingAdjustmentFieldComparison({
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
  final BillingAdjustmentFieldStatus status;
}

final class BillingAdjustmentSimilarityMatch {
  const BillingAdjustmentSimilarityMatch({
    required this.adjustment,
    required this.score,
    required this.fieldComparisons,
    required this.isExact,
  });

  final BillingAdjustment adjustment;
  final int score;
  final List<BillingAdjustmentFieldComparison> fieldComparisons;
  final bool isExact;
}

final class BillingAdjustmentSimilarityResult {
  const BillingAdjustmentSimilarityResult({required this.matches});

  final List<BillingAdjustmentSimilarityMatch> matches;

  bool get hasMatches => matches.isNotEmpty;

  bool get hasExactConflict => matches.any(
    (BillingAdjustmentSimilarityMatch match) => match.isExact,
  );

  int get closestScore => matches.isEmpty
      ? 0
      : matches
            .map((BillingAdjustmentSimilarityMatch match) => match.score)
            .reduce((int a, int b) => a > b ? a : b);
}

bool _isPendingAdjustment(BillingAdjustment adjustment) {
  final String status = (adjustment.status ?? '').trim().toUpperCase();
  return status.isEmpty ||
      status == 'PENDING' ||
      status == 'REQUESTED' ||
      status == 'SUBMITTED';
}

/// Scores a proposed adjust against pending adjusts on the same invoice.
BillingAdjustmentSimilarityResult checkBillingAdjustmentSimilarity({
  required BillingWorkItem invoice,
  required BillingAdjustmentDraft draft,
}) {
  final num proposedAmount = num.tryParse(draft.amount.replaceAll(',', '')) ?? 0;
  final String proposedType = (draft.status ?? draft.reason).trim().toUpperCase();
  final String invoiceLabel =
      (invoice.displayId ?? invoice.invoiceDisplayId ?? '').trim();

  final List<BillingAdjustmentSimilarityMatch> matches =
      <BillingAdjustmentSimilarityMatch>[];

  for (final BillingAdjustment adjustment in invoice.adjustments) {
    if (!_isPendingAdjustment(adjustment)) {
      continue;
    }
    final BillingAdjustmentSimilarityMatch? match = _scoreCandidate(
      invoiceLabel: invoiceLabel,
      proposedAmount: proposedAmount,
      proposedType: proposedType,
      proposedReason: draft.reason.trim(),
      adjustment: adjustment,
    );
    if (match != null && (match.isExact || match.score >= 70)) {
      matches.add(match);
    }
  }

  matches.sort(
    (BillingAdjustmentSimilarityMatch a, BillingAdjustmentSimilarityMatch b) =>
        b.score.compareTo(a.score),
  );
  return BillingAdjustmentSimilarityResult(
    matches: matches.take(5).toList(growable: false),
  );
}

BillingAdjustmentSimilarityMatch? _scoreCandidate({
  required String invoiceLabel,
  required num proposedAmount,
  required String proposedType,
  required String proposedReason,
  required BillingAdjustment adjustment,
}) {
  final String existingType = (adjustment.status ?? '').trim().toUpperCase();
  final String existingReason = (adjustment.reason ?? '').trim();
  final num existingAmount = adjustment.amount;
  final int typeScore = _typeScore(
    proposedType: proposedType,
    proposedReason: proposedReason,
    existingType: existingType,
    existingReason: existingReason,
  );

  final BillingAdjustmentFieldComparison invoice = BillingAdjustmentFieldComparison(
    field: 'invoice',
    inputValue: invoiceLabel,
    candidateValue: invoiceLabel,
    score: 100,
    status: BillingAdjustmentFieldStatus.match,
  );
  final BillingAdjustmentFieldComparison type = BillingAdjustmentFieldComparison(
    field: 'type',
    inputValue: proposedType.isEmpty ? proposedReason : proposedType,
    candidateValue: existingType.isEmpty ? existingReason : existingType,
    score: typeScore,
    status: typeScore == 100
        ? BillingAdjustmentFieldStatus.match
        : typeScore >= 70
        ? BillingAdjustmentFieldStatus.similar
        : BillingAdjustmentFieldStatus.different,
  );
  final BillingAdjustmentFieldComparison amount = _amountField(
    input: proposedAmount,
    candidate: existingAmount,
  );

  final List<BillingAdjustmentFieldComparison> fields =
      <BillingAdjustmentFieldComparison>[invoice, type, amount];
  final int scoredTotal = fields.fold<int>(
    0,
    (int sum, BillingAdjustmentFieldComparison field) => sum + field.score,
  );
  final int score = (scoredTotal / fields.length).round();
  final bool isExact = fields.every(
    (BillingAdjustmentFieldComparison field) => field.score == 100,
  );
  if (!isExact && score < 70) {
    return null;
  }
  return BillingAdjustmentSimilarityMatch(
    adjustment: adjustment,
    score: score,
    fieldComparisons: fields,
    isExact: isExact,
  );
}

int _typeScore({
  required String proposedType,
  required String proposedReason,
  required String existingType,
  required String existingReason,
}) {
  final String left = proposedType.isNotEmpty
      ? proposedType
      : proposedReason.trim().toUpperCase();
  final String right = existingType.isNotEmpty
      ? existingType
      : existingReason.trim().toUpperCase();
  if (left.isEmpty && right.isEmpty) {
    return 100;
  }
  if (left.isEmpty || right.isEmpty) {
    return 40;
  }
  if (left == right) {
    return 100;
  }
  final String leftReason = proposedReason.trim().toUpperCase();
  final String rightReason = existingReason.trim().toUpperCase();
  if (leftReason.isNotEmpty && leftReason == rightReason) {
    return 100;
  }
  if (leftReason.isNotEmpty &&
      rightReason.isNotEmpty &&
      (leftReason.contains(rightReason) || rightReason.contains(leftReason))) {
    return 80;
  }
  return 0;
}

BillingAdjustmentFieldComparison _amountField({
  required num input,
  required num candidate,
}) {
  final String inputLabel = input.toString();
  final String candidateLabel = candidate.toString();
  if (input == 0 && candidate == 0) {
    return BillingAdjustmentFieldComparison(
      field: 'amount',
      inputValue: inputLabel,
      candidateValue: candidateLabel,
      score: 100,
      status: BillingAdjustmentFieldStatus.match,
    );
  }
  final num baseline = input.abs() > candidate.abs() ? input.abs() : candidate.abs();
  if (baseline == 0) {
    return BillingAdjustmentFieldComparison(
      field: 'amount',
      inputValue: inputLabel,
      candidateValue: candidateLabel,
      score: 0,
      status: BillingAdjustmentFieldStatus.different,
    );
  }
  final num delta = (input - candidate).abs() / baseline;
  if (delta <= 0.01) {
    return BillingAdjustmentFieldComparison(
      field: 'amount',
      inputValue: inputLabel,
      candidateValue: candidateLabel,
      score: 100,
      status: BillingAdjustmentFieldStatus.match,
    );
  }
  if (delta <= 0.10) {
    return BillingAdjustmentFieldComparison(
      field: 'amount',
      inputValue: inputLabel,
      candidateValue: candidateLabel,
      score: 85,
      status: BillingAdjustmentFieldStatus.similar,
    );
  }
  if (delta <= 0.25) {
    return BillingAdjustmentFieldComparison(
      field: 'amount',
      inputValue: inputLabel,
      candidateValue: candidateLabel,
      score: 60,
      status: BillingAdjustmentFieldStatus.similar,
    );
  }
  return BillingAdjustmentFieldComparison(
    field: 'amount',
    inputValue: inputLabel,
    candidateValue: candidateLabel,
    score: 0,
    status: BillingAdjustmentFieldStatus.different,
  );
}
