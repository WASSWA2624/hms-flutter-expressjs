# Radiology inventory — convention gaps

Optional findings vs `prompts/.cursor/*.mdc` after code trace (2026-08-11). No UI changes in this inventory pass.

## Residual / notes

- Desk `AppListTable` does **not** mount Export or table Print (`enableExport` / `enablePrint` unused) — print is detail/report-only (`PrintDocumentTemplates.clinicalResult`). Differs from Reception desk Print/Export pattern.
- Orders ↔ Patients view exists on query/controller (`applyView`) and column builders, but **no strip toggle** is mounted; atom maps still document `viewToggle`.
- Configurations dialog remains in code but **strip Configurations action is not mounted** (comment in workspace page).
- Assign / Start imaging intentionally omitted from procedure workbench header (single “Procedure done” confirmation).
- Atom maps still list Assign / Start / Perform study / Edit request / Addendum as write atoms for matrix inventory even when chrome is reduced.

Per-tab inventory lives under this folder; source prompt: `tabs-lister/11-radiology.md`.
