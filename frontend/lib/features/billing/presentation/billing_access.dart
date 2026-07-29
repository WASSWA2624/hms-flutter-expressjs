import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/features/billing/domain/entities/billing_entities.dart';
import 'package:hosspi_hms/features/claims/presentation/claims_access.dart';

/// Module entitlement for the billing workspace route and queues.
const String billingPaymentsModule = 'billing-payments';

/// Insurance module required for Claims pending tab and claim mutations.
const String billingInsuranceClaimsModule = 'insurance-claims';

/// View / read UI for billing queues (matrix ∩ `billing:read`).
const AccessRequirement billingWorkspaceReadRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.billingRead],
  activeModules: <String>[billingPaymentsModule],
);

/// Alias used by tab atom maps / prompts.
const AccessRequirement billingReadRequirement = billingWorkspaceReadRequirement;

/// Route entry (∪): `billing:read` | `billing:write` — matches
/// [AppRoutes.billing] `requiredAnyPermissions`.
const AccessRequirement billingWorkspaceEntryRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.billingRead,
    AppPermissions.billingWrite,
  ],
  activeModules: <String>[billingPaymentsModule],
);

/// Create / update / delete mutations, close shift, close day (matrix ∩
/// `billing:write`).
const AccessRequirement billingWorkspaceWriteRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.billingWrite],
  activeModules: <String>[billingPaymentsModule],
);

/// Alias used by tab atom maps / prompts.
const AccessRequirement billingWriteRequirement = billingWorkspaceWriteRequirement;

/// Approve / reject financial holds (matrix create/update ∩):
/// `billing:write` ∩ `financial:approve` when both apply.
///
/// Source inventory (`screens/billing.md`) historically documented
/// facility-manage for detail approve/reject; matrix + BILLING role pack use
/// `financial:approve` ∩ `billing:write`. Prefer this requirement; backend
/// remains authoritative if scopes differ.
const AccessRequirement billingApprovalDecisionRequirement = AccessRequirement(
  allPermissions: <AppPermission>[
    AppPermissions.billingWrite,
    AppPermissions.financialApprove,
  ],
  activeModules: <String>[billingPaymentsModule],
);

/// Matrix-only `financial:approve` (∩) without write — claims settlement /
/// intersection denial fixtures.
const AccessRequirement billingFinancialApproveRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.financialApprove],
  activeModules: <String>[billingPaymentsModule],
);

/// Claims pending tab visibility — billing read ∩ insurance entitlement.
const AccessRequirement billingClaimsPendingTabRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.billingRead],
  activeModules: <String>[billingPaymentsModule, billingInsuranceClaimsModule],
);

/// Claim submit / reconcile / pre-auth from billing — reuses claims write
/// vocabulary (`billing:write` + `insurance-claims`).
const AccessRequirement billingClaimsWriteRequirement =
    claimsWorkspaceWriteRequirement;

/// Nested claims read / deep-link from billing.
const AccessRequirement billingClaimsNestedReadRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.billingRead],
  activeModules: <String>[billingPaymentsModule, billingInsuranceClaimsModule],
);

/// Per-queue tab strip gate. Most queues need billing read; Claims pending
/// additionally requires the insurance module.
AccessRequirement billingQueueTabRequirement(BillingQueueType queue) {
  return switch (queue) {
    BillingQueueType.claimsPending => billingClaimsPendingTabRequirement,
    _ => billingWorkspaceReadRequirement,
  };
}

/// Requirement for the labeled next-action on a work item.
AccessRequirement billingNextActionRequirement(BillingWorkItem item) {
  if (item.canApproveOrReject) {
    return billingApprovalDecisionRequirement;
  }
  if (item.canSubmitClaim ||
      item.canReconcileClaim ||
      item.canApprovePreAuthorization ||
      item.canDenyPreAuthorization) {
    return billingClaimsWriteRequirement;
  }
  return billingWorkspaceWriteRequirement;
}

bool canReadBilling(AppAccessPolicy policy) {
  return billingWorkspaceReadRequirement.isAllowed(policy);
}

bool canWriteBilling(AppAccessPolicy policy) {
  return billingWorkspaceWriteRequirement.isAllowed(policy);
}

bool canApproveBillingMutations(AppAccessPolicy policy) {
  return billingApprovalDecisionRequirement.isAllowed(policy);
}

/// Alias used by table chrome for approval next-actions.
bool canDecideBillingApproval(AppAccessPolicy policy) {
  return canApproveBillingMutations(policy);
}

bool canWriteBillingClaims(AppAccessPolicy policy) {
  return billingClaimsWriteRequirement.isAllowed(policy);
}

/// Alias used by table chrome for claim / pre-auth next-actions.
bool canMutateBillingClaims(AppAccessPolicy policy) {
  return canWriteBillingClaims(policy);
}

bool canReadBillingClaimsNested(AppAccessPolicy policy) {
  return billingClaimsNestedReadRequirement.isAllowed(policy);
}

bool canViewBillingQueue(AppAccessPolicy policy, BillingQueueType queue) {
  return billingQueueTabRequirement(queue).isAllowed(policy);
}

/// Print / download invoice are read chrome (no separate export key on this tab).
bool canReadBillingDocument(AppAccessPolicy policy) {
  return canReadBilling(policy);
}

/// View ledger — invoices use billing read; claim / pre-auth use nested claims
/// read (`billing:read` ∩ `insurance-claims`) per Claims pending inventory.
bool canViewBillingLedger(AppAccessPolicy policy, BillingWorkItem item) {
  if (item.isClaim || item.isPreAuthorization) {
    return canReadBillingClaimsNested(policy);
  }
  return canReadBilling(policy);
}

/// Whether [item] exposes a permission-allowed next action.
bool billingNextActionIsAllowed(
  AppAccessPolicy policy,
  BillingWorkItem item,
) {
  return billingNextActionRequirement(item).isAllowed(policy);
}

/// Whether the Next action column mounts for [queue].
///
/// Approval required rows only expose approve/reject — write alone must not
/// mount an empty mutation column. Claims pending rows only expose claim /
/// pre-auth mutations — write alone without insurance must not mount an empty
/// column. Other queues keep write / approve / claims.
bool billingQueueShowsNextActionColumn(
  AppAccessPolicy policy,
  BillingQueueType queue,
) {
  return switch (queue) {
    BillingQueueType.approvalRequired => canDecideBillingApproval(policy),
    BillingQueueType.claimsPending => canMutateBillingClaims(policy),
    _ =>
      canWriteBilling(policy) ||
      canDecideBillingApproval(policy) ||
      canMutateBillingClaims(policy),
  };
}

/// All tab atom → permission mapping (inventory + matrix).
///
/// Full billing queue (`?queue=all` or default). Mixed next-actions inherit
/// per-item gates via [billingNextActionRequirement]. Secondary invoice
/// mutations (refund / adjust / void / send) share write ∩ when the item
/// exposes them. Deep link `action=pay` opens payment only when write-
/// authorized. Approval holds need [approve] (`billing:write` ∩
/// `financial:approve`) — matrix alone lists write; source keeps the
/// intersection when both apply.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | All tab | navigate | read ∩ `billing:read` |
/// | Search / filters / columns | read chrome | read ∩ |
/// | Empty / error / retry | read chrome | read ∩ |
/// | Row select → detail | read | read ∩ |
/// | Close shift / Close day | update | write ∩ `billing:write` ([close]) |
/// | Next action Issue / Pay / Refund / Adjust / Void / Send | create / update / delete | write ∩ |
/// | Next action Approve | approve | write ∩ financial:approve |
/// | Detail invoice mutations | CRUD | write ∩ ([issue]/[receivePayment]/[refund]/[adjust]/[voidInvoice]/[send]) |
/// | Detail Approve / Reject | approve | write ∩ financial:approve |
/// | Nested mutation dialogs | create / update / delete | write ∩ / approval ∩ / claims write |
/// | Claim / pre-auth mutations | nested write | claims write ([nestedWrite]) |
/// | Claims pending tab (strip) | navigate | claims pending tab |
/// | View ledger / Print / Download | read / export | document read ∩ |
/// | Route entry (deep link) | navigate | read ∪ write ([routeEntry]) |
///
/// Matrix nested cross-module rows are _(n/a)_; Claims pending strip still uses
/// [billingClaimsPendingTabRequirement] when insurance is entitled. Route entry
/// ∪ (`billing:read` \| `billing:write`) is [billingWorkspaceEntryRequirement].
abstract final class BillingAllAtomPermissions {
  static const AccessRequirement tab = billingWorkspaceReadRequirement;
  static const AccessRequirement listChrome = billingWorkspaceReadRequirement;
  static const AccessRequirement detail = billingWorkspaceReadRequirement;
  static const AccessRequirement create = billingWorkspaceWriteRequirement;
  static const AccessRequirement update = billingWorkspaceWriteRequirement;
  static const AccessRequirement delete = billingWorkspaceWriteRequirement;
  static const AccessRequirement write = billingWorkspaceWriteRequirement;
  static const AccessRequirement close = billingWorkspaceWriteRequirement;
  static const AccessRequirement issue = billingWorkspaceWriteRequirement;
  static const AccessRequirement receivePayment = billingWorkspaceWriteRequirement;
  static const AccessRequirement refund = billingWorkspaceWriteRequirement;
  static const AccessRequirement adjust = billingWorkspaceWriteRequirement;
  static const AccessRequirement voidInvoice = billingWorkspaceWriteRequirement;
  static const AccessRequirement send = billingWorkspaceWriteRequirement;
  static const AccessRequirement approve = billingApprovalDecisionRequirement;
  static const AccessRequirement nestedWrite = billingClaimsWriteRequirement;
  static const AccessRequirement nestedRead = billingClaimsNestedReadRequirement;
  static const AccessRequirement claimsPendingTab =
      billingClaimsPendingTabRequirement;
  static const AccessRequirement document = billingWorkspaceReadRequirement;
  static const AccessRequirement entry = billingWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry = billingWorkspaceEntryRequirement;
}

/// Approval required tab atom → permission mapping (inventory + matrix).
///
/// Matrix create/update keys list `financial:approve` alone; source inventory
/// (`screens/billing.md`) and BILLING pack apply `billing:write` ∩
/// `financial:approve` via [billingApprovalDecisionRequirement] — keep source.
/// Nested cross-module write matrix ∩ is `billing:write`; claims nested UI
/// still requires [billingClaimsWriteRequirement] (+ `insurance-claims`).
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Approval required tab | navigate | read ∩ `billing:read` |
/// | Search / filters / columns | read chrome | read ∩ |
/// | Empty / error / retry | read chrome | read ∩ |
/// | Row select → detail | read | read ∩ |
/// | Close shift / Close day | delete / update | write ∩ `billing:write` |
/// | Next action Approve | approve / create / update | write ∩ financial:approve |
/// | Detail Approve / Reject | approve / create / update | write ∩ financial:approve |
/// | Nested approval notes dialogs | update | write ∩ financial:approve |
/// | View ledger | read | read ∩ |
/// | Print / Download | export / read | document read ∩ |
/// | Claims pending strip / nested | navigate / write | claims pending tab / claims write |
/// | Route entry (deep link) | navigate | read ∪ write |
///
/// Matrix create/update ∩ lists `financial:approve` alone; keep source
/// [billingApprovalDecisionRequirement]. Nested matrix write ∩ is
/// `billing:write` ([write]/[delete]/[close]); claims nested UI still uses
/// [billingClaimsWriteRequirement]. Route entry ∪ is [routeEntry].
abstract final class BillingApprovalRequiredAtomPermissions {
  static const AccessRequirement tab = billingWorkspaceReadRequirement;
  static const AccessRequirement listChrome = billingWorkspaceReadRequirement;
  static const AccessRequirement detail = billingWorkspaceReadRequirement;
  static const AccessRequirement create = billingApprovalDecisionRequirement;
  static const AccessRequirement update = billingApprovalDecisionRequirement;
  static const AccessRequirement delete = billingWorkspaceWriteRequirement;
  static const AccessRequirement write = billingWorkspaceWriteRequirement;
  static const AccessRequirement close = billingWorkspaceWriteRequirement;
  static const AccessRequirement approve = billingApprovalDecisionRequirement;
  static const AccessRequirement nestedWrite = billingClaimsWriteRequirement;
  static const AccessRequirement nestedRead = billingClaimsNestedReadRequirement;
  static const AccessRequirement document = billingWorkspaceReadRequirement;
  static const AccessRequirement claimsPendingTab =
      billingClaimsPendingTabRequirement;
  static const AccessRequirement routeEntry = billingWorkspaceEntryRequirement;
}

/// Awaiting payment tab atom → permission mapping (inventory + matrix).
///
/// Record payment / receipt, refund, adjust, void, and send need `billing:write`.
/// Deep link `action=pay` opens payment only when write-authorized. Matrix
/// nested cross-module rows are _(n/a)_; Claims pending strip still uses
/// [billingClaimsPendingTabRequirement] when insurance is entitled. Route entry
/// ∪ (`billing:read` \| `billing:write`) is [billingWorkspaceEntryRequirement].
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Awaiting payment tab | navigate | read ∩ `billing:read` |
/// | Search / filters / columns | read chrome | read ∩ |
/// | Empty / error / retry | read chrome | read ∩ |
/// | Row select → detail | read | read ∩ |
/// | Close shift / Close day | update | write ∩ `billing:write` |
/// | Next action Receive payment | create / update | write ∩ |
/// | Detail Receive payment / refund / adjust / void / send | CRUD | write ∩ |
/// | Nested payment / refund / adjustment / send dialogs | create / update | write ∩ |
/// | Deep link `action=pay` | create / update | write ∩ |
/// | View ledger / financial panels | read | read ∩ |
/// | Print / Download | export / read | document read ∩ |
/// | Approve nested (other kinds) | approve | write ∩ financial:approve |
/// | Claims pending strip / nested | navigate / write | claims pending tab / claims write |
/// | Route entry (deep link) | navigate | read ∪ write |
abstract final class BillingAwaitingPaymentAtomPermissions {
  static const AccessRequirement tab = billingWorkspaceReadRequirement;
  static const AccessRequirement listChrome = billingWorkspaceReadRequirement;
  static const AccessRequirement detail = billingWorkspaceReadRequirement;
  static const AccessRequirement create = billingWorkspaceWriteRequirement;
  static const AccessRequirement update = billingWorkspaceWriteRequirement;
  static const AccessRequirement delete = billingWorkspaceWriteRequirement;
  static const AccessRequirement write = billingWorkspaceWriteRequirement;
  static const AccessRequirement close = billingWorkspaceWriteRequirement;
  static const AccessRequirement receivePayment = billingWorkspaceWriteRequirement;
  static const AccessRequirement refund = billingWorkspaceWriteRequirement;
  static const AccessRequirement adjust = billingWorkspaceWriteRequirement;
  static const AccessRequirement voidInvoice = billingWorkspaceWriteRequirement;
  static const AccessRequirement send = billingWorkspaceWriteRequirement;
  static const AccessRequirement approve = billingApprovalDecisionRequirement;
  static const AccessRequirement nestedWrite = billingClaimsWriteRequirement;
  static const AccessRequirement nestedRead = billingClaimsNestedReadRequirement;
  static const AccessRequirement document = billingWorkspaceReadRequirement;
  static const AccessRequirement claimsPendingTab =
      billingClaimsPendingTabRequirement;
  static const AccessRequirement routeEntry = billingWorkspaceEntryRequirement;
}

/// Overdue tab atom → permission mapping (inventory + matrix).
///
/// Collections follow-up: receive payment, dunning send, adjust / waive, void.
/// [waive] is the collections synonym for [adjust] (same `billing:write` ∩).
/// Deep link `action=pay` opens payment only when write-authorized.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Overdue tab | navigate | read ∩ `billing:read` |
/// | Search / filters / columns | read chrome | read ∩ |
/// | Empty / error / retry | read chrome | read ∩ |
/// | Row select → detail | read | read ∩ |
/// | Close shift / Close day | update | write ∩ `billing:write` |
/// | Next action Receive payment | create / update | write ∩ |
/// | Detail Receive payment / adjust (waive) / void / send (dunning) | CRUD | write ∩ |
/// | Nested payment / adjustment / send dialogs | create / update | write ∩ |
/// | Deep link `action=pay` | create / update | write ∩ |
/// | View ledger / financial panels | read | read ∩ |
/// | Print / Download | export / read | document read ∩ |
/// | Approve nested (other kinds) | approve | write ∩ financial:approve |
/// | Claims pending strip / nested | navigate / write | claims pending tab / claims write |
///
/// Matrix nested cross-module rows are _(n/a)_; Claims pending strip still uses
/// [billingClaimsPendingTabRequirement] when insurance is entitled. Route entry
/// ∪ (`billing:read` \| `billing:write`) is [billingWorkspaceEntryRequirement].
abstract final class BillingOverdueAtomPermissions {
  static const AccessRequirement tab = billingWorkspaceReadRequirement;
  static const AccessRequirement listChrome = billingWorkspaceReadRequirement;
  static const AccessRequirement detail = billingWorkspaceReadRequirement;
  static const AccessRequirement create = billingWorkspaceWriteRequirement;
  static const AccessRequirement update = billingWorkspaceWriteRequirement;
  static const AccessRequirement delete = billingWorkspaceWriteRequirement;
  static const AccessRequirement write = billingWorkspaceWriteRequirement;
  static const AccessRequirement close = billingWorkspaceWriteRequirement;
  static const AccessRequirement receivePayment = billingWorkspaceWriteRequirement;
  static const AccessRequirement adjust = billingWorkspaceWriteRequirement;
  /// Collections synonym for [adjust] — same write ∩ gate.
  static const AccessRequirement waive = billingWorkspaceWriteRequirement;
  static const AccessRequirement voidInvoice = billingWorkspaceWriteRequirement;
  static const AccessRequirement dunningSend = billingWorkspaceWriteRequirement;
  static const AccessRequirement approve = billingApprovalDecisionRequirement;
  static const AccessRequirement nestedWrite = billingClaimsWriteRequirement;
  static const AccessRequirement nestedRead = billingClaimsNestedReadRequirement;
  static const AccessRequirement document = billingWorkspaceReadRequirement;
  static const AccessRequirement claimsPendingTab =
      billingClaimsPendingTabRequirement;
  static const AccessRequirement routeEntry = billingWorkspaceEntryRequirement;
}

/// Needs issue tab atom → permission mapping (inventory + matrix).
///
/// Invoices awaiting issue; Issue needs `billing:write`. Close shift/day need
/// write. Matrix nested cross-module rows are _(n/a)_; Claims pending strip
/// still uses [billingClaimsPendingTabRequirement] when insurance is entitled.
/// Route entry ∪ (`billing:read` \| `billing:write`) is
/// [billingWorkspaceEntryRequirement]. Secondary invoice mutations reachable
/// from detail (refund / adjust / void / send) share [write] when the item
/// exposes them — DRAFT rows typically only surface Issue.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Needs issue tab | navigate | read ∩ `billing:read` |
/// | Search / filters / columns | read chrome | read ∩ |
/// | Empty / error / retry | read chrome | read ∩ |
/// | Row select → detail | read | read ∩ |
/// | Close shift / Close day | update | write ∩ `billing:write` |
/// | Next action Issue | create / update | write ∩ |
/// | Detail Issue (+ refund / adjust / void / send if applicable) | CRUD | write ∩ |
/// | Nested issue notes dialog | create / update | write ∩ |
/// | View ledger / financial panels | read | read ∩ |
/// | Print / Download | export / read | document read ∩ |
/// | Approve nested (other kinds) | approve | write ∩ financial:approve |
/// | Claims pending strip / nested | navigate / write | claims pending tab / claims write |
/// | Route entry (deep link) | navigate | read ∪ write |
abstract final class BillingNeedsIssueAtomPermissions {
  static const AccessRequirement tab = billingWorkspaceReadRequirement;
  static const AccessRequirement listChrome = billingWorkspaceReadRequirement;
  static const AccessRequirement detail = billingWorkspaceReadRequirement;
  static const AccessRequirement create = billingWorkspaceWriteRequirement;
  static const AccessRequirement update = billingWorkspaceWriteRequirement;
  static const AccessRequirement delete = billingWorkspaceWriteRequirement;
  static const AccessRequirement write = billingWorkspaceWriteRequirement;
  static const AccessRequirement close = billingWorkspaceWriteRequirement;
  static const AccessRequirement issue = billingWorkspaceWriteRequirement;
  static const AccessRequirement approve = billingApprovalDecisionRequirement;
  static const AccessRequirement nestedWrite = billingClaimsWriteRequirement;
  static const AccessRequirement nestedRead = billingClaimsNestedReadRequirement;
  static const AccessRequirement document = billingWorkspaceReadRequirement;
  static const AccessRequirement claimsPendingTab =
      billingClaimsPendingTabRequirement;
  static const AccessRequirement routeEntry = billingWorkspaceEntryRequirement;
}

/// Claims pending tab atom → permission mapping (inventory + matrix).
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Claims pending tab | navigate | read ∩ `billing:read` ∩ `insurance-claims` |
/// | Search / filters / columns | read chrome | tab read ∩ |
/// | Empty / error / retry | read chrome | tab read ∩ |
/// | Row select → detail | read | tab read ∩ |
/// | Close shift / Close day | update / delete | write ∩ `billing:write` ([close]) |
/// | Next action Submit claim | create / update | [submit] / claims write |
/// | Next action Record insurer response | create / update | [reconcile] / claims write |
/// | Next action Approve / Deny authorization | create / update | [preAuth] / claims write |
/// | Detail claim / pre-auth actions | create / update | claims write |
/// | Nested claim submit / reconcile / pre-auth dialogs | create / update | claims write |
/// | View ledger | read | nested claims read ∩ ([nestedRead]) |
/// | Print / Download | export / read | document read ∩ (invoices only) |
/// | Approve nested (other kinds) | approve | write ∩ financial:approve |
/// | Route entry (deep link) | navigate | read ∪ write |
///
/// Matrix nested cross-module rows are _(n/a)_; Claims pending still requires
/// `insurance-claims` via [billingClaimsPendingTabRequirement] /
/// [billingClaimsWriteRequirement]. Matrix create/update ∩ is `billing:write`
/// — module is the nested entitlement (source keeps claims write helper).
/// Route entry ∪ (`billing:read` \| `billing:write`) is
/// [billingWorkspaceEntryRequirement].
abstract final class BillingClaimsPendingAtomPermissions {
  static const AccessRequirement tab = billingClaimsPendingTabRequirement;
  static const AccessRequirement listChrome = billingClaimsPendingTabRequirement;
  static const AccessRequirement detail = billingClaimsPendingTabRequirement;
  static const AccessRequirement create = billingClaimsWriteRequirement;
  static const AccessRequirement update = billingClaimsWriteRequirement;
  static const AccessRequirement delete = billingWorkspaceWriteRequirement;
  static const AccessRequirement write = billingWorkspaceWriteRequirement;
  /// Close shift / Close day — matrix update/delete ∩ `billing:write`.
  static const AccessRequirement close = billingWorkspaceWriteRequirement;
  static const AccessRequirement claimWrite = billingClaimsWriteRequirement;
  /// Submit claim — same ∩ as [claimWrite] (matrix create/update + insurance).
  static const AccessRequirement submit = billingClaimsWriteRequirement;
  /// Record insurer response / reconcile — same ∩ as [claimWrite].
  static const AccessRequirement reconcile = billingClaimsWriteRequirement;
  /// Pre-auth Approve / Deny — same ∩ as [claimWrite].
  static const AccessRequirement preAuth = billingClaimsWriteRequirement;
  static const AccessRequirement approve = billingApprovalDecisionRequirement;
  static const AccessRequirement nestedWrite = billingClaimsWriteRequirement;
  static const AccessRequirement nestedRead = billingClaimsNestedReadRequirement;
  static const AccessRequirement document = billingWorkspaceReadRequirement;
  static const AccessRequirement routeEntry = billingWorkspaceEntryRequirement;
}
