import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_entities.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_access.dart';
import 'package:hosspi_hms/features/accounts/presentation/accounts_strings.dart';
import 'package:hosspi_hms/features/accounts/presentation/widgets/accounts_ledgers_table_support.dart';

AppAccessPolicy _policy({
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

const AccountsPatientBalance _balanced = AccountsPatientBalance(
  patientId: 'p-1',
  patientDisplayName: 'Ada',
  invoiced: 100,
  paid: 40,
  balance: 60,
);

const AccountsPatientBalance _cleared = AccountsPatientBalance(
  patientId: 'p-2',
  patientDisplayName: 'Ben',
  invoiced: 100,
  paid: 100,
  balance: 0,
  clearance: AccountsClearanceState.cleared,
);

void main() {
  group('Patient ledgers permissions', () {
    test('tab requires accounts read ∩ facility-accounts', () {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.accountsRead},
      );
      final AppAccessPolicy noModule = _policy(
        permissions: <AppPermission>{AppPermissions.accountsRead},
        modules: const <AppModuleEntitlement>[],
      );
      expect(canViewAccountsSection(reader, AccountsDeskSection.ledgers), isTrue);
      expect(
        canViewAccountsSection(noModule, AccountsDeskSection.ledgers),
        isFalse,
      );
    });

    test('Pay absent without billing write ∩ billing-payments', () {
      final AppAccessPolicy accountsOnly = _policy(
        permissions: <AppPermission>{AppPermissions.accountsRead},
      );
      expect(
        accountsPatientLedgerNextActionLabel(
          policy: accountsOnly,
          row: _balanced,
        ),
        AccountsStrings.ledgerAction,
      );
      expect(canPayFromAccounts(accountsOnly), isFalse);
    });

    test('Pay present with billing write ∩ billing-payments when balance', () {
      final AppAccessPolicy both = _policy(
        permissions: <AppPermission>{
          AppPermissions.accountsRead,
          AppPermissions.billingWrite,
        },
      );
      expect(
        accountsPatientLedgerNextActionLabel(policy: both, row: _balanced),
        AccountsStrings.payAction,
      );
      expect(
        accountsPatientLedgerNextActionLabel(policy: both, row: _cleared),
        AccountsStrings.ledgerAction,
      );
    });

    test('Ledger present with accounts:read', () {
      final AppAccessPolicy reader = _policy(
        permissions: <AppPermission>{AppPermissions.accountsRead},
      );
      expect(accountsPatientLedgerShowsLedger(reader), isTrue);
      expect(accountsLedgersShowsNextActionColumn(reader), isTrue);
    });

    test('patient-ledgers alias resolves to ledgers', () {
      expect(
        AccountsDeskSection.resolveDeskSlug('patient-ledgers'),
        AccountsDeskSection.ledgers,
      );
      expect(
        AccountsDeskSection.resolveDeskSlug('ledgers')?.sectionQueryValue,
        'ledgers',
      );
    });

    test('settings key is accounts_ledgers_v1', () {
      expect(accountsLedgersTableSettingsKey, 'accounts_ledgers_v1');
    });
  });
}
