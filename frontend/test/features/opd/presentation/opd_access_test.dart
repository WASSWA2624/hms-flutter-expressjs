import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/opd/presentation/opd_access.dart';

void main() {
  group('OPD workspace export/print access', () {
    AppAccessPolicy policyFor({
      required Set<AppPermission> permissions,
      List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
        AppModuleEntitlement(code: 'scheduling-queue', licenseStatus: 'ACTIVE'),
      ],
    }) {
      return AppAccessPolicy.fromSession(
        AuthSession(
          tokens: SessionTokens(accessToken: 'access-token'),
          user: const AuthUserProfile(roles: <String>['CUSTOM']),
          permissions: permissions,
          moduleEntitlements: modules,
          isAuthorizationHydrated: true,
        ),
      );
    }

    test('allows export/print when evidence:export is granted', () {
      final AppAccessPolicy policy = policyFor(
        permissions: <AppPermission>{
          AppPermissions.patientRead,
          AppPermissions.clinicalRead,
          AppPermissions.evidenceExport,
        },
      );
      expect(canExportOpdWorkspace(policy), isTrue);
      expect(canPrintOpdWorkspace(policy), isTrue);
      expect(OpdAllAtomPermissions.export.isAllowed(policy), isTrue);
      expect(OpdAllAtomPermissions.print.isAllowed(policy), isTrue);
      expect(OpdArrivalsAtomPermissions.export.isAllowed(policy), isTrue);
      expect(OpdQueueAtomPermissions.print.isAllowed(policy), isTrue);
      expect(OpdTriageAtomPermissions.export.isAllowed(policy), isTrue);
      expect(OpdActiveAtomPermissions.print.isAllowed(policy), isTrue);
    });

    test('denies export/print without evidence:export', () {
      final AppAccessPolicy policy = policyFor(
        permissions: <AppPermission>{
          AppPermissions.patientRead,
          AppPermissions.clinicalRead,
          AppPermissions.clinicalWrite,
        },
      );
      expect(canExportOpdWorkspace(policy), isFalse);
      expect(canPrintOpdWorkspace(policy), isFalse);
    });
  });
}
