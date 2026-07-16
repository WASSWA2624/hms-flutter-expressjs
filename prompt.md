# Table Standardization

**Objective:** Every worklist table in the HMS Flutter client must share the same chrome, column layout, interaction model, and data freshness behavior so users can scan, filter, and act on records consistently across modules.

**Scope:** All `AppListTable` instances on workspace screens and tab panels. 

## 1. Search chrome (global search bar)

Every table must expose a global search bar that matches across **all** declared columns (visible and hidden) via `AppListTableSearch.matcher` (or `searchMatcher` when search is external).

The search bar may contain **only** these trailing controls — no export, refresh, overflow, or screen-level actions here (those belong in the tab toolbar):


| Control      | Button label | Opens                             | Wiring                                                                                                                                             |
| ------------ | ------------ | --------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Filters**  | `Filters`    | Modal titled **Advanced filters** | `showAdvancedFilterButton: true`, `onAdvancedFilterPressed` or `filterGroups` / `onFilterChanged` on `AppListTableSearch`                          |
| **Settings** | `Settings`   | Modal titled **Table Settings**   | `columnVisibilityLabel: l10n.commonTableSettingsActionLabel`, `columnVisibilityTitle` set to **Table Settings** (add a shared l10n key if missing) |


**Requirements:**

- Use standardized English labels exactly as shown (`Settings` via `commonTableSettingsActionLabel`; prefer a shared `commonFiltersActionLabel` / `commonAdvancedFiltersTitle` rather than per-screen variants where feasible).
- Column visibility preferences must persist for the **session** using `AppListTableColumnVisibilityController` with a stable `columnVisibilityStorageKey` per table.
- Do not place Filters or Settings in the tab toolbar; they live only in the table search chrome.

---



## 2. Column content rules

- **One semantic field per column.** Do not combine unrelated fields (e.g. name + ID in one column). Each `AppListTableColumn` maps to a single domain attribute or a single computed display value.
- **Allowed two-line display:** When one field has a natural primary and secondary tier (e.g. patient name + MRN), render the primary value prominently and the secondary in `bodySmall` / `AppListItemText` subtitle style. This is still one field, not two columns merged.
- **No duplicate columns.** Every column must surface distinct information.

---



## 3. Column layout (maximum five declared columns)

`AppListTable` renders an automatic **row-number** column from pagination (`firstItemNumber`); do **not** add a row-number column to the `columns` list.

The `columns` array is limited to **five** entries:


| Position | When workflow status exists                                                | When no workflow status                 |
| -------- | -------------------------------------------------------------------------- | --------------------------------------- |
| 1–3      | Three highest-priority, context-relevant data fields for the active tab    | Up to five highest-priority data fields |
| 4        | **Status** — unambiguous label via `AppWorkspaceStatusBadge` or equivalent | (optional fourth data field)            |
| 5        | **Next action** — explicit action control (see §4)                         | (optional fifth data field)             |


Pick the three data columns per tab based on what clinicians/operators need first when triaging that worklist. Hide lower-priority fields behind **Settings** (`columnChoices`) rather than exceeding five visible defaults.

---



## 4. Status and next-action columns

When the entity has workflow state:

- **Status column (second from the right):** Show the current status with a clear, human-readable label — never raw API codes without formatting.
- **Next-action column (rightmost):** A single explicit action control labeled with the **specific** required action (e.g. `Approve`, `Assign doctor`, `Discharge`) — never generic text like `Next step` or `Action`.
- **On press:** The control must either open the existing contextual dialog for that action or deep-link to the precise screen/tab where the action is completed. Do not navigate to a generic module home.
- Prefer `WorkflowActionButton` (or the module’s established workflow-action widget) when the entity participates in the shared workflow system.

Users must always be able to read current status and the next required action from the row without opening the detail dialog.

---



## 5. Row selection and detail dialog

- Wire `onRowSelected` (or equivalent row tap / mobile “hero” tap) to open a **modal dialog** with full record context.
- **Reuse** existing dialogs from `frontend/lib/shared/` or the feature’s `presentation/widgets/` / `presentation/dialogs/` — do not duplicate detail UIs.
- The detail dialog must expose clear follow-up actions (same actions available from the next-action column where applicable).

---



## 6. Responsiveness

- Use `displayMode: AppListTableDisplayMode.adaptive` unless a tab has a documented reason not to.
- Provide a meaningful `mobileItemBuilder` that surfaces the same priority fields, status, and next action as the desktop row.
- Tables must remain usable at narrow widths (horizontal scroll is acceptable; clipping primary actions is not).

---



## 7. Shared components and data mapping

- Build on `AppListTable` and related shared widgets under `frontend/lib/shared/components/`.
- Map each column’s `cellBuilder` to the correct entity field; sorting (`sortComparator`) must use the same underlying value.
- Register `columnVisibilityStorageKey` and `columnWidthStorageKey` per table instance when the screen hosts multiple tables.

---



## 8. Real-time data freshness

Table rows, status badges, and action availability must reflect the latest server state without a manual page reload:

- Controllers read from Riverpod providers fed by repository sync / WebSocket reconciliation (see `frontend/.cursor/realtime_sync.mdc` and `frontend/.cursor/instant_ui_sync.mdc`).
- After a successful mutation or inbound domain event, the worklist provider updates and the table re-renders from provider state — never by mutating table widgets directly.

---



## Acceptance checklist (per table)

- [ ] Global search matches all columns (including hidden)
- [ ] Search chrome has **only** Filters (`Advanced filters` modal) and Settings (`Table Settings` modal)
- [ ] Session-persisted column visibility via `AppListTableColumnVisibilityController`
- [ ] ≤ 5 declared columns; row number is automatic, not declared
- [ ] One semantic field per column; two-line display only for primary/secondary tiers of one field
- [ ] Status and next-action columns present when entity has workflow (explicit labels; contextual navigation/dialog)
- [ ] Row tap opens reused detail dialog with follow-up actions
- [ ] Adaptive layout + `mobileItemBuilder` parity
- [ ] Real-time refresh via Riverpod providers

Apply these standards to every screen that presents tabular worklists.