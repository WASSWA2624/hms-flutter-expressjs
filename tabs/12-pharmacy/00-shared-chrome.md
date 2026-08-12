# Pharmacy — shared / cross-tab chrome

## Shell entry

- Route: `AppRoutes.pharmacy` under app `ShellRoute`
- Workspace route gate: `pharmacyWorkspaceRouteEntryRequirement` — ∪ `pharmacy:read` | `operations:read` + module `pharmacy-dispensing`
- Catalog entry: `RouteAccessCatalog.pharmacyEntry` (∩ `pharmacy:read`)
- Order tabs: ∩ `pharmacy:read` + `pharmacy-dispensing`
- Pending payment tab: ∩ `pharmacy:read` + `billing:read` (`PharmacyPendingPaymentAtomPermissions.tab`)
- Catalog / suppliers / stock-alert tabs: `pharmacyCatalogBrowseRequirement` (∩ `pharmacy:read`)
- Route-only `operations:read` without `pharmacy:read`: fallback keeps order worklist tabs; catalog/suppliers/stock omitted
- If no sections allowed: empty `AppWorkspaceStatePanel` (`pharmacyNoOrdersTitle` / `pharmacyNoOrdersBody`)

## Page chrome

- Workspace page wraps controller async state (see page / tests)
- Body: `ResponsivePage` (`scrollable: false`) + `AppTabStrip` + section body
- Section bodies:
  - Order sections → `_PharmacyQueuePanel` (`AppListTable<PharmacyOrder>`)
  - Catalog + stock-alert sections → `PharmacyCatalogPanel` (`opensCatalogPanel`)
  - Suppliers → `PharmacySuppliersCatalogTab` / suppliers panel
- In-desk URL: `syncWorkspaceLocation` with `?section=<query>`
- Deep-links: section; `inventory`/`stock` under catalog prepare Inventory sub-tab; sales/walk-in opens walk-in dialog

## Tab strip

- `AppTabStrip` / `AppTabItem` via `pharmacyTabItems` (`pharmacy_scope_navigation.dart`); omitted when unauthorized — not disabled
- Sibling-count model: dedicated unfiltered workspace summary / stock / supplier totals; active order tab uses filtered `workbench.orders.totalItemCount`; active stock-alert tab uses filtered `inventoryWorkbench.stocks.totalItemCount`
- Counts:
  - Orders: summary queues (`orderedQueue`, `partiallyDispensedQueue`, `pendingPaymentQueue`, `dispensedOrders`, `cancelledOrders`, `totalOrders`)
  - Suppliers: `state.suppliers.totalItemCount`
  - Stock siblings: `stock.expiringSoonRows` / `expiredRows` / `lowStockRows` / `outOfStockRows`
  - Catalog: **null** (management hub, no worklist count)
- Count tones: `warning` (queue, inProgress, pendingPayment, nearExpiry, lowStock); `danger` (cancelled, expired, outOfStock); `info` (completed, catalog, suppliers, allOrders)
- Icons: medication_liquid / pending_actions / payments / done_all / cancel / receipt_long / inventory_2 / local_shipping / hourglass / event_busy / trending_down / remove_shopping_cart
- Deep-link helpers: `pharmacySectionToQueryValue` / `pharmacySectionFromQuery` (aliases include `ready`, `inventory`/`stock`)

## Order-table toolbar pattern

Order: **Filters → Settings → Export → Print → Reports? → Walk-in order?**

| Control | Label / key | Notes |
| --- | --- | --- |
| Search | `pharmacySearchLabel` / `pharmacySearchHint` | |
| Filters | `commonFiltersActionLabel` → `commonAdvancedFiltersTitle` | Apply `opdApplyFiltersAction`; Clear `opdClearFiltersAction` |
| Settings | `commonTableSettings*` | storage `pharmacy_${section}` / `pharmacy_cw_${section}` |
| Export | `commonTableExportActionLabel` | omit without ∩ `evidence:export` (`canExportPharmacyWorkspace`) |
| Print | `commonPrintActionLabel` | preview-first via `printPharmacyListTable` / `pharmacy_workspace_print_helpers`; same gate as Export |
| Open reports | `pharmacyOpenReportsAction` | omitted without `reports:read` + `reporting-analytics` + pharmacy read |
| Walk-in order | `pharmacyWalkInOrderAction` | omitted without ∩ `pharmacy:write` |

Date filter: **enabled** on order tabs — `pharmacyOrderDateFilterLabel` / `pharmacyPickOrderDateAction`.

Filter groups (orders): Location, Priority, Partial stock (`pharmacyFilterPartialStock`), Urgent (`pharmacyFilterUrgent`).

## Shared order dialogs / reuse

| Surface | Owner |
| --- | --- |
| Prescription / order detail dialog | Pharmacy-owned (`_openPharmacyDetailDialog`); title `pharmacyPrescriptionDetailTitle` (surface type) |
| Dispense / Attest / Return / Cancel | Pharmacy-owned |
| Walk-in order | Pharmacy-owned `showPharmacyWalkInOrderDialog`; title `Create order` |
| Record payment | **reused** billing payment path via `pharmacy_billing_helpers` / billing write ∩ |
| Print instructions / invoice / dispense batch | Pharmacy print helpers; trigger label `commonPrintActionLabel` (`Print`) |
| Drug / supplier / storage similarity dialogs | Pharmacy-owned |
| Catalog CRUD dialogs | Pharmacy-owned (+ catalog write ∪ `pharmacy:write` \| `operations:write`) |

## Catalog / suppliers chrome

- Nested icon tab bar: `PharmacyCatalogIconTabBar` + `pharmacyCatalogTabDescriptors`
- Sub-tabs: Drugs, Formulary, Inventory, Storage (layout), Shelves
- Trailing Add / bulk delete gated by `pharmacyCatalogWriteRequirement` (∪ `pharmacy:write` | `operations:write`)
- Printable catalog / suppliers / storage tables: Export + Print gated by `canExportPharmacyWorkspace` / `canPrintPharmacyWorkspace`
- Suppliers: Filters (`commonFiltersActionLabel`) → Settings → Export → Print → Create?
- Nested formulary/selection / shelf-picker tables keep `enableExport: false`

## Feedback patterns

- Walk-in success snackbar: `pharmacyWalkInOrderCreatedMessage`
- Empty orders: `pharmacyNoOrdersTitle` / `pharmacyNoOrdersBody`
- Detail actions omit unauthorized writes (no disabled stubs)
- Print instructions: ∩ `pharmacy:read` (`pharmacyPrintInstructionsRequirement`)
- Table Export / Print: ∩ `evidence:export` (`pharmacyWorkspaceExportRequirement`)
