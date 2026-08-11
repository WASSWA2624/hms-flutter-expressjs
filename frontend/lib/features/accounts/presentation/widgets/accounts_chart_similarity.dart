import 'package:hosspi_hms/features/accounts/domain/entities/accounts_chart_account.dart';

/// Field comparison for Account chart similarity (accounts.md §18).
enum AccountsChartFieldStatus { match, similar, different, missing }

final class AccountsChartFieldComparison {
  const AccountsChartFieldComparison({
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
  final AccountsChartFieldStatus status;
}

final class AccountsChartSimilarityDraft {
  const AccountsChartSimilarityDraft({
    required this.code,
    required this.name,
    required this.accountType,
    this.parentId,
    this.parentLabel = '',
  });

  final String code;
  final String name;
  final String accountType;
  final String? parentId;
  final String parentLabel;
}

final class AccountsChartSimilarityMatch {
  const AccountsChartSimilarityMatch({
    required this.account,
    required this.score,
    required this.fieldComparisons,
    required this.isExact,
    required this.isExactCode,
  });

  final AccountsChartAccount account;
  final int score;
  final List<AccountsChartFieldComparison> fieldComparisons;
  final bool isExact;
  final bool isExactCode;
}

final class AccountsChartSimilarityResult {
  const AccountsChartSimilarityResult({required this.matches});

  final List<AccountsChartSimilarityMatch> matches;

  bool get hasMatches => matches.isNotEmpty;

  bool get hasExactCodeConflict =>
      matches.any((AccountsChartSimilarityMatch match) => match.isExactCode);

  bool get hasExactConflict =>
      matches.any((AccountsChartSimilarityMatch match) => match.isExact);

  int get closestScore => matches.isEmpty
      ? 0
      : matches
            .map((AccountsChartSimilarityMatch match) => match.score)
            .reduce((int a, int b) => a > b ? a : b);
}

/// Scores Code · Name · Type · Parent against existing chart rows.
AccountsChartSimilarityResult checkAccountsChartSimilarity({
  required AccountsChartSimilarityDraft draft,
  required Iterable<AccountsChartAccount> candidates,
  String? excludeAccountId,
}) {
  final String excludeId = (excludeAccountId ?? '').trim();
  final List<AccountsChartSimilarityMatch> matches =
      <AccountsChartSimilarityMatch>[];

  for (final AccountsChartAccount account in candidates) {
    if (excludeId.isNotEmpty && account.id.trim() == excludeId) {
      continue;
    }
    final AccountsChartSimilarityMatch? match = _scoreCandidate(draft, account);
    if (match != null &&
        (match.isExact || match.isExactCode || match.score >= 70)) {
      matches.add(match);
    }
  }

  matches.sort(
    (AccountsChartSimilarityMatch a, AccountsChartSimilarityMatch b) =>
        b.score.compareTo(a.score),
  );
  return AccountsChartSimilarityResult(
    matches: matches.take(5).toList(growable: false),
  );
}

AccountsChartSimilarityMatch? _scoreCandidate(
  AccountsChartSimilarityDraft draft,
  AccountsChartAccount account,
) {
  final AccountsChartFieldComparison code = _textField(
    field: 'code',
    input: draft.code,
    candidate: account.code,
  );
  final AccountsChartFieldComparison name = _textField(
    field: 'name',
    input: draft.name,
    candidate: account.name,
  );
  final AccountsChartFieldComparison type = _textField(
    field: 'type',
    input: draft.accountType,
    candidate: account.accountType,
  );
  final AccountsChartFieldComparison parent = _textField(
    field: 'parent',
    input: draft.parentLabel.isNotEmpty
        ? draft.parentLabel
        : (draft.parentId ?? ''),
    candidate: account.parentLabel.isNotEmpty
        ? account.parentLabel
        : (account.parentId ?? ''),
  );

  final List<AccountsChartFieldComparison> fields =
      <AccountsChartFieldComparison>[code, name, type, parent];
  final int score =
      (fields.fold<int>(
                0,
                (int sum, AccountsChartFieldComparison field) =>
                    sum + field.score,
              ) /
              fields.length)
          .round();
  final bool isExactCode = code.status == AccountsChartFieldStatus.match &&
      code.inputValue.trim().isNotEmpty;
  final bool isExact = fields.every(
    (AccountsChartFieldComparison field) =>
        field.status == AccountsChartFieldStatus.match &&
        field.inputValue.trim().isNotEmpty,
  );
  final bool nearNameOrCode =
      code.status == AccountsChartFieldStatus.match ||
      code.status == AccountsChartFieldStatus.similar ||
      name.status == AccountsChartFieldStatus.match ||
      name.status == AccountsChartFieldStatus.similar;

  if (!isExact && !isExactCode && !nearNameOrCode && score < 70) {
    return null;
  }
  return AccountsChartSimilarityMatch(
    account: account,
    score: isExact
        ? 100
        : (nearNameOrCode && score < 70 ? 70 : score),
    fieldComparisons: fields,
    isExact: isExact,
    isExactCode: isExactCode,
  );
}

AccountsChartFieldComparison _textField({
  required String field,
  required String input,
  required String candidate,
}) {
  final String left = input.trim().toLowerCase();
  final String right = candidate.trim().toLowerCase();
  if (left.isEmpty && right.isEmpty) {
    return AccountsChartFieldComparison(
      field: field,
      inputValue: input,
      candidateValue: candidate,
      score: 0,
      status: AccountsChartFieldStatus.missing,
    );
  }
  if (left.isEmpty || right.isEmpty) {
    return AccountsChartFieldComparison(
      field: field,
      inputValue: input,
      candidateValue: candidate,
      score: 0,
      status: AccountsChartFieldStatus.missing,
    );
  }
  if (left == right) {
    return AccountsChartFieldComparison(
      field: field,
      inputValue: input,
      candidateValue: candidate,
      score: 100,
      status: AccountsChartFieldStatus.match,
    );
  }
  final int score = _tokenOverlapScore(left, right);
  return AccountsChartFieldComparison(
    field: field,
    inputValue: input,
    candidateValue: candidate,
    score: score,
    status: score >= 70
        ? AccountsChartFieldStatus.similar
        : AccountsChartFieldStatus.different,
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
