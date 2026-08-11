import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_chart_account.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_chart_print_helpers.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_chart_similarity.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_support.dart';

AccountsChartAccount _account({
  required String id,
  required String code,
  required String name,
  String accountType = 'ASSET',
  String? parentId,
  String? parentName,
  String? parentCode,
  String currency = 'UGX',
  bool isActive = true,
}) {
  return AccountsChartAccount(
    id: id,
    code: code,
    name: name,
    accountType: accountType,
    currency: currency,
    isActive: isActive,
    parentId: parentId,
    parentName: parentName,
    parentCode: parentCode,
  );
}

void main() {
  group('accounts chart similarity', () {
    test('exact code conflict blocks create candidates', () {
      final AccountsChartSimilarityDraft draft = AccountsChartSimilarityDraft(
        code: '1000',
        name: 'Cash drawer',
        accountType: 'ASSET',
      );
      final AccountsChartAccount existing = _account(
        id: '550e8400-e29b-41d4-a716-446655440001',
        code: '1000',
        name: 'Cash on hand',
      );

      final AccountsChartSimilarityResult result =
          checkAccountsChartSimilarity(
            draft: draft,
            candidates: <AccountsChartAccount>[existing],
          );

      expect(result.hasExactCodeConflict, isTrue);
      expect(result.hasMatches, isTrue);
      expect(result.matches.first.account.code, '1000');
      expect(accountsLooksLikeUuid(result.matches.first.account.id), isTrue);
      expect(result.matches.first.account.accountLabel, 'Cash on hand');
    });

    test('near name match surfaces without exact code', () {
      final AccountsChartSimilarityDraft draft = AccountsChartSimilarityDraft(
        code: '1100',
        name: 'Cash on hand account',
        accountType: 'ASSET',
      );
      final AccountsChartAccount existing = _account(
        id: 'acc-2',
        code: '1000',
        name: 'Cash on hand',
      );

      final AccountsChartSimilarityResult result =
          checkAccountsChartSimilarity(
            draft: draft,
            candidates: <AccountsChartAccount>[existing],
          );

      expect(result.hasExactCodeConflict, isFalse);
      expect(result.hasMatches, isTrue);
      expect(result.matches.first.score, greaterThanOrEqualTo(70));
    });

    test('excludeAccountId skips the row being edited', () {
      final AccountsChartSimilarityDraft draft = AccountsChartSimilarityDraft(
        code: '1000',
        name: 'Cash on hand',
        accountType: 'ASSET',
      );
      final AccountsChartAccount self = _account(
        id: 'self-1',
        code: '1000',
        name: 'Cash on hand',
      );

      final AccountsChartSimilarityResult result =
          checkAccountsChartSimilarity(
            draft: draft,
            candidates: <AccountsChartAccount>[self],
            excludeAccountId: 'self-1',
          );

      expect(result.hasMatches, isFalse);
    });
  });

  group('accounts chart UUID scrub', () {
    test('accountLabel and effectiveId never return raw UUIDs', () {
      final AccountsChartAccount account = _account(
        id: '550e8400-e29b-41d4-a716-446655440099',
        code: '2000',
        name: 'Accounts payable',
        parentId: '550e8400-e29b-41d4-a716-446655440098',
      );

      expect(accountsLooksLikeUuid(account.id), isTrue);
      expect(account.accountLabel, 'Accounts payable');
      expect(account.effectiveId, '2000');
      expect(account.parentLabel, isEmpty);
      expect(accountsLooksLikeUuid(account.accountLabel), isFalse);
      expect(accountsLooksLikeUuid(account.effectiveId), isFalse);
    });
  });

  group('accounts chart print html', () {
    test('print html omits raw UUIDs', () {
      final AccountsChartAccount account = _account(
        id: '550e8400-e29b-41d4-a716-446655440010',
        code: '3000',
        name: 'Equity',
        accountType: 'EQUITY',
        parentId: '550e8400-e29b-41d4-a716-446655440011',
      );

      final String html = accountsChartListHtml(
        accounts: <AccountsChartAccount>[account],
      );

      expect(html.contains(account.id), isFalse);
      expect(html.contains('Equity'), isTrue);
      expect(html.contains('3000'), isTrue);
    });
  });
}
