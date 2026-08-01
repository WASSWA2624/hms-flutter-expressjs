# Pharmacy Workspace: Lifecycle Order Queues, Stock Alerts, and Dual Pricing

**Objective:** Refine the pharmacy workspace so its tabs reflect the real dispensing lifecycle and live stock health, reusing existing backend data and design-system components. Preserve all current dispensing, billing, catalog, returns, and routing behavior unless a requirement below changes it.

## Context

The workspace (`pharmacy_workspace_page.dart`) renders a five-tab strip via `PharmacyDeskSection {queue, inProgress, pendingPayment, completed, allOrders}` labeled Ready / Partial / Pending payment / Completed / All orders, driven by `?section=` (queue | in-progress | pending-payment | completed | all). Counts bind to `PharmacyWorkbenchSummary`. `AppListTable` supplies Filters (Advanced filters dialog), Settings (column visibility), and Export; "Catalog and stock" opens `PharmacyCatalogPanel` (Drugs / Formulary / Inventory / Storage).

`GET /api/v1/pharmacy/workbench` already returns summary counters `ordered_queue`, `partially_dispensed_queue`, `pending_payment_queue`, `dispensed_orders`, `cancelled_orders`, `total_orders`; order status enum is {ORDERED, DISPENSED, PARTIALLY_DISPENSED, CANCELLED}. `GET /api/v1/pharmacy/inventory/stock` already computes `stock_status` {IN_STOCK, ALMOST_OUT_OF_STOCK, LOW_STOCK, OUT_OF_STOCK} and `expiry_alert_status` {EXPIRED, EXPIRING_SOON} and accepts `stock_status`, `low_stock_only`, `expired_only`, `expiring_within_days`. Two prices already exist: pharmacy (`drug.unit_price` → `pharmacy_*`) and facility (`facility_pharmacy_offering.unit_price` → `facility_*`), with `price_source` / `billing_entity` {PHARMACY, FACILITY} on billing lines. `PharmacyOrderFilter.cancelled` exists but has no tab. Drugs expose only `name`, `code`, `form`, `strength` (no brand/generic split).

## Requirements

1. **New orders tab.** Rename the `queue` tab label to "New orders" (keep the enum value, `?section=queue`, and existing aliases). It lists open, unattended orders (status ORDERED) regardless of source (OPD/IPD/emergency/clinical/discharge or pharmacy-created). Do not change its underlying filter or status.
2. **Cancelled tab.** Add a `cancelled` desk section (`?section=cancelled`) that lists CANCELLED orders, bound to `summary.cancelledOrders`, with an error-tone badge. Reuse `PharmacyOrderFilter.cancelled`; next action is View details only.
3. **Preserve** Partial, Pending payment, Completed, and All orders in their current data semantics.
4. **Stock-alert tabs.** Add four sections — Near expiry, Expired, Low stock, Out of stock — that render inventory rows from `GET /inventory/stock` (not orders): Near expiry → `expiring_within_days` using each batch's `expiry_alert_lead_days` (default 30) / `expiry_alert_status=EXPIRING_SOON`; Expired → `expired_only=true`; Low stock (near reorder) → `stock_status` LOW_STOCK + ALMOST_OUT_OF_STOCK; Out of stock → `stock_status=OUT_OF_STOCK`. Bind badges to the corresponding stock-summary counts. Visually group the strip into "Orders" and "Stock" clusters; keep it horizontally responsive.
5. **Context-aware columns.** Show the most relevant columns per tab. Order tabs keep Patient / Location / Dispense|Items / Status / Next action (Pending payment also shows Payment). Stock tabs show Drug (brand + generic), Storage, On-hand qty, Reorder level, Next expiry/batch, Stock status. Stock-row actions open the existing Catalog "Adjust stock" flow.
6. **Dual-price pending payment.** In the Pending payment tab, the Payment column, and order detail, display the amount for the active `price_source`/`billing_entity` and label the tier (Pharmacy retail vs Facility billing), so pharmacy and facility billers see their own price. Preserve existing "Use pharmacy price"/"Use facility price" switches and Record payment (billingEntity PHARMACY/FACILITY). Align the pending-payment match so PENDING, PARTIAL, and UNPAID are counted consistently across summary counter, workbench filter, and column.
7. **Brand + generic naming.** Add `brand_name` and `generic_name` (scientific) to the drug model, serializer, and the Add/Edit drug dialog. Display the brand with the generic as subtitle in the catalog and in order medication labels; extend search to match both. Keep the existing `name` as a fallback so current records still render.
8. **Comprehensive Filters, Settings, Export.** Make the Advanced filters dialog comprehensive and cleanly grouped per context (orders: location, priority, source, partial stock, urgent, order date; stock: storage location, stock status, expiry window). Wire the currently-ignored `partial_stock`, `urgent`, and `priority` params through the workbench controller. Settings must expose all product/order parameters as toggleable columns; Export columns and filters must mirror the active tab's Settings.
9. **Catalog and stock** button continues to open `PharmacyCatalogPanel`; the `?section=inventory|stock` deep link stays unchanged.

## Constraints

- Reuse existing entities, controller, endpoints, billing helpers, and design-system widgets; introduce no parallel data paths.
- Backend RBAC/ABAC stays authoritative: hide unauthorized tabs via `pharmacyAllowedSections` and catalog/billing read gates; never render disabled "no access" controls. Stock tabs require catalog/inventory read; the Payment column/tab requires billing read.
- Do not create encounters, alter OPD/IPD stages, or duplicate MAR administration (`pharmacy-flow.mdc`).
- Refetch frontend data after every mutation. Use theme tokens (light + dark). Keep responsive on mobile, tablet, and desktop with no clipping or overflow. Define permission, loading, empty, error, success, validation, and visible-feedback states for every tab.

## Acceptance Criteria

- (R1) The first tab reads "New orders" and still lists ORDERED orders from any source.
- (R2) A Cancelled tab shows CANCELLED orders with an accurate error-tone badge.
- (R3, R9) Partial, Pending payment, Completed, All orders, the Catalog dialog, and deep links behave as before.
- (R4) Near expiry, Expired, Low stock, and Out of stock tabs list the correct inventory subsets with accurate badge counts.
- (R5) Columns and row actions change appropriately per tab with no overflow at any viewport.
- (R6) Pending amounts and tier labels match the active price source, and pending-payment counts are non-zero when billing is PENDING/PARTIAL/UNPAID.
- (R7) Brand and generic names persist, display, and are searchable; legacy single-name drugs still render.
- (R8) Advanced filters (including partial stock, urgent, priority) change results, and Export mirrors the active tab's visible columns and filters.

## Verification

- Extend Dart tests: `pharmacy_workspace_page_test.dart`, `pharmacy_workbench_query_test.dart`, `pharmacy_access_test.dart`, the per-tab permission tests, `pharmacy_order_search_matcher_test.dart`, and the catalog dialog layout tests. Extend backend Jest: `pharmacy-workspace.service.test.js` (new sections, stock filters, pending-payment status matching) plus catalog/drug schema tests.
- Run `flutter analyze`, `flutter test`, and backend Jest. Manually verify each tab, dual-price payment, brand/generic entry, comprehensive filters/export, light and dark themes, and that unauthorized tabs and actions do not render.

## Relevant Files

- `frontend/lib/features/pharmacy/presentation/pages/pharmacy_workspace_page.dart`
- `frontend/lib/features/pharmacy/presentation/controllers/pharmacy_workspace_controller.dart`
- `frontend/lib/features/pharmacy/domain/entities/pharmacy_entities.dart`
- `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_catalog_panel.dart`, `pharmacy_drug_edit_dialog.dart`
- `frontend/lib/features/pharmacy/presentation/pharmacy_billing_helpers.dart`, `pharmacy_order_item_pricing_helpers.dart`, `pharmacy_access.dart`
- `backend/src/modules/pharmacy-workspace/**` (service, serializer, schema, routes)
- `backend/src/modules/facility-pharmacy-catalog/**`, `backend/prisma/schema.prisma`
