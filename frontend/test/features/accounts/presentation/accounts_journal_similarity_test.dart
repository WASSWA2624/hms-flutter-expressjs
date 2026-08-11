import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_entities.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_journal_similarity.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_support.dart';

void main() {
  group('accounts journal similarity', () {
    test('flags near-duplicate drafts by period source accounts amount', () {
      final AccountsJournalDraft draft = AccountsJournalDraft(
        date: DateTime.utc(2026, 8, 1),
        periodLabel: 'Aug 2026',
        source: 'Manual',
        lines: const <AccountsJournalLineDraft>[
          AccountsJournalLineDraft(accountId: '1000', debit: 50),
          AccountsJournalLineDraft(accountId: '2000', credit: 50),
        ],
        notes: 'Rent',
      );
      final AccountsWorkItem twin = AccountsWorkItem(
        id: '550e8400-e29b-41d4-a716-446655440000',
        kind: AccountsWorkItemKind.journal,
        displayId: 'JRN-100',
        periodLabel: 'Aug 2026',
        sourceLabel: 'Manual',
        accountDisplayId: '1000',
        amount: 50,
        status: 'DRAFT',
        canPostFlag: true,
        requestReason: 'Rent',
      );

      final AccountsJournalSimilarityResult result =
          checkAccountsJournalSimilarity(
            draft: draft,
            candidates: <AccountsWorkItem>[twin],
          );

      expect(result.hasMatches, isTrue);
      expect(result.matches.first.item.displayId, 'JRN-100');
      expect(accountsLooksLikeUuid(result.matches.first.item.id), isTrue);
      expect(accountsWorkItemPublicId(result.matches.first.item), 'JRN-100');
    });

    test('ignores posted journals and unrelated drafts', () {
      final AccountsJournalDraft draft = AccountsJournalDraft(
        date: DateTime.utc(2026, 8, 1),
        periodLabel: 'Aug 2026',
        source: 'Manual',
        lines: const <AccountsJournalLineDraft>[
          AccountsJournalLineDraft(accountId: '1000', debit: 50),
          AccountsJournalLineDraft(accountId: '2000', credit: 50),
        ],
      );
      final AccountsWorkItem posted = AccountsWorkItem(
        id: 'posted-1',
        kind: AccountsWorkItemKind.journal,
        displayId: 'JRN-9',
        periodLabel: 'Aug 2026',
        sourceLabel: 'Manual',
        amount: 50,
        status: 'POSTED',
        canPostFlag: false,
      );
      final AccountsWorkItem other = AccountsWorkItem(
        id: 'draft-2',
        kind: AccountsWorkItemKind.journal,
        displayId: 'JRN-8',
        periodLabel: 'Jul 2026',
        sourceLabel: 'Billing',
        amount: 999,
        status: 'DRAFT',
        canPostFlag: true,
      );

      final AccountsJournalSimilarityResult result =
          checkAccountsJournalSimilarity(
            draft: draft,
            candidates: <AccountsWorkItem>[posted, other],
          );

      expect(result.hasMatches, isFalse);
    });

    test('excludes self on journal update similarity', () {
      final AccountsJournalDraft draft = AccountsJournalDraft(
        date: DateTime.utc(2026, 8, 1),
        periodLabel: 'Aug 2026',
        source: 'Manual',
        lines: const <AccountsJournalLineDraft>[
          AccountsJournalLineDraft(accountId: '1000', debit: 50),
          AccountsJournalLineDraft(accountId: '2000', credit: 50),
        ],
        notes: 'Rent',
      );
      final AccountsWorkItem self = AccountsWorkItem(
        id: 'je-self',
        kind: AccountsWorkItemKind.journal,
        displayId: 'JRN-100',
        periodLabel: 'Aug 2026',
        sourceLabel: 'Manual',
        accountDisplayId: '1000',
        amount: 50,
        status: 'DRAFT',
        canPostFlag: true,
        requestReason: 'Rent',
      );
      final AccountsWorkItem twin = AccountsWorkItem(
        id: 'je-other',
        kind: AccountsWorkItemKind.journal,
        displayId: 'JRN-101',
        periodLabel: 'Aug 2026',
        sourceLabel: 'Manual',
        accountDisplayId: '1000',
        amount: 50,
        status: 'DRAFT',
        canPostFlag: true,
        requestReason: 'Rent',
      );

      final AccountsJournalSimilarityResult alone =
          checkAccountsJournalSimilarity(
            draft: draft,
            candidates: <AccountsWorkItem>[self],
            excludeJournalId: 'je-self',
          );
      expect(alone.hasMatches, isFalse);

      final AccountsJournalSimilarityResult withTwin =
          checkAccountsJournalSimilarity(
            draft: draft,
            candidates: <AccountsWorkItem>[self, twin],
            excludeJournalId: 'je-self',
          );
      expect(withTwin.hasMatches, isTrue);
      expect(withTwin.matches.single.item.id, 'je-other');
    });
  });

  group('accounts public identifiers', () {
    test('never returns raw UUID as journal label', () {
      const AccountsWorkItem uuidOnly = AccountsWorkItem(
        id: '550e8400-e29b-41d4-a716-446655440000',
        kind: AccountsWorkItemKind.journal,
        displayId: '550e8400-e29b-41d4-a716-446655440000',
      );
      expect(uuidOnly.effectiveDisplayId, '—');
      expect(uuidOnly.journalNumber, '—');
      expect(accountsWorkItemPublicId(uuidOnly), isNot(contains('-e29b-')));
    });
  });
}
