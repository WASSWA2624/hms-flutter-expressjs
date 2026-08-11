import 'package:hosspi_hms/features/billing/domain/entities/billing_entities.dart';

/// Field comparison for Refund similarity review (billing.md §18).
enum BillingRefundFieldStatus { match, similar, different, missing }

final class BillingRefundFieldComparison {
  const BillingRefundFieldComparison({
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
  final BillingRefundFieldStatus status;
}

final class BillingRefundSimilarityMatch {
  const BillingRefundSimilarityMatch({
    required this.payment,
    required this.score,
    required this.fieldComparisons,
    required this.isExact,
  });

  final BillingPayment payment;
  final int score;
  final List<BillingRefundFieldComparison> fieldComparisons;
  final bool isExact;
}

final class BillingRefundSimilarityResult {
  const BillingRefundSimilarityResult({required this.matches});

  final List<BillingRefundSimilarityMatch> matches;

  bool get hasMatches => matches.isNotEmpty;

  bool get hasExactConflict =>
      matches.any((BillingRefundSimilarityMatch match) => match.isExact);

  int get closestScore => matches.isEmpty
      ? 0
      : matches
            .map((BillingRefundSimilarityMatch match) => match.score)
            .reduce((int a, int b) => a > b ? a : b);
}

bool _isRefundCandidate(BillingPayment payment) {
  final String status = (payment.status ?? '').trim().toUpperCase();
  return status == 'REFUNDED' ||
      status == 'PENDING_REFUND' ||
      status == 'REFUND_PENDING' ||
      status == 'PARTIAL_REFUND';
}

/// Scores a proposed refund against near-duplicate refunded / pending refunds.
BillingRefundSimilarityResult checkBillingRefundSimilarity({
  required BillingWorkItem invoice,
  required BillingRefundDraft draft,
}) {
  final num proposedAmount = num.tryParse(draft.amount.replaceAll(',', '')) ?? 0;
  final String paymentId = draft.paymentId.trim();
  final List<BillingRefundSimilarityMatch> matches =
      <BillingRefundSimilarityMatch>[];

  for (final BillingPayment payment in invoice.payments) {
    if (!_isRefundCandidate(payment) && payment.id != paymentId) {
      // Only compare against the selected payment when it already shows refund
      // activity, or against other refunded payments on the same invoice.
      continue;
    }
    if (!_isRefundCandidate(payment) && payment.id == paymentId) {
      continue;
    }
    final BillingRefundSimilarityMatch? match = _scoreCandidate(
      draft: draft,
      proposedAmount: proposedAmount,
      payment: payment,
    );
    if (match != null && (match.isExact || match.score >= 70)) {
      matches.add(match);
    }
  }

  matches.sort(
    (BillingRefundSimilarityMatch a, BillingRefundSimilarityMatch b) =>
        b.score.compareTo(a.score),
  );
  return BillingRefundSimilarityResult(
    matches: matches.take(5).toList(growable: false),
  );
}

BillingRefundSimilarityMatch? _scoreCandidate({
  required BillingRefundDraft draft,
  required num proposedAmount,
  required BillingPayment payment,
}) {
  final bool samePayment = payment.id == draft.paymentId.trim();
  final BillingRefundFieldComparison paymentField = BillingRefundFieldComparison(
    field: 'payment',
    inputValue: draft.paymentId,
    candidateValue: payment.displayId ?? payment.id,
    score: samePayment ? 100 : 0,
    status: samePayment
        ? BillingRefundFieldStatus.match
        : BillingRefundFieldStatus.different,
  );
  final BillingRefundFieldComparison amount = _amountField(
    input: proposedAmount,
    candidate: payment.amount,
  );
  final BillingRefundFieldComparison reason = BillingRefundFieldComparison(
    field: 'reason',
    inputValue: draft.reason,
    candidateValue: payment.status ?? '',
    score: draft.reason.trim().isEmpty ? 40 : 70,
    status: BillingRefundFieldStatus.similar,
  );

  final List<BillingRefundFieldComparison> fields =
      <BillingRefundFieldComparison>[paymentField, amount, reason];
  // Prefer payment+amount for overall score.
  final int score = ((paymentField.score * 2) + (amount.score * 2) + reason.score) ~/
      5;
  final bool isExact = samePayment && amount.score == 100;
  if (!isExact && score < 70) {
    return null;
  }
  return BillingRefundSimilarityMatch(
    payment: payment,
    score: score,
    fieldComparisons: fields,
    isExact: isExact,
  );
}

BillingRefundFieldComparison _amountField({
  required num input,
  required num candidate,
}) {
  final String inputLabel = input.toString();
  final String candidateLabel = candidate.toString();
  if (input == 0 && candidate == 0) {
    return BillingRefundFieldComparison(
      field: 'amount',
      inputValue: inputLabel,
      candidateValue: candidateLabel,
      score: 100,
      status: BillingRefundFieldStatus.match,
    );
  }
  final num baseline = input.abs() > candidate.abs() ? input.abs() : candidate.abs();
  if (baseline == 0) {
    return BillingRefundFieldComparison(
      field: 'amount',
      inputValue: inputLabel,
      candidateValue: candidateLabel,
      score: 0,
      status: BillingRefundFieldStatus.different,
    );
  }
  final num delta = (input - candidate).abs() / baseline;
  if (delta <= 0.01) {
    return BillingRefundFieldComparison(
      field: 'amount',
      inputValue: inputLabel,
      candidateValue: candidateLabel,
      score: 100,
      status: BillingRefundFieldStatus.match,
    );
  }
  if (delta <= 0.10) {
    return BillingRefundFieldComparison(
      field: 'amount',
      inputValue: inputLabel,
      candidateValue: candidateLabel,
      score: 85,
      status: BillingRefundFieldStatus.similar,
    );
  }
  if (delta <= 0.25) {
    return BillingRefundFieldComparison(
      field: 'amount',
      inputValue: inputLabel,
      candidateValue: candidateLabel,
      score: 60,
      status: BillingRefundFieldStatus.similar,
    );
  }
  return BillingRefundFieldComparison(
    field: 'amount',
    inputValue: inputLabel,
    candidateValue: candidateLabel,
    score: 0,
    status: BillingRefundFieldStatus.different,
  );
}
