import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_entities.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_access.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_strings.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_approvals_table_support.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_books_table_support.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_chart_panel.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_gl_table_support.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_ledgers_table_support.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_scope_navigation.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_workspace_table_support.dart';
import 'package:hosspi_hms/shared/components/components.dart';
import 'package:hosspi_hms/shared/data/data.dart';

AppAccessPolicy _policy({required Set<AppPermission> permissions}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'token'),
      user: const AuthUserProfile(
        roles: <String>['ACCOUNTANT'],
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
      ),
      permissions: permissions,
      moduleEntitlements: const <AppModuleEntitlement>[
        AppModuleEntitlement(
          code: 'facility-accounts',
          licenseStatus: 'ACTIVE',
        ),
      ],
      isAuthorizationHydrated: true,
    ),
  );
}

void main() {
  group('Accounts convention gaps — cross-cutting', () {
    test('Print trigger labels resolve to Print', () {
      expect(AccountsStrings.printAction, 'Print');
      expect(AccountsStrings.periodPrintAction, 'Print');
      expect(AccountsStrings.chartPrintAction, 'Print');
      expect(AccountsStrings.filtersLabel, 'Filters');
      expect(AccountsStrings.clearFilters, 'Clear filters');
    });

    test('Export/Print gate is ∩ evidence:export', () {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.accountsRead},
      );
      final AppAccessPolicy exporter = _policy(
        permissions: <AppPermission>{
          AppPermissions.accountsRead,
          AppPermissions.evidenceExport,
        },
      );
      expect(canExportAccountsWorkspace(reader), isFalse);
      expect(canPrintAccountsWorkspace(reader), isFalse);
      expect(canExportAccountsWorkspace(exporter), isTrue);
      expect(canPrintAccountsWorkspace(exporter), isTrue);
      expect(
        AccountsOpenWorkAtomPermissions.export,
        accountsWorkspaceExportRequirement,
      );
      expect(
        AccountsOpenWorkAtomPermissions.print,
        accountsWorkspacePrintRequirement,
      );
    });

    test('count tones: warning queues vs info scopes', () {
      expect(
        accountsSectionCountTone(AccountsDeskSection.journals),
        AppTabCountTone.warning,
      );
      expect(
        accountsSectionCountTone(AccountsDeskSection.approvals),
        AppTabCountTone.warning,
      );
      expect(
        accountsSectionCountTone(AccountsDeskSection.books),
        AppTabCountTone.warning,
      );
      expect(
        accountsSectionCountTone(AccountsDeskSection.work),
        AppTabCountTone.info,
      );
      expect(
        accountsSectionCountTone(AccountsDeskSection.gl),
        AppTabCountTone.info,
      );
      expect(
        accountsSectionCountTone(AccountsDeskSection.ledgers),
        AppTabCountTone.info,
      );
      expect(
        accountsSectionCountTone(AccountsDeskSection.chart),
        AppTabCountTone.info,
      );
    });

    test('sibling counts prefer summary; active work-queue uses filtered total', () {
      const AccountsSummary summary = AccountsSummary(
        openWork: 10,
        toPost: 4,
        needApproval: 3,
        glActivity: 9,
        ledgersWithBalance: 5,
        chartActive: 6,
        openPeriods: 2,
      );
      final AccountsWorkspaceState state = AccountsWorkspaceState(
        query: const AccountsWorkspaceQuery(
          section: AccountsDeskSection.work,
          search: 'JE',
        ),
        overview: const AccountsWorkspaceOverview(summary: summary),
        workItems: const AppPage<AccountsWorkItem>(
          items: <AccountsWorkItem>[],
          request: AppPageRequest(pageSize: 12),
          totalItemCount: 2,
        ),
      );

      expect(
        accountsSectionTabCount(
          state,
          AccountsDeskSection.work,
          activeSection: AccountsDeskSection.work,
        ),
        2,
      );
      expect(
        accountsSectionTabCount(
          state,
          AccountsDeskSection.journals,
          activeSection: AccountsDeskSection.work,
        ),
        4,
      );
      expect(
        accountsSectionTabCount(
          state,
          AccountsDeskSection.gl,
          activeSection: AccountsDeskSection.work,
          glActivityOverride: null,
        ),
        9,
      );
      expect(
        accountsSectionTabCount(
          state,
          AccountsDeskSection.gl,
          activeSection: AccountsDeskSection.gl,
          glActivityOverride: 1,
        ),
        1,
      );
    });

    test('default column sets prefer five', () {
      expect(
        accountsDefaultColumnIds[AccountsDeskSection.work]!.length,
        5,
      );
      expect(
        accountsDefaultColumnIds[AccountsDeskSection.journals]!.length,
        5,
      );
      expect(accountsApprovalsDefaultColumnIds.length, 5);
      expect(accountsGlDefaultColumnIds.length, 5);
      expect(accountsLedgersDefaultColumnIds.length, 5);
      expect(accountsChartDefaultColumnIds.length, 5);
      expect(accountsBooksDefaultColumnIds.length, 5);
    });
  });
}
