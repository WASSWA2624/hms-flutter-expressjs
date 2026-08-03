# Fix pharmacy desk counts, prescription detail items, and dispense history

## Objective

Align the Pharmacy workbench so desk tab badges match the visible order queues, prescription detail always shows the ordered medication lines, the items table has no outer section border, and dispense history entries open a printable dispense-batch detail dialog—without changing existing dispense, cancel, print-instructions, billing-gate, or permission behavior unless required to fix the defects below.

## Context

**Scope:** Pharmacy desk (`/pharmacy`) — New Orders, Partial, Completed, Cancelled, All Orders — and the prescription detail dialog opened from a worklist row.

**Current behavior (codebase):**

- Tab badges use `PharmacyWorkbenchSummary` (`orderedQueue`, `partiallyDispensedQueue`, `dispensedOrders`, `cancelledOrders`, `totalOrders`) from the workbench API. Backend `buildWorkbenchSummary` counts against `summaryBaseWhere`, which strips status, location, payment, today, and **search**. The list query uses a narrower `where` (section filter + search + advanced filters). Result: badges can show `4` while the filtered list shows `1` row (patient name primary; `ORD…` subtitle is the order `displayId`).
- Completed / Cancelled list filters use `todayOnly: true`; those bucket counts are also today-scoped. Older dispensed/cancelled orders still inflate `totalOrders` while other tabs stay empty.
- Prescription detail (`_PharmacyDetailPanel`) renders patient details → actions (Dispense / Cancel / Print instructions) → `_MedicationItemsPanel` → `_TimelinePanel`. Items resolve as `workflow.items` if non-empty, else `workflow.order.items`. Users report detail opening with **no lines** while the worklist shows item/dispensed counts (e.g. 21 prescribed, 0 dispensed).
- `_MedicationItemsPanel` wraps `AppListTable` in `AppCollapsibleSection`, which always draws `Border.all` — an unwanted outer frame around the table.
- “Dispense history” is the timeline (`AppTimeline` from `workflow.timeline`). Entries are not tappable. There is no dispense-batch items dialog and no print for a past dispense batch. Print exists only as **Print instructions** on the actions panel.
- Order rows are **one pharmacy order each**, not one patient. Preserve that model.

**Intended behavior:** Counts trustworthy vs what the pharmacist sees; detail always lists ordered items; table chrome matches a bare list table; timeline dispense events open batch line items with print.

## Requirements

1. **Correct desk tab counts** so each Pharmacy desk section badge equals the number of orders that belong in that section under the same facility/scope rules as the worklist for that section (New Orders / Partial / Pending payment if present / Completed / Cancelled / All Orders). Define “belongs” consistently with existing status and payment gates (`ORDERED` + payment cleared, `PARTIALLY_DISPENSED` + payment cleared, pending-payment queue, `DISPENSED`, `CANCELLED`, all non-deleted orders for All). If Completed/Cancelled remain today-scoped, badges for those tabs must use the same today scope as their lists; document that in UI copy only if already present—do not invent new day filters.
2. **Keep badge and list filters aligned for search and advanced filters.** When the user has an active search or advanced filter that shrinks the list, either (a) apply the same constraints to the summary buckets shown on the strip, or (b) clearly derive the strip count from the same query total as the list (`pagination.total` / filtered count) so a single visible order cannot contradict a larger badge. Prefer one coherent rule across all desk tabs; do not leave summary global while the list is filtered.
3. **Fix empty medication lines on prescription detail.** When opening New Orders (or any section) detail for an order that has prescribed items, the items table must show those lines with prescribed vs dispensed quantities. Trace worklist `item_count` / quantity fields through `selectOrder` → workflow GET → DTO → `_MedicationItemsPanel`. Prefer fixing the payload or mapping so `workflow.items` (and fallback `order.items`) are populated; do not hide empty state when the order truly has zero lines.
4. **Remove the outer border around the medication items table** in prescription detail. Render the items `AppListTable` without the enclosing `AppCollapsibleSection` border treatment (or equivalent borderless container). Keep search, columns, empty state, and row actions. Do not strip borders from unrelated panels (patient details, actions, timeline) unless required for consistency with this requirement.
5. **Make dispense history interactive.** Keep the timeline (or an equivalent dispense-history list) on prescription detail. For entries that represent a dispense batch (timeline types / `dispense_batch_ref` / related `PharmacyDispenseLog` groups), tapping opens a dialog listing the medications and quantities in that dispense event.
6. **Support print from the dispense-batch dialog.** From that dialog, provide print of the dispense contents, reusing existing pharmacy print helpers / print document templates and permissions where possible (extend `pharmacy_instructions_print_helpers` or sibling helpers rather than a one-off printer). Preserve existing **Print instructions** on the actions panel.
7. **Preserve existing pharmacy actions and gates:** Dispense, Cancel order, Print instructions, payment-before-dispense, attest/return flows, RBAC/ABAC via `pharmacy_access.dart` and backend permissions, realtime refresh after mutations, and light/dark theme tokens.

### Optional enhancements

- Group timeline rows by `dispense_batch_ref` so one tap maps cleanly to one batch dialog.
- After fixing counts, add a regression test that filtered search cannot leave All Orders badge > filtered list total under the chosen alignment rule.

## Constraints

- Reuse Pharmacy workbench APIs, entities/DTOs, `AppListTable`, `AppTimeline`, `showAppDialog` / `AppDialog`, existing print pipeline, and permission atoms. Do not invent parallel queues or a second detail surface.
- Follow `.cursor/flows/pharmacy-flow.mdc`: pharmacy owns dispensing; do not create encounters or change OPD/IPD stages; keep dispenses tied to the source encounter.
- Backend remains authoritative for counts and workflow payloads; fix serializer/include/query if the empty-items bug is server-side.
- Unauthorized controls must not render; no routine “no access” placeholders.
- Stay under focused diffs: pharmacy frontend presentation/controller/DTO and pharmacy-workspace backend summary/serialize paths as needed.
- Prompt standards: `prompts/.cursor/prompt.mdc`.

## Acceptance Criteria

| ID | Criterion | Traces to |
|----|-----------|-----------|
| A1 | For each desk tab, with no search/advanced filters, the badge count matches the number of orders returned for that section’s filter (or pagination total for that filter). | R1 |
| A2 | With an active search or advanced filter that yields one order in the list, no desk badge for the active section (and All Orders, under the chosen rule) shows a larger contradictory count for that same filtered set. | R2 |
| A3 | Opening prescription detail for an order with prescribed lines shows those lines in the items table (prescribed/dispensed visible); empty state only when the order has zero lines. | R3 |
| A4 | Medication items table in detail has no outer section border/frame around the table. | R4 |
| A5 | Tapping a dispense-history/timeline dispense entry opens a dialog listing that batch’s items and quantities. | R5 |
| A6 | The dispense-batch dialog can print those dispensed items via the existing print path; Print instructions on actions still works. | R6 |
| A7 | Dispense, Cancel, billing gate, and permission-gated UI remain unchanged except where required for A1–A6. | R7 |

## Relevant Files

- `frontend/lib/features/pharmacy/presentation/pages/pharmacy_workspace_page.dart` — desk counts, detail dialog, `_MedicationItemsPanel`, `_TimelinePanel`, actions/print
- `frontend/lib/features/pharmacy/presentation/controllers/pharmacy_workspace_controller.dart` — `selectOrder`, workbench refresh
- `frontend/lib/features/pharmacy/domain/entities/pharmacy_entities.dart` — filters, workflow, dispense logs, timeline
- `frontend/lib/features/pharmacy/data/dtos/pharmacy_dtos.dart` — summary + workflow mapping
- `frontend/lib/features/pharmacy/data/repositories/pharmacy_repository_impl.dart` — query params
- `frontend/lib/features/pharmacy/presentation/pharmacy_instructions_print_helpers.dart` — print reuse
- `frontend/lib/features/pharmacy/presentation/pharmacy_access.dart` — tab/action permissions
- `frontend/lib/shared/components/app_collapsible_section.dart` — outer border source
- `backend/src/modules/pharmacy-workspace/services/pharmacy-workspace.service.js` — `buildWorkbenchSummary` / workbench where
- `backend/src/modules/pharmacy-workspace/services/pharmacy.serializer.js` — items, quantities, timeline, dispense logs
- `backend/src/modules/pharmacy-workspace/services/pharmacy.shared.js` — order includes
- Tests: `frontend/test/features/pharmacy/presentation/pharmacy_*_permissions_test.dart`, `pharmacy_workspace_page_test.dart`, `pharmacy_instructions_print_helpers_test.dart`; backend `pharmacy-workspace.service` tests

## Verification

1. Manual: create/open an ORDERED clinical order with multiple lines → New Orders badge = 1 (or correct N) → open detail → all lines visible → no outer border on items table.
2. Manual: apply search that matches one of several orders → list and badges stay coherent per R2.
3. Manual: partially dispense → Partial/Completed badges and lists update; timeline entry opens batch dialog → print succeeds.
4. Automated: extend/add unit or widget tests for summary/list alignment rule, detail items fallback/payload, timeline tap → dialog, and print helper for a dispense batch; keep permission tests green (unauthorized UI absent).
5. Check mobile/desktop detail dialog scroll, empty/loading/error states, and light/dark themes.
