# Pharmacy workspace UI inventory

Source: `tabs-lister/12-pharmacy.md` · Code base date: 2026-08-11

## Context

Catalog of every visible / reachable UI atom on `PharmacyWorkspacePage`. Not a redesign. Findings traced from presentation code, access maps, routes, and tests—not a visual walkthrough.

**Workspace:** `/pharmacy` (`AppRoutes.pharmacy`)  
**Page:** `frontend/lib/features/pharmacy/presentation/pages/pharmacy_workspace_page.dart`  
**Access:** `frontend/lib/features/pharmacy/presentation/pharmacy_access.dart`  
**Sections enum:** `PharmacyDeskSection`  
**Catalog sub-tabs:** `PharmacyCatalogTab` (`drugs`, `formulary`, `inventory`, `storageLayout`, `shelves`)

## Desk tabs (order)

| Enum | Query `section` | Aliases | File |
| --- | --- | --- | --- |
| `queue` | `queue` | (ready filter) | [01-queue.md](01-queue.md) |
| `inProgress` | `in-progress` | | [02-in-progress.md](02-in-progress.md) |
| `pendingPayment` | `pending-payment` | | [03-pending-payment.md](03-pending-payment.md) |
| `completed` | `completed` | | [04-completed.md](04-completed.md) |
| `cancelled` | `cancelled` | | [05-cancelled.md](05-cancelled.md) |
| `allOrders` | `all` | | [06-all-orders.md](06-all-orders.md) |
| `catalog` | `catalog` | `inventory`/`stock` → Inventory sub-tab | [07-catalog.md](07-catalog.md) |
| `suppliers` | `suppliers` | | [08-suppliers.md](08-suppliers.md) |
| `nearExpiry` | `near-expiry` | | [09-near-expiry.md](09-near-expiry.md) |
| `expired` | `expired` | | [10-expired.md](10-expired.md) |
| `lowStock` | `low-stock` | | [11-low-stock.md](11-low-stock.md) |
| `outOfStock` | `out-of-stock` | | [12-out-of-stock.md](12-out-of-stock.md) |

Helpers: `_sectionToQueryValue` / `_sectionFromQuery` in `pharmacy_workspace_page.dart`. Sales aliases (`sales`/`walk-in`) open walk-in create, not a desk tab.

## Shared / cross-tab chrome

See [00-shared-chrome.md](00-shared-chrome.md).

## Convention gaps

See [99-convention-gaps.md](99-convention-gaps.md).

## Source files

- `frontend/lib/features/pharmacy/presentation/pages/pharmacy_workspace_page.dart`
- `frontend/lib/features/pharmacy/presentation/pharmacy_access.dart`
- `frontend/lib/features/pharmacy/domain/entities/pharmacy_entities.dart`
- `frontend/lib/features/pharmacy/presentation/controllers/pharmacy_workspace_controller.dart`
- `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_catalog_panel.dart`
- `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_catalog_tabs.dart`
- `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_suppliers_panel.dart`
- `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_drug_details_dialog.dart`
- `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_drug_edit_dialog.dart`
- `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_supplier_details_dialog.dart`
- `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_walk_in_order_dialog.dart`
- `frontend/lib/features/pharmacy/presentation/pharmacy_catalog_dialog.dart`
- `frontend/lib/features/pharmacy/presentation/pharmacy_billing_helpers.dart`
- `frontend/lib/features/pharmacy/presentation/pharmacy_instructions_print_helpers.dart`
- `frontend/lib/features/pharmacy/presentation/pharmacy_order_invoice_print_helpers.dart`
- `frontend/test/features/pharmacy/`
