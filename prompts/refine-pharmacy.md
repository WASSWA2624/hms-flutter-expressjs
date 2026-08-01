# Pharmacy Order Tabs: Independent, Purpose-Accurate Queues

**Objective:** Refine the pharmacy workspace's order tabs so each tab and its badge count represents one clear, mutually-exclusive stage of the dispensing lifecycle, with day-scoped Completed/Cancelled views and a full-history All orders view. Preserve the stock-alert tabs, dual pricing, catalog, brand/generic naming, and routing already in place unless a requirement below changes it.

## Context

`pharmacy_workspace_page.dart` renders `PharmacyDeskSection` order tabs — `queue` (New orders), `inProgress` (Partial), `pendingPayment` (Pending payment), `completed` (Completed), `cancelled` (Cancelled), `allOrders` (All orders) — plus the stock-alert tabs. Labels come from `_sectionLabel`; counts from `_sectionCount(state, section)` bound to `PharmacyWorkbenchSummary`; the active dataset from `_applySectionData` → `controller.applyFilter(_filterForSection(section))` → `PharmacyOrderFilter` → `PharmacyWorkbenchQuery`.

Backend `buildWorkbenchSummary` (`pharmacy-workspace.service.js`) currently counts each status independently over ALL time: `ordered_queue` (ORDERED), `partially_dispensed_queue` (PARTIALLY_DISPENSED), `pending_payment_queue` (open + billing PENDING/PARTIAL/UNPAID via `buildPendingPaymentStatusClause`), `dispensed_orders` (DISPENSED), `cancelled_orders` (CANCELLED), `total_orders`. `buildWorkbenchOrderWhere` maps `status`, `pending_payment`, date range (`ordered_at`, `from`/`to`), location, and priority. Order statuses: {ORDERED, DISPENSED, PARTIALLY_DISPENSED, CANCELLED}; billing lives in `billing_snapshot.payment_status`.

Today, an ORDERED order that is also awaiting payment is counted in BOTH New orders and Pending payment, and Completed/Cancelled show every dispensed/cancelled order regardless of date — so tab counts overlap and are not day-scoped.

## Requirements

1. **Clarify labels.** Rename the Completed tab to "Completed orders" and the Cancelled tab to "Cancelled orders" (new l10n keys; keep enum values, `?section=completed|cancelled`, and aliases). Keep New orders, Partial, Pending payment, and All orders labels.

2. **New orders = untouched, payment-gate excluded.** New orders lists open orders with status ORDERED that are NOT awaiting payment (no PENDING/PARTIAL/UNPAID billing). Update `ordered_queue` and the `queue` section query accordingly.

3. **Partial = partially dispensed, not payment-blocked.** Partial lists status PARTIALLY_DISPENSED orders that are NOT awaiting payment. Update `partially_dispensed_queue` and the `inProgress` query accordingly.

4. **Pending payment claims payment-gated orders.** Pending payment lists open orders (ORDERED or PARTIALLY_DISPENSED) whose billing is PENDING/PARTIAL/UNPAID. It takes precedence over New orders and Partial, so an unpaid open order appears only here. Keep PENDING/PARTIAL/UNPAID matching consistent across `pending_payment_queue`, the `pendingPayment` query, and the Payment column.

5. **Completed orders = today.** Completed orders lists status DISPENSED orders completed on the current facility day, scoped by the completion timestamp (the latest ATTEST dispense attestation, else `updated_at`). Update `dispensed_orders` and the `completed` query to the same day scope.

6. **Cancelled orders = today.** Cancelled orders lists status CANCELLED orders cancelled on the current facility day, scoped by the cancellation `updated_at`. Update `cancelled_orders` and the `cancelled` query to the same day scope.

7. **All orders = full history.** All orders lists every order of any status and any date (the historical superset for revisiting history). Keep `total_orders` unscoped by day or status.

8. **Accurate, independent counts.** Each order-tab badge counts exactly its bucket; the active-day buckets (New, Partial, Pending payment, Completed, Cancelled) are mutually exclusive; All orders remains the superset. No order is double-counted across the active-day tabs.

9. **Per-tab Filters, Settings, Export.** Ensure each order tab's Advanced filters, column Settings, and Export operate on that tab's dataset and context: New/Partial/Pending payment offer open-order filters; Completed/Cancelled offer the day plus a date-range override; All orders offers full status + date filters. Export and Settings mirror the active tab's visible columns.

## Constraints

- Reuse `buildWorkbenchSummary`, `buildWorkbenchOrderWhere`, `buildPendingPaymentStatusClause`, `PharmacyOrderFilter`, `_filterForSection`, and `_sectionCount`; introduce no parallel data path.
- Define "today" via the server/facility day boundary already used elsewhere; the date-range advanced filter may override the day scope on Completed/Cancelled.
- Backend RBAC/ABAC stays authoritative; hide unauthorized tabs; never render disabled "no access" controls.
- Preserve stock-alert tabs, dual-price pending payment, brand/generic naming, the catalog dialog, and `?section=` deep links.
- Use theme tokens; keep the strip responsive; define permission, loading, empty, error, success, and validation states per tab.

## Acceptance Criteria

- (R1) Tabs read "Completed orders" and "Cancelled orders"; other labels unchanged.
- (R2, R3, R4) An unpaid open order appears only under Pending payment; New orders and Partial exclude payment-gated orders.
- (R5, R6) Completed orders and Cancelled orders show only the current day's completions/cancellations; their badges match their rows.
- (R7) All orders shows every order across all dates and statuses.
- (R8) Summing the five active-day tab counts never double-counts an order; each badge equals its tab's row total.
- (R9) Each tab's Filters/Settings/Export reflect that tab's dataset and columns.

## Verification

- Extend `pharmacy-workspace.service.test.js`: New/Partial exclude pending payment; Pending payment claims open unpaid orders; Completed/Cancelled day-scoping; independent, non-overlapping counts. Extend `pharmacy_workbench_query_test.dart` and `pharmacy_workspace_page_test.dart` for the renamed labels and count bindings.
- Run backend Jest, `flutter analyze`, and `flutter test`. Manually verify counts are independent, Completed/Cancelled are day-scoped, All orders is historical, and each tab's filters/settings/export match.

## Relevant Files

- `backend/src/modules/pharmacy-workspace/services/pharmacy-workspace.service.js` (`buildWorkbenchSummary`, `buildWorkbenchOrderWhere`, `buildPendingPaymentStatusClause`)
- `backend/src/modules/pharmacy-workspace/services/pharmacy.shared.js`
- `frontend/lib/features/pharmacy/presentation/pages/pharmacy_workspace_page.dart` (`_sectionLabel`, `_sectionCount`, `_filterForSection`)
- `frontend/lib/features/pharmacy/domain/entities/pharmacy_entities.dart` (`PharmacyOrderFilter`, `PharmacyWorkbenchSummary`)
- `frontend/lib/l10n/app_en.arb`
