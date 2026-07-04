# Lab Result Entry — Lab Orders Table Refinement

## Context

The **Lab Result Entry** dialog (`frontend/lib/features/lab/presentation/pages/lab_result_entry_dialog.dart`) is largely improved. The **patient details** header (name, patient ID, encounter, order summary) is acceptable as-is — **do not change it**.

Focus only on refining the **lab orders / results table** within each order card.

## Problem

The results table is visually noisy and hard to scan:

1. **Weak panel–test hierarchy** — Panel headers (e.g. *Panel Bmp | PANEL_BMP*, *Brucellosis Screen Panel | BRUCSCR*) feel disconnected from their child test rows. It is not immediately obvious which tests belong to which panel.
2. **Duplicate status badges in the Tests column** — Under each test name, two badges often show the same state (e.g. double **Cancelled**, double **Verified**). This comes from `_CompactStatusRow` and `_LabResultLifecycleBadge` both rendering lifecycle/status info.
3. **Duplicate flag in the Result column** — Completed results show the value plus a secondary line like `Flag: Negative`, even though a dedicated **Flag** column already exists (`_CompletedResultReadout`).
4. **Overlong action label** — **Edit verified result** truncates in the Action column; it should be shorter.

## Goal

Make the table **simple, scannable, and easy to read** — one piece of information per column, no redundant labels, clear panel grouping.

## Requirements

### 1. Panel–test visual continuity

- Visually group each panel header with its test rows so the relationship is obvious at a glance.
- Use a single cohesive block per panel (shared container, border, background, or indentation) rather than a floating header above a separate table.
- Preserve existing panel delete/actions on `_PanelGroupHeader` where applicable.

### 2. Tests column — remove duplicate status

- Show **test name only** (plus selection checkbox when bulk actions are enabled).
- Remove redundant status/lifecycle badges from the Tests column (`_CompactStatusRow`, `_LabResultLifecycleBadge`, or equivalent).
- Do **not** lose status meaning: row-level styling already communicates state — keep and rely on:
  - Cancelled/rejected → error background + border
  - Abnormal/high → error-tinted background
  - Verified/normal → neutral/success styling as today
- Status text that must remain visible belongs in the **Flag** or **Action** columns, not duplicated under the test name.

### 3. Result column — value only

- In `_CompletedResultReadout`, display **only the result value** (e.g. `Non-reactive`, `15 | x10^9/L`).
- Remove the secondary `Flag: …` line; flag interpretation stays exclusively in the **Flag** column.
- Keep abnormal result values highlighted in red where applicable.

### 4. Action column — shorter label

- Change **Edit verified result** → **Edit** (`labEditVerifiedResultAction` in l10n, or equivalent).
- Ensure the label fits without truncation at typical table widths.

### 5. General simplification

- Do not add new columns or metadata to the table.
- Avoid reintroducing information that already has a dedicated column.
- Match existing design tokens, spacing, and component patterns (`AppButton`, `AppWorkspaceStatusBadge`, theme colors).

## Out of scope

- Patient details / encounter header
- Footer actions (Preview report, Create Lab Order, Edit order, Delete order, Close)
- Backend/API or result-entry workflow logic (save, verify, restore, reject)
- Report preview dialog

## Acceptance criteria

- [ ] Each panel reads as one unified group; child tests are clearly nested under their panel header.
- [ ] Tests column shows test name only — no duplicate Cancelled/Verified/Draft badges.
- [ ] Cancelled, abnormal, and verified rows remain distinguishable via row color/border styling.
- [ ] Result column shows the value only; no `Flag:` sub-label.
- [ ] Flag column remains the single source for Normal / Negative / High / Cancelled flags.
- [ ] Verified-result action button reads **Edit** and does not truncate.
- [ ] Existing tests pass; update or add widget tests if behavior changes.

## Key files

- `frontend/lib/features/lab/presentation/pages/lab_result_entry_dialog.dart`
- `frontend/lib/l10n/app_en.arb` (action label)
- `frontend/test/features/lab/presentation/` (if applicable)
