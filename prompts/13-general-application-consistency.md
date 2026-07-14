# General Application Consistency — Implementation Prompt

## Objective

Mandate a unified, modular, maintainable architecture and UX across HOSSPI HMS: shared components first, consistent workflows/terminology, instant UI + realtime reconciliation, and cleanup of superseded duplicates after verified migration.

**Source requirement:** [prompt.md](../prompt.md) §9  
**Also required:** [00-global-delivery-acceptance.md](./00-global-delivery-acceptance.md)

This prompt is the cross-cutting closeout checklist for every other improvement prompt.

---

## Mandatory reading

1. [`.cursor/index.mdc`](../.cursor/index.mdc)
2. [`frontend/.cursor/architecture.mdc`](../frontend/.cursor/architecture.mdc) + [`instant_ui_sync.mdc`](../frontend/.cursor/instant_ui_sync.mdc)
3. [`backend/.cursor/architecture.mdc`](../backend/.cursor/architecture.mdc)
4. Prompts 01–12 for domain-specific rules

---

## Step-by-step instructions

### 1. Reuse priority

For every change, apply in order:

1. Shared implementation  
2. Extension of shared implementation  
3. New module-specific implementation **only** when behavior is genuinely domain-specific  

### 2. Consistency bars

- Standardized reusable components and business logic throughout
- Consistent workflows, terminology, status mapping, feedback, and UI patterns across modules
- Preserve documented frontend/backend layer boundaries and module ownership
- Public `human_friendly_id` references, normalized API contracts, localized text, shared formatters, design tokens, auditable backend mutations everywhere

### 3. Sync consistency

Synchronize UI, workflow, billing, notifications, badges, and clinical results through:

- Immediate Riverpod updates after successful HTTP persistence
- Scoped WebSocket reconciliation for other authorized clients  

Never use WebSockets as mutation transport.

### 4. State completeness

Maintain complete:

- Loading, empty, error, offline, conflict, forbidden, success, retry  

without leaking sensitive information.

### 5. Cleanup after verified migration

Remove superseded duplicate:

- Code, routes, providers, services, components, tests, documentation  

only after replacement is verified. Prefer deleting obsolete paths over leaving parallel implementations.

### 6. Integration requirement for new features

All new features must integrate with:

- Overarching architecture and design system  
- Authorization model (prompt 01)  
- Shared reusable components (prompts 03–07)  
- Billing engine (prompt 10)  
- Workflow step/progress (prompt 04)  

### 7. Documentation

- Update docs when contracts, workflows, permissions, or shared components change
- Remove stale documentation in the same change set when practical

---

## Definition of done (per delivered section)

Use this checklist for every improvement prompt:

- [ ] Existing behavior audited; only gaps/non-compliant areas changed
- [ ] Database migrations/backfills safe and verified where applicable
- [ ] Backend validation, authorization, transactionality, audit, idempotency, domain events covered
- [ ] Frontend state updates immediately after success; second-client reconciliation verified
- [ ] Unauthorized, cross-scope, cancel, failure, conflict, reconnect, retry paths tested
- [ ] Mobile, tablet, desktop verified for responsiveness, accessibility, localization, theme consistency
- [ ] Relevant automated checks pass with no new warnings/failures
- [ ] Obsolete duplicates removed; docs updated

## Related prompts

All prompts 00–12
