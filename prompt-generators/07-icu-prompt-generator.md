/icu

---

# Screen Standardization Prompt Generator — ICU

You are a coding AI agent acting as a **prompt generator**. Your job is to audit the codebase for the **ICU** screen, then produce a comprehensive, context-aware refactoring prompt that another coding AI agent can execute autonomously — and save that prompt to the `prompts/` folder.

The generated prompt **MUST** be fully compliant with the layout rules in `prompt.md` (Screen, Tabs, and Toolbar Standardization). Every acceptance criterion in the generated prompt must map back to those rules.

## Pre-filled screen context (do not invent alternatives)

| Field | Value |
|-------|-------|
| Route | `/icu` |
| Screen name | ICU |
| Page widget | `IcuWorkspacePage` |
| Primary page file | `frontend/lib/features/icu/presentation/pages/icu_workspace_page.dart` |
| Feature module | `icu` |
| Known tabs | `Active ICU`, `Critical alerts`, `Transfers`, `Discharge ready`, `Ended stays`, `All ICU`, `Bed board` |
| Purpose | ICU stays, alerts, transfers, discharge readiness, and ICU bed board. |

- Deep-link query: confirm whether tab state is URL-backed; add if missing.



### Known tab inventory (validate and complete during audit)

| # | Tab label (current) | Route / query value | Primary toolbar action |
|---|---------------------|---------------------|------------------------|
| 1 | Active ICU | [confirm from code] | [discover during audit] |
| 2 | Critical alerts | [confirm from code] | [discover during audit] |
| 3 | Transfers | [confirm from code] | [discover during audit] |
| 4 | Discharge ready | [confirm from code] | [discover during audit] |
| 5 | Ended stays | [confirm from code] | [discover during audit] |
| 6 | All ICU | [confirm from code] | [discover during audit] |
| 7 | Bed board | [confirm from code] | [discover during audit] |

The executing agent that runs your generated prompt must:
- Have full read/write access to the codebase.
- Be able to create, modify, and delete files.
- Be able to run shell commands (tests, linting, formatting).
- Operate without human clarification — all instructions must be unambiguous and self-contained.
- Receive explicit file paths, exact class/widget names, and concrete code patterns.

---

## Mandatory compliance source: `prompt.md`

Before generating anything, read `prompt.md` at the repository root. The generated prompt **must enforce all of the following** for **ICU** (`/icu`):

1. **Eliminate dedicated screen title/header areas.** No separate title bars on the screen. Prefer `AppWorkspace(showHeader: false)` (or equivalent) so chrome is tabs + toolbar only.
2. **Shared tab component at the top.** Use `AppTabStrip` / `AppTabItem` from `frontend/lib/shared/components/app_tab_strip.dart`. Tab buttons render at the top; the contextual toolbar sits **immediately beneath** the tabs (via `AppTabStrip.primaryAction` / `secondaryActions`).
3. **All former header/title action buttons move into the toolbar** under the tabs. No stray action buttons outside the toolbar (except table-local Filters/Settings — see below).
4. **Toolbar buttons are contextual to the active tab.** Switching tabs must immediately update which buttons appear. Document the exact button set per tab in the generated prompt.
5. **Consistent vertical padding** above and below tab rows (follow `AppTabStrip` / theme spacing already used by Reception).
6. **Toolbar visibility:** omit the toolbar only when a tab truly has no actions — **except** every screen must still expose **at least one** toolbar button somewhere (guarantee a sensible default primary/secondary action so the screen is never actionless).
7. **Tables:** inside the table chrome only, keep **Filters** and **Settings** (use those exact standardized labels via existing l10n keys such as `commonTableSettingsActionLabel` / filter labels). Move every other table/header action into the tab toolbar.
8. **No “more” menus for screen/header actions.** If a header previously used an overflow/more menu, extract each item into its own visible toolbar button, contextual to the active tab.
9. **Consistent naming** for buttons and toolbars across tabs on this screen.

**Objective encoded into every generated prompt:** ICU must present a consistent, clean layout. Tabs and toolbars behave uniformly with clearly contextual actions.

---

## Step 1: Codebase Discovery (mandatory — do this first)

Perform a full audit focused on `/icu` / `IcuWorkspacePage`.

### 1.1 Locate the target screen

- Start at `frontend/lib/features/icu/presentation/pages/icu_workspace_page.dart` and walk all imports: widgets, controllers, providers, repositories, models, routes, dialogs, and tests under `frontend/lib/features/icu/`.
- Map the current widget tree: scaffold / `AppWorkspace` / `AppTabStrip` / body tables / dialogs.
- Note which shared components it already uses vs duplicates.

### 1.2 Audit the reference layout (Reception) and shared chrome

Read (do not modify while generating the prompt — reference only):

- `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart`
- `frontend/lib/shared/components/app_tab_strip.dart` (`AppTabStrip`, `AppTabItem`, `AppTabToolbarPrimary`)
- `frontend/lib/shared/layout/app_workspace.dart` (`AppWorkspace`, `showHeader`)
- `frontend/lib/shared/layout/app_workspace_toolbar.dart` (`appWorkspaceToolbarWithLabels`, `AppWorkspaceToolbarConfig`)
- `prompt.md`

Extract:
- How tabs are defined and selected.
- How routing / query params bind to the active tab.
- How `primaryAction` / `secondaryActions` form the toolbar under tabs.
- How `AppListTable` wires search, Filters, and Settings.
- Responsive / breakpoint behavior.

### 1.3 Inventory shared components to reuse

Locate and list exact import paths for:

- `AppTabStrip` / `AppTabItem` / `AppTabToolbarPrimary`
- `AppListTable` (and column visibility / settings)
- Search / filter widgets used by Reception
- `AppWorkspace` / toolbar helpers
- `AppAccessActionGate` (or module-equivalent permission gates)
- Responsive utilities (`app_breakpoints.dart`, `ResponsivePage`)

### 1.4 Gap analysis vs `prompt.md`

Compare `IcuWorkspacePage` against the rules. Produce a concrete gap list, for example:

- Dedicated header / title still visible (`showHeader: true` or custom header widgets)
- Actions still in a page header, FAB, or overflow “more” menu
- Toolbar not under tabs, or not swapping with tab changes
- Table row/header actions beyond Filters / Settings
- Inconsistent button labels vs shared l10n
- Missing deep-link tab query param
- Tabs without at least one screen-level toolbar affordance

### 1.5 Routes

- Confirm `/icu` in `frontend/lib/app/router/app_routes.dart` and `app_router.dart`.
- Document current tab query wiring.
- Specify exact changes needed for deep-linkable tabs.

### 1.6 Domain-specific requirements for ICU

- Entities, providers, and API surfaces this screen uses.
- Validate the known tabs (`Active ICU`, `Critical alerts`, `Transfers`, `Discharge ready`, `Ended stays`, `All ICU`, `Bed board`) against enums / section models in code; correct labels if l10n differs.
- Primary and secondary actions **per tab** (labels + handlers).
- Behaviors that must be preserved (permissions, counts, realtime refresh, dialogs).

### 1.7 Migrations

- Check whether schema/API changes are required. Prefer “No database migrations required” unless the audit proves otherwise.

---

## Step 2: Generate the Prompt

Produce a self-contained refactoring prompt for a coding AI agent. It must not require re-discovery of basics already known from this generator, but it **must** include the concrete audit findings (exact symbols, files, and per-tab actions).

### Generated prompt structure (exact)

```markdown
# Standardize ICU Screen (Tabs & Toolbar)

## Objective

Refactor the ICU workspace (`/icu`, `IcuWorkspacePage`) so its chrome fully complies with `prompt.md`:
no dedicated screen title/header; `AppTabStrip` at the top; contextual toolbar immediately
beneath tabs; table-local actions limited to Filters and Settings; consistent naming.

## Compliance Checklist (from prompt.md)

- [ ] No dedicated screen title/header
- [ ] Shared `AppTabStrip` at top with consistent vertical padding
- [ ] Toolbar immediately under tabs via `primaryAction` / `secondaryActions`
- [ ] All former header / more-menu actions relocated into the contextual toolbar
- [ ] Toolbar actions change with the active tab
- [ ] Every screen retains at least one toolbar button overall
- [ ] Tables expose only Filters and Settings inside the table area
- [ ] Consistent button labels (l10n) across tabs

## Context for the Executing Agent

You are a coding AI agent with full read/write access to this Flutter codebase. Execute every
step below precisely. Do not skip steps. Do not ask for clarification. Run tests and formatting
after implementation. Treat `prompt.md` as the normative layout contract.

## Current State (from audit)

[Bullet list: file paths, current layout, components in use, concrete prompt.md gaps]

## Reference Implementation

Read these files (do NOT modify them unless fixing shared bugs that block compliance):
- [Reception + shared chrome paths discovered in audit]
- `prompt.md`

## Target Architecture

### Tab Configuration

| Tab Name | Route / Query | Description | Toolbar primary | Toolbar secondary |
|----------|---------------|-------------|-----------------|-------------------|
| ...      | ...           | ...         | ...             | ...               |

### Routing

[Exact router / query-model changes for `/icu`]

### Page Layout

Precise widget tree:
1. `AppWorkspace(showHeader: false, ...)` (or equivalent — no title header)
2. `AppTabStrip(tabs:, selectedId:, onTabTapped:, primaryAction:, secondaryActions:)`
3. Body: tab content — typically `AppListTable` with **only** Filters + Settings in the table chrome
4. No FAB / floating header actions / overflow more-menu for screen actions

### Data & State Management

[Providers/controllers to reuse or adjust — named with file paths]

## Implementation Steps

1. **[...]** — File: `[exact path]`
   - ...

## Shared Components — MUST Reuse

| Component | Import Path | Usage |
|-----------|-------------|-------|
| ...       | ...         | ...   |

## Files to Create / Modify / Delete

[Tables]

## Cleanup: Remove Stale Code

[Checklist for dead headers, duplicate toolbars, unused more-menus, orphaned widgets]

## Database Migrations

[Required migrations OR explicit "No database migrations required — schema unchanged."]

## Responsive Design Requirements

- Desktop (≥1024px): ...
- Tablet (600–1023px): ...
- Mobile (<600px): ...

## Verification Steps

    dart format .
    dart analyze --fatal-infos
    flutter test test/features/icu/
    flutter test test/shared/

## Testing Requirements

- [ ] Tab switch updates URL (if query-backed) and toolbar actions
- [ ] Deep link opens correct tab
- [ ] Per-tab toolbar shows only that tab's actions
- [ ] Table chrome has only Filters + Settings
- [ ] No screen title/header chrome remains
- [ ] At least one toolbar button exists on the screen
- [ ] Permissions still gate write actions
- [ ] Responsive layouts still work

## Acceptance Criteria

- [ ] Fully compliant with `prompt.md`
- [ ] Uses `AppTabStrip` with contextual toolbar under tabs
- [ ] No dedicated header; no stray actions; no header more-menu
- [ ] Domain logic preserved
- [ ] Analyze clean; tests pass; stale code removed
```

---

## Step 3: Save the Output

- List files in `prompts/`.
- Find the highest numeric prefix (two-digit).
- Save as `prompts/{NN}-standardize-icu-tabs-toolbar.md` using the next number.
  - Feature slug for this screen: `icu`
  - Example: `prompts/27-standardize-icu-tabs-toolbar.md`

If a standardize prompt for this screen already exists, **replace/update it** only when it is clearly the same screen’s tabs/toolbar standardization prompt; otherwise create the next numbered file and mention the older file in a short note at the top of the new prompt.

---

## Rules

1. **Never generate a generic prompt.** Every section must cite real paths, classes, providers, and per-tab actions discovered in the audit of `IcuWorkspacePage`.
2. **Do not guess.** If something is missing, instruct the executing agent to follow Reception + `prompt.md`, with the exact pattern to copy.
3. **Preserve domain logic.** Restructure chrome/layout only; keep ICU business behavior.
4. **Reuse over reinvention.** Forbid new tab/table/search/filter implementations when shared ones exist.
5. **Be specific.** Exact imports, constructors, parameters, l10n keys, and route query values.
6. **prompt.md is non-negotiable.** The generated prompt’s acceptance criteria must include the full compliance checklist above.
7. **Agent-executable.** No follow-up questions required.
8. **Include verification.** Concrete shell commands and tests.

---

## Usage

This file is already bound to **ICU** (`/icu`). Run it as a prompt. The generator agent will:

1. Audit `frontend/lib/features/icu/presentation/pages/icu_workspace_page.dart` and related `icu` files against Reception + `prompt.md`.
2. Produce a self-contained, agent-executable refactoring prompt.
3. Save it under `prompts/` with the next numeric prefix.
