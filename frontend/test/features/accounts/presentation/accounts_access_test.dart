import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/route_access_catalog.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_entities.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_access.dart';

AppAccessPolicy _policyFor({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
    AppModuleEntitlement(code: 'facility-accounts', licenseStatus: 'ACTIVE'),
    AppModuleEntitlement(code: 'billing-payments', licenseStatus: 'ACTIVE'),
  ],
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'token'),
      user: const AuthUserProfile(
        roles: <String>['ACCOUNTANT'],
        tenantId: 'tenant-1',
        facilityId: 'facility-1',
      ),
      permissions: permissions,
      moduleEntitlements: modules,
      isAuthorizationHydrated: true,
    ),
  );
}

void main() {
  group('accounts access requirements', () {
    test('read requirement needs accounts:read ∩ facility-accounts', () {
      final AppAccessPolicy reader = _policyFor(
        permissions: <AppPermission>{AppPermissions.accountsRead},
      );
      final AppAccessPolicy writerOnly = _policyFor(
        permissions: <AppPermission>{AppPermissions.accountsWrite},
      );
      final AppAccessPolicy noModule = _policyFor(
        permissions: <AppPermission>{AppPermissions.accountsRead},
        modules: const <AppModuleEntitlement>[],
      );

      expect(accountsWorkspaceReadRequirement.isAllowed(reader), isTrue);
      expect(accountsWorkspaceReadRequirement.isAllowed(writerOnly), isFalse);
      expect(accountsWorkspaceReadRequirement.isAllowed(noModule), isFalse);
    });

    test('write requirement needs accounts:write ∩ facility-accounts', () {
      final AppAccessPolicy reader = _policyFor(
        permissions: <AppPermission>{AppPermissions.accountsRead},
      );
      final AppAccessPolicy writer = _policyFor(
        permissions: <AppPermission>{
          AppPermissions.accountsRead,
          AppPermissions.accountsWrite,
        },
      );

      expect(accountsWorkspaceWriteRequirement.isAllowed(reader), isFalse);
      expect(accountsWorkspaceWriteRequirement.isAllowed(writer), isTrue);
      expect(canWriteAccounts(writer), isTrue);
      expect(canWriteAccounts(reader), isFalse);
    });

    test(
      'approval decision requires accounts:write ∩ financial:approve',
      () {
        final AppAccessPolicy writer = _policyFor(
          permissions: <AppPermission>{
            AppPermissions.accountsRead,
            AppPermissions.accountsWrite,
          },
        );
        final AppAccessPolicy approveOnly = _policyFor(
          permissions: <AppPermission>{
            AppPermissions.accountsRead,
            AppPermissions.financialApprove,
          },
        );
        final AppAccessPolicy both = _policyFor(
          permissions: <AppPermission>{
            AppPermissions.accountsRead,
            AppPermissions.accountsWrite,
            AppPermissions.financialApprove,
          },
        );
        final AppAccessPolicy bothNoBillingModule = _policyFor(
          permissions: <AppPermission>{
            AppPermissions.accountsRead,
            AppPermissions.accountsWrite,
            AppPermissions.financialApprove,
          },
          modules: const <AppModuleEntitlement>[
            AppModuleEntitlement(
              code: 'facility-accounts',
              licenseStatus: 'ACTIVE',
            ),
          ],
        );

        expect(accountsApprovalDecisionRequirement.isAllowed(writer), isFalse);
        expect(
          accountsApprovalDecisionRequirement.isAllowed(approveOnly),
          isFalse,
        );
        expect(accountsApprovalDecisionRequirement.isAllowed(both), isTrue);
        expect(
          accountsApprovalDecisionRequirement.isAllowed(bothNoBillingModule),
          isFalse,
        );
        expect(canApproveAccountsMutations(both), isTrue);
        expect(canApproveAccounts(both), isTrue);
      },
    );

    test('route entry ∪ allows accounts:read or accounts:write', () {
      final AppAccessPolicy reader = _policyFor(
        permissions: <AppPermission>{AppPermissions.accountsRead},
      );
      final AppAccessPolicy writer = _policyFor(
        permissions: <AppPermission>{AppPermissions.accountsWrite},
      );
      final AppAccessPolicy neither = _policyFor(
        permissions: <AppPermission>{AppPermissions.hrRead},
      );

      expect(accountsWorkspaceEntryRequirement.isAllowed(reader), isTrue);
      expect(accountsWorkspaceEntryRequirement.isAllowed(writer), isTrue);
      expect(accountsWorkspaceEntryRequirement.isAllowed(neither), isFalse);
      expect(
        identical(
          accountsWorkspaceEntryRequirement,
          RouteAccessCatalog.accountsEntry,
        ),
        isTrue,
      );
      expect(canEnterAccountsWorkspace(reader), isTrue);
    });

    test('hr:* alone cannot enter Accounts', () {
      final AppAccessPolicy hr = _policyFor(
        permissions: <AppPermission>{
          AppPermissions.hrRead,
          AppPermissions.hrWrite,
        },
      );
      expect(canEnterAccounts(hr), isFalse);
      expect(canReadAccounts(hr), isFalse);
      expect(canWriteAccounts(hr), isFalse);
    });

    test('missing facility-accounts strips route even with keys', () {
      final AppAccessPolicy noModule = _policyFor(
        permissions: <AppPermission>{
          AppPermissions.accountsRead,
          AppPermissions.accountsWrite,
          AppPermissions.financialApprove,
        },
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: 'billing-payments',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );

      expect(canEnterAccounts(noModule), isFalse);
      expect(canWriteAccounts(noModule), isFalse);
      expect(canApproveAccountsMutations(noModule), isFalse);
      expect(
        canViewAccountsSection(noModule, AccountsDeskSection.work),
        isFalse,
      );
    });

    test('patient ledgers read uses accounts:read ∩ facility-accounts', () {
      final AppAccessPolicy reader = _policyFor(
        permissions: <AppPermission>{AppPermissions.accountsRead},
      );
      final AppAccessPolicy writerOnly = _policyFor(
        permissions: <AppPermission>{AppPermissions.accountsWrite},
      );

      expect(canReadAccountsPatientLedgers(reader), isTrue);
      expect(canReadAccountsPatientLedgers(writerOnly), isFalse);
      expect(
        canViewAccountsSection(reader, AccountsDeskSection.ledgers),
        isTrue,
      );
    });

    test('Pay requires billing:write ∩ billing-payments; omit otherwise', () {
      final AppAccessPolicy accountsOnly = _policyFor(
        permissions: <AppPermission>{
          AppPermissions.accountsRead,
          AppPermissions.accountsWrite,
        },
      );
      final AppAccessPolicy withBillingWrite = _policyFor(
        permissions: <AppPermission>{
          AppPermissions.accountsRead,
          AppPermissions.billingWrite,
        },
      );
      final AppAccessPolicy billingWriteNoModule = _policyFor(
        permissions: <AppPermission>{
          AppPermissions.accountsRead,
          AppPermissions.billingWrite,
        },
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: 'facility-accounts',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );

      expect(canPayFromAccounts(accountsOnly), isFalse);
      expect(accountsPatientLedgerShowsPay(accountsOnly), isFalse);
      expect(canPayFromAccounts(withBillingWrite), isTrue);
      expect(canPayFromAccounts(billingWriteNoModule), isFalse);
      expect(
        identical(
          AccountsPatientLedgersAtomPermissions.pay,
          accountsPayDeepLinkRequirement,
        ),
        isTrue,
      );
    });

    test('billing cashier keys do not grant Accounts entry', () {
      final AppAccessPolicy billing = _policyFor(
        permissions: <AppPermission>{
          AppPermissions.billingRead,
          AppPermissions.billingWrite,
        },
      );
      expect(canEnterAccounts(billing), isFalse);
      expect(canWriteAccounts(billing), isFalse);
    });

    test('fallback section is Open work when entitled', () {
      final AppAccessPolicy reader = _policyFor(
        permissions: <AppPermission>{AppPermissions.accountsRead},
      );
      expect(resolveAccountsSection(reader), AccountsDeskSection.work);
    });

    test('chart write accepts accounts write or admin write', () {
      final AppAccessPolicy writer = _policyFor(
        permissions: <AppPermission>{AppPermissions.accountsWrite},
      );
      final AppAccessPolicy facilityAdmin = _policyFor(
        permissions: <AppPermission>{AppPermissions.facilityAdmin},
      );
      final AppAccessPolicy reader = _policyFor(
        permissions: <AppPermission>{AppPermissions.accountsRead},
      );

      expect(canWriteAccountsChart(writer), isTrue);
      expect(canWriteAccountsChart(facilityAdmin), isTrue);
      expect(canWriteAccountsChart(reader), isFalse);
    });

    test('atom maps reuse shared *Requirement helpers', () {
      expect(
        identical(
          AccountsOpenWorkAtomPermissions.write,
          accountsWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          AccountsNeedApprovalAtomPermissions.approve,
          accountsApprovalDecisionRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          AccountsToPostAtomPermissions.postAll,
          accountsWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          AccountsCloseBooksAtomPermissions.openPeriod,
          accountsWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          AccountsChartAtomPermissions.create,
          accountsChartWriteRequirement,
        ),
        isTrue,
      );
    });

    test('unauthorized write/approve atoms stay gated off', () {
      final AppAccessPolicy reader = _policyFor(
        permissions: <AppPermission>{AppPermissions.accountsRead},
      );

      expect(AccountsOpenWorkAtomPermissions.journal.isAllowed(reader), isFalse);
      expect(AccountsOpenWorkAtomPermissions.approve.isAllowed(reader), isFalse);
      expect(AccountsToPostAtomPermissions.post.isAllowed(reader), isFalse);
      expect(
        AccountsNeedApprovalAtomPermissions.reject.isAllowed(reader),
        isFalse,
      );
      expect(
        AccountsCloseBooksAtomPermissions.closePeriod.isAllowed(reader),
        isFalse,
      );
      expect(AccountsChartAtomPermissions.update.isAllowed(reader), isFalse);
      expect(AccountsPatientLedgersAtomPermissions.pay.isAllowed(reader), isFalse);
      expect(
        AccountsPatientLedgersAtomPermissions.ledger.isAllowed(reader),
        isTrue,
      );
    });
  });

  group('role-derived Accounts access (02-roles)', () {
    AppAccessPolicy rolePolicy({
      required List<String> roles,
      List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
        AppModuleEntitlement(code: 'facility-accounts', licenseStatus: 'ACTIVE'),
        AppModuleEntitlement(code: 'billing-payments', licenseStatus: 'ACTIVE'),
      ],
    }) {
      // JWT-only restore expands client role packs (not hydrated).
      return AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'token'),
          user: AuthUserProfile(
            roles: roles,
            tenantId: 'tenant-1',
            facilityId: 'facility-1',
          ),
          moduleEntitlements: modules,
        ),
      );
    }

    test('ACCOUNTANT pack enters Accounts with write and approve', () {
      final AppAccessPolicy accountant = rolePolicy(
        roles: const <String>['ACCOUNTANT'],
      );

      expect(canEnterAccounts(accountant), isTrue);
      expect(canWriteAccounts(accountant), isTrue);
      expect(canApproveAccountsMutations(accountant), isTrue);
      expect(canPayFromAccounts(accountant), isTrue);
    });

    test('FACILITY_ADMIN pack enters Accounts', () {
      final AppAccessPolicy admin = rolePolicy(
        roles: const <String>['FACILITY_ADMIN'],
      );

      expect(canEnterAccounts(admin), isTrue);
      expect(canWriteAccounts(admin), isTrue);
      expect(canWriteAccountsChart(admin), isTrue);
    });

    test('HR and HR_STAFF packs cannot enter Accounts', () {
      expect(
        canEnterAccounts(rolePolicy(roles: const <String>['HR'])),
        isFalse,
      );
      expect(
        canEnterAccounts(rolePolicy(roles: const <String>['HR_STAFF'])),
        isFalse,
      );
    });

    test('BILLING pack does not gain Accounts from cashier rights', () {
      expect(
        canEnterAccounts(rolePolicy(roles: const <String>['BILLING'])),
        isFalse,
      );
    });

    test('missing facility-accounts blocks ACCOUNTANT even with pack keys', () {
      final AppAccessPolicy accountant = rolePolicy(
        roles: const <String>['ACCOUNTANT'],
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: 'billing-payments',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );

      expect(canEnterAccounts(accountant), isFalse);
      expect(canWriteAccounts(accountant), isFalse);
    });

    test('custom role with only accounts keys can enter when entitled', () {
      final AppAccessPolicy custom = _policyFor(
        permissions: <AppPermission>{
          AppPermissions.accountsRead,
          AppPermissions.accountsWrite,
        },
      );

      expect(canEnterAccounts(custom), isTrue);
      expect(canWriteAccounts(custom), isTrue);
    });
  });
}
