# Task: HR staff detail dialog — compact overview and unified actions

## Goal

Redesign the **Staff detail** modal (`/hr` → directory row) so identity and employment facts read like a compact **information sheet** (label + value rows, not bordered cards), and all staff mutations live under a **single Actions section** with left-to-right wrapping buttons. The layout must remain clean on mobile, tablet, and desktop at default and maximized dialog sizes.

**Prerequisite:** `AppDialog` resize and true viewport maximize must already work (see companion dialog-sizing work if not landed yet).

## Context

Staff detail opens from the HR directory via `_openStaffDetailDialog` → `showAppDialog` + `AppDialog` in `hr_workspace_page.dart`. Content is rendered by `_HrStaffDetailPanel` / `_HrStaffDetailBody`.

| Area | Current implementation |
| --- | --- |
| Dialog shell | `AppDialog` — title **"Staff detail"**, `maxWidth: 980`, scrollable |
| Header identity | `AppWorkspaceDetailPanel` — staff name, display ID, edit icon |
| Overview | `AppInfoTileGrid` with bordered `AppInfoTile` cards (staff number, name, position, department, hire date, etc.) |
| Linked user | `_LinkedUserSummary` — separate bordered panel |
| Actions | Four `AppActionSection`s: **Placement**, **Scheduling**, **Payroll**, **Access** — each with its own titled card and `minItemWidth: 200` grid |
| Records | `_SmallRecordSection` for assignments, leave, availability, shifts, compensation (keep as-is) |

Design references: `frontend/.cursor/design-system.mdc`, `ui-workspace.mdc`, `ui-patterns.mdc`.

**Reference screenshots (current UI):**

- Overview uses large bordered tiles; wastes vertical space and feels like a dashboard, not a staff record sheet.
- Action groups (Placement → Scheduling → Payroll → Access) stack as separate sections with sparse button grids.

## Problems (observed at `127.0.0.1:5201/hr`)

### 1. Overview feels like card tiles, not a staff record

`AppInfoTileGrid` renders each field (staff number, name, position, department, hire date) as an individual bordered card with icon, label, and value. This layout:

- Consumes excessive vertical space in the dialog.
- Repeats labels visually (e.g. staff name appears in the panel header and again in Overview).
- Does not match the desired **paper/sheet** metaphor: compact rows with label on the left and value on the right (or label above value in a tight column), with multiple fields per row where width allows.

### 2. Action groups are fragmented

Placement, Scheduling, Payroll, and Access each render as separate `AppActionSection` panels with section titles and internal grids. The user must scroll past four headings to reach record sections (Assignments, Leave, etc.). All staff mutations should appear under **one** umbrella section titled **Actions** (use existing `l10n.hrStaffActionsTitle` — **"Staff actions"** — or add `hrActionsSectionTitle` → **"Actions"** if product prefers the shorter label).

### 3. Action buttons do not flow naturally

Current `AppActionSection` + `minItemWidth: 200` produces columnar grids with large gaps. Desired behavior: buttons aligned **left to right**, wrapping to the next line only when the row is full — similar to `AppPermissionActionList` with `Wrap` / `AppResponsiveWrap` and **no per-category sub-headings**.

### 4. Responsive behavior needs verification

Layout must work at:

- **Mobile** — dialog near minimum width (~360px); overview fields stack; action buttons wrap cleanly.
- **Tablet / default dialog** (~980px); overview uses 2–3 columns of label/value pairs where sensible.
- **Desktop / maximized** — same components scale without overflow or orphaned single-button rows.

## Requirements

### 1. Replace overview card grid with a compact info sheet

- Remove `AppInfoTileGrid` from `_HrStaffDetailBody` overview.
- Introduce a compact label/value layout. Preferred options (pick the smallest change that meets the design):

  **Option A (preferred):** Add a reusable shared widget, e.g. `AppInfoSheet` / `AppInfoSheetGrid`, under `frontend/lib/shared/components/` — flat rows, optional subtle dividers, no per-field borders or icons unless copy affordance requires it.

  **Option B:** Inline a private `_StaffOverviewSheet` in `hr_workspace_page.dart` if the pattern is HR-only for now.

- **Fields to include** (same data as today; omit empty optional fields):

  | Label | Source |
  | --- | --- |
  | Staff number | `profile.staffNumber ?? profile.displayId` — copyable |
  | Staff name | `profile.displayName` |
  | Position | `profile.position` (if non-empty) |
  | Practitioner type | `profile.practitionerType` (if non-empty) |
  | Department | `profile.departmentName ?? profile.departmentDisplayId` |
  | Hire date | formatted `profile.hireDate` |

- **Layout rules:**

  - Each row: **label** (muted, `labelMedium` / `bodySmall`) + **value** (primary text, `bodyMedium`, semibold optional).
  - Use a responsive grid: **1 column** on narrow widths, **2 columns** from ~480px, **3 columns** from ~720px within the dialog content.
  - No bordered card per field; optional single `AppContentPanel` wrapper for the whole Overview block is fine.
  - Unknown/empty values: keep `l10n.profileUnknownValue` (do not show raw enum tokens or UUIDs when a display name exists).
  - Preserve copy-to-clipboard on staff number via `AppCopyableIdentifier`.

- **Linked user:** Fold into the same sheet style under Overview (or a tight sub-block immediately below) — name, email, copyable user ID — instead of a separate heavy bordered panel. Keep the link icon or a small **Linked user** subheading for scanability.

- **Do not duplicate** the staff display name in Overview if it already appears in `AppWorkspaceDetailPanel.title`; overview may omit **Staff name** or show it only when it adds context (e.g. legal name vs preferred). Prefer omitting when redundant.

### 2. Consolidate all staff actions under one section

- Replace `_groupedStaffActionSections` (four `AppActionSection`s) with **one** `AppSectionPanel` titled **Staff actions** / **Actions**.
- Collect the **same** permission-gated handlers into a single ordered list (do not change mutation logic):

  1. Assign department  
  2. Assign position  
  3. Record availability  
  4. Assign shift  
  5. Swap shift  
  6. Request leave  
  7. Compensation  
  8. Run payroll  
  9. Assign role *(only when linked user exists)*  
  10. View module access *(only when linked user exists)*  

- Render with `AppPermissionActionList` (or equivalent) using `Wrap` / `AppResponsiveWrap`:
  - **Left-aligned**, natural reading order.
  - **Wrap** to next line when horizontal space runs out.
  - Suggested `minItemWidth`: ~140–160px (tune so buttons are compact but tappable on mobile).
  - **Remove** intermediate section titles: Placement, Scheduling, Payroll, Access.
  - Keep existing `AccessRequirement` gates and `enabled: !state.isMutating` behavior.

### 3. Preserve record sections and dialog chrome

- **Keep unchanged** (layout only, no feature work): Roles list (if shown), Assignments, Leave, Availability, Shifts, Compensation record sections (`_SmallRecordSection`).
- **Keep** dialog title **"Staff detail"** in `AppDialog`; staff name + display ID in `AppWorkspaceDetailPanel`; header edit button.
- **Remove** redundant footer Close if still present (header ✕ only) — align with [prompt1.md](./prompt1.md) footer cleanup.

### 4. Extract widgets if `hr_workspace_page.dart` grows

If overview sheet or actions block adds significant code, extract to:

- `frontend/lib/features/hr/presentation/widgets/hr_staff_detail_overview.dart`
- `frontend/lib/features/hr/presentation/widgets/hr_staff_detail_actions.dart`

Keep `_HrStaffDetailBody` as the composition root.

## Acceptance criteria

1. Open staff detail for a demo staff member (e.g. Avery Demo): Overview shows compact label/value rows — **no bordered per-field cards**.
2. Staff number and linked user ID remain copyable.
3. Exactly **one** actions section appears above Assignments; all 8–10 action buttons visible (permission permitting) in a single left-to-right wrapping row.
4. No section titles **Placement**, **Scheduling**, **Payroll**, or **Access** in the dialog body.
5. At ~360px content width: no horizontal overflow; overview stacks; action buttons wrap without clipping.
6. At default (~980px) and maximized dialog: layout balanced; no Flutter overflow stripes.
7. Every action still opens the same dialog/handler as before; permission-denied actions still hidden or disabled per existing rules.
8. `flutter analyze` passes; add or update a widget test for overview sheet columns and action wrap at narrow/wide constraints if practical.

## Out of scope

- Backend or API changes
- New staff actions or mutation workflow changes
- Work queues, schedule templates, or HR activity dialog changes ([prompt1.md](./prompt1.md))
- Redesigning Assignments / Leave / Availability / Shifts / Compensation **record lists**
- `AppDialog` sizing/maximize implementation (separate prerequisite)
- Staff directory table column changes

## Key files

```
frontend/lib/features/hr/presentation/pages/hr_workspace_page.dart   # _HrStaffDetailPanel, _HrStaffDetailBody, _groupedStaffActionSections, _LinkedUserSummary
frontend/lib/features/hr/presentation/widgets/hr_enhanced_dialogs.dart
frontend/lib/shared/actions/app_action_panel.dart                    # AppPermissionActionList, AppActionSection
frontend/lib/shared/components/app_info_tile.dart                    # AppInfoTileGrid (replace in overview only)
frontend/lib/shared/components/app_content_panel.dart                # AppSectionPanel, AppContentPanel
frontend/lib/l10n/app_en.arb                                         # hrStaffActionsTitle; optional hrActionsSectionTitle
frontend/test/features/hr/                                           # add/update widget tests
```

## Suggested implementation order

1. Build `AppInfoSheet` (or private equivalent) and swap Overview + linked user.
2. Refactor `_groupedStaffActionSections` → single `AppSectionPanel` + flat `AppPermissionActionList`.
3. Smoke-test all action buttons and responsive breakpoints.
4. Extract widgets if the panel file grows unwieldy.
