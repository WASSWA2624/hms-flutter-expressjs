# Worklist Filter & Column Settings Dialog Footer Fix

## Objective

Fix the **Advanced filters** and **Table columns** utility dialogs opened from `AppListTable` / `AppSearchBar` so their footers always show **two actions in a single horizontal row** on all viewport widths. Remove the redundant **Cancel** action — the global `AppDialog` header close (×) already dismisses without applying changes. Keep the scrollable body and fixed footer contract from [`prompt2.md`](./prompt2.md); this pass targets the shared worklist picker dialogs only.

**Smoke URL:** `127.0.0.1:5201/clinical` — verify **Clinical filters** (filter icon) and **Table columns** (settings icon) at **400×498** mobile width, then spot-check OPD and Lab worklists.

---

## Problems observed (screenshots)

### 1. Footer actions stack vertically on narrow viewports

On Clinical Workspace (`clinical_workspace_page.dart`) at ~400px width:

| Dialog | Current footer (top → bottom) | Symptom |
|--------|------------------------------|---------|
| **Clinical filters** | Clear filters → Cancel → Apply filters | Three buttons wrap/stack via `OverflowBar`; footer consumes excessive height |
| **Table columns** | Reset columns → Cancel → Apply columns | Same stacking; **Last updated** checkbox partially hidden behind the tall footer |

**Likely cause:** `_AppSearchBarFiltersDialog` and `_ColumnVisibilityDialog` each pass **three** widgets to `AppDialog.actions`. `_DialogActions` uses `OverflowBar`, which overflows to a second row/column when horizontal space is tight.

### 2. Redundant Cancel action

Both dialogs render **Cancel** in the footer while `AppDialog` already provides a header **×** that pops the route with `null` (no apply). Users see duplicate dismiss affordances; the extra button worsens narrow-layout overflow.

### 3. Footer feels unstable when dialog is resized

On desktop, dragging dialog resize handles can compress the body while the footer action bar reflows. For these lightweight pickers, the footer should remain a **fixed-height, single-row** action strip; only the body scrolls.

---

## Target UX

### A. Two-button footer (app-wide for these dialogs)

Every **Advanced filters** and **Table columns** dialog must follow:

```
┌─────────────────────────────────────┐
│ HEADER (fixed)          [×] close   │  ← dismiss = cancel (no apply)
├─────────────────────────────────────┤
│ BODY (scrollable)                   │  ← fields / checkboxes only
│                                     │
├─────────────────────────────────────┤
│ FOOTER (fixed, single row)          │
│   [Clear/Reset]          [Apply ✓]  │  ← always horizontal
└─────────────────────────────────────┘
```

**Rules:**

| Dialog | Footer actions (left → right) | Remove |
|--------|------------------------------|--------|
| Advanced filters | **Clear filters** (tertiary) · **Apply filters** (primary) | Cancel |
| Table columns | **Reset columns** (tertiary) · **Apply columns** (primary) | Cancel |

- Dismiss without applying: header **×**, barrier tap (when enabled), or `Esc` — same as today.
- Button order matches existing tertiary-then-primary convention (`EmergencyPatientFormDialog`).
- Footer stays **one row** at 360–400px width; no vertical stacking of action buttons.
- Footer height is stable; vertical dialog resize (desktop) grows/shrinks **body only**.

### B. Lightweight dialog chrome

These pickers are short configuration surfaces, not mutation forms:

- Prefer `showMaximizeButton: false` (and disable resize if the shell supports per-dialog opt-out) so users cannot maximize a 5-field filter into a full-screen panel.
- Keep `scrollable: true` on the body so long filter field lists (Clinical has many text filters) scroll independently of the footer.

---

## Implementation

### Primary files

| File | Change |
|------|--------|
| `frontend/lib/shared/components/app_search_bar.dart` | `_AppSearchBarFiltersDialog`: drop Cancel from `actions`; remove or deprecate `cancelLabel` plumbing |
| `frontend/lib/shared/components/app_list_table.dart` | `_ColumnVisibilityDialog`: drop Cancel from `actions`; remove or deprecate `cancelLabel` on dialog + controller APIs |
| `frontend/lib/shared/components/app_dialog.dart` | If needed: improve `_DialogActions` for **two-action** footers on narrow widths (e.g. `Row` + `MainAxisAlignment.end` + `Flexible`/`Wrap` with `maxLines: 1`, or tuned `OverflowBar` spacing) so actions never stack vertically |

### API cleanup (shared components)

Remove unused cancel label parameters from public surfaces (or mark `@Deprecated` and stop passing them):

- `AppSearchBar.advancedFilterCancelLabel`
- `AppListTableSearch.advancedFilterCancelLabel`
- `AppListTable.columnVisibilityCancelLabel`
- `AppListTableColumnVisibilityController.openColumnVisibilityDialog` `cancelLabel`

**Do not** edit every workspace page individually unless a caller still passes `advancedFilterCancelLabel` / `columnVisibilityCancelLabel` after the shared API is cleaned up — grep and delete dead arguments in the same pass.

### Behavior preservation

| Action | Expected result |
|--------|-----------------|
| × / dismiss | `Navigator.pop()` → `null`; filters/columns unchanged |
| Clear / Reset | Resets draft state inside dialog only; dialog stays open |
| Apply | `Navigator.pop(value)` → parent applies filters or column visibility |

No changes to filter payloads, validation, or column visibility logic.

---

## Scope & constraints

- **Shared components only** — one fix applies to Clinical, OPD, Lab, Billing, and all other modules using `AppListTable` / `AppSearchBar`.
- **No behavior regression** — apply/reset/dismiss semantics unchanged except removing footer Cancel.
- **Follow project rules:** `frontend/.cursor/components.mdc`, `design-system.mdc`, `ui-patterns.mdc`, `ui-feedback.mdc`, `localization_i18n.mdc`.
- **Reuse existing helpers** — `AppDialog.actions`, `AppButton.tertiary` / `.primary`; do not introduce a new dialog abstraction.
- **Complements [`prompt2.md`](./prompt2.md)** — that pass covers mutation forms (`AppFormActions` in body); this pass covers worklist filter/column pickers.

---

## Acceptance criteria

1. **Clinical filters** at 400px width: footer shows **Clear filters** and **Apply filters** on **one horizontal row**; no Cancel button.
2. **Table columns** at 400px width: footer shows **Reset columns** and **Apply columns** on **one horizontal row**; all checkboxes (including **Last updated**) scroll above the footer without clipping.
3. Header **×** dismisses both dialogs without applying; Apply still commits changes.
4. Clear/Reset resets draft values inside the open dialog; Apply closes and updates the worklist.
5. Grep: `_AppSearchBarFiltersDialog` and `_ColumnVisibilityDialog` `actions` lists contain **exactly two** buttons each.
6. Dead `*CancelLabel` parameters removed or deprecated with no remaining call-site usage.
7. Existing tests pass; add or extend coverage in `app_search_bar` / `app_list_table` / `app_dialog` tests for narrow-viewport footer layout (two actions visible without scrolling the footer).
8. Manual smoke on `127.0.0.1:5201`: Clinical (both dialogs), OPD worklist filter, Lab table columns — footer single-row at mobile and desktop widths.

---

## Out of scope (this pass)

- Migrating mutation dialogs (`AppFormActions` in body) — see [`prompt2.md`](./prompt2.md).
- Changing filter fields, column definitions, or Clinical worklist business logic.
- Redesigning dialog header chrome beyond optional maximize/resize disable for these pickers.
- New localization strings (reuse existing Clear/Reset/Apply labels).
