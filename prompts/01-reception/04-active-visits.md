# Reception Active visits tab — rule compliance

## Context

Make the Active visits section (`ReceptionDeskSection.activeVisits`, query `active` / aliases) fully compliant with `tabs.mdc`, `tables.mdc`, `dialogs.mdc`, `forms.mdc`, `printing.mdc`, and `screens.mdc`. Inventory baseline: `tabs/01-reception/04-active-visits.md`.

## Requirements

1. Keep strip label `receptionSectionActiveVisits`; omit tab unless `receptionActiveVisitsRequirement` allows; deep-link `flowId` opens Flow Actions only when row-select is allowed (`tabs.mdc`, `screens.mdc`).
2. Badge count = authoritative active-visit total; active filtered total when stage/next-action/provider/payment/date/search apply (`tabs.mdc`).
3. Use urgency tone appropriate for in-facility pressure (`warning` justified; document in test) (`tabs.mdc`).
4. Toolbar: Filters → Settings → Export → Print → Schedule → Register; exact shared labels; date filter on started-at (`tables.mdc`, `printing.mdc`).
5. Print uses shared preview-first path with options aligned to active-visit export fields; omit when unauthorized.
6. Prefer **5** default columns (justify if next-action omission leaves fewer); Settings lists all optional columns (`tables.mdc`).
7. Advanced filters remain comprehensive (stage, next action, provider, payment status, date, search fields) on the shared filter model (`tabs.mdc`, `tables.mdc`).
8. Row select opens **reused** Flow Actions with `allowBillingActions`, `allowVitalsActions`, and `allowClinicalActions` false. Keep Assign/Change doctor, Follow up, Correct stage (as gated), and Print available per front-desk rules (`screens.mdc`).
9. Print trigger label must be exactly `Print`; preview via `showPrintOpdSummaryDialog` / `PrintDocumentTemplates.clinicalSummary` (or shared preview equivalent) (`printing.mdc`).
10. Nested assign/follow-up/print dialogs: generic titles, shared forms, no tenant/facility prompts (`dialogs.mdc`, `forms.mdc`).
11. Cover empty/loading/error/success; refresh table + all visible tab counts after Flow Actions mutations.

## Constraints

- Do not re-enable clinical/vitals/billing panels from Reception Active visits.
- Do not mount delete controls.
- Do not hand off mid-dialog to another module except ownership handoffs already modeled in shared hubs and allowed by `screens.mdc`.

## Acceptance Criteria

- [ ] Counts/tone and `flowId` deep-link behavior match Requirements 1–3.
- [ ] Toolbar Print after Export with preview-first and omit gates.
- [ ] Flow Actions from Reception still strips clinical/vitals/billing; Print label is `Print`.
- [ ] Filters/columns match Requirements 6–7.
- [ ] `tabs/01-reception/04-active-visits.md` updated to match.

## Verification

- Tests: active-visit membership count; stripped actions absent; Print label; Export/Print omit; nested assign/follow-up still available when front-desk allowed.
- Manual: print preview sections; light/dark; mobile.

## Relevant Files

- `tabs/01-reception/04-active-visits.md`
- `prompts/01-reception/00-shared-chrome.md`
- `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart`
- `frontend/lib/features/reception/presentation/reception_access.dart`
- `frontend/lib/shared/opd_actions/opd_flow_actions_dialog.dart`
- `frontend/lib/shared/opd_actions/opd_print_summary_dialog.dart`
- `frontend/test/features/reception/`
- `prompts/.cursor/tabs.mdc`
- `prompts/.cursor/tables.mdc`
- `prompts/.cursor/dialogs.mdc`
- `prompts/.cursor/forms.mdc`
- `prompts/.cursor/printing.mdc`
- `prompts/.cursor/screens.mdc`
