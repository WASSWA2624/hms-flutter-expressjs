import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_entities.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_scope_navigation.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';

void main() {
  const AccountsSummary summary = AccountsSummary(
    openWork: 10,
    toPost: 4,
    needApproval: 2,
    glActivity: 8,
    ledgersWithBalance: 5,
    chartActive: 20,
    invoices: 1,
  );

  AccountsWorkspaceState stateFor({
    AccountsDeskSection section = AccountsDeskSection.work,
    String search = '',
    String status = '',
    int filteredTotal = 3,
  }) {
    return AccountsWorkspaceState(
      query: AccountsWorkspaceQuery(
        section: section,
        search: search,
        status: status,
      ),
      overview: const AccountsWorkspaceOverview(summary: summary),
      workItems: AppPage<AccountsWorkItem>(
        items: const <AccountsWorkItem>[
          AccountsWorkItem(id: 'a', kind: AccountsWorkItemKind.journal),
          AccountsWorkItem(id: 'b', kind: AccountsWorkItemKind.journal),
          AccountsWorkItem(id: 'c', kind: AccountsWorkItemKind.journal),
        ],
        request: const AppPageRequest(pageSize: 12),
        totalItemCount: filteredTotal,
      ),
    );
  }

  test('sibling badges use summary scope totals', () {
    final AccountsWorkspaceState state = stateFor();
    expect(
      accountsSectionTabCount(state, AccountsDeskSection.work),
      10,
    );
    expect(
      accountsSectionTabCount(state, AccountsDeskSection.journals),
      4,
    );
    expect(
      accountsSectionTabCount(state, AccountsDeskSection.approvals),
      2,
    );
  });

  test('active work-queue badge uses filtered total when narrowed', () {
    final AccountsWorkspaceState state = stateFor(
      section: AccountsDeskSection.work,
      search: 'JE',
      filteredTotal: 3,
    );
    expect(
      accountsSectionTabCount(
        state,
        AccountsDeskSection.work,
        activeSection: AccountsDeskSection.work,
      ),
      3,
    );
    expect(
      accountsSectionTabCount(
        state,
        AccountsDeskSection.journals,
        activeSection: AccountsDeskSection.work,
      ),
      4,
    );
  });

  test('dedicated panels prefer live overrides', () {
    final AccountsWorkspaceState state = stateFor(
      section: AccountsDeskSection.gl,
    );
    expect(
      accountsSectionTabCount(
        state,
        AccountsDeskSection.gl,
        glActivityOverride: 12,
      ),
      12,
    );
    expect(
      accountsSectionTabCount(
        state,
        AccountsDeskSection.chart,
        chartActiveOverride: 7,
      ),
      7,
    );
  });

  test('count tones mark attention queues as warning', () {
    expect(
      accountsSectionCountTone(AccountsDeskSection.journals),
      AppTabCountTone.warning,
    );
    expect(
      accountsSectionCountTone(AccountsDeskSection.approvals),
      AppTabCountTone.warning,
    );
    expect(
      accountsSectionCountTone(AccountsDeskSection.invoices),
      AppTabCountTone.info,
    );
    expect(
      accountsSectionCountTone(AccountsDeskSection.work),
      AppTabCountTone.info,
    );
    expect(
      accountsSectionCountTone(AccountsDeskSection.gl),
      AppTabCountTone.info,
    );
  });
}
