# Nursing inventory — convention gaps

Required compliance gaps vs `prompts/.cursor/*.mdc` after inventory of presentation code (2026-08-11).

## Residual

1. **Route entry vs comments/tests** — live catalog / `AppRoutes.nursing` = ∩ `nursing:read` + module; comments/tests still describe ∪ clinical|patient|last_office|operations:read.
2. **Dual read vocabulary** — shell/catalog uses `nursing:read`; tab/list chrome uses ∪ `clinical:read` \| `patient:read`.
3. **No worklist Print** — print only from patient detail (`printing.mdc` / `tables.mdc` toolbar Print).
4. **No dedicated Handover toolbar** — only Shift context + tab / next-action / detail.
5. **Export ungated** in `NursingWorklistPanel` (table defaults; no `evidence:export`-style nursing gate).
6. **`assignedWard` scope filter is a no-op** in entity `matchesScope` (always true) despite ABAC ward comments.
7. **Handover tab count** uses global pending handovers, not scoped worklist length alone.
8. **Urgent / Medication due / Transfer pending** atom classes omit `billingPanel`/`openBilling`, while shared detail can still show billing.
9. **Transfer** has no `panel=` deep link.
10. **`openIcu` / `navigation`** = empty `AccessRequirement()` when mounted.
11. **Responsible nurse column** is synthetic summary text, not a real assignee field.
12. **Count badges omit `0`** (`_tabCountOrNull`) — empty scopes hide the badge rather than showing explicit `0` (`tabs.mdc` prefers explicit 0 when meaningful).
