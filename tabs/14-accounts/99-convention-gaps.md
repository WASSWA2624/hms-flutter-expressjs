# Accounts inventory — convention gaps

Optional findings vs `prompts/.cursor/*.mdc` (inventory only; no UI changes in this pass).

## Gaps

- Open work lacks table `enableExport` / `enablePrint` while journals/approvals/gl/ledgers export; chart uses a custom Print trailing action instead of `AppListTable.enablePrint`.
- Approvals and GL omit date filter; Books omits advanced Filters entirely (chips only) — document as intentional, but uneven vs reception “Filters on all tabs” convention.
- Print helpers reuse `PrintDocumentTemplates.claimStatement` for journal/approval/GL/books/patient ledger packets (shared template name; Accounts-owned option panels).
- `accounts_gl_workspace_page.dart` is a re-export of the desk page — no separate GL route surface beyond `?section=gl` + dialog.
- Open work has no Export while sibling work-queue tabs do — flag if tables.mdc expects Export whenever list chrome is readable.
