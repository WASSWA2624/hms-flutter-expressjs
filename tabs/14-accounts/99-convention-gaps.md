# Accounts inventory — convention gaps

Residual findings vs `prompts/.cursor/*.mdc` after shared-chrome / convention-gap remediation.

## Gaps

- none

## Justified product exceptions (documented)

- `accounts_gl_workspace_page.dart` remains a re-export of the desk page — GL is in-desk only (`?section=gl`), not a separate nested route surface.
- Detail / dialog print packets may reuse `PrintDocumentTemplates.claimStatement` (shared template name; Accounts-owned option panels) — intentional template reuse, not a residual list-chrome gap.
- List Print uses `printAccountsListTable` → `PrintDocumentTemplates.registry` (preview-first).
