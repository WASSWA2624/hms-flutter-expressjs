/reception

---

# Table Standardization Prompt Generator — Reception

You are a coding AI agent acting as a **prompt generator**. Your job is to audit the codebase for the **Reception** screen, then produce a comprehensive, context-aware refactoring prompt that another coding AI agent can execute autonomously — and save that prompt to `prompts/02-reception-prompt.md` (same name as this generator file, without `-generator`).

The generated prompt **MUST** be fully compliant with the table rules in `prompt.md` (Table Standardization). Every acceptance criterion in the generated prompt must map back to those rules.

## Pre-filled screen context (do not invent alternatives)

| Field | Value |
|-------|-------|
| Route | `/reception` |
| Screen name | Reception |
| Page widget | `ReceptionWorkspacePage` |
| Primary page file | `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart` |
| Feature module | `reception` |
| Known tabs | Appointments, Queue, Active visits, Payment gate |
| Purpose | Front-desk appointments, queue, active visits, and payment gate. |
| Has workflow status columns | Yes |
| Row detail handler (starting point) | `openReceptionPatientEditor` |

- Deep-link query parameter pattern: `?section=<value>`

### Known table inventory (validate and complete during audit)

| # | Table widget | File | Entity | Columns today | Detail on row select |
|---|--------------|------|--------|---------------|----------------------|
| 1 | _ReceptionDeskTable (inline in _ReceptionWorkspaceContentState) | `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart` | `_ReceptionDeskRow` | 4 (audit exact) | [discover during audit] |

The executing agent that runs your generated prompt must:
- Have full read/write access to the codebase.
- Be able to create, modify, and delete files.
- Be able to run shell commands (tests, linting, formatting).
- Operate without human clarification — all instructions must be unambiguous and self-contained.
- Receive explicit file paths, exact class/widget names, column definitions, and concrete code patterns.

---

## Mandatory compliance source: `prompt.md`

Before generating anything, read `prompt.md` at the repository root. The generated prompt **must enforce all of the following** for **Reception** (`/reception`) — **for every `AppListTable` on this screen**:

### §1 Search chrome
- Global search bar matching all declared columns (visible and hidden).
- Search bar trailing controls limited to **Filters** (opens **Advanced filters** modal) and **Settings** (opens **Table Settings** modal).
- `columnVisibilityLabel: l10n.commonTableSettingsActionLabel` (`Settings`); set `columnVisibilityTitle` to **Table Settings**.
- Session-persisted column visibility via `AppListTableColumnVisibilityController` + stable `columnVisibilityStorageKey` per table.

### §2 Column content
- One semantic field per column; allowed two-line primary/subtitle for a single field via `AppListItemText` / `bodySmall`.
- No duplicate or merged unrelated fields in one column.

### §3 Column layout
- Do **not** declare a row-number column (`AppListTable` adds it automatically).
- Maximum **five** entries in each table's `columns` array.
- When workflow applies: three priority data columns + status + explicit next-action column.
- When no workflow: up to five priority data columns; extras belong in `columnChoices` (hidden by default).

### §4 Status and next-action
- **Status column (second from right):** `AppWorkspaceStatusBadge` with formatted label.
- **Next-action column (rightmost):** explicit verb label per workflow stage; prefer `WorkflowActionButton` when applicable.
- Press opens contextual dialog or deep-links to the precise tab/screen — never a generic module home.

### §5 Row selection
- `onRowSelected` / row tap opens a modal detail dialog reusing existing feature/shared dialogs.
- Detail dialog exposes follow-up actions aligned with the next-action column.

### §6 Responsiveness
- `displayMode: AppListTableDisplayMode.adaptive` and a `mobileItemBuilder` mirroring desktop priority fields, status, and actions.

### §7 Shared components
- Build on `AppListTable`, `AppListTableSearch`, `AppListTableColumn` from `frontend/lib/shared/components/app_list_table.dart`.
- Distinct `columnVisibilityStorageKey` and `columnWidthStorageKey` when multiple tables exist on one screen.

### §8 Real-time freshness
- Table data flows from Riverpod providers with WebSocket/sync reconciliation (`frontend/.cursor/realtime_sync.mdc`, `frontend/.cursor/instant_ui_sync.mdc`).

**Objective:** Every worklist table on Reception must match the same chrome, column budget, interaction model, and freshness behavior defined in `prompt.md`.

---

## Step 1: Codebase Discovery (mandatory — do this first)

Perform a full audit focused on `/reception` / `ReceptionWorkspacePage`.

### 1.1 Locate the target screen

- Start at `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart` and walk all imports: widgets, controllers, providers, repositories, models, routes, dialogs, and tests under `frontend/lib/features/reception/`.
- Map every `AppListTable` instance (widget class, file, entity type, tab/panel binding).
- Document current columns per table: `id`, label, field mapped, sort comparator, cell builder pattern.

### 1.2 Audit reference implementations (read only)

Read these files before generating the prompt:

- `frontend/lib/shared/components/app_list_table.dart`
- `frontend/lib/features/mortuary/presentation/pages/mortuary_workspace_page.dart` (`_MortuaryWorklist` — Filters/Settings chrome)
- `frontend/lib/features/emergency/presentation/widgets/emergency_workspace_widgets.dart` (`emergencyNextActionColumn`, `WorkflowActionButton`)
- Closest on-screen reference: **mortuary (_MortuaryWorklist Filters/Settings chrome)**
- `prompt.md`

Extract:
- How `AppListTableSearch` wires Filters (`showAdvancedFilterButton`, `filterGroups`, `advancedFilterTitle`).
- How Settings opens column visibility (`columnVisibilityController`, `columnVisibilityTitle`).
- How next-action buttons and status badges are rendered.
- How `onRowSelected` opens `openReceptionPatientEditor`.
- Current column count vs the five-column budget.

### 1.3 Inventory shared components to reuse

Locate and list exact import paths for:

- `AppListTable` / `AppListTableColumn` / `AppListTableSearch`
- `AppListTableColumnVisibilityController` + `AppListTableColumnVisibilityMemory`
- `AppWorkspaceStatusBadge` / `WorkflowActionButton` (if workflow entity)
- `AppListItemText` for two-line cells
- Existing detail dialogs in `frontend/lib/features/reception/presentation/`

### 1.4 Gap analysis vs `prompt.md`

For **each table** on this screen, produce a concrete gap list, for example:

- Column count exceeds five defaults
- Combined unrelated fields in one column (name + ID, status + date, etc.)
- Search bar missing or not matching hidden columns
- Extra trailing actions in search chrome (export, refresh, overflow)
- Filters/Settings labels or modal titles non-standard
- Missing `columnVisibilityStorageKey` / session persistence
- Generic next-action label (`Next step`, `Action`) instead of explicit verb
- `onRowSelected` missing or navigates away instead of opening detail dialog
- No `mobileItemBuilder` or missing status/action on mobile
- Table not wired to realtime provider refresh

### 1.5 Per-tab / per-panel table matrix

Document how each tab switches table content and which columns differ per tab.

### 1.6 Domain-specific requirements

- Entities, providers, and API surfaces this screen uses.
- Validate known tabs against enums / section models in code; correct labels if l10n differs.
- Workflow stages and the explicit next-action label per stage (if applicable).
- Behaviors that must be preserved (permissions, counts, pagination, deep links, dialogs).

### 1.7 Migrations

- Check whether schema/API changes are required. Prefer "No database migrations required" unless the audit proves otherwise.

---

## Step 2: Generate the Prompt

Produce a self-contained refactoring prompt for a coding AI agent. It must not require re-discovery of basics already known from this generator, but it **must** include the concrete audit findings (exact symbols, files, per-table columns, and per-tab differences).

### Generated prompt structure (exact)

```markdown
# Standardize Reception Tables

## Objective

Refactor every `AppListTable` on the Reception workspace (`/reception`, `ReceptionWorkspacePage`) so each table fully complies with `prompt.md` (search chrome, ≤5 columns, status/action columns when applicable, row detail dialog, responsiveness, realtime).

## Compliance Checklist (from prompt.md — per table)

- [ ] Global search matches all columns (including hidden)
- [ ] Search chrome has only Filters (Advanced filters modal) and Settings (Table Settings modal)
- [ ] Session-persisted column visibility via `AppListTableColumnVisibilityController`
- [ ] ≤ 5 declared columns; automatic row number only
- [ ] One semantic field per column; two-line display only for primary/secondary of one field
- [ ] Status + explicit next-action columns when entity has workflow
- [ ] Row tap opens reused detail dialog with follow-up actions
- [ ] Adaptive layout + `mobileItemBuilder` parity
- [ ] Real-time refresh via Riverpod providers

## Context for the Executing Agent

You are a coding AI agent with full read/write access to this Flutter codebase. Execute every
step below precisely. Do not skip steps. Do not ask for clarification. Run tests and formatting
after implementation. Treat `prompt.md` as the normative table contract.

**Scope boundary:** Restructure **table chrome, columns, and row interactions only**. Do not rewrite domain APIs, permissions, or unrelated screen chrome unless required for compilation.

## Current State (from audit)

[Per-table: widget, file, entity, current columns, search chrome, gaps vs prompt.md]

## Reference Implementation

- `frontend/lib/shared/components/app_list_table.dart`
- `frontend/lib/features/mortuary/presentation/pages/mortuary_workspace_page.dart` (`_MortuaryWorklist`)
- `frontend/lib/features/emergency/presentation/widgets/emergency_workspace_widgets.dart`
- `prompt.md`

## Target Architecture

### Table inventory

| Table widget | Tab / panel | Entity | Default visible columns (max 5) | columnVisibilityStorageKey |
|--------------|-------------|--------|-----------------------------------|----------------------------|
| ...          | ...         | ...    | ...                               | ...                        |

### Column plan (per table)

| Position | Column id | Label | Source field | Notes |
|----------|-----------|-------|--------------|-------|
| 1–3      | ...       | ...   | ...          | priority data |
| 4        | status    | ...   | ...          | if workflow |
| 5        | next_action | ... | ...          | explicit `WorkflowActionButton` or module equivalent |

### Search chrome (per table)

- `AppListTableSearch` matcher covering all column fields + hidden `columnChoices`
- Filters: label `Filters`, modal title `Advanced filters`
- Settings: `commonTableSettingsActionLabel`, modal title `Table Settings`

### Row interaction

- `onRowSelected` → `openReceptionPatientEditor` (or audited replacement)
- Next-action column uses same handler destination as detail dialog actions

## Implementation Steps

1. **[Table 1]** — File: `[exact path]`
   - Reduce/reorder columns to ≤5 defaults; move extras to `columnChoices`
   - ...

## Shared Components — MUST Reuse

| Component | Import Path | Usage |
|-----------|-------------|-------|
| ...       | ...         | ...   |

## Files to Create / Modify / Delete

[Tables]

## l10n

- Add/update keys in `frontend/lib/l10n/app_en.arb` only (per locale rule)
- Prefer shared keys: `commonTableSettingsActionLabel`, shared Filters/Advanced filters keys

## Database Migrations

[Required migrations OR explicit "No database migrations required — schema unchanged."]

## Verification Steps

    cd frontend
    dart format .
    dart analyze --fatal-infos
    flutter test test/features/reception/

## Testing Requirements

- [ ] Each table: search, Filters, Settings only in chrome
- [ ] Column visibility persists for session per table key
- [ ] ≤5 default columns; row number automatic
- [ ] Workflow tables: explicit status + next-action labels
- [ ] Row tap opens detail dialog
- [ ] Mobile list shows same priority fields
- [ ] Realtime refresh still updates rows after mutations/events
- [ ] Permissions still gate write actions

## Acceptance Criteria

- [ ] Fully compliant with `prompt.md` for every table on this screen
- [ ] Domain logic preserved
- [ ] Analyze clean; tests pass
```

---

## Step 3: Save the Output

- **Output path (fixed):** `prompts/02-reception-prompt.md`
- This mirrors this generator file (`prompt-generators/02-reception-prompt-generator.md`) with `-generator` removed from the filename.
- **Replace/update** that file if it already exists; do not invent a different name or numeric prefix.
- Do not save under alternate names such as `standardize-*-tables.md` unless you are explicitly retiring a legacy file — in that case, note the legacy path at the top of the new prompt and delete or redirect the old file.

---

## Rules

1. **Never generate a generic prompt.** Every section must cite real paths, classes, providers, column ids, and per-tab table bindings discovered in the audit of `ReceptionWorkspacePage`.
2. **Do not guess.** If something is missing, instruct the executing agent to follow Mortuary + Emergency references + `prompt.md`, with the exact pattern to copy.
3. **Preserve domain logic.** Restructure table chrome/columns/row interactions only; keep Reception business behavior.
4. **Reuse over reinvention.** Forbid new table/search/filter implementations when `AppListTable` and shared widgets exist.
5. **Be specific.** Exact imports, constructors, parameters, l10n keys, storage keys, and column ids.
6. **prompt.md is non-negotiable.** The generated prompt's acceptance criteria must include the full per-table compliance checklist above.
7. **Agent-executable.** No follow-up questions required.
8. **Include verification.** Concrete shell commands and tests under `test/features/reception/`.
9. **Multi-table screens.** Generate steps and checklists for **each** table widget separately.

---

## Usage

This file is already bound to **Reception** (`/reception`). Run it as a prompt. The generator agent will:

1. Audit `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart` and related `reception` files against Mortuary/Emergency references + `prompt.md`.
2. Produce a self-contained, agent-executable table-standardization prompt.
3. Save it to `prompts/02-reception-prompt.md`.
