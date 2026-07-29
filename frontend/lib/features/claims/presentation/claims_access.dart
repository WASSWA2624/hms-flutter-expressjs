import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/features/claims/domain/entities/claims_entities.dart';

/// Module entitlement for the claims workspace route and tabs.
const String claimsInsuranceClaimsModule = 'insurance-claims';

/// View / read UI (matrix ∩ `billing:read`).
const AccessRequirement claimsWorkspaceReadRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.billingRead],
  activeModules: <String>[claimsInsuranceClaimsModule],
);

/// Alias used by tab atom maps / prompts.
const AccessRequirement claimsReadRequirement = claimsWorkspaceReadRequirement;

/// Insurance Setup tab visibility (matrix ∪):
/// `billing:read` | `facility:admin` | `tenant:admin`.
const AccessRequirement claimsInsuranceSetupReadAnyRequirement =
    AccessRequirement(
      anyPermissions: <AppPermission>[
        AppPermissions.billingRead,
        AppPermissions.facilityAdmin,
        AppPermissions.tenantAdmin,
      ],
      activeModules: <String>[claimsInsuranceClaimsModule],
    );

/// Route entry (∪): `billing:read` | `billing:write` | `financial:approve` —
/// matches [AppRoutes.claims] `requiredAnyPermissions`.
const AccessRequirement claimsWorkspaceEntryRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.billingRead,
    AppPermissions.billingWrite,
    AppPermissions.financialApprove,
  ],
  activeModules: <String>[claimsInsuranceClaimsModule],
);

/// Create / update / delete mutations (matrix ∩ `billing:write`).
///
/// Source inventory (`screens/claims.md`) documents
/// [claimsWorkspaceWriteRequirement] for Insurance Setup creates — keep that
/// helper; matrix ∩ is a single key so `allPermissions` matches semantics.
const AccessRequirement claimsWorkspaceWriteRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.billingWrite],
  activeModules: <String>[claimsInsuranceClaimsModule],
);

/// Alias used by tab atom maps / prompts.
const AccessRequirement claimsWriteRequirement = claimsWorkspaceWriteRequirement;

/// Financial approve access for settlement and close operations.
const AccessRequirement claimsFinancialApproveRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.financialApprove],
  activeModules: <String>[claimsInsuranceClaimsModule],
);

/// Per-desk-section tab strip gate.
///
/// Authorizations / Active Claims / Settled use matrix ∩ `billing:read`.
/// Insurance Setup uses the matrix ∪ read row (billing read | facility/tenant
/// admin).
AccessRequirement claimsDeskSectionRequirement(ClaimsDeskSection section) {
  return switch (section) {
    ClaimsDeskSection.insuranceSetup =>
      claimsInsuranceSetupReadAnyRequirement,
    ClaimsDeskSection.authorizations ||
    ClaimsDeskSection.activeClaims ||
    ClaimsDeskSection.settled =>
      claimsWorkspaceReadRequirement,
  };
}

bool canReadClaims(AppAccessPolicy policy) {
  return claimsWorkspaceReadRequirement.isAllowed(policy);
}

bool canReadClaimsInsuranceSetup(AppAccessPolicy policy) {
  return claimsInsuranceSetupReadAnyRequirement.isAllowed(policy);
}

bool canWriteClaims(AppAccessPolicy policy) {
  return claimsWorkspaceWriteRequirement.isAllowed(policy);
}

bool canApproveClaimsFinancial(AppAccessPolicy policy) {
  return claimsFinancialApproveRequirement.isAllowed(policy);
}

/// Alias used by Active Claims settlement / close-as-paid gates.
bool canApproveClaimsSettlement(AppAccessPolicy policy) {
  return canApproveClaimsFinancial(policy);
}

bool canViewClaimsDeskSection(
  AppAccessPolicy policy,
  ClaimsDeskSection section,
) {
  return claimsDeskSectionRequirement(section).isAllowed(policy);
}

/// Alias used by Authorizations tab helpers / prompts.
bool canViewClaimsSection(AppAccessPolicy policy, ClaimsDeskSection section) {
  return canViewClaimsDeskSection(policy, section);
}

/// Print statement on Authorizations / Active Claims is read chrome
/// (inventory: always when detail is open → [claimsWorkspaceReadRequirement]).
bool canReadClaimsDocument(AppAccessPolicy policy) {
  return canReadClaims(policy);
}

/// Nested cross-module export / print on Settled (matrix ∪):
/// `reports:read` | `evidence:export`.
///
/// Inventory says Print is always when detail is open; Settled matrix maps
/// exports to this nested union — keep the matrix and note the mapping in tests.
const AccessRequirement claimsNestedExportRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.reportsRead,
    AppPermissions.evidenceExport,
  ],
  activeModules: <String>[claimsInsuranceClaimsModule],
);

/// Alias used by Settled atom map / prompts.
const AccessRequirement claimsSettledExportRequirement =
    claimsNestedExportRequirement;

bool canExportClaimsSettledDocument(AppAccessPolicy policy) {
  return claimsNestedExportRequirement.isAllowed(policy);
}

/// Print gate for the detail dialog opened from [section].
///
/// Authorizations / Active Claims reuse the tab [document] read ∩ helper.
/// Settled uses nested export ∪ ([ClaimsSettledAtomPermissions.export]).
AccessRequirement claimsDetailPrintRequirement(ClaimsDeskSection section) {
  return switch (section) {
    ClaimsDeskSection.settled => ClaimsSettledAtomPermissions.export,
    ClaimsDeskSection.authorizations =>
      ClaimsAuthorizationsAtomPermissions.document,
    ClaimsDeskSection.activeClaims =>
      ClaimsActiveClaimsAtomPermissions.document,
    ClaimsDeskSection.insuranceSetup => claimsWorkspaceReadRequirement,
  };
}

/// Requirement for the labeled next-action on a queue item.
AccessRequirement claimsNextActionRequirement(ClaimsQueueItem item) {
  if (item.isAuthorization) {
    return claimsWorkspaceWriteRequirement;
  }
  // Closing / settling an approved claim requires financial approval.
  if (item.status.toUpperCase() == 'APPROVED') {
    return claimsFinancialApproveRequirement;
  }
  return claimsWorkspaceWriteRequirement;
}

bool claimsNextActionIsAllowed(
  AppAccessPolicy policy,
  ClaimsQueueItem item,
) {
  return claimsNextActionRequirement(item).isAllowed(policy);
}

/// Progressive-disclosure chrome for Active Claims next-action column /
/// mobile trailing: write ∪ financial:approve (inventory + matrix).
const AccessRequirement claimsActiveClaimsNextActionColumnRequirement =
    AccessRequirement(
      anyPermissions: <AppPermission>[
        AppPermissions.billingWrite,
        AppPermissions.financialApprove,
      ],
      activeModules: <String>[claimsInsuranceClaimsModule],
    );

/// Whether the Next action column / mobile trailing mounts for [section].
bool claimsSectionShowsNextActionColumn(
  AppAccessPolicy policy,
  ClaimsDeskSection section,
) {
  return switch (section) {
    ClaimsDeskSection.settled ||
    ClaimsDeskSection.insuranceSetup => false,
    ClaimsDeskSection.authorizations => canWriteClaims(policy),
    ClaimsDeskSection.activeClaims =>
      claimsActiveClaimsNextActionColumnRequirement.isAllowed(policy),
  };
}

/// Authorizations tab atom → permission mapping (inventory + matrix).
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Authorizations tab | navigate | read ∩ `billing:read` |
/// | Request authorization (strip primary) | create | write ∩ `billing:write` |
/// | Summary chips (Auth pending / approved / Denied / Expired) | read chrome | read ∩ |
/// | Search / Clear / Settings (columns) | read chrome | read ∩ |
/// | Empty / error / retry | read chrome | read ∩ |
/// | Row select → detail | read | read ∩ |
/// | Print statement | export / read | document read ∩ |
/// | Next action Update status | update | write ∩ |
/// | Nested Request authorization dialog | create | write ∩ |
/// | Nested Update authorization dialog | update | write ∩ |
/// | Deep link `action=preauth` | create | write ∩ |
/// | Route entry (deep link) | navigate | read ∪ write ∪ financial:approve |
///
/// Nested cross-module matrix rows are _(n/a)_ for this tab. Settlement /
/// close-as-paid lives on Active Claims and uses [approve].
abstract final class ClaimsAuthorizationsAtomPermissions {
  static const AccessRequirement tab = claimsWorkspaceReadRequirement;
  static const AccessRequirement listChrome = claimsWorkspaceReadRequirement;
  static const AccessRequirement detail = claimsWorkspaceReadRequirement;
  static const AccessRequirement create = claimsWorkspaceWriteRequirement;
  static const AccessRequirement update = claimsWorkspaceWriteRequirement;
  static const AccessRequirement delete = claimsWorkspaceWriteRequirement;
  static const AccessRequirement write = claimsWorkspaceWriteRequirement;
  static const AccessRequirement requestAuthorization =
      claimsWorkspaceWriteRequirement;
  static const AccessRequirement nextAction = claimsWorkspaceWriteRequirement;
  static const AccessRequirement approve = claimsFinancialApproveRequirement;
  static const AccessRequirement document = claimsWorkspaceReadRequirement;
  static const AccessRequirement entry = claimsWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry = claimsWorkspaceEntryRequirement;
}

/// Active Claims tab atom → permission mapping (inventory + matrix).
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Active Claims tab | navigate | read ∩ `billing:read` |
/// | Summary chips (Submitted / Approved / Partial / Rejected) | read chrome | read ∩ |
/// | Search / Clear / column Settings | read chrome | read ∩ |
/// | Empty / error / retry | read chrome | read ∩ |
/// | Row select → detail | read | read ∩ |
/// | Prepare claim (tab-strip primary) | create | write ∩ `billing:write` |
/// | Next action Submit / Resubmit / Record response | update | write ∩ |
/// | Next action Close as paid | approve | financial:approve ∩ |
/// | Detail Sync insurer status | update | write ∩ |
/// | Print statement | export / read | read ∩ |
/// | Nested prepare / submit / record dialogs | create / update | write ∩ |
/// | Nested close-as-paid dialog | approve | financial:approve ∩ |
/// | Route entry (deep link) | navigate | read ∪ write ∪ financial:approve |
/// | Next-action column chrome | progressive disclosure | write ∪ approve |
///
/// Nested cross-module matrix rows are _(n/a)_ — no Settled-style export ∪
/// on this tab. Settlement uses [claimsFinancialApproveRequirement] (source
/// inventory), not write alone. Column chrome uses
/// [claimsActiveClaimsNextActionColumnRequirement] (∪); per-row buttons still
/// use [claimsNextActionRequirement].
abstract final class ClaimsActiveClaimsAtomPermissions {
  static const AccessRequirement tab = claimsWorkspaceReadRequirement;
  static const AccessRequirement listChrome = claimsWorkspaceReadRequirement;
  static const AccessRequirement detail = claimsWorkspaceReadRequirement;
  static const AccessRequirement create = claimsWorkspaceWriteRequirement;
  static const AccessRequirement update = claimsWorkspaceWriteRequirement;
  static const AccessRequirement delete = claimsWorkspaceWriteRequirement;
  static const AccessRequirement write = claimsWorkspaceWriteRequirement;
  static const AccessRequirement prepare = claimsWorkspaceWriteRequirement;
  static const AccessRequirement submit = claimsWorkspaceWriteRequirement;
  static const AccessRequirement resubmit = claimsWorkspaceWriteRequirement;
  static const AccessRequirement recordResponse = claimsWorkspaceWriteRequirement;
  static const AccessRequirement sync = claimsWorkspaceWriteRequirement;
  static const AccessRequirement approve = claimsFinancialApproveRequirement;
  static const AccessRequirement closeAsPaid = claimsFinancialApproveRequirement;
  static const AccessRequirement nextActionColumn =
      claimsActiveClaimsNextActionColumnRequirement;
  static const AccessRequirement document = claimsWorkspaceReadRequirement;
  static const AccessRequirement entry = claimsWorkspaceEntryRequirement;
  static const AccessRequirement routeEntry = claimsWorkspaceEntryRequirement;
}

/// Settled tab atom → permission mapping (inventory + matrix).
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Settled tab | navigate | read ∩ `billing:read` |
/// | Tab-strip primary / Refresh | _(absent — review-only)_ | — |
/// | Summary chips | _(absent on Settled)_ | — |
/// | Search / Clear / column Settings | read chrome | read ∩ |
/// | Advanced Filters (Paid / Cancelled) | read chrome | read ∩ |
/// | Empty / error / retry / loading | read chrome | read ∩ |
/// | Row select → detail | read | read ∩ |
/// | Next action / Sync / Prepare / Request auth | _(absent)_ | — |
/// | Print statement | export | nested ∪ `reports:read` \| `evidence:export` |
/// | Create / update / delete (matrix verbs) | mutate | write ∩ (no Settled entry) |
/// | Approve / close-as-paid | approve | financial:approve ∩ (Active Claims) |
/// | Route entry (deep link) | navigate | read ∪ write ∪ financial:approve |
///
/// Inventory documents Print as always when detail is open; Settled matrix
/// maps nested cross-module read/export to [export] (∪). Write/approve atoms
/// reuse feature helpers for matrix completeness — Settled UI does not mount them.
/// Detail Sync is section-gated off Settled even if status were non-terminal.
abstract final class ClaimsSettledAtomPermissions {
  static const AccessRequirement tab = claimsWorkspaceReadRequirement;
  static const AccessRequirement listChrome = claimsWorkspaceReadRequirement;
  static const AccessRequirement detail = claimsWorkspaceReadRequirement;
  static const AccessRequirement create = claimsWorkspaceWriteRequirement;
  static const AccessRequirement update = claimsWorkspaceWriteRequirement;
  static const AccessRequirement delete = claimsWorkspaceWriteRequirement;
  static const AccessRequirement write = claimsWorkspaceWriteRequirement;
  static const AccessRequirement approve = claimsFinancialApproveRequirement;
  static const AccessRequirement export = claimsNestedExportRequirement;
  static const AccessRequirement document = claimsNestedExportRequirement;
  static const AccessRequirement nestedRead = claimsNestedExportRequirement;
  static const AccessRequirement routeEntry = claimsWorkspaceEntryRequirement;
}

/// Insurance Setup tab atom → permission mapping (inventory + matrix).
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Insurance Setup tab | navigate | read ∪ |
/// | Description panel | read chrome | read ∪ |
/// | Empty create strip (collapsed) | progressive disclosure | write ∩ |
/// | Add company / scheme / offer | create | write ∩ |
/// | Enroll patient | create | write ∩ |
/// | Add price book entry | create | write ∩ |
/// | Insurer API integration | create | write ∩ |
/// | Nested catalog create dialogs | create | write ∩ (+ opener gate) |
/// | Tab-strip primary / Refresh | _(absent on this tab)_ | — |
/// | Queue search / filters / rows | _(absent on this tab)_ | — |
/// | Nested cross-module | _(n/a)_ | — |
/// | Route entry (deep link) | navigate | entry ∪ |
///
/// Matrix read ∩ (`billing:read`) is [read]. Tab visibility uses [tab] (∪) so
/// facility/tenant admins without `billing:read` still see setup chrome.
/// Catalog edits reuse [claimsWorkspaceWriteRequirement] (source inventory);
/// dialog openers also check [create] before mounting.
abstract final class ClaimsInsuranceSetupAtomPermissions {
  static const AccessRequirement tab =
      claimsInsuranceSetupReadAnyRequirement;
  static const AccessRequirement listChrome =
      claimsInsuranceSetupReadAnyRequirement;
  static const AccessRequirement detail =
      claimsInsuranceSetupReadAnyRequirement;
  static const AccessRequirement read = claimsWorkspaceReadRequirement;
  static const AccessRequirement create = claimsWorkspaceWriteRequirement;
  static const AccessRequirement update = claimsWorkspaceWriteRequirement;
  static const AccessRequirement delete = claimsWorkspaceWriteRequirement;
  static const AccessRequirement write = claimsWorkspaceWriteRequirement;
  static const AccessRequirement routeEntry = claimsWorkspaceEntryRequirement;
}
