# IPD overview — workspace compliance program

## Context

Bring the IPD desk to **100% compliance** with `prompts/.cursor` rules: `prompt.mdc`, `screens.mdc`, `tabs.mdc`, `tables.mdc`, `dialogs.mdc`, `forms.mdc`, and `printing.mdc`.

Inventory baseline (do not reinvent atoms): `tabs/04-ipd/`. Per-surface remediation prompts live beside this file under `prompts/04-ipd/`. Execute this overview first only for shared infrastructure; otherwise implement the matching per-tab / shared-chrome / gaps prompts.

**Compliance** means every acceptance criterion in this program is proven in code and tests. Do not leave “documented exceptions” for required rule clauses unless a numbered requirement here explicitly marks a justified product exception and records the justification in code comments plus tests.

## Requirements

1. Treat `tabs/04-ipd/00-overview.md` as the authoritative tab index (`IpdWorkspaceSection` order, query values, aliases). Keep deep-link helpers aligned with that index.
2. Implement remediation in this order so shared chrome lands once:
   1. `00-shared-chrome.md`
   2. `99-convention-gaps.md` (cross-cutting count/print/export/tone/filter fixes)
   3. Per-tab prompts:
   - `prompts/04-ipd/01-admission-queue.md`
   - `prompts/04-ipd/02-active-patients.md`
   - `prompts/04-ipd/03-transfers.md`
   - `prompts/04-ipd/04-discharge.md`
   - `prompts/04-ipd/05-bed-board.md`
   - `prompts/04-ipd/06-follow-ups.md`
3. Keep all operator flows **in-desk** per `screens.mdc`: dialogs / tabs / panels only; no nested feature `GoRoute` pages for multi-step desk work. Module switches stay shell-owned; only use allowed ownership handoffs from `screens.mdc`.
4. Reuse shared components under `frontend/lib/shared/` and existing feature hubs; extend shared primitives when this desk lacks a required shared capability (notably list-table Print, Export gating, authoritative counts). Do not fork parallel tab, table, dialog, form, or print chrome.
5. Preserve RBAC/ABAC: omit unauthorized tabs/actions; never render disabled “no access” placeholders for routine unauthorized scopes. Cover loading, empty, error, success, validation, and visible feedback on every remediated surface.
6. After each remediation, update the matching inventory file under `tabs/04-ipd/` so the catalog matches shipped behavior (still not under a restored `screens/` folder).
7. Add or extend automated tests under `frontend/test/features/ipd/` proving authorized atoms remain available and unauthorized atoms are absent.

## Constraints

- Do not recreate `screens/` inventory paths.
- Do not broaden scope into unrelated workspace redesigns except shared primitive extensions required for this desk’s compliance and reuse.
- Do not invent tabs, dialogs, or print templates that are unreachable from this desk after remediation.
- Separate optional polish from required compliance; only required items appear under Requirements.

## Acceptance Criteria

- [x] Every desk section in `tabs/04-ipd/00-overview.md` has a completed remediation prompt under `prompts/04-ipd/` and a matching updated inventory under `tabs/04-ipd/`.
- [x] Shared chrome and convention-gap prompts are implemented before claiming per-tab completion for Print, Export gating, authoritative counts, and count tones.
- [x] No mid-flow navigation to another feature page except allowed ownership handoffs (`screens.mdc`).
- [x] Tests prove unauthorized UI is absent and authorized UI remains for representative roles.
- [x] No new markdown inventories under `screens/`.

## Verification

- Trace `frontend/lib/features/ipd/presentation/pages/ipd_workspace_page.dart`, `frontend/lib/features/ipd/presentation/ipd_access.dart`, and widgets listed in `tabs/04-ipd/00-overview.md`.
- Run feature tests under `frontend/test/features/ipd/`; add cases for omit-when-unauthorized, count badges, toolbar order Filters → Settings → Export → Print → context (when Print applies), and print-preview-before-print.
- Spot-check mobile / tablet / desktop and light / dark themes on the desk shell.
- Confirm inventory files were updated to match post-remediation UI.

## Relevant Files

- `tabs/04-ipd/00-overview.md`
- `prompts/04-ipd/00-shared-chrome.md`
- `prompts/04-ipd/99-convention-gaps.md`
- `prompts/04-ipd/01-admission-queue.md`
- `prompts/04-ipd/02-active-patients.md`
- `prompts/04-ipd/03-transfers.md`
- `prompts/04-ipd/04-discharge.md`
- `prompts/04-ipd/05-bed-board.md`
- `prompts/04-ipd/06-follow-ups.md`
- `prompts/.cursor/prompt.mdc`
- `prompts/.cursor/screens.mdc`
- `prompts/.cursor/tabs.mdc`
- `prompts/.cursor/tables.mdc`
- `prompts/.cursor/dialogs.mdc`
- `prompts/.cursor/forms.mdc`
- `prompts/.cursor/printing.mdc`
- `frontend/lib/features/ipd/presentation/pages/ipd_workspace_page.dart`
- `frontend/lib/features/ipd/presentation/ipd_access.dart`
- `frontend/test/features/ipd/`
