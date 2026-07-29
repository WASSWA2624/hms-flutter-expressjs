import 'package:hosspi_hms/core/permissions/access_policy.dart';
import 'package:hosspi_hms/core/permissions/access_requirement.dart';
import 'package:hosspi_hms/core/permissions/app_permission.dart';
import 'package:hosspi_hms/core/permissions/route_access_catalog.dart';
import 'package:hosspi_hms/features/billing/presentation/billing_access.dart';
import 'package:hosspi_hms/features/pharmacy/domain/entities/pharmacy_entities.dart';

/// Module entitlement for the pharmacy workspace route and worklists.
const String pharmacyDispensingModule = 'pharmacy-dispensing';

/// Alias used by tests and newer call sites.
const String pharmacyActiveModule = pharmacyDispensingModule;

/// View / read UI (matrix ∩ `pharmacy:read`).
const AccessRequirement pharmacyWorkspaceReadRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.pharmacyRead],
  activeModules: <String>[pharmacyDispensingModule],
);

/// Alias used by tab atom maps / prompts.
const AccessRequirement pharmacyReadRequirement =
    pharmacyWorkspaceReadRequirement;

/// Create / update / delete / dispense / attest / return / cancel (matrix ∩
/// `pharmacy:write`).
///
/// Source inventory (`screens/pharmacy.md`) `_writeRequirement` used
/// `anyPermissions: [pharmacyWrite]` — equivalent for a single key; prefer ∩
/// `allPermissions` to match the matrix.
const AccessRequirement pharmacyWorkspaceWriteRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.pharmacyWrite],
  activeModules: <String>[pharmacyDispensingModule],
);

/// Alias matching historical `_writeRequirement` / `AppAccessActionGate`.
const AccessRequirement pharmacyWriteRequirement =
    pharmacyWorkspaceWriteRequirement;

/// Alias used by tab atom maps / prompts.
const AccessRequirement pharmacyMutationRequirement =
    pharmacyWorkspaceWriteRequirement;

/// Catalog / stock nested CRUD.
///
/// Matrix narrative defaults to ∩ `pharmacy:write`. Source catalog panel
/// (`pharmacy_catalog_panel.dart`) documents ∪ `pharmacy:write` |
/// `operations:write` — keep that gate and map it in tests.
const AccessRequirement pharmacyCatalogWriteRequirement = AccessRequirement(
  anyPermissions: <AppPermission>[
    AppPermissions.pharmacyWrite,
    AppPermissions.operationsWrite,
  ],
  activeModules: <String>[pharmacyDispensingModule],
);

/// Catalog browse / open dialog (matrix ∩ `pharmacy:read`).
const AccessRequirement pharmacyCatalogBrowseRequirement =
    pharmacyWorkspaceReadRequirement;

/// Record / confirm payment from pharmacy (matrix nested: ∩ `billing:write`).
///
/// Reuses [billingWorkspaceWriteRequirement] (`billing-payments`).
const AccessRequirement pharmacyRecordPaymentRequirement =
    billingWorkspaceWriteRequirement;

/// Pending-payment / billing status visibility (matrix narrative ∩
/// `billing:read`). All-orders status column stays pharmacy-read; payment
/// column on Pending payment uses this when gated.
const AccessRequirement pharmacyBillingStatusReadRequirement =
    billingWorkspaceReadRequirement;

/// Controlled-drug audit panels (matrix narrative ∩ `pharmacy:read` +
/// `compliance:read`). No dedicated chrome on All orders today; documented for
/// reuse when audit panels mount.
const AccessRequirement pharmacyControlledDrugAuditRequirement =
    AccessRequirement(
      allPermissions: <AppPermission>[
        AppPermissions.pharmacyRead,
        AppPermissions.complianceRead,
      ],
      activeModules: <String>[pharmacyDispensingModule],
    );

/// Print medication instructions (inventory: not write-gated; ∩ `pharmacy:read`).
const AccessRequirement pharmacyPrintInstructionsRequirement =
    pharmacyWorkspaceReadRequirement;

/// Navigation catalog entry — ∩ `pharmacy:read`
/// ([RouteAccessCatalog.pharmacyEntry]).
const AccessRequirement pharmacyWorkspaceCatalogEntryRequirement =
    RouteAccessCatalog.pharmacyEntry;

/// Route entry matching [AppRoutes.pharmacy] ∪ `pharmacy:read` |
/// `operations:read` plus `pharmacy-dispensing`.
const AccessRequirement pharmacyWorkspaceRouteEntryRequirement =
    AccessRequirement(
      anyPermissions: <AppPermission>[
        AppPermissions.pharmacyRead,
        AppPermissions.operationsRead,
      ],
      activeModules: <String>[pharmacyDispensingModule],
    );

/// Alias used by atom maps for deep-link / shell entry.
const AccessRequirement pharmacyWorkspaceEntryRequirement =
    pharmacyWorkspaceRouteEntryRequirement;

/// Per-section tab strip gate.
///
/// Worklist tabs (Ready / Partial / Pending payment / Completed / All orders)
/// share ∩ `pharmacy:read` + `pharmacy-dispensing`.
AccessRequirement pharmacySectionTabRequirement(PharmacyDeskSection section) {
  return switch (section) {
    PharmacyDeskSection.allOrders => PharmacyAllOrdersAtomPermissions.tab,
    PharmacyDeskSection.queue ||
    PharmacyDeskSection.inProgress ||
    PharmacyDeskSection.pendingPayment ||
    PharmacyDeskSection.completed => pharmacyWorkspaceReadRequirement,
  };
}

bool canEnterPharmacyWorkspace(AppAccessPolicy policy) {
  return pharmacyWorkspaceRouteEntryRequirement.isAllowed(policy);
}

bool canReadPharmacy(AppAccessPolicy policy) {
  return pharmacyWorkspaceReadRequirement.isAllowed(policy);
}

bool canWritePharmacy(AppAccessPolicy policy) {
  return pharmacyWorkspaceWriteRequirement.isAllowed(policy);
}

bool canBrowsePharmacyCatalog(AppAccessPolicy policy) {
  return pharmacyCatalogBrowseRequirement.isAllowed(policy);
}

bool canWritePharmacyCatalog(AppAccessPolicy policy) {
  return pharmacyCatalogWriteRequirement.isAllowed(policy);
}

bool canRecordPharmacyPayment(AppAccessPolicy policy) {
  return pharmacyRecordPaymentRequirement.isAllowed(policy);
}

bool canReadPharmacyBillingStatus(AppAccessPolicy policy) {
  return pharmacyBillingStatusReadRequirement.isAllowed(policy);
}

bool canViewPharmacyControlledDrugAudit(AppAccessPolicy policy) {
  return pharmacyControlledDrugAuditRequirement.isAllowed(policy);
}

bool canPrintPharmacyInstructions(AppAccessPolicy policy) {
  return pharmacyPrintInstructionsRequirement.isAllowed(policy);
}

bool canViewPharmacySection(AppAccessPolicy policy, PharmacyDeskSection section) {
  return pharmacySectionTabRequirement(section).isAllowed(policy);
}

/// Sections the user may open.
///
/// Matrix tab read is ∩ `pharmacy:read`. Route-only operations readers
/// (`operations:read` without `pharmacy:read`) may still open `/pharmacy` via
/// [pharmacyWorkspaceRouteEntryRequirement] and see worklist chrome read-only —
/// they must not see write / catalog CRUD ([canWritePharmacy]).
List<PharmacyDeskSection> pharmacyAllowedSections(AppAccessPolicy policy) {
  final List<PharmacyDeskSection> byRead = PharmacyDeskSection.values
      .where(
        (PharmacyDeskSection section) => canViewPharmacySection(policy, section),
      )
      .toList(growable: false);
  if (byRead.isNotEmpty) {
    return byRead;
  }
  if (!canEnterPharmacyWorkspace(policy)) {
    return const <PharmacyDeskSection>[];
  }
  // Route ∪ without pharmacy:read: keep worklist tabs read-only.
  return PharmacyDeskSection.values.toList(growable: false);
}

PharmacyDeskSection? pharmacyFallbackSection(AppAccessPolicy policy) {
  final List<PharmacyDeskSection> allowed = pharmacyAllowedSections(policy);
  if (allowed.isEmpty) {
    return null;
  }
  if (allowed.contains(PharmacyDeskSection.queue)) {
    return PharmacyDeskSection.queue;
  }
  return allowed.first;
}

/// Atom → requirement map for Pharmacy All orders (`/pharmacy?section=all`).
///
/// Inventory: `screens/pharmacy.md` → All orders tab (unfiltered worklist;
/// Catalog and stock primary). Nested cross-module matrix rows are _(n/a)_ for
/// strip chrome; payment recording reuses billing write ∩; catalog CRUD keeps
/// source ∪ `pharmacy:write`|`operations:write`. Controlled-drug audit ∩ is
/// [controlledDrugAudit] (no dedicated chrome on All today).
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | All orders strip tab / count | navigate | read ∩ `pharmacy:read` |
/// | Catalog and stock (primary) | navigate / read | browse ∩ `pharmacy:read` |
/// | Search / Clear / Filters / Settings / pagination | read chrome | read ∩ |
/// | Empty / loading / error / retry | read chrome | read ∩ |
/// | Success snackbar / validation (authorized) | visible feedback | write ∩ |
/// | Row select → prescription detail | read / navigate | read ∩ |
/// | Next action (view details) | progressive disclosure | read ∩ |
/// | Next action dispense / attest / return / cancel | update / delete | write ∩ |
/// | Next action record / confirm payment | update | billing write ∩ |
/// | Detail Record payment | update | billing write ∩ |
/// | Detail Dispense / Attest / Return / Cancel | update / delete | write ∩ |
/// | Detail Print instructions | export / read | print ∩ `pharmacy:read` |
/// | Line Map stock / price source | update | write ∩ |
/// | Nested catalog CRUD (drugs / formulary / stock / storage) | create / update / delete | catalog write ∪ |
/// | Controlled-drug audit (narrative ∩) | read | pharmacy:read ∩ compliance:read |
/// | Route entry (deep link) | navigate | ∪ pharmacy\|operations read |
abstract final class PharmacyAllOrdersAtomPermissions {
  static const AccessRequirement tab = pharmacyWorkspaceReadRequirement;
  static const AccessRequirement listChrome = pharmacyWorkspaceReadRequirement;
  static const AccessRequirement search = pharmacyWorkspaceReadRequirement;
  static const AccessRequirement filters = pharmacyWorkspaceReadRequirement;
  static const AccessRequirement settings = pharmacyWorkspaceReadRequirement;
  static const AccessRequirement pagination = pharmacyWorkspaceReadRequirement;
  static const AccessRequirement empty = pharmacyWorkspaceReadRequirement;
  static const AccessRequirement loading = pharmacyWorkspaceReadRequirement;
  static const AccessRequirement retry = pharmacyWorkspaceReadRequirement;
  /// Authorized success snackbar path (mutation entry already write-gated).
  static const AccessRequirement success = pharmacyWorkspaceWriteRequirement;
  /// Authorized form validation feedback (nested write dialogs).
  static const AccessRequirement validation = pharmacyWorkspaceWriteRequirement;
  static const AccessRequirement rowSelect = pharmacyWorkspaceReadRequirement;
  static const AccessRequirement detail = pharmacyWorkspaceReadRequirement;
  static const AccessRequirement nextAction = pharmacyWorkspaceReadRequirement;
  static const AccessRequirement nextActionWrite =
      pharmacyWorkspaceWriteRequirement;
  static const AccessRequirement catalogBrowse =
      pharmacyCatalogBrowseRequirement;
  static const AccessRequirement catalogWrite = pharmacyCatalogWriteRequirement;
  static const AccessRequirement create = pharmacyWorkspaceWriteRequirement;
  static const AccessRequirement update = pharmacyWorkspaceWriteRequirement;
  static const AccessRequirement delete = pharmacyWorkspaceWriteRequirement;
  static const AccessRequirement write = pharmacyWorkspaceWriteRequirement;
  static const AccessRequirement dispense = pharmacyWorkspaceWriteRequirement;
  static const AccessRequirement attest = pharmacyWorkspaceWriteRequirement;
  static const AccessRequirement returnItems = pharmacyWorkspaceWriteRequirement;
  static const AccessRequirement cancelOrder = pharmacyWorkspaceWriteRequirement;
  static const AccessRequirement mapStock = pharmacyWorkspaceWriteRequirement;
  static const AccessRequirement priceSource = pharmacyWorkspaceWriteRequirement;
  static const AccessRequirement recordPayment =
      pharmacyRecordPaymentRequirement;
  static const AccessRequirement billingStatus =
      pharmacyBillingStatusReadRequirement;
  static const AccessRequirement printInstructions =
      pharmacyPrintInstructionsRequirement;
  static const AccessRequirement controlledDrugAudit =
      pharmacyControlledDrugAuditRequirement;
  /// Nested cross-module write — matrix _(n/a)_ on All; payment uses billing ∩.
  static const AccessRequirement nestedBillingWrite =
      pharmacyRecordPaymentRequirement;
  static const AccessRequirement nestedWrite = pharmacyWorkspaceWriteRequirement;
  static const AccessRequirement nestedRead = pharmacyWorkspaceReadRequirement;
  static const AccessRequirement entry = pharmacyWorkspaceRouteEntryRequirement;
  static const AccessRequirement routeEntry =
      pharmacyWorkspaceRouteEntryRequirement;
  static const AccessRequirement catalogEntry =
      pharmacyWorkspaceCatalogEntryRequirement;
  static const AccessRequirement read = pharmacyWorkspaceReadRequirement;
}

bool canViewPharmacyAllOrdersTab(AppAccessPolicy policy) {
  return PharmacyAllOrdersAtomPermissions.tab.isAllowed(policy);
}
