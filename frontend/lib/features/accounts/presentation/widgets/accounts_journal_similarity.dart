import 'package:hosspi_hms/features/accounts/domain/entities/accounts_entities.dart';

/// Field comparison for Journal create similarity (accounts.md §18).
enum AccountsJournalFieldStatus { match, similar, different, missing }

final class AccountsJournalFieldComparison {
  const AccountsJournalFieldComparison({
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
  final AccountsJournalFieldStatus status;
}

final class AccountsJournalSimilarityMatch {
  const AccountsJournalSimilarityMatch({
    required this.item,
    required this.score,
    required this.fieldComparisons,
    required this.isExact,
  });

  final AccountsWorkItem item;
  final int score;
  final List<AccountsJournalFieldComparison> fieldComparisons;
  final bool isExact;
}

final class AccountsJournalSimilarityResult {
  const AccountsJournalSimilarityResult({required this.matches});

  final List<AccountsJournalSimilarityMatch> matches;

  bool get hasMatches => matches.isNotEmpty;

  bool get hasExactConflict =>
      matches.any((AccountsJournalSimilarityMatch match) => match.isExact);

  int get closestScore => matches.isEmpty
      ? 0
      : matches
            .map((AccountsJournalSimilarityMatch match) => match.score)
            .reduce((int a, int b) => a > b ? a : b);
}

/// Scores [draft] against near-duplicate draft journals (period · source ·
/// line accounts · amounts) per accounts.md §18.
AccountsJournalSimilarityResult checkAccountsJournalSimilarity({
  required AccountsJournalDraft draft,
  required Iterable<AccountsWorkItem> candidates,
  String? excludeJournalId,
}) {
  final String excludeId = (excludeJournalId ?? '').trim();
  final List<AccountsJournalSimilarityMatch> matches =
      <AccountsJournalSimilarityMatch>[];

  for (final AccountsWorkItem item in candidates) {
    if (!item.isJournal || !item.canPost) {
      continue;
    }
    if (excludeId.isNotEmpty && item.id.trim() == excludeId) {
      continue;
    }
    final AccountsJournalSimilarityMatch? match = _scoreCandidate(draft, item);
    if (match != null && (match.isExact || match.score >= 70)) {
      matches.add(match);
    }
  }

  matches.sort(
    (AccountsJournalSimilarityMatch a, AccountsJournalSimilarityMatch b) =>
        b.score.compareTo(a.score),
  );
  return AccountsJournalSimilarityResult(
    matches: matches.take(5).toList(growable: false),
  );
}

AccountsJournalSimilarityMatch? _scoreCandidate(
  AccountsJournalDraft draft,
  AccountsWorkItem item,
) {
  final String proposedPeriod = (draft.periodLabel ?? draft.periodId ?? '')
      .trim();
  final String existingPeriod = (item.periodLabel ?? item.periodId ?? '')
      .trim();
  final String proposedSource = (draft.source ?? '').trim();
  final String existingSource = item.source.trim();
  final num proposedDebit = draft.lines.fold<num>(
    0,
    (num sum, AccountsJournalLineDraft line) => sum + line.debit,
  );
  final num proposedCredit = draft.lines.fold<num>(
    0,
    (num sum, AccountsJournalLineDraft line) => sum + line.credit,
  );
  final num existingAmount = item.amount;
  final String proposedAccounts = _accountsFingerprint(draft.lines);
  final String existingAccounts = (item.accountDisplayId ?? item.accountId ?? '')
      .trim()
      .toLowerCase();
  final String proposedMemo = (draft.notes ?? '').trim();
  final String existingMemo = (item.requestReason ?? item.reference ?? '')
      .trim();

  final AccountsJournalFieldComparison period = _textField(
    field: 'period',
    input: proposedPeriod,
    candidate: existingPeriod,
  );
  final AccountsJournalFieldComparison source = _textField(
    field: 'source',
    input: proposedSource,
    candidate: existingSource,
  );
  final AccountsJournalFieldComparison accounts = _accountsField(
    input: proposedAccounts,
    candidate: existingAccounts,
  );
  final AccountsJournalFieldComparison amount = _amountField(
    input: proposedDebit > 0 ? proposedDebit : proposedCredit,
    candidate: existingAmount,
  );
  final AccountsJournalFieldComparison memo = _textField(
    field: 'memo',
    input: proposedMemo,
    candidate: existingMemo,
  );

  final List<AccountsJournalFieldComparison> fields =
      <AccountsJournalFieldComparison>[
        period,
        source,
        accounts,
        amount,
        memo,
      ];
  final int scoredTotal = fields.fold<int>(
    0,
    (int sum, AccountsJournalFieldComparison field) => sum + field.score,
  );
  final int score = (scoredTotal / fields.length).round();
  final bool isExact = fields.every(
    (AccountsJournalFieldComparison field) =>
        field.status == AccountsJournalFieldStatus.match &&
        field.inputValue.trim().isNotEmpty,
  );

  if (score < 70 && !isExact) {
    return null;
  }

  return AccountsJournalSimilarityMatch(
    item: item,
    score: isExact ? 100 : score,
    fieldComparisons: fields,
    isExact: isExact,
  );
}

String _accountsFingerprint(List<AccountsJournalLineDraft> lines) {
  final List<String> codes = lines
      .map((AccountsJournalLineDraft line) => line.accountId.trim().toLowerCase())
      .where((String code) => code.isNotEmpty)
      .toList(growable: false)
    ..sort();
  return codes.join('|');
}

AccountsJournalFieldComparison _accountsField({
  required String input,
  required String candidate,
}) {
  if (input.isEmpty && candidate.isEmpty) {
    return const AccountsJournalFieldComparison(
      field: 'accounts',
      inputValue: '',
      candidateValue: '',
      score: 0,
      status: AccountsJournalFieldStatus.missing,
    );
  }
  if (input.isEmpty || candidate.isEmpty) {
    return AccountsJournalFieldComparison(
      field: 'accounts',
      inputValue: input,
      candidateValue: candidate,
      score: 0,
      status: AccountsJournalFieldStatus.missing,
    );
  }
  if (input == candidate || input.split('|').contains(candidate)) {
    return AccountsJournalFieldComparison(
      field: 'accounts',
      inputValue: input.replaceAll('|', ', '),
      candidateValue: candidate,
      score: 100,
      status: AccountsJournalFieldStatus.match,
    );
  }
  final Set<String> inputSet = input.split('|').toSet();
  final Set<String> candidateSet = candidate.contains('|')
      ? candidate.split('|').toSet()
      : <String>{candidate};
  final int overlap = inputSet.intersection(candidateSet).length;
  if (overlap > 0) {
    final int score =
        ((overlap / (inputSet.length > candidateSet.length
                    ? inputSet.length
                    : candidateSet.length)) *
                100)
            .round();
    return AccountsJournalFieldComparison(
      field: 'accounts',
      inputValue: input.replaceAll('|', ', '),
      candidateValue: candidate,
      score: score,
      status: AccountsJournalFieldStatus.similar,
    );
  }
  return AccountsJournalFieldComparison(
    field: 'accounts',
    inputValue: input.replaceAll('|', ', '),
    candidateValue: candidate,
    score: 0,
    status: AccountsJournalFieldStatus.different,
  );
}

AccountsJournalFieldComparison _textField({
  required String field,
  required String input,
  required String candidate,
}) {
  final String a = input.trim().toLowerCase();
  final String b = candidate.trim().toLowerCase();
  if (a.isEmpty && b.isEmpty) {
    return AccountsJournalFieldComparison(
      field: field,
      inputValue: input,
      candidateValue: candidate,
      score: 0,
      status: AccountsJournalFieldStatus.missing,
    );
  }
  if (a.isEmpty || b.isEmpty) {
    return AccountsJournalFieldComparison(
      field: field,
      inputValue: input,
      candidateValue: candidate,
      score: 0,
      status: AccountsJournalFieldStatus.missing,
    );
  }
  if (a == b) {
    return AccountsJournalFieldComparison(
      field: field,
      inputValue: input,
      candidateValue: candidate,
      score: 100,
      status: AccountsJournalFieldStatus.match,
    );
  }
  if (a.contains(b) || b.contains(a)) {
    return AccountsJournalFieldComparison(
      field: field,
      inputValue: input,
      candidateValue: candidate,
      score: 80,
      status: AccountsJournalFieldStatus.similar,
    );
  }
  return AccountsJournalFieldComparison(
    field: field,
    inputValue: input,
    candidateValue: candidate,
    score: 0,
    status: AccountsJournalFieldStatus.different,
  );
}

AccountsJournalFieldComparison _amountField({
  required num input,
  required num candidate,
}) {
  final String inputLabel = input.toString();
  final String candidateLabel = candidate.toString();
  if (input == 0 && candidate == 0) {
    return AccountsJournalFieldComparison(
      field: 'amount',
      inputValue: inputLabel,
      candidateValue: candidateLabel,
      score: 0,
      status: AccountsJournalFieldStatus.missing,
    );
  }
  if (input == candidate) {
    return AccountsJournalFieldComparison(
      field: 'amount',
      inputValue: inputLabel,
      candidateValue: candidateLabel,
      score: 100,
      status: AccountsJournalFieldStatus.match,
    );
  }
  final num delta = (input - candidate).abs();
  final num base = input.abs() > candidate.abs() ? input.abs() : candidate.abs();
  if (base > 0 && delta / base <= 0.05) {
    return AccountsJournalFieldComparison(
      field: 'amount',
      inputValue: inputLabel,
      candidateValue: candidateLabel,
      score: 85,
      status: AccountsJournalFieldStatus.similar,
    );
  }
  return AccountsJournalFieldComparison(
    field: 'amount',
    inputValue: inputLabel,
    candidateValue: candidateLabel,
    score: 0,
    status: AccountsJournalFieldStatus.different,
  );
}
