# Lab inventory — convention gaps

Required compliance gaps vs `prompts/.cursor/*.mdc` after remediation (2026-08-12).

## Residual

None required.

## Justified product exceptions (tested)

1. **Collect / Receive / Reject / Reverse** — controller + billing inventories + atoms remain; UI stays unmounted. Operator path is Enter result on the worklist. Tests assert `labCollectSampleAction` / Collect tooltip absent.
2. **Open billing CTA** — Await payment text only; settle owned by Billing desk (`labOpenBillingRequirement` kept for inventory/atom maps). No in-desk Billing handoff button.
3. **Lab Configurations / Orders view / Refresh toolbar** — intentionally removed; tests assert tooltips absent. Controller `applyView` / configure atoms residual only.
4. **Create additional / Edit order** helpers on page — dead (no entry from result dialog); product keeps Enter-result + Create Lab Order as the mutation paths.
5. **Critical notify acknowledge chrome** — atom `labCriticalNotifyRequirement` documented; no dedicated acknowledge control on Critical tab (notify remains narrative/capability only).
6. **Delete order/panel/test** atoms — explicitly not mounted.
7. **`LabWorkbenchView.orders`** — domain/controller residual; UI patients-only (tested: Orders view absent).

## Closed in this remediation

- Table Export gated with ∩ `evidence:export` / `canExportLabWorkspace`
- Table Print mounted after Export (preview-first `printLabWorkspaceList`)
- Follow-ups Settings uses panel column prefs (not Lab desk settings override)
- Zero-tabs → `AppFailureStateView` forbidden
- `keepPreviousDataDuringRefresh: true`
- Authoritative sibling counts + filtered active-tab badge (`labSectionTabCount`)
- Count tones via `labSectionCountTone`
- Toolbar Close labels on Advanced filters / Settings
