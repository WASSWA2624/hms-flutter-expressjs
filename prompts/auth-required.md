# Simplify UX Flows — Target Screen: `/auth-required`

Audit the target screen for duplicate actions, redundant surfaces, and extra steps; then remove or merge them so each task takes the fewest clear steps a novice can follow. Follow `prompts/.cursor/prompt.mdc`. To reuse, change only the target screen in the title.

## Context

**Duplicate:** two or more controls or surfaces that start or complete the same goal. **Redundant surface:** a screen, dialog, toolbar, or panel that only repeats parent actions or info without a distinct decision. **Minimal path:** fewest deliberate actions from intent to confirmed result, without dropping required data or auth checks.

Use `screens/[screen-name].md` when present; otherwise derive actions from presentation source. Prefer one discoverable control over parallel shortcuts or nested duplicates.

## Requirements

1. Scope to the target route, page, feature widgets, and reachable dialogs (including nested). Map every primary task completed there.
2. Flag duplicates and redundant surfaces: same-outcome buttons, parallel dialogs for one workflow, and steps that only restate prior choices.
3. Merge or remove so each distinct task has one primary, visible, labeled entry point. Do not bury the sole entry in overflow-only chrome unless the design system already requires that for secondary actions.
4. Cut intermediate steps that do not collect required input, confirm destructive work, or change auth/billing outcomes. Keep progressive disclosure for secondary detail.
5. Remaining paths must still show complete required information. Preserve contracts, permissions, and mutation payloads.
6. Cover loading, empty, no-results, error/retry, success, and validation on simplified surfaces. Unauthorized controls must not render. Responsive; theme tokens only.
7. Tests (or manual checks where UI tests are impractical) must prove duplicates are gone, merged entry points work, and authorized minimal paths still complete.

## Constraints

- Reuse routes, dialogs, list/table patterns, workflow actions, RBAC/ABAC gates, and theme tokens; extend rather than fork.
- Backend auth is authoritative. Do not change API contracts except where a removed client-only step was never required by the backend.
- Discoverability beats clever compression: one clear primary action beats several equivalent shortcuts.
- No unrelated refactors outside the target screen's reachable UI.

## Acceptance Criteria

- Task inventory lists each duplicate/redundant surface and the merge or removal applied (Req 1–3).
- Each distinct task has a single primary labeled entry a novice can find without hunting duplicates (Req 3).
- Paths omit steps that only restated choices or opened empty intermediate shells (Req 4).
- Required data, validation, and auth remain intact; unauthorized UI absent (Req 5–6).
- Tests or documented checks prove Req 7 for representative tasks.

## Relevant Files

- Target screen route, page, and widgets under `frontend/lib/`.
- Shared dialogs, list/search chrome, and workflow actions it invokes.
- `screens/[screen-name].md` (update if actions/labels change).
- Related tests under `frontend/test/`.