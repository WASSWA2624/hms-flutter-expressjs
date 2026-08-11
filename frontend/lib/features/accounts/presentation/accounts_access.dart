import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/route_access_catalog.dart';
import 'package:hosspi_hms/features/accounts/domain/entities/accounts_entities.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';

/// Module entitlement for the Accounts workspace (`facility-accounts`).
const String facilityAccountsModule = 'facility-accounts';

/// View / read UI for Accounts (matrix ∩ `accounts:read`).
const AccessRequirement accountsWorkspaceReadRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.accountsRead],
  activeModules: <String>[facilityAccountsModule],
);

/// Alias used by tab atom maps.
const AccessRequirement accountsReadRequirement =
    accountsWorkspaceReadRequirement;

/// Route entry — (`accounts:read` ∪ `accounts:write`) ∩ `facility-accounts`
/// (accounts.md §9).
const AccessRequirement accountsWorkspaceEntryRequirement =
    RouteAccessCatalog.accountsEntry;

/// Create / update / delete mutations — Journal · Post · Reverse · Void ·
/// Send · Open / Close period (matrix ∩ `accounts:write`).
const AccessRequirement accountsWorkspaceWriteRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.accountsWrite],
  activeModules: <String>[facilityAccountsModule],
);

/// Alias used by tab atom maps.
const AccessRequirement accountsWriteRequirement =
    accountsWorkspaceWriteRequirement;

/// Approve / Reject — `accounts:write` ∩ `financial:approve`
/// (accounts.md §9). `financial:*` is plan-mapped to `billing-payments`, so
/// both facility-accounts and billing-payments must be active for the grant to
/// survive [AppAccessPolicy.fromSession] plan gating.
const AccessRequirement accountsApprovalDecisionRequirement = AccessRequirement(
  allPermissions: <AppPermission>[
    AppPermissions.accountsWrite,
    AppPermissions.financialApprove,
  ],
  activeModules: <String>[facilityAccountsModule, 'billing-payments'],
);

/// Patient ledgers browse — `accounts:read` ∩ `facility-accounts`.
const AccessRequirement accountsPatientLedgersReadRequirement =
    accountsWorkspaceReadRequirement;

/// Chart of accounts mutations — accounts write or admin write equivalents
/// (accounts.md §9).
const AccessRequirement accountsChartWriteRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.accountsWrite,
    AppPermissions.tenantAdmin,
    AppPermissions.facilityAdmin,
  ],
  activeModules: <String>[facilityAccountsModule],
);

/// Pay deep-link / Pay actions — reuses billing write ∩ `billing-payments`
/// (accounts.md §9).
const AccessRequirement accountsPayDeepLinkRequirement =
    billingWorkspaceWriteRequirement;

AccessRequirement accountsSectionTabRequirement(AccountsDeskSection section) {
  return switch (section) {
    AccountsDeskSection.ledgers => accountsPatientLedgersReadRequirement,
    _ => accountsWorkspaceEntryRequirement,
  };
}

bool canEnterAccounts(AppAccessPolicy policy) {
  return accountsWorkspaceEntryRequirement.isAllowed(policy);
}

bool canEnterAccountsWorkspace(AppAccessPolicy policy) {
  return canEnterAccounts(policy);
}

bool canReadAccounts(AppAccessPolicy policy) {
  return accountsWorkspaceReadRequirement.isAllowed(policy);
}

bool canWriteAccounts(AppAccessPolicy policy) {
  return accountsWorkspaceWriteRequirement.isAllowed(policy);
}

bool canApproveAccountsMutations(AppAccessPolicy policy) {
  return accountsApprovalDecisionRequirement.isAllowed(policy);
}

bool canApproveAccounts(AppAccessPolicy policy) {
  return canApproveAccountsMutations(policy);
}

bool canDecideAccountsApproval(AppAccessPolicy policy) {
  return canApproveAccountsMutations(policy);
}

bool canReadAccountsPatientLedgers(AppAccessPolicy policy) {
  return accountsPatientLedgersReadRequirement.isAllowed(policy);
}

bool canWriteAccountsChart(AppAccessPolicy policy) {
  return accountsChartWriteRequirement.isAllowed(policy);
}

bool canPayFromAccounts(AppAccessPolicy policy) {
  return accountsPayDeepLinkRequirement.isAllowed(policy);
}

bool canViewAccountsSection(
  AppAccessPolicy policy,
  AccountsDeskSection section,
) {
  return accountsSectionTabRequirement(section).isAllowed(policy);
}

/// Open facility Account ledger (GL) — entry ∪ ∩ module.
bool canViewAccountsGl(AppAccessPolicy policy) {
  return canEnterAccounts(policy);
}

/// Show Next **GL** when the account has activity the user can open.
bool canOpenAccountsGlNext(AppAccessPolicy policy, AccountsGlAccount account) {
  return canViewAccountsGl(policy) && account.hasActivity;
}

/// Close books Next: Open → Close · Pending approval → Approve · else → Books.
String? accountsBooksNextActionLabel({
  required AppAccessPolicy policy,
  required AccountsFiscalPeriod period,
}) {
  if (period.canClose && canWriteAccounts(policy)) {
    return 'Close';
  }
  if (period.isPendingApproval && canApproveAccountsMutations(policy)) {
    return 'Approve';
  }
  if (canReadAccounts(policy) || canEnterAccounts(policy)) {
    return 'Books';
  }
  return null;
}

String? accountsBooksNextActionTooltip({
  required AppAccessPolicy policy,
  required AccountsFiscalPeriod period,
}) {
  final String? label = accountsBooksNextActionLabel(
    policy: policy,
    period: period,
  );
  return switch (label) {
    'Close' => 'Close this fiscal period',
    'Approve' => 'Approve this pending accounting request',
    'Books' => 'Open period detail and close checklist',
    _ => null,
  };
}

/// Journal from Account ledger — write ∩.
bool canCreateAccountsJournal(AppAccessPolicy policy) {
  return canWriteAccounts(policy);
}

AccountsDeskSection resolveAccountsSection(
  AppAccessPolicy policy, {
  AccountsDeskSection? preferred,
}) {
  if (!canEnterAccounts(policy)) {
    return AccountsDeskSection.fallback;
  }
  if (preferred != null && canViewAccountsSection(policy, preferred)) {
    return preferred;
  }
  for (final AccountsDeskSection section in AccountsDeskSection.values) {
    if (canViewAccountsSection(policy, section)) {
      return section;
    }
  }
  return AccountsDeskSection.fallback;
}

AccessRequirement accountsNextActionRequirement(AccountsWorkItem item) {
  if (item.canApprove) {
    return accountsApprovalDecisionRequirement;
  }
  if (item.canOpenGl || item.canOpenLedger) {
    return accountsWorkspaceEntryRequirement;
  }
  return accountsWorkspaceWriteRequirement;
}

bool accountsNextActionIsAllowed(
  AppAccessPolicy policy,
  AccountsWorkItem item,
) {
  return accountsNextActionRequirement(item).isAllowed(policy);
}

bool accountsSectionShowsNextActionColumn(
  AppAccessPolicy policy,
  AccountsDeskSection section,
) {
  return switch (section) {
    AccountsDeskSection.approvals => canDecideAccountsApproval(policy),
    AccountsDeskSection.ledgers =>
      canPayFromAccounts(policy) || canReadAccountsPatientLedgers(policy),
    AccountsDeskSection.work ||
    AccountsDeskSection.journals ||
    AccountsDeskSection.books ||
    AccountsDeskSection.gl =>
      canWriteAccounts(policy) || canDecideAccountsApproval(policy),
    // Account chart uses Actions for mutations — no work-queue Next column.
    AccountsDeskSection.chart => false,
  };
}

bool accountsApprovalsShowDecisionActions(AppAccessPolicy policy) {
  return canDecideAccountsApproval(policy);
}

bool accountsQueueShowsWriteActions(AppAccessPolicy policy) {
  return canWriteAccounts(policy);
}

bool accountsPatientLedgerShowsPay(AppAccessPolicy policy) {
  return canPayFromAccounts(policy);
}

bool accountsPatientLedgerShowsLedger(AppAccessPolicy policy) {
  return canReadAccountsPatientLedgers(policy);
}

/// Open work atom → permission mapping (accounts.md §9).
abstract final class AccountsOpenWorkAtomPermissions {
  static const AccessRequirement tab = accountsWorkspaceEntryRequirement;
  static const AccessRequirement listChrome = accountsWorkspaceEntryRequirement;
  static const AccessRequirement detail = accountsWorkspaceEntryRequirement;
  static const AccessRequirement journal = accountsWorkspaceWriteRequirement;
  static const AccessRequirement post = accountsWorkspaceWriteRequirement;
  static const AccessRequirement reverse = accountsWorkspaceWriteRequirement;
  static const AccessRequirement voidEntry = accountsWorkspaceWriteRequirement;
  static const AccessRequirement send = accountsWorkspaceWriteRequirement;
  static const AccessRequirement close = accountsWorkspaceWriteRequirement;
  static const AccessRequirement write = accountsWorkspaceWriteRequirement;
  static const AccessRequirement approve = accountsApprovalDecisionRequirement;
  static const AccessRequirement pay = accountsPayDeepLinkRequirement;
  static const AccessRequirement routeEntry = accountsWorkspaceEntryRequirement;
}

abstract final class AccountsToPostAtomPermissions {
  static const AccessRequirement tab = accountsWorkspaceEntryRequirement;
  static const AccessRequirement listChrome = accountsWorkspaceEntryRequirement;
  static const AccessRequirement detail = accountsWorkspaceEntryRequirement;
  static const AccessRequirement post = accountsWorkspaceWriteRequirement;
  static const AccessRequirement postAll = accountsWorkspaceWriteRequirement;
  static const AccessRequirement write = accountsWorkspaceWriteRequirement;
  static const AccessRequirement approve = accountsApprovalDecisionRequirement;
  static const AccessRequirement routeEntry = accountsWorkspaceEntryRequirement;
}

abstract final class AccountsNeedApprovalAtomPermissions {
  static const AccessRequirement tab = accountsWorkspaceEntryRequirement;
  static const AccessRequirement listChrome = accountsWorkspaceEntryRequirement;
  static const AccessRequirement detail = accountsWorkspaceEntryRequirement;
  static const AccessRequirement approve = accountsApprovalDecisionRequirement;
  static const AccessRequirement reject = accountsApprovalDecisionRequirement;
  static const AccessRequirement write = accountsWorkspaceWriteRequirement;
  static const AccessRequirement routeEntry = accountsWorkspaceEntryRequirement;
}

abstract final class AccountsGeneralLedgerAtomPermissions {
  static const AccessRequirement tab = accountsWorkspaceEntryRequirement;
  static const AccessRequirement listChrome = accountsWorkspaceEntryRequirement;
  static const AccessRequirement detail = accountsWorkspaceEntryRequirement;
  static const AccessRequirement journal = accountsWorkspaceWriteRequirement;
  static const AccessRequirement write = accountsWorkspaceWriteRequirement;
  static const AccessRequirement routeEntry = accountsWorkspaceEntryRequirement;
}

abstract final class AccountsPatientLedgersAtomPermissions {
  static const AccessRequirement tab = accountsPatientLedgersReadRequirement;
  static const AccessRequirement listChrome =
      accountsPatientLedgersReadRequirement;
  static const AccessRequirement detail = accountsPatientLedgersReadRequirement;
  static const AccessRequirement ledger = accountsPatientLedgersReadRequirement;
  static const AccessRequirement pay = accountsPayDeepLinkRequirement;
  static const AccessRequirement routeEntry = accountsWorkspaceEntryRequirement;
}

abstract final class AccountsChartAtomPermissions {
  static const AccessRequirement tab = accountsWorkspaceEntryRequirement;
  static const AccessRequirement listChrome = accountsWorkspaceEntryRequirement;
  static const AccessRequirement detail = accountsWorkspaceEntryRequirement;
  static const AccessRequirement create = accountsChartWriteRequirement;
  static const AccessRequirement update = accountsChartWriteRequirement;
  static const AccessRequirement deactivate = accountsChartWriteRequirement;
  static const AccessRequirement write = accountsChartWriteRequirement;
  static const AccessRequirement routeEntry = accountsWorkspaceEntryRequirement;
}

abstract final class AccountsCloseBooksAtomPermissions {
  static const AccessRequirement tab = accountsWorkspaceEntryRequirement;
  static const AccessRequirement listChrome = accountsWorkspaceEntryRequirement;
  static const AccessRequirement detail = accountsWorkspaceEntryRequirement;
  static const AccessRequirement openPeriod = accountsWorkspaceWriteRequirement;
  static const AccessRequirement closePeriod = accountsWorkspaceWriteRequirement;
  static const AccessRequirement write = accountsWorkspaceWriteRequirement;
  static const AccessRequirement approve = accountsApprovalDecisionRequirement;
  static const AccessRequirement routeEntry = accountsWorkspaceEntryRequirement;
}
