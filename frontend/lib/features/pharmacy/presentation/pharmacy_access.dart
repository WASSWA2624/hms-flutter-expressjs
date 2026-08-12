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

/// Set pharmacy retail / OTC sell price on `drug` (∩ `pricing:pharmacy_write`).
const AccessRequirement pharmacyPricingWriteRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.pricingPharmacyWrite],
  activeModules: <String>[pharmacyDispensingModule],
);

/// Set facility encounter tariff on pharmacy offerings (∩ `pricing:facility_write`).
const AccessRequirement facilityPricingWriteRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.pricingFacilityWrite],
  activeModules: <String>[billingPaymentsModule],
);

/// Manual order-line switch to pharmacy retail price source.
const AccessRequirement pharmacyPriceSourcePharmacyRequirement =
    pharmacyPricingWriteRequirement;

/// Manual order-line switch to facility tariff price source.
const AccessRequirement pharmacyPriceSourceFacilityRequirement =
    facilityPricingWriteRequirement;

/// Catalog browse / open dialog (matrix ∩ `pharmacy:read`).
const AccessRequirement pharmacyCatalogBrowseRequirement =
    pharmacyWorkspaceReadRequirement;

/// Record / confirm payment from pharmacy (matrix nested: ∩ `billing:write`).
///
/// Reuses [billingWorkspaceWriteRequirement] (`billing-payments`).
const AccessRequirement pharmacyRecordPaymentRequirement =
    billingWorkspaceWriteRequirement;

/// Pending-payment / billing status visibility (matrix narrative ∩
/// `billing:read`). All-orders / Ready / Partial / Completed status columns
/// stay pharmacy-read; the Payment column on Pending payment (and optional
/// Payment picker columns) uses this when gated.
const AccessRequirement pharmacyBillingStatusReadRequirement =
    billingWorkspaceReadRequirement;

/// Pending payment tab view / read UI (matrix ∩ `pharmacy:read` +
/// `billing:read`).
///
/// Plan modules resolve via [PermissionModuleMap] to `pharmacy-dispensing` and
/// `billing-payments`.
const AccessRequirement pharmacyPendingPaymentReadRequirement =
    AccessRequirement(
      allPermissions: <AppPermission>[
        AppPermissions.pharmacyRead,
        AppPermissions.billingRead,
      ],
    );

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

/// Worklist Export / Print — ∩ `evidence:export` (omit when unauthorized).
const AccessRequirement pharmacyWorkspaceExportRequirement = AccessRequirement(
  allPermissions: <AppPermission>[AppPermissions.evidenceExport],
);

/// Alias — table Print uses the same desk export gate.
const AccessRequirement pharmacyWorkspacePrintRequirement =
    pharmacyWorkspaceExportRequirement;

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
/// Ready / Partial / Completed / All orders: ∩ `pharmacy:read` +
/// `pharmacy-dispensing`. Pending payment: ∩ `pharmacy:read` + `billing:read`
/// (modules via [PermissionModuleMap]).
AccessRequirement pharmacySectionTabRequirement(PharmacyDeskSection section) {
  return switch (section) {
    PharmacyDeskSection.queue => PharmacyReadyAtomPermissions.tab,
    PharmacyDeskSection.allOrders => PharmacyAllOrdersAtomPermissions.tab,
    PharmacyDeskSection.inProgress => PharmacyPartialAtomPermissions.tab,
    PharmacyDeskSection.completed => PharmacyCompletedAtomPermissions.tab,
    // Cancelled is a read-only history view; reuse the All orders read atom.
    PharmacyDeskSection.cancelled => PharmacyAllOrdersAtomPermissions.tab,
    // Catalog and stock management tab surfaces catalog CRUD chrome; gate on
    // catalog/inventory browse (write actions gate on catalog write inside).
    PharmacyDeskSection.catalog ||
    PharmacyDeskSection.suppliers => pharmacyCatalogBrowseRequirement,
    // Stock-alert tabs surface inventory; gate on catalog/inventory browse.
    PharmacyDeskSection.nearExpiry ||
    PharmacyDeskSection.expired ||
    PharmacyDeskSection.lowStock ||
    PharmacyDeskSection.outOfStock => pharmacyCatalogBrowseRequirement,
    PharmacyDeskSection.pendingPayment =>
      PharmacyPendingPaymentAtomPermissions.tab,
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

bool canViewPharmacyPendingPaymentTab(AppAccessPolicy policy) {
  return PharmacyPendingPaymentAtomPermissions.tab.isAllowed(policy);
}

bool canViewPharmacyControlledDrugAudit(AppAccessPolicy policy) {
  return pharmacyControlledDrugAuditRequirement.isAllowed(policy);
}

bool canPrintPharmacyInstructions(AppAccessPolicy policy) {
  return pharmacyPrintInstructionsRequirement.isAllowed(policy);
}

/// Print pharmacy order invoice/receipt (same read gate as instructions).
bool canPrintPharmacyInvoice(AppAccessPolicy policy) {
  return pharmacyPrintInstructionsRequirement.isAllowed(policy);
}

bool canExportPharmacyWorkspace(AppAccessPolicy policy) {
  return pharmacyWorkspaceExportRequirement.isAllowed(policy);
}

bool canPrintPharmacyWorkspace(AppAccessPolicy policy) {
  return pharmacyWorkspacePrintRequirement.isAllowed(policy);
}

/// Open Reports filtered to pharmacy datasets (`reports:read` ∩ reporting module).
bool canOpenPharmacyReportsAnalytics(AppAccessPolicy policy) {
  return canReadPharmacy(policy) &&
      policy.grants(AppPermissions.reportsRead) &&
      policy.hasActiveModule('reporting-analytics');
}

bool canViewPharmacySection(AppAccessPolicy policy, PharmacyDeskSection section) {
  return pharmacySectionTabRequirement(section).isAllowed(policy);
}

/// Write gate for the active desk section (reuses tab atom maps).
AccessRequirement pharmacySectionWriteRequirement(PharmacyDeskSection section) {
  return switch (section) {
    PharmacyDeskSection.queue => PharmacyReadyAtomPermissions.write,
    PharmacyDeskSection.allOrders => PharmacyAllOrdersAtomPermissions.write,
    PharmacyDeskSection.inProgress => PharmacyPartialAtomPermissions.write,
    PharmacyDeskSection.completed => PharmacyCompletedAtomPermissions.write,
    PharmacyDeskSection.cancelled => PharmacyAllOrdersAtomPermissions.write,
    PharmacyDeskSection.catalog ||
    PharmacyDeskSection.suppliers ||
    PharmacyDeskSection.nearExpiry ||
    PharmacyDeskSection.expired ||
    PharmacyDeskSection.lowStock ||
    PharmacyDeskSection.outOfStock => pharmacyCatalogWriteRequirement,
    PharmacyDeskSection.pendingPayment =>
      PharmacyPendingPaymentAtomPermissions.write,
  };
}

/// Sections the user may open.
///
/// Most worklist tabs use ∩ `pharmacy:read`. Pending payment uses ∩
/// `pharmacy:read` + `billing:read`. Route-only operations readers
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
  // Route ∪ without pharmacy:read: keep the order worklist tabs read-only, but
  // never expose the catalog or stock-alert sections — those require catalog
  // browse (∩ pharmacy:read), which this operations-only entrant lacks.
  return PharmacyDeskSection.values
      .where(
        (PharmacyDeskSection section) =>
            !section.isCatalogSection &&
            !section.isStockSection &&
            !section.isSuppliersSection,
      )
      .toList(growable: false);
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

/// Atom → requirement map for Pharmacy Ready (`/pharmacy?section=ready`).
///
/// Inventory: Ready-to-dispense worklist (`PharmacyDeskSection.queue`); columns
/// patient / location / dispense progress / status / next action. Nested
/// cross-module matrix rows are _(n/a)_ for strip chrome; payment recording
/// reuses billing write ∩; catalog CRUD keeps source ∪ `pharmacy:write`|
/// `operations:write`. Controlled-drug audit ∩ is [controlledDrugAudit] (no
/// dedicated chrome on Ready today).
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Ready strip tab / count | navigate | read ∩ `pharmacy:read` |
/// | Catalog and stock (search trailing) | navigate / read | browse ∩ `pharmacy:read` |
/// | Search / Clear / Filters / Settings / pagination | read chrome | read ∩ |
/// | Export / Print (table toolbar) | export | ∩ `evidence:export` |
/// | Dispense progress column | read | read ∩ |
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
abstract final class PharmacyReadyAtomPermissions {
  static const AccessRequirement tab = pharmacyWorkspaceReadRequirement;
  static const AccessRequirement listChrome = pharmacyWorkspaceReadRequirement;
  static const AccessRequirement search = pharmacyWorkspaceReadRequirement;
  static const AccessRequirement filters = pharmacyWorkspaceReadRequirement;
  static const AccessRequirement settings = pharmacyWorkspaceReadRequirement;
  static const AccessRequirement export = pharmacyWorkspaceExportRequirement;
  static const AccessRequirement print = pharmacyWorkspacePrintRequirement;
  static const AccessRequirement pagination = pharmacyWorkspaceReadRequirement;
  static const AccessRequirement dispenseProgress =
      pharmacyWorkspaceReadRequirement;
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
  /// Dispense / prepare fill from Ready queue.
  static const AccessRequirement dispense = pharmacyWorkspaceWriteRequirement;
  static const AccessRequirement attest = pharmacyWorkspaceWriteRequirement;
  static const AccessRequirement returnItems = pharmacyWorkspaceWriteRequirement;
  static const AccessRequirement cancelOrder = pharmacyWorkspaceWriteRequirement;
  static const AccessRequirement mapStock = pharmacyWorkspaceWriteRequirement;
  static const AccessRequirement priceSource =
      pharmacyPriceSourcePharmacyRequirement;
  static const AccessRequirement priceSourceFacility =
      pharmacyPriceSourceFacilityRequirement;
  static const AccessRequirement recordPayment =
      pharmacyRecordPaymentRequirement;
  static const AccessRequirement billingStatus =
      pharmacyBillingStatusReadRequirement;
  static const AccessRequirement printInstructions =
      pharmacyPrintInstructionsRequirement;
  static const AccessRequirement controlledDrugAudit =
      pharmacyControlledDrugAuditRequirement;
  /// Nested cross-module write — matrix _(n/a)_ on Ready; payment uses billing ∩.
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

bool canViewPharmacyReadyTab(AppAccessPolicy policy) {
  return PharmacyReadyAtomPermissions.tab.isAllowed(policy);
}

/// Atom → requirement map for Pharmacy All orders (`/pharmacy?section=all`).
///
/// Inventory: unfiltered worklist (`PharmacyDeskSection.allOrders`); columns
/// patient / location / items / status / next action. Nested cross-module
/// matrix rows are _(n/a)_ for strip chrome; payment recording reuses billing
/// write ∩; catalog CRUD keeps source ∪ `pharmacy:write`|`operations:write`.
/// Controlled-drug audit ∩ is [controlledDrugAudit] (no dedicated chrome on
/// All today).
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | All orders strip tab / count | navigate | read ∩ `pharmacy:read` |
/// | Catalog and stock (search trailing) | navigate / read | browse ∩ `pharmacy:read` |
/// | Search / Clear / Filters / Settings / pagination | read chrome | read ∩ |
/// | Export / Print (table toolbar) | export | ∩ `evidence:export` |
/// | Items / status columns | read | read ∩ |
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
  static const AccessRequirement export = pharmacyWorkspaceExportRequirement;
  static const AccessRequirement print = pharmacyWorkspacePrintRequirement;
  static const AccessRequirement pagination = pharmacyWorkspaceReadRequirement;
  /// Items column on All orders (status stays pharmacy-read).
  static const AccessRequirement items = pharmacyWorkspaceReadRequirement;
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
  static const AccessRequirement priceSource =
      pharmacyPriceSourcePharmacyRequirement;
  static const AccessRequirement priceSourceFacility =
      pharmacyPriceSourceFacilityRequirement;
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

/// Atom → requirement map for Pharmacy Partial (`/pharmacy?section=partial`).
///
/// Inventory: Partial fills worklist (`PharmacyDeskSection.inProgress`);
/// columns patient / location / dispense progress / status / next action.
/// Nested cross-module matrix rows are _(n/a)_ for strip chrome; payment
/// recording reuses billing write ∩; catalog CRUD keeps source ∪
/// `pharmacy:write`|`operations:write`. Controlled-drug audit ∩ is
/// [controlledDrugAudit] (no dedicated chrome on Partial today).
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Partial strip tab / count | navigate | read ∩ `pharmacy:read` |
/// | Catalog and stock (search trailing) | navigate / read | browse ∩ `pharmacy:read` |
/// | Search / Clear / Filters / Settings / pagination | read chrome | read ∩ |
/// | Export / Print (table toolbar) | export | ∩ `evidence:export` |
/// | Dispense progress column | read | read ∩ |
/// | Empty / loading / error / retry | read chrome | read ∩ |
/// | Success snackbar / validation (authorized) | visible feedback | write ∩ |
/// | Row select → prescription detail | read / navigate | read ∩ |
/// | Next action (view details) | progressive disclosure | read ∩ |
/// | Next action continue dispense / attest / return / cancel | update / delete | write ∩ |
/// | Next action record / confirm payment | update | billing write ∩ |
/// | Detail Record payment | update | billing write ∩ |
/// | Detail Dispense (partial fill) / Attest / Return / Cancel | update / delete | write ∩ |
/// | Detail Print instructions | export / read | print ∩ `pharmacy:read` |
/// | Line Map stock / price source | update | write ∩ |
/// | Nested catalog CRUD (drugs / formulary / stock / storage) | create / update / delete | catalog write ∪ |
/// | Controlled-drug audit (narrative ∩) | read | pharmacy:read ∩ compliance:read |
/// | Route entry (deep link) | navigate | ∪ pharmacy\|operations read |
abstract final class PharmacyPartialAtomPermissions {
  static const AccessRequirement tab = pharmacyWorkspaceReadRequirement;
  static const AccessRequirement listChrome = pharmacyWorkspaceReadRequirement;
  static const AccessRequirement search = pharmacyWorkspaceReadRequirement;
  static const AccessRequirement filters = pharmacyWorkspaceReadRequirement;
  static const AccessRequirement settings = pharmacyWorkspaceReadRequirement;
  static const AccessRequirement export = pharmacyWorkspaceExportRequirement;
  static const AccessRequirement print = pharmacyWorkspacePrintRequirement;
  static const AccessRequirement pagination = pharmacyWorkspaceReadRequirement;
  static const AccessRequirement dispenseProgress =
      pharmacyWorkspaceReadRequirement;
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
  /// Continue partial fill / remaining dispense.
  static const AccessRequirement dispense = pharmacyWorkspaceWriteRequirement;
  static const AccessRequirement attest = pharmacyWorkspaceWriteRequirement;
  static const AccessRequirement returnItems = pharmacyWorkspaceWriteRequirement;
  static const AccessRequirement cancelOrder = pharmacyWorkspaceWriteRequirement;
  static const AccessRequirement mapStock = pharmacyWorkspaceWriteRequirement;
  static const AccessRequirement priceSource =
      pharmacyPriceSourcePharmacyRequirement;
  static const AccessRequirement priceSourceFacility =
      pharmacyPriceSourceFacilityRequirement;
  static const AccessRequirement recordPayment =
      pharmacyRecordPaymentRequirement;
  static const AccessRequirement billingStatus =
      pharmacyBillingStatusReadRequirement;
  static const AccessRequirement printInstructions =
      pharmacyPrintInstructionsRequirement;
  static const AccessRequirement controlledDrugAudit =
      pharmacyControlledDrugAuditRequirement;
  /// Nested cross-module write — matrix _(n/a)_ on Partial; payment uses billing ∩.
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

bool canViewPharmacyPartialTab(AppAccessPolicy policy) {
  return PharmacyPartialAtomPermissions.tab.isAllowed(policy);
}

/// Atom → requirement map for Pharmacy Completed (`/pharmacy?section=completed`).
///
/// Inventory: Completed worklist (`PharmacyDeskSection.completed`); dispensed
/// history — prefer read. Columns patient / location / dispense progress /
/// status / next action. Nested cross-module matrix rows are _(n/a)_ for strip
/// chrome; Return (and rare eligible writes) reuse pharmacy write ∩; payment
/// recording reuses billing write ∩; detail payment-clearance fields reuse
/// [billingStatus] ∩ `billing:read`; catalog CRUD keeps source ∪
/// `pharmacy:write`|`operations:write`. Controlled-drug audit ∩ is
/// [controlledDrugAudit] (no dedicated chrome on Completed today).
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Completed strip tab / count | navigate | read ∩ `pharmacy:read` |
/// | Catalog and stock (search trailing) | navigate / read | browse ∩ `pharmacy:read` |
/// | Search / Clear / Filters / Settings / pagination | read chrome | read ∩ |
/// | Export / Print (table toolbar) | export | ∩ `evidence:export` |
/// | Dispense progress column | read | read ∩ |
/// | Empty / loading / error / retry | read chrome | read ∩ |
/// | Success snackbar / validation (authorized) | visible feedback | write ∩ |
/// | Row select → prescription detail | read / navigate | read ∩ |
/// | Next action (view details) | progressive disclosure | read ∩ |
/// | Next action return / attest / cancel | update / delete | write ∩ |
/// | Next action record / confirm payment | update | billing write ∩ |
/// | Detail payment clearance / Payment / Amount | read | billing status ∩ |
/// | Detail Record payment | update | billing write ∩ |
/// | Detail Return / Attest / Cancel (when eligible) | update / delete | write ∩ |
/// | Detail Print instructions | export / read | print ∩ `pharmacy:read` |
/// | Line Map stock / price source | update | write ∩ |
/// | Nested catalog CRUD (drugs / formulary / stock / storage) | create / update / delete | catalog write ∪ |
/// | Controlled-drug audit (narrative ∩) | read | pharmacy:read ∩ compliance:read |
/// | Route entry (deep link) | navigate | ∪ pharmacy\|operations read |
abstract final class PharmacyCompletedAtomPermissions {
  static const AccessRequirement tab = pharmacyWorkspaceReadRequirement;
  static const AccessRequirement listChrome = pharmacyWorkspaceReadRequirement;
  static const AccessRequirement search = pharmacyWorkspaceReadRequirement;
  static const AccessRequirement filters = pharmacyWorkspaceReadRequirement;
  static const AccessRequirement settings = pharmacyWorkspaceReadRequirement;
  static const AccessRequirement export = pharmacyWorkspaceExportRequirement;
  static const AccessRequirement print = pharmacyWorkspacePrintRequirement;
  static const AccessRequirement pagination = pharmacyWorkspaceReadRequirement;
  static const AccessRequirement dispenseProgress =
      pharmacyWorkspaceReadRequirement;
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
  static const AccessRequirement priceSource =
      pharmacyPriceSourcePharmacyRequirement;
  static const AccessRequirement priceSourceFacility =
      pharmacyPriceSourceFacilityRequirement;
  static const AccessRequirement recordPayment =
      pharmacyRecordPaymentRequirement;
  static const AccessRequirement billingStatus =
      pharmacyBillingStatusReadRequirement;
  static const AccessRequirement printInstructions =
      pharmacyPrintInstructionsRequirement;
  static const AccessRequirement controlledDrugAudit =
      pharmacyControlledDrugAuditRequirement;
  /// Nested cross-module write — matrix _(n/a)_ on Completed; payment uses billing ∩.
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

bool canViewPharmacyCompletedTab(AppAccessPolicy policy) {
  return PharmacyCompletedAtomPermissions.tab.isAllowed(policy);
}

/// Atom → requirement map for Pharmacy Pending payment
/// (`/pharmacy?section=pending-payment`).
///
/// Inventory: payment-gate worklist before dispense; columns patient / Payment /
/// ordered-at / status / next action. Tab read is ∩ `pharmacy:read` +
/// `billing:read`. Nested cross-module write is ∩ `billing:write` (record /
/// confirm payment). Catalog CRUD keeps source ∪ `pharmacy:write`|
/// `operations:write`. Controlled-drug audit ∩ is [controlledDrugAudit] (no
/// dedicated chrome on Pending payment today). Route entry remains ∪
/// `pharmacy:read`|`operations:read`.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Pending payment strip tab / count | navigate | read ∩ pharmacy:read + billing:read |
/// | Catalog and stock (search trailing) | navigate / read | browse ∩ `pharmacy:read` |
/// | Search / Clear / Filters / Settings / pagination | read chrome | tab read ∩ |
/// | Export / Print (table toolbar) | export | ∩ `evidence:export` |
/// | Payment status column | read | billing status ∩ `billing:read` |
/// | Empty / loading / error / retry | read chrome | tab read ∩ |
/// | Success snackbar (pharmacy mutate) | visible feedback | write ∩ |
/// | Success snackbar (record payment) | visible feedback | billing write ∩ |
/// | Validation (authorized nested writes) | visible feedback | write ∩ / billing write ∩ |
/// | Row select → prescription detail | read / navigate | tab read ∩ |
/// | Detail Payment / clearance / amount fields | read | billing status ∩ |
/// | Next action (view details) | progressive disclosure | tab read ∩ |
/// | Next action dispense / attest / return / cancel | update / delete | write ∩ |
/// | Next action record / confirm payment | update | billing write ∩ |
/// | Detail Record payment | update | billing write ∩ |
/// | Detail Dispense / Attest / Return / Cancel | update / delete | write ∩ |
/// | Detail Print instructions | export / read | print ∩ `pharmacy:read` |
/// | Line Map stock / price source | update | write ∩ |
/// | Nested catalog CRUD (drugs / formulary / stock / storage) | create / update / delete | catalog write ∪ |
/// | Controlled-drug audit (narrative ∩) | read | pharmacy:read ∩ compliance:read |
/// | Route entry (deep link) | navigate | ∪ pharmacy\|operations read |
abstract final class PharmacyPendingPaymentAtomPermissions {
  static const AccessRequirement tab = pharmacyPendingPaymentReadRequirement;
  static const AccessRequirement listChrome =
      pharmacyPendingPaymentReadRequirement;
  static const AccessRequirement search = pharmacyPendingPaymentReadRequirement;
  static const AccessRequirement filters = pharmacyPendingPaymentReadRequirement;
  static const AccessRequirement settings =
      pharmacyPendingPaymentReadRequirement;
  static const AccessRequirement export = pharmacyWorkspaceExportRequirement;
  static const AccessRequirement print = pharmacyWorkspacePrintRequirement;
  static const AccessRequirement pagination =
      pharmacyPendingPaymentReadRequirement;
  static const AccessRequirement empty = pharmacyPendingPaymentReadRequirement;
  static const AccessRequirement loading = pharmacyPendingPaymentReadRequirement;
  static const AccessRequirement retry = pharmacyPendingPaymentReadRequirement;
  /// Authorized pharmacy-mutation success snackbar path.
  static const AccessRequirement success = pharmacyWorkspaceWriteRequirement;
  /// Authorized record-payment success snackbar (nested billing write ∩).
  static const AccessRequirement paymentSuccess =
      pharmacyRecordPaymentRequirement;
  /// Authorized form validation feedback (nested pharmacy write dialogs).
  static const AccessRequirement validation = pharmacyWorkspaceWriteRequirement;
  /// Authorized billing-dialog validation (nested billing write ∩).
  static const AccessRequirement paymentValidation =
      pharmacyRecordPaymentRequirement;
  static const AccessRequirement rowSelect =
      pharmacyPendingPaymentReadRequirement;
  static const AccessRequirement detail = pharmacyPendingPaymentReadRequirement;
  static const AccessRequirement nextAction =
      pharmacyPendingPaymentReadRequirement;
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
  static const AccessRequirement priceSource =
      pharmacyPriceSourcePharmacyRequirement;
  static const AccessRequirement priceSourceFacility =
      pharmacyPriceSourceFacilityRequirement;
  static const AccessRequirement recordPayment =
      pharmacyRecordPaymentRequirement;
  static const AccessRequirement billingStatus =
      pharmacyBillingStatusReadRequirement;
  static const AccessRequirement printInstructions =
      pharmacyPrintInstructionsRequirement;
  static const AccessRequirement controlledDrugAudit =
      pharmacyControlledDrugAuditRequirement;
  /// Nested cross-module write — matrix ∩ `billing:write`.
  static const AccessRequirement nestedBillingWrite =
      pharmacyRecordPaymentRequirement;
  static const AccessRequirement nestedWrite = pharmacyWorkspaceWriteRequirement;
  static const AccessRequirement nestedRead =
      pharmacyPendingPaymentReadRequirement;
  static const AccessRequirement entry = pharmacyWorkspaceRouteEntryRequirement;
  static const AccessRequirement routeEntry =
      pharmacyWorkspaceRouteEntryRequirement;
  static const AccessRequirement catalogEntry =
      pharmacyWorkspaceCatalogEntryRequirement;
  static const AccessRequirement read = pharmacyPendingPaymentReadRequirement;
}

/// Inventory: Catalog and stock desk (`PharmacyDeskSection.catalog`) with nested
/// Drugs / Formulary / Inventory / Storage / Shelves sub-tabs. Management hub
/// (no strip count). Nested selection pickers keep `enableExport: false`.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Catalog desk strip tab | navigate | browse ∩ `pharmacy:read` |
/// | Nested sub-tab browse | read chrome | browse ∩ |
/// | Search / Filters / Settings / pagination | read chrome | browse ∩ |
/// | Export / Print (printable catalog tables) | export | ∩ `evidence:export` |
/// | Empty / loading / error / retry | read chrome | browse ∩ |
/// | Add / Edit / Delete / bulk | create / update / delete | catalog write ∪ |
/// | Pharmacy price fields | update | ∩ `pricing:pharmacy_write` |
/// | Facility price fields | update | ∩ `pricing:facility_write` (+ billing-payments) |
/// | Route entry (deep link) | navigate | ∪ pharmacy\|operations read |
abstract final class PharmacyCatalogAtomPermissions {
  static const AccessRequirement tab = pharmacyCatalogBrowseRequirement;
  static const AccessRequirement listChrome = pharmacyCatalogBrowseRequirement;
  static const AccessRequirement search = pharmacyCatalogBrowseRequirement;
  static const AccessRequirement filters = pharmacyCatalogBrowseRequirement;
  static const AccessRequirement settings = pharmacyCatalogBrowseRequirement;
  static const AccessRequirement export = pharmacyWorkspaceExportRequirement;
  static const AccessRequirement print = pharmacyWorkspacePrintRequirement;
  static const AccessRequirement pagination = pharmacyCatalogBrowseRequirement;
  static const AccessRequirement empty = pharmacyCatalogBrowseRequirement;
  static const AccessRequirement loading = pharmacyCatalogBrowseRequirement;
  static const AccessRequirement retry = pharmacyCatalogBrowseRequirement;
  static const AccessRequirement create = pharmacyCatalogWriteRequirement;
  static const AccessRequirement update = pharmacyCatalogWriteRequirement;
  static const AccessRequirement delete = pharmacyCatalogWriteRequirement;
  static const AccessRequirement write = pharmacyCatalogWriteRequirement;
  static const AccessRequirement browse = pharmacyCatalogBrowseRequirement;
  static const AccessRequirement priceSource =
      pharmacyPriceSourcePharmacyRequirement;
  static const AccessRequirement priceSourceFacility =
      pharmacyPriceSourceFacilityRequirement;
  static const AccessRequirement routeEntry =
      pharmacyWorkspaceRouteEntryRequirement;
  static const AccessRequirement catalogEntry =
      pharmacyWorkspaceCatalogEntryRequirement;
}

/// Inventory: Suppliers desk (`PharmacyDeskSection.suppliers`). Authoritative
/// count from `state.suppliers.totalItemCount` (filtered query total).
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Suppliers strip tab / count | navigate | browse ∩ `pharmacy:read` |
/// | Search / Filters / Settings / pagination | read chrome | browse ∩ |
/// | Export / Print (table toolbar) | export | ∩ `evidence:export` |
/// | Empty / loading / error / retry | read chrome | browse ∩ |
/// | Create / Edit / Delete | create / update / delete | catalog write ∪ |
/// | Row select → supplier details | read / navigate | browse ∩ |
/// | Route entry (deep link) | navigate | ∪ pharmacy\|operations read |
abstract final class PharmacySuppliersAtomPermissions {
  static const AccessRequirement tab = pharmacyCatalogBrowseRequirement;
  static const AccessRequirement listChrome = pharmacyCatalogBrowseRequirement;
  static const AccessRequirement search = pharmacyCatalogBrowseRequirement;
  static const AccessRequirement filters = pharmacyCatalogBrowseRequirement;
  static const AccessRequirement settings = pharmacyCatalogBrowseRequirement;
  static const AccessRequirement export = pharmacyWorkspaceExportRequirement;
  static const AccessRequirement print = pharmacyWorkspacePrintRequirement;
  static const AccessRequirement pagination = pharmacyCatalogBrowseRequirement;
  static const AccessRequirement empty = pharmacyCatalogBrowseRequirement;
  static const AccessRequirement loading = pharmacyCatalogBrowseRequirement;
  static const AccessRequirement retry = pharmacyCatalogBrowseRequirement;
  static const AccessRequirement create = pharmacyCatalogWriteRequirement;
  static const AccessRequirement update = pharmacyCatalogWriteRequirement;
  static const AccessRequirement delete = pharmacyCatalogWriteRequirement;
  static const AccessRequirement write = pharmacyCatalogWriteRequirement;
  static const AccessRequirement browse = pharmacyCatalogBrowseRequirement;
  static const AccessRequirement detail = pharmacyCatalogBrowseRequirement;
  static const AccessRequirement routeEntry =
      pharmacyWorkspaceRouteEntryRequirement;
  static const AccessRequirement catalogEntry =
      pharmacyWorkspaceCatalogEntryRequirement;
}

/// Inventory: Near expiry desk (`PharmacyDeskSection.nearExpiry`). Reuses
/// Catalog → Inventory with `expiringWithinDays: 30`. Sibling count from
/// `stockAlertSummary.expiringSoonRows`; active badge uses filtered inventory
/// `stocks.totalItemCount`.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Near expiry strip tab / count | navigate | browse ∩ `pharmacy:read` |
/// | Search / Filters / Settings / pagination | read chrome | browse ∩ |
/// | Export / Print (inventory table) | export | ∩ `evidence:export` |
/// | Empty / loading / error / retry | read chrome | browse ∩ |
/// | Adjust / Clear stock | update / delete | catalog write ∪ |
/// | Route entry (deep link) | navigate | ∪ pharmacy\|operations read |
abstract final class PharmacyNearExpiryAtomPermissions {
  static const AccessRequirement tab = pharmacyCatalogBrowseRequirement;
  static const AccessRequirement listChrome = pharmacyCatalogBrowseRequirement;
  static const AccessRequirement search = pharmacyCatalogBrowseRequirement;
  static const AccessRequirement filters = pharmacyCatalogBrowseRequirement;
  static const AccessRequirement settings = pharmacyCatalogBrowseRequirement;
  static const AccessRequirement export = pharmacyWorkspaceExportRequirement;
  static const AccessRequirement print = pharmacyWorkspacePrintRequirement;
  static const AccessRequirement pagination = pharmacyCatalogBrowseRequirement;
  static const AccessRequirement empty = pharmacyCatalogBrowseRequirement;
  static const AccessRequirement loading = pharmacyCatalogBrowseRequirement;
  static const AccessRequirement retry = pharmacyCatalogBrowseRequirement;
  static const AccessRequirement create = pharmacyCatalogWriteRequirement;
  static const AccessRequirement update = pharmacyCatalogWriteRequirement;
  static const AccessRequirement delete = pharmacyCatalogWriteRequirement;
  static const AccessRequirement write = pharmacyCatalogWriteRequirement;
  static const AccessRequirement browse = pharmacyCatalogBrowseRequirement;
  static const AccessRequirement routeEntry =
      pharmacyWorkspaceRouteEntryRequirement;
  static const AccessRequirement catalogEntry =
      pharmacyWorkspaceCatalogEntryRequirement;
}

/// Inventory: Expired desk (`PharmacyDeskSection.expired`). Reuses Catalog →
/// Inventory with `expiredOnly: true`. Sibling count from
/// `stockAlertSummary.expiredRows`; active badge uses filtered inventory
/// `stocks.totalItemCount`.
///
/// | Atom | Kind | Gate |
/// | --- | --- | --- |
/// | Expired strip tab / count | navigate | browse ∩ `pharmacy:read` |
/// | Search / Filters / Settings / pagination | read chrome | browse ∩ |
/// | Export / Print (inventory table) | export | ∩ `evidence:export` |
/// | Empty / loading / error / retry | read chrome | browse ∩ |
/// | Adjust / Clear stock | update / delete | catalog write ∪ |
/// | Route entry (deep link) | navigate | ∪ pharmacy\|operations read |
abstract final class PharmacyExpiredAtomPermissions {
  static const AccessRequirement tab = pharmacyCatalogBrowseRequirement;
  static const AccessRequirement listChrome = pharmacyCatalogBrowseRequirement;
  static const AccessRequirement search = pharmacyCatalogBrowseRequirement;
  static const AccessRequirement filters = pharmacyCatalogBrowseRequirement;
  static const AccessRequirement settings = pharmacyCatalogBrowseRequirement;
  static const AccessRequirement export = pharmacyWorkspaceExportRequirement;
  static const AccessRequirement print = pharmacyWorkspacePrintRequirement;
  static const AccessRequirement pagination = pharmacyCatalogBrowseRequirement;
  static const AccessRequirement empty = pharmacyCatalogBrowseRequirement;
  static const AccessRequirement loading = pharmacyCatalogBrowseRequirement;
  static const AccessRequirement retry = pharmacyCatalogBrowseRequirement;
  static const AccessRequirement create = pharmacyCatalogWriteRequirement;
  static const AccessRequirement update = pharmacyCatalogWriteRequirement;
  static const AccessRequirement delete = pharmacyCatalogWriteRequirement;
  static const AccessRequirement write = pharmacyCatalogWriteRequirement;
  static const AccessRequirement browse = pharmacyCatalogBrowseRequirement;
  static const AccessRequirement routeEntry =
      pharmacyWorkspaceRouteEntryRequirement;
  static const AccessRequirement catalogEntry =
      pharmacyWorkspaceCatalogEntryRequirement;
}
