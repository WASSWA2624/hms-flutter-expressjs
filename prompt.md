# Feature: Pharmacy stock monitoring, reorder alerts, and expiry tracking

## Goal

Give pharmacy staff a single place to **monitor stock levels**, **receive restock alerts** when quantity falls at or below a configured threshold, and **track product expiry** by batch. Staff must be able to set the alert threshold when onboarding a drug or receiving stock—not only via seed data or admin APIs.

## Current state (keep)

The following already exist—extend them; do not regress:

- **Data model:** `inventory_stock` (`quantity`, `reorder_level`, facility-scoped) linked to drugs via `drug_inventory_map`; `drug_batch` (`batch_number`, `expiry_date`, `quantity`).
- **Stock status logic:** `resolveStockStatus` in `backend/src/modules/pharmacy-workspace/services/pharmacy-workspace.service.js` and `pharmacy.serializer.js` — `IN_STOCK`, `ALMOST_OUT_OF_STOCK` (≤ 2× reorder), `LOW_STOCK` (≤ reorder), `OUT_OF_STOCK`.
- **Pharmacy workspace:** Orders queue, drug catalog panel (`PharmacyCatalogTab`: drugs / formulary / inventory), stock adjust dialog, drug-level stock status badges and filters.
- **Inventory API:** `GET /api/v1/pharmacy/inventory/stock` with `low_stock_only`; `POST /api/v1/pharmacy/inventory/adjust`; summary counts (`low_stock_rows`, `almost_out_of_stock_rows`, etc.).
- **Drug-batch API:** `GET/POST /api/v1/drug-batches` with `expired` filter (no Flutter client yet).
- **Inventory-stock API:** `reorder_level` on create/update (`backend/src/modules/inventory-stock/schemas/inventory-stock.schema.js`).
- **Seeder reference:** `backend/scripts/seeders/seed-clinical-catalog-pack.js` — drugs created with `initial_stock`, `reorder_level`, and inventory mapping.

## Gaps

| Area | Today | Needed |
|------|-------|--------|
| **Reorder threshold** | Stored in DB; defaults to `0` on new stock rows | Captured and editable when adding a drug, receiving stock, or editing inventory |
| **Alerts** | Status badge + optional `low_stock_only` filter; dashboard metric only | Visible **workspace alerts** (summary chips / notifications) when items cross threshold |
| **Monitoring UI** | Inventory table shows item, facility, quantity, status | Also show **reorder level**, **next expiry**, and batch count; filter by stock status and expiry window |
| **Expiry** | `drug_batch` API exists; dispense uses free-text batch ref | Batch + expiry captured on **stock receipt**; expiry surfaced in catalog/inventory; alerts for soon-to-expire / expired |
| **Drug onboarding** | Add-drug dialog: name, code, form, strength, price only | Optional stock setup: unit, initial quantity, reorder level, first batch (number + expiry) |

## Scope

### 1. Reorder threshold (restock alert quantity)

- Add **Reorder alert at** (`reorder_level`, non-negative integer) to:
  - Add / edit drug flow when stock is initialized (`_DrugFormDialog` in `pharmacy_catalog_panel.dart`).
  - Stock receive / adjust flow when creating a new `inventory_stock` row (`_InventoryAdjustDialog`).
  - Inventory row edit (inline or dialog) for existing stock.
- Wire through `PharmacyDrugInput` / adjust payloads → backend pharmacy-workspace or inventory-stock endpoints.
- When `reorder_level` is `0`, treat as “no alert configured” (existing status logic already handles this).

### 2. Stock monitoring & alerts

- **Inventory tab** (`_InventoryCatalogTab`): add columns **Reorder level**, **Next expiry** (earliest non-expired batch for the drug, if any).
- Add **summary notification chips** on the pharmacy workspace toolbar (mirror orders-queue chips in `pharmacy_workspace_page.dart`) for:
  - Low stock (`LOW_STOCK` + `OUT_OF_STOCK`)
  - Almost out of stock (`ALMOST_OUT_OF_STOCK`) — optional, lower priority tone
  - Expiring soon (configurable window, e.g. 30 days)
- Chips are **clickable** — apply the corresponding inventory filter.
- Expose **stock status** and **low stock only** filters in the inventory panel (drugs tab already has `_stockStatusFilterChoices`; align inventory tab).
- Show `reorder_level` and computed status in drug catalog rows where stock is mapped.

### 3. Expiry tracking (batch-level)

- On **stock receipt** (`reason: PURCHASE` or dedicated “Receive stock” action), capture:
  - Batch number (required when expiry is provided)
  - Expiry date (optional but encouraged for pharmacy products)
  - Quantity received
- Create or update `drug_batch` via existing drug-batch service; decrement batch quantity on dispense where batch is specified (FEFO preference when batch not chosen—document behavior).
- **Inventory / drug detail:** list batches with expiry, quantity remaining, and expired flag.
- **Filters:** `expiring_within_days`, `expired_only` on inventory/drug-batch queries (backend + controller).
- **Alerts:** summary chip for batches expiring within threshold; badge on rows with expired or soon-to-expire stock.

## Primary references

| Layer | Path |
|-------|------|
| Pharmacy UI | `frontend/lib/features/pharmacy/presentation/pages/pharmacy_workspace_page.dart` |
| Catalog & inventory | `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_catalog_panel.dart` |
| Controller | `frontend/lib/features/pharmacy/presentation/controllers/pharmacy_workspace_controller.dart` |
| Entities / DTOs | `frontend/lib/features/pharmacy/domain/entities/pharmacy_entities.dart`, `data/dtos/pharmacy_dtos.dart` |
| Repository | `frontend/lib/features/pharmacy/data/repositories/pharmacy_repository_impl.dart` |
| Backend workspace | `backend/src/modules/pharmacy-workspace/` (service, serializer, schema, routes) |
| Drug batches | `backend/src/modules/drug-batch/` |
| Inventory stock | `backend/src/modules/inventory-stock/` |
| Schema | `backend/prisma/schema.prisma` — `inventory_stock`, `drug_batch`, `drug_inventory_map` |
| Shared UI | `frontend/lib/shared/layout/app_workspace.dart`, `app_workspace_summary_notification.dart`, `app_list_table.dart`, `app_workspace_status_badge.dart` |

## Implementation rules

- **Reuse existing stock status enums** — do not invent parallel status values; map to `AppWorkspaceStatusBadge` tones (warning for low/almost-out, error for out/expired).
- **Facility scoping:** reorder level and stock rows remain facility-scoped per existing pharmacy-workspace scope rules.
- **Backend parity:** filters (`low_stock_only`, stock status, expiry window) must be enforced server-side on paginated inventory/batch lists.
- **Localization:** add keys to `frontend/lib/l10n/app_en.arb` for reorder level, expiry, batch labels, alert chip text, and filter names.
- **No new visual language** — match pharmacy workspace and Lab/Radiology summary-chip patterns.
- **Minimal schema changes** — prefer existing `reorder_level` and `drug_batch`; only migrate if batch–inventory linkage is required for dispense FEFO.

## Out of scope

- Purchase orders / supplier procurement workflow.
- Push notifications, email, or SMS (in-app workspace alerts only for this task).
- Non-pharmacy inventory modules (equipment, general supplies).

## Acceptance criteria

- [ ] Staff can set **reorder alert quantity** when adding a drug (with initial stock) and when receiving or editing inventory stock.
- [ ] Inventory table shows **quantity**, **reorder level**, **stock status**, and **next expiry** per row.
- [ ] Pharmacy workspace toolbar shows **clickable alert chips** for low/out-of-stock and expiring-soon items; chips apply inventory filters.
- [ ] Stock receipt flow captures **batch number** and **expiry date**; batches appear in drug/inventory detail.
- [ ] Filters work for low stock, stock status, expired, and expiring-within-N-days via backend query params.
- [ ] Existing dispense, return, and stock-adjust flows continue to work; status recomputes after quantity changes.
- [ ] New UI strings are localized; shared workspace components are reused.
