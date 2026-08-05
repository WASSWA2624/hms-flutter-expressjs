import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';

AppAccessPolicy _policyFor({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
    AppModuleEntitlement(code: 'billing-payments', licenseStatus: 'ACTIVE'),
  ],
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'token'),
      user: const AuthUserProfile(
        roles: <String>['BILLING'],
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
  test('analytics readable with billing:read and billing-payments', () {
    final AppAccessPolicy allowed = _policyFor(
      permissions: <AppPermission>{AppPermissions.billingRead},
    );
    expect(canReadBillingAnalytics(allowed), isTrue);
    expect(canViewBillingAnalyticsCharts(allowed), isFalse);

    final AppAccessPolicy withReports = _policyFor(
      permissions: <AppPermission>{
        AppPermissions.billingRead,
        AppPermissions.reportsRead,
      },
      modules: const <AppModuleEntitlement>[
        AppModuleEntitlement(code: 'billing-payments', licenseStatus: 'ACTIVE'),
        AppModuleEntitlement(
          code: 'reporting-analytics',
          licenseStatus: 'ACTIVE',
        ),
      ],
    );
    expect(canViewBillingAnalyticsCharts(withReports), isTrue);
    expect(canOpenBillingReportsAnalytics(withReports), isTrue);
  });

  test('analytics absent without billing read', () {
    final AppAccessPolicy denied = _policyFor(
      permissions: <AppPermission>{AppPermissions.reportsRead},
      modules: const <AppModuleEntitlement>[
        AppModuleEntitlement(code: 'billing-payments', licenseStatus: 'ACTIVE'),
        AppModuleEntitlement(
          code: 'reporting-analytics',
          licenseStatus: 'ACTIVE',
        ),
      ],
    );
    expect(canReadBillingAnalytics(denied), isFalse);
    expect(canViewBillingAnalyticsCharts(denied), isFalse);
  });
}
