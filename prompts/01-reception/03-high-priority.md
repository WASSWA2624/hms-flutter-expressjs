# Reception High priority tab — rule compliance

## Context

Make the High priority section (`ReceptionDeskSection.highPriority`, query `high-priority`) fully compliant with `tabs.mdc`, `tables.mdc`, `dialogs.mdc`, `forms.mdc`, `printing.mdc`, and `screens.mdc`. Inventory baseline: `tabs/01-reception/03-high-priority.md`. Shared Print/Export/count work lands via `00-shared-chrome.md`.

## Requirements

1. Keep strip label `receptionSectionHighPriority`; omit tab without ∩ `patient:read` (+ modules). Nested emergency chrome stays gated by ∪ `emergency:read` and must **not** unlock the tab itself (`tabs.mdc`, inventory RBAC).
2. Badge count = authoritative prioritized non-terminal queue total; active filtered total when filters/search/date apply (`tabs.mdc`).
3. Use `AppTabCountTone.warning` or `danger` for this attention queue (`tabs.mdc`).
4. Toolbar: Filters → Settings → Export → Print → Schedule → Register; exact shared labels; date filter on queued-at (`tables.mdc`, `printing.mdc`).
5. Print preview-first with section/column options; omit Print/Export/context actions when unauthorized.
6. Prefer **5** default columns with recorded justification if fewer; Settings exposes all column choices including badges’ underlying fields where exportable (`tables.mdc`).
7. Advanced filters match desk-queue comprehensiveness (step, next action, provider, payment, date) on the shared filter model (`tabs.mdc`, `tables.mdc`).
8. Preserve row routing: emergency-linked flow + emergency read → Flow Actions; otherwise Queue Actions with High priority front-desk requirement. Emergency badge omitted without nested emergency read (`screens.mdc`).
9. Queue / Flow nested dialogs: generic titles, shared forms, clinical/vitals/billing stripped from Flow Actions; print trigger `Print` (`dialogs.mdc`, `forms.mdc`, `printing.mdc`).
10. Empty uses high-priority empty copy; cover loading/error/success; refresh table + all affected tab counts after mutations.

## Constraints

- Do not grant `/emergency` shell entry from this tab’s nested read.
- Do not mount hard-delete.
- Do not duplicate desk-queue chrome with a fork; share filter/column helpers where practical.

## Acceptance Criteria

- [ ] Counts/tone and emergency omit rules match Requirements 1–3 and 8.
- [ ] Toolbar Print/Export order and gates match Requirements 4–5.
- [ ] Filters and column defaults match Requirements 6–7.
- [ ] Unauthorized emergency Flow Actions path is absent; Queue Actions still available when allowed.
- [ ] `tabs/01-reception/03-high-priority.md` updated to match.

## Verification

- Tests: tab visible without `emergency:read`; emergency badge/Flow Actions only with nested grant; prioritized count; toolbar omit matrix.
- Manual: prioritize badge + emergency badge rendering; light/dark.

## Relevant Files

- `tabs/01-reception/03-high-priority.md`
- `prompts/01-reception/00-shared-chrome.md`
- `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart`
- `frontend/lib/features/reception/presentation/widgets/reception_queue_actions_dialog.dart`
- `frontend/lib/features/reception/presentation/reception_access.dart`
- `frontend/lib/shared/opd_actions/opd_flow_actions_dialog.dart`
- `frontend/test/features/reception/`
- `prompts/.cursor/tabs.mdc`
- `prompts/.cursor/tables.mdc`
- `prompts/.cursor/dialogs.mdc`
- `prompts/.cursor/forms.mdc`
- `prompts/.cursor/printing.mdc`
- `prompts/.cursor/screens.mdc`
