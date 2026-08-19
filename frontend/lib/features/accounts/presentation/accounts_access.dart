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

/// Worklist Export / desk list Print — ∩ `evidence:export` (omit when
/// unauthorized).
const AccessRequirement accountsWorkspaceExportRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.evidenceExport],
);

/// Alias — desk list Print uses the same export gate.
const AccessRequirement accountsWorkspacePrintRequirement =
    accountsWorkspaceExportRequirement;

bool canExportAccountsWorkspace(AppAccessPolicy policy) {
  return accountsWorkspaceExportRequirement.isAllowed(policy);
}

bool canPrintAccountsWorkspace(AppAccessPolicy policy) {
  return accountsWorkspacePrintRequirement.isAllowed(policy);
}

AccessRequirement accountsSectionTabRequirement(AccountsDeskSection section) {
  return switch (section) {
    AccountsDeskSection.ledgers => accountsPatientLedgersReadRequirement,
    // Setup & Controls is read-gated, not entry-gated: a write-only grant must
    // not surface the fiscal calendar or the cost-centre structure.
    AccountsDeskSection.fiscalYearsAndPeriods ||
    AccountsDeskSection.departmentsAndCostCentres ||
    AccountsDeskSection.paymentMethods ||
    AccountsDeskSection.documentNumbering =>
      accountsWorkspaceReadRequirement,
    _ => accountsWorkspaceEntryRequirement,
  };
}

/// A folder is visible when at least one of its leaf tabs is authorized.
bool canViewAccountsCategory(
  AppAccessPolicy policy,
  AccountsDeskCategory category,
) {
  return category.sections.any(
    (AccountsDeskSection section) => canViewAccountsSection(policy, section),
  );
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
    // To post Next is Post-only — omit the column without accounts:write.
    AccountsDeskSection.journals => canWriteAccounts(policy),
    AccountsDeskSection.work || AccountsDeskSection.gl =>
      canWriteAccounts(policy) ||
          canDecideAccountsApproval(policy) ||
          canEnterAccounts(policy),
    // Account chart / Invoices / Setup & Controls tabs use Actions — no
    // work-queue Next column.
    AccountsDeskSection.chart ||
    AccountsDeskSection.invoices ||
    AccountsDeskSection.fiscalYearsAndPeriods ||
    AccountsDeskSection.departmentsAndCostCentres ||
    AccountsDeskSection.paymentMethods ||
    AccountsDeskSection.documentNumbering => false,
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
  static const AccessRequirement filters = accountsWorkspaceEntryRequirement;
  static const AccessRequirement settings = accountsWorkspaceEntryRequirement;
  static const AccessRequirement export = accountsWorkspaceExportRequirement;
  static const AccessRequirement print = accountsWorkspacePrintRequirement;
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
  static const AccessRequirement filters = accountsWorkspaceEntryRequirement;
  static const AccessRequirement settings = accountsWorkspaceEntryRequirement;
  static const AccessRequirement export = accountsWorkspaceExportRequirement;
  static const AccessRequirement print = accountsWorkspacePrintRequirement;
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
  static const AccessRequirement filters = accountsWorkspaceEntryRequirement;
  static const AccessRequirement settings = accountsWorkspaceEntryRequirement;
  static const AccessRequirement export = accountsWorkspaceExportRequirement;
  static const AccessRequirement print = accountsWorkspacePrintRequirement;
  static const AccessRequirement approve = accountsApprovalDecisionRequirement;
  static const AccessRequirement reject = accountsApprovalDecisionRequirement;
  static const AccessRequirement write = accountsWorkspaceWriteRequirement;
  static const AccessRequirement routeEntry = accountsWorkspaceEntryRequirement;
}

abstract final class AccountsGeneralLedgerAtomPermissions {
  static const AccessRequirement tab = accountsWorkspaceEntryRequirement;
  static const AccessRequirement listChrome = accountsWorkspaceEntryRequirement;
  static const AccessRequirement detail = accountsWorkspaceEntryRequirement;
  static const AccessRequirement filters = accountsWorkspaceEntryRequirement;
  static const AccessRequirement settings = accountsWorkspaceEntryRequirement;
  static const AccessRequirement export = accountsWorkspaceExportRequirement;
  static const AccessRequirement print = accountsWorkspacePrintRequirement;
  static const AccessRequirement journal = accountsWorkspaceWriteRequirement;
  static const AccessRequirement write = accountsWorkspaceWriteRequirement;
  static const AccessRequirement routeEntry = accountsWorkspaceEntryRequirement;
}

abstract final class AccountsPatientLedgersAtomPermissions {
  static const AccessRequirement tab = accountsPatientLedgersReadRequirement;
  static const AccessRequirement listChrome =
      accountsPatientLedgersReadRequirement;
  static const AccessRequirement detail = accountsPatientLedgersReadRequirement;
  static const AccessRequirement filters = accountsPatientLedgersReadRequirement;
  static const AccessRequirement settings = accountsPatientLedgersReadRequirement;
  static const AccessRequirement export = accountsWorkspaceExportRequirement;
  static const AccessRequirement print = accountsWorkspacePrintRequirement;
  static const AccessRequirement ledger = accountsPatientLedgersReadRequirement;
  static const AccessRequirement pay = accountsPayDeepLinkRequirement;
  static const AccessRequirement routeEntry = accountsWorkspaceEntryRequirement;
}

abstract final class AccountsChartAtomPermissions {
  static const AccessRequirement tab = accountsWorkspaceEntryRequirement;
  static const AccessRequirement listChrome = accountsWorkspaceEntryRequirement;
  static const AccessRequirement detail = accountsWorkspaceEntryRequirement;
  static const AccessRequirement filters = accountsWorkspaceEntryRequirement;
  static const AccessRequirement settings = accountsWorkspaceEntryRequirement;
  static const AccessRequirement export = accountsWorkspaceExportRequirement;
  static const AccessRequirement print = accountsWorkspacePrintRequirement;
  static const AccessRequirement create = accountsChartWriteRequirement;
  static const AccessRequirement update = accountsChartWriteRequirement;
  static const AccessRequirement deactivate = accountsChartWriteRequirement;
  static const AccessRequirement write = accountsChartWriteRequirement;
  static const AccessRequirement routeEntry = accountsWorkspaceEntryRequirement;
}

/// Setup & Controls → Fiscal Years & Periods atom → permission mapping
/// (`.cursor/finance/accounts-and-finance/setup-and-controls/fiscal-years-and-periods.md`).
abstract final class AccountsFiscalPeriodsAtomPermissions {
  static const AccessRequirement tab = accountsWorkspaceReadRequirement;
  static const AccessRequirement listChrome = accountsWorkspaceReadRequirement;
  static const AccessRequirement detail = accountsWorkspaceReadRequirement;
  static const AccessRequirement filters = accountsWorkspaceReadRequirement;
  static const AccessRequirement settings = accountsWorkspaceReadRequirement;
  static const AccessRequirement export = accountsWorkspaceExportRequirement;
  static const AccessRequirement print = accountsWorkspacePrintRequirement;
  static const AccessRequirement create = accountsWorkspaceWriteRequirement;
  static const AccessRequirement update = accountsWorkspaceWriteRequirement;
  static const AccessRequirement clone = accountsWorkspaceWriteRequirement;
  static const AccessRequirement activate = accountsWorkspaceWriteRequirement;
  static const AccessRequirement deactivate = accountsWorkspaceWriteRequirement;
  static const AccessRequirement archive = accountsWorkspaceWriteRequirement;
  static const AccessRequirement restore = accountsWorkspaceWriteRequirement;
  static const AccessRequirement write = accountsWorkspaceWriteRequirement;
  static const AccessRequirement approve = accountsApprovalDecisionRequirement;
  static const AccessRequirement routeEntry = accountsWorkspaceReadRequirement;
}

/// Fiscal Years & Periods mutations — `accounts:write` ∩ `facility-accounts`.
bool canWriteAccountsFiscalPeriods(AppAccessPolicy policy) {
  return AccountsFiscalPeriodsAtomPermissions.write.isAllowed(policy);
}

/// Setup & Controls → Departments & Cost Centres atom → permission mapping
/// (`.cursor/finance/accounts-and-finance/setup-and-controls/departments-and-cost-centres.md`).
abstract final class AccountsDepartmentsAtomPermissions {
  static const AccessRequirement tab = accountsWorkspaceReadRequirement;
  static const AccessRequirement listChrome = accountsWorkspaceReadRequirement;
  static const AccessRequirement detail = accountsWorkspaceReadRequirement;
  static const AccessRequirement filters = accountsWorkspaceReadRequirement;
  static const AccessRequirement settings = accountsWorkspaceReadRequirement;
  static const AccessRequirement export = accountsWorkspaceExportRequirement;
  static const AccessRequirement print = accountsWorkspacePrintRequirement;
  static const AccessRequirement create = accountsWorkspaceWriteRequirement;
  static const AccessRequirement update = accountsWorkspaceWriteRequirement;
  static const AccessRequirement clone = accountsWorkspaceWriteRequirement;
  static const AccessRequirement activate = accountsWorkspaceWriteRequirement;
  static const AccessRequirement deactivate = accountsWorkspaceWriteRequirement;
  static const AccessRequirement archive = accountsWorkspaceWriteRequirement;
  static const AccessRequirement restore = accountsWorkspaceWriteRequirement;
  static const AccessRequirement write = accountsWorkspaceWriteRequirement;
  static const AccessRequirement approve = accountsApprovalDecisionRequirement;
  static const AccessRequirement routeEntry = accountsWorkspaceReadRequirement;
}

/// Departments & Cost Centres mutations — `accounts:write` ∩ `facility-accounts`.
bool canWriteAccountsDepartments(AppAccessPolicy policy) {
  return AccountsDepartmentsAtomPermissions.write.isAllowed(policy);
}

/// Setup & Controls → Payment Methods atom → permission mapping
/// (`.cursor/finance/accounts-and-finance/setup-and-controls/payment-methods.md`).
abstract final class AccountsPaymentMethodsAtomPermissions {
  static const AccessRequirement tab = accountsWorkspaceReadRequirement;
  static const AccessRequirement listChrome = accountsWorkspaceReadRequirement;
  static const AccessRequirement detail = accountsWorkspaceReadRequirement;
  static const AccessRequirement filters = accountsWorkspaceReadRequirement;
  static const AccessRequirement settings = accountsWorkspaceReadRequirement;
  static const AccessRequirement export = accountsWorkspaceExportRequirement;
  static const AccessRequirement print = accountsWorkspacePrintRequirement;
  static const AccessRequirement create = accountsWorkspaceWriteRequirement;
  static const AccessRequirement update = accountsWorkspaceWriteRequirement;
  static const AccessRequirement clone = accountsWorkspaceWriteRequirement;
  static const AccessRequirement activate = accountsWorkspaceWriteRequirement;
  static const AccessRequirement deactivate = accountsWorkspaceWriteRequirement;
  static const AccessRequirement archive = accountsWorkspaceWriteRequirement;
  static const AccessRequirement restore = accountsWorkspaceWriteRequirement;
  static const AccessRequirement write = accountsWorkspaceWriteRequirement;
  static const AccessRequirement approve = accountsApprovalDecisionRequirement;
  static const AccessRequirement routeEntry = accountsWorkspaceReadRequirement;
}

/// Payment Methods mutations — `accounts:write` ∩ `facility-accounts`.
bool canWriteAccountsPaymentMethods(AppAccessPolicy policy) {
  return AccountsPaymentMethodsAtomPermissions.write.isAllowed(policy);
}

/// Setup & Controls → Document Numbering atom → permission mapping
/// (`.cursor/finance/accounts-and-finance/setup-and-controls/document-numbering.md`).
abstract final class AccountsDocumentNumberingAtomPermissions {
  static const AccessRequirement tab = accountsWorkspaceReadRequirement;
  static const AccessRequirement listChrome = accountsWorkspaceReadRequirement;
  static const AccessRequirement detail = accountsWorkspaceReadRequirement;
  static const AccessRequirement filters = accountsWorkspaceReadRequirement;
  static const AccessRequirement settings = accountsWorkspaceReadRequirement;
  static const AccessRequirement export = accountsWorkspaceExportRequirement;
  static const AccessRequirement print = accountsWorkspacePrintRequirement;
  static const AccessRequirement create = accountsWorkspaceWriteRequirement;
  static const AccessRequirement update = accountsWorkspaceWriteRequirement;
  static const AccessRequirement clone = accountsWorkspaceWriteRequirement;
  static const AccessRequirement activate = accountsWorkspaceWriteRequirement;
  static const AccessRequirement deactivate = accountsWorkspaceWriteRequirement;
  static const AccessRequirement archive = accountsWorkspaceWriteRequirement;
  static const AccessRequirement restore = accountsWorkspaceWriteRequirement;
  static const AccessRequirement write = accountsWorkspaceWriteRequirement;
  static const AccessRequirement approve = accountsApprovalDecisionRequirement;
  static const AccessRequirement routeEntry = accountsWorkspaceReadRequirement;
}

/// Document Numbering mutations — `accounts:write` ∩ `facility-accounts`.
bool canWriteAccountsDocumentSequences(AppAccessPolicy policy) {
  return AccountsDocumentNumberingAtomPermissions.write.isAllowed(policy);
}

abstract final class AccountsInvoicesAtomPermissions {
  static const AccessRequirement tab = accountsWorkspaceEntryRequirement;
  static const AccessRequirement listChrome = accountsWorkspaceEntryRequirement;
  static const AccessRequirement detail = accountsWorkspaceEntryRequirement;
  static const AccessRequirement filters = accountsWorkspaceEntryRequirement;
  static const AccessRequirement settings = accountsWorkspaceEntryRequirement;
  static const AccessRequirement export = accountsWorkspaceExportRequirement;
  static const AccessRequirement print = accountsWorkspacePrintRequirement;
  static const AccessRequirement create = accountsWorkspaceWriteRequirement;
  static const AccessRequirement update = accountsWorkspaceWriteRequirement;
  static const AccessRequirement voidInvoice = accountsWorkspaceWriteRequirement;
  static const AccessRequirement write = accountsWorkspaceWriteRequirement;
  static const AccessRequirement routeEntry = accountsWorkspaceEntryRequirement;
}
