import 'package:flutter_test/flutter_test.dart';
import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/security/auth_session.dart';
import 'package:hosspi_hms/core/security/session_tokens.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_entities.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';

AppAccessPolicy _policyFor({
  required Set<AppPermission> permissions,
  List<AppModuleEntitlement> modules = const <AppModuleEntitlement>[
    AppModuleEntitlement(code: 'billing-payments', licenseStatus: 'ACTIVE'),
    AppModuleEntitlement(code: 'insurance-claims', licenseStatus: 'ACTIVE'),
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
  group('billing access requirements', () {
    test('read requirement needs billing:read ∩ billing-payments', () {
      final AppAccessPolicy reader = _policyFor(
        permissions: <AppPermission>{AppPermissions.billingRead},
      );
      final AppAccessPolicy writerOnly = _policyFor(
        permissions: <AppPermission>{AppPermissions.billingWrite},
      );
      final AppAccessPolicy noModule = _policyFor(
        permissions: <AppPermission>{AppPermissions.billingRead},
        modules: const <AppModuleEntitlement>[],
      );

      expect(billingWorkspaceReadRequirement.isAllowed(reader), isTrue);
      expect(billingWorkspaceReadRequirement.isAllowed(writerOnly), isFalse);
      expect(billingWorkspaceReadRequirement.isAllowed(noModule), isFalse);
    });

    test('write requirement needs billing:write ∩ billing-payments', () {
      final AppAccessPolicy reader = _policyFor(
        permissions: <AppPermission>{AppPermissions.billingRead},
      );
      final AppAccessPolicy writer = _policyFor(
        permissions: <AppPermission>{
          AppPermissions.billingRead,
          AppPermissions.billingWrite,
        },
      );

      expect(billingWorkspaceWriteRequirement.isAllowed(reader), isFalse);
      expect(billingWorkspaceWriteRequirement.isAllowed(writer), isTrue);
      expect(canWriteBilling(writer), isTrue);
      expect(canWriteBilling(reader), isFalse);
    });

    test(
      'approval decision requires billing:write ∩ financial:approve (intersection)',
      () {
        final AppAccessPolicy writer = _policyFor(
          permissions: <AppPermission>{
            AppPermissions.billingRead,
            AppPermissions.billingWrite,
          },
        );
        final AppAccessPolicy approveOnly = _policyFor(
          permissions: <AppPermission>{
            AppPermissions.billingRead,
            AppPermissions.financialApprove,
          },
        );
        final AppAccessPolicy both = _policyFor(
          permissions: <AppPermission>{
            AppPermissions.billingRead,
            AppPermissions.billingWrite,
            AppPermissions.financialApprove,
          },
        );

        expect(billingApprovalDecisionRequirement.isAllowed(writer), isFalse);
        expect(
          billingApprovalDecisionRequirement.isAllowed(approveOnly),
          isFalse,
        );
        expect(billingApprovalDecisionRequirement.isAllowed(both), isTrue);
        expect(canApproveBillingMutations(both), isTrue);
      },
    );

    test('claims pending tab needs insurance-claims module', () {
      final AppAccessPolicy withInsurance = _policyFor(
        permissions: <AppPermission>{AppPermissions.billingRead},
      );
      final AppAccessPolicy withoutInsurance = _policyFor(
        permissions: <AppPermission>{AppPermissions.billingRead},
        modules: const <AppModuleEntitlement>[
          AppModuleEntitlement(
            code: 'billing-payments',
            licenseStatus: 'ACTIVE',
          ),
        ],
      );

      expect(
        canViewBillingQueue(withInsurance, BillingQueueType.claimsPending),
        isTrue,
      );
      expect(
        canViewBillingQueue(withoutInsurance, BillingQueueType.claimsPending),
        isFalse,
      );
      expect(
        canViewBillingQueue(withInsurance, BillingQueueType.all),
        isTrue,
      );
    });

    test('claims write reuses claimsWorkspaceWriteRequirement vocabulary', () {
      final AppAccessPolicy writer = _policyFor(
        permissions: <AppPermission>{AppPermissions.billingWrite},
      );
      final AppAccessPolicy reader = _policyFor(
        permissions: <AppPermission>{AppPermissions.billingRead},
      );

      expect(billingClaimsWriteRequirement.isAllowed(writer), isTrue);
      expect(billingClaimsWriteRequirement.isAllowed(reader), isFalse);
      expect(canMutateBillingClaims(writer), isTrue);
    });

    test('next-action requirement maps approve vs write vs claims', () {
      const BillingWorkItem approval = BillingWorkItem(
        id: 'apr',
        kind: BillingWorkItemKind.approval,
        status: 'PENDING',
      );
      const BillingWorkItem draft = BillingWorkItem(
        id: 'inv',
        kind: BillingWorkItemKind.invoice,
        billingStatus: 'DRAFT',
      );
      const BillingWorkItem claim = BillingWorkItem(
        id: 'clm',
        kind: BillingWorkItemKind.claim,
        status: 'PENDING',
      );

      expect(
        identical(
          billingNextActionRequirement(approval),
          billingApprovalDecisionRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          billingNextActionRequirement(draft),
          billingWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          billingNextActionRequirement(claim),
          billingClaimsWriteRequirement,
        ),
        isTrue,
      );
    });

    test('route entry ∪ allows billing:read or billing:write', () {
      final AppAccessPolicy reader = _policyFor(
        permissions: <AppPermission>{AppPermissions.billingRead},
      );
      final AppAccessPolicy writer = _policyFor(
        permissions: <AppPermission>{AppPermissions.billingWrite},
      );
      final AppAccessPolicy neither = _policyFor(
        permissions: <AppPermission>{AppPermissions.patientRead},
      );

      expect(billingWorkspaceEntryRequirement.isAllowed(reader), isTrue);
      expect(billingWorkspaceEntryRequirement.isAllowed(writer), isTrue);
      expect(billingWorkspaceEntryRequirement.isAllowed(neither), isFalse);
    });

    test('Approval required atom map reuses feature *Requirement helpers', () {
      expect(
        identical(
          BillingApprovalRequiredAtomPermissions.approve,
          billingApprovalDecisionRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingApprovalRequiredAtomPermissions.delete,
          billingWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingApprovalRequiredAtomPermissions.nestedWrite,
          billingClaimsWriteRequirement,
        ),
        isTrue,
      );
    });

    test('Awaiting payment atom map reuses feature *Requirement helpers', () {
      expect(
        identical(
          BillingAwaitingPaymentAtomPermissions.receivePayment,
          billingWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingAwaitingPaymentAtomPermissions.tab,
          billingWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingAwaitingPaymentAtomPermissions.approve,
          billingApprovalDecisionRequirement,
        ),
        isTrue,
      );
    });
  });
}
