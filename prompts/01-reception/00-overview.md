# Reception overview — workspace compliance program

## Context

Bring the Reception desk (`ReceptionWorkspacePage`) to **100% compliance** with `prompts/.cursor` rules: `prompt.mdc`, `screens.mdc`, `tabs.mdc`, `tables.mdc`, `dialogs.mdc`, `forms.mdc`, and `printing.mdc`.

Inventory baseline (do not reinvent atoms): `tabs/01-reception/`. Per-surface remediation prompts live beside this file under `prompts/01-reception/`. Execute this overview first only for shared infrastructure; otherwise implement the matching per-tab / shared-chrome / gaps prompts.

**Compliance** means every acceptance criterion in this program is proven in code and tests. Do not leave “documented exceptions” for required rule clauses unless a numbered requirement here explicitly marks a justified product exception and records the justification in code comments plus tests.

## Requirements

1. Treat `tabs/01-reception/00-overview.md` as the authoritative tab index (`ReceptionDeskSection` order, query values, aliases). Keep deep-link helpers `receptionDeskSectionToQueryValue` / `receptionDeskSectionFromQuery` aligned with that index.
2. Implement remediation in this order so shared chrome lands once:
   1. `00-shared-chrome.md`
   2. `99-convention-gaps.md` (cross-cutting count/print/export/tone fixes)
   3. Per-tab prompts `01-appointments` … `06-payment-gate`
3. Keep all operator flows **in-desk** per `screens.mdc`: dialogs / tabs / panels only; no nested feature `GoRoute` pages for Reception multi-step work. Module switches stay shell-owned; Payment gate must not fork Billing cashier.
4. Reuse shared components and OPD/patient hubs; extend shared primitives when Reception lacks a required shared capability (notably list-table Print). Do not fork parallel tab, table, dialog, form, or print chrome.
5. Preserve RBAC/ABAC: omit unauthorized tabs/actions; never render disabled “no access” placeholders for routine unauthorized scopes. Cover loading, empty, error, success, validation, and visible feedback on every remediated surface.
6. After each remediation, update the matching inventory file under `tabs/01-reception/` so the catalog matches shipped behavior (still not under a restored `screens/` folder).
7. Add or extend automated tests under `frontend/test/features/reception/` proving authorized atoms remain available and unauthorized atoms are absent.

## Constraints

- Do not recreate `screens/` inventory paths.
- Do not broaden scope into OPD/Billing workspace redesigns except shared primitive extensions required for Reception compliance and reuse.
- Do not invent tabs, dialogs, or print templates that are unreachable from Reception after remediation.
- Separate optional polish from required compliance; only required items appear under Requirements.

## Acceptance Criteria

- [ ] Every `ReceptionDeskSection` has a completed remediation prompt under `prompts/01-reception/` and a matching updated inventory under `tabs/01-reception/`.
- [ ] Shared chrome and convention-gap prompts are implemented before claiming per-tab completion for Print, Export gating, authoritative counts, and count tones.
- [ ] No Reception mid-flow navigation to another feature page; Payment gate remains guidance-only for cashier actions (`screens.mdc`).
- [ ] Tests prove unauthorized UI is absent and authorized UI remains for representative Reception roles.
- [ ] No new markdown inventories under `screens/`.

## Verification

- Trace `reception_workspace_page.dart`, `reception_access.dart`, and widgets listed in `tabs/01-reception/00-overview.md`.
- Run Reception feature tests; add cases for omit-when-unauthorized, count badges, toolbar order Filters → Settings → Export → Print → context, and print-preview-before-print.
- Spot-check mobile / tablet / desktop and light / dark themes on the desk shell.
- Confirm inventory files were updated to match post-remediation UI.

## Relevant Files

- `tabs/01-reception/00-overview.md`
- `prompts/01-reception/00-shared-chrome.md`
- `prompts/01-reception/99-convention-gaps.md`
- `prompts/01-reception/01-appointments.md`
- `prompts/01-reception/02-desk-queue.md`
- `prompts/01-reception/03-high-priority.md`
- `prompts/01-reception/04-active-visits.md`
- `prompts/01-reception/05-follow-ups.md`
- `prompts/01-reception/06-payment-gate.md`
- `prompts/.cursor/prompt.mdc`
- `prompts/.cursor/screens.mdc`
- `prompts/.cursor/tabs.mdc`
- `prompts/.cursor/tables.mdc`
- `prompts/.cursor/dialogs.mdc`
- `prompts/.cursor/forms.mdc`
- `prompts/.cursor/printing.mdc`
- `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart`
- `frontend/test/features/reception/`
