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

    test('All tab atom map reuses feature *Requirement helpers', () {
      expect(
        identical(
          BillingAllAtomPermissions.tab,
          billingWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingAllAtomPermissions.listChrome,
          billingWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingAllAtomPermissions.detail,
          billingWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingAllAtomPermissions.document,
          billingWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingAllAtomPermissions.write,
          billingWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingAllAtomPermissions.create,
          billingWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingAllAtomPermissions.update,
          billingWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingAllAtomPermissions.delete,
          billingWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingAllAtomPermissions.close,
          billingWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingAllAtomPermissions.issue,
          billingWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingAllAtomPermissions.receivePayment,
          billingWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingAllAtomPermissions.refund,
          billingWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingAllAtomPermissions.adjust,
          billingWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingAllAtomPermissions.voidInvoice,
          billingWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingAllAtomPermissions.send,
          billingWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingAllAtomPermissions.approve,
          billingApprovalDecisionRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingAllAtomPermissions.nestedWrite,
          billingClaimsWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingAllAtomPermissions.nestedRead,
          billingClaimsNestedReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingAllAtomPermissions.claimsPendingTab,
          billingClaimsPendingTabRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingAllAtomPermissions.entry,
          billingWorkspaceEntryRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingAllAtomPermissions.routeEntry,
          billingWorkspaceEntryRequirement,
        ),
        isTrue,
      );

      final AppAccessPolicy reader = _policyFor(
        permissions: <AppPermission>{AppPermissions.billingRead},
      );
      final AppAccessPolicy writer = _policyFor(
        permissions: <AppPermission>{
          AppPermissions.billingRead,
          AppPermissions.billingWrite,
        },
      );
      expect(BillingAllAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(BillingAllAtomPermissions.document.isAllowed(reader), isTrue);
      expect(BillingAllAtomPermissions.issue.isAllowed(reader), isFalse);
      expect(BillingAllAtomPermissions.create.isAllowed(reader), isFalse);
      expect(BillingAllAtomPermissions.update.isAllowed(reader), isFalse);
      expect(BillingAllAtomPermissions.delete.isAllowed(reader), isFalse);
      expect(BillingAllAtomPermissions.close.isAllowed(reader), isFalse);
      expect(BillingAllAtomPermissions.receivePayment.isAllowed(reader), isFalse);
      expect(BillingAllAtomPermissions.refund.isAllowed(reader), isFalse);
      expect(BillingAllAtomPermissions.adjust.isAllowed(reader), isFalse);
      expect(BillingAllAtomPermissions.voidInvoice.isAllowed(reader), isFalse);
      expect(BillingAllAtomPermissions.send.isAllowed(reader), isFalse);
      expect(BillingAllAtomPermissions.nestedWrite.isAllowed(reader), isFalse);
      expect(BillingAllAtomPermissions.issue.isAllowed(writer), isTrue);
      expect(BillingAllAtomPermissions.create.isAllowed(writer), isTrue);
      expect(BillingAllAtomPermissions.update.isAllowed(writer), isTrue);
      expect(BillingAllAtomPermissions.delete.isAllowed(writer), isTrue);
      expect(BillingAllAtomPermissions.close.isAllowed(writer), isTrue);
      expect(BillingAllAtomPermissions.receivePayment.isAllowed(writer), isTrue);
      expect(BillingAllAtomPermissions.refund.isAllowed(writer), isTrue);
      expect(BillingAllAtomPermissions.adjust.isAllowed(writer), isTrue);
      expect(BillingAllAtomPermissions.voidInvoice.isAllowed(writer), isTrue);
      expect(BillingAllAtomPermissions.send.isAllowed(writer), isTrue);
      expect(BillingAllAtomPermissions.routeEntry.isAllowed(writer), isTrue);
      // Writer without insurance-claims: nested claim write stays denied.
      final AppAccessPolicy writerNoClaims = _policyFor(
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
      expect(
        BillingAllAtomPermissions.nestedWrite.isAllowed(writerNoClaims),
        isFalse,
      );
      expect(BillingAllAtomPermissions.write.isAllowed(writerNoClaims), isTrue);
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
          BillingApprovalRequiredAtomPermissions.create,
          billingApprovalDecisionRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingApprovalRequiredAtomPermissions.update,
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
          BillingApprovalRequiredAtomPermissions.close,
          billingWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingApprovalRequiredAtomPermissions.write,
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
      expect(
        identical(
          BillingApprovalRequiredAtomPermissions.document,
          billingWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingApprovalRequiredAtomPermissions.claimsPendingTab,
          billingClaimsPendingTabRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingApprovalRequiredAtomPermissions.routeEntry,
          billingWorkspaceEntryRequirement,
        ),
        isTrue,
      );
    });

    test(
      'Approval create/update keep source ∩ (write + financial:approve), '
      'not matrix financial:approve alone',
      () {
        final AppAccessPolicy approveOnly = _policyFor(
          permissions: <AppPermission>{AppPermissions.financialApprove},
        );
        final AppAccessPolicy full = _policyFor(
          permissions: <AppPermission>{
            AppPermissions.billingWrite,
            AppPermissions.financialApprove,
          },
        );
        expect(
          BillingApprovalRequiredAtomPermissions.create.isAllowed(approveOnly),
          isFalse,
        );
        expect(
          BillingApprovalRequiredAtomPermissions.update.isAllowed(approveOnly),
          isFalse,
        );
        expect(
          BillingApprovalRequiredAtomPermissions.create.isAllowed(full),
          isTrue,
        );
      },
    );

    test(
      'Approval required next-action column mounts only with approve ∩',
      () {
        final AppAccessPolicy writer = _policyFor(
          permissions: <AppPermission>{
            AppPermissions.billingRead,
            AppPermissions.billingWrite,
          },
        );
        final AppAccessPolicy approver = _policyFor(
          permissions: <AppPermission>{
            AppPermissions.billingRead,
            AppPermissions.billingWrite,
            AppPermissions.financialApprove,
          },
        );
        expect(
          billingQueueShowsNextActionColumn(
            writer,
            BillingQueueType.approvalRequired,
          ),
          isFalse,
        );
        expect(
          billingQueueShowsNextActionColumn(
            approver,
            BillingQueueType.approvalRequired,
          ),
          isTrue,
        );
        expect(
          billingQueueShowsNextActionColumn(
            writer,
            BillingQueueType.needsIssue,
          ),
          isTrue,
        );
      },
    );

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
          BillingAwaitingPaymentAtomPermissions.refund,
          billingWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingAwaitingPaymentAtomPermissions.adjust,
          billingWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingAwaitingPaymentAtomPermissions.voidInvoice,
          billingWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingAwaitingPaymentAtomPermissions.send,
          billingWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingAwaitingPaymentAtomPermissions.write,
          billingWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingAwaitingPaymentAtomPermissions.update,
          billingWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingAwaitingPaymentAtomPermissions.delete,
          billingWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingAwaitingPaymentAtomPermissions.close,
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
          BillingAwaitingPaymentAtomPermissions.listChrome,
          billingWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingAwaitingPaymentAtomPermissions.detail,
          billingWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingAwaitingPaymentAtomPermissions.document,
          billingWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingAwaitingPaymentAtomPermissions.create,
          billingWorkspaceWriteRequirement,
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
      expect(
        identical(
          BillingAwaitingPaymentAtomPermissions.nestedWrite,
          billingClaimsWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingAwaitingPaymentAtomPermissions.nestedRead,
          billingClaimsNestedReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingAwaitingPaymentAtomPermissions.routeEntry,
          billingWorkspaceEntryRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingAwaitingPaymentAtomPermissions.claimsPendingTab,
          billingClaimsPendingTabRequirement,
        ),
        isTrue,
      );

      final AppAccessPolicy reader = _policyFor(
        permissions: <AppPermission>{AppPermissions.billingRead},
      );
      final AppAccessPolicy writer = _policyFor(
        permissions: <AppPermission>{
          AppPermissions.billingRead,
          AppPermissions.billingWrite,
        },
      );
      expect(BillingAwaitingPaymentAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(
        BillingAwaitingPaymentAtomPermissions.document.isAllowed(reader),
        isTrue,
      );
      expect(
        BillingAwaitingPaymentAtomPermissions.receivePayment.isAllowed(reader),
        isFalse,
      );
      expect(
        BillingAwaitingPaymentAtomPermissions.create.isAllowed(reader),
        isFalse,
      );
      expect(
        BillingAwaitingPaymentAtomPermissions.update.isAllowed(reader),
        isFalse,
      );
      expect(
        BillingAwaitingPaymentAtomPermissions.delete.isAllowed(reader),
        isFalse,
      );
      expect(
        BillingAwaitingPaymentAtomPermissions.write.isAllowed(reader),
        isFalse,
      );
      expect(
        BillingAwaitingPaymentAtomPermissions.close.isAllowed(reader),
        isFalse,
      );
      expect(
        BillingAwaitingPaymentAtomPermissions.approve.isAllowed(reader),
        isFalse,
      );
      expect(
        BillingAwaitingPaymentAtomPermissions.nestedWrite.isAllowed(reader),
        isFalse,
      );
      expect(
        BillingAwaitingPaymentAtomPermissions.receivePayment.isAllowed(writer),
        isTrue,
      );
      expect(
        BillingAwaitingPaymentAtomPermissions.create.isAllowed(writer),
        isTrue,
      );
      expect(
        BillingAwaitingPaymentAtomPermissions.write.isAllowed(writer),
        isTrue,
      );
      expect(
        BillingAwaitingPaymentAtomPermissions.close.isAllowed(writer),
        isTrue,
      );
      // Default fixtures include insurance-claims — nested claim write ∩ allows.
      expect(
        BillingAwaitingPaymentAtomPermissions.nestedWrite.isAllowed(writer),
        isTrue,
      );
    });

    test('Overdue atom map reuses feature *Requirement helpers', () {
      expect(
        identical(
          BillingOverdueAtomPermissions.receivePayment,
          billingWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingOverdueAtomPermissions.adjust,
          billingWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingOverdueAtomPermissions.waive,
          billingWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingOverdueAtomPermissions.waive,
          BillingOverdueAtomPermissions.adjust,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingOverdueAtomPermissions.voidInvoice,
          billingWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingOverdueAtomPermissions.dunningSend,
          billingWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingOverdueAtomPermissions.close,
          billingWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingOverdueAtomPermissions.tab,
          billingWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingOverdueAtomPermissions.create,
          billingWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingOverdueAtomPermissions.approve,
          billingApprovalDecisionRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingOverdueAtomPermissions.nestedWrite,
          billingClaimsWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingOverdueAtomPermissions.routeEntry,
          billingWorkspaceEntryRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingOverdueAtomPermissions.claimsPendingTab,
          billingClaimsPendingTabRequirement,
        ),
        isTrue,
      );

      final AppAccessPolicy reader = _policyFor(
        permissions: <AppPermission>{AppPermissions.billingRead},
      );
      final AppAccessPolicy writer = _policyFor(
        permissions: <AppPermission>{
          AppPermissions.billingRead,
          AppPermissions.billingWrite,
        },
      );
      expect(BillingOverdueAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(BillingOverdueAtomPermissions.write.isAllowed(reader), isFalse);
      expect(BillingOverdueAtomPermissions.close.isAllowed(reader), isFalse);
      expect(BillingOverdueAtomPermissions.waive.isAllowed(reader), isFalse);
      expect(BillingOverdueAtomPermissions.write.isAllowed(writer), isTrue);
      expect(BillingOverdueAtomPermissions.close.isAllowed(writer), isTrue);
      expect(BillingOverdueAtomPermissions.waive.isAllowed(writer), isTrue);
      expect(
        BillingOverdueAtomPermissions.voidInvoice.isAllowed(writer),
        isTrue,
      );
    });

    test('Needs issue atom map reuses feature *Requirement helpers', () {
      expect(
        identical(
          BillingNeedsIssueAtomPermissions.issue,
          billingWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingNeedsIssueAtomPermissions.close,
          billingWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingNeedsIssueAtomPermissions.write,
          billingWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingNeedsIssueAtomPermissions.update,
          billingWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingNeedsIssueAtomPermissions.delete,
          billingWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingNeedsIssueAtomPermissions.tab,
          billingWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingNeedsIssueAtomPermissions.listChrome,
          billingWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingNeedsIssueAtomPermissions.detail,
          billingWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingNeedsIssueAtomPermissions.document,
          billingWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingNeedsIssueAtomPermissions.create,
          billingWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingNeedsIssueAtomPermissions.approve,
          billingApprovalDecisionRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingNeedsIssueAtomPermissions.nestedWrite,
          billingClaimsWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingNeedsIssueAtomPermissions.nestedRead,
          billingClaimsNestedReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingNeedsIssueAtomPermissions.routeEntry,
          billingWorkspaceEntryRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingNeedsIssueAtomPermissions.claimsPendingTab,
          billingClaimsPendingTabRequirement,
        ),
        isTrue,
      );

      final AppAccessPolicy reader = _policyFor(
        permissions: <AppPermission>{AppPermissions.billingRead},
      );
      final AppAccessPolicy writer = _policyFor(
        permissions: <AppPermission>{
          AppPermissions.billingRead,
          AppPermissions.billingWrite,
        },
      );
      expect(BillingNeedsIssueAtomPermissions.tab.isAllowed(reader), isTrue);
      expect(BillingNeedsIssueAtomPermissions.document.isAllowed(reader), isTrue);
      expect(BillingNeedsIssueAtomPermissions.issue.isAllowed(reader), isFalse);
      expect(BillingNeedsIssueAtomPermissions.create.isAllowed(reader), isFalse);
      expect(BillingNeedsIssueAtomPermissions.update.isAllowed(reader), isFalse);
      expect(BillingNeedsIssueAtomPermissions.delete.isAllowed(reader), isFalse);
      expect(BillingNeedsIssueAtomPermissions.write.isAllowed(reader), isFalse);
      expect(BillingNeedsIssueAtomPermissions.close.isAllowed(reader), isFalse);
      expect(BillingNeedsIssueAtomPermissions.approve.isAllowed(reader), isFalse);
      expect(
        BillingNeedsIssueAtomPermissions.nestedWrite.isAllowed(reader),
        isFalse,
      );
      expect(BillingNeedsIssueAtomPermissions.issue.isAllowed(writer), isTrue);
      expect(BillingNeedsIssueAtomPermissions.create.isAllowed(writer), isTrue);
      expect(BillingNeedsIssueAtomPermissions.close.isAllowed(writer), isTrue);
      // Default fixtures include insurance-claims — nested claim write ∩ allows.
      expect(
        BillingNeedsIssueAtomPermissions.nestedWrite.isAllowed(writer),
        isTrue,
      );
    });

    test('Claims pending atom map reuses feature *Requirement helpers', () {
      expect(
        identical(
          BillingClaimsPendingAtomPermissions.tab,
          billingClaimsPendingTabRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingClaimsPendingAtomPermissions.listChrome,
          billingClaimsPendingTabRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingClaimsPendingAtomPermissions.detail,
          billingClaimsPendingTabRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingClaimsPendingAtomPermissions.claimWrite,
          billingClaimsWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingClaimsPendingAtomPermissions.create,
          billingClaimsWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingClaimsPendingAtomPermissions.update,
          billingClaimsWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingClaimsPendingAtomPermissions.delete,
          billingWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingClaimsPendingAtomPermissions.close,
          billingWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingClaimsPendingAtomPermissions.write,
          billingWorkspaceWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingClaimsPendingAtomPermissions.approve,
          billingApprovalDecisionRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingClaimsPendingAtomPermissions.nestedWrite,
          billingClaimsWriteRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingClaimsPendingAtomPermissions.nestedRead,
          billingClaimsNestedReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingClaimsPendingAtomPermissions.document,
          billingWorkspaceReadRequirement,
        ),
        isTrue,
      );
      expect(
        identical(
          BillingClaimsPendingAtomPermissions.routeEntry,
          billingWorkspaceEntryRequirement,
        ),
        isTrue,
      );

      final AppAccessPolicy readerWithInsurance = _policyFor(
        permissions: <AppPermission>{AppPermissions.billingRead},
      );
      final AppAccessPolicy writerNoInsurance = _policyFor(
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
      final AppAccessPolicy writerWithInsurance = _policyFor(
        permissions: <AppPermission>{
          AppPermissions.billingRead,
          AppPermissions.billingWrite,
        },
      );

      expect(
        BillingClaimsPendingAtomPermissions.tab.isAllowed(readerWithInsurance),
        isTrue,
      );
      expect(
        BillingClaimsPendingAtomPermissions.tab.isAllowed(writerNoInsurance),
        isFalse,
      );
      expect(
        BillingClaimsPendingAtomPermissions.claimWrite.isAllowed(
          readerWithInsurance,
        ),
        isFalse,
      );
      expect(
        BillingClaimsPendingAtomPermissions.claimWrite.isAllowed(
          writerWithInsurance,
        ),
        isTrue,
      );
    });
  });
}
