import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/claims/domain/entities/claims_entities.dart';
import 'package:hosspi_hms/features/claims/presentation/claims_access.dart';

AppAccessPolicy _policyFor({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
    AppModuleEntitlement(code: 'insurance-claims', licenseStatus: 'ACTIVE'),
    AppModuleEntitlement(code: 'billing-payments', licenseStatus: 'ACTIVE'),
  ],
}) {
  return AppAccessPolicy.fromSession(
    AuthSession(
      tokens: SessionTokens(accessToken: 'token'),
      user: const AuthUserProfile(roles: <String>['BILLING']),
      permissions: permissions,
      moduleEntitlements: modules,
      isAuthorizationHydrated: true,
    ),
  );
}

void main() {
  group('claims access requirements', () {
    test('read requirement needs billing:read ∩ insurance module', () {
      final AppAccessPolicy reader = _policyFor(
        permissions: <AppPermission>{AppPermissions.billingRead},
      );
      final AppAccessPolicy writerOnly = _policyFor(
        permissions: <AppPermission>{AppPermissions.billingWrite},
      );

      expect(claimsWorkspaceReadRequirement.isAllowed(reader), isTrue);
      expect(claimsWorkspaceReadRequirement.isAllowed(writerOnly), isFalse);
      expect(ClaimsAuthorizationsAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(
        ClaimsAuthorizationsAtomPermissions.tab.isAllowed(writerOnly),
        isFalse,
      );
    });

    test('write requirement needs billing:write', () {
      final AppAccessPolicy reader = _policyFor(
        permissions: <AppPermission>{AppPermissions.billingRead},
      );
      final AppAccessPolicy writer = _policyFor(
        permissions: <AppPermission>{
          AppPermissions.billingRead,
          AppPermissions.billingWrite,
        },
      );

      expect(claimsWorkspaceWriteRequirement.isAllowed(reader), isFalse);
      expect(claimsWorkspaceWriteRequirement.isAllowed(writer), isTrue);
      expect(
        ClaimsAuthorizationsAtomPermissions.create.isAllowed(reader),
        isFalse,
      );
      expect(
        ClaimsAuthorizationsAtomPermissions.create.isAllowed(writer),
        isTrue,
      );
    });

    test('financial approve requirement needs financial:approve', () {
      final AppAccessPolicy writer = _policyFor(
        permissions: <AppPermission>{AppPermissions.billingWrite},
      );
      final AppAccessPolicy approver = _policyFor(
        permissions: <AppPermission>{AppPermissions.financialApprove},
      );

      expect(claimsFinancialApproveRequirement.isAllowed(writer), isFalse);
      expect(claimsFinancialApproveRequirement.isAllowed(approver), isTrue);
    });

    test('route entry ∪ allows read, write, or financial:approve', () {
      expect(
        claimsWorkspaceEntryRequirement.isAllowed(
          _policyFor(permissions: <AppPermission>{AppPermissions.billingRead}),
        ),
        isTrue,
      );
      expect(
        claimsWorkspaceEntryRequirement.isAllowed(
          _policyFor(permissions: <AppPermission>{AppPermissions.billingWrite}),
        ),
        isTrue,
      );
      expect(
        claimsWorkspaceEntryRequirement.isAllowed(
          _policyFor(
            permissions: <AppPermission>{AppPermissions.financialApprove},
          ),
        ),
        isTrue,
      );
      expect(
        claimsWorkspaceEntryRequirement.isAllowed(
          _policyFor(permissions: <AppPermission>{AppPermissions.patientRead}),
        ),
        isFalse,
      );
    });

    test('Authorizations next-action column only for writers', () {
      final AppAccessPolicy reader = _policyFor(
        permissions: <AppPermission>{AppPermissions.billingRead},
      );
      final AppAccessPolicy writer = _policyFor(
        permissions: <AppPermission>{
          AppPermissions.billingRead,
          AppPermissions.billingWrite,
        },
      );

      expect(
        claimsSectionShowsNextActionColumn(
          reader,
          ClaimsDeskSection.authorizations,
        ),
        isFalse,
      );
      expect(
        claimsSectionShowsNextActionColumn(
          writer,
          ClaimsDeskSection.authorizations,
        ),
        isTrue,
      );
    });

    test('subscription without insurance-claims strips Authorizations read', () {
      final AppAccessPolicy noInsurance = _policyFor(
        permissions: <AppPermission>{
          AppPermissions.billingRead,
          AppPermissions.billingWrite,
        },
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: 'billing-payments',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );

      expect(canViewClaimsSection(noInsurance, ClaimsDeskSection.authorizations), isFalse);
      expect(ClaimsAuthorizationsAtomPermissions.tab.isAllowed(noInsurance), isFalse);
    });

    test('Active Claims atom map reuses feature *Requirement helpers', () {
      expect(
        identical(
          ClaimsActiveClaimsAtomPermissions.prepare,
          claimsWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ClaimsActiveClaimsAtomPermissions.closeAsPaid,
          claimsFinancialApproveRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ClaimsActiveClaimsAtomPermissions.tab,
          claimsWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ClaimsActiveClaimsAtomPermissions.routeEntry,
          claimsWorkspaceEntryRequirement,
        ),
        isTrue,
      );
    });

    test('Active Claims next-action maps write vs financial approve by status', () {
      const ClaimsQueueItem submitted = ClaimsQueueItem.claim(
        InsuranceClaimRecord(
          id: 'c1',
          displayId: 'CLM-1',
          coveragePlanId: 'plan',
          coveragePlanDisplayId: 'PLAN',
          invoiceId: 'inv',
          invoiceDisplayId: 'INV',
          status: 'SUBMITTED',
        ),
      );
      const ClaimsQueueItem approved = ClaimsQueueItem.claim(
        InsuranceClaimRecord(
          id: 'c2',
          displayId: 'CLM-2',
          coveragePlanId: 'plan',
          coveragePlanDisplayId: 'PLAN',
          invoiceId: 'inv',
          invoiceDisplayId: 'INV',
          status: 'APPROVED',
        ),
      );

      expect(
        identical(
          claimsNextActionRequirement(submitted),
          claimsWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          claimsNextActionRequirement(approved),
          claimsFinancialApproveRequirement,
        ),
        isTrue,
      );
    });

    test('Active Claims next-action column needs write ∪ approve', () {
      final AppAccessPolicy reader = _policyFor(
        permissions: <AppPermission>{AppPermissions.billingRead},
      );
      final AppAccessPolicy writer = _policyFor(
        permissions: <AppPermission>{AppPermissions.billingWrite},
      );
      final AppAccessPolicy approver = _policyFor(
        permissions: <AppPermission>{AppPermissions.financialApprove},
      );

      expect(
        claimsSectionShowsNextActionColumn(
          reader,
          ClaimsDeskSection.activeClaims,
        ),
        isFalse,
      );
      expect(
        claimsSectionShowsNextActionColumn(
          writer,
          ClaimsDeskSection.activeClaims,
        ),
        isTrue,
      );
      expect(
        claimsSectionShowsNextActionColumn(
          approver,
          ClaimsDeskSection.activeClaims,
        ),
        isTrue,
      );
    });

    test('Insurance Setup read ∪ allows facility:admin without billing:read', () {
      final AppAccessPolicy facilityAdmin = _policyFor(
        permissions: <AppPermission>{AppPermissions.facilityAdmin},
      );
      final AppAccessPolicy approveOnly = _policyFor(
        permissions: <AppPermission>{AppPermissions.financialApprove},
      );

      expect(
        ClaimsInsuranceSetupAtomPermissions.tab.isAllowed(facilityAdmin),
        isTrue,
      );
      expect(
        ClaimsInsuranceSetupAtomPermissions.read.isAllowed(facilityAdmin),
        isFalse,
      );
      expect(
        canViewClaimsDeskSection(
          facilityAdmin,
          ClaimsDeskSection.insuranceSetup,
        ),
        isTrue,
      );
      expect(
        ClaimsInsuranceSetupAtomPermissions.tab.isAllowed(approveOnly),
        isFalse,
      );
    });

    test('Insurance Setup atom map reuses feature *Requirement helpers', () {
      expect(
        identical(
          ClaimsInsuranceSetupAtomPermissions.create,
          claimsWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ClaimsInsuranceSetupAtomPermissions.tab,
          claimsInsuranceSetupReadAnyRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ClaimsInsuranceSetupAtomPermissions.routeEntry,
          claimsWorkspaceEntryRequirement,
        ),
        isTrue,
      );
    });

    test('Insurance Setup create ∩ denied without billing:write', () {
      final AppAccessPolicy reader = _policyFor(
        permissions: <AppPermission>{AppPermissions.billingRead},
      );
      final AppAccessPolicy writer = _policyFor(
        permissions: <AppPermission>{
          AppPermissions.billingRead,
          AppPermissions.billingWrite,
        },
      );

      expect(
        ClaimsInsuranceSetupAtomPermissions.create.isAllowed(reader),
        isFalse,
      );
      expect(
        ClaimsInsuranceSetupAtomPermissions.create.isAllowed(writer),
        isTrue,
      );
    });
  });
}
