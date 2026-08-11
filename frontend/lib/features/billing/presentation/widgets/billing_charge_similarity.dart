import 'package:hosspi_hms/features/billing/domain/entities/billing_entities.dart';

/// Field comparison for Charge similarity review (billing.md §18).
enum BillingChargeFieldStatus { match, similar, different, missing }

final class BillingChargeFieldComparison {
  const BillingChargeFieldComparison({
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
  final BillingChargeFieldStatus status;
}

final class BillingChargeSimilarityMatch {
  const BillingChargeSimilarityMatch({
    required this.item,
    required this.score,
    required this.fieldComparisons,
    required this.isExact,
  });

  final BillingWorkItem item;
  final int score;
  final List<BillingChargeFieldComparison> fieldComparisons;
  final bool isExact;
}

final class BillingChargeSimilarityResult {
  const BillingChargeSimilarityResult({
    required this.matches,
  });

  final List<BillingChargeSimilarityMatch> matches;

  bool get hasMatches => matches.isNotEmpty;

  bool get hasExactConflict =>
      matches.any((BillingChargeSimilarityMatch match) => match.isExact);

  int get closestScore => matches.isEmpty
      ? 0
      : matches
            .map((BillingChargeSimilarityMatch match) => match.score)
            .reduce((int a, int b) => a > b ? a : b);
}

/// Scores [draft] against open drafts / recent charges for the same patient.
BillingChargeSimilarityResult checkBillingChargeSimilarity({
  required BillingChargeDraft draft,
  required Iterable<BillingWorkItem> candidates,
}) {
  final String patientId = draft.patientId.trim();
  final List<BillingChargeSimilarityMatch> matches =
      <BillingChargeSimilarityMatch>[];

  for (final BillingWorkItem item in candidates) {
    if (!item.isInvoice) {
      continue;
    }
    final String candidatePatientId = (item.patientId ?? '').trim();
    if (patientId.isEmpty ||
        candidatePatientId.isEmpty ||
        candidatePatientId != patientId) {
      continue;
    }

    final BillingChargeSimilarityMatch? match = _scoreCandidate(draft, item);
    if (match != null && (match.isExact || match.score >= 70)) {
      matches.add(match);
    }
  }

  matches.sort(
    (BillingChargeSimilarityMatch a, BillingChargeSimilarityMatch b) =>
        b.score.compareTo(a.score),
  );
  return BillingChargeSimilarityResult(
    matches: matches.take(5).toList(growable: false),
  );
}

BillingChargeSimilarityMatch? _scoreCandidate(
  BillingChargeDraft draft,
  BillingWorkItem item,
) {
  final String proposedItem = draft.itemDescription.trim();
  final String existingItem = item.items.isEmpty
      ? ''
      : item.items.first.description.trim();
  final String proposedMode = draft.paymentMode.trim().toUpperCase();
  final String existingMode = _inferredPaymentMode(item);
  final String proposedEncounter = (draft.encounterDisplayId ?? '').trim();
  final String existingEncounter = _publicId(item.encounterDisplayId) ?? '';
  final num proposedAmount = draft.lineAmount;
  final num existingAmount = item.effectiveTotal;

  final BillingChargeFieldComparison patient = BillingChargeFieldComparison(
    field: 'patient',
    inputValue: draft.patientDisplayName?.trim().isNotEmpty == true
        ? draft.patientDisplayName!.trim()
        : (draft.patientDisplayId ?? '').trim(),
    candidateValue: item.effectivePatientName,
    score: 100,
    status: BillingChargeFieldStatus.match,
  );
  final BillingChargeFieldComparison itemField = _textField(
    field: 'item',
    input: proposedItem,
    candidate: existingItem,
  );
  final BillingChargeFieldComparison encounter = _encounterField(
    input: proposedEncounter,
    candidate: existingEncounter,
  );
  final BillingChargeFieldComparison mode = BillingChargeFieldComparison(
    field: 'mode',
    inputValue: proposedMode,
    candidateValue: existingMode,
    score: proposedMode == existingMode ? 100 : 0,
    status: proposedMode == existingMode
        ? BillingChargeFieldStatus.match
        : BillingChargeFieldStatus.different,
  );
  final BillingChargeFieldComparison amount = _amountField(
    input: proposedAmount,
    candidate: existingAmount,
  );

  final List<BillingChargeFieldComparison> fields =
      <BillingChargeFieldComparison>[
        patient,
        itemField,
        encounter,
        mode,
        amount,
      ];
  final int scoredTotal = fields.fold<int>(
    0,
    (int sum, BillingChargeFieldComparison field) => sum + field.score,
  );
  final int score = (scoredTotal / fields.length).round();
  final bool isExact = fields.every(
    (BillingChargeFieldComparison field) => field.score == 100,
  );

  if (!isExact && score < 70) {
    return null;
  }
  return BillingChargeSimilarityMatch(
    item: item,
    score: score,
    fieldComparisons: fields,
    isExact: isExact,
  );
}

String _inferredPaymentMode(BillingWorkItem item) {
  if (item.totalInsurerShare > 0) {
    return 'INSURANCE';
  }
  return 'SELF_PAY';
}

BillingChargeFieldComparison _textField({
  required String field,
  required String input,
  required String candidate,
}) {
  final String left = input.trim().toLowerCase();
  final String right = candidate.trim().toLowerCase();
  if (left.isEmpty && right.isEmpty) {
    return BillingChargeFieldComparison(
      field: field,
      inputValue: input,
      candidateValue: candidate,
      score: 100,
      status: BillingChargeFieldStatus.missing,
    );
  }
  if (left.isEmpty || right.isEmpty) {
    return BillingChargeFieldComparison(
      field: field,
      inputValue: input,
      candidateValue: candidate,
      score: 40,
      status: BillingChargeFieldStatus.missing,
    );
  }
  if (left == right) {
    return BillingChargeFieldComparison(
      field: field,
      inputValue: input,
      candidateValue: candidate,
      score: 100,
      status: BillingChargeFieldStatus.match,
    );
  }
  final int score = _tokenOverlapScore(left, right);
  return BillingChargeFieldComparison(
    field: field,
    inputValue: input,
    candidateValue: candidate,
    score: score,
    status: score >= 70
        ? BillingChargeFieldStatus.similar
        : BillingChargeFieldStatus.different,
  );
}

BillingChargeFieldComparison _encounterField({
  required String input,
  required String candidate,
}) {
  final String left = input.trim().toLowerCase();
  final String right = candidate.trim().toLowerCase();
  if (left.isEmpty && right.isEmpty) {
    return const BillingChargeFieldComparison(
      field: 'encounter',
      inputValue: '',
      candidateValue: '',
      score: 100,
      status: BillingChargeFieldStatus.missing,
    );
  }
  if (left.isEmpty || right.isEmpty) {
    return BillingChargeFieldComparison(
      field: 'encounter',
      inputValue: input,
      candidateValue: candidate,
      score: 80,
      status: BillingChargeFieldStatus.similar,
    );
  }
  if (left == right) {
    return BillingChargeFieldComparison(
      field: 'encounter',
      inputValue: input,
      candidateValue: candidate,
      score: 100,
      status: BillingChargeFieldStatus.match,
    );
  }
  return BillingChargeFieldComparison(
    field: 'encounter',
    inputValue: input,
    candidateValue: candidate,
    score: 0,
    status: BillingChargeFieldStatus.different,
  );
}

BillingChargeFieldComparison _amountField({
  required num input,
  required num candidate,
}) {
  final String inputLabel = input.toString();
  final String candidateLabel = candidate.toString();
  if (input <= 0 && candidate <= 0) {
    return BillingChargeFieldComparison(
      field: 'amount',
      inputValue: inputLabel,
      candidateValue: candidateLabel,
      score: 100,
      status: BillingChargeFieldStatus.match,
    );
  }
  final num baseline = input.abs() > candidate.abs() ? input.abs() : candidate.abs();
  if (baseline == 0) {
    return BillingChargeFieldComparison(
      field: 'amount',
      inputValue: inputLabel,
      candidateValue: candidateLabel,
      score: 0,
      status: BillingChargeFieldStatus.different,
    );
  }
  final num delta = (input - candidate).abs() / baseline;
  if (delta <= 0.01) {
    return BillingChargeFieldComparison(
      field: 'amount',
      inputValue: inputLabel,
      candidateValue: candidateLabel,
      score: 100,
      status: BillingChargeFieldStatus.match,
    );
  }
  if (delta <= 0.10) {
    return BillingChargeFieldComparison(
      field: 'amount',
      inputValue: inputLabel,
      candidateValue: candidateLabel,
      score: 85,
      status: BillingChargeFieldStatus.similar,
    );
  }
  if (delta <= 0.25) {
    return BillingChargeFieldComparison(
      field: 'amount',
      inputValue: inputLabel,
      candidateValue: candidateLabel,
      score: 60,
      status: BillingChargeFieldStatus.similar,
    );
  }
  return BillingChargeFieldComparison(
    field: 'amount',
    inputValue: inputLabel,
    candidateValue: candidateLabel,
    score: 0,
    status: BillingChargeFieldStatus.different,
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

final RegExp _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

String? _publicId(String? value) {
  final String normalized = value?.trim() ?? '';
  if (normalized.isEmpty || _uuidPattern.hasMatch(normalized)) {
    return null;
  }
  return normalized;
}
