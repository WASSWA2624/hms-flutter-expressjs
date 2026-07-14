# Shared Reusable Components — Implementation Prompt

## Objective

Audit and extend the shared component catalog under `frontend/lib/shared/` so clinical/operational modules reuse consistent building blocks. Prefer extending existing widgets; create new shared components only when missing. Keep business logic out of presentation widgets.

**Source requirement:** [prompt.md](../prompt.md) §3 (catalog, workspace contract, general)  
**Also required:** [prompts/00-global-delivery-acceptance.md](./00-global-delivery-acceptance.md), [02-responsive-design-system.md](./02-responsive-design-system.md)

Companion prompts for major named deliverables:

- [04-workflow-step-progress.md](./04-workflow-step-progress.md)
- [05-patient-details-component.md](./05-patient-details-component.md)
- [06-permission-aware-actions.md](./06-permission-aware-actions.md)
- [07-clinical-results-preview.md](./07-clinical-results-preview.md)

---

## Mandatory reading

1. [`frontend/.cursor/components.mdc`](../frontend/.cursor/components.mdc)
2. [`frontend/.cursor/ui-workspace.mdc`](../frontend/.cursor/ui-workspace.mdc)
3. [`frontend/.cursor/ui-feedback.mdc`](../frontend/.cursor/ui-feedback.mdc)
4. Existing `frontend/lib/shared/**` catalog (layout, actions, forms, state views)

---

## Pre-implementation audit

1. Inventory `frontend/lib/shared/` for: patient details, permission-aware actions, clinical-results preview, report sections, status badges, loading/empty/error/success, timelines, detail cards, dialogs, step progress.
2. Mark each as exists-compliant / exists-noncompliant / missing.
3. Find feature-local duplicates to delete after shared migration.

---

## Step-by-step instructions

### 1. Catalog capabilities (create or extend only if needed)

Place under the appropriate `frontend/lib/shared/` subfolder:

| Capability | Notes |
| ---------- | ----- |
| Patient details | See prompt 05 |
| Permission-aware actions | See prompt 06 |
| Clinical-results preview | See prompt 07 |
| Report sections | Align with prompt 11 |
| Status badges | Non-color status cues + localized labels |
| Loading / empty / error / success | Shared state views with retry |
| Timeline | Chronological clinical/ops events |
| Detail cards | Typed data + callbacks only |
| Dialogs | Modal-first within-module actions |

### 2. Module workspace contract

Clinical and operational queue screens must reuse:

`AsyncStateScaffold`, `ResponsivePage`, `AppWorkspace`, `AppListTable`, `AppWorkspaceDetailPanel`, `AppActionPanel`

unless the documented screen type is exempt.

Workspace rules:

- Keep selection, filters, rows, details, summary counts, and nav badges in Riverpod.
- After successful actions, update only affected state (instant UI sync).
- Paginate or lazy-load large worklists; debounce remote search.
- Register applicable `RealtimeEventGroups` in workspace controllers.

### 3. General component rules

- Modern, responsive, context-aware, fully configurable.
- Accept typed data and callbacks; no module-specific business logic inside shared widgets.
- Include loading, empty, error, permission-denied, and retry behavior.
- Remove duplicate/legacy UI after verified cutover.
- Add component tests: responsiveness, semantics, permissions, all supported states.

### 4. Backend involvement

Shared presentation components do not own APIs. Where components surface capabilities (actions, print eligibility, workflow steps), those capabilities must come from backend responses already authorized for the current scope.

---

## Cleanup

- Delete feature-local copies of shared patterns after migration.
- Update docs that reference obsolete widgets.

## Related prompts

04–07 (named components), 11 (reporting), 13 (consistency)
