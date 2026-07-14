# Patient Details Component — Implementation Prompt

## Objective

Provide a reusable patient-details presentation component that shows only workflow-relevant patient information, with a persistent Show More / Show Less preference that never caches PHI as part of the preference.

**Source requirement:** [prompt.md](../prompt.md) §3 — Patient Details Component  
**Also required:** [00-global-delivery-acceptance.md](./00-global-delivery-acceptance.md), [03-shared-reusable-components.md](./03-shared-reusable-components.md)

---

## Mandatory reading

1. [`frontend/.cursor/components.mdc`](../frontend/.cursor/components.mdc)
2. [`frontend/.cursor/storage_strategy.mdc`](../frontend/.cursor/storage_strategy.mdc)
3. [`frontend/.cursor/security.mdc`](../frontend/.cursor/security.mdc)
4. [`frontend/.cursor/scope.mdc`](../frontend/.cursor/scope.mdc)

---

## Pre-implementation audit

- Locate existing patient header/context widgets (e.g. workspace patient context headers).
- Extend or consolidate; delete duplicates after migration.

---

## Step-by-step instructions

### 1. Presentation contract

- Display only patient information relevant for the current workflow (caller supplies filtered fields).
- Accept typed patient/encounter view models and callbacks — no repository calls inside the widget.
- Reference patients by public IDs (MRN / `human_friendly_id`), never raw DB keys.

### 2. Show More / Show Less

**Show Less (default compact):**

- Patient name
- Approved public patient identifier (e.g. MRN)
- Age
- Gender

**Show More:**

- All applicable patient/encounter information provided by the caller for that workflow

### 3. Preference persistence

- Persist the expand/collapse preference per user across sessions.
- When server-side preference sync exists, sync across devices.
- Preference stores only the boolean (or equivalent) UI choice — **never** cache displayed patient data with the preference.
- Partition preference by user (and tenant/facility if required by session rules).

### 4. Authorization & privacy

- Render only fields the current scope permits; omit unauthorized fields entirely.
- On context switch/logout, dispose patient-bound state with session cleanup (see prompt 01).

### 5. Responsiveness & a11y

- Works in compact mobile headers and expanded desktop panels.
- Localized labels; theme tokens; accessible toggle with semantics.

---

## Tests

- Compact vs expanded content
- Preference survives restart without storing PHI
- Unauthorized fields never appear
- Responsive layouts and text scaling

## Related prompts

03, 04, 07, 12
