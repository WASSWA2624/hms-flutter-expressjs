{screen_name}

---

# Screen Standardization Prompt Generator

You are a coding AI agent acting as a prompt generator. Given the screen name on the first line of this file, you must audit the codebase, then produce a comprehensive, context-aware refactoring prompt that another coding AI agent can execute autonomously — and save it to the `prompts/` folder.

The generated prompt must be written for a coding AI agent that:
- Has full read/write access to the codebase.
- Can create, modify, and delete files.
- Can run shell commands (tests, linting, formatting).
- Operates without human clarification — all instructions must be unambiguous and self-contained.
- Needs explicit file paths, exact class/widget names, and concrete code patterns to act on.

---

## Step 1: Codebase Discovery (mandatory — do this first)

Before writing any prompt content, perform a full audit of the codebase to gather context specific to the target screen.

### 1.1 Locate the target screen

- Find all files related to `{screen_name}`: pages, widgets, controllers, providers, repositories, models, routes, and tests.
- Identify the current page structure, layout, navigation setup, and state management approach.
- Note which shared components it already uses and which it duplicates or ignores.

### 1.2 Audit the reference implementation (Reception workspace)

- Read `reception_workspace_page.dart` and its supporting files to extract the canonical patterns:
  - Tab structure and how tabs are defined.
  - Routing: how each tab maps to a route segment.
  - Primary action button placement and per-tab behavior.
  - Table usage: `AppListTable` configuration, search bar integration, filter/settings buttons.
  - Mobile/responsive breakpoints and layout switching.
  - State management and data-fetching patterns.

### 1.3 Inventory shared components

- Locate and list all shared/reusable components relevant to the standardization:
  - `AppListTable` (or equivalent data table widget).
  - Tab bar / routable tab components.
  - Search bar widget.
  - Filter and table-settings buttons/dialogs.
  - Primary action button patterns.
  - Responsive layout wrappers/breakpoint utilities.
  - Any `WorkflowActionButton` or workflow infrastructure already wired.

### 1.4 Identify the gap

- Compare the target screen's current implementation against the reference.
- List concrete differences: missing tabs, non-routable navigation, inline tables instead of `AppListTable`, missing search/filter, non-responsive layout, duplicated components, inconsistent state management.

### 1.5 Check route configuration

- Find the target screen's route definition in the app router.
- Determine if it already supports tab-based sub-routes or needs restructuring.
- Note any deep-link query models already defined for this module.

### 1.6 Identify domain-specific requirements

- Determine what data the screen displays (entities, providers, API endpoints).
- Identify the tabs that make sense for this screen based on domain logic (e.g., statuses, categories, workflow stages).
- Identify the primary action per tab (e.g., "New Patient", "Create Order", "Admit").
- Note any screen-specific behaviors that must be preserved during refactoring.

---

## Step 2: Generate the Prompt

Using the audit findings, generate a detailed, actionable refactoring prompt written for a coding AI agent. The prompt must be self-contained — the executing agent should not need to re-discover context or ask questions.

### Generated prompt structure

The output file must follow this exact structure:

```markdown
# Standardize {screen_name} Screen

## Objective

[One paragraph: refactor {screen_name} to match the standardized tab-and-table layout used by the Reception workspace. State what the agent will accomplish.]

## Context for the Executing Agent

You are a coding AI agent with full read/write access to this Flutter codebase. Execute every step below precisely. Do not skip steps. Do not ask for clarification — all information needed is in this prompt. Run tests and formatting after implementation.

## Current State (from audit)

[Bullet list of what currently exists:
- File paths of current implementation
- Current layout/structure description
- Components currently in use
- Problems/inconsistencies found]

## Reference Implementation

Read these files to understand the target patterns (do NOT modify them):
- [Exact file paths to Reception workspace and shared components discovered during audit]
- [Key patterns to extract from each file]

## Target Architecture

### Tab Configuration

| Tab Name | Route Path | Description | Primary Action Button |
|----------|-----------|-------------|----------------------|
| [tab]    | [path]    | [desc]      | [label → action]     |

### Routing

[Exact instructions: which router file to modify, what route definitions to add, how to wire tab index to route segments. Include the specific GoRoute/ShellRoute pattern to follow, referencing the Reception route as the template.]

### Page Layout

[Precise widget tree specification:
- Scaffold structure
- Tab bar: which widget class, how tabs are defined
- Primary action button: positioned where, changes based on which tab state
- Body: AppListTable with specific constructor parameters
- Search bar: integrated how
- Filter/settings buttons: positioned where, which shared widgets to use]

### Data & State Management

[Specific providers/controllers to create or reuse. Name them. Specify their return types. Reference existing patterns by file path.]

## Implementation Steps

[Numbered steps the agent must execute in order. Each step must specify:]

1. **[Action]** — File: `[exact path]`
   - What to do (create / modify / delete)
   - Specific code changes or patterns to apply
   - Imports to add

2. **[Action]** — File: `[exact path]`
   - ...

[Continue for all necessary changes]

## Shared Components — MUST Reuse

Do NOT create new implementations of these. Import and use them directly:

| Component | Import Path | Usage |
|-----------|-------------|-------|
| [name]    | [path]      | [how to use it in this screen] |

## Files to Create

| File Path | Purpose |
|-----------|---------|
| [path]    | [what it contains] |

## Files to Modify

| File Path | Changes |
|-----------|---------|
| [path]    | [summary of modifications] |

## Files to Delete (if any)

| File Path | Reason |
|-----------|--------|
| [path]    | [why it's being removed] |

## Responsive Design Requirements

- **Desktop (≥1024px):** [specific layout — e.g., full table with all columns visible, side-by-side elements]
- **Tablet (600–1023px):** [specific layout — e.g., condensed columns, stacked action area]
- **Mobile (<600px):** [specific layout — e.g., card-based rows, bottom action sheet, hidden columns]

[Reference the exact breakpoint utility/widget from the codebase to use.]

## Verification Steps

After implementation, the agent MUST run these commands and confirm they pass:

```bash
# Format
dart format .

# Analyze
dart analyze --fatal-infos

# Run tests related to this screen
flutter test test/features/{module}/

# Run shared component tests to ensure no regressions
flutter test test/shared/
```

## Testing Requirements

Write or update these tests:

- [ ] Tab navigation: switching tabs updates the URL
- [ ] Deep linking: navigating directly to a tab URL renders the correct tab
- [ ] Table data: each tab displays the correct filtered dataset
- [ ] Search: typing in the search bar filters table rows
- [ ] Filter dialog: filter button opens the filter UI and applies filters
- [ ] Primary action: button label and behavior change per tab
- [ ] Responsive layout: widget tests verify layout at each breakpoint
- [ ] No regressions: existing screen functionality still works

## Acceptance Criteria

The refactor is complete when ALL of the following are true:

- [ ] The screen uses routable tabs matching the Reception workspace pattern
- [ ] Each tab has its own URL that supports deep linking
- [ ] The primary action button is contextual per tab and positioned correctly
- [ ] The page body uses `AppListTable` with integrated search, filter, and settings
- [ ] No shared component is re-implemented — only imported and used
- [ ] The layout is fully responsive across mobile, tablet, and desktop
- [ ] All old/duplicate layout code is removed
- [ ] Domain-specific business logic and data are preserved
- [ ] `dart analyze` reports no new issues
- [ ] All tests pass
```

---

## Step 3: Save the Output

- Inspect existing files in `prompts/` to determine the next available numeric prefix.
- Save the generated prompt as: `prompts/{NN}-standardize-{screen-name-kebab-case}.md`
  - Example: if `{screen_name}` is "Patient Management" and the highest existing prefix is `13`, save as `prompts/14-standardize-patient-management.md`.

---

## Rules

1. **Never generate a generic prompt.** Every section must reference actual file paths, component names, provider names, and patterns discovered during the audit. The executing agent must not need to search for anything.
2. **Do not guess.** If a shared component or pattern cannot be found in the codebase, note its absence and instruct the executing agent to create it following the Reception reference — provide the exact pattern to replicate.
3. **Preserve domain logic.** The generated prompt must not remove screen-specific business behavior — only restructure the UI layer to match the standard layout.
4. **Reuse over reinvention.** The generated prompt must explicitly forbid creating new table, tab, search, or filter implementations when shared ones exist.
5. **Be specific.** Reference exact file paths, class names, widget names, provider names, and route paths. Vague instructions like "use the shared table" are insufficient — specify which import, which constructor, which parameters.
6. **Mobile-first.** The responsive design section must specify concrete breakpoints and layout changes, not just "make it responsive."
7. **Agent-executable.** Every instruction must be unambiguous enough that a coding AI agent can execute it without asking follow-up questions. Include exact code snippets where patterns are non-obvious.
8. **Include verification.** The prompt must end with concrete shell commands and test expectations so the executing agent can self-verify its work.

---

## Usage

Replace `{screen_name}` on line 1 with the name of the screen to standardize, then run this file as a prompt. The generator will:

1. Audit the codebase for full context.
2. Produce a self-contained, agent-executable refactoring prompt.
3. Save it to `prompts/` with the appropriate name and number.
