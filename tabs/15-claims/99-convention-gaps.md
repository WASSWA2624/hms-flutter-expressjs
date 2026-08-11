# Claims inventory — convention gaps

Optional findings vs `prompts/.cursor/*.mdc` (inventory only; no UI changes).

## Gaps

- Advanced Filters only on Settled; Authorizations / Active Claims rely on summary chips — uneven vs “Filters on all tabs” if that convention is applied workspace-wide.
- Date filter explicitly disabled on all Claims queue tabs.
- No table-level Export/Print; Print only in detail (Settled uses nested export ∪; others use read ∩) — document as intentional progressive disclosure, but differs from Reception table Print.
- Insurance Setup count always 0; tab still shows count chrome with zero.
- Collect patient share leaves Claims for Billing (reused) — ensure dialogs.mdc nesting notes remain accurate.
