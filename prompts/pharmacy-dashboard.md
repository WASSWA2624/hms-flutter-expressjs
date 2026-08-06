# Pharmacy Stock Tabs: Open Catalog Inventory With Filters

Route Low stock, Near expiry, Expired, and Out of stock into Catalog and stock → Inventory with the matching stock filters applied, and stop using the separate alert-only stock tables.

## Context

**Current behavior**

- Desk sections `low-stock`, `near-expiry`, `expired`, and `out-of-stock` (`PharmacyDeskSection.lowStock` / `nearExpiry` / `expired` / `outOfStock`) call `applyDeskStockFilter` and render `_PharmacyStockPanel` on the pharmacy workspace.
- That panel reuses inventory stock data (`GET .../pharmacy/inventory/stock`) but is a **second table**: order-style search hint, no inventory Filters UI, **no Adjust / Clear** row actions, and stock-alert empty copy (“No stock alerts”).
- Catalog and stock → **Inventory** (`PharmacyCatalogPanel` / `_InventoryCatalogTab`) already shows the full inventory table: inventory search (“Search item, SKU, or stock ID”), Filters (including LOW_STOCK, OUT_OF_STOCK, expiring, expired), Settings/Export, and Adjust / Clear.
- Controller already has `applyInventoryFilter` / `prepareCatalogTab(PharmacyCatalogTab.inventory)` for opening Inventory with a query; desk stock tabs do not use that path today.
- Home KPI deep links (e.g. `section=low-stock`) and desk badge counts from `stockAlertSummary` remain valid entry points.

**Intended behavior**

- Selecting Low stock, Near expiry, Expired, or Out of stock (tab, overflow, or deep link) opens **Catalog and stock** with the **Inventory** nested tab active and the **equivalent inventory stock filter** applied so the Catalog Inventory table (with Adjust / Clear) is what the user sees.
- Filters chrome reflects the active filter (badge / selected choices). Clearing or changing filters behaves like normal Inventory.
- Do not keep a parallel stock-alert worklist as the primary UI for those sections.

**Definitions**

- *Stock alert tabs*: desk entries Low stock, Near expiry, Expired, Out of stock (and their `section=` deep links).
- *Catalog Inventory*: nested Inventory tab under Catalog and stock (`PharmacyCatalogTab.inventory`).
- *Matching filter*: the same stock constraint the desk section uses today via `PharmacyDeskSection.stockQuery` (low stock / out of stock / expiring-within window / expired-only), applied through the catalog inventory query path so Filters and actions stay consistent.

## Requirements

1. On stock-alert tab select or deep link (`section=low-stock|near-expiry|expired|out-of-stock`), navigate to Catalog and stock → Inventory and apply that section’s stock filter to `inventoryQuery` / inventory load (reuse `applyInventoryFilter` or equivalent—do not invent a second filter stack).
2. Render the existing Catalog Inventory table (search, Filters, Settings, Export, Adjust, Clear). Do not show `_PharmacyStockPanel` as the destination UI for these entries.
3. Keep desk tab labels and badge counts from `stockAlertSummary` unless a small wiring change is required so counts still match filtered Inventory results.
4. Preserve deep links and home KPI routes that use these `section=` values so they land on filtered Inventory (not the old alert panel).
5. Preserve unauthorized absence of Catalog / stock controls; loading, empty, error, success, and mutation feedback must match Catalog Inventory (inventory empty copy when no rows; Adjust/Clear sync after success).
6. Remove or stop mounting obsolete `_PharmacyStockPanel` primary flows once redirected; avoid duplicate stock tables.
7. Responsive; theme tokens; light/dark.
8. Tests: each stock `section=` opens Inventory with the correct filter; Adjust/Clear visible when permitted; Filters badge/active state reflects the filter; home/`section=low-stock` deep link; unauthorized inventory actions absent; order tabs unchanged.

## Constraints

- Reuse Catalog Inventory widgets, controller filter APIs, and `GET .../pharmacy/inventory/stock`—no parallel inventory table.
- Prefer desk/`stockQuery` and Catalog Filters stock-status semantics (aligned `stockStatus` / expiry flags)—do not silently switch to a broader `lowStockOnly` meaning without matching Filters UI.
- Do not remove order desk tabs or Catalog Drugs/Formulary/Rooms/Shelves behavior.
- Follow `.cursor/mandatories.mdc`, `.cursor/access/permissions.mdc`, `prompts/.cursor/prompt.mdc`.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | Low stock tab/deep link opens Catalog → Inventory filtered to low stock; Adjust/Clear present when entitled. | R1–R2, R4–R5 |
| A2 | Near expiry / Expired / Out of stock likewise open Inventory with matching filters. | R1–R2, R4 |
| A3 | Inventory search hint and Filters UI are used (not order search / alert-only empty panel). | R2, R5 |
| A4 | `_PharmacyStockPanel` is no longer the primary UI for those desk sections. | R2, R6 |
| A5 | Order tabs and other catalog tabs unchanged; unauthorized Adjust/Clear absent. | R5, R8 |
| A6 | Loading/empty/error/success feedback work on narrow + light/dark. | R5, R7 |

## Relevant Files

- `frontend/lib/features/pharmacy/presentation/pages/pharmacy_workspace_page.dart` (`_applySectionData`, stock sections, `_PharmacyStockPanel`)
- `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_catalog_panel.dart` (Inventory tab, Filters, Adjust/Clear)
- `frontend/lib/features/pharmacy/presentation/controllers/pharmacy_workspace_controller.dart` (`applyDeskStockFilter`, `applyInventoryFilter`, `prepareCatalogTab`)
- `frontend/lib/features/pharmacy/domain/entities/pharmacy_entities.dart` (`PharmacyDeskSection.stockQuery`)
- `frontend/lib/features/home/presentation/widgets/home_metric_routes.dart` (KPI → `low-stock`)
- `frontend/lib/features/pharmacy/presentation/pharmacy_access.dart`
- Tests: `pharmacy_workspace_page_test.dart`, `pharmacy_workbench_query_test.dart`, home metric route tests

## Verification

- Flutter: each stock section deep link → Inventory + filter + Adjust/Clear; Filters badge active; order tabs unaffected.
- Manual: Low stock (non-empty), Near expiry / Expired / Out of stock (empty or seeded) all show Catalog Inventory, not “No stock alerts” panel; light/dark and narrow viewport.
