import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_entities.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_books_print_helpers.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_period_similarity.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_support.dart';

void main() {
  group('accounts period similarity', () {
    test('exact label and dates conflict', () {
      final AccountsPeriodSimilarityDraft draft = AccountsPeriodSimilarityDraft(
        label: 'FY2026-Q1',
        startDate: DateTime.utc(2026, 1, 1),
        endDate: DateTime.utc(2026, 3, 31),
      );
      final AccountsFiscalPeriod existing = AccountsFiscalPeriod(
        id: '550e8400-e29b-41d4-a716-446655440030',
        label: 'FY2026-Q1',
        status: 'OPEN',
        startDate: DateTime.utc(2026, 1, 1),
        endDate: DateTime.utc(2026, 3, 31),
      );

      final AccountsPeriodSimilarityResult result =
          checkAccountsPeriodSimilarity(
            draft: draft,
            candidates: <AccountsFiscalPeriod>[existing],
          );

      expect(result.hasExactConflict, isTrue);
      expect(result.hasMatches, isTrue);
      expect(result.matches.first.period.effectiveLabel, 'FY2026-Q1');
      expect(accountsLooksLikeUuid(result.matches.first.period.id), isTrue);
    });

    test('overlapping open period blocks', () {
      final AccountsPeriodSimilarityDraft draft = AccountsPeriodSimilarityDraft(
        label: 'FY2026-H1',
        startDate: DateTime.utc(2026, 2, 1),
        endDate: DateTime.utc(2026, 6, 30),
      );
      final AccountsFiscalPeriod existing = AccountsFiscalPeriod(
        id: 'period-open',
        label: 'FY2026-Q1',
        status: 'OPEN',
        startDate: DateTime.utc(2026, 1, 1),
        endDate: DateTime.utc(2026, 3, 31),
      );

      final AccountsPeriodSimilarityResult result =
          checkAccountsPeriodSimilarity(
            draft: draft,
            candidates: <AccountsFiscalPeriod>[existing],
          );

      expect(result.hasOverlapConflict, isTrue);
      expect(result.hasExactConflict, isFalse);
    });

    test('near label without overlap surfaces review', () {
      final AccountsPeriodSimilarityDraft draft = AccountsPeriodSimilarityDraft(
        label: 'Annual FY2026 Q2',
        startDate: DateTime.utc(2026, 4, 1),
        endDate: DateTime.utc(2026, 6, 30),
      );
      final AccountsFiscalPeriod existing = AccountsFiscalPeriod(
        id: 'period-near',
        label: 'FY2026 Q2 Annual',
        status: 'CLOSED',
        startDate: DateTime.utc(2025, 4, 1),
        endDate: DateTime.utc(2025, 6, 30),
      );

      final AccountsPeriodSimilarityResult result =
          checkAccountsPeriodSimilarity(
            draft: draft,
            candidates: <AccountsFiscalPeriod>[existing],
          );

      expect(result.hasOverlapConflict, isFalse);
      expect(result.hasMatches, isTrue);
      expect(result.matches.first.score, greaterThanOrEqualTo(70));
    });
  });

  group('accounts period UUID scrub', () {
    test('effectiveLabel never returns raw UUID', () {
      final AccountsFiscalPeriod period = AccountsFiscalPeriod(
        id: '550e8400-e29b-41d4-a716-446655440031',
        label: 'FY2026-Q3',
        openedBy: '550e8400-e29b-41d4-a716-446655440032',
        facilityLabel: '550e8400-e29b-41d4-a716-446655440033',
      );

      expect(period.effectiveLabel, 'FY2026-Q3');
      expect(period.byLabel, isEmpty);
      expect(period.publicFacilityLabel, isEmpty);
      expect(accountsLooksLikeUuid(period.effectiveLabel), isFalse);
    });
  });

  group('accounts books print html', () {
    test('omits raw UUIDs from print body', () {
      final AccountsFiscalPeriod period = AccountsFiscalPeriod(
        id: '550e8400-e29b-41d4-a716-446655440034',
        label: 'FY2026-Q4',
        status: 'OPEN',
        unpostedJournalCount: 3,
        pendingApprovalsCount: 1,
        notes: 'Close after payroll',
      );

      final String html = accountsBooksHtml(period);

      expect(html.contains(period.id), isFalse);
      expect(html.contains('FY2026-Q4'), isTrue);
      expect(html.contains('3'), isTrue);
      expect(html.contains('Close after payroll'), isTrue);
    });
  });
}
