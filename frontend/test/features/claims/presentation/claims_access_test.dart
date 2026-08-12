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

    test('route entry requires claims:read ∩ insurance-claims', () {
      expect(
        claimsWorkspaceEntryRequirement.isAllowed(
          _policyFor(permissions: <AppPermission>{AppPermissions.claimsRead}),
        ),
        isTrue,
      );
      expect(
        claimsWorkspaceEntryRequirement.isAllowed(
          _policyFor(permissions: <AppPermission>{AppPermissions.billingRead}),
        ),
        isFalse,
      );
      expect(
        claimsWorkspaceEntryRequirement.isAllowed(
          _policyFor(permissions: <AppPermission>{AppPermissions.billingWrite}),
        ),
        isFalse,
      );
      expect(
        claimsWorkspaceEntryRequirement.isAllowed(
          _policyFor(
            permissions: <AppPermission>{AppPermissions.financialApprove},
          ),
        ),
        isFalse,
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
        ClaimsAuthorizationsAtomPermissions.nextActionColumn.isAllowed(reader),
        isFalse,
      );
      expect(
        ClaimsAuthorizationsAtomPermissions.nextActionColumn.isAllowed(writer),
        isTrue,
      );
      expect(
        claimsSectionShowsNextActionColumn(
          reader,
          ClaimsDeskSection.authPending,
        ),
        isFalse,
      );
      expect(
        claimsSectionShowsNextActionColumn(
          writer,
          ClaimsDeskSection.authPending,
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

      expect(canViewClaimsSection(noInsurance, ClaimsDeskSection.authPending), isFalse);
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
          ClaimsActiveClaimsAtomPermissions.submit,
          claimsWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ClaimsActiveClaimsAtomPermissions.recordResponse,
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
      expect(
        identical(
          ClaimsActiveClaimsAtomPermissions.entry,
          claimsWorkspaceEntryRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ClaimsActiveClaimsAtomPermissions.nextActionColumn,
          claimsActiveClaimsNextActionColumnRequirement,
        ),
        isTrue,
      );
    });

    test('Active Claims nested cross-module matrix rows are n/a (document = read ∩)', () {
      expect(
        identical(
          ClaimsActiveClaimsAtomPermissions.document,
          claimsWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          claimsDetailPrintRequirement(ClaimsDeskSection.submitted),
          claimsWorkspaceReadRequirement,
        ),
        isTrue,
      );
      // Settled uses export ∪ — Active Claims must not.
      expect(
        identical(
          ClaimsActiveClaimsAtomPermissions.document,
          claimsNestedExportRequirement,
        ),
        isFalse,
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
          ClaimsDeskSection.submitted,
        ),
        isFalse,
      );
      expect(
        ClaimsActiveClaimsAtomPermissions.nextActionColumn.isAllowed(reader),
        isFalse,
      );
      expect(
        claimsSectionShowsNextActionColumn(
          writer,
          ClaimsDeskSection.submitted,
        ),
        isTrue,
      );
      expect(
        claimsSectionShowsNextActionColumn(
          approver,
          ClaimsDeskSection.submitted,
        ),
        isTrue,
      );
      // Union allowance: either write or approve satisfies column chrome.
      expect(
        ClaimsActiveClaimsAtomPermissions.nextActionColumn.isAllowed(writer),
        isTrue,
      );
      expect(
        ClaimsActiveClaimsAtomPermissions.nextActionColumn.isAllowed(approver),
        isTrue,
      );
    });

    test('Insurance Setup read ∪ allows facility/tenant admin without billing:read', () {
      final AppAccessPolicy facilityAdmin = _policyFor(
        permissions: <AppPermission>{AppPermissions.facilityAdmin},
      );
      final AppAccessPolicy tenantAdmin = _policyFor(
        permissions: <AppPermission>{AppPermissions.tenantAdmin},
      );
      final AppAccessPolicy approveOnly = _policyFor(
        permissions: <AppPermission>{AppPermissions.financialApprove},
      );

      expect(
        ClaimsInsuranceSetupAtomPermissions.tab.isAllowed(facilityAdmin),
        isTrue,
      );
      expect(
        ClaimsInsuranceSetupAtomPermissions.tab.isAllowed(tenantAdmin),
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
        canViewClaimsDeskSection(
          tenantAdmin,
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
          ClaimsInsuranceSetupAtomPermissions.addCompany,
          claimsWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ClaimsInsuranceSetupAtomPermissions.addScheme,
          claimsWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ClaimsInsuranceSetupAtomPermissions.addOffer,
          claimsWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ClaimsInsuranceSetupAtomPermissions.enrollPatient,
          claimsWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ClaimsInsuranceSetupAtomPermissions.addPrice,
          claimsWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ClaimsInsuranceSetupAtomPermissions.insurerApi,
          claimsWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ClaimsInsuranceSetupAtomPermissions.update,
          claimsWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ClaimsInsuranceSetupAtomPermissions.delete,
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
        ClaimsInsuranceSetupAtomPermissions.addCompany.isAllowed(reader),
        isFalse,
      );
      expect(
        ClaimsInsuranceSetupAtomPermissions.create.isAllowed(writer),
        isTrue,
      );
      expect(
        ClaimsInsuranceSetupAtomPermissions.insurerApi.isAllowed(writer),
        isTrue,
      );
    });

    test('Settled atom map reuses feature *Requirement helpers', () {
      expect(
        identical(
          ClaimsSettledAtomPermissions.tab,
          claimsWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ClaimsSettledAtomPermissions.listChrome,
          claimsWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ClaimsSettledAtomPermissions.detail,
          claimsWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ClaimsSettledAtomPermissions.export,
          claimsNestedExportRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ClaimsSettledAtomPermissions.document,
          claimsNestedExportRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ClaimsSettledAtomPermissions.nestedRead,
          claimsNestedExportRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ClaimsSettledAtomPermissions.write,
          claimsWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ClaimsSettledAtomPermissions.create,
          claimsWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ClaimsSettledAtomPermissions.update,
          claimsWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ClaimsSettledAtomPermissions.delete,
          claimsWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ClaimsSettledAtomPermissions.approve,
          claimsFinancialApproveRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ClaimsSettledAtomPermissions.routeEntry,
          claimsWorkspaceEntryRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          claimsDetailPrintRequirement(ClaimsDeskSection.settled),
          claimsWorkspacePrintRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ClaimsSettledAtomPermissions.tableExport,
          claimsWorkspaceExportRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          ClaimsSettledAtomPermissions.print,
          claimsWorkspacePrintRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          claimsSettledExportRequirement,
          claimsNestedExportRequirement,
        ),
        isTrue,
      );
    });

    test('Settled nested export ∪ allows reports:read or evidence:export', () {
      final AppAccessPolicy readerOnly = _policyFor(
        permissions: <AppPermission>{AppPermissions.billingRead},
      );
      final AppAccessPolicy withReports = _policyFor(
        permissions: <AppPermission>{
          AppPermissions.billingRead,
          AppPermissions.reportsRead,
        },
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(code: 'insurance-claims', licenseStatus: 'ACTIVE'),
          AppModuleEntitlement(code: 'billing-payments', licenseStatus: 'ACTIVE'),
          AppModuleEntitlement(
            code: 'reporting-analytics',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );
      final AppAccessPolicy reportsWithoutModule = _policyFor(
        permissions: <AppPermission>{
          AppPermissions.billingRead,
          AppPermissions.reportsRead,
        },
      );
      final AppAccessPolicy withEvidence = _policyFor(
        permissions: <AppPermission>{
          AppPermissions.billingRead,
          AppPermissions.evidenceExport,
        },
      );

      // reports:read is injected for every signed-in role (platform infra).
      expect(ClaimsSettledAtomPermissions.export.isAllowed(readerOnly), isTrue);
      expect(ClaimsSettledAtomPermissions.export.isAllowed(withReports), isTrue);
      // Reporting is platform infrastructure — reports:read is not package-gated.
      expect(
        ClaimsSettledAtomPermissions.export.isAllowed(reportsWithoutModule),
        isTrue,
      );
      expect(
        ClaimsSettledAtomPermissions.export.isAllowed(withEvidence),
        isTrue,
      );
      // Settled detail Print uses ∩ evidence:export (not nested ∪ alone).
      // Platform auto-injects reports:read, so nested ∪ would always pass.
      expect(
        claimsDetailPrintRequirement(ClaimsDeskSection.settled).isAllowed(
          readerOnly,
        ),
        isFalse,
      );
      expect(
        claimsDetailPrintRequirement(ClaimsDeskSection.settled).isAllowed(
          withEvidence,
        ),
        isTrue,
      );
      expect(
        claimsDetailPrintRequirement(ClaimsDeskSection.authPending)
            .isAllowed(readerOnly),
        isTrue,
      );
    });

    test('queue Export/Print require ∩ evidence:export', () {
      final AppAccessPolicy readerOnly = _policyFor(
        permissions: <AppPermission>{AppPermissions.billingRead},
      );
      final AppAccessPolicy withEvidence = _policyFor(
        permissions: <AppPermission>{
          AppPermissions.billingRead,
          AppPermissions.evidenceExport,
        },
      );
      final AppAccessPolicy withReportsOnly = _policyFor(
        permissions: <AppPermission>{
          AppPermissions.billingRead,
          AppPermissions.reportsRead,
        },
      );

      expect(canExportClaimsWorkspace(readerOnly), isFalse);
      expect(canPrintClaimsWorkspace(readerOnly), isFalse);
      expect(canExportClaimsWorkspace(withEvidence), isTrue);
      expect(canPrintClaimsWorkspace(withEvidence), isTrue);
      // reports:read alone unlocks Settled detail nested export, not table Export.
      expect(canExportClaimsWorkspace(withReportsOnly), isFalse);
      expect(
        ClaimsAuthorizationsAtomPermissions.export.isAllowed(withEvidence),
        isTrue,
      );
      expect(
        ClaimsActiveClaimsAtomPermissions.print.isAllowed(withEvidence),
        isTrue,
      );
      expect(
        ClaimsSettledAtomPermissions.tableExport.isAllowed(withEvidence),
        isTrue,
      );
      expect(
        ClaimsSettledAtomPermissions.print.isAllowed(readerOnly),
        isFalse,
      );
    });

    test('Settled next-action column never mounts', () {
      final AppAccessPolicy writer = _policyFor(
        permissions: <AppPermission>{
          AppPermissions.billingRead,
          AppPermissions.billingWrite,
          AppPermissions.financialApprove,
        },
      );

      expect(
        claimsSectionShowsNextActionColumn(writer, ClaimsDeskSection.settled),
        isFalse,
      );
    });

    test('Settled tab ∩ denied without billing:read', () {
      final AppAccessPolicy writeOnly = _policyFor(
        permissions: <AppPermission>{AppPermissions.billingWrite},
      );

      expect(ClaimsSettledAtomPermissions.tab.isAllowed(writeOnly), isFalse);
      expect(
        canViewClaimsDeskSection(writeOnly, ClaimsDeskSection.settled),
        isFalse,
      );
    });
  });
}
