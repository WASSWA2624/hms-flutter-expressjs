import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/access_requirement_l10n.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/l10n/app_localizations.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  test('accessRequirementDenialMessage explains missing module', () {
    final AppAccessPolicy policy = AppAccessPolicy.fromSession(
      AuthSession(
        tokens: SessionTokens(accessToken: 'access-token'),
        user: const AuthUserProfile(
          tenantId: 'tenant-1',
          facilityId: 'facility-1',
          roles: <String>['DOCTOR'],
        ),
        moduleEntitlements: const <AppModuleEntitlement>[
          AppModuleEntitlement(code: 'clinical-care', licenseStatus: 'ACTIVE'),
        ],
      ),
    );
    const AccessRequirement requirement = AccessRequirement(
      anyPermissions: <AppPermission>[AppPermissions.clinicalWrite],
      activeModules: <String>['lab'],
    );

    expect(
      accessRequirementDenialMessage(l10n, requirement, policy),
      l10n.accessDeniedModuleRequired(l10n.accessDeniedModuleLabLabel),
    );
  });

  test('accessRequirementDenialMessage explains missing permission', () {
    final AppAccessPolicy policy = AppAccessPolicy.fromSession(
      AuthSession(
        tokens: SessionTokens(accessToken: 'access-token'),
        user: const AuthUserProfile(
          tenantId: 'tenant-1',
          facilityId: 'facility-1',
          roles: <String>['RECEPTIONIST'],
        ),
        moduleEntitlements: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: 'reporting-analytics',
            licenseStatus: 'ACTIVE',
          ),
        ],
      ),
    );
    const AccessRequirement requirement = AccessRequirement(
      allPermissions: <AppPermission>[AppPermissions.reportsRead],
    );

    expect(
      accessRequirementDenialMessage(l10n, requirement, policy),
      l10n.accessDeniedPermissionRequired,
    );
  });

  test('accessRequirementDenialMessage prefers plan module over permission', () {
    final AppAccessPolicy policy = AppAccessPolicy.fromSession(
      AuthSession(
        tokens: SessionTokens(accessToken: 'access-token'),
        user: const AuthUserProfile(
          tenantId: 'tenant-1',
          facilityId: 'facility-1',
          roles: <String>['DOCTOR'],
        ),
        moduleEntitlements: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: 'patient-registry',
            licenseStatus: 'ACTIVE',
          ),
        ],
      ),
    );
    const AccessRequirement requirement = AccessRequirement(
      allPermissions: <AppPermission>[AppPermissions.labRead],
    );

    expect(
      accessRequirementDenialMessage(l10n, requirement, policy),
      l10n.accessDeniedModuleRequired(l10n.accessDeniedModuleLabLabel),
    );
  });
}
