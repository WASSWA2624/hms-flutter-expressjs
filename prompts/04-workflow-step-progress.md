# Workflow Step Progress & Actions — Implementation Prompt

## Objective

Create or consolidate a reusable workflow/progress step component that visualizes encounter, request, and task progressions across modules without embedding module-specific business logic. Persist all transitions through the owning backend module.

**Source requirement:** [prompt.md](../prompt.md) §3 — Core Reusable Component: Step Progress & Actions  
**Also required:** [00-global-delivery-acceptance.md](./00-global-delivery-acceptance.md), [03-shared-reusable-components.md](./03-shared-reusable-components.md), [06-permission-aware-actions.md](./06-permission-aware-actions.md)

---

## Mandatory reading

1. [`frontend/.cursor/components.mdc`](../frontend/.cursor/components.mdc)
2. [`frontend/.cursor/instant_ui_sync.mdc`](../frontend/.cursor/instant_ui_sync.mdc)
3. Owning module flow files when integrating (lab, radiology, discharge, etc.)

---

## Pre-implementation audit

- Search for existing steppers, progress bars, or workflow action bars in `frontend/lib/shared/` and feature modules.
- Consolidate duplicates into one shared component; migrate callers.

---

## Step-by-step instructions

### 1. Shared component API (presentation only)

Implement under `frontend/lib/shared/` (e.g. workflow / progress).

Each step supports:

- Localized icon, label, description
- Semantic state: current, completed, upcoming, skipped, reverted, unavailable
- Stable step identifier
- Contextual action labels (`Perform`, `Complete`, `Skip`, `Revert`, `Resume`, etc.) only when allowed by **backend-provided workflow capabilities** and current state
- Permission-aware actions with loading, success, failure, confirmation, retry
- Explanations via hover, keyboard focus, and touch-accessible help (not hover alone)
- Localized reason when an authorized action is blocked by prerequisites/workflow constraints

Visual rules:

- Clear differentiation of completed / active / pending / disabled
- Do not expose an action when the user lacks effective permission
- Compact mobile layout and expanded tablet/desktop layout
- Correct reading order and keyboard navigation

### 2. Backend / domain contract

- Owning modules expose workflow state + allowed transitions/capabilities in API payloads (`snake_case`).
- Never infer or mutate workflow state only on the client.
- Valid transitions persist via HTTP through the owning backend module with authorization, audit, idempotency, and domain events.
- Use `human_friendly_id` for step/entity references in public APIs and UI.

### 3. Reuse targets (no module logic inside the widget)

Wire the same component for lab, radiology, admissions, appointments, billing, discharge, and other workflows by supplying typed step models and callbacks from feature controllers.

### 4. Instant UI

- On successful transition: patch worklist row, detail panel, step state, summaries, and badges immediately.
- Reconcile other clients via scoped realtime events.

### 5. Database (if workflow metadata is persisted)

- Migrations for transition history / capability metadata as needed by owning modules.
- Preserve history; do not rewrite past states when catalogs change.
- Remove obsolete client-only workflow enums that conflict with backend state.

---

## Tests

- All semantic states and permission hide vs disable
- Keyboard/focus/touch help affordances
- Mobile compact vs desktop expanded layouts
- Failed/cancelled mutation does not advance steps
- Multi-client reconciliation after transition

## Related prompts

03, 06, 08 (lab), 09 (radiology), 10 (billing), 12 (reception)
