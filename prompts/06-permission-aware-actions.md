# Permission-Aware Actions — Implementation Prompt

## Objective

Provide reusable RBAC/ABAC/entitlement-aware action primitives for forms, dialogs, detail pages, and workflows, with full async lifecycle support and idempotent retries.

**Source requirement:** [prompt.md](../prompt.md) §3 — Actions Component  
**Also required:** [00-global-delivery-acceptance.md](./00-global-delivery-acceptance.md), [01-authorization-security.md](./01-authorization-security.md), [03-shared-reusable-components.md](./03-shared-reusable-components.md)

---

## Mandatory reading

1. [`frontend/.cursor/permissions.mdc`](../frontend/.cursor/permissions.mdc)
2. [`frontend/.cursor/ui-feedback.mdc`](../frontend/.cursor/ui-feedback.mdc)
3. Existing `frontend/lib/shared/actions/` (e.g. `AppActionPanel`)
4. [`.cursor/api-contract.mdc`](../.cursor/api-contract.mdc) — idempotency / offline rules

---

## Pre-implementation audit

- Inventory shared vs feature-local action buttons, toolbars, and confirmation flows.
- Extend `AppActionPanel` / related shared actions rather than creating parallel systems.

---

## Step-by-step instructions

### 1. Authorization inputs

Actions must respect all of:

- RBAC and ABAC effective permissions
- Subscription and module entitlements
- Backend-provided action capabilities for the current resource/workflow state

UI rules (align with prompt 01):

- **Hide** when the user lacks effective permission
- **Disable** when authorized but prerequisites/workflow state block the action; show localized reason

### 2. Action lifecycle states

Support:

- Idle / loading
- Prerequisite-disabled
- Confirmation required
- Contextual (overflow/menu/toolbar placement)
- Asynchronous in-flight
- Success and failure feedback
- Retry with duplicate-submission prevention

### 3. Mutation safety

- Controllers invoke repositories over HTTP; widgets only trigger callbacks.
- Use idempotency keys for retryable mutations per API contract.
- On success: patch Riverpod immediately; on cancel/failure: no patch.
- Never queue online-only mutations (payments, refunds, break-glass, etc.).

### 4. Placement

Reusable across:

- Forms
- Dialogs / bottom sheets
- Detail pages
- Workflow step actions (compose with prompt 04)
- Workspace toolbars and action panels

### 5. Accessibility & responsive

- Keyboard activatable; focus not trapped incorrectly after dialogs
- Touch-friendly targets on mobile; dense but clear on desktop
- Localized labels; icons never sole meaning of destructive/critical actions

---

## Tests

- Hide vs disable matrix for permission and prerequisite cases
- Double-submit prevention and idempotent retry
- Failure/cancel leave state unchanged
- Confirmation flows for destructive actions

## Related prompts

01, 03, 04, 13
