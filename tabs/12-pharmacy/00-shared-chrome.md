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

- `AppTabStrip` / `AppTabItem`; omitted when unauthorized — not disabled
- Counts:
  - Orders: summary queues (`orderedQueue`, `partiallyDispensedQueue`, `pendingPaymentQueue`, `dispensedOrders`, `cancelledOrders`, `totalOrders`); active tab may use filtered membership via `_sectionCount`
  - Suppliers: `state.suppliers.totalItemCount`
  - Stock: `stock.expiringSoonRows` / `expiredRows` / `lowStockRows` / `outOfStockRows`
  - Catalog: **null** (management hub, no worklist count)
- Count tones: `warning` (queue, inProgress, pendingPayment, nearExpiry, lowStock); `danger` (cancelled, expired, outOfStock); `info` (completed, catalog, suppliers, allOrders)
- Icons: medication_liquid / pending_actions / payments / done_all / cancel / receipt_long / inventory_2 / local_shipping / hourglass / event_busy / trending_down / remove_shopping_cart

## Order-table toolbar pattern

Order: **Filters → Settings → (no Export/Print) → Reports? → Walk-in order?**

| Control | Label / key | Notes |
| --- | --- | --- |
| Search | `pharmacySearchLabel` / `pharmacySearchHint` | |
| Filters | `pharmacyQueueFilterLabel` → `commonAdvancedFiltersTitle` | Apply `opdApplyFiltersAction`; Clear `opdClearFiltersAction` |
| Settings | `commonTableSettings*` | storage `pharmacy_${section}` / `pharmacy_cw_${section}` |
| Export / Print (table) | **absent** | not mounted on order `AppListTable` |
| Open reports | `pharmacyOpenReportsAction` | omitted without `reports:read` + `reporting-analytics` + pharmacy read |
| Walk-in order | `pharmacyWalkInOrderAction` | omitted without ∩ `pharmacy:write` |

Date filter: **enabled** on order tabs — `pharmacyOrderDateFilterLabel` / `pharmacyPickOrderDateAction`.

Filter groups (orders): Location, Priority, Partial stock (`pharmacyFilterPartialStock`), Urgent (`pharmacyFilterUrgent`).

## Shared order dialogs / reuse

| Surface | Owner |
| --- | --- |
| Prescription / order detail dialog | Pharmacy-owned (`_openPharmacyDetailDialog`) |
| Dispense / Attest / Return / Cancel | Pharmacy-owned |
| Walk-in order | Pharmacy-owned `showPharmacyWalkInOrderDialog` |
| Record payment | **reused** billing payment path via `pharmacy_billing_helpers` / billing write ∩ |
| Print instructions / invoice / dispense batch | Pharmacy print helpers (`pharmacy_instructions_print_helpers`, `pharmacy_order_invoice_print_helpers`) |
| Drug / supplier / storage similarity dialogs | Pharmacy-owned |
| Catalog CRUD dialogs | Pharmacy-owned (+ catalog write ∪ `pharmacy:write` \| `operations:write`) |

## Catalog chrome (inside Catalog / stock desks)

- Nested icon tab bar: `PharmacyCatalogIconTabBar` + `pharmacyCatalogTabDescriptors`
- Sub-tabs: Drugs, Formulary, Inventory, Storage (layout), Shelves
- Trailing Add / bulk delete gated by `pharmacyCatalogWriteRequirement` (∪ `pharmacy:write` | `operations:write`)
- Catalog tables set `enableExport: false` in formulary/selection flows

## Feedback patterns

- Walk-in success snackbar: `pharmacyWalkInOrderCreatedMessage`
- Empty orders: `pharmacyNoOrdersTitle` / `pharmacyNoOrdersBody`
- Detail actions omit unauthorized writes (no disabled stubs)
- Print instructions: ∩ `pharmacy:read` (`pharmacyPrintInstructionsRequirement`)
