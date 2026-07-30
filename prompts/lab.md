# Simplify Lab Worklist — Tabs, Chrome, Filters, and Counts

Simplify the Lab workspace (`/lab`) so tabs are fewer and clearer, strip redundant toolbar chrome, keep Create Lab Order in the search bar, and fix tab counts so each badge reflects independent backend totals.

## Context

- Surface: `LabWorkspacePage` + `LabWorkspaceController` at `/lab?section=…`. Current tabs (UI labels): **All**, **Awaiting results**, **Processing**, **Critical**, **Completed**, **Follow-ups**. Default opens **All** (`worklist`).
- Observed chrome under the tabs: **Orders view** / patients toggle, **Lab Configurations**, and **+ Create Lab Order**. Configurations belong in admin/facility setup, not Lab.
- Observed defects: switching to an empty tab (e.g. Processing with count 0) can zero other tab badges (e.g. All); worklist does not always fill remaining viewport height; tab filters and search-bar filters are not one shared filter model.
- Domain today: `LabDeskSection` / `LabQueueScope` include `processing`; workbench supports `LabWorkbenchView.patients|orders`. Patient-grouped worklist columns remain the only table mode after this change.
- Permissions: `lab_access.dart` tab/strip atoms; unauthorized UI must not render. Follow `prompts/.cursor/prompt.mdc`.



## Requirements

1. **Remove Processing entirely.** Drop the Processing tab, its URL (`section=processing`), queue scope, summary fields used only for that badge, strip actions, billing/permission inventory atoms, empty states, and related tests. Redirect stale `?section=processing` (and aliases) to **Pending**.
2. **Rename and redefine remaining tabs** (keep URL aliases where safe; update labels via l10n):
  - **All** — full worklist (not default).
  - **Pending** (was Awaiting results / `collection`) — orders whose results are not yet completed (new/pending entry).
  - **Critical** — Results completed (or entered) today that are abnormal / outside reference range so staff can act on them here.
  - **Completed today** (was Completed) — results completed for the current facility day only.
  - **Follow-ups** — patients/results flagged for lab follow-up (existing follow-ups table/fields).
3. **Default section = Pending.** Opening `/lab` with no `section` (and `labFallbackSection`) lands on Pending when allowed; otherwise the first allowed remaining tab.
4. **Remove the section toolbar.** Delete **Orders view** / patients↔orders toggle and **Lab Configurations** from every Lab tab. Do not open catalog/config from Lab; admin/facility setup remains the configuration path. Keep a single patient-grouped worklist (no orders-view mode in the UI).
5. **Move Create Lab Order into the table search bar.** Place it at the extreme right of the search/filter row (with Filters / Settings). On compact widths show icon-only; on large widths show icon + label. Gate with existing create permission; omit when unauthorized. Follow-ups may omit create if that tab already excludes it.
6. **One shared filter model.** Tab selection applies the same comprehensive filter vocabulary as the search-bar Filters control (status/queue, criticality, completed-today, follow-up, search text, etc.). Changing a tab updates those filters; changing Filters updates the worklist the same way. When applied Filters best match another tab’s definition, activate that tab (most similar / exact match) and keep URL `section` in sync.
7. **Independent, accurate tab counts.** Each tab badge is the backend total for that tab’s definition, independent of the active tab and of the current page of rows. Switching tabs must not overwrite or zero other badges. Counts match database/API summary fields for All, Pending, Critical, Completed today, and Follow-ups.
8. **Worklist fills height and scrolls.** Whether empty or loaded, the table/empty-state region spans the remaining viewport height under the search bar; content is infinitely (or continuously) scrollable within that region—no unused gap below the table chrome. Pagination/footer remains usable; no overflow/clipping on mobile, tablet, or desktop.
9. **UI states.** Preserve loading, empty, error/retry, success, and validation feedback. Empty copy stays short (e.g. no patients matching the active filters). Light and dark themes; theme tokens only.
10. **Tests.** Cover: Processing absent + redirect; default Pending; no Orders view / Lab Configurations controls; Create in search bar (authorized present / unauthorized absent); tab↔filter sync and tab activation from filters; counts stable when switching to an empty tab; Completed today scoped to today; Critical = abnormal/out-of-range; height/scroll smoke on a representative viewport; l10n keys for new labels.



## Constraints

- Scope: Lab feature (workspace page, controller, entities/DTOs/API query params as needed), lab l10n, lab access/billing inventories, and lab tests. Do not redesign unrelated workspaces.
- Reuse existing search bar, filters, table, create-order dialog, and permission atoms; remove dead Processing / view-toggle / in-Lab configuration paths rather than leaving hidden stubs.
- Backend RBAC/ABAC remains authoritative; no unauthorized UI.
- Optional enhancements: none.



## Acceptance Criteria

- AC1 (Req 1): Processing tab and related UI/API surface are gone; `section=processing` resolves to Pending.
- AC2 (Req 2–3): Tabs are All, Pending, Critical, Completed today, Follow-ups; `/lab` defaults to Pending when allowed.
- AC3 (Req 4–5): No Orders view or Lab Configurations on Lab; Create Lab Order sits at the right of the search bar with responsive icon/label behavior and correct permission gating.
- AC4 (Req 6): Tab and search-bar filters share one model; filter changes activate the matching tab and update the URL.
- AC5 (Req 7): Each tab badge stays correct and independent when switching tabs, including to empty queues.
- AC6 (Req 8–9): Worklist/empty state fills remaining height and scrolls; loading/empty/error/success remain observable in light and dark themes.
- AC7 (Req 10): Listed tests pass.



## Relevant Files

- `frontend/lib/features/lab/presentation/pages/lab_workspace_page.dart`
- `frontend/lib/features/lab/presentation/controllers/lab_workspace_controller.dart`
- `frontend/lib/features/lab/presentation/lab_access.dart`
- `frontend/lib/features/lab/domain/entities/lab_entities.dart`
- `frontend/lib/features/lab/data/repositories/lab_repository_impl.dart`
- `frontend/lib/features/lab/presentation/lab_*_billing_inventory.dart`
- `frontend/lib/l10n/app_en.arb`
- `frontend/test/features/lab/`
- Backend lab workbench/summary endpoints used for scope counts and completed-today / critical filters

