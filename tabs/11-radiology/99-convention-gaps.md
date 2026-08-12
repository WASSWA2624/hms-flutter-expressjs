# Radiology inventory — convention gaps

Required compliance gaps vs `prompts/.cursor/*.mdc` after remediation (2026-08-12). Completing `prompts/11-radiology/99-convention-gaps.md` + per-tab prompts (`00`–`04`) is the gate for Radiology **100%** rule compliance.

## Residual

None required.

## Justified product exceptions (tested)

1. **Assign / Start imaging** — intentionally omitted from procedure workbench header; **Procedure done** is the single acquisition confirmation. Tests assert Assign / Start imaging absent (`radiology_workspace_page_test`, worklist/reporting permission suites). Cite: workbench product policy; not a rule gap.
2. **Orders ↔ Patients view** — query/controller `applyView` + column builders remain; **no strip toggle** mounted. Atom maps still document `viewToggle` for matrix inventory.
3. **Configurations** — dialog remains in code; **strip Configurations action is not mounted**. Tests assert Configurations tooltip absent.
4. **Assign / Start / Perform study / Edit request / Addendum** — write atoms remain on matrix maps even when chrome is reduced (documented inventory only).

## Closed in this remediation

### Inventory residual gaps
- Desk `AppListTable` mounts Export + table Print (`enablePrint: true`; `canExport` / `canPrint` via ∩ `evidence:export`) — not detail/report-only
- Assign / Start imaging recorded as tested product exception (above)

### tabs.mdc
- Authoritative sibling counts: unfiltered `RadiologySummary` (`workloadCount` / `reportingCount` / `historyCount`) via `radiologySectionTabCount`
- Active narrowed badge uses `orders.totalItemCount` (fallback `items.length` only when total missing)
- Follow-ups: `followUpTabCountProvider` + `onNarrowedCountChanged`
- Count tones via `radiologySectionCountTone`: Worklist + Reporting `warning`; All orders + Follow-ups `info`

### tables.mdc
- Trailing order Filters → Settings → Export → Print → Request imaging (Follow-ups: no Request imaging)
- Export omit when unauthorized (`canExportRadiologyWorkspace` / per-tab `.export` atoms)
- Default visible columns prefer **5** (order boards + Follow-ups panel); Settings exposes choices + Reset
- Advanced filters / Settings footers: shared `Filters` / `Clear filters` / `Apply filters` / `Close`; Settings Close + Reset/Apply columns

### printing.mdc
- Table Print label `commonPrintActionLabel` → `Print`; preview-first `printRadiologyWorkspaceList` / `showAppPrintPreviewDialog`
- Report Print trigger `Print`; dialog title `printPreviewTitle`; document via `PrintDocumentTemplates.clinicalResult`
- Follow-ups list print reuses `printRadiologyWorkspaceList`

### dialogs / forms / screens
- In-desk detail / report / cancel / request imaging / follow-up complete-reschedule; no nested feature routes for desk tasks
- Shared clinical request shell for Request imaging; Follow-ups panel reused

### Program hygiene
- Tab inventories `00-shared-chrome` … `04-follow-ups` refreshed to shipped behavior
- Regression coverage: `radiology_shared_chrome_test`, workspace page export/print/tones, per-tab permission suites (worklist / reporting / all-orders / follow-ups)
