# Reception Desk queue tab — rule compliance

## Context

Make the Desk queue section (`ReceptionDeskSection.queue`, query `desk-queue`) fully compliant with `tabs.mdc`, `tables.mdc`, `dialogs.mdc`, `forms.mdc`, `printing.mdc`, and `screens.mdc`. Inventory baseline: `tabs/01-reception/02-desk-queue.md`. Depend on shared chrome remediation for Print, Export gating, and count infrastructure.

## Requirements

1. Keep strip label `receptionSectionQueue`, omit tab without scheduling read ∩, and show counts on selected and inactive states (`tabs.mdc`).
2. Badge count = authoritative non-terminal queue total for scope; active-tab filtered total when Filters/search/date apply (`tabs.mdc`).
3. Use `AppTabCountTone.warning` (or `danger` when escalation policy requires) — desk queue is an attention queue (`tabs.mdc`).
4. Toolbar order Filters → Settings → Export → Print → Schedule → Register with exact shared labels; date filter on queued-at remains (`tables.mdc`, `printing.mdc`).
5. Mount Print with shared preview-first flow and options aligned to queue export fields; omit Print/Export/Schedule/Register when unauthorized.
6. Default visible columns: prefer **5** with justification if fewer; Settings lists all optional columns (patient id, phone, queue id, payment status, provider, reason, next-action label) (`tables.mdc`).
7. Advanced filters stay comprehensive (current step, next action, provider, payment status, date) and share the filter model with table + active count (`tabs.mdc`, `tables.mdc`).
8. Next-action column remains **read-only guidance** (not a mutation button). Row select opens Flow Actions when a linked flow exists, else Queue Actions (`screens.mdc`).
9. Queue Actions keep generic title; nested Prioritize / Move (change status) / Assign doctor reuse shared dialogs and fields; omit when front-desk write denied (`dialogs.mdc`, `forms.mdc`).
10. Flow Actions from this tab keep clinical/vitals/billing off; print trigger label `Print` (`printing.mdc`).
11. Empty/loading/error/success feedback required; refresh table + all visible tab counts after prioritize/status/assign/schedule/register mutations.

## Constraints

- Do not mount hard-delete on this tab.
- Do not fork `QueueActionsDialog`; keep Reception wrapper.
- Do not navigate to another module mid-queue mutation.

## Acceptance Criteria

- [ ] Counts and `warning` tone satisfy Requirements 2–3.
- [ ] Toolbar includes Print after Export with preview-first behavior and correct omit gates.
- [ ] Filters/settings/defaults satisfy Requirements 6–7.
- [ ] Unauthorized queue hub actions and tab are absent.
- [ ] `tabs/01-reception/02-desk-queue.md` updated to match.

## Verification

- Tests: non-terminal count, prioritize/move/assign omit-when-unauthorized, toolbar order, print preview entry.
- Manual: linked-flow row opens Flow Actions; unlinked opens Queue Actions; light/dark + mobile row layout.

## Relevant Files

- `tabs/01-reception/02-desk-queue.md`
- `prompts/01-reception/00-shared-chrome.md`
- `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart`
- `frontend/lib/features/reception/presentation/widgets/reception_queue_actions_dialog.dart`
- `frontend/lib/features/reception/presentation/reception_access.dart`
- `frontend/lib/shared/opd_actions/opd_queue_actions_dialog.dart`
- `frontend/lib/shared/opd_actions/opd_flow_actions_dialog.dart`
- `frontend/test/features/reception/`
- `prompts/.cursor/tabs.mdc`
- `prompts/.cursor/tables.mdc`
- `prompts/.cursor/dialogs.mdc`
- `prompts/.cursor/forms.mdc`
- `prompts/.cursor/printing.mdc`
- `prompts/.cursor/screens.mdc`
